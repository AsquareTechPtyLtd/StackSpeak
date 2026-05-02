@chapter
id: tde-ch01-data-engineering-foundations
order: 1
title: Data Engineering Foundations
summary: Data engineering is the discipline of building and maintaining the infrastructure that moves, stores, and transforms data — and getting that infrastructure right determines whether everyone downstream can do their job.

@card
id: tde-ch01-c001
order: 1
title: What Data Engineers Actually Do
teaser: Data engineers build the plumbing. Analysts and scientists use the water. Confusing the two roles is how orgs end up with data scientists who spend 80% of their time on ETL.

@explanation

The core job is building and maintaining the systems that move, store, and transform data so that analysts, data scientists, and products can use it. That means pipelines from source systems, storage infrastructure, transformation logic, and the monitoring to know when things break.

The role boundaries matter because they define who owns what:

- **Data engineering** owns the infrastructure layer: pipelines, warehouses, data quality, freshness SLAs, and the reliability of getting data from A to B. The output is clean, accessible, trustworthy data.
- **Data science** owns the analysis layer: modeling, experimentation, prediction. They consume what engineering produces — they should not be building it.
- **Analytics engineering** sits between the two. Tools like dbt and the semantic layer are analytics engineering territory: transforming raw data into business-readable models, defining metrics, curating the presentation layer of the warehouse. It is closer to data engineering in discipline (version-controlled SQL, testing, CI/CD) but oriented toward analyst consumption.

A healthy data org has these boundaries explicit. An unhealthy one has data scientists blocked on data access and data engineers confused about whether metric definitions are their problem.

The single clearest signal of a dysfunctional data org: a survey finds that data scientists spend more than 50% of their time on data cleaning and pipeline work. That is an engineering capacity problem, not a data science problem.

> [!info] The data engineer's job is to make the data boring — reliably available, well-documented, and trusted — so that the people building on top of it can focus on the interesting work.

@feynman

Data engineers are the plumbers who make sure the water arrives clean and at the right pressure; data scientists are the chefs who need water to cook — they shouldn't have to dig the pipes.

@card
id: tde-ch01-c002
order: 2
title: The Modern Data Stack
teaser: The modern data stack replaced on-premises Hadoop with a layered set of cloud-native, often best-of-breed tools — each layer has a job, and the boundaries between them are where most integration debt lives.

@explanation

The modern data stack is a loosely coupled architecture of cloud-native tools organized into layers:

- **Ingestion** — moving data from source systems into your storage layer. Tools: Fivetran, Airbyte, custom connectors, CDC systems like Debezium. The key metric here is reliability and coverage, not performance.
- **Storage** — the data warehouse or lakehouse where transformed data lives. Compute-storage separated cloud warehouses (Snowflake, BigQuery, Redshift) for structured analytics; object stores (S3, GCS, ADLS) as the raw landing zone and lakehouse foundation.
- **Transformation** — converting raw ingested data into analytics-ready models. dbt dominates the SQL transformation layer; Spark and Glue handle heavy distributed computation when SQL isn't sufficient.
- **Orchestration** — scheduling, dependency management, and failure handling across the pipeline graph. Airflow is the incumbent; Prefect and Dagster are newer entrants with better developer experience.
- **Serving** — delivering data to consumers: BI tools (Looker, Tableau, Metabase), APIs for application consumption, feature stores for ML.

This replaced on-premises Hadoop because Hadoop required dedicated infrastructure teams, had steep operational overhead, and coupled storage to compute in ways that made scaling expensive. Cloud warehouses unbundled those concerns and let teams pay for what they use.

The stack creates real integration debt at the seams: ingestion to storage schemas, transformation to serving contracts, orchestration dependencies. Most data incidents live at those boundaries, not inside a single tool.

> [!warning] "Modern data stack" is a marketing term as much as an architecture. Picking best-of-breed tools at every layer means you own the integration between them. Factor that cost in before committing.

@feynman

It is a factory assembly line where each station does one job — the efficiency comes from specialization, but a breakdown at any handoff point stalls the whole line.

@card
id: tde-ch01-c003
order: 3
title: Batch vs Streaming Processing
teaser: Most teams start with batch, add streaming where latency demands it, and end up maintaining both — which is more expensive than either alone.

@explanation

The fundamental distinction is when data is processed:

- **Batch processing** runs on a schedule — hourly, daily, weekly. Data accumulates between runs and is processed as a chunk. It is simpler to build and debug, cheaper to run, and tolerant of failures (rerun the batch). Latency is measured in hours or days.
- **Streaming processing** runs continuously as events arrive. Latency is measured in seconds or milliseconds. It handles unbounded data and enables real-time use cases: fraud detection, live dashboards, immediate notifications. It is substantially more complex and expensive — you pay for the infrastructure to run 24/7, and you pay in engineering hours to reason about event ordering, late data, and stateful processing.

