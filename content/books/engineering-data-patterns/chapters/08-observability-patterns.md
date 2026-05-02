@chapter
id: depc-ch08-observability-patterns
order: 8
title: Observability Patterns
summary: Lineage, pipeline metrics, freshness SLAs, quality dashboards, and the on-call ergonomics that separate systems people can actually debug at 2am from systems that require a postmortem to understand.

@card
id: depc-ch08-c001
order: 1
title: The Observability Gap in Data Systems
teaser: Application engineers have logs, metrics, and traces. Data engineers often have "the dashboard looked wrong this morning." That gap is the observability problem.

@explanation

Software observability — logs, metrics, distributed traces — is a mature discipline. Data observability is newer and less standardized, which is why data failures tend to be discovered by consumers rather than producers.

The observability questions data engineers need to answer:

- **Is the pipeline running?** Did it complete successfully, and when?
- **Did it produce the expected data?** Correct row count, correct time range, correct quality.
- **Where did the data come from?** Which source tables fed into this model, and which jobs transformed them?
- **Why is this row wrong?** Which upstream job introduced the incorrect value?
- **When did this metric change?** Was it the data or the logic?

The patterns in this chapter address each of these. Together, they form a **data observability layer** — the instrumentation that makes data systems debuggable.

> [!info] "Shift-left" in data observability means catching anomalies in the pipeline, not in the dashboard. Every minute between when bad data enters the system and when someone notices it increases the cost of the fix.

@feynman

Like adding metrics and traces to a backend service — without them, debugging is "I added print statements."

@card
id: depc-ch08-c002
order: 2
title: Data Lineage
teaser: Lineage tracks which source data fed into which downstream table. Without it, debugging data quality issues means manually tracing every upstream dependency.

@explanation

**Data lineage** is the directed graph of how data flows from sources through transformations to destinations. A complete lineage graph lets you answer: "this dashboard metric is wrong — which upstream table is the source, and which job produced it?"

Types of lineage:

**Column-level lineage:** tracks not just which tables are dependencies, but which columns. "The `revenue` column in `fact_orders_daily` comes from `SUM(amount)` on `stg_stripe_charges.charge_amount`." Column-level lineage is more useful for debugging but harder to collect.

**Job-level lineage:** "this job reads tables A and B and writes table C." Coarser but easier to collect automatically.

**Cross-system lineage:** traces data across system boundaries — from the operational database through the warehouse through the BI layer to the dashboard. End-to-end lineage is rare but extremely valuable when a dashboard is wrong.

How lineage is collected:
- **dbt lineage:** dbt's `ref()` and `source()` macros build a lineage graph automatically as part of the project manifest.
- **Airflow lineage:** OpenLineage (a standard protocol) instruments Airflow and Spark operators to emit lineage events to a compatible backend (Marquez, Atlan, DataHub).
- **Catalog-based lineage:** data catalog tools (Collibra, Alation, DataHub) build and expose lineage graphs.

> [!tip] dbt projects with consistent use of `ref()` get lineage almost for free. If you're hand-writing `FROM raw_stripe_charges` instead of `FROM {{ ref('stg_stripe_charges') }}`, you're also losing lineage.

@feynman

Like a call stack in a debugger — you can see exactly where this value came from and which function set it.

@card
id: depc-ch08-c003
order: 3
title: Pipeline Metrics
teaser: Instrument every pipeline run with duration, row counts, error counts, and retry counts. These metrics make capacity planning, debugging, and SLA management possible.

@explanation

**Pipeline metrics** are quantitative measurements about how a pipeline ran, emitted consistently so they can be aggregated, trended, and alerted on.

Core metrics to instrument:

- **Duration:** how long each task and DAG run took. Trend line over time detects gradual degradation before it becomes an incident.
- **Row count:** how many rows were read from source, how many passed validation, how many were written to destination. A 0-row load is detectable before it corrupts downstream.
- **Error count:** how many records were quarantined or failed validation.
- **Retry count:** how many times did a task retry before succeeding or failing. High retry rates indicate flaky sources or infrastructure.
- **Lag:** for streaming pipelines, how far behind the consumer is from the producer.

Where to emit metrics:
- **Orchestrator metadata tables:** Airflow stores task duration and state in its metadata database. Query it.
- **Custom instrumentation:** emit metrics to Prometheus, Datadog, CloudWatch from within pipeline code.
- **Data quality tools:** Great Expectations and Soda emit run metadata as structured results that can be stored and queried.

Example pipeline metric instrumentation:
```python
run_start = time.time()
row_count = write_to_destination(df)
duration = time.time() - run_start
emit_metric("pipeline.rows_written", row_count, tags=["pipeline:orders_daily"])
emit_metric("pipeline.duration_seconds", duration, tags=["pipeline:orders_daily"])
```

> [!info] Duration trending is one of the highest-value pipeline metrics. A job that ran in 10 minutes six months ago and now runs in 90 minutes has a problem — and the data is already there to see it.

@feynman

Like application performance monitoring for code — you need the numbers to know which part is slow before you can improve it.

