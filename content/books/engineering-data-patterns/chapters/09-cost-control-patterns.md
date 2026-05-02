@chapter
id: depc-ch09-cost-control-patterns
order: 9
title: Cost-Control Patterns
summary: The patterns that prevent data infrastructure from becoming a runaway spend — query result caching, materialized vs virtual, partition pruning, tier automation, and FinOps tagging.

@card
id: depc-ch09-c001
order: 1
title: Why Data Infrastructure Is Expensive By Default
teaser: Cloud-native data tools make it easy to start. The billing model makes it equally easy to spend without noticing until the invoice arrives.

@explanation

Cloud-native data infrastructure has a characteristic billing dynamic: the costs are invisible until the end of the month, and they compound.

Common cost drivers:

- **Query compute:** warehouses like Snowflake, BigQuery, and Redshift bill per byte scanned or per second of compute. A full table scan on a 10 TB table costs the same whether it returns one row or all of them.
- **Storage:** storing the same data at bronze, silver, and gold triples storage cost at minimum.
- **Egress:** moving data across regions or clouds triggers per-GB egress fees that accumulate quietly.
- **Idle compute:** a warehouse cluster that's never paused charges even when no queries are running.
- **Small-file overhead:** millions of small files on S3 generate expensive LIST operations; queries scan them all even when most are empty.

The FinOps discipline (cloud financial operations) exists specifically because engineering teams consistently underestimate and under-monitor these costs.

> [!warning] Costs don't announce themselves. A well-meaning engineer who adds a daily full table scan of a 500 GB table "just to be safe" adds $50-200/month without any visible signal unless someone reviews billing.

@feynman

Like leaving the lights and heat on in every room because you're not sure which rooms you'll use — the convenience compounds into a surprise bill.

@card
id: depc-ch09-c002
order: 2
title: Query Result Caching
teaser: Cache the results of expensive queries so repeated executions don't re-scan the same data. The fastest query is the one that never runs.

@explanation

**Query result caching** stores the output of a query for reuse by subsequent identical or similar queries, avoiding the cost and latency of re-executing against the underlying table.

Types of caching:

**Warehouse-layer caching:** Snowflake, BigQuery, and Redshift all cache query results automatically for a period (24 hours in Snowflake). Identical queries against unchanged data return the cached result for free. No action required; be aware of the behavior and avoid defeating it with `NOW()` or random row ordering that makes each query unique.

**Application-layer caching:** a BI tool or API stores query results in its own cache, refreshed on a schedule. Tableau Extracts, Looker PDTs (persistent derived tables), Superset database caches.

**Materialized tables:** pre-compute expensive aggregations and write them to a table. Downstream queries read the materialized table instead of re-computing the aggregate.

When to cache:
- The same query runs repeatedly (dashboards refreshed every few minutes).
- The underlying data doesn't change between refreshes (daily refresh for a daily dashboard).
- The query is expensive (full table scan, complex join).

When not to cache:
- The query needs real-time results and correctness matters more than cost.
- The underlying data changes faster than the cache refresh interval.

> [!tip] Every dashboard query is a candidate for caching. Most dashboard consumers don't need data fresher than the pipeline's delivery interval. If the pipeline delivers at 6 AM, a 6 AM cache refresh is sufficient.

@feynman

Like building a FAQ page instead of answering the same email 100 times — invest once, avoid re-computing repeatedly.

@card
id: depc-ch09-c003
order: 3
title: Materialized Views vs Virtual Views
teaser: Virtual views are zero-cost to create but full-cost to query. Materialized views cost storage but turn expensive queries into cheap reads. Choose based on query frequency.

@explanation

**Virtual views** (standard SQL views) are named queries stored in the catalog. When you query a view, the database replaces the view reference with the view's query and executes it. Cost: the same as running the underlying query directly.

**Materialized views** pre-execute the query and store the result as a physical table. When you query a materialized view, you read the stored result. Cost: near-zero (a table scan) after the materialization job runs.

Decision framework:

- **Query frequency:** a view queried 1,000 times per day costs 1,000× more than a materialized view queried 1,000 times per day (the materialized query ran once).
- **Staleness tolerance:** materialized views are stale until refreshed. If consumers need real-time results, a virtual view is more correct.
- **Refresh cost:** materializing a 10 TB aggregation every 15 minutes is expensive. Materializing it once per day is cheap. Match refresh frequency to the staleness tolerance.

