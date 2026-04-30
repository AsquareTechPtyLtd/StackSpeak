@chapter
id: sa-ch08-pipeline
order: 8
title: Pipeline
summary: Data flowing through stages, each transforming what came before. Underrated style — perfect for ETL, batch jobs, content publishing, and any system whose value is "input → transformations → output."

@card
id: sa-ch08-c001
order: 1
title: Pipes and Filters
teaser: A pipeline architecture is a chain of stages. Each stage takes input, does one thing, passes output to the next. Unix has used this shape since the 1970s; it's still one of the cleanest patterns we have.

@explanation

The pipeline (sometimes called pipes-and-filters) architecture organises a system as a sequence of independent stages connected by data flow:

```text
[Source] → [Filter A] → [Filter B] → [Filter C] → [Sink]
```

Each filter:

- Receives input from the previous stage.
- Does one focused transformation.
- Emits output to the next stage.
- Holds no state across invocations (or minimal state).

The Unix shell is the canonical example: `cat file | grep error | sort | uniq -c | head`. Five small programs, none of which know about the others, composed into a useful tool.

In larger systems, the pipeline shows up in:

- **ETL workflows** — extract, transform, load.
- **Build systems** — source → compile → link → package.
- **Content pipelines** — author → review → render → publish.
- **Data processing** — ingest → enrich → validate → store.
- **ML training pipelines** — collect → preprocess → train → evaluate → deploy.

> [!info] The style scales from a shell one-liner to a multi-stage Spark or Beam pipeline. The principle — independent stages, one direction of flow — holds across the size range.

@feynman

The factory line. Each station does one thing; the conveyor belt moves the work between them. You can swap a station without rebuilding the whole line. Pipelines are software factories.

@card
id: sa-ch08-c002
order: 2
title: When Pipeline Is the Right Style
teaser: Tasks where the value is the transformation chain. Batch processing, ETL, content workflows, deterministic builds. The shape fits when the input is well-defined and the output is the result of well-defined steps.

@explanation

Pipeline excels when:

- **The work is naturally sequential.** Each stage's output is the next stage's input.
- **Stages are independent.** Each filter does its job without needing context from earlier or later stages.
- **The data flow is one-direction.** Loops and back-pressure exist but are rare.
- **Stages can be reasoned about independently.** Testing one stage doesn't require running the whole pipeline.
- **Composition matters.** You'll want to swap one stage for another, or insert new stages between existing ones.

It's a poor fit for:

- **Interactive systems** — request-response with low latency. Pipelines are batch-shaped; latency is the sum of stages.
- **Highly stateful workflows** — where one stage needs to know the entire history. Pipelines work best when state is in the data, not in the stages.
- **Dynamic routing** — when the next step depends on complex decisions made elsewhere. Pipelines are linear; branching exists but adds complexity.

> [!info] The renaissance of pipelines in 2020-26 came from data engineering and ML — both fundamentally pipeline-shaped problems. The pattern was always there; the tooling caught up.

@feynman

The car wash. Cars enter, go through pre-rinse, soap, brushes, rinse, dry. Each stage does one thing. The car comes out clean because the *sequence* did the work; no single stage did it alone.

@card
id: sa-ch08-c003
order: 3
title: Filters Are Independent
teaser: A filter doesn't know what comes before or after — it just transforms its input. That ignorance is the strength: filters are reusable, swappable, and composable.

@explanation

The defining discipline of a pipeline architecture: each filter is independent.

What this means in practice:

- **A filter doesn't import other filters.** It imports its inputs and emits its outputs; the orchestration layer handles wiring.
- **A filter doesn't share state with other filters.** State lives in the data flowing through the pipe; filters are pure(-ish) functions.
- **A filter can be tested in isolation.** Feed it input; check the output; no need to run the rest.
- **A filter can be reused in multiple pipelines.** A "deduplication" filter works in any pipeline that has duplicates to remove.
- **A filter can be replaced.** Swap a slow filter for a fast one; the pipeline doesn't notice.

