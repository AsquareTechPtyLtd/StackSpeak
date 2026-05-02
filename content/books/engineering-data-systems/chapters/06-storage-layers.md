@chapter
id: eds-ch06-storage-layers
order: 6
title: Storage Layers
summary: The substrate every other lifecycle stage acts on — formats, systems, abstractions, and the cost-and-shape decisions that ripple everywhere downstream.

@card
id: eds-ch06-c001
order: 1
title: Storage Is The Substrate
teaser: Other lifecycle stages are verbs; storage is the noun underneath all of them. Picking storage well is the highest-leverage architectural decision you'll make.

@explanation

Every other stage is something you do *to* storage — ingestion writes to it, transformation reads-and-writes it, serving reads from it. Storage shapes:

- **What's possible to query.** Columnar warehouses make analytical queries fast that would take hours on row stores.
- **What's affordable.** Storing petabytes in a warehouse vs in object storage differs by 10× in cost.
- **What can be evolved.** Schema changes in some stores are migrations; in others they're metadata operations.
- **What can be queried in parallel.** Distributed storage scales reads; single-node doesn't.

A pipeline running on the wrong storage shape will struggle at every stage. A pipeline on the right storage shape feels almost too easy.

The data engineer's job is matching storage shape to access pattern at every layer of the stack — and accepting that "one storage system for everything" is rarely the right answer at scale.

> [!info] When debugging slow pipelines, the storage layer is the first place to look. Most performance problems trace back to a mismatch between how data is stored and how it's queried.

@feynman

Same role as memory hierarchy in a CPU — the speed and shape of the underlying medium shapes everything that runs on top.

@card
id: eds-ch06-c002
order: 2
title: Raw Materials — Disk, Memory, Network
teaser: All storage abstractions ultimately ride on physical hardware with very different speeds, costs, and access shapes. Knowing the underlying primitives clarifies the trade-offs above.

@explanation

The physical layer:

- **Memory (RAM)** — nanosecond access, gigabytes capacity, expensive per byte, lost on power off.
- **NVMe SSD** — microsecond access, terabytes capacity, moderate cost, persistent.
- **HDD** — millisecond access, terabytes-cheap, large capacity, persistent.
- **Network storage (S3, etc.)** — tens of milliseconds access, effectively unlimited capacity, very cheap, persistent and durable.

Each is six orders of magnitude apart in speed. Pricing inverts the order — RAM costs 100-1000× more per GB than HDD; HDD costs 5-10× more than object storage.

The implication for data systems: **stored data wants to live cheaply; queried data wants to be near the compute**. Storage tiers move data toward cheaper media as it cools off (rarely accessed → archive tier on S3 Glacier).

Modern warehouses (Snowflake, BigQuery) are essentially fancy abstractions that put hot data in fast tiers and cold data in slow tiers automatically — and bill you for the journey.

> [!info] When a query is slow, ask "where does the data physically live?" before tuning the query. Sometimes the right fix is moving the data, not changing the SQL.

@feynman

Same hierarchy idea as caches in a CPU — L1 to L2 to L3 to RAM to disk, six orders of magnitude across the stack.

@card
id: eds-ch06-c003
order: 3
title: Object Storage — The Substrate Of The Modern Data Lake
teaser: S3 and its peers are now the default place to land raw data. Cheap, durable, infinitely scalable, and the foundation of most modern data architectures.

@explanation

Object storage (S3, GCS, Azure Blob) is the most important data infrastructure of the past decade. The defining properties:

- **Practically unlimited capacity** — one bucket can hold petabytes.
- **High durability** — 11 nines for S3 means you essentially won't lose data.
- **Cheap** — pennies per GB-month, with cheaper tiers for cold data.
- **HTTP-accessible** — every tool and framework supports it.
- **Eventual consistency** — used to be the gotcha; mostly resolved as of S3's strong consistency in 2020.

What it gave us:

- **The data lake** — store everything cheaply and figure out structure later.
- **Decoupled storage and compute** — different engines (Spark, Presto, Trino, warehouses) can read the same files.
- **Open table formats** — Iceberg, Delta, Hudi turn object storage into something with warehouse-like semantics.

What it costs:

- **API costs** — every PUT/GET is metered; lots of small files create surprise bills.
- **Latency** — tens of milliseconds per request; not a substitute for an OLTP database.
- **Listing operations** — listing a bucket with millions of objects is slow.

> [!tip] When designing object-storage layouts, partition by query pattern. Date-partitioned files (`year=2026/month=05/day=02/`) let queries skip directories instead of scanning everything.

