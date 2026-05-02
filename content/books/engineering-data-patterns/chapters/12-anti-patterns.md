@chapter
id: depc-ch12-anti-patterns
order: 12
title: Data Engineering Anti-Patterns
summary: The failure modes that recur across teams and tools — small-files explosion, monolithic transforms, untested SQL, manual backfills, schema-drift-by-null — and how to recognize and correct them before they become incidents.

@card
id: depc-ch12-c001
order: 1
title: Anti-Patterns as Recurring Failure Modes
teaser: Anti-patterns aren't mistakes — they're patterns that look correct in the short term and become expensive in the medium or long term.

@explanation

Anti-patterns share a characteristic: they solve the immediate problem quickly and cheaply, and the cost only becomes visible later — when the table has grown, when the team has grown, when the pipeline has been running for 18 months.

This chapter catalogs the most common ones observed across data teams. They're not exotic edge cases — they show up in nearly every team that builds data systems under time pressure.

Knowing them serves two purposes:
- **Detection:** recognizing the pattern in a system you've inherited, so you can prioritize the remediation.
- **Prevention:** avoiding the pattern in a system you're building, so you don't create the same debt.

The anti-patterns below are not things people do ignorantly — they're things that seem like fine decisions under the pressure of a deadline, with a team of two, with a table of 100K rows. The pain arrives later, when the context has changed.

> [!info] Every anti-pattern in this chapter has been "the right call" in some context. The failure mode is applying it in contexts where it isn't.

@feynman

Like technical debt in application code — not wrong per se; wrong when you don't account for the interest accumulating.

@card
id: depc-ch12-c002
order: 2
title: Small-Files Explosion
teaser: A thousand files that each hold one row are worse than one file that holds a thousand rows. Streaming writes and partition over-granularity are the common causes.

@explanation

The **small-files problem** occurs when a data lake accumulates millions of tiny files (under 1 MB), degrading query performance and inflating metadata operations.

How it happens:
- **Streaming writes at high granularity:** Kafka consumers flush to S3 after each batch of 100 events, producing thousands of small files per hour.
- **Partition over-granularity:** partitioning by `year/month/day/hour/minute` on a table that receives 100 rows per minute creates 1,440 partitions per day, each with 100 rows.
- **Delta/CDC writes without compaction:** every CDC event becomes a small Delta file before compaction runs.
- **Failed jobs producing partial writes:** a job that dies halfway through has written 50 small files that were never compacted.

Consequences:
- **Query latency:** Spark opens each file separately; listing and opening 10,000 files takes longer than reading one 1 GB file with the same total data.
- **Metadata pressure:** S3 LIST operations are rate-limited. A prefix with 10 million objects causes throttling.
- **Object storage cost:** per-object billing on some tiers; high request costs at massive file counts.

Solutions:
- **Compaction jobs:** run `OPTIMIZE` (Delta), `rewrite_data_files` (Iceberg), or a Spark coalesce job periodically.
- **Buffered writes:** in streaming pipelines, buffer events for 5 minutes before flushing to produce reasonably-sized files.
- **Coarser partitioning:** daily partitions instead of hourly if queries rarely filter to sub-day.

> [!warning] Without scheduled compaction, a Kafka-to-Delta pipeline will accumulate small files continuously. Set up OPTIMIZE as a daily maintenance job from day one.

@feynman

Like having a million sticky notes instead of a notebook — same information, much harder to find anything and much harder to carry around.

@card
id: depc-ch12-c003
order: 3
title: Monolithic Transforms
teaser: One giant SQL query or Python script that does everything — extract, join, clean, aggregate, and load — is fast to write and slow to debug, test, and modify.

@explanation

A **monolithic transform** combines multiple logical steps into a single, undifferentiated operation. A 500-line SQL query that joins 10 tables, applies business logic, and produces an output in one shot.

Why it happens: writing one query is faster than writing five. Under deadline pressure, the monolith gets shipped.

Why it hurts:
- **Untestable:** there's no way to test the intermediate steps independently. A bug in the join logic is buried in a wall of SQL.
- **Undebugable:** when the output is wrong, there's no intermediate state to inspect.
- **Unmodifiable without risk:** any change to one part of the query risks breaking another. Engineers learn to fear touching it.
- **Performance blind:** slow sections can't be profiled independently.
- **Owner dependency:** the engineer who wrote it carries all the context; when they leave, the query becomes opaque.

