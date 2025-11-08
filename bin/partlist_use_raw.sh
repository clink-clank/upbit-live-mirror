#!/usr/bin/env bash
# Usage: partlist_use_raw.sh <partlist.urls>
# Rewrites jsDelivr URLs to raw.githubusercontent.com as a fallback CDN.
set -euo pipefail
LIST=${1:?Usage: $0 web/docs/parts/materials.partlist.urls}
tmp="${LIST}.tmp"

sed -E 's#https://cdn.jsdelivr.net/gh/([^@]+)@([0-9a-f]{7,})/web/docs/parts/(materials_[0-9]{3}\.b64.*)#https://raw.githubusercontent.com/\1/\2/web/docs/parts/\3#g' "$LIST" > "$tmp"
mv "$tmp" "$LIST"

echo "[raw] rewritten to raw.githubusercontent.com"
head -n3 "$LIST"
