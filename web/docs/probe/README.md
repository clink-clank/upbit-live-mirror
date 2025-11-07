# LLM Materials Probe
A tiny, safe-to-parse subset of the full `LLM_MATERIALS.json` for external readers and monitors.

## Why
- Do **not** slice compressed `b64+gz` blobs — partial gzip produces CRC/EoF errors and truncated JSON.
- Instead, slice the **uncompressed** JSON first, then publish that tiny subset as plain JSON or re-encode if needed.

## Generate
```bash
chmod +x bin/*.sh
bin/publish_probe.sh  # uses web/docs/LLM_MATERIALS.json → web/docs/probe/materials_probe_sample.json
```

The resulting file is intentionally small and can be served via GitHub Pages and jsDelivr:

- Pages: `https://<you>.github.io/<repo>/web/docs/probe/materials_probe_sample.json`
- jsDelivr: `https://cdn.jsdelivr.net/gh/<you>/<repo>@main/web/docs/probe/materials_probe_sample.json`