What to do instead:
- **Staged transformations:** split the monolith into a sequence of intermediate tables or CTEs with clear names. Each stage can be tested and inspected independently.
- **dbt model decomposition:** in dbt, each transformation step is a separate model, tested independently, with documented lineage.
- **Named CTEs over subqueries:** even within a single SQL query, named CTEs are more readable and testable than nested subqueries.

> [!tip] The test for whether a transform is too large: can you describe what each section does in one sentence without referencing other sections? If not, split it.

@feynman

Like a function that's 500 lines long — correct in the narrow sense, impossible to maintain, and the source of every subtle bug going forward.

@card
id: depc-ch12-c004
order: 4
title: Untested SQL
teaser: A SQL transform with no tests is a liability. The next schema change, volume change, or logic change will break it silently — and downstream consumers will find out before you do.

@explanation

Most data engineering pipelines include SQL transforms that have no automated tests. The transforms were written, manually verified once at the time, and deployed. From then on, they're assumed to be correct until someone notices otherwise.

Why SQL goes untested:
- Testing SQL is less ergonomic than testing application code. There's no standard test framework with the mindshare of pytest or JUnit.
- Manual verification feels sufficient — "I checked the output, it looks right."
- The table has 10 rows in development. In production, with 10 million rows, behavior can differ.

What breaks untested SQL:
- **Source schema changes:** a column rename nulls out a field the query relied on.
- **NULL propagation:** new data has NULLs in a column that was previously always populated. Aggregations now return unexpected results.
- **Duplicate rows:** a join produces unexpected duplicates that the original data didn't have.
- **Business logic drift:** a requirement changes but only the application is updated; the SQL still uses the old logic.

Testing approaches:
- **dbt built-in tests:** `unique`, `not_null`, `accepted_values`, `relationships` — four tests that catch the majority of common SQL failures.
- **dbt custom tests:** SQL queries that return 0 rows when correct; any returned row is a test failure.
- **Great Expectations:** validate output tables after each transform run.
- **Unit testing with mock data:** tools like dbt-unit-testing allow SQL logic testing on minimal mock datasets.

> [!warning] The "I verified it once" argument fails the first time the source schema changes, which happens within 6 months for most pipelines. Tests catch that; memory doesn't.

@feynman

Like deploying backend code without tests because "I manually tested it" — fine until the first edge case or dependency change.

@card
id: depc-ch12-c005
order: 5
title: Manual Backfills
teaser: Running backfills by hand — editing job parameters, running commands, watching output — is slow, error-prone, and doesn't scale. Pipelines should be backfillable without manual steps.

@explanation

A **manual backfill** means re-running a pipeline over historical data through a process that requires human intervention — editing config files, running shell commands, watching progress, re-running failures manually.

Why it happens: building proper backfill infrastructure takes time; the first backfill is urgent; you do it manually. The pattern solidifies.

Why it's a problem:
- **Scale:** manually backfilling 30 days of data is slow; backfilling 365 days is a project.
- **Errors:** manually specifying date ranges for each run introduces off-by-one errors and missed dates.
- **Discoverability:** a manual backfill that ran three weeks ago isn't recorded in any system; the next person doesn't know it happened.
- **On-call burden:** the on-call engineer who needs to recover a month of data after an incident shouldn't be running shell scripts for 8 hours.

What well-designed pipelines enable:
- **Date-range backfill via the orchestrator:** Airflow's backfill command reruns a DAG over a date range automatically.
- **Idempotent partition overwrites:** each day's backfill run is safe to re-run if it fails partway through.
- **No manual parameter editing:** the date is passed as a parameter by the orchestrator, not hardcoded in config.

```bash
# Airflow backfill — no manual steps required
airflow dags backfill orders_daily_etl \
  --start-date 2026-01-01 \
  --end-date 2026-01-31
```

> [!tip] Design every pipeline for backfill on day one. The test: can a new team member trigger a 30-day backfill without reading your notes? If not, the pipeline isn't complete.

@feynman

Like a database migration you can only run manually — it works once, it's a nightmare the second time, and the third time is a 2am incident.

@card
id: depc-ch12-c006
order: 6
title: Schema Drift Handling by Null
teaser: When a source column disappears or changes type, pipelines that silently pass NULL downstream instead of alerting are hiding a data quality failure as a data value.

