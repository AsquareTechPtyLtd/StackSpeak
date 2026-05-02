@chapter
id: tde-ch05-orchestration-and-scheduling
order: 5
title: Orchestration and Scheduling
summary: Orchestration is the layer that turns a collection of scripts into a reliable pipeline — it manages dependencies, retries, schedules, and visibility so you spend less time debugging silent failures at 3am.

@card
id: tde-ch05-c001
order: 1
title: What Orchestrators Actually Do
teaser: An orchestrator does not run your code — it coordinates when and in what order your code runs, and tells you what happened afterward.

@explanation

Cron schedules a command. An orchestrator manages a graph of commands. That distinction sounds small until a pipeline has 40 tasks, 12 upstream dependencies, a retry requirement on network errors, and a Slack alert when something fails. Cron cannot do any of that.

What an orchestrator actually provides:

- **Dependency management** — task B does not start until task A succeeds. The ordering is explicit in code, not assumed from wall-clock timing.
- **Retry logic** — transient failures (network blips, throttled APIs) get retried automatically without waking a human up.
- **Scheduling** — runs at 6am UTC every day, or every hour, or triggered by an external event.
- **Status and observability** — a UI or API surface that shows which runs succeeded, which failed, how long each task took, and why a specific run went wrong.
- **Backfill** — the ability to re-run historical periods without rewriting code.

The orchestrator as analogy: it is the air traffic controller of the data stack. It does not fly the planes (your transform scripts, SQL models, API calls). It sequences them, prevents collisions, and raises an alarm when one goes off course.

The cost of not having one: pipelines that silently fail because a downstream task started before an upstream one finished, nobody noticing until an analyst asks why a dashboard is stale.

> [!info] If your "orchestration" is a set of cron jobs that run sequentially and hope the previous one finished, you have scheduling but not orchestration. The distinction matters when something goes wrong.

@feynman

A cron job is an alarm clock that wakes your code up; an orchestrator is a project manager who checks whether the previous team finished before handing off work to the next one.

@card
id: tde-ch05-c002
order: 2
title: Airflow Fundamentals
teaser: Airflow is the most widely deployed orchestrator in data engineering — understanding its architecture explains both why it works and where it will hurt you.

@explanation

Apache Airflow models pipelines as DAGs (Directed Acyclic Graphs): a Python file that defines tasks and the dependencies between them. "Acyclic" means no task can depend on itself, directly or transitively — which prevents infinite loops and makes execution order deterministic.

The Airflow architecture has four components:

- **Scheduler** — parses DAG files on disk, determines which task instances are ready to run based on schedule and dependency state, and submits them to the executor.
- **Executor** — takes submitted tasks and runs them. LocalExecutor runs tasks in subprocesses on the same machine (fine for development, limited for production). CeleryExecutor distributes tasks to a pool of worker nodes via a message queue (Redis or RabbitMQ). KubernetesExecutor spawns a fresh pod per task — strong isolation, good for heterogeneous resource requirements.
- **Workers** — the processes or pods that actually execute task code.
- **Metadata database** — a Postgres (or MySQL) instance that stores DAG runs, task states, and Airflow configuration. This is the single source of truth for run history and status.

DAGs are defined in Python, which means you can generate them programmatically — a DAG factory pattern can produce 50 similarly-structured DAGs from a config file. This is powerful and also a footgun; dynamic DAGs that are slow to parse will stall the scheduler.

XCom (cross-communication) lets tasks push and pull small values from the metadata database. Task A pushes a record count; task B pulls it to decide whether to proceed. Use XCom for metadata, not data — it is stored in the database, not object storage, so it cannot handle a DataFrame.

> [!warning] XCom is for small values (strings, counts, identifiers). Pushing a pandas DataFrame through XCom serializes it into the metadata database and will cause performance and reliability problems at any meaningful scale.

@feynman

