#!/usr/bin/env bash
# Local Kubernetes concepts lab. Creates kind cluster k8s-lab only.
# Does not stop or change kind clusters gitops-lab and cloud-poc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/logs"
LOG="$ROOT/logs/lab-run.log"
exec > >(tee -a "$LOG") 2>&1

PREV_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
CONTEXT="kind-k8s-lab"

cleanup() {
  local status=$?
  echo "===== cleanup k8s-lab ====="
  kind delete cluster --name k8s-lab || true
  if [ -n "$PREV_CONTEXT" ] && [ "$PREV_CONTEXT" != "kind-k8s-lab" ]; then
    kubectl config use-context "$PREV_CONTEXT" >/dev/null 2>&1 || true
  else
    kubectl config unset current-context >/dev/null 2>&1 || true
  fi
  echo "===== clusters after cleanup ====="
  kind get clusters || true
  echo "===== existing clusters after lab ====="
kubectl --context kind-gitops-lab get nodes --no-headers || true
kubectl --context kind-cloud-poc get nodes --no-headers || true
echo "===== host listeners left alone ====="
  docker ps --format '{{.Names}} {{.Ports}}' | grep -E 'gitops-lab|cloud-poc|cloud-ops|festive_joliot' || true
  echo "CLEANUP_DONE previous_exit=${status}"
  exit "$status"
}
trap cleanup EXIT

echo "===== $(date '+%Y-%m-%dT%H:%M:%S%z') ====="
echo "===== tools ====="
kubectl version --client
kind version
helm version || echo "helm_exit=$?"
echo "previous_context=${PREV_CONTEXT:-<unset>}"

echo "===== existing clusters, read only ====="
kind get clusters
kubectl --context kind-gitops-lab get nodes -o wide || true
kubectl --context kind-cloud-poc get nodes -o wide || true

echo "===== tag local kind node ====="
docker tag a1ed56cfb0e7 kindest/node:v1.37.0
docker image inspect kindest/node:v1.37.0 --format '{{.Id}}'

if kind get clusters | grep -qx k8s-lab; then
  echo "k8s-lab already exists; leaving it in place"
else
  echo "===== kind create k8s-lab ====="
  if ! kind create cluster --config "$ROOT/kind-config.yaml" --image kindest/node:v1.37.0; then
    echo "first create failed; retry once"
    kind delete cluster --name k8s-lab || true
    kind create cluster --config "$ROOT/kind-config.yaml" --image kindest/node:v1.37.0
  fi
fi

echo "===== version and readiness ====="
kubectl --context "$CONTEXT" version
kubectl --context "$CONTEXT" cluster-info
kubectl --context "$CONTEXT" get nodes -o wide
kubectl --context "$CONTEXT" get pods -n kube-system -o wide
kubectl --context "$CONTEXT" get leases -n kube-node-lease
echo "----- readyz -----"
kubectl --context "$CONTEXT" get --raw='/readyz?verbose' || true
echo
echo "----- runtime -----"
kubectl --context "$CONTEXT" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" kubelet="}{.status.nodeInfo.kubeletVersion}{" runtime="}{.status.nodeInfo.containerRuntimeVersion}{" os="}{.status.nodeInfo.operatingSystem}{" arch="}{.status.nodeInfo.architecture}{"\n"}{end}'

echo "===== wait for node ====="
kubectl --context "$CONTEXT" wait --for=condition=Ready node --all --timeout=180s
echo "nginx image is pulled by the node. kind load of this multi-arch image failed with a missing content digest, so it is not used."

echo "===== apply study stack ====="
kubectl --context "$CONTEXT" apply -k "$ROOT/manifests"
kubectl --context "$CONTEXT" rollout status deployment/web -n study --timeout=180s
kubectl --context "$CONTEXT" rollout status daemonset/logger -n study --timeout=180s
kubectl --context "$CONTEXT" wait --for=condition=Ready pod/hello -n study --timeout=180s

