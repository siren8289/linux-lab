# 트러블슈팅

## AWS 자격 증명이 없다

Problem: 교재의 오류표에는 `AccessDenied`와 `aws sts get-caller-identity`가 있다. 이 Mac에는 AWS 자격 증명이 없다.

해결한 방법: 호출만 하고 `aws configure`는 하지 않았다. AWS 리소스 생성, `poc3-aws`의 `plan`과 `apply`, S3 Backend 초기화를 하지 않았다.

Result: `An error occurred (NoCredentials): Unable to locate credentials. You can configure credentials by running "aws login".` exit 253. `poc3-aws`에는 `terraform.tfstate`가 없다.

## 첫 Drift 검사가 복구된 파일을 실패로 기록했다

Problem: fundamentals에서 수동 수정 뒤 apply는 `Hello, Terraform!`을 다시 썼다. 러너 마지막은 `FAIL: fundamentals drift repaired (Hello, Terraform!)`였다.

해결한 방법: `repaired:` 줄과 파일을 보았다. 내용은 기대와 같았다. 실패는 비교식이 `$(cat hello.txt)`와 `$'Hello, Terraform!\n'`를 비교해서 생겼다. 명령 치환은 끝의 줄바꿈을 지운다. 비교를 `Hello, Terraform!`로 바꿨다. PoC 2 교재의 `test "$VALUE" = "managed-by-terraform"$'\n'`도 같은 종류라서, 통과한 테스트는 Python `subprocess.check_output`으로 줄바꿈 바이트를 비교한다.

Result: 파일은 `b'Hello, Terraform!\n'`이고 `terraform output -raw file_content`도 같다. `logs/lab-run.log`의 그 FAIL은 첫 실행 기록으로 남아 있다. 비교를 고친 뒤 전체 `scripts/run-lab.sh`는 다시 실행하지 않았다. PoC 1은 별도 `grep -qx 'environment=dev'`로 통과했다.

## local_file Import가 구현되어 있지 않다

Problem: PoC 2 교재대로 `terraform import local_file.existing "$PWD/existing.txt"`를 실행했다.

해결한 방법: 오류를 확인했다. `hashicorp/local` v2.9.1은 이 리소스의 Import를 구현하지 않는다. `~> 2.5` 안에서 더 낮은 버전을 골라도 이 기능이 생기는 구조가 아니었다. 실패한 Import는 State를 쓰지 않았다. 이어서 `hashicorp/null` v3.3.2의 `null_resource`에 같은 경로를 Import ID로 넣었고, 같은 오류가 났다. null Provider는 구성에서 제거했다.

Result: 첫 로그의 PoC 2는 `Error: Resource Import Not Implemented`와 `FAIL: PoC2`다. 현재 `poc2-import/.terraform.lock.hcl`에는 `hashicorp/local` 2.9.1만 있다.

## Import는 terraform_data로 통과했다

Problem: 비용 없이 Import와 모듈 출력을 검증해야 하는데, 파일 Provider가 Import를 받지 않는다.

해결한 방법: Terraform 코어 리소스인 빈 `terraform_data.existing`을 두고, Import ID를 `existing.txt` 절대 경로로 했다. `input`을 넣으면 Import 뒤 plan이 값 갱신으로 나와서, no-op을 보려면 속성 없는 리소스여야 했다. 파일 내용은 모듈의 `data.local_file`이 읽게 했다. 테스트는 깨끗한 State에서 한 번 실행했다.

Result: State의 `imported_id`는 `/Users/jeong-yelim/linux-lab/Terraform/poc2-import/existing.txt`이고, `imported_content`는 `managed-by-terraform`과 줄바꿈이다. `terraform state list`는 `terraform_data.existing`와 `module.reader.data.local_file.input`이다. 테스트 마지막은 `PASS: import and module output verified`다. 남은 `import.tfplan`은 삭제했다.

## AWS Provider 스키마 로딩이 한 번 시간 초과됐다

Problem: PoC 3 첫 `./test.sh`가 `hashicorp/aws` v6.70.0을 설치한 뒤 `terraform validate`에서 멈췄다. `set -e` 때문에 CIDR Python은 실행되지 않았다.

해결한 방법: init이 플러그인을 설치한 상태인지 lock과 그래프를 확인했다. State 파일이 없는 것도 확인했다. 같은 구성으로 `terraform validate`와 `./test.sh`를 다시 실행했다. `plan`은 추가하지 않았다.

Result: 첫 오류는 `Failed to load plugin schemas`와 `timeout while waiting for plugin to start`, 로그의 `FAIL: PoC3`다. 그래프의 `aws_instance.app -> aws_subnet.private` 같은 간선은 그 뒤 출력되었다. 재검증은 `Success! The configuration is valid.`, `PASS: CIDR design`, `PASS: Terraform static validation`, `poc3_no_state`, exit 0이다.

## prevent_destroy를 유지한 채 실험 리소스를 지워야 했다

Problem: `lifecycle.prevent_destroy`가 `terraform plan -destroy`를 exit 1로 막았다. 학습용 파일을 디스크에 남겨 두면 다음 설명이 적용된 상태와 섞인다.

해결한 방법: 오류 원문을 남긴 뒤, destroy 직전에만 `prevent_destroy` 블록을 뺐다. destroy 후 `main.tf`를 원래 설명 구성으로 되돌리고 `kept.txt`, `quiet.txt`를 지웠다. 리소스가 0개인 State와 backup도 삭제했다.

Result: 막힐 때의 문구는 `Resource local_file.kept has lifecycle.prevent_destroy set`다. 블록을 뺀 destroy는 `Destroy complete! Resources: 2 destroyed.`다. 현재 `lifecycle/main.tf`에는 `prevent_destroy`와 `ignore_changes`가 다시 있고, `terraform.tfstate`는 없다.

## Git 기록이 없다

Problem: 교재 17장은 `git init`, PoC별 커밋, 원격이 있으면 `git push`를 한다.

해결한 방법: 저장소와 원격 여부를 확인만 했다. `git init`, commit, push는 하지 않았다. State와 Plan은 `.gitignore`에 적어 두었을 뿐, 커밋하지 않았다.

Result: `git rev-parse --is-inside-work-tree`는 `fatal: not a git repository (or any of the parent directories): .git`, exit 128. 커밋 해시는 없다.