@card
id: depc-ch08-c004
order: 4
title: Freshness SLAs
teaser: Define how stale data is allowed to be for each table, then measure and alert on violations. Freshness is a first-class service level agreement, not an assumption.

@explanation

A **freshness SLA** (service level agreement) defines the maximum acceptable staleness for a given table. "The `fact_orders` table must have data no older than 2 hours by 9 AM each business day" is a freshness SLA.

Why freshness SLAs matter:
- Consumers don't know a pipeline is stuck unless they check timestamps. A dashboard that says "yesterday's revenue" but shows numbers from three days ago is more dangerous than an error message.
- On-call engineers need objective criteria for whether a pipeline is within acceptable range or an incident.
- Data contracts between teams need freshness specifications, not just schema specifications.

Implementing freshness checks:
```sql
-- dbt freshness check
version: 2
sources:
  - name: stripe
    tables:
      - name: charges
        freshness:
          warn_after: {count: 1, period: hour}
          error_after: {count: 3, period: hour}
        loaded_at_field: created_at
```

Where freshness breaks down:
- **Low-volume tables:** a table that normally receives 100 rows per hour but receives zero for 3 hours might be within its freshness SLA but still indicate a problem.
- **Seasonal variation:** tables with lower weekend volume will appear "stale" on Monday morning even if they're correct. Freshness thresholds should be schedule-aware.
- **Missing vs stale distinction:** freshness checks only detect that the latest row timestamp is old. They don't detect whether yesterday's data is complete (volume check) or correct (quality check).

> [!tip] Build freshness checks into the pipeline's self-check step and into a consumer-facing data catalog. Consumers should be able to see freshness status without paging the data team.

@feynman

Like a "last updated" timestamp on a shared document — without it, you don't know whether to trust the numbers or refresh the page.

@card
id: depc-ch08-c005
order: 5
title: On-Call Ergonomics
teaser: A pipeline that works great in normal conditions but produces incomprehensible errors at 2am is a liability. Design for the worst debugging context, not the best.

@explanation

**On-call ergonomics** is the practice of designing pipelines so that the on-call engineer who receives an alert at 2am can diagnose and resolve the issue without deep context of how the pipeline was originally built.

The failure mode to avoid: an on-call engineer who didn't build the pipeline receives an alert, opens the DAG, and finds a wall of custom Python, opaque task names, no comments about what the pipeline is supposed to do, and error messages that say `NullPointerException at line 214`.

Design principles for on-call ergonomics:

**Descriptive task names.** `extract_stripe_charges_last_24h` is debuggable; `task_1` is not.

**Meaningful error messages.** When the circuit breaker trips, emit a message that says why: "Expected ≥10,000 rows. Got 0. Source: Stripe charges API. Possible cause: API outage or credential expiry."

**Runbooks.** A short document linked from the DAG or alert that describes: what this pipeline does, what the common failure modes are, and the first three steps to investigate. 90% of incidents are one of three causes; a runbook that covers the top 3 saves hours.

**Shallow dependency graphs.** A DAG where task failure cascades through 20 dependent tasks is harder to diagnose than one where failures are isolated. Limit fan-out in critical paths.

**Idempotent recovery.** Once the root cause is fixed, the on-call engineer should be able to clear the stuck tasks and re-run without risk of data corruption.

> [!tip] After every incident, add a runbook entry for the failure mode that caused it. The fifth occurrence of the same failure should take under 5 minutes to resolve.

@feynman

Like leaving a clear note when you pass code to a colleague — the context you carry in your head is lost when they're debugging at 2am.

@card
id: depc-ch08-c006
order: 6
title: Data Quality Dashboards
teaser: Centralize quality metrics into a single view so the team and its consumers can see the health of the data layer at a glance.

@explanation

A **data quality dashboard** aggregates the results of expectation tests, freshness checks, anomaly alerts, and quarantine volumes into a single view — the "health dashboard" for the data layer.

What to show:
- **Table freshness:** last updated timestamp and freshness SLA status (green/yellow/red) for each critical table.
- **Quality check results:** pass/fail per expectation test, trend over the last 30 days.
- **Quarantine volumes:** rows quarantined per source per day.
- **Pipeline run status:** last successful run per DAG, success rate over the last 7 days.
- **Open incidents:** active data quality issues with owning team and estimated resolution.

Who consumes it:
- **On-call engineers:** see at a glance whether anything is broken before investigating individual pipelines.
- **Data consumers (analysts, scientists):** check whether the tables they're about to query have fresh, quality-checked data.
- **Data leadership:** understand the health of the data layer without pinging an engineer.

Building it:
- Most orchestrators (Airflow, Prefect, Dagster) expose a UI with run history — use it as the source for pipeline status.
- Great Expectations / Soda produce structured results that can be stored in a database and visualized with any BI tool.
- Data catalog tools (DataHub, Atlan, Monte Carlo) offer built-in quality dashboards with cross-source aggregation.

> [!info] A quality dashboard that shows only "pass" and "fail" is less useful than one that shows trend lines. A table that passes today but has been trending toward failure for a week is more actionable than a table that failed today with no history.

@feynman

Like a CI/CD dashboard for code — test pass rates and build health in one place, so you see the trend, not just today's state.
