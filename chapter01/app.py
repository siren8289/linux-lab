#!/usr/bin/env python3
"""
Chapter 01 · 실습 05 - Python 모의 AI 서비스 (Heartbeat 데몬)
systemd의 Restart=on-failure 및 자동 장애 복구 실습용
"""
import logging
import os
import time

# 표준 로그 형식 지정 (타임스탬프, 로그레벨, 메시지)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

def main():
    pid = os.getpid()
    logging.info("AI demo service started. PID=%s", pid)
    
    count = 1
    while True:
        logging.info("AI demo service heartbeat #%d (PID: %d)", count, pid)
        count += 1
        time.sleep(5)

if __name__ == "__main__":
    main()
