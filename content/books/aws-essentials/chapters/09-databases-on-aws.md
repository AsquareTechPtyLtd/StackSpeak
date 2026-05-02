@chapter
id: aws-ch09-databases-on-aws
order: 9
title: Databases on AWS
summary: AWS offers a managed database for nearly every workload — relational, NoSQL, caching, analytics, and more — and choosing the right one means understanding where the shared responsibility boundary sits, what consistency model you actually need, and what you're trading off when you pick serverless over provisioned.

@card
id: aws-ch09-c001
order: 1
title: Amazon RDS Fundamentals
teaser: RDS gives you a managed relational database where AWS owns the hard parts — patching, backups, and hardware — and you own the schema, queries, and application logic.

@explanation

Amazon RDS (Relational Database Service) is a managed service that runs familiar relational engines without requiring you to provision or maintain EC2 instances yourself. Supported engines are MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, and Aurora (covered separately).

The shared responsibility boundary is specific: AWS handles OS patching, database engine version upgrades (if you enable auto minor version upgrades), automated backups, and the underlying hardware. You are responsible for schema design, query optimization, parameter group tuning, access control, and deciding when to apply major version upgrades.

Instance classes follow the same naming convention as EC2: `db.t3.micro` for light workloads, `db.m6g` for general-purpose, `db.r6g` for memory-heavy workloads. Your instance class drives CPU, RAM, and network bandwidth — not storage, which is provisioned separately (gp2, gp3, or io1/io2).

Deployment options:

- **Single-AZ:** one instance, no automatic failover. Cheaper, acceptable for dev/staging.
- **Multi-AZ:** primary instance with a synchronous standby in a second AZ. Automatic failover in 60–120 seconds if the primary fails. The standby is not readable — it exists only for durability and failover.

You connect to RDS via an endpoint DNS name, not an IP. During a Multi-AZ failover, the DNS record updates to point to the standby, so your application reconnects without a code change.

> [!info] RDS Multi-AZ is a high-availability feature, not a read-scaling feature. The standby instance does not serve any read traffic during normal operation.

@feynman

RDS is like hiring a DBA to handle the server room — they patch the OS, replace failing disks, and flip to the backup when the primary crashes, while you stay focused on the database schema and queries.

@card
id: aws-ch09-c002
order: 2
title: Multi-AZ vs Read Replicas
teaser: Multi-AZ keeps your database alive when a zone fails; Read Replicas keep your database fast when your read traffic outgrows one instance — they solve completely different problems.

@explanation

This distinction trips up almost everyone preparing for AWS exams or making a first architecture decision. Getting it wrong costs money or availability.

**Multi-AZ** uses synchronous replication. Every write committed on the primary is confirmed on the standby before it's acknowledged to the client. If the primary instance or its AZ fails, RDS promotes the standby automatically — no manual intervention, roughly 60–120 seconds of downtime. Multi-AZ operates within a single region. The standby is invisible to your application: no separate endpoint, no read traffic.

**Read Replicas** use asynchronous replication. Changes from the primary are shipped to one or more replicas, but there's a lag — typically under 1 second for low-write workloads, potentially higher under heavy writes. You get a separate endpoint for each replica, and your application must be written to direct reads there explicitly. Read Replicas can exist in a different region (cross-region read replicas), which also gives you a disaster recovery option.

You can have up to 5 Read Replicas per RDS instance (15 for Aurora). A Read Replica can be promoted to a standalone primary, but this is a manual operation and severs the replication relationship.

The practical rule: if your question is "what happens when the primary instance dies?", the answer is Multi-AZ. If your question is "how do I serve more read queries?", the answer is Read Replicas.

> [!tip] You can combine both: enable Multi-AZ on the primary for failover protection, and add Read Replicas for read scaling. They address orthogonal concerns.

@feynman

Multi-AZ is the spare tire — you don't use it until you need it, but it gets you moving again automatically; Read Replicas are carpool lanes — they exist to move more traffic in parallel, not to cover for a breakdown.

