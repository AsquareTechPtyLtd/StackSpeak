@chapter
id: azr-ch12-cost-ai-and-architecture-patterns
order: 12
title: Cost, AI, and Architecture Patterns
summary: Controlling Azure spend, choosing between AI services, and wiring production workloads together with proven architecture patterns are the three skills that separate engineers who can deploy to Azure from engineers who can run Azure responsibly.

@card
id: azr-ch12-c001
order: 1
title: Azure Cost Management Fundamentals
teaser: If you're not looking at Cost Analysis weekly, you're flying blind — Azure bills accumulate silently and the first signal most teams get is a budget alert they set six months ago.

@explanation

Azure Cost Management is the built-in observability layer for your spending. The **Cost Analysis** blade in the Azure portal lets you slice actual and forecasted costs by subscription, resource group, resource, service name, location, or any custom tag. The default view shows the current month's accrued spend versus forecast — change the grouping to "Service name" to see which services are driving cost, or switch to "Tag: environment" to see how much production versus staging is spending.

**Budgets** are the control mechanism. A budget is a threshold attached to a scope (subscription, resource group, or management group) with alert rules that fire at specified percentages:
- Set an 80% alert to get early warning while you still have time to act.
- Set a 100% alert on forecasted spend — this fires before you actually breach, based on Azure's projection of the current trajectory.
- Wire budget alerts to email recipients or an Action Group that pages your team.

**Cost anomaly detection** runs automatically — Azure's ML models flag daily spend that deviates from your historical baseline and sends an email with the anomalous resource identified. You don't configure it; you just ensure a billing contact is set on the subscription.

Before you deploy anything significant, run the **Azure Pricing Calculator** at azure.microsoft.com/pricing/calculator. Model your SKUs, regions, and estimated usage hours to get a monthly estimate. It's imprecise for variable workloads but invaluable for catching orders-of-magnitude mistakes before the first invoice.

> [!tip] Tag every resource at creation with at minimum `environment`, `team`, and `project`. Without tags, Cost Analysis shows you how much you're spending but not why — and cost attribution becomes a quarterly archaeology project.

@feynman

Cost Management is the application performance monitoring for your bill — same principle as APM, but the metric is dollars per day instead of latency per request.

@card
id: azr-ch12-c002
order: 2
title: Reservations and Savings Plans for Committed Workloads
teaser: Pay-as-you-go is the most expensive way to run predictable workloads — committing to one or three years cuts VM costs by up to 72%, and the decision between Reservations and Savings Plans comes down to how stable your workload shape is.

@explanation

When a workload runs predictably — a web app with stable traffic, a database that never scales down, a set of worker VMs that run 24/7 — you are overpaying on pay-as-you-go. Azure offers two commitment models:

**Azure Reservations** are the more aggressive discount. You commit to a specific VM size, region, and term (1 year or 3 years). In exchange, Azure discounts that VM's compute cost by up to 72% versus pay-as-you-go. The commitment is to capacity, not to running that capacity — you're billed for the reservation whether the VM is running or not. Reservations also apply to Managed Disks, SQL Database, Cosmos DB, App Service, Azure Cache for Redis, and several other services.

**Azure Savings Plans** are more flexible. You commit to a fixed dollar amount of compute spend per hour (e.g., $1.50/hr) for 1 or 3 years. The discount — up to 65% on compute — applies automatically to any eligible compute usage across VM families, regions, and operating systems as long as your spend reaches the commitment. If you swap a D-series VM for an F-series, the savings plan follows the bill rather than the resource.

The decision heuristic:
- **Choose Reservations** when your VM size, OS, and region are locked in for the foreseeable future. The extra ~7 percentage points of discount justify the inflexibility.
- **Choose Savings Plans** when you're uncertain about VM family or region but confident about total compute spend — common during architecture migrations or multi-region expansions.

Neither is a trap: unused reservation hours carry zero refund by default, but you can exchange or refund reservations within Azure's return policies (up to $50K per year, subject to a 12% early termination fee on annual prepay).

