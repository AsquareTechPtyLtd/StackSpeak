@chapter
id: eds-ch09-serving-data-downstream
order: 9
title: Serving Data Downstream
summary: The lifecycle's payoff stage — making data available to humans and machines that consume it, in shapes and latencies each consumer actually needs.

@card
id: eds-ch09-c001
order: 1
title: Serving Is Where Data Becomes Value
teaser: Generated, ingested, stored, and transformed data has zero value until a consumer reads it. Serving is the lifecycle stage where business outcomes finally crystallize.

@explanation

Every other stage exists in service of this one. The pipeline that no one consumes is overhead, not infrastructure. Understanding who consumes data and how shapes everything upstream:

Three primary consumer classes:

- **Humans** — analysts, executives, operators looking at dashboards or running ad-hoc queries.
- **ML systems** — models being trained on historical data; models doing real-time inference.
- **Operational systems** — CRMs, marketing tools, support platforms consuming enriched data via reverse ETL.

Each has distinct needs:

- **Latency** — humans tolerate seconds-to-minutes for analysis; inference often needs single-digit ms.
- **Throughput** — analytics often does big infrequent scans; ML training does massive sequential reads; inference does many tiny lookups.
- **Freshness** — operational dashboards need minutes-fresh data; some analytical reports are fine being daily.
- **Schema shape** — wide flat tables for BI; specific feature shapes for ML; APIs or row-level for operational consumers.

A pipeline designed for one consumer often serves another poorly. The serving layer's job is matching shape to use.

> [!info] If you can't name the consumer for a pipeline, you have either a missing relationship or a pipeline that shouldn't exist. Both worth investigating.

@feynman

Same as the response phase of a request — everything before exists to make this moment fast and correct.

@card
id: eds-ch09-c002
order: 2
title: Analytics Serving — Dashboards And Ad-Hoc SQL
teaser: The most common serving pattern. BI tools and SQL clients query the warehouse. The expectation is "fast enough that an analyst keeps thinking, not gets distracted."

@explanation

What analytics serving needs:

- **Aggregations** — most queries roll many rows up to summaries.
- **Filtering** — by date, by segment, by category.
- **Slicing** — group by dimensions, rank, compare across periods.
- **Concurrency** — many analysts simultaneously, mostly small queries with occasional large ones.

The pattern that works:

- **Warehouse with columnar storage** — Snowflake, BigQuery, Redshift, Databricks SQL.
- **Properly modeled marts** — Kimball-style or wide tables, optimized for the warehouse's strengths (clustering, partitioning).
- **BI tool layer** — Tableau, Looker, Mode, Hex, Metabase — depending on team and budget.
- **Caching where appropriate** — common dashboard queries cached at the BI tool or warehouse level.
- **Semantic layer for shared definitions** — increasingly the norm for medium+ teams.

The latency expectation: dashboards load in < 5 seconds; complex ad-hoc queries return in < 30 seconds; really heavy investigative queries can take minutes. Slower than that and analysts switch tasks and lose flow.

What kills analytics serving:

- **Unmodeled raw tables** — full scans across billions of rows.
- **Many small queries pounding the warehouse** — concurrency limits surface.
- **Cross-cluster federation** — joining tables from different vendors live, slowly.
- **Ungoverned access** — every analyst writing their own joins; competing definitions of basic metrics.

> [!tip] When dashboards get slow, the fix is usually "model better tables" before "buy more warehouse compute." Compute solves performance you couldn't get from physics; modeling solves performance you didn't get from architecture.

@feynman

Same shape as a search engine — fast queries on pre-indexed data, not slow scans through raw documents.

@card
id: eds-ch09-c003
order: 3
title: BI Tool Choices And Their Trade-Offs
teaser: BI tools span a wide spectrum from drag-and-drop simplicity to code-first power. Picking the right one for the team's skill mix matters more than the specific brand.

@explanation

The major categories:

- **Self-serve drag-and-drop** — Tableau, Power BI, Metabase. Analysts and PMs build dashboards without code. Strong for breadth of users.
- **SQL-first BI** — Mode, Hex, Redash. Analysts write SQL and chart the results. Strong for analytical-engineering teams.
- **Modeling-first** — Looker, Lightdash. Logic lives in a modeling layer (LookML); dashboards consume the model. Strong for teams that want one-source-of-truth metrics.
- **Notebook-style** — Hex, Mode (notebook view), Deepnote. Exploratory analysis with shareable artifacts. Strong for data science crossover.
- **Embedded analytics** — Sigma, ThoughtSpot, Cube. BI inside another product. Strong for SaaS teams shipping analytics to customers.

The decision factors:

- **Team skill mix** — if most consumers can't write SQL, lean drag-and-drop. If most can, lean SQL-first.
- **Source of truth strategy** — Looker-style modeling enforces shared metrics; everything-else lets teams diverge unless you add a separate semantic layer.
- **Cost** — Tableau and Looker land at the high end; Metabase and Redash at the open-source end.
- **Embedding needs** — for white-label or in-product analytics, the embedded category becomes essential.

The mistake to avoid: optimizing for the most powerful tool when most consumers will never use the power. A simpler tool that 50 people use beats a powerful tool 5 people use.

> [!info] Most teams underestimate the cost of switching BI tools — every dashboard is a custom artifact. Pick once with care; switching is a major project.

@feynman

Same trade-off as IDE vs notepad — power vs accessibility, with different right answers for different audiences.

@card
id: eds-ch09-c004
order: 4
title: ML Training Data Serving
teaser: Training a model means reading lots of historical data — large sequential reads in specific shapes. Different from analytics; different from inference.

@explanation

ML training has its own serving requirements:

- **Massive batch reads.** Modern training reads gigabytes to terabytes per epoch.
- **Specific formats.** Parquet for tabular; TFRecord, WebDataset, or sharded files for image/text/multimodal.
- **Reproducibility.** The exact training set used months ago must be reproducible — for retraining, for audits, for debugging.
- **Versioning.** Datasets change as new data lands; you need to pin which snapshot a model was trained on.
- **Feature engineering** — the input to training often comes from feature tables built by data pipelines.

Common patterns:

- **Snapshots in object storage** — training datasets snapshotted to S3/GCS at known versions. Versioning via path conventions (`s3://.../v3/`).
- **Feature stores** — Feast, Tecton, Hopsworks, native warehouse offerings (Databricks, Snowflake). Provide point-in-time correct features for training.
- **Direct warehouse training** — pull training data directly from Snowflake or BigQuery for smaller models.
- **Lakehouse-as-training-source** — Iceberg or Delta tables read directly into PyTorch, JAX, or Spark training jobs.

The hardest problem in ML data serving: **point-in-time correctness**. When you train on "what was true as of order time," you must not accidentally include data that arrived after the order. Feature stores exist largely to solve this.

> [!warning] Training data leakage — features that include information from after the prediction time — is the most common silent bug in ML systems. The model performs amazingly in offline evaluation and terribly in production.

@feynman

Same problem as look-ahead bias in financial backtesting — using information you wouldn't have had at the moment of decision.

@card
id: eds-ch09-c005
order: 5
title: ML Inference Serving — The Tightest Latency Budget
teaser: Models making predictions at request time need data in milliseconds. The serving shape that supports this is fundamentally different from analytics or training.

@explanation

A user opens an app; the personalization model needs features (recent activity, profile attributes, computed embeddings) to score recommendations. The full request budget is often < 100ms; the data fetch portion gets a fraction of that.

What this requires:

- **Key-value lookups, not analytical scans.** Given a user_id, return their feature vector.
- **In-memory or near-in-memory storage.** Redis, DynamoDB, in-memory feature stores.
- **Pre-computed features.** Computing on-demand at request time is rarely fast enough; features are computed in batch and looked up at inference.
- **Versioned feature definitions.** The features used at training time must match the features used at inference — drift here breaks the model.

Architectural pieces:

- **Online feature store** — Redis-like store with the latest feature values, refreshed by batch or streaming pipelines.
- **Offline feature store** — warehouse-style store with full history, used for training and audit.
- **Sync between them** — pipelines materialize from offline to online as new features compute.

The challenge: keeping online and offline in sync. The model trained on what was in the offline store; inference reads from the online store; if the two definitions drift, predictions degrade silently.

> [!info] Feature stores formalized this two-storage pattern. Building it from scratch (raw Redis + batch pipelines) is doable but operational; managed feature stores save real time.

@feynman

Same trade-off as caching layers in web apps — pre-compute the slow stuff so request-time is just a lookup.

@card
id: eds-ch09-c006
order: 6
title: Reverse ETL — Pushing Data Back To Operational Systems
teaser: Warehouse data is most valuable when it flows back into the tools sales, marketing, and support actually use. Reverse ETL is the plumbing that closes the loop.

@explanation

The pattern: your warehouse holds enriched, modeled data — customer health scores, product recommendations, lifetime value, churn risk. The team that benefits is your sales/CS/marketing team — but they live in Salesforce, Hubspot, Marketo, Zendesk, not in the warehouse.

Reverse ETL tools (Hightouch, Census, Polytomic) sync warehouse tables to operational systems:

- **Customer health score** computed in dbt → synced to Salesforce as a custom field.
- **Marketing segments** modeled in the warehouse → synced to Mailchimp or Iterable.
- **Account-level activity** computed from logs → synced to support tool for context.

What makes reverse ETL hard:

- **Idempotency** — repeated syncs shouldn't duplicate records or overwrite intentional manual changes.
- **Conflict resolution** — what if the operational system has been updated since last sync?
- **Field mapping** — operational systems have rigid schemas; warehouse data must conform.
- **Throughput limits** — Salesforce has API limits per day; sync strategies must respect them.
- **Identity resolution** — matching warehouse records to operational system records (by email, phone, custom ID).

The wins, when it works: the warehouse stops being a read-only artifact and becomes the central nervous system that updates every operational tool.

> [!tip] Reverse ETL multiplies the value of warehouse work. Modeled customer attributes that sit in the warehouse help analysts; pushed to sales, they help close deals.

@feynman

Same insight as turning a database read-only into a write target — closes a loop that previously wasn't.

@card
id: eds-ch09-c007
order: 7
title: Data Products — Treating Datasets Like Software
teaser: A "data product" is a dataset built and supported with the same rigor a SaaS team brings to a real product. The mindset shift changes how teams work.

@explanation

The data-as-product framing comes from the data mesh movement, but the practices apply broadly. A data product has:

- **An owner** — usually a team, with on-call rotation and accountability for quality.
- **A consumer base** — known downstream users; not "anyone who happens to find it."
- **A documented contract** — schema, freshness, quality SLAs, change policy.
- **Versioning** — schema changes go through deprecation cycles, not surprise breaking changes.
- **Discoverability** — listed in a catalog, with documentation, search, examples.
- **Support** — consumers can report issues, request features, get response within SLA.

Compare to the alternative: a table built once for one project, never documented, owned by whichever person originally created it (often gone now), consumed by twelve people who don't know each other.

The shift requires investment:

- **Time** — owners spend ongoing capacity on the product, not just initial build.
- **Tooling** — catalogs, observability, lineage, contract enforcement.
- **Cultural** — data teams learn to treat downstream consumers as customers.

Where it's transformative: the warehouse stops being a backwater of accumulated tables and becomes a curated set of dependable products other teams build on.

> [!info] You don't need to call it "data mesh" to get the wins. The product mindset can be adopted on a single team's outputs without a full organizational restructure.

@feynman

Same shift as moving from internal scripts to internal services — same code, different ownership and quality standards.

@card
id: eds-ch09-c008
order: 8
title: Self-Serve Analytics — Democratizing Data Access
teaser: When the data team can't service every request manually, they invest in making it possible for consumers to serve themselves. Hard to do well; transformative when it works.

@explanation

The bottleneck pattern: every analytical question routes through the data team. Requests pile up; the team becomes a service desk; senior engineers spend the day writing SELECT statements for other people. Self-serve analytics is the antidote.

