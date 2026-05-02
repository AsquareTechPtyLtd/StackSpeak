@chapter
id: depc-ch03-storage-layout-patterns
order: 3
title: Storage Layout Patterns
summary: How you organize data within your storage layer determines query performance, cost, and how well consumers can trust what they find. Bronze/silver/gold, SCD, partitioning, and tiering — all covered.

@card
id: depc-ch03-c001
order: 1
title: The Storage Layout Problem
teaser: Raw data lands in whatever shape the source produced. Downstream users need a different shape. The storage layer is where you manage that gap.

@explanation

Storage layout is about more than where files live. It determines:
- **Query performance:** how much data a query must scan to return a result.
- **Cost:** how much you pay to store and query data at different ages and access frequencies.
- **Consumer trust:** whether the person querying a table finds clean, consistent data or raw noise.
- **Reproducibility:** whether a job that ran yesterday can be reproduced exactly today.

The forces that shape storage layout decisions:

- **Volume.** A 1 GB table and a 1 PB table need different organizational strategies.
- **Query patterns.** Filtering by date is different from filtering by user ID. Partitioning by date helps the first; partitioning by date hurts the second.
- **Access patterns.** Data accessed every day needs different storage economics than data accessed once a quarter.
- **Consumer sophistication.** Analysts querying a warehouse expect clean data. Data scientists building models expect raw events. Both can be served from the same storage layer with the right organization.

> [!info] Storage layout decisions are expensive to change after the fact. Getting them wrong in week one can mean a costly migration in month six.

@feynman

Like the shelving system in a library — the right organization makes every book findable; the wrong one means searching every shelf every time.

@card
id: depc-ch03-c002
order: 2
title: The Medallion Architecture
teaser: Bronze, silver, gold — three named layers with increasing levels of quality and transformation. Each layer serves different consumers with different trust requirements.

@explanation

The **medallion architecture** (popularized by Databricks) organizes a data lakehouse into three named layers:

**Bronze (raw):** Data arrives in exactly the shape it left the source — no transformations, no cleaning, no schema enforcement. The only additions are ingestion metadata (arrival timestamp, source system). This layer is the audit log and replay buffer.

**Silver (cleaned):** Data has been validated, deduplicated, and lightly transformed. Schema is enforced. Incorrect rows are quarantined rather than dropped. Business entities are joinable but not yet aggregated. Analysts can query silver if they're willing to work with row-level data.

**Gold (serving):** Aggregated, modeled, and optimized for consumption. Fact and dimension tables, pre-computed metrics, materialized aggregates. This is what most dashboards and BI tools query.

Benefits:
- **Auditability.** Bronze is the source of truth. Any silver or gold table can be recomputed from bronze.
- **Consumer isolation.** Analysts query gold; engineers debug from bronze. Neither set of queries affects the other.
- **Incremental trust.** A data quality issue can be fixed at silver without touching gold until it's resolved.

Costs:
- **Storage multiplication.** The same data exists at three levels. At high volumes, this matters.
- **Pipeline complexity.** Three levels means three transformation jobs to maintain.

> [!tip] Name your bronze tables after the source system and entity (`raw_stripe_charges`), silver tables after the cleaned entity (`charges`), gold tables after the business concept (`daily_revenue`).

@feynman

Like raw footage → edited film → movie trailer — each layer is the right artifact for a different audience and use case.

@card
id: depc-ch03-c003
order: 3
title: Slowly Changing Dimension Storage
teaser: When a dimension attribute changes over time, how you store that change determines whether historical reporting stays accurate.

@explanation

A **slowly changing dimension (SCD)** is a dimension (customer, product, employee) whose attributes change slowly over time and whose historical values need to be preserved for accurate historical reporting.

The three common patterns:

**SCD Type 1 — Overwrite.** Update the dimension row in place. The current value is always the stored value. Historical queries reflect current attributes, not historical ones. Use when historical accuracy on that attribute doesn't matter.

**SCD Type 2 — Add a new row.** Add a new row for each change, with a validity range (`valid_from`, `valid_to`, `is_current`). Historical queries join to the row valid at that point in time. This is the most common analytical pattern. The primary key is surrogate — the natural key repeats across versions.

