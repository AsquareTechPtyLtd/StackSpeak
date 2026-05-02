@chapter
id: aws-ch12-observability-and-iac
order: 12
title: Observability and IaC
summary: AWS gives you CloudWatch for metrics, logs, and alarms; X-Ray for distributed tracing; and a spectrum of IaC tools — CloudFormation, CDK, Terraform, and SSM — to build, operate, and govern infrastructure at scale.

@card
id: aws-ch12-c001
order: 1
title: CloudWatch Metrics and Insights
teaser: CloudWatch Metrics is your numerical pulse on AWS — but the details around namespaces, resolution tiers, and retention schedule determine whether you'll actually find the signal when it matters.

@explanation

Every AWS service publishes metrics into CloudWatch under a **namespace** (e.g., `AWS/EC2`, `AWS/Lambda`). You organize metrics further with **dimensions** — key-value pairs like `InstanceId=i-0abc` or `FunctionName=my-function` — that let you slice data across your fleet.

Two resolution tiers:
- **Standard resolution:** 1-minute granularity. Default for most AWS service metrics and custom metrics.
- **High-resolution:** 1-second granularity. Available for custom metrics via `PutMetricData`. Alarm minimum period drops to 10 seconds. Costs more.

**Retention and granularity decay:** CloudWatch keeps data for 15 months, but the granularity degrades automatically — 1-second data is aggregated to 1-minute after 3 hours, 1-minute to 5-minute after 63 days, 5-minute to 1-hour after 63 days. Plan dashboards accordingly; historical forensics will always be coarser than real-time.

**Metric Math** lets you compute derived metrics in dashboards and alarms — for example, dividing `5xxErrorCount` by `TotalRequests` to get an error rate without publishing a new metric.

**CloudWatch Metrics Insights** adds a SQL-like query syntax across your metric catalog. A query like `SELECT AVG(CPUUtilization) FROM SCHEMA("AWS/EC2") GROUP BY InstanceId` lets you explore across dimensions without knowing instance IDs upfront. Useful for fleet-wide anomaly investigation.

> [!tip] Use Metric Math for error rates and saturation percentages rather than publishing pre-computed values — it keeps your metric count lower and lets you recalculate thresholds without backfilling data.

@feynman

Think of namespaces as database schemas, dimensions as indexed columns, and Metric Math as a computed view you define at query time instead of write time.

@card
id: aws-ch12-c002
order: 2
title: CloudWatch Logs — Groups, Insights, and Subscriptions
teaser: CloudWatch Logs stores text output from nearly every AWS service, but without intentional configuration it turns into an ever-growing, never-expiring cost center.

@explanation

Logs are organized into **log groups** (one per service or application) and **log streams** (one per instance, container, or function invocation). Lambda and ECS write streams automatically; EC2 needs the CloudWatch agent.

**Default retention is never expire.** That means every byte you write accumulates forever until you explicitly set a retention policy on each log group. Common practice: set a lifecycle policy (7 days for debug logs, 90 days for application logs, 1 year for audit logs) immediately at group creation — or enforce it via CloudFormation or AWS Config.

**Metric filters** let you scan incoming log events with a pattern (e.g., `[ERROR]`) and increment a CloudWatch metric each time it matches. This is how you turn unstructured log output into actionable alarms without changing application code.

