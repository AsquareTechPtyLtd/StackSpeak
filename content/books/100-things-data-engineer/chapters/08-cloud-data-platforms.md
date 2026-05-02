@chapter
id: tde-ch08-cloud-data-platforms
order: 8
title: Cloud Data Platforms
summary: The cloud data platform landscape converged around two architectures — warehouse and lakehouse — and picking the wrong one, or the wrong vendor within the right one, is an expensive mistake you will live with for years.

@card
id: tde-ch08-c001
order: 1
title: Warehouse vs Lakehouse
teaser: A data warehouse and a data lakehouse store the same data, but the architecture choices they make — format, storage, governance — determine your query performance, costs, and exit options.

@explanation

The data warehouse model — Snowflake, BigQuery, Redshift — stores data in a proprietary columnar format managed entirely by the vendor. You get fast SQL, strong governance, and a polished query experience. The tradeoff: storage is 3–10× more expensive than raw object storage, and your data is locked in a format only that vendor can read efficiently.

The data lakehouse model — Delta Lake or Apache Iceberg on S3/GCS/ADLS, fronted by Databricks, Athena, or Spark — stores data in open formats (Parquet + a transaction log) on cheap object storage. You get low storage costs and portability; you give up some query polish and take on more infrastructure responsibility.

What makes the choice hard:

- **Query performance**: Warehouses win on optimized, governed SQL at most scales. Lakehouses have closed the gap significantly with Photon and vectorized execution engines, but managed warehouses still edge ahead on complex concurrent workloads.
- **Storage cost**: Iceberg/Delta on S3 runs roughly $0.023/GB/month. Snowflake managed storage runs about $40/TB/month — roughly 2× higher but includes compression and micro-partition management.
- **Governance**: Warehouses have mature RBAC and auditing built in. Lakehouses require Unity Catalog or similar to reach the same level.
- **The 2024–2026 convergence**: Both sides are crossing the aisle. Snowflake added Iceberg external table support. BigQuery now reads Delta directly. Databricks ships a warehouse-quality SQL experience via Databricks SQL. The lines are blurring, but the pricing models and operational profiles remain distinct.

> [!info] The warehouse vs lakehouse decision is not purely technical — it is also a bet on your team's operational capacity. Lakehouses give you more control and lower storage costs at the price of more things to manage.

@feynman

A warehouse is a managed apartment building — you pay more per square foot, but maintenance, security, and the elevator are someone else's problem; a lakehouse is a plot of land where you build your own structure on cheap real estate and handle the plumbing yourself.

@card
id: tde-ch08-c002
order: 2
title: Snowflake Architecture
teaser: Snowflake's value proposition is one architectural decision repeated across every layer: compute and storage are completely separated, and you pay for each only when you use it.

@explanation

Snowflake stores data in its own compressed, micro-partitioned columnar format in cloud object storage (S3, GCS, or Azure Blob). Micro-partitions are immutable files of 50–500MB, each containing column-level min/max statistics. The query engine uses those statistics to prune partitions before scanning — this is how Snowflake achieves fast queries without you manually defining indexes.

The compute layer consists of virtual warehouses — independently scalable clusters you spin up and shut down. An X-Small warehouse costs 1 credit/hour; a 6X-Large costs 512 credits/hour. You can run ten warehouses simultaneously without any storage contention, because they all read from the same underlying object storage.

Key features that distinguish Snowflake:

- **Time Travel** — query data as it existed at any point in the past, up to 90 days (Enterprise tier). `SELECT * FROM orders AT (TIMESTAMP => '2024-03-01')` — no backup restoration needed.
- **Fail-Safe** — after Time Travel expires, Snowflake retains a 7-day recovery window managed by Snowflake support. Not queryable; purely a disaster recovery backstop.
- **Zero-copy cloning** — clone a 10TB database in seconds. The clone shares underlying storage with the source until rows diverge; you pay only for the delta. Critical for dev/test environments.
- **Snowpark** — run Python, Java, or Scala code inside Snowflake's compute layer. Pushes compute to the data rather than the reverse; useful for feature engineering and ML pipelines that would otherwise require an external cluster.

