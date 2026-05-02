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

@card
id: depc-ch13-c008
order: 8
title: Reading Team and Scale Context
teaser: The right pattern for a 3-person startup is not the right pattern for a 50-person data platform. Context — team size, data volume, operational maturity — shapes pattern selection as much as technical fit.

@explanation

**Context signals** that should influence pattern selection, beyond the technical requirements:

**Team size:**
- 1–3 engineers → avoid patterns that require dedicated operational expertise (self-hosted Kafka, Flink clusters, custom feature stores). Choose managed services and simple patterns that one person can reason about entirely.
- 5–10 engineers → dedicated operational roles become viable. Platform patterns (shared CDC infrastructure, centralized feature store) start paying back.
- 10+ engineers → distributed ownership patterns (team-owned pipelines, data contracts, catalog-enforced governance) become necessary. Simple shared-everything models break at this team size.

**Data volume:**
- < 1 TB → DuckDB or any warehouse handles this; complex architecture is premature.
- 1–100 TB → standard warehouse or lakehouse patterns fit well.
- 100 TB – 1 PB → performance optimization patterns (clustering, compaction, partition pruning) become necessary.
- 1 PB+ → specialist architecture choices; generic patterns may not apply.

**Operational maturity:**
- No on-call rotation → avoid patterns that require monitoring and rapid response (streaming, CDC, sub-hourly freshness SLAs).
- Established SRE practices → streaming and real-time patterns are supportable.

**Regulatory context:**
- GDPR/HIPAA/PCI-DSS → deletion cascade, audit log, column masking, and encryption patterns are not optional.
- No regulated data → governance patterns are good practice but not compliance requirements.

> [!tip] Before proposing a new architecture, write down the team size, data volume, and operational maturity on a whiteboard. The combination usually narrows the viable pattern space significantly.

@feynman

Like prescribing medication — the right dosage depends on the patient's weight and condition, not just the diagnosis.

@card
id: depc-ch13-c009
order: 9
title: Pattern Combinations That Work Well
teaser: Certain pattern combinations appear together in production systems repeatedly because they address complementary concerns — knowing the common pairings saves architectural design time.

@explanation

Some patterns are natural complements that address different concerns in the same system:

**Medallion + Open table format:** bronze/silver/gold layering organizes quality; Iceberg or Delta provides ACID transactions, schema evolution, and time travel within each layer. Virtually every modern lakehouse uses both.

**CDC ingestion + Snapshot-plus-stream bootstrap:** CDC provides ongoing change capture; snapshot+stream solves the "how do I get the historical data" bootstrap problem every CDC pipeline faces on initial setup.

**Kimball star schema + Semantic layer:** Kimball provides the physical fact/dim tables; the semantic layer exposes business metrics consistently to all consumers. The physical model and the business vocabulary are separated.

**Expectation testing + Circuit breakers:** expectations catch specific known failures; circuit breakers catch catastrophic volume and schema failures the expectations didn't anticipate. Both serve quality in different ways.

**Idempotent writes + Partition overwrite:** the combination makes backfills trivially safe — a backfill run over 30 days deletes and rewrites each day's partition without any risk of duplication.

**SCD Type 2 dimensions + Feature store point-in-time joins:** SCD Type 2 maintains the dimension history; the feature store's `get_historical_features` uses that history to join features as-of a label timestamp. Without SCD Type 2, point-in-time correctness is impossible.

**FinOps tagging + Cost attribution dashboard:** tags are the instrumentation; the dashboard is the output. Tags without a dashboard are wasted work; a dashboard without tags has nothing to display.

> [!info] The inverse is also useful: some pattern combinations appear often because people copied them without thinking, not because they're complementary. Kafka + Flink for 50 events per second is a frequently-copied anti-combination.

@feynman

Like classic ingredient pairings in cooking — salt and caramel work together because they address complementary flavor dimensions; knowing the pairs saves experimentation.

@card
id: depc-ch13-c010
order: 10
title: The Minimum Viable Pattern Set
teaser: A team starting from scratch doesn't need all 40 patterns on day one. A minimum viable set covers the critical concerns without imposing patterns that will only pay off at 10× scale.

@explanation

For a team building their first production data system, a minimal pattern set that handles the most critical concerns:

**Ingestion:** incremental watermark with cursor persistence. Handles most sources; simple to operate; upgradeable to CDC when freshness demands it.

**Storage:** medallion architecture (bronze/silver/gold) with date partitioning. Adds auditability and consumer isolation from day one; no lakehouse complexity until volume demands it.

**Transformation:** staging-then-mart with idempotent partition overwrites. Separates ingestion from transformation; makes backfills safe.

**Quality:** volume circuit breakers + three dbt schema tests (`unique`, `not_null`, `relationships`) per critical table. Catches catastrophic failures and common data problems with minimal setup.

**Orchestration:** a simple DAG with well-named tasks and retry configuration. Works for most teams before dynamic tasks or event-driven patterns are necessary.

**Modeling:** Kimball star schema for the first 3-5 business domains. Familiar to analysts, well-supported by BI tools, expandable later.

**Security:** column masking on PII columns + a service account for pipelines. Minimum structural security that prevents the most common exposure.

This set is implementable by a two-person team in 6–8 weeks and handles most data engineering requirements for a mid-size product. Additional patterns are added when a specific constraint makes the minimum insufficient — not before.

> [!tip] The minimum viable pattern set is not the final architecture — it's the architecture that's sufficient until proven otherwise. Expand it incrementally when evidence shows a specific pattern is needed.

@feynman

Like an MVP product — solve the real problems first, with the simplest approach that works; add sophistication when the constraints demand it, not when it sounds interesting.
