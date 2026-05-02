@chapter
id: depc-ch06-quality-validation-patterns
order: 6
title: Quality and Validation Patterns
summary: How to detect bad data before it corrupts downstream consumers — schema contracts, expectation testing, quarantine zones, circuit breakers, and anomaly detection.

@card
id: depc-ch06-c001
order: 1
title: The Data Quality Problem
teaser: Bad data moves through pipelines silently until a dashboard shows the wrong number and someone important notices. Quality gates catch it earlier.

@explanation

Data quality failures are unique in how they fail. Unlike code bugs that produce error messages, data quality problems produce wrong numbers — dashboards that undercount, reports that overclaim, model predictions that degrade silently.

The failure modes:

- **Schema changes:** a source column gets renamed or its type changes, and the downstream pipeline starts nulling out a field.
- **Volume anomalies:** an API returns zero rows because the source had an outage, and the pipeline writes an empty table to the destination.
- **Distribution shifts:** a column that used to range from 1-100 suddenly has values in the millions because the source changed units.
- **Referential breaks:** a fact table references a dimension key that no longer exists.
- **Duplicates:** a retry in the ingestion layer doubles the row count.

The quality patterns in this chapter create detection and handling mechanisms before bad data reaches consumers who trust it.

> [!info] The goal isn't zero data quality issues — sources will always produce bad data occasionally. The goal is detecting issues before downstream consumers are affected.

@feynman

Like software testing — not to guarantee bugs don't exist, but to catch them before they reach users.

@card
id: depc-ch06-c002
order: 2
title: Schema-on-Write Contracts
teaser: Define what the data must look like before it lands. Validate on ingest. Route violations to a quarantine zone instead of letting them corrupt the clean layer.

@explanation

**Schema-on-write** enforces a defined schema at write time, rejecting or routing non-conforming records before they enter the clean layer.

Contrast with **schema-on-read** (the data lake default), where the schema is applied at query time. Schema-on-read is flexible — raw data lands without enforcement — but validation failures only appear when a consumer queries and gets wrong types or errors.

Schema-on-write approaches:

**Column definitions in the destination table:** creating the destination table with explicit column types means the write fails when a record doesn't conform. Simple but often too strict — a single bad row fails the entire load.

**Explicit validation before write:** validate the DataFrame schema before the write step. Log or route bad records; write the good ones. Tools: dbt schema tests, Great Expectations, Soda, AWS Glue Schema Registry.

**Schema registry for streams:** in Kafka-based pipelines, a schema registry (Confluent Schema Registry, AWS Glue Schema Registry) enforces that producers serialize to a registered schema before publishing. Consumers are guaranteed to receive a compatible shape.

Example with Great Expectations:
```python
result = validator.expect_column_values_to_not_be_null("order_id")
result = validator.expect_column_values_to_be_between("amount", 0, 1_000_000)
if not result.success:
    route_to_quarantine(df)
```

> [!tip] A schema contract at ingest catches source-system changes within minutes of the first run. Without one, the change propagates silently and is discovered when someone notices a wrong number weeks later.

@feynman

Like type-checking at compile time vs runtime — catching the shape mismatch early is cheaper than debugging wrong results later.

@card
id: depc-ch06-c003
order: 3
title: Expectation Testing
teaser: Define what "good data" means as explicit, testable assertions. Run the assertions in the pipeline. Fail the pipeline when expectations are violated, not when consumers complain.

@explanation

**Expectation testing** formalizes data quality checks as assertions that run as part of the pipeline. Unlike ad-hoc checks, expectations are versioned, automated, and produce structured results.

Categories of expectations:

**Volume expectations:** "this table should have between 10K and 20K rows after today's ingest." Catches empty loads and sudden volume spikes.

**Completeness expectations:** "column `user_id` must be non-null in 100% of rows." Catches source-side schema changes that null out previously-required fields.

**Distribution expectations:** "column `age` values should be between 0 and 130." Catches unit changes and data corruption.

**Referential expectations:** "every `customer_id` in `fact_orders` should exist in `dim_customers`." Catches orphaned references.

**Freshness expectations:** "the latest row in this table should have a timestamp within the last 2 hours." Catches stuck pipelines that write nothing.

Tools: Great Expectations, Soda, dbt tests, MonteCarlo, Anomalo.

