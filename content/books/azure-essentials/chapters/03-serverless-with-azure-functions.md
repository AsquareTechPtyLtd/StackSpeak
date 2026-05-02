@chapter
id: azr-ch03-serverless-with-azure-functions
order: 3
title: Serverless with Azure Functions
summary: Azure Functions is Azure's event-driven serverless compute platform — this chapter covers its execution model, hosting plans, triggers and bindings, Durable Functions orchestrations, cold starts, networking, secrets, monitoring, and how it compares to AWS Lambda.

@card
id: azr-ch03-c001
order: 1
title: The Azure Functions Execution Model
teaser: A Function is the smallest unit of deployment in Azure Functions — a single trigger-bound handler that the Functions host discovers, wires up, and executes on demand

@explanation

An Azure Function is a single piece of code paired with a trigger and zero or more bindings. The runtime responsible for managing the function's lifecycle is the **Functions host** — a process that runs inside a container or VM, discovers your function definitions, and dispatches invocations as events arrive.

Key building blocks:

- **Function app** — the deployment unit. One or more functions packaged together, sharing a runtime version, configuration, and compute resources.
- **Trigger** — exactly one per function. Defines what causes execution: an HTTP request, a queue message, a timer, a blob upload. A function without a trigger is inert.
- **Bindings** — optional input/output connectors declared in code (or `function.json` for scripted languages). They wire your function to external services without you writing SDK boilerplate.
- **Functions host** — the go-between layer. It handles scaling decisions, trigger polling (for queue and timer triggers), binding resolution, and integration with the underlying compute plan.

**Supported languages** include C#, JavaScript, TypeScript, Python, Java, and PowerShell via first-class workers. Go, Rust, and others are supported through the **custom handler** model, where your binary acts as an HTTP server and the Functions host proxies invocations to it.

The isolation model varies by plan: on Consumption you share infrastructure with other tenants; on Premium and Dedicated you get dedicated VMs. The host itself is the same across plans — it's the underlying compute and scaling behavior that changes.

> [!info] The "one trigger per function" constraint is intentional. It keeps each function's reason-for-existing explicit and testable — a function that can be started by five different event types is five functions in disguise.

@feynman

It's like a web framework's route handler, except instead of just HTTP verbs, the "verb" can be a queue message, a blob upload, or a timer tick — and the framework handles the polling and connection management for you.

@card
id: azr-ch03-c002
order: 2
title: Hosting Plans and When to Use Each
teaser: Four hosting plans cover every tradeoff between cost, cold starts, execution time, and network isolation — picking the wrong one is a common source of production surprises

@explanation

The hosting plan determines where your function runs, how it scales, and what limits apply. There are four options:

**Consumption plan** — the original serverless plan. Scales to zero when idle, scales out automatically under load. You pay only for the invocations and execution time you use. The catch: cold starts (200ms–2s+), a default 5-minute execution timeout (configurable up to 10 minutes), no VNet integration, and no guaranteed instance count. Use it for workloads with unpredictable or low traffic where cost efficiency matters more than latency.

**Flex Consumption plan** (generally available from 2025/2026) — a redesigned serverless plan. Supports **always-ready instances** to eliminate cold starts on a defined concurrency baseline, per-part billing (you pay for the always-ready capacity separately), and longer timeouts. This is the plan to reach for when Consumption cold starts are a problem but you don't want to commit to Premium pricing.

**Premium plan** — pre-warmed worker instances that are never cold-started. Supports VNet integration (outbound), private endpoints (inbound), longer execution times (up to 60 minutes), and VNET-triggered scaling. Priced per-second of compute on always-running instances. Use it for latency-sensitive workloads, private network access, or execution times beyond 10 minutes.

**Dedicated (App Service) plan** — your function runs on an App Service VM you already manage. No auto-scale-to-zero unless you configure it explicitly. No additional compute cost if the VM is already paid for. Use it when you have reserved App Service capacity and just need the Functions programming model on top of it.

> [!warning] Consumption plan VNet integration is not supported. If your function needs to talk to a private database, storage account with a service endpoint, or anything inside a VNet, you must use Premium or Flex Consumption.

@feynman

Consumption is like a taxi — pay per ride, but you wait for one to show up; Premium is like a company car sitting in the garage — always ready, always billing.

