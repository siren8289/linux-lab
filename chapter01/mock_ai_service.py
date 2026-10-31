#!/usr/bin/env python3
"""
가상 AI 챗봇 서비스 데몬 (Mock AI Service)
Chapter 01 실습 04 - 프로세스 라이프사이클 및 시그널(SIGTERM) 정상 종료 실습용
"""
import os
import signal
import sys
import time

def sigterm_handler(signum, frame):
    """
    SIGTERM(15) 정상 종료 시그널 핸들러
    - 강제 종료(SIGKILL 9)와 달리, 데이터 저장 및 리소스 정리(Graceful Shutdown) 기회를 가짐
    """
    pid = os.getpid()
    print(f"\n[AI Service PID: {pid}] SIGTERM(15) 수신: Graceful Shutdown(정상 정리 작업) 시작...")
    time.sleep(0.5)  # 정리 작업 시뮬레이션
    print(f"[AI Service PID: {pid}] 모든 활성 연결 종료 및 로그 플러시 완료.")
    print(f"[AI Service PID: {pid}] 안전하게 종료되었습니다 (Exit Code 0).")
    sys.exit(0)

# SIGTERM 시그널 등록
signal.signal(signal.SIGTERM, sigterm_handler)

def main():
    pid = os.getpid()
    ppid = os.getppid()
    print(f"==================================================")
    print(f"  AI 챗봇 모의 서비스 시작")
    print(f"  - PID (프로세스 ID): {pid}")
    print(f"  - PPID (부모 프로세스 ID): {ppid}")
    print(f"  - 종료 테스트: kill -TERM {pid}")
    print(f"==================================================")

    count = 1
    while True:
        print(f"[AI Service PID: {pid}] 상태: 정상 가동 중... (Heartbeat #{count})", flush=True)
        count += 1
        time.sleep(3)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n[AI Service] SIGINT (Ctrl+C) 수신: 즉시 중단합니다.")
        sys.exit(0)
