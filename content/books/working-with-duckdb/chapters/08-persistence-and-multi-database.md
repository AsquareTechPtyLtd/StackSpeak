@chapter
id: wdd-ch08-persistence-and-multi-database
order: 8
title: Persistence and Multi-Database
summary: How DuckDB stores data on disk, the difference between in-memory and file-backed databases, and how to work with multiple attached databases simultaneously.

@card
id: wdd-ch08-c001
order: 1
title: In-Memory Database Mode
teaser: A DuckDB in-memory database lives entirely in RAM — fast, zero file I/O, and completely gone when the connection closes.

@explanation

The simplest way to open DuckDB is with no file at all:

```python
import duckdb

con = duckdb.connect(':memory:')
con.execute("CREATE TABLE events (id INTEGER, name VARCHAR)")
con.execute("INSERT INTO events VALUES (1, 'click')")
```

Or equivalently — the default when you call `duckdb.connect()` with no arguments is also in-memory.

When to use in-memory mode:

- **Unit tests and fixtures.** Create a fresh schema, run your test, and discard it. No cleanup needed.
- **One-shot ETL.** Read a file, transform it, write the result somewhere else. The intermediate state does not need to survive.
- **Exploratory analysis.** Spin up a connection in a notebook, query a few CSVs, and throw the connection away.
- **CI pipelines.** No disk writes, no leftover files, no cleanup step.

The lifecycle is explicit: data exists as long as the connection object exists. When the connection is garbage-collected or `.close()` is called, all data is gone.

Memory implications: in-memory mode still uses DuckDB's vectorized engine and will spill to temporary disk files if a query exceeds the memory limit. `:memory:` means "no persistent file," not "guaranteed to fit in RAM."

> [!info] Two separate `duckdb.connect(':memory:')` calls create two completely isolated databases — they do not share state. If you need multiple connections to the same in-memory database, use `duckdb.connect()` (no argument) and share the connection object.

@feynman

Like an in-memory SQLite database — it is a fully functional database engine with no backing file, useful for exactly the same reasons: fast tests, throwaway transforms, and ephemeral state.

@card
id: wdd-ch08-c002
order: 2
title: File-Backed Database
teaser: Pass a file path to `duckdb.connect()` and DuckDB creates a persistent `.duckdb` file that survives process restarts and is portable across platforms.

@explanation

Creating or opening a persistent database is identical to in-memory — you just supply a path:

```python
con = duckdb.connect('analytics.duckdb')
```

```sql
-- From the CLI:
duckdb analytics.duckdb
```

If the file does not exist, DuckDB creates it. If it does exist, DuckDB opens it. The same path argument works across Python, the CLI, Node.js, Go, and every other binding.

What the file contains:

- **The schema** — all table definitions, views, macros, and sequences.
- **The data** — all rows, stored in DuckDB's columnar PAX format.
- **The catalog** — internal metadata linking it all together.

Persistence guarantees:

- Data committed via a transaction is durable once `COMMIT` returns (or once an auto-committed statement completes).
- The `.duckdb` file is a standalone file — copy it to another machine and DuckDB opens it without any migration step.
- The format is platform-independent. A file created on macOS opens on Linux or Windows.

> [!tip] DuckDB 1.0 stabilized the storage format — a `.duckdb` file created by DuckDB 1.0+ can be opened by any later 1.x version without migration. Pin to DuckDB >=1.0 in production pipelines to benefit from this guarantee.

@feynman

Like a SQLite `.db` file — a single, self-contained, portable binary file that is the entire database, no server or import step required.

@card
id: wdd-ch08-c003
order: 3
title: The Write-Ahead Log (WAL)
teaser: DuckDB writes changes to a `.wal` file before applying them to the main database file — that file is your durability guarantee and must travel with the `.duckdb` file.

@explanation