Airflow is like a factory floor manager who reads the shift schedule (DAG file), checks which stations are ready (scheduler), sends jobs to workers (executor), and logs everything in a ledger (metadata database) — but the manager cannot do the actual manufacturing.

@card
id: tde-ch05-c003
order: 3
title: Prefect and Dagster as Modern Alternatives
teaser: Prefect and Dagster fix real Airflow pain points but make different bets about the right mental model — one is task-centric, the other is asset-centric.

@explanation

Airflow was built in 2014 and its architecture shows it. DAG files must be importable by the scheduler (which means import-time side effects crash it), the local development experience is painful to set up, and the UI is functional but dated. Prefect and Dagster emerged to address these problems, but they are not the same alternative.

**Prefect** stays in the task-execution model but makes it more Python-native. You decorate functions with `@flow` and `@task`; the orchestration graph is inferred from how functions call each other. Prefect's hybrid execution model separates the control plane (Prefect Cloud or a self-hosted server that tracks state) from the execution plane (your own infrastructure that runs the code). This means you get observability without giving a third party network access to your data. Observable by default means every run emits structured events without configuration.

**Dagster** makes a different bet: it models pipelines as the data assets they produce, not the tasks they run. A software-defined asset (SDA) is a Python function that describes a table, a file, or an ML model — and Dagster builds the dependency graph from those asset definitions. Type-checked I/O managers enforce that the data flowing between assets matches what the downstream asset expects. Lineage is a first-class concept, not an afterthought.

When to prefer each:

- **Airflow** — large existing investment, complex multi-team deployments, mature plugin ecosystem needed.
- **Prefect** — new team, wants Python-native workflows, needs easy local dev, uses managed cloud.
- **Dagster** — asset-oriented thinking, wants built-in lineage, teams that care about data catalog integration and type safety.

> [!tip] The best reason to choose Dagster over Airflow for a greenfield project is not features — it is that defining assets forces you to think about what the pipeline produces, which leads to better-designed pipelines.

@feynman

Airflow is a task runner that can be orchestrated into pipelines; Dagster is a data asset manager that happens to also execute the code that produces those assets — they answer different questions first.

@card
id: tde-ch05-c004
order: 4
title: The Software-Defined Asset Paradigm
teaser: Defining pipelines in terms of the data they produce — not the code that runs — changes how you reason about dependencies, lineage, and what "done" means.

@explanation

Traditional orchestration asks: "what tasks need to run, and in what order?" The software-defined asset (SDA) paradigm asks: "what data assets need to exist, and what do they depend on?" The shift looks subtle but changes the design of pipelines in practice.

In Dagster's SDA model, you define assets like this: `orders_by_region` is a Snowflake table. It depends on `raw_orders` (another asset). When `raw_orders` is updated, Dagster knows `orders_by_region` may be stale and can offer to re-materialize it. The code that computes `orders_by_region` is attached to the asset definition, not to a task in a DAG.

The practical consequences:

- **Lineage by construction.** The asset graph is the lineage graph. You do not need a separate metadata catalog to trace where a table came from — it is encoded in the asset definitions.
- **Asset materialization vs. task execution.** A task succeeds or fails. An asset is materialized or stale. The latter framing aligns with how analysts actually think about data: "is this table fresh?" not "did the task run?"
- **Incremental computation.** Dagster can partition assets by date and only re-materialize the partitions that are stale, rather than rerunning the entire pipeline.
- **Type-checked I/O.** I/O managers validate that the data flowing between assets matches the declared schema. A type mismatch fails at the boundary, not silently downstream.

The model aligns data engineering with software engineering thinking: assets are like functions with defined inputs and outputs, composable, testable, and refactorable with confidence.

> [!info] The asset-centric model does not replace task orchestration — it is a higher-level abstraction on top of it. Under the hood, materializing an asset still executes code. The difference is in what you optimize for and what the system tracks.

@feynman

It is the difference between writing a function that runs some code and writing a function that returns a value — the SDA paradigm keeps focus on the output, which makes it easier to reason about whether you have what you need.