@feynman

Same role as Linux's filesystem in a hosted-service form — the universal substrate every other tool can read and write.

@card
id: eds-ch06-c004
order: 4
title: Row Storage Versus Column Storage
teaser: Two fundamentally different ways to physically arrange data. Row stores favor transactional access; column stores favor analytical queries. The wrong choice tanks performance.

@explanation

**Row storage.** All values for a single row live together on disk. Reading row 47's email means reading row 47's entire record. Optimal when you read whole rows: OLTP databases (Postgres, MySQL) put one row's worth of data per record.

**Column storage.** All values for a single column live together. Reading the email column means reading just that column's contiguous bytes for many rows. Optimal when you scan many rows but few columns: analytical queries (`SELECT email FROM users WHERE ...`).

The implications:

- **Compression** — column storage compresses dramatically better. A column of repeated countries (US, US, US, UK, US) compresses to almost nothing; the row form interleaves countries with ages and emails.
- **Scan cost** — analytical queries on column storage scan only the columns they need. Row storage reads everything.
- **Write performance** — row storage handles single-row inserts cleanly. Column storage prefers batch writes; per-row inserts are inefficient.

The split:

- **Operational systems** → row storage (Postgres, MySQL, Mongo).
- **Analytical systems** → column storage (Snowflake, BigQuery, Redshift, ClickHouse).

This is one reason transactional databases make poor analytical engines, and vice versa.

> [!info] If your "warehouse" is built on a row store and queries scan whole tables, you have an architecture mismatch. The fix is migrating to a columnar engine, not tuning the queries.

@feynman

Same idea as struct-of-arrays vs array-of-structs in low-level programming — choose the layout that matches how you'll iterate.

@card
id: eds-ch06-c005
order: 5
title: File Formats — Parquet, ORC, Avro, Delta
teaser: How data is encoded on disk matters as much as where it sits. Modern formats are the difference between fast queries and pipelines that crawl.

@explanation

The major formats and their roles:

- **CSV** — text-based, universal, slow, no schema. Use for human-readable export and not much else.
- **JSON / JSONL** — text-based, schemaless, easy to debug, expensive to query. Common for API output and event streams.
- **Avro** — row-based binary, schema-embedded, good for streaming sources where each record is processed individually. Used heavily with Kafka.
- **Parquet** — column-based binary, best-in-class compression, the default for analytical workloads. Read by every major engine.
- **ORC** — columnar, similar to Parquet, popular in Hive/Hadoop ecosystems.
- **Delta / Iceberg / Hudi** — *table formats* on top of Parquet that add ACID, schema evolution, time travel.

The hierarchy in 2026:

- **Streaming** → Avro for the event payload, Parquet for derived analytical tables.
- **Lake landing zone** → Parquet for analytical workloads; original format (often JSON) for replayability.
- **Warehouse-style tables on a lake** → Iceberg or Delta as the table format wrapping Parquet.
- **Operational systems** → whatever the database uses internally; not your concern.

> [!warning] If you're still landing CSV in your data lake in 2026, your queries are 5-10× slower than they could be and you're paying for it on every scan.

@feynman

Same idea as choosing between MP3 and WAV — both store audio, one's an order of magnitude smaller for the same content.

@card
id: eds-ch06-c006
order: 6
title: Compression — Free Speed, Mostly
teaser: Most modern formats compress data heavily before writing. Right compression choice means smaller storage bills and faster scans.

@explanation

Compression buys you two things in data systems: smaller storage cost and less data to scan (which means faster queries). Common algorithms:

- **Snappy** — fast compress/decompress, moderate ratio. Default for many engines because it's fast enough that decompression doesn't slow queries.
- **Gzip / Zlib** — slow compress, good ratio. Common for archive data, less common for hot tables.
- **LZ4** — extremely fast, modest ratio. Good when CPU is the bottleneck.
- **Zstd** — newer, tunable compression level, often the best modern default. Good ratio at high speed.
- **Brotli** — high ratio, slow compress. Good for cold archive data.

Plus columnar-specific encodings within the format:

- **Run-length encoding** — `[US, US, US, US, UK]` becomes `[(US, 4), (UK, 1)]`. Massive savings on low-cardinality columns.
- **Dictionary encoding** — replace string values with integer IDs into a dictionary. Country codes, status enums, anything with finite cardinality.
- **Bit packing** — store small integers in fewer bits than a full int.

You don't usually pick these manually — Parquet writers choose per-column. But understanding what's happening explains why a 10TB raw dataset becomes a 200GB Parquet table.

