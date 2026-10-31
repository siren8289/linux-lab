#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/linux-lab/리눅스/logs/health.log"

{
  echo "===== $(date -Is) ====="
  echo "[UPTIME]"
  uptime
  echo "[MEMORY]"
  free -h
  echo "[DISK]"
  df -h /
  echo "[SERVICE]"
  systemctl is-active labweb
  echo "[HTTP]"
  curl -fsS --max-time 5 http://127.0.0.1:8080
  echo
} >> "$LOG" 2>&1

echo "Health check completed: $LOG"
