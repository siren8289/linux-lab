#!/usr/bin/env bash
set -euo pipefail

BASE="http://127.0.0.1:8082"

echo "[1] Build and start"
docker compose up -d --build

echo "[2] Wait for HTTP readiness"
READY=0
for i in $(seq 1 30); do
  if curl -fsS "$BASE/health" >/dev/null; then
    READY=1
    break
  fi
  sleep 1
done
test "$READY" -eq 1

echo "[3] Save message"
curl -fsS -X POST "$BASE/message" \
  -H "Content-Type: application/json" \
  -d '{"message":"persistent-data"}'
echo

echo "[4] Recreate container"
docker compose up -d --force-recreate

READY=0
for i in $(seq 1 30); do
  if curl -fsS "$BASE/health" >/dev/null; then
    READY=1
    break
  fi
  sleep 1
done
test "$READY" -eq 1

echo "[5] Verify persisted data"
RESULT=$(curl -fsS "$BASE/message")
echo "$RESULT"

python3 -c \
  'import json,sys; assert json.loads(sys.argv[1])["message"] == "persistent-data"' \
  "$RESULT"

echo "PASS: data survived container recreation"
