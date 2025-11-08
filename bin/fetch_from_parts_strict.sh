#!/usr/bin/env bash
# Usage: fetch_from_parts_strict.sh <partlist.urls> <out.json>
# Downloads all .b64 parts, concatenates, base64-decodes, gunzips, and validates JSON schema.
set -euo pipefail
LIST=${1:?Usage: $0 web/docs/parts/materials.partlist.urls <out.json>}
OUT=${2:?Usage: $0 web/docs/parts/materials.partlist.urls <out.json>}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  curl -fsSL "$url" >> "$work/all.b64"
done < "$LIST"

# Quick magic check
magic=$(head -c 4 "$work/all.b64" | tr -d '\n')
if [[ "$magic" != "H4sI" ]]; then
  echo "[strict] ERROR: bad magic at start of concatenated base64 (got '$magic', want 'H4sI')" >&2
  exit 3
fi

# Decode+gunzip
base64 -d "$work/all.b64" | gunzip > "$OUT"

# Validate minimal schema
if ! command -v jq >/dev/null 2>&1; then
  echo "[strict] WARN: jq not found; skipping schema validation"
  exit 0
fi

jq -e 'type=="object" and .version=="LLM_MATERIALS_V1" and (.markets|type=="array" and length>0)' "$OUT" >/dev/null
echo "[strict] OK: version=$(jq -r .version "$OUT"), utc=$(jq -r .timestamps.utc "$OUT"), markets=$(jq -r ".markets|length" "$OUT")"
