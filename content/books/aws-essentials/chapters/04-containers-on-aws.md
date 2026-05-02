@chapter
id: aws-ch04-containers-on-aws
order: 4
title: Containers on AWS
summary: AWS offers a layered container stack — from the low-level primitives of ECS and EKS through the fully managed abstractions of Fargate and App Runner — and choosing the right layer determines how much operational complexity you own.

@card
id: aws-ch04-c001
order: 1
title: ECS: AWS's Native Container Orchestrator
teaser: ECS is the AWS-native way to run containers at scale — it manages scheduling, placement, health checks, and service recovery so you don't have to build that machinery yourself.

@explanation

Amazon Elastic Container Service (ECS) organizes your containers around four concepts:

- **Cluster** — the logical boundary for your workloads; a fleet of infrastructure (EC2 instances or Fargate capacity) that ECS can schedule tasks onto.
- **Task definition** — a blueprint (JSON) describing one or more containers: the image, CPU, memory, port mappings, environment variables, and IAM role. Think of it as a versioned pod spec.
- **Task** — a running instantiation of a task definition. One-off tasks are common for batch jobs or DB migrations.
- **Service** — a long-running abstraction that keeps N tasks running, replaces unhealthy ones, and integrates with load balancers for traffic distribution.

The **ECS container agent** runs on every EC2 node in the cluster. It communicates with the ECS control plane, receives placement instructions, and reports task health back. You never interact with it directly — it's background infrastructure.

Where ECS diverges from running `docker run` on a VM: ECS handles bin-packing tasks across nodes, restarts containers that exit unexpectedly, drains tasks during deployments, and wires tasks into VPCs and load balancers. What you would have built manually as a fleet management layer is provided for you.

> [!info] ECS does not require Kubernetes knowledge. If you're running containers on AWS and don't already have Kubernetes expertise on your team, ECS is the faster path to production.

@feynman

ECS is to containers what systemd is to processes — it manages the lifecycle, restarts failures, and keeps the declared state running without you watching the process table manually.

@card
id: aws-ch04-c002
order: 2
title: EC2 vs Fargate Launch Types
teaser: ECS supports two launch types with opposite tradeoffs — EC2 gives you control and density; Fargate eliminates the fleet entirely in exchange for per-task billing.

@explanation

When you create an ECS service, you choose a launch type:

**EC2 launch type:**
- You provision and manage a fleet of EC2 instances that join the ECS cluster.
- Tasks are bin-packed onto those instances by the ECS scheduler.
- You pay for the instances whether tasks are running on them or not.
- Gives you control over instance type, AMI customization, GPU access, and placement affinity.
- Better unit economics at steady, high utilization (e.g., 80%+ CPU utilization across the fleet).

**Fargate launch type:**
- No EC2 instances — AWS manages the underlying compute.
- You declare the vCPU and memory for each task; AWS launches it in isolation.
- Billing is per second of task execution, not per node.
- No cluster capacity management, no AMI patching, no over-provisioning decisions.
- Slower cold starts (a few seconds to provision task infrastructure) versus tasks already warm on an EC2 node.

The right choice criteria:
- Variable or bursty load with no guaranteed baseline → Fargate (you only pay for what runs).
- Stable, high-density load with cost-sensitive budget → EC2 (lower per-vCPU cost at scale).
- Team has no interest in managing instances → Fargate regardless of cost.
- Workloads need GPU or specific instance features → EC2 only.

> [!tip] Start new workloads on Fargate. Move to EC2 launch type only after you have real utilization data that shows the EC2 economics justify the operational overhead.

@feynman

Choosing EC2 launch type over Fargate is like leasing a server rack instead of paying for cloud compute — cheaper per hour at full utilization, but you own the provisioning problem.

@card
id: aws-ch04-c003
order: 3
title: AWS Fargate: Serverless Compute for Containers
teaser: Fargate is the compute engine underneath serverless containers — it handles the VM layer entirely so your unit of operation is the task, not the machine.

@explanation

Fargate is not a service you directly interact with — it's the underlying compute provider for ECS and EKS tasks when you choose the Fargate launch type. Understanding its properties helps you size and cost your workloads correctly.

**Task sizing** — Fargate enforces valid vCPU/memory combinations. You can't specify arbitrary values. Examples of valid pairs: 0.25 vCPU / 512 MB, 1 vCPU / 2 GB, 4 vCPU / 8 GB, up to 16 vCPU / 120 GB. Each container in the task shares the task's total allocation.

**Fargate Spot** — like EC2 Spot, Fargate Spot runs your tasks on spare capacity at up to 70% discount. Tasks can be interrupted with a 2-minute warning. Suitable for batch processing, CI runners, and other interruptible workloads — not for services handling live user traffic.

