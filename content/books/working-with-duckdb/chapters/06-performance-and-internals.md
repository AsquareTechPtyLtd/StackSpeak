@chapter
id: wdd-ch06-performance-and-internals
order: 6
title: Performance and Internals
summary: How DuckDB achieves analytical query performance — vectorized execution, parallel processing, the query optimizer, and memory management.

@card
id: wdd-ch06-c001
order: 1
title: Vectorized Execution Explained
teaser: DuckDB processes thousands of rows at once per operation — not one row at a time — and that single change explains most of its speed advantage.

@explanation

Traditional SQL engines use the "volcano model" (also called iterator model): each operator calls `next()` on its child, which returns one row, which is passed up the pipeline. Elegant, but expensive — one function call per row, per operator, on millions of rows adds up to billions of function calls.

DuckDB uses **vectorized execution**: each operator processes a batch of rows — by default 2,048 rows per vector — in a single call. One `next()` call returns 2,048 rows, not one.

Why batching is faster:

- **CPU cache efficiency.** A 2,048-row vector of `int64` values fits in L2 cache. Processing it entirely before moving on keeps the data hot.
- **SIMD utilization.** Modern CPUs (x86 AVX2/AVX-512, ARM NEON) can perform arithmetic on 4–16 values simultaneously. Tight numeric loops over a contiguous array allow the compiler and CPU to auto-vectorize — one instruction, multiple data points.
- **Reduced function call overhead.** Operator dispatch happens once per 2,048 rows, not once per row.
- **Better branch prediction.** Null checks and type dispatches happen at the vector boundary, not inline per row.

Real-world implication: on a 10-million-row `SUM(revenue)` query, DuckDB issues roughly 4,883 vector calls. The volcano model issues 10,000,000 row-level calls. The arithmetic alone makes vectorized execution orders of magnitude cheaper for scan-heavy analytics.

> [!info] The vector size of 2,048 rows is tunable via `SET vector_size = 4096`, but the default is well-calibrated for modern L2 cache sizes. Changing it rarely improves real-world performance without profiling first.

@feynman

Like the difference between processing a batch of images in one GPU kernel call versus submitting each image as a separate CPU task — the overhead of dispatch dominates when the unit of work is too small.

@card
id: wdd-ch06-c002
order: 2
title: Columnar Storage and Compression
teaser: Storing data column-by-column lets DuckDB compress aggressively and skip entire column chunks without reading them — the layout is inseparable from the performance.

@explanation

Row-oriented storage (PostgreSQL, SQLite) writes each row contiguously: `(id, name, price, region, ...)` packed together. To compute `SUM(price)`, the engine reads every byte of every row to extract just the `price` column.

DuckDB stores data **column-by-column**: all `price` values together, all `region` values together. A `SUM(price)` query reads only the `price` column — skipping every other column entirely.

Two performance benefits fall directly from this layout:

**Compression ratio:**
Values in the same column are the same type and often correlated. A `region` column with values `['us-east', 'us-west', 'eu-central']` repeated millions of times compresses to near nothing with dictionary encoding. A `price` column of floats near the same magnitude compresses well with frame-of-reference encoding. Row storage mixes types and disrupts these patterns — columnar storage enables compression rates of 5–20x on typical analytical data.

**Column pruning:**
If a query references 3 out of 50 columns, DuckDB reads 3 column segments from disk. The other 47 are never accessed. On a 10GB table with 50 columns, a 3-column query might read 600MB instead of 10GB.

DuckDB uses several encoding schemes automatically:
- Dictionary encoding for low-cardinality strings
- RLE (run-length encoding) for repeated values
- Frame-of-reference for numeric columns with small ranges
- Bit-packing for small integers

> [!tip] Columnar compression means `COPY` to Parquet and querying Parquet directly often produces better performance than equivalent CSV queries — the column layout and compression do the work before the query even runs.

@feynman

Like a spreadsheet where you store each column in a separate array — computing a column sum becomes a tight loop over contiguous memory rather than a scattered read across a row-interleaved heap.

