# 4. PoC 세 개

각 PoC는 `~/linux-lab/Docker` 아래의 독립 디렉터리다. 교재의 `~/docker-study` 대신 주제 폴더에 두었다. 세 테스트가 끝난 뒤 컨테이너, 학습용 네트워크, 학습용 볼륨은 지웠다.

## PoC 1. Namespace와 cgroup

`poc1/test-isolation.sh`는 `isolation-poc`라는 alpine 컨테이너를 호스트 이름 `isolated-host`, 메모리 128m, CPU 0.5로 띄운다. 끝나면 `docker rm -f` 한다.

```text
[1] PID Namespace
PASS: PID 1 is sleep
[2] UTS Namespace
PASS: hostname isolated
[3] Memory cgroup
PASS: memory=128MiB
[4] CPU cgroup
cpu.max=50000 100000
PASS: CPU quota=0.5
ALL TESTS PASSED
```

기초 실험의 PID 1은 셸이었고, 여기서는 `sleep`이 PID 1이다. 메모리 파일은 `134217728`, CPU는 주기 100000 중 50000이다.

## PoC 2. 볼륨에 남는 API

교재의 `app.py`는 `do_POST` 안의 `try:`에서 잘려 있었다. 잘린 부분을 이어서, JSON의 `message` 문자열을 `/data/message.txt`에 쓰고 `{"saved": true}`를 반환하게 했다. 4096바이트를 넘으면 413, JSON이 아니면 400이다.

이미지는 uid 10001이 `/data`를 소유한다. Compose는 `127.0.0.1:8082:8080`과 볼륨 `app-data`를 쓴다.

```text
[3] Save message
{"saved": true}
[5] Verify persisted data
{"message": "persistent-data"}
PASS: data survived container recreation
```

`docker compose up -d --force-recreate`로 컨테이너를 다시 만든 뒤에도 같은 문자열이었다. 기동 직후 curl이 한 번 exit 52였고, 준비된 다음 요청은 성공했다.

`docker compose down` 다음에는 컨테이너가 없어도 볼륨이 남았다.

```text
DRIVER    VOLUME NAME
local     poc2_app-data
persistent-data
```

`docker compose down -v` 다음에 그 볼륨은 목록에서 사라졌다. 데이터를 지우는 명령과 컨테이너만 지우는 명령을 구분해서 썼다.

## PoC 3. 프로세스가 죽은 뒤의 재시작

`poc3` 워커는 2초마다 `heartbeat`를 찍고, SIGTERM이면 로그를 남긴 뒤 정상 종료한다. Compose는 `restart: unless-stopped`, 메모리 128m, CPU 0.5다.

교재대로 다른 프로세스에서 PID 1에 SIGKILL을 보낸 실행은 재시작되지 않았다. 같은 PID Namespace 안에서는 SIGKILL이 init인 PID 1에 전달되지 않는다. 자세한 경위는 [troubleshooting.md](troubleshooting.md)에 있다.

수정한 워커는 SIGUSR1을 받으면 스스로 `os._exit(137)` 한다. 테스트는 그 신호를 보낸다.

```text
Restart count before: 0
[1] Inject process failure
[2] Wait for restart
Restart count after: 1
worker-1  | Worker started PID=1
worker-1  | heartbeat
worker-1  | Crashing on signal: 10
worker-1  | Worker started PID=1
worker-1  | heartbeat
PASS: worker restarted after crash
```

10은 Linux의 SIGUSR1이다. 재시작 뒤 `inspect`는 `Running=true Restart=1 OOM=false`였다. `Exit=0`은 새로 뜬 프로세스가 아직 살아 있어서 나온 현재 상태다. 죽은 시점의 코드는 로그의 crash 줄로 확인했다.

`unless-stopped`는 프로세스가 끝난 컨테이너를 다시 실행한다. 애플리케이션이 잘못된 데이터를 고치지는 않는다. 확인 후 `docker compose down`으로 `poc3-worker-1`과 `poc3_default`를 지웠다.

## Git

교재의 `git init`, `git commit`, `git push`는 실행하지 않았다. `git rev-parse`는 `fatal: not a git repository`, exit 128이다. 원격도 없다.
