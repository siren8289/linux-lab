#!/usr/bin/env bash
# Runs the local Docker curriculum and writes a transcript.
# Does not stop pre-existing containers (kind, festive_joliot, cloud-ops).
set -uo pipefail

ROOT="$HOME/linux-lab/Docker"
mkdir -p "$ROOT/logs" "$ROOT/shared"
LOG="$ROOT/logs/lab-run.log"
exec > >(tee "$LOG") 2>&1

fail() {
  echo "FAIL: $*"
  FAILS=$((FAILS + 1))
}
pass() {
  echo "PASS: $*"
}

FAILS=0

echo "===== $(date '+%Y-%m-%dT%H:%M:%S%z') HOST ====="
uname -a
hostname
sw_vers

echo "===== Docker Client / Engine ====="
docker version
docker compose version
docker info --format 'Server={{.ServerVersion}} OS={{.OperatingSystem}} Kernel={{.KernelVersion}} OSType={{.OSType}} Cgroup={{.CgroupVersion}} CgroupDriver={{.CgroupDriver}} Driver={{.Driver}} Arch={{.Architecture}} CPUs={{.NCPU}} Mem={{.MemTotal}} Name={{.Name}}'

echo "===== systemctl (Mac에서는 실패가 정상) ====="
if systemctl status docker; then
  echo "systemctl_exit=0"
else
  echo "systemctl_exit=$?"
fi

echo "===== 기존 컨테이너 (유지) ====="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'

echo "===== hello-world ====="
if docker run --rm hello-world; then
  pass "hello-world"
else
  fail "hello-world"
fi

echo "===== 커널 비교 ====="
echo "[host]"; uname -srm
echo "[container]"; docker run --rm alpine:3.20 uname -srm

echo "===== 실습 1 PID Namespace ====="
docker run --rm alpine:3.20 sh -c 'echo "PID=$$"; ps; echo COMM=$(cat /proc/1/comm)'

echo "===== 실습 2 UTS Namespace ====="
docker run --rm --hostname study-container alpine:3.20 hostname
echo "[host hostname] $(hostname)"

echo "===== 실습 3 Network Namespace ====="
docker run --rm alpine:3.20 sh -c 'echo "[route]"; cat /proc/net/route; echo "[resolv]"; cat /etc/resolv.conf; echo "[addr]"; ip addr 2>/dev/null || cat /proc/net/dev'

echo "===== cgroup memory.max ====="
MEM=$(docker run --rm --memory=128m alpine:3.20 cat /sys/fs/cgroup/memory.max)
echo "memory.max=$MEM"
if [ "$MEM" = "134217728" ]; then
  pass "memory.max 128MiB"
else
  fail "memory.max expected 134217728 got $MEM"
fi

echo "===== cgroup cpu.max ====="
CPU=$(docker run --rm --cpus=0.5 alpine:3.20 cat /sys/fs/cgroup/cpu.max)
echo "cpu.max=$CPU"
read -r QUOTA PERIOD <<< "$CPU"
if [ $((QUOTA * 2)) -eq "$PERIOD" ]; then
  pass "cpu quota 0.5"
else
  fail "cpu.max quota*2 != period ($CPU)"
fi

echo "===== resource-lab stats ====="
docker rm -f resource-lab >/dev/null 2>&1 || true
docker run -d --name resource-lab --memory=128m --cpus=0.5 alpine:3.20 sleep 300 >/dev/null
docker stats --no-stream resource-lab
echo "HostConfig.Memory=$(docker inspect resource-lab --format '{{.HostConfig.Memory}}')"
echo "HostConfig.NanoCpus=$(docker inspect resource-lab --format '{{.HostConfig.NanoCpus}}')"
docker rm -f resource-lab >/dev/null

echo "===== image alpine:3.20 ====="
docker image ls alpine:3.20
docker image inspect alpine:3.20 --format 'Id={{.Id}} Os={{.Os}} Arch={{.Architecture}} Size={{.Size}}'
echo "Layers:"
docker image inspect alpine:3.20 --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}'
docker history alpine:3.20

echo "===== build study-api:1.0 ====="
if docker build -t study-api:1.0 "$ROOT/fundamentals"; then
  pass "docker build study-api:1.0"
else
  fail "docker build study-api:1.0"
fi
docker image inspect study-api:1.0 --format 'User={{.Config.User}} Cmd={{json .Config.Cmd}} Exposed={{json .Config.ExposedPorts}}'
docker history study-api:1.0

