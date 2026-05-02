@chapter
id: azr-ch01-azure-fundamentals
order: 1
title: Azure Fundamentals
summary: The foundational layer of Azure — how the physical and logical infrastructure is organized, how you interact with it, how you pay for it, and the framework Microsoft uses to judge whether your architecture is any good.

@card
id: azr-ch01-c001
order: 1
title: Azure Global Infrastructure Hierarchy
teaser: Azure's physical layout — regions, availability zones, paired regions, edge PoPs, and sovereign clouds — is the foundation every resilience and compliance decision you make rests on

@explanation

Azure's infrastructure has a clear hierarchy from planetary scale down to individual fault domains. Getting this mental model right early saves you from designing systems that look resilient on a whiteboard but fall over in practice.

The layers, outermost to innermost:

- **Geographies** — a geopolitical boundary (e.g., United States, Europe). Defines where data sovereignty rules apply.
- **Regions** — a cluster of datacenters within a geography, connected by low-latency network. Azure has 60+ regions. You deploy resources to a region: `eastus`, `westeurope`, `southeastasia`.
- **Availability Zones (AZs)** — physically separate datacenters within a region, each with independent power, cooling, and networking. A region with AZ support has at least three. Spreading VMs or managed services across AZs gives you resilience against a single datacenter failure.
- **Paired regions** — every region (except Brazil South) is paired with another region in the same geography at least 300 miles away. Platform updates roll to one paired region before the other, and geo-redundant storage replicates to the pair automatically. Use this for disaster recovery.
- **Edge PoPs (Points of Presence)** — over 190 locations used by Azure CDN and Azure Front Door for content caching and DDoS mitigation closer to end users.

Two special categories exist outside the normal region map:
- **Azure Government** — isolated US government cloud, accessed only by vetted US public sector entities. Separate endpoints, separate identity.
- **Azure China** — operated by 21Vianet under Chinese regulations. Separate portal at `portal.azure.cn`, separate tenant.

> [!info] Not all services are available in all regions. Before committing to a region, check service availability — especially for newer AI or specialized compute offerings — at the Azure products by region page.

@feynman

Think of it like AWS availability zones but with a mandatory buddy system — every Azure region has a disaster-recovery partner baked in at the infrastructure level, not something you wire up yourself.

@card
id: azr-ch01-c002
order: 2
title: Azure Resource Manager Is the Control Plane
teaser: Every action you take in Azure — portal click, CLI command, Terraform apply — hits the same HTTP API: ARM, the single control plane that owns authentication, authorization, and idempotent state management for every resource

@explanation

Azure Resource Manager (ARM) is the layer that sits between you and every Azure service. You never talk to the underlying service API directly; you always go through ARM.

What this means practically:

- The Azure Portal, `az` CLI, Azure PowerShell, Azure SDKs, Bicep, and Terraform all translate their operations into ARM REST API calls to `management.azure.com`.
- ARM authenticates you via Entra ID, checks your RBAC permissions, and routes the request to the right resource provider (e.g., `Microsoft.Compute` for VMs, `Microsoft.Storage` for storage accounts).
- ARM enforces **idempotency** — if you re-deploy a template describing the same desired state, ARM diffs the current state against the desired state and only makes the necessary changes. This is the foundation of infrastructure-as-code on Azure.
- **Resource locks** are an ARM feature: `ReadOnly` locks prevent any modification; `CanNotDelete` locks prevent deletion. Locks apply regardless of how you interact with the resource (portal, CLI, SDK).

A minimal ARM REST call looks like:

```bash
PUT https://management.azure.com/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}?api-version=2023-01-01
```

That path structure — subscription, resource group, provider, resource type, resource name — is the canonical identifier for any Azure resource. It appears everywhere: in the portal URL, in CLI output, in Terraform resource IDs.

> [!tip] When something fails in Azure and you need to debug it, ARM activity logs (under Monitor → Activity Log) record every control-plane operation. This is the first place to look when a deployment fails or a resource is unexpectedly deleted.

@feynman