@card
id: azr-ch03-c003
order: 3
title: Triggers and Bindings in Practice
teaser: Bindings replace the boilerplate of connecting to Azure services — declare what you want to read or write and let the runtime handle the SDK, connection, and retry logic

@explanation

Triggers and bindings are the contract between your function and the outside world. You declare them — in code attributes for C#, or in `function.json` for scripted languages — and the Functions runtime wires up the actual connections.

**Trigger types** include:

- **HTTP** — exposes the function as an HTTP endpoint, useful for REST APIs and webhooks
- **Timer** — CRON expression-driven scheduled execution
- **Blob** — fires when a blob is created or modified in Azure Blob Storage
- **Queue** — processes messages from Azure Storage Queue, with built-in retry and poison-message handling
- **Service Bus** — messages or topic subscriptions from Azure Service Bus
- **Event Hub** — high-throughput event stream batches from Event Hubs
- **Cosmos DB** — change feed trigger, fires on document inserts/updates
- **Durable** — orchestration, activity, entity, and client triggers for Durable Functions

**Input bindings** let you read data from a source at invocation time — for example, binding a Blob input to load a document by ID extracted from a queue message. **Output bindings** write data without you calling an SDK: a `[BlobOutput]` attribute on a return value writes the result to Storage automatically.

The binding expression syntax uses `{variableName}` to interpolate values from trigger metadata. For example, a Blob trigger path of `uploads/{name}` passes the blob name through to bindings on the same function.

The practical payoff: you avoid hand-rolling polling loops for queues, retry logic for transient failures, and connection management for Azure SDKs. For simple read-write patterns, bindings can reduce a 60-line function to 15 lines.

> [!tip] Use output bindings aggressively for common sinks (Storage, Cosmos DB, Service Bus). Reserve direct SDK calls for operations the binding model doesn't cover: conditional writes, batch operations, or cases where you need the response object.

@feynman

Bindings are like ORM associations — instead of writing SQL to load a related record, you declare the relationship and the framework fetches it before your method runs.

@card
id: azr-ch03-c004
order: 4
title: Durable Functions — Stateful Orchestrations
teaser: Durable Functions adds stateful, long-running workflow coordination on top of the stateless Functions runtime — without you managing checkpoints, queues, or retry state

@explanation

A standard Azure Function is stateless: it runs, it exits, and anything in memory is gone. Durable Functions extends the runtime with a checkpointing mechanism (backed by Azure Storage) that lets you write workflows as ordinary sequential or branching code, even when those workflows span minutes, hours, or days.

Three core patterns:

**Orchestrator/Activity pattern** — the orchestrator function is the workflow coordinator. It calls activity functions (the actual work units) and awaits their results. The runtime checkpoints the orchestrator's state after each `await`, so if the process restarts mid-workflow, it replays history to restore position. Activity functions are stateless and can run in parallel.

**Fan-out/fan-in** — the orchestrator fires N activity functions in parallel (`Task.WhenAll`), then aggregates their results. Common for map-reduce-style work: splitting a large file into chunks, processing each in parallel, merging results.

**Human interaction (approval) workflows** — the orchestrator calls `WaitForExternalEvent`, suspending until a signal arrives (e.g., a manager approves a request via a webhook). The orchestrator resumes on the signal. Timeout escalation is built in: if no signal arrives within an interval, a timer fires and the workflow takes a different path.

**Async HTTP APIs** — the orchestrator starts immediately, returns a `202 Accepted` with a status URL, and the client polls. Durable handles the status endpoint automatically.

**Eternal orchestrations** — orchestrators that restart themselves in a loop via `ContinueAsNew`, used for long-running polling or monitoring tasks without unbounded history growth.

The cost: Durable Functions uses Azure Table Storage and Azure Queues for checkpointing. At high throughput this can become a bottleneck; for very high-scale orchestrations, the Netherite storage provider (backed by Event Hubs) is the alternative.

> [!info] Orchestrator functions must be deterministic — no random numbers, no `DateTime.Now`, no direct I/O. All non-deterministic work belongs in activity functions, which the orchestrator calls and awaits.

@feynman

