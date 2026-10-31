#!/usr/bin/env bash
set -euo pipefail

NAME="isolation-poc"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d \
  --name "$NAME" \
  --hostname isolated-host \
  --memory=128m \
  --cpus=0.5 \
  alpine:3.20 sleep 300 >/dev/null

echo "[1] PID Namespace"
docker exec "$NAME" sh -c \
  'test "$(cat /proc/1/comm)" = "sleep"'
echo "PASS: PID 1 is sleep"

echo "[2] UTS Namespace"
HOST=$(docker exec "$NAME" hostname)
test "$HOST" = "isolated-host"
echo "PASS: hostname isolated"

echo "[3] Memory cgroup"
MEM=$(docker exec "$NAME" \
  cat /sys/fs/cgroup/memory.max)
test "$MEM" = "134217728"
echo "PASS: memory=128MiB"

echo "[4] CPU cgroup"
CPU=$(docker exec "$NAME" \
  cat /sys/fs/cgroup/cpu.max)
echo "cpu.max=$CPU"

read -r QUOTA PERIOD <<< "$CPU"
test $((QUOTA * 2)) -eq "$PERIOD"
echo "PASS: CPU quota=0.5"

echo "ALL TESTS PASSED"
