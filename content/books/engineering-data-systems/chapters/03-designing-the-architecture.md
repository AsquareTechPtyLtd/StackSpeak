@chapter
id: eds-ch03-designing-the-architecture
order: 3
title: Designing the Architecture
summary: Principles, patterns, and trade-offs that turn a collection of pipelines into a coherent system other people can build on.

@card
id: eds-ch03-c001
order: 1
title: Architecture Is The Decisions Hard To Reverse
teaser: A pipeline can be rewritten in a sprint. The shape of your storage layers, the boundaries between systems, the technology of your warehouse — those are the decisions that calcify and shape every choice that follows.

@explanation

Data architecture is the set of decisions whose blast radius extends far beyond a single pipeline. The reversibility test is the cleanest filter for what counts:

- Can you change it without coordinating across teams? Probably implementation, not architecture.
- Can you change it without rewriting at scale? Probably implementation.
- Does changing it cascade into ten other systems? Architecture.

What lands in the architectural bucket:

- **Storage shape** — warehouse, lake, lakehouse, hybrid; columnar vs row; partition strategy.
- **Boundaries** — what's in the warehouse, what's in operational systems, what's a separate service.
- **Integration style** — batch, streaming, change-data-capture, polling.
- **Vendor selection** — picking a warehouse vendor is harder to undo than picking a transformation tool.
- **Cloud topology** — which clouds, which regions, what crosses boundaries.

The architect's discipline is making these decisions deliberately, with the trade-offs documented, rather than letting them accrete from whichever pipeline happened to ship first.

> [!info] If your team can describe its data architecture on one whiteboard with the major stages and tools labeled, you have an architecture. If it takes a half-hour storytelling session to explain, you have an accumulation.

@feynman

Same as building a house — you can rearrange the furniture forever, but moving a load-bearing wall is a project.

@card
id: eds-ch03-c002
order: 2
title: Principles Of Good Data Architecture
teaser: Six principles that distinguish architectures that age well from architectures that age into legacy. None novel; all routinely violated under deadline pressure.

@explanation

The principles compound. Skip them and you ship faster initially; pay interest forever.

1. **Choose common components wisely** — pick storage, orchestration, and the warehouse with care; everything else is downstream.
2. **Plan for failure** — every component will fail; design for graceful degradation, not heroic uptime.
3. **Architect for scalability** — both up (more data) and out (more pipelines, more teams).
4. **Architect is leadership** — the architect's job is to build consensus across teams, not just draw diagrams.
5. **Always be architecting** — architecture is continuous, not a one-time event before the build phase.
6. **Build loosely coupled systems** — independent deployments, independent scaling, independent ownership.
7. **Make reversible decisions** — when you can defer a hard-to-reverse choice, do; preserve optionality.
8. **Prioritize security** — bake it in from day one, not as a phase-2 concern.
9. **Embrace FinOps** — cost is a first-class architectural concern in the cloud era.

The principle that gets the least attention and pays the most: loose coupling. Tightly coupled data systems become impossible to change. Loose coupling lets each piece evolve at its own pace.

> [!warning] Beware architectures that look elegant on paper but require every team to coordinate every release. Elegance shouldn't cost you your delivery cadence.

@feynman

Same lessons as software architecture — the wins compound, the failures crystallize, and the rules read like obvious advice you'll still violate next quarter.

@card
id: eds-ch03-c003
order: 3
title: Architect For Failure, Not For Perfection
teaser: Components fail. Networks partition. Vendors have outages. Build assuming all of that is inevitable, and your pipelines degrade gracefully instead of cascading.

@explanation

Three concrete failure modes data systems hit constantly:

- **Source outages** — the upstream database is down; your ingestion can't read.
- **Compute failures** — a Spark job dies mid-run; an orchestrator hangs; a Kubernetes pod crashes.
- **Vendor outages** — the warehouse is degraded; the message bus is reachable but slow.

Designing for failure means specific practices:

- **Idempotency everywhere** — running a pipeline twice with the same input produces the same output. Then retries are safe.
- **Replayability** — pipelines can be re-run for any historical window. Then bugs become recoverable.
- **Bounded retries with backoff** — failed steps retry on a backoff curve, then alert when they exhaust.
- **Circuit breakers** — when a downstream is unhealthy, stop hammering it.
- **Backpressure** — when downstream can't keep up, slow down ingestion rather than dropping data.
- **Graceful degradation** — partial pipeline output is better than no output, when correct.

