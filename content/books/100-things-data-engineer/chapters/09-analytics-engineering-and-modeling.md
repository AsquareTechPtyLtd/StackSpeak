@chapter
id: tde-ch09-analytics-engineering-and-modeling
order: 9
title: Analytics Engineering and Modeling
summary: Analytics engineering sits between raw pipelines and analyst dashboards — it's the discipline of transforming messy source data into modeled, tested, documented datasets that the business can actually trust.

@card
id: tde-ch09-c001
order: 1
title: The Analytics Engineering Role
teaser: Analytics engineering is the discipline between data pipelines and dashboards — the team that turns raw data into modeled datasets analysts can trust without calling someone to ask what the numbers mean.

@explanation

Analytics engineers own the transformation layer. Data engineers build pipelines that land raw data in the warehouse. Analysts build reports and dashboards. Analytics engineers sit in between: they take raw data and produce clean, tested, documented models that analysts can query with confidence.

What that looks like in practice:
- Raw events land in a staging schema from Fivetran, Airbyte, or a custom pipeline.
- Analytics engineers write SQL transformations that clean, join, and model that data into fact and dimension tables.
- Analysts query the modeled layer — not the raw tables — so their reports are insulated from upstream schema changes.

The defining tool for this role is **dbt** (data build tool). dbt runs on top of your existing warehouse (BigQuery, Snowflake, Redshift, DuckDB, Trino) and treats SQL SELECT statements as first-class artifacts — versioned in git, tested, and documented.

The SQL-layer distinction matters: analytics engineering operates at the warehouse SQL level, not the Spark/Flink distributed compute level. If your transformation fits in a SQL query on your warehouse, it belongs here. If you need to process 100 TB of raw logs in parallel before they hit the warehouse, that's a data engineering problem.

> [!info] Analytics engineering is not a technology choice — it's a discipline. You can practice it without dbt. But dbt operationalizes the discipline so completely that the two are nearly synonymous.

@feynman

Analytics engineers are the translators between the plumbing (pipelines) and the display layer (dashboards) — they make sure the water that comes out of the tap is actually clean and not just pressurized.

@card
id: tde-ch09-c002
order: 2
title: dbt Fundamentals
teaser: dbt turns SQL SELECT statements into a tested, versioned, self-documenting DAG — and `ref()` is the single function that makes the whole thing work.

@explanation

A **dbt model** is a `.sql` file containing a single SELECT statement. When you run `dbt run`, dbt compiles each model into a CREATE TABLE or CREATE VIEW statement and executes it against your warehouse. That's it — no new query language, no custom runtime.

The `ref()` function is what separates dbt from a folder of SQL scripts. When you write `FROM {{ ref('stg_orders') }}` instead of `FROM raw.orders`, dbt automatically builds the DAG, resolves execution order, and ensures the staging model runs before the model that references it.

**Materializations** control what dbt does with the SELECT result:
- `view` — creates a view (no data stored; runs at query time)
- `table` — creates a full table (replaces entirely on each `dbt run`)
- `incremental` — appends or upserts only new rows (covered in card 8)
- `ephemeral` — inlines the SQL as a CTE; never materialized in the warehouse

**Project structure:**
- `models/` — SQL transformation files, often split into staging → intermediate → marts
- `sources/` — YAML declarations of raw tables dbt should reference
- `seeds/` — small CSV files (lookup tables, country codes) loaded by `dbt seed`
- `tests/` — SQL assertions run by `dbt test`
- `macros/` — reusable Jinja snippets

The typical workflow is three commands: `dbt run` to materialize models, `dbt test` to run quality checks, then `dbt docs generate && dbt docs serve` to view the data catalog.

> [!tip] Start every new dbt project with sources declared in YAML and a staging layer that maps one-to-one with source tables. This separation means your downstream models are never directly coupled to source schema changes.

@feynman

dbt is to SQL what Make is to build scripts — it adds dependency resolution and incremental execution to something you were already writing by hand.

@card
id: tde-ch09-c003
order: 3
title: The Medallion Architecture
teaser: Bronze, Silver, Gold is a naming convention for a discipline that matters more than the names: never let raw data touch your analytics layer without a cleaning checkpoint in between.

@explanation

The **Medallion architecture** defines three layers with increasing data quality:

**Bronze (raw layer):** An immutable copy of source data exactly as it arrived — schema preserved, no transformations, no deletions. Bronze tables are an audit trail. If you ever question whether a downstream transformation introduced a bug, you can reprocess from Bronze. Write Bronze once; never update it.

**Silver (cleaned layer):** Data that has been deduplicated, type-cast, null-handled, and joined with related entities. A Silver table for orders might join raw order events with customer and product dimensions, standardize currency to USD, and remove test accounts. Silver is where most analytics engineering work lives.