ARM is to Azure what the kernel is to an OS — every userland operation eventually makes a syscall, and every Azure operation eventually makes an ARM call; the surface in the middle is the thing that enforces access control.

@card
id: azr-ch01-c003
order: 3
title: The Azure Resource Hierarchy
teaser: Azure organizes everything into a four-level tree — management groups, subscriptions, resource groups, resources — and understanding where billing, access control, and policy land at each level is the prerequisite for any real architecture

@explanation

Every Azure resource lives inside a hierarchy. From top to bottom:

- **Management groups** — containers for subscriptions. You apply Azure Policy and RBAC here to govern multiple subscriptions at once. The root management group sits at the top; you can nest groups up to six levels deep. Most small orgs don't need this layer yet, but any organization with more than a handful of subscriptions uses it.
- **Subscriptions** — the primary billing and scale boundary. Every Azure resource belongs to exactly one subscription. Resource quotas (e.g., max 25,000 VMs per subscription per region) are enforced here. This is the boundary between prod and non-prod in most production-grade architectures: separate subscriptions for dev, staging, and prod.
- **Resource groups** — a logical container for resources that share a lifecycle (covered in the next card). Every resource must belong to exactly one resource group. RBAC and policies can be scoped here.
- **Resources** — the actual things: VMs, storage accounts, databases, virtual networks.

Inheritance flows downward: a policy attached at a management group is inherited by all subscriptions, resource groups, and resources inside it. A role assignment at a subscription scope is inherited by all resource groups and resources in that subscription.

The billing boundary is the subscription. Separate subscriptions give you separate invoices, separate quota pools, and a clean cost boundary between environments or business units.

> [!warning] A common mistake is putting everything in one subscription because it feels simpler. At scale, a single subscription creates quota contention, makes cost attribution messy, and means a rogue policy or IAM change can affect all environments at once. Plan for multi-subscription early.

@feynman

It's the same as a filesystem with ACLs that inherit downward — except each top-level mount point also gets its own credit card bill.

@card
id: azr-ch01-c004
order: 4
title: Resource Groups Are a Lifecycle Unit
teaser: A resource group is not a folder — it's a deployment boundary that lets you create, manage, and destroy a set of related resources together, with a single delete command or template

@explanation

The "folder" analogy for resource groups is common and mostly wrong. The key mental model is **lifecycle unit**: a resource group contains resources that you want to create together, manage together, and delete together.

What this means in practice:

- When you delete a resource group, every resource inside it is deleted. This is why you put a web app, its storage account, and its database connection strings in one resource group — a clean teardown of a dev environment is one command.
- You deploy ARM or Bicep templates to a resource group, and the template describes the desired state of everything in it. This makes templates reusable: deploy the same template to a `dev-rg` and a `prod-rg` with different parameters.
- **Tagging for cost attribution** happens at the resource group level (and individual resource level). A `costcenter`, `environment`, or `team` tag on the resource group applies broadly; individual resources can override. Azure Cost Management reads these tags to slice your bill.
- Resource groups are tied to a **region** (the metadata for the group lives there), but resources inside the group can live in any region. A resource group in `eastus` can contain a VM in `eastus` and a storage account in `westus`.

```bash
# Delete an entire environment in one command
az group delete --name myapp-dev-rg --yes --no-wait
```

> [!tip] Name resource groups with a consistent convention that encodes app, environment, and sometimes region: `myapp-dev-eastus-rg`. This makes `az group list` output scannable without needing the portal.

@feynman

A resource group is like a Docker Compose file — not just a namespace, but a deployment and teardown unit where `docker compose down` removes everything that was defined together.

@card
id: azr-ch01-c005
order: 5
title: Azure Entra ID Is the Identity Plane
teaser: Azure Entra ID (formerly Azure AD) is the tenant-level identity store that sits completely outside your subscription hierarchy — understanding the tenant boundary, and how it differs from on-prem Active Directory, prevents a class of access control mistakes

@explanation

Azure Entra ID (rebranded from Azure Active Directory in 2023) is Azure's identity and access management service. It's the thing that authenticates humans and service principals before ARM lets them touch anything.