The credit model is the biggest source of surprise bills. A virtual warehouse running idle for 8 hours while an analyst forgot to suspend it can consume more credits than a week of deliberate queries. Auto-suspend (set to 60–300 seconds for most workloads) is not optional — it is a cost control mechanism.

> [!warning] Snowflake warehouses do not auto-suspend by default on older configurations. Always set `AUTO_SUSPEND` on every virtual warehouse you create. A Medium warehouse running 24/7 costs roughly $2,000/month in idle credits alone.

@feynman

Snowflake is like a shared library where the books (data) live on shelves anyone can reach, and the reading rooms (virtual warehouses) are rented by the hour — you only pay for the room while you're actually in it, and ten reading groups can all use the same books simultaneously.

@card
id: tde-ch08-c003
order: 3
title: Google BigQuery Architecture
teaser: BigQuery removes the cluster entirely — there are no nodes to size, no warehouses to configure, and no idle costs when your queries aren't running.

@explanation

BigQuery stores data in Capacitor, Google's proprietary columnar format, distributed across Colossus (Google's distributed file system). You never interact with storage directly; you submit SQL and BigQuery handles the rest.

Compute is provided by slots — units of CPU, memory, and I/O that BigQuery allocates to query execution. The pricing model bifurcates here, and the choice matters significantly:

- **On-demand pricing**: $5 per TB scanned. No reservation required. Spiky, unpredictable workloads fit this model. A query scanning 1TB costs $5 whether it runs in 10 seconds or 10 minutes.
- **Slot reservations**: Commit to a baseline of slots (100 slots minimum, $2,000/month at standard rates). Suitable for consistent, high-volume workloads where predictable cost matters more than per-query elasticity. Flat-rate pricing often breaks even around 8–10TB scanned per day.

Additional features worth knowing:

- **BigQuery ML**: Train and inference ML models with SQL. `CREATE MODEL` runs logistic regression, XGBoost, or AutoML inside BigQuery without data leaving the warehouse. Reduces the need for an external ML platform for simpler use cases.
- **BI Engine**: In-memory analysis layer that accelerates specific queries against cached table data to sub-second latency. Targeted at dashboard queries that hit the same tables repeatedly — Looker and Data Studio both integrate with it directly.
- **INFORMATION_SCHEMA**: BigQuery exposes query history, table metadata, reservation usage, and job statistics through `INFORMATION_SCHEMA` views. This is your primary tool for auditing query costs and diagnosing scan inefficiency.

Partition pruning is the single highest-leverage cost control in BigQuery. A query on a 10TB table partitioned by date that filters on `WHERE date >= CURRENT_DATE - 7` scans only 7 days of data rather than the full table. Without a partition filter on a large on-demand table, a single careless query can generate a $50 bill.

> [!tip] Use `SELECT * EXCEPT(columns_you_dont_need)` carefully — BigQuery charges for columns scanned in non-nested tables. Select only what you need, and partition aggressively on date columns that appear in your WHERE clauses.

@feynman

BigQuery is like a taxi with a metered fare based on distance traveled (bytes scanned), not time in the cab — fast or slow, you pay for the road you cover, so the way to cut your bill is to take shorter routes, not drive faster.

@card
id: tde-ch08-c004
order: 4
title: Amazon Redshift Architecture
teaser: Redshift is the data warehouse you choose when your data lives in AWS and your team already speaks the AWS operational language — it integrates natively with S3, Glue, and the rest of the ecosystem.

@explanation

Redshift is a massively parallel processing (MPP) database. A cluster has one leader node that parses queries and coordinates execution, and one or more compute nodes that store data and execute query slices in parallel. The query planner splits work across nodes and combines results at the leader.

Data distribution is explicitly controlled, and the choice has a direct impact on query performance and data movement:

- **KEY distribution**: rows with the same distribution key land on the same node. Joins between large tables on the distribution key avoid cross-node data movement — ideal for a `fact_orders` table joined frequently on `customer_id`.
- **ALL distribution**: a full copy of the table on every node. Use for small, frequently joined dimension tables (under ~1M rows) where broadcast cost is acceptable.
- **EVEN distribution**: rows round-robined across nodes. Simple, no skew, but joins require full redistribution — fine for append-only tables that aren't joined to other large tables.
- **AUTO**: Redshift chooses KEY or ALL based on table size. Sensible default for tables whose access pattern you don't know yet.