**Fargate vs Lambda for containers:**
- Lambda also runs container images (up to 10 GB), but imposes a 15-minute execution limit and charges per 100ms invocation.
- Fargate tasks have no execution time limit and are appropriate for longer-running workloads, persistent connections (WebSockets), or processes that don't fit a request/response model.
- Lambda is still better for pure event-driven, short-duration functions regardless of packaging format.

> [!warning] Fargate tasks that idle consume the full vCPU/memory allocation you declared. Don't over-provision task sizes on long-running services — it directly inflates your bill.

@feynman

Fargate is the managed runtime beneath your container — the same relationship Lambda has to your function code, except the boundaries are task-shaped instead of invocation-shaped.

@card
id: aws-ch04-c004
order: 4
title: Amazon EKS: Managed Kubernetes on AWS
teaser: EKS runs a managed Kubernetes control plane so you get the full Kubernetes API without operating etcd, the API server, or control-plane upgrades yourself.

@explanation

Amazon Elastic Kubernetes Service (EKS) gives you a production-grade Kubernetes cluster where AWS manages the control plane — the API server, etcd, the scheduler, and controller manager. You pay $0.10/hour per cluster for that management, then pay separately for the nodes that run your workloads.

**Node options:**
- **Managed node groups** — AWS-provisioned EC2 instances that join the cluster automatically; AWS handles AMI updates and drain-on-upgrade.
- **Self-managed nodes** — you manage the EC2 fleet and bootstrapping yourself; maximum control but maximum operational work.
- **Fargate nodes** — pods scheduled onto Fargate capacity; no node management at all, same tradeoffs as ECS Fargate.

**EKS add-ons** — AWS-managed versions of cluster components like the VPC CNI plugin, CoreDNS, and kube-proxy. Add-ons are versioned and upgradable through the EKS API rather than manual kubectl apply.

**EKS vs ECS — when EKS is the right choice:**
- Your team already knows Kubernetes and has existing Helm charts or operators.
- You need multi-cloud portability — EKS workloads can be migrated to GKE or AKS with minimal changes.
- You need Kubernetes-native primitives: custom resource definitions (CRDs), admission webhooks, or a rich ecosystem of operators (e.g., cert-manager, Argo CD, Prometheus Operator).
- You are already running Kubernetes on-prem and want cloud parity.

If none of those apply, ECS is simpler and faster to operate.

> [!info] EKS control-plane upgrades happen roughly every 3-4 months when a new Kubernetes version releases. Plan for upgrade windows — each cluster has an end-of-support date after which patches stop.

@feynman

EKS is like using a managed database instead of running Postgres on a VM — you still query the same API, but you don't manage the process that answers the queries.

@card
id: aws-ch04-c005
order: 5
title: Amazon ECR: Private Container Registry
teaser: ECR is the fully managed container registry for your private images — it handles storage, authentication, scanning, and lifecycle cleanup without you running a registry server.

@explanation

Amazon Elastic Container Registry (ECR) stores Docker-compatible container images in private repositories within your AWS account. The key integration: ECR authenticates through IAM, so your ECS tasks and EKS pods pull images with the same IAM role-based model as every other AWS service — no separate registry credentials to rotate.

**Lifecycle policies** — you define rules that automatically expire old image tags. Example: retain only the 10 most recent tagged images and delete untagged images older than 7 days. Without lifecycle policies, ECR repositories grow unboundedly and storage costs accumulate silently.

**Image scanning:**
- **Basic scanning** uses open-source CVE data (Clair) and runs on push or on demand. Free.
- **Enhanced scanning** integrates with Amazon Inspector for continuous scanning and deeper OS + package-level analysis. Inspector evaluates new CVEs against existing images without waiting for a push.

**Cross-account pull** — you can grant another AWS account permission to pull from your repository using a resource-based ECR repository policy. Common for central shared image libraries in multi-account organizations.

**ECR Public** (`public.ecr.aws`) — a public gallery for open images, equivalent to Docker Hub. You can publish public images here for free and consumers can pull without authentication.

> [!tip] Set up lifecycle policies on every ECR repository at creation time. Retroactively cleaning up thousands of untagged image layers is tedious, and ECR storage pricing adds up at scale.

@feynman

ECR is to container images what S3 is to objects — durable, IAM-integrated storage, with lifecycle rules to keep it from becoming a landfill.

@card
id: aws-ch04-c006
order: 6
title: ECS Task Definitions in Depth
teaser: The task definition is the contract between you and ECS — everything ECS needs to run your containers lives here, including secrets, IAM roles, and resource allocation.

@explanation

A task definition is a JSON document you register with ECS. It's versioned — every update creates a new revision (e.g., `my-api:42`). Services and scheduled tasks reference a specific revision, giving you controlled rollout and easy rollback.

