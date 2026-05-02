@chapter
id: azr-ch11-observability-and-iac
order: 11
title: Observability and IaC
summary: Azure Monitor gives you the data layer — metrics, logs, and alerts — while Bicep, ARM, and Terraform give you the code layer; together they let you build and operate Azure infrastructure with the same rigour you apply to application code.

@card
id: azr-ch11-c001
order: 1
title: Azure Monitor as the Observability Hub
teaser: Every metric, log, and alert on Azure flows through Azure Monitor — understanding its data pipeline tells you where to look when something breaks and how much you'll pay for visibility.

@explanation

Azure Monitor is the umbrella platform that surfaces telemetry from every Azure resource. You do not have to install it; it is always on. What you control is where the data goes and how much of it you keep.

The data flow has four layers:

- **Collection** — resources emit platform metrics (CPU, request count, latency) for free, automatically, with 93 days of retention. Custom metrics emitted via the Azure Monitor Ingestion API are paid, billed per data point.
- **Routing** — diagnostic settings on each resource decide whether logs and detailed metrics are forwarded to a Log Analytics workspace, an Event Hub, or a Storage Account. You configure this per resource, per category.
- **Storage and query** — Log Analytics is the query store for logs; the Metrics Explorer is the interface for platform metrics.
- **Action** — alerts watch metrics or log query results and fire action groups when a threshold is crossed.

The distinction between metrics and logs matters for cost. Platform metrics are free and short-lived. Logs ingested into Log Analytics are billed per GB and retained for 31 days by default (up to 730 days at extra cost). Ingesting every diagnostic category for every resource will surprise you on the invoice — be selective.

> [!info] Azure Monitor is not one product; it is a data pipeline. Think of it as a bus with collection, routing, storage, and alerting stages — knowing which stage to configure for a given problem saves hours of troubleshooting.

@feynman

Azure Monitor is like a logging framework bolted into the infrastructure layer — every resource is pre-wired to emit events, and you configure the appenders (Log Analytics, Event Hub, Storage) separately from the emitters.

@card
id: azr-ch11-c002
order: 2
title: Log Analytics Workspace and KQL Basics
teaser: Log Analytics is where your Azure logs live, and KQL is the query language that makes them useful — a handful of operators covers 90% of what you need day-to-day.

@explanation

A Log Analytics workspace is the central store for log data ingested from Azure resources, Application Insights, custom agents, and third-party sources. Every workspace has its own data, its own access controls, and its own retention settings.

Pricing tiers matter at scale. Pay-As-You-Go charges per GB ingested. Commitment Tiers (100 GB/day up to 5,000 GB/day) give a fixed daily cap at a lower per-GB rate — they break even over Pay-As-You-Go at roughly consistent high-volume ingestion. Default retention is 31 days; you can extend to 730 days (about two years) per workspace or per table.

KQL (Kusto Query Language) is the query language. Five operators get you very far:

- `where` — filter rows: `AzureActivity | where OperationNameValue == "MICROSOFT.COMPUTE/VIRTUALMACHINES/WRITE"`
- `project` — select columns: `| project TimeGenerated, Caller, ResourceGroup`
- `summarize` — aggregate: `| summarize count() by bin(TimeGenerated, 1h)`
- `extend` — add computed columns: `| extend DurationSec = DurationMs / 1000`
- `join` — combine tables: `AppRequests | join AppExceptions on operation_Id`
- `render` — visualise in the portal: `| render timechart`

Table-level retention lets you keep cheap tables like `ContainerLog` for 7 days while keeping `SecurityEvent` for 365 days, which is a meaningful cost lever on large workloads.

> [!tip] Write KQL in the Log Analytics query editor with Intellisense before embedding it in an alert rule — alert rule authoring gives you much less feedback on syntax errors.

@feynman

KQL is SQL with a pipe operator instead of nested subqueries — if you can write `SELECT ... WHERE ... GROUP BY`, you can write KQL with one afternoon of practice.

