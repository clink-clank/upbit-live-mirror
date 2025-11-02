#!/usr/bin/env bash
set -euo pipefail

if [ ! -f LLM_MATERIALS.json ]; then
  echo "::notice::LLM_MATERIALS.json missing; skip shards"
  exit 0
fi

python3 scripts/split_llm_materials.py

git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

if ! git diff --quiet -- materials_10/; then
  git add materials_10/*.json || true
  git commit -m "chore: update materials_10 shards (auto)"
  git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
  git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
  echo "::notice title=Commit::Pushed materials_10 shards"
else
  echo "::notice title=Commit::No shard changes"
fi