Key fields to understand:

**CPU and memory at two levels:**
- Task level: total resources available to all containers in the task combined (required for Fargate; optional but recommended for EC2).
- Container level: a reservation (soft limit) and an optional hard limit per container. If a container exceeds its hard memory limit, it is killed.

**Port mappings** — `containerPort` is what your app listens on. `hostPort` is the EC2 host port (set to `0` for dynamic assignment on EC2; irrelevant in `awsvpc` network mode where each task has its own ENI).

**Environment variables vs secrets:**
- Plain `environment` entries are visible in the task definition JSON — fine for non-sensitive config.
- `secrets` entries reference an AWS Secrets Manager secret or SSM Parameter Store path by ARN; ECS injects the resolved value at task startup. The value is never stored in the task definition.

**IAM roles — two separate roles, each with a distinct purpose:**
- **Execution role** — used by the ECS agent to pull the image from ECR and fetch secrets from Secrets Manager before your container starts.
- **Task role** — assumed by your application code at runtime; grants permissions to call AWS APIs (S3, DynamoDB, SQS, etc.).

> [!warning] Confusing the execution role with the task role is one of the most common ECS IAM mistakes. If your container can't pull its image or fetch secrets on startup, check the execution role. If your app can't call S3, check the task role.

@feynman

A task definition is like a Dockerfile for your infrastructure — it specifies the runtime environment declaratively, and the platform handles making that environment real.

@card
id: aws-ch04-c007
order: 7
title: ECS Service Auto-Scaling
teaser: ECS services can scale task count automatically in response to load — but the scaling policy you choose determines how tightly the service tracks demand versus how smoothly it behaves under spikes.

@explanation

ECS service auto-scaling adjusts the desired task count of a service up or down. It's built on Application Auto Scaling and supports three policy types:

**Target tracking** — the most common choice. You declare a target metric value and auto-scaling does the math to keep the metric near that target. Common targets:
- ECS service average CPU utilization (e.g., 60%).
- ECS service average memory utilization.
- ALB request count per target (requests per running task).

Target tracking scales out fast when the metric exceeds the target and scales in conservatively (waits 15 minutes by default to avoid flapping).

**Step scaling** — you define explicit step adjustments: "add 2 tasks when CPU > 70%, add 4 tasks when CPU > 85%." Gives precise control but requires manual tuning. Useful when you know your traffic profile well.

**Scheduled scaling** — set minimum/maximum task counts on a cron schedule. Appropriate when traffic patterns are predictable (e.g., scale up at 8 AM Monday through Friday).

**Connection draining on scale-in** — when ECS removes a task, the load balancer stops sending new requests to it but waits for in-flight requests to complete before deregistering the target. Default deregistration delay is 300 seconds; tune this to match your request duration.

**Service quotas to know:** ECS default is 5,000 tasks per service and 10,000 tasks per cluster. At very large scale, these require a quota increase.

> [!info] Target tracking on ALB request count per target is generally the best starting policy for HTTP services — it scales directly in response to user-visible load rather than a proxy metric like CPU.

@feynman

Target tracking auto-scaling is like a PID controller for your service — you set the setpoint, and the controller continuously adjusts task count to keep the measurement near it.

@card
id: aws-ch04-c008
order: 8
title: The Sidecar Pattern on ECS and EKS
teaser: Sidecars let you attach cross-cutting concerns — log shipping, observability, service mesh — to every container without modifying application code or rebuilding images.

@explanation

A sidecar is a container that runs alongside your application container in the same task (ECS) or pod (Kubernetes). It shares the network namespace and optionally the filesystem, which lets it intercept traffic, tail log files, or export metrics without any changes to the application.

**Common sidecar use cases on AWS:**

**Log shipping with FireLens** — AWS's log routing sidecar built on Fluent Bit. You configure FireLens in the task definition as the `logConfiguration` driver. Your app writes to stdout; FireLens parses and ships logs to CloudWatch Logs, Kinesis Firehose, Datadog, or any Fluent Bit output. You get structured logging without touching application code.

**Service mesh with AWS App Mesh** — App Mesh injects an Envoy proxy sidecar that intercepts all inbound and outbound traffic. Envoy enforces routing rules, collects telemetry, and handles retries/circuit breaking at the network level. Your app connects to services by name; App Mesh handles the actual routing.

**Observability agents** — CloudWatch Agent or an OpenTelemetry Collector as a sidecar exports custom metrics and traces without requiring the app to call AWS APIs directly.

**ECS task definition vs Kubernetes pod spec:**
- In ECS, multiple containers in a task definition run as a unit; resource limits are per-container but share the task's total allocation.
- In Kubernetes, containers in a pod share the same network and optionally the same volume mounts; sidecars are first-class in the pod spec. Kubernetes 1.29 introduced native sidecar support with ordered startup/shutdown guarantees.