The independence is what makes pipelines tractable. A monolithic transformation that does ten things is hard to test, hard to evolve, hard to debug. The pipeline version — ten filters each doing one thing — is the opposite on every dimension.

> [!warning] Filters that "just need a bit of state from earlier in the pipeline" are usually wrong. If the next filter needs context from earlier, that context belongs in the data, not in the filter. Wrong instinct: smarter filters. Right instinct: richer data.

@feynman

The same principle as composable Unix tools. `grep` doesn't know about `sort`; `sort` doesn't know about `grep`. They both know how to read stdin and write stdout. That ignorance is what lets you compose them in any order.

@card
id: sa-ch08-c004
order: 4
title: Stage Variants — Producer, Filter, Sink
teaser: Three roles in a pipeline. Producer creates data; filters transform it; sinks consume the final output. Most pipelines have exactly one of each, in sequence.

@explanation

A typical pipeline has:

- **Producers (sources)** — generate data from outside the pipeline. File readers, queue consumers, API pollers, event subscribers.
- **Filters (transformers)** — take input, produce output. The bulk of the pipeline.
- **Sinks (consumers)** — write data outside the pipeline. Database writers, file writers, queue producers, API publishers.

The roles imply different design concerns:

- **Producers** care about backpressure — what happens when downstream is slower than upstream.
- **Filters** care about throughput and latency — they're in the middle of the work.
- **Sinks** care about durability and idempotency — their output crosses the pipeline's boundary.

The three-role split also tells you where to put error handling. Producers retry on input failures; filters fail fast and let the pipeline retry the batch; sinks need idempotency for safe retries on output failures.

> [!info] A "filter" can have multiple outputs (split into branches) or multiple inputs (join branches). The DAG (directed acyclic graph) generalisation is what frameworks like Apache Beam and Dagster encode.

@feynman

The kitchen brigade. Producer is the pantry — gets ingredients in. Filters are the prep cooks, line cooks, and saucier — each doing one transformation. Sinks are the plates going out the door. Each role has its own kind of failure mode and its own kind of expertise.

@card
id: sa-ch08-c005
order: 5
title: Pipeline Topology
teaser: Linear is the simplest. DAGs (with branches and joins) are the most common in real systems. Cycles (feedback loops) are rare and usually a hint to redesign.

@explanation

Pipeline topologies, in order of complexity:

- **Linear** — A → B → C → D. The simplest; easiest to reason about.
- **Tree (split)** — A → B → {C, D}. One output drives multiple consumers.
- **DAG** — A → {B, C} → D. Branches and joins. Most production pipelines look like this.
- **Cyclic** — A → B → A. Rare; usually indicates the design wants to be a loop or a state machine, not a pipeline.

The DAG shape is the workhorse. Real pipelines branch (one stream of events feeds five different processors) and join (two enriched streams merge before storage). The DAG framing keeps the dependencies explicit.

Tools that natively model DAG pipelines:

- **Apache Beam / Dataflow** — for batch and streaming data pipelines.
- **Apache Airflow / Dagster / Prefect** — for scheduled batch workflows.
- **Spark / Flink** — for distributed data processing.
- **GitHub Actions / GitLab CI** — for build pipelines (DAGs of jobs).
- **dbt** — for SQL transformation DAGs.

Each renders the same DAG abstraction with a different operational model. The architecture is shared.

> [!warning] Cycles in a pipeline are a smell. They usually mean you've conflated "pipeline" (one-direction flow) with "agent" (deciding what to do next). The two patterns coexist; pick the right one for the job.

@feynman

The same shape as a build system's DAG, a Make file, or a CI pipeline. The DAG is everywhere; recognising it across domains is the architect's perception.

@card
id: sa-ch08-c006
order: 6
title: Batch vs Streaming
teaser: Batch pipelines process bounded data — a file, a table, today's records. Streaming pipelines process unbounded data — events arriving continuously. Same architecture, very different operational shape.

