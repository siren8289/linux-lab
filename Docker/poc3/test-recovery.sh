#!/usr/bin/env bash
set -euo pipefail

docker compose up -d --build

ID=""
for i in $(seq 1 30); do
  ID=$(docker compose ps -q worker || true)
  if [ -n "$ID" ] && [ "$(docker inspect "$ID" --format '{{.State.Running}}')" = "true" ]; then
    break
  fi
  sleep 1
done
test -n "$ID"

BEFORE=$(docker inspect "$ID" \
  --format '{{.RestartCount}}')

echo "Restart count before: $BEFORE"

echo "[1] Inject process failure"
# 같은 네임스페이스의 SIGKILL은 PID 1에 전달되지 않는다.
# SIGUSR1 핸들러가 프로세스 자신을 종료 코드 137로 끝낸다.
docker exec "$ID" \
  python -c 'import os,signal; os.kill(1,signal.SIGUSR1)' \
  || true

echo "[2] Wait for restart"
RECOVERED=0
AFTER="$BEFORE"

for i in $(seq 1 30); do
  STATE=$(docker inspect "$ID" \
    --format '{{.State.Running}}')
  AFTER=$(docker inspect "$ID" \
    --format '{{.RestartCount}}')

  if [ "$STATE" = "true" ] && [ "$AFTER" -gt "$BEFORE" ]; then
    RECOVERED=1
    break
  fi

  sleep 1
done

echo "Restart count after: $AFTER"

echo "[3] Collect logs"
docker compose logs --tail 20 worker

test "$RECOVERED" -eq 1
echo "PASS: worker restarted after crash"
