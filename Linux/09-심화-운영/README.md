# 9. 심화 운영: 디스크·보안·성능

2026-10-28에 `~/linux-lab`이 있는 Mac(Darwin)에서 9장 명령을 실행하고 남긴 기록이다. 교재 명령은 Debian/Ubuntu와 systemd를 가정한다. 이 호스트에 없는 명령은 같은 질문을 답하는 macOS 도구로 확인했다.

## 한 줄 결론

- 루트 `/`는 봉인된 읽기 전용 APFS이고, 용량 약 10%, inode 사용률 0%이다. inode 고갈 상태는 아니다.
- `~/linux-lab` 합계는 24K이다.
- 지워졌지만 아직 열려 있는 파일 143개가 약 737MiB를 잡고 있다.
- 샘플 구간의 여유 메모리는 약 69MiB였고, `disk0`는 초당 400MB 이상을 처리했다. CPU는 여러 앱에 나뉘어 있었다.
- 애플리케이션 방화벽은 꺼져 있다. `mysqld`는 3306과 33060을 모든 인터페이스에서 수신한다. TCP 22에는 수신 프로세스가 없다.

## 파일

| 파일 | 내용 |
|---|---|
| [9-1-디스크-마운트-inode.md](9-1-디스크-마운트-inode.md) | `lsblk`, `df`, `du`, `findmnt`, `blkid`, `lsof +L1` |
| [9-2-cpu-메모리-io.md](9-2-cpu-메모리-io.md) | `vmstat`, `iostat`, `pidstat`와 실제로 모은 수치 |
| [9-3-보안-기본-점검.md](9-3-보안-기본-점검.md) | 서비스, 수신 포트, 방화벽, SSH, AppArmor, 패키지 업데이트 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

시스템 패키지를 설치하거나 서비스를 재시작하거나 방화벽 설정을 바꾸지는 않았다.
