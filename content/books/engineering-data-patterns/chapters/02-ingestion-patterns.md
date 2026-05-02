@chapter
id: depc-ch02-ingestion-patterns
order: 2
title: Ingestion Patterns
summary: The recurring patterns for moving data from source systems into your storage layer — batch refresh, CDC, event sourcing, webhooks, and hybrids — with the tradeoffs that decide which fits when.

@card
id: depc-ch02-c001
order: 1
title: The Ingestion Problem
teaser: Every data system starts with the same challenge — getting data out of a system that wasn't designed to give it to you.

@explanation

Ingestion is the entry point of the data lifecycle. Data exists in operational databases, application logs, event streams, third-party APIs, files, sensors, and dozens of other systems — none of which were designed with your pipeline's needs in mind.

The recurring tensions:

- **Source coupling.** Tight coupling to a source schema means breaking changes break your pipeline. Loose coupling means you might miss important changes.
- **Freshness vs load.** The fresher you want the data, the more frequently you must query the source — and the more load you impose on it.
- **Full vs incremental.** Full refreshes are simple but expensive. Incremental updates are efficient but require reliable change detection.
- **Push vs pull.** Sources that push data to you (webhooks, streams) reduce your query burden but add operational complexity on the source side.

The patterns in this chapter resolve these tensions in different ways. No single pattern dominates — the right choice depends on the source's capabilities, the freshness requirement, and the volume of data.

> [!info] The cheapest ingestion is often the one that reads a full snapshot on a schedule — until the table has 10 million rows and the reads take two hours.

@feynman

Same first problem as any distributed system — getting a copy of data from somewhere else reliably, without breaking the source.

@card
id: depc-ch02-c002
order: 2
title: Batch Refresh
teaser: Read the entire source table on a schedule, overwrite the destination. Simple, reliable, expensive at scale.

@explanation

**Batch refresh** (also called full extraction) reads the entire source dataset at a scheduled interval and replaces the destination with the new snapshot.

How it works:
1. Extract all rows from the source (SQL `SELECT *`, API pagination, file download).
2. Write the result to the destination, replacing the previous snapshot.
3. Repeat on schedule (hourly, daily, etc.).

When batch refresh fits:
- **Small tables** — sub-million rows where a full read completes in seconds.
- **No reliable change indicator** — the source doesn't have an `updated_at` column or audit log.
- **Correctness over efficiency** — deletes in the source are automatically reflected; incremental approaches often miss them.
- **Infrequently changing data** — dimension tables, lookup tables, reference data.

When it doesn't:
- **Large tables** — a 500-million-row transaction table can't be fully read every hour.
- **Source load sensitivity** — a full table scan on a production OLTP database during peak hours is an incident waiting to happen.
- **Latency requirements** — batch refresh can't deliver sub-minute freshness.

> [!warning] Batch refresh that worked fine at 100K rows often becomes an incident at 10M rows. Build in a size threshold check from the start.

@feynman

Like backing up by copying the entire hard drive every night — works fine until the drive is a terabyte.

@card
id: depc-ch02-c003
order: 3
title: Incremental Extraction With a Watermark
teaser: Track a high-water mark and read only rows newer than the last run. Efficient, but silently misses soft deletes and updates to old rows.

@explanation

**Incremental extraction** reads only the rows that have changed since the last run, using a watermark (a timestamp or monotonically-increasing ID) to identify what's new.

Typical implementation:
```sql
SELECT * FROM orders
WHERE updated_at > :last_watermark
ORDER BY updated_at
```

After the run, persist the maximum `updated_at` seen as the new watermark for the next run.

What it does well:
- Dramatically reduces extraction volume for large tables.
- Reduces source load compared to full scans.
- Works with most SQL-capable sources.

What it misses:
- **Hard deletes.** If a row is deleted from the source, the incremental run never sees it. The destination retains the deleted row indefinitely.
- **Out-of-order updates.** If a row with an `updated_at` earlier than the watermark is updated (possible in certain insert patterns), it's silently skipped.
- **Clock skew.** If source servers have inconsistent clocks, watermark logic can produce gaps or duplicates.

Strategies to handle deletes:
- Periodic full-refresh to reconcile (e.g., weekly full + daily incremental).
- Soft-delete pattern at the source (mark rows deleted rather than removing them).
- CDC as an upgrade path when hard deletes matter.

> [!tip] Always add a small overlap — read from `last_watermark - 5 minutes` to catch late-arriving rows and clock skew. Dedup downstream.

@feynman

Like checking "what email arrived after I last checked" — fast, but you miss the ones that got deleted before you looked.

@card
id: depc-ch02-c004
order: 4
title: Change Data Capture
teaser: Read the database transaction log and stream every insert, update, and delete as an event. The most faithful representation of source changes — and the most operationally demanding.

@explanation

**Change Data Capture (CDC)** reads the source database's replication log (the write-ahead log in Postgres, the binary log in MySQL, the redo log in Oracle) and emits every row-level change as a structured event.

