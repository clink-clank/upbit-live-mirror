#!/usr/bin/env bash
set -euo pipefail
URLS_FILE="${1:-web/docs/parts/materials.partlist.urls}"
NEW_SHA="${2:-}"
PART_SAMPLE="${PART_SAMPLE:-web/docs/parts/materials_000.b64}"

if [ ! -f "$URLS_FILE" ]; then
  echo "[fix][ERROR] urls file not found: $URLS_FILE" >&2
  exit 1
fi

if [ -z "$NEW_SHA" ]; then
  if git ls-files --error-unmatch "$PART_SAMPLE" >/dev/null 2>&1; then
    NEW_SHA="$(git log -1 --format=%H -- "$PART_SAMPLE")"
  else
    echo "[fix] 로컬에서 part 샘플을 찾지 못했습니다: $PART_SAMPLE" >&2
    echo "[fix] 수동으로 커밋 SHA를 넣어주세요. 예:" >&2
    echo "      bin/fix_partlist_commit.sh $URLS_FILE a145915c0ffee1234deadbeef5678abcd901234" >&2
    exit 2
  fi
fi

if ! [[ "$NEW_SHA" =~ ^[0-9a-f]{7,40}$ ]]; then
  echo "[fix][ERROR] invalid SHA: $NEW_SHA" >&2
  exit 3
fi

cp -f "$URLS_FILE" "${URLS_FILE}.bak"
sed -i -E "s/@[0-9a-f]{7,40}/@${NEW_SHA}/g" "$URLS_FILE"
echo "[fix] pinned commit in $URLS_FILE -> $NEW_SHA"

echo "[fix] git 커밋/푸시 (선택):"
echo "  git add $URLS_FILE && git commit -m "fix(parts): pin partlist to ${NEW_SHA}" && git push || true"
