#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-chore/live-v2-full}"

echo "==> Using branch: $BRANCH"

# 0) ensure repo root
test -d .git || { echo "Run this in the repo root (where .git exists)"; exit 1; }

# 1) create branch
git switch -C "$BRANCH"

# 2) ensure dirs
mkdir -p .github/workflows scripts materials_10

# 3) split script (only write if missing)
if [ ! -f scripts/split_llm_materials.py ]; then
  cat > scripts/split_llm_materials.py <<'PY'
#!/usr/bin/env python3
import json, os, math
SRC = "LLM_MATERIALS.json"
N   = int(os.environ.get("SHARDS", "10"))
OUT = "materials_10"
os.makedirs(OUT, exist_ok=True)
with open(SRC, "r", encoding="utf-8") as f:
    data = json.load(f)
markets = data.get("markets", [])
total = len(markets)
if total == 0:
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as g:
        json.dump({"parts": [], "total": 0}, g, ensure_ascii=False)
    raise SystemExit(0)
size = (total + N - 1) // N
parts = []
for i in range(N):
    beg = i*size
    end = min((i+1)*size, total)
    if beg >= end: break
    shard = {
        "version": data.get("version", "LLM_MATERIALS_V1"),
        "timestamps": data.get("timestamps", {}),
        "meta": {**data.get("meta", {}), "shard": {"index": i, "count": N}},
        "markets": markets[beg:end],
    }
    path = os.path.join(OUT, f"LLM_MATERIALS_part_{i:02d}.json")
    with open(path, "w", encoding="utf-8") as g:
        json.dump(shard, g, ensure_ascii=False)
    parts.append(os.path.basename(path))
with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as g:
    json.dump({"parts": parts, "total": total}, g, ensure_ascii=False)
PY
  chmod +x scripts/split_llm_materials.py
fi

# 4) write v2 workflow (dispatch + */5 + full pipeline)
cat > .github/workflows/mirror_live_v2.yml <<'YAML'
name: Mirror Live v2
on:
  workflow_dispatch: {}
  schedule:
    - cron: "*/5 * * * *"
permissions:
  contents: write
concurrency:
  group: mirror-upbit-v2
  cancel-in-progress: true
jobs:
  mirror:
    runs-on: ubuntu-24.04
    env:
      UA: "GA-mirror/1.1"
      BASE: "https://api.shenqn.uk"
      CHUNK: "10"
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
          curl -4fsSL "https://api.upbit.com/v1/market/all?isDetails=false" -H "User-Agent: $UA"             | jq -r '.[].market' | grep '^KRW-' > markets.txt
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
              sleep 0.8
              url="${BASE}/materials.json?mode=selected&full=1&markets=${enc_part}"
              code=$(curl -4sS -H "User-Agent: $UA" -H "Accept: application/json" -w "%{http_code}" -o "$out.tmp" --max-time 60 "$url" || true)
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
            echo "::error::No part files"; exit 1
          fi

      - name: Commit LLM_MATERIALS.json if changed
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          if ! git diff --quiet -- LLM_MATERIALS.json; then
            git add LLM_MATERIALS.json
            git commit -m "chore(live): update LLM_MATERIALS.json (v2)"
            git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
            git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
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
            git commit -m "chore(live): update materials_10 shards (v2)"
            git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" || true
            git push origin HEAD:"${GITHUB_REF_NAME:-main}" || true
          else
            echo "::notice title=Commit::No shard changes"
          fi
YAML

# 5) commit & push
git add .github/workflows/mirror_live_v2.yml scripts/split_llm_materials.py
git commit -m "ci(live-v2): add full pipeline + shards (dispatch + */5)"
git push -u origin "$BRANCH"

echo "==> Done."
echo "Create PR and merge:"
echo "  gh pr create --fill --base main --head $BRANCH"
echo "  gh pr merge  --merge --delete-branch"
echo "Run once after merge:"
echo "  gh workflow run .github/workflows/mirror_live_v2.yml --ref main"