Tools: Debezium (open source, runs on Kafka Connect), AWS DMS, Google Datastream, Fivetran Log-Based CDC, Oracle GoldenGate.

CDC event structure (Debezium example):
```json
{
  "op": "u",
  "before": { "id": 1, "status": "pending" },
  "after": { "id": 1, "status": "shipped" },
  "ts_ms": 1714982400000
}
```

What CDC does that watermarks don't:
- Captures hard deletes (`"op": "d"`).
- Captures every intermediate state of a fast-changing row.
- Near-real-time latency (sub-second from transaction to event).

CDC operational requirements:
- The source database must have replication enabled (often it already does for HA).
- Log retention must be long enough to survive pipeline downtime.
- Consumer lag must be monitored; a lagging consumer can cause the source to retain large log volumes, eventually causing disk pressure.

When CDC fits:
- Event streaming to a warehouse or lakehouse.
- Real-time analytics with sub-minute freshness requirements.
- Audit logging (preserve every state transition, not just the current state).

When it doesn't:
- Sources without accessible transaction logs (SaaS APIs, spreadsheets, file-based sources).
- Teams without the operational capacity to manage Kafka and Debezium reliably.

> [!warning] CDC requires ongoing operational care. A stopped consumer that restarts after 48 hours against a source with 24-hour log retention has an irrecoverable gap.

@feynman

Like listening to every keystroke instead of checking the document every hour — you see everything, but someone has to keep the microphone running.

@card
id: depc-ch02-c005
order: 5
title: Log Shipping
teaser: Move application log files from source systems to your storage layer on a schedule. Simple, low-impact on the source, and the right pattern for event-log analytics.

@explanation

**Log shipping** collects application log files (access logs, error logs, event logs, audit trails) from source systems and transfers them to the analytics storage layer for querying and analysis.

Common implementations:
- **Agent-based:** Fluentd, Filebeat, or Vector runs on the source host, reads log files, and forwards to a destination (S3, GCS, Kafka, Elasticsearch).
- **Sidecar pattern:** In containerized environments, a sidecar container in each pod ships logs to a central collector.
- **Direct write:** Applications write logs directly to S3 or a message queue, skipping the file-agent layer entirely.

Log shipping fits well when:
- The data of record is the log file itself (web access logs, application events, audit trails).
- The source system cannot support database-level CDC.
- Log files are produced on predictable rotation schedules.
- The analytics use case is time-windowed (query logs from the last 7 days).

Failure modes:
- **Log rotation before pickup.** If the agent is down and the log file rotates, events are lost. Solution: agent should track file position and handle rotation atomically.
- **At-least-once delivery.** Log shipping agents typically guarantee at-least-once. Dedup on ingest if exactly-once semantics matter.
- **Parsing drift.** Log format changes (e.g., a developer adds a new field) break downstream parsers silently. Schema enforcement on ingest catches this early.

> [!tip] Treat log files as the boundary between applications and your analytics layer. Any app that writes structured JSON logs can feed your data system with minimal coupling.

@feynman

Like the postal service picking up outgoing mail — the application just drops the file, someone else handles delivery.

@card
id: depc-ch02-c006
order: 6
title: Event Sourcing and Stream Ingestion
teaser: Build your analytics foundation on an event stream rather than a database snapshot — every state is derivable from the event history.

@explanation

**Event sourcing** models the source of truth as an ordered, append-only log of events rather than a current-state table. A stream ingestion pipeline consumes this log as the data enters the analytics layer.

How it differs from CDC:
- **CDC is a retrofit** — it extracts changes from a system that wasn't designed around events.
- **Event sourcing is by design** — the source system produces events as its primary data product. The current state is a materialized view derived from the events, not the other way around.

In practice, a stream ingestion pipeline consumes events from Kafka, Kinesis, Pub/Sub, or similar, and lands them in the analytics store (warehouse, lakehouse, or stream processor).

Patterns within stream ingestion:
- **Direct landing:** consume events, write to Parquet on S3, query with Athena or Spark.
- **Micro-batch landing:** buffer events in the stream processor, write batches every 60 seconds to reduce small-file pressure.
- **Stream processing first:** apply filters, joins, or aggregations in Flink or Spark Streaming before landing.
- **Dual-write to bronze:** land raw events before any transformation, so replays are always possible.

Benefits of event-sourced ingestion:
- Replay from any point in history.
- Late-arriving event handling is a first-class concern, not a special case.
- Decoupled producer/consumer — source keeps producing even if the consumer is down.

> [!info] Kafka retention defaults to 7 days. For replay-capable pipelines, configure longer retention or use log compaction for key-based state.

@feynman

Like keeping every bank transaction vs only the current balance — more storage, but you can reconstruct any past state.

@card
id: depc-ch02-c007
order: 7
title: Push-Based Ingestion with Webhooks
teaser: Let the source system tell you when something changed rather than you asking. Lower source load, near-real-time, but harder to operate.