Sort keys determine physical row ordering on disk — Redshift uses zone maps (min/max per 1MB block) to skip blocks that don't match a range predicate. A `date` sort key on a table queried by date range can reduce scan by 90%+ on filtered queries.

RA3 nodes (current generation) decouple compute and storage: data lives in Redshift Managed Storage (RMS), backed by S3, and compute nodes cache hot data locally. You can resize compute without migrating data — a structural improvement over older DS2 nodes where storage was tied to instance size.

Redshift Serverless provides automatic scaling without cluster management, billing per RPU-second. For variable or unpredictable workloads it removes the "right-size the cluster" problem. For steady high-volume workloads, provisioned RA3 clusters usually cost less.

Redshift Spectrum lets you query data in S3 directly using external tables, paying $5/TB scanned (same rate as BigQuery on-demand). It bridges the gap to your data lake without moving data into Redshift managed storage.

> [!info] Distribution key mismatches are the most common cause of Redshift performance degradation. Run `SVV_TABLE_INFO` and inspect the `diststyle` and `skew_rows` columns before concluding a query is slow due to cluster size.

@feynman

Redshift is like a factory floor divided into stations — each station (compute node) works on its own slice of the data in parallel, and the floor manager (leader node) combines their outputs; the efficiency depends entirely on how well you assigned which parts to which stations at the start.

@card
id: tde-ch08-c005
order: 5
title: Databricks Lakehouse Platform
teaser: Databricks is what you choose when your team does data engineering, machine learning, and analytics engineering and you want all three on a single platform rather than three separate tools stitched together with pipelines.

@explanation

Databricks is built on three open-source projects that it largely created: Apache Spark (distributed compute), Delta Lake (ACID transactions on object storage), and MLflow (ML experiment tracking and model registry). The commercial platform wraps these with Unity Catalog for governance, Databricks SQL for warehouse-quality SQL, and a managed runtime layer.

The key components:

- **Databricks SQL**: A serverless SQL endpoint that runs on the Photon engine — a C++ vectorized query engine designed to accelerate Spark SQL by 2–12× on typical analytical queries. It behaves like a warehouse from the user's perspective (JDBC/ODBC compatible, integrates with BI tools) while storing data in Delta format on your own cloud storage.
- **Unity Catalog**: A unified governance layer for data, ML models, and feature stores. A single catalog spans multiple workspaces — critical for organizations with prod/dev workspace separation. Fine-grained access control, column-level masking, and audit logs.
- **Delta Sharing**: An open protocol (not vendor-specific) for sharing live Delta or Parquet data with external organizations without copying it. The recipient queries data through a pre-signed URL or a REST endpoint; the provider controls access and revokes it without moving files. Snowflake and other platforms have added Delta Sharing connectors, making it genuinely cross-platform.
- **MLflow**: Tracks experiment parameters and metrics, stores trained model artifacts, and manages model versioning through a registry. A data engineer working on feature pipelines and an ML engineer training models can share the same workspace.

DBU (Databricks Unit) is the billing unit — compute costs are DBUs per node per hour multiplied by node count and runtime. A Standard DBU on a typical cloud instance runs $0.07–0.22/DBU depending on tier and cloud. Photon workloads consume more DBUs per hour but complete faster — net cost is usually neutral to lower for SQL-heavy workloads, better for scan-heavy pipelines.

> [!info] The most common Databricks cost mistake is leaving clusters running between jobs. All-purpose clusters (interactive) accrue DBUs continuously when attached. Job clusters (ephemeral, spun up per job run) are cheaper by 2–3× for scheduled workloads and should be the default for production pipelines.

@feynman

Databricks is like a research lab and a factory combined — the same physical space where scientists experiment, engineers run production lines, and analysts pull reports, all sharing the same raw materials stored in a warehouse next door.

@card
id: tde-ch08-c006
order: 6
title: Cost Per Query Patterns
teaser: Each cloud data platform charges you differently — and the gap between "I understand the pricing model" and "I optimized for it" is where most teams leave money on the table.

