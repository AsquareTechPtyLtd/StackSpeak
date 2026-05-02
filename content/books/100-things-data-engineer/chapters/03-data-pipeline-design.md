@chapter
id: tde-ch03-data-pipeline-design
order: 3
title: Data Pipeline Design
summary: A pipeline is a product with users, SLAs, and failure modes — the decisions you make at design time about idempotency, state, partitioning, and observability determine whether it runs reliably in production or quietly corrupts your warehouse.

@card
id: tde-ch03-c001
order: 1
title: The Pipeline as a Product
teaser: A pipeline has users, SLAs, and failure modes. The moment you treat it as a cron script instead of a product, you've committed to technical debt someone else will pay later.

@explanation

A pipeline's users are real: the analyst whose dashboard breaks when the pipeline is late, the data scientist whose model trains on stale features, the downstream system that fails a data freshness check at 9 AM. When you build a pipeline without thinking about those users, you optimize for "it works on my machine" and ship something that works until it doesn't.

Treating a pipeline as a product means four concrete things:

- **Documentation.** What does this pipeline produce? What is the schema? What are the SLAs? What does a healthy run look like? What are the known failure modes? If the answer to any of these lives only in your head, it's tribal knowledge with a timer.
- **Versioning.** Schema changes and logic changes should be tracked. An unversioned pipeline breaks its consumers silently.
- **On-call.** Someone owns the pipeline. There is a runbook. Alerts route to a person. "The pipeline just fixes itself" is not an SLA.
- **Explicit SLAs.** "The daily sales table is ready by 7 AM UTC" is a product commitment. "It usually runs overnight" is not.

The cost of treating a pipeline as a script shows up when the script runs at 3 AM, fails silently, and the first signal is an analyst filing a ticket at 10 AM. The gap between "the pipeline ran" and "the pipeline produced correct output on time" is the gap that product thinking closes.

> [!info] The question to ask before shipping any pipeline: if this fails silently at 3 AM, who finds out first — you, or the analyst whose report is wrong in the morning standup?

@feynman

A pipeline without SLAs and on-call is like deploying an API with no uptime commitment and no monitoring — it works until it doesn't, and nobody knows when it stopped.

@card
id: tde-ch03-c002
order: 2
title: Idempotency at the Design Level
teaser: The single most important design property of a pipeline is whether you can safely re-run it from any point — and most pipelines fail this test.

@explanation

Idempotency means running the pipeline multiple times produces the same result as running it once. This sounds obvious until you actually test it: can you re-run yesterday's pipeline job right now, on the same data, and get identical output without duplicating rows, double-counting revenue, or corrupting state?

The two most reliable patterns for achieving idempotency:

**Partition overwrite.** For batch pipelines writing to a partitioned table, overwrite the entire target partition rather than appending to it. If you're writing `date=2024-01-15`, delete and replace that partition on every run. This means a re-run produces exactly the same partition content regardless of how many times it runs. The risk of append-based pipelines is that a re-run doubles every row in the partition.

**MERGE/upsert for SCD targets.** For slowly changing dimension tables or any target that tracks current state, use MERGE (or equivalent upsert). Match on a natural key, update changed records, insert new ones. A re-run is safe because the MERGE logic is idempotent by definition — inserting an existing key updates it rather than creating a duplicate.

The test: pick any partition or time range. Re-run the pipeline three times in a row. Open the output table. Does it look the same as after one run? If not, your pipeline is not idempotent, and any on-call incident that requires a re-run will corrupt your data.

This matters most at 3 AM when something failed partway through and the on-call engineer needs to safely re-run without knowing exactly where execution stopped.

> [!warning] Append-on-success logic ("only append if the run succeeded") is not idempotency. It breaks the moment a run succeeds partially, which is exactly when re-runs are needed.

@feynman

Idempotency is the property that makes re-running safe — like a database UPSERT compared to an INSERT: call it twice, get the same state, not double the rows.

@card
id: tde-ch03-c003
order: 3
title: Incremental vs Full Refresh
teaser: Full refresh is simple and expensive. Incremental is fast and fragile. Picking the wrong one costs you either money or correctness.

@explanation

Full refresh pipelines recompute everything from scratch on every run. You read the entire source, apply transformations, overwrite the target. The advantages are simplicity and correctness: there is no state to manage, no watermark to track, and a re-run always produces the right output. The disadvantage is cost — reprocessing 500 GB of events every hour to produce a 10 MB summary table is wasteful.

