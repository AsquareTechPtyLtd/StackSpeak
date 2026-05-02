@chapter
id: azr-ch02-compute-vms-and-app-service
order: 2
title: Compute: VMs and App Service
summary: Azure offers a spectrum of compute options from raw VMs — with their naming conventions, availability guarantees, and scale-out machinery — through fully managed App Service, with deployment slots, autoscaling, and background job support at every tier.

@card
id: azr-ch02-c001
order: 1
title: VM Sizes and Series Naming
teaser: Azure VM names encode a contract about hardware profile — once you can read the name, you can pick the right size without guessing

@explanation

Every Azure VM size follows the pattern `<Tier>_<Family><vCPUs>[<Addons>]_v<Version>`. For example, `Standard_D4s_v5` means: Standard tier, D-series (general purpose), 4 vCPUs, `s` = premium storage supported, version 5.

The series families you'll reach for most often:

- **D-series** — general purpose, balanced CPU/memory ratio (1:4 vCPU-to-GiB). Good default for web servers, app servers, and mid-tier databases.
- **E-series** — memory optimized (1:8 ratio). Pick this for in-memory caches, SAP HANA, large SQL Server workloads.
- **F-series** — compute optimized (1:2 ratio). CI/CD agents, batch processing, gaming servers where raw CPU throughput matters more than RAM.
- **B-series** — burstable. VMs accumulate CPU credits during idle periods and spend them during bursts. Ideal for dev/test environments and workloads with spiky, infrequent CPU peaks. Cheapest option for low-utilization apps.
- **L-series** — storage optimized. High local NVMe throughput for workloads like Cassandra, Elasticsearch, or any app that needs local scratch space fast.
- **HBv3** — HPC (High Performance Compute). AMD EPYC chips with 448 GiB RAM, 200 Gb/s InfiniBand networking. Purpose-built for MPI jobs, computational fluid dynamics, genomics pipelines — not general workloads.

Addons in the name tell you about extras: `s` = premium SSD eligible, `d` = local temp disk, `a` = AMD CPU, `p` = ARM (Ampere Altra).

> [!tip] When you're unsure, start with D-series. Move to E-series if your app is memory-bound (watch RSS / working set in Azure Monitor), or F-series if it's CPU-bound and memory-light.

@feynman

Reading a VM size name is like reading a Docker image tag — the family tells you the base, the number tells you the scale, and the suffixes tell you which optional features are bolted on.

@card
id: azr-ch02-c002
order: 2
title: Availability Sets vs Availability Zones
teaser: Azure gives you two distinct mechanisms for fault tolerance on VMs — they protect against different failure scopes, and mixing them up costs you either money or the SLA you thought you had

@explanation

**Availability Sets** protect against rack-level and planned-maintenance failures within a single datacenter. When you place VMs in an availability set, Azure spreads them across:

- **Fault domains** (up to 3) — separate physical racks with independent power and networking. If one rack loses power, VMs on other fault domains keep running.
- **Update domains** (up to 20) — logical groups that Azure reboots sequentially during planned maintenance. Only one update domain is taken down at a time.

The SLA for availability sets is **99.95%** — roughly 4.4 hours of allowed downtime per year. The cost is zero: it's a free grouping mechanism, not a separate resource.

**Availability Zones** protect against entire datacenter failures. Each Azure region has three physically separate datacenters (zones), each with independent power, cooling, and networking. Placing VMs across zones means a datacenter fire or flood takes out at most one third of your fleet.

The SLA for multi-zone VMs is **99.99%** — about 52 minutes of allowed downtime per year. Zones come with a small inter-zone data transfer cost and slightly higher latency between VMs in different zones.

When to use each:
- Use **availability sets** when you need SLA compliance but the workload is latency-sensitive and must stay within one datacenter, or when the region doesn't have zones yet.
- Use **availability zones** for anything customer-facing where a datacenter-level outage would be unacceptable. Zones are the modern default for production.

> [!warning] A single VM with Premium SSD gets a 99.9% SLA — but that drops to 0% if you use Standard HDD. Always check the disk tier before assuming you have an SLA.

@feynman

Availability sets are like RAID 1 inside one machine room; availability zones are like replicating across three separate buildings on different power grids — the failure domain you're protecting against is completely different.

@card
id: azr-ch02-c003
order: 3
title: Virtual Machine Scale Sets (VMSS)
teaser: VMSS turns a VM definition into a fleet with autoscaling, instance repair, and rolling upgrades — things individual VMs can't do without a lot of manual glue

@explanation

A Virtual Machine Scale Set lets you manage a group of identical VMs as a single resource. You define one VM configuration (image, size, NIC, extensions), and VMSS stamps out as many copies as needed, adds them to a load balancer, and removes them when demand drops.

Two orchestration modes:

- **Uniform mode** — all instances are identical and interchangeable. The scale set manages them as a homogeneous pool. Best fit for stateless workloads where instances are fungible.
- **Flexible mode** — instances can differ (different sizes, different zones). You trade some automation for more control. Flexible mode is required if you want to mix spot and on-demand instances in the same set.

Autoscaling works via rules:
- **Metric-based rules** — scale out when average CPU > 70% for 5 minutes, scale in when CPU < 30% for 10 minutes. You set the metric, threshold, and cooldown.
- **Schedule-based rules** — add 10 instances every weekday at 08:00, remove them at 20:00. Useful for predictable load patterns.
- **Predictive autoscale** — uses ML to forecast load and provisions capacity before demand arrives, avoiding cold-start lag.

**Instance repair policies** automatically replace unhealthy instances. VMSS polls the load balancer health probe (or an application health extension); if an instance fails the health check for a configurable grace period (default 30 minutes), VMSS deletes and recreates it.

> [!info] VMSS supports rolling upgrades — it updates instances in batches with a configurable max-unavailable percentage, so you can ship a new image across a fleet of 100 VMs without a full outage.

@feynman

VMSS is to individual VMs what a Kubernetes Deployment is to a single Pod — same unit of work, but with self-healing, scaling, and rollout mechanics managed for you.

@card
id: azr-ch02-c004
order: 4
title: Azure Bastion for Secure VM Access
teaser: Bastion gives you browser-based RDP and SSH into a VM that has no public IP — eliminating the jump box, the open port 22, and the keys you have to rotate

@explanation

The traditional pattern for SSH-ing into a VM is: expose port 22 (or 3389), create a jump box, and manage credentials. Each step is an attack surface. Azure Bastion collapses this to a single managed service deployed into a dedicated subnet (`AzureBastionSubnet`) in your VNet.

Once Bastion is provisioned, you connect through the Azure Portal or CLI — the session runs over TLS 443 from your browser to the Bastion host, and from there via private IP to the target VM. The VM never needs a public IP or an open inbound port.

The three SKUs and what they add:

- **Basic** — RDP and SSH, no extra features. Sufficient for simple access needs. Limited to the host VNet (no VNet peering support).
- **Standard** — adds native client support (use your local SSH/RDP client instead of the browser), VNet peering (connect to VMs in peered VNets), host scaling (up to 50 scale units for concurrent sessions), and shareable links.
- **Premium** — adds session recording (stored in a Storage Account), private-only Bastion (Bastion itself has no public IP), and customer-managed keys for recordings.

Bastion is priced per provisioned hour plus per-GB of outbound data. A single Basic instance is roughly $0.19/hour.

> [!tip] If your team currently relies on a jump box VM with a public IP, replacing it with Bastion Standard eliminates a patch surface, removes a persistent credential store, and gives you session logging without building it yourself.

@feynman

Bastion is like an AWS Systems Manager Session Manager for Azure — the network path to the VM goes through the control plane, not through an exposed port on the data plane.

@card
id: azr-ch02-c005
order: 5
title: App Service Plans and Pricing Tiers
teaser: The App Service plan is the VM underneath your web app — its tier determines CPU, memory, instance count, and whether features like custom domains and deployment slots are available at all

@explanation

An App Service plan is the underlying compute allocation. Multiple apps can share one plan; they share its CPU and memory. The plan's tier controls what you get:

- **Free (F1)** — 60 CPU-minutes/day, 1 GB storage, shared infrastructure, no custom domain, no SSL. Good for experiments only.
- **Shared (D1)** — custom domain enabled, still shared infrastructure, no SLA.
- **Basic (B1/B2/B3)** — dedicated VMs, custom domains, SSL, manual scaling up to 3 instances. No deployment slots, no autoscale.
- **Standard (S1/S2/S3)** — adds autoscale (up to 10 instances), 5 deployment slots, daily backups, Traffic Manager integration. The minimum tier for production.
- **Premium v3 (P0v3–P3v3)** — larger compute options, up to 30 instances, up to 20 deployment slots, VNet integration (for outbound connections to private resources). Premium is the tier for high-traffic or VNet-isolated apps.
- **Isolated v2 (I1v2–I3v2)** — runs in your own dedicated App Service Environment (ASE), fully VNet-injected. Required for PCI or HIPAA workloads that demand network isolation.

The **Always On** setting (available from Basic upward) keeps the app process warm so it doesn't idle out after 20 minutes of inactivity. Without it, the first request after an idle period hits a cold start — a noticeable delay for apps with heavy initialization.

> [!warning] Putting multiple high-traffic apps on a single plan to save money will cause them to compete for CPU and memory. Monitor plan-level CPU/memory, not per-app metrics, to detect this.

@feynman

The App Service plan is the server rack; your apps are the services running on it — upgrading the rack benefits everything in it, but overloading the rack hurts everything equally.