echo "===== objects ====="
kubectl --context "$CONTEXT" get deploy,rs,ds,po,svc,endpoints,ingress,cm,secret,pvc,hpa,quota,sa,role,rolebinding -n study

echo "===== service read ====="
kubectl --context "$CONTEXT" exec -n study deploy/web -- wget -qO- http://web.study.svc.cluster.local/
echo
kubectl --context "$CONTEXT" exec -n study deploy/web -- cat /etc/study/token
echo

echo "===== job ====="
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/job.yaml"
kubectl --context "$CONTEXT" wait --for=condition=complete job/once -n study --timeout=120s
kubectl --context "$CONTEXT" logs -n study job/once

echo "===== emptyDir disappears with the pod ====="
TARGET="$(kubectl --context "$CONTEXT" get pod -n study -l app=web -o jsonpath='{.items[0].metadata.name}')"
echo "write_pod=${TARGET}"
kubectl --context "$CONTEXT" exec -n study "$TARGET" -- sh -c 'echo scratch-note > /scratch/note && cat /scratch/note'
kubectl --context "$CONTEXT" delete pod -n study "$TARGET"
kubectl --context "$CONTEXT" rollout status deployment/web -n study --timeout=180s
echo "----- pods after replacement -----"
kubectl --context "$CONTEXT" get pods -n study -l app=web -o wide
NEW="$(kubectl --context "$CONTEXT" get pod -n study -l app=web -o jsonpath='{.items[0].metadata.name}')"
echo "read_pod=${NEW}"
if kubectl --context "$CONTEXT" exec -n study "$NEW" -- cat /scratch/note; then
  echo "EMPTYDIR_SURVIVED"
else
  echo "EMPTYDIR_GONE exit=$?"
fi
kubectl --context "$CONTEXT" exec -n study deploy/web -- wget -qO- http://127.0.0.1/
echo

echo "===== bare pod is not recreated ====="
kubectl --context "$CONTEXT" delete pod hello -n study
if kubectl --context "$CONTEXT" get pod hello -n study; then
  echo "HELLO_STILL_PRESENT"
else
  echo "HELLO_NOT_RECREATED exit=$?"
fi

echo "===== quota ====="
kubectl --context "$CONTEXT" describe quota study -n study

echo "===== rbac ====="
echo -n "list_pods="
kubectl --context "$CONTEXT" auth can-i list pods -n study --as=system:serviceaccount:study:reader || true
echo -n "list_secrets="
kubectl --context "$CONTEXT" auth can-i list secrets -n study --as=system:serviceaccount:study:reader || true

echo "===== hpa ====="
sleep 5
kubectl --context "$CONTEXT" get hpa -n study
kubectl --context "$CONTEXT" describe hpa web -n study

echo "===== scheduling ====="
kubectl --context "$CONTEXT" describe pod unschedulable -n study | sed -n '/Node-Selectors/,+2p;/Events/,$p'

echo "===== pvc ====="
kubectl --context "$CONTEXT" describe pvc data -n study | sed -n '/Status/,+8p;/Events/,$p'

echo "===== ingress ====="
kubectl --context "$CONTEXT" describe ingress web -n study

echo "===== privileged pod rejected ====="
set +e
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/privileged.yaml"
PRIV_EXIT=$?
set -e
echo "privileged_apply_exit=${PRIV_EXIT}"

echo "===== crashloop ====="
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/crash.yaml"
sleep 8
kubectl --context "$CONTEXT" get pods -n study -l app=crash -o wide
kubectl --context "$CONTEXT" logs -n study -l app=crash --tail=20 || true
kubectl --context "$CONTEXT" delete deployment crash -n study

echo "===== explain first lines ====="
kubectl --context "$CONTEXT" explain deployment | head -n 20 || true
kubectl --context "$CONTEXT" explain hpa | head -n 12 || true

echo "LAB_COMMANDS_DONE"
