# Docker

Mac의 Docker Desktop에서 실행한 학습이다. 코드는 이 폴더에 있고, 실행 결과와 트러블슈팅은 [학습기록](학습기록/README.md)에 있다.

| 경로 | 내용 |
|---|---|
| `fundamentals/` | 비루트 HTTP API, Dockerfile, Compose |
| `poc1/test-isolation.sh` | PID, 호스트 이름, CPU·메모리 제한 |
| `poc2/` | 볼륨에 남기는 메시지 API |
| `poc3/` | 프로세스 종료 후 재시작 |
| `scripts/run-lab.sh` | 기초부터 PoC까지 한 번에 실행 |
| `logs/lab-run.log` | 그 실행의 원문 |
| `shared/message.txt` | 읽기 전용 바인드 마운트 확인용 |

호스트 8080은 kind 노드 `gitops-lab-control-plane`이 쓰고 있어서, 이 학습의 API는 `127.0.0.1:8081`에 붙였다. PoC 2는 교재대로 `127.0.0.1:8082`다. 기존 컨테이너는 중지하지 않았고, 학습용 컨테이너·네트워크·볼륨은 확인 후 지웠다.
