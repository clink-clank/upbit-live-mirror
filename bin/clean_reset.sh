\
    #!/usr/bin/env bash
    set -euo pipefail

    OUT_DOCS_DIR="${1:-}"
    if [[ -z "${OUT_DOCS_DIR}" ]]; then
      echo "usage: $0 <output_docs_dir>   # e.g., web/docs" >&2
      exit 64
    fi

    echo "정리 대상: ${OUT_DOCS_DIR}/materials_current.b64gz.txt"
    echo "정리 대상: ${OUT_DOCS_DIR}/parts/*"
    rm -f "${OUT_DOCS_DIR}/materials_current.b64gz.txt" || true
    rm -f "${OUT_DOCS_DIR}/parts/"*.b64 || true
    rm -f "${OUT_DOCS_DIR}/parts/"*.urls || true

    echo "완료"
