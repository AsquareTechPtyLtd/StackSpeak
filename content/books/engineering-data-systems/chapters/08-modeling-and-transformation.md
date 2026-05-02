@chapter
id: eds-ch08-modeling-and-transformation
order: 8
title: Modeling and Transformation
summary: Turning raw landed data into the modeled, queryable, reliable artifacts that downstream consumers actually need — and the philosophies that have been arguing about how to do it for fifty years.

@card
id: eds-ch08-c001
order: 1
title: Modeling Is Designing The Vocabulary
teaser: A data model isn't just tables and columns — it's the shared vocabulary downstream users will think with. Good modeling outlasts every tool change in the stack.

@explanation

When an analyst asks "what's our customer count?", they're asking against a model. Their query references entities (customer, order, session) that someone, at some point, defined and shaped. That definition is the data model.

What modeling decides:

- **What entities exist.** Customer, account, session — what's a noun in this business?
- **How entities relate.** Customer has many orders; order has one shipment; product belongs to many categories.
- **What attributes each has.** And what they mean — `is_active = true` defined how, exactly?
- **How history is preserved.** When a customer's address changes, do we keep the old one? For how long?

A team without an explicit model accumulates one accidentally — every analyst writes their own joins; every dashboard re-derives "active customer" slightly differently; the same number on different reports doesn't match.

The role formalizing this work has shifted. The data engineer used to own modeling; now analytics engineers (dbt-shop role) often do. Either way, somebody must — implicitly or explicitly — and the work is the difference between a data warehouse people trust and one they second-guess.

> [!info] The "single source of truth" promise of a warehouse only delivers if there's a single authoritative model behind it. Without that, you have a shared database, not a shared truth.

@feynman

Same as designing an API — the names you pick and the structures you choose shape every conversation that follows.

@card
id: eds-ch08-c002
order: 2
title: Normalization Versus Denormalization
teaser: Two ends of a design spectrum. Normalized models avoid redundancy; denormalized models avoid joins. Both are right, for different workloads.

@explanation

**Normalized.** Each fact stored once, in one place. Updates are atomic; storage is minimal. Queries that need related data must join.

OLTP systems (Postgres, MySQL) are heavily normalized. A customer's address lives in `customers`; their orders in `orders`; an order's line items in `order_lines`. Updates are clean. Reading a complete order requires three joins.

**Denormalized.** Related data duplicated for read efficiency. A single fat row often replaces multiple joined tables. Updates are messier; storage is larger; reads are fast.

Analytical systems (warehouses, lakes) lean heavily denormalized. The fact table for orders might already include customer name, customer email, region, segment — denormalized from `customers` so downstream queries don't have to join.

The trade-off:

- **Storage** — denormalized takes more space.
- **Update cost** — change a customer's email in a normalized model and one row updates; in a denormalized model, every order they've placed needs updating.
- **Read cost** — joins are expensive at warehouse scale; denormalized reads are cheap.
- **Consistency** — normalized data is always self-consistent; denormalized risks divergence between source-of-truth and copies.

Modern warehouses (with cheap compute) blur the distinction — joins on properly clustered tables can be near-free. But the fundamental trade-off persists.

> [!tip] The right normalization level depends on the layer: highly normalized in OLTP source, denormalized analytics tables in serving layer, often a hybrid in transformation layers.

@feynman

Same trade-off as caching — duplicate data buys read speed at the cost of having to keep the duplicate in sync.

@card
id: eds-ch08-c003
order: 3
title: Star Schema And Kimball Modeling
teaser: The Kimball star-schema model — facts surrounded by dimensions — has been the default analytical modeling pattern for decades. It still is, for good reasons.

@explanation

Ralph Kimball formalized the star schema in the 1990s. Three core ideas:

- **Fact tables** — the things that happened. Each row is a measurement or event: an order, a click, a transaction. Facts are typically numeric (quantity, price, duration) plus foreign keys to dimensions.
- **Dimension tables** — the context for facts. Each dimension answers a "by what?" question: by customer, by product, by date, by region.
- **Star pattern** — a fact table at the center, surrounded by its dimensions. Queries slice and dice by dimension attributes.

A typical e-commerce star:

- **Fact**: `fact_orders` (order_id, date_id, customer_id, product_id, quantity, price)
- **Dimensions**: `dim_date`, `dim_customer`, `dim_product`, `dim_geography`

Why it endures:

- **Queryable** — analysts intuit it; SQL against star schemas reads naturally.
- **Performant** — most warehouse engines optimize for star-schema patterns specifically.
- **Stable** — the entity hierarchy doesn't change much; dimensions add attributes without breaking facts.
- **Self-documenting** — the model itself describes the business.

Kimball wrote a whole book of patterns — slowly changing dimensions, factless facts, conformed dimensions, snowflake variants. The patterns are pragmatic and still-relevant.

> [!info] If your warehouse model isn't broadly Kimball-shaped, it's worth understanding why. The default works well for most analytics workloads; deviations should be deliberate.

@feynman

Same idea as a relational schema for the analytical world — a small number of patterns that compose into most useful models.

@card
id: eds-ch08-c004
order: 4
title: Slowly Changing Dimensions — Type 1 Through Type 7
teaser: Dimensions evolve over time. How you handle the change defines whether your historical reports show what was true then or what's true now.

@explanation

A customer moves from Texas to California. Your dimension table has a `state` column. What do you do?

- **Type 0 — Retain original.** Whatever you first recorded never changes. Useful for things that legitimately don't change (date of birth).
- **Type 1 — Overwrite.** Update the row in place; lose the history. Simple, common, but historical reports show "current" state for past dates.
- **Type 2 — Add new row.** Insert a new dimension row with the new value, marked with effective dates. Old fact rows still reference the old version. Historical reports show "as it was."
- **Type 3 — Add new attribute.** Keep `current_state` and `previous_state` columns. Limited history (just one prior value).
- **Type 4 — Add history table.** Current state in the main table; full change history in a separate table.
- **Type 6 — Hybrid.** Type 1 + Type 2 + Type 3 in combination — most flexible, most complex.
- **Type 7 — Dual.** Two versions of the dimension exposed, one current and one historical, downstream picks.

The decision depends on what reports need:

- "What's the customer's current state?" → Type 1 is fine.
- "What state were they in when this order was placed?" → Type 2 required.
- Most analytical use cases want Type 2 for important dimensions, Type 1 for cosmetic attributes.

> [!warning] Choosing Type 1 by default and discovering later you need Type 2 history is the most common modeling regret. If in doubt, lean Type 2 from the start.

@feynman

Same problem as schema migrations — preserving history vs current truth, with different right answers for different consumers.

@card
id: eds-ch08-c005
order: 5
title: Inmon, Data Vault, And Wide Tables
teaser: Three modeling philosophies that compete with Kimball. Each has a constituency; understanding their pros tells you when Kimball isn't the right answer.

@explanation

