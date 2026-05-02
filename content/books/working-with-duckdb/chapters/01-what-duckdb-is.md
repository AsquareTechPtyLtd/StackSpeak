@chapter
id: wdd-ch01-what-duckdb-is
order: 1
title: What DuckDB Is (and Isn't)
summary: DuckDB's design choices — embedded, columnar, OLAP-only — explain both what it's exceptional at and where you should use something else.

@card
id: wdd-ch01-c001
order: 1
title: The One-Sentence Positioning
teaser: DuckDB is an embedded analytical SQL database — think SQLite, but built for column-scanning analytics instead of row-by-row OLTP.

@explanation

DuckDB occupies a narrow, specific slot in the database landscape. Understanding that slot prevents both under-use (reaching for Pandas when DuckDB would be faster) and over-use (building a multi-user SaaS backend on it).

The key properties:

- **Embedded:** no server process, no network socket, no daemon to manage. The database engine runs inside your application or script as a library.
- **Columnar storage:** data is organized by column, not by row. Aggregations and scans over a few columns of a wide table are dramatically faster than row-oriented storage.
- **OLAP-oriented:** designed for analytical queries — GROUP BY, aggregations, window functions, range joins — not for high-concurrency point-read/write workloads.
- **In-process:** the SQL engine runs in the same process as your Python, R, Node.js, or Go code. No serialization overhead for local data.

What it is not:

- Not a replacement for PostgreSQL or MySQL for transactional application backends.
- Not a distributed system — one node, one writer.
- Not a streaming processor — it processes data at rest, not in-flight events.

DuckDB 1.0 (released mid-2024) marked the first ABI-stable release. DuckDB 1.1 followed in late 2024, adding Delta Lake support and further stabilizing the extension API.

@feynman

DuckDB is to analytical queries what SQLite is to transactional queries — an embedded engine you include as a dependency rather than a service you deploy.

@card
id: wdd-ch01-c002
order: 2
title: Embedded vs Server — What the Distinction Actually Means
teaser: "Embedded" means the database engine is a library linked into your process, not a server you connect to over a socket — that changes the operational model entirely.

@explanation

Most databases people know — PostgreSQL, MySQL, ClickHouse, BigQuery — are servers. You run a process, it listens on a port, and clients connect to it. DuckDB is a library.

What changes with the embedded model:

- **No deployment.** There is no DuckDB server to provision, patch, scale, or restart. `pip install duckdb` and you have a full analytical SQL engine.
- **No network hop.** Data you already have in memory (a Pandas DataFrame, a Polars LazyFrame, an Arrow table) can be queried by DuckDB without serialization or network transfer.
- **Process-local.** If your Python script dies, DuckDB dies with it. There is no shared state across processes — by design.
- **Single writer.** Because there is no server arbitrating writes, only one process can write to a DuckDB file at a time. Multiple readers are supported with appropriate locking.

The embedded model is why DuckDB excels in:
- Data science notebooks and scripts
- CLI tools that need to query files
- CI pipelines that run analytical assertions on test data
- Edge analytics where deploying a server is impractical

> [!info] DuckDB's in-memory mode (`duckdb.connect(':memory:')`) leaves no file on disk at all. Useful for one-shot transformations and test fixtures.

@feynman

Like SQLite vs MySQL — one is a file you include, the other is a service you run; the tradeoffs that follow from that choice define everything else.

@card
id: wdd-ch01-c003
order: 3
title: OLAP vs OLTP — Why the Distinction Matters for DuckDB
teaser: DuckDB's columnar layout makes table scans fast and point lookups slow — that's not a bug, it's the core design tradeoff.

@explanation

**OLTP (Online Transaction Processing):** workloads dominated by single-row reads and writes. A web application hitting its database for user sessions, orders, and product details. Row-oriented storage is optimal — you need all columns for a given row.

**OLAP (Online Analytical Processing):** workloads dominated by aggregations over many rows but few columns. `SELECT region, SUM(revenue) FROM orders GROUP BY region` scans one column out of fifty on a million-row table. Columnar storage is optimal.

DuckDB is columnar. That means:

- `SELECT AVG(price) FROM products` — fast. Reads one column, ignores the rest.
- `SELECT * FROM orders WHERE id = 12345` — slower relative to PostgreSQL. Must reconstruct the row from column segments.
- `SELECT city, COUNT(*) FROM events GROUP BY city` — fast. Aggregation over one column.
- `INSERT INTO orders VALUES (...); INSERT INTO orders VALUES (...)` — slower than Postgres for high-frequency individual inserts.

This is not a limitation to work around — it is the design. Use DuckDB where OLAP patterns dominate. Use PostgreSQL or SQLite where OLTP patterns dominate.

> [!warning] If your use case involves thousands of single-row inserts per second from concurrent clients, DuckDB is the wrong tool. The single-writer constraint and columnar layout are both working against you.

@feynman

Like a spreadsheet vs a filing cabinet — the spreadsheet lets you sum a column instantly, but looking up one specific row takes more effort than a system built for exactly that.

@card
id: wdd-ch01-c004
order: 4
title: When to Reach for DuckDB
teaser: DuckDB fits a specific set of situations well — knowing them by pattern saves the decision-making overhead each time.

@explanation

Reach for DuckDB when:

- **You are querying files.** Parquet, CSV, JSON on local disk or remote storage. DuckDB can query them directly without importing into a separate database.
- **You need SQL over Pandas/Polars data.** Join or aggregate DataFrames without leaving Python or writing NumPy indexing chains.
- **You are building a CLI or notebook tool.** No infrastructure to manage; the engine is a dependency.
- **You are doing ETL/ELT locally.** Transform a 50GB Parquet file on a laptop or CI runner without spinning up a warehouse.
- **You need embedded analytics in an application.** Ship a desktop or server-side app that queries analytical data without requiring a separate database server.
- **You want to test data pipelines cheaply.** Run full analytical assertions in CI against a local DuckDB instance instead of hitting a cloud warehouse.
- **You are building on a lake-format dataset.** DuckDB's Iceberg and Delta Lake readers (both stable in DuckDB 1.1) let you query table formats in place.

Do not reach for DuckDB when:

- Multiple concurrent writers are needed.
- You need row-level locking and transactions from concurrent clients.
- You need full-text search as a primary workload (though the FTS extension helps at small scale).
- Your data is purely relational OLTP — there is no analytical query pattern in sight.

@feynman

Like a Swiss army knife for data files — it does not replace a professional chef's knife for daily kitchen work, but it handles everything else surprisingly well.

@card
id: wdd-ch01-c005
order: 5
title: DuckDB 1.0 and Stability Commitments
teaser: DuckDB 1.0 marked the first ABI-stable release — what that means for extension authors, language binding maintainers, and anyone building on DuckDB in 2026.

@explanation

DuckDB 1.0 shipped in June 2024. Before 1.0, the extension API and file format could change between minor versions, breaking third-party extensions and requiring file re-creation.

What 1.0 stabilized:

- **Storage format stability.** A `.duckdb` file created by 1.0 can be read by 1.1 and beyond without migration.
- **C API stability.** The C extension API is now versioned and backward compatible across 1.x releases. Extensions compiled for DuckDB 1.0 load on DuckDB 1.1.
- **Extension API contracts.** The community extension registry (extensions.duckdb.org) can ship pre-compiled binaries because the ABI is stable.

What 1.0 did not change:

- The single-writer constraint. Still one concurrent writer per file.
- The OLAP-only positioning. DuckDB is not trying to become a general-purpose database.
- The dependency-free ethos. The core library still has zero dependencies beyond the C++ standard library.

DuckDB 1.1 (late 2024) added:
- Delta Lake support via the community `delta` extension.
- Iceberg read support promoted to the core distribution.
- Improved Arrow IPC streaming performance.

In 2026, DuckDB's version cadence runs roughly one minor release per quarter. Check the GitHub releases page for the current stable version.

> [!info] If you are pinning a DuckDB version in a production pipeline, pin to a patch version (e.g., `duckdb==1.1.3`) and test before upgrading — minor releases occasionally change query planner behavior that can affect performance-sensitive queries.

@feynman

Like a library reaching 1.0 on npm — it signals that the author is committing to not breaking you on every update, even if the internals keep improving.

@card
id: wdd-ch01-c006
order: 6
title: Production Use Cases in 2026
teaser: DuckDB has moved well beyond notebooks — in 2026 it runs in production pipelines, analytics backends, edge deployments, and ML feature stores.

@explanation

DuckDB's production footprint has expanded substantially since 1.0. Common patterns seen in production in 2026:

**Embedded analytics in applications:**
An application server runs DuckDB in-process to power dashboards and reporting. No separate analytics warehouse required. Works well when the dataset fits in a few GB and latency matters more than extreme scale.

**Lake-format query engine:**
DuckDB replaces Spark for small-to-medium Iceberg or Delta Lake queries. A team with a 200GB Delta table on S3 can query it with DuckDB on a single EC2 instance faster and cheaper than Spark for most ad-hoc queries.

**ML feature engineering:**
DuckDB's Python API and zero-copy Arrow integration make it fast for feature computation pipelines. Compute aggregations over event data, join with entity tables, and hand off to a training framework without intermediate file writes.

**CI data quality assertions:**
Test suites run DuckDB against fixture data to assert pipeline correctness. No warehouse credentials required in CI — just a file and a DuckDB binary.

**Edge analytics:**
DuckDB-Wasm runs in the browser, enabling client-side analytical queries over downloaded datasets. No server required for read-only analytics products.

> [!tip] For teams with datasets under ~500GB and no concurrency requirements, DuckDB + local or S3-backed Parquet files replaces a managed warehouse for a large fraction of use cases at a fraction of the cost.

@feynman

Like how SQLite powers millions of production apps that never needed PostgreSQL — DuckDB is proving the same point for the analytical tier.

@card
id: wdd-ch01-c007
order: 7
title: Common Gotchas Before You Begin
teaser: Most DuckDB surprises come from three things — the single-writer constraint, file path handling, and default memory limits — all fixable once you know about them.

@explanation

**Single-writer constraint:**
Only one process can open a DuckDB file in write mode at a time. Attempting to open the same file from two processes simultaneously throws an error. If you need read access from multiple processes while a writer is running, use DuckDB's read-only mode: `duckdb.connect('mydb.duckdb', read_only=True)`.

**Cross-platform file paths:**
DuckDB path handling is the platform's native path handling. On Windows, backslash separators in hardcoded path strings cause issues in some contexts. Use forward slashes or `pathlib.Path` objects consistently.

**Default memory limit:**
DuckDB defaults to using 80% of available RAM. On a shared machine (CI runner, containerized environment), this can cause OOM errors when multiple processes run simultaneously. Set it explicitly:
```sql
SET memory_limit = '4GB';
```
Or via Python: `con.execute("SET memory_limit='4GB'")`.

**WAL behavior:**
DuckDB uses a write-ahead log (WAL file, `.duckdb.wal`). If a process is killed mid-write, the WAL is replayed on next open. This is correct behavior, not corruption — but it means the `.duckdb` and `.duckdb.wal` files must travel together.

**Thread count:**
DuckDB parallelizes queries across CPU cores automatically. On shared machines, cap threads to avoid resource contention: `SET threads = 4`.

> [!warning] Committing a `.duckdb` file to git without the accompanying `.duckdb.wal` file (if one exists) can leave the database in an inconsistent state on checkout. Add both to `.gitignore` for ephemeral databases.

@feynman

Like learning Git's detached HEAD state — slightly surprising the first time, completely predictable once you understand the model, never a problem again.

@card
id: wdd-ch01-c008
order: 8
title: DuckDB vs SQLite — Understanding the Overlap
teaser: Both are embedded, zero-dependency, file-backed databases — but their storage models, query performance profiles, and intended workloads are fundamentally different.

@explanation

DuckDB and SQLite are often compared because they share the embedded, no-server model. The comparison ends there.

**Storage model:**
- SQLite: row-oriented B-tree storage. Optimal for point reads, single-row writes, mixed workloads.
- DuckDB: columnar PAX (Partition Attributes Across) layout. Optimal for scans, aggregations, analytical queries.

**Concurrency:**
- SQLite: supports multiple concurrent readers and one concurrent writer via file locking.
- DuckDB: supports multiple concurrent readers and one concurrent writer. Similar at the surface, but DuckDB's read isolation model is different — readers see a consistent snapshot via MVCC.

**Query engine:**
- SQLite: volcano-model (row-at-a-time) query execution.
- DuckDB: vectorized (batch-at-a-time) query execution, with parallel query support across CPU cores.

**When SQLite wins:**
- Application config/state storage.
- Mixed read-write from an application backend.
- Mobile apps, browser extensions, any environment where extreme binary size matters.

**When DuckDB wins:**
- Analytical queries over large datasets.
- File format queries (Parquet, CSV, JSON).
- ETL/ELT transforms in scripts and pipelines.

> [!tip] Some teams use both in the same project — SQLite for application state (user preferences, session data) and DuckDB for analytics (usage reports, data exports). They are complementary, not competing.

@feynman

Like a row-store vs a column-store in a warehouse context — the technology difference explains the performance difference, not just marketing claims.

@card
id: wdd-ch01-c009
order: 9
title: The Zero-Dependency Philosophy
teaser: DuckDB's core library ships with no external dependencies — understanding why that choice was made explains the design constraints it creates.

@explanation

DuckDB's core library (`libduckdb`) has zero runtime dependencies beyond the C++ standard library. No OpenSSL, no zlib, no protobuf. The entire SQL engine, columnar storage, query optimizer, and built-in type system compile to a single shared library or static binary.

Why this matters:

- **Portability.** A DuckDB binary built for Linux x86_64 runs on any Linux x86_64 without dependency installation. This makes it practical for CI runners, Lambda functions, and edge deployments.
- **WASM build.** The no-dependency constraint made the DuckDB-Wasm build feasible. The browser has no package manager — you get one bundle and it must work.
- **Predictable behavior.** No underlying library upgrades silently change behavior. DuckDB's behavior changes only when DuckDB's version changes.

The constraint it creates:

Network and cloud storage access (S3, GCS, Azure) is provided by the `httpfs` extension — an optional extension, not part of the core. This keeps the core dependency-free while still enabling cloud access for users who need it.

Similarly, Excel read/write, full-text search, and spatial data support are all extensions. The core stays lean; users load only what they need.

> [!info] DuckDB-Wasm ships at around 7MB compressed. That's a full analytical SQL engine in a browser bundle smaller than many JavaScript frameworks.

@feynman

Like a Go binary that compiles to a single static file — the portability comes directly from the no-external-dependency constraint.

@card
id: wdd-ch01-c010
order: 10
title: The DuckDB Ecosystem in 2026
teaser: DuckDB has grown from a research project into an ecosystem with a managed cloud offering, a community extension registry, and official bindings for every major language.

@explanation

DuckDB's ecosystem in 2026 spans several layers:

**Core engine and bindings:**
Official, first-party language bindings with roughly equivalent feature coverage: Python (`duckdb`), R (`duckdb`), Node.js/Bun (`duckdb`), Java/Kotlin (JDBC driver), Go (`go-duckdb`), Rust (`duckdb-rs`), C/C++ (native), and DuckDB-Wasm (browser).

**Extension registry:**
A community extension registry at `extensions.duckdb.org` hosts pre-compiled extensions. Users install them with `INSTALL extension_name; LOAD extension_name;`. Key extensions: `httpfs`, `spatial`, `fts` (full-text search), `iceberg`, `delta`, `excel`, `json`, `parquet` (built-in but listed for completeness).

**MotherDuck:**
The managed cloud offering built on DuckDB. Adds multi-user access, a web UI, shared databases, and hybrid local+cloud query execution. A DuckDB connection string starting with `md:` connects to MotherDuck instead of a local file.

**DuckLake:**
A 2025-introduced open table format specification designed around DuckDB's strengths — a simpler alternative to Iceberg for DuckDB-centric architectures.

**Tooling:**
`dbt-duckdb` (dbt adapter), `evidence` (DuckDB-backed BI tool), `Rill` (DuckDB-backed embedded analytics), and dozens of community tools built around the DuckDB Python API.

@feynman

Like the SQLite ecosystem but with a managed cloud tier and a richer analytics-oriented tooling layer built on top.

@card
id: wdd-ch01-c011
order: 11
title: Honest Limitations
teaser: DuckDB's constraints are real — single-writer, no built-in replication, limited full-text search, and no row-level security — knowing them prevents architectural surprises.

@explanation

DuckDB's constraints are worth naming directly:

**Single writer at a time.** This is the most impactful constraint for multi-process or multi-user applications. There is no write-concurrency — one process holds the write lock. Reads can be concurrent via read-only connections, but writes cannot be.

**No built-in replication.** DuckDB has no native replication or high-availability story. If the machine running DuckDB fails, data recovery is from backups only. For HA, back the database file with a replicated storage layer (S3, a RAID volume).

**No row-level security.** DuckDB does not have a built-in user/role/permission system with row-level security policies like PostgreSQL. It relies on the calling process having appropriate filesystem-level access to the database file.

**Full-text search is limited.** The `fts` extension provides basic full-text search, but it is not competitive with Elasticsearch or even PostgreSQL's `tsvector` search for large text corpora. Use a dedicated search engine if FTS is a primary workload.

**Not designed for streaming inserts.** High-frequency single-row inserts are slow compared to batch inserts. If you have a stream of incoming events, batch them before writing to DuckDB.

**Memory-intensive on very wide tables.** Vectorized columnar processing loads full column chunks into memory. Very wide tables (200+ columns) with large scans can use more memory than expected.

> [!warning] Do not use DuckDB as a production OLTP backend for a multi-user application. The single-writer constraint will become the bottleneck long before any other limit is reached.

@feynman

Like a single-threaded event loop — it processes requests extremely efficiently one at a time, but it was never designed to handle concurrent writes from many clients simultaneously.

@card
id: wdd-ch01-c012
order: 12
title: Selecting the Right Mental Model
teaser: The most accurate mental model for DuckDB is "a SQL engine over files" — not a database you install, not a data warehouse you provision.

@explanation

Mental model drift causes most DuckDB misuse. The three wrong mental models and why they fail:

**Wrong: "DuckDB is like PostgreSQL but faster."**
PostgreSQL is a server with concurrent write support, row-level security, logical replication, and a OLTP-first design. DuckDB has none of those. The SQL dialect looks similar but the operational model is entirely different.

**Wrong: "DuckDB is a data warehouse."**
A warehouse (Snowflake, BigQuery, Redshift) is a managed, multi-user, scalable service. DuckDB is single-node, single-writer, and embedded. It does analytical queries well, but it is not warehouse-scale by default.

**Wrong: "DuckDB is just a faster Pandas."**
Pandas is a dataframe library. DuckDB is a SQL engine. They have different APIs, different mental models, and different strengths. They interoperate well, but DuckDB is not a pandas replacement — it is a complement.

**Right: "DuckDB is a SQL engine over files."**
Point it at Parquet files, CSV files, JSON files, Delta tables, or Iceberg catalogs. Run SQL over them with full query optimizer and vectorized execution. Get results back in Python, R, Arrow, or any other format. No server, no cluster, no credentials beyond filesystem or object storage access.

This mental model correctly predicts:
- When DuckDB is fast (file scans, aggregations, joins over columnar data)
- When DuckDB is constrained (concurrent writes, FTS, OLTP)
- How to integrate DuckDB (as a library, not a service)

@feynman

Like `grep` or `jq` but for structured tabular data — a tool you run over files, not a service you connect to.

@card
id: wdd-ch01-c013
order: 13
title: DuckDB's Origin and Why It Matters
teaser: DuckDB came out of academic database research at CWI Amsterdam — that origin explains the quality of the query optimizer and the deliberate, constraint-driven design.

@explanation

DuckDB was created at the Centrum Wiskunde & Informatica (CWI) in Amsterdam by Mark Raasveldt and Hannes Mühleisen, released as open source in 2019. The initial paper, "DuckDB: an Embeddable Analytical Database," was published at SIGMOD 2019.

The research origins have practical implications:

- **Query optimizer quality.** DuckDB's optimizer is based on academic state-of-the-art — it uses a dynamic programming join order optimizer by default, which significantly outperforms heuristic-based optimizers on complex multi-table queries.
- **Vectorized execution.** The execution engine is a direct implementation of vectorized query processing research, executing in 2048-row batches by default rather than row-at-a-time.
- **Deliberate constraints.** The "embedded only" and "OLAP only" constraints are intentional. The researchers explicitly did not want to build another general-purpose database — they wanted to demonstrate that an embedded analytical database could match or beat server-based systems for analytical workloads.

DuckDB GmbH was founded in 2021 to commercialize MotherDuck and provide enterprise support. The core DuckDB engine remains MIT-licensed and open source.

The MIT license means:
- Use in commercial products without royalty.
- Modify the source without disclosing modifications.
- The license is business-friendly.

> [!info] The SIGMOD 2019 paper is publicly available and worth reading — it explains the design decisions in detail and is unusually clear for a database systems paper.

@feynman

Like V8 coming from Google's research investment in JavaScript performance — the academic rigor behind it is why the results outperform what you'd expect from a side project.
