#!/usr/bin/env python3
"""
zendesk_backfill_external_id.py
-------------------------------
Re-stamps the external_id on Zendesk organizations so they match the correct
warehouse / Hightouch key. The existing orgs already carry an external_id, but
the wrong one, which makes Hightouch upserts collide. This fixes them in place.

Input CSV (default: zendesk_external_id_updates.csv) with columns:
    zendesk_org_id, zendesk_name, old_external_id, new_external_id, source_name

For each row it issues:
    PUT /api/v2/organizations/{id}.json
    { "organization": { "external_id": "<new_external_id>" } }

SAFETY: before writing, it re-reads the org's current external_id and only
proceeds if it still equals old_external_id. If the live value has drifted from
what the CSV expected, the row is SKIPPED (not clobbered) and reported.

Usage:
    export ZENDESK_SUBDOMAIN=your-subdomain
    export ZENDESK_EMAIL=you@getaddify.com
    export ZENDESK_API_TOKEN=your_api_token

    python3 zendesk_backfill_external_id.py            # dry run (default)
    python3 zendesk_backfill_external_id.py --apply     # actually write
    python3 zendesk_backfill_external_id.py --csv path.csv --apply
    python3 zendesk_backfill_external_id.py --no-verify  # skip pre-write re-check
"""

import argparse
import csv
import os
import sys
import time

import requests
from requests.auth import HTTPBasicAuth


def get_env(key):
    val = os.environ.get(key)
    if not val:
        print(f"ERROR: Missing environment variable {key}")
        sys.exit(1)
    return val


def request_with_retry(session, method, url, **kwargs):
    """Issue a request, honoring Zendesk's 429 Retry-After before raising."""
    kwargs.setdefault("timeout", 30)
    for _ in range(5):
        resp = session.request(method, url, **kwargs)
        if resp.status_code == 429:
            wait = int(resp.headers.get("Retry-After", "1"))
            print(f"  Rate limited (429); waiting {wait}s before retry...")
            time.sleep(wait)
            continue
        resp.raise_for_status()
        return resp
    resp.raise_for_status()
    return resp


def get_org(session, base_url, org_id):
    resp = request_with_retry(
        session, "GET", f"{base_url}/api/v2/organizations/{org_id}.json"
    )
    return resp.json().get("organization", {})


def set_external_id(session, base_url, org_id, new_external_id):
    request_with_retry(
        session,
        "PUT",
        f"{base_url}/api/v2/organizations/{org_id}.json",
        json={"organization": {"external_id": new_external_id}},
    )


def main():
    parser = argparse.ArgumentParser(description="Re-stamp Zendesk org external_ids.")
    parser.add_argument("--csv", default="zendesk_external_id_updates.csv",
                        help="Input CSV (default: zendesk_external_id_updates.csv)")
    parser.add_argument("--apply", action="store_true",
                        help="Actually write changes. Default is a dry run.")
    parser.add_argument("--no-verify", dest="verify", action="store_false",
                        help="Skip the pre-write check that live value == old_external_id.")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only process the first N rows (useful for a test run).")
    args = parser.parse_args()

    dry_run = not args.apply

    subdomain = get_env("ZENDESK_SUBDOMAIN")
    email = get_env("ZENDESK_EMAIL")
    token = get_env("ZENDESK_API_TOKEN")

    base_url = f"https://{subdomain}.zendesk.com"
    session = requests.Session()
    session.auth = HTTPBasicAuth(f"{email}/token", token)
    session.headers.update({"Content-Type": "application/json"})

    with open(args.csv, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"{'[DRY RUN] ' if dry_run else ''}Processing {len(rows)} external_id updates "
          f"from {args.csv}\n")

    updated, skipped_noop, skipped_drift, errors = [], [], [], []

    for row in rows:
        org_id = row["zendesk_org_id"].strip()
        name = row["zendesk_name"]
        old_ext = (row["old_external_id"] or "").strip()
        new_ext = (row["new_external_id"] or "").strip()

        try:
            current = old_ext
            if args.verify:
                current = (get_org(session, base_url, org_id).get("external_id") or "").strip()

            if current == new_ext:
                print(f"NOOP:  {name} (id={org_id}) already set to {new_ext}")
                skipped_noop.append(org_id)
                continue

            if args.verify and current != old_ext:
                print(f"SKIP (drift): {name} (id={org_id}) live={current!r} "
                      f"expected old={old_ext!r} — not overwriting")
                skipped_drift.append(org_id)
                continue

            print(f"UPDATE: {name} (id={org_id}) {old_ext} → {new_ext}")
            if not dry_run:
                set_external_id(session, base_url, org_id, new_ext)
            updated.append(org_id)
            time.sleep(0.4)  # ~150 req/min, under Zendesk's 200/min limit
        except requests.RequestException as e:
            print(f"ERROR on '{name}' (id={org_id}): {e}")
            errors.append(org_id)

    print(f"\n--- Summary {'(dry run — nothing written)' if dry_run else ''} ---")
    print(f"Updated:        {len(updated)}")
    print(f"Already set:    {len(skipped_noop)}")
    print(f"Skipped drift:  {len(skipped_drift)}")
    print(f"Errors:         {len(errors)}")
    if skipped_drift:
        print(f"\nDrifted (review manually): {skipped_drift}")
    if errors:
        print(f"\nFailed: {errors}")
    if dry_run:
        print("\nRe-run with --apply to write these changes.")


if __name__ == "__main__":
    main()
