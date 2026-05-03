@chapter
id: plf-ch09-cost-and-finops
order: 9
title: Cost and FinOps for Platforms
summary: Platform engineering and FinOps share an audience — and the platform team is uniquely positioned to enforce cost discipline, expose unit economics, and shift cost-awareness from finance into the developer's daily workflow.

@card
id: plf-ch09-c001
order: 1
title: The Platform as Cost-Control Choke Point
teaser: Because every team's infrastructure flows through the platform, the platform team is the single best place in the organization to enforce cost discipline — if it chooses to.

@explanation

Most organizations try to manage cloud spend through finance reviews and monthly budget alerts. Both arrive too late. By the time a team sees its bill, the expensive resource has already run for weeks.

The platform team has a structural advantage: it controls the provisioning path. Every Kubernetes namespace, every database, every cloud account comes into existence because some platform abstraction permitted it. That means the platform can:

- **Enforce tagging at creation time.** Resources that don't carry required tags (team, service, environment) can be rejected before they're ever provisioned — not audited after the fact.
- **Set cost-aware defaults.** Auto-scaling maximums, default instance sizes, and default retention periods are all platform choices. Expensive defaults propagate to every team; conservative defaults save money at scale.
- **Surface costs at provisioning time.** A developer requesting a new RDS instance through a platform form can be shown an estimated monthly cost before they click confirm.
- **Own the shared infrastructure layer.** Ingress controllers, observability stacks, CI runners, and secrets managers are shared costs. Only the platform team has visibility into how they're consumed and how to allocate those costs fairly.

The tradeoff is responsibility. When the platform team takes on cost governance, it also takes on the role of saying "no" to engineers — or at least "here's what that will cost." That requires organizational trust and a clear mandate.

> [!info] The platform team's cost leverage is highest at provisioning time. Every dollar of waste that gets prevented at the IDP layer is a dollar that never shows up in a surprised finance review.

@feynman

The platform is like the only hardware store in town — if every team has to come through you to buy materials, you can post prices, enforce bulk limits, and refuse to sell without a project code.

@card
id: plf-ch09-c002
order: 2
title: The FinOps Foundation Framework
teaser: The FinOps Foundation defines three iterative phases — Inform, Optimize, Operate — and the platform team has a role to play in all three, not just reporting.

@explanation

The FinOps Foundation (finops.org) is the industry body that codified cloud financial management into a repeatable discipline. Its framework is built around three phases that teams cycle through continuously, not once:

**Inform:** Make costs visible and attributable. This means tagging, allocation, and dashboards. Teams cannot optimize what they cannot see. The platform's contribution here is enforcing tagging policies and feeding cost data into dashboards that developers actually look at — not just the ones finance uses.

**Optimize:** Reduce waste and improve efficiency. This covers right-sizing, reserved capacity purchasing, auto-scaling configuration, and idle resource cleanup. The platform team often has more leverage here than individual teams because it controls defaults and can act across all workloads simultaneously.

**Operate:** Establish ongoing processes. Cost reviews in sprint planning, cost owners per service, automated anomaly alerting, and accountability loops between engineering and finance. The platform team supports this by making cost data queryable and attributable — without that foundation, operational reviews are just gut-feel conversations.

The framework explicitly acknowledges that no team starts at "Operate." Most organizations are still in early Inform — discovering that they have no idea what anything costs by service. The platform team's most valuable first move is almost always making allocation possible, not jumping straight to optimization.

> [!tip] The FinOps Foundation publishes open maturity models and training at finops.org. The Certified FinOps Practitioner (FOCP) credential is the clearest signal that someone on the platform team has internalized the framework.

@feynman

The FinOps framework is like the scientific method applied to cloud spending — first you measure what's actually happening, then you form hypotheses about what to cut, then you build repeatable processes so the whole cycle keeps running on its own.

@card
id: plf-ch09-c003
order: 3
title: Showback vs Chargeback
teaser: Showback tells teams what they're spending without changing their bill; chargeback actually transfers costs — and the organizational maturity required for each is very different.

@explanation

**Showback** means showing each team or service its attributed cloud costs without moving money between budgets. The finance system still shows one cloud bill; the platform system shows each team its slice. There are no financial consequences — the intent is visibility and behavioral nudging.