> [!info] Run the **Reservations Advisor** in Azure Cost Management before buying. It analyzes your last 30 days of usage and recommends the reservation scope, size, and quantity with a projected annual savings estimate.

@feynman

Reservations are a fixed-rate mortgage on compute — lower monthly cost, but you're committed to the house; Savings Plans are a loyalty discount at the same hotel chain, where the rate applies regardless of which property you stay at.

@card
id: azr-ch12-c003
order: 3
title: Azure Advisor for Automated Optimization Signals
teaser: Azure Advisor reads your resource configuration and usage data and surfaces specific, actionable recommendations across cost, security, reliability, performance, and operational excellence — for free, on demand.

@explanation

Azure Advisor is the opinionated recommendations engine built into Azure. It analyzes your actual resource usage and configuration and produces a prioritized list of improvements across five pillars. You access it from the Azure portal or pull recommendations via API and feed them into dashboards or ticketing systems.

What each pillar surfaces:

**Cost** — identifies underutilized VMs (less than 5% average CPU and less than 2% average network), unattached managed disks, idle App Service plans, and reservations you should buy based on your usage history. A single Advisor cost review on a mature subscription often surfaces $1,000–$10,000/month in quick wins.

**Security** — integrates with Microsoft Defender for Cloud's Secure Score. Recommendations include enabling MFA, applying missing security patches, restricting public IP exposure, and rotating secrets. Improving Secure Score is often a compliance requirement, not just a best practice.

**Reliability** — flags single-instance VMs not covered by Availability Zones, SQL databases without geo-redundancy, storage accounts with LRS in regions where ZRS is available, and App Service plans with only one instance. Each recommendation maps to an SLA impact.

**Operational Excellence** — surfaces expired SSL certificates, API versions that are being deprecated, out-of-date VM agent versions, and Log Analytics workspaces that are nearing their free tier limit.

**Performance** — identifies SQL databases that would benefit from missing indexes (via Query Performance Insight data), App Service plans running at high CPU, and storage accounts where enabling blob indexing would improve access patterns.

Advisor scores each pillar on a 0–100 scale. The score degrades over time as your environment drifts from best practices, which makes it a useful weekly health check rather than a one-time audit.

> [!tip] Enable **Advisor alerts** so new high-impact recommendations push to your email or a monitoring channel rather than waiting for someone to open the portal. A rightsize recommendation sitting unread for three months is three months of overpayment.

@feynman

Azure Advisor is a staff engineer who read every Microsoft well-architected framework doc, scanned your entire Azure subscription, and wrote you a prioritized to-do list — the only catch is you have to actually read it.

@card
id: azr-ch12-c004
order: 4
title: Azure AI Foundry for Generative AI Applications
teaser: Azure AI Foundry is the unified portal for building, evaluating, and deploying generative AI applications on Azure — replacing the fragmented Studio experiences with a single hub-and-project model.

@explanation

Azure AI Foundry (formerly Azure AI Studio) is Microsoft's consolidated development environment for production generative AI. The key organizational concepts are **hubs** and **projects**: a hub is an Azure resource that holds shared infrastructure (compute, connections, storage, Key Vault references), and a project is a workspace within a hub where a team or use case lives. One hub can serve multiple projects, which keeps security boundaries and resource sharing manageable at the organizational level.

The **model catalog** is the starting point for model selection. It includes:
- **OpenAI models** (GPT-4o, GPT-4 Turbo, GPT-3.5, DALL-E 3, Whisper, Embeddings) — deployed via Azure OpenAI
- **Meta Llama** (Llama 3.1 70B, 405B) — deployable as serverless API or managed compute
- **Mistral** (Mistral Large, Mistral Nemo) — serverless or managed
- **Cohere** (Command R+, Embed) — serverless
- **Microsoft Phi** (Phi-3 Mini, Medium) — optimized small models for latency-sensitive tasks

Models can be deployed as a **Serverless API** (pay-per-token, no infrastructure) or as a **Managed Online Endpoint** (your VMs, your VNet, your latency SLA).

