@chapter
id: wdd-ch09-working-with-large-files
order: 9
title: Working with Large Files
summary: How DuckDB reads files too large to fit in memory — streaming, row-group skipping, chunked result processing, and where the practical limits are.

@card
id: wdd-ch09-c001
order: 1
title: Streaming Reads and Projection Pushdown
teaser: DuckDB never loads an entire Parquet or CSV file into memory — it streams only the bytes it needs, column by column, chunk by chunk.

@explanation

When you run `SELECT region, SUM(revenue) FROM read_parquet('sales.parquet') GROUP BY region`, DuckDB does not read the full file into RAM first. It streams the file in chunks, and only the columns it needs.

This is called **streaming reads with projection pushdown**. The two mechanisms work together:

- **Streaming:** DuckDB reads the file in row-group-sized chunks (typically 128MB each). At no point does the full file live in memory.
- **Projection pushdown:** DuckDB inspects the query before opening the file and determines which columns are needed. Only those column byte ranges are read from disk or network.

For a 10-column Parquet file where your query touches 2 columns, DuckDB skips the I/O for the other 8 entirely. On a 50GB file, that is often the difference between a 4-second query and a 40-second one.

CSV files also stream, but without column-level byte offsets — DuckDB must parse each row to find column boundaries. Parquet is faster for large files because the format was designed for column-selective access.

> [!tip] If you are generating Parquet files and later querying them with DuckDB, write them with smaller row groups (64MB–128MB) for better streaming granularity. The default 512MB row groups in some writers reduce pushdown effectiveness.

@feynman

Like `curl | grep` piping output through a filter — you never buffer the whole response, you process it line by line and discard what you don't need.

@card
id: wdd-ch09-c002
order: 2
title: Row Group Skipping with Min/Max Statistics
teaser: Parquet embeds min/max statistics per column per row group — DuckDB uses them to skip entire row groups without reading a single data byte.

@explanation

Parquet files store metadata in a footer: for each row group and each column, the footer records the minimum and maximum values observed. DuckDB reads this footer first — it is small — and uses it to prune row groups before reading any data.

Example: a 10GB Parquet file with 80 row groups, querying `WHERE event_date = '2024-03-15'`. DuckDB reads the footer, checks each row group's min/max for `event_date`, and skips any row group where `max < '2024-03-15'` or `min > '2024-03-15'`. If 70 of 80 row groups can be skipped, DuckDB reads roughly 12% of the file.

This is called **predicate pushdown** combined with **statistics-based row group skipping**.

Why Parquet layout matters:

- If data is written in time order, rows for `2024-03-15` are clustered. Few row groups straddle the boundary. Skipping is effective.
- If data is written in random order (e.g., Kafka topics that shuffle partitions), every row group may contain some `2024-03-15` rows. Min/max ranges overlap. No row groups are skipped.

The practical recommendation: sort your Parquet files on the most common filter columns before writing them, or use partitioned Parquet directories (one file per date, for example) for even coarser skipping.

> [!info] DuckDB also supports Bloom filter statistics in Parquet (added in DuckDB 1.0), which enable skipping for equality predicates on high-cardinality columns where min/max ranges are wide.

@feynman

Like a book index — you don't read every page to find all mentions of "mutex"; you check the index range for M and jump directly to the right section.

@card
id: wdd-ch09-c003
order: 3
title: Column Pruning — Only Reading What You Select
teaser: A `SELECT col1, col2` on a 40-column Parquet file reads roughly 5% of the bytes a `SELECT *` would — the file format makes this free.

@explanation

Parquet stores each column as a separate byte range within each row group. Column pruning means DuckDB only issues read I/O for the columns that appear in the query.

```sql
-- DuckDB reads only 'user_id' and 'event_type' byte ranges
SELECT user_id, event_type
FROM read_parquet('events.parquet');

-- DuckDB reads all column byte ranges — significantly more I/O
SELECT *
FROM read_parquet('events.parquet');
```

On a 40-column, 20GB Parquet file where your query uses 3 columns, column pruning reduces I/O to roughly 7.5% of the file size — assuming roughly equal column sizes. Real numbers vary by column data type and compression ratio, but the order-of-magnitude reduction is reliable.

