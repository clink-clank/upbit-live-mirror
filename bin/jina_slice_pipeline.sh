#!/usr/bin/env bash
set -euo pipefail

# Usage: bin/jina_slice_pipeline.sh <SRC_JSON> <OUT_DIR> [NUM_SLICES=50] [BRANCH=main]
# Orchestrates:
#  1) Ensure materials_current.b64gz.txt (from SRC_JSON if missing)
#  2) Split into slices
#  3) Build manifest (with Jina URLs)
#  4) Commit & push if changed
SRC_JSON="${1:-web/docs/LLM_MATERIALS.json}"
OUT_DIR="${2:-web/docs/jina_slices/materials_current}"
NUM="${3:-50}"
BRANCH="${4:-${GITHUB_REF_NAME:-main}}"

if [[ ! -f "${SRC_JSON}" ]]; then
  echo "[pipeline] SRC_JSON not found: ${SRC_JSON}" >&2
  echo "[pipeline] Trying to create from parts via bin/publish_llm_materials.sh (if available)..." >&2
  if [[ -x "bin/publish_llm_materials.sh" ]]; then
    # Try to build web/docs/LLM_MATERIALS.json and web/docs/materials_current.b64gz.txt
    bin/publish_llm_materials.sh || true
  fi
fi

mkdir -p "$(dirname -- web/docs/materials_current.b64gz.txt)"

# Rebuild b64gz from SRC_JSON if file missing
if [[ ! -f "web/docs/materials_current.b64gz.txt" ]]; then
  if [[ ! -f "${SRC_JSON}" ]]; then
    echo "ERR: cannot proceed; neither SRC_JSON nor b64gz exists" >&2
    exit 10
  fi
  echo "[pipeline] Build web/docs/materials_current.b64gz.txt from ${SRC_JSON}"
  gzip -c -9 "${SRC_JSON}" | base64 -w 0 > "web/docs/materials_current.b64gz.txt"
fi

# Split into NUM slices
bin/jina_split_b64.sh "web/docs/materials_current.b64gz.txt" "${OUT_DIR}" "${NUM}"

# Make manifest (auto-detect owner/repo from git)
bin/jina_make_manifest.sh "${SRC_JSON}" "${OUT_DIR}" "${BRANCH}"

# Git commit & push if changed
git add "${OUT_DIR}" "web/docs/materials_current.b64gz.txt"
if git diff --cached --quiet; then
  echo "[pipeline] no changes to commit"
  exit 0
fi

git config user.name "github-actions[bot]" || true
git config user.email "41898282+github-actions[bot]@users.noreply.github.com" || true

# Rebase in case of concurrent pushes
git pull --rebase --autostash origin "${BRANCH}" || true
git commit -m "jina: publish slices (N=${NUM})"
git push origin "${BRANCH}"

echo "[pipeline] done"
