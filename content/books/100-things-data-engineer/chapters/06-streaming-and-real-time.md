@chapter
id: tde-ch06-streaming-and-real-time
order: 6
title: Streaming and Real-Time
summary: Streaming is powerful and expensive — understanding when it's genuinely required, how Kafka and Flink work under the hood, and where the operational complexity hides will save you from over-engineering the majority of pipelines that batch handles fine.

@card
id: tde-ch06-c001
order: 1
title: When Streaming Is Actually Necessary
teaser: "Real-time" is on every requirements doc, but most systems that claim to need streaming run fine on batch with short intervals — and the ones that don't share a specific profile.

@explanation

Streaming infrastructure carries a real cost: operational complexity, Kafka clusters to manage, consumer lag to monitor, schema registries to maintain, and engineers who understand stateful processing. Before reaching for it, be clear on whether you genuinely need it.

The cases that legitimately require streaming:

- **Fraud detection** — a payment must be accepted or declined in under 200ms. By the time a batch job runs, the transaction has cleared.
- **Live leaderboards** — standings that update as events occur, not once an hour.
- **Operational monitoring** — detecting that a service is returning errors right now, not after a 5-minute batch window.
- **Event-driven side effects** — triggering a downstream action (send notification, update inventory) as soon as an event occurs.

The cases that don't require streaming but often get it anyway:

- A dashboard that refreshes every 5 minutes. Batch with a 5-minute schedule is simpler, cheaper, and equally correct.
- An ML feature store that tolerates 15-minute staleness. Micro-batch on Spark handles this without a streaming cluster.
- Analytics queries over the last 24 hours. Any data warehouse works.

The honest rule of thumb: if a human wouldn't notice a 5-minute delay, you probably don't need streaming. Reach for it when the business consequence of latency is measured in seconds, not minutes.

> [!warning] "We might need real-time someday" is not a requirement. Build for batch, leave room to add streaming if the latency requirement materializes — retrofitting is much cheaper than maintaining a streaming pipeline that never needed to exist.

@feynman

Adding streaming to a pipeline that doesn't need it is like buying a race car for a commute because you might someday drive on a track — it solves a problem you don't have and creates ones you weren't expecting.

@card
id: tde-ch06-c002
order: 2
title: Apache Kafka Fundamentals
teaser: Kafka is not a queue — it's a distributed, durable, ordered log, and that single distinction explains most of its behavior, guarantees, and limitations.

@explanation

Kafka organizes data into **topics**. Each topic is divided into **partitions** — ordered, append-only sequences of records. Each record in a partition has an **offset**: an immutable, monotonically increasing integer that identifies its position. Producers write records to topics; consumers read them by tracking their current offset.

The key design decisions that make Kafka useful:

- **Log-based storage.** Records are written to disk and retained for a configurable period (7 days by default). The log is the source of truth, not an ephemeral buffer. This means consumers can re-read data and pipelines can replay historical events without a separate archive.
- **Durability via replication.** Each partition is replicated across multiple brokers (typically 3). A producer write is acknowledged only after a configurable number of replicas confirm receipt. Losing a broker doesn't lose data.
- **Retention period as time machine.** Set retention to 30 days and you can replay any consumer from any point within that window. This is the escape hatch for reprocessing after a bug.
- **Partition as unit of parallelism.** A partition can be consumed by only one consumer in a consumer group at a time. With 12 partitions, you can have at most 12 parallel consumers in a group — more consumers than partitions and some sit idle.

Kafka does not guarantee ordering across partitions, only within a single partition. If you need all events for a given user to be ordered, route them to the same partition using the user ID as the partition key.

> [!info] The retention period is not a backup strategy. It's a replay buffer. For long-term archival, sink Kafka topics to object storage (S3, GCS) via a connector — don't rely on extended broker retention for that job.

@feynman

A Kafka topic is like a time-stamped newspaper printing press — every edition is published in order, kept on file for a set period, and any subscriber can request to start reading from any edition in the archive.

