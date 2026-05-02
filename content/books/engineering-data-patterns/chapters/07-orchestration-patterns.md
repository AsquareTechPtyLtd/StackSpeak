@chapter
id: depc-ch07-orchestration-patterns
order: 7
title: Orchestration Patterns
summary: DAG design, dynamic tasks, idempotency-first scheduling, and how to structure pipelines that fail gracefully, retry safely, and scale without becoming unmaintainable.

@card
id: depc-ch07-c001
order: 1
title: What Orchestration Actually Is
teaser: Orchestration is dependency management and scheduling for data jobs — not the same as execution. The orchestrator decides what runs and when; the worker does the work.

@explanation

**Orchestration** in data engineering means: coordinate which jobs run, in which order, with what dependencies, and what to do when something fails.

The key distinction: the orchestrator (Airflow, Prefect, Dagster, Mage, dbt Cloud, AWS Step Functions) is not where computation happens. It triggers, monitors, and retries jobs that run on separate execution infrastructure (Spark clusters, Snowflake warehouses, Python processes, dbt runners).

What a good orchestrator handles:
- **Dependencies:** job B can't start until job A completes successfully.
- **Scheduling:** job A runs daily at 6 AM UTC.
- **Retries:** if job A fails, retry it up to 3 times with exponential backoff.
- **Observability:** which runs succeeded, which failed, what the failure message was.
- **Backfills:** re-run job A for all dates between 2026-01-01 and 2026-01-15.
- **Alerting:** notify the on-call engineer when job A fails twice in a row.

What an orchestrator doesn't do:
- Run heavy computation itself. The Airflow worker that triggers a Spark job is not Spark.
- Validate data quality (that's the pipeline's responsibility).
- Automatically fix failed jobs (humans still do that).

> [!info] The best orchestration is the one your team will actually maintain. A complex, feature-rich orchestrator that nobody understands is worse than a simple scheduler that everyone trusts.

@feynman

Like a stage manager in a theater — they don't act, build sets, or run lights; they make sure everyone else does their job in the right order.

@card
id: depc-ch07-c002
order: 2
title: DAG Decomposition
teaser: A DAG that does everything in one task is a liability. Decompose by failure domain — each task should be restartable independently without re-running the others.

@explanation

**DAG decomposition** is the practice of splitting a complex pipeline into discrete tasks, each with a clear boundary, so that failures can be isolated and retried independently.

A monolithic task that extracts, transforms, loads, and validates in one Python function has several problems:
- If validation fails at step 4, the entire job re-runs from step 1 on retry, including the expensive extraction.
- You can't observe which step in the sequence is slow — the whole function appears as one unit.
- Any partial change requires re-testing and re-deploying the entire task.

Well-decomposed DAG structure:
```
extract_from_source
    ↓
validate_raw_schema
    ↓
transform_to_staging
    ↓
run_quality_checks
    ↓
load_to_mart
    ↓
refresh_semantic_layer
```

Each task is idempotent. If `transform_to_staging` fails, retrying it doesn't re-run `extract_from_source`. The task retry picks up from the failed task.

Guidelines for decomposition:
- **Split by failure domain:** tasks that fail for different reasons should be separate.
- **Split by execution environment:** a Spark job and a SQL query should be separate tasks even if they're sequential.
- **Don't split too finely:** a task per SQL statement produces DAGs with 200 tasks that are impossible to debug.
- **One task = one unit of retry.** If it makes sense to retry just this piece, it's the right granularity.

> [!tip] If a DAG has one task and a failure means re-running everything, it's not a DAG — it's a script. Decompose until each retry unit makes sense on its own.

@feynman

Like microservices vs monolith — decompose to the granularity where each piece fails and restarts independently, then stop.

@card
id: depc-ch07-c003
order: 3
title: Idempotency-First Design
teaser: Every DAG task should produce the same result whether it's the first run or the tenth. This one property makes retries, backfills, and incidents manageable.

@explanation

**Idempotency-first design** means every task in the DAG is built to be safe to re-run without side effects. This should be the default assumption, not an afterthought.

The trigger: Airflow and most orchestrators retry failed tasks automatically. If a task appends rows on each run, a retry produces duplicates. If a task sends an email, a retry sends the email again. Idempotency prevents both.

Patterns for idempotent tasks:

**Parameterize by logical date, not wall-clock time.** In Airflow, use `{{ ds }}` (the logical date) instead of `datetime.now()`. The task run for 2026-01-01 always processes 2026-01-01's data, whether it ran on Jan 1 or was backfilled on Jan 10.

