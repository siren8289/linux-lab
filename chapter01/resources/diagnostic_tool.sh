#!/usr/bin/env bash
# ==============================================================================
# Chapter 01 · 실습 06 — 시스템 4대 핵심 자원(CPU/메모리/디스크/네트워크) 종합 진단 스크립트
# 지원 환경: Linux (Ubuntu/Debian/CentOS) 및 macOS (Darwin)
# ==============================================================================

set -u

echo "=================================================="
echo " [시스템 종합 리소스 진단 보고서 (Diagnostic Report)]"
echo " 측정 일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo " 호스트명: $(hostname)"
echo " 운영체제: $(uname -s) $(uname -r) ($(uname -m))"
echo "=================================================="

echo "\n[1] CPU 자원 및 부하 상태 (Load Average & CPU Spec)"
echo "--------------------------------------------------"
if command -v nproc > /dev/null 2>&1; then
    echo "CPU 논리 코어 수: $(nproc)"
elif command -v sysctl > /dev/null 2>&1; then
    echo "CPU 논리 코어 수: $(sysctl -n hw.ncpu 2>/dev/null || echo 'Unknown')"
fi
uptime

echo "\n-> CPU 점유율 상위 5개 프로세스:"
ps -eo pid,pcpu,pmem,comm | sort -k2 -r -n | head -6

echo "\n[2] 메모리 점유 및 스왑 상태 (RAM & Swap)"
echo "--------------------------------------------------"
if command -v free > /dev/null 2>&1; then
    free -h
else
    echo "macOS Mach VM 통계:"
    vm_stat | head -8
fi

echo "\n-> 메모리 점유율 상위 5개 프로세스:"
ps -eo pid,pmem,pcpu,comm | sort -k2 -r -n | head -6

echo "\n-> OOM(Out Of Memory) 킬러 발생 이력 점검:"
if command -v journalctl > /dev/null 2>&1; then
    OOM_LOGS=$(sudo journalctl -k -b 2>/dev/null | grep -i -E 'oom|out of memory|killed process' | tail -5 || true)
    if [ -n "$OOM_LOGS" ]; then
        echo "⚠️ OOM 경고 발견:\n$OOM_LOGS"
    else
        echo "✅ 최근 OOM 킬러 발동 이력 없음 (정상)"
    fi
elif [ -f /var/log/system.log ]; then
    OOM_LOGS=$(grep -i "out of memory" /var/log/system.log 2>/dev/null | tail -5 || true)
    if [ -n "$OOM_LOGS" ]; then
        echo "⚠️ OOM 로그:\n$OOM_LOGS"
    else
        echo "✅ 최근 OOM 관련 로그 없음 (정상)"
    fi
else
    echo "✅ 커널 로그 상 특이 OOM 감지 안 됨"
fi

echo "\n[3] 디스크 용량 및 inode 상태 (Disk Space & Inode)"
echo "--------------------------------------------------"
echo "-> 파일시스템 용량 (df -h):"
df -h .

echo "\n-> Inode 사용량 (df -i):"
df -i .

echo "\n-> 현재 실습 디렉터리 사용 용량 (du -sh):"
du -sh .

echo "\n[4] 네트워크 소켓 및 서비스 포트 상태 (Network Ports)"
echo "--------------------------------------------------"
if command -v ss > /dev/null 2>&1; then
    echo "-> LISTEN 포트 현황 (ss -tulpn):"
    ss -tulpn | head -10
elif command -v netstat > /dev/null 2>&1; then
    echo "-> LISTEN 포트 현황 (netstat -an | grep LISTEN):"
    netstat -an | grep LISTEN | head -10
fi

echo "\n=================================================="
echo "✅ 종합 자원 진단 완료"
echo "=================================================="
