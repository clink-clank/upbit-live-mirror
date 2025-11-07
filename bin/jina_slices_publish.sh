#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bin/jina_slices_publish.sh [SRC_B64GZ_TXT] [TAG]
# Defaults:
#   SRC_B64GZ_TXT = web/docs/materials_current.b64gz.txt
#   TAG           = materials_current

SRC="${1:-web/docs/materials_current.b64gz.txt}"
TAG="${2:-materials_current}"
CHUNK_BYTES=81920  # 80KB

OUT_DIR="web/docs/jina_slices/${TAG}"
mkdir -p "$OUT_DIR"

# jq ensure
if ! command -v jq >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y jq
  else
    echo "jq not found. Please install jq." >&2
    exit 1
  fi
fi

if [ ! -f "$SRC" ]; then
  echo "[ERR] source file not found: $SRC" >&2
  exit 2
fi

SRC_BYTES=$(wc -c < "$SRC" | tr -d ' ')
SRC_SHA=$(sha256sum "$SRC" | awk '{print $1}')

# reset old slices
rm -f "${OUT_DIR}/slice_"*.b64 2>/dev/null || true

# slice 80KB parts
split -b "${CHUNK_BYTES}" -d -a 4 "$SRC" "${OUT_DIR}/slice_"
for f in "${OUT_DIR}"/slice_*; do mv "$f" "${f}.b64"; done

TMP=$(mktemp)
echo '[]' > "$TMP"

ORI=$(git config --get remote.origin.url | sed 's#.*github.com/##; s#\.git$##')
HEAD=$(git rev-parse HEAD)
RAW_BASE="https://raw.githubusercontent.com/${ORI}/refs/heads/main/${OUT_DIR}"
RAW_PIN="https://raw.githubusercontent.com/${ORI}/${HEAD}/${OUT_DIR}"

i=0
for f in $(ls -1 "${OUT_DIR}"/slice_*.b64 | sort); do
  SZ=$(wc -c < "$f" | tr -d ' ')
  SH=$(sha256sum "$f" | awk '{print $1}')
  BN=$(basename "$f")
  JINA_BASE="https://r.jina.ai/${RAW_BASE}/${BN}"
  JINA_PIN="https://r.jina.ai/${RAW_PIN}/${BN}"
  jq --arg name "$BN"      --arg sz "$SZ"      --arg sh "$SH"      --arg url_raw "${RAW_BASE}/${BN}"      --arg url_raw_pin "${RAW_PIN}/${BN}"      --arg url_jina "$JINA_BASE"      --arg url_jina_pin "$JINA_PIN"      --argjson idx "$i"      '. + [{index:$idx, name:$name, bytes:($sz|tonumber), sha256:$sh,
            urls:{raw:$url_raw, raw_pin:$url_raw_pin, jina:$url_jina, jina_pin:$url_jina_pin}}]'      "$TMP" > "${TMP}.next" && mv "${TMP}.next" "$TMP"
  i=$((i+1))
done

TOTAL=$(jq 'length' "$TMP")

MAN="${OUT_DIR}/manifest.json"
jq -n --arg tag "$TAG"       --arg src "$SRC"       --arg src_sha "$SRC_SHA"       --argjson src_bytes "$SRC_BYTES"       --argjson chunk_bytes "$CHUNK_BYTES"       --arg date_utc "$(date -u +%FT%TZ)"       --arg head "$HEAD"       --arg repo "$ORI"       --arg out_dir "$OUT_DIR"       --argjson total "$TOTAL"       --slurpfile slices "$TMP"       '{ tag:$tag, repo:$repo, commit:$head, src:$src,
         src_sha256:$src_sha, src_bytes:$src_bytes, chunk_bytes:$chunk_bytes,
         total_slices:$total, out_dir:$out_dir, generated_utc:$date_utc,
         slices:$slices[0] }' > "$MAN"

git add "$OUT_DIR"
git commit -m "docs: publish Jina slices ($TAG) and manifest.json" || true
git push || true

echo "== DONE =="
echo "Manifest (branch): https://r.jina.ai/https://raw.githubusercontent.com/${ORI}/refs/heads/main/${MAN}"
echo "Manifest (pinned): https://r.jina.ai/https://raw.githubusercontent.com/${ORI}/${HEAD}/${MAN}"
