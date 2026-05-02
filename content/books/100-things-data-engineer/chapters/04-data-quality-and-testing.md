@chapter
id: tde-ch04-data-quality-and-testing
order: 4
title: Data Quality and Testing
summary: Data quality is not a property your pipeline has or doesn't have — it's a set of specific, measurable dimensions that you instrument, test, and enforce continuously, or watch degrade silently until a downstream user loses trust in your tables.

@card
id: tde-ch04-c001
order: 1
title: The Six Dimensions of Data Quality
teaser: Data quality isn't a single dial. It's six independent axes, and optimizing one often degrades another — which means you need to be explicit about the tradeoffs you're accepting.

@explanation

The six dimensions are:

**Completeness** — is all expected data present? A column that should have a value in every row, does it? A daily file that should arrive with 100k records, does it? Completeness is about the presence of data that should be there.

**Accuracy** — is the data correct? A customer's email address is complete if it's populated, accurate only if it's the right email. Accuracy is hardest to measure because it requires a ground truth to compare against.

**Consistency** — does the data agree with itself across systems? If the orders table says a customer placed 12 orders and the customer table says 11, you have a consistency problem. Cross-system consistency is one of the hardest to enforce at scale.

**Timeliness** — is the data fresh enough for its use case? A dashboard built on yesterday's data is fine for monthly reporting and catastrophic for real-time fraud detection. Timeliness is always relative to the consumer's SLA.

**Validity** — does the data conform to the schema, constraints, and business rules? A phone number field that contains "N/A", a negative order total, a user_id that references no user — all valid problems.

**Uniqueness** — are there unexpected duplicates? A primary key with two rows for the same ID, an events table counting the same event twice because of a retry bug — uniqueness failures compound downstream.

The tradeoff: shipping faster (timeliness) often means accepting lower completeness or accuracy because late-arriving data hasn't reconciled yet. Enforcing strict validity at ingestion improves validity but reduces completeness when valid-looking records are rejected. You can't maximize all six simultaneously. Pick the dimensions that matter most for each table's use case and be explicit about it.

> [!warning] "Data quality is good" is not a statement. "This table has 99.8% completeness on required fields, <2h freshness, and zero duplicate primary keys" is a statement. Unmeasured quality is not quality — it's hope.

@feynman

The same way a microservice can be available, fast, and consistent but not all three simultaneously, your data can be complete, accurate, timely, and unique but not necessarily all at once — CAP theorem, but for tables.

@card
id: tde-ch04-c002
order: 2
title: Data Expectations and Contracts
teaser: An expectation is a machine-enforceable rule about your data. A contract is a set of expectations with an owner. Without them, your pipeline's quality guarantees exist only in someone's head.

@explanation

An expectation is a claim like: "the `order_id` column is never null," "the `status` field contains only one of ['pending', 'shipped', 'delivered']," or "this table receives between 80,000 and 120,000 rows daily." Expressed in code, it can be evaluated automatically at every run.

The major tooling options:
- **Great Expectations** — Python-native, full-featured; define expectation suites, generate data docs, validate on a schedule or in CI.
- **dbt tests** — co-located with your dbt models; runs as part of your transformation layer.
- **Soda Core** — YAML-defined checks; integrates with Soda Cloud for alerting and history.

A soft warning logs a failure and continues. A hard fail stops the pipeline and prevents bad data from propagating downstream. The choice matters: a hard fail at ingestion protects everything downstream but blocks data delivery. A soft warning at serving catches problems late but doesn't interrupt the pipeline.

Where you place expectations changes what they protect:

- **At ingestion:** catches upstream issues before they enter your warehouse. Hard fails here prevent corruption but mean the pipeline goes dark until the issue is fixed.
- **At transformation:** catches logic errors in your models — a join that fans out unexpectedly, a dedup that didn't deduplicate.
- **At serving:** catches problems right before a consumer reads the data. Too late to prevent corruption, but still useful for alerting.

The expectation-as-contract frame changes the relationship with data producers. Instead of "we found bad data again," you have a documented, versioned specification that upstream teams agreed to meet.

> [!info] An expectation without an owner is a check that nobody acts on when it fails. Define who is responsible for each expectation alongside the expectation itself.

@feynman

An expectation is a unit test for your data — and a data contract is the interface definition that the test enforces between the team that produces the data and the team that consumes it.

@card
id: tde-ch04-c003
order: 3
title: dbt Tests — Built-In, Custom, and Coverage
teaser: dbt ships four generic tests that cover the most common quality rules. Combined with custom tests, they turn your documentation into enforcement — but only if you actually run them in CI.

@explanation

dbt's four built-in generic tests:

- `not_null` — the column has no null values.
- `unique` — the column has no duplicate values.
- `accepted_values` — all values in the column belong to a specified list.
- `relationships` — every value in a column exists as a key in a referenced table (referential integrity).