Critical distinctions:

- **Entra ID is not inside your subscription.** You have a tenant (a directory) and separately you have subscriptions. A single tenant can manage multiple subscriptions; a subscription is linked to exactly one tenant. If you delete your subscription, your tenant (and all its users, groups, and service principals) still exists.
- **Entra ID is not on-prem Active Directory.** On-prem AD uses Kerberos, LDAP, and domain controllers. Entra ID uses OAuth 2.0, OpenID Connect, and SAML over HTTPS. They don't speak the same protocols. If you want your on-prem AD to work with Azure resources, you need Azure AD Connect (or Entra Connect) to sync identities, or you use Entra Domain Services if you need actual Kerberos/LDAP in the cloud.
- **Tenants** — your Entra ID tenant has a globally unique `tenantId` (a GUID) and a default domain like `yourorg.onmicrosoft.com`. Every user, group, app registration, and service principal lives in a tenant.
- **B2B vs B2C** — Entra External ID for B2B (guest access) lets external users authenticate with their own work identity and access your tenant's resources. Entra External ID for B2C (customer identities) is a separate service for consumer apps, supporting social logins and custom user flows.

> [!warning] A common mistake when setting up a new Azure environment is confusing the tenant admin role with Azure subscription Owner. They are separate: you can own a subscription but have no tenant-level permissions, and vice versa.

@feynman

Entra ID is the authentication service, not the house — the house (your subscription) can change hands, but the lock company (the tenant) keeps your keys regardless.

@card
id: azr-ch01-c006
order: 6
title: Azure CLI Basics That Actually Save Time
teaser: The `az` CLI is your primary lever for automation, and five features — `az login`, `az account set`, `--output`, `--query`, and `az find` — cover 80% of daily use before you've written a single script

@explanation

The Azure CLI (`az`) is the fastest path from idea to deployed resource when you don't need idempotent infrastructure-as-code. Install it with `brew install azure-cli` or from `aka.ms/installazurecli`.

The essential commands:

```bash
# Authenticate (browser pop-up by default; use --use-device-code for headless)
az login

# List subscriptions your account can see
az account list --output table

# Switch to a specific subscription (use subscription name or ID)
az account set --subscription "My Dev Subscription"

# Show the currently active subscription
az account show
```

**Output formats** — the `--output` flag changes everything:
- `--output table` — human-readable, great for terminals
- `--output json` — full object, great for scripting
- `--output tsv` — tab-separated, great for `awk` or shell variable assignment

**JMESPath filtering** with `--query` — lets you slice and dice JSON output without piping to `jq`:

```bash
# Get just the names of all resource groups
az group list --query "[].name" --output tsv

# Get VMs with their power state
az vm list --query "[].{name:name, state:powerState}" --output table
```

**`az find`** — AI-powered command search for when you can't remember the exact subcommand:

```bash
az find "how do I list storage account keys"
```

> [!tip] Set a default subscription and resource group so you don't repeat them on every command: `az configure --defaults group=myapp-dev-rg`. These are stored in `~/.azure/config`.

@feynman

`--query` with JMESPath is the same as adding a `.filter().map()` chain to your fetch call — you pull exactly the shape you need without storing the whole response.

@card
id: azr-ch01-c007
order: 7
title: Choosing the Right Azure Tooling Layer
teaser: Portal, CLI, PowerShell, Bicep, and Terraform are not interchangeable — each occupies a distinct position on the exploration-to-production spectrum, and picking the wrong one creates rework

@explanation

Azure gives you five primary ways to manage resources. Knowing when to use each one prevents the anti-patterns of clicking around in the portal to set up production infrastructure, or writing a Terraform module to spin up a one-off debugging VM.

The tools and their jobs:

- **Azure Portal** — a web GUI at `portal.azure.com`. Best for: exploration, learning, one-off investigations, and reading dashboards. Terrible for: anything you want to repeat or version-control. Click-ops in the portal is production technical debt.
- **Azure CLI (`az`)** — cross-platform command-line tool. Best for: ad-hoc operations, shell scripts, CI/CD steps that don't need idempotency. Fast to write, easy to read. Not idempotent by default — running a create command twice errors on the second run.
- **Azure PowerShell** — PowerShell module (`Az`). Best for: Windows-centric teams, complex scripting that leverages PowerShell's object pipeline. Functionally equivalent to the CLI; pick one per team and be consistent.
- **Bicep** — Azure's native declarative IaC language. Best for: production Azure infrastructure that doesn't need to be multi-cloud. Compiles to ARM templates. Idempotent by design. Better Azure service coverage than Terraform and no provider lag. The Microsoft-recommended IaC path.
- **Terraform (AzureRM provider)** — HashiCorp's IaC tool. Best for: multi-cloud shops, teams already standardized on Terraform, or where community modules are more important than coverage lag. The AzureRM provider sometimes trails new Azure features by weeks or months.

> [!info] Bicep and Terraform are not rivals in practice — most teams that use Terraform on Azure have already invested in the HCL ecosystem. If you're starting fresh on Azure with no IaC history, Bicep is worth evaluating seriously before defaulting to Terraform.

@feynman

Same as choosing between the REPL, a shell script, and a proper service: the REPL (portal) is for exploration, the shell script (CLI) is for repeatable one-offs, and the service (Bicep/Terraform) is what you actually ship.

@card
id: azr-ch01-c008
order: 8
title: How Azure Pricing Actually Works
teaser: Azure's pricing model has six layers of decision — service tier, pay-as-you-go vs reservation vs savings plan, egress costs, region pricing, free tier limits, and the pricing calculator — and misunderstanding any one of them produces bill shock

@explanation

Azure billing is consumption-based but has multiple dimensions that aren't obvious until your first invoice arrives.

The core pricing modes:

- **Pay-as-you-go (PAYG)** — the default. You pay the full published rate by the second or minute for what you use. No commitment, maximum flexibility, highest per-unit price.
- **Reservations** — commit to one or three years for specific resource types (VMs, SQL, storage) in exchange for up to 72% discount. The commitment is to a compute capacity class, not a specific resource. You can exchange or cancel with a fee.
- **Azure Savings Plans** — a newer, more flexible commitment. You commit to a fixed hourly spend (e.g., $5/hour) across eligible compute services, and Azure applies the discount (up to 65%) to whatever compute you run. More flexible than reservations but lower maximum discount.

The cost item engineers most often miss: **egress (outbound data transfer)**. Data moving out of Azure to the internet is billed per GB (around $0.08/GB for the first 10 TB in most regions). Data moving between Azure regions is also billed. Data moving within the same region between services is free. This makes region co-location decisions cost decisions, not just latency decisions.

The Azure Pricing Calculator at `azure.microsoft.com/pricing/calculator` lets you model a full architecture before deploying it. Always run estimates there before committing to a production architecture — a 16-core VM with geo-redundant storage and cross-region replication adds up fast.

The **free tier** gives you 12 months of limited free services (750 hours/month of B1s VM, 5 GB blob storage, etc.) plus a handful of always-free services. The limits are real: exceed them and billing starts without warning.

> [!warning] Azure Cost Management alerts don't fire instantaneously — there can be a 24–48 hour lag between spend occurring and an alert triggering. Set budget alerts at 50%, 75%, and 90% thresholds, not just at 100%, to give yourself reaction time.

@feynman

Reservations are like a cell phone plan with a data commitment — you pay less per GB, but you're on the hook for the minimum even if you use less; savings plans are the unlimited plan at a lower ceiling price.

@card
id: azr-ch01-c009
order: 9
title: The Azure Service Category Map
teaser: Azure has 200+ services across eight categories — knowing the map before you need a specific service means you pick the right family of solutions instead of defaulting to the one service you've heard of

@explanation

Azure's service portfolio is large enough to be disorienting. Organizing it into categories gives you a mental map to navigate before you need a specific service.

The eight core categories and representative services:

- **Compute** — running code. VM scale sets, App Service (PaaS web hosting), Azure Functions (serverless), AKS (managed Kubernetes), Azure Container Apps.
- **Storage** — persisting data. Blob Storage (object storage), Azure Files (SMB/NFS shares), Azure Disks (block storage for VMs), Azure Data Lake Storage (analytics at scale).
- **Networking** — connecting things. Virtual Network (VNet), Azure Load Balancer, Application Gateway (L7 LB + WAF), Azure Front Door (global CDN + WAF), VPN Gateway, ExpressRoute (private circuits).
- **Databases** — structured data stores. Azure SQL Database, Azure Cosmos DB (globally distributed NoSQL), Azure Database for PostgreSQL, Azure Cache for Redis.
- **AI/ML** — cognitive and model services. Azure OpenAI Service (GPT-4, embeddings), Azure Machine Learning, Azure AI Search (vector + hybrid search), Cognitive Services.
- **DevOps** — build and release. Azure DevOps (pipelines, repos, boards), GitHub Actions (native Azure integration), Azure Container Registry.
- **Security** — access and threat management. Microsoft Defender for Cloud, Azure Key Vault (secrets, keys, certificates), Entra ID (identity — covered separately).
- **Monitoring and Management** — observability and governance. Azure Monitor, Application Insights, Log Analytics, Azure Policy, Cost Management.

> [!info] The line between categories blurs frequently. Azure SQL is both a database and a managed service that sits on compute. Azure Front Door is both networking and CDN. Don't get attached to the taxonomy — use it to find where to start, then read the individual service docs.

@feynman

It's the same as knowing the Linux filesystem layout — you don't have `ls /etc` memorized, but you know that if it's a config it's in `/etc`, not `/var`, and that's enough to find it fast.

@card
id: azr-ch01-c010
order: 10
title: The Azure Well-Architected Framework
teaser: Microsoft's Well-Architected Framework gives you five named pillars — Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency — that turn vague architecture instincts into checkable design criteria

@explanation

The Azure Well-Architected Framework (WAF) is Microsoft's published set of architectural best practices, organized into five pillars. The value isn't the pillars themselves — it's having a common vocabulary that turns "this design feels wrong" into a specific, actionable concern.

The five pillars and what they actually mean for real systems:

- **Reliability** — the system continues to work correctly when components fail. Decisions: which services to deploy across availability zones, what your RTO/RPO targets are, where to put retry logic, when to use geo-redundancy vs active-active. The WAF pushes you to define failure modes before deployment, not after.
- **Security** — protecting the system from unauthorized access and data exposure. Decisions: network segmentation (private endpoints vs public endpoints), secret management (Key Vault, not environment variables), identity (managed identities instead of stored credentials), defense-in-depth layers. The WAF's security pillar maps closely to the CIS Azure benchmark.
- **Cost Optimization** — spending money in proportion to the value delivered. Decisions: right-sizing VMs, using reservations for predictable workloads, designing to minimize egress, choosing serverless when utilization is spiky. The WAF frames cost as a first-class architectural concern, not an afterthought.
- **Operational Excellence** — the team can deploy, monitor, and recover the system with confidence. Decisions: infrastructure-as-code (idempotent deployments), structured logging, runbooks for known failure modes, deployment strategies (blue/green, canary). This pillar is essentially "can you operate this at 2am without tribal knowledge?"
- **Performance Efficiency** — the system scales to meet demand without wasting resources. Decisions: auto-scaling configuration, caching strategies, database indexing, CDN for static assets, choosing the right service tier.

Microsoft publishes a WAF Assessment tool at `learn.microsoft.com/azure/architecture/framework/assessments/` that scores an existing workload against each pillar and generates prioritized recommendations.

> [!tip] Use the WAF pillars as a design review checklist. For any new service or architecture change, run through all five in 10 minutes: "have we thought about reliability here? Security? Cost?" Most gaps surface in the first pass.

@feynman

It's the same as a pre-flight checklist — not because pilots don't know how to fly, but because a structured checklist catches the thing you'd otherwise skip when you're confident and in a hurry.