@card
id: aws-ch09-c003
order: 3
title: Amazon Aurora Architecture
teaser: Aurora is not just a faster MySQL or PostgreSQL — it's a fundamentally different storage architecture that decouples compute from storage and bakes in the fault tolerance most teams bolt on manually.

@explanation

Aurora is AWS's own relational engine, compatible with MySQL 5.7+/8.0 and PostgreSQL 13+. The compatibility means you can migrate from either with minimal application changes, but under the hood the storage layer is completely rewritten.

Key architectural facts:

- **6-copy storage across 3 AZs.** Aurora writes each transaction to six storage nodes spread across three Availability Zones. Writes succeed after 4 of 6 acknowledge. Reads require 3 of 6. You can lose an entire AZ and a storage node in a second AZ without losing data or availability.
- **Storage auto-grows in 10 GB increments up to 128 TB.** You never provision storage upfront or resize a volume.
- **Up to 15 Aurora Replicas** with sub-10ms replication lag. Unlike RDS Read Replicas, Aurora Replicas share the same underlying storage — replication is at the storage layer, not the log-shipping layer, which is why lag is so low.
- **Aurora Serverless v2** scales compute capacity in increments as small as 0.5 ACUs (Aurora Capacity Units) within seconds. It's suitable for variable-traffic apps, dev environments, and workloads with unpredictable peaks.
- **Aurora Global Database** replicates to up to 5 secondary regions with a typical replication lag under 1 second. Secondary regions are read-only by default but can be promoted to primary in under 1 minute for disaster recovery.

> [!warning] Aurora's per-I/O pricing model means it can be more expensive than RDS under write-heavy workloads. Evaluate the cost model against your write pattern before defaulting to Aurora.

@feynman

Aurora is like a distributed file system with a SQL interface bolted on top — instead of one disk that the database writes to, the storage layer is a cluster of nodes that collectively own the data, making the disk failure problem someone else's problem.

@card
id: aws-ch09-c004
order: 4
title: DynamoDB Fundamentals
teaser: DynamoDB is AWS's fully managed NoSQL service — serverless, infinitely scalable, and single-digit millisecond at any load, but only if you design your data model around your access patterns first.

@explanation

DynamoDB is a key-value and document store. Every table has a primary key, which is either:

- **Partition key only** (simple primary key): a single attribute whose hash determines the partition where the item lives.
- **Partition key + sort key** (composite primary key): the partition key groups related items together; the sort key orders items within a partition and enables range queries (`BETWEEN`, `begins_with`, `>`).

Items in a table can have different attributes — DynamoDB is schema-less aside from the primary key.

**Capacity modes:**

- **Provisioned:** you specify read capacity units (RCUs) and write capacity units (WCUs). One RCU = one strongly consistent read of up to 4 KB/s (or two eventually consistent reads). One WCU = one write of up to 1 KB/s. You pay for provisioned capacity whether you use it or not. Auto Scaling can adjust provisioned capacity within bounds.
- **On-demand:** DynamoDB scales automatically with no capacity planning. You pay per request. More expensive per request, but zero waste on idle capacity. Good for unpredictable or spiky workloads.

DynamoDB delivers single-digit millisecond read and write latency at any scale — whether your table holds 1,000 items or 1 trillion. The performance guarantee holds because DynamoDB partitions data automatically and routes requests directly to the correct partition.

> [!info] DynamoDB charges for RCUs and WCUs separately for reads and writes, and eventually consistent reads cost half as many RCUs as strongly consistent reads. Know which consistency model your reads actually require.

@feynman

DynamoDB is like a hash map that AWS manages at planetary scale — you hand it a key and get back a value in under a millisecond, but you lose the ability to do ad-hoc queries the way you would with a relational database.

@card
id: aws-ch09-c005
order: 5
title: DynamoDB Data Modeling
teaser: DynamoDB rewards engineers who design their schema around access patterns first and punishes those who try to normalize their data the way they would in PostgreSQL.

