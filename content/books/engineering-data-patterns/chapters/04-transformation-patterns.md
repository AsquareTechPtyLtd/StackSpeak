@chapter
id: depc-ch04-transformation-patterns
order: 4
title: Transformation Patterns
summary: How data moves from raw to useful — staging, idempotent writes, late arrivals, deduplication, and replay-friendly design — the patterns that make transformations safe to run more than once.

@card
id: depc-ch04-c001
order: 1
title: The Transformation Problem
teaser: Transformation is where raw data becomes useful data. It's also where most data quality problems and pipeline reliability failures live.

@explanation

Transformation takes data from its raw source shape and turns it into something consumable: cleaned, joined, aggregated, deduplicated, and shaped for the people and systems downstream.

The recurring pressures:

**Correctness:** A transformation that runs on bad input can silently produce bad output. How do you know the transformation result is right without re-running it on known-good data?

**Idempotency:** Transformations run multiple times — due to failures, retries, and backfills. A transformation that produces different results on the second run is dangerous.

**Late arrivals:** Data from yesterday might arrive today. A daily transform that closed at midnight missed it. How do you incorporate it without re-running the entire history?

**Scale:** A transformation that ran in 10 minutes on 10 GB may run in 8 hours on 10 TB if it wasn't designed for scale from the start.

**Testability:** A SQL transformation buried in a pipeline with no isolated test is a liability. Any future change might silently break it.

The patterns in this chapter address these pressures directly.

> [!info] Most transformation bugs are discovered downstream, not at the transformation step. Tests at the transformation layer surface them before they reach consumers.

@feynman

Same as software: correctness, testability, and resilience to failure are harder to retrofit than to design in.

@card
id: depc-ch04-c002
order: 2
title: Staging Then Mart
teaser: Land raw data in a staging layer before transforming it into consumption models. Separating ingest from transform makes both safer.

@explanation

**Staging-then-mart** separates the ingestion and transformation steps into distinct layers, with a staging area as a buffer between them.

The flow:
1. **Ingest → Staging:** raw data lands in the staging layer as-is, with only source-system fidelity preserved. No joins, no business logic, minimal cleaning.
2. **Staging → Mart:** a separate transformation job (usually dbt or Spark) reads from staging and produces the consumption model (fact tables, dim tables, aggregates).

Why the separation matters:
- **Debuggability:** when the mart has wrong data, you can inspect the staging layer to determine whether the problem is upstream (source) or downstream (transformation).
- **Independent scheduling:** the ingestion job and the transformation job can have different retry logic, dependencies, and SLAs.
- **Safe re-runs:** clearing and re-running the mart doesn't require re-running ingestion from the source. The staging layer acts as a buffer.
- **Audibility:** staging tables preserve the "as received" record. If a source system disputes a value, you have the original data.

In a dbt project, staging models are the `stg_` models that select directly from raw source tables; mart models are the `fct_` and `dim_` models that build on staging.

> [!tip] Never join staging tables directly in a downstream dashboard query. Every staging-to-consumption transformation should go through an explicitly-tested mart model.

@feynman

Like having a loading dock and a storeroom — materials arrive at the dock in any shape; the storeroom is organized for the people who need to find things.

@card
id: depc-ch04-c003
order: 3
title: Idempotent Writes
teaser: Design transformations so that running them twice produces exactly the same result as running them once. Retries, backfills, and duplicate scheduling all become safe.

@explanation

An **idempotent write** produces the same result regardless of how many times it's executed. This is the single most important property for production pipeline reliability.

Why idempotency matters:
- Airflow DAGs retry failed tasks automatically.
- Cloud scheduler services (Cloud Composer, MWAA) occasionally schedule the same run twice.
- Engineers manually trigger backfills that overlap with already-processed date ranges.
- Network timeouts cause operations to re-run without confirmation the first attempt succeeded.

Patterns for idempotent writes:

**Partition overwrite:** delete the output partition before writing, then write the new result. In Spark: `df.write.mode("overwrite").partitionBy("date").parquet(path)`. Any re-run for a given date deletes and rewrites that date's partition only.

**Merge/upsert:** use the table format's MERGE operation to insert-or-update based on a unique key. Delta and Iceberg support this natively.

