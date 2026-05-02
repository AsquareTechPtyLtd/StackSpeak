@chapter
id: wdd-ch04-file-format-support
order: 4
title: File Format Support
summary: DuckDB reads and writes Parquet, CSV, JSON, Iceberg, Delta, Excel, and Arrow IPC — understanding each format's strengths determines when to use which.

@card
id: wdd-ch04-c001
order: 1
title: Parquet — The Primary Format
teaser: Parquet is the file format DuckDB is most optimized for — columnar, compressed, and metadata-rich enough to enable predicate pushdown and column pruning.

@explanation

Parquet is the default choice for DuckDB workloads. The format's columnar layout matches DuckDB's internal execution model, and its rich metadata enables significant query optimization.

Reading Parquet:
```sql
-- Single file
SELECT * FROM 'data.parquet';

-- Multiple files with glob
SELECT * FROM 'data/**/*.parquet';

-- With schema inspection
DESCRIBE SELECT * FROM 'data.parquet';

-- Explicit read function with options
SELECT * FROM read_parquet('data.parquet', hive_partitioning=true);
```

Writing Parquet:
```sql
COPY (SELECT * FROM orders WHERE year = 2024) TO 'orders_2024.parquet' (FORMAT PARQUET);

-- With compression
COPY orders TO 'orders.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- With row group size (affects read parallelism)
COPY events TO 'events.parquet' (FORMAT PARQUET, ROW_GROUP_SIZE 100000);
```

From Python:
```python
# Write to Parquet
con.execute("COPY orders TO 'orders.parquet' (FORMAT PARQUET)")

# Or use PyArrow integration
import pyarrow.parquet as pq
arrow_table = con.execute("SELECT * FROM orders").fetch_arrow_table()
pq.write_table(arrow_table, 'orders.parquet', compression='zstd')
```

Parquet optimization features DuckDB uses:
- **Column pruning:** only reads columns referenced in the query.
- **Predicate pushdown:** filters using min/max statistics in row group metadata to skip row groups.
- **Dictionary encoding:** for low-cardinality columns, avoids reading repeated string values.

> [!tip] Use ZSTD compression for Parquet files that will be queried repeatedly. Compared to Snappy (Parquet default), ZSTD achieves 20-40% better compression with similar or faster decompression speed.

@feynman

Like a columnar spreadsheet that the database can read selectively — instead of reading the whole file, DuckDB reads only the columns and row groups it needs.

@card
id: wdd-ch04-c002
order: 2
title: CSV — Auto-Detection and Manual Override
teaser: DuckDB's CSV reader auto-detects delimiters, headers, and types in most cases — but knowing when to override matters for production reliability.

@explanation

DuckDB reads CSV files with `read_csv_auto` (or the shorthand `'file.csv'` in a FROM clause).

```sql
-- Auto-detected schema
SELECT * FROM 'orders.csv' LIMIT 5;

-- Inspect detected schema
DESCRIBE SELECT * FROM read_csv_auto('orders.csv');

-- Manual schema specification
SELECT * FROM read_csv('orders.csv',
    sep = ',',
    header = true,
    columns = {
        'order_id': 'INTEGER',
        'customer_id': 'INTEGER',
        'amount': 'DECIMAL(10,2)',
        'order_date': 'DATE',
        'status': 'VARCHAR'
    }
);
```

Common auto-detection overrides:

```sql
-- Semicolon delimiter
SELECT * FROM read_csv('euro_data.csv', sep=';');

-- No header row
SELECT * FROM read_csv('data.csv', header=false);

-- Specific null string
SELECT * FROM read_csv('data.csv', nullstr='NA');

-- Skip first N rows
SELECT * FROM read_csv('data.csv', skip=2);

-- Quoted fields with non-standard quote char
SELECT * FROM read_csv('data.csv', quote="'");
```

Writing CSV:
```sql
COPY (SELECT * FROM orders LIMIT 1000) TO 'sample.csv' (FORMAT CSV, HEADER true);
```

Multi-file CSV queries:
```sql
-- Query all CSVs in a directory
SELECT * FROM read_csv('logs/*.csv', union_by_name=true);
```

`union_by_name=true` aligns columns by name rather than position — useful when multiple CSV files have slightly different column orders.

> [!warning] Auto-detected types for date columns default to VARCHAR if the format is ambiguous (e.g., `01/02/2024` — month/day or day/month?). Always specify explicit types for date columns in production pipelines.

@feynman

Like `pandas.read_csv` with better defaults — it guesses right most of the time, but production code should always specify the schema explicitly.

@card
id: wdd-ch04-c003
order: 3
title: JSON — Reading Nested Data
teaser: DuckDB reads JSON files and JSON columns natively, including nested and semi-structured data, with functions to extract, navigate, and flatten the structure.

@explanation

DuckDB reads JSON files directly, handling both newline-delimited JSON (NDJSON) and JSON arrays.

```sql
-- Newline-delimited JSON (one JSON object per line)
SELECT * FROM 'events.ndjson';

-- JSON array file
SELECT * FROM read_json_auto('events.json', format='array');

-- Auto-detect format
SELECT * FROM read_json_auto('events.json');

-- Extract nested fields
SELECT
    json_extract_string(payload, '$.user.id') AS user_id,
    json_extract(payload, '$.attributes') AS attributes
FROM read_json_auto('events.json');
```

JSON path extraction:
```sql
-- JSONPath syntax
SELECT payload->>'$.user.name' AS name FROM events;

-- Nested access
SELECT payload->'$.address'->'city' AS city FROM events;
```

Flattening JSON arrays into rows:
```sql
-- Unnest a JSON array field into rows
SELECT
    event_id,
    unnest(json_extract(payload, '$.tags')::VARCHAR[]) AS tag
FROM events;
```

Struct extraction from JSON:
```sql
-- Convert JSON object to a typed struct
SELECT json_extract(payload, '$.address')::STRUCT(
    street VARCHAR, city VARCHAR, zip VARCHAR
) AS address
FROM events;
```

Writing JSON:
```sql
COPY orders TO 'orders.json' (FORMAT JSON);
COPY orders TO 'orders.ndjson' (FORMAT JSON, ARRAY false);
```

> [!info] For very large JSON files with deeply nested structures, consider converting to Parquet first: `COPY (SELECT * FROM 'raw.ndjson') TO 'data.parquet' (FORMAT PARQUET)`. Subsequent queries on the Parquet file will be significantly faster.

@feynman

Like `jq` with a full SQL query optimizer — navigate nested JSON structures with paths, but aggregate and join across millions of records at the same time.

@card
id: wdd-ch04-c004
order: 4
title: Apache Iceberg Support
teaser: DuckDB reads Apache Iceberg tables directly in 2026 — including snapshot time travel and partition pruning — making it a capable Iceberg query engine without Spark.

@explanation

DuckDB's `iceberg` extension provides native Iceberg table reads. As of DuckDB 1.1, Iceberg support is bundled in the distribution (no separate install needed in most contexts).

```sql
-- Load the extension if not auto-loaded
LOAD iceberg;

-- Query an Iceberg table (local path or S3 URI)
SELECT * FROM iceberg_scan('s3://my-bucket/my-iceberg-table/');

-- Use the catalog (if you have a REST or Glue catalog)
-- Note: full catalog integration varies by catalog implementation
SELECT * FROM iceberg_scan('/path/to/iceberg-table/', allow_moved_paths=true);

-- Time travel by snapshot ID
SELECT * FROM iceberg_scan('s3://bucket/table/', snapshot_id=8765432198765);

-- Time travel by timestamp
SELECT * FROM iceberg_scan('s3://bucket/table/', version_as_of='2024-01-15 12:00:00');
```

What DuckDB supports with Iceberg:
- Reading Parquet-backed Iceberg tables (v1 and v2 format).
- Partition pruning on Iceberg partition specs.
- Snapshot time travel.
- Schema evolution awareness (reads with current schema mapped to historical snapshots).
- Integration with AWS Glue Data Catalog via the `aws` extension.

What DuckDB does not support (as of 2026):
- Writing to Iceberg tables (reads only).
- Sort order optimization hints from Iceberg metadata.
- Full REST catalog integration for all catalog implementations.

For write-path Iceberg workflows, pair DuckDB with a dedicated Iceberg writer (Spark, Flink, or an Iceberg REST catalog client).

> [!tip] DuckDB + Iceberg on S3 is a compelling alternative to Athena for ad-hoc Iceberg queries — lower latency for interactive queries, no per-scan cost, and zero infrastructure beyond the DuckDB binary.

@feynman

Like reading a versioned document store — the table tracks its own history, and DuckDB can open any version like checking out a git commit.

@card
id: wdd-ch04-c005
order: 5
title: Delta Lake Support
teaser: DuckDB reads Delta Lake tables via the delta extension — including time travel and change data feed — for teams already invested in the Delta ecosystem.

@explanation

The `delta` extension adds Delta Lake read support. It became a community extension in DuckDB 1.1.

```sql
-- Install and load
INSTALL delta;
LOAD delta;

-- Query a Delta table
SELECT * FROM delta_scan('/path/to/delta-table/');

-- S3-backed Delta table (requires httpfs loaded too)
LOAD httpfs;
SELECT COUNT(*) FROM delta_scan('s3://my-bucket/delta-table/');

-- Time travel by version
SELECT * FROM delta_scan('/path/to/table/', version=42);

-- Time travel by timestamp
SELECT * FROM delta_scan('/path/to/table/', timestamp='2024-06-01 00:00:00');
```

What the delta extension supports:
- Reading Delta v1 and v2 tables.
- Time travel by version number and timestamp.
- Partition pruning.
- Schema evolution (reads latest schema by default).
- Deletion vectors (DV-aware reads so soft-deleted rows are excluded).

Delta vs Iceberg for DuckDB users in 2026:
- Both are read-only in DuckDB. For writes, use a Delta-native writer (Spark, Delta-rs, polars).
- Delta extension is community-maintained vs Iceberg which ships with DuckDB core.
- Choose based on your existing ecosystem — Delta if your warehouse is Databricks, Iceberg if it is AWS Glue or Snowflake.

```python
import duckdb
con = duckdb.connect()
con.install_extension('delta')
con.load_extension('delta')
result = con.execute("SELECT * FROM delta_scan('s3://bucket/table/')").df()
```

> [!info] Delta Lake's transaction log is a directory of JSON files. DuckDB reads the log to determine which Parquet files constitute the current table state, then reads those files directly. The query plan bypasses the Delta engine entirely.

@feynman

Like reading a git repo's history to figure out which files are in the current checkout — the log tells you what exists, then you read the actual files.

@card
id: wdd-ch04-c006
order: 6
title: Excel Support
teaser: DuckDB's Excel extension reads .xlsx files directly as tables — useful for the significant amount of real-world data that lives in spreadsheets.

@explanation

The `excel` extension adds read and write support for `.xlsx` files.

```sql
INSTALL excel;
LOAD excel;

-- Read an Excel file (first sheet by default)
SELECT * FROM read_xlsx('report.xlsx');

-- Read a specific sheet
SELECT * FROM read_xlsx('report.xlsx', sheet='Sales Data');

-- Read a specific range
SELECT * FROM read_xlsx('report.xlsx', sheet='Sheet1', range='A1:F100');

-- Skip header rows
SELECT * FROM read_xlsx('report.xlsx', header=false);
```

Writing Excel:
```sql
COPY (SELECT * FROM orders WHERE year = 2024)
TO 'output.xlsx' (FORMAT XLSX);
```

From Python:
```python
con.install_extension('excel')
con.load_extension('excel')
df = con.execute("SELECT * FROM read_xlsx('data.xlsx')").df()
```

Practical use: ETL for stakeholder data that arrives as Excel files. Instead of converting to CSV first, query the Excel file directly and transform in DuckDB.

Limitations:
- Only `.xlsx` format (Open XML). Older `.xls` binary format is not supported.
- No formula evaluation — cell values only, not formula results. Excel must have calculated the values before DuckDB reads them.
- Images, charts, and formatting are ignored.

> [!tip] Combine Excel reading with Parquet writing for a simple "spreadsheet to data lake" pipeline: `COPY (SELECT * FROM read_xlsx('report.xlsx')) TO 's3://bucket/data.parquet' (FORMAT PARQUET)`.

@feynman

Like treating a spreadsheet as a database table — skip the export-to-CSV step and query the Excel file directly as if it were already structured data.

@card
id: wdd-ch04-c007
order: 7
title: Arrow IPC — Zero-Copy Interop
teaser: DuckDB's Arrow integration enables zero-copy data exchange with any Arrow-compatible library — no serialization overhead when moving data between DuckDB and Pandas, Polars, or cuDF.

@explanation

Apache Arrow defines a columnar in-memory format and IPC (Inter-Process Communication) serialization format. DuckDB uses Arrow as its primary interoperability layer.

The key property: DuckDB's internal columnar format is Arrow-compatible. Transferring a result set to an Arrow table requires no data copying — DuckDB hands over a pointer to its internal buffers.

```python
import duckdb
import pyarrow as pa

con = duckdb.connect()

# Zero-copy result to Arrow table
arrow_table = con.execute("SELECT * FROM 'data.parquet'").fetch_arrow_table()

# Pass Arrow table back to DuckDB for further querying
result = con.execute("SELECT region, SUM(revenue) FROM arrow_table GROUP BY region")
```

Arrow streaming (for large results that don't fit in memory):
```python
# Fetch as a streaming RecordBatch reader
reader = con.execute("SELECT * FROM large_table").fetch_record_batch(rows_per_batch=50000)
for batch in reader:
    # Process 50,000 rows at a time
    process(batch)
```

DuckDB and Polars via Arrow:
```python
import polars as pl

# Query DuckDB, get Polars DataFrame
df = con.execute("SELECT * FROM 'data.parquet'").pl()

# Pass Polars DataFrame to DuckDB
polars_df = pl.read_parquet('data.parquet')
result = con.execute("SELECT * FROM polars_df WHERE value > 100").df()
```

Arrow IPC files:
```sql
-- Read Arrow IPC stream file
SELECT * FROM read_arrow('data.arrows');
```

> [!info] "Zero-copy" means DuckDB does not copy the data when handing it to Arrow. The Arrow table references DuckDB's memory. If the DuckDB connection is closed before the Arrow table is consumed, the referenced memory is freed. Always consume Arrow results before closing the connection.

@feynman

Like passing a reference rather than a copy — the data stays in one place in memory; both DuckDB and the Arrow consumer just hold a pointer to it.

@card
id: wdd-ch04-c008
order: 8
title: Hive Partitioning
teaser: DuckDB reads Hive-partitioned directory structures and propagates partition keys as virtual columns — enabling efficient partition pruning across large datasets.

@explanation

Hive partitioning organizes data files into directories named `key=value`, creating a physical partition structure. DuckDB understands this layout and uses it for query optimization.

```
data/
├── year=2023/
│   ├── month=01/
│   │   └── events.parquet
│   └── month=02/
│       └── events.parquet
└── year=2024/
    ├── month=01/
    │   └── events.parquet
    └── month=02/
        └── events.parquet
```

```sql
-- Read with Hive partitioning enabled
SELECT * FROM read_parquet('data/**/*.parquet', hive_partitioning=true);

-- The partition keys become query-able columns
SELECT year, month, COUNT(*) 
FROM read_parquet('data/**/*.parquet', hive_partitioning=true)
GROUP BY year, month;

-- Partition pruning: DuckDB only reads year=2024 directories
SELECT COUNT(*) 
FROM read_parquet('data/**/*.parquet', hive_partitioning=true)
WHERE year = 2024;
```

Writing Hive-partitioned output:
```sql
COPY orders TO 'output/' (FORMAT PARQUET, PARTITION_BY (year, month));
-- Creates output/year=2024/month=01/data.parquet, etc.
```

Partition pruning behavior:
When a `WHERE` clause filters on a Hive partition key, DuckDB skips reading the non-matching directories entirely. For a dataset with 48 monthly partitions, a query filtered to one month reads approximately 1/48 of the data.

> [!tip] Write Hive-partitioned Parquet with the columns you filter on most frequently as the outer partition keys. Date-based partitions (`year`, `month`, `day`) are the most common choice for event and log data.

@feynman

Like file system folders as database indexes — the directory structure encodes the partition key values, and skipping a folder skips all the data in it.

@card
id: wdd-ch04-c009
order: 9
title: DuckLake — A DuckDB-Native Table Format
teaser: DuckLake is an open table format designed around DuckDB's strengths — simpler than Iceberg with a SQL-managed catalog stored in a DuckDB database.

@explanation

DuckLake is an open table format introduced in 2025, designed specifically for DuckDB-centric architectures. It addresses the operational complexity of Iceberg and Delta by storing the catalog metadata in a DuckDB database file rather than a directory of JSON files.

Key differences from Iceberg:

- **Catalog storage:** DuckLake stores metadata in a DuckDB file (SQL tables). Iceberg stores metadata as JSON files in object storage alongside the data.
- **Transactional catalog:** DuckLake catalog operations use DuckDB's ACID transactions. This eliminates the eventual-consistency concerns of Iceberg's JSON-file-based catalog.
- **Simpler tooling:** read and write DuckLake with DuckDB directly, without a separate catalog server.

```sql
-- Attach a DuckLake catalog
ATTACH 'ducklake:catalog.duckdb?data_path=s3://my-bucket/data' AS lake;

-- Create a table in the catalog
CREATE TABLE lake.orders (
    order_id INTEGER,
    amount DECIMAL(10,2),
    order_date DATE
);

-- Insert and query with standard SQL
INSERT INTO lake.orders SELECT * FROM 'new_orders.parquet';
SELECT * FROM lake.orders WHERE order_date >= '2024-01-01';

-- Time travel
SELECT * FROM lake.orders AT (VERSION => 42);
```

DuckLake in 2026: growing adoption for DuckDB-native pipelines where teams want lake format benefits (ACID writes, time travel, schema evolution) without Iceberg's operational overhead. Less ecosystem tooling than Iceberg — not yet readable by Spark or Flink natively.

> [!info] DuckLake is the right choice when DuckDB is your primary query engine and you do not need to share the table format with Spark, Flink, or other systems. For multi-engine environments, Iceberg remains the more portable choice.

@feynman

Like SQLite for the catalog layer — instead of a complex distributed metadata store, the catalog is just a database file you can open and inspect.

@card
id: wdd-ch04-c010
order: 10
title: Format Performance Comparison
teaser: The file format you choose affects query speed by an order of magnitude — columnar compressed formats like Parquet dominate for analytical workloads, but each format has tradeoffs.

@explanation

Format performance for analytical queries on a 10GB dataset (representative benchmark, not universal):

**Parquet (ZSTD compressed):**
- Storage: ~2GB (5:1 compression typical)
- Read speed: fastest for column-selective queries; DuckDB reads only needed columns
- Predicate pushdown: yes (row group statistics)
- Best for: all new analytical datasets

**CSV (gzip compressed):**
- Storage: ~3-4GB
- Read speed: slower than Parquet — row-oriented, requires parsing every column even for selective queries
- Predicate pushdown: none
- Best for: interoperability and source files from systems that don't produce Parquet

**JSON/NDJSON:**
- Storage: ~5-8GB uncompressed
- Read speed: slowest — each line requires JSON parsing; no column pruning
- Best for: API responses, log files, event streams

**Iceberg/Delta (over Parquet):**
- Storage: Parquet storage plus small metadata overhead
- Read speed: comparable to raw Parquet plus partition pruning via table metadata
- Best for: when you need ACID writes, time travel, or schema evolution

**Arrow IPC:**
- Storage: uncompressed, approximately equal to in-memory size
- Read speed: fastest for programmatic access — zero deserialization overhead when reading into Arrow-compatible tools
- Best for: inter-process data handoff, not long-term storage

> [!tip] For a dataset you will query many times, the one-time cost of converting CSV or JSON to Parquet pays back in seconds on the first query and every query after. For a 10GB CSV file, the conversion takes under a minute; subsequent query times drop from minutes to seconds.

@feynman

Like choosing between JSON and binary serialization — the choice that is easiest to write is rarely the fastest to read, especially when you need it millions of times.