@card
id: tde-ch06-c003
order: 3
title: Consumer Groups and Partition Assignment
teaser: A consumer group is the mechanism that lets multiple processes share the work of reading a topic — and the partition count is the hard ceiling on how much parallelism you can actually get.

@explanation

A **consumer group** is a named set of consumers that collectively read a topic. Kafka assigns each partition to exactly one consumer in the group at any time. This provides both load distribution and ordered processing: within a partition, messages are processed in order by a single consumer.

The implications:

- If you have 8 partitions and 4 consumers in a group, each consumer handles 2 partitions.
- If you have 8 partitions and 12 consumers, 8 consumers are active and 4 sit idle. You've wasted 4 instances.
- If you want more parallelism than you have, you need to increase the partition count first — this is a forward-planning decision made at topic creation because repartitioning an existing topic is disruptive.

**Offset tracking** is how consumers record progress. A consumer commits its offset to Kafka after processing a batch. If the consumer crashes and restarts, it resumes from the last committed offset. Unprocessed records in that batch will be reprocessed — Kafka's default delivery guarantee is at-least-once.

**Offset reset policy** governs what happens when a consumer group has no committed offset for a partition (new group, or retention expired):
- `earliest` — start from the oldest available record. Use this for reprocessing.
- `latest` — start from the newest record, skipping everything before now. Use this for new consumers that should only process future data.

**Rebalancing** occurs when a consumer joins or leaves the group. During a rebalance, partition assignments are redistributed and consumption pauses briefly. Frequent rebalances (caused by consumers crashing, slow processing triggering session timeouts, or rolling restarts) are a top source of consumer lag spikes.

@feynman

A consumer group is like a team of workers splitting a stack of numbered folders — each worker takes their pile and processes in order, but if one leaves, the folders get redistributed and everyone pauses while the new assignments are handed out.

@card
id: tde-ch06-c004
order: 4
title: Event Time vs Processing Time
teaser: When an event happened and when your pipeline saw it are two different things — and aggregating on the wrong one produces numbers that are quietly wrong in ways that are hard to debug.

@explanation

Every event in a stream has two timestamps:

- **Event time** (`event_time`): when the event actually occurred in the source system. A payment was made at 14:03:22. A sensor reading was recorded at 09:17:44. This is the timestamp embedded in the event payload.
- **Processing time** (`processing_time`): when the pipeline received and processed the event. This is assigned by the stream processor on ingestion.

In an ideal world these are the same. In production, they diverge for several reasons: mobile clients that buffer events offline, network delays, upstream system backlogs, or late-arriving records replayed from Kafka.

Why this matters for aggregations: suppose you want hourly revenue totals. If you use processing time, a payment that occurred at 14:58 but arrived late at 15:03 gets counted in the 15:00 hour instead of the 14:00 hour. Your hourly report is wrong, and the error is invisible unless you compare against a ground-truth batch.

**Watermarks** are the mechanism for handling this gap. A watermark is a signal the stream processor emits that says "I believe all events with event_time before T have now arrived." When the watermark advances past a window's end time, the processor closes and emits that window's result. The watermark's lag behind the current processing time is your tolerance for late data.

Setting the watermark too tight drops late events silently. Setting it too loose delays results. The right value depends on the observed lateness distribution in your data — measure it in production before committing to a strategy.

> [!tip] Always log both timestamps. Being able to compare event_time and processing_time in production is how you diagnose whether lateness is a problem and how bad it is.

@feynman

Event time vs processing time is like the difference between when a letter was written and when the post office sorted it — a daily letter count based on sorting time will miss letters that arrived a day late, even though they were written on time.

@card
id: tde-ch06-c005
order: 5
title: Stream Processing with Apache Flink
teaser: Flink is the dominant open-source stream processor for stateful, exactly-once workloads — and understanding its execution model tells you both what it's good at and what it costs.

@explanation

