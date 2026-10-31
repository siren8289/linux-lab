# Kubernetes — 실행 기록

2026-10-29, Mac, `~/linux-lab/Kubernetes`. 문서 목차는 v1.32 개념 페이지다. 실제로 뜬 클러스터는 kind 노드 v1.37.0이다.

## 문서 목차와 이번 확인

| 개념 문서 | 이번 머신에서 본 것 |
|---|---|
| 쿠버네티스란 무엇인가 | 선언한 Deployment가 파드를 다시 만들고, Service 주소는 그대로였다 |
| 클러스터 아키텍처 | `kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `kubelet`, `kube-proxy`, `kindnet`, CoreDNS |
| 컨테이너 | 런타임 `containerd://2.3.4`. 이미지는 `nginx:1.27-alpine` |
| 윈도우 | 이 노드 OS는 `linux`, `arm64` |
| 워크로드 | Pod, ReplicaSet, Deployment, DaemonSet, Job |
| 서비스·네트워킹 | ClusterIP `web.study`, Ingress 객체. Ingress 컨트롤러는 없다 |
| 스토리지 | ConfigMap, Secret, emptyDir. PVC `data`는 Pending |
| 구성 | ConfigMap `web-config`, Secret `web-secret` |
| 보안 | ServiceAccount `reader`, Pod Security `baseline` |
| 정책 | ResourceQuota `study` |
| 스케줄링·축출 | nodeSelector 불일치, HPA는 metrics API가 없어 계산하지 못함 |
| 클러스터 관리 | kind로 `k8s-lab`만 만들었고 지웠다 |
| 확장 | Helm 없음. `kubectl apply -k`에 들어 있는 Kustomize v5.8.1 |

## 도구

| 도구 | 결과 |
|---|---|
| kubectl | Client v1.37.1, Kustomize v5.8.1. 통과 실행의 Server는 v1.37.0 |
| kind | v0.33.0, darwin/arm64 |
| 노드 | Debian 13, kernel `6.12.76-linuxkit`, containerd 2.3.4, cgroup v2 |
| helm | `command not found`, exit 127 |
| 기존 클러스터 | `gitops-lab` control-plane+worker, `cloud-poc` control-plane. 둘 다 Ready. 변경하지 않음 |

## 파일

| 파일 | 내용 |
|---|---|
| [01-기초.md](01-기초.md) | 버전, control plane, 노드, CRI |
| [02-중급.md](02-중급.md) | 워크로드, Service, 구성, 스토리지 |
| [03-심화.md](03-심화.md) | RBAC, Quota, 스케줄링, HPA, Ingress |
| [04-poc.md](04-poc.md) | 교체, emptyDir, 장애 재현 |
| [troubleshooting.md](troubleshooting.md) | Problem → 해결한 방법 → Result |

원문 로그는 `Kubernetes/logs/lab-run.log`다.

## 체크리스트

| 항목 | 상태 |
|---|---|
| 문서 v1.32와 실행 버전 | 문서는 v1.32 스냅샷. 클러스터는 v1.37.0 |
| control plane 구성 요소 | etcd, apiserver, scheduler, controller-manager가 `kube-system`에 있음 |
| 노드·런타임 | `kubelet=v1.37.0`, `containerd://2.3.4`, `os=linux` |
| Deployment·ReplicaSet | `web` 2/2. ReplicaSet `web-d7496596b` |
| Service DNS | `wget` 결과가 `study-web` |
| ConfigMap·Secret | 페이지 내용과 `/etc/study/token`의 `study-token` |
| 단독 Pod | 삭제 후 `NotFound` |
| DaemonSet·Job | logger 1/1. Job `once` 완료, 로그 `study-web` |
| emptyDir | 파드를 지우자 `/scratch/note`가 없음 |
| PVC | `standard` 클래스, `WaitForFirstConsumer`, Pending |
| RBAC | `list pods` yes, `list secrets` no |
| Pod Security | privileged 파드 Forbidden, `baseline:latest` |
| Quota | 요청을 안 적은 Pod는 거절. 이후 `pods: 4/10` |
| HPA | `cpu: <unknown>/50%`. `pods.metrics.k8s.io` 없음 |
| Ingress | 호스트 `web.study.local`. Address 비어 있음 |
| 기존 kind | 실습 뒤에도 Ready. `127.0.0.1:8080`은 `gitops-lab-control-plane` |
| Git | 하지 않음. `~/linux-lab`는 Git 저장소가 아니다 |