Example:
```sql
SELECT o.*, c.tier
FROM orders o
JOIN customers c
  ON o.customer_id = c.customer_id
  AND o.created_at BETWEEN c.valid_from AND c.valid_to
```

**SCD Type 3 — Add a new column.** Store the current value and one previous value in the same row. Cheap but limited — only tracks one change, not a history.

When to use Type 2:
- Customer tier, address, subscription plan — any attribute that affects historical reporting.
- Fact tables need to join to the dimension as it was at transaction time.

Operational complexity of Type 2:
- Insert logic must manage `valid_to` on the previous row and set `is_current = false`.
- Queries must always filter to the correct version; forgetting the time-window join is a silent accuracy bug.

> [!warning] SCD Type 2 without query filters returns duplicate rows per natural key. Every downstream query must filter on `is_current = true` or the time range.

@feynman

Like a passport with all your previous addresses stamped in it, vs one that only shows where you live now.

@card
id: depc-ch03-c004
order: 4
title: Partitioning Strategies
teaser: Partitioning divides a large dataset into smaller chunks that queries can skip. Partition by the field queries filter on most, not the field you happened to ingest by.

@explanation

**Partitioning** divides a large table or file set into smaller segments, each stored separately. A query that filters on the partition column can skip all other partitions — this is partition pruning, and it's often the single largest performance and cost lever for large tables.

Common partition strategies:

**Date/time partitioning.** Most analytical workloads filter by time. Partitioning by `year/month/day` means a query for "last 7 days" reads 7 partitions, not the entire table. This is the right default for time-series data.

```text
s3://data/events/year=2026/month=05/day=01/
```

**Hash partitioning.** Distribute rows across N partitions by hashing the key. Useful when queries filter on a high-cardinality key (user ID, session ID). Prevents skew where one date has 10× the rows of others.

**Range partitioning.** Rows within a key range go into the same partition. Useful for ordered keys (order IDs, sequence numbers) where range scans are common.

**Composite partitioning.** Combine two strategies — date first, then hash by tenant. Useful for multi-tenant systems where tenant isolation and time filtering are both common.

Partitioning anti-patterns:
- **Over-partitioning.** Partitioning by `year/month/day/hour/minute` produces millions of tiny partitions. Metadata operations become slow; read amplification appears where partition pruning should help.
- **Partitioning on a field that's never filtered.** The scan doesn't improve; you just get small files and slow metadata.
- **Partition columns in WHERE without explicit values.** An expression like `WHERE DATE_TRUNC('day', event_time) = '2026-01-01'` may not trigger pruning; `WHERE event_date = '2026-01-01'` does.

> [!tip] For a table that grows by date and is queried by date, `date` partitioning is almost always the right default. Add a second partition key only when you have clear evidence it's needed.

@feynman

Like organizing a filing cabinet by year, then month — you find January 2025 in seconds instead of searching every drawer.

@card
id: depc-ch03-c005
order: 5
title: File Size Optimization
teaser: Too many small files and queries run slowly. Too few large files and parallelism suffers. The right file size for most analytical workloads sits between 128 MB and 1 GB.

@explanation

File size in a data lake directly affects query performance and storage cost:

**Small-file problem:** A table made of ten thousand 1 MB files requires ten thousand file open/close operations per query. Object store metadata operations (LIST, HEAD) are expensive at this scale. Spark jobs create one task per file — ten thousand files means ten thousand tasks, most of which spend more time in overhead than processing.

**Large-file problem:** One massive 100 GB file can't be processed in parallel without splitting. It also means any append or update requires rewriting the entire file.

The sweet spot: **128 MB – 1 GB per file**, matching Hadoop block size conventions and the parallelism units of most distributed processing engines.

Strategies to maintain file size:
- **Compaction jobs:** periodically merge small files into larger ones. In Iceberg or Delta Lake, table maintenance operations (`OPTIMIZE` in Delta, `rewrite_data_files` in Iceberg) handle this.
- **Micro-batching:** buffer streaming writes for a short interval (e.g., 5 minutes) before flushing, so each flush produces a reasonably-sized file rather than one file per event.
- **Target-size writes:** configure Spark or Flink writers to target a specific file size rather than a row count.

In modern table formats (Iceberg, Delta Lake, Hudi), metadata tracking means many small files don't cause the same plan-time penalty as raw Parquet on S3, but compaction is still important for read-time performance.