@card
id: wdd-ch06-c003
order: 3
title: Zone Maps and Predicate Pushdown
teaser: DuckDB tracks min/max values per column chunk and uses them to skip entire blocks of data before evaluating any rows — a technique that makes WHERE clauses much cheaper.

@explanation

DuckDB divides each column into **row groups** of 122,880 rows (the default). For each row group, it stores a **zone map**: the minimum and maximum value of that column chunk.

When a query has a filter predicate, DuckDB consults the zone maps before reading any data:

```sql
SELECT * FROM orders WHERE order_date >= '2025-01-01';
```

If the `order_date` zone map for a row group shows `max = '2024-12-31'`, the entire row group is skipped without reading a single row. On a sorted or partially sorted column, this eliminates the majority of I/O for range queries.

This is called **predicate pushdown** — filters are pushed down to the storage layer and evaluated as early as possible, before data is decoded and materialized.

How to maximize zone map effectiveness:

- **Sort your data on filter columns.** If you frequently filter by `event_date`, sort the Parquet file by `event_date` before writing. This concentrates relevant rows into fewer row groups.
- **Use the right data type.** A `DATE` column gets better zone map benefit than a `VARCHAR` column containing date strings — string comparisons work but numeric comparisons are more precise.
- **Avoid functions on filter columns.** `WHERE year(order_date) = 2025` cannot use zone maps. `WHERE order_date BETWEEN '2025-01-01' AND '2025-12-31'` can.

> [!tip] For large Parquet files you query repeatedly by date range, pre-sorting on the date column before writing can reduce query time by 80–90% on selective filters. Use `COPY (SELECT * FROM tbl ORDER BY event_date) TO 'sorted.parquet'`.

@feynman

Like a book index — instead of reading every page to find mentions of a term, you consult a structure that tells you exactly which pages to skip.

@card
id: wdd-ch06-c004
order: 4
title: Parallel Query Execution
teaser: DuckDB automatically splits scans, joins, and aggregations across all available CPU cores — parallelism is on by default and requires no query hints.

@explanation

DuckDB parallelizes query execution at the operator level across all available CPU cores. This happens automatically — no `PARALLEL` hints, no partitioning declarations, no explicit configuration required for the default behavior.

How parallelism works per operator type:

**Table scans:** The row group list is divided across threads. With 8 cores and 100 row groups, each thread scans ~12–13 row groups independently.

**Aggregations:** Each thread aggregates its partition of rows into a local hash table. Thread-local results are merged in a final reduction step. This avoids write contention on a shared hash table.

**Hash joins:** The build phase (loading the smaller table into a hash table) is parallelized. The probe phase (scanning the larger table and probing the hash table) is also parallelized across threads with a shared read-only hash table.

**Sorting:** Parallel sort uses a split-then-merge strategy similar to external merge sort, with each thread sorting its partition independently before merging.

Controlling thread count:

```sql
-- Check current setting
SELECT current_setting('threads');

-- Set for the session
SET threads = 4;

-- Set at connection time (Python)
con = duckdb.connect()
con.execute("SET threads = 4")
```

DuckDB defaults to the number of logical CPU cores. On a shared machine or container with constrained CPU quotas, set `threads` explicitly to avoid oversubscription.

> [!warning] On CI runners or containers with cgroup CPU limits, DuckDB may detect the physical core count of the host rather than the cgroup limit. Always set `threads` explicitly in constrained environments to match your actual CPU budget.

@feynman

Like map-reduce at the single-node level — each core runs a local map phase, then a shared reduce phase merges the partial results.

@card
id: wdd-ch06-c005
order: 5
title: The Query Optimizer
teaser: DuckDB's optimizer uses cardinality statistics and a dynamic programming join order search — it makes better join ordering decisions than most heuristic-based systems.

@explanation

DuckDB's query optimizer operates in several stages before execution:

**Logical optimization:**
- Predicate pushdown — moves filters as close to the scan as possible.
- Projection pushdown — eliminates unused columns early.
- Common subexpression elimination — avoids recomputing identical expressions.
- Filter and join reordering — uses selectivity estimates to order filters cheaply-first.

