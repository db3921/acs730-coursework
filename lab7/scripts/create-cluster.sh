#!/usr/bin/env bash
#
# create-cluster.sh -- build (or rebuild) the Lab 7 kind cluster from nothing.
# The cluster lives in Docker on this workstation, so it does not survive
# a stop/start or a lab reset. Run from the repository root.
 
set -euo pipefail
 
CLUSTER="acs730"
NS="lab7"
TAG="${1:-v1}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
 
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "==> Deleting the old $CLUSTER cluster"
  kind delete cluster --name "$CLUSTER"
fi
 
echo "==> Creating the $CLUSTER cluster"
kind create cluster --config lab7/kind-cluster.yaml
 
echo "==> Building and loading acs730-lab4:$TAG"
docker build -t "acs730-lab4:$TAG" lab4/
kind load docker-image "acs730-lab4:$TAG" --name "$CLUSTER"
 
# The Namespace has to exist before anything that lives in it, and applying
# the folder in one go does not guarantee that: kubectl walks a directory in
# filename order, where namespace.yaml sorts after configmap.yaml. So the
# Namespace gets its own apply first, every time.
if [ -f lab7/k8s/namespace.yaml ]; then
  kubectl apply -f lab7/k8s/namespace.yaml
fi
 
if [ -f lab7/k8s/deployment.yaml ]; then
  kubectl apply -f lab7/k8s/
  kubectl -n "$NS" rollout status deployment/acs730-lab4 --timeout=120s
fi
 
# Added in Part 2 of 2, Part 1. Not a graded deliverable -- a convenience this walkthrough
# adds so you are not re-minting a kubeconfig by hand after every rebuild.
# The guard is why this script works before that file exists.
if [ -x lab7/scripts/mint-deployer-kubeconfig.sh ]; then
  ./lab7/scripts/mint-deployer-kubeconfig.sh
fi
 
echo "==> Done. Try: curl -s http://localhost:30080/healthz"
