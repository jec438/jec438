#!/usr/bin/env python3
"""
find_account_dupes.py
---------------------
Finds likely-duplicate Salesforce Accounts by combining:
  1. Address agreement (normalized billing OR mailing/shipping address), and
  2. Fuzzy name similarity (token-sorted, suffix/punctuation stripped).

Designed to run locally (e.g. via Claude Code) against the full org rather than
through a chat tool, because the org has ~30K accounts and pairwise fuzzy
matching needs real compute + blocking.

OUTPUT: a CSV of candidate duplicate PAIRS for human review. It does NOT merge
anything. Merging is a separate, deliberate step (Salesforce UI or the
composite merge REST endpoint).

------------------------------------------------------------------------------
SETUP
------------------------------------------------------------------------------
Requires Python 3.9+. One third-party dep for fast fuzzy matching:

    pip install rapidfuzz requests

Auth: credentials are loaded automatically from 1Password
("Salesforce SF Credentials (jenna@getaddify.com)"). Requires the `op` CLI
to be installed and unlocked. As a fallback, you can export env vars:

    export SF_INSTANCE_URL="https://yourorg.my.salesforce.com"
    export SF_ACCESS_TOKEN="00D...."

Access tokens expire. To refresh: sf org display --target-org my-org --json,
update the 1Password item, and re-run.

------------------------------------------------------------------------------
USAGE
------------------------------------------------------------------------------
    python find_account_dupes.py
    python find_account_dupes.py --name-threshold 90 --out candidates.csv
    python find_account_dupes.py --require-address   # default: address required
    python find_account_dupes.py --no-require-address # name-only blocking too
"""

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from collections import defaultdict

import requests
from rapidfuzz import fuzz

API_VERSION = "v64.0"
PAGE_SIZE = 2000  # SOQL hard cap per query batch we page through

# ---------------------------------------------------------------------------
# Normalization
# ---------------------------------------------------------------------------

# Common company suffixes / noise tokens to drop from names before comparison.
COMPANY_SUFFIXES = {
    "inc", "incorporated", "llc", "l.l.c", "llp", "ltd", "limited", "corp",
    "corporation", "co", "company", "group", "holdings", "holding", "enterprises",
    "enterprise", "the", "and", "&", "of",
}

# Street abbreviation normalization so "Road Northwest" == "RD NW", etc.
STREET_ABBREV = {
    "street": "st", "st": "st",
    "road": "rd", "rd": "rd",
    "avenue": "ave", "ave": "ave", "av": "ave",
    "boulevard": "blvd", "blvd": "blvd",
    "drive": "dr", "dr": "dr",
    "lane": "ln", "ln": "ln",
    "court": "ct", "ct": "ct",
    "place": "pl", "pl": "pl",
    "suite": "ste", "ste": "ste",
    "highway": "hwy", "hwy": "hwy",
    "parkway": "pkwy", "pkwy": "pkwy",
    "circle": "cir", "cir": "cir",
    "terrace": "ter", "ter": "ter",
    "northwest": "nw", "nw": "nw",
    "northeast": "ne", "ne": "ne",
    "southwest": "sw", "sw": "sw",
    "southeast": "se", "se": "se",
    "north": "n", "n": "n",
    "south": "s", "s": "s",
    "east": "e", "e": "e",
    "west": "w", "w": "w",
    "apartment": "apt", "apt": "apt",
    "building": "bldg", "bldg": "bldg",
    "floor": "fl", "fl": "fl",
}

_punct_re = re.compile(r"[^a-z0-9\s]")
_ws_re = re.compile(r"\s+")


def _tokens(s):
    return _ws_re.sub(" ", _punct_re.sub(" ", (s or "").lower())).strip().split()


def normalize_name(name):
    """Lowercase, strip punctuation, drop company suffix/noise tokens, sort tokens."""
    toks = [t for t in _tokens(name) if t not in COMPANY_SUFFIXES]
    if not toks:  # name was all noise (e.g. "The Co") -> fall back to raw tokens
        toks = _tokens(name)
    return " ".join(sorted(toks))


