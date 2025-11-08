#!/usr/bin/env bash
# Usage: diff_vs_single.sh <PIN_COMMIT> <partlist.urls>
# Compares parts-joined JSON vs single-file JSON from the same commit by SHA256 (sorted).
set -euo pipefail
PIN="${1:?commit}"
LIST="${2:?partlist.urls}"

repo_path="$(head -n1 "$LIST" | sed -E 's#^https://cdn\.jsdelivr\.net/gh/([^@]+)@.*#\1#')"
single_url="https://cdn.jsdelivr.net/gh/${repo_path}@${PIN}/web/docs/materials_current.b64gz.txt"

tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
parts_json="$tmpdir/parts.json"
single_json="$tmpdir/single.json"
b64="$tmpdir/single.b64"

# Build from parts
"$(dirname "$0")/join_from_parts_strict.sh" "$LIST" "$parts_json"

# Fetch single and decode
curl -fsSL "$single_url" -o "$b64"
base64 -d "$b64" | gunzip -c > "$single_json"

# Hash after canonical sort
hash_parts="$(jq -S . "$parts_json" | sha256sum | awk '{print $1}')"
hash_single="$(jq -S . "$single_json" | sha256sum | awk '{print $1}')"

echo "[parts]  $hash_parts"
echo "[single] $hash_single"

if [[ "$hash_parts" == "$hash_single" ]]; then
  echo "OK: hashes match"
  exit 0
else
  echo "MISMATCH: hashes differ"
  exit 2
fi