> [!info] Compression ratio of 50× is normal on well-shaped analytical data. If your Parquet files are barely smaller than the source CSV, something's wrong with your encoding.

@feynman

Same magic as gzipping log files — ten lines that all start with `INFO 2026-05-02` compress almost to nothing.

@card
id: eds-ch06-c007
order: 7
title: Open Table Formats — The Lakehouse Pattern
teaser: Iceberg, Delta, and Hudi turn directories of Parquet files into something with warehouse semantics: ACID, schema evolution, time travel, snapshot isolation.

@explanation

The problem they solve: a directory of Parquet files in S3 is a great storage primitive but a terrible *table*. You can't safely append or update without race conditions. Schema changes are coordinated by hand. There's no concept of a "current version" of the table.

Open table formats add a metadata layer that manages all of this:

- **ACID transactions** — multiple writers can append safely; readers see consistent snapshots.
- **Schema evolution** — add, drop, rename, change-type columns without rewriting all the files.
- **Time travel** — query the table as of a previous snapshot. Roll back if a bad write happens.
- **Hidden partitioning** — partitioning is metadata; you can change partition layout without rewriting data.
- **Compaction** — merge small files into larger ones in the background.

The three players:

- **Apache Iceberg** — Netflix-originated, vendor-neutral, the broadest engine support.
- **Delta Lake** — Databricks-originated, recently open-sourced, deep Spark integration.
- **Apache Hudi** — Uber-originated, good at streaming-style upserts and CDC ingestion.

The lakehouse pattern (Databricks coined it; Iceberg + warehouses now embody it) is converging warehouse and lake into one architecture: cheap object storage, open formats, multiple engines reading the same tables.

> [!info] If you're starting fresh in 2026, Iceberg or Delta on object storage is the safest forward-looking bet. The path from there to either a warehouse or pure lake compute is well-trodden.

@feynman

Same arc as filesystems — POSIX gave us shared semantics over raw disks; table formats give us shared semantics over object storage.

@card
id: eds-ch06-c008
order: 8
title: Cloud Warehouses — Managed Analytical Databases
teaser: Snowflake, BigQuery, Redshift, Databricks SQL — purpose-built for analytical queries at scale, with the operational burden taken off your team.

@explanation

Cloud warehouses are the dominant analytical storage choice. The defining capabilities:

- **Columnar storage** internally, optimized for scan-heavy queries.
- **Massively parallel processing** — queries fan out across many nodes.
- **Decoupled storage and compute** — independent scaling of each. Warm storage in the warehouse vendor's storage; spin up compute clusters as needed.
- **SQL interface** — every analyst tool can query without custom drivers.
- **Managed everything** — backups, replication, security, scaling all handled.

The major options:

- **Snowflake** — vendor-neutral, multi-cloud, great UX, premium pricing.
- **BigQuery** — Google's offering, serverless model, strong ML integration.
- **Redshift** — AWS's, deeply integrated with the AWS ecosystem, cluster-management can be operational work.
- **Databricks SQL** — built on top of the Databricks platform, integrates closely with Spark and Delta.
- **Synapse / Fabric** — Microsoft's offering, deep Azure integration.

The trade-off: you get a tremendous amount of capability for the operational cost of zero (no clusters to manage). The bill grows with usage; the lock-in is real (proprietary SQL extensions, native data types). Most teams accept the trade-off because the alternative is operating Spark or Trino themselves.

> [!info] Warehouses' biggest cost driver is usually compute on poorly-optimized queries. Spend time on partitioning, clustering, and query tuning before adding more compute.

@feynman

Same shape as managed Postgres vs running your own — pay more for the service, save the operational time.

@card
id: eds-ch06-c009
order: 9
title: Data Lakes — Flexible But Demanding
teaser: A data lake is what you get when you put raw data on object storage and decide what shape it should take later. Cheap, flexible, and easy to turn into a swamp if no one's tending it.

@explanation

A data lake is less a product and more a pattern: object storage holding raw data, compute engines (Spark, Presto, Trino) reading it. The wins:

- **Cheap** — object storage costs almost nothing per TB.
- **Format flexibility** — anything from CSV to images to JSON to Parquet.
- **Decoupled compute** — different teams can use different engines on the same data.
- **Scales to anything** — petabytes of training data, raw event streams, regulatory archives.

The losses (without discipline):

- **Discoverability** — what data exists where? Catalogs become essential.
- **Quality** — no schema enforcement means anything can land; consumers waste time validating.
- **Governance** — who has access to what? Permissions on raw object storage are coarse.
- **Performance** — without partitioning and good formats, queries scan terabytes for trivial results.