def normalize_street(street):
    toks = _tokens(street)
    toks = [STREET_ABBREV.get(t, t) for t in toks]
    return " ".join(toks)


def normalize_postal(pc):
    if not pc:
        return ""
    digits = re.sub(r"[^0-9]", "", str(pc))
    return digits[:5]  # ZIP5; drops +4 so 30305 == 30305-1234


def address_key(street, postal):
    """A blocking + agreement key. Empty if not enough address to trust."""
    ns, np = normalize_street(street), normalize_postal(postal)
    if not ns or not np:
        return ""
    return f"{ns}|{np}"


def account_address_keys(rec):
    """Return the set of usable address keys for an account (billing + shipping)."""
    keys = set()
    bk = address_key(rec.get("BillingStreet"), rec.get("BillingPostalCode"))
    if bk:
        keys.add(bk)
    sk = address_key(rec.get("ShippingStreet"), rec.get("ShippingPostalCode"))
    if sk:
        keys.add(sk)
    return keys


# ---------------------------------------------------------------------------
# Salesforce paging
# ---------------------------------------------------------------------------

def sf_get(instance_url, token, path, params=None):
    url = f"{instance_url}/services/data/{API_VERSION}/{path.lstrip('/')}"
    r = requests.get(url, headers={"Authorization": f"Bearer {token}"}, params=params)
    if r.status_code == 401:
        sys.exit("ERROR 401: access token expired or invalid. Refresh with "
                 "`sf org display --target-org <alias> --json` and re-export SF_ACCESS_TOKEN.")
    r.raise_for_status()
    return r.json()


def fetch_all_accounts(instance_url, token):
    """Page through every Account using an Id cursor (stable, avoids OFFSET limits)."""
    fields = ("Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, "
              "ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, CreatedDate")
    all_recs = []
    last_id = ""
    while True:
        where = f"WHERE Id > '{last_id}' " if last_id else ""
        soql = (f"SELECT {fields} FROM Account {where}"
                f"ORDER BY Id ASC LIMIT {PAGE_SIZE}")
        data = sf_get(instance_url, token, "query", {"q": soql})
        recs = data.get("records", [])
        if not recs:
            break
        all_recs.extend(recs)
        last_id = recs[-1]["Id"]
        print(f"  fetched {len(all_recs)} accounts...", file=sys.stderr)
        if len(recs) < PAGE_SIZE:
            break
        time.sleep(0.1)  # be gentle on API limits
    return all_recs


# ---------------------------------------------------------------------------
# Matching
# ---------------------------------------------------------------------------

