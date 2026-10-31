# PoC 결과

세 개 모두 로컬에서 실행했다. AWS 계정 리소스는 만들지 않았다. Git commit과 push는 하지 않았다.

## PoC 1 — VPC 검증

`AWS/poc1-vpc/validate_vpc.py`

```text
test_outside_vpc_detected ... ok
test_overlap_detected ... ok
test_valid_design ... ok
test_wrong_route_detected ... ok
Ran 4 tests in 0.001s
OK
```

검사 내용:

- 서브넷이 `10.0.0.0/16` 안에 있는지
- CIDR이 서로 겹치는지
- public의 기본 경로는 `igw`, private는 `nat`, database는 없는지

교재에 잘린 예시는 테스트 3개였다. 합격 기준에 VPC 밖 서브넷 탐지가 있어 `10.1.0.0/24` 케이스를 네 번째로 넣었다.

`subnet_check.py`는 여섯 서브넷이 VPC 안에 있고 겹치지 않으며, `/24` 사용 가능 주소가 251이라고 출력했다.

## PoC 2 — 정책과 S3

`check_policy.py`:

```text
GetObject: ALLOW
PutObject: DENY
PASS
```

이 판정은 `policy.json`의 Action, Resource, Allow만 본다. 실제 IAM의 Condition과 SCP는 포함하지 않는다. LocalStack의 S3 호출은 이 정책 엔진을 거치지 않는다. 둘은 일부러 분리한 검증이다.

S3 API는 LocalStack Community `4.9.2`, `SERVICES=s3`, `127.0.0.1:4566`이다. 자격 증명은 LocalStack이 받는 테스트 값 `test` / `test`, 리전 `us-east-1`이다. 끝난 뒤 컨테이너는 제거했다.

```text
make_bucket: aws-study-local
upload: ./hello.txt to s3://aws-study-local/hello.txt
2026-10-29 00:42:03    17 hello.txt
download: s3://aws-study-local/hello.txt to ./downloaded.txt
diff exit code: 0
```

SHA-256은 두 파일이 같다.

```text
4e11c5257a8ad158f3527973bc12e96e04b2eb28ec1a572d77514eb9d252aca2
```

`latest` 이미지는 인증 토큰 없이 바로 종료해서 쓰지 못했다. 경위는 [troubleshooting.md](troubleshooting.md)에 있다.

## PoC 3 — ALB, 스케일, 알람

`AWS/poc3-operations/simulator.py`

```text
[ALB]
['EC2-A', 'EC2-B', 'EC2-A', 'EC2-B', 'EC2-A', 'EC2-B']
[AUTO SCALING]
CPU=85% desired=3
CPU=90% desired=4
CPU=50% desired=4
CPU=20% desired=3
[CLOUDWATCH ALARM]
CPU 85: ALARM
CPU 40: OK
PASS: all tests
```

`EC2-C`는 비정상이라 목록에 없다. 정상 대상이 하나도 없으면 `No healthy targets`다. Desired는 2에서 시작하고 2 미만, 4 초과가 되지 않는다.

이 출력은 의사결정만 재현한다. 실제 Health Check 주기, 메트릭 시계열, 인스턴스 워밍업은 없다.

## 합격 기준

| 항목 | 결과 |
|---|---|
| VPC 밖 서브넷 | `test_outside_vpc_detected` ok |
| CIDR 중복 | `test_overlap_detected` ok |
| 잘못된 기본 경로 | `test_wrong_route_detected` ok |
| S3 왕복 | diff 0, SHA-256 동일 |
| GetObject / PutObject | ALLOW / DENY |
| 비정상 대상 제외 | `EC2-C` 미포함 |
| Min/Max | 2 미만·4 초과 없음 |
| 알람 | 85 ALARM, 40 OK |
