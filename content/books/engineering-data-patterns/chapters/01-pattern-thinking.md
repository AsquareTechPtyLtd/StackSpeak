@chapter
id: depc-ch01-pattern-thinking
order: 1
title: Pattern Thinking for Data Systems
summary: What a pattern actually is, why they exist, and how to use them without letting them become a constraint rather than a tool.

@card
id: depc-ch01-c001
order: 1
title: What a Pattern Is (and Isn't)
teaser: A pattern is a named, reusable solution to a recurring problem — not a template to copy, but a vocabulary for discussing the solution space.

@explanation

A pattern, in the original Christopher Alexander sense, is a description of a problem that occurs over and over in an environment, plus the core of the solution to that problem. Software engineers borrowed this framing in the 1990s for object-oriented design. Data engineers need the same vocabulary now that the field has accumulated enough war stories to see what recurs.

A pattern is not:
- A blueprint to copy verbatim into your codebase.
- A guarantee that the approach will work in your context.
- An excuse to over-engineer a problem that doesn't actually repeat.

A pattern is:
- A named shorthand for a solution family, so the team can say "we're using a CDC pattern here" instead of re-explaining every time.
- A record of tradeoffs — what the solution costs, what problems it introduces, when it fails.
- A starting point for the conversation about whether this is the right tool for this specific problem.

The patterns in this book emerged from real data systems across many teams and industries. Each has been named, documented, and contextualized with tradeoffs. You'll find some immediately recognizable and some unfamiliar — both are worth the attention.

> [!info] A pattern without a named failure mode isn't a pattern yet. The tradeoff is what earns the name.

@feynman

Same idea as GoF design patterns — not the code itself, but the vocabulary for the conversation about the code.

@card
id: depc-ch01-c002
order: 2
title: When Patterns Help
teaser: Patterns pay off most when your problem is genuinely recurring and your team is growing — the shared vocabulary is the real value.

@explanation

Patterns add value in specific conditions:

**Team growth.** When the team scales from two people to ten, the informal shared understanding that worked when you could shout across the room breaks down. Named patterns let new engineers understand why a design choice was made, not just what it is.

**Cross-team contracts.** When an ingestion pipeline hands data to a transformation team that hands data to an analytics team, a shared pattern vocabulary reduces the cost of every integration conversation.

**Debugging unfamiliar systems.** When something breaks in a system you didn't build, a known pattern tells you where to look first. "This is an idempotent-write pattern, so check the dedup key" is faster than reasoning from first principles.

**Communicating with leadership.** "We're implementing a medallion architecture with CDC ingestion" lands faster in a planning meeting than a ten-minute system walkthrough.

Patterns do less work when the problem is genuinely novel, the team is small and co-located, or the system will be used once and thrown away. In those cases, solving the specific problem directly is cheaper than matching it to a catalog entry.

> [!tip] When introducing a pattern to a new team, start with the failure mode, not the solution. "This pattern exists because pipelines that don't do X end up doing Y" makes the value concrete.

@feynman

Like learning common chess openings — the value isn't memorization, it's fluency with why each sequence tends to be good.

@card
id: depc-ch01-c003
order: 3
title: When Patterns Hurt
teaser: Pattern-matching against a catalog without reading the problem carefully is how teams end up with elegant systems that don't fit the actual need.

@explanation

The most expensive pattern-related failures come from premature standardization — choosing a pattern before understanding the problem, or applying an enterprise-grade solution to a start-up problem.

Specific failure modes:

**The hammer problem.** A team learns CDC (change data capture) in a training and then wants to use it everywhere, including for sources that don't change frequently or don't support CDC at all. The pattern is real; the fit is wrong.

**Cargo-culting at scale.** A team copies an architecture from a blog post about a company with 100× the data volume. They inherit the complexity without the problem that justifies it. Kafka, Flink, and Iceberg make sense at that company's scale; a batch Parquet-to-Snowflake pipeline would have served the copying team for the next five years.

**Premature abstraction.** A team encapsulates "the ingestion pattern" into a framework before they've built three different ingestion pipelines. The abstraction is designed around the first problem, not the pattern that would have emerged from three.

**Pattern-driven conversations.** Design reviews where participants defend a pattern choice instead of examining whether the system solves the problem. The pattern becomes tribal, not pragmatic.

> [!warning] If the team spends more time discussing which pattern to use than building the system, the pattern is adding cost, not reducing it.

@feynman

Like premature optimization — the solution is real, but applying it before the problem exists makes things worse.

@card
id: depc-ch01-c004
order: 4
title: How to Read This Book
teaser: Each chapter covers a pattern family — the shared problem, the pattern options, when each fits, and what breaks it.

@explanation

This catalog is organized by lifecycle stage: ingestion, storage, transformation, modeling, quality, orchestration, observability, cost, security, and ML/AI integration. The final chapter is a selection guide.

Within each chapter, the structure is consistent:

1. **The recurring problem** — what pressure causes teams to reach for a solution in this space.
2. **The named patterns** — each one with a concrete description, typical implementation, and example system.
3. **Tradeoffs** — what the pattern costs in complexity, latency, infrastructure, and operational load.
4. **When each fits** — the context clues that push toward or away from each option.
5. **Failure modes** — what breaks, and how teams typically discover it.

You can read this linearly or use it as a reference. The lifecycle-stage organization means the ingestion chapter is useful independently of the modeling chapter. Cross-references note when patterns interact.

Two conventions used throughout:
- **Bronze/silver/gold** refers to the three-layer medallion architecture for storage layering.
- **"The pipeline"** refers to any automated process that moves or transforms data — it could be an Airflow DAG, a Spark job, a dbt model, or a Kafka consumer.

> [!info] The catalog is not exhaustive. New patterns emerge as new tools and new scales create new recurring problems. The goal is the thinking style, not the complete list.

@feynman

Like a field guide — not every species, but enough coverage and methodology to identify the ones you haven't seen before.

@card
id: depc-ch01-c005
order: 5
title: The Underlying Forces That Create Patterns
teaser: Patterns don't appear from nowhere — they're responses to specific pressures that data systems face at scale.

@explanation

Understanding why a pattern exists makes it easier to apply correctly and adapt when your situation doesn't quite match the documented form.

The recurring forces in data systems:

**Latency vs throughput.** Real-time pipelines optimize for low latency at the cost of complexity and infrastructure. Batch pipelines optimize for throughput and simplicity at the cost of freshness. Most patterns in this book involve choosing a position on this tradeoff.

**Idempotency.** Pipelines run more than once — due to failures, retries, backfills, and incremental runs. Systems that don't handle this produce duplicates or data loss. Many patterns exist specifically to make a pipeline safe to re-run.

**Schema evolution.** Source systems change schemas without warning. Downstream consumers break when shapes shift. A category of patterns exists specifically to absorb schema change before it reaches consumers.

**Cost vs performance.** Cloud infrastructure scales elastically but bills elastically too. Patterns that assume cheap compute may produce expensive pipelines. Cost-aware patterns exist to keep infrastructure proportional to the problem.

**Operational load.** A pipeline that works perfectly in week one can become a full-time job to maintain if it doesn't account for failures, monitoring, and change. Patterns that ignore operational load ship technical debt at the same time they ship data.

> [!tip] When evaluating a pattern, name the force it addresses. If the pattern doesn't address a real force in your system, it's adding complexity for no reason.

@feynman

Same as how GoF patterns respond to recurring OOP forces — coupling, extensibility, state — each pattern here responds to a recurring data-systems force.

@card
id: depc-ch01-c006
order: 6
title: How to Document a Pattern
teaser: A pattern without documentation is a tribal practice. The documentation is what turns an informal solution into something the next engineer can apply correctly.

@explanation

A well-documented pattern has a fixed structure that communicates both the solution and the context in which it's valid.

The minimum documentation for a reusable pattern:

**Name:** a short, memorable name the team agrees to use. "CDC-ingestion" is a name; "the thing we do for Postgres" is not.

**Problem statement:** one paragraph on the recurring problem this pattern addresses. Be specific — "sources that change records without producing events" is better than "data movement challenges."

**Solution:** how the pattern works. Concrete enough to implement, not so detailed that it's tied to one tool. "Use the source database's replication log as a stream of change events" rather than "run Debezium 2.3 with these specific settings."

**Consequences:** what the pattern costs. Operational complexity, latency, infrastructure, and the scenarios where it degrades.

**Known uses:** one or two examples of where this pattern is applied in your system. New engineers benefit from seeing a live instance, not just an abstract description.

**Related patterns:** patterns that are often combined with this one, or patterns that solve related problems.

A pattern documented in a wiki page at this level is useful for onboarding, architecture review, and debugging. Undocumented patterns exist only in the minds of the engineers who built them.

> [!tip] A team retrospective after solving a new recurring problem is the right moment to document it. The context is fresh, the solution is working, and the failure modes are clear from recent experience.

@feynman

Like a recipe card — the dish can be cooked from memory, but the card makes it reproducible by anyone, including the cook who made it six months ago.

@card
id: depc-ch01-c007
order: 7
title: Pattern Evolution Over Time
teaser: Patterns reflect the constraints of when they were designed. As tools, scale, and infrastructure change, patterns that were once correct become outdated.

@explanation

Patterns are not timeless. They represent the best known solution to a recurring problem given a specific set of constraints — tools, scale, team size, cost structure. When those constraints change, the pattern may no longer be optimal or correct.

Examples of patterns that have evolved:

**Lambda architecture** (2011–2020): originally proposed by Nathan Marz to serve both real-time (speed layer) and historical (batch layer) queries from a single system. Required maintaining two separate code paths. As stream processing matured (Flink, Spark Structured Streaming), the Kappa architecture replaced it for most teams — one streaming layer serves both.

**Hadoop HDFS + MapReduce** (2007–2016): the dominant big data pattern before cloud object storage became cheap and reliable. Object stores (S3, GCS) with Parquet replaced HDFS for most new systems by 2018.

**Full denormalization in NoSQL** (2010–2018): a reaction to relational database scalability limits. As NewSQL databases and distributed PostgreSQL improved, the tradeoffs of full denormalization became harder to justify for many use cases.

**Manual schema management** (pre-2020): managing warehouse schemas through handwritten migrations. dbt formalized schema-as-code and made version-controlled schema management the standard.

How to tell a pattern has become outdated:
- The problem it solves is no longer a real problem at your scale.
- The tools it was designed to work around have been replaced.
- A simpler approach delivers the same outcome with less complexity.

> [!info] When learning patterns from older sources (books published before 2020, blog posts from the Hadoop era), check whether the pattern's problem statement still applies before adopting it.

@feynman

Like design patterns that predate garbage collection — valid in their era, not always the right choice today when the language does it for you.

@card
id: depc-ch01-c008
order: 8
title: The Pattern Selection Mindset
teaser: Experienced engineers don't pattern-match against a catalog — they reason from problem constraints to the solution space, then use the catalog to name what they find.

@explanation

The catalog in this book is a vocabulary, not a flowchart. The right use of it:

1. **Start with the problem.** What is the concrete pressure the system faces? Low latency? High volume? Schema instability? Auditability?

2. **Characterize the constraints.** What does the source support? What can the team operate? What's the freshness budget? What does it cost if this goes wrong?

3. **Reason toward a solution.** Given those constraints, what kind of approach fits? Incremental? Event-driven? Aggregated? Normalized?

4. **Name it from the catalog.** Once you've reasoned toward the shape, find the pattern name that matches. The name is the vocabulary item — it didn't determine your reasoning, it describes the conclusion.

5. **Validate against the pattern's known failure modes.** Does your system have the conditions that make this pattern break? If so, either address them or choose a different pattern.

This is the opposite of: "we need to ingest data, which pattern is most popular?" or "the blog post used Kafka so we should use Kafka."

The selection mindset produces teams that can reason about new problems with no catalog entry — because they're reasoning from principles, not pattern-matching against a list.

> [!info] The best indication that a team has internalized patterns is when they discover the right approach independently and then find it already has a name. The name is a confirmation, not a discovery.

@feynman

Like how a physicist approaches a new problem — they reason from first principles and then recognize that the result is a known configuration, rather than starting from the known configurations and seeing which fits.

@card
id: depc-ch01-c009
order: 9
title: Patterns Across the Lifecycle
teaser: Patterns don't exist in isolation — they span the data lifecycle. An ingestion pattern constrains the transformation pattern available to it; a modeling choice constrains serving.

@explanation

The chapters in this book are organized by lifecycle stage, but real data systems don't have clean stage boundaries. Choosing a pattern in one stage often constrains or enables choices in adjacent stages.

Some cross-stage dependencies that matter:

**Ingestion → Transformation:** CDC ingestion produces event records with `before` and `after` fields. The transformation stage must be designed to handle this format — a staging model that expects a simple INSERT-shaped record will not work against CDC events without an upstream flatten step.

**Storage layout → Modeling:** a bronze layer that uses date partitioning and file-per-day granularity affects how the transformation step can do incremental processing. The modeling step's SCD Type 2 dimension requires that the silver layer preserves historical versions, not just current state.

**Transformation → Serving:** an idempotent, date-partitioned transformation makes backfilling easy for analytical serving. The same transformation used as a feature pipeline for ML serving has different requirements — it must be point-in-time correct, not just correct-as-of-today.

**Modeling → Security:** a wide-table model that embeds PII columns directly (customer email, name) in every fact row requires column masking to be applied everywhere. A narrow fact table that joins to a separate `dim_customer` table can mask at the dimension level only.

The implication: when changing a pattern in one stage, audit downstream stages for cascading impacts. A CDC upgrade from watermark ingestion is not complete until the transformation stage has been updated to consume the new event format.

> [!tip] Before finalizing a pattern choice, trace it forward: "if we use CDC here, what does the transformation stage need to handle that it doesn't today?"

@feynman

Like changing an API signature — the change is complete only when all callers have been updated; the downstream impact is the work, not the change itself.
