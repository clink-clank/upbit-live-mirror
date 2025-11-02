#!/usr/bin/env bash
set -Eeuo pipefail
REPO_DIR="${1:-.}"
N="${2:-10}"
OUT_DIR="${3:-}"

cd "${REPO_DIR}"

SRC="LLM_MATERIALS.json"
if [ ! -f "${SRC}" ]; then
  echo "::warning::missing ${SRC}"
  exit 0
fi

COUNT="$(jq -r '(.markets | length) // 0' "${SRC}")"
if [ -z "${COUNT}" ] || [ "${COUNT}" -eq 0 ] 2>/dev/null; then
  echo "::notice title=Reshard::No markets in ${SRC}"
  exit 0
fi

if [ -z "${OUT_DIR:-}" ]; then
  OUT_DIR="materials_${N}"
fi

mkdir -p "${OUT_DIR}"

WIDTH=${#N}
q=$(( COUNT / N ))
r=$(( COUNT % N ))
start=0

i=0
while [ ${i} -lt "${N}" ]; do
  size=${q}
  if [ ${i} -lt ${r} ]; then size=$((size+1)); fi
  if [ ${size} -le 0 ]; then
    i=$((i+1))
    continue
  fi
  idx="$(printf "%0${WIDTH}d" "${i}")"
  out="${OUT_DIR}/LLM_MATERIALS_part_${idx}.json"
  jq \
    --argjson s "${start}" \
    --argjson size "${size}" \
    '
    .markets = (.markets[$s:($s+$size)]) 
    | .meta = (.meta // {})
    | .meta.params = (.meta.params // {})
    | .meta.params.markets = (.markets | length)
    ' "${SRC}" > "${out}"
  start=$((start+size))
  i=$((i+1))
done

# List file (optional)
ls -1 "${OUT_DIR}"/LLM_MATERIALS_part_*.json 2>/dev/null | sort > "${OUT_DIR}/list.txt" || true
