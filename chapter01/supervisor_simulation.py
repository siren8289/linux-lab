#!/usr/bin/env python3
"""
systemd Restart=on-failure 시뮬레이터 (macOS 및 로컬 실습용)
- macOS에는 systemd가 없으므로, systemd의 프로세스 감시 및 자동 재시작 알고리즘을 파이썬으로 구현하여
  로컬 맥북에서도 동일한 장애 복구 원리를 직접 관찰할 수 있도록 지원합니다.
"""
import os
import signal
import subprocess
import sys
import time

TARGET_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app.py")
RESTART_SEC = 5

def run_supervisor():
    print("=" * 60)
    print(" [systemd Supervisor Simulation Mode]")
    print(f" - 감시 대상: {TARGET_SCRIPT}")
    print(f" - 복구 정책: Restart=on-failure (대기 시간: {RESTART_SEC}초)")
    print(f" - 테스트 방법: 다른 터미널에서 'kill -9 <PID>' 실행")
    print(f" - 시뮬레이터 종료: Ctrl + C")
    print("=" * 60)

    restart_count = 0

    while True:
        # 자식 프로세스로 AI 데몬 실행 (ExecStart 시뮬레이션)
        proc = subprocess.Popen([sys.executable, TARGET_SCRIPT])
        child_pid = proc.pid
        print(f"\n[Supervisor] 서비스 프로세스 기동 완료 (PID: {child_pid})")
        
        try:
            # 자식 프로세스 상태 감시
            retcode = proc.wait()
            
            # 정상 종료(0)인 경우: Restart=on-failure 정책에 따라 재시작하지 않음
            if retcode == 0:
                print(f"[Supervisor] 프로세스(PID: {child_pid})가 정상 종료(Exit 0)되었습니다. 자동 재시작 안 함.")
                break
            else:
                # 비정상 종료 (SIGKILL 등 음수 또는 0이 아닌 반환값)
                restart_count += 1
                sig_name = f"Signal {-retcode}" if retcode < 0 else f"Exit code {retcode}"
                print(f"\n⚠️ [Supervisor 경고] 비정상 종료 감지! (원인: {sig_name})")
                print(f"🔄 [Supervisor] RestartSec={RESTART_SEC}s 대기 후 자동 재시작을 준비합니다... (재시작 횟수: #{restart_count})")
                time.sleep(RESTART_SEC)
                print(f"🚀 [Supervisor] 서비스 자동 복구 시작!")
        except KeyboardInterrupt:
            print("\n[Supervisor] 종료 신호 수신. 자식 프로세스를 정리합니다...")
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
            print("[Supervisor] 정리 완료. 시뮬레이터를 종료합니다.")
            break

if __name__ == "__main__":
    run_supervisor()
