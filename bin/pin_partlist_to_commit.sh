#!/usr/bin/env bash
# Usage: pin_partlist_to_commit.sh <partlist.urls> <commit_sha>
# Replaces any @<sha>/web/docs/parts/ with the given commit SHA (keeps the path).
set -euo pipefail
list="${1:?partlist.urls}"
sha="${2:?commit sha}"

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
awk -v sha="$sha" '{
  gsub(/@[0-9a-f]{7,}\/web\/docs\/parts\//, "@" sha "/web/docs/parts/");
  print
}' "$list" > "$tmp"
mv "$tmp" "$list"

echo "[pin] updated commit in $list -> $sha"
