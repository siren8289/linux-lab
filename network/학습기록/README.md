# 네트워크 엔지니어링 — 실행 기록

실습 코드는 `~/linux-lab/네트워크/`에 있다. `network-poc1/`, `tcp_server.py`, `tcp_client.py`, `udp_demo.py`, `backend-a/`, `backend-b/`, `nginx/lab-lb.conf`, `scripts/lab_lb.py`, `scripts/test-lb.sh`, `scripts/network-diagnostic.sh`다. 진단 로그는 `~/linux-lab/네트워크/logs/network-diagnostic.log`에 있다.

2026-10-29에 `~/linux-lab`이 있는 Mac(Darwin)에서 교재 명령을 실행한 기록이다. 교재 기준 환경은 Ubuntu Server 24.04 LTS다. 이 호스트에는 `ip`, `ss`, `systemctl`, `apt`, `nginx`가 없고 `sudo`는 비밀번호가 필요하다. 같은 질문을 답할 수 있는 조회는 실행했고, 호스트 방화벽·NAT·SSH 키·원격 push는 바꾸지 않았다.

## 한 줄 결론

- 루프백은 `lo0` `127.0.0.1/8`, 실제 인터페이스는 `en0` `172.30.1.80/24`다. 기본 게이트웨이는 `172.30.1.254`다.
- `192.168.10.130/26`의 네트워크 주소는 `192.168.10.128`이다.
- DNS `example.com` A 레코드는 조회 시점에 `172.66.147.243`, `104.20.23.154`였고 TTL 잔여는 3초였다. HTTPS는 TLS 1.3, 인증서 검증 성공, HTTP/2 200이었다.
- TCP 실습은 `ACK:hello`, UDP 실습은 `hello UDP 127.0.0.1`을 돌려줬다. 연결 중 `netstat`에는 `ESTABLISHED`가 보였다.
- `127.0.0.1:8080`은 Docker가 듣고 있다. TCP는 붙지만 HTTP는 `Empty reply`(curl 52)라서 진단 스크립트는 실패한다.
- 로드밸런서 대체 프록시는 10번 중 Backend A 5, Backend B 5였다. A를 끄면 네 번 모두 B가 응답했다.
- 패킷 캡처와 Git push는 하지 못했다. 이유는 [troubleshooting.md](troubleshooting.md)에 있다.

## 파일

| 파일 | 내용 |
|---|---|
| [01-기초.md](01-기초.md) | OSI, TCP/IP, IPv4/CIDR, ARP, DHCP, DNS |
| [02-중급.md](02-중급.md) | TCP/UDP, HTTP/TLS, 라우팅, NAT, 방화벽, SSH, VPN |
| [03-심화.md](03-심화.md) | L7 분산, tcpdump |
| [04-poc.md](04-poc.md) | PoC 1·2·3 실행 결과 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

원시 진단 로그는 `네트워크/logs/network-diagnostic.log`이다.

## AWS로 이어지는 대응

| 이번 실습에서 본 것 | AWS |
|---|---|
| `172.30.1.80/24` | VPC CIDR, Subnet |
| `default via 172.30.1.254` | VPC Route Table의 기본 경로 |
| 호스트/공유기 쪽 NAT. VM 안에 규칙이 없을 수 있음 | NAT Gateway |
| 애플리케이션 방화벽, 수신 주소와 별개 | Security Group, NACL |
| `dig`, 시스템 리졸버 `168.126.63.1` | Route 53, VPC DNS |
| `127.0.0.1:8088` 라운드 로빈 | ALB. L4 분산은 NLB |
| 진단 스크립트의 TCP/HTTP 분리 | VPC Flow Logs, CloudWatch |

## 개념 확인

1. `192.168.10.130/26`의 네트워크 주소는 **192.168.10.128**이다. Python `ipaddress`로 확인했다.
2. TCP 3-way handshake 순서는 **SYN → SYN/ACK → ACK**다.
3. `Connection refused`일 때 먼저 볼 것은 **서버의 리스닝 포트와 프로세스**다. 포트 9는 수신 프로세스가 없어 errno 61이었다.

## 체크리스트

| 항목 | 상태 |
|---|---|
| OSI와 TCP/IP 계층 설명 | 기록함 |
| IPv4·CIDR·서브넷 계산 | 실행함. `/24`부터 `/28`까지 |
| ARP·DHCP·DNS 구분 | ARP 캐시, 라우팅, `dig` 실행. DHCP 패킷 재임대는 하지 않음 |
| TCP 3-way handshake | 애플리케이션 ACK와 `ESTABLISHED` 확인. SYN 플래그 캡처는 권한 부족 |
| HTTP·HTTPS·TLS | `curl`, `openssl s_client` 실행 |
| 라우팅·NAT | 라우팅 테이블과 `route get` 실행. conntrack은 없음 |
| 방화벽·SSH·VPN | 방화벽 변경, 키 생성, WireGuard 설치는 하지 않음 |
| L7 로드밸런싱 | nginx 없이 로컬 프록시로 A/B 응답 검증 |
| tcpdump | 인터페이스 목록만 가능. 캡처와 pcap은 없음 |
| PoC 1 | 실행. 종료 코드 0. 8080은 labweb이 아님 |
| PoC 2 | `test-lb.sh` PASS |
| PoC 3 | 8080은 FAIL. 8099에서 정상·중지·복구를 재현 |
| Git commit·push | 저장소와 원격이 없어 실행하지 않음 |
