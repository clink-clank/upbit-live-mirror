Materials parts (gzip+base64), version=LLM_MATERIALS_V1, markets=224
timestamps: kst=2025- 11- 04- 오후 08:39:03, utc=2025-11-04T11:39:03.146Z
parts: 40, chunk=80000B
dir: docs/parts

# Join & decode to JSON (server-side)
cat docs/parts/materials_*.b64 | tr -d '\n' | base64 -d | gzip -dc > LLM_MATERIALS_joined.json

# Join & decode (from GitHub Raw), writes LLM_MATERIALS_joined.json in CWD
curl -fsSL "https://raw.githubusercontent.com/clink-clank/upbit-live-mirror/main/docs/parts/materials.partlist" | while read -r f; do curl -fsSL "https://raw.githubusercontent.com/clink-clank/upbit-live-mirror/main/docs/parts/${f}"; done | tr -d '\n' | base64 -d | gzip -dc > LLM_MATERIALS_joined.json
jq -r '["version=\(.version)","kst=\(.timestamps.kst)","utc=\(.timestamps.utc)","markets=\((.markets|length))"]|.[]' LLM_MATERIALS_joined.json
