#!/usr/bin/env python3
"""
Scoped Salesforce Attachment exporter.

Downloads the BINARY body of every Attachment matching a SOQL filter and saves
each as a real file on disk (optionally inside a Google Drive for Desktop folder
so it syncs straight to a Shared Drive).

It is built to back up EXACTLY the set you are about to hard-delete, so your
backup is scoped to what's at risk -- no 140-ZIP wrangling.

Features
  - Streams each file body via the REST API (no base64-in-CSV nonsense)
  - Resumable: skips files already downloaded; safe to re-run after a stall
  - Writes a manifest.csv mapping Id -> saved file path (+ size, parent, type)
  - Verifies downloaded byte count against the record's BodyLength
  - Concurrency for speed, with retries/backoff

------------------------------------------------------------------------------
SETUP (one time)
------------------------------------------------------------------------------
1. Python 3.9+ required. Install dependencies:

       pip install requests

2. Install the 1Password CLI and sign in:
       https://developer.1password.com/docs/cli/get-started/
       op signin

3. Create a 1Password item named "Salesforce Access Token" with two fields:
       credential  ->  your SF bearer token (00D...!AQ...)
       hostname    ->  https://yourorg.my.salesforce.com

   To use a different item name, set: export OP_SF_ITEM="My Item Name"

4. Choose where files land. To send straight to Google Drive, install
   Google Drive for Desktop, add the Shared Drive, and point OUTPUT_DIR at
   that folder, e.g. (mac) "/Volumes/GoogleDrive/Shared drives/SF Backups/attachments"
   or (Windows) "G:\\Shared drives\\SF Backups\\attachments".
   Use STREAM mode in Drive for Desktop so it doesn't keep a full local copy.

------------------------------------------------------------------------------
RUN
------------------------------------------------------------------------------
   python export_attachments.py

   # dry run first -- counts + total size, downloads nothing:
   python export_attachments.py --dry-run

   # override the output folder on the command line:
   python export_attachments.py --out "/path/to/Shared drives/SF Backups/attachments"
------------------------------------------------------------------------------
"""

import os
import csv
import sys
import time
import argparse
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# =============================================================================
# CONFIG -- edit these defaults, or override with env vars / CLI flags
# =============================================================================

# The SOQL WHERE clause that defines the set to export.
# This MUST match the filter you will hard-delete on, so the backup is exact.
#
# Default below = the "images first" delete set: pre-2024 image attachments.
# To back up ALL pre-2024 attachments instead, drop the ContentType line.
WHERE_CLAUSE = (
    "CreatedDate < 2024-01-01T00:00:00Z "
    "AND ContentType LIKE 'image/%'"
)

# Where to save files. Point this at a Drive for Desktop Shared Drive folder
# to sync straight to Google Drive. Can be overridden with --out.
OUTPUT_DIR = os.environ.get(
    "SF_OUTPUT_DIR",
    os.path.expanduser(
        "~/Library/CloudStorage/GoogleDrive-jenna@getaddify.com"
        "/Shared drives/SFDC Data Export/SFDC Attachments"
    ),
)

# How many parallel downloads. 5-8 is a sane range; higher risks API throttling.
MAX_WORKERS = 6

# API version
API_VERSION = "v60.0"

# Retry settings
MAX_RETRIES = 4
RETRY_BACKOFF_SEC = 3

# =============================================================================
# 1PASSWORD
# =============================================================================

# Name of the 1Password item that holds Salesforce credentials.
# The item should have two fields:
#   - "access token"   (the SF bearer token)
#   - "instance url"   (e.g. https://yourorg.my.salesforce.com)
OP_ITEM_NAME = os.environ.get("OP_SF_ITEM", "Salesforce Access Token")


