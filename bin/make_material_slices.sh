#!/usr/bin/env bash
set -euo pipefail
# make_material_slices.sh
# Usage:
#   bin/make_material_slices.sh web/docs/LLM_MATERIALS.json
#
# Produces:
#   web/docs/materials_preview.json
#   web/docs/materials_status.json
#   web/docs/materials_index.json
#   web/docs/materials_by_market/<MARKET>.json  (per-market slice)
#
# Notes:
# - Requires: jq
# - Safe on re-run; only updates changed files.

SRC="${1:-web/docs/LLM_MATERIALS.json}"
[ -f "$SRC" ] || { echo "[ERR] source JSON not found: $SRC" >&2; exit 2; }

# derive target dirs
ROOT_DIR="$(cd "$(dirname "$SRC")" && pwd)"
OUT_DIR="$ROOT_DIR"
SLICE_DIR="$ROOT_DIR/materials_by_market"

mkdir -p "$SLICE_DIR"

# 1) Preview (tiny)
jq -c '{
  version: .version,
  timestamps: .timestamps,
  markets_count: (.markets | length),
  example: (.markets[0] // {})
}' "$SRC" | jq . > "$OUT_DIR/materials_preview.json"

# 2) Status (tiny)
# allow passing GITHUB_SHA from CI
GHSHA="${GITHUB_SHA:-unknown}"
jq -c --arg sha "$GHSHA" '{
  version: .version,
  timestamps: .timestamps,
  markets_count: (.markets | length),
  source_commit: $sha
}' "$SRC" | jq . > "$OUT_DIR/materials_status.json"

# Build meta once for slices
META="$(jq -c '{version, timestamps}' "$SRC")"

# 3) Index of market codes (sorted unique)
jq -r '[.markets[] | (.market // .symbol // .code // .id)] | map(tostring) | sort | unique' "$SRC" > "$OUT_DIR/materials_index.json"

# 4) Per-market slices
#    Each slice: { meta: {version, timestamps}, data: <market object> }
#    File name is the market code (slashes/spaces replaced with underscore).
#
#    We make this as stream to avoid high memory usage.
jq -c '.markets[]' "$SRC" | while IFS= read -r row; do
  code="$(jq -r '(.market // .symbol // .code // .id // "unknown")' <<<"$row" | tr '/ ' '_')"
  [ -n "$code" ] || continue
  printf '{"meta":%s,"data":%s}\n' "$META" "$row" | jq . > "$SLICE_DIR/${code}.json"
done

# 5) Summary
echo "[OK] slices written under: $SLICE_DIR"
echo "     preview: $OUT_DIR/materials_preview.json"
echo "     status : $OUT_DIR/materials_status.json"
echo "     index  : $OUT_DIR/materials_index.json"
