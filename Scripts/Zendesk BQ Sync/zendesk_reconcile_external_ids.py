#!/usr/bin/env python3
"""
zendesk_reconcile_external_ids.py
---------------------------------
Periodic reconciliation that keeps each Zendesk organization's external_id equal
to the warehouse "winner" account_id for its business name — catching the
status-driven drift that the Hightouch dedup ranking can introduce.

Pipeline (one headless run):
  1. Query BigQuery for the winning account_id per businesslegalname, using the
     SAME ranking as the Hightouch model (status -> most recent coverage -> account_id).
  2. Pull every Zendesk org (id, name, external_id) via cursor pagination.
  3. Join by normalized name; any org whose external_id != the current winner is
     re-keyed via PUT.

Dry run by default; pass --apply to write. Safe to run on a schedule.

Env:
    ZENDESK_SUBDOMAIN   (required)
    Auth — one of:
        ZENDESK_OAUTH_TOKEN                  (preferred: scoped OAuth2 Bearer token)
        ZENDESK_EMAIL + ZENDESK_API_TOKEN    (fallback: full-permission Basic auth, local use)
    BQ_PROJECT   (default: production-storage-b567)

Requires: bq CLI (authenticated), python3 + requests.
"""

import argparse
import html
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

import requests
from requests.auth import HTTPBasicAuth

BQ_PROJECT = os.environ.get("BQ_PROJECT", "production-storage-b567")

# The winner query lives in reconcile_winners.sql (single source of truth, shared
# with the cloud routine that runs it via the BigQuery MCP connector). Ranking:
#   status (today)  ->  most recent coverage end (desc)  ->  account_id (deterministic)
SQL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reconcile_winners.sql")


def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] {msg}", flush=True)


def norm(s):
    return " ".join(html.unescape(s or "").split()).lower()


def get_env(key):
    val = os.environ.get(key)
    if not val:
        sys.exit(f"ERROR: missing environment variable {key}")
    return val


def winners_from_rows(rows):
    """[{businesslegalname, account_id}, ...] -> {normalized_name: account_id}."""
    return {norm(r["businesslegalname"]): r["account_id"] for r in rows}


def fetch_winners_bq():
    """Run reconcile_winners.sql via the bq CLI (local use)."""
    with open(SQL_PATH) as f:
        sql = f.read()
    # Pass via stdin: the SQL starts with a "--" comment line, which bq would
    # otherwise parse as a flag if given as a positional argument.
    proc = subprocess.run(
        ["bq", f"--project_id={BQ_PROJECT}", "query", "--nouse_legacy_sql",
         "--format=json", "--max_rows=100000"],
        input=sql, capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.exit(f"ERROR: bq query failed:\n{proc.stderr.strip()}")
    return winners_from_rows(json.loads(proc.stdout or "[]"))


def load_winners_file(path):
    """Load winners pre-fetched via the BigQuery MCP connector (JSON array of
    {businesslegalname, account_id}). Used by the cloud routine."""
    with open(path) as f:
        rows = json.load(f)
    if not rows:
        sys.exit(f"ERROR: winners file {path} is empty — refusing to run (would look like total drift).")
    return winners_from_rows(rows)


def request_with_retry(session, method, url, **kwargs):
    kwargs.setdefault("timeout", 30)
    for _ in range(5):
        resp = session.request(method, url, **kwargs)
        if resp.status_code == 429:
            wait = int(resp.headers.get("Retry-After", "1"))
            log(f"  rate limited (429); waiting {wait}s")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp
    resp.raise_for_status()
    return resp


def dump_orgs(session, base_url):
    """All orgs (id, name, external_id) via cursor pagination."""
    orgs = []
    url = f"{base_url}/api/v2/organizations.json?page[size]=100"
    while url:
        data = request_with_retry(session, "GET", url).json()
        for o in data.get("organizations", []):
            orgs.append({"id": str(o["id"]), "name": o.get("name") or "",
                         "external_id": o.get("external_id") or ""})
        url = data.get("links", {}).get("next") if data.get("meta", {}).get("has_more") else None
    return orgs


def main():
    ap = argparse.ArgumentParser(description="Reconcile Zendesk external_ids to warehouse winners.")
    ap.add_argument("--apply", action="store_true", help="Write changes. Default is a dry run.")
    ap.add_argument("--winners-file", help="JSON array of {businesslegalname, account_id} "
                    "(e.g. from the BigQuery MCP connector). If omitted, queries via the bq CLI.")
    args = ap.parse_args()
    dry = not args.apply

    subdomain = get_env("ZENDESK_SUBDOMAIN")
    base_url = f"https://{subdomain}.zendesk.com"
    session = requests.Session()
    session.headers.update({"Content-Type": "application/json"})
    # Prefer a scoped OAuth2 Bearer token (ZENDESK_OAUTH_TOKEN) — Zendesk API
    # tokens can't be scoped, so OAuth is the least-privilege option for the
    # scheduled job. Fall back to email/API-token Basic auth for local runs.
    oauth = os.environ.get("ZENDESK_OAUTH_TOKEN")
    if oauth:
        session.headers["Authorization"] = f"Bearer {oauth}"
    else:
        email = get_env("ZENDESK_EMAIL")
        token = get_env("ZENDESK_API_TOKEN")
        session.auth = HTTPBasicAuth(f"{email}/token", token)

    log(f"{'DRY RUN' if dry else 'APPLY'} — loading warehouse winners…")
    winners = load_winners_file(args.winners_file) if args.winners_file else fetch_winners_bq()
    log(f"  {len(winners)} winning account_ids ({'winners-file' if args.winners_file else 'bq'})")

    log("fetching Zendesk orgs…")
    orgs = dump_orgs(session, base_url)
    log(f"  {len(orgs)} orgs")

    drift = [(o, winners[norm(o["name"])]) for o in orgs
             if norm(o["name"]) in winners and o["external_id"] != winners[norm(o["name"])]]
    log(f"drifted orgs (external_id != current winner): {len(drift)}")

    updated = errors = 0
    for o, want in drift:
        log(f"  {'WOULD re-key' if dry else 're-keying'} {o['name'].strip()!r} "
            f"(id={o['id']}) {o['external_id'][:8] or 'BLANK'} -> {want[:8]}")
        if dry:
            continue
        try:
            request_with_retry(session, "PUT", f"{base_url}/api/v2/organizations/{o['id']}.json",
                               json={"organization": {"external_id": want}})
            updated += 1
            time.sleep(0.4)
        except requests.RequestException as e:
            log(f"    ERROR: {e}")
            errors += 1

    log(f"done — drift={len(drift)} updated={updated if not dry else 0} errors={errors}"
        f"{' (dry run; re-run with --apply)' if dry and drift else ''}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