@card
id: tde-ch05-c005
order: 5
title: DAG Design Principles
teaser: A badly designed DAG is a maintenance debt that compounds — small idempotent tasks with clear names pay dividends every time you debug, retry, or extend the pipeline.

@explanation

The most common DAG design mistake is the monolithic task: one Python function that pulls data, transforms it, validates it, and loads it — 400 lines of code, all-or-nothing retry behavior, no visibility into which step failed. When it fails at 5am, you have no idea where.

The guiding principle is small idempotent tasks. Idempotent means running the task twice produces the same result as running it once. A task that appends rows to a table without deduplicating is not idempotent — retrying it doubles the data. A task that does a `MERGE` or writes to a partition with `OVERWRITE` is idempotent — retrying it is safe.

Design rules that hold up in production:

- **One logical unit of work per task.** Extract is a task. Transform is a task. Load is a task. Validation is a task. Each can succeed, fail, and be retried independently.
- **Task names reflect the output, not the code.** `load_orders_to_staging` is better than `run_etl_script`. A failing task name should tell you what data is missing, not what function broke.
- **Do not pass large data through XCom.** If task B needs the data from task A, write it to S3 (or GCS, or your warehouse staging area) and pass the path via XCom. XCom is for coordinates, not cargo.
- **Keep DAGs short.** A DAG with 200 tasks is hard to read, slow to parse, and difficult to own. If a DAG has grown past ~30 tasks, question whether it should be split.

> [!warning] Putting all transformation logic in a single task because "it is easier to write" is technical debt you pay during every incident. The retry granularity of your task design determines how long failures take to recover from.

@feynman

Each task should be like a pure function — take an input, produce an output, have no side effects that make retrying it dangerous — and the DAG is just the composition of those functions.

@card
id: tde-ch05-c006
order: 6
title: Sensors and Triggers
teaser: Sensors let your pipeline wait for an external condition rather than assuming data will arrive on time — which is almost never a safe assumption in production.

@explanation

The naive approach to data dependencies across systems: schedule pipeline B to run 30 minutes after pipeline A is supposed to finish. This works until pipeline A runs late, and then pipeline B either fails or processes stale data silently. The correct approach: pipeline B uses a sensor to wait for pipeline A's output to actually exist before starting.

A sensor is a task that polls for a condition. Examples:

- `S3KeySensor` in Airflow — waits for a specific file to appear in an S3 bucket. The pipeline starts when the file arrives, not at a fixed time.
- `ExternalTaskSensor` — waits for a task or DAG in another Airflow DAG to reach a success state.
- `SqlSensor` — polls a SQL query until it returns a truthy result (e.g., a row count above zero in a source table).

The distinction between "sensor in the orchestrator" and "sleep loop in task code" matters. A `time.sleep(300)` in a Python task occupies a worker slot for the entire wait period, consumes resources, and is invisible in the orchestrator UI. A sensor runs in the orchestrator, consumes minimal resources between polls, and shows its state in the UI.

Key sensor configuration parameters:

- **`poke_interval`** — how often the sensor checks the condition (default 60 seconds in Airflow; set higher for slow-changing conditions to reduce load).
- **`timeout`** — how long the sensor will wait before failing. Set this; an uncapped sensor that waits forever blocks downstream tasks indefinitely.
- **`mode`** — `poke` (holds a worker slot) vs. `reschedule` (releases the slot between polls). For sensors that wait hours, use `reschedule`.

> [!tip] Set a `timeout` on every sensor. A sensor waiting forever is a silent pipeline hang — nothing fails, nothing alerts, data just stops flowing.

@feynman

A sensor is a patient colleague who checks the inbox every few minutes and only calls you when the thing you are waiting for has actually arrived — instead of you blocking your entire afternoon waiting for an email that might be late.