**Insert-then-deduplicate:** land all rows from every run; downstream queries deduplicate on a unique key or by selecting the latest version.

**Truncate-and-reload:** delete the entire destination and rewrite from staging. Simple but only viable when full recompute is fast.

What makes a write non-idempotent (and dangerous):
- `INSERT INTO` without a prior `DELETE` or merge — every re-run appends duplicates.
- Sequence-number generation inside the transform — each run generates different IDs for the same rows.
- Side effects (email sends, API calls) that shouldn't fire twice.

> [!warning] `INSERT INTO` is almost never the right write pattern for a scheduled pipeline. Default to partition overwrite or MERGE instead.

@feynman

Like a form that can be submitted multiple times safely because it checks whether you already submitted and skips if so.

@card
id: depc-ch04-c004
order: 4
title: Late-Arriving Data Handling
teaser: Data from yesterday arrives today. Data from last month arrives this week. How you handle late arrivals determines whether your historical reports stay accurate.

@explanation

**Late-arriving data** occurs when an event's event_time is earlier than its ingestion_time — the event happened before it was recorded in your system.

Common causes:
- Mobile clients on poor connectivity batch their events locally and flush hours or days later.
- Third-party systems export data on a delay.
- CDC consumers fall behind and catch up in bulk.
- Manual data corrections are entered after the fact.

Patterns for handling late arrivals:

**Tumbling-window reprocessing:** keep the last N days of gold-layer outputs "live" (recomputable). Any row that arrives within that window triggers a recomputation of the affected day. Set N based on the observed late-arrival distribution — if 99% of events arrive within 3 days, N = 7 gives comfortable headroom.

**Event-time vs processing-time duality:** always store both the event's original timestamp (`event_time`) and when it arrived (`ingestion_time`). This lets you query "what happened on Jan 1" (filter `event_time`) separately from "what did we know on Jan 2" (filter `ingestion_time`).

**Watermarks in streaming:** in Flink or Spark Streaming, a watermark tells the processor "events earlier than T are no longer expected; close the window." Events that arrive after the watermark are either dropped or routed to a side output for later reprocessing.

**Append-and-dedup:** append all late-arriving records to the destination; run a periodic deduplication job to reconcile. Simple but less precise for time-windowed aggregations.

> [!tip] Always store `ingestion_time` alongside `event_time`. You'll need it the first time someone asks "what did the number look like on Tuesday morning" — a question that's only answerable if you tracked when data arrived.

@feynman

Like timestamping the postmark and the delivery date on a letter — you need both to know when the event happened and when you found out about it.

@card
id: depc-ch04-c005
order: 5
title: Deduplication Patterns
teaser: Pipelines produce duplicates — at-least-once delivery is the default guarantee for most systems. The question is where and how you remove them.

@explanation

Most data pipelines operate with **at-least-once delivery** semantics: every event is delivered at least once, and possibly more than once under failure or retry conditions. Deduplication converts "at least once" into "exactly once" for the consumer.

Where duplicates come from:
- CDC consumers that restart after failure replay events from the log position before the commit.
- Webhook receivers that fail after writing but before acknowledging cause the sender to retry.
- Ingestion jobs that re-read an overlapping watermark window to handle clock skew.
- Manual backfills over date ranges that were already processed.

Deduplication strategies:

**Unique key dedup:** if each record has a stable unique key (order ID, event UUID), a MERGE/upsert on that key is the simplest approach. The last write wins; or reject if the key already exists.

**Content hash dedup:** hash the full row content. Reject rows whose hash already exists in the destination. Handles cases where there's no natural unique key, but is more expensive to compute and store.

**Window dedup:** for streaming, deduplicate within a time window. A 60-minute dedup window means any duplicate of the same key arriving within 60 minutes is dropped. Events older than 60 minutes are assumed to be legitimately new records (or handled by batch reconciliation).

**Downstream query dedup:** don't deduplicate at write time; deduplicate in the consuming query using `DISTINCT` or `ROW_NUMBER() PARTITION BY key ORDER BY ingestion_time`. Cheap to implement; hides the problem rather than solving it.

Dedup at the storage layer is better than relying on downstream queries — consumers shouldn't need to know that the source can produce duplicates.

> [!warning] Dedup windows have a cost: you must hold state proportional to the window size. A 7-day dedup window on a 10 million events/day stream is 70 million keys in memory or on disk.