Writing a Durable orchestrator is like writing an async/await workflow in normal code, except the runtime checkpoints the call stack to durable storage so it survives process restarts the same way a database transaction survives a server reboot.

@card
id: azr-ch03-c005
order: 5
title: Cold Starts — Causes, Costs, and Mitigations
teaser: A cold start is the latency tax you pay when Azure has to provision a new instance for your function — understanding what drives it tells you which mitigation to reach for

@explanation

A cold start happens when Azure needs to spin up a new worker instance to handle an invocation because no warm instance is available. The sequence:

1. Azure allocates a container or VM slot.
2. The Functions host process starts.
3. The language worker (the .NET, Node, Python, or JVM process) initializes.
4. Your function app's code and dependencies load.
5. The function handles the request.

Steps 1–4 are the cold start. Typical latencies:

- **.NET (in-process or isolated worker):** 200–600ms on Consumption
- **Node.js / Python:** 500ms–1.5s, depending on dependency count
- **Java:** 2–4s+ on Consumption; the JVM startup cost is substantial
- **Pre-compiled C# with minimal dependencies:** as low as ~150ms

Cold starts only affect the first request to a new instance; subsequent requests on the same warm instance have no cold start overhead. Under sustained load, Azure keeps instances warm and you don't notice cold starts at all. The problem is sporadic or bursty traffic, or low-traffic functions that sit idle.

**Mitigations:**

- **Premium plan** — maintains pre-warmed instances at all times. Zero cold starts.
- **Flex Consumption always-ready instances** — you specify a minimum concurrency baseline; Azure keeps that many instances warm. You pay for the always-ready capacity separately.
- **"Always On" setting on Dedicated plan** — prevents the App Service plan from recycling idle workers.
- **Language choice** — if cold start latency is critical and you're on Consumption, prefer C# or Node.js over Java.

> [!warning] Premium plan eliminates cold starts but does not scale to zero. You pay for at least one instance continuously. For truly sporadic workloads the economics often favor Flex Consumption with always-ready instances instead.

@feynman

A cold start is like the first compile in a fresh dev container — everything after that runs fast, but the first invocation pays the full initialization cost.

@card
id: azr-ch03-c006
order: 6
title: Azure Logic Apps vs Azure Functions
teaser: Logic Apps and Functions both process events and integrate services, but they optimize for opposite profiles — choosing the right one saves you from building a visual workflow in code or writing a no-code integration that needs custom logic

@explanation

Logic Apps and Azure Functions are complementary services that overlap enough to cause confusion. The choice comes down to what kind of work you're doing and who's maintaining it.

**Logic Apps wins when:**

- You're building an integration workflow — moving data between systems, transforming formats, routing events
- Your connectors are among the 400+ Logic Apps connectors (Salesforce, SAP, Outlook, Dynamics, Slack, and so on)
- The people who will maintain the workflow are not developers — the visual designer makes the logic auditable by PMs and ops staff
- You need built-in retry policies, run history, and step-by-step debugging of connector calls without writing any code

**Functions wins when:**

- Your logic requires a real programming language: complex transformations, custom algorithms, string parsing, conditional branching that would be ugly in a visual designer
- You need full control over dependencies, performance, and error handling
- You're writing an API, not an integration
- Your team works in code and treats the visual designer as overhead

**They compose well.** A common pattern: a Logic Apps workflow handles connector-heavy data ingestion (pull from Salesforce, transform, write to Blob), then calls an HTTP-triggered Azure Function for the custom transformation step that Logic Apps can't express cleanly. You get 400+ connectors for free and full language power where you need it.

Logic Apps Standard (the newer tier) runs on the same App Service/Functions runtime and supports local development, source control, and CI/CD — narrowing the developer experience gap significantly.

> [!tip] If you're spending more time fighting the Logic Apps designer than writing logic, you've crossed the threshold where a Function is the right tool. The threshold is typically any non-trivial branching or custom computation.

@feynman

Logic Apps is like a no-code ETL pipeline tool — it shines for connector-rich integration work, but the moment you need a for-loop or a custom parser, you want a Function sitting alongside it.

@card
id: azr-ch03-c007
order: 7
title: Azure Functions and VNet Integration
teaser: Getting your function onto a private network requires the right hosting plan — Consumption leaves you stranded outside the VNet perimeter

