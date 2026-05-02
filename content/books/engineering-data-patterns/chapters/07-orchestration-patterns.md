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