**Prompt Flow** is the LLM pipeline orchestration tool built into AI Foundry. You build a DAG of nodes — LLM calls, Python functions, vector index lookups, API calls — and run them as a single versioned pipeline. It replaces the LangChain/LlamaIndex orchestration layer with an Azure-native alternative that integrates directly with Azure AI Search and Azure OpenAI deployments.

**Evaluation tools** let you run automated batch evaluations against your prompt flows using built-in metrics (groundedness, relevance, coherence, fluency) or custom evaluators — critical for measuring regression between prompt versions before promoting to production.

> [!info] AI Foundry hubs provision a managed storage account and Key Vault automatically. Connect your Azure AI Search resource and Azure OpenAI resource to the hub as shared connections rather than duplicating credentials per project.

@feynman

AI Foundry is the monorepo and CI/CD platform for your AI applications — the model catalog is your package registry, prompt flows are your pipelines, and evaluations are your test suite before you ship.

@card
id: azr-ch12-c005
order: 5
title: Azure OpenAI Quota and Provisioned Throughput Units
teaser: Azure OpenAI's default quota is deliberately conservative — understanding the TPM/RPM model, how to increase it, and when PTUs change the economics is the difference between a demo and a production deployment.

@explanation

Azure OpenAI quota has two dimensions per model deployment:

**Tokens Per Minute (TPM)** — the cap on total tokens (input + output) processed per minute across all API calls to that deployment. The default for GPT-4o in most regions is 30,000 TPM (roughly 22,500 words of input/output per minute combined). At high request concurrency, this is the constraint you hit first.

**Requests Per Minute (RPM)** — a secondary throttle, automatically set at 6 RPM per 1,000 TPM. With 30K TPM you get 180 RPM. When you hit either limit, the API returns HTTP 429; well-behaved clients implement exponential backoff.

To request a quota increase: navigate to Azure OpenAI → Quotas → select the model and region → click "Request Quota." Microsoft reviews increases; typical turnaround is 1–3 business days. Quota is regional, so deploying the same model in East US and West Europe doubles your effective capacity.

**Provisioned Throughput Units (PTUs)** are the enterprise commitment model. You purchase a fixed number of PTUs per model (minimum 25 PTUs for GPT-4o), and Azure reserves dedicated model instances for your exclusive use. The guarantees you get in exchange:
- **Deterministic latency** — no noisy-neighbor variance because you're not sharing capacity.
- **No throttling** — calls within your PTU allocation never return 429.
- **Predictable cost** — flat hourly rate regardless of tokens processed.

The economics of PTUs versus pay-as-you-go only favor PTUs when utilization is high. Microsoft's published breakeven is approximately **40% utilization** — if your workload drives the PTU deployment above 40% of its maximum throughput continuously, PTUs are cheaper than equivalent pay-as-you-go spend. Below that, you're paying for reserved capacity you're not using.

> [!warning] PTU commitments are hourly and cannot be paused. A 25-PTU GPT-4o deployment in East US costs roughly $6,000/month at list price whether you use it or not. Validate production traffic volume before committing.

@feynman

PTUs are a reserved lane on the highway — you pay whether or not you're driving, but you're guaranteed the lane is clear when you need it; shared pay-as-you-go is the general lanes that are usually fine but occasionally gridlocked.

@card
id: azr-ch12-c006
order: 6
title: Azure Landing Zones for Enterprise Adoption
teaser: A landing zone is not a subscription — it is a pre-configured environment with governance, networking, identity, and security controls built in before the first workload arrives, so that workloads inherit compliance instead of retrofitting it.

@explanation

The Azure Landing Zone pattern is the recommended architecture for organizations deploying Azure at scale. The structure starts with a **management groups hierarchy** that maps to your organizational needs:

```
Root Management Group
├── Platform
│   ├── Connectivity subscription   (hub VNet, ExpressRoute/VPN gateways, DNS, Azure Firewall)
│   ├── Identity subscription       (AD DS, Entra Domain Services, private CA)
│   └── Management subscription     (Log Analytics, Defender for Cloud, Azure Monitor, Automation)
└── Landing Zones
    ├── Corp (workloads that need private connectivity to on-premises)
    └── Online (internet-facing workloads)
```

Each subscription serves a single purpose, which limits the blast radius of misconfigurations and keeps billing, policy, and access control boundaries clean.

**Azure Policy** and **RBAC** are applied at the management group level, so every workload subscription under a management group inherits them automatically. Common platform-level policies enforce resource tagging, allowed regions, required diagnostic settings, and prohibited public IPs.

The **Azure Landing Zone accelerator** (available at aka.ms/alz) is a reference implementation deployable via Bicep, Terraform, or the Azure portal. It provisions the full management groups hierarchy, starter policies, and platform subscriptions in roughly two hours. You don't build this from scratch in production.

The critical distinction: **a landing zone is not just creating a subscription.** A bare subscription has no network topology, no governance policies, no identity integration, and no monitoring. A landing zone subscription arrives with guardrails — teams building workloads can move fast because the platform constraints are pre-baked.

> [!info] The landing zone pattern separates platform responsibilities (connectivity, identity, management — owned by a platform team) from workload responsibilities (app deployment, workload-level monitoring — owned by application teams). Confusing the two leads to either over-centralized bottlenecks or under-governed sprawl.

@feynman

A landing zone is the difference between handing a new engineer a blank laptop and handing them a laptop with the company's dev environment already set up, security policies applied, and VPN configured — same hardware, completely different time-to-productive.

@card
id: azr-ch12-c007
order: 7
title: Multi-Tier Web Application Architecture on Azure
teaser: The canonical Azure web application pattern has five layers, and each layer has a preferred Azure service — wiring them together correctly from the start avoids the expensive retrofits that come from using the wrong service for a layer.

@explanation

The canonical multi-tier web application on Azure assembles these five layers:

**Global ingress — Azure Front Door.** Terminates TLS, applies WAF policies, routes traffic to the nearest healthy origin, and provides built-in CDN for static assets. For a single-region app, an Application Gateway in the same region is sufficient; Front Door earns its cost at two or more regions.

**Web tier — Azure App Service.** PaaS hosting for your web application. No VMs to manage, built-in auto-scaling, deployment slots for zero-downtime releases, and native managed identity support. Choose App Service over VMs unless you need OS-level access or a runtime Azure doesn't support.

**Data tier — Azure SQL Database or Azure Database for PostgreSQL Flexible Server.** Both support managed identity authentication, so your App Service connects without a connection string in config. Enable geo-redundant backups from day one. For PostgreSQL, Flexible Server is the current GA tier — single server is retired.

**Cache tier — Azure Cache for Redis.** Session state, output caching, and frequently-read reference data. A Basic C1 cache ($50/month) removes 80% of reads from the database tier in typical web applications. Always set a `maxmemory-policy` — the default `noeviction` will cause your cache to reject writes when full.

**Observability — Application Insights.** Instrument your App Service with the Application Insights SDK (or auto-instrumentation). You get request tracing, dependency tracking, exception capture, custom metrics, and Live Metrics stream. Wire Application Insights to a Log Analytics workspace so you can query telemetry alongside platform logs.

Connection strings and secrets flow from **Key Vault** via Key Vault references in App Service configuration — the app reads an environment variable that resolves to a Key Vault secret at runtime, and the App Service's managed identity is the only credential needed. No secrets in code, no secrets in App Settings in plaintext.

> [!warning] Do not store secrets as plain text in App Service Application Settings. They appear in the portal, export to ARM templates, and are visible to anyone with Contributor access. Use Key Vault references instead — the setup is 15 minutes of work that eliminates a class of credential exposure.

@feynman

This architecture is a production-grade IKEA flat-pack: the components are standardized and the assembly order is documented, so you spend your engineering effort on what makes your application unique rather than reinventing the shelf.

