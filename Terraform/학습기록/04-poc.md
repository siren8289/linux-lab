# PoC 세 개

세 디렉터리는 따로 실행했다. AWS 리소스는 만들지 않았다.

| 프로젝트 | 완성 기준 | 결과 | 비용 |
|---|---|---|---|
| PoC 1 Drift | 파일 생성, 수동 수정 탐지, 선언 내용 복구 | 통과 | 0원 |
| PoC 2 Import·Module | 기존 파일을 State에 연결하고 모듈 출력으로 읽기 | 통과. `local_file` Import는 미구현이라 `terraform_data`로 바꿈 | 0원 |
| PoC 3 AWS 설계 | `fmt`, `init`, `validate`, CIDR 검사 | 첫 validate 실패 후 재실행 통과. `plan`/`apply` 없음 | 0원 |

## PoC 1 — State와 Drift

`poc1-drift/main.tf`는 `local_file.config`에 `environment=${var.environment}`를 쓴다. 기본값은 `dev`다.

`./test.sh` 결과의 핵심:

```text
Success! The configuration is valid.
[1] Apply desired state
local_file.config: Creation complete after 1s [id=1685b7a32904c8d97e4170def7199024e268bfb3]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
[2] Inject drift
[3] Detect drift
# local_file.config will be created
Plan: 1 to add, 0 to change, 0 to destroy.
true
[4] Restore desired state
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
PASS: drift detected and repaired
```

`true`는 plan JSON에서 `local_file.config`의 action에 `create`가 있다는 jq 조건이다. `config.txt`는 다시 `environment=dev`다. `drift.tfplan`은 테스트 후 삭제했다.

의미: State에 있던 내용 SHA1과 디스크의 `environment=production`이 다르자, Provider는 재생성을 계획했고 apply가 선언한 `environment=dev`를 다시 썼다.

## PoC 2 — Module, Data Source, Import

교재는 `terraform import local_file.existing "$PWD/existing.txt"`를 실행한다. 첫 실행은 여기서 멈췄다.

```text
local_file.existing: Importing from ID "/Users/jeong-yelim/linux-lab/Terraform/poc2-import/existing.txt"...
Error: Resource Import Not Implemented
This resource does not support import.
FAIL: PoC2
```

실패한 Import는 State를 만들지 않았다. `hashicorp/null`의 `null_resource`로 바꿔도 같은 `Resource Import Not Implemented`였다. 그 Provider는 구성에서 뺐고, 다음 `init`이 lock에서 null을 제거했다.

동작하는 구성은 빈 코어 리소스다.

```hcl
resource "terraform_data" "existing" {}
```

Import ID는 `existing.txt`의 절대 경로다. 모듈 `modules/file-reader`는 그 경로를 `data.local_file`로 읽어서 `content`를 출력한다.

통과 후 State를 다시 읽은 결과 (`logs/recheck.log`):

```text
terraform_data.existing
module.reader.data.local_file.input
imported_content = managed-by-terraform
imported_id = "/Users/jeong-yelim/linux-lab/Terraform/poc2-import/existing.txt"
```

Data Source ID는 내용 SHA1 `2a4939f0f55936554da25b67e1d58a490d657f8e`다. 테스트의 plan JSON은 `terraform_data.existing`의 action이 `["no-op"]`일 때 통과했고, apply는 `0 added, 0 changed, 0 destroyed`였다. 마지막 줄은 `PASS: import and module output verified`다.

이 통과는 “기존 파일 리소스를 `local_file`로 가져왔다”가 아니다. 파일 경로를 `terraform_data`의 ID로 State에 연결하고, 모듈이 그 파일을 읽은 것이다. `terraform_data`를 나중에 destroy해도 그 리소스는 파일을 지우지 않는다. 이번 실습에서는 destroy하지 않았다.

테스트를 다시 실행하려면 State가 없는 디렉터리가 필요하다. 스크립트는 `terraform.tfstate`가 있으면 `Use a fresh directory for this PoC`로 끝난다. 현재 State는 증거로 남겨 두었다.

## PoC 3 — VPC·EC2를 코드로만 검증

리전 기본값은 `ap-northeast-2`다. AMI 기본값 `ami-00000000000000000`은 `^ami-[0-9a-f]{17}$` 형식만 통과하는 가짜 값이다. 이 값으로 EC2를 만들면 안 된다. `plan`과 `apply`는 실행하지 않았다.

구성의 참조는 `terraform graph`에 이렇게 나왔다.

```text
aws_instance.app -> aws_security_group.app
aws_instance.app -> aws_subnet.private
aws_internet_gateway.main -> aws_vpc.main
aws_route_table.public -> aws_internet_gateway.main
aws_route_table_association.public -> aws_route_table.public
aws_route_table_association.public -> aws_subnet.public
aws_security_group.app -> aws_vpc.main
aws_subnet.private -> aws_vpc.main
aws_subnet.public -> aws_vpc.main
aws_vpc_security_group_ingress_rule.http -> aws_security_group.app
```

설계 숫자:

| 객체 | 값 |
|---|---|
| VPC | `10.0.0.0/16`, DNS support·hostnames 켬 |
| Public subnet | `10.0.1.0/24`, `map_public_ip_on_launch = false` |
| Private subnet | `10.0.11.0/24`, 공인 IP 자동 할당 없음 |
| 라우트 | Public 라우트 테이블만 `0.0.0.0/0`을 Internet Gateway로 |
| EC2 | `t3.micro`, Private subnet, `associate_public_ip_address = false` |
| 보안 그룹 | `10.0.0.0/16`에서 TCP 8080 수신 |

Private subnet에는 라우트 테이블 연결이 없다. NAT Gateway도 없다. 그래서 이 최소 구성에는 그 인스턴스의 일반 인터넷 출구가 없다.

첫 `./test.sh`는 init으로 aws v6.70.0을 설치한 뒤 validate에서 실패했다.

```text
Error: Failed to load plugin schemas
timeout while waiting for plugin to start
FAIL: PoC3
```

그래프는 그 실패 뒤에도 나왔고, `terraform.tfstate`는 없었다. 같은 디렉터리에서 `terraform validate`를 다시 실행하면 `Success! The configuration is valid.`였다.

2026-10-29 재검증 (`logs/recheck.log`):

```text
- Reusing version 6.70.0 of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v6.70.0
Success! The configuration is valid.
PASS: CIDR design
PASS: Terraform static validation
poc3_no_state
```

Python 검사는 `10.0.1.0/24`와 `10.0.11.0/24`가 `10.0.0.0/16` 안이고 서로 겹치지 않음을 확인했다.

`terraform validate`는 스키마와 문법까지다. AMI가 그 리전에 있는지, IAM이 충분한지, 실제 생성 가능한지는 검사하지 않는다. init이 안내한 `terraform plan`은 실행하지 않았다. Provider가 AWS API를 부르면 자격 증명과 계정 조회가 생기기 때문이다.
