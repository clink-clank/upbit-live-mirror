#!/usr/bin/env bash
# Reassemble LLM_MATERIALS.json from 80KB parts (b64+gz) listed in materials.partlist.urls
set -euo pipefail

if ! command -v jq >/dev/null; then
  echo "jq not found; please install jq" >&2
  exit 1
fi

PARTLIST_URLS="${1:-}"
WORKDIR="${2:-./_materials_dl}"
OUT_JSON="${3:-LLM_MATERIALS.json}"

if [ -z "${PARTLIST_URLS}" ]; then
  echo "Usage: $0 <URL-to-materials.partlist.urls> [workdir] [out_json]" >&2
  echo "Example:" >&2
  echo "  $0 https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@<COMMIT>/web/docs/parts/materials.partlist.urls" >&2
  exit 2
fi

mkdir -p "$WORKDIR"
curl -fsSL "$PARTLIST_URLS" -o "$WORKDIR/partlist.urls"
echo "[+] Using partlist: $PARTLIST_URLS"
echo "[+] Downloading parts..."

: > "$WORKDIR/materials.b64"
idx=0
while IFS= read -r url; do
  [ -n "$url" ] || continue
  idx=$((idx+1))
  printf "  - [%03d] %s\n" "$idx" "$url"
  curl -fsSL "$url" >> "$WORKDIR/materials.b64"
done < "$WORKDIR/partlist.urls"

first4=$(head -c 4 "$WORKDIR/materials.b64" || true)
if [ "$first4" != "H4sI" ]; then
  echo "[!] Warning: unexpected prefix '$first4' (expected 'H4sI')" >&2
fi

base64 -d "$WORKDIR/materials.b64" | gzip -d > "$OUT_JSON"
echo "[+] Wrote $OUT_JSON"

jq -e 'type=="object" and .version=="LLM_MATERIALS_V1" and (.markets|type=="array" and length>0)' "$OUT_JSON" >/dev/null
echo "[+] Valid JSON shape"
echo "    version:  $(jq -r .version "$OUT_JSON")"
echo "    utc:      $(jq -r .timestamps.utc "$OUT_JSON")"
echo "    markets:  $(jq -r '.markets|length' "$OUT_JSON")"
