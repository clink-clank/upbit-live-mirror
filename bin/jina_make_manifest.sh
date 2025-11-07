#!/usr/bin/env bash
set -euo pipefail

# Usage: bin/jina_make_manifest.sh <SRC_JSON> <OUT_DIR> [BRANCH=main]
# Produces <OUT_DIR>/manifest.json with:
#  - source meta from SRC_JSON (version, utc, markets len)
#  - slices: relative paths to repo root
#  - base_raw: <owner>/<repo>/refs/heads/<branch>
#  - jina.slice_urls: full r.jina.ai URLs for each slice
SRC_JSON="${1:-}"
OUT_DIR="${2:-}"
BRANCH="${3:-main}"

if [[ -z "${SRC_JSON}" || -z "${OUT_DIR}" ]]; then
  echo "Usage: $0 <SRC_JSON> <OUT_DIR> [BRANCH=main]" >&2
  exit 2
fi

if [[ ! -f "${SRC_JSON}" ]]; then
  echo "ERR: SRC_JSON not found: ${SRC_JSON}" >&2
  exit 3
fi

if [[ ! -d "${OUT_DIR}" ]]; then
  echo "ERR: OUT_DIR not found: ${OUT_DIR}" >&2
  exit 4
fi

# Derive owner/repo from git remote
remote_url="$(git config --get remote.origin.url || true)"
if [[ -z "${remote_url}" ]]; then
  echo "ERR: cannot detect git remote.origin.url" >&2
  exit 5
fi

# Normalize to https://github.com/owner/repo(.git)?
norm="${remote_url}"
norm="${norm%.git}"
owner_repo=""
if [[ "${norm}" =~ github.com[:/]+([^/]+)/([^/]+)$ ]]; then
  owner_repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
else
  echo "ERR: cannot parse owner/repo from ${remote_url}" >&2
  exit 6
fi

# Gather slices (paths relative to repo root). We assume OUT_DIR is relative path from repo root.
mapfile -t SLICES < <( (cd "$(git rev-parse --show-toplevel)"; ls -1 "${OUT_DIR}"/slice_*.b64) | sed 's|^\./||' )

if [[ "${#SLICES[@]}" -lt 1 ]]; then
  echo "ERR: no slices found under ${OUT_DIR}" >&2
  exit 7
fi

version="$(jq -r '.version' "${SRC_JSON}")"
utc="$(jq -r '.timestamps.utc' "${SRC_JSON}")"
markets_len="$(jq -r '.markets|length' "${SRC_JSON}")"

base_ref="refs/heads/${BRANCH}"
base_raw="${owner_repo}/${base_ref}"
prefix="${OUT_DIR}"

# Compute sha256 of whole b64 and joined slices if file exists alongside slices
b64_path="web/docs/materials_current.b64gz.txt"
sha_b64=""
if [[ -f "${b64_path}" ]]; then
  sha_b64="$(sha256sum "${b64_path}" | awk '{print $1}')"
fi
sha_join=$(cat "${OUT_DIR}"/slice_*.b64 | sha256sum | awk '{print $1}')

# Build manifest with jq
jq -n \
  --arg ver "${version}" \
  --arg src_utc "${utc}" \
  --argjson markets "${markets_len}" \
  --arg base_raw "${base_raw}" \
  --arg prefix "${prefix}" \
  --arg sha_b64 "${sha_b64}" \
  --arg sha_join "${sha_join}" \
  --argjson slices "$(printf '%s\n' "${SLICES[@]}" | jq -R . | jq -s .)" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '
  {
    version: "LLM_MATERIALS_JINA_V1",
    created_utc: $created,
    source: { dataset_version: $ver, utc: $src_utc, markets: $markets },
    base_raw: $base_raw,
    prefix: $prefix,
    slices: $slices,
    integrity: { sha256_b64: $sha_b64, sha256_joined_slices: $sha_join },
    jina: {
      manifest_url: ("https://r.jina.ai/https://raw.githubusercontent.com/" + $base_raw + "/" + $prefix + "/manifest.json"),
      slice_urls: ($slices | map("https://r.jina.ai/https://raw.githubusercontent.com/" + $base_raw + "/" + .))
    }
  }' > "${OUT_DIR}/manifest.json"

echo "[manifest] wrote ${OUT_DIR}/manifest.json (slices=${#SLICES[@]})"