@feynman

Like deduplicating your email inbox by message-ID — find the duplicates by comparing a stable identifier, not by reading every email.

@card
id: depc-ch04-c006
order: 6
title: Replay-Friendly Transforms
teaser: Design transformations so they can be re-run from the beginning without manual intervention or data corruption. Backfills and disaster recovery depend on it.

@explanation

A **replay-friendly transform** can be executed from scratch on historical data and produce the same results as the incremental runs that built up those results over time.

Why this matters more than it seems:
- Every time you change a transformation's logic, you need to backfill history. If the transform is replay-friendly, this is a scheduled job; if it isn't, it's a migration project.
- Disaster recovery scenarios often require replaying all transforms from bronze on a new destination.
- A/B testing model changes requires replaying on the same historical data.

Properties that make a transform replay-friendly:

**Pure functions over data:** the output depends only on the input data and explicit parameters (like the run date). No side effects (emails, external API calls) that shouldn't fire during replay.

**Deterministic output:** the same input always produces the same output. Avoid `NOW()` or `CURRENT_TIMESTAMP` in transform logic; use the event's `event_time` instead.

**Idempotent writes:** replay writes the same destination rows as incremental writes; re-running doesn't duplicate or corrupt.

**No hard dependencies on processing order:** a replay for January should produce the same result whether it runs before or after the replay for February.

One useful test: run the transform on the same date partition twice and compare the output. If they differ, the transform is not replay-safe.

> [!tip] The easiest way to make a transform replay-friendly is to remove all use of `NOW()` in business logic and replace it with the processing date as an explicit parameter.

@feynman

Like making a function pure — given the same inputs, it always produces the same outputs, regardless of when you call it.

@card
id: depc-ch04-c007
order: 7
title: Partition Overwrite Pattern
teaser: Delete the destination partition before writing. A single, specific idempotency technique that handles most batch pipeline cases with minimal overhead.

@explanation

**Partition overwrite** is the most common idempotent write pattern for batch pipelines: before writing the results for a given time period, delete that period's partition and replace it entirely.

The mechanic:
```python
# Spark with dynamic partition overwrite
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
df.write.mode("overwrite").partitionBy("date").parquet("s3://bucket/table/")
```

With `dynamic` partition overwrite mode, Spark only overwrites the partitions present in the DataFrame — not all partitions. A run for `date=2026-05-01` overwrites only that partition; other dates are untouched.

Why it works for idempotency: if the same run is triggered twice (manual, retry, backfill), the second run deletes and rewrites the same partition. The final state is identical to a single run.

Limitations:
- **Streaming pipelines:** continuous micro-batch writers can't pause to overwrite a partition; a different strategy is needed.
- **Mid-day updates:** if the pipeline runs hourly and results accumulate within a day, overwriting at the day partition drops all hours except the current one. Use hourly partitions or a MERGE in this case.
- **Cross-run aggregations:** if the output aggregates data that spans partitions (e.g., a trailing 7-day window that needs 7 input partitions), overwrite alone isn't enough — the input range must be correct.

> [!tip] Use dynamic partition overwrite mode rather than full-table overwrite unless you genuinely need to replace the entire table. Full-table overwrite on a multi-year dataset to update one day is unnecessary and risky.

@feynman

Like `git stash && git apply` — you cleanly replace the change for that specific unit without touching anything else.

@card
id: depc-ch04-c008
order: 8
title: Merge and Upsert Pattern
teaser: Insert new rows and update existing ones in a single operation — the write pattern for tables that must handle both new records and corrections to old ones.

@explanation

**Merge (upsert)** combines insert and update logic: if a row with the matching key already exists, update it; otherwise insert a new row. It's the write pattern for tables where records can be both created and subsequently corrected.

SQL syntax (ANSI MERGE):
```sql
MERGE INTO target t
USING source s
  ON t.order_id = s.order_id
WHEN MATCHED THEN
  UPDATE SET t.status = s.status, t.updated_at = s.updated_at
WHEN NOT MATCHED THEN
  INSERT (order_id, status, created_at, updated_at)
  VALUES (s.order_id, s.status, s.created_at, s.updated_at)
```

Delta Lake, Iceberg, and Snowflake all support MERGE natively. dbt's incremental model uses MERGE when configured with `unique_key`.