**Chargeback** means actually transferring cost to team or product budgets. Each team's engineering budget is debited by their cloud consumption. Financial consequences are real.

When showback is appropriate:
- Early in cost visibility maturity, when tagging and allocation are not yet reliable enough to bill against
- In organizations where internal transfers create more bureaucracy than value
- When the goal is behavior change through information, not accountability through budget pressure

When chargeback is appropriate:
- When teams consistently ignore showback data because there's no consequence
- When the organization has mature cost allocation (complete tagging, reliable attribution)
- When product managers are expected to factor infrastructure costs into their P&L

The common failure is jumping to chargeback before showback is working. If your cost attribution is 40% accurate, charging against it creates resentment without driving real optimization. Get showback accurate first; chargeback is a policy decision made on top of a working allocation model.

Hybrid approaches exist — for example, charging back for clearly attributable resources (dedicated databases, allocated namespaces) while keeping shared infrastructure on showback until it can be fairly split.

> [!warning] Chargeback without accurate attribution punishes teams for costs they didn't incur. Fix the data model before introducing financial consequences.

@feynman

Showback is handing each person at the table an itemized bill so they can see what they ordered; chargeback is actually splitting the check and collecting money — the information is the same, but the stakes are completely different.

@card
id: plf-ch09-c004
order: 4
title: Tagging Strategy
teaser: Tags are the foundation of every cost allocation model — and without enforcement, tagging is just a suggestion that engineers ignore under deadline pressure.

@explanation

Cloud cost allocation depends entirely on tags. Without tags, a $200,000 monthly AWS bill is one number. With consistent tags, it becomes a breakdown by team, by service, by environment, by feature — and you can answer "which microservice costs the most to run?"

The minimal viable tagging trinity that most organizations converge on:

- **team** — the engineering team that owns the resource (e.g., `platform`, `payments`, `identity`)
- **service** — the specific application or component (e.g., `checkout-api`, `user-db`, `ml-pipeline`)
- **environment** — the deployment tier (e.g., `prod`, `staging`, `dev`)

