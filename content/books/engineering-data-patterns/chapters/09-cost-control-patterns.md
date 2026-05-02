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