**Partition-overwrite writes.** Delete the destination partition for the logical date, then write the new result. Any re-run deletes and rewrites the same partition.

**Merge/upsert instead of append.** For non-partitioned destinations, MERGE on the natural key. Duplicates are not possible because the same key is updated, not duplicated.

**Checkpoint state externally.** If a task partially completes and the machine dies, the next run should be able to skip work that was already done. Store checkpoints in durable state (S3, a database row).

The backfill test: if you backfill a 30-day range and the final state of the destination tables is identical to running each day incrementally, the pipeline is idempotent.

> [!warning] `datetime.now()` inside a DAG task is a sign the task is not idempotent. Replace it with the logical execution date passed as a parameter.

@feynman

Like writing to a temp file and renaming atomically — the operation either happens completely or not at all, and you can always redo it safely.

@card
id: depc-ch07-c004
order: 4
title: Dynamic Task Generation
teaser: Generate DAG tasks programmatically from a configuration or database query, rather than hardcoding each task. Scales without DAG code changes.

@explanation

**Dynamic task generation** creates tasks at runtime based on a configuration, database query, or upstream task result, rather than hardcoding each task at DAG definition time.

When it applies: a pipeline that needs to run the same logic for each of 50 clients, 200 tables, or 10 environments. Hardcoding produces a DAG with 50 identical tasks that diverge as you make incremental changes.

Airflow 2.5+ TaskFlow API with dynamic task mapping:
```python
@task
def get_sources():
    return ["clients/a", "clients/b", "clients/c"]

@task
def process_source(source: str):
    # runs once per item in the list
    run_etl(source)

sources = get_sources()
process_source.expand(source=sources)
```

The advantage: adding a fourth source requires no DAG code change — the source list in the database grows by one row and the DAG automatically generates an additional task.

Patterns and risks:
- **Fan-out with concurrency limits.** Dynamic mapping can generate hundreds of tasks simultaneously. Set `max_active_tis_per_dag` to avoid overwhelming workers or downstream systems.
- **Homogeneous tasks only.** Dynamic tasks should all do the same thing on different inputs. If task A needs different logic from task B, they should be explicitly defined.
- **Observability.** Each dynamically mapped task instance is observable independently, which is better than a loop inside one task where failure is opaque.

> [!tip] Put the configuration that drives dynamic tasks in a database table, not in the DAG code. This lets you add/remove sources without any DAG deployment.

@feynman

Like a `for` loop vs copy-pasted code — you write the logic once and map it over inputs, rather than maintaining N copies that diverge.

@card
id: depc-ch07-c005
order: 5
title: Sensors vs Schedulers
teaser: Scheduled tasks run at a fixed time; sensor tasks wait for a condition to be true. Use sensors when downstream tasks shouldn't run until data is actually ready.

@explanation

A **scheduler** triggers a task at a wall-clock time: "run at 6 AM every day." A **sensor** triggers a task when a condition is met: "run when the upstream file exists in S3."

When sensors are the right choice:
- The upstream source doesn't run on a predictable schedule. It delivers data "sometime in the morning."
- The upstream source is on a different team's pipeline. You depend on their data but don't control their schedule.
- You want to start processing as soon as upstream data arrives, not at the earliest common scheduled time.

Airflow built-in sensors: `S3KeySensor` (file exists), `ExternalTaskSensor` (another DAG run succeeded), `SqlSensor` (query returns rows), `HttpSensor` (endpoint returns 200).

Sensor risk: **sensor poke modes and timeouts.**
- `mode="poke"` occupies a worker slot while waiting. If many sensors poke simultaneously, worker slots exhaust.
- `mode="reschedule"` releases the worker slot while waiting, then re-checks. Preferred for sensors with long wait times.
- Always set a `timeout`. A sensor waiting indefinitely for data that will never arrive blocks the task slot forever.

When not to use sensors:
- The upstream data always arrives before the schedule anyway. A sensor adds latency to wait for a condition that's always already true.
- You're coupling two pipelines that should be independently deployable. Prefer writing to a well-known location and polling, rather than hardwired ExternalTaskSensor dependencies.

> [!info] ExternalTaskSensor across teams creates tight coupling. Consider data-availability signals (a sentinel file, a database flag) as a decoupled alternative.

@feynman

Like a function waiting on a promise vs a cron job — the sensor waits for a real signal; the scheduler just bets the data is ready by then.