@explanation

Understanding the billing unit for each platform is the prerequisite for cost control:

- **Snowflake**: credits consumed by virtual warehouses. Cost = warehouse size × run time. An X-Large warehouse (16 nodes) costs 16 credits/hour; at $3–4/credit, that is $48–64/hour. The lever is auto-suspend: a warehouse that runs 10 minutes instead of 60 costs one-sixth as much.
- **BigQuery (on-demand)**: $5/TB scanned. The lever is partition pruning and column selection. A query that scans 500GB instead of 5TB saves $22.50 per execution — multiplied by 100 daily runs, that is $82,000/year.
- **BigQuery (reservations)**: flat monthly cost for committed slots. Once you have reservations, additional queries are "free" from a marginal cost perspective. The lever is slot utilization — idle slots are wasted spend.
- **Redshift (RA3)**: hourly node cost (~$3.26–$13.04/node/hour depending on size) plus Spectrum ($5/TB scanned for S3 queries). The lever is right-sizing the cluster and scheduling cluster pause windows for overnight hours.
- **Databricks**: DBUs/hour × node count × runtime. The levers are cluster auto-termination, job clusters vs all-purpose clusters, and spot instance usage (50–80% cheaper for fault-tolerant batch workloads).

Platform-agnostic optimization levers:

- **Clustering and partitioning**: reduces data scanned per query. A Snowflake table clustered on `event_date` with 99% query filters on the last 7 days will prune ~95% of partitions automatically.
- **Materialized views**: pre-compute expensive aggregations. BigQuery materialized views update incrementally and are used transparently by the query planner when the query pattern matches.
- **Result caching**: Snowflake and BigQuery both cache identical query results (same query text, same data version) and serve them at zero compute cost. Dashboard queries that run every 30 seconds against unchanged data can hit cache rates of 70–90%.

> [!warning] Costs at cloud data platforms compound invisibly. A Snowflake virtual warehouse auto-suspended at 300 seconds instead of 60 seconds costs 4× more in idle time across a team of 20 analysts running short queries throughout the day. Audit warehouse utilization logs monthly.

@feynman

Cloud data platform pricing is like renting a construction crane — Snowflake charges you by the hour the crane is on your site, BigQuery charges you by how much material the crane moves, and Databricks charges you by both the crane size and the time, with a discount if you're willing to use a crane that might be recalled mid-job.

@card
id: tde-ch08-c007
order: 7
title: Data Sharing and Marketplace
teaser: Live data sharing — where the consumer queries the provider's data directly without a file transfer or a copy — changes the operational model for data products inside and outside your organization.

@explanation

Traditional data sharing involves exporting a file, sending it to a recipient, and trusting they imported the right version. Live data sharing eliminates the copy: the consumer queries data that physically lives in the provider's storage, governed by the provider's access controls, and always reflects the current version.

The three main implementations:

- **Snowflake Data Sharing**: a provider creates a share object pointing to specific tables or views. The consumer (another Snowflake account, potentially on a different cloud) adds the share and queries it as if it were a local database. No data movement occurs — the consumer's virtual warehouse reads directly from the provider's storage. Revocation is instant. Cross-cloud sharing requires Snowflake's replication layer, which does move data, but within Snowflake.
- **BigQuery Analytics Hub**: a marketplace model for listing datasets. Providers publish a "listing" — a dataset that subscribers can link to their own project. Linked datasets are read-only views into the provider's BigQuery dataset. Governance, column-level security, and audit logs apply. Well-suited for internal data products across GCP projects or for publishing to external customers on GCP.
- **Delta Sharing**: an open REST protocol that works across platforms. A Databricks workspace (or any Delta Sharing server) exposes shares that recipients can access with any compatible client — including non-Databricks environments, Pandas in Python, or Tableau. The key differentiator is vendor neutrality: a consumer does not need a Databricks account.

The data marketplace model — purchasing third-party datasets through platforms like Snowflake Marketplace or AWS Data Exchange — extends these mechanisms to commercial data. A retailer can subscribe to a weather dataset or foot traffic index and join it directly against internal sales data without ever receiving a CSV.