Apache Flink is a distributed stateful stream processor. Its core abstractions are the **DataStream API** (operator-level control) and the **Table API / SQL** (higher-level, SQL-compatible). For most new work, the Table API is the right starting point — it's more expressive and Flink's optimizer improves it.

Key Flink concepts:

- **State** is first-class. Flink operators can maintain keyed state (e.g., running totals per user) and the framework manages that state's lifecycle, durability, and redistribution across rescaling.
- **Windowing** divides the stream into bounded chunks for aggregation: tumbling (non-overlapping fixed-size intervals), sliding (overlapping), session (gap-triggered, variable-size), and global (entire stream, user-controlled).
- **Checkpointing** is Flink's fault tolerance mechanism. At regular intervals (typically every 30–60 seconds), Flink snapshots operator state to durable storage (S3, HDFS). On failure, Flink restores from the last checkpoint. This is what makes exactly-once processing possible.
- **Exactly-once semantics** end-to-end require coordinated sinks. Flink achieves this with a **two-phase commit** pattern: the sink writes in a pending state and only finalizes when the checkpoint completes. Kafka sinks and JDBC sinks support this; not all sinks do.

**Flink vs Spark Streaming:** Spark Structured Streaming is micro-batch — it processes records in small batches on a schedule (sub-second to seconds). Latency is higher, but the programming model is simpler and it reuses the Spark ecosystem. Flink is true record-at-a-time streaming, with lower latency and more sophisticated state management. For sub-second requirements or complex stateful topologies, choose Flink. For teams already on Spark with moderate latency needs, Structured Streaming is often sufficient.

@feynman

Flink's checkpoint-and-replay model is like a video game save state — if the job crashes, you restore from the last checkpoint and replay only the events that happened after it, arriving at the same correct result every time.

@card
id: tde-ch06-c006
order: 6
title: Windowing Operations
teaser: Your window type is not a configuration detail — it's a statement about the business question you're answering, and choosing the wrong one gives you answers to a question you weren't asking.

@explanation

A window groups stream records into bounded sets for aggregation. The three types you'll use most:

**Tumbling windows** — fixed size, non-overlapping. A new window opens the moment the previous one closes. Example: revenue per hour, computed for exactly one hour at a time. Every record belongs to exactly one window. Use when you want a clean, non-overlapping summary. 24 1-hour windows per day, no overlap.

**Hopping (sliding) windows** — fixed size, but they advance by a smaller fixed step. Example: "rolling 1-hour total, updated every 10 minutes." This produces 6× more windows than a tumbling window of the same size, and each record appears in multiple windows (the overlap factor). Use when you want a continuously updating view of a trailing period.

**Session windows** — gap-triggered, variable size. A new session starts when the gap between consecutive events exceeds a threshold (e.g., 30 minutes of inactivity). Use for user activity sessions where the "window" is defined by the user's behavior, not a clock.

**Late data handling** differs by window type. Once a watermark advances past a window's end, the window is closed and emitted. Records arriving after that are either dropped, counted in a side output, or used to update the result if you've configured allowed lateness (Flink supports this explicitly). Tumbling and hopping windows have a clear close time; session windows close when the gap is observed, so late events can extend an already-closed session if they arrive within the allowed lateness.

Mismatched window types are a common source of metric discrepancies: two dashboards showing "hourly revenue" that disagree because one uses tumbling 1-hour windows and the other uses a 1-hour hopping window with a 15-minute slide.

> [!info] When a business stakeholder asks for "rolling 30-day totals updated daily," they're describing a hopping window (30-day size, 1-day slide) — not a tumbling window, which would give them non-overlapping 30-day blocks.

@feynman

Window types are like different ways to cut a timeline into slices: tumbling is clean non-overlapping cuts, hopping is overlapping cuts moving forward step by step, and session windows let the data itself decide where each slice begins and ends.

@card
id: tde-ch06-c007
order: 7
title: Kafka Streams and ksqlDB
teaser: Not every streaming topology needs a Flink cluster — Kafka Streams and ksqlDB handle simpler, Kafka-native workloads with significantly less operational overhead.