@card
id: depc-ch07-c006
order: 6
title: Sub-DAGs vs Task Groups
teaser: Sub-DAGs were the old way to group related tasks. Task groups are the modern replacement — lighter weight, better observability, same conceptual grouping.

@explanation

Airflow offers two ways to logically group related tasks within a DAG: **sub-DAGs** (legacy) and **task groups** (modern replacement).

**Sub-DAGs** run a nested DAG as a single task from the parent's perspective. Problems: they use a separate DAG runner, creating scheduling complexity; they have separate state from the parent DAG; debugging failures requires navigating to the sub-DAG; they're deprecated in Airflow 2.x.

**Task groups** provide visual and logical grouping without separate scheduling or state. They're purely organizational — tasks within a group are still tasks in the parent DAG, but the UI collapses them into a single node for readability.

```python
from airflow.utils.task_group import TaskGroup

with TaskGroup("transform") as transform_group:
    clean = PythonOperator(task_id="clean_data", ...)
    validate = PythonOperator(task_id="validate_data", ...)
    load = PythonOperator(task_id="load_to_staging", ...)
    clean >> validate >> load
```

Use task groups when:
- A logical step in the pipeline (e.g., "transformation") has 4-5 sequential tasks that are always executed together.
- You want the DAG visualization to be readable without showing 30 task nodes.
- Multiple parallel sub-processes share a common pre/post step.

> [!tip] Group tasks by business step (ingest, transform, validate, serve), not by technical mechanism (SQL tasks, Python tasks). Business-step grouping makes the DAG graph readable by non-engineers.

@feynman

Like modules in a codebase — task groups are namespacing for readability, not separate binaries.

@card
id: depc-ch07-c007
order: 7
title: Cross-DAG Dependencies
teaser: When one pipeline must wait for another team's pipeline to complete, the dependency must be explicit — and it must be decoupled enough that one team can deploy independently.

@explanation

**Cross-DAG dependencies** arise when a downstream pipeline can only run after an upstream pipeline from a different DAG (often owned by a different team) has completed.

The tight-coupling approach: use Airflow's `ExternalTaskSensor` to wait for a specific task in another DAG to complete. Simple; no extra infrastructure; but creates a compile-time coupling between two separately-deployed DAGs. If the upstream DAG is renamed or the task is reorganized, the downstream sensor silently never fires.

The decoupled approach: use a **data-availability signal** instead of a task dependency. After the upstream pipeline completes, it writes a sentinel file or flag (an S3 object, a database row, a Kafka event). The downstream pipeline uses an `S3KeySensor` or `SqlSensor` to wait for the signal.

Benefits of signal-based decoupling:
- The upstream team can rename tasks, change DAG structure, or migrate to a different orchestrator without breaking downstream sensors.
- The signal is inspectable by human operators ("has today's sentinel appeared?").
- The signal can carry metadata (row count, completion timestamp, schema version).

Signal naming convention: `s3://data-signals/{dataset_name}/{date}/SUCCESS` is a common pattern. The upstream job writes the SUCCESS file after validating its output; downstream jobs poll for it.

> [!tip] If your ExternalTaskSensor references a task ID that was renamed six months ago, the sensor is in a permanent wait state that only shows up as a long-running sensor. Signal-based dependencies fail more clearly.

@feynman

Like a webhook notification rather than polling an internal state variable — you decouple the observer from the implementation details of the producer.

@card
id: depc-ch07-c008
order: 8
title: Retry Strategies and Backoff
teaser: How a pipeline retries failed tasks determines whether it recovers gracefully or amplifies the failure. Immediate retries, exponential backoff, and dead-letter routing each fit different failure modes.

@explanation

A failed task isn't an incident — it's an expected event. How the orchestrator handles retries determines whether the failure resolves automatically or escalates.

**Immediate retry:** retry the task immediately after failure. Works for transient failures (brief network blip, lock contention that resolves in seconds). Wrong for failures caused by downstream overload — retrying immediately may make the overload worse.

**Exponential backoff with jitter:** retry after a delay that doubles with each attempt, plus random jitter to prevent synchronized retry storms. Standard for API calls and external service dependencies.

```python
# Airflow task with exponential backoff
my_task = PythonOperator(
    task_id='call_api',
    retry_delay=timedelta(seconds=30),
    retries=5,
    retry_exponential_backoff=True,
    max_retry_delay=timedelta(minutes=30),
)
```

**Fixed retry with extended delay:** for pipeline failures caused by upstream data not yet being available (e.g., a source that delivers "sometime between midnight and 6 AM"), retry every 30 minutes instead of immediately. The task will eventually succeed when the data arrives.