@explanation

Private connectivity matters as soon as your function needs to reach a resource that isn't on the public internet: a database on a VNet, a storage account with a service endpoint, an internal API behind a private endpoint, or an on-premises resource via ExpressRoute.

There are two directions of traffic to reason about:

**Outbound (function calling other services)** — controlled by **VNet Integration**. When enabled, outbound calls from your function route through a delegated subnet in your VNet, picking up the VNet's routing rules, DNS, and NSGs. VNet Integration is available on Premium plan and Dedicated (App Service) plan. As of 2025/2026, Flex Consumption also supports it.

**Inbound (clients calling the function)** — controlled by **Private Endpoints** on the function app itself. With a private endpoint, the function's HTTP trigger URL resolves to a private IP on your VNet and is unreachable from the public internet. Private endpoints are available on Premium and Dedicated plans.

**Consumption plan networking gap** — standard Consumption plan has neither outbound VNet Integration nor inbound private endpoints. If your function is on Consumption and your database is behind a private endpoint, the function cannot reach it. This catches teams off guard when they secure storage accounts or Cosmos DB accounts with VNet restrictions after initial deployment.

Typical private architecture:

- Function on Premium plan or Flex Consumption with VNet Integration enabled
- Outbound traffic routes through a dedicated subnet (`/28` minimum)
- Target resources (Cosmos DB, SQL, Key Vault) have private endpoints on the same or peered VNet
- NSGs on the function's subnet control which resources it can reach

> [!warning] Enabling VNet Integration on a Premium plan is not instant — it requires subnet delegation to `Microsoft.Web/serverFarms`, which cannot be changed once a subnet has live resources attached. Size the subnet correctly (at least `/26` for room to scale) before enabling.

@feynman

VNet Integration is like adding a NIC to a VM on a private subnet — once it's there, outbound traffic from your function follows the VNet's routing table instead of going out the public internet.

@card
id: azr-ch03-c008
order: 8
title: Function App Configuration and Secrets
teaser: Application settings are environment variables with a Key Vault superpower — pull secrets at runtime without a connection string in your config file

@explanation

Azure Functions reads configuration from **application settings** — key-value pairs stored in the function app's configuration plane, injected as environment variables at runtime. In local development these live in `local.settings.json`; in Azure they live in the portal or ARM/Bicep.

Straightforward settings are fine for non-secret values: feature flags, resource URIs, environment names. For secrets, you have two options:

**Option 1: Store the secret directly in application settings.** It's encrypted at rest and not visible in logs, but it means the secret's plaintext is in the app's config surface. Rotation requires redeployment or a settings update.

**Option 2: Key Vault references.** Set the application setting's value to a Key Vault reference:

```
@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/MySecret/)
```

The Functions host resolves this reference at startup, fetching the current secret value from Key Vault. Your function code reads the environment variable and gets the plaintext value — it never sees the Key Vault URI.

To pull secrets this way without a connection string:

1. Enable a **system-assigned managed identity** on the function app.
2. Grant the identity `Key Vault Secrets User` on the Key Vault.
3. Set the application setting value to the `@Microsoft.KeyVault(...)` syntax.

No credentials in config. No rotation ceremony — update the secret in Key Vault and the next invocation after the cache TTL (~30 minutes) picks up the new value.

This pattern extends to connection strings for storage, Service Bus, and Event Hubs: instead of a connection string in settings, store the connection string in Key Vault and reference it, or better — use managed identity directly for SDK authentication where the SDK supports it.

> [!tip] Prefer managed identity authentication over connection strings wherever the target service supports Azure AD auth (Storage, Service Bus, Event Hubs, Cosmos DB, Key Vault all do). Connection strings are a credential that can be copied; managed identity is an identity that cannot.

@feynman

Key Vault references in app settings are like a `.env` file that fetches its own values from a secrets manager at startup — your code reads a normal environment variable and the plumbing stays out of your repository.

@card
id: azr-ch03-c009
order: 9
title: Monitoring Azure Functions with Application Insights
teaser: Application Insights is the built-in observability layer for Functions — invocations, failures, durations, and dependency traces flow in automatically the moment you wire up the instrumentation key

@explanation

