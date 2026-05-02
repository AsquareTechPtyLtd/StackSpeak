@chapter
id: depc-ch13-pattern-selection-guide
order: 13
title: Pattern Selection Guide
summary: When to compose patterns, when to skip them, how to match a pattern to a real context, and the signals that tell you a pattern is becoming an anti-pattern at your scale.

@card
id: depc-ch13-c001
order: 1
title: The Selection Problem
teaser: Knowing all the patterns is not enough. Knowing which one fits your situation — and why — is the actual skill.

@explanation

A catalog of patterns is only useful if you can match a pattern to a real problem. The failure modes on both ends:

**Under-applying patterns:** teams that haven't been exposed to a pattern solve the same problem from scratch, over and over, without the benefit of accumulated engineering wisdom. They invent a CDC-like system without knowing CDC exists, and their version misses half the edge cases.

**Over-applying patterns:** teams that know patterns reach for them reflexively, regardless of fit. They deploy a full Kimball star schema with SCD Type 2 for a five-person startup's first warehouse. The complexity isn't wrong in principle; it's wrong for this context.

The guide in this chapter is structured around the context signals that indicate which pattern fits. The signals are more useful than a decision tree — context is always messier than a diagram.

> [!info] When a pattern doesn't fit cleanly, it's usually because the underlying problem doesn't match the pattern's problem definition. Go back to the problem statement before going back to the pattern catalog.

@feynman

Like reading a field guide — useful when you know what you're looking for; misleading when you fit the observation to the closest entry rather than the most accurate one.

@card
id: depc-ch13-c002
order: 2
title: Choosing an Ingestion Pattern
teaser: The right ingestion pattern depends on three questions — how fresh does the data need to be, what does the source support, and what operational load can the team sustain?

@explanation

**Freshness requirement first:**

- Sub-minute freshness → CDC or streaming ingestion. Batch and watermark patterns can't deliver this.
- Hourly freshness → incremental watermark or micro-batch. Simpler than CDC; sufficient for most use cases.
- Daily freshness → batch refresh if the table is small; incremental watermark if it's large.

**Source capabilities second:**

- Database with transaction log → CDC is possible; evaluate whether the freshness justifies the complexity.
- Database with `updated_at` column → incremental watermark is the natural fit.
- API with cursor pagination → API polling with cursor.
- Third-party SaaS with webhook support → push-based webhook with queue buffer.
- File drops, partner feeds → log shipping or batch pickup.

**Team operational capacity third:**

- Two-person team → CDC with Debezium + Kafka is a significant operational bet; consider managed CDC (Fivetran, Stitch, Airbyte) before self-hosted.
- Mature platform team → self-hosted CDC is defensible.

Common mistake: choosing CDC for freshness that hourly watermarks would satisfy, because CDC "feels more advanced."

> [!tip] Start with the simplest pattern that meets the freshness requirement. Upgrade when the simpler pattern demonstrably fails to satisfy it — not in anticipation that it might.

@feynman

Like choosing a vehicle — a bicycle, car, and airplane all solve "get from A to B" at different speeds, costs, and operational burdens. Match to the journey, not the most impressive option.

@card
id: depc-ch13-c003
order: 3
title: Choosing a Storage Layout Pattern
teaser: Medallion + open table format is the modern default. Deviate when you have a specific reason — usually a query pattern that the default doesn't serve well.

@explanation

The 2026 default for a new lakehouse or warehouse layer:

- **Medallion architecture** (bronze/silver/gold) for layered quality and auditability.
- **Iceberg or Delta Lake** for ACID transactions, time travel, and schema evolution.
- **Date partitioning** for time-series tables; hash partitioning when queries primarily filter on a high-cardinality key.
- **Target file size 256 MB – 1 GB** with scheduled compaction.
- **Storage tiering** via lifecycle policies for data older than 90 days.

When to deviate:

- **Small team, no operational capacity for a lakehouse:** a simple DuckDB or Snowflake warehouse with no custom table format is the right call. Add the lakehouse layer when the team grows.
- **Event-sourced system with audit as the primary goal:** append-only bronze with point-in-time queries is the model; silver and gold are optional.
- **Time-series workloads:** ClickHouse or TimescaleDB may outperform a general-purpose lakehouse by 10× for sub-second time-window queries.

Signals that the default isn't working:
- Bronze-to-silver pipeline running longer than the gold-layer SLA allows.
- Consumers querying bronze directly because silver takes too long to refresh.
- Compaction jobs running longer than their scheduled window.

> [!info] Don't build the full medallion architecture on day one if you have fewer than 3 people on the data team. A single clean layer with good naming is better than three layers maintained by people who don't have time.

@feynman

Like following a recipe — the default is good for most kitchens; substitute when you have a specific ingredient that the recipe doesn't account for.

@card
id: depc-ch13-c004
order: 4
title: Choosing a Modeling Pattern
teaser: Kimball is the right default for BI-centric analytics. Wide tables for ML and self-serve. Data Vault for enterprise governance at scale. Semantic layer for metric consistency across consumers.

@explanation

Decision guide for modeling pattern selection:

**Kimball star schema fits when:**
- BI tools are the primary consumers.
- The data has clear facts (transactions, events) and dimensions (customers, products).
- The team has dbt or a similar modeling tool.
- Schema is relatively stable (dimension tables don't change shape frequently).

**Wide tables (OBT) fit when:**
- ML feature pipelines need all features in one place without joins.
- Self-serve analytics users are SQL-proficient but shouldn't need to know join logic.
- The table is accessed primarily for full-row retrieval, not aggregation.

**Data Vault fits when:**
- Multiple source systems feed the same business entities.
- Regulatory or audit requirements demand full historization.
- Large enterprise team where different groups own different ingestion streams.

**Time-series modeling fits when:**
- Data is high-frequency and insert-only (metrics, IoT, logs).
- Query patterns are windowed aggregations over recent history.
- Volume is large enough that general-purpose modeling is too slow.

**Semantic layer fits when:**
- Multiple teams define the same metrics differently.
- BI tools and AI assistants need structured metric definitions.
- Schema changes should be invisible to consumers.

These patterns are composable: a Kimball fact/dim star schema served through a semantic layer is a common production combination.

> [!tip] Start with Kimball. Add a semantic layer when metric definitions start diverging across teams. Switch sections of the model to wide tables when ML teams start building features.

@feynman

Like choosing the right data structure in code — the default (array, map) works most of the time; specialized structures (tree, heap) earn their complexity when you have a specific access pattern that demands them.

@card
id: depc-ch13-c005
order: 5
title: When Patterns Become Anti-Patterns at Scale
teaser: Every pattern has a scale at which its assumptions break. The pattern that works at 100 GB silently fails at 100 TB, and it's not always obvious when the crossing point has passed.

@explanation

Patterns have scale assumptions built into their designs. When those assumptions are violated, the pattern begins producing worse outcomes than a simpler approach would.

**Batch refresh anti-pattern at scale:** full table refresh works at 100K rows. At 100M rows, the scan time exceeds the SLA. At 1B rows, the scan creates source-system load incidents. The pattern hasn't changed; the data volume crossed the threshold.

**Watermark extraction anti-pattern at high cardinality:** incremental watermark logic is simple when `updated_at` is indexed. When the query returns 10M rows per run and the index is not selective, the pattern produces worse performance than CDC would.

**Partition over-granularity anti-pattern at high frequency:** daily partitioning is optimal for daily analytical workloads. Hourly partitioning is useful for real-time pipelines. Per-minute partitioning for most analytical workloads produces 525,600 partitions per year — a metadata nightmare.

**Star schema anti-pattern at many-to-many relationships:** the Kimball model assumes a clear grain. When a fact has many-to-many relationships at the natural grain (one transaction involves multiple products, multiple promotions, multiple shipping events), the schema degrades to bridging tables and fanout problems.

The detection heuristics:
- Query plans show full scans where you expected pruning.
- Pipeline runtime is growing month-over-month without data volume growth.
- A "simple" query requires joining 7+ tables.
- Compaction jobs are running longer than their predecessor runs.

> [!warning] Performance problems caused by pattern/scale mismatch look like "the system is slow" rather than "the pattern is wrong." Diagnose the root cause before optimizing the wrong layer.

@feynman

Like sorting an array — insertion sort is fine at 100 elements; at 10 million, you need a different algorithm. The failure mode is assuming the algorithm scales.

@card
id: depc-ch13-c006
order: 6
title: Composing Patterns
teaser: Most production data systems use multiple patterns together. Understanding how patterns interact prevents the cases where two correct patterns compose into an incorrect system.

@explanation

Real data systems rarely apply a single pattern end-to-end. More commonly:

**Ingestion:** CDC (for operational database tables) + log shipping (for application logs) + API polling (for third-party SaaS).

**Storage:** Medallion architecture (for layering) + Iceberg (for table format) + date partitioning (for query pruning) + storage tiering (for cost management).

**Modeling:** Kimball (for the consumption layer) + SCD Type 2 (for dimensions that change) + a semantic layer (for metric definitions).

**Quality:** Schema contracts (on ingest) + expectation tests (on transform output) + circuit breakers (before writes) + anomaly detection (on the consumption layer).

These compositions work because each pattern solves a different problem. The risk is when two patterns solve overlapping problems differently.

Conflict example: using both SCD Type 2 in the dimension tables and snapshot tables in the fact layer. Both provide point-in-time history, but they do it differently — and joins between them require careful time-range alignment to avoid incorrect results.

Composition principles:
- Patterns from the same layer (all storage layout patterns) are more likely to conflict than patterns from different layers (ingestion + modeling).
- When composing, test the interaction explicitly — don't assume that two independently-correct patterns compose correctly.
- Document the interactions in runbooks, not just the individual patterns.

> [!info] The most common composition failure is two teams adopting different patterns for the same layer without coordinating. The result is a system that's consistent within each team's work and inconsistent at the boundaries.

@feynman

Like microservices composition — each service is internally correct; the bugs live at the interface between services.

@card
id: depc-ch13-c007
order: 7
title: A Pattern for Every Stage — Quick Reference
teaser: One reference card covering the full data lifecycle, with the primary pattern recommendation and the one condition that overrides it.

@explanation

**Ingestion:**
- Default: incremental watermark with cursor persistence.
- Override to CDC if sub-minute freshness is required or hard deletes must be captured.

**Storage:**
- Default: medallion (bronze/silver/gold) + Iceberg/Delta + date partitioning.
- Override to time-series optimized store (ClickHouse) for high-frequency metric data.

**Transformation:**
- Default: staging-then-mart with idempotent partition overwrites.
- Override to streaming transforms (Flink) if freshness SLA requires sub-minute lag.

**Modeling:**
- Default: Kimball star schema with SCD Type 2 dimensions.
- Override to wide tables for ML feature pipelines; override to Data Vault for enterprise multi-source governance.

**Quality:**
- Default: dbt schema tests + circuit breakers on ingest.
- Override to ML-based anomaly detection when explicit thresholds are impractical at the table/column count.

**Orchestration:**
- Default: dependency DAG with idempotent tasks and partition overwrite.
- Override to event-driven triggers when upstream arrival time is unpredictable.

**Cost:**
- Default: date partitioning + materialized aggregates + S3 lifecycle tiering.
- Override to query-result caching + pre-computed flat tables when query frequency is high and data doesn't change frequently.

**Security:**
- Default: column masking + row-level security on PII tables + audit log.
- Override to tokenization at ingest when downstream deletion compliance (GDPR/CCPA) is a hard requirement.

> [!tip] This table is a starting point, not an authority. The right pattern is always the one that fits the constraints of your system — freshness, scale, team capacity, regulatory requirements, and the existing stack.

@feynman

Like a style guide — follow the default until you have a specific reason not to; deviations should be documented, not assumed.