**Join order optimization:**
DuckDB uses a **dynamic programming (DP) join order optimizer** for queries with up to a configurable number of tables (default 10). For queries with more tables it falls back to a greedy algorithm. The DP optimizer considers all possible join orders and selects the one with the lowest estimated cost — significantly better than left-deep heuristics used by many simpler systems.

**Statistics:**
The optimizer uses column statistics (min, max, distinct count, null fraction) gathered during writes and `ANALYZE` to estimate cardinalities. More accurate statistics → better join order decisions.

**Adaptive query execution:**
DuckDB can switch between hash join and nested loop join mid-query based on observed row counts. If a join's build side turns out to be larger than estimated, the optimizer adapts rather than committing to a bad plan upfront.

Running `ANALYZE` after bulk loads:

```sql
ANALYZE;           -- update statistics for all tables
ANALYZE my_table;  -- update for one table
```

> [!tip] On tables that receive large batch inserts, run `ANALYZE` before the next complex query. Stale statistics are the most common cause of unexpectedly slow queries in DuckDB.

@feynman

Like a chess engine evaluating positions several moves ahead — the DP optimizer exhaustively searches the space of join orderings rather than committing to the first reasonable-looking plan.

@card
id: wdd-ch06-c006
order: 6
title: Reading EXPLAIN Output
teaser: EXPLAIN shows the physical query plan DuckDB will execute — reading it takes five minutes to learn and saves hours of guessing why a query is slow.

@explanation

DuckDB supports two forms of query plan inspection:

```sql
-- Logical plan (before optimization)
EXPLAIN SELECT region, SUM(revenue) FROM orders GROUP BY region;

-- Physical plan with timing and row counts (after execution)
EXPLAIN ANALYZE SELECT region, SUM(revenue) FROM orders GROUP BY region;
```

Key operators to recognize in EXPLAIN output:

- **SEQ_SCAN** — sequential column scan. Expected for analytical queries. Shows which columns were read and any filters pushed to the scan.
- **FILTER** — a filter not pushed to the scan (e.g., applied after a join). If you see FILTER above a SEQ_SCAN on a selective predicate, the optimizer may be missing statistics.
- **HASH_JOIN** — standard hash join. Shows build side (smaller table) and probe side. Check estimated vs actual row counts.
- **HASH_GROUP_BY** — parallel aggregation via hash table. Expected for GROUP BY.
- **ORDER_BY** — sort operation. Expensive on large tables — confirm it is necessary.
- **PROJECTION** — column projection step. Usually cheap.

What to look for:

- **Large estimated vs actual row count mismatch** — stale statistics, run `ANALYZE`.
- **FILTER above SEQ_SCAN on a selective column** — predicate pushdown is not happening; check if the filter uses a function on the column.
- **Unexpected nested loop joins** — may indicate the optimizer chose a suboptimal plan due to bad statistics.
- **High rows in ORDER_BY** — sorting is often the bottleneck for queries that do not need full ordering; consider `LIMIT` or replacing with `QUALIFY` for top-N patterns.

> [!info] `EXPLAIN ANALYZE` actually runs the query. Use it on queries you are already running — do not run it on long queries just to inspect the plan, as you will pay the full execution cost.

@feynman

Like reading a compiler's assembly output — most of the time you do not need it, but when a hot path is unexpectedly slow, it is the fastest way to understand what the machine is actually doing.

@card
id: wdd-ch06-c007
order: 7
title: Memory Management and the Buffer Pool
teaser: DuckDB manages its own memory pool with a configurable limit — understanding how it uses memory prevents OOM surprises on shared machines.

@explanation

DuckDB uses an internal **buffer pool** to manage memory for query execution. All intermediate results, hash tables, sort buffers, and column data in flight pass through this pool.

The default memory limit is **80% of available system RAM**. On a laptop with 16GB RAM that means DuckDB will use up to ~12.8GB before taking action. On a shared CI runner with 4GB of RAM shared across processes, this default is almost always wrong.

Setting the memory limit:

```sql
SET memory_limit = '4GB';
```

Or at connection time in Python:

```python
con = duckdb.connect()
con.execute("SET memory_limit = '4GB'")
```

What DuckDB tracks toward the memory limit:

- Column data loaded into the buffer pool
- Hash tables for joins and aggregations
- Sort buffers
- Intermediate projection results