@card
id: azr-ch12-c008
order: 8
title: Event-Driven Architecture on Azure
teaser: Azure has three messaging services — Event Grid, Event Hubs, and Service Bus — and they are not interchangeable; choosing the wrong bus for the job creates reliability or cost problems that compound as volume grows.

@explanation

The three services occupy different positions on two axes: **message volume** (low vs. high throughput) and **delivery semantics** (best-effort reactive vs. reliable transactional).

**Azure Event Grid** — reactive infrastructure events, low to moderate volume, fan-out delivery. Event Grid is a push-based pub/sub broker with built-in support for 20+ Azure services as event sources (Blob Storage, Resource Manager, Container Registry, Service Bus, etc.). When a file lands in storage, Event Grid fires an event to your Function or webhook within milliseconds. It is not designed for high-throughput telemetry — the maximum is ~10 million events/second sustained across the entire service, but individual topic throughput is lower. Use Event Grid for: infrastructure automation, reactive workflows, event-sourced integrations between Azure services.

**Azure Event Hubs** — high-throughput telemetry streaming, ordered partitions, multiple consumers at their own pace. Event Hubs ingests millions of events per second per namespace, retains them for 1–90 days, and lets multiple consumer groups replay from any offset independently. Use Event Hubs for: IoT telemetry, application log streaming, clickstream data, anything that looks like an Apache Kafka workload.

**Azure Service Bus** — reliable message queuing with transactional delivery guarantees. Features that Event Grid and Event Hubs don't have:
- **Dead-letter queue (DLQ)** — messages that fail processing N times are moved to the DLQ for manual inspection rather than lost.
- **Sessions** — ordered delivery per session key, enabling FIFO processing of related messages.
- **Scheduled delivery** — enqueue a message to be delivered at a future timestamp.
- **Transactions** — send to multiple queues or topics atomically.

Use Service Bus for: order processing, job queues, workflows where every message must be processed exactly once or investigated if it fails.

**Consumers**: Azure Functions and Container Apps are the natural consumers for all three — trigger-based Functions for low-latency reactive processing, Container Apps with KEDA scaling for sustained high-volume consumers.

> [!info] The simplest selection heuristic: if you care about every individual message surviving to processing, use Service Bus. If you care about ingesting a high-volume stream and processing it at scale, use Event Hubs. If you need Azure infrastructure events to trigger automation, use Event Grid.

@feynman

Event Grid is the smoke alarm, Event Hubs is the security camera recording continuously, and Service Bus is the certified postal service — pick based on whether you need a reaction, a recording, or a receipt.

@card
id: azr-ch12-c009
order: 9
title: Hub-and-Spoke Networking at Enterprise Scale
teaser: Hub-and-spoke is the standard enterprise network topology on Azure — shared connectivity infrastructure in a central hub, isolated workload VNets as spokes — and Azure Virtual WAN automates what a manual hub-and-spoke requires you to build yourself.

@explanation

In a hub-and-spoke topology, a **hub VNet** in the Connectivity subscription holds the shared network infrastructure:
- An **Azure Firewall** or third-party NVA that inspects and controls traffic between spokes and to the internet.
- A **VPN Gateway** for site-to-site connectivity to on-premises offices.
- An **ExpressRoute Gateway** for private, dedicated circuits from on-premises or colocation.
- A **Private DNS Resolver** for centralized resolution of Private Endpoint DNS zones.
- A **Bastion host** for secure RDP/SSH access to VMs across all spokes.

**Spoke VNets** are peered to the hub. Each spoke typically maps to one workload or environment — Production, Staging, Dev. Spoke-to-spoke traffic routes through the hub firewall rather than directly, which enforces consistent inspection. VNet peering is non-transitive by default, so this routing requires user-defined routes (UDRs) in each spoke pointing to the firewall as the next hop.