@explanation

The pipeline architecture takes two main operational forms:

**Batch pipelines** — run on a schedule (or on demand) over bounded data. ETL nightly. Build the data warehouse weekly. Render the report on request.

- **Predictable resource usage** — start, do the work, stop. Scale up the cluster, do the job, scale down.
- **Restart-friendly** — failed batch can be re-run end-to-end.
- **Easier reasoning** — bounded inputs, deterministic outputs.

**Streaming pipelines** — run continuously over unbounded data. Process every event as it arrives. Update the materialised view in real time.

- **Constant resource usage** — the pipeline is always running.
- **Restart-tricky** — exactly-once processing across failure requires care (checkpoints, idempotent sinks).
- **Harder reasoning** — windowing, late events, ordering all matter.

In 2026, the line between them has blurred. Beam's "unified batch and streaming" model treats both with the same code. Most modern data platforms (Materialize, RisingWave, Flink) handle either. The architecture stays the same; the runtime decides batch or streaming.

> [!info] Most teams need both. Critical real-time signals run as streams; large analytical workloads run as batches. The same pipeline framework can host both, and the team gets one mental model instead of two.

@feynman

Same instinct as scheduling vs always-on. The lawn gets mowed weekly (batch); the air conditioner runs whenever it's hot (streaming). Same goal — comfort — different operational shape.

@card
id: sa-ch08-c007
order: 7
title: Backpressure and Buffering
teaser: When a downstream stage is slower than upstream, something has to give. Backpressure (slow the producer) or buffering (queue the work) are the two answers. Pick deliberately; don't let it default.

@explanation

Pipeline stages run at different speeds. The slowest stage sets the throughput. The other stages have to handle the mismatch:

**Backpressure** — slow stages signal upstream to slow down. Producer pauses or rate-limits. The pipeline runs at the slowest stage's speed; nothing accumulates.

**Buffering** — slow stages let upstream keep producing; queue the in-flight work. The pipeline absorbs spikes; memory or disk grows when the slow stage falls behind.

Tradeoffs:

- **Backpressure** preserves resource use but loses throughput on bursty workloads.
- **Buffering** preserves throughput but risks unbounded queue growth.
- **Bounded buffering** is the practical middle: queue up to N items; once full, apply backpressure. Best of both.

The choice depends on what's expected:

- For **constant-rate workloads** (regular event streams), backpressure with small buffers fits.
- For **bursty workloads** (events that come in spikes), bigger buffers avoid losing the spikes.
- For **batch-mode workloads**, backpressure usually doesn't apply; the pipeline runs at its own pace.

> [!warning] Unbounded queues are a production failure waiting to happen. Memory grows; disk fills; the system either crashes or starts dropping events silently. Always cap the buffer; always have a policy for "what happens when the buffer is full."

@feynman

The grocery store checkout. If checkout is slow, you can either close the doors (backpressure) or let the queue grow longer (buffering). Smart stores cap the line: when it hits a length, they open more checkouts.

@card
id: sa-ch08-c008
order: 8
title: Error Handling — Dead Letter Queues
teaser: When a record fails to process, you have three options: drop, retry, or shunt to a dead-letter queue. The third is the right answer for almost every production pipeline.

@explanation

Real pipelines see errors. A bad record, a transient outage, a schema mismatch. The pipeline can't stop on every error; it can't pretend the error didn't happen. The pattern is the **dead-letter queue (DLQ)**:

```text
[Producer] → [Filter A] → [Filter B] → [Sink]
                  ↓ error           ↓ error
                [DLQ A]          [DLQ B]
```

When a stage fails on a record, the failed record (and its context — error, stage, timestamp) goes to a DLQ. The pipeline continues with the next record. A separate process inspects the DLQ later: human review, automated retry, root-cause investigation.

Why DLQ beats the alternatives:

- **Dropping silently** — you lose data and don't know it.
- **Crashing the pipeline** — one bad record halts everything.
- **Retrying forever** — the pipeline gets stuck on the same record.
- **DLQ** — the pipeline keeps moving, you keep the bad record for analysis, you can fix and re-process later.

The DLQ becomes a debug surface. Looking at recent DLQ entries tells you what kinds of failures are happening, often with a tighter signal than logs.

> [!tip] DLQ entries should include the *original* input, the *stage that failed*, and the *error*. Without all three, you can't replay or debug.

@feynman

The "return to sender" mailbox. The mail truck doesn't stop because one letter has a bad address; it puts the bad letter in a separate bin and keeps delivering. The DLQ is the bad-mail bin.

@card
id: sa-ch08-c009
order: 9
title: Pipeline Observability
teaser: Per-stage metrics — throughput, latency, error rate — turn pipelines into systems you can reason about. Without them, you're guessing which stage is the bottleneck.

@explanation

A pipeline's health is the product of its stages' health. Useful metrics per stage:

- **Throughput** — records processed per second. Where is the bottleneck.
- **Latency** — time to process one record (or one batch). Detects slow stages.
- **Error rate** — fraction of records that failed. Detects unhealthy stages.
- **Queue depth** — number of records waiting to be processed. Detects backpressure.
- **DLQ rate** — records ending up in the dead-letter queue. Detects systematic failures.

Aggregate to the pipeline level for the user-facing view: end-to-end latency from producer to sink, total throughput, total error rate. But the per-stage metrics are where you debug.

Tools that expose this natively in 2026:

- **OpenTelemetry** — distributed tracing crosses pipeline stages naturally.
- **Apache Beam / Dataflow** — built-in per-step metrics and visualisation.
- **dbt** — per-model run metrics, lineage graphs.
- **Airflow / Dagster** — per-task duration, retry counts, DAG visualisation.

> [!info] Pipeline observability is one of the categories where the tooling has visibly improved over the last few years. If you're using a modern data platform, the observability is mostly free; if you're rolling your own, budget for it.

@feynman

The factory's dashboard showing each station's throughput. The plant manager doesn't watch the whole line; they watch the stations and intervene where one is slowing. Pipeline observability is the same dashboard.

@card
id: sa-ch08-c010
order: 10
title: When Pipeline Isn't Right
teaser: When you need real-time interactivity, complex branching that depends on history, or true random access to data, pipeline isn't the fit. Layered or event-driven serves better. Recognise the misfit early.

@explanation

The pipeline architecture is the right answer for a specific shape of problem. When the problem doesn't have that shape, forcing it into a pipeline makes everything harder.

Misfits to recognise:

- **Interactive UIs** — request, decide, respond, all in milliseconds. Pipelines are batch-shaped; the latency adds up.
- **Stateful workflows** — when the next step genuinely depends on a complex history. Pipelines work best when the data carries everything; deeply stateful logic belongs in a state machine or an agent.
- **Random-access patterns** — when consumers want to query "give me record 12345," not "give me a stream." A database is the right answer; a pipeline isn't.
- **Two-way communication** — when filters need to talk back to upstream. The pipeline model assumes one-direction flow.
- **Tightly-coupled stages** — if every stage needs intricate context from every other, the pipeline structure is more friction than help.

For each of these, a different style fits better:

- Interactive UIs → layered or service-based.
- Stateful workflows → event-driven, agentic, or state machine.
- Random access → database with appropriate indexing.
- Two-way → request-response, not pipeline.
- Tightly-coupled → modular monolith or layered.

> [!tip] If you find yourself adding sideways arrows to your pipeline diagram, you're outgrowing the style. Recognise it early; the fix is changing styles, not fighting the model.

@feynman

The factory line works for assembling cars; it doesn't work for an artist's studio where the work is iterative. Picking the wrong style is forcing the studio to operate like a factory — every edit becomes a re-run of the line.
