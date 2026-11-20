# Lab 7 - Kubernetes Fundamentals and CI/CD to Kubernetes

## Week 9

### Pinned tool versions
This lab uses kubectl v1.31.1, kind v0.24.0 (node image kindest/node:v1.31.0) and kubeconform v0.8.0, installed by `scripts/install-lab-tools.sh lab7`; the lab7-ci workflow pins the same kubeconform v0.8.0. They are pinned because an unpinned kubectl against a kind node image built for a different minor version produces skew warnings and, eventually, API calls that do not exist. Pinning makes "it worked for me" reproducible, and keeps local and CI validation in agreement on what `-strict` means.

### Why kind on the EC2 workstation, not EKS
This is a deliberate cost decision. The Learner Lab gives $50 for the entire term, and an EKS control plane bills per hour (about $0.10/hour, roughly $73 a month) whether or not anything is deployed, which would use up the term budget on its own before any worker nodes. kind runs the cluster as Docker containers on the workstation we are already paying for, so it adds nothing. `eks:CreateCluster` is permitted in this account; we chose not to use it, not because we could not.

### What a label selector does
The Deployment's `selector.matchLabels` (`app: acs730-lab4`) is how it recognises its own pods. The Service's `selector` is an independent match that decides which pod IPs end up in its Endpoints; neither is inherited from the other. A mismatch looks like a Deployment creating pods forever, or `kubectl get endpoints` reading `<none>` while the pods are Running.

### Recreating everything from nothing
`lab7/scripts/create-cluster.sh` deletes any existing `acs730` cluster, creates a new one from `lab7/kind-cluster.yaml`, builds `acs730-lab4:v1` from `lab4/`, loads it into the node with `kind load`, applies `namespace.yaml` on its own, then applies the whole `lab7/k8s/` folder and waits for the rollout. The Namespace goes first because kubectl applies a folder in filename order, and `configmap.yaml` sorts before `namespace.yaml`, so it would be rejected for a namespace that does not exist yet.

### Why the tag is v1, and why kind load is needed
A fixed tag names one specific image; with `latest`, Kubernetes defaults to `imagePullPolicy: Always` and tries to pull from a registry on every start, which fails for a locally built image. The kind node is a separate container with its own image store, so it cannot see images in the workstation's Docker. Before `kind load docker-image`, both pods sat in `ErrImagePull` / `ImagePullBackOff` ("pull access denied, repository does not exist"); after loading, they reached 1/1 Running without re-applying anything, because the kubelet retries the pull on a back-off.

### Why the Service is NodePort
kind has no cloud provider to provision a load balancer, so a `type: LoadBalancer` Service sits at `EXTERNAL-IP <pending>` forever with no error. NodePort 30080 opens the port on the node container, and `extraPortMappings` in `lab7/kind-cluster.yaml` maps it to `127.0.0.1:30080` on the workstation, which is what `week09-app-response.txt` reached.

### What scaling showed
`week09-scaling.txt` shows 2/2 with two pods before and 4/4 with four pods after. The two original pods kept their age (3h13m) and two new ones (4s) were added; scaling up does not restart running pods. Deleting all four pods did not leave zero: the ReplicaSet replaced them within seconds because the declared count was still 4. Only `kubectl scale --replicas=2` brought it back to two.

## Week 10

### Why a GitHub-hosted runner cannot reach the cluster
This is a reachability problem, not a permissions one. The kind API server listens on 127.0.0.1 inside a Docker container on the EC2 workstation: it has no public address, no DNS name, a security group in front of the instance, and no inbound route from GitHub's network. No token or secret fixes that, because nothing is being refused; there is nothing for a GitHub-hosted VM to connect to. The self-hosted runner works because it runs on the workstation itself and only polls GitHub outbound for jobs. `lab7-ci.yml` is fine on `ubuntu-latest` because it only reads files and never touches a cluster.

### Self-hosted runner risk
A self-hosted runner executes the workflow from the triggering commit on my workstation, as `ec2-user`, with the LabRole instance profile, docker group membership and my kubeconfig, so a workflow triggered by a fork pull request would run a stranger's code on my machine. Mitigations: `lab7-deploy.yml` triggers only on push to `main` (plus manual `workflow_dispatch`) and never on `pull_request`; fork pull request workflows require approval for all external contributors; the pipeline authenticates as the `lab7-deployer` ServiceAccount instead of cluster-admin; and the runner is removed at the end of the lab.

**Residual risk:** anyone who can push to `main` (me, or anyone who obtains my GitHub credentials) still gets arbitrary code execution on the workstation as `ec2-user`, with the LabRole instance profile and docker group membership, which is effectively root on that machine; that user can also read the kind admin kubeconfig in `~/.kube/config`, so the scoped ServiceAccount limits the pipeline as written, not a malicious workflow. The mitigations reduce who can trigger a job, not what a job can do. The control that would actually reduce this is an ephemeral runner on a throwaway machine that is not also my workstation.

### What the deployer ServiceAccount can and cannot do
From `week10-auth-can-i.txt`: patch deployments in lab7 - yes; delete deployments - no; read secrets - no; create namespaces - no; delete nodes - no. It can write ConfigMaps because configuration is something a deploy legitimately changes; it cannot read Secrets because reading Secrets in a namespace means reading every credential in it. The pods still get `APP_TOKEN` because a `secretKeyRef` is resolved by the kubelet on the node under its own identity, not by whoever created or updated the Deployment.

### Why rollout status is its own step
`kubectl set image` returns success as soon as the API server accepts the edit; it says nothing about whether a pod started. `kubectl rollout status --timeout=120s` blocks until the new ReplicaSet is fully available and exits non-zero if it is not, and as its own `run:` step that exit code fails the job. Without it, the broken-probe deploy would have reported green while the new pods sat at 0/1; `week10-deploy-red.png` shows the red X on exactly that step, with every earlier step green, after a 120-second timeout.

### Rollback
The broken deploy (readiness probe pointed at `/not-a-real-path`) produced new pods that ran but never became ready, while the old pods kept serving, so `/healthz` stayed ok throughout. A plain `kubectl rollout undo` went back one revision to the broken deploy's intermediate revision, because the workflow's apply and set image steps create two revisions per deploy, and that revision still had the broken probe. `kubectl get rs` with the revision annotation showed revision 4 (`sha-3c6b79824874`, `/healthz`) as the last good deploy, and `rollout undo --to-revision=4`, run as the `lab7-deployer` ServiceAccount, restored it (`week10-rollout-undo.txt`: 2/2, probe `/healthz`). Undo changed only the cluster; `main` still contained the broken probe, so the next deploy would have reapplied it. The commit "fix the readiness probe path" (PR #37) fixed the repository, and the deploy after it was green.

## Experiments

### Experiment 2 - Ask kind for a load balancer
**Prediction:** EXTERNAL-IP would stay `<pending>` indefinitely, with no error anywhere.
**Result:** After patching the Service to `type: LoadBalancer`, `kubectl get svc -w` showed `EXTERNAL-IP <pending>` for the full two minutes; `kubectl describe svc` showed `Events: <none>` and `kubectl get events` had nothing for the Service. The NodePort 30080 stayed allocated, so the app was still reachable the old way.
**Explanation:** A LoadBalancer Service only records a request; a cloud controller is what provisions the load balancer and writes its address back. kind has no cloud provider or load-balancer controller, so nothing ever answers and nothing reports an error. On EKS, the AWS cloud controller (or the AWS Load Balancer Controller) would create an ELB/NLB and fill EXTERNAL-IP with its DNS name. Reverted to NodePort.

### Experiment 4 - Change a ConfigMap and watch nothing happen
**Prediction:** Running pods would keep `info`; only new pods after a restart would see `debug`.
**Result:** After setting `LOG_LEVEL` to `debug`, the ConfigMap read `debug` but `printenv LOG_LEVEL` in the running pod still printed `info`. After `kubectl rollout restart deployment/acs730-lab4`, the new pods printed `debug`.
**Explanation:** `envFrom` copies ConfigMap values into the environment once, when the container starts; later edits are never pushed into running containers. So a deploy that only changes a ConfigMap applies successfully and reports success while the application keeps the old setting, until the pods are replaced (a rollout restart, or a change to the pod template). Set back to `info`.
