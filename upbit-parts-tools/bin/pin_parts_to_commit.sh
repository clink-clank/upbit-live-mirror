#!/usr/bin/env bash
# Usage: pin_parts_to_commit.sh <partlist.urls> [COMMIT]
# Pins all jsDelivr lines in the partlist to a commit that actually contains the parts.
set -euo pipefail
LIST=${1:?Usage: $0 web/docs/parts/materials.partlist.urls [COMMIT]}
COMMIT="${2:-}"

repo_url=$(git config --get remote.origin.url | sed 's#^git@github.com:#https://github.com/#')
repo_path=$(echo "$repo_url" | sed 's#https://github.com/##; s#\.git$##')

test_200() {
  local sha="$1"
  local path="$2"
  curl -sSI "https://cdn.jsdelivr.net/gh/${repo_path}@${sha}/${path}" | sed -n '1p' | grep -q "200"
}

if [[ -z "${COMMIT}" ]]; then
  echo "[pin] auto-searching commit that has web/docs/parts/materials_000.b64 on CDN..."
  # prefer commits that touched the parts path
  CANDS=$( (git log -n 80 --format='%H' -- web/docs/parts/materials_000.b64 2>/dev/null;             git log -n 80 --format='%H' -- docs/parts/materials_000.b64 2>/dev/null) | awk '!seen[$0]++')
  for c in $CANDS; do
    if test_200 "$c" "web/docs/parts/materials_000.b64"; then COMMIT="$c"; break; fi
  done
  if [[ -z "${COMMIT}" ]]; then
    # fallback: first add commit (diff-filter=A)
    c=$(git log --diff-filter=A -n 1 --format='%H' -- web/docs/parts/materials_000.b64 2>/dev/null || true)
    if [[ -n "$c" ]] && test_200 "$c" "web/docs/parts/materials_000.b64"; then COMMIT="$c"; fi
  fi
fi

if [[ -z "${COMMIT}" ]]; then
  echo "[pin] ERROR: could not find a commit with CDN-available parts (web/docs/parts/materials_000.b64)"
  exit 2
fi

# Rewrite all lines to the chosen commit (keep /web/docs/parts path)
tmp="${LIST}.tmp"
awk -v sha="$COMMIT" '{ gsub(/@[0-9a-f]{7,}\/web\/docs\/parts\//, "@" sha "/web/docs/parts/"); print }' "$LIST" > "$tmp"
mv "$tmp" "$LIST"

echo "[pin] pinned $LIST -> ${COMMIT}"
head -n1 "$LIST"
curl -I "$(head -n1 "$LIST")" | sed -n '1,8p' || true

echo "[pin] You may commit the change:"
echo "      git add $LIST && git commit -m \"chore: pin parts to ${COMMIT}\" && git push"
