# Terraform — 실행 기록

2026-10-29, Mac, `~/linux-lab/Terraform`. 로컬 파일과 정적 검증만 했다. VPC나 EC2는 만들지 않았다.

## 한 줄로 보는 동작

```text
terraform init
  └─ Provider 다운로드, Backend 초기화
terraform validate
  └─ HCL과 Provider 스키마 검사
terraform plan
  └─ 코드 + State + 실제 객체 조회 후 변경 계획
terraform apply
  └─ Provider가 실제 객체를 바꾸고 State를 갱신
```

명령으로 생성 순서를 하나씩 적는 방식이 아니다. 원하는 최종 상태를 적으면 Terraform이 필요한 작업을 계산한다. State는 실행 로그가 아니라, `local_file.study` 같은 주소와 실제 객체를 잇는 관리 정보다.

## 도구

| 도구 | 결과 |
|---|---|
| terraform | v1.17.0, darwin_arm64, `/opt/homebrew/bin/terraform` |
| local provider | hashicorp/local v2.9.1, HashiCorp 서명 |
| aws provider | hashicorp/aws v6.70.0, HashiCorp 서명. `poc3-aws`에서만 초기화 |
| aws sts | `NoCredentials`, exit 253. `aws configure`는 하지 않음 |
| jq / python3 | PoC 1의 plan JSON, PoC 3의 CIDR 검사 |

## 파일

| 파일 | 내용 |
|---|---|
| [01-기초.md](01-기초.md) | HCL, Provider, Resource, 첫 apply |
| [02-중급.md](02-중급.md) | Variable, Local, Output, Data, State, Plan, Module |
| [03-심화.md](03-심화.md) | Backend, Drift, Lifecycle, Import, 보안 |
| [04-poc.md](04-poc.md) | PoC 1·2·3 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

첫 실행 원문은 `Terraform/logs/lab-run.log`다. 그 로그는 `FAILS=3`으로 끝난다. 이후 고친 PoC 2의 State와 PoC 3 재검증은 `Terraform/logs/recheck.log`에 있다.

## 복습 정답

1. State의 역할은 Terraform 리소스 주소와 실제 객체의 연결을 관리하는 것이다. 요금 계산, 이미지 빌드, 사용자 인증이 아니다.
2. `terraform plan`은 필요한 변경을 계산해서 보여 준다. 그 명령만으로 리소스가 생기지는 않는다.
3. 이미 있는 객체를 관리 대상으로 등록하는 명령은 `terraform import`다.

## 체크리스트

| 항목 | 상태 |
|---|---|
| CLI 설치·버전 | 통과. 이미 v1.17.0. 재설치하지 않음 |
| HCL·Provider·Resource | `local_file.study` 생성. id `ae9c7cc6581fe6b7a01af3ee5fa123a4afc9bac1` |
| Variable·Local·Output·Data | `-var`가 `TF_VAR_`보다 우선. Data Source가 같은 파일을 읽음 |
| init·validate·plan·apply | fundamentals, modular, PoC 1에서 실행 |
| State·그래프 | `terraform state list`에 주소가 남음. `data.local_file.existing -> local_file.study` |
| Module | `api_config` name `study-api`, port `8080`. 리소스 0개 |
| Backend·잠금 | 로컬 `terraform.tfstate`만 사용. S3 Backend는 초기화하지 않음 |
| Drift 복구 | fundamentals 파일과 PoC 1 모두 `environment=dev` / `Hello, Terraform!`로 복구 |
| Lifecycle | `ignore_changes`는 계획 없음. `prevent_destroy`는 destroy 계획을 exit 1로 막음 |
| Import | `local_file`과 `null_resource`는 미구현. `terraform_data` Import 통과 |
| 비밀값·State | HCL에 키를 넣지 않음. State·Plan은 `.gitignore` 대상. Git 저장소는 아님 |
| PoC 1 | `PASS: drift detected and repaired` |
| PoC 2 | `PASS: import and module output verified`. 교재의 `local_file` Import는 실패 후 대체 |
| PoC 3 | 첫 `validate`는 플러그인 시작 시간 초과. 재실행은 `Success!`와 `PASS: CIDR design`. State 없음 |
| 비용 | AWS `plan`/`apply` 없음. 만든 AWS 리소스 없음 |
| Git commit·push | 하지 않음. `~/linux-lab`는 Git 저장소가 아니고 원격도 없다 |

다음 학습으로 교재는 Kubernetes를 적었다. 이번 작업에는 포함하지 않았다.
