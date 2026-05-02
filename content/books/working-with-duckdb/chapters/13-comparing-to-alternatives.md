@chapter
id: wdd-ch13-comparing-to-alternatives
order: 13
title: Comparing DuckDB to Alternatives
summary: DuckDB vs SQLite, pandas, Polars, Spark, and cloud warehouses — the decision framework for picking the right tool and the gotchas to know before shipping.

@card
id: wdd-ch13-c001
order: 1
title: DuckDB vs SQLite — Same Model, Different Purpose
teaser: Both are embedded and file-backed with zero infrastructure, but SQLite is built for transactional row writes while DuckDB is built for analytical column scans.

@explanation

SQLite and DuckDB share the no-server, no-daemon, dependency-as-a-library model. That surface similarity makes the comparison feel closer than it is. Underneath, they are optimized for opposite workloads.

**SQLite strengths:**
- High-frequency single-row reads and writes (application state, user sessions, config storage)
- Mixed OLTP workloads from multiple concurrent writers (SQLite uses WAL-mode file locking)
- Minimal binary footprint (~600KB) — ideal for mobile apps and browser extensions
- Decades of production hardening and compatibility guarantees

**DuckDB strengths:**
- Analytical queries over millions of rows (`GROUP BY`, `SUM`, `AVG`, window functions)
- Scanning wide Parquet, CSV, or JSON files without importing them first
- Columnar vectorized execution — DuckDB runs `SELECT AVG(price) FROM orders` roughly 10–100x faster than SQLite on the same data at scale
- Parallel query execution across CPU cores

**When to reach for SQLite:**
- Your app writes individual records from user actions (inserts, updates, deletes)
- You need multiple concurrent writers
- Binary size or mobile deployment matters

**When to reach for DuckDB:**
- You are computing aggregations, running ETL, or querying file-based datasets
- Your read-to-write ratio is high and the reads are analytical in nature

> [!tip] Many mature applications use both: SQLite for application state and operational records, DuckDB for reporting, exports, and analytics over that same data.

@feynman

Like choosing between a filing cabinet and a spreadsheet — one is optimized for storing and retrieving individual records, the other for summarizing and aggregating across all of them.

@card
id: wdd-ch13-c002
order: 2
title: DuckDB vs pandas — SQL vs DataFrame Operations
teaser: Both run in-process on a single machine, but DuckDB's vectorized SQL engine beats pandas on memory efficiency and performance for analytical queries at medium-to-large scale.

@explanation

pandas is the default in-process analytics tool for Python data work. DuckDB is not a replacement — it is a better fit for a large subset of what pandas is used for.

**Where DuckDB wins over pandas:**
- **Memory efficiency.** pandas loads entire DataFrames into memory as dense NumPy arrays. DuckDB executes queries in chunks, spilling to disk when necessary. A 20GB CSV that crashes a pandas `read_csv` can be queried with DuckDB in a few seconds.
- **SQL expressiveness.** Complex `GROUP BY`, multi-table joins, and window functions are 5–20 lines of SQL versus 30–50 lines of chained pandas operations that are harder to read and debug.
- **Speed.** DuckDB's vectorized columnar engine typically outperforms pandas on aggregations by 5–50x on datasets above a few million rows.
- **No intermediate copies.** DuckDB can query a pandas DataFrame directly without copying it: `duckdb.query("SELECT * FROM df WHERE x > 10")`.

**Where pandas still wins:**
- Row-level iteration and imperative per-row logic
- Rich ecosystem of libraries that expect DataFrame inputs/outputs (scikit-learn, matplotlib, etc.)
- Quick exploratory manipulation at small scale where SQL syntax feels heavyweight

The common production pattern is pandas for ingestion and output formatting, DuckDB for the analytical heavy lifting in between.

```python
import duckdb, pandas as pd

df = pd.read_parquet("events.parquet")
result = duckdb.query("""
    SELECT user_id, COUNT(*) AS events, SUM(value) AS total
    FROM df
    GROUP BY user_id
    ORDER BY total DESC
    LIMIT 100
""").df()
```