**Inmon (Bill Inmon's 3NF warehouse).** A normalized enterprise data warehouse, modeled close to the source systems. Marts (often Kimball-style stars) are derived from the EDW for specific consumer groups.

Pros: enterprise-wide consistency. Single normalized layer.
Cons: heavy upfront modeling. Slower to evolve. Marts are still needed for actual querying.

**Data Vault.** Hubs (business keys), links (relationships), satellites (attributes with history). Designed for auditability, parallel loading, and easy schema evolution.

Pros: handles changing source schemas gracefully. Strong audit trail. Loads can parallelize.
Cons: massive schema (3-5× the table count of Kimball). Still needs a "presentation layer" (Kimball-style) for analysts to query usefully.

**Wide tables (One Big Table).** Pre-join everything into a single denormalized table. Modern warehouses handle these efficiently; queries don't join.

Pros: simplest possible queries. Fastest reads. Self-service analytics-friendly.
Cons: storage cost. Update complexity. Doesn't scale well to many entity relationships.

Where each fits:

- **Inmon** — large enterprise, multi-consumer, regulated data warehouse.
- **Data Vault** — high-change source systems, regulatory audit requirements, very large teams loading in parallel.
- **Wide tables** — startups, simple domains, BI-led teams that prize self-service.
- **Kimball** — most things else; the safe default.

> [!info] Many modern teams use Kimball-style marts as the consumer-facing layer regardless of what shape the underlying transformation philosophy takes. The shape that works for analysts hasn't changed much.

@feynman

Same as picking architecture — the problem usually constrains the answer more than personal preference.

@card
id: eds-ch08-c006
order: 6
title: ELT With dbt — How Modern Teams Transform
teaser: dbt didn't invent SQL transformations, but it did formalize them into something teams can collaborate on, version, and test. It's now the default tool for warehouse-native modeling.

@explanation

dbt (data build tool) is a SQL-based transformation framework. Models are SQL files in a git repo; dbt compiles them, manages dependencies, runs them in the warehouse, and tests the results.

Why it caught on:

- **SQL is the lingua franca** — analysts and engineers both read it.
- **Version control** — models are files; PRs review changes; history is preserved.
- **Modular** — models reference other models with `{{ ref('...') }}`; dbt builds the dependency DAG.
- **Tests** — declarative assertions (uniqueness, not-null, accepted-values, custom) run on every build.
- **Documentation** — descriptions live with the code; dbt generates a docs site automatically.
- **Lineage** — the dependency graph is auto-generated from `ref` calls; no manual upkeep.

Common project structure:

- **Sources** — declarative refs to raw landed tables.
- **Staging** — light cleaning per source (renaming, casting, basic filtering). One staging model per source table.
- **Intermediate** — joins and aggregations that don't quite belong to the final mart.
- **Marts** — the consumer-facing tables (star schema, wide tables, whatever the model demands).

> [!tip] dbt's biggest gift isn't the tool — it's the discipline of treating SQL transformations as engineered software. PRs, tests, modular structure, documentation. Adopt those even if you choose a different tool.

@feynman

Same arc as Webpack for JavaScript — formalized something everyone was doing badly into a default everyone now does well.

@card
id: eds-ch08-c007
order: 7
title: Where To Transform — Source, Flight, Warehouse, Or Read
teaser: The same logical transformation can happen at very different physical points. Each location has different cost, complexity, and reusability properties.

@explanation

Four candidate locations for a transformation:

**At the source.** Application code computes the value before storing it.
- Pros: data lands ready-to-use.
- Cons: couples your warehouse needs to application code; expensive coordination cost.

**In flight (during ingestion).** Streaming transformations (Flink, Kafka Streams) process events as they pass.
- Pros: low-latency results; no warehouse compute needed.
- Cons: hard to recompute; logic lives outside SQL toolchains; expertise scarce.

**At rest in the warehouse (ELT).** dbt or similar runs SQL transformations after raw landed.
- Pros: easy to recompute, test, version, share. Cheap warehouse compute.
- Cons: results lag ingestion by transformation runtime.

**At read time (views, virtual layers).** SQL views; semantic layers; LookML-style logic that runs per-query.
- Pros: always fresh; no recomputation needed.
- Cons: slower per query; complex views can become expensive at scale.

The modern default: most transformation happens at rest in the warehouse via dbt. Streaming for the slice that genuinely needs sub-minute freshness. Views for last-mile filtering and customization. Source-side transformation only when truly necessary.

> [!info] Pushing transformation upstream toward the source feels efficient and is usually a trap — every consumer pays the coordination cost when source code needs to change.

@feynman

Same as deciding when to compute something in code — eagerly at write, lazily at read, batched in the middle. Each fits different workloads.

@card
id: eds-ch08-c008
order: 8
title: Batch Versus Streaming Transformations
teaser: The same transformation applied to a batch window or to a continuous stream looks similar in code and very different in operation.

@explanation

**Batch transformation.** Run on a schedule against a window of data. Reads from a stable input; produces a stable output. Re-runs are clean.

Examples: nightly dbt run; hourly Spark job aggregating yesterday's events.

Wins: simple operationally. Easy to debug. Easy to re-compute. Output is deterministic.
Losses: latency bounded by batch frequency.

**Streaming transformation.** Process events as they arrive. Produces continuous output (a materialized view, a derived stream, alert events).

Examples: Flink computing 5-minute aggregations and emitting them; Materialize keeping a SQL view continuously up-to-date; Kafka Streams transforming events between topics.

Wins: near-real-time output.
Losses: substantially more complex. State management, watermarks, late-arriving data, out-of-order events all become explicit concerns.

Picking:

- **Default to batch.** Hourly or daily batch handles most analytics needs at a fraction of the operational cost.
- **Streaming when freshness drives value.** Real-time fraud detection, inventory updates, live operational dashboards.
- **Hybrid is fine.** Streaming for the freshest layer; batch jobs that periodically reconcile and correct. Use the strengths of each.

The under-discussed cost of streaming: late-arriving events. An event from 30 seconds ago arrives now — does your aggregation reopen the window? Do you produce a correction? These questions are routine in batch (re-run yesterday) and tricky in streaming.

> [!warning] "Make it streaming" is one of the most expensive defaults a team can accept. Be sure the freshness justifies the operational complexity.

@feynman

Same as choosing between a CRON job and an always-on service. Simpler is usually better; choose complex with reason.

@card
id: eds-ch08-c009
order: 9
title: Dimensional Hierarchies And Conformed Dimensions
teaser: Two Kimball patterns that pay off as the warehouse scales — let consumers slice up and across multiple fact tables consistently.

@explanation

**Dimensional hierarchies.** Dimensions often have natural roll-up structures. Date rolls up to week, month, quarter, year. Product rolls up to category, line, brand. Geography rolls up city → state → country → region.

Encoding hierarchies in the dimension table lets queries roll up easily:

```
dim_date columns: date_id, date, day_of_week, week, month, quarter, year, fiscal_period
```

A query "revenue by quarter" then groups by `quarter` directly without external lookup.

**Conformed dimensions.** When the same dimension appears across multiple fact tables — `dim_customer` used by `fact_orders`, `fact_support_tickets`, `fact_marketing_touches` — they must conform: same primary key, same definitions, same SCD policy.

Why this matters: it lets analysts compare across facts. "Customers who placed an order AND opened a support ticket in the same month" is a query that only works if `dim_customer` is the same dimension on both fact tables.

In a small warehouse, this happens naturally. As the warehouse scales across teams, conforming dimensions becomes an explicit governance discipline — there's one `dim_customer`; it's owned by a specific team; other teams use it as-is.

> [!tip] When you find two competing customer dimensions in your warehouse, that's a sign the team has outgrown informal coordination. Time to designate ownership and consolidate.

@feynman

Same as canonical types in a typesystem — one source of truth that other things reference, instead of every module redefining `User`.

@card
id: eds-ch08-c010
order: 10
title: Testing Transformations
teaser: Untested transformation code is just SQL waiting to silently produce wrong numbers. Tests are how you catch the bugs before consumers do.

@explanation

What can be tested:

- **Schema** — expected columns exist with expected types.
- **Uniqueness** — primary key is actually unique.
- **Referential integrity** — every foreign key resolves to a row in the referenced table.
- **Not null** — required fields are populated.
- **Accepted values** — `status` is one of `('active', 'inactive', 'pending')`.
- **Range** — `age` is between 0 and 150; `quantity` is positive.
- **Row count** — within expected bounds; not catastrophically empty or huge.
- **Custom logic** — business invariants ("revenue equals sum of order amounts").

dbt's built-in tests cover the common cases declaratively. dbt-utils, dbt-expectations, and Great Expectations cover the rest.

Where tests fit in the pipeline:

- **Source tests** — run against staging models; catch source-data issues at the boundary.
- **Model tests** — run after each model builds; catch transformation logic errors.
- **Final assertion tests** — run after marts build; catch business-invariant violations.

The ideal: every model has at least basic tests (unique, not_null on key columns); critical models have business-invariant tests. Failed tests fail the dbt run; alert routes to the on-call.

> [!info] The teams that catch bad data before consumers report it test their transformations exhaustively. The teams that get surprised by their own dashboards usually don't.

@feynman

Same hygiene as unit testing in software — declarative assertions about what should be true; failure means stop the build.

@card
id: eds-ch08-c011
order: 11
title: Materializing Versus Virtualizing
teaser: A transformation can produce a physical table or a virtual view. Each has different cost, freshness, and maintainability properties.

@explanation

**Materialized output.** The transformation runs and writes results to a physical table. Future queries hit the table directly.

Pros: query performance is excellent (just reading a table). Costs are predictable.
Cons: refresh on a schedule; data is as fresh as the last refresh. Storage cost grows.

**Virtual output.** The transformation is defined as a view; future queries re-execute the view's SQL on the underlying tables.

Pros: always fresh. No storage cost. Trivial to change (just edit the view).
Cons: every query pays the transformation cost. Complex views become expensive.

dbt offers four materializations:

- **table** — full table rebuild on each dbt run.
- **incremental** — append or upsert based on a watermark. The default for high-volume facts.
- **view** — virtual; query-time execution.
- **ephemeral** — inlined into downstream models; never persisted.

The decision pattern:

- **Small dimensional data** — view (cheap to recompute, always fresh).
- **Large fact data** — incremental table (expensive to rebuild, fresh enough to schedule).
- **Frequently changed business logic** — view during development, table for production stability.
- **Heavy intermediate joins** — table or ephemeral, depending on whether reuse justifies persistence.

> [!tip] Start with views and only materialize when query performance demands it. Premature materialization is a common cost driver.

@feynman

Same trade-off as memoization — store the result vs recompute every time. Choose based on access frequency vs storage cost.

@card
id: eds-ch08-c012
order: 12
title: Semantic Layers — One Definition Of A Metric
teaser: A semantic layer encodes business definitions ("monthly active users") once and exposes them consistently across BI tools, queries, and reverse ETL.

@explanation

The problem: "monthly active users" is computed slightly differently in five dashboards. Marketing's MAU includes free trial users; product's excludes them. Both teams' numbers are "right" by their own definitions; both are different.

A semantic layer fixes this by centralizing definitions:

- **Metrics defined once** — in code, with explicit logic, version-controlled.
- **Surfaces in BI tools** — Looker, Tableau, Mode call into the layer rather than re-implementing.
- **Reused across consumers** — dashboards, alerts, reverse ETL, ML features all use the same definitions.

The major options in 2026:

- **dbt Semantic Layer** — metrics defined alongside dbt models; compiled to SQL on query.
- **Cube** — open-source semantic layer; sits in front of warehouses.
- **LookML** (Looker's proprietary) — metrics live in LookML; tightly coupled to Looker BI.
- **MetricFlow** (acquired by dbt) — formed the basis of dbt's offering.
- **AtScale, AtomicJolt, others** — specialized vendors.

Adoption is uneven. Many teams technically have a semantic layer (LookML, MicroStrategy) but don't share metrics across tools. The rising movement is to make metrics genuinely portable — defined once, consumed by any tool.

> [!info] Semantic layers solve a real problem (definition drift) but are operationally heavy to introduce. Most teams adopt them after they've been bitten by the inconsistency they prevent.

@feynman

Same as a shared library of pure functions — define the calculation once; call it from many places; never re-derive.

@card
id: eds-ch08-c013
order: 13
title: Lineage And Impact Analysis
teaser: When something looks wrong, you need to trace it backward. When something is about to change, you need to see what depends on it. Lineage gives you both.

@explanation

Data lineage maps the dependency graph of your data system: source A feeds table B feeds dashboard C feeds reverse-ETL push D. With it, two questions get easy:

- **Backward** — "where did this number come from?" Trace dashboard back through models to source.
- **Forward** — "what depends on this column?" Before deprecating it, you can see the blast radius.

Where lineage lives:

- **dbt** — auto-generates column- and model-level lineage from `ref` and `source` calls. Visible in dbt docs.
- **Data catalogs** (DataHub, Amundsen, OpenMetadata, Collibra, Atlan) — pull lineage from dbt, Airflow, BI tools and aggregate.
- **OpenLineage** — emerging standard for emitting lineage events from any tool.
- **Vendor-specific** — Snowflake, BigQuery, Databricks all have native lineage features now.

What lineage doesn't solve:

- **Semantic equivalence** — two tables with the same data and different lineage paths look unrelated.
- **External consumers** — once data leaves your stack (sent to a third party, exported), lineage typically drops.
- **Manual changes** — analysts copy-pasting SQL into ad-hoc queries doesn't show in lineage.

Even imperfect lineage is hugely valuable. A team with column-level lineage can run an impact analysis in minutes; a team without it spends days.

> [!tip] If you only invest in one observability tool early, automated lineage pays back the fastest. Schema-change incidents become 10× easier to scope.

@feynman

Same as a stack trace for data — shows the path from where you are now back to where the value originated.
