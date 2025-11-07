#!/usr/bin/env bash
set -euo pipefail

# Usage: bin/jina_fetch_and_join.sh <JINA_MANIFEST_URL> [OUT=/tmp/jina_joined.b64] [MAX_SLICES=0(all)]
MURL="${1:-}"
OUT="${2:-/tmp/jina_joined.b64}"
MAX="${3:-0}"

if [[ -z "${MURL}" ]]; then
  echo "Usage: $0 <JINA_MANIFEST_URL> [OUT] [MAX_SLICES]" >&2
  exit 2
fi

# Jina sometimes wraps with header lines. Strip until 'Markdown Content:' and keep the rest.
manifest_json="$(curl -fsSL "${MURL}" | awk 'f{print} /^Markdown Content:/{f=1}' | sed '1d')"

if [[ -z "${manifest_json}" ]]; then
  echo "ERR: failed to fetch/parse manifest from Jina: ${MURL}" >&2
  exit 3
fi

# Extract slice_urls array
mapfile -t URLS < <(printf '%s' "${manifest_json}" | jq -r '.jina.slice_urls[]')
if [[ "${#URLS[@]}" -lt 1 ]]; then
  echo "ERR: no slice_urls in manifest" >&2
  exit 4
fi

: > "${OUT}"
count=0
for u in "${URLS[@]}"; do
  if [[ "${MAX}" -gt 0 && "${count}" -ge "${MAX}" ]]; then
    break
  fi
  curl -fsSL "${u}" | awk 'f{print} /^Markdown Content:/{f=1}' | sed '1d' >> "${OUT}"
  count=$((count+1))
done

echo "[join] wrote ${OUT} (slices=${count})"