When you write to a DuckDB file-backed database, changes are first appended to a write-ahead log — a file named `<yourdb>.duckdb.wal` — before being applied to the main `.duckdb` file.

How it works:

- An `INSERT`, `UPDATE`, or `DELETE` is written to the WAL atomically.
- The WAL is flushed to disk before DuckDB acknowledges the commit.
- Periodically — and always on clean close — DuckDB **checkpoints**: it applies the WAL's contents to the main file and truncates the WAL.

Why this matters in practice:

- If a process is killed mid-write, the WAL file will be present on disk. The next time you open the database, DuckDB replays the WAL automatically. This is correct behavior, not corruption.
- If you copy only the `.duckdb` file and not the `.duckdb.wal` file, you may lose uncommitted data or open an inconsistent snapshot.

```bash
# Both files must travel together if a WAL is present
cp analytics.duckdb analytics.duckdb.wal /backup/
```

You can force a checkpoint manually:

```sql
CHECKPOINT;
```

After `CHECKPOINT`, the WAL is empty and only the `.duckdb` file is needed.

> [!warning] Never commit a `.duckdb` file to git without first running `CHECKPOINT` or verifying the WAL is empty. Add `*.duckdb.wal` to `.gitignore` for databases that are checked in.

@feynman

Like a database transaction log in PostgreSQL — writes go to the log first for durability, then are periodically folded into the main data files during a checkpoint.

@card
id: wdd-ch08-c004
order: 4
title: Single-Writer Concurrency Limit
teaser: DuckDB enforces one writer at a time per database file — attempting a second concurrent write fails immediately with a clear error, not silently.

@explanation

DuckDB's concurrency model is: **one writer, multiple readers**. This is enforced at the file level via an OS-level exclusive lock.

What happens with concurrent write attempts:

```python
# Process A
con_a = duckdb.connect('analytics.duckdb')  # acquires write lock

# Process B (separate process, simultaneous)
con_b = duckdb.connect('analytics.duckdb')
# raises: duckdb.IOException: Could not set lock on file "analytics.duckdb":
# Resource temporarily unavailable
```

The lock is released when the connection is closed or the process exits.

Workarounds for common scenarios:

- **Multiple read consumers + one writer:** open read-only connections (see the next card) for readers while the writer holds the lock.
- **Multiple write producers:** funnel writes through a single worker process. Use a queue (Redis, a message bus, a simple file queue) to serialize writes.
- **Periodic batch writes:** instead of continuous writes from multiple sources, batch data externally and write in a single scheduled job.
- **MotherDuck:** DuckDB's managed cloud offering handles multi-writer coordination at the platform level.

The single-writer constraint is not a bug — it is a deliberate tradeoff. Without a server to arbitrate writes, file-level locking is the only safe mechanism. The result is simple, predictable behavior at the cost of write concurrency.

> [!info] Within a single process, a single DuckDB connection is thread-safe. Multiple threads can execute queries on the same connection concurrently — DuckDB parallelizes them internally. The single-writer constraint applies across *processes*, not across *threads*.

@feynman

Like a write lock on a shared file in a distributed system — only one holder at a time, everyone else waits or is rejected, which avoids corruption at the cost of throughput.

@card
id: wdd-ch08-c005
order: 5
title: Read-Only Mode
teaser: Open a DuckDB file in read-only mode to query it safely from multiple processes simultaneously, even while another process holds the write lock.

@explanation

Read-only connections do not acquire the exclusive write lock, which means multiple processes can open the same `.duckdb` file simultaneously as long as all of them are read-only:

```python
con = duckdb.connect('analytics.duckdb', read_only=True)
```

```sql
-- CLI read-only flag
duckdb -readonly analytics.duckdb
```

What read-only mode enables:

- Multiple dashboard instances querying the same database file simultaneously.
- A reporting process reading data while a writer loads new data (reads see a consistent snapshot via MVCC).
- Opening a database file that you do not have write permission to on the filesystem.