@feynman

Like using SQL instead of nested for-loops to aggregate a database table — both arrive at the same answer, but one lets the engine do the optimization work.

@card
id: wdd-ch13-c003
order: 3
title: DuckDB vs Polars — Closest Competitors
teaser: Both are columnar, in-process, and fast on a single node — the real decision is SQL familiarity versus Polars' lazy API and expression system.

@explanation

Polars and DuckDB are the two strongest options for in-process analytical work in Python as of 2026. The performance difference on most workloads is small enough that it should not drive the decision.

**What they share:**
- Columnar, vectorized execution
- Single-node, in-process operation
- Zero-copy Arrow interoperability
- Roughly comparable performance on typical aggregation and join workloads
- Both handle datasets significantly larger than RAM through lazy/streaming execution

**When DuckDB wins:**
- Your team thinks in SQL — complex analytics that would be natural SQL are awkward in Polars' expression API
- You need to query files directly without loading them first (`SELECT * FROM 'data/*.parquet'`)
- You want a single API that works identically in Python, R, Node.js, and the browser (DuckDB-Wasm)
- You are joining across different file formats or sources (Parquet + CSV + a pandas DataFrame in one query)

**When Polars wins:**
- You prefer a typed DataFrame API over SQL strings — Polars expressions are checked at construction, SQL strings are checked at execution
- You need fine-grained control over the lazy execution plan without switching to SQL
- Your pipeline is pure Python and you want IDE autocompletion on transformation logic

Polars also has a tighter Python-native developer experience — errors are caught earlier, and the expression API composes more naturally in Python code. DuckDB's advantage is the SQL interface and multi-language consistency.

> [!info] DuckDB and Polars interoperate well via Arrow. Running a DuckDB query that returns a Polars DataFrame, or feeding a Polars LazyFrame into DuckDB, is a single function call on either side.

@feynman

Like choosing between writing a complex calculation as a spreadsheet formula versus as Python code — both produce the same result, but one fits your team's mental model better.

@card
id: wdd-ch13-c004
order: 4
title: DuckDB vs Spark — The Scale Threshold Question
teaser: Spark handles petabyte-scale distributed workloads; DuckDB handles single-node workloads up to roughly 500GB comfortably — the question is whether you actually need the cluster.

@explanation

Spark is the default answer for big data in enterprise environments. It is also dramatically over-engineered for the majority of analytical workloads that teams actually run.

**DuckDB's realistic ceiling:**
- A modern laptop (32–64GB RAM, NVMe SSD) handles DuckDB queries over ~500GB comfortably with spill-to-disk
- A single high-memory cloud instance (192–384GB RAM, like an `r7i.8xlarge`) pushes DuckDB to the multi-terabyte range
- For most analytics teams, 80–90% of their queries run over datasets well under 500GB

**Spark's actual cost:**
- Cluster provisioning, scaling, and management overhead
- 5–15 minute startup times on EMR/Databricks for job initialization
- Complex debugging — stacktraces span cluster executors, shuffle failures are opaque
- Serialization overhead — data moves between JVM processes on different nodes
- Cost: a small Spark cluster runs $200–$1,000/day depending on scale

**When to graduate from DuckDB to Spark:**
- Your dataset is reliably in the multi-terabyte range and growing
- You need distributed writes to Iceberg or Delta at high throughput from parallel sources
- Your organization already runs a Databricks or EMR environment with existing tooling

**When to stay on DuckDB:**
- Single-machine queries finish in acceptable time
- Your team does not have Spark expertise on staff
- The dataset fits on a high-memory instance

> [!warning] A common mistake: migrating to Spark because a query "feels big" rather than because it measured too slow on DuckDB. Benchmark on DuckDB first. The Spark operational overhead is a steep price for marginal scale gains most teams never need.

@feynman

Like choosing between a motorcycle and a semi-truck to deliver packages across town — the truck can carry more, but the overhead of operating it is only worth it if you actually have that much cargo.

