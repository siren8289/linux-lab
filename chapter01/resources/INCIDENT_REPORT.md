# 실습 06 — 시스템 장애 분석 및 리소스 관찰 보고서

- **작성 일시**: 2026-10-31
- **분석 시스템**: macOS / Ubuntu Linux 공통 진단 환경
- **담당 엔지니어**: jeong-yelim (Senior Cloud / Backend SRE)

---

## 1. 실무 장애 시나리오 요약
> **인시던트 상황**: "오전부터 사내 AI 챗봇 응답이 현저히 지연되고, 간헐적으로 HTTP 504 Gateway Timeout 및 연결 실패 에러가 발생함."

---

## 2. 4대 핵심 자원별 점검 결과 및 관찰 기록

### ① CPU 부하 테스트 및 관찰 결과
- **테스트 방법**: `safe_cpu_stress.py` (또는 `stress-ng --cpu 1 --timeout 15s`)로 15초간 1개 CPU 코어 풀연산 수행
- **관찰된 수치 변화**:
  - `uptime`의 1분 Load Average가 일시적으로 상승 (`0.8` ➔ `1.8` 수준)
  - `ps -eo pid,pcpu,comm --sort=-pcpu` 상위에 Python Worker 프로세스가 CPU 99.8%를 점유하며 등재됨
  - 15초 타임아웃 경과 후 Worker 프로세스가 자체 종료되면서 CPU 사용량이 즉시 평시 상태(0~3%)로 복귀
- **엔지니어 해석**: 특정 단일 프로세스가 CPU를 100% 점유하더라도 멀티코어 환경에서는 즉시 시스템 다운으로 이어지지 않으나, 스레드 풀이 고갈되면 웹 서버가 신규 HTTP 요청을 제때 처리하지 못해 **응답 지연(Latency 급증)**이 발생함을 확인.

### ② 메모리(RAM) 및 OOM(Out of Memory) 점검 결과
- **점검 명령어**: `free -h`, `vm_stat`, `journalctl -k -b | grep -i oom`
- **관찰 결과**:
  - 시스템 총 메모리 8.0 GiB 중 Active/Inactive 페이징 메모리가 안정적으로 관리되고 있으며, 여유 공간(Available)이 충분함
  - 최근 커널 메시지에서 `Out of memory: Killed process` 또는 OOM-Killer 발동 이력 없음
- **엔지니어 해석**: 메모리 누수(Memory Leak)로 인한 프로세스 피살(SIGKILL) 현상은 발생하지 않았음.

### ③ 디스크 용량 및 Inode 상태 점검 결과
- **점검 명령어**: `df -h .`, `df -i .`, `du -sh .`
- **관찰 결과**:
  - 데이터 볼륨 사용량: 전체 460 GiB 중 334 GiB 사용 중 (79% 점유, 가용 공간 90 GiB 확보)
  - Inode 사용량: 0% 수준으로 파일 메타데이터 테이블 공간 충분
  - `dd` 도구를 활용한 10 MiB 쓰기 테스트(`bs=1M count=10`)가 지연 없이 정상 완료됨
- **엔지니어 해석**: 디스크 풀(100% Full) 또는 Inode 고갈로 인한 로그 기록 실패 장애는 배제할 수 있음.

---

## 3. 관찰 결과 기반 원인 규명 및 종합 판단

| 점검 영역 | 현재 상태 | 장애 원인 연관도 | 조치 및 권고사항 |
| :--- | :---: | :---: | :--- |
| **CPU** | ⚠️ 부하 급증 가능 | **높음 (High)** | 특정 AI 추론 연산 또는 정규식 파싱 루프가 CPU 코어를 독점함. 작업 큐 분리 및 Gunicorn/Uvicorn 워커 수 증설 권장. |
| **메모리** | ✅ 정상 | **낮음 (Low)** | OOM 킬러 발동 흔적 없음. 안전 범위 내 유지 중. |
| **디스크** | ✅ 정상 | **낮음 (Low)** | 90 GiB 여유 확보. 로그 롤링(Logrotate) 주기 유지. |
| **네트워크** | ✅ 정상 | **보통 (Medium)** | 커넥션 풀(Time-Wait 소켓) 고갈 여부 지속 모니터링 필요. |

---

## 4. 최종 결론 및 재발 방지 대책
1. **CPU 부하 분산**: AI 모델 전처리/추론 요청을 비동기 태스크 큐(Celery / Redis / RabbitMQ)로 분리하여 웹 서빙 스레드의 CPU 기아(Starvation) 방지.
2. **모니터링 알림 설정**: Prometheus & Grafana 또는 Datadog을 통해 CPU Load Average가 논리 코어 수의 80%를 3분 이상 초과할 경우 Slack 채널로 P1 Alert 자동 발송.