What read-only mode prevents:

- Any DDL (`CREATE TABLE`, `DROP VIEW`, etc.)
- Any DML (`INSERT`, `UPDATE`, `DELETE`)
- Explicit `CHECKPOINT`

If you attempt a write in read-only mode, DuckDB raises an error immediately.

```python
con = duckdb.connect('analytics.duckdb', read_only=True)
con.execute("INSERT INTO events VALUES (2, 'scroll')")
# raises: duckdb.TransactionException: Attempt to execute write query in read-only transaction
```

> [!tip] In a web service that serves analytical queries, open the DuckDB connection in read-only mode at application startup. This lets you run multiple worker processes (Gunicorn workers, Uvicorn workers) against the same database file without coordination overhead — as long as a separate writer process handles updates.

@feynman

Like opening a file with `O_RDONLY` in POSIX — multiple readers can hold it simultaneously, and the OS prevents anyone in read-only mode from accidentally corrupting the shared state.

@card
id: wdd-ch08-c006
order: 6
title: ATTACH — Multiple Databases in One Session
teaser: `ATTACH` lets you open additional DuckDB files (or other data sources) inside an existing session and query across them with standard SQL.

@explanation

DuckDB supports attaching multiple databases to a single session. Each attached database is accessible by its alias, and you can join across them as if they were schemas in the same database.

```sql
-- Attach a second database with an alias
ATTACH 'warehouse.duckdb' AS warehouse;

-- Now both the default database and warehouse are accessible
SELECT *
FROM memory.main.events e
JOIN warehouse.main.products p ON e.product_id = p.id;
```

The default (first) database is always accessible as `memory` (for in-memory) or by its file path alias. Attached databases are addressed as `<alias>.<schema>.<table>`.

```python
import duckdb

con = duckdb.connect('primary.duckdb')
con.execute("ATTACH 'secondary.duckdb' AS sec")
con.execute("SELECT COUNT(*) FROM sec.main.orders")
```

Attaching read-only:

```sql
ATTACH 'archive.duckdb' AS archive (READ_ONLY);
```

What you can attach:

- Other `.duckdb` files (read-write or read-only)
- In-memory databases: `ATTACH ':memory:' AS scratch`
- MotherDuck databases: `ATTACH 'md:mydb' AS cloud` (requires `httpfs` extension and MotherDuck token)
- SQLite files via the SQLite extension: `ATTACH 'legacy.sqlite' AS legacy (TYPE SQLITE)`

> [!info] Cross-database queries in DuckDB run entirely within the same process. There is no network hop, no serialization, and no external query planner — the DuckDB optimizer sees all attached databases equally and can push predicates and projections across database boundaries.

@feynman

Like `USE database` in MySQL but more powerful — instead of switching databases, you mount multiple databases simultaneously and treat them like schemas in one unified namespace.

@card
id: wdd-ch08-c007
order: 7
title: Detaching Databases and Inspecting the Catalog
teaser: `DETACH` releases an attached database and `SHOW DATABASES` gives you the current attach state — both are essential for dynamic multi-database workflows.

@explanation

Once you are done with an attached database, detach it to release the file lock:

```sql
DETACH warehouse;
```

After `DETACH`, the alias is gone and the write lock on `warehouse.duckdb` is released. The primary database (the one you opened with `connect()`) cannot be detached.

Inspecting what is attached:

```sql
SHOW DATABASES;
```

Returns the alias and file path for each attached database. In Python:

```python
print(con.execute("SHOW DATABASES").fetchdf())
#    database_name          path
# 0       primary  primary.duckdb
# 1           sec  secondary.duckdb
```

You can also use the `information_schema` to inspect tables across attached databases:

```sql
SELECT table_catalog, table_schema, table_name
FROM information_schema.tables
ORDER BY table_catalog, table_name;
```

Use cases for attaching and detaching dynamically:

- **Sharded archives:** attach a per-month archive database for a date-range query, detach when done.
- **Migration workflows:** attach source and destination databases, copy data, detach source.
- **Parallel loading:** attach scratch databases for intermediate work, merge results, detach.

> [!tip] In long-running processes, detach databases you no longer need. Each attached file holds a file lock — accumulating open handles causes resource leaks and blocks other processes from writing.

@feynman

Like mounting and unmounting filesystems in Linux — `ATTACH` is `mount`, `DETACH` is `umount`, and `SHOW DATABASES` is `df` or `mount -l`.

@card
id: wdd-ch08-c008
order: 8
title: Copying Data Between Attached Databases
teaser: With two databases attached, you can move or copy tables between them using standard SQL — no intermediate files, no export/import cycle.

@explanation

Once two databases are attached, moving data between them is plain SQL:

```sql
ATTACH 'source.duckdb' AS src;
ATTACH 'dest.duckdb' AS dst;

-- Copy a table
CREATE TABLE dst.main.orders AS SELECT * FROM src.main.orders;

-- Copy with a filter
CREATE TABLE dst.main.recent_orders AS
SELECT * FROM src.main.orders
WHERE created_at >= '2025-01-01';

-- Insert into an existing table
INSERT INTO dst.main.events
SELECT * FROM src.main.events WHERE event_type = 'purchase';
```

The entire operation runs in-process — DuckDB reads from the source database and writes to the destination database within the same query execution, using vectorized batch processing.

For larger copies, wrapping in a transaction improves performance and gives you atomicity:

```sql
BEGIN;
CREATE TABLE dst.main.orders AS SELECT * FROM src.main.orders;
CREATE TABLE dst.main.products AS SELECT * FROM src.main.products;
COMMIT;
```

If the source database is very large, consider copying in batches:

```sql
-- Chunked insert to avoid memory pressure
INSERT INTO dst.main.events
SELECT * FROM src.main.events
WHERE event_date BETWEEN '2024-01-01' AND '2024-03-31';

INSERT INTO dst.main.events
SELECT * FROM src.main.events
WHERE event_date BETWEEN '2024-04-01' AND '2024-06-30';
```

> [!warning] `CREATE TABLE dst.main.orders AS SELECT ...` will fail if the table already exists in the destination. Use `CREATE OR REPLACE TABLE` or check existence with `IF NOT EXISTS` depending on your intent.

@feynman

Like `INSERT INTO ... SELECT FROM` across schemas in PostgreSQL — when two databases are visible to the same session, moving data between them is just SQL with a qualified table name.

@card
id: wdd-ch08-c009
order: 9
title: EXPORT DATABASE — Portable Snapshots
teaser: `EXPORT DATABASE` dumps a DuckDB database to a directory of Parquet files and SQL schema — human-readable, portable, and readable by any Parquet-compatible tool.

@explanation

`EXPORT DATABASE` writes the entire contents of a database to a directory:

```sql
EXPORT DATABASE '/tmp/my_export';
```

The output directory contains:

- `schema.sql` — DDL for all tables, views, sequences, and macros
- One `.parquet` file per table (named `<table_name>.parquet`)
- `load.sql` — a script that re-imports everything into a fresh DuckDB database

To restore:

```sql
IMPORT DATABASE '/tmp/my_export';
```

Or manually from the load script:

```bash
duckdb fresh.duckdb < /tmp/my_export/load.sql
```

Why `EXPORT DATABASE` is useful:

- **Portability.** Parquet files are readable by Spark, Polars, pandas, BigQuery, Snowflake, and any other Parquet-compatible tool — no DuckDB required to consume the export.
- **Version migration.** If a DuckDB major version breaks the storage format (unlikely with 1.x but possible with 2.x), export/import provides a format-agnostic migration path.
- **Inspection.** You can open individual Parquet files with any Parquet reader to inspect the data without loading the entire database.
- **Backup.** The export directory is a self-contained backup that can be restored independently of the original `.duckdb` file.

