#!/usr/bin/env bash
set -euo pipefail

# 1) SHA 자동 추출(파츠 URL 1줄에서 커밋 핀 가져옴)
URLS_FILE="${1:-web/docs/parts/materials.partlist.urls}"
OUT_JSON="${2:-LLM_MATERIALS.single.json}"

SHA="$(head -n1 "$URLS_FILE" | sed -E 's#.*@([0-9a-f]{7,40}).*#\1#')"
SINGLE_URL="https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@${SHA}/web/docs/materials_current.b64gz.txt"

echo "[single] commit: $SHA"
echo "[single] url: $SINGLE_URL"

tmp_b64="$(mktemp)"
trap 'rm -f "$tmp_b64"' EXIT

curl -fsSL "$SINGLE_URL" -o "$tmp_b64"
echo -n "[single] head magic: "; head -c 4 "$tmp_b64"; echo
base64 -d < "$tmp_b64" | gunzip > "$OUT_JSON"

echo "[single] wrote $OUT_JSON ($(wc -c < "$OUT_JSON") bytes)"
jq -e 'type=="object" and .version=="LLM_MATERIALS_V1" and (.markets|type=="array" and length>0)' "$OUT_JSON" >/dev/null
echo "[single] ok: version=$(jq -r .version "$OUT_JSON"), utc=$(jq -r .timestamps.utc "$OUT_JSON"), markets=$(jq -r ".markets|length" "$OUT_JSON")"