@card
id: tde-ch05-c007
order: 7
title: Retries and Failure Handling
teaser: Retries recover from transient failures automatically — but retrying a data failure is not recovery, it is just delaying the alert while the problem compounds.

@explanation

Automatic retries are one of the clearest wins of proper orchestration over ad-hoc scripts. A script that fails at 3am stays failed until someone notices. An orchestrated task with retries configured will recover from a network timeout or a momentarily throttled API without waking anyone up.

The configuration that matters:

- **`retries`** — number of retry attempts. 2–3 is typical. More than 5 is usually masking a problem.
- **`retry_delay`** — time between retries. Exponential backoff (start at 5 minutes, double each attempt) is better than a fixed delay for hitting rate-limited external APIs.
- **`retry_exponential_backoff`** — available in Airflow; enables exponential delay automatically.

The harder problem is distinguishing failure types:

**Transient failures** — network blips, temporary API unavailability, a warehouse cluster that was mid-autoscale. These resolve on their own; retrying succeeds. Appropriate response: retry with backoff, alert if retries exhaust.

**Data failures** — malformed source data, a schema change upstream, a referential integrity violation. These will fail on every retry, in the same way. Retrying 3 times burns 45 minutes before alerting. Appropriate response: fail fast, alert immediately, route to a data quality queue rather than an infrastructure queue.

The `on_failure_callback` (Airflow) or equivalent in other orchestrators lets you send a Slack message, page on-call, or write to an incidents table when a task fails after exhausting retries. Every production pipeline should have this configured — silent failures are how stale dashboards stay stale for a week before anyone notices.

> [!warning] If a task is failing on every retry, do not increase `retries`. You are not fixing the problem; you are adding latency before the alert. Investigate the failure type first.

@feynman

Retries are like hitting "resend" on a failed API request — useful when the problem was a hiccup in the network, useless when the payload itself is malformed.

@card
id: tde-ch05-c008
order: 8
title: Backfill and Catchup
teaser: Backfill lets you re-run a pipeline for historical periods — but Airflow's automatic catchup behavior has ended more than a few on-call shifts badly.

@explanation

Pipelines are parameterized by time. A daily pipeline that loads orders for "yesterday" needs to be able to run for any past day if you need to reprocess historical data — because a source schema changed, a bug was fixed, or a new downstream consumer needs data that predates the pipeline's deployment.

This is backfill: running pipeline executions for past time periods.

**Airflow's `catchup` behavior:** By default, Airflow sets `catchup=True`. This means when you deploy a DAG with a `start_date` of 90 days ago, Airflow will immediately try to run 90 daily instances to "catch up." On a shared production Airflow instance, this can saturate the executor queue, starve other pipelines, and trigger downstream effects (alerts, quotas) for every one of those 90 runs. This is called a backfill storm.

The safe default for new DAGs: `catchup=False`. This tells Airflow to only run for the current (or next scheduled) interval, not for every past interval since `start_date`.

When you actually need a backfill:

1. Set `catchup=False` on the DAG.
2. Use the Airflow CLI: `airflow dags backfill --start-date 2024-01-01 --end-date 2024-01-31 my_dag_id`
3. Add `--delay-on-limit` or run in batches to avoid overwhelming downstream systems.
4. Monitor the run queue — backfills can take hours for large ranges.

Parameterizing pipelines correctly is a prerequisite: the task code must accept an execution date (or date range) as input and process only that window, not "all data up to now." Idempotent, partitioned writes make it safe to re-run.

> [!warning] Deploying a new DAG with `catchup=True` and `start_date` 6 months ago on a shared Airflow instance is a production incident waiting to happen. Set `catchup=False` and backfill deliberately.

@feynman

Catchup is like asking a new employee to retroactively do all the work from their start date to today on their first morning — technically correct by the rules, operationally catastrophic.

@card
id: tde-ch05-c009
order: 9
title: Dependency Management in Complex Pipelines
teaser: Dependencies that are implicit in timing assumptions fail silently; dependencies that are explicit in code fail loudly, which is strictly better.