The practical implication: live sharing changes data products from one-time exports to live subscriptions. The consumer always sees current data; the provider retains access control. The operational cost is a governance model that holds up under scrutiny — if a consumer can query your `customer_pii` table, accidental column exposure in a share is a breach, not a misconfiguration.

> [!tip] Before building a custom data API to share data with an external partner, check whether your cloud platform's native sharing mechanism covers the use case. A Snowflake share or a BigQuery Analytics Hub listing eliminates the maintenance overhead of an API while providing better access controls.

@feynman

Live data sharing is like giving someone a library card that lets them read books in your library rather than photocopying the pages — they always see the current edition, and you can revoke the card without chasing down every copy.

@card
id: tde-ch08-c008
order: 8
title: Warehouse Performance Tuning
teaser: Before you spend more on a larger cluster or a bigger reservation, spend thirty minutes reading an EXPLAIN plan — most warehouse slowness is fixable without adding compute.

@explanation

The universal first step is the query execution plan. Every major platform exposes it:

- Snowflake: `EXPLAIN USING TABULAR SELECT ...` or the Query Profile in the UI (shows operator-level time and bytes)
- BigQuery: `EXPLAIN` or the Query Execution Details panel (shows slot time and bytes processed per stage)
- Redshift: `EXPLAIN SELECT ...` or SVL_QUERY_REPORT for post-execution analysis
- Databricks: Spark UI with the physical plan and shuffle read/write metrics

What to look for in the plan before escalating to "we need bigger compute":

- **Large scans on unpartitioned/unclustered columns**: a query scanning 100% of a partitioned table because the filter column is not the partition key. Fix: repartition or add a clustering key.
- **Large shuffles (Spark/Redshift)**: data redistribution across nodes is expensive. A 500GB shuffle on a 10-node cluster means each node is sending and receiving 50GB over the network. Fix: join on the distribution key or broadcast the smaller table.
- **Skewed distribution**: 90% of query time on one node or one slot. In Redshift, `SELECT tbl, skew_rows FROM SVV_TABLE_INFO` surfaces this. Fix: change the distribution key to a higher-cardinality column.

Platform-specific tuning tools:

- **Snowflake automatic clustering**: for tables queried heavily on a specific column (e.g., `event_date`), enabling automatic clustering maintains micro-partition ordering automatically. Cost is ongoing credits, so only enable it when query pruning savings exceed clustering costs — typically for tables above 100GB with selective range filters.
- **Materialized views**: all four major platforms support them. A materialized view pre-aggregates a query result and refreshes on a schedule or incrementally. A daily summary table that previously took 90 seconds to aggregate from a 5TB fact table runs in under a second from the materialized view.
- **Statistics freshness**: query planners use table statistics to choose join order and distribution strategy. Stale statistics cause wrong plans. In Redshift, run `ANALYZE` after large loads. BigQuery statistics update automatically. Snowflake updates them on DML operations.

> [!info] Result caching is free compute savings you may already be getting without realizing it. Snowflake caches query results for 24 hours if the underlying data hasn't changed. BigQuery caches for 24 hours per query text and data version. Dashboard tools that run the same query every 5 minutes can have >80% cache hit rates — that is 80% of those queries consuming zero compute.

@feynman

Tuning a slow warehouse query is like debugging a slow function before buying a faster server — you read the profiler output, find the line that takes 90% of the time, and fix that specific thing, because throwing hardware at an unpartitioned table scan is just a faster way to do the same wasteful work.

@card
id: tde-ch08-c009
order: 9
title: Multi-Cloud Data Strategy
teaser: Multi-cloud sounds like resilience, but for most data engineering teams it is two of everything — two billing models, two skill sets, two sets of operational runbooks — and the actual resilience benefit is limited.

@explanation

The motivations for multi-cloud data architectures are real:

- **Avoid vendor lock-in**: a single platform can change pricing, deprecate features, or be acquired. Distributing across clouds provides negotiating leverage and an exit path.
- **Regulatory data residency**: some jurisdictions require data to remain within a specific geography or cloud provider. A company serving EU customers from GCP and US customers from AWS may have this forced on them.
- **Best-in-class per workload**: use BigQuery for large-scale batch analytics, Snowflake for governed SQL sharing with external partners, Databricks for ML training — each where it genuinely excels.

