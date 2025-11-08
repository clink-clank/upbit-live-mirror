#!/usr/bin/env bash
# Usage: bisect_bad_part.sh <partlist.urls>
# Checks each part for base64 validity quickly; prints first index that fails.
# Note: parts after index 0 will not start with H4sI (that is NORMAL).
set -euo pipefail
list="${1:?partlist.urls}"

idx=0
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url:-}" ]] && continue
  # Fetch this part
  data="$(curl -fsSL "$url" | tr -d '\n' || true)"
  if [[ -z "$data" ]]; then
    echo "EMPTY at index $idx $url"
    exit 3
  fi
  # Base64 validity check
  if ! printf '%s' "$data" | base64 -d >/dev/null 2>&1; then
    echo "BAD-BASE64 at index $idx $url"
    exit 4
  fi
  # Extra check: for the very first part, ensure gzip magic 1f8b
  if [[ "$idx" -eq 0 ]]; then
    if ! printf '%s' "$data" | base64 -d 2>/dev/null | head -c 2 | xxd -p -c2 | grep -qi '^1f8b$'; then
      echo "BAD-GZIP-HEADER on first part (idx 0): $url"
      exit 5
    fi
  fi
  idx=$((idx+1))
done < "$list"

echo "All parts look base64-valid (and first part has correct gzip magic)."
