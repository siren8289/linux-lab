# 트러블슈팅

## kind가 multi-user 로그를 기다리다 실패했다

Problem: 첫 `kind create cluster --name k8s-lab`가 Preparing nodes에서 끝났다.

해결한 방법: kind가 노드를 지운 뒤의 메시지와, `--retain`으로 다시 만든 노드의 `docker logs`를 봤다. systemd는 결국 `Reached target multi-user.target`과 `detected cgroup v2`를 남겼다. 첫 시도는 그 줄이 나오기 전에 kind가 실패로 처리했다. 생성을 다시 실행했다.

Result: 첫 오류는 `could not find a log line that matches "Reached target .*Multi-User System.*|detected cgroup v1"`이다. 이후 생성은 control-plane, CNI, StorageClass까지 끝났고 Server Version은 v1.37.0이다. Docker cgroup은 v2, 메모리 약 4GB, CPU 6개다. 기존 kind 노드 3개가 이미 떠 있는 상태에서 네 번째 노드 기동이 느려질 수 있다.

## 떠 있던 k8s-lab를 스크립트가 지웠다

Problem: 한 번 만들어진 `k8s-lab`에 `kubectl get nodes`가 `TLS handshake timeout`을 냈다. 스크립트는 준비되지 않은 클러스터로 보고 삭제한 뒤 다시 만들었다. 같은 시각 `gitops-lab`와 `cloud-poc` 조회도 timeout이었다.

해결한 방법: 기존 클러스터를 지우지 않도록 스크립트를 바꿨다. `k8s-lab`가 없을 때만 만들고, 실패하면 한 번 더 만든다. 실습 종료 시에만 `k8s-lab`를 삭제한다.

Result: 통과 실행은 생성부터 삭제까지 exit 0이다. 삭제 후 `kind get clusters`는 `cloud-poc`와 `gitops-lab`뿐이다. 두 클러스터의 노드는 Ready다.

## kind load가 이미지 digest를 찾지 못했다

Problem: 호스트에 있는 `nginx:1.27-alpine`을 `kind load docker-image`로 넣었다.

해결한 방법: 로드를 멈췄다. 파드 `imagePullPolicy`는 `IfNotPresent`라서, 노드에 이미지가 없으면 containerd가 레지스트리에서 받게 두었다.

Result: 오류는 `ctr: content digest sha256:62223d644fa234c3a1cc785ee14242ec47a77364226f1c811d2f669f96dc2ac8: not found`다. 그 다음 실행에서 Deployment `web`는 2/2로 뜨고 `wget`은 `study-web`를 받았다.

## Quota가 request 없는 파드를 거절했다

Problem: `hello` 파드만 cpu·memory request가 없었다. `kubectl apply -k`가 다른 객체는 만든 뒤 `hello`에서 멈췄다.

해결한 방법: ResourceQuota가 `requests.cpu`와 `requests.memory`를 제한하면 모든 컨테이너에 그 request가 필요하다. `hello`와, 거절 이유를 Pod Security로 보려는 privileged 예제에 `cpu: 10m`, `memory: 16Mi`를 넣었다.

Result: 수정 전 오류는 `must specify requests.cpu for: nginx; requests.memory for: nginx`다. 수정 후 `hello`는 Running이고 쿼터 사용량은 `pods: 5/10`, `requests.cpu: 130m/1`, `requests.memory: 112Mi/256Mi`였다.

## auth can-i의 거절이 스크립트를 멈췄다

Problem: `list_secrets=no`가 출력된 직후 스크립트가 exit 1로 끝나고 HPA describe 이후가 실행되지 않았다. 클러스터는 cleanup이 지웠다.

해결한 방법: `kubectl auth can-i`는 답이 no일 때 종료 코드 1을 반환한다. `set -e`가 그 코드를 실패로 봤다. 두 can-i 명령에 `|| true`를 붙였다. `kubectl explain | head`도 SIGPIPE로 실패할 수 있어 `|| true`를 붙였다.

Result: 다시 실행한 로그는 `list_pods=yes`, `list_secrets=no` 다음에 HPA, 스케줄링, PVC, Ingress, Pod Security, CrashLoopBackOff까지 있고 `LAB_COMMANDS_DONE`, `CLEANUP_DONE previous_exit=0`이다.

## HPA가 CPU 사용률을 계산하지 못했다

Problem: HPA 대상은 `<unknown>/50%`이고 `ScalingActive`는 False다.

해결한 방법: metrics-server를 설치하지 않았다. 이벤트 문장으로 API 부재를 확인했다. 레플리카를 손으로 바꾸지는 않았다.

Result: `unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)`. `AbleToScale`은 True이고 파드는 2개다.

## Ingress에 주소가 없다

Problem: Ingress `web`의 Address와 Ingress Class가 비어 있다.

해결한 방법: 컨트롤러를 설치하지 않은 상태로 객체와 Service 백엔드만 확인했다. 접속 시험은 클러스터 안 Service DNS로 했다.

Result: 규칙은 `web.study.local` `/` → `web:80`이고, describe의 백엔드 IP는 파드 IP다. Events는 없다. `wget http://web.study.svc.cluster.local/`은 `study-web`다.

## Helm이 없다

Problem: 개념 확장과 패키지 도구로 Helm을 실행했다.

해결한 방법: `brew install`은 하지 않았다. 매니페스트 묶음은 Kustomize로 적용했다.

Result: `helm: command not found`, exit 127. `kubectl apply -k`는 namespace부터 HPA까지 만들었다. `kubectl explain deployment`의 설명은 `Deployment enables declarative updates for Pods and ReplicaSets.`다.

## Git 기록이 없다

Problem: 다른 학습 교재는 커밋과 push를 포함한다.

해결한 방법: 저장소를 만들지 않았다. `k8s-lab`의 kubeconfig 항목은 클러스터 삭제와 함께 정리되고, 시작 시 current-context가 없었으므로 끝나고도 비운다.

Result: 실습 후 `kubectl config current-context`는 `error: current-context is not set`이다. `~/linux-lab`에는 커밋이 없다.
