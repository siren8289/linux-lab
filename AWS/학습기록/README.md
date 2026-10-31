# AWS — 실행 기록

2026-10-29, Mac(Darwin), `~/linux-lab/AWS`. 자격 증명은 설정되어 있지 않다. 실제 계정 조회와 유료 리소스 생성은 하지 않았다.

## 사용자가 사이트에 접속하면

```text
사용자
  ↓ HTTPS
Internet Gateway
  ↓
ALB (Public Subnet, 기본 경로 0.0.0.0/0 → igw)
  ↓ HTTP 또는 HTTPS
EC2 (Private Subnet, 기본 경로 0.0.0.0/0 → nat)
  ├── EBS: OS와 애플리케이션 파일. AZ에 묶인 블록 디스크
  ├── S3: 이미지·백업. VPC 안 리소스가 아님
  └── RDS: 관계형 데이터. DB 서브넷에는 인터넷 기본 경로를 두지 않음
CloudWatch: 메트릭·로그·알람
IAM: API 허용·거부
Auto Scaling: EC2 수
```

S3, IAM, CloudWatch는 VPC 안에 그리는 자원이 아니다. EBS는 EC2가 있는 AZ의 디스크다. ALB는 두 AZ 이상의 퍼블릭 서브넷을 쓴다.

## 도구

| 도구 | 결과 |
|---|---|
| aws | `aws-cli/2.38.6` Python/3.15.2 Darwin/25.6.0 arm64. 이미 설치됨 |
| python3 | 3.11.9 |
| jq | 1.7.1 |
| docker | 29.6.1 |
| 자격 증명 | access key, secret, region 모두 없음 |

`brew install`은 다시 하지 않았다.

## 파일

| 파일 | 내용 |
|---|---|
| [01-기초.md](01-기초.md) | IAM, CLI, VPC, 라우트 |
| [02-중급.md](02-중급.md) | SG/NACL, EC2, EBS, S3 |
| [03-심화.md](03-심화.md) | ALB, Auto Scaling, RDS, CloudWatch |
| [04-poc.md](04-poc.md) | PoC 1·2·3 결과 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

## 복습 정답

1. Private Subnet의 EC2가 밖으로 나가려면 Private Route Table의 `0.0.0.0/0`이 NAT Gateway를 가리켜야 한다.
2. Security Group은 Stateful, Network ACL은 Stateless다.
3. ALB 대상이 Unhealthy면 Health Check 경로, 포트, 응답 코드를 먼저 본다.

EC2의 8080은 인터넷 전체(`0.0.0.0/0`)가 아니라 ALB Security Group만 허용하는 쪽이 최소 권한이다.

## 체크리스트

| 항목 | 상태 |
|---|---|
| IAM 최소 권한 | `GetObject` 허용, `PutObject` 거부를 코드로 확인 |
| AWS CLI | 버전 확인. 계정 조회는 자격 증명 없음으로 실패 |
| VPC·서브넷 | 6개 서브넷 포함·비중첩, `/24` 사용 가능 251 |
| Public/Private 경로 | 검증기가 `igw` / `nat` / 없음 을 구분 |
| IGW·NAT | 개념과 라우트 규칙으로 확인. 실 게이트웨이는 만들지 않음 |
| SG·NACL | 차이 정리. 계정 조회는 하지 않음 |
| EC2·EBS·S3 | 이 Mac은 EC2가 아님. S3 API는 LocalStack에서 업로드·다운로드 성공 |
| ALB Health Check | 비정상 백엔드 `EC2-C`를 분산에서 제외 |
| Auto Scaling | 85%→3, 90%→4, 50%→4, 20%→3. 최소 2, 최대 4 |
| RDS | 로컬 `psql`은 시간 초과. 엔진 조회는 자격 증명 없음 |
| CloudWatch | 임계값 70 기준 85는 ALARM, 40은 OK |
| PoC 1 | 4 tests OK |
| PoC 2 | 정책 PASS, 파일 SHA-256 동일, diff 0 |
| PoC 3 | `PASS: all tests` |
| Git commit·push | 실행하지 않음 |