What is NOT tracked:

- Python objects that reference DuckDB results (after `fetchall()`, the data is in Python's heap, not DuckDB's)
- Arrow zero-copy results (memory is shared, counted once)

Checking current memory usage:

```sql
SELECT * FROM duckdb_memory();
```

This returns a breakdown of memory used by category — useful when debugging unexpectedly high consumption.

> [!tip] Setting `memory_limit` lower than the default is safe and does not degrade correctness — DuckDB will spill to disk when the limit is reached. Set it to leave headroom for other processes, especially in containers.

@feynman

Like setting a JVM heap size with `-Xmx` — the runtime needs an explicit ceiling or it will consume as much as the OS allows, which is often more than a shared environment can afford.

@card
id: wdd-ch06-c008
order: 8
title: Spilling to Disk When Memory Is Exhausted
teaser: When a query exceeds the memory limit, DuckDB spills intermediate results to temporary files on disk — the query still completes, but slower.

@explanation

DuckDB does not crash or error when a query exceeds `memory_limit`. Instead, it **spills** intermediate data (hash tables, sort buffers) to a temporary directory on disk, processes from disk, and then cleans up afterward. This is called **out-of-core** or **external** processing.

Operations that support spilling:

- **Hash joins** — the build-side hash table is partitioned and the overflow written to temp files.
- **Hash aggregations** — partial aggregation hash tables spill when full.
- **Sort** — external merge sort writes sorted runs to disk and merges them.

Operations that do not spill (and will error if memory is insufficient):

- Window functions with very large frames
- Some complex subquery materializations

Configuring the temp directory:

```sql
SET temp_directory = '/path/to/fast/disk';
```

Default is the same directory as the database file (or the OS temp directory for in-memory databases). If spilling is expected, point this at a fast local NVMe drive rather than a network-mounted volume.

Detecting spilling:

Run `EXPLAIN ANALYZE` and look for `(Spilled to Disk)` annotations on hash join and hash group-by operators. If you see spilling on a query that runs frequently:

- Increase `memory_limit` if the machine has spare RAM.
- Reduce the query's intermediate data (push filters earlier, reduce join fanout).
- If spilling is unavoidable, ensure `temp_directory` is on fast local storage.

> [!warning] Spilling to a network filesystem (NFS, EFS, SMB) can make a query 100x slower than the same query on a local disk. Always configure `temp_directory` to a local path if you expect memory-intensive queries.

@feynman

Like a database sort that pages through a B-tree when it cannot fit the sort key in RAM — it still produces correct results, just with disk I/O replacing in-memory operations.

@card
id: wdd-ch06-c009
order: 9
title: The .duckdb File Format
teaser: DuckDB's file format stores data in a columnar block structure with a catalog, row groups, and a checkpoint mechanism — knowing the layout explains WAL behavior and file sizes.

@explanation

A `.duckdb` file is a self-contained binary file with several internal layers:

**Storage layout:**
- A file header with a magic number (`DUCK`) and version metadata.
- A **catalog** segment storing table definitions, indexes, and schema metadata.
- **Column segments** — the actual columnar data, organized into row groups of 122,880 rows each.
- Each column segment stores compressed column chunks with accompanying zone maps (min/max metadata).

**Checkpointing:**
DuckDB writes changes in memory first, then periodically **checkpoints** — serializing the in-memory state to the `.duckdb` file. Checkpointing happens:
- On a clean shutdown.
- After a configurable number of WAL writes (`wal_autocheckpoint`, default: 1,000 blocks).
- When explicitly called with `CHECKPOINT;`.

**WAL (Write-Ahead Log):**
Before data is checkpointed to the main file, it is appended to a `.duckdb.wal` file. This ensures crash recovery — on next open, DuckDB replays the WAL to recover any un-checkpointed writes.

```sql
-- Force an immediate checkpoint
CHECKPOINT;

-- Force checkpoint with WAL deletion
FORCE CHECKPOINT;
```

File size behavior: `.duckdb` files do not automatically shrink after deletes. Run `VACUUM;` to reclaim space from deleted rows. Run `VACUUM FULL;` to rewrite and compact the file (takes a write lock for the duration).