@explanation

The single most important principle in DynamoDB design: **define every access pattern before you design a single table**. The schema exists to serve those patterns efficiently. If you don't know how you'll query the data, you can't design the table correctly.

DynamoDB supports secondary indexes to handle access patterns that the primary key can't serve:

**Global Secondary Index (GSI):** a projection of the table with a different partition key (and optional sort key). Queries on a GSI are eventually consistent. GSIs have their own provisioned capacity (or inherit on-demand). You can create up to 20 GSIs per table, and you can add them after table creation.

**Local Secondary Index (LSI):** shares the table's partition key but uses a different sort key. Queries on an LSI can be strongly consistent. LSIs share the table's capacity. Critical constraint: **LSIs must be defined at table creation** — you cannot add one after the fact.

**Single-table design** is the pattern used by teams that have mastered DynamoDB. Instead of one table per entity type (users, orders, products), you pack multiple entity types into a single table and use overloaded partition/sort key values (like `PK=USER#123`, `SK=ORDER#456`) to represent relationships. This lets you fetch related entities in a single query with no joins. The tradeoff is that the schema is opaque until you map the access patterns — it's not readable without documentation.

> [!warning] Do not design a DynamoDB table as if it were a relational table with a NoSQL backend. That path leads to full table scans, GSI fan-out, and costs that surprise you on the billing page.

@feynman

Designing a DynamoDB table is like designing an index structure before you have a database — the data lives where the queries need it to be, not where it feels logically organized.

@card
id: aws-ch09-c006
order: 6
title: DynamoDB Streams and DAX
teaser: Streams let you react to every change in your table as it happens; DAX lets you serve millions of reads per second at microsecond latency without touching the table at all.

@explanation

**DynamoDB Streams** is a change data capture feature. Every item-level modification (insert, update, delete) is written to an ordered stream of records. Streams retain records for 24 hours. You can configure each stream record to contain the new image, old image, both, or just keys.

The primary use case is triggering Lambda functions in response to data changes — building event-driven architectures without polling. Examples: sending a welcome email when a new user item is created, invalidating a cache when a product price is updated, fanning out writes to a search index.

One Lambda function can process a stream shard; DynamoDB partitions stream data to match the table's partition layout.

**DynamoDB Accelerator (DAX)** is an in-memory write-through cache purpose-built for DynamoDB. It sits in front of your table, intercepts read requests, and returns results from cache when available. Cache hits return in microseconds (vs. single-digit milliseconds for DynamoDB directly). Cache misses fall through to DynamoDB and populate the cache.

DAX is appropriate when:
- Your workload is read-heavy.
- Eventual consistency is acceptable (DAX does not support strongly consistent reads from cache).
- You want caching without changing your application's DynamoDB API calls — the DAX client is a drop-in replacement.

DAX is not appropriate for write-heavy workloads or for items that require strongly consistent reads, since those bypass the cache.

> [!info] DAX runs on a cluster inside your VPC — it's not serverless. You provision node types (starting at `dax.r6g.large`) and pay for uptime regardless of traffic.

@feynman

DAX is like adding a CDN in front of your database — the first request is slow, but repeated reads of the same item come back instantly without ever touching the origin.

@card
id: aws-ch09-c007
order: 7
title: Amazon ElastiCache
teaser: ElastiCache gives you managed Redis or Memcached — if you need persistence, replication, or complex data structures, pick Redis; if you need a fast, simple, multi-threaded cache with no state, pick Memcached.

@explanation

ElastiCache is a managed in-memory caching service. You pick your engine at creation — the choice is not reversible without recreating the cluster.

**Redis** is the right default for most use cases. It supports:
- Persistence (RDB snapshots, AOF append-only files)
- Replication (primary + up to 5 read replicas)
- Cluster mode (sharding across up to 500 nodes for horizontal scale)
- Rich data structures: strings, hashes, lists, sets, sorted sets, streams
- Lua scripting for atomic multi-key operations
- Pub/sub messaging
- TTL-based expiration and keyspace notifications