Most teams follow a maturity progression: batch first, streaming when the latency requirement justifies the complexity. The mistake is building streaming infrastructure for use cases where hourly batch is adequate.

Two architectural models for managing both:

- **Lambda architecture** — run batch and streaming pipelines in parallel and merge the results. The batch layer provides correctness; the streaming layer provides speed. The cost: you maintain two code paths for the same logic, and they will diverge.
- **Kappa architecture** — treat everything as a stream, replay historical data through the streaming system when you need reprocessing. Simpler than Lambda conceptually; harder to implement correctly, especially for high-volume historical replays.

> [!tip] Before committing to streaming infrastructure, write down the specific latency requirement and who is waiting on it. "Real-time dashboards" that only refresh every 5 minutes do not need a streaming pipeline — they need a faster batch schedule.

@feynman

Batch processing is like picking up mail once a day; streaming is like a phone call — both deliver messages, but the right choice depends entirely on whether the message needs to arrive in seconds or hours.

@card
id: tde-ch01-c004
order: 4
title: The Data Pipeline Contract
teaser: Your upstream source systems are external dependencies — they will change without warning, send malformed data, and go silent at the worst possible moment. Treat them like untrusted APIs, not reliable teammates.

@explanation

Every data pipeline has a contract with its upstream producers: what schema to expect, how frequently data arrives, and what SLA the source system commits to. In practice, most of these contracts are implicit and undocumented, which means they are silently violated constantly.

The components of an explicit pipeline contract:

- **Schema** — field names, types, nullability, and allowed values. The most common breakage pattern: a source team adds, renames, or drops a column without notifying downstream consumers. An upstream rename that breaks six downstream pipelines is not unusual.
- **Frequency** — how often new records arrive. A pipeline that expects hourly data and receives daily data has bad freshness. A pipeline that expects daily data and suddenly receives nothing has a silent failure.
- **SLA** — by what time data is guaranteed to be available and at what reliability threshold. Most source systems have no documented SLA. This means your pipelines have no SLA either, because you can't promise what your inputs don't guarantee.

The correct mental model is treating upstream systems like external third-party APIs: assume they will break, build defensive code, validate inputs explicitly, alert when expectations are violated. The fact that the upstream system is owned by the same company does not make it reliable — internal teams change schemas without thinking about downstream impact routinely.

The most practical change you can make: add schema validation at pipeline ingestion and alert immediately when the contract is violated, rather than silently propagating bad data downstream.

> [!warning] "They'll tell us if they change the schema" is not a data contract. It is an optimistic assumption that will fail at 2 AM on a Friday.

@feynman

Trusting an upstream data source without validation is like calling an external API without checking the response code — you're assuming success and will only find out otherwise when something downstream breaks.

@card
id: tde-ch01-c005
order: 5
title: Idempotency as a Pipeline Virtue
teaser: A pipeline that produces the same result whether it runs once or ten times is a pipeline you can rerun without fear — and in data engineering, you will rerun everything eventually.

@explanation

Idempotency means: running the pipeline multiple times with the same input produces the same output as running it once. The inverse — a non-idempotent pipeline — appends duplicate rows on rerun, double-counts events, or produces results that depend on how many times it has executed.

Why idempotency matters in practice: pipelines fail. Orchestrators retry failed tasks. Engineers manually rerun jobs when debugging. Historical backfills process the same date ranges multiple times during development. If none of those reruns produce duplicates or inconsistencies, the pipeline is safe to operate. If any of them do, you have a correctness problem that compounds over time.

The patterns that produce idempotency:

- **MERGE/upsert over INSERT** — write records keyed on a natural identifier. Rerunning the same data updates existing rows rather than appending new ones.
- **Partition overwrite over append** — for partitioned tables, overwrite the entire partition rather than appending to it. Rerunning a daily partition replaces it cleanly rather than duplicating it.
- **Timestamp-based watermarks** — process data for a bounded time window defined by the run parameters, not by "all new data since last run." The latter is non-deterministic and breaks on reruns; the former produces the same result every time for a given input window.

A useful test: pick a pipeline you own and manually rerun yesterday's job today. Does the output change? If yes, you have a non-idempotent pipeline and you should know it.

> [!info] Idempotency is not free — MERGE is more expensive than INSERT, partition overwrite requires careful partition design. The cost is worth it. The cost of a production deduplication incident is always higher.

@feynman

