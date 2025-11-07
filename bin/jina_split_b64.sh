#!/usr/bin/env bash
set -euo pipefail

# Usage: bin/jina_split_b64.sh <INPUT_B64_FILE> <OUT_DIR> <NUM_SLICES>
# Splits a single-line base64 text file into NUM_SLICES approximately equal parts.
# It does NOT re-encode; it's safe to cut base64 text arbitrarily and concat back later.
# Output files: <OUT_DIR>/slice_000.b64 ... slice_XXX.b64
INPUT="${1:-}"
OUT_DIR="${2:-}"
NUM="${3:-50}"

if [[ -z "${INPUT}" || -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <INPUT_B64_FILE> <OUT_DIR> [NUM_SLICES=50]" >&2
  exit 2
fi

if [[ ! -f "${INPUT}" ]]; then
  echo "ERR: input file not found: ${INPUT}" >&2
  exit 3
fi

mkdir -p "${OUT_DIR}"

# Count bytes
TOTAL=$(wc -c < "${INPUT}")
if [[ "${TOTAL}" -eq 0 ]]; then
  echo "ERR: input is empty" >&2
  exit 4
fi

# Compute chunk size (ceil division)
# Avoid zero by ensuring at least 1 byte per chunk.
CHUNK=$(( (TOTAL + NUM - 1) / NUM ))
if [[ "${CHUNK}" -lt 1 ]]; then CHUNK=1; fi

# Split
tmp_prefix="${OUT_DIR}/.tmp_piece_"
rm -f ${tmp_prefix}*
split -b "${CHUNK}" -d -a 3 -- "${INPUT}" "${tmp_prefix}"

# Normalize names -> slice_000.b64 ...
i=0
for f in ${tmp_prefix}[0-9][0-9][0-9]*; do
  new="${OUT_DIR}/slice_$(printf '%03d' "${i}").b64"
  mv -f "${f}" "${new}"
  i=$((i+1))
done

COUNT=$((i))
if [[ "${COUNT}" -lt 1 ]]; then
  echo "ERR: split produced no slices" >&2
  exit 5
fi

# Verify concatenation hash equals original hash
orig_sha=$(sha256sum "${INPUT}" | awk '{print $1}')
cat "${OUT_DIR}"/slice_*.b64 > "${OUT_DIR}/.joined.tmp"
join_sha=$(sha256sum "${OUT_DIR}/.joined.tmp" | awk '{print $1}')
rm -f "${OUT_DIR}/.joined.tmp"

if [[ "${orig_sha}" != "${join_sha}" ]]; then
  echo "ERR: sha256 mismatch after split" >&2
  echo "orig=${orig_sha} join=${join_sha}" >&2
  exit 6
fi

echo "[split] ok: total_bytes=${TOTAL} slices=${COUNT} chunk_bytes=${CHUNK} sha256=${orig_sha}"