@explanation

Within a single DAG, dependencies between tasks are explicit: `task_b.set_upstream(task_a)` or the `>>` operator in Airflow. The scheduler enforces them. This is the easy case.

The hard cases:

**Cross-DAG dependencies** are where most production problems live. A reporting DAG needs the results of a transformation DAG that runs in parallel. The naive solution: schedule the reporting DAG 30 minutes after the transformation DAG. The problem: the transformation DAG runs late on Mondays when the source data is larger. The reporting DAG starts on time, reads incomplete data, produces wrong numbers, and nobody knows until Tuesday.

The correct solution in Airflow: `ExternalTaskSensor` — a sensor that polls for a specific task in another DAG to reach a success state before proceeding. In Dagster: asset dependencies are cross-job by default; an asset can depend on an asset materialized by a different job. The dependency is structural, not timing-based.

**Implicit ordering assumptions** are the hardest to detect because they work most of the time. A pipeline that assumes raw data is always loaded by 5am will fail silently on the day it is not — not with an error, but with empty output or stale data that passes downstream validation.

Rules for making dependencies explicit:

- Use sensors rather than schedule offsets for cross-system dependencies.
- Document every assumption about upstream data arrival in the DAG definition, not in a wiki.
- Fail loudly when assumptions are violated (a validation task that checks row counts before transformation starts).
- In Dagster or Prefect, use asset/flow dependencies rather than trigger-based scheduling where possible.

> [!info] A dependency encoded in a schedule offset is invisible to the orchestrator. A dependency encoded as a sensor or asset reference is enforced by the orchestrator. Prefer the latter.

@feynman

Implicit timing dependencies are like verbal agreements — they work when everything goes to plan, but when something slips, there is no contract to enforce and no alarm to raise.

@card
id: tde-ch05-c010
order: 10
title: Orchestrator Operational Concerns
teaser: The orchestrator is infrastructure, and like all infrastructure it needs monitoring, capacity planning, and a runbook for when it breaks — because everything downstream depends on it.

@explanation

The orchestrator is the nervous system of your data stack. When it is healthy, it is invisible. When it is unhealthy, every pipeline is potentially affected, and the failure surface is broad enough that diagnosing the problem takes time you do not have.

Key operational metrics to monitor in Airflow (analogues exist in Prefect and Dagster):

- **Scheduler heartbeat** — the scheduler emits a heartbeat every few seconds. If the heartbeat goes stale, the scheduler has died and no tasks will be submitted. This should alert within 5 minutes.
- **DAG parse time** — the scheduler re-parses all DAG files on a cycle. Parse times above 30 seconds delay task submission. A single slow DAG file (one that makes network calls at import time, or generates thousands of task instances dynamically) can stall the entire scheduler.
- **Task queue depth** — the number of tasks waiting to be picked up by workers. A growing queue means the executor is under-resourced relative to the workload. This is the signal to add workers before pipelines start missing SLAs.
- **Metadata database size and query latency** — the metadata DB stores every task state transition. It grows without pruning. Airflow's `db clean` command removes old records; run it on a schedule. Slow metadata DB queries will slow the scheduler.

Keeping DAG parse times short requires discipline: no database queries at DAG file import time, no HTTP calls at import time, no expensive Python object construction at the module level. The scheduler imports your DAG file every 30 seconds. Every millisecond of import cost accumulates.

The orchestrator outage runbook should cover: how to determine whether the scheduler or executor is the problem, how to drain and restart workers safely without losing in-progress tasks, and what the recovery order is for a full metadata DB restore.

> [!warning] If the metadata database goes down, the orchestrator loses its state. Running tasks may complete but their status will not be recorded, creating reconciliation problems. Treat the metadata DB with the same operational care as a production database.

@feynman

Monitoring your orchestrator is like monitoring the monitoring system — easy to skip because it usually works, catastrophic to skip when it does not, because everything else is flying blind.