@explanation

**Schema drift handling by null** is the pattern where a pipeline, on encountering a source column that has been renamed, dropped, or changed type, writes NULL to the destination column for affected rows — without alerting, without failing, without any visible signal.

Why it happens: pipelines are built to be resilient to missing data. NULL is the "safe" default. The engineer didn't anticipate this specific column disappearing.

Why it's dangerous:
- NULL is a valid business value for many columns. NULL in `customer_email` might mean "no email provided" — or it might mean "the source changed the column name and the pipeline silently failed."
- No alert fires. Dashboards start showing incomplete data. Analysts assume the data is correct. Decisions are made on wrong numbers.
- Discovery is typically downstream: "why are our email open rates zero this week?"

Better alternatives:
- **Schema enforcement:** fail the pipeline when the source schema doesn't match the expected schema. The failure is visible and actionable.
- **Schema validation with quarantine:** validate the schema before writing; route non-conforming records to a quarantine table rather than writing NULL.
- **Schema registry:** for streaming pipelines, a schema registry rejects events that don't conform to the registered schema.
- **Alerting on NULL rate spikes:** even if silently passing NULL, alert when the NULL rate for a column spikes above a threshold.

> [!warning] A pipeline that silently passes NULL for unexpected source changes is worse than a pipeline that fails loudly. Failure is visible; silent NULL is invisible.

@feynman

Like a build that compiles with warnings instead of errors — it "works," but the warnings are telling you something broke and you're choosing not to see it.

@card
id: depc-ch12-c007
order: 7
title: The God Pipeline
teaser: A single pipeline that ingests, transforms, validates, and serves all data for a domain is fast to build and impossible to maintain. Monolithic pipelines accumulate every concern into one failure domain.

@explanation

A **god pipeline** is a data pipeline that does too many things: it extracts from multiple sources, joins them, applies business logic, validates, aggregates, and writes to multiple destinations — all in one job. The individual steps may be correct; the problem is their coupling.

How god pipelines form: a data engineer builds a pipeline for a new domain. Over time, requirements are added to it because "it's already loading that data." Three years later, a 2,000-line Spark job owns all the data for a domain. Touching it requires full regression testing on every change.

Failure modes of god pipelines:
- A source schema change in one of the many inputs breaks the entire pipeline, blocking all outputs.
- A performance issue in one transformation step slows all other outputs.
- Different parts of the pipeline need different retry strategies; they're all forced to share one.
- Testing requires mocking all inputs simultaneously.
- The pipeline is too big for any one person to fully understand.

What to do instead:
- **One job, one output:** each pipeline job has one clear output and one failure domain.
- **Shared libraries, not shared jobs:** common transformation logic lives in a shared library; each pipeline calls it independently.
- **dbt DAG decomposition:** break the monolith into a graph of models, each testable and independently rerunnable.

> [!warning] The god pipeline is recognizable when: changing it requires a "this touches everything" comment, the on-call runbook says "be careful with this one," and no single person can explain all the steps in one sitting.

@feynman

Like a function that's 3,000 lines long — technically works, practically unmaintainable, and the first place something breaks when requirements change.

@card
id: depc-ch12-c008
order: 8
title: Hardcoded Business Logic in SQL
teaser: Business rules embedded directly in a SQL transform — magic numbers, status codes, tier thresholds — become undocumented debt that breaks when the rule changes.

@explanation

**Hardcoded business logic** is decision-making embedded directly in SQL or pipeline code in a way that's opaque, undocumented, and fragile when the rule changes.

Examples:
```sql
-- Hardcoded: what do these numbers mean?
WHERE status IN (2, 4, 7)
  AND amount > 500
  AND region_code NOT IN ('XX', 'YY', 'ZZ')
```

Three months later: nobody knows what statuses 2, 4, and 7 represent. The threshold 500 — is it dollars? Cents? Orders? Which currency? Region codes XX and YY — were those countries removed from the product? Did someone manually add a new one?

What to do instead:

**Named constants via dbt vars or source definitions:**
```sql
WHERE status IN {{ var('completed_status_codes') }}
  AND amount > {{ var('minimum_order_threshold') }}
```

**Reference dimension tables:**
```sql
WHERE o.status_code IN (SELECT code FROM dim_order_statuses WHERE is_completed = true)
  AND o.region_key IN (SELECT region_key FROM dim_regions WHERE is_supported = true)
```

