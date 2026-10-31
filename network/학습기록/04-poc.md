# Part 4. PoC 세 개

세 실습 모두 추가 클라우드 비용 없이 로컬에서 실행했다. Git commit과 push는 하지 않았다. `~/linux-lab`은 Git 저장소가 아니고 원격도 없다.

## PoC 1 — 서브넷, DNS, TCP

코드는 `네트워크/network-poc1/network_check.py`다.

```text
[SUBNET]
Network: 192.168.10.128
Mask: 255.255.255.192
Total addresses: 64

[DNS]
Resolved: 127.0.0.1
Resolved: ::1

[TCP]
CONNECTED 127.0.0.1:8080
Exit code: 0
```

`192.168.10.130/26`이 `192.168.10.128/26`인 이유는 [01-기초.md](01-기초.md)의 비트 계산과 같다. 전체 주소 64개다.

`localhost`는 `127.0.0.1`과 `::1`로 해석됐다.

TCP가 성공한 이유는 `labweb`이 떠서가 아니다. `com.docke`가 `127.0.0.1:8080`을 듣고 있다. 이 검사 함수는 소켓이 연결되는지만 본다. 같은 포트의 HTTP는 PoC 3에서 실패했다. TCP 성공과 서비스 정상은 다르다.

수신자가 없는 포트로 같은 방식의 연결을 하면 실패한다.

```text
FAILED 127.0.0.1:9: [Errno 61] Connection refused
```

`systemctl start labweb`은 실행하지 않았다. `systemctl`이 없다.

## PoC 2 — L7 분산

`네트워크/scripts/test-lb.sh`를 8001, 8002, 8088이 떠 있는 상태에서 실행했다. 10번 중 A 5, B 5, `PASS: Both backends responded`, 종료 코드 0.

A를 끈 뒤에는 4번 모두 B가 200을 줬다. nginx 설정 원문과 프록시의 차이는 [03-심화.md](03-심화.md)에 있다. `nginx -t`와 `systemctl is-active nginx`는 실행하지 못했다.

## PoC 3 — 장애 진단

스크립트는 `네트워크/scripts/network-diagnostic.sh`다. 로그는 `네트워크/logs/network-diagnostic.log`에 이어 붙는다.

교재와의 차이:

- `date -Is`가 실패하면 `date '+%Y-%m-%dT%H:%M:%S%z'`를 쓴다.
- `getent ahostsv4`가 없으면 Python `getaddrinfo`로 `localhost`의 IPv4를 확인한다. 이것은 시스템 이름 해석이고, 외부 DNS가 정상이라는 증명까지는 아니다.
- `ip route`가 없으면 `netstat -rn -f inet`을 찍는다.
- `timeout`과 `ss`가 없으면 Python 소켓과 `lsof`를 쓴다.
- `HOST`, `PORT`, `URL`로 대상을 바꿀 수 있다. 기본값은 `http://127.0.0.1:8080/`이다.

### 기본 대상 8080

종료 코드 1.

| 항목 | 결과 |
|---|---|
| DNS/Hosts | OK. `127.0.0.1` |
| 라우팅 | 기본 경로 `172.30.1.254` `en0` |
| TCP | OK |
| HTTP | FAIL. `curl: (52) Empty reply from server` |
| 리스너 | `com.docke` PID 73397, `127.0.0.1:8080` |

DNS와 라우팅과 TCP가 맞아도 HTTP는 실패할 수 있다. 이 포트의 프로세스를 재시작하지 않았다. kind 노드가 쓰고 있는 포트다.

### 직접 띄운 8099로 정상, 중지, 복구

`python3 -m http.server 8099`로 `web/`을 제공하고 `PORT=8099`로 같은 스크립트를 세 번 돌렸다.

| 상태 | TCP | HTTP | 종료 코드 | 리스너 |
|---|---|---|---|---|
| 정상 | OK | OK | 0 | Python `127.0.0.1:8099` |
| 프로세스 종료 | FAIL. errno 61 Connection refused | FAIL. curl 7 | 1 | 없음 |
| 다시 기동 | OK | OK | 0 | Python이 다시 LISTEN |

이것은 경로 장애가 아니라 프로세스 유무로 생기는 접속 실패다. 8080 사례는 프로세스는 있는데 애플리케이션 응답이 비는 경우다. 둘을 나누는 것이 이 진단의 목적이다.

`journalctl -u labweb`은 실행하지 못했다.