@explanation

**Kafka Streams** is a Java/Kotlin library that runs inside your application process — there is no separate cluster to manage. You import the library, define a processing topology (filter, map, join, aggregate), and deploy it as part of your service. Kafka itself handles state backup via changelog topics and fault tolerance via consumer group rebalancing.

What makes it the right choice:
- Your entire data flow lives in Kafka — source and sink are both Kafka topics.
- The topology is relatively simple: stateless transformations, aggregations, or joins against a KTable (a changelog-backed table view).
- You want to avoid running and maintaining a Flink or Spark cluster for a use case that doesn't justify it.
- Your team is Java/JVM-first and already maintains services.

**ksqlDB** is SQL on top of Kafka Streams. You write SQL statements against Kafka topics as if they were tables. Persistent queries run continuously, updating materialized views as new records arrive. The tradeoff is expressiveness: complex stateful logic that's natural in Flink's DataStream API can be awkward or impossible in ksqlDB SQL.

When to use Flink instead:
- You need sub-second latency with exactly-once guarantees across diverse sinks (Kafka + JDBC + S3).
- Your topology has complex multi-stream joins or large managed state.
- You need fine-grained control over watermarks, late data, and state TTL.
- Your team is polyglot and needs Python or SQL support (Flink supports both via PyFlink and Flink SQL).

The rule: start with Kafka Streams or ksqlDB for Kafka-to-Kafka transformations, materialized views, and simple aggregations. Reach for Flink when those tools hit their expressiveness or performance limits.

@feynman

Kafka Streams is to Flink what SQLite is to Postgres — lighter, embedded, no separate server to run, and perfectly sufficient for the workloads it was designed for.

@card
id: tde-ch06-c008
order: 8
title: Change Data Capture
teaser: CDC turns your operational database's write-ahead log into a real-time event stream — it's the cleanest way to integrate OLTP systems with streaming pipelines without touching application code.

@explanation

**Change Data Capture (CDC)** captures inserts, updates, and deletes from a source database and publishes them as a stream of events. The dominant tool is **Debezium**, an open-source Kafka connector that supports MySQL, PostgreSQL, MongoDB, SQL Server, and Oracle.

**Log-based CDC** (how Debezium works) reads directly from the database's replication log:
- PostgreSQL: the WAL (write-ahead log)
- MySQL: the binlog
- MongoDB: the oplog

Every committed transaction is already in this log — Debezium reads it as a secondary consumer, with minimal overhead on the primary database. The output is a Kafka topic per table, with each record containing the before and after state of the changed row.

**Query-based (table-scan) CDC** polls the table with a `WHERE updated_at > last_run` query. It's simpler to set up but has serious drawbacks: it misses deletes (no `updated_at` on deleted rows), it hammers the database with read queries, and it can't capture multiple changes to the same row within one polling interval. Avoid it for production use.

CDC solves a specific class of integration problem: OLTP databases are not designed for analytics consumption, but the data in them needs to reach your warehouse or streaming pipeline. Instead of pushing application teams to emit events, CDC extracts them automatically from the log. The streaming pipeline sees inserts and updates in near-real-time (typically sub-second with log-based CDC) without polling.

One operational note: Debezium requires that the source database has replication enabled and has sufficient log retention that Debezium can catch up if it falls behind. Losing your position in the binlog requires a full snapshot restart.

> [!warning] Log-based CDC is sensitive to schema changes. An ALTER TABLE that Debezium hasn't been told about can halt the pipeline. Pair CDC pipelines with a schema registry and a migration review process.

@feynman

CDC with a WAL reader is like tapping a wire — the database keeps doing exactly what it was doing, and you read the signal flowing through the log without the source system knowing or caring.

@card
id: tde-ch06-c009
order: 9
title: Lambda Architecture and the Kappa Simplification
teaser: Lambda architecture solved a real problem by running batch and streaming in parallel — then created a worse one by forcing you to maintain two separate implementations of the same logic forever.

@explanation

