#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-}"; REQ_PIN="${2:-}"
[ -n "$FILE" ] || { echo "usage: $0 <materials.partlist.urls> [pin_sha]" >&2; exit 2; }
[ -f "$FILE" ] || { echo "not found: $FILE" >&2; exit 2; }

pick_pin() {
  local req="$1"
  if [ -n "$req" ]; then
    echo "$req"; return 0
  fi

  # Try last commits that touched materials_000.b64
  for path in web/docs/parts/materials_000.b64 docs/parts/materials_000.b64; do
    if git rev-list -n 10 HEAD -- "$path" >/dev/null 2>&1; then
      for cand in $(git rev-list -n 10 HEAD -- "$path"); do
        if curl -sSI "https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@${cand}/web/docs/parts/materials_000.b64" \
          | awk 'toupper($1) ~ /^HTTP/ {c=$2} END{exit !(c==200)}'
        then
          echo "$cand"; return 0
        fi
      done
    fi
  done

  # Fallback: commit extracted from the first URL in file
  local first urlpin
  first="$(head -n1 "$FILE")"
  urlpin="$(echo "$first" | awk -F'@' '{if (NF>1){split($2,a,"/"); print a[1]}}')"
  echo "$urlpin"
}

PIN="$(pick_pin "${REQ_PIN:-}")"
[ -n "$PIN" ] || { echo "could not determine a valid pin commit" >&2; exit 1; }

# Quick CDN probe (warn only)
if ! curl -sSI "https://cdn.jsdelivr.net/gh/clink-clank/upbit-live-mirror@${PIN}/web/docs/parts/materials_000.b64" \
  | awk 'toupper($1) ~ /^HTTP/ {c=$2} END{exit !(c==200)}'; then
  echo "warning: CDN HEAD not 200 for materials_000.b64 at ${PIN} (continuing to pin)"
fi

cp -f "$FILE" "${FILE}.bak"
awk -v sha="$PIN" '{ gsub(/@[0-9a-f]{7,}\/web\/docs\/parts\//, "@" sha "/web/docs/parts/"); print }' "$FILE" > "${FILE}.tmp"
mv "${FILE}.tmp" "$FILE"
echo "[pin] updated $FILE -> $PIN"