```sql
-- Export with Parquet compression options
EXPORT DATABASE '/tmp/my_export' (FORMAT PARQUET, COMPRESSION ZSTD);
```

> [!info] `EXPORT DATABASE` exports committed data only — it does not capture in-flight transactions or WAL entries. Run `CHECKPOINT` before exporting if you want to ensure all recent writes are included.

@feynman

Like `pg_dump` for PostgreSQL — a human-inspectable snapshot of the database that can be restored, moved, or fed into a completely different tool without needing the original binary format.

@card
id: wdd-ch08-c010
order: 10
title: Temporary Tables and Temporary Files
teaser: `CREATE TEMP TABLE` creates a session-scoped table that is automatically dropped when the connection closes, with no impact on the persistent database.

@explanation

Temporary tables are a lightweight alternative to creating permanent tables for intermediate work:

```sql
CREATE TEMP TABLE staging AS
SELECT *
FROM read_parquet('raw/*.parquet')
WHERE status = 'active';

-- Use it in subsequent queries this session
SELECT region, COUNT(*) FROM staging GROUP BY region;

-- Automatically dropped when the connection closes
```

Key properties of temp tables in DuckDB:

- **Session-scoped.** Visible only to the current connection. No other connection sees them.
- **Schema:** temp tables live in the `temp` schema (accessible as `temp.main.<table_name>`).
- **Storage:** stored in a temporary file on disk (not purely in-memory), so they can exceed available RAM by spilling to disk.
- **No WAL.** Changes to temp tables are not written to the WAL and are not durable.

Temp tables are useful for:

- Multi-step transformations where the intermediate result is expensive to recompute.
- Staging data before validation and insert into a permanent table.
- Breaking up a complex query into debuggable steps.

```sql
-- Multi-step pipeline with temp tables
CREATE TEMP TABLE step1 AS SELECT ... FROM raw;
CREATE TEMP TABLE step2 AS SELECT ... FROM step1 WHERE ...;
INSERT INTO main.final SELECT * FROM step2;
```

You can also explicitly drop a temp table before the session ends:

```sql
DROP TABLE staging;
```

> [!tip] Prefer `CREATE TEMP TABLE` over creating and dropping regular tables in a workflow — it is explicit about lifecycle intent and avoids accidentally polluting the persistent schema.

@feynman

Like a variable declared inside a function scope in Python — it exists for the duration of the call, is invisible outside of it, and is cleaned up automatically when the scope exits.

@card
id: wdd-ch08-c011
order: 11
title: Memory vs Disk: How DuckDB Spills
teaser: DuckDB does not fail with OOM on large queries — it spills intermediate data to a temp directory automatically, trading speed for the ability to process data larger than RAM.

@explanation

DuckDB's memory manager enforces a configurable memory limit and automatically spills to disk when that limit is reached during a query:

```sql
-- Check the current memory limit
SELECT current_setting('memory_limit');

-- Set a limit
SET memory_limit = '8GB';
```

What gets spilled:

- Sort operations that exceed the memory limit spill sort runs to temp files.
- Hash join build sides that exceed the limit spill partitions to disk.
- Aggregation hash tables that exceed the limit use external aggregation.

Where temp files are written:

```sql
-- Check and configure the temp directory
SELECT current_setting('temp_directory');
SET temp_directory = '/fast-nvme/duckdb_tmp';
```

By default, DuckDB uses the system temp directory. On machines where the temp directory is on a slow disk (or a small tmpfs), pointing it at a faster path meaningfully improves spill performance.

Performance implications:

- Queries that fit in memory run significantly faster than those that spill.
- Spill is disk I/O — query time will increase, sometimes dramatically on slow disks.
- You can avoid spill by setting a higher memory limit (`SET memory_limit = '16GB'`) or by reducing data volume earlier in the pipeline (filter before join, project early).