**CloudWatch Logs Insights** is an interactive query language over log data. You can filter, parse fields, and aggregate:
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
```
Queries are billed per byte scanned, so time-range scoping matters.

**Subscription filters** stream log events in near-real-time to a Kinesis Data Stream, Kinesis Firehose, or Lambda function. This is the pattern for feeding logs into OpenSearch, a SIEM, or a custom alerting pipeline. Each log group supports up to 2 subscription filters.

> [!warning] Not setting a retention policy on log groups is the most common cause of CloudWatch bill surprises. Automate it at provisioning time, not after the first bill.

@feynman

A log group with no retention policy is a bucket with no drain — data flows in continuously and nothing ever leaves until you decide it needs to.

@card
id: aws-ch12-c003
order: 3
title: CloudWatch Alarms, Composite Alarms, and Dashboards
teaser: Alarms are more than alert triggers — they are stateful objects with three distinct states, and composite alarms let you build signal-to-noise logic directly into the monitoring layer.

@explanation

A CloudWatch Alarm evaluates a metric against a threshold over a specified period and moves between three states:
- **OK** — metric is within the acceptable range.
- **ALARM** — threshold breached; actions trigger.
- **INSUFFICIENT_DATA** — not enough data points to evaluate (common at startup or after a gap in metric emission).

Alarm actions let you route state changes to:
- **SNS topics** (fan out to email, SMS, Lambda, PagerDuty, etc.)
- **Auto Scaling policies** (scale out/in EC2 or ECS capacity)
- **EC2 actions** (stop, reboot, terminate, or recover an instance)

**Composite alarms** evaluate a Boolean expression over other alarms using AND/OR/NOT logic. Example: fire only when `HighCPU ALARM AND HighNetworkErrors ALARM`. This is critical for reducing alert fatigue — don't wake someone at 3 AM for CPU alone if it isn't correlated with errors.

**CloudWatch Dashboards** are shareable, configurable operational screens. Widgets can show metrics, alarms, log queries, and text. Two capabilities worth knowing:
- **Cross-account dashboards** — aggregate metrics from multiple AWS accounts into a single view using CloudWatch cross-account observability.
- **Cross-region dashboards** — plot metrics from us-east-1 and eu-west-1 on the same widget.

Dashboards are billed per dashboard per month (first 3 are free), not per widget.

> [!info] Model your composite alarms to reflect real user impact, not raw infrastructure state. A single composite alarm per service that fires only when users are affected is more actionable than ten individual metric alarms.

@feynman

A composite alarm is a circuit breaker wired across multiple signals — it only trips when the combination of conditions indicates a real problem, not when any single sensor twitches.

@card
id: aws-ch12-c004
order: 4
title: AWS X-Ray — Distributed Tracing
teaser: X-Ray gives you a visual map of request flow across your services, turning a cascade of CloudWatch metrics into a traceable path from entry point to failure.

@explanation

X-Ray works by injecting a **trace ID** into every request at the entry point. Each service that handles the request records a **segment** (its own work) and optionally **subsegments** (downstream calls to databases, HTTP APIs, or other services). The segments are assembled into a trace — a full timeline of one request's path through the system.

**Sampling rules** control what fraction of requests are traced. The default: 5% of requests after the first request per second. You can configure custom rules (e.g., 100% sampling for errors, 1% for healthy requests) to balance coverage against cost and noise.

**X-Ray Service Map** auto-generates a visual graph of your services and their dependencies, annotated with error rates and latency percentiles. This is the fastest way to identify which service in a call chain is introducing latency or errors.

Two metadata models on segments:
- **Annotations** — indexed key-value pairs (e.g., `userId`, `tenantId`). You can filter and search traces by annotations. Use these for anything you want to query.
- **Metadata** — arbitrary JSON, not indexed. Use for verbose debug data you might need to inspect but won't search across.

**Integration surface:** Lambda adds trace headers automatically when active tracing is enabled. API Gateway passes trace IDs downstream. ECS requires the X-Ray daemon as a sidecar container. EC2 needs the daemon installed manually.

> [!tip] Add user-facing identifiers (order ID, customer ID) as X-Ray annotations from day one. Filtering traces by customer ID during an incident is far faster than correlating log lines across services.

@feynman

X-Ray is like a flight data recorder for your request — every segment is a leg of the journey, and the trace is the full black box that tells you exactly where and why the flight ended early.

@card
id: aws-ch12-c005
order: 5
title: AWS CloudFormation — Infrastructure as Code
teaser: CloudFormation is AWS's native IaC — you describe resources in JSON or YAML, and AWS manages the create, update, and delete lifecycle, including rollback when things go wrong.

@explanation

A CloudFormation **template** is a JSON or YAML file that declares a set of AWS resources and their configuration. You deploy it as a **stack**. CloudFormation handles dependency ordering, parallel provisioning where possible, and tracks resource state.

The resource lifecycle:
- **Create** — provisions resources in dependency order; rolls back the entire stack if any resource fails.
- **Update** — computes a diff and modifies only changed resources. Some changes require replacement (a new resource is created, traffic shifted, old one deleted) — CloudFormation signals this clearly.
- **Delete** — tears down all resources in reverse dependency order. Resources with `DeletionPolicy: Retain` or `Snapshot` are handled accordingly.

**Change sets** let you preview what an update will do before applying it. This is your "plan before apply" step. Always use change sets in production before updating a stack.

**Stack policies** restrict which resources can be replaced or deleted during updates. You define an IAM-style policy document and attach it to the stack. Useful for protecting stateful resources like RDS instances from accidental replacement.

**Drift detection** compares live resource configuration against the template. If someone manually modified a security group after CloudFormation created it, drift detection surfaces the delta. It does not auto-remediate — it flags, you decide.

> [!warning] Drift detection is not continuous. It is a point-in-time scan you initiate manually or schedule. If you care about configuration compliance, pair it with AWS Config rules for real-time detection.

@feynman

CloudFormation is a reconciliation loop: you declare the desired state in a template, and AWS keeps working until the stack matches — including cleaning up what no longer belongs.

@card
id: aws-ch12-c006
order: 6
title: AWS CDK — Infrastructure in Real Code
teaser: CDK lets you define infrastructure in TypeScript, Python, or other languages, compiles it to CloudFormation, and unlocks loops, conditionals, and reusable constructs that YAML simply cannot express.

@explanation

The AWS Cloud Development Kit (CDK) generates CloudFormation templates from code. You write a CDK app in TypeScript, Python, Java, Go, or C#, run `cdk synth`, and get a CloudFormation template. `cdk deploy` synthesizes and deploys in one step.

CDK uses a three-tier **construct** model:
- **L1 (Cfn* classes):** Direct wrappers of CloudFormation resource types. No defaults, full control. Generated directly from the CloudFormation schema. Use when you need exact resource properties.
- **L2 (higher-level constructs):** Opinionated defaults with sensible security settings. `aws-cdk-lib.aws_s3.Bucket` creates a bucket with sane encryption defaults, whereas `CfnBucket` gives you a blank slate. Most day-to-day work happens here.
- **L3 (patterns):** Multi-resource compositions — e.g., `aws-cdk-lib.aws_ecs_patterns.ApplicationLoadBalancedFargateService` provisions ECS service, task definition, ALB, security groups, and IAM roles in one construct. Use patterns to bootstrap standard architectures fast.

**When CDK beats raw CloudFormation:**
- You need loops (provision 10 identical resources with parameterized names).
- You want reusable constructs shared across teams as a library.
- You need conditional logic that would require Conditions + Fn::If chains in YAML.
- You want IDE autocomplete and type safety on resource properties.

**CDK Toolkit commands:** `cdk synth` (generate CloudFormation), `cdk diff` (preview changes), `cdk deploy` (apply), `cdk destroy` (tear down).

> [!info] CDK still deploys via CloudFormation — all CDK stacks appear in the CloudFormation console and follow the same rollback and change set semantics. CDK is an authoring experience, not a separate deployment engine.

@feynman

CDK is a compiler for infrastructure — you write in a high-level language, it emits CloudFormation assembly, and AWS executes the assembly the same way it always has.

@card
id: aws-ch12-c007
order: 7
title: Terraform on AWS — HCL-Based Multi-Cloud IaC
teaser: Terraform uses HashiCorp Configuration Language to manage AWS infrastructure — and its state model and multi-cloud reach make it the dominant choice outside AWS-centric teams.

@explanation

Terraform describes infrastructure in **HCL** (HashiCorp Configuration Language). An AWS **provider** maps HCL resource blocks to AWS API calls. You run `terraform plan` to preview changes and `terraform apply` to execute them.

The **state file** is Terraform's record of what it has provisioned. By default it is local, which is fine for one developer but dangerous on a team. The production pattern: store state in **S3 with DynamoDB locking** — S3 holds the file, DynamoDB provides a lock to prevent concurrent applies.

Core workflow:
- `terraform plan` — compare desired config to current state; emit a diff.
- `terraform apply` — apply the plan.
- `terraform destroy` — tear down all resources tracked in state.

**Workspaces** let you maintain multiple state files from the same configuration — useful for isolating dev, staging, and prod environments. Each workspace gets its own state. This is simpler than duplicating directories but requires discipline in variable handling.

**CDK vs Terraform decision tree:**
- AWS-only shop with existing CloudFormation expertise → CDK is a natural fit.
- Multi-cloud or team with existing Terraform expertise → Terraform.
- Need to manage non-AWS resources (Datadog monitors, GitHub teams, PagerDuty schedules) in the same state → Terraform, because CDK has no provider model for non-AWS APIs.
- Want to share reusable infrastructure libraries across teams in a typed language → CDK constructs are more ergonomic.

> [!tip] Lock your Terraform provider version (`~> 5.0` not just `>= 5.0`) and pin the Terraform binary version in your CI pipeline. Provider version drift between environments is a reliable source of plan discrepancies.

@feynman

Terraform is like a database migration tool for cloud infrastructure — the state file is the schema history, and every plan is a migration diff you review before committing.

@card
id: aws-ch12-c008
order: 8
title: AWS Systems Manager — Fleet Operations Without SSH
teaser: SSM is the operational backbone for managing EC2 instances and other resources at scale — no bastion hosts, no open port 22, no manually distributed secrets.

@explanation

**Parameter Store** is a hierarchical key-value store for configuration and secrets. Standard parameters are free; advanced parameters support larger values and higher throughput. Use `/myapp/prod/db-password` path conventions. SecureString parameters are encrypted with KMS. Applications fetch values at runtime with `GetParameter` — no secrets in environment variables or config files.

**Session Manager** provides browser-based and CLI shell access to EC2 instances (and on-premises servers with the SSM agent) without an open inbound port. Sessions are routed through the SSM service, logged to CloudWatch Logs or S3, and controlled via IAM. This replaces SSH and bastion hosts for most use cases.

**Run Command** executes scripts or predefined documents (`SSM Documents`) across a fleet simultaneously. Example: run a `yum update` across 200 instances, filtered by tag, with per-instance execution logs. No SSH required.

**Patch Manager** automates OS and application patching. You define a patch baseline (which patches are approved), a maintenance window, and a target group. Patch Manager applies patches and reports compliance per instance.

**State Manager** enforces a desired configuration state continuously. If an instance drifts from the baseline — an agent stops running, a config file is modified — State Manager reapplies the association on schedule.

**Inventory** collects metadata from managed instances — installed software, network configuration, running services — and stores it in a queryable SSM Inventory database. Useful for fleet visibility and compliance audits.

> [!info] Session Manager with CloudWatch logging satisfies most compliance requirements for auditable shell access. Pair it with IAM permission boundaries to give developers instance access without root-level AWS console access.

@feynman

SSM is the control plane for your fleet — every instance becomes a managed resource you operate through APIs rather than a server you log into manually.

@card
id: aws-ch12-c009
order: 9
title: AWS Service Catalog — Governed Self-Service Infrastructure
teaser: Service Catalog lets developers provision approved infrastructure without full AWS access — the governance lives in the product definition, not in the access policy.

@explanation

Service Catalog is a governance layer over CloudFormation. Administrators package CloudFormation templates as **products** and organize them into **portfolios**. Products can have multiple versions — a newer version can be released without breaking existing provisioned resources.

Users (developers, data scientists, etc.) access portfolios assigned to them and launch products. The key design: the user does not need CloudFormation `CreateStack` permission in IAM. Instead, a **launch constraint** specifies an IAM role that Service Catalog assumes during provisioning. The template runs with that role's permissions, not the user's — enabling a developer to provision an RDS instance using a template that hard-codes the security group, KMS key, and parameter group, without the developer having the raw IAM permissions to make those choices differently.

This pattern solves a real tension: developers need infra to be productive, but open CloudFormation access lets them provision anything, including expensive, insecure, or non-compliant resources.

Operational model:
1. Platform team writes and maintains approved CloudFormation templates.
2. Templates are published as Service Catalog products with guardrails baked in (encryption enabled, VPC placement enforced, backup policies attached).
3. Developers self-service from the catalog. Provisioning is tracked per user in the Service Catalog console.
4. Platform team updates product versions; existing provisioned products can be upgraded.

> [!warning] Service Catalog adds operational overhead — products need to be maintained as underlying service APIs evolve. Invest in it when you have 10+ teams or regulatory compliance requirements. For a two-team startup, it is likely premature.

@feynman

Service Catalog is like a vending machine for infrastructure — you've pre-loaded only the approved options, users pick what they need, and the machine handles the provisioning with its own key, not yours.

@card
id: aws-ch12-c010
order: 10
title: Tagging Strategy and Cost Allocation
teaser: Tags are the metadata layer that makes cost attribution, compliance, and operational visibility possible at scale — but they only work if you enforce them before the infrastructure exists, not after.

@explanation

A tag is a key-value pair attached to an AWS resource. Tags are not strongly typed, not validated by AWS by default, and completely optional — which means without governance, you'll have some resources tagged `Environment=prod`, others tagged `env=production`, and many tagged nothing.

**Cost Allocation Tags** connect your tagging strategy to billing. After activating a tag key in the Billing console (takes up to 24 hours to appear in Cost Explorer), you can filter and group costs by that tag. A query like "show me all spend tagged `team=payments` this month" becomes actionable only if the payments team tags their resources consistently.

**Enforcing tags at provisioning time:**
- **Service Control Policies (SCPs):** Block resource creation if required tags are missing. Enforces at the Organizations level before the API call succeeds.
- **AWS Config rules:** Detect resources without required tags and flag them as non-compliant. Does not block creation but produces a compliance report.
- **CloudFormation / CDK:** Bake required tags into every stack template so resources inherit them at creation.

**Operational discipline required:**
- Define a standard taxonomy before resources exist (e.g., `Environment`, `Team`, `Service`, `CostCenter`).
- Automate tagging via IaC — never rely on manual post-creation tagging.
- Audit monthly: untagged resources appearing in Cost Explorer are a signal that something bypassed your IaC pipeline.

Tagging pays dividends beyond billing: operational dashboards filtered by `Service=api`, CloudWatch alarms grouped by `Team`, and SSM Run Command targets filtered by `Environment=prod` all depend on consistent tags.

> [!info] Activate Cost Allocation Tags in the Billing console as soon as you define your taxonomy — the 24-hour activation delay means any cost data generated before activation is permanently unattributable to that tag.

@feynman

Tags are like Git commit metadata — they cost nothing to add at the time, but trying to reconstruct who owns what after the fact is an archaeology project you don't want to run.
