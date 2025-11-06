# upbit_llm_delivery_kit

업비트 스캔 데이터(단일 또는 파츠)를 **LLM 친화적 경로(jsDelivr)** 로 배포하고,
**index.html에서 링크를 클릭해 열람**할 수 있도록 구성한 배포 키트입니다.
또한 기존 예약 작업(예: GitHub Actions 스케줄, cron)을 정리하고 재시작하는 가이드를 포함합니다.

## 폴더 구조
```
upbit_llm_delivery_kit/
├─ bin/
│  ├─ make_parts.sh        # payload.json → gzip → base64 → 80KB 파츠 생성 + 싱글 파일 생성 + partlist 생성
│  ├─ verify_parts.sh      # 파츠 결합 후 디코드/검증
│  ├─ pin_commit.sh        # index.html/partlist의 @main → @<commit> 핀 고정
│  ├─ clean_reset.sh       # 산출물 정리(초기화)
├─ web/
│  ├─ index.html           # LLM이 클릭해서 열 수 있는 링크 모음
│  └─ docs/
│     ├─ materials_current.b64gz.txt           # 싱글 페이로드(샘플)
│     └─ parts/
│        └─ materials.partlist.urls.sample     # 파츠 URL 목록 템플릿
├─ prompt_snippet_ko.txt   # 프롬프트에 삽입할 권장 스니펫
├─ reset_guide.md          # 예약 작업 전부 취소 후 재시작 가이드
└─ .env.example            # OWNER/REPO/REF 환경변수 템플릿
```

## 빠른 사용법
1. `data/payload.json`을 준비합니다(원본 JSON).
2. `.env`를 만들어 OWNER/REPO/REF를 지정합니다(예: clink-clank / upbit-live-mirror / main).
3. 파츠/싱글 생성:
   ```bash
   ./bin/make_parts.sh data/payload.json web/docs materials 81920
   ```
4. 검증:
   ```bash
   ./bin/verify_parts.sh web/docs/parts
   ```
5. 커밋/푸시 후 커밋 핀 고정(옵션):
   ```bash
   COMMIT=$(git rev-parse HEAD)
   ./bin/pin_commit.sh "$COMMIT" web/index.html web/docs/parts/materials.partlist.urls
   ```
6. GitHub에 푸시하면, LLM은 `web/index.html`에서 링크를 클릭해 접근할 수 있습니다.

자세한 내용은 `reset_guide.md`를 참고하세요.
