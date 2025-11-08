#!/usr/bin/env bash
# slice50_prepare.sh (fixed)
# Usage: slice50_prepare.sh <INPUT_FILE> <OUT_DIR> [NUM_SLICES=50]
# - Splits INPUT_FILE into NUM_SLICES chunks and writes manifest.json in OUT_DIR
# - Designed for GitHub raw + proxy-friendly consumption (Jina, jsDelivr, etc.)
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[ERR] jq is required. Install: sudo apt-get update -y && sudo apt-get install -y jq" >&2
  exit 1
fi

INPUT_FILE="${1:-}"
OUT_DIR="${2:-}"
NUM_SLICES="${3:-50}"

if [[ -z "${INPUT_FILE}" || -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <INPUT_FILE> <OUT_DIR> [NUM_SLICES=50]" >&2
  exit 2
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "[ERR] INPUT_FILE not found: ${INPUT_FILE}" >&2
  exit 3
fi

mkdir -p "${OUT_DIR}"
# Clean old slices if any
rm -f "${OUT_DIR}"/slice_*.bin || true

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "[WARN] Not a git repo; base_raw URLs will be generic." >&2
fi

# Compute source metadata
SRC_SIZE=$(stat -c%s "${INPUT_FILE}")
SRC_SHA=$(sha256sum "${INPUT_FILE}" | awk '{print $1}')

# Compute chunk size for NUM_SLICES (ceil division)
if [[ "${NUM_SLICES}" -le 0 ]]; then
  echo "[ERR] NUM_SLICES must be > 0" >&2
  exit 4
fi
CHUNK_SIZE=$(( (SRC_SIZE + NUM_SLICES - 1) / NUM_SLICES ))
if [[ "${CHUNK_SIZE}" -le 0 ]]; then
  CHUNK_SIZE="${SRC_SIZE}"
fi

echo "[INFO] Source size=${SRC_SIZE} bytes, sha256=${SRC_SHA}"
echo "[INFO] Splitting into ${NUM_SLICES} slices of ~${CHUNK_SIZE} bytes"

# Split into slices with numeric suffix length 3 => 000..049
TMP_PREFIX="${OUT_DIR}/slice_"
split -b "${CHUNK_SIZE}" -d -a 3 -- "${INPUT_FILE}" "${TMP_PREFIX}"

# Ensure .bin extension for all slices
for f in "${OUT_DIR}"/slice_*; do
  [[ -e "$f" ]] || continue
  if [[ "${f}" != *.bin ]]; then
    mv -f -- "$f" "${f}.bin"
  fi
done

# Build slices metadata
SLICES_JSONL="${OUT_DIR}/.slices.jsonl"
rm -f "${SLICES_JSONL}"
COUNT=0
for f in "${OUT_DIR}"/slice_*.bin; do
  [[ -e "$f" ]] || continue
  sz=$(stat -c%s "$f")
  sh=$(sha256sum "$f" | awk '{print $1}')
  nm=$(basename "$f")
  printf '{"name":%s,"size":%d,"sha256":%s}\n' \
    "$(printf '%s' "$nm" | jq -Rsa . | jq -r '.')" \
    "$sz" \
    "$(printf '%s' "$sh" | jq -Rsa . | jq -r '.')" >> "${SLICES_JSONL}"
  COUNT=$((COUNT+1))
done

if [[ "${COUNT}" -eq 0 ]]; then
  echo "[ERR] No slices produced. Aborting." >&2
  exit 5
fi

# Derive owner/repo and ref (commit)
ORIGIN_URL="$(git config --get remote.origin.url 2>/dev/null || echo "")"
OWNER_REPO=""
if [[ -n "${ORIGIN_URL}" ]]; then
  # Convert SSH/HTTPS to owner/repo
  OWNER_REPO="$(printf '%s' "${ORIGIN_URL}" | sed -E 's#.*github.com[:/]+([^/]+/[^/.]+)(\.git)?#\1#')"
fi
REF="$(git rev-parse HEAD 2>/dev/null || echo "main")"

# Compute path relative to repo root for OUT_DIR (for base_raw)
REL_OUT="${OUT_DIR}"
if [[ -n "${REPO_ROOT}" ]]; then
  case "${OUT_DIR}" in
    "${REPO_ROOT}"/*) REL_OUT="${OUT_DIR#${REPO_ROOT}/}" ;;
    *) REL_OUT="${OUT_DIR}" ;;
  esac
fi

BASE_RAW=""
if [[ -n "${OWNER_REPO}" ]]; then
  BASE_RAW="https://raw.githubusercontent.com/${OWNER_REPO}/${REF}/${REL_OUT}/"
else
  # If we cannot detect, leave empty; consumer can override
  BASE_RAW=""
fi

# Assemble manifest.json using jq for correctness
MANIFEST_TMP="${OUT_DIR}/manifest.json.tmp"
jq -n \
  --arg schema "JINA_SLICES_V1" \
  --arg input "${INPUT_FILE}" \
  --arg rel_out "${REL_OUT}" \
  --arg owner_repo "${OWNER_REPO}" \
  --arg ref "${REF}" \
  --arg base_raw "${BASE_RAW}" \
  --arg src_sha "${SRC_SHA}" \
  --argjson src_size "${SRC_SIZE}" \
  --slurpfile slices <(jq -s '.' "${SLICES_JSONL}") '
  {
    schema: $schema,
    source: { path: $input, sha256: $src_sha, size: $src_size },
    repo: { owner_repo: $owner_repo, ref: $ref },
    out_dir: $rel_out,
    base_raw: $base_raw,
    slices: $slices[0]
  }' > "${MANIFEST_TMP}"

mv -f "${MANIFEST_TMP}" "${OUT_DIR}/manifest.json"
rm -f "${SLICES_JSONL}"

echo "[OK] Wrote manifest: ${OUT_DIR}/manifest.json"
echo "[OK] Total slices: ${COUNT}"