The "data swamp" anti-pattern: a lake that grew without discipline, where finding the right dataset takes longer than recreating it from scratch.

What turns a lake into a useful asset:

- **Layered architecture** — bronze (raw), silver (cleaned), gold (curated) layers with progressive refinement.
- **Open table formats** — Iceberg or Delta to add structure.
- **Metadata layer** — a catalog (Glue, Unity Catalog, Polaris) tracking what's where.
- **Access controls** — fine-grained permissions, not just bucket-level.

> [!warning] "We have a data lake" too often means "we have a few hundred TB of files no one understands." Lakes need governance and curation to be useful, not just storage.

@feynman

Same as a hard drive shared by a team without folders — works briefly, then nobody can find anything.

@card
id: eds-ch06-c010
order: 10
title: The Lakehouse Convergence
teaser: Lakes are gaining warehouse features. Warehouses are gaining lake features. The line between them keeps blurring, and most modern stacks blend both.

@explanation

For years, lakes and warehouses had clear roles. Lakes were cheap raw storage; warehouses were expensive analytics-optimized engines. The gap is closing fast:

**From the lake side, gaining warehouse features:**
- Iceberg / Delta tables with ACID, schema evolution, time travel.
- High-performance query engines (Trino, Presto, Spark SQL, DuckDB) that scan lake-format files efficiently.
- Catalogs and governance layers (Unity Catalog, Polaris) that match warehouse-style metadata.

**From the warehouse side, gaining lake features:**
- Snowflake's external tables and Iceberg support.
- BigQuery's BigLake reading lake-format files directly.
- Databricks SQL serving Delta Lake tables.

The convergence point — the lakehouse — combines:

- Object storage as the physical substrate (cheap, scalable).
- Open table formats (portable, ACID, evolvable).
- Multiple compute engines (analytical SQL, ML training, batch processing).
- A unified governance layer.

The practical implication: in 2026 you can often pick a single architecture (lakehouse) instead of running both a lake and a warehouse. Whether to do so depends on your specific access patterns and team skills.

> [!info] If your warehouse spend is dominated by storage and your lake is mostly serving warehouse-style queries, you have two architectures doing one job. Consolidating saves money and operational complexity.

@feynman

Same as Linux desktop and macOS converging on similar UX — different starting points, same end-state pressures.

@card
id: eds-ch06-c011
order: 11
title: OLTP, OLAP, And When To Use Each
teaser: Two acronyms that draw the most important boundary in data system design: transactional vs analytical workloads.

@explanation

**OLTP — Online Transaction Processing.** Optimized for many small, low-latency reads and writes. Application databases. Postgres, MySQL, MongoDB, DynamoDB. Workload shape: "read this user's profile," "insert this order," "update this inventory count." Latency target: single-digit milliseconds.

**OLAP — Online Analytical Processing.** Optimized for fewer large reads that scan and aggregate. Data warehouses, lakes. Snowflake, BigQuery, Spark, ClickHouse. Workload shape: "show me total revenue by country by month for the last year." Latency target: seconds to minutes is fine.

The contrast in physical design:

- **Storage** — OLTP row-based; OLAP column-based.
- **Latency** — OLTP milliseconds; OLAP seconds to minutes.
- **Concurrency** — OLTP high (thousands of small queries); OLAP lower (tens of large queries).
- **Updates** — OLTP in-place; OLAP append or recompute.
- **Indexing** — OLTP primary + many secondaries; OLAP sort/cluster keys.
- **Joins** — OLTP few rows via indexed lookups; OLAP many rows via hash or merge joins.

The error to avoid: running analytical queries against your OLTP database, or building user-facing applications on a warehouse. Each is fine for what it's designed for; both are bad at the other's job.

> [!info] HTAP ("hybrid") systems exist (TiDB, SingleStore, CockroachDB with analytics extensions) but the OLTP/OLAP split remains the cleanest mental model. Most teams run separate systems and ETL between them.

@feynman

Same as splitting hot-path code from batch jobs — different optimization targets, different physical layouts.

@card
id: eds-ch06-c012
order: 12
title: Specialized Stores — Time Series, Vector, Search
teaser: Beyond OLTP and OLAP, several specialized storage types serve specific workloads better than either generalist would.

@explanation

When workload patterns get specialized, specialized stores often beat the generalists:

- **Time-series databases** (InfluxDB, Prometheus, TimescaleDB) — optimized for high-volume time-stamped data with downsampling, retention, range queries. Used for metrics, telemetry, IoT.
- **Search engines** (Elasticsearch, OpenSearch, Solr) — full-text indexing and ranked retrieval. Logs, product search, knowledge bases.
- **Vector databases** (Pinecone, Weaviate, pgvector) — similarity search over high-dimensional embeddings. The default for RAG and recommendation use cases.
- **Graph databases** (Neo4j, JanusGraph) — relationships are first-class; traversal queries that would join 10 tables in SQL are native operations.
- **Key-value stores** (Redis, DynamoDB, Cassandra) — millisecond reads on a primary key, often used as serving caches.
- **Document stores** (MongoDB, Couchbase, Firestore) — schemaless JSON-style storage with flexible querying.

The decision: if your access pattern matches a specialized store's sweet spot by 10×, run it. If your access is mostly mixed, generalists (Postgres for OLTP, a warehouse for OLAP) are usually simpler.

> [!warning] Each specialized store you add is a new operational burden — backups, monitoring, scaling, security. Adopt only when the access-pattern win clearly justifies the cost.

@feynman

Same trade-off as picking specialized hardware (GPU, TPU) vs CPU — beats the generalist on its sweet spot, costs more in operational complexity.

@card
id: eds-ch06-c013
order: 13
title: Storage Tiering — Hot, Warm, Cold
teaser: Most data gets accessed once and never again. Tiering moves cold data to cheap storage automatically, cutting bills by 5-10× without affecting fresh queries.

@explanation

Data has a temperature curve. Today's data gets hammered; last year's data gets queried occasionally; data from five years ago is mostly archive. Storage tiers exploit this:

- **Hot** — fast, expensive. Recent data, frequently queried. Cloud SSDs, in-warehouse storage.
- **Warm** — slower, cheaper. Data accessed monthly. Standard object storage tiers.
- **Cold** — slowest, cheapest. Archive data, regulatory holds. S3 Glacier, Azure Archive.
- **Frozen** — tape-equivalent. Multi-year retention you might never read. Deep Archive tiers.

Per-GB-month cost ratios (rough): hot 1×, warm 0.5×, cold 0.05×, frozen 0.01×.

How to use tiering:

- **Lifecycle policies on object storage** — move objects to cheaper tiers automatically based on age.
- **Warehouse external tables** — keep cold data on object storage; query it occasionally without paying warehouse storage rates.
- **Partitioned tables** — drop or archive old partitions on a schedule.

The retrieval cost: cold-tier reads are cheap per GB but have higher latency and per-request fees. Reading a single object back from Glacier can take hours. Plan tiering with retrieval needs in mind.

> [!tip] If your warehouse storage bill is large, ten minutes with the access pattern report (which tables are scanned monthly vs. weekly vs. daily) usually identifies cold candidates.

@feynman

Same as the cache hierarchy — keep hot bytes in the expensive layer, push cold bytes down to cheap layers, profit on the average.

@card
id: eds-ch06-c014
order: 14
title: Storage Costs Are Architectural, Not Just Operational
teaser: How you structure storage drives a huge fraction of cloud data spend. Architectural decisions made early determine whether your storage bill is reasonable or alarming.

@explanation

Architectural decisions that drive storage cost:

- **Format** — Parquet vs CSV is 5-10× compression. JSON vs Parquet is similar.
- **Partitioning** — well-partitioned data lets queries skip 99% of files. Poorly-partitioned data forces full scans.
- **Retention policies** — keep data forever and storage compounds. Aggressive retention windows cap the growth.
- **Duplication** — copying the same data into a lake, a warehouse, and a feature store triples the bill.
- **Replication** — multi-region storage doubles or triples bills; sometimes necessary, often default-on without need.
- **Small files** — many small Parquet files bill for every PUT and slow down queries; periodic compaction is essential.

Patterns that keep storage costs sane:

- **Single source of truth** — raw lands once; downstream consumers read from there or from layered derivatives.
- **Active retention management** — every dataset has a documented retention; automated policies enforce it.
- **Format discipline** — everything analytical lands as Parquet (or in a table format). No raw JSON sitting in the warehouse.
- **Compaction jobs** — small files get merged into 100MB+ chunks regularly.
- **Partition pruning** — queries that touch one day shouldn't scan all-time data.

> [!info] Storage costs grow with O(time × volume × replication). Each multiplier is something you can dial. Cost shock usually means at least one is on a default you didn't choose.

@feynman

Same idea as software complexity — small architectural decisions early compound into either a manageable system or a permanent tax.
