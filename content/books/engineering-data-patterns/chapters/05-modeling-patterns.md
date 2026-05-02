@chapter
id: depc-ch05-modeling-patterns
order: 5
title: Modeling Patterns
summary: The structural patterns that shape how data is organized for analytical consumption — Kimball stars, Data Vault, wide tables, time-series, and when each fits the query and governance requirements.

@card
id: depc-ch05-c001
order: 1
title: Why Modeling Choices Are Durable
teaser: You can change a transformation or fix a pipeline in hours. Changing the fundamental modeling pattern of a 10 TB warehouse takes months. Get the model right before the data grows.

@explanation

Data modeling decisions define the shape that all downstream consumers encounter. Unlike pipeline code that can be refactored, a modeling choice becomes load-bearing once analysts build reports on top of it, data scientists build features from it, and executives run dashboards from it.

The modeling patterns in this chapter address different recurring requirements:

- **Kimball star schema:** optimized for BI tooling, straightforward joins, and performance on columnar stores.
- **Data Vault:** optimized for auditability, source-system separation, and highly concurrent change.
- **Wide tables / one-big-table:** optimized for analytical query simplicity at the cost of redundancy.
- **Anchor modeling:** optimized for extreme schema evolution where attributes change frequently.
- **Time-series modeling:** optimized for temporal queries over ordered, high-frequency data.

No single model is universally correct. The right choice depends on who's querying, how often the schema evolves, whether governance and auditability matter, and the scale of the data.

> [!info] dbt has made star-schema modeling the practical default for most modern data teams. That's a reasonable default — but understand what it trades away before assuming it's always right.

@feynman

Like database normalization in application engineering — different normal forms are right for different use cases, and understanding why matters more than memorizing the rules.

@card
id: depc-ch05-c002
order: 2
title: Kimball Star Schema
teaser: A central fact table surrounded by dimension tables — the pattern optimized for BI query performance and analytical ergonomics.

@explanation

The **Kimball star schema** organizes an analytical model into fact tables (events, transactions, measurements) and dimension tables (entities that describe the facts — customers, products, dates, locations).

Structure:
- **Fact table:** each row is one event or measurement. Contains foreign keys to dimensions and numeric measures. Small columns, many rows.
- **Dimension tables:** each row describes one entity. Rich descriptive columns. Fewer rows than facts.

Example schema for e-commerce:
```sql
-- fact_orders: one row per order
-- dimensions: dim_customer, dim_product, dim_date, dim_geography
SELECT d.year, c.tier, SUM(f.revenue)
FROM fact_orders f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY d.year, c.tier
```

Why star schema performs well on modern columnar warehouses:
- Wide fact tables allow the warehouse to scan just the columns a query needs.
- Dimension joins are efficient because dimension tables are small relative to facts.
- Denormalized dimension columns eliminate multi-table joins for common attributes.

When star schema fits:
- The data has clear facts (transactions, events) and entities (customers, products).
- BI tools and SQL-savvy analysts are the primary consumers.
- Query patterns are predictable enough to inform the grain of the fact table.

When it doesn't:
- Highly volatile schemas where entities add and drop attributes frequently.
- Many-to-many relationships that don't resolve neatly to a single grain.
- Operational data that isn't naturally event-structured.

> [!tip] Define the grain of a fact table — what exactly one row represents — before designing the schema. "One row per order" is clear; "one row per order line" is different; ambiguity produces wrong aggregations.

@feynman

Like a database normalized to 3NF except the read path is optimized — the joins are predictable and the structure serves the most common queries directly.

@card
id: depc-ch05-c003
order: 3
title: Data Vault
teaser: A modeling pattern that separates raw source data from business rules, making the warehouse auditable and survivable across source-system changes.

@explanation

**Data Vault** separates a warehouse into three entity types, each with a distinct purpose:

**Hubs:** contain the unique business keys from each source system. One row per unique real-world entity. No descriptive data — just the key and metadata about where it came from.

**Links:** record relationships between hubs. One row per relationship instance. Again, no descriptive data.

**Satellites:** contain descriptive attributes, tied to a hub or link, with full history. When an attribute changes, a new row is added — the old row is preserved.

Benefits of Data Vault:
- **Source-system agnosticism.** A hub can hold keys from multiple source systems for the same real-world entity. Adding a new source is adding new satellites, not restructuring the model.
- **Full historization by default.** Every change to any attribute is stored. Audit requirements are met structurally rather than through special processes.
- **Parallel loading.** Hubs, links, and satellites can be loaded concurrently; they have no loading dependencies on each other.

Costs of Data Vault:
- **Query complexity.** Consumer queries join hubs, links, and satellites — the query to get "the customer's current name" is multiple joins. Business-vault or information-mart layers are typically built on top for consumption.
- **More tables.** A modeled entity that's one dimension table in Kimball becomes one hub plus multiple satellites in Data Vault.
- **Steeper learning curve.** Analysts accustomed to star schemas find Data Vault disorienting.

Data Vault is most valuable in enterprise environments with multiple source systems feeding the same entities, strict audit requirements, and large teams where different groups load different parts of the warehouse.

> [!info] Most teams using Data Vault also build a "business vault" or "information mart" layer on top for analyst consumption — effectively a star schema built on a Data Vault foundation.

@feynman

Like double-entry bookkeeping — every fact is recorded with its source and time, and the structure enforces the audit trail rather than relying on discipline.