@card
id: azr-ch11-c003
order: 3
title: Application Insights for APM
teaser: Application Insights gives you request tracing, dependency tracking, and exception capture for web apps and services — the difference between knowing your app is slow and knowing why.

@explanation

Application Insights is the application performance monitoring (APM) layer inside Azure Monitor. It captures telemetry from your running application, not from the underlying infrastructure. Two instrumentation paths exist:

**Auto-instrumentation** — for App Service, Azure Functions, and AKS, you enable Application Insights via the portal or a config flag and it injects a monitoring agent at runtime. No code changes. Supports .NET, Java, Node.js, and Python. You get requests, dependencies, and exceptions with no SDK.

**SDK instrumentation** — you add the Application Insights SDK directly to your code. Required for custom telemetry. The telemetry types are: `requests` (inbound HTTP calls), `dependencies` (outbound — database queries, HTTP calls, queue operations), `exceptions` (unhandled and handled), `traces` (structured log messages), `pageViews` (browser, requires JS SDK), and `customEvents` (anything you want to track explicitly).

Features that justify the cost:

- **Live Metrics** — sub-second view of incoming requests, failures, and server CPU. Useful during deployments to catch regressions before alerts fire.
- **Application Map** — topology view of your service dependencies, annotated with failure rate and latency. Shows you at a glance which downstream dependency is causing errors.
- **Availability tests** — synthetic HTTP checks from Azure edge locations (up to 16 locations). Set up URL ping tests in under two minutes; configure multi-step web tests for authenticated flows.

> [!warning] Application Insights has its own Log Analytics workspace in the background. If you use a workspace-based Application Insights resource (the current default), that data appears in your workspace tables and counts against your ingestion bill — don't double-count when estimating cost.

@feynman

Application Insights is a distributed tracing harness pre-built for Azure — it is to your app what diagnostic settings are to your infrastructure: a standardised way to route telemetry somewhere useful without writing the plumbing yourself.

@card
id: azr-ch11-c004
order: 4
title: Azure Monitor Alerts and Action Groups
teaser: Alerts are only as useful as the rules that define them and the action groups that route them — misconfigured thresholds are noise, and missing action groups mean the right person never finds out.

@explanation

Azure Monitor supports four alert types:

**Metric alerts** — trigger when a metric crosses a threshold over an evaluation window. Static thresholds are straightforward (CPU > 80% for 5 minutes). Dynamic thresholds use machine learning to derive normal baselines from historical data, which reduces false positives for metrics with weekly seasonality.

**Log search alerts** — run a KQL query on a schedule and alert when the result count (or a computed value) meets a condition. Example: alert if more than 10 exceptions of a given type appear in a 5-minute window. Evaluation frequency minimum is 1 minute; query time range minimum is 5 minutes.

**Activity log alerts** — trigger on subscription-level events in the Azure Activity Log. Example: alert when anyone deletes a resource group in production. These are free and have no metric or log ingestion cost.

**Action groups** define what happens when an alert fires: email, SMS, voice call, webhook, Logic App, Azure Function, Event Hub, or ITSM connector. A single action group can be shared by many alert rules.

**Alert processing rules** let you suppress notifications during planned maintenance windows without deleting alert rules. Configure a processing rule to mute a set of alerts between 2:00 AM and 4:00 AM on Saturday, and no one gets paged during the deployment window.

> [!tip] Start with activity log alerts on production resource groups — they are free, catch accidental deletes and config changes, and require no threshold tuning.

@feynman

An alert rule is a boolean expression over a data stream; an action group is a list of consequence handlers — the rule says "when this is true" and the action group says "do this about it."

@card
id: azr-ch11-c005
order: 5
title: Azure Bicep for Declarative IaC
teaser: Bicep is what ARM JSON should have been — a first-class DSL that compiles to ARM templates, eliminates copy loops, adds modules and type inference, and makes Azure-native IaC maintainable at scale.

@explanation

