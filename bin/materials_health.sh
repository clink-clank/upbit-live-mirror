#!/usr/bin/env bash
# bin/materials_health.sh
set -euo pipefail

REPO="${1:-clink-clank/upbit-live-mirror}"
BASE="https://cdn.jsdelivr.net/gh/$REPO@main/web/docs"

echo "== JSON summary =="
curl -fsSL "$BASE/LLM_MATERIALS.json" | jq -r '.version, .timestamps.utc, (.markets|length)'
echo "== B64+GZ magic =="
curl -fsSL "$BASE/materials_current.b64gz.txt" | head -c 4; echo