The teams that get paged least aren't the teams with the strongest infrastructure — they're the teams whose pipelines fail correctly.

> [!tip] When designing a new pipeline, write the runbook before the code. "What happens when X fails" forces you to design for failure from the start.

@feynman

Same as designing a distributed system — assume the network, the disk, and the upstream all fail eventually. They will.

@card
id: eds-ch03-c004
order: 4
title: Scalability Is Two Different Problems
teaser: Scaling for more data and scaling for more teams are different challenges. Architectures often handle one well and the other poorly.

@explanation

**Vertical scalability — bigger data.** Your warehouse grows from 10TB to 1PB. Your daily ingestion goes from millions of rows to billions. Your transformation jobs take longer or need more compute.

This is the easier problem. Modern cloud-native data infra handles it well: warehouses autoscale, lakes have effectively infinite capacity, distributed compute frameworks (Spark, Flink) handle larger workloads with more nodes.

**Horizontal scalability — more teams.** You go from 5 data consumers to 500. Many more pipelines, more dashboards, more requests, more dependencies between datasets.

This is the harder problem. It's an organizational problem masquerading as a technical one. Solutions:

- **Self-serve infrastructure** — make it easy for teams to ship pipelines without going through a central team.
- **Clear ownership** — every dataset has a known owner; every pipeline has a known on-call.
- **Discoverability** — catalogs, search, lineage, so consumers can find what exists without asking.
- **Consistent patterns** — paved roads for common shapes (CDC, daily aggregations, ML feature pipelines).

The data mesh movement is largely about making horizontal scale work — by treating datasets as products and pushing ownership to the teams that produce them.

> [!info] If your team is hitting scale issues that a bigger warehouse won't fix, you have a horizontal scale problem. Throwing more compute at it is a category error.

@feynman

Same as monolith → microservices — solves a coordination problem, not a performance problem.

@card
id: eds-ch03-c005
order: 5
title: Loose Coupling Beats Premature Coupling
teaser: When two systems are tightly coupled, they share a release schedule whether you want them to or not. Loose coupling lets each piece move at its own pace.

@explanation

Coupling shows up in data architectures in several forms:

- **Schema coupling** — when an ingestion pipeline assumes specific columns exist with specific types, every source schema change breaks it.
- **Tool coupling** — when transformation logic lives inside an ingestion tool's UI, you can't swap the tool without rewriting all the logic.
- **Pipeline coupling** — when one pipeline reads directly from another's intermediate output, you can't change either without coordinating both.
- **Vendor coupling** — when your transformation language only runs on one warehouse, switching vendors becomes a rewrite.

Loose coupling alternatives:

- **Schemas with contracts** — explicit, versioned interfaces between producers and consumers.
- **Open formats** — Parquet/Iceberg over warehouse-proprietary tables when portability matters.
- **Materialized intermediate datasets** — pipelines depend on stable datasets, not on each other's runs.
- **Tool-portable logic** — SQL or dbt over warehouse UIs.

The principle: prefer dependencies on stable, well-defined interfaces over dependencies on internal implementation.

> [!warning] Tight coupling is fastest to build initially. The bill comes later — usually right when you need to change something fundamental.

@feynman

Same as microservice boundaries — the seam between two services is more important than what's inside either of them.

@card
id: eds-ch03-c006
order: 6
title: Data Lake, Data Warehouse, Data Lakehouse
teaser: Three storage paradigms with overlapping use cases and very different cost-and-flexibility tradeoffs. Picking the right one — or knowing why you're using both — shapes every other architectural choice.

@explanation

**Data warehouse.** Schema-on-write. Columnar storage tuned for analytical SQL. Strong consistency, ACID transactions, often expensive compute. Examples: Snowflake, BigQuery, Redshift, Synapse. Best for: well-modeled analytics with predictable query patterns and many concurrent users.

**Data lake.** Schema-on-read. Object storage (S3, GCS, ADLS) holds raw files in any format. Cheap storage, flexible compute, weak consistency without extra layers. Best for: massive raw landing zones, ML training data, unstructured or semi-structured content.

**Data lakehouse.** Lake-style storage with warehouse-style transactional semantics on top. Open table formats (Delta, Iceberg, Hudi) provide ACID, schema evolution, and time travel directly on object-store files. Best for: teams that want both the cheap storage of a lake and the queryability of a warehouse without paying for two systems.