Incremental pipelines process only new or changed records since the last successful run. You track a watermark (typically a `created_at` or `updated_at` timestamp, or a CDC offset) and process only records beyond it. The advantages are speed and cost efficiency. The failure modes are:

- **Missed records.** If your watermark is based on `created_at` and a record is inserted with a backdated timestamp, it will never be processed.
- **Broken watermarks.** If your watermark state is lost or corrupted, you either reprocess everything (expensive) or skip records (incorrect).
- **Late-arriving updates.** If rows can be updated after insertion and your watermark tracks inserts only, updates are silently missed.

Use full refresh when: the source dataset is small enough that full recomputation is cheap, the output is derived from a complex join that makes incremental hard, or correctness is more important than cost. Use incremental when: the source dataset is large, the transformation is simple, and you have a reliable watermark (CDC is better than timestamp-based for mutating sources).

> [!tip] When in doubt, start with full refresh. Switching from full refresh to incremental is a known migration path. Debugging why your incremental pipeline has silent data loss is much harder.

@feynman

Full refresh is like re-building the index from scratch every time; incremental is like applying a diff — the diff is faster but meaningless if you lose track of where you were.

@card
id: tde-ch03-c004
order: 4
title: Handling Late-Arriving Data
teaser: Events from mobile devices, IoT sensors, and distributed systems arrive late — often minutes, sometimes hours. Your pipeline needs an explicit policy for what to do with them, not an implicit assumption that they don't exist.

@explanation

Late-arriving data is the norm, not the exception, in any system where data originates outside your infrastructure. A mobile app fires an event at 11:58 PM, but the device was offline and the event is ingested at 12:15 AM — an hour after the window it belongs to has closed. This is not a bug in the data; it's a property of distributed systems.

The industry answer is watermarks: a threshold that defines "late enough to ignore." A watermark of 1 hour means events more than 1 hour behind the current processing time are considered late. Events within the watermark are held and assigned to their correct window; events beyond the watermark are handled by policy.

The three policies, with their tradeoffs:

**Drop late data.** Simple, fast, slightly incorrect. Acceptable when the lateness rate is low (say, under 0.1%) and the downstream metric can tolerate it. Not acceptable for financial or compliance data.

**Backfill affected partitions.** When a late event arrives, trigger a recomputation of the partition it belongs to. Correct but operationally expensive. Requires idempotent partition overwrites (see card 2) to be safe.

**Reprocessing window.** Keep a rolling window of "live" partitions that can still be updated (e.g., the last 3 days). Late events within the window are incorporated; late events beyond it are dropped or quarantined.

Pick your policy before you ship, not after the first analyst asks why last month's numbers changed during this morning's backfill.

> [!warning] A pipeline that silently drops late data and a pipeline that silently incorporates it at unpredictable times are both broken. The difference is which analysts are confused.

@feynman

A watermark is a cutoff beyond which the pipeline stops waiting — like a mail courier who departs at noon whether or not all the letters have arrived, but holds the truck for anything postmarked today.

@card
id: tde-ch03-c005
order: 5
title: The Exactly-Once Semantics Challenge
teaser: Exactly-once delivery is the hardest problem in distributed data systems — and most production pipelines solve it by cheating in a principled way.

@explanation

The three delivery semantics and what they mean in practice:

**At-most-once.** Send the message, don't retry on failure. Data can be lost if the write fails. Acceptable for low-stakes logging where occasional gaps are tolerable. Not acceptable for financial records or anything a downstream system counts on.

**At-least-once.** Retry on failure. Data is never lost, but can be duplicated if the write succeeded but the acknowledgment didn't. Most production pipelines operate at-least-once by default. The risk is duplicate rows that inflate counts, revenue, or event rates.

**Exactly-once.** Each record is processed and written exactly once, even in the presence of retries and failures. Genuinely hard to implement end-to-end because it requires coordination between the source, the processing system, and the sink — all of which may fail independently.

The practical answer used in most production systems: at-least-once delivery combined with idempotent sinks. If your pipeline retries a failed write and the sink handles duplicate writes gracefully (via MERGE, partition overwrite, or a deduplication key), the net effect is exactly-once-equivalent. You don't get true exactly-once semantics, but you get correct output.

The key question is whether your sink is idempotent. A MERGE on a natural key is idempotent. An INSERT is not. Partition overwrite is idempotent. APPEND is not. Design your sinks to be idempotent and you get exactly-once-equivalent behavior without needing distributed transaction support.

> [!info] "Exactly once" in marketing materials usually means "at-least-once delivery with idempotent writes" — which is correct, just not technically pure. Know what you're getting.

