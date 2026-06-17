#!/usr/bin/env python3
"""
merge_account_dupes.py
----------------------
Merges duplicate Salesforce Account groups identified by find_account_dupes.py.

Reads account_dupe_candidates.csv (or --csv path), picks the oldest record in
each group as the master, and calls the Salesforce SOAP merge() API.

SOAP limits:
  - Up to 200 MergeRequests per SOAP call.
  - Up to 3 records per MergeRequest (1 master + 2 to merge).
  - Groups larger than 3 are handled with successive merge requests, all
    targeting the same master record.

Credentials are loaded from 1Password ("Salesforce SF Credentials
(jenna@getaddify.com)"). Fallback: SF_INSTANCE_URL + SF_ACCESS_TOKEN env vars.

USAGE
-----
    # Dry run (default) — prints what would be merged, touches nothing
    python merge_account_dupes.py

    # Actually merge
    python merge_account_dupes.py --execute

    # Limit to top N groups (useful for a test run)
    python merge_account_dupes.py --execute --limit 10

    # Use a different CSV
    python merge_account_dupes.py --csv my_candidates.csv --execute
"""

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import textwrap
import time
from xml.etree import ElementTree as ET

import requests

SOAP_API_VERSION = "64.0"
SOAP_NS_ENV   = "http://schemas.xmlsoap.org/soap/envelope/"
SOAP_NS_SF    = "urn:partner.soap.sforce.com"
SOAP_NS_OBJ   = "urn:sobject.partner.soap.sforce.com"
MERGE_BATCH   = 200   # max MergeRequests per SOAP call
CHUNK_SIZE    = 2     # max recordToMergeIds per MergeRequest (master + 2 = 3 total)


# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------

def load_credentials():
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
                "Fallback: set SF_INSTANCE_URL and SF_ACCESS_TOKEN env vars."
            )
    if not instance_url or not token:
        sys.exit("ERROR: instanceUrl or accessToken missing.")
    return instance_url, token


# ---------------------------------------------------------------------------
# SOAP merge
# ---------------------------------------------------------------------------

def _merge_request_xml(master_id, record_ids_to_merge):
    """Build one <request> element: master + up to CHUNK_SIZE records."""
    lines = [
        "    <request>",
        "      <masterRecord>",
        f"        <obj:type>Account</obj:type>",
        f"        <obj:Id>{master_id}</obj:Id>",
        "      </masterRecord>",
    ]
    for rid in record_ids_to_merge:
        lines.append(f"      <recordToMergeIds>{rid}</recordToMergeIds>")
    lines.append("    </request>")
    return "\n".join(lines)


def soap_merge(instance_url, token, merge_requests, dry_run=True):
    """
    merge_requests: list of (master_id, [ids_to_merge])
    Batches into calls of up to MERGE_BATCH requests each.
    Returns list of result dicts.
    """
    if dry_run:
        for master_id, ids in merge_requests:
            print(f"  [DRY RUN] merge {ids} → master {master_id}")
        return []

    soap_url = f"{instance_url}/services/Soap/u/{SOAP_API_VERSION}"
    headers = {
        "Content-Type": "text/xml; charset=UTF-8",
        "SOAPAction": '""',
    }

    all_results = []
    for batch_start in range(0, len(merge_requests), MERGE_BATCH):
        batch = merge_requests[batch_start: batch_start + MERGE_BATCH]
        requests_xml = "\n".join(
            _merge_request_xml(master_id, ids) for master_id, ids in batch
        )
        envelope = textwrap.dedent(f"""\
            <?xml version="1.0" encoding="UTF-8"?>
            <soapenv:Envelope
                xmlns:soapenv="{SOAP_NS_ENV}"
                xmlns:sf="{SOAP_NS_SF}"
                xmlns:obj="{SOAP_NS_OBJ}">
              <soapenv:Header>
                <sf:SessionHeader>
                  <sf:sessionId>{token}</sf:sessionId>
                </sf:SessionHeader>
              </soapenv:Header>
              <soapenv:Body>
                <sf:merge>
            {requests_xml}
                </sf:merge>
              </soapenv:Body>
            </soapenv:Envelope>
        """)

        resp = requests.post(soap_url, data=envelope.encode("utf-8"), headers=headers)
        if resp.status_code == 401:
            sys.exit("ERROR 401: token expired. Refresh via `sf org display` and update 1Password.")
        resp.raise_for_status()

        root = ET.fromstring(resp.text)
        ns = {"sf": SOAP_NS_SF}
        for result in root.iter("{%s}result" % SOAP_NS_SF):
            success_el = result.find("{%s}success" % SOAP_NS_SF)
            success = success_el is not None and success_el.text == "true"
            merged_ids = [el.text for el in result.findall("{%s}mergedRecordIds" % SOAP_NS_SF)]
            updated_ids = [el.text for el in result.findall("{%s}updatedRelatedIds" % SOAP_NS_SF)]
            errors = [el.find("{%s}message" % SOAP_NS_SF).text
                      for el in result.findall("{%s}errors" % SOAP_NS_SF)
                      if el.find("{%s}message" % SOAP_NS_SF) is not None]
            all_results.append({
                "success": success,
                "mergedRecordIds": merged_ids,
                "updatedRelatedIds": updated_ids,
                "errors": errors,
            })

        time.sleep(0.1)

    return all_results


