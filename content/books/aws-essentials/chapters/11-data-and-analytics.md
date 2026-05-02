@chapter
id: aws-ch11-data-and-analytics
order: 11
title: Data and Analytics
summary: AWS's data and analytics stack spans managed metadata, serverless SQL, real-time streaming, and lakehouse architecture — knowing which tool solves which class of problem lets you build pipelines that are fast to build and cheap to run.

@card
id: aws-ch11-c001
order: 1
title: AWS Glue Data Catalog
teaser: The Glue Data Catalog is the single place where all your data assets get names, schemas, and locations — without it, Athena, EMR, and Redshift Spectrum are each working from their own private map of your S3 data.

@explanation

The Glue Data Catalog is a managed metadata repository: it stores database and table definitions, partition information, and schema versions for data that lives anywhere — typically S3, but also JDBC sources. You don't move your data into the Catalog; you register metadata about where the data is and what shape it has.

The core objects are:

- **Databases** — logical namespaces, not storage.
- **Tables** — schemas (column names, types, SerDe settings) pointing to a physical location in S3 or elsewhere.
- **Crawlers** — Glue agents that scan a data source, infer schemas, and populate or update table definitions automatically. A crawler run costs ~$0.44/DPU-hour.

Three services share the same Catalog natively:

- **Amazon Athena** — runs SQL against Catalog tables without any additional setup.
- **Amazon EMR** — uses Catalog as a drop-in Hive Metastore; you pass one flag at cluster creation.
- **Redshift Spectrum** — queries Catalog tables directly from a Redshift cluster.

Schema versioning is built in. Each time a crawler detects a schema change, it creates a new version rather than overwriting the previous one — useful for debugging why a downstream query broke after a data format change.

The Glue Catalog replaced the need to run your own Hive Metastore. A self-managed Hive Metastore requires an RDS instance, EC2 to host the Metastore service, and you to handle HA yourself. Glue Catalog is serverless, costs $1 per 100,000 objects stored per month, and requires no infrastructure management.

> [!info] If you already run a Hive Metastore on EMR and want to migrate, Glue Catalog is a one-flag swap — EMR accepts `--configurations` pointing to the Glue Catalog endpoint. Your Hive DDL and table schemas migrate as-is.

@feynman

The Glue Data Catalog is the package.json of your data lake — it tells every tool where to find each dataset and what format to expect, so they don't each have to figure it out independently.

@card
id: aws-ch11-c002
order: 2
title: AWS Glue ETL Jobs
teaser: Glue ETL gives you serverless Spark without managing clusters — you write the transformation logic, AWS provisions the compute, and you pay only for the DPU-hours consumed.

@explanation

A Glue ETL job runs Apache Spark under the hood, but you never provision or manage the cluster. You write Python or Scala, upload it, and Glue handles execution. The billing unit is a DPU-hour (Data Processing Unit): one DPU is 4 vCPUs and 16 GB of memory. A standard job starts with 10 DPUs; cost is $0.44/DPU-hour.

Worker types let you right-size the job:

- **G.1X** — 1 DPU per worker, 16 GB memory. Good for memory-efficient workloads.
- **G.2X** — 2 DPUs per worker, 32 GB memory. Default recommendation for most ETL.
- **G.4X** — 4 DPUs per worker, 64 GB memory. Heavy joins, large shuffles, ML feature engineering.

Glue introduces **DynamicFrames** as an alternative to native Spark DataFrames. A DynamicFrame handles schema inconsistencies across records without failing the job — if one JSON record has a field with type `string` and another has it as `null`, Spark throws; DynamicFrame tracks the mismatch in a "choice" column and keeps processing. You resolve choices explicitly before writing output. For clean, well-typed data, native Spark DataFrames perform better and give you the full Spark API surface.

**Job bookmarks** solve incremental processing. When enabled, Glue tracks which S3 objects or JDBC rows it has already processed, so re-running the job only processes new data since the last run. No watermark logic to write yourself.

**Glue Studio** is a visual drag-and-drop editor that generates PySpark code. Useful for simple transformations; for complex joins or custom logic, write the script directly.

> [!warning] Glue job startup time is 2–3 minutes for the Spark cluster to initialize. For sub-minute latency needs, Glue ETL is the wrong tool — use Lambda or Kinesis Data Analytics instead.

@feynman