@card
id: wdd-ch13-c005
order: 5
title: DuckDB vs Cloud Warehouses — Local vs Managed
teaser: Cloud warehouses (Snowflake, BigQuery, Redshift) add multi-user access, managed scaling, and collaboration — DuckDB trades those for zero cost, zero latency, and no egress fees.

@explanation

Cloud warehouses are the right tool for multi-user analytics at organizational scale. DuckDB is the right tool when you do not need what the warehouse provides.

**What cloud warehouses provide that DuckDB does not:**
- **Multi-user concurrent writes.** Dozens of pipelines writing simultaneously without coordination.
- **Managed scaling.** BigQuery scales to petabytes without a single capacity decision.
- **Collaboration.** Shared catalogs, role-based access control, query history, shared dashboards.
- **SLA and durability.** Managed replication, point-in-time recovery, 99.9%+ uptime guarantees.

**What DuckDB provides that warehouses do not:**
- **Zero egress cost.** Moving 100GB out of BigQuery costs roughly $60. Moving 100GB from a local Parquet file costs nothing.
- **Zero query latency.** No round-trip to a cloud API, no cold start on a serverless warehouse, no queue time.
- **Offline capability.** DuckDB works without a network connection. A warehouse does not.
- **Zero monthly cost for development.** Local DuckDB for development, CI, and one-person analytics workflows costs nothing.

**DuckDB's ceiling for warehouse replacement:**
- Single writer, so high-throughput concurrent ingestion pipelines require coordination
- No built-in access control beyond filesystem permissions
- No shared catalog for multiple users without MotherDuck

MotherDuck (the DuckDB cloud offering) closes some of this gap — it adds multi-user sharing, a web UI, and hybrid local+cloud execution — while retaining the DuckDB SQL interface.

@feynman

Like the difference between a local dev server and a production cloud deployment — local is cheaper and faster for development, but the managed service exists because collaboration and scale require it.

@card
id: wdd-ch13-c006
order: 6
title: Single-Writer Concurrency Gotcha
teaser: DuckDB allows only one writer at a time — two processes attempting concurrent writes throw an error immediately, and the fix requires architectural coordination, not a config flag.

@explanation

DuckDB's single-writer constraint is the most common source of production surprises. It is not a bug or a limitation that will be removed — it is a fundamental property of the embedded, file-locking model.

**What happens:**
When a second process tries to open a DuckDB file in write mode while another process already holds the write lock, it throws immediately:

```
duckdb.duckdb.IOException: IO Error: Could not set lock on file
"mydb.duckdb": Resource temporarily unavailable
```

**What breaks:**
- Running two data pipeline workers simultaneously writing to the same file
- A notebook writing to a database file that a background script also writes to
- Docker containers sharing a mounted volume with a DuckDB file
- CI jobs running in parallel that share a fixture database

**Workarounds:**

- **Separate files per writer.** Each process writes to its own DuckDB file, and a merge step combines them periodically.
- **Read-only connections for readers.** Use `duckdb.connect('mydb.duckdb', read_only=True)` for processes that only need to read. Multiple read-only connections work simultaneously while a writer holds the lock.
- **External write coordination.** Use a file lock, a queue, or a process manager to serialize writes to a shared DuckDB file.
- **Use MotherDuck.** The managed offering adds multi-user write coordination on top of DuckDB.

> [!warning] The error surfaces at runtime, not at connection time, if the write happens after a delay. Test your concurrency patterns explicitly — do not assume a workflow is single-writer without verifying it.

@feynman

Like a single-threaded write queue — the architecture guarantees consistency, but you must design around the constraint rather than expecting it to disappear.

@card
id: wdd-ch13-c007
order: 7
title: Cross-Platform File Path Gotchas
teaser: DuckDB uses the native OS path separator, so hardcoded Windows backslashes break on other platforms — use forward slashes or pathlib consistently.

@explanation