@card
id: depc-ch05-c004
order: 4
title: Wide Tables and One-Big-Table
teaser: Denormalize everything into a single wide table. Query ergonomics are excellent; storage cost goes up; governance gets harder.

@explanation

A **wide table** (also called OBT — one-big-table) pre-joins everything into a single flat table: every relevant dimension attribute is a column alongside the measures. No joins in queries — just SELECT, WHERE, GROUP BY.

Example: instead of joining `fact_orders`, `dim_customer`, `dim_product`, and `dim_date` in every query, a wide orders table has all those columns already joined in:

```sql
SELECT order_month, customer_tier, product_category, SUM(revenue)
FROM wide_orders
WHERE order_date >= '2026-01-01'
GROUP BY 1, 2, 3
```

Why wide tables have become more popular:
- Modern columnar warehouses (Snowflake, BigQuery, Redshift) handle large numbers of columns efficiently; the historical concern about wide rows doesn't apply.
- LLM and ML feature extraction benefits from a single wide table where all features are accessible with no joins.
- Self-serve analytics users find query ergonomics much simpler — no need to know the join logic.

Costs:
- **Redundancy.** The same dimension attribute (e.g., customer tier) is stored N times — once per order row. Storage cost scales with fact row count.
- **Update propagation.** When a dimension changes (customer tier changes), the wide table must be rewritten or the old rows become stale.
- **Multiple grains.** A single wide table can't serve both "orders" and "order-line" queries at different grains without duplicating rows.

> [!tip] Start with a normalized star schema for governance and correctness. Build wide-table views or materialized tables on top for self-serve consumers and ML feature pipelines.

@feynman

Like a spreadsheet that pastes in lookup values instead of using VLOOKUP — everyone understands it immediately, but it takes more space and gets stale when the source changes.

@card
id: depc-ch05-c005
order: 5
title: Time-Series Modeling
teaser: Time-series data has special properties — high frequency, ordered by time, rarely updated — that reward purpose-built modeling choices.

@explanation

**Time-series data** is a sequence of values indexed by time: server metrics, sensor readings, financial prices, event counts, IoT telemetry. It differs from transactional data in key ways that affect modeling:

- **Insert-only:** rows are almost never updated; only inserted. This is compatible with append-only storage and streaming ingestion.
- **Time-ordered access:** queries almost always filter on a time range. Partitioning by time is natural.
- **High cardinality:** billions of rows are common. Efficient compression matters.
- **Aggregation over windows:** average over the last 5 minutes, min/max in the last hour — the query patterns are windowed, not point lookups.

Modeling choices for time-series:

**Column ordering and encoding.** Columnar storage compresses repeated values well. In a metric time series, the metric name, host, and region repeat billions of times. Using dictionary encoding for these columns compresses them by 10–100×.

**Materialized rollups.** Storing per-second data forever is expensive. Pre-aggregate to per-minute, per-hour, per-day as data ages. Queries for recent data hit raw rows; queries for older data hit rollups.

**Schema:** a flat schema with `timestamp`, `metric_name`, `tags` (map), and `value` is the common pattern. Time-series databases (TimescaleDB, InfluxDB, ClickHouse) optimize storage and query for this shape.

**Retention:** time-series data grows without bound unless you define a retention policy. 90 days raw + rollups forever is a common tiering strategy.

> [!info] ClickHouse is a strong choice for analytical time-series workloads — its columnar compression, vectorized aggregation, and materialized views handle billions of rows per second effectively.

@feynman

Like a log file with a rotation policy — you keep the recent stuff in detail and compress or summarize the old stuff.

@card
id: depc-ch05-c006
order: 6
title: Semantic Layers
teaser: A semantic layer sits above your physical tables and exposes business definitions consistently to all consumers — metrics defined once, correct everywhere.

@explanation

A **semantic layer** is an abstraction layer that translates physical data models (tables, columns) into business concepts (metrics, dimensions, entities) and exposes them through a consistent interface to any consumer (BI tool, dashboard, LLM, API).

Why a semantic layer matters:
- **Single source of truth for metrics.** Without a semantic layer, "monthly active users" gets defined differently in every dashboard, every Jupyter notebook, and every ad-hoc query. With one, the definition lives in one place and every consumer uses it.
- **Consumer decoupling.** When the underlying table renames a column or splits into two tables, only the semantic layer changes. Consumers are unaffected.
- **Self-serve analytics.** Business users query concepts, not columns. "Show me revenue by tier" is understandable without knowing which join to use.

Modern semantic layer tools: dbt Semantic Layer (MetricFlow), Cube, LookML (Looker), AtScale, Superset datasets.

What a semantic layer defines:
- **Dimensions:** filterable attributes (date, region, customer tier).
- **Measures:** aggregatable metrics with defined formulas (revenue = SUM(order_amount), DAU = COUNT(DISTINCT user_id) WHERE activity_date = today).
- **Relationships:** how entities join (orders join to customers on customer_id).

In 2026, semantic layers have become increasingly important as LLM-powered analytics tools (text-to-SQL, AI data assistants) query them as structured metadata rather than inferring join logic from raw table names.

> [!tip] Define the 10 most-used business metrics in a semantic layer before doing anything else. The consistency gain is immediate and visible — the first time two dashboards disagree, it's fixed in one place instead of hunted across ten.

@feynman

Like a well-named API — consumers call `getRevenue(month, tier)` and don't need to know which tables or joins that involves.