> [!info] Running weekly OPTIMIZE on Iceberg/Delta tables is one of the highest-return maintenance habits in a lakehouse. It costs minutes of compute and can cut read latency by 10×.

@feynman

Like packing a truck — too many tiny boxes means too many trips; one giant box means you can't lift it alone.

@card
id: depc-ch03-c006
order: 6
title: Hot, Warm, and Cold Tiering
teaser: Data accessed daily should be fast and expensive. Data accessed yearly should be cheap and slow. Tiering matches storage cost to access frequency.

@explanation

**Storage tiering** assigns data to different storage classes based on how often it's accessed, matching cost to value:

**Hot tier:** Standard cloud object storage (S3 Standard, GCS Standard, Azure Hot). Fastest access, highest per-GB cost. Use for the last 30-90 days of data — the window that dashboards, operational queries, and recent analytics typically access.

**Warm tier:** Infrequent access storage (S3-IA, GCS Nearline, Azure Cool). Moderate access cost with a minimum storage duration commitment. Use for data between 90 days and 1 year old.

**Cold tier:** Archive storage (S3 Glacier, GCS Coldline, Azure Archive). Cheapest storage; retrieval takes minutes to hours and costs extra. Use for compliance-required data that's queried rarely (or never in normal operations).

Implementing tiering:
- **Lifecycle policies:** configure automatic transitions based on object age. S3 lifecycle rules can transition objects from Standard to Glacier after 180 days with no application code.
- **Iceberg/Delta time travel retention:** set retention policies on historical versions, not just current data.
- **Query routing:** ensure queries that could land on warm/cold storage are routed to jobs that account for retrieval cost and latency.

Cost example: at AWS pricing, S3 Standard is ~$23/TB/month; S3 Glacier is ~$4/TB/month. A 1 PB archive running warm instead of cold costs ~$19,000 extra per month.

> [!tip] Most teams have 80% of their data older than 90 days and query it less than 5% of the time. A tiering policy often cuts storage bills by 30-60% with one afternoon of lifecycle-rule configuration.

@feynman

Like moving old files from your SSD to an external drive — still there if you need them, but you're not paying SSD prices for things you open once a year.

@card
id: depc-ch03-c007
order: 7
title: Open Table Formats
teaser: Iceberg, Delta Lake, and Hudi add ACID transactions, schema evolution, and time travel to cloud object stores — the lakehouse foundation.

@explanation

Raw Parquet files on S3 are fast and cheap but lack the guarantees that make data trustworthy in production: no atomic writes, no schema enforcement, no time travel, no efficient updates or deletes.

**Open table formats** add those guarantees while keeping the open-format benefits of the data lake:

**Apache Iceberg:** Metadata-layer approach with snapshot-based versioning, full ACID transactions, hidden partitioning, schema evolution without rewrites, and a catalog API. Integrates with Spark, Flink, Trino, Athena, Snowflake, and BigQuery.

**Delta Lake:** Originally built for Databricks, now fully open source. Strong Spark integration, incremental processing (merge), OPTIMIZE and VACUUM maintenance operations. DeltaSharing for cross-organizational data sharing.

**Apache Hudi:** Upsert-optimized; CoW (copy-on-write) and MoR (merge-on-read) variants for different read/write tradeoff profiles. Strong streaming ingestion support.

Key capabilities all three provide:
- **ACID transactions:** concurrent writers and readers see consistent snapshots.
- **Time travel:** query the table as it was at any past snapshot.
- **Schema evolution:** add, rename, or drop columns without rewriting files.
- **Partition evolution:** change partitioning strategy without rewriting old data.
- **Efficient upserts and deletes:** GDPR deletion, CCPA, record correction without full rewrites.

Iceberg has the broadest ecosystem adoption as of 2026. Delta Lake has the deepest Databricks toolchain integration. Hudi remains strong for high-frequency upsert workloads.

> [!info] Choosing a table format is a durable architectural decision. Migrating between formats is possible but expensive. Evaluate ecosystem fit for your query engines before committing.

@feynman

Like going from a shared file folder to a proper database — you keep the files, but you gain transactions, history, and the ability to fix mistakes without starting over.