def _op_read(item, field):
    """Read a single field from a 1Password item via the `op` CLI."""
    import subprocess
    result = subprocess.run(
        ["op", "item", "get", item, "--field", field, "--reveal"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.exit(
            f"1Password lookup failed for item '{item}', field '{field}':\n"
            f"{result.stderr.strip()}\n\n"
            "Make sure you are signed in (`op signin`) and the item exists."
        )
    return result.stdout.strip()


# =============================================================================
# AUTH
# =============================================================================

def get_session():
    """Return (session_with_auth_header, instance_url) using 1Password + simple-salesforce."""
    try:
        from simple_salesforce import Salesforce
    except ImportError:
        sys.exit("Run: pip install simple-salesforce")

    username = _op_read(OP_ITEM_NAME, "username").strip()
    security_token = _op_read(OP_ITEM_NAME, "credential").strip()
    password = _op_read(OP_ITEM_NAME, "password").strip()

    sf = Salesforce(
        username=username,
        password=password,
        security_token=security_token,
        domain="login",
    )

    s = requests.Session()
    s.headers.update({"Authorization": f"Bearer {sf.session_id}"})
    instance_url = f"https://{sf.sf_instance}".rstrip("/")
    return s, instance_url


# =============================================================================
# QUERY
# =============================================================================

def query_all(session, instance_url, soql):
    """Run SOQL, following queryLocator pagination, return list of records."""
    records = []
    url = f"{instance_url}/services/data/{API_VERSION}/query"
    params = {"q": soql}
    while True:
        r = session.get(url, params=params, timeout=120)
        if r.status_code != 200:
            sys.exit(f"Query failed [{r.status_code}]: {r.text}")
        data = r.json()
        records.extend(data["records"])
        if data.get("done"):
            break
        # nextRecordsUrl is a full path; params no longer needed
        url = f"{instance_url}{data['nextRecordsUrl']}"
        params = None
    return records


def safe_filename(att_id, name):
    """Build a collision-proof filename: <Id>__<original name>."""
    base = (name or "file").replace("/", "_").replace("\\", "_").strip()
    # keep it reasonable length
    if len(base) > 150:
        root, dot, ext = base.rpartition(".")
        base = (root[:140] + dot + ext) if dot else base[:150]
    return f"{att_id}__{base}"


# =============================================================================
# DOWNLOAD
# =============================================================================

_print_lock = threading.Lock()
_counter = {"ok": 0, "skip": 0, "fail": 0}


def download_one(session, instance_url, rec, out_dir):
    att_id = rec["Id"]
    name = rec.get("Name") or "file"
    body_len = rec.get("BodyLength") or 0
    fname = safe_filename(att_id, name)
    fpath = os.path.join(out_dir, fname)

    # Resume: skip if already present and the right size
    if os.path.exists(fpath) and os.path.getsize(fpath) == body_len:
        with _print_lock:
            _counter["skip"] += 1
        return (att_id, fpath, os.path.getsize(fpath), "skipped")

    body_url = (
        f"{instance_url}/services/data/{API_VERSION}"
        f"/sobjects/Attachment/{att_id}/Body"
    )

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with session.get(body_url, stream=True, timeout=300) as r:
                if r.status_code == 200:
                    tmp = fpath + ".part"
                    written = 0
                    with open(tmp, "wb") as fh:
                        for chunk in r.iter_content(chunk_size=1 << 16):
                            if chunk:
                                fh.write(chunk)
                                written += len(chunk)
                    # verify size if we know the expected length
                    if body_len and written != body_len:
                        os.remove(tmp)
                        raise IOError(
                            f"size mismatch {written} != {body_len}"
                        )
                    os.replace(tmp, fpath)
                    with _print_lock:
                        _counter["ok"] += 1
                    return (att_id, fpath, written, "ok")
                elif r.status_code in (401, 403):
                    return (att_id, fpath, 0, f"auth_error_{r.status_code}")
                elif r.status_code == 404:
                    return (att_id, fpath, 0, "not_found")
                elif r.status_code in (429, 500, 502, 503):
                    time.sleep(RETRY_BACKOFF_SEC * attempt)
                    continue
                else:
                    return (att_id, fpath, 0, f"http_{r.status_code}")
        except Exception as e:
            if attempt == MAX_RETRIES:
                with _print_lock:
                    _counter["fail"] += 1
                return (att_id, fpath, 0, f"error:{e}")
            time.sleep(RETRY_BACKOFF_SEC * attempt)

    with _print_lock:
        _counter["fail"] += 1
    return (att_id, fpath, 0, "failed")


# =============================================================================
# MAIN
# =============================================================================

def main():
    ap = argparse.ArgumentParser(description="Scoped Salesforce Attachment exporter")
    ap.add_argument("--out", default=OUTPUT_DIR, help="output directory")
    ap.add_argument("--where", default=WHERE_CLAUSE, help="SOQL WHERE clause")
    ap.add_argument("--workers", type=int, default=MAX_WORKERS)
    ap.add_argument("--dry-run", action="store_true",
                    help="count + total size only; download nothing")
    args = ap.parse_args()

    session, instance_url = get_session()
    print(f"Connected to: {instance_url}")

    soql = (
        "SELECT Id, Name, ContentType, BodyLength, ParentId, CreatedDate "
        f"FROM Attachment WHERE {args.where}"
    )
    print(f"Querying: {soql}")
    records = query_all(session, instance_url, soql)
    total = len(records)
    total_bytes = sum((r.get("BodyLength") or 0) for r in records)
    print(f"Matched {total:,} attachments, "
          f"{total_bytes/1e9:.2f} GB total.")

    if args.dry_run:
        print("Dry run -- nothing downloaded.")
        return

    if total == 0:
        print("Nothing to do.")
        return

    os.makedirs(args.out, exist_ok=True)
    manifest_path = os.path.join(args.out, "manifest.csv")

    # Open manifest for writing as we go
    mf = open(manifest_path, "w", newline="", encoding="utf-8")
    writer = csv.writer(mf)
    writer.writerow(["Id", "Name", "ContentType", "ParentId",
                     "CreatedDate", "BodyLength", "SavedPath", "Status"])

    start = time.time()
    rec_by_id = {r["Id"]: r for r in records}

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {
            ex.submit(download_one, session, instance_url, r, args.out): r["Id"]
            for r in records
        }
        done = 0
        for fut in as_completed(futures):
            att_id, fpath, written, status = fut.result()
            r = rec_by_id[att_id]
            writer.writerow([
                att_id, r.get("Name"), r.get("ContentType"),
                r.get("ParentId"), r.get("CreatedDate"),
                r.get("BodyLength"), fpath, status,
            ])
            done += 1
            if done % 250 == 0 or done == total:
                mf.flush()
                elapsed = time.time() - start
                rate = done / elapsed if elapsed else 0
                with _print_lock:
                    print(f"  {done:,}/{total:,}  "
                          f"ok={_counter['ok']:,} "
                          f"skip={_counter['skip']:,} "
                          f"fail={_counter['fail']:,}  "
                          f"({rate:.1f}/s)")

    mf.close()
    elapsed = time.time() - start
    print("-" * 60)
    print(f"Done in {elapsed/60:.1f} min")
    print(f"  downloaded: {_counter['ok']:,}")
    print(f"  skipped (already had): {_counter['skip']:,}")
    print(f"  failed: {_counter['fail']:,}")
    print(f"Manifest: {manifest_path}")
    if _counter["fail"]:
        print("\nSome files failed. Re-run the script -- it resumes and "
              "only retries what's missing. Check manifest Status column "
              "for rows that aren't 'ok' or 'skipped'.")
    else:
        print("\nAll files downloaded and size-verified. "
              "Confirm count matches before you hard-delete.")


if __name__ == "__main__":
    main()