@feynman

Exactly-once is like a bank guaranteeing a transfer completes exactly once — easy to promise, hard to implement end-to-end without a two-phase commit that most pipelines don't have.

@card
id: tde-ch03-c006
order: 6
title: Pipeline Immutability and Audit Trails
teaser: The raw data you land should be immutable. Transformation artifacts are derived. Conflating these two produces pipelines that are impossible to audit and terrifying to reprocess.

@explanation

The raw data layer — the append-only landing zone where events, CDC records, or API payloads are written as they arrive — should never be overwritten or deleted in normal operation. This is your source of truth. Every transformation downstream is a derived artifact that can be recomputed from this layer.

Why immutability matters:

- **Replayability.** If your transformation logic changes, or you discover a bug, you can reprocess from the raw layer. If you've overwritten or deleted the raw data, that option is gone.
- **Audit trails.** Regulatory and compliance requirements often require the ability to show what data you had at a point in time. An immutable raw layer is evidence; a mutable one is not.
- **Debugging.** When a downstream table looks wrong, the first question is always "is the input correct?" If the raw layer is immutable, you can always check. If it's been modified, you can't.

The architecture this implies: raw data lands in an append-only store (object storage is common — S3, GCS, ADLS — because it's cheap and deletion is explicit). Transformation jobs read from raw and write to derived tables. Derived tables can be overwritten on reprocessing. The raw layer is never touched by transformations.

The practical implication for retention: keep raw data for as long as you might need to replay. 90 days is common for operational data; 7 years is common for financial data. Cheap storage makes this less of a tradeoff than it used to be.

> [!tip] If you ever find yourself writing a transformation that overwrites the raw landing zone, stop. You're about to delete your audit trail and your ability to replay history.

@feynman

The raw layer is the git history — you can reset to any commit because nothing is ever rewritten; the build artifacts are derived and can always be regenerated.

@card
id: tde-ch03-c007
order: 7
title: Data Partitioning Strategy
teaser: Partitioning is how you make large tables queryable at scale — but the wrong partition key or granularity creates problems that are expensive to fix after the fact.

@explanation

Partitioning divides a large table into physically separate segments that query engines can skip entirely when the filter doesn't match. A query on `date=2024-01-15` against a table partitioned by date reads only that day's data, not the full table. This is partition pruning, and on a 3-year table of event data, it's the difference between a 2-second query and a 6-minute one.

Partition key choices and their tradeoffs:

**Date (daily, the most common).** Aligns with how most batch pipelines write (one run per day) and how most analysts query (by date range). Daily granularity is right for most production pipelines. Too coarse for high-frequency streaming; too fine for low-volume tables.

**Hourly.** Useful for high-volume data where analysts regularly query sub-day windows. Risk: small files. Hourly partitions on a low-volume table produce hundreds of tiny files that most columnar query engines handle poorly. This is the "small files problem" — Spark and Hive especially suffer when partition counts are high and files are small.

**Monthly or coarser.** Useful for archival tables or low-volume data where daily partitioning is overkill. Risk: large scans when a query spans a full month to get a week's data.

**By tenant or geography.** Useful when most queries filter by a single tenant or region. Risk: uneven partition sizes if tenant volumes differ by orders of magnitude.

The practical default: partition by date at daily granularity. Add a secondary partition (e.g., by event type or region) only if query patterns require it and you understand the cardinality implications. Changing partition strategy on a live table is painful — get it right at design time.

> [!warning] Partitioning by a high-cardinality column (e.g., user_id) produces as many partitions as you have users. Most query engines will not thank you for this.

@feynman

Partitioning is like filing documents by year then month — the folder structure determines how fast you find anything; the wrong structure means searching every drawer every time.

@card
id: tde-ch03-c008
order: 8
title: Backfill Strategy
teaser: When your pipeline logic changes, you need to reprocess history — and doing that incorrectly will overwrite correct data with incorrect data before you notice.

@explanation

Backfills happen when: transformation logic has a bug that was fixed, business definitions changed (revenue is now calculated differently), a new column is added that requires recomputing historical values, or a data source was backfilled by the upstream team.

The naive approach — re-run the pipeline for all historical dates — works if and only if the pipeline is idempotent (see card 2). If it's not, re-running overwrites or corrupts existing data.

Three backfill patterns:

**Parametric backfill.** The pipeline accepts `start_date` and `end_date` parameters. Backfilling is just running the same pipeline code with a date range. This is the standard pattern. Its prerequisite is that the pipeline logic is stateless with respect to processing order — each date's output depends only on that date's inputs.

**Blue-green backfill.** Write the backfilled output to a new set of partitions (e.g., write to `table_v2` or a staging schema), validate that the output looks correct, then swap. This is the safe pattern when you're not confident the new logic is correct and don't want to overwrite good data with potentially bad data. The cost is temporary double storage.

**Incremental historical backfill.** For very large tables, process one month at a time and validate each before continuing. This limits the blast radius if the logic is wrong — you discover the problem after processing January, not after processing seven years.

Regardless of approach: always run a backfill in a non-production environment first, validate the output, then run in production. Never run a backfill directly on production tables without a rollback plan.

> [!warning] The most dangerous backfill is the one you run quickly because you're confident the fix is correct. Run slowly, validate each partition, and keep the old data until you're sure.

@feynman

A backfill is like applying a migration to a database — straightforward in a test environment, terrifying in production without a rollback path.

@card
id: tde-ch03-c009
order: 9
title: Testing a Data Pipeline
teaser: A pipeline without tests is a script you believe works. The first sign it doesn't is usually a Slack message from an analyst asking why the numbers are wrong.

@explanation

Pipeline testing has four distinct layers, each catching a different class of failure:

**Unit testing transformation logic.** If your transformations are written as pure functions — input data in, output data out, no I/O — you can test them like any other function. Pass a small DataFrame with known values, assert the output matches expectations. This catches logic errors: wrong formulas, incorrect joins, off-by-one date arithmetic.

**Integration testing with data snapshots.** Capture a representative sample of real input data (anonymized if needed) and store it as a fixture. Run the full pipeline against it and assert on the output schema and key metrics. This catches wiring errors: the function is correct but it's connected to the wrong source column.

**Contract testing for upstream schema changes.** Your pipeline has an implicit contract with its upstream sources: I expect column `user_id` to be a non-null integer. When the upstream team renames it to `userId`, your pipeline breaks. Contract tests validate the upstream schema on each run before processing starts. A schema mismatch fails fast with a clear error rather than silently producing wrong output or crashing halfway through.

**CI schema drift checks.** Add a CI step that reads the expected output schema from a checked-in artifact and fails if the pipeline code would produce a different schema. This catches schema changes before they reach production — a new column gets added to the output, downstream consumers break.

The minimum viable test suite: unit tests on every transformation function and a contract test on every upstream source. These two layers catch the majority of production failures.

> [!info] A pipeline that fails fast with a clear schema mismatch error is dramatically easier to operate than one that silently produces nulls or drops rows because a column name changed upstream.

@feynman

Testing a pipeline is like testing an ETL at a border crossing — check the passport format before the traveler gets through, not after they're already at the hotel.

@card
id: tde-ch03-c010
order: 10
title: Monitoring a Data Pipeline
teaser: A pipeline that runs without errors but produces wrong output is worse than a pipeline that fails loudly — at least the failure is visible.

@explanation

Pipeline monitoring has two distinct goals: detecting execution failures (the pipeline didn't run, or it ran and crashed) and detecting data quality failures (the pipeline ran successfully but the output is wrong). Most teams instrument the first and ignore the second. The second is where data trust is actually lost.

The core checks for every production pipeline:

**Row count.** How many rows did we process? Compare to the expected range (e.g., yesterday's run ±20%). A sudden 80% drop means either the source is empty or the pipeline dropped records somewhere. A sudden 200% spike means either legitimate growth or a duplicate.

**Null rate on critical columns.** If `user_id` goes from 0.1% null to 45% null, something upstream broke. Track the null rate on every column that downstream queries filter or join on.

**Freshness check.** What is the most recent event timestamp in the output? If a pipeline that should contain today's data has a max timestamp of 3 days ago, data ingestion stalled even though the pipeline "succeeded."

**Data quality assertions inline.** Add assertions inside the pipeline: `assert revenue >= 0`, `assert user_id is not null for paid events`. These fail the run immediately when violated rather than writing corrupt data and succeeding.

**Alerting with a runbook.** Every alert should have an associated runbook: what does this alert mean, what are the likely causes, what are the first three things to check? An alert that fires and sends the on-call engineer to the Slack channel with no context is an alert that trains engineers to ignore it.

> [!tip] Instrument row counts and null rates from day one. Adding them retroactively requires understanding what "normal" looks like — and you lose that baseline the moment you skip the first week.

@feynman

Monitoring a pipeline is like a blood test — the patient can look fine on the outside while the numbers tell a different story, and you need the numbers to know when something is wrong.
