@chapter
id: eds-ch04-choosing-the-stack
order: 4
title: Choosing the Stack
summary: How to pick technologies for each lifecycle stage without getting captured by hype, vendor pitches, or internal politics.

@card
id: eds-ch04-c001
order: 1
title: Tools Are Easier Than Decisions
teaser: Picking tools is the part of the job everyone wants to talk about. The harder work is figuring out what you actually need before you start shopping.

@explanation

The most expensive technology choices aren't bad tools — they're tools picked before the team understood what problem it was solving. The hierarchy of decisions:

1. **What problem are we solving?** — Specific user, specific pain, specific cost of doing nothing.
2. **What capability do we need?** — Translated from problem to category (orchestrator, ingestion, warehouse).
3. **What constraints bound us?** — Team size, existing stack, compliance, budget.
4. **What candidates fit?** — Now you can shortlist.
5. **Which one?** — Picking among well-fit candidates is the easy step.

Most teams skip the first three and start at four. The result is technically excellent tools that no one ends up using.

> [!warning] The strongest signal that a team is doing this wrong: they can describe the tool they want before they can describe the problem. Listen for it in planning meetings.

@feynman

Same trap as picking a framework before knowing what app you're building. Looks productive; rarely is.

@card
id: eds-ch04-c002
order: 2
title: Build Versus Buy Versus Adopt
teaser: Three options for any capability. Most teams default to buy without considering the others; the best teams pick deliberately for each piece of the stack.

@explanation

Three options when you need a capability:

- **Build** — write it yourself. Full control, full ownership, full operational burden.
- **Buy** — pay a vendor. Faster to value, less control, ongoing cost, lock-in.
- **Adopt** (open source) — use someone else's free code. Often free at the license, expensive at the operational cost; you become responsible for running it.

The right choice depends on:

- **Strategic differentiation** — if it's core to your competitive advantage, lean toward build. If it's commodity, lean toward buy.
- **Team capacity** — if you don't have the team to operate or build, buy. Vendor SLAs are cheaper than burnout.
- **Switching cost** — if changing later is expensive (warehouses, ML platforms), evaluate harder upfront.
- **Total cost of ownership** — buy looks expensive in dollars; build often is more expensive in time.

A common pattern: buy for commodity infrastructure (warehouse, ingestion), adopt for the orchestration layer (Airflow, dbt), build only for the pieces that are unique to your business.

> [!info] "We can build it cheaper than the vendor charges" is almost never true once you account for staff time, opportunity cost, and ongoing operational burden. Math the actual TCO before deciding.

@feynman

Same as restaurant vs cooking at home — the meal is rarely the expensive part; your time is.

@card
id: eds-ch04-c003
order: 3
title: Open Source Isn't Free
teaser: Open source software has a license cost of zero and an operational cost of a real engineer. Forgetting the second number is the most common open-source mistake.

@explanation

Open source brings real wins: no license, source code transparency, community improvements, no vendor lock-in. It also brings real costs:

- **Operational burden** — running, monitoring, patching, scaling. The vendor's job becomes yours.
- **Integration work** — gluing the open-source piece into your stack, building auth, observability, deployment.
- **Skill cost** — you need engineers fluent in the tool to get value; many open-source data tools have steep learning curves.
- **Compliance work** — security reviews, audit trails, retention policies that vendors often handle for you.

A useful rule of thumb: pick open source when you have at least one engineer who knows the tool deeply, or when the alternative vendor is genuinely unaffordable. Otherwise the time-to-value gap is real.

The sweet spot for many teams is **managed open source** — pay a vendor (Databricks for Spark, Astronomer for Airflow, Confluent for Kafka) to run the open-source tool you'd otherwise self-host. You get the openness and the operational ease.

> [!tip] When evaluating open source, ask: "if the original maintainer disappears tomorrow, can we still operate this?" If the answer is "barely," budget for the worst case.

@feynman

Same as adopting a Linux distro vs paying for managed cloud Linux — the OS is free, the running of it isn't.

