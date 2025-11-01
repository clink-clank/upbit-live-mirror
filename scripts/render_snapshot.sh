#!/usr/bin/env bash
set -euo pipefail
# Render docs/materials.html from LLM_MATERIALS.json without sed/JS (avoid arg-list-too-long)
mkdir -p docs
python3 - <<'PY'
import json,html,os,sys
src="LLM_MATERIALS.json"
dst="docs/materials.html"
with open(src,"r",encoding="utf-8") as f:
    data=json.load(f)
s=json.dumps(data, ensure_ascii=False, indent=2)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst,"w",encoding="utf-8") as f:
    f.write('''<!doctype html>
<meta charset="utf-8">
<title>Upbit Materials Snapshot</title>
<style>
 body{font:14px/1.5 system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;margin:32px;max-width:1100px}
 pre{white-space:pre-wrap;word-wrap:break-word}
 .meta{color:#555;margin-bottom:16px}
 a{ text-decoration:none }
</style>
<h1>Upbit KRW Markets — Materials Snapshot</h1>
<p class="meta">Source: LLM_MATERIALS.json (static render). No JavaScript.</p>
<pre>''')
    f.write(html.escape(s))
    f.write("</pre>")
print(f"Wrote {dst}")
PY