These four cover a large fraction of real data quality failures. A model with all four applied to its primary key and foreign keys is already meaningfully safer than one with no tests at all.

Beyond the built-ins, dbt supports two categories of custom tests:

**Generic tests** — reusable macros you write once and apply to any model or column. Example: a `not_negative` test you apply to every revenue or quantity column.

**Singular tests** — SQL queries that return rows when the assertion fails. If the query returns zero rows, the test passes. These are powerful for complex business rules that don't fit a generic template, like "no order should have a shipped date before its created date."

The test-as-documentation benefit is real: when a new engineer reads your model, the tests communicate what invariants the data is supposed to maintain. The YAML schema file becomes a spec, not just metadata.

**Run tests in CI before deploying model changes.** A dbt model change that breaks a downstream test should fail the pull request, not fail in production two hours later. The CI pattern is: `dbt run --select <changed models>` followed by `dbt test --select <changed models> +`.

**Test coverage ratio** — the fraction of models that have at least one dbt test — is a signal worth tracking. A coverage ratio below 50% in a production warehouse is a risk indicator. Aim for 100% on fact tables and dimension tables that serve dashboards.

@feynman

dbt tests are the same as a test suite for your code — except the thing under test is the shape and content of your data rather than the behavior of a function.

@card
id: tde-ch04-c004
order: 4
title: Schema Validation at Ingestion
teaser: Validating data against an expected schema at the point of ingestion is the cheapest place to catch corruption — before it has touched anything downstream.

@explanation

The failure you are trying to prevent: upstream sends a JSON payload where a field that was always an integer is now sometimes a string. Your pipeline ingests it, the warehouse accepts it because the column is typed loosely, and for the next three days every downstream model joins on a type mismatch. The corruption is silent and has propagated to twelve tables and four dashboards before anyone notices.

Schema validation at ingestion catches this at the boundary.

**For Python batch pipelines:**
- **Pydantic** — define a model class with field types and constraints; deserialize incoming records into the model and fail on mismatches. Works at per-row granularity.
- **Pandera** — DataFrame-level schema validation; validate column types, ranges, and constraints on a pandas or Polars DataFrame before writing to the warehouse.

**For streaming pipelines:**
- **Avro** — schema-encoded binary format; the schema lives in a schema registry; incompatible messages are rejected at the producer or consumer.
- **Protobuf** — similar approach; schema-first, strongly typed.
- **JSON Schema** — lighter weight; validate JSON payloads against a schema document before they enter the pipeline.

