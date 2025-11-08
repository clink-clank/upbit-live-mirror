#!/usr/bin/env bash
set -euo pipefail
# 1회 실행: 변경 감지 → 필요시 준비 → 다음 조각 하나 커밋/푸시
# 사용법: bin/slice50_push_once.sh <SRC_FILE> <OUT_DIR>
SRC_FILE="${1:?SRC_FILE required}"
OUT_DIR="${2:?OUT_DIR required}"
SLICE_COUNT=50

# git 사용자 정보 기본값
GIT_NAME=$(git config user.name || echo "")
GIT_EMAIL=$(git config user.email || echo "")
if [ -z "$GIT_NAME" ]; then git config user.name "automation-bot"; fi
if [ -z "$GIT_EMAIL" ]; then git config user.email "bot@example.invalid"; fi

# 상태 확인 및 변경 감지
NEED_PREP=0
if [ ! -f "${OUT_DIR}/.state.json" ]; then
  NEED_PREP=1
else
  CURR_SHA=$(sha256sum "${SRC_FILE}" | awk '{print $1}')
  STATE_SHA=$(jq -r '.src_sha256' < "${OUT_DIR}/.state.json" || echo "")
  if [ "${CURR_SHA}" != "${STATE_SHA}" ]; then
    NEED_PREP=1
  fi
fi

if [ "$NEED_PREP" -eq 1 ]; then
  "$(dirname "$0")/slice50_prepare.sh" "${SRC_FILE}" "${OUT_DIR}"
  echo "[push-once] prepared slices for new source"
fi

NEXT=$(jq -r '.next_index' < "${OUT_DIR}/.state.json")
if [ "${NEXT}" = "null" ] || [ -z "${NEXT}" ]; then NEXT=0; fi

if [ "${NEXT}" -ge "${SLICE_COUNT}" ]; then
  echo "[push-once] all slices already pushed (next_index=${NEXT})"
  exit 0
fi

# 커밋/푸시: manifest (처음에만) + 해당 slice
MANIFEST=$(jq -r '.manifest' < "${OUT_DIR}/.state.json")
SRC_SHA=$(jq -r '.src_sha256' < "${OUT_DIR}/.state.json")
SLICE_FILE=$(printf "%s/slices/part_%03d.part" "${OUT_DIR}" "${NEXT}")

# manifest 미커밋시 포함시키기(간단히 항상 add)
git add "${MANIFEST}" || true

# slice add
if [ ! -f "${SLICE_FILE}" ]; then
  echo "[push-once] missing slice file: ${SLICE_FILE}" >&2
  exit 2
fi
git add "${SLICE_FILE}"

# 커밋 메시지
BRANCH=$(git rev-parse --abbrev-ref HEAD || echo main)
SHORT_SHA=$(echo "${SRC_SHA}" | cut -c1-7)
git commit -m "docs(jina-slices): upload slice $(printf "%02d" $((NEXT+1)))/${SLICE_COUNT} for ${SHORT_SHA}" || true
git push origin "${BRANCH}"

# next_index 증가
NEW_NEXT=$((NEXT+1))
tmp="${OUT_DIR}/.state.json.tmp"
jq --argjson n "${NEW_NEXT}" '.next_index=$n | .updated_utc=now|strftime("%Y-%m-%dT%H:%M:%SZ")'       "${OUT_DIR}/.state.json" > "${tmp}"
mv "${tmp}" "${OUT_DIR}/.state.json"

echo "[push-once] pushed slice ${NEXT}/${SLICE_COUNT} -> next_index=${NEW_NEXT}"