**Memcached** is simpler and faster for pure key-value caching at scale. It's multi-threaded (Redis is single-threaded per shard), which helps on large instance types. It has no persistence, no replication, no complex data structures. If your only requirement is "cache this value for N seconds and never mind if it disappears on restart," Memcached works.

**Redis Cluster mode** distributes data across shards (each shard is a primary + replicas). You can scale out to handle more write throughput. Cluster mode requires your client to be cluster-aware, and some Redis commands that operate across keys in multiple slots are not supported.

**Eviction policies** control what happens when memory is full: `allkeys-lru` evicts the least recently used key across all keys; `volatile-lru` evicts only among keys with a TTL set; `noeviction` returns errors rather than evicting. Set a policy deliberately — the default is `noeviction`, which causes write failures when memory fills up.

> [!tip] Use ElastiCache Redis in front of RDS or Aurora for session state, leaderboards, and hot read-path data. A well-placed cache can reduce RDS load by 80%+ and cut database costs significantly.

@feynman

ElastiCache is like RAM for your application tier — brutally fast, limited by size, and the data disappears when you lose power, but for hot data that's exactly the tradeoff you want.

@card
id: aws-ch09-c008
order: 8
title: Amazon Redshift for Analytics
teaser: Redshift is a columnar data warehouse built for analytical queries across terabytes of data — it's not a replacement for your operational database, and the moment you treat it like one, query performance and cost both become problems.

@explanation

Redshift uses a massively parallel processing (MPP) architecture. A cluster has a leader node that parses and optimizes queries, and one or more compute nodes that execute slice operations in parallel. This makes it fast for aggregations over large datasets and slow for high-concurrency OLTP workloads.

**Node types:**
- `ra3`: separate compute and managed storage (stored in S3, hot data cached locally on NVMe). Scales compute and storage independently. The right default for most new workloads.
- `dc2`: dense compute with local SSD storage. Good for sub-terabyte datasets that need fast local I/O.

**Distribution keys** determine how rows are spread across compute nodes. A distribution key that matches your JOIN columns minimizes data movement during queries. Poor distribution key choice means Redshift redistributes rows across the network for every join, which dominates query time.

**Sort keys** define the on-disk sort order of data within a slice. Range-filtered queries on a sort key benefit from zone maps — Redshift skips entire 1 MB blocks where the filter condition cannot match. Choose sort keys based on your most common WHERE and ORDER BY columns.

**Redshift Serverless** removes cluster management — you pay per RPU-second of actual compute usage. Suitable for infrequent queries and dev environments, but can be expensive under sustained load compared to a provisioned cluster.

**Redshift Spectrum** lets you query data directly in S3 using the same SQL syntax and cluster compute, without loading data into Redshift tables. Useful for cold data that you query occasionally.

> [!info] Redshift is an OLAP engine. Running short, high-concurrency writes through it will degrade performance for everyone querying it. Separate your transactional and analytical workloads.

@feynman

Redshift is like a library with all the books sorted so the librarian can scan a whole shelf for a topic in seconds — brilliant for finding patterns across millions of rows, terrible for the high-frequency one-book-at-a-time requests a bookstore handles.

@card
id: aws-ch09-c009
order: 9
title: DocumentDB and Keyspaces
teaser: DocumentDB gives you a MongoDB-compatible API without running MongoDB, and Keyspaces gives you a Cassandra-compatible API without running Cassandra — useful if you're already on those APIs, but neither is the same engine underneath.

@explanation

**Amazon DocumentDB** is a managed document database with a MongoDB 3.6, 4.0, and 5.0 compatible API. It is not MongoDB. Under the hood it uses the Aurora storage architecture — 6-copy replication across 3 AZs, storage auto-grows to 64 TB, up to 15 read replicas. You migrate by pointing your MongoDB driver at a DocumentDB endpoint. Most MongoDB queries, indexes, and aggregation pipeline operators work, but not all — check the compatibility guide before migrating.

