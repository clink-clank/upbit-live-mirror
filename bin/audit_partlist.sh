#!/usr/bin/env bash
# Usage: audit_partlist.sh <partlist.urls> [MAX_ROWS]
# Prints: idx http len magic url
set -euo pipefail
list="${1:?path to materials.partlist.urls}"
max="${2:-}"
echo "# idx http len magic url"

idx=0
while IFS= read -r url || [[ -n "${url:-}" ]]; do
  [[ -z "${url:-}" ]] && continue
  if [[ -n "$max" && "$idx" -ge "$max" ]]; then break; fi

  # HTTP code & length from HEAD (200 expected)
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"
  len="$(curl -fsSI "$url" 2>/dev/null | awk 'tolower($1)=="content-length:"{print $2; exit}' || true)"
  len="${len:-?}"

  # First 4 BYTES by Range (avoids curl 23 when piping to head)
  magic="$(curl -fsSL -r 0-3 "$url" 2>/dev/null || true)"
  magic="${magic:-----}"

  printf "%04d http=%s len=%s magic=%s %s\n" "$idx" "$code" "$len" "$magic" "$url"
  idx=$((idx+1))
done < "$list"
