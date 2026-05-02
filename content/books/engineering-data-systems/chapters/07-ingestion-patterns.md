@chapter
id: eds-ch07-ingestion-patterns
order: 7
title: Ingestion Patterns
summary: Moving data from where it's born to where it's useful — the patterns, trade-offs, and operational realities of the lifecycle stage that pages people most.

@card
id: eds-ch07-c001
order: 1
title: Ingestion Is The Riskiest Stage
teaser: Most pipeline outages happen at the source-to-storage seam. Investing in ingestion robustness pays back faster than investment anywhere else in the lifecycle.

@explanation

Ingestion sits at the boundary between systems you don't control (sources) and systems you do (storage). That boundary is where things break:

- **Source goes down** — your ingestion can't read.
- **Source schema changes** — your parsing breaks.
- **Source slows down** — your batch window blows past its SLA.
- **Network partitions** — half your records arrive, the other half don't.
- **Auth tokens expire** — the connector silently stops working.
- **Volume spikes** — a marketing push triples the rate; your ingestion falls behind.

The good news: ingestion failures are usually loud. Pipelines fail; alerts fire; you fix the connector. The bad news: silent ingestion bugs (partial loads, dropped records, schema drift handled by null-fill) cause downstream pain that's much harder to diagnose months later.

Investment priority: observability (you know what's happening), idempotency (replays are safe), and replayability (you can recover from a window of bad data) — in that order.

> [!info] When a downstream consumer reports "data looks wrong," the most productive first hypothesis is an ingestion bug from days or weeks ago. Look there before tuning transformations.

@feynman

Same as the network layer in distributed systems — most bugs live at the seams between systems, not inside any one of them.

@card
id: eds-ch07-c002
order: 2
title: Batch Versus Streaming
teaser: The defining choice in ingestion design — process data in scheduled windows or as events arrive. Each model has its sweet spot and its operational cost.

@explanation

**Batch ingestion** runs on a schedule — every hour, every day, every week. Pulls a window of data, processes it, lands it in storage, exits. Examples: nightly Snowflake load from operational DB, hourly file pickup from S3.

Wins: simpler, cheaper, easier to reason about. Failure recovery is "re-run the batch." Operational burden is low.

Losses: data freshness is bounded by batch frequency. Hourly batch means the freshest data is up to an hour old.

**Streaming ingestion** consumes data continuously as it's produced. Long-lived processes pulling from Kafka, processing CDC streams, handling webhook calls. Examples: real-time event ingestion from app, CDC stream from production DB.

Wins: data is fresh within seconds. Downstream systems can react in near-real-time.

Losses: operational complexity is much higher. State management, checkpointing, exactly-once semantics, backpressure all become concerns.

Reality: most teams over-build for streaming. Batch is the right answer when downstream can tolerate hour-old data — which is most analytical use cases. Streaming earns its keep when freshness genuinely drives business value (fraud detection, real-time personalization, operational dashboards).

> [!tip] Default to batch unless a specific consumer requires streaming. The complexity tax of streaming pays back only when the freshness genuinely matters.

@feynman

Same trade-off as cron job vs always-on service — simpler is usually better unless the requirements force the complex one.

@card
id: eds-ch07-c003
order: 3
title: ETL Versus ELT
teaser: The order of "transform" and "load" matters more than it sounds. The shift from ETL to ELT is one of the defining architectural changes of the cloud-warehouse era.

@explanation

**ETL — Extract, Transform, Load.** Pull data from source. Transform it (clean, join, model) in some intermediate compute. Load the transformed result into the warehouse. The classic pattern from when warehouse compute was scarce and expensive.

**ELT — Extract, Load, Transform.** Pull data from source. Load it raw into the warehouse. Transform it inside the warehouse using its own compute. The pattern that won as cloud warehouses made compute cheap.

Why ELT won:

- **Cheap warehouse compute** — Snowflake, BigQuery, Databricks made it affordable to do transformations at warehouse scale.
- **Reproducibility** — raw data is preserved; if a transformation has a bug, you re-transform without re-extracting.
- **Tooling** — dbt, Coalesce, and similar tools made warehouse-native transformation pleasant.
- **SQL accessibility** — analytics engineers can build ELT pipelines; ETL often required Python/Scala/Java specialists.

Where ETL still makes sense:

- **Sensitive data masking** — strip PII before it lands, not after.
- **Bandwidth constraints** — when the source-to-warehouse link is expensive, transform first to reduce volume.
- **Legacy systems** — many enterprise integrations are still pure ETL.
- **Streaming transformations** — Flink, Kafka Streams transform in flight.

The current convention: ELT for analytics; ETL when sensitivity or bandwidth dictates; streaming transformations as their own thing.

> [!info] When ELT is feasible, choose it. When you choose ETL, document why — most "we should ETL" arguments don't survive five years of cheap warehouse compute.

@feynman

Same trade-off as compile-time vs runtime — ETL pays the cost up front, ELT defers it. Cheap runtime makes deferring the better choice.

@card
id: eds-ch07-c004
order: 4
title: Push Versus Pull
teaser: Does the source send data to you, or do you go and get it? The choice shapes ownership, latency, and where complexity lives.

@explanation

**Pull (you fetch).** Your code requests data from the source on a schedule or trigger. Examples:

- Querying a database for new rows since the last watermark.
- Polling an API for changes.
- Listing an S3 bucket for new files.

Pros: full control over rate, timing, retry policy. The source doesn't need to know you exist.
Cons: latency is bounded by polling frequency. Catching every change requires either fast polling (expensive) or change tracking (complex).

**Push (source sends).** The source pushes events to you as they happen. Examples:

- Webhooks from a SaaS service.
- Kafka topics where producers publish events.
- Database CDC streams (technically a pull from the WAL, conceptually a push to the consumer).

Pros: low latency. Source-driven.
Cons: you must run a reliable receiver. Replays and missed messages need their own handling. The source dictates the data shape and rate.

Hybrid is common: subscribe to a stream for fresh data, periodically reconcile against the source via pull to catch anything dropped.

> [!warning] Webhook receivers are easy to build wrong. They must be highly available, idempotent (the source will retry), and capable of handling burst loads. Most teams underbuild them at first.

@feynman

Same as polling vs WebSockets in web apps — simpler vs fresher, with different operational profiles.

@card
id: eds-ch07-c005
order: 5
title: Full Refresh Versus Incremental
teaser: Re-loading the world every run is simple but expensive. Incremental is efficient but requires you to track state. Picking depends on data shape and tolerance.

@explanation

**Full refresh.** Every run pulls the entire source dataset. Loads it as the new version of the table. Discards (or archives) the previous version.

Pros: trivial correctness — whatever the source has now is what you have. No state to manage. Easy to recover from bugs (just re-run).
Cons: expensive at scale. A daily full refresh of a 1B-row table is not viable.

**Incremental.** Each run pulls only what's changed since the last successful run. Common keys for "what's changed":

- **Modified timestamp** — `WHERE updated_at > last_high_water_mark`.
- **Sequence ID** — `WHERE id > last_id`.
- **CDC offset** — Kafka offset, WAL position.

Pros: efficient. Daily volume is the daily change rate, not the total dataset size.
Cons: requires state management (where did we leave off?). Misses deletes unless you've designed for them. Misses out-of-order updates if the modified field isn't reliable.

Decision matrix:

- **Small data** (< 1M rows) — full refresh is fine; the simplicity wins.
- **Large append-only data** — incremental by sequence ID is the cleanest.
- **Mutable data** — incremental by modified timestamp, with periodic full refreshes to catch drift.
- **Operational source** — CDC is usually the right choice now.

> [!tip] When in doubt about incremental correctness, schedule a periodic full refresh (weekly, monthly) as a safety net. The cost is bounded; the confidence is worth it.

@feynman

Same trade-off as full backup vs incremental backup — full is simpler, incremental is cheaper, prudent setups do both.

@card
id: eds-ch07-c006
order: 6
title: Idempotency Is The Foundation
teaser: A pipeline that produces correct output when run twice with the same input is idempotent. Without idempotency, every retry is a roll of the dice.

@explanation

Pipelines fail. Networks blip. Workers die. Orchestrators retry. If your pipeline produces different output when run multiple times with the same input, retries become a source of bugs. If it's idempotent, retries are free safety.

What makes ingestion non-idempotent:

- **Appending without deduplication** — second run inserts the same rows again.
- **Auto-incrementing IDs** — a re-run produces different IDs for the same source records.
- **Side effects** — sending notifications, calling external APIs from inside the pipeline.
- **Stateful counters** — incrementing a metric without bound.

What makes ingestion idempotent:

- **Upserts on natural keys** — `MERGE` or `INSERT ... ON CONFLICT UPDATE` instead of plain `INSERT`.
- **Deterministic output paths** — file written to `s3://.../date=2026-05-02/` is always the same path regardless of run number.
- **Watermark tracking** — re-running for a window produces the same set of records.
- **No external side effects in the pipeline** — leave notifications, alerts, downstream triggers to a separate orchestration step.

Designed-in idempotency makes the operational story dramatically simpler. Replays, backfills, and retries all become safe.

> [!warning] If your pipeline can't be safely re-run, you don't have a pipeline — you have a one-shot script that pages someone whenever it fails.

@feynman

Same property that makes HTTP GETs safe to retry and POSTs not. Build for the GET model whenever you can.

@card
id: eds-ch07-c007
order: 7
title: Backfills And Replays
teaser: When something breaks, you need to re-process historical data. Pipelines built to support this stay manageable; pipelines that don't accumulate data debt forever.

@explanation

Reasons you'll need to backfill:

- **Bug in transformation logic** — historical data computed wrong; need to re-compute.
- **Schema change** — new column added; need to populate it for historical rows.
- **Source recovery** — source had bad data for a period; corrected version available; need to re-ingest.
- **New downstream consumer** — needs the dataset starting from a date earlier than current retention.

What makes backfills feasible:

- **Raw data preserved** — if the raw landing zone is immutable and complete, you can always recompute downstream.
- **Idempotent pipelines** — re-running for a window produces the same output as the original run.
- **Parameterized runs** — pipelines accept date ranges or windows as inputs; can run for arbitrary historical windows.
- **Separate backfill compute** — don't slow current pipelines by running massive backfills on the same schedule.

The hardest backfills are those where the source itself can't replay. CDC streams that have aged past retention; APIs that don't expose history; webhooks that fired once and weren't captured. The lesson: design ingestion to capture and persist raw data even if you don't immediately use it.

> [!info] A team's "backfill ergonomics" — how easy it is to re-process arbitrary windows of data — is one of the most underrated quality signals for a data platform.

@feynman

Same as having a `git revert` that actually works — preparation that costs nothing today and saves your week eventually.

@card
id: eds-ch07-c008
order: 8
title: Connectors — Build, Buy, Or Adopt
teaser: Most ingestion is plumbing between sources and storage. Pre-built connectors save enormous time; custom connectors are sometimes unavoidable.

@explanation

**Buy (managed connectors).** Vendors like Fivetran, Stitch, Airbyte Cloud offer hundreds of pre-built connectors for SaaS sources. You configure source credentials and target table; they handle ingestion, schema evolution, and failures.

Pros: fastest to value, lowest operational burden, handles vendor API quirks.
Cons: per-connector pricing adds up. Limited customization. Scaling can be expensive.

**Adopt (open source).** Airbyte (open-source version), Singer, Meltano. Same connector library, you run it.

Pros: free at the license. Customizable. No per-row pricing.
Cons: operational burden is real. Connector maintenance falls to your team. Less polished UX.

**Build (custom).** Write your own connector. For unusual sources, internal systems, or sources with specific business logic.

Pros: exactly what you need.
Cons: ongoing maintenance forever; you own every API change, every schema drift, every retry case.

The decision pattern most teams converge on:

- **Standard SaaS sources** → managed (Fivetran/Airbyte Cloud) for speed, until cost forces re-evaluation.
- **CDC from operational DBs** → managed CDC (Debezium-based) or vendor (Fivetran's offering).
- **Internal sources, files, custom APIs** → build it; nobody sells a connector for your bespoke system.

> [!tip] Calculate the loaded cost of "free" — engineer-weeks to build, plus ongoing maintenance. Compared properly, managed connectors are usually cheaper than custom builds for standard sources.

@feynman

Same as build vs buy for any tool — buy what's commodity, build what's differentiating.

@card
id: eds-ch07-c009
order: 9
title: Ordering, Exactly-Once, And At-Least-Once
teaser: Three guarantees that sound like they should be cheap and aren't. Understanding the trade-offs prevents the most expensive ingestion mistakes.

@explanation

**At-most-once delivery.** Each event delivered zero or one times. Simplest, but you might lose data. Rarely acceptable for analytics.

**At-least-once delivery.** Each event delivered one or more times. Easy to achieve; downstream must handle duplicates. The realistic default.

**Exactly-once delivery.** Each event delivered precisely once. Theoretically requires distributed coordination. Some systems claim it (Kafka with idempotent producers, Flink with checkpointing); the guarantee usually has fine print.

**Ordering guarantees** orthogonal:

- **Per-partition ordering** — events within a partition arrive in order. The standard Kafka guarantee.
- **Global ordering** — all events arrive in source order. Hard at scale; usually requires single-partition processing, which doesn't scale.
- **No ordering** — events arrive in any order. Common for asynchronous push systems.

The realistic engineering posture: design for at-least-once delivery with idempotent processing. That gets you exactly-once *effects* even if delivery is technically at-least-once. Don't depend on global ordering unless your throughput is low enough to support a single-partition consumer.

> [!warning] When a vendor claims "exactly-once delivery," read the fine print. It usually requires specific producer config, specific consumer config, and breaks under specific failure modes.

@feynman

Same fundamental impossibility as distributed transactions. Get it close enough with idempotency, not perfect with coordination.

@card
id: eds-ch07-c010
order: 10
title: Backpressure And Buffering
teaser: When downstream can't keep up with ingestion, what happens? Pipelines without an answer drop data, crash, or silently fall behind.

@explanation

Backpressure is the pressure that propagates upstream when downstream is overloaded. Three strategies for handling it:

- **Buffer** — hold incoming data in a queue while downstream catches up. Works until the buffer fills.
- **Drop** — discard data once the buffer fills. Sometimes acceptable (sampled telemetry); usually not.
- **Block / slow down** — stop accepting new input until downstream drains. Propagates pressure further upstream.

What systems offer:

- **Kafka** — buffers at the broker; consumers can fall behind for as long as retention allows. Producer can block if the broker is full.
- **Kinesis** — similar; throttling at write side when downstream lags too far.
- **Webhooks** — usually no buffer; if your receiver is overloaded, the source drops or retries.
- **File-based ingestion** — files queue up at the source location; you fall behind silently.

What to design:

- **Sized buffers** — explicit, monitored. When buffer hits 80%, alert.
- **Backpressure-aware consumers** — process at a sustainable rate; don't accept faster than you can land.
- **Spillover storage** — when the primary buffer fills, spill to cheaper but slower storage (S3 buffer for Kafka overflow).
- **Sampling under pressure** — for non-critical data, drop or sample when overloaded.

> [!info] Pipeline lag (consumer offset behind producer) is one of the most predictive operational metrics. Watch it closely; alarm when it grows.

@feynman

Same problem as TCP flow control — sender must adjust to receiver's rate, or things break loudly.

@card
id: eds-ch07-c011
order: 11
title: Schema Registry — A Contract Between Producer And Consumer
teaser: When data flows through Kafka or similar, a schema registry enforces what producers can publish and what consumers can expect.

@explanation

In streaming systems, the producer and consumer are decoupled — they don't talk directly. Without a schema registry, the producer can change the message shape and consumers break silently.

A schema registry (Confluent's, AWS Glue Schema Registry, Apicurio) sits between them:

- **Producers register their schema.** Each topic has one or more schemas.
- **Producers serialize against the schema.** Avro, Protobuf, JSON Schema all work.
- **Consumers deserialize against the schema.** They fetch it from the registry by ID.
- **Compatibility rules enforced at the registry.** Backward-compatible changes (new optional field) are accepted; breaking changes (removing a field, changing a type) are rejected.

The wins:

- **No silent breakage.** Incompatible producer changes fail fast.
- **Independent evolution.** Producers and consumers can deploy on different schedules.
- **Discoverability.** New consumers can find schemas to integrate against.

The cost: another piece of infrastructure to run; integration work in producer/consumer code; learning curve for compatibility rules.

In practice, schema registries are essential at scale and overkill for small Kafka deployments. The decision point is when you have enough producers and consumers that informal coordination breaks down.

> [!info] If you have more than 10 services producing to Kafka, you need a schema registry. The day your team starts breaking each other in production is the day you wished you'd set one up six months earlier.

@feynman

Same role as `package.json` versioning between services — formalizes a contract that's otherwise carried in everyone's head.

@card
id: eds-ch07-c012
order: 12
title: Observability For Ingestion
teaser: You can't operate ingestion you can't see. The metrics that matter aren't generic — they're specific to what ingestion actually does.

@explanation

The minimum metrics every ingestion pipeline needs:

- **Run status** — succeeded / failed / in-progress, last run timestamp.
- **Lag** — how stale is the data in the destination relative to the source? Often the most user-facing metric.
- **Volume** — rows/events ingested per run; sudden drops or spikes indicate trouble.
- **Schema drift** — alerts when source schema changes unexpectedly.
- **Quality checks** — null rates, range checks, uniqueness, completeness for critical fields.
- **Latency** — for streaming, end-to-end latency from source emit to destination availability.

Tools that help:

- **Pipeline orchestrators** (Airflow, Dagster, Prefect) — first-class run status and history.
- **Data observability platforms** (Monte Carlo, Bigeye, Lightup) — schema drift, freshness, anomaly detection on top of pipelines you've already built.
- **dbt tests** — assertion checks that fail when data shape goes wrong.
- **Custom alerts** — for the metrics that don't fit the platforms above.

The discipline that distinguishes mature teams: every ingestion pipeline has a defined SLA (e.g., "data fresh within 30 minutes 99% of the time") and metrics that prove whether the SLA is met.

> [!tip] If a pipeline is "running fine" by orchestrator status but downstream is complaining about staleness, your observability is missing freshness checks. Add them.

@feynman

Same as monitoring HTTP services — uptime is necessary, latency and error rate are the actually-useful metrics.

@card
id: eds-ch07-c013
order: 13
title: Data Quality Gates At Ingestion
teaser: Quality issues are easiest to catch at the boundary. Letting bad data into the warehouse means every downstream consumer pays.

@explanation

Two philosophies for handling bad data:

- **Reject bad data at the door.** Schema mismatches, null required fields, out-of-range values — fail the ingestion, alert, don't write.
- **Land everything, flag bad data.** Always land the raw data; tag bad rows with quality flags; let downstream decide.

The hard-line "reject" philosophy keeps the warehouse clean but can paralyze ingestion when sources have any messiness. The lenient "land everything" approach keeps pipelines running but pushes the cleanup tax everywhere downstream.

The pragmatic middle:

- **Land raw data without modification.** Always. The raw landing zone is the recoverable record.
- **Run quality checks at landing.** Flag issues; alert on regressions; don't block ingestion of the rest.
- **Reject at the next layer.** Curated/silver tables enforce stricter contracts. Bronze keeps everything; silver only accepts what passes checks.
- **Quarantine bad data.** Don't drop it; route it to a quarantine path where someone can investigate.

Tools that help: Great Expectations, dbt tests, Soda, Monte Carlo. The common pattern is declarative quality expectations checked on every run.

> [!info] The cost of a bad-data incident scales with how far it propagates before being caught. Quality gates at ingestion catch issues before they touch dashboards or models.

@feynman

Same idea as input validation — defend at the boundary, not deep in the business logic where everything has already been touched.
