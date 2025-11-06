\
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "${1:-}" == "" || "${2:-}" == "" ]]; then
      echo "usage: $0 <input_json> <output_docs_dir> [basename=materials] [part_bytes=81920]" >&2
      exit 64
    fi

    INPUT_JSON="$1"              # e.g., data/payload.json
    OUT_DOCS_DIR="$2"            # e.g., web/docs
    BASENAME="${3:-materials}"
    PART_BYTES="${4:-81920}"

    OWNER="${OWNER:-clink-clank}"
    REPO="${REPO:-upbit-live-mirror}"
    REF="${REF:-main}"

    mkdir -p "${OUT_DOCS_DIR}/parts"

    # 1) gzip → base64 (한 줄)
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    JSON_GZ="${TMP_DIR}/${BASENAME}.json.gz"
    STREAM_B64="${TMP_DIR}/${BASENAME}.stream.b64"

    gzip -c "${INPUT_JSON}" > "${JSON_GZ}"
    base64 -w 0 "${JSON_GZ}" > "${STREAM_B64}"

    # 2) 싱글 파일 생성 (materials_current.b64gz.txt)
    SINGLE="${OUT_DOCS_DIR}/materials_current.b64gz.txt"
    cp -f "${STREAM_B64}" "${SINGLE}"

    # 3) 80KB 파츠 생성
    split -b "${PART_BYTES}" -d -a 3 --additional-suffix=.b64 "${STREAM_B64}" "${OUT_DOCS_DIR}/parts/${BASENAME}."

    # 4) 첫 파츠 프롤로그 "H4sI" 확인
    FIRST_PART="${OUT_DOCS_DIR}/parts/${BASENAME}.000.b64"
    HEAD4="$(head -c 4 "${FIRST_PART}")"
    if [[ "${HEAD4}" != "H4sI" ]]; then
      echo "경고: 첫 파츠 선두 4문자가 H4sI가 아닙니다: '${HEAD4}'" >&2
    fi

    # 5) partlist 생성 (jsDelivr @REF)
    PARTLIST="${OUT_DOCS_DIR}/parts/${BASENAME}.partlist.urls"
    : > "${PARTLIST}"
    for f in $(ls -1 "${OUT_DOCS_DIR}/parts/${BASENAME}."*.b64 | sort); do
      # repo 루트 기준 경로 계산
      REL_PATH="$(realpath --relative-to="$(git rev-parse --show-toplevel)" "${f}" 2>/dev/null || echo "${f}")"
      echo "https://cdn.jsdelivr.net/gh/${OWNER}/${REPO}@${REF}/${REL_PATH}" >> "${PARTLIST}"
    done

    echo "생성 완료:"
    echo " - 싱글: ${SINGLE}"
    echo " - 파츠: ${OUT_DOCS_DIR}/parts/${BASENAME}.[000..].b64"
    echo " - partlist: ${PARTLIST}"