What self-serve actually requires:

- **Modeled, intuitive marts** — not raw tables; well-shaped consumer-facing tables that match how the business thinks.
- **A data catalog** — searchable, browsable inventory of what exists with descriptions.
- **Documentation** — what each table means, what the columns are, who owns it, how fresh it is.
- **Trusted definitions** — when a consumer queries "active customers," they get the same number a colleague would.
- **Approachable BI tools** — not power-user-only; consumable by non-technical staff.
- **Office hours and support** — even with self-serve, consumers will get stuck; provide a place to ask.

What it doesn't mean:

- **Anyone can write any query** — access controls still apply; sensitive data is still gated.
- **No data team needed** — self-serve consumers ask harder questions, not zero questions.
- **Free-for-all** — without a semantic layer or shared modeling discipline, self-serve produces conflicting numbers fast.

When self-serve works, the data team's role shifts from "answering analytical questions" to "enabling others to answer their own."

> [!warning] Self-serve announced without the modeling, catalog, and tooling work in place leads to chaos and conflicting numbers. The investment must come before the rollout.

@feynman

Same shift as moving from "ops handles every deploy" to "developers self-serve with a paved road." Transformative when the tooling supports it; chaos when it doesn't.

@card
id: eds-ch09-c009
order: 9
title: Notebooks As A Serving Pattern
teaser: Jupyter, Hex, and similar notebook environments are how data scientists and analysts actually work. They double as a serving pattern that warehouse-only thinking misses.

@explanation

Notebook environments interleave SQL, Python/R, charts, and prose into a single document. Where they fit in the lifecycle:

- **Exploratory analysis** — quick questions that don't justify a full dashboard.
- **Investigative work** — drilling into anomalies; testing hypotheses; following the thread.
- **Sharable analyses** — a notebook becomes the artifact that explains a finding.
- **Lightweight ML training** — model development happens in notebooks before production training pipelines.
- **Operational reports** — a parameterized notebook re-run on a schedule can serve as a report.

Modern notebook platforms add useful structure:

- **Hex / Deepnote** — collaborative notebooks with first-class SQL, scheduled runs, dashboard publishing.
- **Mode** — SQL-first notebooks aimed at analytics teams.
- **Databricks notebooks** — integrated with the lakehouse; both ad-hoc and production patterns.
- **Jupyter on managed infra** — JupyterHub, SageMaker Studio, Vertex AI Workbench.

The trap: notebooks make it easy to ship analyses without engineering rigor. SQL that should be a dbt model lives in cell 4 of a notebook nobody else can find. Treat notebooks as a phase, not a destination — successful exploratory work should graduate into production pipelines, dashboards, or models.

> [!tip] If your team's most-used metric lives in a notebook only one person can find, you have a productionization gap. Move it to a real artifact before the original author leaves.

@feynman

Same role as a sketchbook for designers — essential for ideation, not the final deliverable for a product.

@card
id: eds-ch09-c010
order: 10
title: Real-Time Dashboards And Operational Analytics
teaser: When the question is "what's happening right now?" warehouse refreshes are too slow. Real-time analytics needs different infrastructure end-to-end.

@explanation

Operational analytics serves the same kinds of questions as historical analytics, but with sub-minute freshness:

- **Live operations dashboards** — orders per minute, error rates, queue depths.
- **Real-time fraud detection** — score transactions as they arrive.
- **Marketing campaign monitoring** — clicks and conversions live.
- **Inventory state** — current stock across distribution centers.

The infrastructure pattern is fundamentally different from batch analytics:

- **Streaming-first ingestion** — Kafka, Kinesis carry events.
- **Stream processors** — Flink, Materialize, Kafka Streams compute aggregations continuously.
- **Real-time analytical stores** — ClickHouse, Pinot, Druid, Materialize. Designed for high-cardinality, low-latency aggregations on streaming data.
- **Live-updating BI** — Grafana, custom dashboards, vendor offerings (Tinybird, Materialize).