Bicep is Microsoft's declarative IaC language for Azure. You write `.bicep` files; the Bicep compiler transpiles them to ARM JSON before deployment. The Azure CLI and Azure DevOps pipelines handle this transparently — you never touch the ARM JSON directly.

What Bicep fixes compared to raw ARM:

- **No copy loops** — deploy multiple resources with a simple `for` expression instead of the ARM `copy` object.
- **Modules** — split your template into reusable files and compose them with `module` declarations. A storage module, a vnet module, and a function-app module can each be maintained and versioned independently.
- **Type inference** — property names are validated by the compiler. If you misspell `storageAccountType`, you get a compile error rather than a deployment failure at runtime.
- **Cleaner parameter references** — `param location string = resourceGroup().location` is far more readable than the ARM equivalent.

The `bicep decompile` command converts an existing ARM template to Bicep. Output quality varies — complex templates produce valid but verbose Bicep — but it is the fastest path to onboarding an existing resource into IaC.

When Bicep is the right choice over Terraform: your team deploys exclusively to Azure, you want the tightest possible parity with ARM (Bicep supports every Azure resource type the day ARM does, ahead of the Terraform azurerm provider), and your engineers are willing to learn Bicep syntax. For Azure-only shops this is often the lowest-friction path.

> [!info] Bicep and Terraform are not enemies — some teams use Bicep for foundational Azure infrastructure and Terraform for multi-cloud or application-layer resources. The tools compose at the CLI level.

@feynman

Bicep is to ARM JSON what TypeScript is to hand-written JavaScript bundle output — it is a better authoring experience that compiles to the same underlying format.

@card
id: azr-ch11-c006
order: 6
title: ARM Templates the Foundation Under Bicep
teaser: ARM templates are the native format Azure actually deploys — understanding the structure and deployment modes makes you a better Bicep author and a faster incident responder when deployments go wrong.

@explanation

ARM (Azure Resource Manager) templates are JSON documents that describe the desired state of Azure resources. Every Bicep deployment, every Terraform azurerm provider call, and every portal deployment eventually becomes an ARM template submission to the ARM API.

Template structure:

- `parameters` — inputs that vary between environments (location, SKU, tags).
- `variables` — computed values reused within the template.
- `resources` — the array of resource declarations. Each entry has a `type`, `apiVersion`, `name`, `location`, and `properties`.
- `outputs` — values returned after deployment (resource IDs, connection strings).

**Deployment modes** control what ARM does with resources that exist in the resource group but are not in the template:

- `incremental` (default) — only creates and updates resources in the template; existing resources not mentioned are left alone.
- `complete` — deletes any resource in the resource group that is not in the template. Dangerous on shared resource groups. Correct for resource groups managed entirely by IaC.

**Nested vs linked templates** address scale. Nested templates embed the child template JSON inline (simple, no external dependencies). Linked templates reference an external URL — typically an Azure Storage blob — and require network access at deploy time.

The `what-if` operation (`az deployment group what-if`) shows the diff between current state and desired state before you apply. Run it in every CI pipeline before the actual deployment step. It catches deletions in complete-mode templates before they hit production.

> [!warning] A complete-mode deployment to the wrong resource group will delete resources. Validate with `what-if` and tag resource groups clearly before running complete-mode deployments in production.

@feynman

ARM templates are like a database migration file — they describe a target schema, and the engine figures out the diff; the deployment mode controls whether columns not in the migration get dropped or left alone.

@card
id: azr-ch11-c007
order: 7
title: Terraform on Azure with the azurerm Provider
teaser: Terraform's azurerm provider covers Azure thoroughly, but multi-cloud portability and HCL familiarity are the real reasons to choose it over Bicep — understand the tradeoffs before committing the team.

@explanation

Terraform manages Azure resources via the `azurerm` provider, maintained by HashiCorp in partnership with Microsoft. The provider wraps the ARM API, so any resource available in ARM can eventually be managed in Terraform, though new Azure features typically appear in Bicep first (sometimes by weeks to months).