**Dead-letter routing:** after N retries, stop retrying and route to a failure queue or alert channel. The task needs human intervention; continuing to retry would mask the failure.

Retry strategy by failure category:
- Network timeout → exponential backoff, up to 5 retries.
- Source data not available → fixed interval retry, up to 12 attempts over 6 hours.
- Schema mismatch → no retry; alert immediately (retrying won't fix a schema problem).
- Out of memory → no retry; alert; the task needs to be redesigned.

> [!warning] Retrying schema failures wastes compute and delays alerting. Distinguish failure categories in error handling and only retry failures that are likely to resolve on their own.

@feynman

Like reconnect logic in a network client — exponential backoff prevents hammering an overloaded server while still recovering automatically when it comes back.

@card
id: depc-ch07-c009
order: 9
title: Event-Driven Orchestration
teaser: Schedule-driven pipelines run whether upstream data is ready or not. Event-driven pipelines start when data actually arrives — lower latency, lower idle compute, fewer races.

@explanation

**Event-driven orchestration** triggers pipeline runs in response to data events rather than on a fixed schedule.

Why schedule-driven orchestration creates problems:
- A 6 AM scheduled run starts before upstream data arrives, fails, retries, eventually succeeds — but the SLA was missed.
- A 6 AM scheduled run starts after upstream data arrived at 3 AM. Three hours of unnecessary latency.
- A scheduled run that has nothing to process still occupies an orchestrator slot.

Event sources that can trigger pipeline runs:
- **Object storage events:** S3 event notifications or SNS trigger a Lambda/Cloud Function that starts the DAG when a new file lands.
- **Message queue messages:** an SQS/Pub/Sub message published by an upstream service triggers the consumer pipeline.
- **Database CDC events:** a change in the source database triggers the ingestion pipeline via Debezium.
- **Webhook calls:** a third-party system calls your webhook endpoint on data ready, triggering a DAG via Airflow's REST API.

Airflow REST API trigger:
```bash
curl -X POST \
  "http://airflow/api/v1/dags/orders_etl/dagRuns" \
  -H "Content-Type: application/json" \
  -d '{"conf": {"source_file": "s3://bucket/2026-05-01/orders.parquet"}}'
```

Prefect, Dagster, and Temporal all have first-class event-driven execution models with built-in connectors for common event sources.

> [!info] Schedule-driven orchestration is simpler to reason about and debug. Event-driven reduces latency and idle compute. Most production systems use both: event-driven for latency-sensitive paths, schedule-driven as a fallback and for batch jobs.

@feynman

Like an interrupt-driven program vs a polling loop — the interrupt fires when something actually happens; the poll checks whether something happened and usually finds nothing.

@card
id: depc-ch07-c010
order: 10
title: DAG Deployment and Versioning
teaser: Deploying a changed DAG while runs are in flight can break in-progress runs. Safe deployment requires understanding how your orchestrator handles DAG code changes mid-run.

@explanation

**DAG deployment** — pushing new pipeline code to production — is riskier in orchestrated data systems than in stateless web services. An in-flight DAG run may hold references to task definitions that no longer exist in the new code.

Failure modes from naive deployment:
- A running DAG has tasks A → B → C. You deploy a new version that renames task B to B2. The running instance tries to start B; it no longer exists in the DAG definition; the run fails.
- A paused sensor is waiting on a task ID that was reorganized. After deployment, the task ID doesn't match; the sensor never fires.
- Task retry state held in the Airflow metadata database references a task that was removed.

Safe deployment strategies:

**Versioned DAG IDs:** name DAGs with a version suffix (`orders_etl_v2`). The old version runs to completion; the new version starts fresh for new runs. Expensive in large deployments but safest.

**Pause-then-deploy:** before deploying a changed DAG, pause it (prevent new runs from starting), wait for in-flight runs to complete, deploy, resume. Works for pipelines with short run times.

**Blue-green DAG deployment:** run two versions of the DAG simultaneously for a switchover period. New runs start on the new version; old runs complete on the old version. Requires naming convention discipline.

**Non-breaking changes only:** design changes to be additive (new tasks added, old tasks kept with no changes). Removes the deployment risk entirely for most routine changes.

> [!tip] Treat mid-flight failures after a deployment as a distinct failure category in your runbook. "Did we deploy recently?" is always in the first three diagnostic questions.

@feynman

Like database schema migrations — forward-compatible changes can be deployed at any time; breaking changes require a coordinated cutover.
