# 트러블슈팅

9장을 이 Mac에서 실행하면서 막힌 항목이다. 각 항목은 Problem → 해결한 방법 → Result 순이다. 패키지 설치, 서비스 재시작, 방화벽 변경은 하지 않았다.

환경: Darwin, 작업 디렉터리 `~/linux-lab`, 기록 날짜 2026-10-28.

## 1. `lsblk`가 없음

### Problem

`lsblk -f`가 `command not found: lsblk`로 끝났다. 디스크와 파일 시스템 목록을 얻지 못했다.

### 해결한 방법

`diskutil info /`로 루트 볼륨의 장치, 파일 시스템, UUID, 용량을 조회했다.

### Result

`/dev/disk3s1s1`, APFS, 볼륨 이름 Macintosh HD, UUID `F7A747E5-8CB6-4602-8B16-6C1A1E57AD0C`, 디스크 494.3GB, SSD.

## 2. `findmnt`가 없음

### Problem

`findmnt /`의 종료 코드는 127이었다. `/`의 마운트 옵션을 알 수 없었다.

### 해결한 방법

`mount` 출력에서 마운트 지점이 `/`인 줄을 읽었다.

### Result

`/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)`. 시스템 볼륨은 봉인된 읽기 전용이다.

## 3. `blkid`와 sudo 비밀번호

### Problem

`sudo blkid`는 비밀번호를 요구했고, `blkid` 바이너리도 없다. UUID 확인이 막혔다.

### 해결한 방법

`sudo -n`으로 비밀번호 대기 없이 실패를 확인하고, UUID는 `diskutil info /`의 Volume UUID를 사용했다.

### Result

Volume UUID `F7A747E5-8CB6-4602-8B16-6C1A1E57AD0C`.

## 4. `df -h /`만으로는 데이터 사용량이 안 보임

### Problem

`df -h /`는 460Gi 중 12Gi 사용, 10%다. 이 한 줄만 보면 사용자 데이터가 어디에 얼마나 있는지를 놓친다.

### 해결한 방법

`mount`로 `/`가 읽기 전용 시스템 볼륨인 것을 확인한 뒤, 같은 머신의 전체 `df -h`에서 `/System/Volumes/Data`를 같이 읽었다.

### Result

시스템 볼륨은 12Gi 사용이다. Data 볼륨(`/dev/disk3s5`)은 321Gi 사용, 75%, 남은 공간 약 108Gi다. APFS가 빈 공간을 컨테이너 안에서 공유한다. `/`의 inode 사용률은 0%라서, 파일 생성이 실패한다면 이번 루트 파일 시스템의 inode 고갈은 원인이 아니다.

## 5. 지운 파일이 용량을 계속 잡는 경우

### Problem

로그를 삭제해도 프로세스가 파일을 열고 있으면 `df` 사용량이 바로 줄지 않는다. 그 양을 확인하고 싶었다.

### 해결한 방법

`lsof +L1`로 `NLINK`가 0인 열린 파일을 봤다. 같은 inode를 여러 프로세스가 열면 크기가 중복되므로 inode 번호당 한 번만 합산했다.

### Result

출력 513줄, 고유 inode 143개, 약 736.9MiB. 예시로 `.plist-cache`, LaunchServices `.csstore`, 아이콘 캐시가 있다. 프로세스가 닫기 전에는 이 용량이 비지 않는다. 이 명령은 현재 사용자 권한으로 보여 주는 파일만 포함한다.

## 6. `apt install sysstat`를 실행하지 못함

### Problem

`vmstat`, `iostat -xz`, `pidstat`를 쓰려면 교재는 `sudo apt install -y sysstat lsof`를 먼저 한다. 이 호스트에는 `apt`가 없고, `sudo -n`은 `a password is required`로 끝난다.

### 해결한 방법

설치를 중단했다. 이미 있는 `lsof`, `vm_stat`, BSD `iostat`, `ps`로 메모리·디스크·프로세스 CPU를 각각 측정했다.

### Result

sysstat은 설치되지 않았다. 측정값은 7번과 8번에 있다. `lsof`는 원래부터 사용할 수 있었다.

