# 검증 — 교체, 임시 디스크, 장애

세 가지는 통과 실행에서 이어서 확인했다. 클러스터는 그 뒤에 삭제했다.

## 1. Deployment는 파드를 되돌리고 Service는 유지된다

`web-d7496596b-2jjp5`를 삭제했다.

```text
pod "web-d7496596b-2jjp5" deleted from study namespace
deployment "web" successfully rolled out
web-d7496596b-hhl79   1/1   Running   10.244.0.10
web-d7496596b-qrnh8   1/1   Running   10.244.0.5
```

남은 파드와 새 파드가 다시 2개다. 그 다음 `wget http://127.0.0.1/` 결과는 `study-web`이다.

컨트롤러가 없는 `hello`는 삭제 후 `NotFound`다. 복구는 Pod 객체의 기본 동작이 아니라 ReplicaSet이 desired 개수를 맞춘 결과다.

## 2. emptyDir는 파드와 함께 사라진다

지운 파드에만 `scratch-note`를 썼다. 새 파드 `web-d7496596b-hhl79`:

```text
cat: can't open '/scratch/note': No such file or directory
EMPTYDIR_GONE exit=1
```

페이지 내용 `study-web`는 ConfigMap에 있어서 새 파드에서도 같다. `/etc/study/token`의 `study-token`도 Secret이 다시 마운트된 값이다. 빈 디렉터리에 쓴 파일만 사라졌다.

## 3. 실패 상태를 로그와 이벤트로 구분한다

스케줄 실패는 컨테이너가 시작되기 전이다. `unschedulable`은 `Pending`이고 이벤트는 `FailedScheduling`, `didn't match Pod's node affinity/selector`다. 이미지 pull이나 프로세스 종료가 아니다.

프로세스 실패는 Deployment `crash`다. 명령은 `echo boom; exit 1`이다.

```text
crash-88ccb8787-gwbcp   0/1   CrashLoopBackOff   1 (4s ago)
boom
```

kubelet이 컨테이너를 다시 실행하고, 로그에 `boom`이 남는다. 확인 후 Deployment를 삭제했다.

권한 실패는 파드가 생기기 전이다.

```text
violates PodSecurity "baseline:latest": privileged
privileged_apply_exit=1
```

HPA 실패는 파드 상태가 아니다. 파드는 Running 2개인데 `ScalingActive=False`, 이유는 `pods.metrics.k8s.io`를 찾지 못한 것이다.

PVC `data`는 Pending이고 이유는 `WaitForFirstConsumer`다. 소비자 파드를 만들지 않은 상태라 바인드 실패와는 이벤트가 다르다.

Ingress `web`은 생성되었으나 Address가 비어 있다. 컨트롤러가 없어 외부 호스트 라우팅은 확인하지 않았다.
