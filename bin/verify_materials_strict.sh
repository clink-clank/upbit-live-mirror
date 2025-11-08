#!/usr/bin/env bash
set -euo pipefail

# verify_materials_strict.sh
# Usage: verify_materials_strict.sh <partlist.urls> <single_b64gz_url>
# - Rebuilds JSON from parts, fetches single b64+gz JSON, sorts both, and compares SHA256.
# Requirements: curl, base64, gzip, jq, sha256sum

usage() {
  echo "usage: $0 <partlist.urls> <single_b64gz_url>" >&2
  exit 1
}

[ $# -lt 2 ] && usage
PFILE="$1"
SINGLE_URL="$2"

if [ ! -f "$PFILE" ]; then
  echo "[err] partlist file not found: $PFILE" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

from_parts="$work/from_parts.json"
single="$work/single.json"

# 1) Build from parts
"$(dirname "$0")/fetch_from_parts_strict.sh" "$PFILE" "$from_parts"

# 2) Single URL fetch
code="$(curl -sS -o /dev/null -w "%{http_code}" -I "$SINGLE_URL" || true)"
if [ "$code" != "200" ]; then
  echo "[err] single url HEAD -> $code :: $SINGLE_URL" >&2
  exit 2
fi
curl -fsSL "$SINGLE_URL" | base64 -d | gunzip > "$single"

# 3) Normalize + hash
parts_sorted="$work/parts.sorted.json"
single_sorted="$work/single.sorted.json"
jq -S . "$from_parts" > "$parts_sorted"
jq -S . "$single" > "$single_sorted"

sha_parts="$(sha256sum "$parts_sorted" | awk '{print $1}')"
sha_single="$(sha256sum "$single_sorted" | awk '{print $1}')"

echo "[parts ] sha256=${sha_parts}"
echo "[single] sha256=${sha_single}"

if [ "$sha_parts" != "$sha_single" ]; then
  echo "[FAIL] mismatch"
  exit 10
fi

ver="$(jq -r '.version' "$from_parts")"
utc="$(jq -r '.timestamps.utc' "$from_parts")"
cnt="$(jq -r '.markets|length' "$from_parts")"
echo "[OK] match. version=${ver} utc=${utc} markets=${cnt}"