Column pruning works for:
- Local Parquet files (maps to fewer `pread` syscalls)
- Remote Parquet over HTTP/S3 (maps to fewer and smaller range requests — significant for latency)
- CSV files do NOT benefit — CSV has no column byte offsets, so all bytes must be parsed

This is one of the strongest arguments for converting CSV archives to Parquet if you query them repeatedly. The one-time conversion cost pays back on the first few queries.

> [!warning] `SELECT *` disables column pruning. If you are exploring a schema, `SELECT *` is fine. If you are running a production query over large files, name your columns explicitly.

@feynman

Like lazy loading in an ORM — instead of fetching all relations eagerly, you only fetch the fields you actually access, and the performance difference compounds at scale.

@card
id: wdd-ch09-c004
order: 4
title: Larger-Than-Memory Queries and Disk Spilling
teaser: When intermediate results exceed DuckDB's memory budget, it spills to disk automatically — you get correct results, not an OOM crash.

@explanation

DuckDB is not a purely in-memory engine. When a query's intermediate state (a sort buffer, a hash table for a GROUP BY, or a join build side) exceeds the memory budget, DuckDB spills that state to disk and continues.

The spill location is controlled by the `temp_directory` setting:

```sql
SET temp_directory = '/path/to/fast/disk';
```

Or in Python:
```python
con.execute("SET temp_directory = '/data/duckdb_tmp'")
```

What happens during a spill:
- DuckDB writes sorted runs to `temp_directory` during an external sort.
- For hash aggregation, DuckDB partitions the hash table to disk in chunks, then processes each partition in turn.
- The query is slower (disk I/O instead of RAM), but it completes correctly.

Practical numbers: a GROUP BY over a 100GB file with many unique keys may produce a hash table larger than available RAM. With spilling enabled (it is the default), DuckDB will complete the query. Without spilling, you would hit an out-of-memory error.

Default behavior: spilling is always enabled. DuckDB creates a `temp_directory` in the current working directory if none is set. On machines with a fast NVMe SSD, spilling has acceptable performance. On machines where `temp_directory` lands on a slow HDD or network volume, expect severe slowdowns.

> [!tip] Point `temp_directory` at your fastest disk, not necessarily the same volume as your data. On cloud instances (EC2, GCE), instance-local NVMe storage is significantly faster than EBS/persistent disk for spill workloads.

@feynman

Like a database using a swap file — you give up speed compared to RAM, but the process completes rather than crashing, which is the right tradeoff for large analytical jobs.

@card
id: wdd-ch09-c005
order: 5
title: Configuring `memory_limit`
teaser: DuckDB defaults to 80% of available RAM — on shared machines or containers, setting it explicitly prevents OOM kills and resource contention.

@explanation

DuckDB's default memory limit is 80% of detected system RAM. On a dedicated 32GB machine, that is 25.6GB — appropriate. On a 4-core, 8GB CI runner where three other processes are also running, that is 6.4GB per DuckDB instance, which is too aggressive.

Setting the limit:

```sql
SET memory_limit = '4GB';
```

```python
con = duckdb.connect()
con.execute("SET memory_limit = '4GB'")
```

What the limit controls:
- The maximum amount of memory DuckDB will use for query intermediate state (sort buffers, hash tables, join build sides).
- When the limit is hit, DuckDB begins spilling to `temp_directory` rather than allocating more RAM.
- The limit does not include the memory consumed by loaded data buffers or Python objects — it is the query execution budget.

Recommended values by environment:
- **Dedicated analytics machine (32GB RAM):** `20GB` — leave headroom for the OS and other processes.
- **Shared CI runner (8GB RAM, 2 jobs):** `2GB` — conservative to avoid crowding other processes.
- **Docker container with 4GB limit:** `3GB` — leave 1GB for the container overhead and Python runtime.
- **Laptop development (16GB RAM):** `8GB` — reasonable default; raise if you see excessive spilling on large queries.

> [!warning] On Kubernetes pods with strict memory limits, DuckDB's 80% default can be higher than the container's actual memory ceiling. The container gets OOM-killed by the kernel before DuckDB's internal limit triggers. Always set `memory_limit` explicitly in containerized environments.

@feynman

Like setting a heap size with `-Xmx` in a JVM — the runtime has a default that is fine in some environments and catastrophic in others, so explicit configuration is safer in production.

@card
id: wdd-ch09-c006
order: 6
title: Chunked Result Processing with `fetchmany()`
teaser: `fetchmany()` and `fetch_chunk()` let you process query results row-batch by row-batch in Python, without pulling the entire result set into memory.

@explanation

By default, DuckDB's Python API returns all results at once:

```python
results = con.execute("SELECT * FROM read_parquet('big.parquet')").fetchall()
# 'results' is now a Python list of all rows — potentially gigabytes in RAM
```

For large result sets, this causes the same memory problem you were trying to avoid. Use `fetchmany()` or `fetch_chunk()` instead:

```python
cursor = con.execute("SELECT * FROM read_parquet('big.parquet')")

# Process 10,000 rows at a time
while True:
    batch = cursor.fetchmany(10_000)
    if not batch:
        break
    process(batch)
```

Or using the Arrow-native chunk API (more efficient — avoids Python object creation):

```python
import pyarrow as pa

cursor = con.execute("SELECT * FROM read_parquet('big.parquet')")

while True:
    chunk = cursor.fetch_chunk()  # returns a pyarrow.RecordBatch or None
    if chunk is None:
        break
    process_arrow(chunk)
```

The iterator API:

```python
for batch in con.execute("SELECT ...").fetch_arrow_reader():
    process_arrow(batch)
```

`fetch_chunk()` and the Arrow reader avoid the overhead of converting columnar DuckDB internals into Python row tuples. For numerical workloads, the Arrow path is 5–20x faster per batch than `fetchmany()` with tuple rows.

> [!info] DuckDB's internal chunk size is 2048 rows by default (one vector). `fetchmany(n)` with `n` as a multiple of 2048 aligns with internal batch boundaries and avoids partial-chunk overhead.

@feynman

Like paginating a database API with a cursor rather than fetching all records in one request — you control memory consumption by controlling how much you pull at once.

@card
id: wdd-ch09-c007
order: 7
title: Reading Multiple Files with Glob Patterns
teaser: `read_parquet('logs/*.parquet')` reads all matching files as a single logical table — DuckDB handles the union, schema validation, and the `filename` virtual column.

@explanation

DuckDB's file reader functions accept glob patterns:

```sql
-- Read all Parquet files in a directory
SELECT COUNT(*) FROM read_parquet('data/logs/*.parquet');

-- Read files across subdirectories
SELECT * FROM read_parquet('data/year=*/month=*/*.parquet');

-- CSV equivalent
SELECT * FROM read_csv('exports/batch_*.csv');
```

Behavior:
- DuckDB treats all matched files as a single logical table. Rows are concatenated — equivalent to `UNION ALL`.
- All files must have the same schema. DuckDB validates column names and types across files. On mismatch, the query fails with a schema error.
- Files are read in parallel across DuckDB's thread pool. On an 8-core machine reading 50 files, all 50 are opened and streamed concurrently.

The `filename` virtual column:

```sql
SELECT filename, COUNT(*)
FROM read_parquet('data/*.parquet', filename = true)
GROUP BY filename;
```

`filename = true` adds a `filename` column to each row containing the source file path. Useful for debugging schema mismatches, auditing which files contributed which rows, or tracking data provenance.

List patterns instead of glob:

```sql
SELECT * FROM read_parquet(['file1.parquet', 'file2.parquet', 'file3.parquet']);
```

Explicit lists are useful when files are not in the same directory or when you need precise control over which files are included.

> [!tip] Hive-partitioned directories (e.g., `year=2024/month=03/`) are automatically parsed as filter columns when you set `hive_partitioning = true`. DuckDB then uses partition directory names to skip entire directories, not just row groups.

@feynman

Like shell globbing for file arguments — the same `*.log` pattern you use with `grep` or `cat`, but DuckDB reads and queries the matching files as a single dataset.

@card
id: wdd-ch09-c008
order: 8
title: CSV Reading Options and Auto-Detection
teaser: DuckDB's CSV reader detects delimiters, headers, and types automatically — knowing the options lets you override detection when it gets things wrong.

@explanation

DuckDB's `read_csv()` runs a sampling pass on the first few thousand rows to detect delimiter, header presence, and column types. For well-formed CSVs, auto-detection works without any options:

```sql
SELECT * FROM read_csv('data.csv');
```

When auto-detection fails or is slow, override it explicitly:

```sql
SELECT * FROM read_csv(
    'data.csv',
    delim = '|',            -- pipe-delimited, not comma
    header = true,           -- first row is a header
    columns = {              -- explicit types skip the inference pass
        'user_id': 'INTEGER',
        'event_ts': 'TIMESTAMP',
        'amount': 'DOUBLE'
    }
);
```

Common override scenarios:
- **Delimiter:** auto-detection considers `,`, `\t`, `|`, `;`. Ambiguous files (e.g., a CSV with commas inside quoted fields) occasionally misdetect.
- **Header:** auto-detection reads the first row and guesses. On files with all-numeric first rows, it may incorrectly guess no header.
- **Types:** DuckDB defaults inferred string columns to `VARCHAR`. If you need `BIGINT` or `TIMESTAMP`, specifying `columns` skips inference and is faster on large files.
- **Encoding:** `encoding = 'latin1'` for legacy exports that are not UTF-8.

Handling malformed rows:

```sql
SELECT * FROM read_csv('messy.csv', ignore_errors = true);
```

`ignore_errors = true` skips rows that fail to parse (wrong column count, type conversion failures) rather than aborting the query. Use it for exploratory work on dirty data; audit the skipped rows by checking the `errors` table DuckDB exposes after the read.

> [!warning] `ignore_errors = true` silently discards bad rows. Always check how many rows were skipped with `SELECT * FROM duckdb_errors()` before trusting aggregate results from a messy CSV.

@feynman

Like HTTP content negotiation — the client sends preferences (Accept headers), the server can auto-detect what it has, but explicit declaration is always faster and more reliable than inference.

@card
id: wdd-ch09-c009
order: 9
title: Hive Partitioning and Partition Pruning
teaser: DuckDB reads directory names as filter columns in Hive-partitioned datasets, skipping entire directories when partition values don't match the query's WHERE clause.

@explanation

Hive-partitioned datasets use directory structure to encode partition keys:

```
data/
  year=2023/month=01/data.parquet
  year=2023/month=02/data.parquet
  year=2024/month=01/data.parquet
  year=2024/month=02/data.parquet
```

DuckDB reads partition keys from directory names when `hive_partitioning = true`:

```sql
SELECT SUM(revenue)
FROM read_parquet('data/**/*.parquet', hive_partitioning = true)
WHERE year = 2024 AND month = 1;
```

DuckDB evaluates the WHERE clause against partition directory names before opening any files. In this example, it opens only `year=2024/month=01/data.parquet` — a factor of 4 reduction in files opened for a 4-partition dataset, scaling to orders of magnitude reduction on large datasets.

Partition columns are added automatically to the result schema and can be used in SELECT and GROUP BY:

```sql
SELECT year, month, SUM(revenue)
FROM read_parquet('data/**/*.parquet', hive_partitioning = true)
GROUP BY year, month
ORDER BY year, month;
```

Partition pruning stacks with row group skipping and column pruning — all three can apply to the same query simultaneously, making DuckDB highly effective on well-structured Parquet datasets at the hundreds-of-GB scale.

Types of partition values are inferred from directory names. DuckDB correctly parses `year=2024` as integer 2024 and `event_date=2024-03-15` as a date literal.

> [!info] Auto-detection of Hive partitioning (without the explicit flag) was added in DuckDB 1.0. If you are on an older version, always pass `hive_partitioning = true` explicitly.

@feynman

Like a filesystem-level index — instead of scanning every file to find 2024 data, the directory structure itself tells DuckDB which folders contain what, and it skips the rest.

@card
id: wdd-ch09-c010
order: 10
title: Parallel File Reading
teaser: DuckDB reads multiple files and multiple row groups within a file in parallel across all available CPU cores — no configuration required.

@explanation

DuckDB's query engine is multi-threaded by default. For file reads, parallelism happens at two levels:

**Cross-file parallelism:** when reading multiple files via glob, DuckDB assigns files to worker threads from a thread pool. On an 8-core machine reading 20 Parquet files, up to 8 files are read and scanned simultaneously.

**Intra-file parallelism:** a single large Parquet file is also read in parallel. DuckDB distributes row groups across worker threads. A 10GB file with 80 row groups on an 8-core machine splits work roughly 10 row groups per thread.

The thread count defaults to the number of logical CPU cores. Override it:

```sql
SET threads = 4;
```

When parallelism matters most:
- Reading 50 small Parquet files (100MB each) — cross-file parallelism dominates. More threads directly reduces wall clock time.
- Reading one 50GB Parquet file — intra-file parallelism across row groups.
- I/O-bound reads (remote S3, slow spinning disk) — parallelism helps less; the bottleneck is throughput, not CPU.

On a laptop with a fast NVMe SSD, DuckDB reading a 10GB Parquet file typically achieves 1–3GB/s scan throughput using all cores. That puts a 10GB scan at 4–10 seconds.

> [!tip] On shared machines, reduce `threads` to leave cores for other processes. `SET threads = 4` on an 8-core CI runner prevents DuckDB from monopolizing the CPU while other jobs run.

@feynman

Like a thread pool processing a work queue — each file or row group is a task, workers pull tasks as they finish, and more workers means the queue drains faster up to the I/O limit.

@card
id: wdd-ch09-c011
order: 11
title: Reading from Remote Storage (S3, HTTP)
teaser: DuckDB reads Parquet and CSV directly from S3 URLs or HTTPS endpoints — column pruning and row group skipping work over HTTP range requests.

@explanation

With the `httpfs` extension loaded, DuckDB reads files from remote storage as efficiently as local disk — using HTTP range requests to fetch only the byte ranges it needs:

```sql
INSTALL httpfs;
LOAD httpfs;

-- Read a public S3 file
SELECT COUNT(*) FROM read_parquet('s3://my-bucket/data/events.parquet');

-- Configure credentials
SET s3_region = 'us-east-1';
SET s3_access_key_id = 'AKIA...';
SET s3_secret_access_key = 'xxx';

SELECT region, SUM(revenue)
FROM read_parquet('s3://my-bucket/sales/*.parquet')
GROUP BY region;
```

How remote reads stay efficient:
- DuckDB reads the Parquet footer first (a small range request to the end of the file).
- It uses the footer's row group statistics to identify which row groups to read.
- For each row group, it issues byte-range GET requests for only the needed columns.
- Multiple range requests are issued in parallel.

Practical performance on S3:
- Column pruning and row group skipping reduce the number of range requests proportionally.
- Network latency per request matters more than on local disk. Fewer, larger requests outperform many small ones — DuckDB batches range requests where possible.
- For repeated queries on the same file, caching the footer metadata locally (DuckDB does this automatically in-session) eliminates repeated footer fetches.

> [!info] DuckDB's `httpfs` extension supports S3-compatible APIs (MinIO, Cloudflare R2, DigitalOcean Spaces) in addition to AWS S3. Set `s3_endpoint` to point at non-AWS storage.

@feynman

Like a CDN with range request support — instead of downloading the whole file, the client requests only the byte ranges it needs, and the server returns just those bytes.

@card
id: wdd-ch09-c012
order: 12
title: Practical Scale Limits — What DuckDB Handles Comfortably
teaser: DuckDB handles hundreds of GB comfortably on a single machine; the practical ceiling is where data volume exceeds single-node I/O or where concurrency requirements appear.

@explanation

DuckDB's practical scale by scenario:

**Comfortable range (DuckDB is the right tool):**
- Parquet files up to 500GB on a machine with sufficient RAM and a fast SSD.
- Glob queries over hundreds of Parquet files totaling 1–2TB when queries are selective (row group skipping eliminates most I/O).
- Aggregation and JOIN queries on datasets that fit in RAM (no spilling).
- CSV files up to ~50GB on modern hardware.

**Works but slower (consider whether it is worth it):**
- 2–5TB total data with aggressive partition pruning — viable, but queries take minutes rather than seconds.
- Queries that require full table scans of very large tables (no predicate pushdown possible).
- Complex multi-way JOINs with large build-side tables that exceed memory and spill heavily.

**Where Spark or ClickHouse becomes the better choice:**
- Data volume exceeds what a single machine can hold on fast storage (multi-TB with no partition pruning).
- Multiple concurrent analytical queries from many users — DuckDB's single-writer constraint becomes a bottleneck for write-heavy workloads.
- Incremental streaming ingestion of high-frequency events.
- Datasets requiring distributed processing across many machines.

Numbers to anchor expectations: on a modern 32-core machine with 128GB RAM and NVMe storage, DuckDB has been benchmarked scanning ~1TB/minute for simple aggregations over Parquet. Most real workloads involve more complex queries and land in the 50–200GB/minute range.

> [!warning] Storage speed is often the real bottleneck, not DuckDB itself. A query that runs in 30 seconds on NVMe local storage may take 8 minutes on a network-attached volume — the engine is the same, the I/O substrate is not.

@feynman

Like a single high-end server vs a cluster — the single machine handles more than most people assume, and the cluster becomes necessary only when you genuinely exceed what one fast machine can do.

@card
id: wdd-ch09-c013
order: 13
title: The `COPY` Statement for Large Exports
teaser: `COPY ... TO` streams query results directly to a Parquet or CSV file without materializing all rows in memory — the right way to export large result sets.

@explanation

For large exports, use `COPY ... TO` rather than fetching results into Python and writing them manually:

```sql
-- Export a query result to Parquet
COPY (
    SELECT user_id, event_type, SUM(value) AS total
    FROM read_parquet('events/*.parquet')
    GROUP BY user_id, event_type
) TO 'output/aggregated.parquet' (FORMAT PARQUET);

-- Export to CSV
COPY (SELECT * FROM read_parquet('data.parquet') WHERE year = 2024)
TO 'output/2024.csv' (HEADER, DELIMITER ',');
```

`COPY ... TO` is a streaming export: DuckDB processes the query in chunks and writes each chunk to the output file as it is produced. The full result set never needs to fit in memory simultaneously.

Partitioned export:

```sql
COPY (SELECT * FROM read_parquet('events.parquet'))
TO 'output/' (FORMAT PARQUET, PARTITION_BY (year, month));
```

This creates a Hive-partitioned directory structure automatically:
- `output/year=2024/month=01/data_0.parquet`
- `output/year=2024/month=02/data_0.parquet`
- etc.

The resulting files are immediately queryable by DuckDB (and other Parquet-aware tools) with partition pruning.

Row group size control:

```sql
COPY (...) TO 'output.parquet' (FORMAT PARQUET, ROW_GROUP_SIZE 100000);
```

Smaller row groups improve future query performance (finer-grained skipping) at the cost of more metadata overhead. 100,000–500,000 rows per group is a reasonable range.

> [!tip] For multi-file Parquet exports, use `PARTITION_BY` rather than manually splitting queries. DuckDB writes files in parallel across threads, making partitioned export significantly faster than running separate queries per partition.

@feynman

Like streaming an HTTP response to disk with `curl -o` — the data flows through without buffering the whole thing in RAM, and the output is written as it arrives.

@card
id: wdd-ch09-c014
order: 14
title: Profiling Large-File Queries
teaser: `EXPLAIN ANALYZE` shows which row groups were skipped, how much I/O was issued, and where time was spent — essential for diagnosing slow large-file queries.

@explanation

Before optimizing a slow query, measure it:

```sql
EXPLAIN ANALYZE
SELECT region, SUM(revenue)
FROM read_parquet('sales.parquet')
WHERE event_date >= '2024-01-01'
GROUP BY region;
```

The output includes:
- **Operator timings:** how long each pipeline stage took (scan, filter, hash aggregate).
- **Rows read vs rows estimated:** whether the planner's cardinality estimates were accurate.
- **Pushdown information:** which predicates were pushed into the file scan.

For Parquet specifically, check the scan operator output for row group statistics:

```sql
SELECT * FROM parquet_metadata('sales.parquet');
```

This shows every row group's min/max statistics for every column — letting you verify whether your filter predicate aligns with the file's sort order.

```sql
SELECT * FROM parquet_schema('sales.parquet');
```

Shows the column schema, data types, encoding, and compression codec — useful when diagnosing type mismatch errors or understanding why a file is larger than expected.

Practical profiling workflow for a slow query:
- Run `EXPLAIN ANALYZE` and note the scan operator's elapsed time as a fraction of total.
- Check `parquet_metadata()` to see if row group ranges overlap with your filter predicate.
- If most row groups are being read despite a selective filter, the file is not sorted on the filter column.
- Consider rewriting the file sorted on the filter column, or switching to a partitioned directory structure.

> [!info] `EXPLAIN ANALYZE` runs the query. For very large files where you only want the plan without running, use `EXPLAIN` alone — it shows the logical plan without executing and is instantaneous.

@feynman

Like `strace` or `perf stat` for a system call — you cannot optimize what you cannot measure, and the profiler tells you whether you are spending time on I/O, CPU, or memory allocation.
