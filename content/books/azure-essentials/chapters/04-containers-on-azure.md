@chapter
id: azr-ch04-containers-on-azure
order: 4
title: Containers on Azure
summary: Azure offers a spectrum of container services from fully managed serverless (Container Apps) to self-managed clusters (AKS), each with distinct control, cost, and operational tradeoffs you need to understand before picking one.

@card
id: azr-ch04-c001
order: 1
title: AKS: Managed Kubernetes, Defined Boundaries
teaser: AKS gives you Kubernetes without paying for the control plane — but "managed" has a specific meaning and you need to know exactly where Microsoft's responsibility ends and yours begins.

@explanation

Azure Kubernetes Service (AKS) provides a free managed control plane: the API server, etcd, scheduler, and controller manager are all Microsoft's responsibility. You pay only for the worker nodes (VMs) that run your workloads. For a cluster with three nodes, you're paying for three VMs — not six.

What Microsoft manages for you:
- Control plane uptime and patching
- etcd backups
- API server TLS certificates
- Kubernetes version upgrades for the control plane (when you trigger them)

What you still manage:
- Node OS patching (you can automate this with node image auto-upgrade, but it's opt-in)
- Cluster upgrades for node pools — a control-plane upgrade does not automatically upgrade nodes
- Application workloads, RBAC, network policies, and ingress

The AKS upgrade process matters in practice. When you upgrade, the control plane upgrades first. Node pools are upgraded separately, in a rolling fashion: one node is cordoned and drained, replaced with an upgraded node, then the next node proceeds. You can configure `maxSurge` to spin up extra nodes during the upgrade to maintain capacity, which avoids downtime at the cost of brief extra spend.

**System vs user node pools** is a distinction you'll hit immediately. System node pools run critical cluster services (CoreDNS, konnectivity, metrics-server). You must have at least one. User node pools run your application workloads. Separating them lets you apply taints and tolerations to keep application pods off system nodes and vice versa — important for isolating noisy workloads from cluster stability.

> [!info] AKS free control plane is genuinely free — it does not cost you anything even at hundreds of nodes. The only cost is the node VMs, persistent volumes, load balancers, and egress.

@feynman

AKS is like a managed database service but for Kubernetes: the engine is Microsoft's problem, and your job starts at the schema — or in this case, the workloads.

@card
id: azr-ch04-c002
order: 2
title: AKS Node Pool Types and When to Mix Them
teaser: Picking the wrong VM family for a node pool is one of the most expensive silent mistakes in AKS — here's the taxonomy and the decision logic.

@explanation

AKS node pools map directly to Azure VM families. The choice of family determines CPU-to-memory ratio, availability of accelerators, and price per hour.

Common families and when to reach for them:
- **D-series (general-purpose):** Balanced CPU and memory. `Standard_D4s_v5` (4 vCPU, 16 GiB) is the default starting point for most web services and APIs. Good default.
- **E-series (memory-optimized):** High memory relative to CPU. Reach for E-series when your workloads are in-memory caches, large JVM heaps, or anything that OOM-kills on D-series. `Standard_E8s_v5` gives 8 vCPU and 64 GiB.
- **NC/ND-series (GPU):** NVIDIA GPU-equipped. NC-series (T4/A100) for inference; ND-series (A100/H100) for training. These are expensive — don't use them for a system node pool.
- **Spot node pools:** Azure Spot VMs at up to 90% discount, but they can be evicted with 30 seconds notice. Use for batch processing, CI runners, or fault-tolerant background jobs. Never run stateful or latency-sensitive workloads on spot.
- **ARM64 (Ampere Altra):** `Dpsv5` family. Better price-to-performance for workloads that are already ARM64-compiled. Your container images must be built for ARM64 or be multi-arch.

Mixing node pools is the standard pattern for production clusters. A typical setup: one system node pool on `Standard_D4s_v5`, one user node pool on `Standard_D8s_v5` for standard services, and a spot node pool on `Standard_D8s_v5` for async workers. Add a GPU pool only when you actually need inference.

> [!tip] Use node selectors and tolerations to pin workloads to the right pool. Without them, the scheduler will place pods arbitrarily across pools, which can land a GPU-trained model inference pod on a general-purpose node.

@feynman

Node pool selection is like picking EC2 instance types in an Auto Scaling group — the VM family is the chassis, and getting it wrong doesn't crash the car, it just costs you money every second the engine is running.

@card
id: azr-ch04-c003
order: 3
title: Azure Container Apps: Serverless Containers Without the Cluster
teaser: Container Apps is AKS for teams who don't want to know about nodes, node pools, or Kubernetes — it abstracts all of that behind a scale-to-zero, revision-based deployment model.

@explanation

Azure Container Apps is built on top of AKS, KEDA, and Dapr, but you never touch any of those directly. Microsoft runs the Kubernetes cluster; you deploy container apps into an **environment** (a shared networking and logging boundary) and configure scaling rules.

The deployment model has two key primitives:
- **Environment:** A logical grouping of apps that share a VNet, Log Analytics workspace, and Dapr configuration. Think of it as the namespace boundary you'd manage manually in AKS.
- **App + Revision:** Each new deployment creates a new revision. You can split traffic between revisions — send 10% to a canary revision while 90% stays on the current one. Revisions are immutable after creation.

Scale-to-zero is on by default. If your app receives no traffic, it scales to zero replicas and you pay nothing. When a request arrives, it cold-starts in seconds. This makes Container Apps very cost-effective for low-traffic APIs, event processors, and background jobs that run sporadically.

When to use Container Apps over AKS:
- You don't need direct Kubernetes API access (no custom CRDs, no Helm charts that expect cluster-admin)
- Your scaling story is traffic-based or event-based (not workload-specific autoscaling)
- You want zero ops overhead for the cluster itself
- Small to medium services where per-app billing makes more sense than paying for idle nodes

When to prefer AKS:
- You need specific node types (GPUs, high-memory VMs)
- You have existing Helm charts or operators that require direct cluster access
- You need fine-grained network policies or pod security policies
- You're running stateful workloads that need custom storage configuration

> [!info] Container Apps pricing is per vCPU-second and per GiB-second of active consumption. At low traffic, it will cost you significantly less than a minimum two-node AKS cluster idling overnight.

@feynman

Container Apps is to AKS what Vercel is to a self-managed Nginx cluster — the same deployment happens, but the abstraction layer means you only configure what matters to your app.

@card
id: azr-ch04-c004
order: 4
title: KEDA: Event-Driven Autoscaling Beyond CPU
teaser: Kubernetes HPA scales on CPU and memory; KEDA scales on the thing that actually matters for your workloads — queue depth, event hub lag, Service Bus message count, and dozens of other external signals.

@explanation

Kubernetes Horizontal Pod Autoscaler (HPA) is built-in but limited: it scales based on CPU utilization or memory pressure, which is a proxy for load, not a direct measure. For a background worker that processes messages from a queue, CPU is near-zero until a message arrives — HPA will never scale it up in time.

KEDA (Kubernetes Event-Driven Autoscaling) fixes this by introducing **scalers** — connectors to external systems that tell KEDA the current event backlog. KEDA then scales the deployment accordingly, including all the way to zero.

Key scalers for Azure workloads:
- **Azure Service Bus:** Scale based on active message count or dead-letter count in a queue or topic subscription.
- **Azure Event Hubs:** Scale based on consumer group lag — how far behind your processors are from the latest offset.
- **Azure Storage Queue:** Scale based on approximate message count.
- **HTTP:** Scale based on in-flight HTTP request count (requires KEDA HTTP add-on).
- **CPU/Memory:** KEDA also wraps HPA behavior, so you can consolidate all scaling configuration in one place.

A concrete example: you have a worker that processes images uploaded to a Storage Queue. With plain HPA, the worker pod sits idle consuming memory but not scaling. With KEDA, you define `queueLength: 5` as the target — one pod per 5 pending messages. At 100 messages, KEDA scales to 20 pods. At 0 messages, it scales to 0.

KEDA is the engine that runs inside Container Apps when you configure scaling rules. If you're on AKS, you can install KEDA as an add-on with `az aks enable-addons --addons keda`.

> [!warning] Scale-to-zero has a cold-start cost. For latency-sensitive workloads, set `minReplicaCount: 1` to keep at least one warm pod. The savings from full scale-to-zero rarely justify the tail-latency impact for user-facing services.

@feynman

KEDA is the difference between scaling based on how hot your server is versus scaling based on how long the line of customers is — one is a symptom, the other is the actual signal.

@card
id: azr-ch04-c005
order: 5
title: Dapr on Container Apps: Distributed Primitives Without the Plumbing
teaser: Dapr gives your microservices pub/sub, state management, and service invocation as sidecar APIs — and on Container Apps, you get all of that without managing the sidecar yourself.

@explanation

Dapr (Distributed Application Runtime) is a portable, event-driven runtime for building distributed applications. Its core idea: abstract the messy parts of microservice communication behind a consistent HTTP/gRPC API, so your code doesn't need to know whether pub/sub is backed by Service Bus, Redis Streams, or Kafka.

The sidecar architecture is the key: Dapr runs as a container alongside your app container. Your app talks to `localhost:3500` (Dapr's HTTP port) and Dapr handles the actual communication, retries, and observability with the external system.

Dapr's building blocks relevant to Azure workloads:
- **Pub/Sub:** Publish and subscribe to topics. Configure Service Bus or Event Hubs as the component; your code just calls `POST /v1.0/publish/{pubsubname}/{topic}`.
- **State management:** Key/value store with consistent APIs. Back it with Azure Cosmos DB or Redis Cache without changing your application code.
- **Service invocation:** Call other services by name with automatic service discovery, retries, and mTLS. No service mesh required.
- **Bindings:** Trigger your app on external events (a new blob in Storage, a new message in a queue) or invoke external services (send an email, write to a database) without SDK dependencies.

On Container Apps, you enable Dapr at the environment level and opt in per app. Container Apps manages the sidecar lifecycle — you never write a Kubernetes pod spec with two containers. Set `daprEnabled: true` and provide a component YAML; Container Apps does the rest.

The tradeoff: Dapr adds a network hop (localhost, so fast) and introduces its own component configuration surface. If you already have direct SDK integrations that work well, Dapr adds complexity without proportional benefit.

> [!tip] Dapr shines most when you need portability (same app code across multiple cloud providers) or when you're building many small services that all need the same cross-cutting communication patterns.

@feynman

Dapr is like a hardware abstraction layer for your messaging and state infrastructure — your application code programs to the interface, and you swap the driver without rewriting anything.

@card
id: azr-ch04-c006
order: 6
title: Azure Container Instances: On-Demand Containers, No Cluster
teaser: ACI spins up a container in seconds, bills per second, and disappears when done — it's the right tool for short-lived workloads where standing up a cluster would be absurd overkill.

@explanation

Azure Container Instances (ACI) is the simplest compute primitive in Azure's container story: you give it a container image and resource requirements, it runs the container, and you pay per second of vCPU and memory consumption. No cluster, no nodes, no scheduler to think about.

Key characteristics:
- **Startup time:** 5–10 seconds for a fresh container start. Warm restarts are faster.
- **Billing:** Per-second granularity on vCPU and memory. A 30-second batch job costs almost nothing.
- **Container groups:** ACI's unit of deployment is the **container group** — multiple containers on the same host, sharing a network namespace and optional volume mounts. Think of it as a Kubernetes pod without the cluster. This lets you run a sidecar (e.g., a log shipper) alongside your main container.
- **No persistent state:** Container groups are ephemeral. Use Azure Files mounts for shared storage if needed.

Best-fit use cases:
- **Batch and ETL jobs:** Run a data transformation, write results to Blob Storage, exit. Total cost for a 5-minute job on 2 vCPU / 4 GiB: roughly $0.01.
- **CI/CD runners:** Spin up a fresh build environment per pipeline run. No shared state between builds.
- **Burst capacity:** ACI can back AKS virtual nodes — when your AKS cluster is at capacity, pods can overflow onto ACI without pre-provisioning nodes.

ACI vs Container Apps vs AKS at a glance:
- Use ACI for short-lived, on-demand workloads with no ongoing traffic.
- Use Container Apps for long-running services with variable traffic and scale-to-zero.
- Use AKS when you need full cluster control or workloads that outgrow Container Apps constraints.

> [!info] ACI virtual nodes on AKS let you burst Kubernetes workloads directly onto ACI, which is useful for predictable peak workloads (end-of-day batch, overnight report generation) without permanently provisioning the underlying node capacity.

@feynman

ACI is like a serverless function but for containers — you get the isolation and portability of a container without the infrastructure that normally surrounds it.

@card
id: azr-ch04-c007
order: 7
title: Azure Container Registry: Private Images, Secure Pull
teaser: ACR is your private container registry — pick the right tier, use managed identity to pull images without storing credentials anywhere, and let ACR Tasks handle your cloud builds.

@explanation

Azure Container Registry (ACR) stores and distributes Docker and OCI-compatible container images. It integrates deeply with AKS, Container Apps, and ACI — and when you use managed identity for pulls, there are no credentials to rotate, leak, or expire.

**Registry tiers and their key differences:**
- **Basic:** 10 GiB storage, 2 webhooks. Fine for development and small teams. No geo-replication.
- **Standard:** 100 GiB storage, 10 webhooks. The default production choice for most workloads.
- **Premium:** 500 GiB storage, 500 webhooks, **geo-replication**, private link support, customer-managed keys, dedicated data endpoints. Required if you need replicas in multiple regions to reduce pull latency and avoid cross-region data transfer costs.

**Geo-replication (Premium):** Your registry content is replicated to additional Azure regions. When a cluster in East US pulls an image, it pulls from the East US replica — not from the primary in West Europe. This reduces pull latency for large images from seconds to milliseconds.

**ACR Tasks:** Build images in the cloud without a local Docker daemon or a dedicated CI VM. `az acr build --registry myregistry --image myapp:v1 .` streams your build context to Azure and runs the build there. You can also define multi-step tasks and trigger builds on base image updates.

**Content trust:** ACR supports Docker Content Trust for signed images. On Premium, you can use customer-managed keys with Azure Key Vault for encryption.

**Managed identity pull:** Assign the AcrPull role to your AKS cluster's kubelet managed identity or your Container Apps environment's managed identity. No imagePullSecret, no stored credentials in Kubernetes secrets.

> [!warning] The most common ACR mistake is using admin credentials (username/password) for automation instead of managed identity or a service principal with the AcrPull role. Admin credentials are a single shared secret that can't be scoped — if leaked, it has write access to your registry.

@feynman

Managed identity pull from ACR is like SSH certificate authentication instead of passwords — the identity is asserted cryptographically, there's no secret to rotate, and access control is role-based.

@card
id: azr-ch04-c008
order: 8
title: AKS Networking: CNI Modes, Ingress, and Private Clusters
teaser: AKS gives you two CNI models, two popular ingress controllers, and the option to make your API server completely private — understanding the tradeoffs before you create the cluster matters because some of these can't be changed later.

@explanation

AKS networking is one of the areas where you make decisions at cluster creation time that are hard or impossible to change. Get this wrong and you're rebuilding the cluster.

**kubenet vs Azure CNI:**
- **kubenet (basic):** Pods get IPs from a private overlay network. Only nodes are directly routable on your VNet. Pod-to-pod traffic across nodes goes through NAT. Simpler IP management, but pods aren't directly reachable from other VNet resources.
- **Azure CNI (VNet-integrated):** Pods get real VNet IPs. Every pod is directly routable from other subnets, on-premises, and peered VNets. Required for scenarios where pods need to be addressable outside the cluster. Downside: you need to pre-allocate a large subnet (one IP per potential pod, not just per node).
- **Azure CNI Overlay (2024+):** The best of both worlds — pods get IPs from a private overlay but Azure CNI handles routing more efficiently. Removes the subnet exhaustion problem while keeping pod-level routing. This is now the recommended choice for most new clusters.

**Network policies:** Kubernetes Network Policies restrict pod-to-pod traffic. AKS supports two implementations: Azure Network Policy (uses Azure's VNET plumbing) and Calico (open-source, more features). Choose at cluster creation time — you can't switch.

**Ingress controllers:** Two popular options on AKS:
- **NGINX Ingress Controller:** Open-source, flexible, widely understood. You manage it as a deployment in your cluster. Good default for most teams.
- **Application Gateway Ingress Controller (AGIC):** Provisions an Azure Application Gateway for ingress. Adds WAF, TLS offloading at the gateway layer, and tight Azure integration. More expensive ($150+/month for the gateway) but reduces per-cluster operational burden for security-focused teams.

**Private AKS clusters:** The API server gets a private IP, accessible only within your VNet or via peering. No public internet exposure of the Kubernetes API. Required for most regulated or enterprise workloads.

> [!info] Azure CNI Overlay is generally the right default for new clusters in 2024+. It avoids subnet exhaustion, gives you VNet-integrated pods, and eliminates the NAT complexity of kubenet.

@feynman

Picking kubenet vs Azure CNI is like choosing between NAT and a routable IP block for your dev environment — both work, but only one lets other systems on your network talk directly to your containers.

@card
id: azr-ch04-c009
order: 9
title: AKS Security: Workload Identity, Policy, and Secrets
teaser: The four pillars of AKS security in 2024 are workload identity for pod-level Azure auth, Azure Policy for guardrails, Defender for runtime threat detection, and CSI driver for secret injection — using all four closes the most common attack surfaces.

@explanation

**Workload Identity (replacing pod identity):** Pods need to authenticate to Azure services (Key Vault, Storage, databases). The old approach was pod identity (preview for years, now deprecated) or mounting service principal credentials as Kubernetes secrets. The current approach is **workload identity**: a Kubernetes service account is federated with an Azure Managed Identity using OpenID Connect. The pod gets a signed token; Azure validates it. No credentials stored anywhere in the cluster.

Setup requires three things: an Azure Managed Identity with the right RBAC roles, a federated credential linking the identity to a Kubernetes service account + namespace, and the workload identity mutating webhook installed on the cluster (available as an AKS add-on).

**Azure Policy for Kubernetes (Gatekeeper):** Azure Policy integrates with Open Policy Agent Gatekeeper to enforce guardrails on what can run in your cluster. Example policies: disallow privileged containers, require resource limits on all pods, enforce that images come only from your ACR, restrict allowed host ports. Policies are evaluated at admission time — non-compliant pods are rejected before they start.

**Microsoft Defender for Containers:** Runtime threat detection. Analyzes running workloads for anomalous behavior, detects known attack patterns (e.g., cryptomining, privilege escalation), and integrates with Defender for Cloud's unified security posture. Deployed as a DaemonSet on nodes.

**CSI Driver + Azure Key Vault:** The Secrets Store CSI Driver mounts Key Vault secrets as files or environment variables into pods without storing them in Kubernetes Secrets (which are only base64-encoded, not encrypted, in etcd by default). Combine with workload identity for fully credential-free secret access from pods.

> [!warning] Kubernetes Secrets are not encrypted at rest in etcd unless you explicitly enable at-rest encryption in AKS. Either enable it or use the CSI driver + Key Vault so secrets never land in etcd.

@feynman

Workload identity is like OAuth for your pods — instead of handing every pod a username and password to Azure, you issue a signed token scoped to a specific identity that Azure already trusts.

@card
id: azr-ch04-c010
order: 10
title: AKS Scaling: Four Layers, Each Solving a Different Problem
teaser: AKS has four distinct scaling mechanisms that operate at different levels — confusing them leads to either over-provisioned clusters or workloads that can't get scheduled during traffic spikes.

@explanation

AKS scaling operates at multiple layers simultaneously, and understanding which layer solves which problem prevents you from over-engineering (or under-engineering) your scaling strategy.

**1. Cluster Autoscaler (node-level):** Adds or removes nodes from a node pool based on whether pods are pending due to insufficient node capacity. If a pod can't be scheduled because no node has enough CPU/memory, Cluster Autoscaler provisions a new node. When nodes are underutilized and pods can be rescheduled, it removes nodes. Enable per node pool with a min/max range. This is the slowest scaler — node provisioning takes 2–5 minutes.

**2. HPA — Horizontal Pod Autoscaler (pod-level, metric-based):** Kubernetes-native scaling based on CPU, memory, or custom metrics exposed via the Metrics API. When average CPU across pods in a deployment exceeds 70%, HPA scales the replica count up. Simple and reliable for stateless services with predictable CPU-correlated load. Blind to external signals.

**3. KEDA (event-driven, pod-level):** Scales deployments based on external event sources — queue depth, event hub lag, HTTP request count. Covers cases HPA can't handle, especially background processors that need to scale before CPU rises. KEDA can also scale to zero, which HPA cannot.

**4. AKS Node Provisioner (faster node scaling, 2024+):** The new node provisioner (Karpenter-inspired, AKS-native) replaces Cluster Autoscaler for eligible clusters. It selects the optimal VM SKU per workload request, provisions nodes in under 60 seconds (vs 2–5 minutes for Cluster Autoscaler), and bins packs more efficiently. Available in preview for new clusters.

**VPA (Vertical Pod Autoscaler):** Not a scaling mechanism in the reactive sense, but useful for right-sizing resource requests. VPA analyzes historical usage and recommends or automatically applies new CPU/memory requests. Use it in recommendation mode first — auto-apply mode restarts pods.

> [!tip] The typical production setup: Cluster Autoscaler (or Node Provisioner) for node-level, HPA for CPU-sensitive services, KEDA for queue workers and event processors. VPA in recommendation mode to keep resource requests accurate so HPA and Cluster Autoscaler have real data to work with.

@feynman

The four scaling layers are like traffic management at different road levels — KEDA is the intersection sensor, HPA is the ramp meter, Cluster Autoscaler is the highway expansion crew, and VPA is the lane-width optimizer that keeps traffic flowing efficiently before you ever need to add more lanes.