@explanation

**Push-based ingestion** inverts the usual pattern: instead of your pipeline querying the source, the source calls an endpoint your pipeline exposes whenever a relevant event occurs.

The most common form: an HTTP webhook. A third-party SaaS service (Stripe, GitHub, Salesforce, Twilio) sends an HTTP POST to a URL you register, containing a JSON payload describing the event.

Receiving end architecture:
1. **Webhook receiver** — a lightweight HTTP service that accepts the event, validates the signature (HMAC), acknowledges with 200, and writes the payload to a queue or storage.
2. **Queue buffer** — SQS, Pub/Sub, or Kafka absorbs spikes and decouples the receiver from downstream processing.
3. **Consumer** — downstream processor reads from the queue and writes to the warehouse or lake.

Why acknowledge immediately and process asynchronously:
- Webhook senders retry on failure. If processing takes 10 seconds and you return 200 only after processing, spikes cause timeouts and duplicate retries.
- Separating receipt from processing makes each step independently scalable and observable.

Failure modes:
- **Missed events during receiver downtime.** Most webhook providers buffer retries for 24-72 hours, but gaps remain if your receiver was down longer.
- **Signature validation skipped.** Accepting unsigned webhooks opens you to spoofing.
- **No replay capability.** Many providers don't offer event history replay. If you missed it and they stopped retrying, it's gone.

> [!warning] Always validate the webhook signature before processing. An unsigned POST endpoint in front of a database ingestion path is a security incident waiting to happen.

@feynman

Like a doorbell instead of you walking to the door every minute — more efficient, but someone has to be home to answer.

@card
id: depc-ch02-c008
order: 8
title: Snapshot-Plus-Stream Hybrid
teaser: Bootstrap a stream pipeline from a historical snapshot, then switch to live events. Solves the "stream starts from now" problem for systems with history.

@explanation

Streaming pipelines naturally start from "now." Historical data in the source isn't in the stream — it's in the database. The snapshot-plus-stream hybrid bridges this gap.

The pattern:
1. **Initial snapshot:** export the source table as of a known point in time (the snapshot LSN/SCN in CDC terms, or a timestamped export for file-based sources). Load this into the destination.
2. **Stream from snapshot point:** start the stream consumer from the same log position as the snapshot. Events that arrived after the snapshot are applied on top of it.
3. **Ongoing stream:** once the initial load is complete, the pipeline is in steady-state streaming mode.

Where this is most common:
- **Database migration to a lakehouse.** New system needs historical data + ongoing changes.
- **Analytics backfill.** Building a new model that needs history; stream-only would have a gap for months.
- **New consumer added to an existing CDC pipeline.** The existing topic starts from "now"; the snapshot bootstraps the new consumer.

Operational risks:
- **Snapshot/stream boundary drift.** If the snapshot takes longer than the stream retention window, you have a gap between the snapshot point and the earliest available stream event. Set stream retention conservatively before starting.
- **Schema evolution during bootstrap.** If the source schema changes during the initial load, the snapshot and stream may have different shapes.

> [!tip] Pin the stream consumer offset before starting the snapshot. If you start the snapshot first without pinning, you can miss events that happened during the load.

@feynman

Like syncing a file from a backup while simultaneously capturing live changes — get the history first, replay the delta to close the gap.

@card
id: depc-ch02-c009
order: 9
title: API Polling with Cursor Pagination
teaser: Systematically page through a third-party API using a cursor, storing your position so you can resume on failure and avoid re-fetching old data.

@explanation

Most third-party SaaS APIs don't offer CDC or webhooks — they offer paginated REST endpoints. Cursor-based pagination is the pattern for extracting data from these APIs reliably.

How it works:
```python
cursor = load_last_cursor()  # from persistent state
while True:
    response = api.get("/orders", params={"after": cursor, "limit": 100})
    records = response["data"]
    if not records:
        break
    write_to_destination(records)
    cursor = response["next_cursor"]
    save_cursor(cursor)  # persist before next request
```

Key design decisions:
- **Save cursor after write, not before.** If the write fails, re-read from the last saved cursor. Accept possible duplicates at the destination; dedup downstream.
- **Cursor persistence.** Store the cursor in a durable store (database, S3). In-memory cursor state dies with the process.
- **Rate limit handling.** Most APIs impose per-minute request limits. Implement exponential backoff with jitter and respect `Retry-After` headers.
- **API versioning.** The API you target today may change its response shape or deprecate the endpoint. Build in schema validation to catch changes early.

Idempotent writes + cursor persistence = a resumable, replay-safe pipeline. If the job dies halfway through a page, the next run re-reads that page and the destination deduplicates.

> [!info] Some APIs offer a `since_id` or timestamp-based cursor; others offer opaque tokens. Opaque tokens can't be backfilled — you can only go forward. Plan your initial historical load separately.

@feynman

Like reading a long book with a bookmark — you can always pick up where you left off, as long as you don't lose the bookmark.
