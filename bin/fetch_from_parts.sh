#!/usr/bin/env bash
set -euo pipefail

URLS_FILE="${1:-web/docs/parts/materials.partlist.urls}"
OUT_JSON="${2:-LLM_MATERIALS.from_parts.json}"

tmp_b64="$(mktemp)"
trap 'rm -f "$tmp_b64"' EXIT

echo "[parts] reading urls from: $URLS_FILE"
while IFS= read -r url; do
  [ -z "$url" ] && continue
  curl -fsSL "$url" >> "$tmp_b64"
done < "$URLS_FILE"

echo -n "[parts] head magic: "; head -c 4 "$tmp_b64"; echo
base64 -d < "$tmp_b64" | gunzip > "$OUT_JSON"

echo "[parts] wrote $OUT_JSON ($(wc -c < "$OUT_JSON") bytes)"
jq -e 'type=="object" and .version=="LLM_MATERIALS_V1" and (.markets|type=="array" and length>0)' "$OUT_JSON" >/dev/null
echo "[parts] ok: version=$(jq -r .version "$OUT_JSON"), utc=$(jq -r .timestamps.utc "$OUT_JSON"), markets=$(jq -r ".markets|length" "$OUT_JSON")"
