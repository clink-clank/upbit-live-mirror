\
    #!/usr/bin/env bash
    set -euo pipefail

    PARTS_DIR="${1:-}"
    if [[ -z "${PARTS_DIR}" ]]; then
      echo "usage: $0 <parts_dir>   # e.g., web/docs/parts" >&2
      exit 64
    fi

    BASENAME="${BASENAME:-materials}"

    FIRST="${PARTS_DIR}/${BASENAME}.000.b64"
    if [[ ! -f "${FIRST}" ]]; then
      FIRST="$(ls -1 "${PARTS_DIR}"/*.000.b64 2>/dev/null | head -n1 || true)"
    fi
    if [[ ! -f "${FIRST}" ]]; then
      echo "첫 파츠(.000.b64)를 찾을 수 없습니다" >&2
      exit 66
    fi

    HEAD4="$(head -c 4 "${FIRST}")"
    echo "첫 파츠 헤더(4B): ${HEAD4}"
    if [[ "${HEAD4}" != "H4sI" ]]; then
      echo "경고: 첫 파츠 선두 4문자가 H4sI가 아닙니다."
    fi

    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    cat "${PARTS_DIR}/"*.b64 | tr -d '\n' | base64 -d > "${TMP}/payload.gz"
    gzip -t "${TMP}/payload.gz"
    echo "검증 OK: base64 → gzip 무결성 확인 완료"