In BigQuery: materialized views refresh automatically when the base table changes; you can also add a `max_staleness` parameter to allow controlled lag in exchange for reduced refresh cost.

In dbt: models configured as `materialized = 'table'` are full materialized tables; `materialized = 'view'` are virtual; `materialized = 'incremental'` is incremental append with merge.

> [!info] The highest-ROI optimization in most data warehouses is materializing the 5-10 queries that run most frequently. In Snowflake, the Query History tab shows the most expensive recurring queries — start there.

@feynman

Like printing a report vs computing it from scratch every time — printing costs paper; computing costs time; choose based on how often people ask.

@card
id: depc-ch09-c004
order: 4
title: Partition Pruning for Cost
teaser: A query that scans only the relevant partitions costs a fraction of one that scans the whole table. Partition-aware queries are the first thing to check on expensive warehouse bills.

@explanation

**Partition pruning** is the query optimizer's ability to skip partitions that don't contain relevant data based on the WHERE clause. For a table partitioned by date, a query filtering on a single day reads 1/365 of the data at 1/365 of the cost.

Partition pruning only works when:
- The query explicitly filters on the partition column.
- The filter is a literal value or parameter, not a function applied to the partition column.

What works:
```sql
-- Reads only the 2026-05-01 partition
SELECT * FROM events WHERE event_date = '2026-05-01'
```

What defeats pruning:
```sql
-- Full table scan — DATE_TRUNC prevents pruning in many warehouses
SELECT * FROM events WHERE DATE_TRUNC('day', event_timestamp) = '2026-05-01'
```

Practical cost impact: a 1 TB table partitioned by day, with 365 partitions. A single-day query with pruning reads 2.7 GB. The same query without pruning reads 1 TB. In BigQuery, which bills per byte scanned, the difference is $0.015 vs $5.

Common mistakes that defeat pruning:
- Applying functions to the partition column in WHERE (`DATE_FORMAT(dt, ...)`, `CAST(dt AS STRING)`).
- Using a non-partition column as the only filter.
- Joining a large table to a small table where the optimizer doesn't recognize the filter applies to the large table.

> [!tip] Check the partition elimination count in query plans before assuming pruning is working. Snowflake's query profile and BigQuery's execution plan both show partitions scanned vs total.

@feynman

Like searching only the relevant filing cabinet drawer instead of opening every drawer — the query plan tells you whether the optimizer actually did that.

@card
id: depc-ch09-c005
order: 5
title: Tier Downgrade Automation
teaser: Automate the movement of old data to cheaper storage classes. Most teams manually manage tiering until a quarterly bill forces the conversation.

@explanation

**Tier downgrade automation** uses lifecycle policies to automatically move data to cheaper storage classes as it ages, without manual intervention.

Implementation by platform:

**S3 lifecycle rules:** define rules that transition objects to cheaper storage classes after a configured number of days. No code required — configured via the AWS console or Terraform.

```json
{
  "Rules": [{
    "Filter": {"Prefix": "data/"},
    "Transitions": [
      {"Days": 90, "StorageClass": "STANDARD_IA"},
      {"Days": 365, "StorageClass": "GLACIER_INSTANT_RETRIEVAL"}
    ],
    "Status": "Enabled"
  }]
}
```

**Iceberg table maintenance:** Iceberg supports retention policies on snapshot history. `expire_snapshots` removes snapshots older than a configured retention window; `remove_orphan_files` cleans up files no longer referenced by any snapshot.

**Snowflake auto-suspend:** Snowflake virtual warehouses should be configured to auto-suspend after a period of inactivity. A warehouse that auto-suspends after 60 seconds charges nothing for the 23.5 hours per day it's not being used.

ROI analysis example: a team with 500 TB of data, 80% older than 90 days. Moving 400 TB from Standard to Standard-IA saves ~$8,000/month at AWS pricing. The lifecycle rule takes 30 minutes to configure.

> [!tip] Set a quarterly reminder to review data volumes and verify lifecycle policies are in place. Storage grows; lifecycle policies don't update themselves.

@feynman

Like archiving old email to cold storage — it's still there if you need it, but you're not paying active-inbox prices for things you haven't touched in two years.

@card
id: depc-ch09-c006
order: 6
title: FinOps Tagging for Data Infrastructure
teaser: Tag every data infrastructure resource by team, pipeline, and environment. Without tags, cost attribution is impossible and optimization is guesswork.

@explanation

