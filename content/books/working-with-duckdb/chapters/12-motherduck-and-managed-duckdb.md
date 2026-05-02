@chapter
id: wdd-ch12-motherduck-and-managed-duckdb
order: 12
title: MotherDuck and Managed DuckDB
summary: MotherDuck brings DuckDB to the cloud with hybrid local+cloud execution, shared databases, and the DuckLake lakehouse format — DuckDB's 2026 cloud story.

@card
id: wdd-ch12-c001
order: 1
title: What MotherDuck Is
teaser: MotherDuck is a managed cloud service built on DuckDB — it adds multi-user access, a web UI, and shared databases without replacing the DuckDB you already know.

@explanation

MotherDuck is the commercial managed offering built on top of the open-source DuckDB engine. DuckDB GmbH (founded 2021) operates it as a cloud service. The core DuckDB engine stays MIT-licensed and unchanged — MotherDuck layers a service model on top.

What MotherDuck adds that self-hosted DuckDB lacks:

- **Multi-user access.** Multiple people can connect to the same database without sharing credentials to a single file.
- **Web UI.** A browser-based SQL editor with schema browsing, query history, and result sharing.
- **Shared databases.** Grant read or read-write access to a database with another user or team, scoped to the database level.
- **Managed storage.** Your databases live in MotherDuck's cloud storage — no S3 bucket to provision, no backups to configure.
- **Hybrid execution.** Queries can run partly on your local machine and partly in MotherDuck's compute, choosing the most efficient path.

What MotherDuck does not change:

- The DuckDB SQL dialect. Queries that work locally work in MotherDuck.
- The extension ecosystem. Extensions that load locally load in MotherDuck.
- The single-writer constraint per database. Concurrent write contention is still a design consideration.

> [!info] MotherDuck uses the same DuckDB version as the client library you connect with. If you connect with `duckdb==1.1.3`, MotherDuck executes on 1.1.3. Pin your client version if you need deterministic behavior across environments.

@feynman

Like GitHub relative to Git — Git stays open source and unchanged while GitHub layers collaboration, access control, and a web UI on top of it.

@card
id: wdd-ch12-c002
order: 2
title: Connecting to MotherDuck
teaser: A `md:` connection prefix and an authentication token are all it takes — MotherDuck is a DuckDB connection string, not a separate client.

@explanation

MotherDuck uses a connection string prefix to distinguish cloud connections from local file connections. There is no separate SDK or client library — you use the standard `duckdb` package.

**Python:**
```python
import duckdb

# Connect to MotherDuck (token from env or interactive prompt)
con = duckdb.connect("md:")

# Connect to a specific database in MotherDuck
con = duckdb.connect("md:my_database")
```

**Authentication:**
Set the `motherduck_token` environment variable before connecting:
```bash
export motherduck_token="your_token_here"
```

Or pass it inline (not recommended for scripts committed to git):
```python
con = duckdb.connect("md:?motherduck_token=your_token_here")
```

**CLI:**
```bash
duckdb md:my_database
```

**Connection string anatomy:**
- `md:` — connect to MotherDuck, use the default database
- `md:my_db` — connect to MotherDuck, open `my_db`
- `md:my_db?motherduck_token=...` — explicit token in the URL

> [!warning] Never hardcode your MotherDuck token in source code. Use environment variables or a secrets manager. Tokens grant full access to your MotherDuck account.

@feynman

Like a PostgreSQL connection string — the scheme changes (`postgres://` vs `md:`), but the model of "connection string encodes where and how to connect" is identical.

@card
id: wdd-ch12-c003
order: 3
title: Hybrid Execution Model
teaser: MotherDuck queries can split across local and cloud compute — DuckDB's query planner decides which fragments run where based on data locality.

@explanation

Hybrid execution is MotherDuck's most distinctive feature. When you run a query against a MotherDuck connection, the DuckDB query planner can execute different parts of the query in different locations:

- **Cloud-side execution:** Scans and aggregations over data stored in MotherDuck run on MotherDuck's compute. No data is downloaded unless needed.
- **Local-side execution:** Joins against local files or in-memory data run on your local DuckDB process. Local data never leaves your machine.
- **Combined:** A join between a MotherDuck table and a local Parquet file can run with the MotherDuck scan executing remotely and the result joined locally.

