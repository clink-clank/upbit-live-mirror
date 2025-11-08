#!/usr/bin/env bash
set -euo pipefail
# repo 루트에서 실행
mkdir -p bin
cp -f ./bin/slice50_prepare.sh ./bin/slice50_push_once.sh bin/
chmod +x bin/slice50_*.sh

# systemd user 설치
mkdir -p "${HOME}/.config/systemd/user"
cp -f ./systemd-user/slice50-pusher.service "${HOME}/.config/systemd/user/"
cp -f ./systemd-user/slice50-pusher.timer "${HOME}/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now slice50-pusher.timer

echo "== Installed. You can check status with: systemctl --user status slice50-pusher.timer"