def find_candidates(accounts, name_threshold, require_address):
    """
    Block accounts to keep comparisons cheap, then fuzzy-compare names within
    each block. With require_address=True, blocks are address keys (so a pair
    only surfaces if it shares an address AND has similar names). With
    require_address=False, accounts with no usable address also get blocked by
    the first token of their normalized name as a fallback.
    """
    blocks = defaultdict(list)  # block_key -> list of (idx, normalized_name)
    norm_cache = {}

    for idx, rec in enumerate(accounts):
        nname = normalize_name(rec.get("Name"))
        norm_cache[idx] = nname
        addr_keys = account_address_keys(rec)
        if addr_keys:
            for ak in addr_keys:
                blocks[("addr", ak)].append(idx)
        elif not require_address and nname:
            blocks[("name", nname.split()[0])].append(idx)

    # --- find all matching edges ---
    seen_pairs = set()
    edges = []  # (score, idx_a, idx_b)

    for block_key, idxs in blocks.items():
        if len(idxs) < 2:
            continue
        for i in range(len(idxs)):
            for j in range(i + 1, len(idxs)):
                a, b = idxs[i], idxs[j]
                pair = (min(a, b), max(a, b))
                if pair in seen_pairs:
                    continue
                seen_pairs.add(pair)
                na, nb = norm_cache[a], norm_cache[b]
                if not na or not nb:
                    continue
                score = fuzz.token_sort_ratio(na, nb)
                if score >= name_threshold:
                    edges.append((round(score, 1), a, b))

    # --- union-find to cluster connected accounts ---
    parent = list(range(len(accounts)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x, y):
        parent[find(x)] = find(y)

    for _, a, b in edges:
        union(a, b)

    # group indices by cluster root; only keep clusters with 2+ members
    from collections import defaultdict as _dd
    clusters = _dd(list)
    matched_idxs = set(idx for _, a, b in edges for idx in (a, b))
    for idx in matched_idxs:
        clusters[find(idx)].append(idx)

    # for each cluster, compute min/max score across its internal edges
    cluster_scores = _dd(list)
    for score, a, b in edges:
        cluster_scores[find(a)].append(score)

    candidates = []
    for root, idxs in clusters.items():
        idxs_sorted = sorted(idxs)
        scores = cluster_scores[root]
        row = {
            "min_score": min(scores),
            "max_score": max(scores),
            "group_size": len(idxs_sorted),
        }
        for letter_idx, idx in enumerate(idxs_sorted):
            suffix = chr(ord("a") + letter_idx)  # a, b, c, d, ...
            rec = accounts[idx]
            row[f"id_{suffix}"]      = rec["Id"]
            row[f"name_{suffix}"]    = rec.get("Name")
            row[f"street_{suffix}"]  = rec.get("BillingStreet")
            row[f"city_{suffix}"]    = rec.get("BillingCity")
            row[f"state_{suffix}"]   = rec.get("BillingState")
            row[f"zip_{suffix}"]     = rec.get("BillingPostalCode")
            row[f"created_{suffix}"] = rec.get("CreatedDate")
        candidates.append(row)

    candidates.sort(key=lambda c: c["max_score"], reverse=True)
    return candidates


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Find likely-duplicate Salesforce accounts.")
    ap.add_argument("--name-threshold", type=float, default=88.0,
                    help="Min fuzzy name score (0-100) to flag a pair. Default 88.")
    ap.add_argument("--require-address", dest="require_address", action="store_true",
                    default=True, help="Only flag pairs that share an address (default).")
    ap.add_argument("--no-require-address", dest="require_address", action="store_false",
                    help="Also block by name first-token for addressless accounts.")
    ap.add_argument("--out", default="account_dupe_candidates.csv",
                    help="Output CSV path. Default account_dupe_candidates.csv")
    args = ap.parse_args()

    instance_url = os.environ.get("SF_INSTANCE_URL", "").rstrip("/")
    token = os.environ.get("SF_ACCESS_TOKEN", "")
    if not instance_url or not token:
        try:
            result = subprocess.run(
                ["op", "item", "get", "Salesforce SF Credentials (jenna@getaddify.com)",
                 "--format", "json", "--reveal"],
                capture_output=True, text=True, check=True
            )
            item = json.loads(result.stdout)
            fields = {f["label"]: f.get("value", "") for f in item.get("fields", [])}
            instance_url = fields.get("instanceUrl", "").rstrip("/")
            token = fields.get("accessToken", "")
        except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError) as e:
            sys.exit(
                f"ERROR: could not load credentials from 1Password ({e}).\n"
                "Fallback: set SF_INSTANCE_URL and SF_ACCESS_TOKEN env vars, "
                "or run: sf org display --target-org <alias> --json"
            )
    if not instance_url or not token:
        sys.exit("ERROR: instanceUrl or accessToken missing from 1Password item.")

    print("Fetching all accounts...", file=sys.stderr)
    accounts = fetch_all_accounts(instance_url, token)
    print(f"Total accounts: {len(accounts)}", file=sys.stderr)

    print("Matching...", file=sys.stderr)
    candidates = find_candidates(accounts, args.name_threshold, args.require_address)
    print(f"Candidate duplicate groups: {len(candidates)}", file=sys.stderr)

    # Build column list dynamically from the widest group found
    max_size = max((c["group_size"] for c in candidates), default=0)
    per_account_fields = ["id", "name", "street", "city", "state", "zip", "created"]
    fixed_cols = ["min_score", "max_score", "group_size"]
    account_cols = [
        f"{field}_{chr(ord('a') + i)}"
        for i in range(max_size)
        for field in per_account_fields
    ]
    cols = fixed_cols + account_cols

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(candidates)
    print(f"Wrote {len(candidates)} groups to {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
