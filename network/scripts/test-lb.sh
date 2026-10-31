#!/usr/bin/env bash
# ~/linux-lab/네트워크/scripts/test-lb.sh
set -euo pipefail

URL="http://127.0.0.1:8088"
RESULT=$(mktemp)
trap 'rm -f "$RESULT"' EXIT

for i in $(seq 1 10); do
    curl -fsS --max-time 3 "$URL" >> "$RESULT"
done

echo "[Response count]"
sort "$RESULT" | uniq -c

grep -q "Backend A" "$RESULT"
grep -q "Backend B" "$RESULT"

echo "PASS: Both backends responded"