> [!info] The `.duckdb` and `.duckdb.wal` files must always travel together. Copying the `.duckdb` file without the `.wal` file (if one exists) may produce a database that is missing recent writes. Copy both, or use `EXPORT DATABASE` for safe portable exports.

@feynman

Like Git's object store and ref log — the main file is the stable committed state, the WAL is the in-flight transaction log, and a checkpoint is the equivalent of a garbage-collected pack operation.

@card
id: wdd-ch06-c010
order: 10
title: Benchmarking DuckDB Queries
teaser: EXPLAIN ANALYZE gives per-operator timing and row counts — but accurate benchmarking requires warm-up runs, realistic data sizes, and measuring the right thing.

@explanation

**Using EXPLAIN ANALYZE:**

```sql
EXPLAIN ANALYZE
SELECT region, SUM(revenue), COUNT(*)
FROM orders
WHERE order_date >= '2025-01-01'
GROUP BY region
ORDER BY SUM(revenue) DESC;
```

Output includes:
- Estimated vs actual row counts per operator
- CPU time per operator
- Whether any operator spilled to disk

**Timing queries directly:**

DuckDB tracks query timing automatically. After any query, `duckdb_profiling_output()` returns the most recent profiling data:

```sql
PRAGMA enable_profiling;
SELECT region, SUM(revenue) FROM orders GROUP BY region;
SELECT * FROM duckdb_profiling_output();
```

**Benchmarking best practices:**

- **Warm up the buffer pool.** Run the query once before timing — the first run loads column chunks into the buffer pool. Subsequent runs are faster. If benchmarking cold-start I/O performance, clear the OS page cache between runs.
- **Use realistic data volumes.** DuckDB's vectorized execution has overhead that only pays off at scale. A 10,000-row table benchmarks worse relative to SQLite than a 10,000,000-row table.
- **Time at the right layer.** Timing in Python includes Python's `fetchall()` overhead. Time the SQL execution separately: `con.execute(query).fetchdf()` vs timing just `con.execute(query)` to isolate query time from result materialization time.
- **Disable result output.** For microbenchmarks, use `SELECT COUNT(*) FROM (...)` to force evaluation without materializing the full result set.
- **Watch for caching effects.** DuckDB caches parsed queries and compiled pipelines. The second run of an identical query is sometimes faster than the first by 5–15% due to pipeline caching.

> [!tip] For macro-benchmarks comparing DuckDB configurations (different thread counts, memory limits, file formats), use the TPC-H or TPC-DS benchmark datasets — they are available as DuckDB shell scripts via the `tpch` and `tpcds` extensions.

@feynman

Like profiling a web server with `ab` or `wrk` — a single-run timing number is almost meaningless; percentiles across warm, repeated runs with realistic load reveal the actual behavior.

@card
id: wdd-ch06-c011
order: 11
title: Pipelines and the Push-Based Execution Model
teaser: DuckDB uses a push-based pipeline execution model internally — understanding it explains why some query shapes are faster and how parallel execution is structured.

@explanation

DuckDB's execution engine uses a **push-based** (also called "morsel-driven") model rather than the pull-based volcano iterator model.

In the pull model: the top operator pulls rows from its children — control flows top-down, data flows bottom-up via function return values.

In the push model: operators are compiled into **pipelines** — chains of operators that can be executed with a single pass over the data. The source (a scan) pushes vectors through the pipeline until it hits a **pipeline breaker** — an operation that must see all input before producing output.

Pipeline breakers include:
- Hash joins (must build the full hash table before probing)
- Sort operations
- Hash aggregations (final merge step)

Why pipelines matter:

- A pipeline with no breakers can be parallelized trivially — split the scan across threads, each thread runs the full pipeline on its partition.
- Pipeline-parallel execution avoids thread synchronization until a breaker is reached.
- DuckDB compiles each pipeline into a tight execution loop. Column vectors flow through filter, project, and expression operators without intermediate materialization.

In practice, a query like:

```sql
SELECT region, SUM(price * quantity)
FROM orders
WHERE status = 'shipped'
GROUP BY region
```