> [!info] DuckDB defaults to 80% of available RAM as the memory limit. On a shared machine or in a container, set `memory_limit` explicitly to avoid starving other processes.

@feynman

Like how a database's sort operator in PostgreSQL uses `work_mem` before spilling to disk — DuckDB applies the same mechanism across joins, aggregations, and sorts, and the temp directory is where it lands.

@card
id: wdd-ch08-c012
order: 12
title: Checkpointing — When the WAL Is Flushed
teaser: DuckDB checkpoints automatically on clean close and at a configurable WAL size threshold — understanding when checkpoints happen prevents surprises with file sizes and recovery.

@explanation

A checkpoint in DuckDB means: apply all WAL entries to the main `.duckdb` file, then truncate the WAL. After a checkpoint, only the `.duckdb` file is needed — the `.wal` file is empty or absent.

Checkpoints happen automatically in three situations:

- **Clean connection close.** When you call `con.close()` or the connection object is garbage-collected, DuckDB checkpoints before closing.
- **WAL size threshold.** When the WAL exceeds a threshold (default: 16MB), DuckDB triggers a background checkpoint mid-session.
- **Explicit call.** `CHECKPOINT;`

You can tune the WAL threshold:

```sql
SET wal_autocheckpoint = '64MB';
```

Forcing a checkpoint before copying or backing up the database file:

```python
con.execute("CHECKPOINT")
# Now safe to copy analytics.duckdb — no WAL to worry about
import shutil
shutil.copy('analytics.duckdb', '/backup/analytics.duckdb')
```

What happens if a checkpoint fails mid-way:

- DuckDB does not corrupt the main file — the WAL is only truncated after the checkpoint is confirmed complete.
- On the next open, DuckDB replays the WAL from the beginning.

> [!tip] If your `.duckdb` file appears smaller than expected after heavy writes, it is likely because data is in the WAL and not yet checkpointed. Run `CHECKPOINT` and then check the file size again.

@feynman

Like compacting a write-ahead log in Kafka or an LSM tree — you periodically merge the log entries into the base data structure so the log stays small and reads are fast.

@card
id: wdd-ch08-c013
order: 13
title: Database Aliases and the Default Database
teaser: The first database opened in a session is the default — understanding how DuckDB resolves unqualified table names across attached databases prevents subtle query errors.

@explanation

When you open a DuckDB connection, the first database is the **default database**. Unqualified table names (no `db.schema.table` prefix) resolve to the default database's `main` schema.

```python
con = duckdb.connect('primary.duckdb')
# primary.duckdb is the default database, aliased as "primary" (or the filename stem)

con.execute("ATTACH 'secondary.duckdb' AS sec")
# sec is now also available

con.execute("SELECT * FROM orders")
# resolves to primary.main.orders — the default database

con.execute("SELECT * FROM sec.main.orders")
# explicit cross-database reference
```

You can check the current default:

```sql
SELECT current_database();
```

You can change the default schema (within the default database):

```sql
SET search_path = 'reporting';
SELECT * FROM orders;  -- now resolves to primary.reporting.orders
```

You cannot change which attached database is the default mid-session — it is set at connection open time.

Common mistake: attaching a second database and assuming unqualified names search both databases. They do not — unqualified names only resolve against the default database and the `search_path`.

```sql
ATTACH 'secondary.duckdb' AS sec;

SELECT * FROM orders;      -- primary.main.orders only
SELECT * FROM sec.orders;  -- sec.main.orders (schema is optional if unambiguous)
```

> [!warning] If two attached databases have a table with the same name and you use an unqualified reference, DuckDB resolves to the default database — silently. Always use qualified names in cross-database queries.

@feynman

Like PostgreSQL's `search_path` — the database has a default resolution order, unqualified names go there first, and explicit qualification is the only safe way to reference objects in non-default schemas across databases.