## 7. `iostat -xz` 옵션 거부

### Problem

`iostat -xz 1 3`이 `illegal option -- x`를 냈다. macOS `iostat`는 `-c`, `-w`, `-d`를 받는다. `%util`과 `await`가 있는 리눅스 sysstat 형식이 아니다.

### 해결한 방법

`iostat -d -c 3 -w 1`로 1초 간격 디스크 통계를 찍었다. 첫 줄은 부팅 이후 평균으로 읽었다.

### Result

`disk0` 부팅 이후 평균은 33.52KB/t, 1613 tps, 52.81MB/s다. 이어진 1초 구간은 11959 tps / 435.08MB/s, 다음 1초는 14267 tps / 560.06MB/s다. `disk4`–`disk6`은 그 구간에 거의 유휴였다. 지연 시간(`await`)은 없어서 디스크 지연 결론은 내리지 않았다.

## 8. `vmstat`와 `pidstat`가 없음

### Problem

`vmstat 1 5`와 `pidstat 1 3`이 `command not found`였다. 실행 대기, iowait, 프로세스별 1초 평균을 교재 형식으로 못 모았다.

### 해결한 방법

메모리는 `vm_stat`, 프로세스 CPU는 `ps -axro pcpu,pmem,rss,pid,comm` 한 장면을 사용했다. 페이지 크기는 16384바이트라서 페이지 수에 16KiB를 곱해 크기로 바꿨다.

### Result

여유 페이지 4,383(약 69MiB), active 약 1.0GiB, inactive 약 0.9GiB, wired 약 2.5GiB. compressor에 들어간 논리 페이지는 1,551,329이고, 압축되어 있어 실제 RAM은 페이지 수 × 16KiB보다 작다. CPU 상위는 Notion Calendar Helper 61.5%, Virtualization VM 30.9%, WindowServer 26.3%, Codex Renderer 26.2%다. 이 CPU 수치는 3초 평균이 아니라 한 시점이다.

## 9. 보안 점검 명령이 systemd/Debian 전용

### Problem

`systemctl`, `ss`, `ufw`, `journalctl`, `aa-status`, `apt`가 없거나 `sudo` 비밀번호에 막혔다. 실행 중인 서비스, 방화벽 규칙, SSH 로그, AppArmor, 업데이트 목록을 교재 명령으로 못 채웠다.

### 해결한 방법

설정을 바꾸지 않는 조회만 했다.

```bash
lsof -nP -iTCP -sTCP:LISTEN
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
lsof -nP -iTCP:22 -sTCP:LISTEN
```

Docker가 연 포트는 `docker ps`의 공개 포트와 맞췄다. `sudo`는 `-n`으로 실행해 입력 대기에서 멈추지 않게 했다.

### Result

- 애플리케이션 방화벽은 `Firewall is disabled. (State = 0)`.
- TCP 22 수신 프로세스 없음. SSH 저널을 봐도 이 호스트의 `sshd` 기록은 없을 상태다.
- `mysqld`는 `*:3306`, `*:33060`에서 수신한다. 방화벽이 꺼진 사실과 같이 적는 항목이다.
- `postgres` 5432와 Docker의 8000, 8080, 8443, 54600, 58472는 `127.0.0.1`에만 있다.
- ControlCenter는 `*:5000`, `*:7000`, rapportd는 `*:55288`이다. 둘은 macOS 시스템 프로세스다.
- systemd 유닛 목록, ufw 규칙, AppArmor 프로필, `apt list --upgradable`는 미확인이다.

## 같이 읽은 결론

CPU, 메모리, 디스크를 따로 보면 다른 이야기가 된다. 이번 샘플에서 CPU는 여러 앱에 나뉘어 있고, 여유 페이지는 약 69MiB이며, `disk0`는 그 1–2초에 400MB/s 이상을 처리했다. 디스크 용량과 inode는 `/` 기준으로 부족하지 않다. 보안 쪽에서 바로 적을 관찰은 MySQL의 전체 인터페이스 수신과 방화벽 꺼짐이다.
