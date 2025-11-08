#!/usr/bin/env bash
# Usage: debug_parts.sh <partlist.urls>
# Prints HTTP status and first 4 chars (magic) for each part URL.
set -euo pipefail
LIST=${1:?Usage: $0 web/docs/parts/materials.partlist.urls}
i=0
while IFS= read -r url; do
  [[ -z "${url}" ]] && continue
  code=$(curl -sSI "$url" | sed -n '1p' | awk '{print $2}')
  # peek first 4 bytes (base64 letters)
  peek=$(curl -fsSL "$url" 2>/dev/null | head -c 4 | tr -d '\n' || true)
  if [[ "$i" == "0" ]]; then
    printf "%04d http=%s magic=%s %s\n" "$i" "${code:-?}" "${peek:-----}" "$url"
  else
    printf "%04d http=%s peek=%s %s\n" "$i" "${code:-?}" "${peek:-----}" "$url"
  fi
  i=$((i+1))
done < "$LIST"
