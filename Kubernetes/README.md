# Kubernetes

Mac의 Docker Desktop 위에서 kind로 확인한 학습이다. 기준 문서는 [Kubernetes v1.32 개념](https://v1-32.docs.kubernetes.io/ko/docs/concepts/)이다. 코드와 실행 기록은 이 폴더에 있고, 결과와 트러블슈팅은 [학습기록](학습기록/README.md)에 있다.

| 경로 | 내용 |
|---|---|
| `kind-config.yaml` | 실습용 클러스터 이름 `k8s-lab`. 단일 control-plane |
| `manifests/` | Namespace `study`의 Deployment, Service, DaemonSet, Job, Ingress, PVC, RBAC, Quota, HPA |
| `scripts/run-lab.sh` | 클러스터 생성, 적용, 검증, `k8s-lab` 삭제 |
| `logs/lab-run.log` | 실패한 시도와 마지막 통과 실행의 원문 |

마지막 통과 실행은 `LAB_COMMANDS_DONE` 뒤에 `CLEANUP_DONE previous_exit=0`으로 끝난다. `k8s-lab`는 확인 후 지웠다. `gitops-lab`과 `cloud-poc`는 중지하지 않았다.

이 머신의 클라이언트는 kubectl v1.37.1, 노드 이미지는 `kindest/node:v1.37.0`이다. 문서 스냅샷은 v1.32다. Helm은 설치되어 있지 않다.