Every function app should have Application Insights attached. The integration is automatic: add the `APPLICATIONINSIGHTS_CONNECTION_STRING` application setting and the Functions host starts emitting telemetry without any code changes.

**What you get automatically:**

- **Invocation logs** — every function execution, with success/failure, duration, and trigger metadata
- **Exception tracking** — unhandled exceptions are captured with full stack traces and correlated to the invocation
- **Dependency tracking** — outbound HTTP calls, SQL queries, and calls to Azure services (Storage, Service Bus) are traced automatically
- **Performance counters** — memory, CPU, and request rates on the underlying worker instance

**Live Metrics stream** (`/metrics/live` in the portal) is the fastest debugging surface during active incidents: you see invocation counts, failure rates, and server telemetry in near-real-time with sub-second latency, without waiting for the normal 1-2 minute ingestion delay.

**Custom telemetry** — inject `TelemetryClient` (via the Application Insights SDK) to emit custom events, metrics, and traces from within your function code. This is how you track business-level signals: "order processed," "cache hit rate," "file size histogram."

**Alerting** — define metric alerts on standard signals:

- `requests/failed` — function failure count
- `requests/duration` — P95 latency threshold
- `customMetrics/{name}` — business-level custom metrics

Log-based queries in Application Insights use **KQL** (Kusto Query Language). A useful starting point: `requests | where success == false | summarize count() by name, bin(timestamp, 5m)` — failure counts per function per 5-minute window.

> [!info] The Application Insights sampling configuration matters on high-volume functions. At default settings, 100% of telemetry is ingested — which is expensive at thousands of invocations per minute. Configure adaptive sampling or a fixed rate to control cost.

@feynman

Application Insights attached to a function app is like structured logging plus a distributed trace exporter wired in at the framework level — you get invocation spans, dependency traces, and exception correlation without adding an APM agent yourself.

@card
id: azr-ch03-c010
order: 10
title: Azure Functions vs AWS Lambda
teaser: Functions and Lambda solve the same problem with different trade-offs — the differences in cold starts, bindings, and pricing become real when you're choosing a platform or porting a workload

@explanation

Azure Functions and AWS Lambda are direct competitors in the FaaS space. At a high level they're equivalent: event-driven, auto-scaling, pay-per-invocation compute. The differences matter at the edges.

**Cold starts** — Lambda cold starts are comparable to Functions Consumption: 100ms–2s depending on runtime and package size. Lambda SnapStart (for Java) pre-initializes the JVM snapshot, reducing Java cold starts to ~200ms — a meaningful advantage over Functions Consumption for Java workloads. Functions Premium and Flex Consumption always-ready instances are the equivalent mitigation on the Azure side.

**Trigger/binding vs event source mapping** — Functions bindings and Lambda event source mappings both connect functions to event sources without hand-written polling, but Functions bindings also cover output (writing to Cosmos DB, Storage, Service Bus) without SDK code. Lambda event source mappings are primarily input-side; output connections require SDK calls.

**Hosting plan equivalents:**
- Lambda (base) ≈ Functions Consumption
- Lambda with Provisioned Concurrency ≈ Functions Premium / Flex Consumption always-ready
- Lambda on EC2 (via App Runner or self-hosted) has no clean equivalent — Functions Dedicated plan is the closest analog

**Pricing model** — both charge per invocation and per GB-second of execution time. Lambda's free tier (1M invocations/month, 400K GB-seconds) is generous for low-volume workloads. Functions Consumption has the same structure. At high volume the difference is small; the real cost driver is the always-on capacity of Premium vs Provisioned Concurrency.

**Portability and self-hosted scenarios** — if you want to run function-style workloads on Kubernetes (on-prem or any cloud), **KEDA** (Kubernetes Event-driven Autoscaling) supports both Azure Functions (via the Functions worker model) and Lambda-like workloads via its scalers. KEDA lets you use the Functions programming model without being tied to Azure's managed hosting.

> [!info] If you're already in Azure and need event-driven compute, Functions is the default choice. The decision to use Lambda is about existing AWS infrastructure or team expertise — not a functional capability gap.

@feynman

Choosing between Functions and Lambda is like choosing between Azure DevOps Pipelines and GitHub Actions — both can build and deploy anything, and the right answer is usually whichever one is already where your other infrastructure lives.