@card
id: eds-ch04-c004
order: 4
title: Server, Container, Serverless — Compute Models For Pipelines
teaser: Three deployment models with different operational and cost profiles. Picking the wrong one for the wrong stage is one of the easier mistakes to make.

@explanation

**Server (VM-based).** Long-running compute. You provision instances, install software, manage scaling. Cheapest at sustained high utilization; most expensive in operational time. Examples: EC2, GCE, on-prem.

**Container (orchestrated).** Compute packaged as containers, scheduled on Kubernetes or similar. Better resource utilization than VMs, more operational complexity. Good for stateless pipelines that run continuously or on demand.

**Serverless.** Fully managed compute. AWS Lambda, GCP Cloud Functions, etc. Pay per invocation, no infrastructure to manage. Cheap for spiky workloads, expensive at high sustained throughput, has cold-start and runtime-limit constraints.

Mapping to lifecycle stages:

- **Ingestion connectors** — often serverless or containerized; bursty, idempotent, easy to operate.
- **Transformation jobs** — often containers (for Spark) or warehouse-native compute.
- **Orchestrator** — container or VM; needs to be running constantly.
- **Real-time stream processing** — containers or VMs; serverless usually doesn't fit.

The mistake to avoid: forcing one compute model across the whole stack because it's "simpler." The cost and operational profile usually argues for a mix.

> [!info] Serverless is the easiest to get started, often the most expensive once usage scales. Build with awareness of the inflection point where you'd want to migrate.

@feynman

Same trade-off as renting vs owning vs Uber — different sweet spots for different usage patterns.

@card
id: eds-ch04-c005
order: 5
title: Monolithic Versus Modular Tooling
teaser: Some teams pick one platform that does everything. Others assemble best-of-breed point solutions. Each has a sustainable end state and a painful intermediate one.

@explanation

