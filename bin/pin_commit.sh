\
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${1:-}" ]]; then
      echo "usage: $0 <commit> <file1> [file2 ...]" >&2
      exit 64
    fi
    COMMIT="$1"; shift
    if [[ -z "${COMMIT}" ]]; then
      echo "commit 해시가 필요합니다" >&2
      exit 64
    fi
    for f in "$@"; do
      if [[ ! -f "$f" ]]; then
        echo "skip: $f (파일 없음)" >&2
        continue
      fi
      sed -i.bak -E "s/@__REF__/@$COMMIT/g; s/@main/@$COMMIT/g" "$f"
      echo "updated: $f"
    done