File path handling in DuckDB is handled by the OS, not DuckDB itself. This creates platform-specific surprises when SQL strings contain hardcoded paths.

**The Windows backslash problem:**
```sql
-- Works on Windows, breaks on Linux/macOS
SELECT * FROM 'C:\Users\alice\data\events.parquet';

-- Works everywhere
SELECT * FROM 'C:/Users/alice/data/events.parquet';
```

DuckDB accepts forward slashes on Windows as well as backslashes, so using forward slashes is the portable convention.

**Glob patterns and path separators:**
```sql
-- Portable glob
SELECT * FROM 'data/**/*.parquet';

-- Windows-specific — avoid this in shared code
SELECT * FROM 'data\**\*.parquet';
```

**Relative vs absolute paths:**
DuckDB resolves relative paths relative to the process working directory, not the database file location. If your script changes working directory during execution, relative paths in SQL can resolve to unexpected locations. Prefer absolute paths in production code.

**Symlink behavior:**
DuckDB follows symlinks. If a Parquet file is a symlink to a different location, DuckDB reads the target. This is usually correct, but be aware when debugging "why is this query reading old data" issues after a symlink swap.

**Pathlib integration in Python:**
```python
from pathlib import Path
data_dir = Path("/data/processed")
duckdb.query(f"SELECT * FROM '{data_dir / 'events.parquet'}'")
```

`pathlib.Path` objects produce forward-slash strings on all platforms when embedded in f-strings via `as_posix()`, or simply via `str()` on macOS/Linux.

> [!tip] For maximum portability, use `Path.as_posix()` when constructing DuckDB path strings from Python `pathlib` objects.

@feynman

Like Python's `os.path.join` vs hardcoded `/` — the system will let you hardcode it, but portable code uses the abstraction.

@card
id: wdd-ch13-c008
order: 8
title: Memory Configuration Gotchas
teaser: DuckDB defaults to 80% of available RAM, which causes silent spill-to-disk or OOM errors on shared machines — always set memory_limit explicitly in production.

@explanation

DuckDB's default memory limit is 80% of available system RAM. On a developer laptop with 32GB, that is fine. On a shared CI runner with 8GB and five parallel jobs, that is a recipe for OOM kills.

**The default behavior:**
- DuckDB uses up to 80% of detected RAM for in-memory query processing
- When that limit is hit, it spills to a temporary directory on disk
- Spill is silent — no warning, no error — just slower queries
- If temp disk space is also exhausted, the query throws `Out of Memory` and fails

**Setting the limit explicitly:**
```sql
SET memory_limit = '4GB';
SET temp_directory = '/tmp/duckdb_spill';
```

Or in Python at connection time:
```python
con = duckdb.connect()
con.execute("SET memory_limit = '4GB'")
con.execute("SET temp_directory = '/tmp/duckdb_spill'")
```

**Common production configurations:**

For a CI runner with 8GB total RAM and multiple parallel jobs:
```sql
SET memory_limit = '2GB';
SET threads = 2;
```

For a dedicated analytics server with 128GB RAM:
```sql
SET memory_limit = '100GB';
SET threads = 16;
```

**Detecting spill:**
Enable progress reporting to see when spill is happening:
```sql
PRAGMA enable_progress_bar;
```

Or query the current settings:
```sql
SELECT current_setting('memory_limit'), current_setting('temp_directory');
```

> [!warning] On containerized environments (Docker, Kubernetes), DuckDB detects the host machine's total RAM, not the container's memory limit. Set `memory_limit` explicitly to a value within your container's cgroup limit or you will OOM the container.

@feynman

Like setting `ulimit` for a process — the system has a default that works on a dedicated machine but breaks in shared or constrained environments unless you configure it explicitly.

@card
id: wdd-ch13-c009
order: 9
title: Type Coercion Surprises
teaser: DuckDB's "friendly" type coercion silently converts mismatched types at query time — helpful in exploration, dangerous in production pipelines where schema drift needs to surface as errors.

@explanation