What this costs:

- **Operational complexity** — running streaming infra is non-trivial.
- **Skill investment** — stream processing is genuinely a different skillset from batch.
- **Cost** — always-on infrastructure vs scheduled batch jobs.

Most teams should start with batch and add real-time only for the specific use cases that justify it. The temptation to "do everything streaming" usually creates more problems than it solves.

> [!info] If your real-time dashboard is consumed once per day, it didn't need to be real-time. Re-evaluate periodically; usage patterns reveal where the freshness budget actually pays off.

@feynman

Same trade-off as polling vs WebSockets in apps — most users don't need second-fresh data; the ones who do, really do.

@card
id: eds-ch09-c011
order: 11
title: Data APIs And Embedded Analytics
teaser: When the consumer is software (not a human in a BI tool), data needs to come through APIs with predictable latency and contracts.

@explanation

Some data consumers are services, not people:

- **Mobile / web apps** consuming user-specific analytics ("your weekly summary").
- **Internal services** querying enriched data ("get this customer's lifetime value").
- **External customers** in B2B SaaS receiving data through APIs.
- **Embedded analytics** inside other products (Sigma, Cube, ThoughtSpot Embedded).

What this serving shape requires:

- **API layer** — REST or GraphQL in front of warehouse-backed data.
- **Caching** — warehouse latency (seconds) is too slow for interactive APIs; cache at the API layer or use a fast serving store.
- **Authentication and authorization** — fine-grained access control, often per-row (each customer sees only their data).
- **Rate limiting and quotas** — API consumers misbehave; protect the underlying warehouse.
- **Schema stability** — API contracts have hard backward-compatibility requirements; downstream apps depend on them.

Common architectural patterns:

- **Warehouse → cache → API** — periodically materialize warehouse aggregations to Redis or DynamoDB; API reads from there.
- **Real-time stream → serving store → API** — for fresher data, stream directly into a fast store.
- **Cube / Sigma / similar** — purpose-built tools for embedded analytics that handle the API layer.

The biggest difference from analytics serving: the consumer doesn't care about your warehouse's daily refresh schedule. APIs need to behave like APIs — fast, reliable, well-defined.

> [!warning] Warehouses make poor API backends. Direct queries from a mobile app to Snowflake produce both bad latency and runaway cost. Always put a serving layer in between.

@feynman

Same as caching for web apps — the source of truth (DB, warehouse) is the slow correct place; the cache is the fast accessible place.

@card
id: eds-ch09-c012
order: 12
title: Feedback Loops Close The Cycle
teaser: Serving isn't the end. The systems consuming data produce new data — about how it was used, what worked, what didn't. That data feeds the next cycle of improvement.

@explanation

The lifecycle is circular when done well:

- **Serving produces usage data.** Which dashboards get viewed? Which queries get run? Which features get used in models? Which ML inferences led to conversions?
- **Usage data informs the next round.** Unused tables can be deprecated. Slow dashboards point to modeling work. Models with degrading accuracy need retraining.
- **The loop closes.** Tomorrow's pipelines are better because of yesterday's serving outcomes.

What captures the feedback:

- **BI tool analytics** — most BI platforms track query patterns, dashboard usage, popular tables.
- **Warehouse query logs** — Snowflake's `QUERY_HISTORY`, BigQuery's `INFORMATION_SCHEMA.JOBS` show every query and its cost.
- **Reverse ETL outcome tracking** — did the customer-health-score sync to Salesforce actually drive sales actions?
- **ML model monitoring** — accuracy, drift, feature distribution changes over time.
- **User feedback** — explicit channels for consumers to report issues, request features, suggest deprecation.

The team that closes the loop deliberately learns faster. The team that ignores it builds the same pipelines repeatedly without knowing what's working.

> [!info] Quarterly review of pipeline usage is a high-leverage practice. Most teams find 20-30% of pipelines have no consumers and can be retired — freeing capacity for higher-value work.

@feynman

Same as feature usage analytics in a product — knowing what gets used vs ignored is what makes the next release better than the last.
