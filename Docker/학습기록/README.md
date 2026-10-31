# Docker — 실행 기록

2026-10-29, Mac(Darwin 25.6.0, macOS 26.6.2), `~/linux-lab/Docker`. 이미지 빌드와 컨테이너 실행만 했고 유료 자원은 없다.

## 한 줄로 보는 구조

```text
Mac (Darwin 커널)
  └─ Docker Desktop의 Linux VM (Kernel 6.12.76-linuxkit)
       └─ 컨테이너들. 같은 Linux 커널을 공유하는 프로세스
            ├─ PID / UTS / Network Namespace
            ├─ cgroup v2 로 CPU·메모리 제한
            └─ OverlayFS 이미지 + 지워지는 Writable Layer
```

Mac 커널을 컨테이너가 직접 공유하지는 않는다. 공유되는 커널은 Docker Desktop Linux VM의 커널이다.

## 도구

| 도구 | 결과 |
|---|---|
| docker | Client 29.6.1 darwin/arm64, Engine 29.6.1 linux/arm64, Desktop 4.80.0 |
| compose | v5.3.0 |
| 엔진 | Cgroup 2, driver cgroupfs, storage overlayfs, CPU 6, 메모리 4108914688바이트 |
| hello-world | `Hello from Docker!` 까지 출력. PASS |
| systemctl | `command not found`, exit 127. Mac에는 Docker systemd 유닛이 없다 |

`brew install --cask docker`는 다시 하지 않았다. CLI와 Engine이 이미 동작했다.

## 파일

| 파일 | 내용 |
|---|---|
| [01-기초.md](01-기초.md) | VM과 컨테이너, Namespace, cgroup |
| [02-중급.md](02-중급.md) | 이미지, Dockerfile, 생명주기, 볼륨, 네트워크, Compose |
| [03-심화.md](03-심화.md) | 권한, 로그, 장애 재현 |
| [04-poc.md](04-poc.md) | PoC 1·2·3 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

원문 로그는 `Docker/logs/lab-run.log`다.

## 복습 정답

1. 컨테이너 안 PID 1과 호스트 PID가 다른 이유는 PID Namespace가 프로세스 ID 공간을 격리하기 때문이다.
2. 컨테이너를 지우고 다시 만들어도 데이터를 남기려면 Named Volume을 쓴다. `EXPOSE`나 `docker logs`는 데이터를 보존하지 않는다.
3. OOMKilled면 메모리 제한과 실제 사용량을 본다. 이번 실험은 `--memory=32m`에서 `OOM=true`, `Exit=137`이었다.

## 체크리스트

| 항목 | 상태 |
|---|---|
| Engine·CLI·hello-world | 통과. 재설치하지 않음 |
| Container와 VM | Mac은 Linux VM 안에서 커널을 공유 |
| PID·UTS·Network Namespace | 통과 |
| CPU·메모리 cgroup | `memory.max=134217728`, `cpu.max=50000 100000` |
| Image·Layer | alpine 파일 레이어 1개. `USER`/`EXPOSE`/`CMD`는 0B |
| Dockerfile 빌드·실행 | `study-api:1.0`, 호스트 포트 8081 |
| Volume·Bind Mount | `persistent`, `hello host`, 읽기 전용 쓰기는 거부 |
| Bridge·DNS | 같은 네트워크 ping 성공. 다른 네트워크는 `bad address` |
| Compose | `fundamentals-api-1` healthy, `/health` 200 |
| 비루트·read-only | uid 10001. `touch`는 Read-only file system |
| 로그·상태·리소스 | `docker logs`, `inspect`, `stats`, OOM 확인 |
| PoC 1 | `ALL TESTS PASSED` |
| PoC 2 | 재생성 후 `persistent-data` |
| PoC 3 | 컨테이너 안 SIGKILL은 무효. SIGUSR1로 자기 종료 후 RestartCount 1 |
| Git commit·push | 하지 않음. `~/linux-lab`는 Git 저장소가 아니고 원격도 없다 |

다음 학습으로 교재는 Terraform을 적었다. 이번 작업에는 포함하지 않았다.
