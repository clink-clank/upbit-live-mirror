# 리셋 & 재시작 가이드

이 문서는 "예약 작업 전부 취소하고 다시 시작"을 위한 체크리스트입니다.

## 0) 산출물 정리(선택)
기존 산출물을 지우고 깨끗하게 시작하려면:
```bash
./bin/clean_reset.sh web/docs
```

## 1) GitHub Actions 예약(스케줄) 끄기
- GitHub 웹 UI → **Actions** → 해당 워크플로 선택 → 우측 상단 **Disable workflow**
- 또는 `gh` CLI:
  ```bash
  gh workflow list
  gh workflow disable <workflow.yml>
  ```
- 스케줄을 잠깐 멈추고만 싶다면 워크플로의 `on.schedule` 섹션을 주석 처리/삭제 후 커밋.

## 2) 서버/로컬 크론 취소
- 크론 확인:
  ```bash
  crontab -l
  ```
- 편집:
  ```bash
  crontab -e
  ```
- 관련 엔트리(예: 데이터 생성/배포 스크립트) 제거 후 저장.

## 3) (선택) 클라우드 스케줄러 비활성화
- 사용 중인 서비스(GCP Cloud Scheduler, AWS EventBridge, etc.) 콘솔에서 트리거 **Pause/Disable**.

## 4) 데이터 파이프라인 재시작
1. 최신 원본 JSON 준비 (`data/payload.json`).
2. `.env`에 OWNER/REPO/REF 설정 (예: clink-clank / upbit-live-mirror / main).
3. 파츠/싱글 생성:
   ```bash
   ./bin/make_parts.sh data/payload.json web/docs materials 81920
   ```
4. 검증:
   ```bash
   ./bin/verify_parts.sh web/docs/parts
   ```
5. 커밋/푸시 후(필요 시) 커밋 핀:
   ```bash
   COMMIT=$(git rev-parse HEAD)
   ./bin/pin_commit.sh "$COMMIT" web/index.html web/docs/parts/materials.partlist.urls
   ```
6. LLM 프롬프트에는 `prompt_snippet_ko.txt`를 참고하여
   - **index.html을 먼저 열고, 그 안의 링크를 클릭**하도록 지시.
   - 싱글 실패 시 폴백(partlist) 직렬 GET을 수행하도록 지시.

## 5) 점검 커맨드
- 싱글 프롤로그 확인:
  ```bash
  curl -sL https://cdn.jsdelivr.net/gh/<OWNER>/<REPO>@<REF>/web/docs/materials_current.b64gz.txt | head -c 4
  # 기대: H4sI
  ```
- 파츠 결합/검증:
  ```bash
  curl -sL $(cat web/docs/parts/materials.partlist.urls) | tr -d '\n' | base64 -d | gzip -t && echo OK
  ```