Example — join a cloud table with a local file:
```sql
-- cloud_orders is in MotherDuck; local_dim.parquet is on your machine
SELECT o.order_id, d.region
FROM cloud_orders o
JOIN read_parquet('/data/local_dim.parquet') d ON o.region_code = d.code
WHERE o.created_at > '2026-01-01';
```

DuckDB's planner pushes the `cloud_orders` scan and the date filter to MotherDuck's compute. Only the filtered rows transfer over the network for the local join.

Latency implications:
- Cloud-only queries: latency is dominated by MotherDuck's compute, not your local machine.
- Hybrid queries: network round-trip adds latency. For latency-sensitive interactive queries, keep hot data in MotherDuck.
- Local-only queries on a `md:` connection: behave identically to a plain DuckDB connection — no cloud round-trip.

@feynman

Like a query federation layer in a distributed database — the planner is aware of where data lives and ships compute to the data rather than always pulling data to compute.

@card
id: wdd-ch12-c004
order: 4
title: Cloud Databases vs Local Databases
teaser: A `md:` prefix puts a database in MotherDuck's cloud storage — without it, the database stays local, even on a MotherDuck connection.

@explanation

A MotherDuck connection can work with both cloud-hosted and local databases simultaneously. The `md:` prefix on a database name determines where the database lives.

**Creating a cloud database:**
```sql
-- Creates a database in MotherDuck cloud storage
CREATE DATABASE my_cloud_db;

-- Equivalent explicit form
ATTACH 'md:my_cloud_db' AS my_cloud_db;
```

**Creating a local database on a MotherDuck connection:**
```sql
-- Creates a .duckdb file on your local filesystem, not in the cloud
ATTACH 'my_local.duckdb' AS local_db;
```

**Listing attached databases:**
```sql
SHOW DATABASES;
-- Returns both local and cloud-attached databases
```

**Switching between databases:**
```sql
USE my_cloud_db;
SELECT * FROM my_table; -- queries the cloud database

USE local_db;
SELECT * FROM my_table; -- queries the local file
```

Key distinctions:

- Cloud databases (`md:my_db`): stored in MotherDuck, accessible from any connection, shared with other users via grants.
- Local databases (`my_db.duckdb`): stored on your filesystem, accessible only from the local machine, not shared.

Both types can be queried in the same session and joined across in hybrid queries.

> [!tip] Use local databases for staging or scratch work during development, then `COPY` or `INSERT INTO SELECT` to promote data to a cloud database when ready to share.

@feynman

Like the difference between a local Git repository and a remote hosted on GitHub — local stays on your machine, remote is accessible to the team.

@card
id: wdd-ch12-c005
order: 5
title: Sharing Databases in MotherDuck
teaser: MotherDuck lets you share a database with another user or team at the database level — read-only or read-write, with no credential sharing required.

@explanation

Sharing in MotherDuck is modeled at the database level. You grant access to a database to another MotherDuck account; they attach it to their connection without needing your credentials.

**Sharing a database (MotherDuck web UI or SQL):**
```sql
-- Grant read-only access to another MotherDuck user
GRANT READ ON DATABASE my_cloud_db TO 'colleague@example.com';

-- Grant read-write access
GRANT READ WRITE ON DATABASE my_cloud_db TO 'colleague@example.com';
```

