# 9-1. 디스크·마운트·inode

## 목적

용량, inode, 마운트, 삭제 뒤에도 남아 있는 파일을 구분해 읽는다. 용량이 남아도 inode가 없으면 파일을 만들지 못한다. 로그를 지웠는데 `df`가 줄지 않으면, 프로세스가 그 파일을 아직 열고 있을 수 있다.

## 실행한 명령

교재 순서대로 실행했다.

```bash
lsblk -f
df -h /
df -i /
du -sh ~/linux-lab
findmnt /
```

표에 있던 확인도 같이 실행했다.

```bash
sudo -n blkid
lsof +L1
```

`du`는 디렉터리별 숫자를 보려고 한 단계 아래도 더했다.

```bash
du -sh ~/linux-lab ~/linux-lab/*
```

## 결과

| 명령 | 결과 |
|---|---|
| `lsblk -f` | `command not found: lsblk` |
| `df -h /` | 460Gi 중 12Gi 사용, 107Gi 남음, 10% |
| `df -i /` | inode 458,732 사용, 여유 1,122,620,560, 사용률 0% |
| `du -sh ~/linux-lab` | 24K |
| `findmnt /` | `command not found: findmnt` (종료 코드 127) |
| `sudo -n blkid` | `sudo: a password is required` |
| `lsof +L1` | 513줄. 링크 수가 0인 고유 inode 143개, 약 736.9MiB |

`df -h /`:

```text
Filesystem        Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1s1   460Gi    12Gi   107Gi    10%    459k  1.1G    0%   /
```

`df -i /`:

```text
Filesystem     512-blocks      Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk3s1s1  965492904  24686160 224524112    10%  458732 1122620560    0%   /
```

macOS `df -i`는 inode 열 옆에 512바이트 블록 열도 같이 보여 준다. 파일 개수 한계를 볼 때는 `iused`, `ifree`, `%iused`를 읽는다.

`du`:

```text
 24K    ~/linux-lab
  0B    ~/linux-lab/backup
4.0K    ~/linux-lab/files
8.0K    ~/linux-lab/logs
8.0K    ~/linux-lab/scripts
4.0K    ~/linux-lab/web
```

## `lsblk` / `findmnt` / `blkid` 자리에 확인한 것

`diskutil info /`:

```text
Device Node:               /dev/disk3s1s1
Volume Name:               Macintosh HD
Mount Point:               /
File System:               APFS
Volume UUID:               F7A747E5-8CB6-4602-8B16-6C1A1E57AD0C
Disk Size:                 494.3 GB
Volume Used Space:         12.6 GB
Solid State:               yes
```

`mount`가 보여 준 `/`:

```text
/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
```

같은 날 앞선 점검의 전체 `df -h`에서 사용자 데이터 볼륨은 아래였다.

```text
/dev/disk3s5   460Gi   321Gi   108Gi   75%   /System/Volumes/Data
```

## 배운 점

- `df -h`는 파일 시스템 전체 용량이다. `du -sh`는 지정한 디렉터리 합계다. `/`는 12Gi를 쓰고, `linux-lab`은 그 중 24K만 쓴다.
- `/`의 inode 사용률은 0%다. 이 파일 시스템에서 새 파일이 실패한다면 원인은 inode 고갈이 아니다.
- `/`는 봉인된 읽기 전용 시스템 볼륨이다. 지울 수 있는 데이터는 `/System/Volumes/Data`에 있고, 그 볼륨은 75%를 쓰고 있었다. APFS 컨테이너가 빈 공간을 공유해서 `/`와 Data의 남은 용량이 둘 다 약 107–108Gi로 보인다.
- `lsof +L1`의 `NLINK` 0은 디렉터리 항목은 사라졌는데 파일은 아직 열려 있다는 뜻이다. 고유 inode 143개가 약 737MiB를 잡고 있다. 예시는 설정 캐시 `.plist-cache`, LaunchServices `.csstore`, 아이콘 캐시, `se_SecurityMessages`이다. 이 프로세스들이 파일을 닫기 전에는 `df` 사용량이 그만큼 줄지 않는다.
- 리눅스에서 `lsblk -f`는 디스크·파일 시스템·UUID·마운트 위치를, `findmnt /`는 `/`의 장치와 옵션을, `blkid`는 fstab에 쓰는 UUID를 보여 준다. 이번 호스트에서는 `diskutil`과 `mount`가 그 세 질문을 답했다.

## 이 절의 트러블슈팅

### Problem

`lsblk -f`가 `command not found: lsblk`로 끝났다. 디스크 이름, 파일 시스템, 마운트 위치를 이 명령으로는 못 읽었다.

### 해결한 방법

같은 질문을 `diskutil info /`로 물었다.

### Result

루트 장치는 `/dev/disk3s1s1`, 파일 시스템은 APFS, 볼륨 이름은 Macintosh HD, SSD이다.

### Problem

`findmnt /`가 종료 코드 127이었다. `/`가 읽기 전용인지 알 수 없었다.

### 해결한 방법

`mount` 출력에서 마운트 지점이 `/`인 줄을 골랐다.

### Result

`/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)`. 시스템 볼륨은 봉인된 읽기 전용이다.

### Problem

`sudo blkid`가 `sudo: a password is required`에서 멈췄다. 이 Mac에는 `blkid`도 없다. UUID를 못 읽으면 나중에 fstab에 해당하는 식별자를 적을 수 없다.

### 해결한 방법

`diskutil info /`의 Volume UUID 줄을 사용했다. 비밀번호가 필요한 명령은 `sudo -n`으로 실행해 입력을 기다리지 않게 했다.

### Result

Volume UUID는 `F7A747E5-8CB6-4602-8B16-6C1A1E57AD0C`이다.

### Problem

`df -h /`만 보면 디스크가 10%라서 여유가 커 보인다. 사용자 파일이 어디 있는지는 이 한 줄에 없다.

### 해결한 방법

`mount` 옵션으로 `/`가 읽기 전용 시스템 볼륨인 것을 확인하고, 전체 `df -h`의 Data 볼륨과 비교했다.

### Result

시스템 볼륨은 12Gi 사용이다. `/System/Volumes/Data`는 321Gi 사용, 75%다. 빈 공간 약 107Gi는 APFS 컨테이너가 공유한다. inode는 `/` 기준 0%다.

### Problem

파일을 지운 뒤에도 용량이 바로 돌아오지 않는 경우를 숫자로 확인하고 싶었다.

### 해결한 방법

`lsof +L1`로 링크 수가 1보다 작은, 즉 삭제됐지만 열린 파일을 봤다. 여러 프로세스가 같은 inode를 열면 용량이 중복되므로 inode 번호 기준으로 한 번만 더했다.

### Result

출력 513줄, 고유 inode 143개, 잡혀 있는 크기 736.9MiB. 이 용량은 해당 프로세스가 파일을 닫은 뒤에야 `df`로 돌아온다.