Glue ETL is like a managed Spark cluster that you rent by the minute — you write the job, AWS finds the machines, runs it, and bills you when it's done.

@card
id: aws-ch11-c003
order: 3
title: Amazon Athena — Serverless SQL on S3
teaser: Athena lets you run SQL against files in S3 with no database to manage — you pay $5 per terabyte scanned, which means the query you write directly determines your bill.

@explanation

Athena is an interactive query service built on Presto (now Trino). You point it at data in S3, define a table schema in the Glue Data Catalog, and run standard SQL. There are no clusters to provision, no indexes to build, no storage to manage. You pay $5 per TB of data scanned by your query.

Because cost scales with bytes scanned, two optimizations deliver 30–90% savings in practice:

- **Columnar formats** (Parquet or ORC) — Athena reads only the columns your query references. A table with 100 columns where you SELECT 3 reads roughly 3% of the raw data compared to CSV. Converting a CSV dataset to Parquet before querying typically cuts Athena costs by 60–70%.
- **Partitioning** — organizing S3 data by a partition key (e.g., `year=2024/month=05/day=03/`) allows Athena to skip entire prefixes. A query with `WHERE month = '05'` never touches the other 11 months. **Partition projection** takes this further: you define the partition scheme in table properties and Athena infers partition paths algorithmically, eliminating the `MSCK REPAIR TABLE` step that adds minutes to partition discovery.

**Federated queries** extend Athena beyond S3. Athena connectors (Lambda-backed) let you JOIN between an S3 dataset and live data in DynamoDB, RDS, Redshift, or even custom JDBC sources in a single SQL statement.

Athena is the right choice for ad-hoc analytics on data you already store in S3. It's the wrong choice for sub-second dashboards (use Redshift or OpenSearch) or for data not in S3.

> [!tip] Always check your query's estimated bytes scanned in the Athena console before running on large tables. A missing partition filter on a petabyte table is a hundred-dollar mistake.

@feynman

Athena is like a pay-per-page printer for your data — the query is the print job, and compressing your data into columnar format means you print fewer pages and pay less.

@card
id: aws-ch11-c004
order: 4
title: Amazon Kinesis Data Streams
teaser: Kinesis Data Streams is AWS's low-latency data streaming service — the shard is the capacity unit, and understanding shard math is what separates a pipeline that works from one that throttles under load.

@explanation

Kinesis Data Streams ingests real-time data (logs, clickstreams, IoT telemetry) and makes it available for multiple consumers within milliseconds. The fundamental capacity unit is the **shard**:

- **Ingest:** 1 MB/s or 1,000 records/s per shard.
- **Consume:** 2 MB/s per shard (shared across all standard consumers).

Sizing is arithmetic: if your producers generate 5 MB/s, you need at least 5 shards. If you have 3 consumers each reading at 2 MB/s from a single-shard stream, you'll be throttled — total read capacity is 2 MB/s, shared.

**Enhanced fan-out** solves the shared-throughput problem. Each enhanced fan-out consumer gets its own dedicated 2 MB/s per shard via a push model over HTTP/2. You can have up to 20 enhanced fan-out consumers per stream; the additional cost is ~$0.015 per shard-hour plus $0.013 per GB delivered.

**Shard splitting and merging** scale capacity up and down. Splitting one shard into two doubles capacity at that shard; merging two adjacent shards halves it. The operation takes a few seconds but old shards remain readable until their data expires — there's no data loss.

**Retention** is configurable from 24 hours (default) to 365 days. Extended retention costs $0.020 per shard-hour beyond the first 24 hours. This replay capability distinguishes Kinesis (and Kafka) from SQS, which deletes messages after consumption.

> [!info] You can't merge non-adjacent shards. Kinesis tracks shard adjacency in its partition key hash space, so only shards with contiguous hash ranges can be merged.

@feynman

A Kinesis shard is like a highway lane — each lane has a fixed throughput, you add lanes when traffic grows, and every car that passes through is preserved in a toll record for up to a year.

@card
id: aws-ch11-c005
order: 5
title: Amazon Kinesis Data Firehose
teaser: Firehose is the no-shards, no-consumer-code path to loading streaming data into S3, Redshift, or OpenSearch — you configure a destination and a buffer, and Firehose handles the rest.

@explanation