**FinOps tagging** means labeling cloud resources with metadata that enables cost attribution — connecting cloud spend to the specific teams, products, or pipelines that generated it.

Without tagging, an AWS bill might show $80,000 in Snowflake credits. With tagging, it shows "$12,000 for the analytics team's daily warehouse, $18,000 for the ML feature pipeline, $4,000 for ad-hoc development queries."

Tag categories for data resources:

- **Team:** which team owns this resource (`team: data-platform`).
- **Pipeline:** which specific pipeline or workload (`pipeline: orders-daily-etl`).
- **Environment:** prod vs dev vs staging (`env: prod`).
- **Cost center:** for cross-charge or budget attribution.

Where to apply tags:
- Cloud object storage (S3 buckets, GCS buckets).
- Warehouse resources (Snowflake warehouses, BigQuery datasets, Redshift clusters).
- Compute (EC2/GKE clusters, Glue jobs, Dataflow pipelines).
- Streaming infrastructure (Kafka clusters, Kinesis streams).

In Snowflake, use resource monitors and query tags to attribute compute spend per team:
```sql
ALTER SESSION SET QUERY_TAG = 'team:analytics,pipeline:orders-daily-etl';
```

> [!info] FinOps tagging must be mandatory from the start, not retrofitted. Adding tags after 18 months of untagged resources requires auditing every existing resource — a multi-week project that could have been a policy on day one.

@feynman

Like labeling every expense in an expense report — obvious in hindsight, painful to reconstruct if you didn't do it at the time.

@card
id: depc-ch09-c007
order: 7
title: Warehouse Sizing and Auto-Scaling
teaser: An oversized warehouse burns credits on idle capacity; an undersized one queues queries and breaks SLAs. Right-sizing is an ongoing tuning exercise, not a one-time decision.

@explanation

Cloud warehouses (Snowflake virtual warehouses, BigQuery slots, Redshift clusters) are sized independently of storage. The cost of compute is directly controlled by warehouse configuration.

**Snowflake** bills per-second of warehouse uptime (minimum 60 seconds per resume). A XL warehouse costs 2× a L, which costs 2× a M. Larger warehouses don't always mean faster queries — they mean more parallelism for queries that benefit from it.

Right-sizing heuristics for Snowflake:
- Most dashboard and reporting queries run fine on an XS or S warehouse.
- Large historical scans, complex multi-table joins, and ML model training benefit from M or L.
- Multi-user concurrent workloads (many analysts querying simultaneously) benefit from multi-cluster warehouses with auto-scaling.

**Auto-suspend and auto-resume:** configure every warehouse to auto-suspend after 60 seconds of inactivity. A warehouse resumed for a single 3-second query costs 60 seconds of credit — the minimum. Even so, auto-suspend prevents hours of idle billing.

**Workload isolation:** separate warehouses for ETL vs analytics vs dashboards. This prevents a large ETL job from starving analyst queries, and lets you right-size each workload independently.

**BigQuery slot reservations:** BigQuery can run in on-demand mode (pay per byte scanned) or reserved slot mode (fixed monthly cost). Reserved slots are cheaper at high query volumes but require capacity planning.

> [!tip] Query the Snowflake `ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY` view to see credit consumption per warehouse per hour. The first time you run this, you will almost always find a warehouse that was running while no one was using it.

@feynman

Like choosing server instance sizes in a cloud deployment — you right-size to the workload, monitor utilization, and resize when the workload changes.

@card
id: depc-ch09-c008
order: 8
title: Spot and Preemptible Instances for Batch
teaser: Batch transformation and ML training pipelines that tolerate interruption can run on spot instances at 60–80% lower compute cost than on-demand.

@explanation

**Spot instances** (AWS) and **preemptible VMs** (GCP) are excess cloud compute capacity offered at steep discounts — typically 60–80% below on-demand prices — with the catch that the cloud provider can reclaim the instance with 2 minutes notice.

This trade-off is a natural fit for batch data engineering workloads that are:
- **Restartable:** the job can be re-run from a checkpoint without losing all progress.
- **Long-running:** the savings compound on jobs that run for hours or days.
- **Not time-critical:** running on spot may extend wall-clock time due to interruptions; that's acceptable for non-SLA-sensitive batch work.

Workloads that work well on spot:
- Spark batch transforms (with checkpointing enabled).
- ML model training (with checkpoint-based restart).
- Large historical backfills.
- Data quality scan jobs.

