#!/usr/bin/env bash
# Fetch single b64+gz file and restore LLM_MATERIALS.json
set -euo pipefail

if ! command -v jq >/dev/null; then
  echo "jq not found; please install jq" >&2
  exit 1
fi

SINGLE_URL="${1:-}"
OUT_JSON="${2:-LLM_MATERIALS.json}"

if [ -z "${SINGLE_URL}" ]; then
  echo "Usage: $0 <URL-to-materials_current.b64gz.txt> [out_json]" >&2
  echo "Example:" >&2
  echo "  $0 https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@<COMMIT>/web/docs/materials_current.b64gz.txt" >&2
  exit 2
fi

tmp="materials_current.b64gz.txt"
curl -fsSL "$SINGLE_URL" -o "$tmp"
head -c 4 "$tmp" | sed -e 's/^/[prefix] /'
base64 -d "$tmp" | gzip -d > "$OUT_JSON"
rm -f "$tmp"

jq -e 'type=="object" and .version=="LLM_MATERIALS_V1" and (.markets|type=="array" and length>0)' "$OUT_JSON" >/dev/null
echo "[+] Restored $OUT_JSON"
jq -r '.version, .timestamps.utc, (.markets|length)' "$OUT_JSON"
