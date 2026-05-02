@chapter
id: tde-ch02-data-storage-and-formats
order: 2
title: Data Storage and Formats
summary: The format you choose for your data is not a detail — it determines query speed, storage cost, write throughput, schema evolution options, and whether your downstream tools can read it at all.

@card
id: tde-ch02-c001
order: 1
title: Row vs Columnar Storage
teaser: The layout of data on disk determines what queries run fast — and mixing up OLTP and OLAP storage models is one of the most common and expensive mistakes in data engineering.

@explanation

Row-oriented storage writes each record as a contiguous sequence of column values on disk. When you fetch a row, you get everything about that entity in one read. That's ideal for transactional workloads: Postgres and MySQL are row stores because typical application queries say "give me all fields for user 42" — the read is narrow in rows, wide in columns.

Columnar storage writes all values for a single column together. When you run `SELECT revenue, region FROM orders` across 200 million rows, a columnar engine reads only the two relevant columns. It skips the other forty columns on disk entirely. The result: 10–100× faster analytical queries on wide tables when you select a small fraction of columns.

The tradeoff is write performance. Row stores write one record at a time efficiently. Columnar formats like Parquet batch writes into row groups and then organize by column — which is expensive to update in-place. That's why columnar formats are almost always immutable append-only in practice.

The pattern that follows from this:
- OLTP writes (application databases) → row stores (Postgres, MySQL, DynamoDB)
- OLAP reads (analytics, reporting, ML features) → columnar stores (Parquet, ORC, Redshift, BigQuery)
- Trying to use a row store for analytical queries at scale is a cost and performance problem waiting to surface

> [!info] If your analytics query reads 5 of 50 columns, columnar storage skips 90% of the I/O before the query engine even starts.

@feynman

A row store organizes data like a spreadsheet printed row by row; a columnar store organizes it like every column ripped out and stacked separately — useless if you need a full row, perfect if you need one column across every row.

@card
id: tde-ch02-c002
order: 2
title: Parquet — The Analytical Data Lake Standard
teaser: Parquet is the de facto format for analytical data at rest — understanding its internal structure explains both why it's fast and how to use it correctly.

@explanation

Parquet is an open-source columnar file format designed for analytical workloads. It stores data in row groups (default 128 MB each), and within each row group, data is organized by column. The schema is embedded in the file footer, so readers don't need an external schema registry.

What makes Parquet fast in practice:

- **Predicate pushdown.** Each row group stores min/max statistics per column. If your filter is `WHERE year = 2023` and a row group's year column has min=2020 and max=2021, the engine skips that row group entirely without reading a byte of data.
- **Column pruning.** Because columns are stored separately, the engine reads only the columns your query references. A 60-column table where your query touches 4 columns reads roughly 1/15th of the file data.
- **Built-in compression and encoding.** Columnar layouts enable aggressive encoding: dictionary encoding for low-cardinality columns, run-length encoding for sorted data, bit-packing for integers. Parquet files are typically 3–8× smaller than equivalent CSV.
- **Nested types.** Parquet supports lists, structs, and maps natively using the Dremel encoding. You can represent semi-structured data without flattening.

The one thing Parquet doesn't handle well: small random writes and point updates. Once written, a Parquet file is immutable. For ACID updates on top of Parquet, you need a table format layer (Delta Lake or Iceberg — covered in cards 5 and 6).

@feynman

Parquet is to analytical data what an index is to a database — the structure does the work upfront so the query engine can skip most of the reading.

@card
id: tde-ch02-c003
order: 3
title: ORC — Hive's Native Format with ACID Support
teaser: ORC predates Parquet and remains the right choice for Hive-native pipelines, especially when you need ACID transactions or rely on Bloom filter optimization in older engines.

@explanation

ORC (Optimized Row Columnar) is a columnar format developed by Hortonworks for the Hive ecosystem. Like Parquet, it stores data in column stripes with embedded statistics. Unlike Parquet, it was designed with Hive's execution model in mind, and that specificity gives it advantages in certain scenarios.

Where ORC stands out:

- **ACID transactions in Hive 3+.** ORC has native support for row-level inserts, updates, and deletes in Hive. Parquet has no equivalent — you need a separate table format layer (Delta, Iceberg) to get ACID on Parquet. If you're running Hive and need mutation semantics, ORC is the path of least resistance.
- **Built-in Bloom filters.** ORC embeds Bloom filters per column stripe, which dramatically speeds up equality lookups (`WHERE user_id = 'abc123'`). Parquet supports Bloom filters in spec version 2, but older engines (pre-2020 Spark, pre-2.x Hive) often don't use them.
- **Compression options.** ORC supports ZLIB (best ratio, slow), SNAPPY (fast, moderate ratio), and ZSTD (good balance). ZLIB is the default in many Hive configurations and produces smaller files than SNAPPY but at significant CPU cost on write.

