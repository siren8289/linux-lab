# Terraform

Mac에서 실행한 학습이다. AWS 계정에 리소스를 만들지 않았다. 코드는 이 폴더에 있고, 실행 결과와 트러블슈팅은 [학습기록](학습기록/README.md)에 있다.

| 경로 | 내용 |
|---|---|
| `fundamentals/` | `local_file` 생성, 변수, Data Source, Drift 복구 |
| `modular/` | 입력과 출력만 있는 모듈. 외부 리소스 0개 |
| `lifecycle/` | `prevent_destroy`와 `ignore_changes` 예시. 적용했던 파일은 삭제 후 구성만 남김 |
| `poc1-drift/` | 파일 생성, 수동 수정 탐지, 선언한 내용으로 복구 |
| `poc2-import/` | 기존 파일 경로를 `terraform_data`로 Import하고 모듈이 내용을 읽음 |
| `poc3-aws/` | VPC·서브넷·라우트·보안 그룹·EC2 구성의 정적 검증. `plan`과 `apply`는 실행하지 않음 |
| `scripts/run-lab.sh` | 기초부터 PoC까지 한 번에 실행 |
| `logs/lab-run.log` | 첫 전체 실행의 원문. 끝은 `FAILS=3` |
| `logs/recheck.log` | 이후 PoC 2 출력 확인과 PoC 3 재검증 |

Terraform CLI는 이미 `v1.17.0` (`darwin_arm64`)이었다. `brew install`은 다시 하지 않았다. `hashicorp/local`은 `2.9.1`, `hashicorp/aws`는 `6.70.0`이다. AWS 자격 증명은 없고 `aws sts get-caller-identity`는 `NoCredentials`, exit 253이었다.