Compiles into two pipelines:
1. Scan → Filter → Project → Build hash aggregation table (breaker)
2. Finalize and return hash aggregation results

Each pipeline runs parallel across all threads, synchronizing only at the breaker boundary.

@feynman

Like an assembly line where each station passes the part to the next without stopping — the pipeline flows continuously until it hits an operation (like quality inspection) that requires accumulating the full batch.

@card
id: wdd-ch06-c012
order: 12
title: Adaptive Radix Tree Indexes
teaser: DuckDB supports ART (Adaptive Radix Tree) indexes for point lookups — they help specific query patterns but are rarely needed for analytical workloads.

@explanation

DuckDB supports **ART (Adaptive Radix Tree)** indexes — a trie-based data structure that provides O(k) lookup time (where k is key length) and compact memory usage compared to B-trees.

Creating an index:

```sql
CREATE INDEX idx_orders_id ON orders(id);
CREATE UNIQUE INDEX idx_users_email ON users(email);
```

When ART indexes help:

- Point lookups: `WHERE id = 12345`
- Unique constraint enforcement
- Range scans on highly selective predicates (returning < 0.1% of rows)

When ART indexes do not help (and add overhead):

- Full table scans — DuckDB always does a full scan regardless of index presence for non-selective predicates
- Aggregations over large fractions of a table
- Analytical queries that read most of the column data anyway

The overhead of maintaining an index:

- Index entries are updated on every INSERT, UPDATE, DELETE — write-heavy tables with indexes are slower to load
- Indexes consume memory proportional to the number of indexed rows

For most DuckDB analytical workloads, **zone maps (automatic) and column pruning are more impactful than explicit indexes**. Add an index only after confirming via `EXPLAIN ANALYZE` that a non-selective point lookup is the actual bottleneck.

> [!tip] DuckDB does not require indexes for aggregation performance — zone maps and columnar layout do that work. Treat ART indexes as a targeted tool for point lookup patterns, not a general performance default.

@feynman

Like adding an index to a database table in PostgreSQL — it speeds up lookups at the cost of write overhead, but for full-table analytical scans it provides no benefit and just adds maintenance cost.

@card
id: wdd-ch06-c013
order: 13
title: Profiling with duckdb_profiling_output
teaser: DuckDB's built-in profiling system captures per-operator timing and cardinality data without external tools — enabling systematic performance diagnosis inside a single SQL session.

@explanation

DuckDB has a built-in profiling mode that captures detailed execution statistics for the most recently run query.

Enabling and reading profiling:

```sql
PRAGMA enable_profiling;
PRAGMA profiling_output = 'json';  -- options: 'json', 'query_tree'

-- Run a query
SELECT region, SUM(revenue) FROM orders GROUP BY region;

-- Read the profile
SELECT * FROM duckdb_profiling_output();
```

The JSON output includes a tree of operators with the following per-node fields:

- `operator_type` — e.g., `HASH_GROUP_BY`, `SEQ_SCAN`, `HASH_JOIN`
- `rows_scanned` — rows read from storage
- `result_set_size` — rows produced by this operator (after filtering)
- `cpu_time` — wall-clock time spent in this operator
- `extra_info` — operator-specific details (e.g., columns scanned, join keys, filter expressions)

Useful diagnostic patterns:

- **High `rows_scanned` with low `result_set_size`** on a SEQ_SCAN indicates a selective filter that is not using zone maps. Check if the filter column has sorted data or if it could benefit from an index.
- **High `cpu_time` on HASH_JOIN build side** relative to probe side indicates the build table is larger than expected — check join direction.
- **`extra_info` showing spill** on hash operators means memory limit was hit — increase limit or tune the query.

Disabling profiling when done:

```sql
PRAGMA disable_profiling;
```

Profiling adds ~2–5% overhead per query. Leave it disabled in production code paths and enable it only during active investigation.

> [!info] The `json` profiling format is machine-readable and can be parsed with `json_extract()` directly in DuckDB for automated performance monitoring pipelines.

@feynman

Like Node.js's `--prof` flag combined with `node --prof-process` — the engine captures detailed timing data internally during execution, and you read it as structured output rather than instrumenting your code externally.
