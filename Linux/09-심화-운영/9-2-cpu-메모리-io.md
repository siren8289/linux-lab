# 9-2. CPU·메모리·I/O 분석

## 목적

성능은 CPU 하나만으로 판단하지 않는다. 실행 대기, 메모리, 스왑, 디스크 처리량, 프로세스별 사용량을 같은 구간에서 같이 본다.

리눅스에서 각 명령이 보여 주는 것은 다음과 같다.

| 명령 | 읽는 것 |
|---|---|
| `vmstat 1 5` | 1초 간격 5번. 실행 대기(`r`), I/O에 막힌 프로세스(`b`), 스왑, 여유 메모리, 블록 입출력(`bi`/`bo`), CPU의 user/system/idle/iowait |
| `iostat -xz 1 3` | 1초 간격 3번. 장치별 읽기/쓰기 처리량, 평균 대기(`await`), 큐 길이, 사용률(`%util`). `-z`는 놀고 있는 장치를 숨긴다 |
| `pidstat 1 3` | 1초 간격 3번. 프로세스별 `%usr`, `%system`, `%CPU` |

`%util`이 높고 `await`가 길면 병목 후보는 디스크다.

## 실행한 명령

```bash
sudo -n apt install -y sysstat lsof
vmstat 1 5
iostat -xz 1 3
pidstat 1 3
```

호스트에 있는 도구로 같은 세 축을 다시 재었다.

```bash
vm_stat
iostat -d -c 3 -w 1
ps -axro pcpu,pmem,rss,pid,comm
```

## 결과

| 명령 | 결과 |
|---|---|
| `sudo -n apt install -y sysstat lsof` | `sudo: a password is required`. `apt`도 없다 |
| `vmstat 1 5` | `command not found: vmstat` |
| `iostat -xz 1 3` | `iostat: illegal option -- x` |
| `pidstat 1 3` | `command not found: pidstat` |

`lsof`와 BSD `iostat`는 이미 설치되어 있었다. sysstat 꾸러미는 설치하지 못했다.

### 메모리 (`vm_stat`)

페이지 크기는 16384바이트다. 아래 크기는 그 페이지 수에 16KiB를 곱한 값이다.

| 항목 | 페이지 | 크기 |
|---|---|---|
| free | 4,383 | 약 69MiB |
| active | 64,763 | 약 1.0GiB |
| inactive | 58,265 | 약 0.9GiB |
| wired | 163,943 | 약 2.5GiB |
| compressor에 들어간 논리 페이지 | 1,551,329 | 압축 전 페이지 수. 실제 RAM은 이 수 × 16KiB보다 적다 |

이 샘플의 여유 페이지는 약 69MiB다.

`vm_stat`은 `vmstat 1 5`처럼 1초마다 찍는 시계열이 아니다. 스왑 인/아웃과 CPU iowait는 이 출력에 없다.

### 디스크 (`iostat -d -c 3 -w 1`)

첫 줄은 부팅 이후 평균이고, 다음 두 줄이 각 1초 구간이다.

```text
              disk0
    KB/t     tps     MB/s
   33.52    1613    52.81     부팅 이후 평균
   37.25   11959   435.08     1초 구간
   40.20   14267   560.06     다음 1초
```

같은 두 구간에서 `disk4`, `disk5`, `disk6`의 tps는 0에 가까웠다. 전송 크기는 약 37–40KB라서, 아주 큰 순차 전송만 있는 형태는 아니다.

리눅스 `iostat -xz`의 `%util`과 `await`는 BSD `iostat` 기본 출력에 없다. 처리량만으로도 그 1–2초 동안 `disk0`가 바쁘다는 것은 보인다. 부팅 이후 평균도 1613 tps, 52.81MB/s다.

### 프로세스 (`ps` 한 장면)

`pidstat`의 3초 평균 대신, 명령을 친 시점의 CPU 순 한 장면이다.

| %CPU | RSS | PID | 프로세스 |
|---|---|---|---|
| 61.5 | 92MiB | 814 | Notion Calendar Helper |
| 30.9 | 198MiB | 73470 | Virtualization VM. Docker가 쓰는 Linux VM |
| 26.3 | 41MiB | 405 | WindowServer |
| 26.2 | 174MiB | 31148 | Codex Renderer |
| 22.7 | 166MiB | 44119 | Chrome Helper |
| 18.5 | 138MiB | 38996 | Claude Helper |
| 14.8 | 129MiB | 4108 | agy |

## 배운 점

세 숫자를 같이 읽으면 이렇게 된다.

- CPU는 한 프로세스가 전부 쓰지 않는다. 캘린더, Linux VM, 윈도 서버, 브라우저와 편집기가 나눠 갖는다.
- 여유 페이지는 약 69MiB라서 메모리는 빠듯하다.
- 같은 시각에 `disk0`는 초당 1만 트랜잭션 이상, 435–560MB/s였다. 다른 디스크는 쉬고 있었다.

CPU 사용률만 보면 디스크가 바쁘다는 사실을 놓친다. 디스크 처리량만 보면 어느 프로세스가 같이 바빴는지 놓친다. 이번 샘플은 원인 하나를 확정하지 않는다. `disk0`가 핫한 구간과 Virtualization VM이 CPU 상위에 있던 사실을 다음 확인의 출발점으로 적는다.

## 이 절의 트러블슈팅

### Problem

`sudo apt install -y sysstat lsof`를 실행하지 못했다. `sudo -n`은 `a password is required`를 냈고, `apt` 명령 자체가 없다. `vmstat`과 `pidstat`도 없다.

### 해결한 방법

설치를 진행하지 않았다. 이미 있는 `vm_stat`, `iostat`, `ps`, `lsof`로 메모리, 디스크, 프로세스 CPU를 각각 한 번씩 재었다. 비밀번호 입력은 기다리지 않도록 `sudo -n`을 썼다.

### Result

sysstat은 설치되지 않았다. 여유 메모리 약 69MiB, `disk0` 구간 처리량 435MB/s와 560MB/s, CPU 상위 프로세스 목록은 확보했다.

### Problem

교재의 `iostat -xz 1 3`이 `illegal option -- x`로 거절됐다. macOS `iostat` 사용법은 `-c count`, `-w wait`, `-d`이다.

### 해결한 방법

같은 간격에 가깝게 `iostat -d -c 3 -w 1`을 실행했다.

### Result

`disk0`의 KB/t, tps, MB/s 세 줄을 얻었다. `%util`과 `await`는 이 출력에 없어서, 지연 시간 결론은 내리지 않았다.

### Problem

`pidstat 1 3`이 없어 프로세스별 CPU를 1초 간격으로 못 모았다.

### 해결한 방법

`ps -axro pcpu,pmem,rss,pid,comm`으로 그 시점의 CPU 순서를 찍었다.

### Result

한 장면이라 `pidstat`의 3초 평균은 아니다. 상위는 Notion Calendar Helper 61.5%, Virtualization VM 30.9%, WindowServer 26.3%이다.
