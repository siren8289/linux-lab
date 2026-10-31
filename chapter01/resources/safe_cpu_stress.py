#!/usr/bin/env python3
"""
안전한 CPU 부하 테스트 도구 (Safe CPU Stressor)
- Ubuntu VM 및 macOS 로컬 환경 모두에서 stress-ng 설치 없이 안전하게 1코어 부하를 재현합니다.
- 지정된 타임아웃(기본 15초) 후 스스로 안전하게 연산을 종료합니다.
"""
import argparse
import multiprocessing
import os
import time

def cpu_burner(end_time):
    # 타임아웃 시점까지 부동소수점 및 정수 연산 반복
    count = 0
    while time.time() < end_time:
        _ = 12345.6789 * 98765.4321
        count += 1

def main():
    parser = argparse.ArgumentParser(description="Safe CPU Stress Tool for Lab 06")
    parser.add_argument("--cpu", type=int, default=1, help="부하를 발생시킬 CPU 작업자 수 (기본 1)")
    parser.add_argument("--timeout", type=int, default=15, help="실행 시간(초) (기본 15s)")
    args = parser.parse_args()

    print(f"==================================================")
    print(f"  안전한 CPU 부하 테스트 시작")
    print(f"  - 작업자 수 (Worker): {args.cpu}개")
    print(f"  - 제한 시간 (Timeout): {args.timeout}초")
    print(f"  - 프로세스 PID: {os.getpid()}")
    print(f"==================================================")

    end_time = time.time() + args.timeout
    processes = []

    for i in range(args.cpu):
        p = multiprocessing.Process(target=cpu_burner, args=(end_time,))
        p.start()
        processes.append(p)
        print(f"-> Worker #{i+1} 가동 (Worker PID: {p.pid})")

    print(f"-> {args.timeout}초 동안 CPU 부하 유지 중... (ps 및 top으로 확인 가능)")

    for p in processes:
        p.join()

    print(f"✅ [완료] {args.timeout}초가 경과하여 모든 CPU 부하 작업이 안전하게 정상 종료되었습니다.")

if __name__ == "__main__":
    main()