> [!tip] FireLens is almost always the right answer for log routing on ECS. It decouples your logging infrastructure from your application and supports dozens of destinations without application changes.

@feynman

A sidecar is like middleware in a web framework — it intercepts the request/response (or network traffic/log stream) to add cross-cutting behavior without the handler knowing it's there.

@card
id: aws-ch04-c009
order: 9
title: AWS App Runner: Containers Without the Cluster
teaser: App Runner takes a container image or a source repository and handles everything else — no task definitions, no services, no cluster — targeting teams who want a running web app, not a container platform.

@explanation

AWS App Runner is a fully managed service that deploys web applications and APIs from either a container image (ECR) or source code (GitHub). You specify CPU, memory, and scaling parameters, and App Runner handles provisioning, load balancing, TLS termination, health checks, and auto-scaling — none of the ECS/EKS surface area is exposed.

**Key properties:**
- Automatic deployments when you push a new image tag to ECR (configurable via the deployment trigger).
- Scales to zero when there's no traffic (minimum instance count can be set to 0, with a cold-start penalty on first request after idle).
- Built-in HTTPS with AWS-managed certificates on the `awsapprunner.com` domain; custom domains supported.
- VPC connector for private resource access (RDS, ElastiCache) without exposing them to the internet.

**When App Runner is the right abstraction:**
- A small team deploying a web API or frontend — no one wants to learn ECS to ship a side project.
- Rapid prototyping where time-to-running matters more than control.
- Stateless HTTP workloads with unpredictable or low traffic (scale-to-zero economics are favorable).

**When App Runner is not the right abstraction:**
- Long-running background workers, queue processors, or anything not HTTP-based.
- Workloads requiring sidecar patterns, custom networking, or host-level control.
- Cost-optimized high-volume services where per-vCPU ECS pricing with Fargate or EC2 is cheaper.

> [!info] App Runner abstracts away roughly 80% of the operational surface of ECS Fargate. The cost is the missing 20% — if you ever need that control, you're migrating rather than configuring.

@feynman

App Runner is to ECS what Heroku was to EC2 — a tighter abstraction that trades configurability for the ability to deploy without reading the docs first.

@card
id: aws-ch04-c010
order: 10
title: Container Networking on AWS
teaser: How your containers get network identities and talk to each other depends on which networking mode you choose — and the wrong choice creates scaling ceilings you'll hit at the worst time.

@explanation

Container networking on AWS is not uniform — ECS and EKS each have distinct network models with real scaling and security implications.

**ECS network modes:**

- **bridge mode** — the Docker default. Containers share the EC2 host's network namespace through a virtual bridge. Port mapping is required; containers on the same host can communicate via the bridge. Security group rules apply at the host (ENI) level, not the container level. Cheap on ENIs; limited isolation.

- **awsvpc mode** — each ECS task gets its own Elastic Network Interface (ENI) and a private IP in your VPC. Security groups attach directly to the task, not the host. This is the required mode for Fargate and the recommended mode for EC2 launch type. Limitation: EC2 instances have an ENI limit by instance type (e.g., a `c5.large` supports up to 3 ENIs). If your instance type can't support your task density, you hit a hard ceiling. Workaround: use larger instances or enable ENI trunking via ECS Trunk ENI for supported instance families.

**EKS networking with VPC CNI:**
The AWS VPC CNI plugin assigns real VPC IP addresses to pods (not an overlay network). Every pod is directly routable within the VPC, which simplifies security group rules and firewall policies. Tradeoff: pod density is bounded by the number of private IPs available on the node's ENIs. IPv6 mode and prefix delegation (assigning /28 IP prefixes per ENI slot) are common fixes for IP exhaustion.

**Inter-service communication patterns:**
- **Service discovery via AWS Cloud Map** — ECS services register DNS names (e.g., `api.local`) in a private hosted zone. Other services resolve the name; Cloud Map returns the task IP. Low latency, no extra hop.
- **Internal load balancers** — an ALB or NLB in a private subnet fronts a service. More overhead than Cloud Map but gives you health check, path routing, and TLS termination.
- **App Mesh / service mesh** — appropriate when you need traffic shaping, retries, circuit breaking, or mutual TLS at the service-to-service level.

> [!warning] ENI limits per EC2 instance are a silent ceiling in `awsvpc` mode. Audit your instance types against expected task density before going to production — you will not get a clear error until scheduling starts failing.

@feynman

Container networking on AWS is like VLAN design in a data center — the model you choose at the start determines your isolation boundaries, your IP address budget, and how much pain you hit when you scale.
