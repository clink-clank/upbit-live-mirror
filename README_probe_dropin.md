# Probe Drop-in

이 드롭인은 거대한 `web/docs/LLM_MATERIALS.json`에서 일부만 추출해
`web/docs/probe/materials_probe_sample.json`을 만들고, 간단 뷰어(`index.html`)까지 함께 배포합니다.

## 파일
- `bin/make_probe_from_json.sh` : jq 필터 (배열/객체 모두 대응)
- `bin/publish_probe.sh` : 샘플 생성 + git 커밋/푸시
- `web/docs/probe/index.html` : GitHub Pages로 바로 확인

## 사용
```bash
cd ~/upbit-live-mirror
unzip -o probe-dropin-fixed.zip
chmod +x bin/make_probe_from_json.sh bin/publish_probe.sh
bin/publish_probe.sh web/docs/LLM_MATERIALS.json 12
```

## 확인
- GitHub Pages: https://<user>.github.io/upbit-live-mirror/web/docs/probe/materials_probe_sample.json
- jsDelivr: https://cdn.jsdelivr.net/gh/<user>/upbit-live-mirror@main/web/docs/probe/materials_probe_sample.json
