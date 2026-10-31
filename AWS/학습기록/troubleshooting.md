# 트러블슈팅

2026-10-29, `~/linux-lab/AWS`. 각 항목은 Problem → 해결한 방법 → Result 순이다. `aws configure`, 유료 리소스 생성, Git push는 하지 않았다.

## 1. AWS 자격 증명이 없음

### Problem

`aws sts get-caller-identity --region ap-northeast-2`가 `NoCredentials: Unable to locate credentials`를 냈다. `aws configure list`의 access key, secret, region은 비어 있다. VPC, EC2, 로드밸런서, RDS, CloudWatch 조회 명령을 계정에 보낼 수 없다.

### 해결한 방법

`aws configure`와 `aws login`을 실행하지 않았다. 계정 ARN이 필요한 `simulate-principal-policy`도 예시 계정 `123456789012` 그대로 호출하지 않았다. 읽기 검증은 Python과 LocalStack으로 바꿨다.

### Result

실계정 리소스 목록은 없다. IAM 판정, VPC 계산, ALB·스케일·알람은 로컬 테스트로 통과했다.

## 2. LocalStack `latest`가 인증 토큰 없이 종료

### Problem

`localstack/localstack:latest`(2026.10.4)가 기동 직후 종료 코드 55로 끝났다.

```text
License activation failed
Reason: No credentials were found in the environment.
Please set the LOCALSTACK_AUTH_TOKEN variable
Localstack returning with exit code 55
```

2026-03-23 이후 `latest`는 `LOCALSTACK_AUTH_TOKEN` 없이 뜨지 않는다. 포트 4566에도 연결이 거절됐다.

### 해결한 방법

계정을 만들거나 토큰을 넣지 않았다. 인증 없이 기동되던 Community 태그 `localstack/localstack:4.9.2`를 받고, S3만 올리도록 `-e SERVICES=s3`를 붙였다. 실습이 끝난 뒤 `docker rm -f aws-study-localstack`으로 컨테이너를 지웠다.

### Result

헬스 응답은 `"edition": "community"`, `"version": "4.9.2"`, `"s3": "available"`이다. 버킷 `aws-study-local`에 `hello.txt` 17바이트를 올리고 다시 받았다. `diff` 종료 코드 0, SHA-256 `4e11c5257a8ad158f3527973bc12e96e04b2eb28ec1a572d77514eb9d252aca2`가 양쪽 같다. 컨테이너는 남아 있지 않다.

## 3. IMDSv2와 로컬 PostgreSQL

### Problem

EC2 메타데이터와 RDS용 `psql`을 이 Mac에서 확인하려 했다. `169.254.169.254`는 2초 안에 `Connection timed out`이었다. `psql -h 127.0.0.1 -p 5432 -U study -d studydb`는 `timeout expired`였다.

### 해결한 방법

타임아웃을 짧게 두고 재시도하지 않았다. EC2를 띄우거나 데이터베이스를 새로 설치하지 않았다.

### Result

인스턴스 ID와 `studydb` 쿼리 결과는 없다. 메타데이터 주소는 EC2 안에서만 의미가 있고, RDS 접속에는 엔드포인트와 Security Group이 더 필요하다는 기록만 남겼다.

## 4. PoC 1 예시 코드가 중간에 잘림

### Problem

교재의 `validate_vpc.py`는 서브넷 루프 도중에 끊겨 있고, 보여 준 테스트 이름은 3개다. 합격 기준에는 VPC 밖 서브넷 탐지도 있다.

### 해결한 방법

포함 관계, 중복, 기본 경로를 `validate()`에 구현하고, `10.1.0.0/24`가 VPC 밖인 테스트를 추가했다.

### Result

`python3 validate_vpc.py`가 4 tests, `OK`, 종료 코드 0이다. `subnet_check.py`는 여섯 서브넷에 대해 `PASS: valid VPC subnet design`과 `/24` 사용 가능 251, `/26` 59, `/28` 11을 출력했다.

## 5. PoC 3 예시 코드가 함수 정의에서 끊김

### Problem

교재 `simulator.py`는 `scale()` 도중에 끝나고, 기대 출력의 호출 순서는 본문에 없다.

### 해결한 방법

기대 출력과 맞게 라우팅, 스케일, 알람을 이어서 구현했다. 비정상 `EC2-C`를 넣어 제외되는지 검사하고, Desired가 2 미만·4 초과가 되지 않는지도 검사했다.

### Result

ALB 6회는 A, B가 번갈아 나온다. CPU 85, 90, 50, 20의 Desired는 3, 4, 4, 3이다. 알람은 85 ALARM, 40 OK다. 마지막 줄은 `PASS: all tests`다.

## 6. Git

### Problem

교재는 각 PoC 뒤에 `git commit`과, 원격이 있을 때 `git push`를 한다. `~/linux-lab`은 Git 저장소가 아니다.

### 해결한 방법

`git init`과 commit, push를 실행하지 않았다. `poc2-s3/.gitignore`에 `.env`, `*.pem`, `downloaded.txt`를 적어 두기만 했다. 테스트용 키 `test`는 LocalStack 기본값이고 계정 비밀이 아니다.

### Result

커밋 해시와 원격 push 결과는 없다.
