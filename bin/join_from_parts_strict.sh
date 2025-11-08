#!/usr/bin/env bash
# Usage: join_from_parts_strict.sh <partlist.urls> <out.json>
# Joins the listed base64 parts exactly-as-listed, decodes+gunzips into JSON,
# and prints a short summary using jq.
set -euo pipefail
list="${1:?partlist.urls}"
out="${2:?out.json}"

tmp_b64="$(mktemp)"
trap 'rm -f "$tmp_b64"' EXIT

# Join exactly as listed
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url:-}" ]] && continue
  curl -fsSL "$url" >> "$tmp_b64"
done < "$list"

# Decode → GZip → JSON
# (If anything is wrong this will exit non-zero)
base64 -d "$tmp_b64" | gunzip -c > "$out"

# Quick summary (if jq exists)
if command -v jq >/dev/null 2>&1; then
  echo "== summary =="
  jq -r '.version, .timestamps.utc, (.markets|length)' "$out"
fi
