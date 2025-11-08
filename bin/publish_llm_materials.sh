#!/usr/bin/env bash
set -euo pipefail
#
# publish_llm_materials.sh
# Usage:
#   publish_llm_materials.sh [PARTLIST_PATH] [OUTPUT_JSON] [PIN_COMMIT]
#
# Env:
#   GIT_COMMIT=1  # set 0 to skip git commit/push
#   BRANCH=main
#
# What it does:
#   1) (optional) pin PARTLIST to PIN_COMMIT
#   2) probe & repair PARTLIST using CDN (prefers magic=H4sI)
#   3) join parts into OUTPUT_JSON
#   4) also write web/docs/materials_current.b64gz.txt
#   5) verify JSON (version/utc/markets)
#   6) (optional) git add/commit/push
#
PARTLIST="${1:-web/docs/parts/materials.partlist.urls}"
OUT_JSON="${2:-web/docs/LLM_MATERIALS.json}"
PIN="${3:-}"
BRANCH="${BRANCH:-main}"
GIT_COMMIT="${GIT_COMMIT:-1}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 97; }; }
need curl; need jq; need git; need awk; need sed; need base64; need gzip

echo "[+] partlist: $PARTLIST"
[ -s "$PARTLIST" ] || { echo "[✗] partlist not found"; exit 2; }

# 1) optional pin
if [ -n "$PIN" ]; then
  echo "[+] pin to commit: $PIN"
  if [ -x bin/pin_partlist_to_commit.sh ]; then
    bin/pin_partlist_to_commit.sh "$PARTLIST" "$PIN"
  else
    tmp="${PARTLIST}.tmp.$$"
    awk -v sha="$PIN" '{ gsub(/@[0-9a-f]{7,}\/web\/docs\/parts\//, "@" sha "/web/docs/parts/"); print }'           "$PARTLIST" > "$tmp" && mv "$tmp" "$PARTLIST"
  fi
fi

# 2) probe & repair
if [ -x bin/repair_partlist_by_probe.sh ]; then
  echo "[+] probe/repair via bin/repair_partlist_by_probe.sh"
  tmp="${PARTLIST}.fixed.$$"
  bin/repair_partlist_by_probe.sh "$PARTLIST" "${PIN:-}" > "$tmp"
  mv "$tmp" "$PARTLIST"
else
  echo "[!] bin/repair_partlist_by_probe.sh not found, skipping probe (assuming PARTLIST is good)"
fi

# 3) join parts → OUT_JSON
mkdir -p "$(dirname "$OUT_JSON")"
if [ -x bin/join_from_parts_strict.sh ]; then
  echo "[+] join via bin/join_from_parts_strict.sh → $OUT_JSON"
  bin/join_from_parts_strict.sh "$PARTLIST" "$OUT_JSON"
else
  echo "[!] fallback join (concatenate gzip members then gunzip)"
  tmpgz="$(mktemp)"
  while IFS= read -r url; do
    [ -n "$url" ] || continue
    curl -fsSL "$url" | base64 -d >> "$tmpgz"
  done < "$PARTLIST"
  gunzip -c "$tmpgz" > "$OUT_JSON"
  rm -f "$tmpgz"
fi

# 4) also write single-file b64+gz for CDN
SINGLE="web/docs/materials_current.b64gz.txt"
mkdir -p "$(dirname "$SINGLE")"
echo "[+] write $SINGLE"
gzip -c -9 "$OUT_JSON" | base64 -w 0 > "$SINGLE"

# 5) verify JSON
echo "== summary =="
jq -r '.version, .timestamps.utc, (.markets|length)' "$OUT_JSON"

# 6) git add/commit/push
if [ "${GIT_COMMIT}" = "1" ]; then
  echo "[+] git commit & push"
  git add "$OUT_JSON" "$SINGLE" || true
  if ! git diff --cached --quiet; then
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com"           commit -m "docs: publish LLM_MATERIALS.json and materials_current.b64gz.txt"
    git push origin "$BRANCH"
  else
    echo "[=] no changes to commit"
  fi
else
  echo "[=] GIT_COMMIT=0 → skipping commit/push"
fi