**Monolithic platforms** (Databricks, Snowflake's expanding suite, Microsoft Fabric) cover many lifecycle stages in one product. Pros: integration is implicit, vendor relationship is singular, billing is one line item. Cons: lock-in is deep, the product's weakest stage drags the rest, you pay platform pricing for commodity capabilities.

**Modular stacks** assemble point solutions: Snowflake for warehouse, Fivetran for ingestion, dbt for transformation, Airflow for orchestration, Hightouch for reverse ETL. Pros: best tool per stage, easy to swap any one piece. Cons: integration is your problem, vendor-management overhead is real, costs add up.

The tension lives along a few axes:

- **Team size** — small teams benefit more from monoliths (less vendor management); large teams can afford modular complexity.
- **Maturity stage** — early-stage teams ship faster on monoliths; mature teams often outgrow them.
- **Differentiation needs** — if your data work is commodity, monolith is fine; if you have unique needs, modular gives you the freedom.

A common pattern: start monolithic, migrate stage-by-stage to modular as the team grows and specific stages outgrow the platform's strength.

> [!warning] The intermediate state — partway between monolith and modular — is the most expensive. Plan to commit to one philosophy or the other; flapping between them costs more than either pure approach.

@feynman

Same trade-off as iPhone vs Android + custom ROM — monoliths trade flexibility for cohesion.

@card
id: eds-ch04-c006
order: 6
title: Cloud Versus On-Prem Versus Hybrid
teaser: The cloud isn't the only option, even in 2026. Picking deliberately requires understanding what each model gives up.

@explanation

**Cloud (AWS, GCP, Azure).** The default for new data teams since ~2015. Wins: elastic capacity, managed services, fast provisioning. Losses: ongoing OpEx, network egress costs, vendor concentration risk.

**On-premise.** Owned infrastructure in your own data center or colo. Wins: predictable cost at sustained high utilization, full control, often lower cost at multi-PB scale. Losses: capacity is bounded by what you bought, operational burden is yours, slower to evolve.

**Hybrid.** Some workloads on-prem, some in cloud. Wins: optimize for each workload. Losses: integration complexity, two operational models to maintain, network costs to bridge them.

**Multi-cloud.** Workloads spread across clouds, often for resilience or vendor leverage. Wins: avoid lock-in, sometimes regional pricing wins. Losses: substantially more complex; often more expensive than single-cloud once tooling and skills compound.

The honest pattern: most teams don't choose multi-cloud — they end up there because of acquisitions or politically driven decisions. Pure single-cloud is operationally simpler. On-prem still makes sense at very large scale or for regulatory reasons.

> [!info] "Multi-cloud for resilience" usually means "two suboptimal stacks instead of one well-tuned one." Resilience within a cloud (multi-region, multi-AZ) is almost always cheaper.

@feynman

Same trade-off as renting vs buying a house — flexibility vs predictable cost. Different right answers for different life stages.

@card
id: eds-ch04-c007
order: 7
title: The Total Cost Of Ownership Lens
teaser: Every technology choice has a sticker price and a real price. The gap is often 10× or more. Always evaluate the real price.

@explanation

Sticker price is what the vendor charges or what the open-source license says (zero). TCO includes everything else:

- **Implementation cost** — engineer-weeks to integrate the tool into your stack.
- **Operational cost** — ongoing monitoring, alerting, patching, on-call.
- **Migration cost** — if you ever need to leave, what does that cost?
- **Skill cost** — hiring or training engineers fluent in the tool.
- **Opportunity cost** — what else could those engineers be doing?
- **Failure cost** — what's the cost when this tool breaks? (Outage minutes × revenue impact.)

A worked example. Two transformation tools, both useful:

- Tool A: $50K/year, fully managed, your team learns it in a week.
- Tool B: free open-source, requires ~30% of an engineer to operate, your team learns it in a month.

If your engineer costs $300K/year fully loaded, Tool B's "free" actually costs $90K/year in operational time alone — before training, integration, or failure costs. Tool A is cheaper.

> [!tip] When the math points to "this open-source thing costs more than the managed alternative," your team is going to feel like they're losing if you switch. Show the math; the choice gets easier.

@feynman

Same as evaluating a job offer in salary alone — ignores the half of the picture that matters most over time.

@card
id: eds-ch04-c008
order: 8
title: Future-Proofing Without Over-Engineering
teaser: Building for a future you might never reach is wasted work. Building only for today guarantees a painful rebuild in two years. The middle path is preserving optionality.

@explanation

Two failure modes pull on architectural choices:

- **Over-engineering** — building for a scale you don't have, supporting requirements you don't have, with complexity you can't justify. Slows delivery, hides bugs, alienates the team.
- **Under-engineering** — building only for current needs, with no slack for growth. Fast initially, expensive when you outgrow it.

The middle: **preserve optionality**. Make decisions that don't preclude future choices, without paying for the future today.

Concrete examples:

- **Use open formats** (Parquet, Iceberg) for raw data. You're not paying to write Parquet; you keep the option to switch query engines.
- **Externalize transformation logic** in dbt or SQL files instead of warehouse stored procedures. Same logic; portable.
- **Decouple orchestration from execution.** Orchestrator triggers jobs; jobs run on whatever compute you choose; you can swap either.
- **Document important assumptions.** When the future-you needs to revisit a choice, the rationale isn't lost.

What this isn't: pre-building features you don't need yet, abstracting "in case." Optionality is about reducing future cost, not adding present cost.

> [!info] If a current decision would cost an extra week to make portable, it's usually worth it. If it would cost an extra quarter, you're over-engineering.

@feynman

Same as designing software for testability — small upfront effort, large downstream payoff, and you don't have to commit to specific tests today.

@card
id: eds-ch04-c009
order: 9
title: Pragmatic Vendor Evaluation
teaser: Most vendor evaluations are theater. A good one takes a few weeks, costs real engineering time, and produces a decision the team can defend.

@explanation

A pragmatic evaluation has a few non-skippable parts:

1. **Define the decision criteria up front.** What "good" means in this category — capabilities, cost, operational burden, team fit. Weight them. Don't change them mid-evaluation.
2. **Shortlist 2-4 candidates.** More is theater; fewer is sample of one. Industry analysts (Gartner, Forrester) help identify candidates, not pick winners.
3. **Run a real proof-of-concept.** A representative pipeline, real data shape, real volume. Not the vendor's demo; not their ideal scenario.
4. **Evaluate the experience, not the marketing.** How easy is it to debug? What's the support like? What's the upgrade path? Talk to existing customers, not just references the vendor handed you.
5. **Stress-test the costs.** Vendors price for the demo; production costs are often 3-10× higher. Forecast realistic usage and back into the bill.
6. **Decide and document.** Write down what you chose and why. The next architect deserves to know.

The biggest waste: 6-month "evaluations" that produce paralysis. Set a timebox.

> [!warning] Vendor pitches are calibrated to your enthusiasm, not your reality. Bring an engineer with healthy skepticism to every demo.

@feynman

Same hygiene as hiring — define the role, shortlist, do a real working session, decide. Skip steps and you regret it.

@card
id: eds-ch04-c010
order: 10
title: When Tools Are Decided For You
teaser: Half of your stack's decisions are inherited, mandated, or already done. Working productively within those constraints is half the job.

@explanation

You'll rarely arrive at a clean greenfield. The reality:

- **Pre-existing tools.** Your team uses Airflow because three years of pipelines are already built on it.
- **Mandated platforms.** Compliance, IT, or executive direction requires Snowflake, AWS, or Databricks.
- **Skill-driven constraints.** Your team knows Python; rebuilding in Scala isn't realistic.
- **Budget gates.** The Tier-1 vendor is in budget; the Tier-2 isn't.

Working with these constraints rather than against them:

- **Document what's locked.** Make the constraints explicit; don't waste cycles re-litigating them.
- **Find the seams.** Even within a fixed warehouse, there's room to choose modeling philosophy, transformation tool, orchestration approach.
- **Pick battles.** Some constraints are worth challenging (an obviously wrong vendor mandate); most aren't.
- **Build well within the constraints.** A great pipeline on a mediocre tool beats a mediocre pipeline on the perfect tool.

The architects who get the most done are the ones who treat constraints as facts of physics, not personal slights.

> [!info] Frequent battles over already-decided tools are a symptom: the team isn't focused on what's actually open. Reframe the conversation toward what's still up for design.

@feynman

Same as software constraints — language, framework, deployment platform are usually fixed. The interesting work is what you do within them.

@card
id: eds-ch04-c011
order: 11
title: A Working Default Stack
teaser: When you're starting fresh and need defaults, a working modern data stack looks roughly like this. Useful as a baseline to deviate from intentionally.

@explanation

A reasonable default stack for a small-to-mid team starting in 2026:

- **Storage / warehouse** — Snowflake or BigQuery (managed, mature, large talent pool).
- **Lake / object store** — S3 or GCS for raw landing and ML training data.
- **Open table format** (if going lakehouse) — Iceberg or Delta.
- **Ingestion** — Fivetran or Airbyte for SaaS sources; Debezium for CDC; custom Python for unusual ones.
- **Transformation** — dbt for SQL transformations in the warehouse.
- **Orchestration** — Airflow (mature) or Dagster (data-aware) or Prefect.
- **BI** — Looker, Mode, or Hex; Metabase if you need open source.
- **Reverse ETL** — Hightouch or Census.
- **Catalog / observability** — dbt's docs as a starting point; Monte Carlo or similar when scale justifies.
- **Streaming** (if needed) — Kafka or Kinesis; Flink for stream processing.

This isn't *the* answer — it's a starting point that gets a team to first value within a quarter. Deviate where you have specific needs (highly-regulated industries, real-time-first products, very large scale).

> [!tip] If your stack diverges from this default in five places, you have either very unusual needs or a lot of accidental complexity. Worth knowing which.

@feynman

Same as Rails-default vs custom-everything — the default isn't optimal, it's the baseline that gets you shipping. Deviate when you have a reason.
