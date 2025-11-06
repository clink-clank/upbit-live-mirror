#!/usr/bin/env bash
set -euo pipefail

URLS_FILE="${1:-web/docs/parts/materials.partlist.urls}"

# Ensure helper scripts are executable
chmod +x bin/fetch_from_parts.sh bin/fetch_single_b64.sh

bin/fetch_from_parts.sh "$URLS_FILE" LLM_MATERIALS.from_parts.json
bin/fetch_single_b64.sh "$URLS_FILE" LLM_MATERIALS.single.json

if command -v sha256sum >/dev/null 2>&1; then
  H1=$(jq -cS . LLM_MATERIALS.from_parts.json | sha256sum | awk '{print $1}')
  H2=$(jq -cS . LLM_MATERIALS.single.json     | sha256sum | awk '{print $1}')
else
  # macOS fallback
  H1=$(jq -cS . LLM_MATERIALS.from_parts.json | shasum -a 256 | awk '{print $1}')
  H2=$(jq -cS . LLM_MATERIALS.single.json     | shasum -a 256 | awk '{print $1}')
fi

echo "[verify] from_parts sha256: $H1"
echo "[verify]     single sha256: $H2"

if [ "$H1" = "$H2" ]; then
  echo "[verify] ✅ match"
else
  echo "[verify] ❌ mismatch"; exit 1
fi