Where Parquet has the edge: broader ecosystem support. Spark, Trino, Athena, DuckDB, Pandas, and Arrow all treat Parquet as first-class. ORC support exists but is less uniform outside the Hive/Hadoop stack.

The practical decision: if your pipeline runs entirely in Hive and needs mutation support without a table format layer, ORC. Otherwise, default to Parquet.

@feynman

ORC and Parquet are the same idea built for different ecosystems — ORC grew up in the Hive world and carries its conventions; Parquet grew up in the Spark/Arrow world and became the open standard.

@card
id: tde-ch02-c004
order: 4
title: Avro — Row-Based Serialization for Streaming
teaser: Avro is not a columnar analytical format — it's a row-based serialization format built for schema evolution and streaming, and understanding that distinction prevents misuse.

@explanation

Avro is a row-based binary serialization format developed by the Hadoop project. Every Avro file (or Kafka message, in practice) carries the schema in a JSON header. The actual data is compact binary — faster and smaller than JSON but without the column-oriented layout of Parquet or ORC.

Why Avro fits streaming workloads:

- **Schema evolution is a first-class feature.** Avro supports field addition, removal, and type promotion with explicit forward and backward compatibility rules. You can evolve the schema of events flowing through Kafka without breaking producers or consumers that haven't updated yet.
- **Row-at-a-time write model.** Streaming producers write one event at a time. Avro encodes each row independently, so there's no need to buffer into row groups before writing. This is the opposite of Parquet's model, which is optimized for bulk writes.
- **Schema registry pattern.** In Kafka deployments, Avro schemas are typically centrally managed by a schema registry (Confluent's, for example). Producers register a schema and embed only a schema ID in each message — not the full schema — which reduces message overhead significantly. Consumers look up the schema by ID to deserialize.

Where Avro doesn't belong: analytical queries on cold storage. Reading Avro data for `SELECT avg(revenue) GROUP BY region` is slower than Parquet by a large margin because every row must be deserialized even if you only need two fields out of forty.

The practical pattern: ingest and streaming → Avro (with schema registry); landed cold storage and analytics → convert to Parquet.

> [!tip] If you're ingesting Avro events from Kafka, convert them to Parquet partitioned by date at the landing zone boundary. Don't run analytics on raw Avro files.

@feynman

Avro is to data what JSON is to an API response — self-describing, portable, and built for one record at a time, not for scanning millions of records at once.

@card
id: tde-ch02-c005
order: 5
title: Delta Lake — ACID Transactions on Data Lake Files
teaser: Delta Lake adds a transaction log on top of Parquet files, giving you ACID semantics, time travel, and scalable metadata handling without migrating off your existing object storage.

@explanation

Delta Lake is an open-source storage layer developed by Databricks. It sits on top of Parquet files stored in S3, ADLS, or GCS and adds a transaction log (`_delta_log/`) that records every operation — insert, update, delete, schema change — as an ordered set of JSON commit files. The data itself remains Parquet; Delta adds the coordination layer.

What Delta gives you that raw Parquet doesn't:

- **ACID transactions.** Multiple writers can commit concurrently without corrupting the table. Readers see a consistent snapshot even while a write is in progress. This is impossible with bare Parquet on object storage.
- **Time travel.** Every version of the table is queryable. `SELECT * FROM events VERSION AS OF 42` or `TIMESTAMP AS OF '2024-01-15'` reads the state of the table at any past point. Useful for auditing, reprocessing, and debugging pipelines that wrote bad data.
- **Schema enforcement and evolution.** Delta rejects writes that violate the declared schema. Schema changes are transactional and version-tracked.
- **Compaction and Z-ordering.** The `OPTIMIZE` command merges small files into larger ones (solving the small-files problem — see card 8). `ZORDER BY (column)` co-locates related data on disk, reducing the rows scanned for selective queries by 2–10×.

Delta also defines the Lakehouse architecture: structured ACID query semantics on top of cheap object storage, replacing the need for a separate warehouse for governed data.

The transaction log itself can become a bottleneck on very high-frequency append tables (millions of small commits per day). For those cases, enable auto-compaction and log checkpointing to keep metadata read times fast.

@feynman

Delta Lake is the transaction log you bolt onto a file system that was never designed to have one — it turns a pile of immutable Parquet files into something that behaves like a database table.

@card
id: tde-ch02-c006
order: 6
title: Apache Iceberg — The Open Table Format Standard
teaser: Iceberg solves the same problems as Delta Lake — ACID, time travel, schema evolution — but as a fully open, engine-agnostic standard that major cloud services are converging on.

@explanation

Apache Iceberg is an open table format specification for large analytical tables. Like Delta Lake, it sits on top of Parquet files and adds a metadata layer. Unlike Delta, it was designed from the start to be engine-agnostic: Spark, Flink, Trino, Dremio, Athena, Snowflake, and DuckDB all implement Iceberg natively without any single vendor owning the spec.

The metadata architecture is different from Delta's append-only log. Iceberg uses a tree of metadata:
- The **catalog** points to the current metadata file for each table
- **Metadata files** contain schema, partition specs, and snapshots
- **Manifest lists** and **manifest files** track which data files belong to each snapshot

This structure enables hidden partitioning — a critical differentiator. You declare a partition strategy at the logical level (`PARTITIONED BY (days(event_time))`), and Iceberg handles the physical layout transparently. You can change the partition strategy without rewriting existing data and without breaking existing queries. Delta Lake does not support partition evolution this way.

What makes Iceberg the open standard bet for 2025–2026:
- AWS Athena, Glue, and S3 Tables use Iceberg natively
- Snowflake reads external Iceberg tables
- Databricks supports Iceberg alongside Delta via UniForm
- The spec is governed by Apache, not a single vendor

The practical tradeoff: Delta's tooling (Databricks, Delta Standalone) is more mature for write-heavy streaming ingest. Iceberg's partition evolution and catalog abstraction make it better for multi-engine environments where different teams use different query engines on the same tables.

> [!info] If your organization uses more than one query engine (e.g., Spark for ETL and Athena for ad-hoc), Iceberg's engine-agnostic catalog model reduces the coordination overhead significantly.

@feynman

Iceberg is to data lakes what an open API standard is to a software ecosystem — any engine that implements the spec can read and write the table, so you're not locked into one vendor's runtime.

@card
id: tde-ch02-c007
order: 7
title: Compression Choices and the Speed-Ratio Tradeoff
teaser: Compression codec choice is a runtime decision disguised as a storage decision — the right codec depends on whether your bottleneck is I/O, CPU, or storage cost.

@explanation

Every columnar format (Parquet, ORC) and most streaming formats (Avro, Kafka) give you a choice of compression codec. Getting this wrong means either burning CPU on reads and writes unnecessarily or paying more for storage and transferring more data across the network than you need to.

The main codecs and their practical characteristics:

- **SNAPPY** — Fast compression and decompression (2–3× compression ratio). No need to tune. The default in many Spark and Parquet configurations. Best for: write-heavy workloads, streaming landing zones, any scenario where write latency matters.
- **ZSTD** — Better ratio than SNAPPY (3–5×) with tunable speed via compression level (1–22). Level 3 is a reasonable default. Best for: read-heavy analytical data where storage cost and I/O throughput matter more than write speed.
- **GZIP/ZLIB** — Best compression ratio (5–7×), slowest decompression. Best for: cold archive storage where you write once, rarely read, and want the lowest storage footprint. Avoid for hot analytics tables.
- **LZ4** — Fastest of all codecs, lowest ratio (~1.5–2×). Best for: in-memory or near-real-time scenarios where any compression overhead is unacceptable.
- **Uncompressed** — Worth considering when your data is already compressed (JPEG, compressed JSON) or when profiling shows compression overhead dominates.

A useful decision rule: if your pipeline is I/O bound (network or object storage), use ZSTD — the reduction in data transferred outweighs the CPU cost. If your pipeline is CPU bound (high-frequency inserts, streaming), use SNAPPY or LZ4.

@feynman

Compression codec selection is the same tradeoff as memory vs CPU caching — you're trading one type of resource for another, and the right answer depends on which one you have less of.

@card
id: tde-ch02-c008
order: 8
title: File Size and the Small-Files Problem
teaser: Object storage performs best with large files, and pipelines that produce thousands of tiny files are slower, more expensive, and harder to maintain than pipelines that produce dozens of large ones.

@explanation

Object storage systems like S3, GCS, and ADLS are optimized for large sequential reads. The practical sweet spot for Parquet files is 128 MB to 1 GB. Smaller than that and you're paying overhead on every file in several ways:

- **Metadata overhead.** Every S3 LIST operation has per-object overhead. A table with 100,000 small files takes much longer to plan a query against than a table with 100 files, because the engine must list all objects and load all file-level statistics before it can start reading.
- **Slow query planning.** In Spark, Athena, and Trino, query planning time scales with the number of files. A table with 500,000 small files can take 30+ seconds just to plan a query that runs in 10 seconds once started.
- **Inefficient parallelism.** Spark assigns one task per file by default. 500,000 files means 500,000 tasks — the task scheduling overhead dominates the actual compute.

How small files accumulate: streaming pipelines that write micro-batches, Spark jobs that repartition to 1 before writing, hourly partition jobs that each produce many files.

Compaction strategies:
- **Delta Lake:** `OPTIMIZE` merges small files into target-size files per partition. Run it nightly or trigger it after bulk loads.
- **Iceberg:** `rewriteDataFiles` action does the same.
- **Plain Spark:** `df.repartition(n).write.parquet(...)` — choose n so each output file is ~256 MB to 512 MB.
- **Managed tables (Databricks, Athena):** enable auto-compaction so the platform handles it.

> [!warning] A pipeline that produces small files and no compaction job is a slow-accumulating performance problem. Query times will degrade steadily as the file count grows.

@feynman

Small files in object storage are like thousands of tiny packages being delivered one by one — the shipping overhead dominates the cost, regardless of how small and light each package is.

@card
id: tde-ch02-c009
order: 9
title: Data Warehouse vs Lake vs Lakehouse
teaser: These are not just marketing terms — they represent different fundamental tradeoffs in storage cost, query speed, schema flexibility, and governance that determine where different data belongs.

@explanation

Understanding these three architectures as a decision space — not as competing products — lets you place data correctly and avoid paying for properties you don't need.

**Data warehouse** (Snowflake, BigQuery, Redshift): structured tables in a proprietary format, governed schema, SQL-first, fast queries on any pattern. The tradeoff: expensive storage ($20–30/TB/month), schema-on-write rigidity, vendor lock-in. Best for: high-priority governed data that business users query directly and frequently.

**Data lake** (raw files on S3, ADLS, GCS): cheap object storage (~$0.02/TB/month), arbitrary file formats, schema-on-read flexibility, handles raw and semi-structured data. The tradeoff: slow ad-hoc queries, no governance enforcement, no ACID semantics, high-entropy without strict conventions. Best for: raw ingestion, unprocessed logs, archival, ML training data, data you're not sure you'll ever query.

**Lakehouse** (Delta Lake or Iceberg + Databricks, Athena, Trino, Spark SQL): open table formats on cheap object storage, ACID semantics, SQL engines, governance via schema enforcement. The tradeoff: more operational complexity than a warehouse, still slower than a fully managed warehouse on complex multi-join queries. Best for: large-volume analytical data where warehouse storage cost is prohibitive but you still need reliable SQL access.

The convergence happening in 2024–2026: cloud warehouses (Snowflake, BigQuery, Redshift) are adding native Iceberg read/write support. The line between warehouse and lakehouse is blurring at the storage layer. The practical implication: standardizing on Iceberg as your open format gives you portability between engines without sacrificing warehouse-quality SQL.

@feynman

A warehouse is a clean, expensive, structured hotel; a lake is cheap open land where you can store anything but finding things is your problem; a lakehouse is building a well-organized storage facility on that cheap land.

@card
id: tde-ch02-c010
order: 10
title: Choosing a Storage Format for Your Use Case
teaser: Format selection is a decision with long-term consequences — the anti-pattern is choosing a format for convenience and discovering the mismatch two years later when the pipeline is load-bearing.

@explanation

There is no universally correct format. The right choice depends on your write pattern, read pattern, mutation requirements, and which engines need to read the data.

Decision rules by workload:

- **Streaming producers (Kafka, Kinesis):** Avro with a schema registry if schema evolution is a concern; JSON if flexibility and debuggability matter more than size. Do not land streaming data as Parquet directly — buffer and batch first.
- **Cold archive storage:** Parquet or ORC with GZIP compression. Write once, optimize for the smallest possible footprint. No mutation required.
- **Data lake analytics (read-heavy, no mutations):** Parquet with ZSTD compression, partitioned by the most common filter column (usually date). Add row group statistics to enable predicate pushdown.
- **Lakehouse with ACID requirements (updates, deletes, upserts):** Delta Lake if you're on Databricks or want the most mature write-path tooling; Iceberg if you're in a multi-engine environment (Athena + Spark, or Trino + Flink) or want the most portable open standard.
- **Hive-native pipeline with mutation semantics:** ORC with Hive ACID. Don't add a table format layer on top of a Hive stack that doesn't need it.

The anti-patterns to avoid:
- Mixing formats across layers of the same pipeline (Avro in landing, JSON in transformation, Parquet in serving — each hop requires a conversion step that accumulates latency and cost)
- Using JSON for cold analytical storage at scale (5–15× larger than Parquet, no column pruning)
- Storing Parquet without partitioning on high-volume tables (every query scans everything)
- Choosing a table format (Delta/Iceberg) before you have ACID requirements (unnecessary operational complexity)

> [!tip] Pick one format per layer and enforce it. The value of a format standard comes from consistency — not from always choosing the theoretically optimal format for each individual dataset.

@feynman

Choosing a storage format is like choosing a database — the wrong choice doesn't fail immediately, it degrades slowly until the day you need to migrate everything.
