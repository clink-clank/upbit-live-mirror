#!/usr/bin/env bash
# Ensure shards are regenerated & committed whenever LLM_MATERIALS.json changes.
set -euo pipefail

# Fail early if jq or python3 not available
command -v python3 >/dev/null || { echo "::error::python3 not found"; exit 2; }

if [ ! -f LLM_MATERIALS.json ]; then
  echo "::notice::LLM_MATERIALS.json missing; skip shards"
  exit 0
fi

# Generate shards
python3 scripts/split_llm_materials.py

# Commit shards if changed
git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if ! git diff --quiet -- materials_10/; then
  git add materials_10/*.json || true
  git commit -m "chore: update materials_10 shards (auto)"
  # Non-fast-forward safe push
  git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
  git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
  echo "::notice title=Commit::Pushed materials_10 shards"
else
  echo "::notice title=Commit::No shard changes"
fi