Workloads that shouldn't use spot:
- Streaming consumers (interruption means gap in the stream; recovery is complex).
- Time-sensitive pipelines with hard SLAs.
- Interactive queries.

AWS Spot best practices:
- Use **Spot Fleet** or **EMR managed scaling** to automatically replace interrupted instances.
- Enable **checkpointing** in Spark (`spark.checkpoint.dir`); on resume, the job picks up from the last checkpoint, not the beginning.
- Mix spot and on-demand: 80% spot, 20% on-demand ensures a minimum cluster exists even during spot shortages.

> [!info] A 10-hour Spark job running on spot at 70% discount costs the same as a 3-hour on-demand job. If it can tolerate interruption and occasional restart, the math strongly favors spot.

@feynman

Like flying standby — cheaper, occasionally disrupted, worth it for trips where you have flexibility.

@card
id: depc-ch09-c009
order: 9
title: Egress Cost Reduction Patterns
teaser: Moving data between regions or clouds triggers per-GB egress fees. Architecture choices made without considering egress can easily cost more in network fees than in compute.

@explanation

Cloud egress fees — charges for data leaving a cloud provider's network — are one of the most surprising line items in data infrastructure bills. They're low-per-GB but multiply across high-volume data movement.

Typical egress pricing (approximate):
- Same-region, same-cloud: free.
- Cross-AZ, same-region: $0.01/GB (AWS).
- Cross-region, same-cloud: $0.02–0.09/GB.
- Cross-cloud or to internet: $0.05–0.15/GB.

Where data engineering generates egress:
- **Multi-region warehouse access:** analysts in EU-West querying a warehouse in US-East. Every query result crosses regions.
- **Cross-region pipeline movement:** Spark cluster in us-east-1 reading raw data from S3 in us-west-2.
- **Reverse ETL to SaaS:** pushing data to Salesforce, HubSpot, or other SaaS systems that live in a different cloud or region.
- **Cross-cloud data sharing:** sending data to a partner on a different cloud.

Reduction strategies:
- **Compute close to data:** run Spark or Flink in the same region as S3.
- **Compress before shipping:** reduce bytes transferred proportionally to the compression ratio. Parquet/Snappy gives 5–10× compression over CSV.
- **Use private connectivity:** AWS PrivateLink, GCP Private Service Connect often eliminate NAT gateway fees that compound egress.
- **Cache query results:** a materialized table in the EU served from EU storage avoids cross-region result transfer on every query.

> [!warning] A pipeline that moves 10 TB/month across regions adds $200–900/month in egress alone at AWS pricing. This isn't visible until the bill arrives. Audit data movement paths when designing cross-region architectures.

@feynman

Like international roaming — cheap to use, expensive to abuse, and the bill arrives after the trip is already over.

@card
id: depc-ch09-c010
order: 10
title: Cost Attribution and Showback
teaser: Sharing a warehouse across teams without cost attribution means nobody is accountable for spend. Showback makes the cost of each team's usage visible without requiring chargeback.

@explanation

**Cost attribution** connects cloud infrastructure spend to the specific teams, products, or pipelines that generated it. **Showback** means making that attribution visible to the teams — "your pipelines cost $4,200 last month" — without requiring them to pay from their budget (which would be **chargeback**).

Why showback works when no attribution doesn't: teams that can see their own costs change their behavior. A team that learns their ad-hoc query cluster runs $800/week during business hours often finds ways to consolidate or cache that are invisible without the signal.

Attribution in Snowflake:
```sql
-- Tag each session with team and pipeline
ALTER SESSION SET QUERY_TAG = '{"team":"analytics","pipeline":"orders-dashboard"}';
```

Query the results:
```sql
SELECT
    PARSE_JSON(query_tag):team::STRING AS team,
    SUM(credits_used) AS credits
FROM ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE)
GROUP BY team
ORDER BY credits DESC
```

Attribution in BigQuery: label datasets, jobs, and reservations by team. BigQuery exports billing data to BigQuery (recursively) for detailed cost analysis.

Monthly showback report: a one-page summary per team showing their top 5 most expensive queries or pipelines, their credit/dollar spend, and how it compares to the prior month. Delivered to engineering leads, not finance.

> [!tip] Start showback before costs become a problem. The first report creates visibility; subsequent reports create accountability; eventually teams self-regulate. Starting after a cost crisis feels punitive rather than informational.

@feynman

Like showing developers their test coverage numbers — the metric itself changes behavior more than any mandate would.
