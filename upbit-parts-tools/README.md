# Upbit materials parts helpers

## Files
- `bin/debug_parts.sh` — check each part URL: HTTP status and magic/peek.
- `bin/pin_parts_to_commit.sh` — pin `materials.partlist.urls` to a commit that actually serves parts on the CDN.
- `bin/fetch_from_parts_strict.sh` — reconstruct JSON from parts (strict validation).
- `bin/partlist_use_raw.sh` — switch part URLs to `raw.githubusercontent.com` fallback.

## Install into your repo
```bash
# from your repo root:
mkdir -p ./bin
cp -f ./upbit-parts-tools/bin/*.sh ./bin/
chmod +x ./bin/*.sh
```

## Typical recovery flow when 404 persists
```bash
# 1) Try to auto-pin to a good commit that has parts on jsDelivr
bin/pin_parts_to_commit.sh web/docs/parts/materials.partlist.urls

# 2) Sanity check a few parts (first 10 lines)
bin/debug_parts.sh web/docs/parts/materials.partlist.urls | sed -n '1,10p'

# 3) Rebuild from parts (strict)
bin/fetch_from_parts_strict.sh web/docs/parts/materials.partlist.urls LLM_MATERIALS.from_parts.json
jq -r '.version, .timestamps.utc, (.markets|length)' LLM_MATERIALS.from_parts.json

# 4) If jsDelivr still 404 across the board, temporarily rewrite to raw.githubusercontent.com:
bin/partlist_use_raw.sh web/docs/parts/materials.partlist.urls

# 5) Re-run debug + strict fetch
bin/debug_parts.sh web/docs/parts/materials.partlist.urls | sed -n '1,10p'
bin/fetch_from_parts_strict.sh web/docs/parts/materials.partlist.urls LLM_MATERIALS.from_parts.json
```

## Notes
- The first part (`materials_000.b64`) should start with `H4sI` (base64 of gzip). Others will not, which is normal.
- Keep the canonical path `web/docs/parts/` in the partlist. Only use `partlist_use_raw.sh` as a temporary fallback.
