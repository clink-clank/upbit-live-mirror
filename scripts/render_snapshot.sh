\
#!/usr/bin/env bash
set -euo pipefail

JSON="LLM_MATERIALS.json"
OUT="docs/materials.html"
TPL="docs/materials.template.html"

if [ ! -f "$JSON" ]; then
  echo "::error::Missing $JSON. Run the mirror workflow first."
  exit 1
fi

mkdir -p docs

# 1) Build table rows from JSON using jq (no giant argv; write to a tmp file)
ROWS_FILE="$(mktemp)"
jq -r '
  .timestamps as $ts
  | .markets
  | sort_by(.market)
  | map({
      market: .market,
      base: (.market | split("-")[1]),
      kr_name: (.korean_name // ""),
      en_name: (.english_name // ""),
      total_ask: (.orderbook.total_ask_size // empty),
      total_bid: (.orderbook.total_bid_size // empty)
    })
  | (["Market","Base","KR Name","EN Name","Ask Size","Bid Size"] | @html | "<tr><th>"+(split("\t")|join("</th><th>"))+"</th></tr>"),
    (.[] | [
      .market,.base,.kr_name,.en_name,
      (if (.total_ask|tostring) == "null" then "" else (.total_ask|tostring) end),
      (if (.total_bid|tostring) == "null" then "" else (.total_bid|tostring) end)
    ] | @html | "<tr><td>"+(split("\t")|join("</td><td>"))+"</td></tr>")
' "$JSON" > "$ROWS_FILE"

# 2) Write full HTML without expanding huge variables on the command line
{
  if [ -f "$TPL" ]; then
    cat "$TPL"
  else
    # Minimal fallback template
    cat <<'HTMLHEAD'
<!doctype html>
<html lang="ko">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Upbit KRW Materials Snapshot</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:20px;}
  header{display:flex;justify-content:space-between;align-items:baseline;gap:12px;flex-wrap:wrap}
  table{width:100%;border-collapse:collapse;margin-top:12px;font-size:14px}
  th,td{border:1px solid #e5e7eb;padding:6px 8px;text-align:left;vertical-align:top}
  th{background:#f3f4f6;position:sticky;top:0}
  .meta{color:#6b7280;font-size:13px}
  .mono{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}
</style>
<header>
  <h1>Upbit KRW Materials Snapshot</h1>
  <div class="meta">
    Built from <span class="mono">LLM_MATERIALS.json</span>
  </div>
</header>
HTMLHEAD
  fi

  echo "<table>"
  cat "$ROWS_FILE"
  echo "</table>"
  echo "<footer class=\"meta\">Generated: $(date -u +"%Y-%m-%d %H:%M:%SZ") (UTC)</footer>"
  echo "</html>"
} > "$OUT"

echo "::notice title=Snapshot::Wrote $OUT ($(wc -c < "$OUT") bytes)"
