#!/usr/bin/env bash
# Usage: repair_partlist_by_probe.sh <partlist.urls> <PIN_COMMIT> > materials.partlist.urls.fixed
# For each part index found in the list, probe a set of candidate URLs
# (materials_XXX.b64, materials_XXX.b64.b64, ...) at the given commit and
# pick the first that returns 200 and looks base64-valid (plus gzip magic on idx 0).
set -euo pipefail
LIST="${1:?partlist.urls}"
PIN="${2:?commit}"
# Derive repo path from first URL
FIRST="$(head -n1 "$LIST")"
REPO="$(echo "$FIRST" | sed -E 's#^https://cdn\.jsdelivr\.net/gh/([^@]+)@.*#\1#')"

# Collect unique part indices present in the list
readarray -t IDXES < <(grep -Eo 'materials_[0-9]{3}\.b64(\.b64)*' "$LIST" \
  | sed -E 's/.*materials_([0-9]{3}).*/\1/' | sort -u)

if [[ "${#IDXES[@]}" -eq 0 ]]; then
  echo "No part numbers found in $LIST" >&2
  exit 10
fi

for idx in "${IDXES[@]}"; do
  found=""
  for extra in $(seq 0 12); do
    dots=""
    if [[ "$extra" -gt 0 ]]; then
      dots="$(printf '.b64%.0s' $(seq 1 $extra))"
    fi
    url="https://cdn.jsdelivr.net/gh/${REPO}@${PIN}/web/docs/parts/materials_${idx}.b64${dots}"
    code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"
    if [[ "$code" != "200" ]]; then
      continue
    fi
    # fetch a small base64 sample (first 64 chars)
    sample="$(curl -fsSL -r 0-63 "$url" 2>/dev/null || true)"
    if [[ -z "$sample" ]]; then
      continue
    fi
    # base64 validity
    if ! printf '%s' "$sample" | base64 -d >/dev/null 2>&1; then
      continue
    fi
    # for idx 000 only, ensure gzip magic
    if [[ "$idx" == "000" ]]; then
      if ! printf '%s' "$sample" | base64 -d 2>/dev/null | head -c 2 | xxd -p -c2 | grep -qi '^1f8b$'; then
        continue
      fi
    fi
    found="$url"
    break
  done
  if [[ -z "$found" ]]; then
    echo "FAILED to find a good candidate for part $idx" >&2
    exit 11
  fi
  echo "$found"
done