**Gold (business layer):** Aggregated, metric-ready tables built for specific business use cases: daily active users, monthly revenue by region, retention cohorts. Gold tables are what analysts and BI tools query directly. They're optimized for read performance and business readability, not normalization.

The naming is flexible — some teams call these layers staging/intermediate/marts, others use raw/clean/aggregated. The names don't matter. The discipline does:
- Raw data is never directly exposed to analytics consumers.
- Cleaning logic is isolated in one layer so bugs are easy to find.
- Business logic (what counts as "active," what's included in "revenue") lives in Gold, not scattered across 50 dashboards.

> [!warning] The most common mistake is skipping Silver and transforming directly from Bronze to Gold. When your cleaning and business logic are merged in the same model, a schema change in your source breaks your metrics layer all at once.

@feynman

Bronze is the raw ingredient delivery, Silver is the kitchen prep, and Gold is the plated dish — and you wouldn't serve prep-table scraps as a finished course.

@card
id: tde-ch09-c004
order: 4
title: Star Schema vs Wide Table
teaser: Star schemas optimize for BI tools that join well; wide tables optimize for columnar warehouses that scan fast — understanding the tradeoff saves you from building the wrong thing for your query pattern.

@explanation

**Star schema** organizes data into a central fact table surrounded by dimension tables. A fact table for orders contains order_id, customer_id, product_id, amount, and event timestamps — foreign keys to dimensions that hold the descriptive attributes. Analysts join fact to dimension to get customer names, product categories, and region hierarchies.

Star schemas are:
- Well-understood by BI tools (Tableau, Looker, Power BI) that autogenerate joins
- Storage-efficient because descriptive attributes are stored once in dimensions
- Harder to query ad-hoc because every question requires at least one join

**Wide table / one-big-table (OBT)** denormalizes everything into a single table. Customer name, product category, and region are columns on the order row — no joins required. Every query is a scan plus a filter.

Wide tables are:
- Fast in columnar warehouses (BigQuery, Snowflake, DuckDB) where full-column scans are cheap and cross-table joins are relatively expensive
- Simple to query — any analyst can answer a question with a single SELECT
- Expensive in storage (denormalized data repeats descriptive attributes for every row)
- A poor fit when dimension attributes change frequently (every customer name change updates thousands of rows)

The modern trend has shifted toward wide tables for analytics use cases in columnar warehouses. If your primary consumers are analysts running ad-hoc SQL or Python notebooks — not BI tools with pre-built join models — a wide table is often the right default.

> [!info] These aren't mutually exclusive. Many teams maintain a normalized Silver layer for auditability and flexibility, then materialize wide Gold tables for specific analyst use cases.

@feynman

Star schema is a normalized database built for flexibility; a wide table is a denormalized report built for speed — and in columnar warehouses, speed usually wins for analytics.

@card
id: tde-ch09-c005
order: 5
title: Slowly Changing Dimensions
teaser: When a customer moves cities or changes their company name, you have to decide whether to overwrite the old value, preserve history, or store both — and the wrong choice destroys your ability to answer "what did this look like at the time?"

@explanation

A **slowly changing dimension (SCD)** is any dimension attribute that changes over time — customer address, employee department, product category, account tier. The SCD type determines how you handle that change.

**Type 1 — Overwrite:** Update the record in place. The old value is gone. Simple to implement, but destroys history. Use Type 1 when history genuinely doesn't matter (correcting a typo, for example).

**Type 2 — Add a row:** Insert a new row with `valid_from` and `valid_to` date columns. The old row has a `valid_to` set to yesterday; the new row has `valid_from` today and `valid_to` = NULL (or 9999-12-31). Historical queries join on the date range to get the value as it existed at a point in time. This is the standard for anything that matters historically.

**Type 3 — Add a column:** Add `previous_value` and `current_value` columns to the same row. Stores exactly one generation of history. Use it when "before/after" is the only historical question you'll ever need to answer.

**dbt snapshots** implement SCD Type 2 automatically. You define a snapshot model with a `unique_key` and `strategy` (timestamp or check), run `dbt snapshot`, and dbt handles the `valid_from`/`valid_to` bookkeeping.

When is SCD Type 2 essential? When you need time-series accuracy: a customer's revenue attribution should use the region they were in *at the time of the sale*, not their current region. Regulatory audits require showing the state of data at specific past dates. Without Type 2, those questions are unanswerable.

When is SCD Type 2 overkill? When you're tracking attributes that change constantly (session counts, event totals) or when nobody will ever ask a historical question about the dimension.

> [!warning] Teams that skip SCD Type 2 for years discover they need it when a business question requires historical accuracy they can no longer reconstruct. Retrofitting SCD Type 2 onto an existing dimension is painful — the history before you added it is gone.

@feynman

SCD types are just a decision about how many snapshots of a record to keep: none (Type 1), one per change (Type 2), or just the last one (Type 3).

@card
id: tde-ch09-c006
order: 6
title: The Semantic Layer
teaser: The semantic layer is where you write the definition of "revenue" once so every dashboard, notebook, and API query uses the exact same number — and stop having the same argument at every executive review.

@explanation

The **semantic layer** maps raw data fields to business metrics with consistent, centralized definitions. Instead of every dashboard hardcoding its own interpretation of "active user" or "monthly recurring revenue," those definitions live in one place, and all consumers generate their numbers from the same definition.

What a metric definition captures:
- Which table and column to aggregate
- The aggregation function (sum, count distinct, etc.)
- Filters to apply (exclude internal test accounts, exclude refunded orders)
- The time grain and dimensions it can be sliced by

Without a semantic layer, the same metric definition is re-implemented in every BI tool, every notebook, every API endpoint. When the definition changes (new product line, changed refund policy), you update it in 40 places — and miss 12. The result is a dashboards that show different numbers for "the same thing."

Tools in this space:
- **dbt Metrics / MetricFlow** — defines metrics as YAML in the dbt project; queries resolved by MetricFlow
- **LookML (Looker)** — Looker's proprietary semantic layer
- **Cube** — standalone semantic layer that sits between warehouse and BI tools
- **AtScale** — enterprise-grade semantic layer with MDX support

The "one metric, one definition" principle is the point. When an executive asks "what was revenue last quarter?" and two analysts give the same answer, the semantic layer is doing its job.

> [!info] A semantic layer doesn't prevent business discussions about what revenue *should* include. It forces those discussions to happen once, produce a decision, and encode that decision in code — rather than happening repeatedly with different outcomes.

@feynman

The semantic layer is a company-wide glossary checked into git — the dictionary that prevents every team from inventing their own language for the same concepts.

@card
id: tde-ch09-c007
order: 7
title: Metrics Consistency Across Reports
teaser: Two dashboards showing different revenue numbers for the same period is not a data quality problem — it's an architecture problem, and the fix is not reconciliation meetings but a single source of definition.

@explanation

The scenario plays out in almost every data organization: a finance team builds their revenue dashboard, a growth team builds theirs, and an executive review discovers they disagree by 8%. Both teams defend their numbers. Both are technically correct given their own filters and logic. The reconciliation takes two hours and produces a temporary truce, not a fix.

Why the numbers differ:
- Different tables as source (orders vs invoices vs Stripe events)
- Different filters (exclude refunds vs include pending refunds vs exclude sandbox)
- Different time bucketing (order date vs payment date vs recognition date)
- Different currency conversion assumptions

The architectural fix is not to run the reconciliation meeting better — it's to define the metric once and generate all reports from that single definition. When there is one `revenue` metric in the semantic layer and both dashboards are forced to use it, divergence is structurally impossible.

The audit process that precedes this fix:
1. Identify every place "revenue" is computed across all reports and tools.
2. Document the differences in definition (there will be several).
3. Convene the business owners to agree on the canonical definition.
4. Encode the canonical definition in the semantic layer.
5. Migrate all reports to the shared definition, retire the divergent ones.

This is not a one-afternoon fix. For large orgs it's a weeks-long project. But the alternative is running step 1-3 as an ad-hoc reconciliation every quarter, forever.

> [!tip] Track metric definition as a code artifact with the same rigor as schema migrations. When the definition of "active user" changes from "logged in in 30 days" to "logged in in 7 days," that change needs a PR, a reviewer, and a comment explaining why.

@feynman

Divergent dashboards are like two services with different versions of a shared library — the real fix is a single dependency, not pinning each service to its own copy.

@card
id: tde-ch09-c008
order: 8
title: dbt Incremental Models
teaser: Running a full table refresh on 500 million rows every hour is expensive and slow — incremental models process only new and changed rows, but the correctness is entirely your responsibility.

@explanation

An **incremental model** in dbt only processes rows that are new or changed since the last run, rather than rebuilding the entire table from scratch. For large event tables (billions of rows, refreshed every hour), the difference between a full refresh and an incremental run can be 100× in cost and time.

The core mechanism uses the `is_incremental()` macro to add a filter when the model runs in incremental mode:

```sql
SELECT *
FROM {{ source('events', 'raw_events') }}
{% if is_incremental() %}
  WHERE event_time > (SELECT MAX(event_time) FROM {{ this }})
{% endif %}
```

On the first run, `is_incremental()` is false — the full table is built. On subsequent runs, only rows after the current max timestamp are processed.

The `unique_key` config tells dbt how to handle rows that already exist in the target — either by deleting and reinserting (`delete+insert`), or by merging (`merge`). This supports late-arriving data that needs to update existing rows.

**The risks:**
- If your filter logic is wrong, you silently miss rows. A clock skew in the source system or an event with an old timestamp falls outside your filter and is never processed.
- Late-arriving data that bypasses your timestamp filter is silently dropped unless you build an explicit lookback window (e.g., `event_time > (max - 3 hours)`).
- Schema changes in the source table can break incremental models in ways that a full refresh would auto-correct.

Run `dbt run --full-refresh` on a schedule (weekly, or after schema changes) to rebuild from scratch and catch anything incremental logic may have missed.

> [!warning] Incremental models fail silently. There is no error when your filter misses rows — the model succeeds, the table is smaller than it should be, and you find out when a metric looks wrong three days later. Test the row count.

@feynman

An incremental model is like a database transaction log replay — fast and efficient, but only correct if you never miss an entry.

@card
id: tde-ch09-c009
order: 9
title: Testing and Documenting dbt Models
teaser: A dbt project without tests is a folder of SQL files you have to manually verify after every deployment — and documentation written at model-creation time costs one-tenth what it costs to write six months later.

@explanation

**Tests in dbt** are assertions that your data meets a quality contract. There are two kinds:

**Schema tests** (built-in or from dbt-utils): declared in YAML, applied to columns.
- `not_null` — the column has no null values
- `unique` — all values are distinct
- `accepted_values` — only allowed values appear (e.g., status in ['pending', 'complete', 'refunded'])
- `relationships` — foreign key integrity (every order has a valid customer_id)

**Data tests** (custom SQL assertions): a `.sql` file that returns rows only when the test fails. Write one for any business rule that can't be expressed by the built-in tests: "revenue should never be negative," "event counts should not drop more than 30% day-over-day."

Run `dbt test` after every `dbt run` in CI. A deployment that passes `dbt run` but fails `dbt test` should not be merged.

**Documentation** in dbt lives alongside the models in YAML. At the column level, you write a `description:` for every column — what it means, how it's calculated, what edge cases to know about. At the model level, you describe the grain (one row per order), the update frequency, and the primary use cases.

`dbt docs generate` compiles all of this into a static HTML site — a searchable data catalog showing the full DAG, every model description, column-level docs, and test results.

Why document at creation time? When you write the model, the intent is in your head. Documenting it takes 15 minutes. Six months later, you need to reconstruct the intent from the SQL, trace through the source tables, and interview whoever can still remember — that's a two-hour job and it's still incomplete.

> [!info] The dbt docs site is only useful if it's accurate. A column description that reads "see upstream table" or "TBD" is worse than no description — it signals that the catalog can't be trusted, so people stop using it.

@feynman

Writing a column description when you create the model is like writing a commit message when you make the change — the context is right there, and it costs almost nothing compared to reconstructing it later.

@card
id: tde-ch09-c010
order: 10
title: The Analytics Engineering Mindset
teaser: The difference between a dbt project that scales to 10 engineers and one that collapses under its own weight is whether the team treats their SQL models the way good software teams treat their code.

@explanation

Analytics engineering is software engineering applied to SQL. The same practices that make large codebases maintainable apply directly to a dbt project — and teams that skip them pay the same costs: fragility, onboarding failure, and an increasing fear of touching existing models.

The four practices that separate a healthy dbt project from a 500-model nightmare:

**Version control:** Every model, every test, every doc block lives in git. Changes go through PRs. Reviewers check logic, naming conventions, and whether tests were updated. A change that adds a new column to a fact table without updating the downstream models or documentation doesn't pass review.

**Testing:** Every model has at minimum `not_null` and `unique` tests on its primary key, and `not_null` on its most important metric columns. High-stakes Gold models have custom data tests that catch business logic errors (negative revenue, impossible date ranges, row count anomalies). The test suite runs in CI on every PR.

**Documentation:** Every model has a description of its grain and purpose. Every column used by downstream consumers is described. The dbt docs site is updated before a PR is merged, not as a follow-up task.

**Code review:** PRs for model changes get reviewed for SQL correctness, naming consistency, and documentation completeness. The review is a quality gate, not a formality.

Teams that do this treat their dbt project like a product. Teams that don't end up with 500 untested, undocumented models where nobody wants to make changes because there's no safety net and nobody remembers what anything does. The refactoring cost at that point is months, not days.

> [!warning] "We'll add tests and docs later" is how you end up with a data warehouse that moves slower than a monolith from 2010. The time to add the test is when you write the model. Later doesn't happen.

@feynman

A dbt project without tests and documentation is just a warehouse full of stored procedures — you're back to the problem analytics engineering was supposed to solve.