echo "===== publish 없이 실행 ====="
docker rm -f study-api >/dev/null 2>&1 || true
docker run -d --name study-api study-api:1.0 >/dev/null
sleep 1
echo "docker port:"; docker port study-api || true
if curl -fsS --max-time 3 http://127.0.0.1:8081/health; then
  fail "unpublished port answered on 8081"
else
  echo "curl_unpublished_exit=$?"
  pass "EXPOSE alone does not publish 8081"
fi
docker rm -f study-api >/dev/null

echo "===== 127.0.0.1:8081 로 게시 (8080은 kind) ====="
docker run -d --name study-api -p 127.0.0.1:8081:8080 study-api:1.0 >/dev/null
HEALTH=""
for _ in $(seq 1 20); do
  if HEALTH=$(curl -fsS --max-time 2 http://127.0.0.1:8081/health); then
    break
  fi
  sleep 1
done
echo "health=$HEALTH"
echo "$HEALTH" | grep -q '"status": "ok"' && pass "GET /health" || fail "GET /health ($HEALTH)"
echo "----- logs -----"
docker logs study-api
echo "----- id -----"
docker exec study-api id
echo "----- lifecycle -----"
echo "before_stop=$(docker inspect study-api --format '{{.State.Status}}')"
docker stop study-api >/dev/null
echo "after_stop=$(docker inspect study-api --format '{{.State.Status}}')"
docker start study-api >/dev/null
echo "after_start=$(docker inspect study-api --format '{{.State.Status}}')"
docker logs --tail 20 study-api
echo "ports=$(docker port study-api)"
docker rm -f study-api >/dev/null

echo "===== 8080 포트 충돌 (kind 유지) ====="
if docker run --rm -p 127.0.0.1:8080:80 alpine:3.20 sleep 2; then
  fail "8080 publish unexpectedly succeeded"
else
  echo "port_conflict_exit=$?"
  pass "8080 already allocated, kind left running"
fi
echo "----- lsof 8080 -----"
lsof -nP -iTCP:8080 -sTCP:LISTEN || true

echo "===== fundamentals compose ====="
cd "$ROOT/fundamentals"
docker compose config
if docker compose up -d --build; then
  pass "compose up"
else
  fail "compose up"
fi
CID=""
HSTATUS=""
for _ in $(seq 1 40); do
  CID=$(docker compose ps -q api || true)
  if [ -n "$CID" ]; then
    HSTATUS=$(docker inspect "$CID" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}')
    echo "compose_health=$HSTATUS"
    [ "$HSTATUS" = "healthy" ] && break
  fi
  sleep 1
done
COMPOSE_BODY=""
if COMPOSE_BODY=$(curl -fsS --max-time 3 http://127.0.0.1:8081/health); then
  echo "compose_health_body=$COMPOSE_BODY"
  pass "compose /health"
else
  echo "compose_curl_exit=$?"
  fail "compose /health"
fi
docker compose ps
docker compose logs --tail 20
if [ -n "$CID" ]; then
  docker inspect "$CID" --format 'Status={{.State.Status}} OOM={{.State.OOMKilled}} Exit={{.State.ExitCode}} Health={{if .State.Health}}{{.State.Health.Status}}{{end}}'
fi
docker compose down
cd "$ROOT"

echo "===== named volume ====="
docker volume rm study-data >/dev/null 2>&1 || true
docker volume create study-data
docker run --rm -v study-data:/data alpine:3.20 sh -c 'echo persistent > /data/test.txt'
VOL_TEXT=$(docker run --rm -v study-data:/data alpine:3.20 cat /data/test.txt)
echo "volume_text=$VOL_TEXT"
[ "$VOL_TEXT" = "persistent" ] && pass "named volume" || fail "named volume ($VOL_TEXT)"
docker volume rm study-data >/dev/null

echo "===== bind mount readonly ====="
echo "hello host" > "$ROOT/shared/message.txt"
BIND_TEXT=$(docker run --rm \
  --mount type=bind,source="$ROOT/shared",target=/shared,readonly \
  alpine:3.20 cat /shared/message.txt)
echo "bind_text=$BIND_TEXT"
[ "$BIND_TEXT" = "hello host" ] && pass "bind mount read" || fail "bind mount read"
if docker run --rm \
  --mount type=bind,source="$ROOT/shared",target=/shared,readonly \
  alpine:3.20 sh -c 'echo mutated > /shared/message.txt'; then
  fail "readonly bind allowed a write"
else
  echo "readonly_bind_exit=$?"
  pass "readonly bind rejected write"
fi
echo "host file still: $(cat "$ROOT/shared/message.txt")"

echo "===== bridge DNS ====="
docker rm -f server-a >/dev/null 2>&1 || true
docker network rm study-net isolated-net >/dev/null 2>&1 || true
docker network create study-net >/dev/null
docker run -d --name server-a --network study-net alpine:3.20 sleep 300 >/dev/null
if docker run --rm --network study-net alpine:3.20 ping -c 2 server-a; then
  pass "same-network DNS ping"
else
  fail "same-network DNS ping"
fi
echo "----- study-net containers -----"
docker network inspect study-net --format '{{range $id, $c := .Containers}}{{$c.Name}} {{$c.IPv4Address}}{{"\n"}}{{end}}'
echo "----- name resolves, TCP port closed -----"
docker run --rm --network study-net alpine:3.20 wget -q -O- -T 2 http://server-a:9/ || echo "wget_closed_port_exit=$?"
docker network create isolated-net >/dev/null
if docker run --rm --network isolated-net alpine:3.20 ping -c 1 server-a; then
  fail "cross-network name should not resolve"
else
  echo "cross_network_exit=$?"
  pass "cross-network DNS failed"
fi
docker rm -f server-a >/dev/null
docker network rm study-net isolated-net >/dev/null

echo "===== non-root and read-only ====="
docker run --rm study-api:1.0 id
if docker run --rm \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  alpine:3.20 sh -c 'id; touch /blocked.txt'; then
  fail "read-only root allowed touch"
else
  echo "readonly_root_exit=$?"
  pass "read-only root blocked touch"
fi

echo "===== connection refused (nothing on 8099) ====="
if curl -fsS --max-time 2 http://127.0.0.1:8099/health; then
  fail "8099 unexpectedly answered"
else
  echo "curl_8099_exit=$?"
  pass "connection refused on unused 8099"
fi

echo "===== OOM 실험 (32MiB) ====="
docker rm -f oom-lab >/dev/null 2>&1 || true
docker run -d --name oom-lab --memory=32m --memory-swap=32m python:3.12-slim \
  python -c 'b=bytearray(64*1024*1024); print(len(b), flush=True)' >/dev/null
for _ in $(seq 1 20); do
  ST=$(docker inspect oom-lab --format '{{.State.Status}}')
  [ "$ST" != "running" ] && break
  sleep 1
done
docker inspect oom-lab --format 'Status={{.State.Status}} OOM={{.State.OOMKilled}} Exit={{.State.ExitCode}} Error={{.State.Error}}'
echo "----- oom logs -----"
docker logs oom-lab || true
docker rm -f oom-lab >/dev/null

echo "===== PoC 1 ====="
cd "$ROOT/poc1"
chmod +x test-isolation.sh
if ./test-isolation.sh; then
  pass "PoC1"
else
  fail "PoC1"
fi

echo "===== PoC 2 ====="
cd "$ROOT/poc2"
chmod +x test.sh
if ./test.sh; then
  pass "PoC2"
else
  fail "PoC2"
fi
echo "----- volume remains after compose down -----"
docker compose down
docker volume ls --filter name=poc2_app-data
echo "----- read volume after container is gone -----"
docker run --rm -v poc2_app-data:/data alpine:3.20 cat /data/message.txt || echo "volume_read_exit=$?"
echo "----- compose down -v removes it -----"
docker compose down -v
docker volume ls --filter name=poc2_app-data

echo "===== PoC 3 ====="
cd "$ROOT/poc3"
chmod +x test-recovery.sh
if ./test-recovery.sh; then
  pass "PoC3"
else
  fail "PoC3"
fi
docker compose down

echo "===== git (실행하지 않음) ====="
if git -C "$HOME/linux-lab" rev-parse --is-inside-work-tree; then
  echo "repo=yes"
else
  echo "repo=no exit=$?"
fi

echo "===== 정리 확인 ====="
echo "----- our names -----"
docker ps -a --format '{{.Names}}' | grep -E '^(study-api|isolation-poc|resource-lab|server-a|oom-lab|fundamentals-api-1|poc2-api-1|poc3-worker-1)$' || echo "no lab containers"
echo "----- kind still up -----"
docker ps --filter name=gitops-lab-control-plane --format '{{.Names}} {{.Status}} {{.Ports}}'
echo "FAILS=$FAILS"
if [ "$FAILS" -ne 0 ]; then
  exit 1
fi
echo "ALL LAB CHECKS PASSED"
