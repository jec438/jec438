#!/usr/bin/env bash
#
# dump_zendesk_orgs.sh
# --------------------
# Dumps every Zendesk organization (id, name, external_id) to a CSV using
# cursor-based pagination. This is the left side of the external_id backfill
# reconciliation join (see zendesk_backfill_external_id.py).
#
# Credentials are read from the environment so nothing secret lands in the repo:
#
#     export ZENDESK_SUBDOMAIN=your-subdomain
#     export ZENDESK_EMAIL=you@getaddify.com
#     export ZENDESK_API_TOKEN=your_api_token
#     ./dump_zendesk_orgs.sh [output.csv]
#
# Requires: curl, jq
set -euo pipefail

OUT="${1:-zendesk_orgs.csv}"

: "${ZENDESK_SUBDOMAIN:?Set ZENDESK_SUBDOMAIN}"
: "${ZENDESK_EMAIL:?Set ZENDESK_EMAIL}"
: "${ZENDESK_API_TOKEN:?Set ZENDESK_API_TOKEN}"

AUTH="${ZENDESK_EMAIL}/token:${ZENDESK_API_TOKEN}"
URL="https://${ZENDESK_SUBDOMAIN}.zendesk.com/api/v2/organizations.json?page[size]=100"

echo "id,name,external_id" > "$OUT"

while [ -n "$URL" ] && [ "$URL" != "null" ]; do
  # -g disables curl globbing so the [] in page[size]/page[after] aren't parsed.
  RESP=$(curl -sfg -u "$AUTH" "$URL")
  echo "$RESP" | jq -r '.organizations[] | [.id, .name, .external_id] | @csv' >> "$OUT"
  HAS_MORE=$(echo "$RESP" | jq -r '.meta.has_more')
  if [ "$HAS_MORE" = "true" ]; then
    URL=$(echo "$RESP" | jq -r '.links.next')
  else
    URL=""
  fi
done

# Subtract the header line from the count.
echo "Done: $(( $(wc -l < "$OUT") - 1 )) orgs → $OUT"
