#!/usr/bin/env bash
# gh_fetch_through_proxies.sh
# Fetch a GitHub file via multiple public CDNs/proxies with graceful fallback.
# Usage:
#   gh_fetch_through_proxies.sh <owner> <repo> <ref> <path/to/file> [output|-]
#
# Examples:
#   gh_fetch_through_proxies.sh clink-clank upbit-live-mirror main web/docs/LLM_MATERIALS.json out.json
#   gh_fetch_through_proxies.sh clink-clank upbit-live-mirror 35794df60 web/docs/materials_current.b64gz.txt - | head -c 64
#
# Notes:
# - Set EXPECT_MAGIC=H4sI to require the file to start with that 4-char magic (useful for base64+gz).
# - Set EXTRA_PROXIES (newline-separated patterns) to prepend custom endpoints.
#   Pattern placeholders: {owner} {repo} {ref} {path}
#   To add a request header, append "#HEADER:<Header-Name>: <value>"
#   Example: "https://example.com/git/{owner}/{repo}/{ref}/{path}#HEADER:Authorization: Bearer $TOKEN"
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <owner> <repo> <ref> <path> [output|-]" >&2
  exit 1
fi

owner="$1"; repo="$2"; ref="$3"; relpath="$4"; out="${5:--}"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

# Built-in proxy chain (ordered by speed/cache likelihood)
# docs:
# - jsDelivr:   https://www.jsdelivr.com/github
# - Statically: https://statically.io/docs/gh/
# - Githack:    https://raw.githack.com/ (prod domain is rawcdn.githack.com)
PROXIES_DEFAULT=$(cat <<'EOF'
https://cdn.jsdelivr.net/gh/{owner}/{repo}@{ref}/{path}
https://cdn.statically.io/gh/{owner}/{repo}/{ref}/{path}
https://rawcdn.githack.com/{owner}/{repo}/{ref}/{path}
https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}
https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={ref}#HEADER:Accept: application/vnd.github.raw
EOF
)

# Allow caller to prepend custom proxies
PROXIES_COMBINED="${EXTRA_PROXIES:-}
${PROXIES_DEFAULT}"

_subst() {
  local s="$1"
  s="${s//{owner}/$owner}"; s="${s//{repo}/$repo}"; s="${s//{ref}/$ref}"; s="${s//{path}/$relpath}"
  printf "%s" "$s"
}

# Try each proxy until one works and (optionally) passes magic test
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  url="$(_subst "$p")"
  header=""
  if [[ "$url" == *"#HEADER:"* ]]; then
    header="${url#*#HEADER:}"
    url="${url%%#HEADER:*}"
  fi

  echo "[try] $url" >&2
  if [[ -n "$header" ]]; then
    # shellcheck disable=SC2086
    if ! curl -fsSL --retry 2 -H "$header" -o "$tmp" "$url"; then
      echo "[fail] $url" >&2
      continue
    fi
  else
    if ! curl -fsSL --retry 2 -o "$tmp" "$url"; then
      echo "[fail] $url" >&2
      continue
    fi
  fi

  # Sanity: non-empty and not obvious HTML error page
  if [[ ! -s "$tmp" ]]; then
    echo "[skip] empty body from $url" >&2
    continue
  fi
  # quick HTML check
  if head -c 1 "$tmp" | grep -q "<"; then
    # but allow JSON
    if ! head -c 1 "$tmp" | grep -q "{" ; then
      echo "[skip] looks like HTML, skipping $url" >&2
      continue
    fi
  fi

  # Optional magic check
  if [[ -n "${EXPECT_MAGIC:-}" ]]; then
    head4="$(head -c 4 "$tmp" || true)"
    if [[ "$head4" != "$EXPECT_MAGIC" ]]; then
      echo "[skip] magic mismatch (got '$head4', want '$EXPECT_MAGIC') from $url" >&2
      continue
    fi
  fi

  # Success
  if [[ "$out" == "-" ]]; then
    cat "$tmp"
  else
    mkdir -p "$(dirname -- "$out")"
    mv "$tmp" "$out"
  fi
  echo "[ok] fetched from: $url" >&2
  exit 0
done <<< "$PROXIES_COMBINED"

echo "[error] all proxies failed for $owner/$repo@$ref:$relpath" >&2
exit 2