**dbt project variables or seeds:** put configurable constants in a `dbt_project.yml` vars block or a seed CSV with column documentation.

**Code comments are not a solution:** a comment next to a hardcoded value documents it at a moment in time; the comment doesn't update when the rule changes.

The cost of business logic in SQL vs in a governed location: when the rule changes, a governed reference table requires updating one row; hardcoded SQL requires finding every pipeline that embeds the same constant and updating each one.

> [!tip] Every time you write a number or string literal that represents a business concept in a SQL WHERE clause, ask: is there a table or variable that should own this value instead of this query?

@feynman

Like magic numbers in application code — every developer knows the rule when it's written; nobody knows it two years later.

@card
id: depc-ch12-c009
order: 9
title: Ignoring Pipeline Idempotency
teaser: A pipeline that appends on retry will silently double-count. The failure is invisible until someone notices a metric is twice what it should be.

@explanation

A **non-idempotent pipeline** produces different results when run more than once on the same input. The most common manifestation: an `INSERT INTO` that appends without checking for existing rows.

The scenario: a daily pipeline runs at 6 AM, processes yesterday's orders, and inserts them into `fact_orders`. The Airflow task fails at 6:15 AM for an unrelated reason (network timeout). Airflow retries at 6:20 AM. The retry succeeds. The orders from yesterday are now in `fact_orders` twice.

This doubles revenue in any dashboard that aggregates `fact_orders`. If nobody checks yesterday's order count against the source, the duplicate persists indefinitely.

Why this isn't caught immediately:
- Revenue went up, not down. An increase is less alarming than a decrease.
- The duplicate affects only yesterday's partition; the daily total change is invisible in weekly trends.
- No quality check validates row count against the source system.

Detection: a reconciliation query that compares fact row counts to the source:
```sql
SELECT order_date, COUNT(*) AS fact_count,
       (SELECT COUNT(*) FROM source_orders WHERE DATE(created_at) = order_date) AS source_count
FROM fact_orders
GROUP BY order_date
HAVING fact_count != source_count
```

Prevention: partition overwrite, MERGE/upsert, or a deduplication step on the unique key before any INSERT. The principle is: design the write so that repeating it produces the same state as running it once.

> [!warning] `INSERT INTO` in a scheduled pipeline is almost always the wrong write pattern. Default to partition overwrite or MERGE; use INSERT only for append-only tables where duplicates genuinely can't occur.

@feynman

Like a financial ledger that posts every entry twice on retry — the balance is wrong, but it's wrong in a direction that's easy to miss.

@card
id: depc-ch12-c010
order: 10
title: Over-Engineering Early
teaser: Applying enterprise-scale data infrastructure to startup-scale problems creates complexity without value. The patterns are real — the problem must be real-size too.

@explanation

**Over-engineering** in data systems means solving a problem at a scale or complexity the team doesn't have, producing infrastructure that is harder to maintain than the problem it solved warranted.

Common manifestations:

**Full lakehouse architecture for 10 GB of data.** Bronze/silver/gold + Iceberg + Spark + Airflow is excellent at petabyte scale. For a team with 10 GB of data and three analysts, DuckDB + dbt + a simple scheduler solves the same problem in 1/10th the infrastructure.

**Kafka for 100 events per second.** Kafka is designed for millions of messages per second and high-throughput stream processing. At 100 events/second, a simple SQS queue with a Lambda consumer is simpler, cheaper, and easier to operate.

**Microservice data architecture on a two-person team.** Each team owning their own data store and pipeline requires cross-team coordination that a two-person team doesn't need. A shared warehouse they both query is sufficient.

**Feature store for two ML models.** Feature stores are valuable when many ML models share features and training-serving consistency is a proven problem. For two models in early development, a simple Parquet-backed feature table is sufficient.

The pattern: a team learns a sophisticated tool or architecture from a conference talk or blog post about a company 10× their scale, and applies it because it's "best practice." The complexity is real; the payoff isn't, yet.

> [!tip] A useful heuristic: if the architecture is harder to explain than the data problem it solves, the architecture is probably over-engineered for the problem's current size.

@feynman

Like deploying Kubernetes for a single-server app — the tool is real and valuable at its intended scale; the problem isn't at that scale yet.