The key decision is where to place the validation failure boundary. Fail at the producer (the source team's system) when you have enough influence over the upstream. Fail at your ingestion layer when you don't. What you should not do is let invalid data enter your warehouse and discover it later.

The cost comparison is stark: catching a bad schema change at ingestion takes five minutes to investigate and one Slack message to the upstream team. Catching it three days downstream takes hours of forensics, a rollback, and a reprocessing job.

> [!tip] Version your ingestion schemas. When an upstream field changes from int to string, the schema version mismatch is immediately visible instead of silent.

@feynman

Schema validation at ingestion is like type checking at compile time rather than runtime — catching the mismatch before it corrupts any state is always cheaper than debugging the symptoms later.

@card
id: tde-ch04-c005
order: 5
title: Anomaly Detection for Data Quality
teaser: Rule-based checks catch problems you anticipated. Anomaly detection catches the ones you didn't — the table that received half its usual volume with no schema change and no alert configured.

@explanation

There's a class of data quality problem that rule-based expectations can't catch, because writing the rule requires knowing the problem exists in advance. Anomaly detection fills this gap by learning what "normal" looks like for a table and alerting when behavior deviates from it.

**Statistical approaches:**
- **Z-score on row counts:** compute the mean and standard deviation of daily row counts over a rolling 30-day window. Alert when a new count falls more than 3 standard deviations from the mean. Simple, cheap, and catches most volume anomalies.
- **Moving average drift:** track a metric (null rate, mean value, distinct count) over time; alert when it shifts significantly from the trailing average. Useful for gradual drift that doesn't trigger a threshold rule.

**ML-based tools:**
- **Monte Carlo Data** — scans your warehouse metadata and query history to build models of normal behavior across freshness, volume, schema changes, and distribution shifts. Generates automatic alerting.
- **Bigeye** — similar approach; monitors column-level distributions and alerts on deviations.
- **Metaplane** — same category; integrates with dbt and Looker for lineage-aware monitoring.

The rule of thumb: automated anomaly detection is most valuable for tables that receive data from many upstream sources with no human-readable schema change — high-volume event tables, click streams, API call logs. For curated, well-understood tables, explicit expectations are more precise and produce fewer false positives.

These tools are complementary, not substitutes. Anomaly detection is your smoke detector. Expectations are your sprinkler system. You need both.

@feynman

Rule-based expectations are a known-bug checklist; anomaly detection is a canary in the coal mine — it doesn't need to know what's wrong to know that something is.

@card
id: tde-ch04-c006
order: 6
title: The Data Quarantine Pattern
teaser: When a row fails validation, dropping it silently destroys information. Moving it to a quarantine table preserves the evidence and creates a path to recovery.

@explanation

The naive approach to validation failures is to drop the bad row and continue. This works in the short term and creates problems in the long term: you've silently lost data, you have no record of how often this happens, and you have no way to recover the rows once the upstream issue is fixed.

The quarantine pattern routes failing rows to a separate table — the quarantine table — instead of dropping them.

A typical quarantine table schema includes:
- The original row data
- The name of the check that failed
- The timestamp the failure was detected
- The pipeline run ID that produced the failure

This structure lets you answer: how many rows are failing, which rule is most commonly violated, and when did this start?

Quarantine also functions as a buffer for investigation. When an upstream team fixes the issue that caused the failures, you have the original data and can reprocess it into the main table rather than waiting for it to be re-sent.

**How quarantine drains:**
1. **Fix upstream and reprocess** — the upstream issue is corrected; quarantined rows are cleaned and inserted into the main table.
2. **Discard with documentation** — the rows are unrecoverable or irrelevant; they are removed from quarantine with a written record of why.
3. **Accept and relax the rule** — investigation reveals the rule was too strict; rows are promoted to the main table and the expectation is updated.

What quarantine does not do is solve the problem. It buys you time to investigate without losing data and without propagating corruption downstream.

> [!info] A quarantine table that grows continuously without draining is a signal that no one is acting on failures. Quarantine is a buffer, not a trash can.

@feynman

Quarantine is the same as a dead-letter queue in messaging systems — failed messages go there instead of being dropped so you can inspect them, fix the issue, and replay.

@card
id: tde-ch04-c007
order: 7
title: Data Observability vs Data Monitoring
teaser: Monitoring checks conditions you thought to define. Observability surfaces conditions no one thought to define yet. You need both, and they require different tools.

@explanation

The distinction matters because the two failure modes are different.

**Monitoring** catches known unknowns. You know what can go wrong — the daily row count can drop below threshold, a required column can go null, a join can produce unexpected duplicates — so you write a rule that checks for it. When the rule fires, you know exactly what happened.

Tools: dbt tests, Great Expectations, Soda Core. These run on a schedule or in CI, check explicit conditions, and fail or pass on each run.

**Observability** catches unknown unknowns. A table's null rate has been drifting upward for three weeks, but nobody set a null-rate monitor because it was always fine. A table's row distribution shifted in a way that no threshold rule would catch because the shift is statistical, not binary. Observability tools learn what normal looks like and alert when something is abnormal — without requiring you to define the rule in advance.

Tools: Monte Carlo Data, Bigeye, Metaplane. These scan metadata, query history, and column statistics continuously and surface anomalies using learned models.

The practical stack at most mature data orgs is:
- dbt tests + Great Expectations for monitoring (specific, actionable rules)
- Monte Carlo or Bigeye for observability (broad, anomaly-based coverage)

The common mistake is treating one as a replacement for the other. Monitoring is precise but blind to unanticipated failure modes. Observability has broad coverage but generates more noise and requires more investigation to action.

> [!tip] Start with monitoring because it's cheaper and more actionable. Add observability once you've exhausted the obvious rule-based checks and are still finding quality problems you didn't anticipate.

@feynman

Monitoring is a checklist of known failure modes; observability is a smoke detector that doesn't need to know the source of the fire to tell you the building is unusual right now.

@card
id: tde-ch04-c008
order: 8
title: Testing dbt Models — Unit and Integration
teaser: dbt 1.8 added native unit testing, which means you can test your SQL transformation logic without running against a full production warehouse — the same way you test a function without calling a live database.

@explanation

Before dbt 1.8, testing a dbt model meant running it against real data in a development schema. That's slow, environment-dependent, and requires production-like data volumes to be meaningful. Unit testing changes the model.

**dbt unit tests (dbt 1.8+):**
You define mock inputs — small, controlled datasets — and the expected output of the model given those inputs. dbt runs the model SQL against the mocks and asserts the result matches expectations. No warehouse data needed.

This is particularly valuable for:
- Transformation logic with edge cases (null handling, division by zero guards, date arithmetic)
- Complex window functions and aggregations where bugs are subtle
- Business logic that's hard to test by inspecting production outputs

**Snapshot tests for SCD output:** Slowly Changing Dimension (SCD Type 2) snapshots are notoriously hard to validate. A snapshot test pins the expected state of the snapshot after a specific set of input changes and asserts the SCD columns (`dbt_valid_from`, `dbt_valid_to`, `dbt_is_current`) are correct.

**The CI workflow for a mature dbt project:**

1. **Lint** — `sqlfluff lint` or `dbt parse` to catch syntax errors and style violations.
2. **Unit tests** — `dbt test --select test_type:unit` against mocks; fast, no warehouse required.
3. **Integration tests** — `dbt run --select <changed_models> +` followed by `dbt test --select <changed_models> +` against a development schema with recent data.

Running the full integration test against a dev schema before merging catches the failures that unit tests miss — the ones that depend on data volume, distribution, or join behavior against real tables.

@feynman

dbt unit tests are the same as mocking a database call in application code — you isolate the transformation logic from the data so you can test it deterministically.

@card
id: tde-ch04-c009
order: 9
title: Data Quality SLAs
teaser: "We try to have good data" is not an SLA. An SLA is a specific, measurable commitment attached to a table — and the difference between the two is whether anyone gets paged when it's violated.

@explanation

An SLA-backed table has a documented quality commitment that looks something like: "this table has a null rate below 0.1% on `user_id` and `event_type`, freshness within 30 minutes of event time, and 99.9% availability on a 30-day rolling window." These numbers are written down, attached to the table in the catalog, and monitored with alerts that fire when a threshold is breached.

Without an explicit SLA, you can't answer three questions that consumers legitimately need to ask:
- Is this table fresh enough for my use case?
- If the table breaks tonight, will someone know and fix it?
- What's the historical reliability of this data source?

**Making SLAs explicit:**

1. Define the dimensions that matter for each table — typically freshness, completeness on key fields, row count bounds, and uptime.
2. Set thresholds based on consumer requirements, not what feels achievable. If a dashboard needs 15-minute-fresh data, the SLA is 15 minutes — not 2 hours because that's what's easy to deliver.
3. Attach the SLA to the table's catalog entry (dbt docs, Datahub, Atlan) so consumers can find it.
4. Instrument alerts that fire when the SLA is breached, routed to a clear owner.
5. Track compliance over time and report it. A monthly report showing 99.2% SLA compliance across tier-1 tables is a concrete accountability mechanism.

**SLA tiers** reduce the operational burden. A tier-1 table (executive dashboard, customer-facing metric) gets 24/7 alerting and a 30-minute response SLA. A tier-3 table (internal, low-frequency) gets a daily check and a best-effort response.

> [!warning] An SLA no one monitors is a false promise. Before publishing an SLA, verify that you have the alerting and on-call coverage to honor it.

@feynman

A data SLA is the same as an API uptime SLA — it's only meaningful if it's measurable, monitored, and enforced, not just stated in a README.

@card
id: tde-ch04-c010
order: 10
title: The Cost of Silent Data Quality Failures
teaser: The most expensive data quality failures aren't the loud ones that break a pipeline. They're the quiet ones that let wrong data reach a dashboard and stay there for weeks.

@explanation

A pipeline that crashes is visible. Someone gets paged. The table goes dark. Users notice. The fix happens within hours. The trust damage is limited because the failure was obvious and the response was fast.

A silent data quality failure looks like this: a deduplication bug introduces a 3% double-counting error in the orders table. The pipeline runs successfully every day. No alert fires. No one notices for six weeks. In that time, a VP uses the inflated order numbers in a board presentation. A pricing analyst builds a model on the inflated revenue baseline. An operations team sets headcount targets based on demand forecasts derived from the corrupted data.

The cost breakdown:
- Six weeks of decisions made on incorrect data.
- Hours of forensic work to determine when the corruption started and which downstream artifacts are affected.
- A reprocessing job that may require re-running months of pipeline history.
- An email to every consumer of the affected tables explaining what happened.
- The erosion of trust that takes months to rebuild, because once a table has been wrong, consumers don't know when to trust it again.

The last item is the most expensive and the least quantifiable. Trust in data is accumulated slowly through consistency and lost quickly through a single high-visibility failure. Engineers who haven't lived through a major data quality incident often underestimate this cost.

The prevention economics are straightforward: the dbt tests, expectations, and monitoring described in this chapter cost hours to implement per table. A single silent quality incident that reaches executive-level decision-making costs weeks to remediate. The math is never close. Quality instrumentation is not optional infrastructure — it's the cheapest insurance you can buy.

> [!warning] The silent failure is the dangerous one. The goal of every quality check you add is not to fix failures — it's to ensure that failures are never silent.

@feynman

A silent data quality failure is like a memory leak that doesn't crash the process — it's invisible right up until the system has been degraded for so long that the damage is everywhere and you can't find where it started.