Expectations in a dbt project:
```yaml
models:
  - name: fact_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

The key discipline: define expectations before the pipeline is deployed, not after the first data quality incident.

> [!warning] Expectations that fail silently (log and continue) are better than nothing but worse than expectations that fail loudly (halt the pipeline and alert). Silent failures let bad data through; loud failures give you a chance to investigate before consumers see it.

@feynman

Like unit tests for data — specify what correct looks like up front; run automatically; fail with a clear message when violated.

@card
id: depc-ch06-c004
order: 4
title: Quarantine Zones
teaser: Route invalid records to a quarantine table rather than dropping or blocking them. Quarantined records are reprocessable once the underlying issue is fixed.

@explanation

A **quarantine zone** is a dedicated storage area for records that failed validation. Instead of dropping invalid records (data loss) or halting the pipeline (downtime), quarantined records wait in a known location for investigation and reprocessing.

Why quarantine instead of drop:
- Dropped records are gone. The source may not have them anymore. The quarantine zone gives you a chance to fix the issue and process the records correctly.
- Dropping silently is worse — you don't know how many records were lost or why.

Why quarantine instead of halt:
- A single bad record shouldn't block thousands of good records. Quarantine the bad, pass the good.
- Halting is appropriate only for critical violations (e.g., the entire payload is malformed). For partial violations, quarantine is less disruptive.

Quarantine table schema:
- The original record, as-received.
- The validation error that caused the quarantine.
- The source pipeline and run ID.
- The quarantine timestamp.

Reprocessing from quarantine:
1. Fix the validation rule or the upstream source.
2. Re-run the validation job on the quarantine table.
3. Move passing records to the destination; leave still-failing records in quarantine.

Operational practices:
- Alert on quarantine zone growth — a growing quarantine table means a recurring source problem.
- Set a TTL on quarantine records. Records older than 30 days with no remediation plan can be archived or dropped.

> [!tip] Build a small dashboard on your quarantine tables. "Top 10 validation failures this week" tells you where to invest in source-system improvement conversations.

@feynman

Like a returns desk at a warehouse — problematic items don't block the production line; they wait in a known location for someone to decide what to do.

@card
id: depc-ch06-c005
order: 5
title: Circuit Breakers
teaser: When a source delivers data that's catastrophically wrong — zero rows, wildly wrong volume, wrong schema — stop the pipeline before it damages the destination.

@explanation

A **circuit breaker** is a pre-write check that halts the pipeline when the incoming data is so abnormal that processing it would do more harm than stopping. Named after the electrical protection device.

Typical circuit breaker conditions:
- **Zero rows:** the source returned nothing. If the destination overwrites on this run, it wipes out a full day of data.
- **Volume drop >50%:** the source is returning half the normal number of rows. A pipeline that overwrites the destination today would delete records that existed yesterday.
- **Schema mismatch:** the incoming schema doesn't match the expected schema for this source. Writing it would produce nulls or type errors across the destination.
- **Freshness violation:** the source's most recent event timestamp is hours older than expected. The extract ran but returned stale data.

Implementation:
```python
expected_rows = load_historical_mean()
actual_rows = count(ingested_df)

if actual_rows < expected_rows * 0.5:
    raise CircuitBreakerException(
        f"Row count {actual_rows} is less than 50% of expected {expected_rows}. Halting."
    )
```

A halted pipeline is recoverable. A pipeline that overwrites a month of clean data with a zero-row extract is not recoverable without a bronze-layer replay.

Calibrate circuit breaker thresholds carefully:
- Too sensitive: frequent false positives that alert and halt for normal variation.
- Not sensitive enough: genuinely bad data passes through.

Start loose (50% drop, not 5%) and tighten as you observe the variance.

> [!warning] A circuit breaker that never trips provides false safety. Log every run's volume alongside the threshold; review quarterly to ensure thresholds still match reality.

@feynman

Like a fuse in a circuit — it exists to prevent a small problem from becoming a catastrophic one; the point is that it does trip when needed.

@card
id: depc-ch06-c006
order: 6
title: Anomaly Detection in Data
teaser: Rule-based expectations catch known failure modes. Anomaly detection catches the ones you didn't anticipate — sudden shifts in any metric the system has learned to expect.

@explanation

**Data anomaly detection** uses statistical or ML methods to identify unusual patterns in data quality metrics — volume, null rates, value distributions, referential integrity — that differ significantly from historical norms.

How it differs from expectation testing:
- **Expectations** check known conditions: "this column must be non-null." They catch regressions against an explicit contract.
- **Anomaly detection** learns from history and flags unusual deviations: "the null rate in this column jumped from 0.1% to 12% — that's unusual."

Common anomaly detection patterns:

**Z-score thresholds:** for each metric (row count, null rate, mean value), compute the z-score against recent history. Alert when |z| > 3.

**Seasonal decomposition:** row count naturally varies by day of week and time of month. Decompose the time series; alert on residuals above a threshold, not absolute values.

**Cohort comparison:** compare today's data distribution to the same day last week. Sharp divergence indicates an upstream change.

Tools: Monte Carlo, Bigeye, Anomalo, Soda Cloud anomaly detection, custom SQL + dbt-based checks.

When anomaly detection makes sense:
- Pipelines with too many metrics to manually define thresholds for.
- Metrics with natural seasonal variation that make fixed thresholds inaccurate.
- When you want a catch-all layer beyond explicit expectation tests.

Anomaly detection generates alerts that require human interpretation — it tells you something changed, not whether the change is a problem.

> [!info] Anomaly detection is not a replacement for explicit expectations. Run both. Expectations catch the problems you anticipated; anomaly detection catches the ones you didn't.

@feynman

Like setting a smoke detector in addition to a carbon monoxide detector — each catches a different class of problem; you need both.