**Attaching a shared database (recipient's connection):**
```sql
-- The recipient attaches the shared database by owner-qualified name
ATTACH 'md:sivsadha/my_cloud_db' AS shared_db;
SELECT * FROM shared_db.my_table;
```

Use cases for database sharing:

- **Team analytics:** a data engineer writes, analysts read. One database, one source of truth, no ETL to a separate warehouse.
- **Data products:** publish a curated database to downstream consumers without giving them access to raw data pipelines.
- **Collaboration:** two engineers work on different parts of a pipeline, each writing to their own databases but reading from each other's.

Revoke access:
```sql
REVOKE READ ON DATABASE my_cloud_db FROM 'colleague@example.com';
```

> [!info] Shared databases are live — the recipient always reads the current state. There is no snapshot-on-share. If you need a point-in-time copy, export and share a Parquet or DuckLake snapshot instead.

@feynman

Like sharing a Google Doc — you grant access to a specific document to a specific person, they open it directly without you handing over your account credentials.

@card
id: wdd-ch12-c006
order: 6
title: DuckLake — DuckDB's Native Lakehouse Format
teaser: DuckLake is an open table format specification built for DuckDB-centric architectures — simpler than Iceberg, with DuckDB metadata management built in.

@explanation

DuckLake is an open table format introduced in 2025, designed to be the lakehouse format for architectures centered on DuckDB and MotherDuck. It is distinct from Apache Iceberg and Delta Lake, both of which predate DuckDB's prominence and carry design decisions made for JVM-centric ecosystems.

Core design choices in DuckLake:

- **DuckDB as the catalog.** Table metadata (partition maps, file manifests, schema history, snapshots) is stored in a DuckDB database file rather than in per-directory metadata JSON files (Iceberg) or transaction log files (Delta).
- **Object storage for data.** The actual data files (Parquet) live in S3, GCS, or Azure Blob. Only the catalog database is a DuckDB file.
- **Native DuckDB DDL.** `CREATE TABLE`, `INSERT`, `MERGE`, `ALTER TABLE` against a DuckLake catalog use standard DuckDB SQL — no separate Iceberg REST catalog or Delta log protocol.

Compared to Iceberg:
- Iceberg: catalog is a hierarchy of JSON manifest files + a catalog server (REST, Hive Metastore, Glue).
- DuckLake: catalog is one DuckDB file. No catalog server required. Query the catalog itself with SQL.

Compared to Delta Lake:
- Delta: transaction log is per-table `_delta_log/` JSON/Parquet files, designed for Spark.
- DuckLake: centralized DuckDB catalog, designed for DuckDB-native tooling.

```sql
-- Create a DuckLake catalog backed by S3
ATTACH 's3://my-bucket/my-catalog.duckdb' AS lake (TYPE DUCKLAKE);

-- Create a table in the DuckLake catalog
CREATE TABLE lake.events (id BIGINT, ts TIMESTAMP, payload JSON);

-- Insert data — written as Parquet to S3, catalog updated in DuckDB
INSERT INTO lake.events VALUES (1, now(), '{"action":"click"}');
```

@feynman

Like using a SQLite file as a package registry instead of a tree of JSON files — you gain SQL query capability over the metadata itself, at the cost of needing a DuckDB reader for the catalog.

@card
id: wdd-ch12-c007
order: 7
title: DuckLake vs Iceberg and Delta Lake
teaser: DuckLake trades Iceberg and Delta's broad ecosystem compatibility for simpler catalog management and deeper DuckDB integration — the tradeoff is real and intentional.

@explanation

Choosing between DuckLake, Iceberg, and Delta Lake depends on your ecosystem, not just your query engine.

**Where Iceberg wins:**
- Multi-engine environments. Iceberg is supported by Spark, Trino, Flink, Hive, Snowflake, BigQuery, and most cloud warehouses. If you need multiple query engines reading the same table, Iceberg is the safer choice.
- Managed catalog services. AWS Glue, Polaris, and Nessie are mature Iceberg catalog implementations.
- Existing investment. If your team already has an Iceberg catalog and data, migration to DuckLake adds no value.

**Where Delta Lake wins:**
- Spark-centric pipelines. Delta Lake has the deepest Spark integration and is the default format in Databricks environments.
- DML operations at scale. Delta's write protocol is optimized for high-concurrency Spark writers.

**Where DuckLake wins:**
- DuckDB-only or MotherDuck-centric architectures. When DuckDB is your only query engine, DuckLake eliminates the catalog server.
- Simplicity. One DuckDB file is the entire catalog — backup, copy, or inspect it with any DuckDB connection.
- Self-contained data products. Ship a DuckLake catalog + Parquet data as a unit without requiring a catalog service to consume it.
- Local development. No catalog server means no local services to run during development.

> [!warning] DuckLake is not a drop-in replacement for Iceberg or Delta if your pipeline includes Spark, Flink, or non-DuckDB engines. It is a DuckDB-native choice, not a universal table format.

@feynman

Like SQLite vs PostgreSQL for application state — SQLite is simpler and self-contained for the single-process case, PostgreSQL is the right choice when you need multi-engine concurrency.

@card
id: wdd-ch12-c008
order: 8
title: DuckDB 1.0 — What Stability Actually Means
teaser: DuckDB 1.0 committed to storage format stability, ABI-compatible extensions, and a no-silent-breaking-changes policy — concrete promises, not just a version number bump.

@explanation

DuckDB 1.0 shipped in June 2024. Before 1.0, the storage format and C extension API changed between minor releases. Extensions compiled for 0.9 would not load on 0.10. `.duckdb` files created on 0.9 required re-import on 0.10.

The 1.0 stability commitments:

- **Storage format stability.** A `.duckdb` file created by DuckDB 1.0 is readable by all future 1.x releases. No re-import required for minor version upgrades.
- **C API stability.** The C extension API is versioned. Extensions compiled for 1.0 load on 1.1, 1.2, and so on without recompilation.
- **Extension ABI contracts.** The community extension registry (`extensions.duckdb.org`) can ship pre-compiled binaries because the ABI is stable. Users install community extensions without building from source.
- **Breaking-change policy.** Behavioral changes that affect query results (changed default values, removed syntax) are now gated behind a major version bump. Minor and patch releases may add behavior but do not remove or silently change it.

What 1.0 did not change:

- The single-writer constraint. Still by design.
- The OLAP-only positioning.
- The zero-dependency philosophy for the core engine.

Practical impact for production pipelines:

- Pin to a patch version (`duckdb==1.1.3`) for reproducibility.
- Upgrade minor versions deliberately — test against your queries before promoting.
- Extension compatibility is guaranteed within 1.x, not across major versions.

@feynman

Like a library publishing a 1.0 on semver — it signals that the author is committing to backward compatibility within the major version, not that development has stopped.

@card
id: wdd-ch12-c009
order: 9
title: DuckDB 1.1 and 1.2 — Notable Additions
teaser: DuckDB's post-1.0 releases added community extensions, asynchronous I/O, and a secrets manager — each addressing a real friction point from production use.

@explanation

DuckDB's release cadence since 1.0 has run roughly one minor release per quarter. Notable additions across 1.1 and 1.2:

**Community extensions (1.1):**
A public extension registry at `extensions.duckdb.org` allows third-party extension authors to publish pre-compiled extensions installable with one command:
```sql
INSTALL quack FROM community;
LOAD quack;
```
Extensions are signed and verified. The registry now hosts spatial analytics, additional file format readers, and utility extensions beyond the core distribution.

**Asynchronous I/O (1.1):**
DuckDB's I/O layer became asynchronous — reads from S3, GCS, Azure Blob, and `httpfs` no longer block the query execution thread. Queries over remote storage that previously stalled waiting for I/O now overlap compute and I/O, reducing wall-clock time for network-bound workloads.

**Secrets manager (1.1):**
A unified secrets management API replaces the pattern of setting `s3_access_key_id` and similar environment variables via `SET`:
```sql
CREATE SECRET my_s3_creds (
    TYPE S3,
    KEY_ID 'AKIAIOSFODNN7EXAMPLE',
    SECRET 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    REGION 'us-east-1'
);
```
Secrets persist across sessions and scope to a connection or a named profile. Multiple cloud providers (S3, GCS, Azure) use the same API.

**Delta Lake support (1.1):**
The `delta` community extension promoted to the core distribution. Read Delta tables directly:
```sql
SELECT * FROM delta_scan('s3://my-bucket/my-delta-table/');
```

> [!tip] The secrets manager replaces the older `SET s3_access_key_id = '...'` pattern. Migrate to `CREATE SECRET` for cleaner multi-environment credential handling.

@feynman

Like a platform SDK graduating features from experimental plugins to stable built-ins — each release takes what the community proved out and promotes it to first-class support.

@card
id: wdd-ch12-c010
order: 10
title: MotherDuck Pricing and Service Model
teaser: MotherDuck bills on compute and storage separately — understanding the model prevents bill surprises when hybrid queries involve more local compute than expected.

@explanation

MotherDuck's pricing model (as of 2026) separates storage from compute:

- **Storage:** billed per GB stored in MotherDuck cloud storage per month. Your database files and their DuckLake catalogs count against storage.
- **Compute:** billed per DuckDB-second of cloud-side query execution. Local-side hybrid execution (running on your machine) does not incur compute charges.
- **Free tier:** MotherDuck offers a free tier suitable for individual use, experimentation, and small team projects. Check the current pricing page — free tier limits change over time.

What counts as cloud compute:

- Scans and aggregations running on MotherDuck's servers.
- Queries run from the MotherDuck web UI.
- Scheduled queries run server-side.

What does not count:

- Query fragments that run on your local DuckDB process.
- Reads of shared databases where you are the recipient (compute is charged to the owner for data they serve, or split by policy — verify current terms).

Cost optimization strategies:

- Use hybrid execution to push aggregations to the cloud (reducing data transfer) and do final joins locally.
- Store raw data as Parquet on S3 outside MotherDuck; only import summary tables into MotherDuck cloud storage.
- Use local databases for iterative development; promote to cloud databases only when sharing is needed.

> [!info] MotherDuck's pricing page is the authoritative source — this chapter reflects the model as of early 2026 but specific numbers change. Always verify before making cost projections.

@feynman

Like AWS Lambda billing — you pay for compute time consumed, not for provisioned capacity sitting idle, so the cost profile is very different from a provisioned warehouse.

@card
id: wdd-ch12-c011
order: 11
title: MotherDuck Web UI and Developer Workflow
teaser: MotherDuck's browser UI handles schema browsing, query history, and result sharing — useful for collaborative analytics without setting up a BI tool.

@explanation

MotherDuck provides a browser-based SQL editor at `app.motherduck.com`. The UI is built on top of the same DuckDB connection model as the Python and CLI clients — it is not a separate query layer.

What the web UI provides:

- **SQL editor** with autocomplete for table and column names across your cloud databases.
- **Schema browser** showing all databases, tables, and columns visible to your account, including shared databases.
- **Query history** with shareable links to past queries and results.
- **Result export** — download query results as CSV or Parquet directly from the UI.
- **Notebook mode** — multi-cell SQL notebooks with markdown cells for documentation, shareable with team members.

Developer workflow patterns:

Exploratory analysis:
```sql
-- Run in the MotherDuck web UI
SELECT date_trunc('week', created_at) AS week, COUNT(*) AS events
FROM prod.events
WHERE created_at > '2026-01-01'
GROUP BY 1 ORDER BY 1;
```

Pipeline development:
- Develop and test queries locally with DuckDB CLI or Python.
- Promote to MotherDuck by pointing the same SQL at `md:` connection.
- Schedule production runs via MotherDuck's scheduled query feature.

The web UI connects to the same databases as your local `md:` connection. There is no "web UI database" separate from your programmatic databases — changes made via SQL in the UI are visible to your Python client immediately.

@feynman

Like the GitHub web editor versus a local clone — both operate on the same repository, you pick the interface based on what you are doing at the moment.

@card
id: wdd-ch12-c012
order: 12
title: When to Use MotherDuck vs Self-Hosted DuckDB
teaser: The decision comes down to five factors — team size, data sharing needs, compliance constraints, latency requirements, and total cost at scale.

@explanation

Neither MotherDuck nor self-hosted DuckDB is universally better. The decision follows from your specific constraints.

**Favor MotherDuck when:**

- **Team collaboration is required.** Multiple people need to query the same database. Self-hosted DuckDB has no multi-user model — you would need to build one.
- **You want managed storage.** No S3 bucket provisioning, no backup configuration, no storage scaling decisions.
- **You want a web UI without building one.** MotherDuck's notebook and query sharing features replace a BI tool for SQL-comfortable teams.
- **Your dataset fits the MotherDuck scale.** MotherDuck targets the "fits on one very large node" scale — multi-terabyte analytical databases, not petabyte Hadoop replacements.
- **Cost simplicity matters.** Pay-as-you-go beats provisioning, operating, and monitoring your own infrastructure for most small-to-medium teams.

**Favor self-hosted DuckDB when:**

- **Data cannot leave your environment.** Compliance, regulatory, or contractual requirements prohibit sending data to a third-party cloud service.
- **Network latency is the bottleneck.** For latency-sensitive applications where the database is local to the compute, removing the network is the most effective optimization.
- **You are already operating object storage.** If you have S3 + an EC2 instance, self-hosted DuckDB + Parquet/DuckLake can be cheaper at scale than MotherDuck.
- **Single-user or automated pipelines.** A solo data engineer running nightly ETL jobs has no collaboration requirement. The operational overhead of MotherDuck adds cost without benefit.
- **Extreme scale.** Multi-terabyte write-heavy workloads may require a horizontally scalable system — at that point, neither self-hosted DuckDB nor MotherDuck is the right answer.

> [!tip] Start with self-hosted DuckDB. When the friction of sharing queries, results, or databases with teammates starts to cost meaningful time, evaluate MotherDuck. The migration is a connection string change.

@feynman

Like Postgres on your laptop vs a managed RDS instance — the right choice depends on whether the operational overhead of self-hosting is worth avoiding the cost and data-residency implications of the managed service.

@card
id: wdd-ch12-c013
order: 13
title: Migrating from Self-Hosted DuckDB to MotherDuck
teaser: Migrating an existing DuckDB database to MotherDuck is a connection string change plus a one-time data copy — the SQL stays the same.

@explanation

Because MotherDuck uses the standard DuckDB engine and SQL dialect, migration is primarily an operational task, not a code rewrite.

**Step 1: Attach both databases in one session.**
```python
import duckdb

# Connect to MotherDuck
con = duckdb.connect("md:")

# Attach your existing local database as a second database
con.execute("ATTACH 'local_data.duckdb' AS local_db")
```

**Step 2: Create the target database in MotherDuck.**
```sql
CREATE DATABASE my_cloud_db;
```

**Step 3: Copy tables.**
```sql
-- Copy a single table
CREATE TABLE my_cloud_db.orders AS SELECT * FROM local_db.orders;

-- Or copy schema + data with full fidelity
COPY (SELECT * FROM local_db.orders) TO 'orders_export.parquet';
COPY my_cloud_db.orders FROM 'orders_export.parquet';
```

**Step 4: Update connection strings in your application.**
```python
# Before
con = duckdb.connect("local_data.duckdb")

# After
con = duckdb.connect("md:my_cloud_db")
```

All queries that worked against the local file work unchanged against MotherDuck. Extensions load identically. The DuckDB SQL dialect is the same.

Things to verify post-migration:

- Extension availability: confirm extensions you use are available in MotherDuck's environment.
- Secret management: local credential `SET` statements should be replaced with MotherDuck's managed credential UI for cloud storage connections.
- Scheduled jobs: update connection strings in cron jobs, CI scripts, and application configs.

@feynman

Like migrating a SQLite app to a hosted Postgres instance — the data model does not change, only the connection target and credential management.

@card
id: wdd-ch12-c014
order: 14
title: MotherDuck and DuckLake Together
teaser: DuckLake and MotherDuck are complementary — MotherDuck manages the DuckLake catalog database while your Parquet data stays in your own object storage.

@explanation

DuckLake and MotherDuck are designed to work together, but each can be used independently. Their combination unlocks a specific architecture: MotherDuck manages the DuckLake catalog (a DuckDB file) while raw data files stay in the customer's own S3 or GCS bucket.

**The architecture:**

```
Your S3 bucket
└── parquet-data/
    ├── events/
    │   ├── part-0001.parquet
    │   └── part-0002.parquet
    └── users/
        └── part-0001.parquet

MotherDuck (cloud-hosted DuckDB)
└── my_catalog.duckdb   ← DuckLake catalog
    ├── table: events   → points at s3://your-bucket/parquet-data/events/
    └── table: users    → points at s3://your-bucket/parquet-data/users/
```

Creating the lakehouse:
```sql
-- On a MotherDuck connection
ATTACH 'md:my_catalog' AS lake (TYPE DUCKLAKE, DATA_PATH 's3://your-bucket/parquet-data/');

CREATE TABLE lake.events (id BIGINT, ts TIMESTAMP, payload JSON);
INSERT INTO lake.events SELECT * FROM read_parquet('s3://your-bucket/raw/events/*.parquet');
```

Data sovereignty split:
- **Catalog metadata** lives in MotherDuck (MotherDuck's storage, in your account).
- **Data files** live in your S3/GCS bucket (your account, your access controls, your billing).

This gives you MotherDuck's multi-user catalog sharing without sending raw data to MotherDuck's storage. Multiple MotherDuck users can query the catalog and read data directly from S3.

> [!info] DuckLake is the recommended path for teams that want the MotherDuck collaboration model but have compliance requirements around where raw data is stored. The catalog is metadata only — a few MB even for large lakes.

@feynman

Like a database storing file pointers rather than the files themselves — the catalog knows where everything is without holding the actual data, letting you keep data residency separate from query access.