In practice most modern stacks blend two or three. Raw lands in a lake. Curated tables sit in a lakehouse format. The warehouse holds high-concurrency analytics models. The line between them keeps blurring as warehouse vendors add lake features and lake vendors add warehouse features.

> [!info] If you only have a warehouse, you eventually grow a lake to handle data that doesn't fit. If you only have a lake, you eventually grow warehouse-style serving for analytics. Picking the lakehouse path early can save you the second migration.

@feynman

Like SQL vs NoSQL vs NewSQL — three answers to overlapping questions, each with its own gravity.

@card
id: eds-ch03-c007
order: 7
title: Lambda And Kappa Architectures
teaser: Two patterns for combining batch and streaming. Lambda runs both in parallel; Kappa unifies on streaming alone. Most modern stacks pick a side, then live with the consequences.

@explanation

**Lambda architecture.** Two pipelines run in parallel: a batch layer that processes large historical data correctly, and a speed layer that processes recent events with lower latency. A serving layer merges results.

Pros: each layer is optimized for what it's good at; batch handles correctness, streaming handles freshness.
Cons: you maintain two implementations of the same logic, and they will drift.

**Kappa architecture.** One pipeline, streaming-only. Batch is treated as a replay of historical events through the same stream-processing logic.

Pros: single codebase, unified operational story, easier to reason about.
Cons: streaming is genuinely harder to build correctly; you need a system that can handle both real-time and high-throughput replay.

Modern stacks often blur the line: streaming-first with materialized views computed at rest. Tools like Flink, Beam, and Materialize make this practical. The decision often comes down to your team's comfort with stream processing — Kappa is elegant on paper and harder in production.

> [!tip] If most of your serving needs daily-fresh data, Lambda's complexity often isn't worth it. If you need second-fresh data with full historical replay, Kappa pays for itself.

@feynman

Same tradeoff as full-stack TypeScript vs polyglot stacks — one runtime is simpler operationally, multiple specialized stacks each do their job better.

@card
id: eds-ch03-c008
order: 8
title: The Modern Data Stack
teaser: A loose category name for the cloud-native, SaaS-heavy, ELT-flavored architecture that has become the default for new data teams since around 2018.

@explanation

The "modern data stack" is less a specific architecture and more a stylistic cluster. Typical components:

- **Cloud warehouse** — Snowflake, BigQuery, Redshift, Databricks SQL.
- **Managed ingestion** — Fivetran, Airbyte, Meltano for source-to-warehouse pipelines.
- **In-warehouse transformation** — dbt for SQL-based transformations after data lands.
- **Reverse ETL** — Hightouch, Census for warehouse-to-operational-system flows.
- **BI** — Looker, Mode, Hex, Metabase, or similar.
- **Orchestration** — Airflow, Prefect, Dagster, or the warehouse vendor's offering.
- **Catalog and observability** — Monte Carlo, Bigeye, dbt's own docs.

What ties them together is a philosophy:

- **ELT over ETL** — land raw, transform in the warehouse where compute is cheap.
- **SaaS over self-hosted** — pay vendors for operational burden where it makes sense.
- **SQL-first** — transformation logic is SQL, version-controlled, tested.
- **Modular** — each tool does one thing well; integration via standard interfaces.

The trade-off: vendor lock-in is real, costs scale with usage, and the integration tax across many SaaS tools adds up. But the time-to-first-value is unbeatable.

> [!info] "Modern data stack" is starting to feel less novel as adoption matures. The next wave (data mesh, lakehouse-first, operational analytics) is building on its lessons rather than replacing it wholesale.

@feynman

Same arc as JAMstack for web — a cluster of opinionated SaaS choices that won the default position by being faster to start than alternatives.

@card
id: eds-ch03-c009
order: 9
title: Data Mesh As Architectural And Organizational Pattern
teaser: Treating datasets as products owned by domain teams instead of a central data team. Half technical architecture, half organizational redesign.

@explanation

Data mesh, articulated by Zhamak Dehghani, is a response to the bottleneck of central data teams trying to serve every domain. Its four principles:

1. **Domain ownership** — each business domain (sales, marketing, finance) owns its data products end-to-end.
2. **Data as a product** — datasets are treated as first-class products, with APIs, SLAs, owners, support.
3. **Self-serve data platform** — central infrastructure makes it easy for domain teams to ship and operate data products.
4. **Federated computational governance** — shared standards (security, schema conventions, quality bars) enforced across domains.

The hard part is organizational. Data mesh requires domain teams to own data the way they own services — staffing, on-call, roadmap. Many companies adopt the technical pieces without the organizational shift and end up with the same central bottleneck wearing a new hat.

