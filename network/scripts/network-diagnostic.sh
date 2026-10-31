#!/usr/bin/env bash
# ~/linux-lab/네트워크/scripts/network-diagnostic.sh
# Records DNS, routing, TCP, and HTTP for a local service.
# Defaults match the lab (127.0.0.1:8080). HOST, PORT, and URL override them.
set -uo pipefail

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
URL="${URL:-http://${HOST}:${PORT}/}"
LOG="${LOG:-$HOME/linux-lab/네트워크/logs/network-diagnostic.log}"
mkdir -p "$(dirname "$LOG")"

exec > >(tee -a "$LOG") 2>&1

FAILED=0

if ts=$(date -Is 2>/dev/null); then
    echo "===== ${ts} ====="
else
    echo "===== $(date '+%Y-%m-%dT%H:%M:%S%z') ====="
fi
echo "Target: ${URL}"

echo "[DNS]"
if command -v getent >/dev/null 2>&1 && getent ahostsv4 localhost; then
    echo "DNS/Hosts: OK"
else
    if python3 - <<'PY'
import socket
import sys
try:
    rows = socket.getaddrinfo("localhost", None, socket.AF_INET, socket.SOCK_STREAM)
except OSError as error:
    print(f"DNS/Hosts: FAIL {error}")
    sys.exit(1)
ips = sorted({item[4][0] for item in rows})
for ip in ips:
    print(ip)
sys.exit(0 if ips else 1)
PY
    then
        echo "DNS/Hosts: OK"
    else
        echo "DNS/Hosts: FAIL"
        FAILED=1
    fi
fi

echo "[ROUTING]"
if command -v ip >/dev/null 2>&1; then
    ip route
else
    netstat -rn -f inet
fi

echo "[TCP PORT]"
if command -v timeout >/dev/null 2>&1; then
    if timeout 3 bash -c "echo > /dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
        echo "TCP: OK"
    else
        echo "TCP: FAIL"
        FAILED=1
    fi
elif python3 - "$HOST" "$PORT" <<'PY'
import socket
import sys
host, port = sys.argv[1], int(sys.argv[2])
try:
    socket.create_connection((host, port), 3).close()
except OSError as error:
    print(f"TCP detail: {error}", file=sys.stderr)
    sys.exit(1)
PY
then
    echo "TCP: OK"
else
    echo "TCP: FAIL"
    FAILED=1
fi

echo "[HTTP]"
if curl -fsS --max-time 3 "$URL" >/dev/null; then
    echo "HTTP: OK"
else
    echo "HTTP: FAIL"
    FAILED=1
fi

echo "[LISTENING PORTS]"
if command -v ss >/dev/null 2>&1; then
    ss -lnt
else
    echo "ss is not installed. Listeners on ${HOST}:${PORT}:"
    if ! lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN; then
        echo "nothing listening on TCP ${PORT}"
    fi
fi

echo "[RESULT]"
if (( FAILED == 0 )); then
    echo "PASS"
else
    echo "FAIL"
fi

exit "$FAILED"
