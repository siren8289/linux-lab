# 트러블슈팅

## Mac에는 systemctl이 없다

Problem: 교재의 `systemctl status docker`를 실행했다.

해결한 방법: 설치되어 있지 않음을 확인하고, Engine 확인은 `docker version`, `docker info`, `docker run --rm hello-world`로 했다. Docker Desktop을 다시 설치하지 않았다.

Result: `systemctl`은 exit 127 `command not found`. hello-world는 `Hello from Docker!`까지 출력했다. 엔진 커널은 `6.12.76-linuxkit`, cgroup은 v2다.

## 8080은 이미 kind가 쓴다

Problem: 교재는 API를 `127.0.0.1:8080`에 게시한다. 그 포트에는 `gitops-lab-control-plane`이 떠 있다.

해결한 방법: 충돌을 한 번 재현만 하고 kind는 멈추지 않았다. fundamentals와 단독 `study-api`는 `127.0.0.1:8081`을 썼다. PoC 2는 교재의 8082를 유지했다.

Result: `docker run -p 127.0.0.1:8080:80`은 exit 125, `Bind for 127.0.0.1:8080 failed: port is already allocated`. `lsof`의 수신 프로세스는 `com.docke` PID 73397이다. 8081의 `/health`는 `{"status": "ok", ...}`를 반환했다. 학습이 끝난 뒤에도 kind는 Up 상태였다.

## 막 띄운 포트에 curl하면 Empty reply

Problem: 포트를 게시한 직후 `curl`이 exit 52 `Empty reply from server`를 냈다. 프로세스가 없는 8099는 exit 7이었다.

해결한 방법: 앱이 `/health`에 응답할 때까지 짧은 간격으로 다시 요청했다. 게시만 된 포트와, 프로세스가 받기 시작한 포트를 구분했다.

Result: 몇 번의 exit 52 뒤에 `study-api`와 Compose, PoC 2 모두 HTTP 200이 되었다. 로그에 `GET /health` 200이 남았다.

## 컨테이너 안의 SIGKILL은 PID 1을 죽이지 못한다

Problem: PoC 3을 교재처럼 `os.kill(1, SIGKILL)`로 실행했다. `docker exec`는 exit 0이었는데 `RestartCount`는 0이었고 heartbeat가 계속됐다.

해결한 방법: `/proc/1`을 확인했다. 이름은 `python`, Pid 1, PPid 0이었다. Linux는 같은 PID Namespace의 다른 프로세스가 init에게 보내는 SIGKILL을 전달하지 않는다. 핸들러를 등록할 수 없는 신호라서 컨테이너 안에서는 사실상 버릴 수 있다. 호스트 네임스페이스에서의 `docker kill`로 바꾸지 않고, PID 1이 처리하도록 SIGUSR1 핸들러를 넣어 그 안에서 `os._exit(137)` 하게 했다. 테스트의 `|| true`는 exec가 컨테이너가 죽으며 0이 아닌 코드로 끝나도 스크립트가 멈추지 않게 둔 것이다.

같은 디버그에서 SIGTERM은 핸들러가 있어 전달됐다. 로그는 `Received signal: 15`, `Worker stopped`, 다시 `Worker started PID=1`이었고 RestartCount는 1이었다. 공식 테스트는 비정상 종료에 가깝게 SIGUSR1 경로를 사용했다.

Result: 수정 후 `Restart count before: 0`, `after: 1`, 로그에 `Crashing on signal: 10`과 두 번째 `Worker started PID=1`. 마지막 줄은 `PASS: worker restarted after crash`. 컨테이너와 `poc3_default` 네트워크는 삭제했다.

## 교재 app.py가 잘려 있다

Problem: PoC 2 본문의 `do_POST`가 `try:`에서 끝난다. 그대로는 저장 요청을 처리할 수 없다.

해결한 방법: 본문을 JSON으로 읽고 `message` 문자열만 `/data/message.txt`에 기록한 뒤 `{"saved": true}`를 반환하도록 구현을 마쳤다.

Result: POST 응답은 `{"saved": true}`. 컨테이너를 다시 만든 뒤 GET은 `{"message": "persistent-data"}`. `PASS: data survived container recreation`.

## down과 down -v

Problem: 볼륨 실험 뒤에 데이터를 남길지 지울지 명령이 갈린다.

해결한 방법: PoC 2 테스트가 끝난 뒤 먼저 `docker compose down`만 하고 볼륨을 읽었다. 기록한 다음에 `docker compose down -v`로 지웠다.

Result: down 직후 `poc2_app-data`가 남았고 내용은 `persistent-data`였다. down -v 뒤 볼륨 목록에서는 빠졌다. 다른 프로젝트의 볼륨은 지우지 않았다.

## Git 기록이 없다

Problem: 교재 17장은 `git init`과 커밋 세 개, 그리고 원격이 있으면 push를 한다.

해결한 방법: 저장소와 원격을 확인만 했다. `git init`과 commit, push는 하지 않았다.

Result: `git rev-parse --is-inside-work-tree`는 `fatal: not a git repository`, exit 128. 커밋 해시는 없다.