> [!warning] Data mesh isn't a cure for an under-resourced central data team. It's a different model that requires investment across multiple teams to work.

@feynman

Same arc as monolith → microservices — works only if you're willing to staff and own each service properly.

@card
id: eds-ch03-c010
order: 10
title: Costs Are Architectural
teaser: In on-prem days, hardware was a sunk cost. In the cloud, every architectural choice has a recurring monthly bill attached.

@explanation

Cloud data infra makes cost a moving target tied to usage. Three categories:

- **Storage cost** — usually low per TB, but compounding over time. Retention policy matters.
- **Compute cost** — query cost in the warehouse, processing cost in the lake, often the largest line item.
- **Egress cost** — bandwidth out of the cloud, especially across regions and clouds. Easy to under-budget.

Architectural choices that affect each:

- **Storage tiering** — hot/warm/cold tiers for object storage cut costs by 5-10× for older data.
- **Compute right-sizing** — picking warehouse warehouse sizes appropriately, killing idle clusters.
- **Query patterns** — partitioning and clustering let queries skip data; full scans destroy budgets.
- **Cross-region/cross-cloud** — minimize traffic that crosses these boundaries; the bills compound silently.
- **Reserved capacity vs on-demand** — committed spend often gets 30-50% discounts.

FinOps has emerged as a discipline because most cloud data spend is silently architectural. Tagging, attribution, and showback to teams is the only way to drive cost-aware decisions.

> [!tip] Build cost dashboards before you have a cost problem. Once the bill is six figures, you have to do forensics; before, you can shape behavior.

@feynman

Like database indexes — small architectural decisions, large bill consequences. Worth thinking about up front.

@card
id: eds-ch03-c011
order: 11
title: Two-Way Door And One-Way Door Decisions
teaser: Some architectural decisions are easy to reverse if you're wrong. Some aren't. Knowing the difference shapes how much rigor each deserves.

@explanation

Borrowed from Amazon's decision-making framework:

- **Two-way door** — easily reversible. Try it, see what happens, change if it doesn't work. Move fast on these.
- **One-way door** — hard to reverse. Once you walk through, going back is expensive. Move carefully.

In data architecture:

**Two-way doors.**
- Trying a new BI tool alongside the existing one.
- Adding a new transformation library.
- Adopting a new dbt convention.
- Switching to a different orchestration vendor (painful but bounded).

**One-way doors.**
- Picking a primary warehouse vendor — multi-year migration to switch.
- Choosing a cloud (or worse, multi-cloud) — defines security model, networking, talent pool.
- Adopting a particular data modeling philosophy across the org.
- Building heavy custom logic into proprietary services.

Many teams treat all decisions with equal weight, which slows two-way doors unnecessarily and rushes one-way doors fatally. The architect's contribution is calibrating which is which and adjusting rigor accordingly.

> [!info] When facing a one-way door, an extra month of evaluation is cheap insurance. When facing a two-way door, an extra month is a delivery delay with no upside.

@feynman

Same idea as `git checkout` (cheap, reversible) vs `rm -rf .git` (catastrophic, permanent). Match the caution to the consequence.

@card
id: eds-ch03-c012
order: 12
title: The Architect As Translator
teaser: Architecture documents and diagrams are deliverables. The harder, less visible work is helping teams agree on what to build and why.

@explanation

An architect who only produces diagrams gets ignored. An architect who builds shared understanding across teams gets followed. Practical responsibilities of the role:

- **Translate business needs to technical constraints** — what does "self-serve analytics" require of the warehouse, the catalog, the access model?
- **Translate technical constraints to business needs** — why we can't ship the dashboard in two weeks; what we need to invest in first.
- **Run design reviews** — gather stakeholders before significant changes; surface assumptions; document decisions.
- **Maintain shared mental models** — diagrams that match reality; architecture decision records (ADRs) for major choices.
- **Defend the decisions** — when pressure mounts to violate a principle, explain the cost and accept it deliberately rather than implicitly.

The role is part technical, part product, part diplomat. The best architects are not the ones with the deepest tool knowledge — they're the ones who can hold a multi-team conversation and produce shared agreement at the end of it.

> [!tip] If your team has architectural decisions but no architectural decision records, future-you will be furious about it within a year. Start writing ADRs even if briefly.

@feynman

Same as a tech lead — the deliverable isn't code, it's coherence.