Additional tags with high value: `cost-center` (for chargeback), `project` (for initiative-level attribution), `owner` (an email address for the resource's point of contact).

**Enforcement mechanisms:**
- **IaC validation** — Terraform modules and Helm charts on the platform require tag variables; missing values fail the plan stage.
- **AWS Service Control Policies (SCPs) / GCP Organization Policies** — deny resource creation if required tags are absent. This is enforcement at the cloud API level, bypassing any team-level workarounds.
- **AWS Config rules** — flag or remediate resources that lose tags after creation (possible through tag drift from console edits).
- **Admission webhooks (Kubernetes)** — reject pod or namespace creation if required labels are absent.

The tradeoff of strict enforcement: it creates friction for fast-moving teams and can slow incident response (no one wants to add a tag while a system is on fire). Common mitigations include a break-glass mechanism for emergencies and a grace period before enforcement activates for new resources.

> [!warning] Tags applied inconsistently are nearly as bad as no tags. Establish a canonical tag vocabulary — including exact key names and allowed values — before you start enforcing.

@feynman

A tagging strategy is like requiring every item in a warehouse to have a barcode with a standard format — without it, you can count the boxes, but you cannot tell who ordered what, where it's going, or what it costs per product line.

@card
id: plf-ch09-c005
order: 5
title: Cost Allocation per Service
teaser: Turning a shared platform bill into per-service numbers requires a model that handles both dedicated resources (easy) and shared resources (genuinely hard).

@explanation

Dedicated resources are straightforward to allocate: a Kubernetes namespace used by one team, a database with a clear owner tag, an EC2 instance in a tagged account. The tag on the resource maps directly to the cost.

Shared resources are where cost allocation gets difficult. An ingress controller, a logging pipeline, a service mesh, a CI system — these are consumed by every team and owned by the platform. Allocating them requires a model:

**Common allocation approaches for shared infrastructure:**

- **Equal split** — divide shared costs by the number of consuming teams. Simple, but ignores actual usage patterns. A team running five services pays the same as a team running fifty.
- **Usage-proportional** — allocate based on a proxy metric: number of requests, number of pods, GB of logs shipped, build minutes consumed. More accurate but requires instrumentation. Tools like OpenCost and Kubecost can attribute Kubernetes infrastructure costs down to the namespace level based on actual resource requests and limits.
- **Unallocated** — some organizations keep a "shared platform" cost bucket and don't attempt to split it further. This is honest about uncertainty but makes it hard for product teams to understand their true cost.

**AWS Cost Explorer**, **GCP Cost Management**, and **Azure Cost Management** all support tag-based views. For Kubernetes-specific allocation, Kubecost and OpenCost (its open-source variant) are the dominant tools — they calculate per-namespace, per-deployment, and per-pod cost estimates based on the underlying node costs and actual resource consumption.

The goal is not perfect accuracy; it's directionally correct numbers that change behavior. A team that learns their logging pipeline is generating $3,000/month in costs will investigate verbose log levels. That conversation doesn't happen without attribution.

> [!info] OpenCost is the CNCF-graduated open-source project that underpins many commercial cost tools. Running it in-cluster gives you per-workload cost visibility without a SaaS dependency.

@feynman

Allocating shared platform costs to services is like splitting a restaurant bill when some people shared appetizers — you can split evenly, split by what each person ate, or just leave the shared items as a group tab, and each approach has different accuracy and different arguments.

@card
id: plf-ch09-c006
order: 6
title: Unit Economics
teaser: Unit economics turn an abstract cloud bill into an operational metric — cost per request, cost per active user, cost per team — and it's the platform team that has the data to calculate them.

@explanation

A $500,000/month cloud bill is a number. $0.0003 per API request is an insight. Unit economics express infrastructure cost in terms of business value delivered, and they're the only way to answer questions like "is our efficiency improving?" and "can we afford to grow this product by 10x?"

Common unit cost metrics:

- **Cost per request** — total service compute cost divided by request volume. Requires both cost attribution and traffic telemetry. Useful for API services and microservices.
- **Cost per user** or **cost per active user** — total cost divided by MAU or DAU. Useful for consumer products where cost-per-user is a direct profitability input.
- **Cost per active team** (platform-specific) — total platform operating cost divided by the number of engineering teams using the platform. This is the platform team's internal unit economic — it answers "are we getting more efficient as we scale?"
- **Cost per build** — total CI/CD infrastructure cost divided by build count. Surfaces whether build infrastructure is right-sized.
- **Cost per GB processed** — relevant for data pipelines and analytics platforms.

The platform team's role:

1. Own cost attribution (so costs are accurate by service/team)
2. Provide or integrate with metrics APIs (so denominators — request counts, user counts — are available)
3. Compute and publish unit cost dashboards that blend both sources
4. Alert when unit costs trend in the wrong direction (a 20% increase in cost-per-request with flat traffic is a signal worth investigating)

The tradeoff: unit economics are only meaningful when both the numerator (cost) and denominator (usage) are measured consistently. Partial instrumentation produces misleading numbers that can drive wrong decisions.

> [!tip] Start with one unit cost metric and get it right before adding more. Cost per request for your highest-traffic service is usually the highest-value starting point.

@feynman

Unit economics for cloud costs is like calculating the cost per mile to run your car — instead of just knowing what you spend on gas each month, you know whether your efficiency is going up or down, and you can compare routes, vehicles, and driving styles on a fair basis.

@card
id: plf-ch09-c007
order: 7
title: Reserved Capacity and Savings Plans
teaser: Committing to usage upfront via reserved instances or savings plans can cut compute costs by 30–72% — but the platform team needs to decide who owns that commitment and how to handle unused capacity.

@explanation

Cloud providers sell discounted pricing in exchange for usage commitments. The savings are real and substantial, but the mechanism differs across providers:

**AWS:**
- **Reserved Instances (RIs)** — commit to a specific instance family, size, and region for 1 or 3 years. Savings of 30–60% vs on-demand. Can be Standard (fully locked) or Convertible (exchangeable for other instance types at a reduced discount).
- **Savings Plans** — more flexible. Compute Savings Plans apply to any EC2 instance, Lambda, or Fargate usage within a region or globally. EC2 Instance Savings Plans commit to a specific family but allow size/OS flexibility. Savings of 17–66%.

**GCP:** Committed Use Discounts (CUDs) cover vCPU and memory commitments. Sustained Use Discounts apply automatically without commitments.

**Azure:** Reserved VM Instances and Azure Savings Plans work similarly to AWS.

**Who should own the commitment — platform team or individual teams?**

The platform team is the right buyer in most organizations because:

- It has visibility across all teams' usage, enabling better commitment sizing
- Individual teams may not have authority to make multi-year financial commitments
- Unused capacity from one team can be reassigned to another (especially with Savings Plans)

The risk: if a team's usage drops significantly (a product is sunset, a migration happens), the platform team holds a commitment it can no longer absorb. Reserved Instance marketplaces allow selling unused RIs, but at a discount.

**Practical approach:** Run on-demand for the first 3–6 months after a workload stabilizes. Analyze actual usage patterns via AWS Cost Explorer's Reserved Instance recommendations or the Savings Plans recommendations tab. Buy coverage for the baseline load only — let variable/peak load run on-demand.

> [!warning] Buying reserved capacity for workloads that haven't stabilized is a common expensive mistake. Commit to baseline usage only after you have several months of steady-state data.

@feynman

Buying reserved cloud capacity is like signing a year-long gym membership instead of paying day rates — you save money if you show up consistently, but if your habits change or the gym closes, you've pre-paid for something you're not using.

@card
id: plf-ch09-c008
order: 8
title: Auto-Scaling Defaults
teaser: The platform-set auto-scaling defaults are one of the highest-leverage cost controls available — because they propagate instantly to every workload that inherits from the platform's base configuration.

@explanation

Auto-scaling prevents two categories of waste:

1. **Over-provisioning** — statically sized workloads that run at peak capacity around the clock, paying for headroom that's only needed during traffic spikes.
2. **Under-scaling** — workloads that fall over under load, requiring over-provisioning as a safety buffer.

The platform team's role is to set defaults that are right for the majority of workloads and make it easy for teams to override them for workloads that have different characteristics.

**Kubernetes-specific defaults the platform controls:**
- **Vertical Pod Autoscaler (VPA)** mode — the platform can run VPA in recommendation-only mode (surfacing right-sizing suggestions without enforcing them) or auto mode (adjusting requests and limits automatically).
- **Horizontal Pod Autoscaler (HPA)** targets — default CPU and memory utilization thresholds at which scale-out triggers. A default of 80% CPU utilization is more efficient than the common manually-set 50%.
- **Cluster Autoscaler / Karpenter** — the platform controls node provisioning policies. Karpenter (AWS) can be configured to prefer spot instances for non-critical workloads, consolidate underutilized nodes aggressively, and set maximum node counts per namespace or workload class.
- **Pod disruption budgets** — platform-set defaults that allow Karpenter or Cluster Autoscaler to drain nodes without breaking the workload, enabling aggressive consolidation.

**The consolidation trap:** overly conservative auto-scaling minimums (e.g., minimum replicas set to 3 for a service that handles 5 requests per day) multiply across hundreds of services. The platform should set a policy on what minimum replica count is appropriate by workload tier (production vs staging vs dev) and enforce it through admission webhooks or Helm chart defaults.

> [!info] Scale-to-zero for dev and staging environments is one of the highest-ROI platform features. A Kubernetes namespace that scales to zero outside business hours can reduce dev cluster costs by 60–70%.

@feynman

Auto-scaling defaults set by the platform are like a thermostat's schedule — every room follows the base schedule unless someone explicitly overrides it, so you get energy savings everywhere without having to change each room individually.

@card
id: plf-ch09-c009
order: 9
title: Right-Sizing Recommendations
teaser: Right-sizing tools — Kubecost, Cast.AI, AWS Compute Optimizer — identify resources that are chronically over-provisioned, but the platform team has to decide how to surface those recommendations in a way engineers will actually act on.

@explanation

Right-sizing is the practice of matching resource allocation to actual observed usage. A pod with a 2 vCPU request that consistently uses 0.3 vCPU is wasting capacity on every node it lands on. Multiply that across a cluster and the waste can be significant.

**Key tools:**

- **Kubecost** — cluster-deployed tool that attributes Kubernetes costs to namespaces, deployments, pods, and labels. Provides right-sizing recommendations based on actual request vs usage data. Integrates with AWS Cost Explorer and cloud billing APIs for full cost context. Has a free tier for single-cluster use.
- **OpenCost** — CNCF-graduated open-source alternative to Kubecost's core allocation functionality. No cost attribution to cloud billing; stays within the cluster metrics layer. Better for organizations that want to avoid vendor dependency.
- **Cast.AI** — SaaS platform focused on Kubernetes cost optimization. Provides right-sizing, bin-packing, and automated spot instance rebalancing. More opinionated than Kubecost; includes an automation mode that applies recommendations without human review.
- **AWS Compute Optimizer** — AWS-native service that analyzes EC2 instances, ECS tasks, Lambda functions, and EBS volumes. Uses CloudWatch metrics to recommend downsizing or instance family changes. Free to use; findings are available via console or API.
- **AWS Cost Explorer** — includes savings plan and RI recommendations built in. Not right-sizing in the Kubernetes sense, but covers EC2 and RDS over-provisioning with actionable recommendations.

**How the platform surfaces recommendations:**
- Weekly digest emails per team showing their top 5 right-sizing opportunities
- Annotations on Kubernetes deployments from VPA in recommendation mode (visible in `kubectl describe`)
- A cost optimization dashboard showing namespace-level efficiency scores
- Integration with the IDP's service catalog so recommendations appear next to the service's cost data

The tradeoff: automated enforcement of right-sizing (auto mode on VPA or Cast.AI automation) can cause unexpected pod restarts and OOMKill events if recommendations are wrong. Most platform teams start with recommendation-only mode and move to automation for non-production environments first.

> [!tip] Right-sizing recommendations are only as good as the observation window they're based on. A recommendation generated from one week of data will miss monthly or quarterly traffic patterns. Use at least 30 days of metrics before acting on any right-sizing suggestion.

@feynman

Right-sizing tools are like a fitness tracker that tells you you've been wearing shoes two sizes too big — the inefficiency was there all along, but you needed the measurement to see it and the recommendation to know what to change.

@card
id: plf-ch09-c010
order: 10
title: Idle Resource Detection
teaser: Idle and orphaned resources — abandoned dev databases, forgotten load balancers, unused reserved IPs — are a slow tax on your cloud bill that compounds invisibly until someone decides to look.

@explanation

Idle resources accumulate in every organization. A developer spins up an RDS instance to test a migration, finishes, and forgets to delete it. A load balancer outlives the service it was fronting by six months. A dev environment created for a feature branch never gets torn down when the branch merges. Individually small; at scale, they can represent 10–30% of total cloud spend.

**Categories of idle resources:**

- **Orphaned compute** — EC2 instances, pods, or containers with near-zero CPU/network utilization for sustained periods (common threshold: under 5% CPU for 7+ days)
- **Abandoned databases** — RDS instances or S3 buckets with no read/write activity for 30+ days
- **Unused load balancers** — ALBs or NLBs with zero traffic throughput
- **Unattached storage** — EBS volumes not attached to any instance; Persistent Volume Claims in a Released or Failed state
- **Idle dev environments** — developer namespaces, preview environments, or sandbox accounts that haven't seen activity in weeks

**The platform reaper pattern:**
The platform team runs an automated job (the "reaper") that:
1. Scans for idle resources matching defined criteria
2. Tags them with a TTL and sends a notification to the resource owner (via tag-based email lookup)
3. After a grace period (typically 48–72 hours with no response), destroys the resource or scales it to zero
4. Logs the action for audit trail

AWS Compute Optimizer identifies some idle resources. Tools like Cloud Custodian (open source, CNCF project) can implement policy-driven reaping across AWS, Azure, and GCP. Kubecost includes a cluster idle cost view. For dev environments specifically, the platform can enforce a maximum TTL on dev namespaces through admission webhooks and a CronJob-based cleanup process.

The organizational tradeoff: reaping resources without sufficient notice will create angry engineers who lose work. The grace period, notification quality, and opt-out mechanism (the team explicitly marks a resource as permanent) are as important as the detection logic.

> [!warning] Deleting a resource without a restore path is irreversible. Always require a snapshot or backup step before the reaper terminates databases or storage resources.

@feynman

Idle resource detection is like a library fine system for cloud resources — you can leave books checked out as long as you're using them, but if you haven't touched them in weeks, you get a notice, and if you ignore the notice long enough, the library reclaims them.

@card
id: plf-ch09-c011
order: 11
title: The Platform Team as Cost Reviewer
teaser: When the platform team gates expensive infrastructure requests through a review process, it can catch cost problems before they're deployed — but the SLA on that review determines whether engineers see it as a guardrail or a blocker.

@explanation

Some infrastructure requests carry disproportionate cost: a team asking for a large ElasticSearch cluster, a request for a multi-region database with synchronous replication, a request for dedicated GPU nodes for workloads that haven't justified the need. Left unreviewed, these decisions land in the bill six weeks later with no context.

**What a platform cost review covers:**

- Estimated monthly cost of the requested resource (the platform team runs the numbers, not the requesting team)
- Whether a lower-cost alternative meets the stated requirements (e.g., managed OpenSearch vs self-managed ElasticSearch; a read replica vs a second write cluster)
- Whether the resource is sized correctly for the stated load
- Whether reserved pricing applies and who will purchase it
- What the expected growth curve looks like and whether the initial size should be smaller

**SLA is critical.** If cost review takes five business days, engineers will route around it — provisioning manually outside the IDP, using an existing resource beyond its intended scope, or escalating to a manager to bypass the process. A same-day or next-business-day SLA makes the review a reasonable part of the workflow rather than a bureaucratic obstacle.

**What makes the review lightweight:**
- A standard request form in the IDP that collects the information the reviewer needs upfront (expected load, growth curve, alternatives considered)
- A runbook with pre-approved patterns that bypass review (e.g., "any PostgreSQL instance under db.r6g.xlarge for a new service goes straight through")
- A clear owner on the platform team who is responsible for reviews with an explicit SLA commitment

> [!info] Cost review gates work best when they also serve as an architectural checkpoint. Catching a wrong database choice is more valuable than catching an expensive one.

@feynman

The platform team as cost reviewer is like a building inspector — you do not need approval for every nail, but anything load-bearing gets a sign-off before it goes into the wall, and the value is in catching the wrong structural choices before they are impossible to undo.

@card
id: plf-ch09-c012
order: 12
title: Cost Dashboards as Developer Feedback
teaser: A cost estimate shown to a developer at scaffolding time — "this service template will cost approximately $X per month" — is more effective than any retrospective review, because it changes the decision before the resource exists.

@explanation

The most effective cost control is information delivered at the moment of decision. A developer choosing between two database configurations will weigh cost if cost is visible; they will ignore it if it is not.

**Where cost feedback belongs in the developer workflow:**

- **Scaffolding / IDP service creation** — when a developer creates a new service through the internal developer platform, the template selection screen shows an estimated monthly cost for each template tier. A "lightweight" template (1 replica, shared ingress, no dedicated DB) vs a "production-grade" template ($300/month estimate) prompts a real decision.
- **Pre-deploy cost estimation** — tools like Infracost (Terraform), cost-aware admission webhooks (Kubernetes), or custom IDP integrations can show a "this change will add $X/month" prompt before a pull request is merged or a deployment is applied.
- **Per-service cost dashboards** — embedded in the IDP's service catalog, showing each service owner their attributed cost trend over the last 30/90 days alongside traffic volume. The goal is making cost visible in the same place developers check deployment status.
- **Cost anomaly alerts to service owners** — when a service's cost jumps more than a threshold (e.g., 20% week over week) relative to its traffic, an alert goes to the team's Slack channel, not just a finance inbox.

**Infracost** is the most widely used open-source tool for pre-deploy cost estimation on Terraform. It integrates with GitHub Actions, GitLab CI, and Atlantis to post cost diffs on pull requests. AWS also provides the **AWS Pricing Calculator** API for programmatic cost estimation.

The tradeoff: cost estimates at scaffolding time are approximations. Showing a developer "$240/month" when the actual cost lands at $380/month erodes trust. Communicate clearly that these are estimates with stated assumptions, and update the models regularly.

> [!tip] The scaffolding-time cost estimate does not need to be precise to be valuable. Even a wide range ("this template typically costs $100–$400/month depending on traffic") changes behavior by making developers aware that infrastructure has a cost before they've committed to a design.

@feynman

Showing a developer their infrastructure cost at scaffolding time is like displaying the calorie count on a menu — you do not have to forbid anything, but knowing the number before you order changes what people choose.