The operational costs that usually get underestimated:

- **Skill duplication**: your data engineering team needs to be competent on both platforms. Two credential systems, two monitoring setups, two cost management consoles, two incident playbooks.
- **Data transfer costs**: moving data between clouds costs $0.08–$0.09/GB in egress fees. A 10TB daily transfer between AWS and GCP costs roughly $800/day — $292,000/year before any compute.
- **Latency**: cross-cloud joins require replicating data to one side first. A real-time join between a BigQuery table and a Snowflake table requires ETL, not a query.

The open format hedge is the most pragmatic version of multi-cloud: store data in Apache Iceberg or Delta Lake on object storage, choose your compute separately. Because the format is open, you can replace the query engine (Athena → Spark → Databricks SQL) without migrating the data. Data egress costs still apply, but you've decoupled the storage bet from the compute bet.

The actual question: does your team have the engineering capacity to operate two platforms at production quality, or are you accepting lower quality on both to avoid betting on one?

> [!warning] Multi-cloud data architectures are rarely cheaper than single-cloud at the teams that adopt them expecting cost savings. The savings from competitive pricing are typically smaller than the added engineering overhead and data transfer costs. Adopt multi-cloud for genuine regulatory or resilience requirements, not hypothetical vendor leverage.

@feynman

Running data on two clouds to avoid lock-in is like keeping accounts at two banks to avoid being dependent on one — theoretically sound, but in practice you are paying two sets of fees and managing two logins to prevent a problem that may never materialize.

@card
id: tde-ch08-c010
order: 10
title: Choosing a Cloud Data Platform
teaser: The right cloud data platform is determined by your current cloud ecosystem, your query patterns, and your team's operational capacity — not by which vendor has the best conference talk.

@explanation

The decision is genuinely context-dependent, but the signal set is knowable:

**Choose BigQuery if:**
- You are already on Google Cloud (GKE, Cloud Run, Pub/Sub integration is native)
- Your workload is bursty and unpredictable — on-demand pricing means you pay nothing when idle
- You are running large-scale analytics on 10s of terabytes where the serverless model eliminates cluster sizing decisions
- You need BigQuery ML for in-database model training without an external MLOps platform

**Choose Snowflake if:**
- You are multi-cloud or want to keep optionality between AWS/GCP/Azure
- Strong SQL, rich data sharing, and Data Marketplace access are priorities
- Your team is primarily SQL-focused (analysts, analytics engineers) rather than Spark-heavy
- You need cross-organization data sharing via Snowflake Sharing or the Marketplace

**Choose Redshift if:**
- You are AWS-native with heavy EC2/S3/Glue/Lambda integration
- Your workload is steady and predictable — provisioned RA3 clusters amortize well at constant utilization
- You need Redshift Spectrum to bridge from a Redshift warehouse into an S3 data lake without a full platform migration

**Choose Databricks if:**
- Your team does data engineering and ML together and you want a single platform for both
- You have large Spark workloads and want managed Spark without cluster operations overhead
- You are standardizing on Delta Lake and want full Unity Catalog governance
- Python-heavy data science workflows are a primary use case alongside SQL analytics

The anti-pattern to avoid: choosing a platform because it is what the team already knows without validating that it fits the query and cost patterns of the new workload. A team comfortable with Redshift that is now running highly variable, analyst-driven ad-hoc queries will overpay for provisioned nodes relative to BigQuery's on-demand model. Run a proof of concept with your actual query workload and actual data volumes before signing a contract.

> [!tip] Before evaluating platforms, document your workload profile: average query count per day, peak concurrency, data volume scanned per query, and whether usage is predictable or bursty. A one-page workload summary makes vendor evaluations dramatically more productive and prevents the "we chose it because it sounded good" outcome.

@feynman

Picking a cloud data platform without profiling your workload first is like buying a car based on the brochure without knowing whether you drive mostly highway or city — the specs that matter are determined by the roads you actually travel, not the ones the manufacturer highlights.