# ---------------------------------------------------------------------------
# Group → merge plan
# ---------------------------------------------------------------------------

def build_merge_plan(group):
    """
    group: list of dicts with keys id, name, created (ISO string)
    Returns: master_id, list of (master_id, [ids_to_merge]) SOAP requests
    All requests target the same master (oldest by CreatedDate).
    """
    sorted_group = sorted(group, key=lambda r: r["created"])
    master = sorted_group[0]
    to_merge = [r["id"] for r in sorted_group[1:]]

    soap_requests = []
    for i in range(0, len(to_merge), CHUNK_SIZE):
        chunk = to_merge[i: i + CHUNK_SIZE]
        soap_requests.append((master["id"], chunk))

    return master["id"], soap_requests


def load_groups(csv_path):
    groups = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            size = int(row["group_size"])
            members = []
            for i in range(size):
                s = chr(ord("a") + i)
                members.append({
                    "id":      row[f"id_{s}"],
                    "name":    row[f"name_{s}"],
                    "created": row[f"created_{s}"],
                })
            groups.append(members)
    return groups


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Merge duplicate Salesforce Account groups.")
    ap.add_argument("--csv", default="account_dupe_candidates.csv",
                    help="Input CSV from find_account_dupes.py")
    ap.add_argument("--execute", action="store_true",
                    help="Actually perform merges. Default is dry-run.")
    ap.add_argument("--limit", type=int, default=None,
                    help="Only process the first N groups (useful for test runs).")
    args = ap.parse_args()

    dry_run = not args.execute

    instance_url, token = load_credentials()

    groups = load_groups(args.csv)
    if args.limit:
        groups = groups[:args.limit]

    print(f"Groups to process: {len(groups)}", file=sys.stderr)
    if dry_run:
        print("DRY RUN — pass --execute to perform merges.", file=sys.stderr)

    all_soap_requests = []
    plan_map = []  # parallel list: (group_index, master_id, soap_request)

    for i, group in enumerate(groups):
        master_id, soap_requests = build_merge_plan(group)
        for req in soap_requests:
            all_soap_requests.append(req)
            plan_map.append((i, master_id, req))

    print(f"Total SOAP merge requests: {len(all_soap_requests)}", file=sys.stderr)

    if dry_run:
        for i, master_id, (_, ids) in plan_map:
            names = {m["id"]: m["name"] for m in groups[i]}
            id_labels = ", ".join(f"{rid} ({names.get(rid, '?')})" for rid in ids)
            print(f"  Group {i+1}: merge [{id_labels}] → master {master_id} ({names.get(master_id, '?')})")
        print("\nRe-run with --execute to perform merges.")
        return

    results = soap_merge(instance_url, token, all_soap_requests, dry_run=False)

    succeeded = sum(1 for r in results if r["success"])
    failed    = sum(1 for r in results if not r["success"])
    child_updates = sum(len(r["updatedRelatedIds"]) for r in results)

    print(f"\nResults: {succeeded} succeeded, {failed} failed, "
          f"{child_updates} child records re-parented.", file=sys.stderr)

    for idx, r in enumerate(results):
        if not r["success"]:
            _, master_id, (_, ids) = plan_map[idx]
            print(f"  FAILED — master {master_id}, merging {ids}: {r['errors']}", file=sys.stderr)


if __name__ == "__main__":
    main()
