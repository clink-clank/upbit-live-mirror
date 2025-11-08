#!/usr/bin/env bash
set -euo pipefail
IN="${1:-web/docs/LLM_MATERIALS.json}"
OUT="${2:-web/docs/probe/materials_probe_sample.json}"
LIMIT="${3:-12}"

mkdir -p "$(dirname "$OUT")"

# Robust jq: works whether .markets is an array or an object.
jq --argjson N "$LIMIT" '
  def markets_slice(n):
    if (.markets|type)=="array" then
      .markets[:n]
    elif (.markets|type)=="object" then
      (.markets
       | to_entries[:n]
       | map({key: (.key|tostring), value: .value}))
    else
      null
    end;
  {
    version,
    utc: .timestamps.utc,
    markets_sample: markets_slice($N)
  }
' "$IN" > "$OUT"

# Show quick summary
jq -r '.version, .utc, ( .markets_sample|if type=="array" then length else length end )' "$OUT" 2>/dev/null || true