Use DocumentDB when: you have an existing MongoDB workload you want to migrate to a fully managed service on AWS without re-architecting, and you want the operational simplicity of Aurora-style storage with no self-managed replica sets.

Do not use DocumentDB as your first choice when starting fresh — DynamoDB is usually the better fit for new document-model workloads on AWS.

**Amazon Keyspaces (for Apache Cassandra)** is a serverless, fully managed service with a Cassandra-compatible CQL (Cassandra Query Language) API. You migrate by pointing your Cassandra driver at a Keyspaces endpoint. It's not Cassandra — it's AWS infrastructure with a CQL interface. The operational model is serverless: no clusters to manage, storage scales automatically, and you choose provisioned or on-demand capacity.

Use Keyspaces when: you're migrating a Cassandra workload to AWS and want to eliminate the operational burden of managing Cassandra clusters (topology, compaction, repair jobs).

Both services are compatibility-first solutions. Their value proposition is "bring your existing driver and minimal code changes" — not "best-in-class for greenfield work."

> [!warning] Neither DocumentDB nor Keyspaces is 100% compatible with its respective open-source engine. Validate your specific query patterns and driver versions against the AWS compatibility documentation before committing to a migration.

@feynman

DocumentDB and Keyspaces are like API-compatible cloud services that speak the same language as MongoDB and Cassandra but are built on completely different infrastructure — useful for migration, but you should read the dialect differences before you move.

@card
id: aws-ch09-c010
order: 10
title: Choosing the Right AWS Database
teaser: AWS has more than a dozen managed database services, but the decision tree collapses quickly once you know your data model, consistency requirements, and whether your workload is transactional or analytical.

@explanation

Use this decision tree when selecting a database on AWS:

**OLTP relational (joins, ACID transactions, existing SQL workload):**
- Default: Aurora (MySQL or PostgreSQL compatible)
- If cost is a constraint and you don't need Aurora's scale: RDS
- Aurora beats RDS on availability, replication lag, and read replica count; RDS beats Aurora on per-I/O cost under write-heavy loads

**Key-value or document at scale (high throughput, flexible schema, NoSQL):**
- Default: DynamoDB
- Only consider DocumentDB if you have an existing MongoDB workload you're migrating

**Read-heavy workload with microsecond latency requirement:**
- Add DAX in front of DynamoDB
- Add ElastiCache Redis or Memcached in front of RDS/Aurora

**Session state, leaderboards, pub/sub, ephemeral data:**
- ElastiCache Redis

**Simple, stateless cache (no persistence, no complex data types):**
- ElastiCache Memcached

**OLAP, analytics, business intelligence, large aggregations:**
- Redshift (provisioned for sustained load, Serverless for infrequent queries)
- Redshift Spectrum if most data lives in S3 and you query it occasionally

**MongoDB-compatible document store (migration scenario):**
- DocumentDB

**Cassandra-compatible wide-column store (migration scenario):**
- Keyspaces

**Graph relationships (social graphs, fraud detection, recommendations):**
- Neptune (not covered in depth here, but worth knowing it exists)

**Time-series data (IoT, metrics, monitoring):**
- Timestream (same caveat — it exists, purpose-built, often overlooked)

The default mistake is reaching for RDS because SQL is familiar. DynamoDB at single-digit millisecond latency with no servers to manage is often the better choice for new workloads — if you invest upfront in access-pattern design.

> [!tip] The question "which database should I use?" almost always reduces to two sub-questions: what shape is your data (relational vs. document vs. wide-column), and what are your query patterns (known and bounded vs. ad-hoc and exploratory)?

@feynman

Picking a database is like picking a transportation mode — a car, a train, a plane, and a bike all move people, but the right choice depends entirely on the distance, the number of passengers, and how often the route changes.