**Authentication** options: service principal with client secret (common in CI), service principal with certificate, managed identity (preferred for agents running on Azure VMs or GitHub Actions via workload identity federation), and Azure CLI credentials for local development. Avoid committing client secrets to source control.

**Remote state** is mandatory for team use. The canonical Azure pattern is to store Terraform state in an Azure Storage Account blob container with blob-level locking. Three resources to provision before the rest of your infrastructure: a resource group, a storage account, and a blob container. Many teams use a small bootstrap Bicep file to create these, then hand off to Terraform for everything else.

**Terraform workspaces** provide isolated state files within the same backend configuration. Common pattern: `dev`, `staging`, `prod` workspaces in the same storage account, each with a separate state blob.

**Bicep vs Terraform decision framework:**

- Azure-only infra, team wants zero context-switching → Bicep.
- Multi-cloud (Azure + AWS + GCP) in the same codebase → Terraform.
- Team already fluent in HCL → Terraform pays off faster.
- Team starting fresh with Azure → Bicep has a shallower learning curve within Azure.
- Need immediate support for the latest Azure features → Bicep.

> [!tip] If you are already running Terraform for AWS and need to add Azure resources, extend the existing Terraform codebase. Introducing a second IaC tool increases cognitive and operational overhead.

@feynman

Choosing Terraform over Bicep for Azure is like choosing a cross-platform build system over Xcode — the right call if you are targeting multiple platforms, an unnecessary abstraction if you are not.

@card
id: azr-ch11-c008
order: 8
title: Azure DevOps Pipelines for IaC Delivery
teaser: A YAML pipeline is the delivery vehicle that takes your Bicep or Terraform files from source control to deployed infrastructure — the pipeline is not optional, it is where your IaC actually runs.

@explanation

Azure DevOps Pipelines uses YAML to define CI/CD workflows. The three structural levels are:

- **Stages** — logical phases: `Build`, `DeployDev`, `DeployProd`. A stage contains one or more jobs.
- **Jobs** — a set of steps that run on a single agent. Jobs in the same stage can run in parallel.
- **Steps** — individual tasks or script commands: `AzureCLI@2`, `TerraformTaskV4`, `script:`.

Key primitives for IaC pipelines:

**Variable groups** are collections of variables (including secrets) stored in Azure DevOps Library and linked to pipelines. Use them to inject environment-specific values (subscription IDs, key vault names) without hardcoding in YAML.

**Environments** are logical deployment targets (`dev`, `staging`, `prod`) with optional approval gates. A deployment job targeting a protected environment pauses until a human approves — this is your manual gate before production.

**Service connections** are the credential objects that let a pipeline authenticate to Azure. Create an ARM service connection backed by a service principal or workload identity federation; reference it in tasks via `azureSubscription: 'my-service-connection'`.

A typical Bicep pipeline: checkout → `az bicep build` (validate syntax) → `az deployment group what-if` (preview) → manual approval gate → `az deployment group create`. The pipeline is the audit trail: every deployment is logged, linked to a commit, and retraceable.

> [!info] Environments with approval gates solve the "who approved this production deployment?" audit question permanently — the approver is recorded in the pipeline run history with a timestamp.

@feynman

The Azure DevOps pipeline is the shell script that runs your IaC, except it has version history, access controls, approval gates, and a UI — it is infrastructure automation with the same rigor you apply to the infrastructure it deploys.

@card
id: azr-ch11-c009
order: 9
title: GitHub Actions on Azure with OIDC
teaser: GitHub Actions can deploy to Azure without storing a long-lived client secret — OIDC workload identity federation gives you short-lived tokens and removes a whole class of credential-rotation toil.

@explanation

The traditional GitHub Actions / Azure integration uses a service principal client secret stored as a GitHub Actions secret. This works, but secrets expire, get leaked, and must be rotated. OIDC workload identity federation eliminates the stored secret entirely.

**How OIDC works here:**

