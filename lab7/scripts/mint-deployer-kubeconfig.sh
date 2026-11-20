#!/usr/bin/env bash
#
# mint-deployer-kubeconfig.sh -- build ~/.kube/lab7-deployer.conf, a
# kubeconfig that authenticates as the lab7-deployer ServiceAccount in the
# lab7 namespace instead of as the kind cluster admin.
# Helper for this walkthrough, not a graded file. Run from the repo root.

set -euo pipefail

CONF="$HOME/.kube/lab7-deployer.conf"
CTX="kind-acs730"
NS="lab7"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

kubectl config use-context "$CTX" >/dev/null
kubectl apply -f lab7/k8s/namespace.yaml
kubectl apply -f lab7/k8s/rbac.yaml

TOKEN="$(kubectl -n "$NS" create token lab7-deployer --duration=24h)"

mkdir -p "$HOME/.kube"
kubectl config view --minify --raw > "$CONF"
chmod 600 "$CONF"

KUBECONFIG="$CONF" kubectl config unset users >/dev/null
KUBECONFIG="$CONF" kubectl config set-credentials lab7-deployer --token="$TOKEN" >/dev/null
KUBECONFIG="$CONF" kubectl config set-context --current \
  --user=lab7-deployer --namespace="$NS" >/dev/null

echo "==> $CONF authenticates as the lab7-deployer ServiceAccount in $NS"

# kubectl auth can-i exits 1 on "no"; || true keeps set -e from stopping the script
echo -n "can patch deployments in $NS:  "; KUBECONFIG="$CONF" kubectl auth can-i patch deployments -n "$NS" || true
echo -n "can delete deployments in $NS: "; KUBECONFIG="$CONF" kubectl auth can-i delete deployments -n "$NS" || true
echo -n "can read secrets in $NS:       "; KUBECONFIG="$CONF" kubectl auth can-i get secrets -n "$NS" || true
echo -n "can create namespaces:         "; KUBECONFIG="$CONF" kubectl auth can-i create namespaces || true
echo -n "can delete nodes:              "; KUBECONFIG="$CONF" kubectl auth can-i delete nodes || true
