# 트러블슈팅

2026-10-29, Darwin, `~/linux-lab`. 각 항목은 Problem → 해결한 방법 → Result 순이다. 방화벽, NAT, SSH 키, 패키지 설치, Git push는 하지 않았다.

## 1. `ip` 계열 명령이 없음

### Problem

`ip -br addr`, `ip -d link show`, `ip -s link`, `ip neigh`, `ip route`, `ip route get`가 전부 `command not found`였다. 인터페이스, ARP, 라우팅을 교재 형식으로 못 읽었다.

### 해결한 방법

`ifconfig`, `netstat -ib -I en0`, `arp -an`, `netstat -rn -f inet`, `route -n get 8.8.8.8`로 같은 항목을 조회했다.

### Result

`lo0`는 `127.0.0.1/8`이다. `en0`는 `172.30.1.80/24`, MAC `f6:e8:2f:bb:25:70`, mtu 1500이다. 기본 게이트웨이는 `172.30.1.254`이고 그 MAC은 `c:96:cd:4a:16:35`다. `8.8.8.8`은 default 경로로 `en0`에서 나간다.

## 2. Ubuntu 컨테이너에도 `ip`가 없음

### Problem

떠 있는 `ubuntu:24.04` 컨테이너 `festive_joliot`에서 `ip`를 실행하면 executable file not found였다. 교재의 VM 출력 예시를 거기서도 얻지 못했다.

### 해결한 방법

컨테이너에 패키지를 설치하지 않았다. 인터페이스 관찰은 호스트 조회로 마쳤다.

### Result

교재 예시 `enp0s1 192.168.64.10/24`는 재현하지 못했다. 이 머신에서 설명 가능한 주소는 `172.30.1.80/24`다.

## 3. `sudo`가 필요한 설치와 캡처

### Problem

`sudo apt install`로 traceroute 추가 설치, conntrack, nginx, tcpdump 권한, ufw, wireguard를 진행할 수 없다. `sudo -n`은 `a password is required`다.

### 해결한 방법

이미 있는 `traceroute`, `tcpdump`, `dig`, `curl`, `openssl`, Python만 사용했다. 설치와 방화벽 변경은 중단했다.

### Result

sysstat식 추가 패키지와 conntrack 테이블, UFW 규칙, WireGuard 인터페이스는 비어 있다. 라우팅과 DNS, TLS는 기존 도구로 확인했다.

## 4. tcpdump 캡처 권한

### Problem

handshake 플래그를 `tcpdump -i lo`로 남기려고 했다. 목록은 보였지만 캡처는 `/dev/bpf0: Permission denied`였다.

### 해결한 방법

비밀번호 입력을 기다리지 않았다. 연결을 유지한 뒤 `netstat -an -p tcp`로 상태만 확인했다. pcap은 만들지 않았다.

### Result

`tcpdump -D`에 `lo0`와 `en0`이 있다. `127.0.0.1:9010`은 LISTEN 한 줄과 ESTABLISHED 두 줄이었다. SYN, SYN/ACK, ACK 플래그 원문은 없다.

## 5. `date -Is`, `getent`, `timeout`, `ss`

### Problem

진단 스크립트 초안을 그대로 두면 macOS에서 시각 찍기가 실패하고, bash에는 glibc `getent`가 없으며, `timeout`과 `ss`도 없다. zsh의 `getent` 함수는 `/etc/hosts`만 보는 다른 구현이라 bash 스크립트에서 쓸 수 없다.

### 해결한 방법

`네트워크/scripts/network-diagnostic.sh`에 대체 경로를 넣었다. 시각은 `date '+%Y-%m-%dT%H:%M:%S%z'`, 이름은 Python `getaddrinfo`, TCP는 Python `create_connection`, 라우팅은 `netstat -rn`, 리스너는 `lsof`다.

### Result

로그 시각은 `2026-10-29T00:21:46+0900` 형식이다. `localhost`는 `127.0.0.1`로 확인됐다. `ss` 전체 목록 대신 대상 포트의 리스너만 로그에 남았다.

## 6. PoC 1이 8080을 성공으로 보고함

### Problem

`network_check.py` 종료 코드가 0이었다. 이전 실습에서 8080 HTTP는 빈 응답이었다. labweb systemd 서비스도 없다. TCP 성공만으로 서비스가 정상이라고 적으면 틀린다.

### 해결한 방법

