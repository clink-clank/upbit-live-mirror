#!/usr/bin/env bash
set -euo pipefail

IN="${1:-web/docs/LLM_MATERIALS.json}"
OUT="${2:-web/docs/probe/materials_probe_sample.json}"
LIMIT="${3:-12}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

chmod +x bin/make_probe_from_json.sh || true
bin/make_probe_from_json.sh "$IN" "$OUT" "$LIMIT"

# Ensure viewer exists (created by drop-in)
if [ -f web/docs/probe/index.html ]; then
  git add web/docs/probe/index.html
fi

git add "$OUT"
git commit -m "docs: publish probe sample ($LIMIT)" || true
git push || true

echo "== probe published =="
echo "JSON: web/docs/probe/materials_probe_sample.json"