An idempotent pipeline is like a well-designed database migration — you can run it again on an already-migrated database and nothing breaks, because the operation checks state before acting.

@card
id: tde-ch01-c006
order: 6
title: Data Freshness SLAs
teaser: "We update daily" is a description of what you do when nothing goes wrong. A freshness SLA is a commitment with a reliability target, monitoring, and alerting — most data pipelines have neither.

@explanation

There is a meaningful difference between:

- "Our data warehouse updates at 6 AM every day" — a description of the nominal schedule.
- "Data is guaranteed to be fresh as of 5 AM with 99.9% reliability, with alerts firing within 15 minutes of a breach" — an SLA.

The first tells you what happens when the pipeline runs successfully. The second tells you what you're committing to, how often you expect to meet it, and what happens when you don't.

Most data teams operate without SLAs. This produces two specific problems:

1. **No basis for prioritization** — without SLAs, all freshness failures feel equally urgent. An analyst waiting on a daily dashboard gets the same escalation path as an exec dashboard that drives real-time decisions. SLAs create triage logic.
2. **No monitoring** — if you haven't defined what "fresh enough" means, you can't write a check that fires when it's violated. Silent staleness is common: the dashboard looks populated, but the data is 36 hours old.

How to set a freshness SLA in practice: start with the consumer. What is the latest acceptable data time for the business decision being made? Work backwards to what the pipeline must deliver. Set the SLA tighter than the consumer requirement to give yourself margin for failures.

Monitoring freshness means checking actual data timestamps, not just whether the pipeline job completed. A pipeline that ran successfully but loaded zero rows is a freshness violation.

> [!info] The first time an exec makes a decision on stale data and you have no SLA to point to, you will wish you had defined one. Define it proactively, not reactively.

@feynman

A freshness SLA is like a food safety expiration date — "best before" is the consumer commitment, and you need both a reliable process and a way to know when something has gone off.

@card
id: tde-ch01-c007
order: 7
title: The Cost of Bad Data
teaser: A data quality problem at the source looks like a small bug until an exec makes a wrong decision based on a report built on it — then it looks like a business problem.

@explanation

Bad data has a compounding effect downstream that makes the cost far larger than the incident that caused it:

1. A source system has a bug: it double-counts certain transaction types.
2. A data pipeline ingests the bad data without catching it — no row count validation, no range checks.
3. An analyst builds a revenue report on that pipeline. The numbers are 15% high.
4. The report goes to an exec who decides to cut marketing spend because revenue appears strong.
5. The decision is wrong. Marketing spend is cut. Revenue actually falls.

The bug originated at step 1. The cost was realized at step 5. The engineer who wrote the source system bug had no visibility into step 5. The analyst who built the report trusted the pipeline. The exec trusted the analyst. Everyone made a reasonable local decision and the system produced a bad outcome.

This is why data quality is the data engineer's responsibility, not just the analyst's. The data engineer is the only person who sees both the source and the downstream consumers. They are the natural quality gate.

Operationalizing "garbage in, garbage out":

- Validate row counts on every pipeline run — a table that normally loads 50k rows loading 5k rows is a signal, not background noise.
- Set nullability and range checks on critical fields.
- Build anomaly detection on key metrics: revenue, user counts, event volumes. A 20% daily swing is worth an alert.

The root cause of most data quality failures is not malicious actors or exotic edge cases. It is source system changes that nobody noticed.

> [!warning] "The analyst should have checked the data" is a reasonable statement and also a failure of the data engineering function. Both can be true. Build the quality gates so analysts don't have to.

@feynman

Bad data is like a contaminated ingredient early in a supply chain — by the time it reaches the consumer, it has been processed, packaged, and distributed into dozens of products, and tracing it back is expensive.

@card
id: tde-ch01-c008
order: 8
title: Data Lineage
teaser: When a number is wrong, you need to know where it came from — data lineage is the audit trail that makes debugging take hours instead of days.

@explanation

Data lineage is the record of where data came from, what transformed it, and where it flows to. It answers questions that are otherwise very hard to answer:

- "This metric is wrong — which upstream table caused it?"
- "We're deleting a deprecated table — what downstream reports depend on it?"
- "A compliance audit requires us to show where this PII field originated."
- "A source system changed its schema two weeks ago — what was affected?"

Without lineage, debugging a data quality issue means manually tracing back through SQL transformations, checking pipeline configs, and asking engineers which tables feed which dashboards. In a complex warehouse with hundreds of tables and dozens of pipelines, this takes days.

Lineage tooling exists at different layers:

- **dbt** produces lineage automatically for SQL transformations: a DAG of model dependencies that shows exactly which models feed which. This covers the transformation layer but not ingestion or downstream serving.
- **OpenLineage / Marquez** — open standard for lineage metadata across heterogeneous systems (Spark, Airflow, dbt). Integrations are uneven.
- **Data catalog tools** (Atlan, Collibra, Microsoft Purview) — enterprise lineage with broader coverage and business context annotations, at significant cost and implementation effort.

The lineage gap in most organizations: ingestion-to-warehouse lineage is usually missing. Most teams can tell you how Table B was built from Table A in dbt, but not which source system or API call produced Table A in the first place. That last-mile lineage is where many debugging investigations dead-end.

> [!info] Lineage is the most valuable documentation in a data system — it is generated automatically by good tooling, but only if you configure it. The investment is low relative to the debugging time it saves.

@feynman

Data lineage is a version control history for your data's journey — without it, you can see what the data looks like now but not how it got there or what would break if you changed something upstream.

@card
id: tde-ch01-c009
order: 9
title: Schema Evolution
teaser: Adding a column is safe. Removing or renaming one breaks consumers who didn't ask to be broken. Schema evolution is the discipline of changing data structures without causing silent failures downstream.

@explanation

Schemas change because requirements change. The challenge is that schemas are shared contracts between producers and consumers, and not all changes are safe.

**Safe changes (backward compatible):**
- Adding a new nullable column — existing consumers ignore it; new consumers can use it.
- Adding a new value to an enum, if consumers handle unknown values gracefully.

**Unsafe changes (breaking):**
- Removing a column — consumers that read it will fail or return nulls without warning.
- Renaming a column — functionally identical to remove + add, breaks every consumer.
- Changing a column's type — a string to int change, for example, will break downstream type assumptions silently or loudly depending on the tool.

The **expand/contract pattern** handles breaking changes safely:

1. **Expand** — add the new column alongside the old one. Populate both.
2. **Migrate** — update all consumers to use the new column.
3. **Contract** — remove the old column once no consumers reference it.

This takes longer than just renaming the column, but it does not break production.

For streaming systems, **schema registries** (Confluent Schema Registry, AWS Glue Schema Registry) enforce compatibility rules centrally — producers cannot publish a schema that would break registered consumers. This is the streaming equivalent of the expand/contract discipline.

The organizational failure mode: source teams don't know who their consumers are, so they don't know what a schema change will break. Lineage (the previous card) and schema registries together solve this.

> [!warning] "It's just a rename" is the phrase that precedes a 2 AM incident. Renames are breaking changes. Treat them as such.

@feynman

Changing a database column name without coordinating consumers is like renaming a function in a public API — perfectly valid in your codebase, immediately breaking for every caller who depended on the old name.

@card
id: tde-ch01-c010
order: 10
title: The Data Engineer's Debugging Mindset
teaser: Data bugs are not like code bugs — the program ran successfully, the output is just wrong, and finding out why requires systematic narrowing rather than stack traces.

@explanation

Code bugs have stack traces. Data bugs have wrong numbers. The program ran, the pipeline completed, Airflow shows green — and the revenue report is off by 12%. This is the normal debugging environment for data engineers.

Systematic debugging works better than intuition here. A repeatable process:

1. **Check row counts first.** Does the affected table have the expected number of rows for the time period in question? An unexpected count tells you whether you have a missing data problem or a wrong-value problem — these require different investigations.
2. **Check nulls.** Are key join columns, filter fields, or metric inputs unexpectedly null? Null propagation in SQL is silent — a null in a sum is ignored, not errored.
3. **Check joins.** Fan-out joins and failed joins are the most common source of incorrect aggregates. Run the join in isolation and check whether it's one-to-one, one-to-many, or many-to-many. Unexpected many-to-many joins inflate row counts silently.
4. **Check time boundaries.** Is the pipeline using the right date column, in the right timezone, with the right boundary condition (inclusive vs exclusive)? Off-by-one errors on date partitions are extremely common.

The **incremental isolation technique**: bisect the pipeline. If the final output is wrong, check the intermediate tables. Find the earliest point where the data diverges from expectation — that is where the bug lives.

Logging discipline: log row counts and key metric values at each pipeline stage, not just success/failure status. "Pipeline completed in 4m 32s" is useless for debugging. "Pipeline loaded 47,832 rows for 2026-05-01, p95 transaction value $142" is useful.

> [!tip] Before you touch any code, spend 10 minutes just looking at the data. Count rows by partition, check null rates on key columns, spot-check individual records. Most data bugs reveal themselves before you write a single query.

@feynman

Debugging a data pipeline is like diagnosing a patient who feels fine but has a wrong blood test result — you check the collection process, the sample integrity, the lab equipment, and the result interpretation before concluding anything about the patient.
