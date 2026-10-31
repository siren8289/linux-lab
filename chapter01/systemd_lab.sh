#!/usr/bin/env bash
# ==============================================================================
# Chapter 01 · 실습 05 — systemd 서비스 등록 및 자동 장애 복구 실습 스크립트
# 대상 환경: Ubuntu VM (systemd 지원 환경)
# ==============================================================================

set -euo pipefail

APP_USER="$(whoami)"
APP_HOME="$HOME"
LAB_DIR="$APP_HOME/ai-service-lab"
SERVICE_NAME="ai-demo.service"

echo "=================================================="
echo "1. 실습 디렉터리 및 Python AI 서비스 배포"
echo "=================================================="
mkdir -p "$LAB_DIR"
cp "$(dirname "$0")/app.py" "$LAB_DIR/app.py"
chmod +x "$LAB_DIR/app.py"
echo "-> 배포 완료: $LAB_DIR/app.py"

echo "\n=================================================="
echo "2. systemd 유닛 파일 동적 생성 (/etc/systemd/system/$SERVICE_NAME)"
echo "=================================================="
sudo tee "/etc/systemd/system/$SERVICE_NAME" > /dev/null <<EOF
[Unit]
Description=AI Demo Service
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$LAB_DIR
ExecStart=/usr/bin/python3 $LAB_DIR/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
echo "-> 유닛 파일 등록 완료"

echo "\n=================================================="
echo "3. systemd 데몬 리로드 및 서비스 활성화"
echo "=================================================="
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"

sleep 2
echo "-> 서비스 상태 확인:"
systemctl status "$SERVICE_NAME" --no-pager

OLD_PID=$(systemctl show "$SERVICE_NAME" -p MainPID --value)
echo "\n-> 현재 실행 중인 Main PID: $OLD_PID"

echo "\n=================================================="
echo "4. 비정상 종료 장애 재현 (kill -KILL $OLD_PID)"
echo "=================================================="
echo "-> 강제 종료 시그널(SIGKILL 9)을 전송하여 예기치 않은 크래시 유발"
sudo kill -KILL "$OLD_PID"

echo "-> RestartSec=5 대기 중 (총 7초 대기)..."
sleep 7

NEW_PID=$(systemctl show "$SERVICE_NAME" -p MainPID --value)
echo "-> 재시작 후 새로운 Main PID: $NEW_PID"

if [ "$OLD_PID" != "$NEW_PID" ] && [ "$NEW_PID" != "0" ]; then
    echo "🎉 [성공] systemd에 의해 새로운 PID($NEW_PID)로 자동 복구되었습니다!"
else
    echo "⚠️ [주의] 자동 재시작이 되지 않았습니다. 로그를 확인하세요."
fi

echo "\n=================================================="
echo "5. journalctl 최근 20줄 로그 확인"
echo "=================================================="
sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager
