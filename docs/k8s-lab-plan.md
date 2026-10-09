# Kubernetes lab plan: 3 remote VMs → CKA

**Context:** 3 VMs × 16 GB RAM on a remote network, reached over SSH. Manifests live in Git and are synced by Flux. Renovate opens PRs under my username. A local **minikube** sandbox on my Mac runs alongside as a disposable training ground.

**End goal:** pass the CKA.

**Rule for the whole plan:** every phase includes **break drills**. Troubleshooting is 30% of the exam, so it is practiced throughout, not saved for the end.

🔸 marks a decision that is still open. Each one gets a short ADR when it is made.

---

## Target architecture

```mermaid
flowchart LR
    subgraph mac["My Mac"]
        kubectl["kubectl"]
    end

    subgraph github["GitHub"]
        repo[("homelab repo<br/>clusters/ infrastructure/ apps/")]
        renovate["Renovate<br/>(PRs under my username)"]
    end

    subgraph remote["Remote network"]
        subgraph cluster["Kubernetes cluster"]
            n1["VM 1<br/>16 GB"]
            n2["VM 2<br/>16 GB"]
            n3["VM 3<br/>16 GB"]
            flux["Flux controllers"]
        end
    end

    kubectl -- "SSH tunnel → API server :6443<br/>🔸 K0" --> n1
    renovate -- "opens PRs" --> repo
    flux -- "pulls (outbound HTTPS only)" --> repo
    flux -- "applies manifests" --> cluster
    user(["Browser"]) -- "HTTPS, cert signed by my intermediate CA<br/>🔸 entry method K3" --> cluster
```

Flux **pulls** from GitHub, so the cluster only needs outbound HTTPS. Nothing has to reach into the remote network except my SSH access.

---

## Roadmap

```mermaid
flowchart TD
    K0["K0 · Access & foundations"]
    K1["K1 · Cluster built by hand<br/>+ destroy/rebuild from runbook"]
    K2["K2 · Flux bootstrap<br/>+ practice zone"]
    K3["K3 · Platform infra<br/>traffic in + TLS"]
    K4["K4 · First stateless app<br/>podinfo"]
    K5["K5 · Renovate"]
    K6["K6 · Storage & PostgreSQL<br/>Uptime Kuma → Miniflux → Forgejo"]
    K7["K7 · Security basics<br/>RBAC + NetworkPolicy"]
    K8["K8 · Cluster operations<br/>etcd, upgrades, scheduling"]
    K9["K9 · Full destroy & rebuild"]
    K10["K10 · Exam preparation"]

    M["M · minikube sandbox<br/>(local, disposable, starts now)"]

    K0 --> K1 --> K2 --> K3 --> K4 --> K5
    K4 --> K6 --> K7 --> K8 --> K9 --> K10

    M -.->|"rehearse objects before<br/>deploying them for real"| K4
    M -.->|"timed drills"| K10

    PKI[/"Case 2.2<br/>intermediate CA"/] -.-> K3
    SEC[/"🔸 Secrets-in-Git decision"/] -.->|blocks| K6
    K1 -.->|"CNI choice decides<br/>NetworkPolicy enforcement"| K7
```

Solid arrows show the phase order. Dotted arrows show dependencies that are easy to forget.

---

## Phases

### M: minikube sandbox (parallel track)
- **Why:** it runs on my Mac **today**, while K0 is blocked waiting for VM access. Breaking it costs nothing: delete and recreate in a minute.
- **Role:** a training ground, not a second lab. No Flux, no Renovate, nothing in Git that depends on it. Everything is done by hand with `kubectl`, which is what the exam tests.
- **What I practice:**
  - every object before deploying it for real on the remote cluster: Pod, Deployment, Service, ConfigMap, Secret, probes, requests/limits, Jobs/CronJobs (this matches FORMATION case 6.1);
  - RBAC and NetworkPolicy experiments, isolated from the real cluster;
  - multi-node scheduling (taints, affinity, drain) using minikube's multi-node mode;
  - looking at the control plane from the inside (`minikube ssh`): static pod manifests, kubelet, etcd. minikube is bootstrapped with kubeadm, so this transfers to K1 and K8.
- 🔸 Driver: which one, given that Lima is already on my Mac?
- ⚠️ **Limits to remember:** a single machine, no real network between nodes, no exposure to the outside world. Ingress, TLS and anything that depends on the remote network stay K3 topics.
- **Done when:** this phase never ends. It feeds K4 (rehearsal) and K10 (drills).
- **CKA:** Workloads & Scheduling, Troubleshooting, speed.

### K0: Access and foundations
- **Goal:** reach the nodes and know their network.
- 🔸 How I reach the API server (6443), and which address my kubeconfig points to. This decides the API server certificate SANs.
- **Done when:** I can SSH to all 3 nodes, and their IPs, OS and outbound internet access are written down.

### K1: Cluster built by hand
- **Goal:** a bare cluster, built the way the exam expects.
- 🔸 Distribution: kubeadm, k3s, or both. The CKA uses kubeadm.
- 🔸 Topology: 1 control plane + 2 workers, or 3 control planes.
- 🔸 CNI. ⚠️ It must enforce NetworkPolicy, otherwise K7 can't be done.
- **Deliverable:** a written runbook, since Ansible comes later.
- **Done when:** 3 nodes are Ready, then the cluster is **destroyed and rebuilt from the runbook alone**.
- **CKA:** Cluster Architecture, Installation & Configuration.

### K2: Flux bootstrap and a practice zone
- **Goal:** the cluster syncs itself from Git, and there is still a place where Flux does not revert manual changes.
- 🔸 Repo structure, and how Flux authenticates to the repo.
- 🔸 Which namespaces Flux manages and which are left for manual practice.
- **Done when:** a Git change shows up in the cluster without `kubectl apply`, and a manual change in the practice zone survives.

### K3: Platform infrastructure, getting traffic in
- **Goal:** HTTPS from the outside, with a certificate signed by my intermediate CA (case 2.2).
- 🔸 How traffic gets in on a network I don't control: NodePort, hostPort or LoadBalancer.
- 🔸 Ingress or Gateway API (Gateway API is in the CKA).
- 🔸 How cert-manager gets the CA key, and what that exposes.
- **Test app:** traefik/whoami.
- **Done when:** whoami answers over HTTPS and my Mac trusts the certificate.
- **CKA:** Services & Networking.

### K4: First stateless app
- **Goal:** podinfo deployed only through Git.
- **What I practice:** probes, requests/limits, rolling updates, rollback.
- **Done when:** podinfo is deleted by hand and Flux recreates it, and a bad version is rolled back.
- **CKA:** Workloads & Scheduling.

### K5: Renovate
- **Goal:** new versions arrive as PRs.
- 🔸 Where Renovate runs, the token's scope, and auto-merge or review every PR.
- **Done when:** a Renovate PR on podinfo is merged and Flux rolls it out.

### K6: Storage and PostgreSQL
- **Goal:** state that survives pod restarts.
- 🔸 Storage provisioner (local first, see FORMATION section 9).
- 🔸 PostgreSQL: one per app, one shared, or an operator.
- ⚠️ **Blocked by** the secrets-in-Git decision, because Miniflux needs a database password.
- **Order:** Uptime Kuma (SQLite) → Miniflux (PostgreSQL) → Forgejo.
- **Done when:** a pod is deleted and its data is still there.
- **CKA:** Storage.

### K7: Security basics
- **Goal:** least privilege inside the cluster.
- **What I practice:** RBAC (a ServiceAccount with minimal rights), NetworkPolicy (only Miniflux can reach its PostgreSQL).
- **Done when:** an unauthorized pod's connection to PostgreSQL is refused.

### K8: Cluster operations
- **Goal:** the operational tasks the exam focuses on.
- **What I practice:** etcd backup and restore, a kubeadm minor upgrade, drain/cordon, taints and affinity, static pods.
- **Done when:** etcd is restored from a backup and the apps come back, and the cluster has been upgraded one minor version.
- **CKA:** Cluster Architecture, Troubleshooting.

### K9: Full destroy and rebuild
- **Goal:** prove the whole setup works (Règle 2).
- **Done when:** VMs reinstalled, cluster rebuilt from the runbook, Flux bootstrapped, apps back. Everything Git can't restore (data) is written down as a known gap.

### K10: Exam preparation
- Timed drills on minikube (fast reset between attempts): imperative `kubectl`, generating YAML with `--dry-run=client -o yaml`, finding things fast in the kubernetes.io docs.
- killer.sh simulator, twice.
- Book the exam.

---

## Open decisions, in the order they block

| # | Decision | Blocks | Status |
|---|---|---|---|
| 0 | minikube driver | M | 🔸 Open |
| 1 | Access to 6443 | K0 | 🔸 Open |
| 2 | Distribution, topology, CNI | K1 | 🔸 Open |
| 3 | Repo structure and practice zone | K2 | 🔸 Open |
| 4 | Traffic entry, Ingress vs Gateway API | K3 | 🔸 Open |
| 5 | Secrets in Git | K6 | 🔸 Open |
| 6 | Storage and PostgreSQL model | K6 | 🔸 Open |
| 7 | Renovate location, token scope, merge policy | K5 | 🔸 Open |

## Later, not CKA

Kyverno, Cilium in depth, supply chain (signing, SBOM), Velero, Flagger, writing an operator in Go. Each needs a real trigger first.