@card
id: azr-ch02-c006
order: 6
title: App Service Deployment Options
teaser: App Service supports half a dozen deployment methods — each with different latency, reliability, and automation tradeoffs — and picking the right one saves you from accidental downtime

@explanation

App Service separates the concern of deploying code from the concern of when it becomes live (that's deployment slots, covered next). The core deployment methods:

**ZIP deploy** — upload a zip of your build artifacts via the REST API or Azure CLI (`az webapp deploy --type zip`). Fast, scriptable, no source control required. The deployment engine (Kudu) unpacks the zip in place. Best for CI pipelines where you build once and push the artifact.

**GitHub Actions** — Azure generates a workflow YAML that builds and deploys on push to a branch. The integration uses OIDC (no long-lived secrets) when configured via the portal's Deployment Center. Best when your source is in GitHub and you want zero-config CI/CD.

**Azure DevOps Pipelines** — same concept as GitHub Actions but using Azure Pipelines YAML. Required in orgs standardized on ADO. The `AzureWebApp@1` task handles ZIP deploy or container deploy under the hood.

**Local Git** — App Service provisions a Git remote; you push directly to it and Kudu builds on receive. Convenient for solo developers but scales poorly — no branch policy, no PR review, direct-to-production push is one typo away.

**Container deploy** — App Service pulls an image from Azure Container Registry or Docker Hub. Supports webhook-based auto-deploy when a new image is pushed to a tag. Best when your artifact is a container rather than raw code.

> [!tip] In a production setup, combine GitHub Actions or ADO Pipelines with deployment slots: deploy to a staging slot, run smoke tests, then swap. This gives you CI/CD with zero-downtime rollout and a one-click rollback.

@feynman

Deployment options are like database write paths — they all get your data in, but they differ in atomicity, latency, and what happens when something goes wrong mid-write.

@card
id: azr-ch02-c007
order: 7
title: App Service Deployment Slots
teaser: Deployment slots let you bake a release in a production-identical environment and swap it live in seconds — no downtime, and the previous version is one swap away if something breaks

@explanation

A deployment slot is a separate app instance running on the same App Service plan with its own hostname (e.g., `myapp-staging.azurewebsites.net`). Slots are available from Standard tier upward (5 slots on Standard, 20 on Premium v2/v3).

**Slot-specific settings** let you configure environment variables and connection strings that don't swap — useful for pointing the staging slot at a staging database while the production slot hits the production database. Mark a setting as "deployment slot setting" in the Configuration blade to pin it to the slot.

**Swap mechanics**: when you initiate a swap, App Service:
1. Applies the target slot's settings to the source slot's workers.
2. Waits for the workers to respond to health checks (the warm-up phase).
3. Routes traffic by flipping the internal routing pointer — near-instant, no downtime.

**Warm-up before swap**: if your app has a slow initialization path (loading caches, establishing DB connection pools), configure `applicationInitialization` in `web.config` or the health check URL. App Service won't complete the swap until the warm-up succeeds, preventing a cold app from going live.

**A/B testing**: App Service supports traffic splitting between slots via the Testing in Production feature — send 10% of traffic to staging to validate a change under real load before committing to a full swap.

> [!info] After a swap, the previous production build is now running in the staging slot. A rollback is simply another swap — not a redeploy.

@feynman

Deployment slots are like blue-green deployments as a platform primitive — the infrastructure wiring for the cutover is already built in, so you just push a button instead of managing two load balancers yourself.

@card
id: azr-ch02-c008
order: 8
title: App Service Autoscaling
teaser: App Service can scale out instances automatically based on metrics or schedules, but the rules interact with your plan tier in ways that bite you if you don't read the fine print

@explanation

App Service supports three modes of scaling:

**Manual scaling** — set a fixed instance count in the portal or CLI. Simple, predictable, but requires you to provision for peak at all times.

**Rule-based autoscale** — define metric thresholds that trigger scale-out or scale-in. Common rules:
- Scale out by 1 instance when average CPU > 70% over the last 10 minutes.
- Scale in by 1 instance when average CPU < 30% over the last 15 minutes.
- Set minimum (e.g., 2) and maximum (e.g., 10) instance bounds.

Scale-in cooldown defaults to 5 minutes to prevent thrashing. Scale-out cooldown defaults to 1 minute.

**Automatic scaling** (preview as of late 2024, available on Premium v2/v3) — Azure manages instance count using HTTP queue depth as the primary signal, without you defining explicit CPU/memory rules. Best for HTTP workloads with variable arrival rates. You set only the max instance count.

Tier limits matter:
- Basic: no autoscale, max 3 instances.
- Standard: rule-based autoscale, max 10 instances.
- Premium v2/v3: rule-based + automatic autoscale, max 30 instances.
- Isolated v2: up to 100 instances in an ASE.

**Scale out vs scale up**: scaling out (more instances) handles more concurrent requests; scaling up (bigger VM inside the plan) handles requests that need more CPU or RAM per request. They're not interchangeable — a memory-bound app that's running out of RAM needs scale-up, not scale-out.

> [!warning] Autoscale operates at the plan level, not the app level. If you have three apps on one plan and one spikes, the plan scales out — and all three apps benefit, which can mask the real problem and inflate your bill.

@feynman

Autoscaling rules are like circuit breakers in your codebase — if you set the thresholds too tight you trip them constantly, too loose and they don't fire until you're already on fire.

@card
id: azr-ch02-c009
order: 9
title: WebJobs for Background Tasks
teaser: WebJobs let you run background processing code in the same App Service plan as your web app — no separate compute to manage, and the WebJobs SDK gives you triggers, bindings, and a dashboard

@explanation

A WebJob is a script or executable that runs in the context of an App Service app. It shares the plan's compute, filesystem, and environment variables with the web app. No separate VM, no separate pricing.

Two types:

**Continuous WebJobs** — start immediately when the WebJob is deployed and keep running. Use these for message queue processors, event listeners, or polling loops. App Service restarts them if they crash. Continuous WebJobs benefit from the Always On setting — without it, they stop when the app idles.

**Triggered WebJobs** — run on demand or on a CRON schedule (e.g., `0 0 * * *` for midnight daily). Use these for nightly report generation, cleanup jobs, batch imports, or anything with a defined schedule.

The **WebJobs SDK** adds structure on top of raw scripts:
- Trigger bindings — listen to Azure Storage queues, blobs, Service Bus without writing polling loops.
- Output bindings — write to Storage, send to Service Bus.
- A dashboard (the WebJobs dashboard in the portal) that shows invocation history, logs per run, and retry state.

**WebJobs vs Azure Functions**: Functions are the modern replacement for most WebJob use cases. Functions have consumption pricing (pay-per-execution, not per-hour), better cold-start behavior for infrequent tasks, and a richer trigger ecosystem. Use WebJobs when you specifically need the background task to be colocated in the same App Service plan (shared storage, same environment variables, no additional resource to manage) and you don't want a separate Functions deployment.

> [!info] WebJobs are not going away, but new background task work is usually better served by Azure Functions unless the cohabitation with App Service is a hard requirement.

@feynman

A WebJob is like a cron job on the same server as your web app — convenient because it shares the environment, but coupled to the app's compute in ways that matter when you need to scale them independently.

@card
id: azr-ch02-c010
order: 10
title: VM Extensions and Azure Compute Gallery
teaser: VM extensions let you bootstrap a VM without baking everything into a custom image, and Azure Compute Gallery turns that custom image into a versioned, replicated, shareable artifact

@explanation

**VM Extensions** are small agents that run inside a VM after provisioning. The most commonly used:

- **Custom Script Extension** — runs a shell script (Bash or PowerShell) from a Storage blob or a public URL. Use it to install packages, configure services, join a domain, or apply config management tooling as part of a VM deployment. Example: `az vm extension set --name CustomScript --publisher Microsoft.Azure.Extensions --settings '{"fileUris": ["https://storage.blob.core.windows.net/scripts/setup.sh"], "commandToExecute": "./setup.sh"}'`.
- **Azure Monitor Agent** — installs the monitoring agent to stream metrics and logs to a Log Analytics workspace.
- **Key Vault VM Extension** — automatically refreshes certificates from Key Vault without restarting the VM.

Extensions run at provisioning time and can be re-applied to drift-correct the VM state, which makes them a lightweight alternative to a full configuration management layer like Ansible or Chef for simple bootstrapping.

**Azure Compute Gallery** (formerly Shared Image Gallery) is a repository for custom VM images. You capture a VM image, version it (e.g., `1.0.0`), and store it in a gallery. The gallery handles:

- **Replication** — replicate the image to multiple Azure regions so VMSS instances in each region pull from a nearby replica, speeding up scale-out.
- **Versioning** — store multiple versions and reference the latest or a pinned version in VMSS definitions.
- **Sharing** — share images across subscriptions within a tenant via RBAC, or across tenants via direct sharing or Azure Marketplace (for ISVs).

The combination of a gallery image with extensions is the standard pattern: bake the stable, slow-changing layer into the image (OS config, runtime, certificates), and use extensions for the fast-changing layer (app version, config overrides).

> [!tip] Avoid putting the application binary directly in the base image if it changes on every release — you'll spend more time building and replicating images than deploying. Put the runtime in the image, deploy the app via extension or VMSS custom data.

@feynman

A gallery image is like a Docker base image tag — it gives you a stable, versioned foundation to build on, and extensions are the equivalent of the RUN commands you add in your Dockerfile for the layer that changes more often.