스크립트는 교재 그대로 두었다. 이어서 진단 스크립트로 같은 포트의 HTTP를 따로 보고, 수신 프로세스를 `lsof`로 확인했다. 비교용으로 포트 9에도 연결해 보았다.

### Result

PoC 1은 `CONNECTED 127.0.0.1:8080`, 종료 코드 0이다. 리스너는 Docker PID 73397이다. 같은 포트 HTTP는 curl 52로 실패한다. 포트 9는 `[Errno 61] Connection refused`다.

## 7. nginx와 systemctl이 없어 PoC 2를 못 올림

### Problem

`sudo apt install nginx`, `sudo nginx -t`, `systemctl reload nginx`를 실행할 수 없다. 8088에 올릴 L7 프록시가 없으면 두 백엔드 분산을 검증할 수 없다.

### 해결한 방법

교재 설정은 `네트워크/nginx/lab-lb.conf`로 저장만 했다. `네트워크/scripts/lab_lb.py`가 `127.0.0.1:8088`에서 8001과 8002를 라운드 로빈하고, 연결 실패 시 다른 백엔드를 한 번 시도한다. 백엔드는 `python3 -m http.server`다. 검증은 `네트워크/scripts/test-lb.sh`다.

### Result

10회 호출은 Backend A 5, Backend B 5, `PASS`, 종료 코드 0이다. 8001을 종료한 뒤 4회는 모두 `X-Lab-Backend: http://127.0.0.1:8002`, 본문 `Backend B`였다. 시스템 nginx 설정 테스트는 하지 못했다.

## 8. labweb을 멈추는 장애 주입을 할 수 없음

### Problem

PoC 3의 `systemctl stop labweb`은 `systemctl`이 없어 실행되지 않는다. 8080을 듣고 있는 Docker를 멈추면 kind 클러스터까지 같이 죽는다.

### 해결한 방법

8080은 조회만 했다. 정상·중지·복구는 `web/`을 제공하는 임시 서버 `127.0.0.1:8099`에 `PORT=8099`로 같은 진단 스크립트를 세 번 실행해 재현했다. 실험 후 그 프로세스는 종료했다.

### Result

8080은 TCP OK, HTTP FAIL, 종료 코드 1이다. 8099는 정상 0, 중지 1(TCP errno 61, curl 7, 리스너 없음), 복구 0이다. DNS와 기본 경로는 세 경우 모두 정상이라서, 실패 원인이 이름 해석이나 기본 경로가 아니라는 기록이 남는다.

## 9. traceroute가 목적지까지 안 감

### Problem

`traceroute -n 1.1.1.1`을 교재처럼 끝까지 두면 오래 걸릴 수 있다. 홉과 대기 시간을 제한하면 중간에서 끊긴 출력만 나온다.

### 해결한 방법

`traceroute -n -m 6 -w 1 1.1.1.1`로 여섯 홉만 봤다.

### Result

1홉은 게이트웨이 `172.30.1.254`다. 5홉과 6홉은 시간 초과다. 홉 상한을 6으로 둔 결과이므로 인터넷 경로가 끊겼다고 적지 않는다. 기본 경로의 다음 홉이 게이트웨이라는 사실만 확인했다.

## 10. curl과 openssl의 TLS 암호군이 다름

### Problem

같은 `example.com:443`인데 curl 상세 로그와 `openssl s_client`의 cipher 이름이 달랐다. 하나를 실패로 볼 수 있다.

### 해결한 방법

버전, 인증서 CN, 검증 코드, ALPN을 각각 읽어 비교했다.

### Result

둘 다 TLS 1.3이고 인증서 CN은 `example.com`, 검증은 성공이다. curl 암호군은 `AEAD-CHACHA20-POLY1305-SHA256`, openssl은 `TLS_AES_256_GCM_SHA384`다. HTTP 응답은 `HTTP/2 200`이다. 클라이언트가 다른 암호군을 골라도 인증서 검증 성공과는 별개다.

## 11. Git commit과 push

### Problem

교재는 PoC마다 `git init`, `git commit`, 원격이 있을 때 `git push`를 한다. 이 디렉터리는 Git 저장소가 아니고 `git remote`도 없다. push 성공을 출력 없이 적을 수 없다.

### 해결한 방법

저장소를 새로 만들지 않고 commit과 push를 실행하지 않았다. 코드와 이 노트는 작업 트리에만 두었다.

### Result

커밋 해시와 원격 push 결과는 없다. 체크리스트의 Git 항목은 미완료다.
