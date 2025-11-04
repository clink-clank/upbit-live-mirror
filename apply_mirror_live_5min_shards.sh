#!/usr/bin/env bash
# Apply Mirror Live workflow (5min + shards) and splitter script.
# Usage:
#   bash apply_mirror_live_5min_shards.sh [--branch <name>] [--no-push]
set -euo pipefail

BRANCH=""
PUSH=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2;;
    --no-push) PUSH=0; shift;;
    *) echo "Unknown arg: $1"; exit 2;;
  esac
done

# Ensure repo root
if [[ ! -d .git ]]; then
  echo "Run this inside your git repository root." >&2
  exit 1
fi

# Optional branch switch/create
if [[ -n "$BRANCH" ]]; then
  git switch -C "$BRANCH"
fi

mkdir -p .github/workflows scripts

# --- Write splitter script ---
cat > scripts/split_llm_materials.py <<'PY'
#!/usr/bin/env python3
from pathlib import Path
import json, math, sys
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "LLM_MATERIALS.json"
DST = ROOT / "materials_10"
DST.mkdir(parents=True, exist_ok=True)
if not SRC.exists():
    print("LLM_MATERIALS.json not found; skip split.", file=sys.stderr); sys.exit(0)
try:
    data = json.loads(SRC.read_text(encoding="utf-8"))
except Exception as e:
    print(f"JSON parse error: {e}", file=sys.stderr); sys.exit(1)
markets = data.get("markets", []); k = 10; n = len(markets)
if n == 0:
    print("No markets to split.", file=sys.stderr); sys.exit(0)
chunk = math.ceil(n / k); index = []
for i in range(k):
    a, b = i*chunk, min((i+1)*chunk, n); shard = markets[a:b]
    if not shard: continue
    out = dict(data); out["markets"] = shard
    meta = dict(out.get("meta", {})); meta["shard"] = {"index": i, "total": k, "range": [a, b-1], "count": len(shard)}
    out["meta"] = meta
    name = f"LLM_MATERIALS_part_{i:02d}.json"
    (DST / name).write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    index.append({"file": name, "index": i, "count": len(shard)})
idx = {"source": "LLM_MATERIALS.json", "total_markets": n, "shards": index, "total_shards": len(index)}
(DST / "index.json").write_text(json.dumps(idx, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print(f"Split {n} markets into {len(index)} shard files in {DST}")
PY
chmod +x scripts/split_llm_materials.py

# --- Write workflow (Mirror Live) ---
cat > .github/workflows/mirror_live.yml <<'YAML'
name: Mirror Live

on:
  workflow_dispatch: {}
  schedule:
    - cron: "*/5 * * * *"
  push:
    branches: [ main ]

permissions:
  contents: write

concurrency:
  group: mirror-upbit
  cancel-in-progress: true

jobs:
  mirror:
    runs-on: ubuntu-24.04
    env:
      BASE: "https://api.shenqn.uk"
      CHUNK: "10"
      UA: "GA-mirror/1.1"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: true

      - name: Setup jq and Python
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
          python3 -V

      - name: Build KRW market list (from Upbit)
        run: |
          set -euo pipefail
          curl -4fsSL "https://api.upbit.com/v1/market/all?isDetails=false" -H "User-Agent: $UA" \
            | jq -r '.[].market' | grep '^KRW-' > markets.txt
          echo "::notice title=KRW markets::$(wc -l < markets.txt)"

      - name: Fetch materials in chunks
        run: |
          set -euo pipefail
          rm -rf parts && mkdir -p parts
          mapfile -t ARR < markets.txt
          n=${#ARR[@]}; i=0; idx=1
          while [ $i -lt $n ]; do
            part=$(IFS=,; printf '%s' "${ARR[*]:i:${CHUNK}}")
            enc_part=$(printf '%s' "$part" | jq -sRr @uri)
            out="parts/part_${idx}.json"; ok=0
            for attempt in 1 2 3 4 5 6 7 8; do
              delay=$(python3 - <<'PY' "$attempt"
import random,sys
base=[0.0,0.6,1.0,1.7,3.0,5.0,8.0,13.0][int(sys.argv[1])-1]
print(base+0.2)
PY
              )
              sleep "$delay"
              url="${BASE}/materials.json?mode=selected&full=1&markets=${enc_part}"
              code=$(curl -4sS -H "User-Agent: $UA" -H "Accept: application/json" -w "%{http_code}" -o "$out.tmp" --max-time 60 "$url" || true)
              echo "HTTP=$code"
              if [ "$code" = "200" ] && jq -e '(.markets|type=="array") and (.markets|length>=1)' "$out.tmp" >/dev/null 2>&1; then
                mv "$out.tmp" "$out"; ok=1; break
              fi
            done
            [ "$ok" = "1" ] || { echo "::warning::part ${idx} failed"; rm -f "$out.tmp"; }
            i=$((i+CHUNK)); idx=$((idx+1))
          done
          ls -1 parts/part_*.json 2>/dev/null | sort > parts/list.txt || true

      - name: Merge -> LLM_MATERIALS.json
        run: |
          set -euo pipefail
          files=$(cat parts/list.txt 2>/dev/null || true)
          if [ -n "${files}" ]; then
            jq -s '
              def valid: type=="object" and (.markets|type=="array");
              def GOOD: [ .[] | select(valid) ];
              def M: [ GOOD[] | .markets[] ];
              def FIRST: (GOOD | first) // {};
              {
                version: (FIRST.version // "LLM_MATERIALS_V1"),
                timestamps: (FIRST.timestamps // {kst:"",utc:""}),
                meta: (
                  (FIRST.meta // {}) as $m
                  | ($m + {params: (($m.params // {}) + {markets: (M | map(.market) | unique)})})
                ),
                markets: (M | unique_by(.market))
              }' $files > LLM_MATERIALS.json
          else
            echo "::error::No part files"
            exit 1
          fi

      - name: Commit LLM_MATERIALS.json if changed
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          if ! git diff --quiet -- LLM_MATERIALS.json; then
            git add LLM_MATERIALS.json
            git commit -m "chore(live): update LLM_MATERIALS.json"
            git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
            git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
            echo "::notice title=Commit::Pushed LLM_MATERIALS.json"
          else
            echo "::notice title=Commit::No changes"
          fi

      - name: Generate & commit 10 shards (materials_10/)
        run: |
          set -euo pipefail
          python3 scripts/split_llm_materials.py
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          if ! git diff --quiet -- materials_10/; then
            git add materials_10/*.json || true
            git commit -m "chore(live): update materials_10 shards"
            git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
            git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
            echo "::notice title=Commit::Pushed materials_10 shards"
          else
            echo "::notice title=Commit::No shard changes"
          fi
YAML

# sanitize hidden unicode (BOM/ZWSP) just in case
perl -i -pe 's/\x{200B}|\x{200C}|\x{200D}|\x{200E}|\x{200F}//g' .github/workflows/mirror_live.yml
sed -i '1s/^\xEF\xBB\xBF//' .github/workflows/mirror_live.yml

# commit
git add .github/workflows/mirror_live.yml scripts/split_llm_materials.py
if ! git diff --cached --quiet; then
  git commit -m "ci(live): 5min schedule + manual dispatch + auto shards"
  if [[ $PUSH -eq 1 ]]; then
    git push -u origin "$(git branch --show-current)"
  fi
else
  echo "No changes to commit."
fi

echo "Done. Trigger with: gh workflow run .github/workflows/mirror_live.yml --ref $(git branch --show-current)"
