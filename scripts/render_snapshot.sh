#!/usr/bin/env bash
set -euo pipefail

# Paths
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_JSON="${ROOT_DIR}/LLM_MATERIALS.json"
OUT_DIR="${ROOT_DIR}/docs"
PRETTY_JSON="${OUT_DIR}/LLM_MATERIALS.pretty.json"
HTML="${OUT_DIR}/materials.html"
STAMP="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

# Checks
if [[ ! -f "$SRC_JSON" ]]; then
  echo "ERROR: ${SRC_JSON} not found."
  exit 1
fi

mkdir -p "$OUT_DIR"

# 1) JSON 정렬/들여쓰기 (대용량도 안전)
jq --sort-keys . "$SRC_JSON" > "$PRETTY_JSON"

# 메타 정보 뽑기 (있으면 사용, 없으면 빈값)
VER="$(jq -r '.version // empty' "$SRC_JSON" || true)"
KST_T="$(jq -r '.timestamps.kst // empty' "$SRC_JSON" || true)"
UTC_T="$(jq -r '.timestamps.utc // empty' "$SRC_JSON" || true)"
COUNT="$(jq -r '.markets | length' "$SRC_JSON" 2>/dev/null || echo 0)"

# 2) 정적 HTML 생성 (JS 없음, 캐시 우회 팁 포함)
cat > "$HTML" <<'HTML_HEAD'
<!doctype html>
<html lang="ko">
<meta charset="utf-8">
<meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<title>LLM Materials Snapshot (static)</title>
<style>
  body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 24px; line-height: 1.45; }
  .muted { color:#666; font-size:0.92rem; }
  pre { background:#0b1020; color:#e4e7ef; padding:16px; border-radius:8px; overflow:auto; }
  .meta { margin-bottom: 12px; }
  .meta b { display:inline-block; min-width:140px; }
  .tip { background:#fff3cd; color:#5f4b00; padding:10px 12px; border-radius:8px; border:1px solid #ffe69c; margin: 12px 0 18px; }
  a { color:#0059b3; text-decoration:none; }
  a:hover { text-decoration:underline; }
</style>
<body>
<h1>LLM Materials Snapshot</h1>
HTML_HEAD

cat >> "$HTML" <<HTML_META
<div class="meta">
  <div><b>Generated at</b> ${STAMP}</div>
  <div><b>Version</b> ${VER:-"-"}</div>
  <div><b>Timestamps (KST / UTC)</b> ${KST_T:-"-"} / ${UTC_T:-"-"}</div>
  <div><b>Total markets</b> ${COUNT}</div>
</div>

<div class="tip">
  <b>새로고침 시 최신 반영?</b> GitHub Pages는 정적 파일을 서빙합니다. 이 파일(<code>docs/materials.html</code>)이
  다시 커밋/배포되면 새 내용으로 노출돼요. 브라우저 캐시를 피하려면 <code>?v=$(date +%s)</code>처럼
  쿼리를 붙여 새로고침 하거나, Ctrl+F5(강력 새로고침) 를 사용하세요.
</div>

<p class="muted">
  원본: <a href="https://raw.githubusercontent.com/clink-clank/upbit-live-mirror/main/LLM_MATERIALS.json" target="_blank" rel="noopener">
  raw LLM_MATERIALS.json</a> · 정렬본: <a href="LLM_MATERIALS.pretty.json">LLM_MATERIALS.pretty.json</a>
</p>

<h2>Raw (pretty printed)</h2>
<pre>
HTML_META

# 3) pretty JSON을 HTML로 안전하게 삽입(전체를 읽어 이스케이프)
#    -R : raw, -s : slurp(전체), @html : HTML 이스케이프
jq -R -s '@html' "$PRETTY_JSON" >> "$HTML"

cat >> "$HTML" <<'HTML_TAIL'
</pre>
</body>
</html>
HTML_TAIL

echo "Wrote:"
ls -lh "$PRETTY_JSON" "$HTML"