**Lambda architecture**, proposed by Nathan Marz around 2012, addressed a genuine tension: batch processing is accurate but slow; streaming processing is fast but historically hard to make accurate (state management, fault tolerance, reprocessing were unsolved in early systems). Lambda's answer was to run both in parallel:

- **Batch layer:** periodically recomputes results from the full historical dataset. Accurate, but results are hours old.
- **Speed layer:** processes the stream in real time, producing approximate recent results.
- **Serving layer:** merges results from both layers to answer queries.

The cost that became clear in practice:

- **Two code paths for the same business logic.** Compute hourly revenue in batch (SQL on Hive, Spark batch) and also in streaming (Storm, Spark Streaming). Any logic change must be made twice, tested twice, and kept in sync forever.
- **Subtle divergence between layers.** The batch result and the speed result rarely agree exactly. Debugging why they differ — and deciding which to trust — is ongoing work.
- **Operational overhead of two systems.** Two clusters, two deployment pipelines, two on-call surfaces.

**Kappa architecture** is the simplification: run only a streaming system. Use stream replay (from Kafka's retention, or from an event archive in S3) to reprocess historical data when you need accurate historical results. One code path, one cluster, one deployment. The prerequisite is a stream processor mature enough to handle both real-time and reprocessing workloads correctly — Flink and Spark Structured Streaming both qualify today.

Lambda is still appropriate when your batch and stream layers use genuinely different algorithms (e.g., a complex batch ML pipeline that can't run record-at-a-time), but for most aggregation and transformation workloads, Kappa is the right default.

@feynman

Lambda architecture is like keeping two separate codebases for mobile and web that share a product spec — they start in sync, drift over time, and the maintenance cost eventually exceeds any benefit over building a single responsive app.

@card
id: tde-ch06-c010
order: 10
title: Streaming Pipeline Operational Concerns
teaser: The hardest part of running a streaming pipeline is not building it — it's knowing it's healthy, catching when it's not, and having a runbook ready before things go wrong at 2 a.m.

@explanation

The primary health metric for a streaming pipeline is **consumer lag**: the number of messages in a partition that the consumer has not yet processed. Lag of zero means the consumer is caught up. Growing lag means the consumer is falling behind the producer. A lag alert threshold of, say, 100,000 records on a high-volume topic is meaningless if the consumer normally processes a million records per second — calibrate thresholds to your typical steady-state lag.

Operational concerns to instrument and alert on:

- **Consumer lag per partition and per consumer group.** A single slow partition is easy to miss in aggregate metrics.
- **Broker disk usage.** Kafka retention is time-based by default; on high-throughput topics, disk can fill before the retention window expires if you haven't sized appropriately.
- **Rebalancing frequency.** Frequent rebalances are a symptom: consumers crashing, processing taking longer than the session timeout, or a rolling restart not staggered correctly. A consumer group stuck in a rebalance loop — joining, triggering rebalance, crashing before completing it — will stop processing entirely.
- **Schema registry availability.** If your producers and consumers depend on a schema registry (Confluent Schema Registry, AWS Glue Schema Registry), it is a hard operational dependency. Registry downtime typically halts production. Monitor it with the same urgency as the brokers.

**Runbook for a consumer group stuck in rebalancing:**
1. Check consumer group status with `kafka-consumer-groups.sh --describe`.
2. Identify which consumers are in a `PreparingRebalance` or `CompletingRebalance` state.
3. Check consumer logs for the session timeout error: `Heartbeat session expired`.
4. Increase `session.timeout.ms` and `max.poll.interval.ms` if processing time is the cause.
5. If consumers are crash-looping, fix the application error before restarting; otherwise the rebalance storm recurs immediately.

> [!tip] Set up a dead-letter topic for records that fail deserialization or processing. Without one, a single malformed record can block an entire partition indefinitely.

@feynman

Running a streaming pipeline without consumer lag monitoring is like running a production service without latency metrics — you'll only know it's broken when someone downstream notices the silence.
