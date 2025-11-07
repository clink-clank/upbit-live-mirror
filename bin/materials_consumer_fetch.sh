#!/usr/bin/env bash
# materials_consumer_fetch.sh
# Usage:
#   materials_consumer_fetch.sh [OUTPUT_JSON] [PIN_COMMIT]
# Default OUTPUT_JSON=LLM_MATERIALS.json, PIN_COMMIT=main
set -euo pipefail

OUT="${1:-LLM_MATERIALS.json}"
PIN="${2:-main}"

BASE="https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@${PIN}/web/docs"
SINGLE_URL="${BASE}/materials_current.b64gz.txt"
PARTLIST_URL="${BASE}/parts/materials.partlist.urls"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "[single] probing ${SINGLE_URL}"
code=$(curl -fsSIL -o /dev/null -w "%{http_code}" "$SINGLE_URL" || true)
if [ "$code" = "200" ]; then
  head4=$(curl -fsSL --range 0-3 "$SINGLE_URL" | tr -d '\n' || true)
  if [ "$head4" = "H4sI" ]; then
    echo "[single] ok; decoding to ${OUT}"
    curl -fsSL "$SINGLE_URL" | base64 -d | gunzip > "$OUT"
    jq -r '.version, .timestamps.utc, (.markets|length)' "$OUT" || true
    exit 0
  fi
fi

echo "[parts] falling back to parts from ${PARTLIST_URL}"
curl -fsSL "$PARTLIST_URL" -o "$tmpdir/urls.txt"
> "$tmpdir/joined.b64"
while IFS= read -r url; do
  [ -z "$url" ] && continue
  case "$url" in \#*) continue;; esac
  curl -fsSL "$url" >> "$tmpdir/joined.b64"
done < "$tmpdir/urls.txt"

# Quick sanity: expect 'H4sI' at start of the base64 payload
head -c 4 "$tmpdir/joined.b64" | tr -d '\n' | grep -q '^H4sI'
echo "[parts] decode+gunzip -> ${OUT}"
base64 -d < "$tmpdir/joined.b64" | gunzip > "$OUT"
jq -r '.version, .timestamps.utc, (.markets|length)' "$OUT" || true
