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
