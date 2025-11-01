
# 업로드 후 실행할 명령어 (복붙용)

# 0) 리포 클론 / 이동 (이미 있다면 생략)
# git clone https://github.com/clink-clank/upbit-live-mirror.git
# cd upbit-live-mirror

# 1) 파일 투하
# (ZIP 풀고 아래 파일/경로를 그대로 덮어쓰기)
#   .github/workflows/mirror_hot.yml

# 2) 커밋/푸시
git add .github/workflows/mirror_hot.yml
git commit -m "chore: hot mirror + HTML snapshot (every 5m)"
git push origin main

# 3) 워크플로 수동 실행(즉시 반영 원할 때)
gh workflow run mirror_hot.yml --ref main -f chunk=15

# 4) GitHub Pages 설정(/docs → 공개 URL)
gh api -X POST repos/clink-clank/upbit-live-mirror/pages -f "source[branch]=main" -f "source[path]=/docs" || true
gh api -X PUT  repos/clink-clank/upbit-live-mirror/pages -f "source[branch]=main" -f "source[path]=/docs" || true

# 5) 확인
echo "OPEN  https://clink-clank.github.io/upbit-live-mirror/materials.html"
echo "RAW   https://raw.githubusercontent.com/clink-clank/upbit-live-mirror/main/LLM_MATERIALS.json"