**Azure Virtual WAN** is Microsoft's managed hub-and-spoke implementation. Instead of manually creating hub VNets, configuring gateways, and maintaining UDRs, Virtual WAN provisions a managed hub in each Azure region you enable, automatically programs routing across all connected VNets and branches, and provides a global transit backbone. The tradeoff: Virtual WAN costs more than a DIY hub and reduces your control over the routing logic. It pays off at 10+ spokes or when you have multiple regions — the operational overhead of manually maintaining a multi-region hub-and-spoke without Virtual WAN is significant.

The platform subscriptions that anchor this topology in a landing zone:
- **Connectivity subscription** — the hub VNet, gateways, firewall, Bastion.
- **Identity subscription** — Active Directory Domain Services or Entra Domain Services domain controllers, peered to the hub so workload spokes can reach them.
- **Management subscription** — Log Analytics, Azure Monitor, Defender for Cloud, Automation Accounts.

> [!tip] Deploy Azure Firewall in Policy mode (Firewall Policy) rather than the legacy classic rule mode. Firewall Policy is a separate ARM resource that can be shared across multiple firewall instances, versioned in Git, and deployed via Bicep — which is essential as your rule set grows past 50 entries.

@feynman

Hub-and-spoke is the airport hub model applied to networking: every spoke flies to the hub, the hub handles all routing and security inspection, and no spoke needs a direct connection to any other spoke to reach it.

@card
id: azr-ch12-c010
order: 10
title: Azure Architecture Best Practices Condensed
teaser: Most Azure production incidents trace back to a small set of skipped best practices — these are the ones that are easy to implement on day one and expensive to retrofit after something goes wrong.

@explanation

These are the practices that appear as recommendations in every Azure Well-Architected review, every Defender for Cloud alert, and every postmortem from teams who skipped them:

**Use managed identities, not connection strings.** Every Azure service that needs to call another Azure service can authenticate via a system-assigned or user-assigned managed identity. Key Vault, Storage, SQL, Service Bus, Event Hubs — all support Azure AD authentication. Managed identities eliminate secrets from config, rotation from your runbooks, and credential exposure from your incident list.

**Use Private Endpoints for PaaS services.** A storage account, SQL database, Key Vault, or Event Hubs with a public endpoint is accessible from anywhere on the internet — authentication is your only control layer. A Private Endpoint gives the service a private IP inside your VNet. Combine with `publicNetworkAccess: Disabled` on the service, and the attack surface shrinks to your network boundary.

**Enable Defender for Cloud from day one.** Defender for Cloud's foundational CSPM tier is free and starts collecting Secure Score recommendations immediately. Enabling it after you've deployed 50 resources means retroactively remediating findings across a production environment. The Defender for Cloud enhanced workload protections (CWPP, $15–$30/resource/month depending on type) add runtime threat detection — enable these for production workloads, not just dev.

**Tag everything at deployment time.** Tags cannot be reliably added to resources after the fact at scale. Define your mandatory tag policy (environment, team, cost-center, project) in Azure Policy with a `deny` effect, and enforce it before the first workload lands. Enforce it after and you'll spend weeks in a tagging sprint that always has exceptions.

**Use Bicep or Terraform for all infrastructure.** Click-ops infrastructure is unauditable, unrepeatable, and undeletable with confidence. A Bicep or Terraform template is a deployment artifact you can review in a pull request, run through a linter, deploy to a test environment, and destroy cleanly. The 2-hour investment to write infrastructure as code for a new workload pays back the first time you need to reproduce the environment or roll back a configuration change.

**Set budgets before you deploy.** Budget alerts configured before resources exist catch cost surprises before the invoice, not after. A 100%-of-forecast alert on the workload's resource group, wired to your team's email, takes 10 minutes to configure and has prevented more budget overruns than any post-deployment cost review.

> [!warning] Skipping Private Endpoints because the setup is complex is a security decision, not an operational shortcut. Public PaaS endpoints protected only by authentication keys have appeared in breach postmortems repeatedly. Treat Private Endpoints as required, not optional, for any service holding sensitive data.

@feynman

These six practices are the load-bearing walls of a production Azure environment — you can skip them while building fast, but removing them after the house is finished is far more expensive than putting them in during framing.