DuckDB implements what the documentation calls "friendly SQL" — automatic type coercion that makes exploratory queries more forgiving. In production pipelines, this same friendliness masks data quality issues.

**What friendly coercion does:**
```sql
-- DuckDB coerces the string '42' to INTEGER automatically
SELECT 100 + '42';  -- returns 142

-- Coerces string to DATE
SELECT * FROM events WHERE event_date > '2024-01-01';
-- Works even if event_date is VARCHAR, not DATE
```

**Where this causes problems:**
A pipeline ingesting CSV files may silently coerce a column that should be strictly `INTEGER` but contains occasional strings like `'N/A'` or `''`. DuckDB attempts conversion; if it fails, it returns `NULL` without error by default in some contexts.

**The `TRY_CAST` vs `CAST` distinction:**
```sql
-- CAST raises an error on failure — use this in production pipelines
SELECT CAST(raw_value AS INTEGER) FROM staging;

-- TRY_CAST returns NULL on failure — use for intentional nullable coercion
SELECT TRY_CAST(raw_value AS INTEGER) FROM staging;
```

**Enforcing strict types on CSV ingestion:**
```sql
-- Explicitly specify column types to disable auto-detection
SELECT * FROM read_csv('data.csv',
    columns = {'id': 'INTEGER', 'amount': 'DECIMAL(10,2)', 'created_at': 'TIMESTAMP'}
);
```

**Schema drift detection:**
Add assertions to your pipeline:
```sql
SELECT COUNT(*) FROM staging WHERE TRY_CAST(amount AS DECIMAL(10,2)) IS NULL AND amount IS NOT NULL;
-- Should return 0 — any non-zero result means coercion would lose data
```

> [!warning] Relying on DuckDB's auto-coercion in a production ETL pipeline without explicit type assertions is a data quality time bomb. Friendly coercion is for exploration; explicit types and `CAST` are for production.

@feynman

Like Python's implicit `int` to `float` coercion — convenient in interactive use, but a hidden bug in code that expects type-safe contracts between components.

@card
id: wdd-ch13-c010
order: 10
title: Choosing DuckDB — The Decision Checklist
teaser: DuckDB is the right tool for a specific pattern of workloads — this checklist surfaces the signals that predict whether it will serve you well or frustrate you.

@explanation

DuckDB is the right tool when all or most of these are true:

**Green lights:**
- Your query workload is predominantly analytical — aggregations, joins, GROUP BY, window functions
- Your dataset fits on a single machine (comfortably under 500GB; push to multi-TB with a large instance and explicit memory config)
- You have one writer at a time, or can architect for it
- You want to query files (Parquet, CSV, JSON, Delta, Iceberg) without a separate import step
- You are building a script, notebook, CLI tool, or embedded analytics feature
- You want identical SQL semantics across Python, R, Node.js, and the browser
- Egress costs, latency, or offline capability matter

**Red lights — reach for something else:**
- Multiple concurrent writers are a hard requirement (reach for PostgreSQL or a managed warehouse)
- Your workload is OLTP — frequent single-row reads and writes from many concurrent clients (reach for SQLite or PostgreSQL)
- Your dataset is reliably in the multi-terabyte range and you need distributed processing (reach for Spark or a warehouse)
- You need row-level security, user management, or audit logging built into the database layer (reach for PostgreSQL or a warehouse)
- You need full-text search as a primary workload at large scale (reach for Elasticsearch or PostgreSQL with `tsvector`)

**The one-question heuristic:**
Would this be naturally expressed as a SQL query over files or tables, run by one process at a time? If yes, DuckDB is almost certainly the right choice.

> [!info] The most common DuckDB mistake is not using it when it would be perfect, because the team defaulted to their existing tool (pandas, Spark, a warehouse) out of familiarity. Benchmark DuckDB before assuming you need something heavier.

@feynman

Like the Unix philosophy of using the simplest tool that solves the problem — DuckDB is that tool for single-node analytical SQL, and reaching past it before you need to adds cost without adding value.
