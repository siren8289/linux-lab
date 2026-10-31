# Chapter 01 · Linux 핵심 기초 및 AI 서비스 운영 실습

본 디렉터리는 Linux 및 macOS 환경에서 AI 서비스의 파일시스템, 권한, 프로세스, 그리고 systemd 기반 자동 장애 복구를 학습하기 위한 실습 환경입니다.

---

## 📂 실습 구성 및 파일 구조

| 파일명 | 유형 | 설명 |
| :--- | :--- | :--- |
| `logs/ai-service.log` | 실습 01-02 | AI 서비스 표준 출력 리다이렉션(`>`, `>>`) 및 `grep` 검색 로그 |
| `app.conf` | 실습 03 | 최소 권한 원칙(`chmod 640`)이 적용된 AI 서비스 가상 설정 파일 |
| `mock_ai_service.py` | 실습 04 | `SIGTERM(15)`을 가로채 Graceful Shutdown을 수행하는 모의 데몬 |
| `process_lab.sh` | 실습 04 | 백그라운드 프로세스 생성(`&`), 상태 조회(`ps`), 안전한 종료(`kill -TERM`) 자동화 |
| `app.py` | 실습 05 | 5초 간격으로 Heartbeat 로그를 출력하는 가상 AI 챗봇 서비스 데몬 |
| `ai-demo.service` | 실습 05 | `Restart=on-failure`가 설정된 systemd Unit 정의 파일 |
| `systemd_lab.sh` | 실습 05 | Ubuntu VM 환경에서 systemd 등록 ➔ kill -9 장애 재현 ➔ 자동 복구 검증 자동화 스크립트 |
| `supervisor_simulation.py` | 실습 05 | macOS 환경에서 systemd의 감시 및 재시작 알고리즘을 체험할 수 있는 로컬 시뮬레이터 |

---

## 🚀 실습 05: systemd 자동 장애 복구 실습 가이드

### 1. Ubuntu VM 환경에서 실행할 경우
```bash
# 원클릭 실습 자동화 스크립트 실행
chmod +x systemd_lab.sh
./systemd_lab.sh
```

### 2. 수동 제어 명령어 모음
```bash
# 유닛 등록 및 서비스 시작
sudo cp ai-demo.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ai-demo.service

# 상태 및 PID 확인
systemctl status ai-demo.service
systemctl show ai-demo.service -p MainPID

# 장애 재현 (강제 종료)
sudo kill -KILL <MainPID>

# 7초 대기 후 새 PID 및 로그 확인
systemctl show ai-demo.service -p MainPID
sudo journalctl -u ai-demo.service -n 20 --no-pager
```

### 3. macOS 로컬 환경에서 시뮬레이션할 경우
```zsh
chmod +x supervisor_simulation.py
python3 supervisor_simulation.py
```
* 다른 터미널 창에서 출력된 PID로 `kill -9 <PID>`를 전송하면, 5초 후 새로운 PID로 자동 복구되는 과정을 실시간으로 관찰할 수 있습니다.
