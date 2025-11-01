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