When MERGE is the right write strategy:
- The source can produce both new records and corrections to existing records.
- CDC pipelines where insert/update/delete events all must be applied.
- SCD Type 1 dimensions where you want the latest value, not history.
- Tables where partition overwrite is impractical (no clear partition key, or updates span many partitions).

Performance considerations:
- MERGE is more expensive than INSERT. The database must check for each incoming row whether a match exists.
- Large MERGE operations (millions of rows) can be slow if the merge key is not indexed.
- For very high-volume tables, partition overwrite is usually faster than MERGE; use MERGE when correctness requires it.

> [!warning] MERGE on a table without a unique key on the target side will update multiple rows per source row if duplicates exist. Always verify uniqueness of the merge key in the target before relying on MERGE semantics.

@feynman

Like a database upsert in application code — the same logic, applied to entire batches of rows in a single operation.

@card
id: depc-ch04-c009
order: 9
title: Incremental Processing with dbt
teaser: dbt incremental models process only new or changed rows on each run — the practical implementation of incremental-then-merge for SQL-based transformation.

@explanation

**dbt incremental models** apply transformation logic only to rows that have changed since the last run, appending or merging the results into a destination table instead of rebuilding it from scratch.

Configuration:
```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='fail'
) }}

SELECT order_id, customer_id, amount, status, updated_at
FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
  WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

On the first run, this processes all rows (full refresh). On subsequent runs, only rows with `updated_at` newer than the last run are processed and merged.

The `unique_key` parameter determines merge behavior: rows with a matching `unique_key` are updated; rows without a match are inserted. Without `unique_key`, dbt appends without deduplication.

When dbt incrementals work well:
- Source tables have a reliable `updated_at` column.
- The incremental volume per run is small relative to the total table size.
- Full rebuilds would be too slow to run on every deployment.

When full refresh is safer:
- The transformation logic changes significantly — the incremental filter may have missed rows affected by the logic change.
- The `updated_at` column on the source isn't reliable.
- The table is small enough that a full refresh takes under 60 seconds.

> [!tip] After any change to an incremental model's SQL logic, run `dbt run --full-refresh` for that model to reprocess history with the new logic. Incremental runs after a logic change only process new rows, leaving old rows in the old shape.

@feynman

Like an append-only build cache — the first build processes everything; subsequent builds only process what changed since the last run.

@card
id: depc-ch04-c010
order: 10
title: Schema Evolution in Transforms
teaser: Source schemas change without warning. Transformation logic that hardcodes column names or types breaks silently. Build in tolerance for schema change.

@explanation

**Schema evolution** in transformation pipelines means handling source schema changes — added columns, renamed columns, type changes, dropped columns — without breaking downstream consumers.

Common failure modes when transforms don't handle schema evolution:
- A column is renamed at the source; the downstream SELECT fails with "column not found."
- A column type changes from INT to BIGINT; a comparison downstream silently overflows.
- A new column appears; the transform's `SELECT *` starts passing it downstream where it breaks a schema-strict destination.
- A column is dropped; the transform writes NULL for all downstream rows.

Strategies for evolution tolerance:

**Explicit column selection over `SELECT *`:** name the columns you need. New columns are ignored; a drop produces a clear error rather than a silent NULL.

**Schema drift detection:** validate the input schema against a registered expected schema before running the transform. Fail loudly if a breaking change is detected. Tools: dbt `on_schema_change` parameter, Glue Schema Registry, Great Expectations.

**Nullable-first design:** accept that any column might be NULL in any given run. Downstream logic should handle NULLs explicitly rather than assuming presence.

**Column aliasing for renames:** when a source renames a column, add a COALESCE or CASE to handle both the old and new names during the transition period:
```sql
COALESCE(new_column_name, old_column_name) AS canonical_name
```

dbt's `on_schema_change` setting controls behavior when the destination table schema differs from the model output: `'fail'` stops the run; `'append_new_columns'` adds new columns; `'sync_all_columns'` drops and adds to match.

> [!warning] `SELECT *` in a transformation that writes to a schema-enforced destination will fail when upstream adds a column. Use explicit column lists.

@feynman

Like a function that validates its inputs — you don't assume the caller always sends the right shape; you check and handle deviations explicitly.