1. Configure a Federated Identity Credential on an Entra ID app registration (or managed identity). The credential trusts tokens from `token.actions.githubusercontent.com` for a specific GitHub repository and branch/environment.
2. In the GitHub Actions workflow, use the `azure/login@v2` action with `client-id`, `tenant-id`, and `subscription-id` — no `client-secret`. The action requests a short-lived OIDC token from GitHub and exchanges it for an Azure access token.
3. The access token is scoped and expires within minutes of the job ending.

**Deploying IaC from GitHub Actions:**

- `azure/arm-deploy@v1` — deploys an ARM template or compiled Bicep file directly. Accepts `template`, `parameters`, and `deploymentMode` inputs.
- `azure/bicep-build@v0` — compiles a `.bicep` file to ARM JSON as a pipeline step.
- For Terraform, use the `hashicorp/setup-terraform@v3` action followed by standard `terraform init`, `plan`, and `apply` steps authenticated via the OIDC-obtained environment variables (`ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_USE_OIDC=true`).

**Secrets in GitHub Actions vs Key Vault:** GitHub Actions secrets are fine for non-sensitive pipeline config values. For application secrets that the deployed resource itself needs at runtime, use Azure Key Vault references from App Service or retrieve them in the pipeline via `azure/get-keyvault-secrets@v1` — never embed them in workflow YAML.

> [!tip] Set up OIDC from the start. Migrating from client-secret auth to OIDC later is painless, but every week you run with a stored client secret is a week that secret could be leaked via a compromised dependency or a public fork.

@feynman

OIDC workload identity federation is the same pattern as "sign in with GitHub" for human users, except the GitHub Actions runner is the user and Azure is the identity provider being trusted — no password, just proof of identity.

@card
id: azr-ch11-c010
order: 10
title: Diagnostic Settings and Log Routing
teaser: Diagnostic settings are the wiring between Azure resources and your observability stack — without them, logs stay inside the resource and you have no query access, no alerts, and no audit trail.

@explanation

Every Azure resource that produces logs and metrics exposes a diagnostic settings configuration. This is a separate ARM resource (type `microsoft.insights/diagnosticSettings`) attached to the target resource. It defines which log categories and metrics to forward, and where to send them.

**Three destinations:**

- **Log Analytics workspace** — best for querying and alerting. Data appears in workspace tables (e.g., `AzureDiagnostics`, `StorageBlobLogs`, `NetworkSecurityGroupFlowEvent`) with a latency of approximately 5 minutes from event time.
- **Event Hub** — best for streaming to third-party SIEMs (Splunk, Datadog) or real-time processing pipelines. Low latency, no retention.
- **Storage Account** — best for long-term archive and compliance. Low cost per GB. Not queryable without exporting first.

**Log categories vary by resource type.** A storage account exposes categories like `StorageRead`, `StorageWrite`, `StorageDelete`. A virtual network exposes `NetworkSecurityGroupFlowEvent`. You cannot infer the categories from the resource type — check the resource's Diagnostic Settings pane in the portal or run `az monitor diagnostic-settings categories list`.

**Cost implication of ingesting everything:** Log Analytics charges per GB ingested (approximately $2.30 per GB in pay-as-you-go). Enabling all diagnostic categories on a high-traffic storage account or a busy AKS cluster can add hundreds of dollars per month. Be selective: enable audit logs and security events broadly; enable verbose resource logs only for resources actively being debugged.

**IaC tip:** define diagnostic settings in your Bicep or Terraform templates alongside the resource. A storage account resource with no diagnostic settings module attached is an incomplete deployment — you will have no visibility into access patterns or errors until someone manually enables them.

> [!warning] The 5-minute ingestion latency means diagnostic logs are not suitable for real-time alerting on sub-minute events. For that, use platform metrics (near-real-time) and reserve log-based alerts for patterns that require aggregation over minutes or hours.

@feynman

Diagnostic settings are the infrastructure equivalent of adding a log appender to a logger — the resource is already emitting events internally; diagnostic settings are simply the configuration that decides whether those events reach somewhere you can query them.