Kinesis Data Firehose (now branded Amazon Data Firehose) is a fully managed delivery stream. Unlike Kinesis Data Streams, there are no shards to size, no consumer code to write, and no checkpointing to manage. You point producers at a Firehose delivery stream, configure a destination, and Firehose batches and delivers the data automatically.

Supported destinations:

- **Amazon S3** — the most common target. Firehose writes Gzip-compressed files.
- **Amazon Redshift** — Firehose lands data in S3 first, then issues a COPY command to load into Redshift.
- **Amazon OpenSearch Service** — streams records directly into an OpenSearch index.
- **HTTP endpoint** — any HTTPS endpoint, including Splunk, Datadog, and custom receivers.

**Buffering hints** control when Firehose flushes data to the destination: by size (up to 128 MB) or by time interval (60 seconds to 900 seconds). The 60-second minimum is why Firehose is described as "near-real-time" rather than real-time — there's an inherent latency floor. For sub-second delivery, use Kinesis Data Streams with a custom consumer.

**Built-in format conversion** is one of Firehose's strongest features: it can transform JSON records to Parquet or ORC using the Glue Data Catalog schema, with no Lambda function required. This makes S3 output immediately queryable by Athena at columnar-format cost savings.

Firehose also supports optional Lambda-based record transformation (for filtering, enrichment, or format changes) applied before buffering.

> [!warning] Firehose does not support replay. Once data is delivered to S3 or Redshift, it's gone from the stream. If you need replay or multiple independent consumers, use Kinesis Data Streams as the upstream source.

@feynman

Firehose is the managed loading dock between your stream and your warehouse — data arrives, Firehose sorts and stacks it into the destination on a schedule, and you never touch the forklift.

@card
id: aws-ch11-c006
order: 6
title: Amazon MSK — Managed Kafka
teaser: MSK runs Apache Kafka on AWS without you managing brokers — choose it over Kinesis when you need Kafka protocol compatibility, topic replay, or complex consumer group management.

@explanation

Amazon MSK (Managed Streaming for Apache Kafka) is a managed service that provisions, patches, and monitors Apache Kafka brokers. You get standard Kafka APIs — producers, consumers, Kafka Streams, Kafka Connect — without operating the broker fleet yourself.

MSK comes in two deployment modes:

- **MSK Provisioned** — you choose broker instance types (e.g., `kafka.m5.large`, `kafka.m5.4xlarge`) and storage. You control partition count, replication factor, and retention. You pay per broker-hour and per GB stored.
- **MSK Serverless** — capacity auto-scales with throughput. You pay per cluster-hour plus throughput consumed. No broker sizing required. Limits apply: max 200 MB/s ingress per cluster.

**MSK Connect** manages Kafka Connect workers — the connectors that move data between Kafka and external systems (S3, RDS, DynamoDB, Elasticsearch). You deploy connector plugins and MSK Connect handles worker scaling and fault recovery.

When MSK beats Kinesis:

- You're migrating a self-managed Kafka cluster and need protocol compatibility without rewriting producers/consumers.
- You need topic replay with configurable offsets (Kafka's consumer group offset management is more flexible than Kinesis shard iterators).
- You need complex consumer group semantics — multiple consumer groups at different offsets on the same topic, consumer lag metrics per group.
- You use Kafka Streams, ksqlDB, or other Kafka-ecosystem tools that expect native Kafka APIs.

When Kinesis beats MSK: you want a fully managed, no-Kafka-expertise-required stream where AWS handles everything, and you don't need Kafka ecosystem compatibility.

> [!tip] MSK Serverless has a hard throughput ceiling. If your workload spikes above 200 MB/s ingress, you'll need MSK Provisioned — over-provision brokers and monitor `BytesInPerSec` to stay ahead.

@feynman

MSK is like getting a fully managed PostgreSQL service when you've already built your app against Postgres — you keep all your tooling and queries, AWS just removes the server operations.

@card
id: aws-ch11-c007
order: 7
title: AWS Lake Formation
teaser: Lake Formation adds a fine-grained permissions layer over your S3 data lake — instead of managing a maze of S3 bucket policies and IAM roles, you grant table, column, and row access through one central control plane.

@explanation

Lake Formation sits on top of S3 and the Glue Data Catalog. It doesn't store data — it controls access to data that is already registered in the Catalog and stored in S3. When an Athena query or Redshift Spectrum job reads a Catalog table, Lake Formation intercepts the request and enforces its permissions before returning any data.

Lake Formation adds two access control capabilities that S3 bucket policies cannot provide:

- **Column-level security** — grant a user access to a table but restrict specific columns. A query that SELECT * will silently omit restricted columns; a query that explicitly references a restricted column is denied.
- **Row-level security** — data filters define a WHERE condition attached to a principal. A user with a row filter for `region = 'us-east-1'` only ever sees rows matching that condition, even if the underlying S3 data contains all regions.

The Lake Formation permission model works via LF-tags (tag-based access control) or direct resource-level grants. LF-tags scale better for large catalogs — tag databases and tables with environment, classification, or team labels, then grant access to tag combinations rather than individual resources.

The tradeoff versus pure S3 bucket policies: S3 policies are evaluated before Lake Formation. Lake Formation cannot grant more access than S3 allows. In practice, you give a Lake Formation service role broad S3 access, and use Lake Formation exclusively for fine-grained control — mixing the two models creates hard-to-debug permission conflicts.

> [!warning] Lake Formation and S3 bucket policies interact in ways that can produce unexpected denials. If a principal passes Lake Formation checks but still gets "Access Denied," the S3 bucket policy is usually the culprit. Audit both layers together.

@feynman

Lake Formation is the security desk at the data lake entrance — the data is still in S3, but nobody gets to a specific table, column, or row without Lake Formation checking their badge first.

@card
id: aws-ch11-c008
order: 8
title: Amazon OpenSearch Service
teaser: OpenSearch Service is managed OpenSearch (the Elasticsearch fork) — use it for log analytics, full-text search, and observability dashboards where sub-second query latency on indexed data matters more than cost per query.

@explanation

Amazon OpenSearch Service provisions and manages OpenSearch clusters (and the older Elasticsearch API-compatible versions). You choose domain sizing — instance type, instance count, storage per node — and AWS handles OS patching, backups, and multi-AZ replication.

Core use cases where OpenSearch wins:

- **Log analytics** — ingest application and infrastructure logs, search and aggregate in milliseconds. Kibana / OpenSearch Dashboards provide visualization out of the box.
- **Full-text search** — search across unstructured text with relevance scoring, fuzzy matching, and faceted filtering that SQL cannot express naturally.
- **Observability** — metrics, traces, and logs in one service. OpenSearch Observability integrates with AWS X-Ray and CloudWatch.

**UltraWarm** is OpenSearch's warm storage tier: it stores older, less-queried index data in S3 with a small cache layer in front, at roughly 90% lower cost than hot storage nodes. Query latency on UltraWarm data is higher (seconds vs milliseconds), so it suits historical data accessed occasionally. The standard lifecycle is: hot node (recent data, fast) → UltraWarm (older data, cheaper) → cold storage (archive, S3-priced) → delete.

Compared to self-managed OpenSearch: AWS handles node replacement on failure, rolling upgrades during version updates, and automated snapshots. You give up some configuration flexibility (cluster settings, JVM tuning) but eliminate the operational overhead of running an Elasticsearch/OpenSearch cluster at scale.

OpenSearch Service is not the right choice for ad-hoc SQL analytics over structured S3 data — that's Athena's domain. OpenSearch shines when you need free-text search or sub-second aggregations on data you've loaded into its index.

> [!info] OpenSearch index storage costs ~$0.135/GB-month for hot nodes (gp3). UltraWarm drops this to ~$0.024/GB-month. For log data you keep 90 days and only query the last 7, moving day-8-through-90 to UltraWarm can cut storage costs by 80%.

@feynman

OpenSearch is the search index you build on top of your data lake — the raw logs stay in S3, but OpenSearch is the inverted index that makes "find all errors from service X in the last hour" return in 50 milliseconds instead of 50 seconds.

@card
id: aws-ch11-c009
order: 9
title: Amazon EMR — Managed Hadoop Ecosystem
teaser: EMR runs the full Hadoop ecosystem on managed clusters — it's the right choice when your Spark job is too large, too specialized, or too tightly integrated with the Hadoop ecosystem for Glue ETL to handle.

@explanation

Amazon EMR provisions clusters running Apache Spark, Hive, HBase, Presto, Flink, and the broader Hadoop ecosystem. You choose the applications to install at cluster creation; AWS provisions the EC2 instances, installs the software, and handles bootstrapping.

Three deployment modes:

- **EMR on EC2** — traditional master/core/task node model. Full control over instance types, bootstrap actions, cluster config, and long-running vs transient clusters. Use spot instances for task nodes to cut costs by 60–80%.
- **EMR Serverless** — no cluster to provision; you submit a job, AWS finds the capacity, and you pay only for what the job uses. Eliminates idle cluster cost for workloads with irregular run schedules. Cold start adds ~1 minute.
- **EMR on EKS** — submit Spark jobs to a Kubernetes cluster. Use when your organization already operates EKS and wants unified infrastructure management.

**Spot instance strategy for cost:** run master and core nodes on on-demand (data durability requires stable core nodes), run task nodes on spot. A task node failure causes a task retry, not data loss. Spot pricing for task nodes commonly achieves 70% savings versus on-demand.

**EMR Studio** provides a managed Jupyter notebook environment connected to the cluster — useful for interactive Spark development and data exploration without SSH.

EMR beats Glue ETL when: your Spark job exceeds what Glue's worker types can handle (e.g., 500+ nodes), you need Hadoop ecosystem components Glue doesn't support (HBase, custom YARN configurations), you want fine-grained Spark configuration control, or you're running workloads that benefit from long-running cluster warm caches (Presto on large catalogs).

Glue beats EMR when: you want serverless Spark with no cluster management, your job fits in a few G.2X workers, and you want Glue Catalog integration without additional configuration.

> [!tip] For transient clusters (one job, then terminate), always use the latest EMR release version — it patches vulnerabilities and improves Spark performance. Pinning to an old version on a long-running cluster trades security for stability; document that tradeoff explicitly.

@feynman

EMR is the full professional kitchen — every appliance, full control over every burner — while Glue ETL is the meal kit service that handles setup and cleanup but only gives you the ingredients and tools the kit includes.

@card
id: aws-ch11-c010
order: 10
title: Analytics Architecture Patterns on AWS
teaser: S3 is the foundation of every AWS analytics architecture — how you layer Glue, Athena, Kinesis, and Lake Formation on top of it depends on whether your workload is batch, streaming, or both.

@explanation

Three patterns cover the majority of AWS analytics architectures:

**S3-based lakehouse** — the baseline for batch analytics. S3 stores all data in open formats (Parquet, ORC). The Glue Data Catalog defines schemas. Athena runs SQL queries. Lake Formation enforces column- and row-level access. This pattern costs nearly nothing at rest ($0.023/GB-month for S3 Standard) and scales to petabytes without provisioning storage. Add Redshift Spectrum when you need consistent sub-second SQL performance for dashboards, since Athena latency varies with data scanned.

**Lambda architecture** — combines a speed layer and a batch layer. Kinesis Data Streams captures real-time events; a speed layer (Lambda, Kinesis Data Analytics, or Flink on EMR) processes events with low latency and writes to a serving store (DynamoDB, OpenSearch, or a hot tier). Simultaneously, Kinesis Data Firehose (or a Glue job) writes the same events to S3 for the batch layer. Downstream queries merge both layers. The cost: complexity. Two code paths means two things to maintain.

**Medallion architecture** — organizes S3 into three tiers. Bronze: raw ingest, unchanged from source (landing zone). Silver: cleaned, deduplicated, type-corrected, partitioned. Gold: aggregated, business-logic-applied, query-optimized. Glue ETL jobs promote data between tiers. Athena and Redshift Spectrum query gold (and sometimes silver) directly. Each tier has its own Glue Catalog database. This makes data quality failures visible and recoverable — a bad silver job doesn't corrupt the bronze data you can reprocess from.

**Kinesis vs MSK** selection rule: start with Kinesis if you're AWS-native and don't need Kafka APIs. Move to MSK if you're migrating from Kafka, need Kafka Connect workers via MSK Connect, or require consumer group offset flexibility beyond what Kinesis provides.

> [!info] The lakehouse pattern is the right default starting point for most new analytics workloads on AWS. Add streaming and Lambda architecture only when you have a concrete latency requirement that batch processing cannot meet — streaming adds operational complexity that should earn its place.

@feynman

These patterns are like network topologies — the right one depends on the latency and throughput requirements of your workload, and starting with the simplest one that meets your SLA is always cheaper than over-engineering from day one.
