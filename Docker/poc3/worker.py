import os
import signal
import time

running = True


def shutdown(signum, frame):
    global running
    print(f"Received signal: {signum}", flush=True)
    running = False


def crash(signum, frame):
    # PID 1이 스스로 종료해야 한다. 같은 PID Namespace의 다른 프로세스가
    # 보내는 SIGKILL은 커널이 버린다.
    print(f"Crashing on signal: {signum}", flush=True)
    os._exit(137)


signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGUSR1, crash)
print(f"Worker started PID={os.getpid()}", flush=True)
while running:
    print("heartbeat", flush=True)
    time.sleep(2)
print("Worker stopped", flush=True)
