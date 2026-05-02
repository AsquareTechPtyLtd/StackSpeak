@chapter
id: wdd-ch02-getting-started
order: 2
title: Getting Started — CLI and Language Bindings
summary: Installing DuckDB and making your first queries from the CLI, Python, JavaScript/WASM, JVM, R, and Go — with the practical differences between each binding.

@card
id: wdd-ch02-c001
order: 1
title: The DuckDB CLI
teaser: The DuckDB CLI is a self-contained binary with a full SQL REPL — download one file and you have a complete analytical SQL environment.

@explanation

The DuckDB CLI ships as a single self-contained binary with no dependencies. Download it, make it executable, and start querying.

```bash
# macOS (Homebrew)
brew install duckdb

# Linux — download directly
curl -L https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip -o duckdb.zip
unzip duckdb.zip && chmod +x duckdb
./duckdb

# Windows (WinGet)
winget install DuckDB.cli
```

Starting the CLI:

```bash
duckdb                        # in-memory, nothing persisted
duckdb mydata.duckdb          # file-backed, persists between sessions
duckdb -readonly mydata.duckdb  # read-only, multiple processes can open
```

Once inside the REPL, useful meta-commands:

- `.help` — list all dot commands
- `.tables` — list tables
- `.schema tablename` — show CREATE statement
- `.mode markdown` — output results as a Markdown table (useful for docs)
- `.output result.csv` + `.mode csv` — redirect output to a file

The CLI evaluates any SQL you type. Semicolons end a statement. Multi-line input is supported — press Enter to continue the statement, terminate with `;`.

> [!tip] The CLI accepts a SQL file as an argument: `duckdb mydb.duckdb < transform.sql`. Useful for running migration scripts or pipeline steps without opening an interactive session.

@feynman

Like `psql` for PostgreSQL but self-contained — one binary, no server to start, ready to query immediately.

@card
id: wdd-ch02-c002
order: 2
title: Python Bindings — The Most Common Entry Point
teaser: The DuckDB Python package gives you a SQL engine inside any Python environment, with direct integration for Pandas, Polars, and Arrow.

@explanation

```bash
pip install duckdb
```

That is the entire installation. The `duckdb` package bundles the full engine — no separate binary needed.

Basic usage:

```python
import duckdb

# In-memory connection (default)
con = duckdb.connect()

# File-backed connection
con = duckdb.connect('mydata.duckdb')

# Query a Parquet file directly
result = con.execute("SELECT * FROM 'data/*.parquet' LIMIT 10").fetchdf()

# Query a Pandas DataFrame directly (zero-copy read)
import pandas as pd
df = pd.read_csv('data.csv')
result = con.execute("SELECT region, SUM(revenue) FROM df GROUP BY region").fetchdf()

# Return as Arrow table
arrow_table = con.execute("SELECT * FROM 'data.parquet'").fetch_arrow_table()

# Return as Polars DataFrame
polars_df = con.execute("SELECT * FROM 'data.parquet'").pl()
```

Connection lifecycle: a `duckdb.connect()` call returns a `DuckDBPyConnection`. In-memory connections are garbage-collected. File-backed connections should be closed explicitly (`con.close()`) or used as a context manager.

The module-level `duckdb.execute()` uses a thread-local in-memory connection — convenient for scripts, but use explicit connections in multi-threaded code.

> [!warning] In multi-threaded Python code, create one connection per thread. The `duckdb.connect()` connection object is not thread-safe for concurrent queries from multiple threads.

@feynman

Like having `psycopg2` but the database engine is already inside the package — no `pg_hba.conf`, no connection string to a server.

@card
id: wdd-ch02-c003
order: 3
title: Python Connection Patterns
teaser: How you structure DuckDB connections in Python — thread-local, context manager, or explicit close — affects correctness in scripts, notebooks, and servers.

@explanation

DuckDB Python connections come in several flavors with different lifetime and sharing semantics.

**Default module-level connection (scripts and notebooks):**
```python
import duckdb
# Implicit in-memory connection, thread-local
result = duckdb.sql("SELECT 42").fetchall()
```
Fine for single-threaded scripts and notebooks. Avoid in servers or multi-threaded code.

**Explicit in-memory connection:**
```python
con = duckdb.connect(':memory:')
# ... use con ...
con.close()
```

**File-backed connection:**
```python
con = duckdb.connect('warehouse.duckdb')
con.execute("CREATE TABLE IF NOT EXISTS events AS SELECT * FROM 'input.parquet'")
con.close()
```

**Context manager (recommended for file-backed):**
```python
with duckdb.connect('warehouse.duckdb') as con:
    con.execute("INSERT INTO events SELECT * FROM 'new_batch.parquet'")
    # Automatically closed and committed on exit
```

**Read-only connection (safe for multiple processes):**
```python
# Multiple processes can each open read-only connections simultaneously
con = duckdb.connect('warehouse.duckdb', read_only=True)
```

**Cursor-based (for parallel queries on one connection):**
```python
con = duckdb.connect(':memory:')
cur1 = con.cursor()
cur2 = con.cursor()
# Each cursor can run queries independently from the same connection
```

> [!info] A file-backed DuckDB connection holds a write lock on the `.duckdb` file. Opening a second write connection to the same file from a different process raises `IOException: Could not set lock on file`. Use read-only mode for read-access from additional processes.

@feynman

Like database connection pooling — the semantics of how you open and share connections determine whether concurrent access works correctly.

@card
id: wdd-ch02-c004
order: 4
title: JavaScript and DuckDB-Wasm
teaser: DuckDB runs in the browser and in Node.js via a WASM build — enabling client-side analytical queries without a server.

@explanation

DuckDB-Wasm compiles the full DuckDB engine to WebAssembly. It runs in modern browsers and in Node.js/Bun.

```bash
# Node.js installation
npm install @duckdb/duckdb-wasm
```

Basic Node.js usage:

```javascript
import * as duckdb from '@duckdb/duckdb-wasm';

const JSDELIVR_BUNDLES = duckdb.getJsDelivrBundles();
const bundle = await duckdb.selectBundle(JSDELIVR_BUNDLES);
const worker = new Worker(bundle.mainWorker);
const logger = new duckdb.ConsoleLogger();
const db = new duckdb.AsyncDuckDB(logger, worker);
await db.instantiate(bundle.mainModule, bundle.pthreadWorker);

const conn = await db.connect();
const result = await conn.query('SELECT 42 AS answer');
console.log(result.toArray());
await conn.close();
```

Browser usage follows the same pattern — import from a CDN (jsdelivr, unpkg) and instantiate.

DuckDB-Wasm capabilities:
- Full SQL query support including window functions and CTEs.
- Read Parquet, CSV, and JSON files loaded via the browser's Fetch API.
- Query Arrow IPC streams directly.
- Run analytical queries over data downloaded to the browser — no server roundtrip for each query.

Limitations compared to the native library:
- Single-threaded execution (WASM thread model constraints).
- No S3/HTTPFS extension in the browser build (CORS and credential handling limitations).
- Slightly slower than native due to WASM overhead.

> [!tip] DuckDB-Wasm is the engine behind several no-server BI tools. If you are building an analytics product where the dataset fits in the browser (< ~500MB), it eliminates the need for a query API entirely.

@feynman

Like running SQLite in the browser — the database engine ships with the page, and queries never leave the client.

@card
id: wdd-ch02-c005
order: 5
title: Java and JVM Bindings
teaser: DuckDB's JDBC driver gives JVM languages — Java, Kotlin, Scala — a standard database connection to DuckDB with full SQL support.

@explanation

DuckDB provides a standard JDBC driver. Add it as a Maven or Gradle dependency — the driver bundles the native library for your platform.

```xml
<!-- Maven -->
<dependency>
    <groupId>org.duckdb</groupId>
    <artifactId>duckdb_jdbc</artifactId>
    <version>1.1.0</version>
</dependency>
```

```kotlin
// Kotlin usage
import java.sql.DriverManager

val conn = DriverManager.getConnection("jdbc:duckdb:/path/to/data.duckdb")
val stmt = conn.createStatement()
val rs = stmt.executeQuery("SELECT COUNT(*) FROM 'data/*.parquet'")
while (rs.next()) {
    println(rs.getLong(1))
}
conn.close()
```

In-memory connection: `DriverManager.getConnection("jdbc:duckdb:")`.

The JDBC driver supports:
- Standard `PreparedStatement` with parameterized queries.
- `ResultSet` iteration.
- Connection pooling via standard JDBC pool libraries (HikariCP, c3p0).
- Appender API for fast bulk inserts (DuckDB-specific extension to JDBC).

The Appender API bypasses JDBC overhead for bulk ingestion:
```java
DuckDBConnection duckConn = (DuckDBConnection) conn;
try (var appender = duckConn.createAppender(DuckDBConnection.DEFAULT_SCHEMA, "events")) {
    appender.beginRow();
    appender.append("2024-01-01");
    appender.append(42L);
    appender.endRow();
}
```

> [!info] For Spark workloads, `dbt-duckdb` and direct JDBC are the common integration paths. A DuckDB-native Spark connector does not exist — the embedding model is fundamentally incompatible with Spark's distributed executor model.

@feynman

Like any other JDBC driver — the API is standard, but the database is embedded in the JAR rather than running on a remote host.

@card
id: wdd-ch02-c006
order: 6
title: R Bindings
teaser: The DuckDB R package integrates tightly with the tidyverse — you can query DuckDB tables using dplyr verbs or raw SQL, and results come back as data frames.

@explanation

```r
install.packages("duckdb")
```

Basic usage:

```r
library(duckdb)
library(dplyr)

# Create connection
con <- dbConnect(duckdb(), dbdir = "mydata.duckdb")

# Query a Parquet file
result <- dbGetQuery(con, "SELECT * FROM 'data/*.parquet' LIMIT 10")

# Create a table from a CSV
dbExecute(con, "CREATE TABLE orders AS SELECT * FROM read_csv_auto('orders.csv')")

# Use dplyr verbs via dbplyr
tbl(con, "orders") |>
  group_by(region) |>
  summarise(total_revenue = sum(revenue, na.rm = TRUE)) |>
  collect()

dbDisconnect(con, shutdown = TRUE)
```

The `dbplyr` integration translates dplyr verbs to SQL and executes them in DuckDB. This is often 5-20x faster than equivalent dplyr operations on a data frame, because DuckDB's vectorized engine handles the computation.

DuckDB and Arrow in R:
```r
library(arrow)
arrow_table <- arrow::read_parquet("data.parquet", as_data_frame = FALSE)
dbWriteTable(con, "data", arrow_table)
```

> [!tip] For large datasets in R, DuckDB is typically faster than `data.table` for aggregation-heavy workloads and dramatically faster than base R or dplyr on in-memory data frames. Run benchmarks for your specific workload before assuming one is faster.

@feynman

Like `RSQLite` but built for analytics — the same DBI interface but the engine underneath is columnar and vectorized instead of row-oriented.

@card
id: wdd-ch02-c007
order: 7
title: Go Bindings
teaser: The go-duckdb package wraps the DuckDB C API with CGo — full SQL support with good performance, at the cost of CGo build complexity.

@explanation

```bash
go get github.com/marcboeker/go-duckdb
```

The `go-duckdb` package uses CGo to call the DuckDB C library. It implements Go's `database/sql` interface, so standard library patterns apply.

```go
package main

import (
    "database/sql"
    "fmt"
    _ "github.com/marcboeker/go-duckdb"
)

func main() {
    db, err := sql.Open("duckdb", "data.duckdb")
    if err != nil {
        panic(err)
    }
    defer db.Close()

    rows, err := db.Query("SELECT region, SUM(revenue) FROM 'sales.parquet' GROUP BY region")
    if err != nil {
        panic(err)
    }
    defer rows.Close()

    for rows.Next() {
        var region string
        var revenue float64
        rows.Scan(&region, &revenue)
        fmt.Printf("%s: %.2f\n", region, revenue)
    }
}
```

Important Go-specific notes:

- CGo must be enabled (`CGO_ENABLED=1`). This means cross-compilation is more complex.
- The DuckDB C library must be present at link time (pre-compiled or built from source).
- `database/sql` connection pooling applies — DuckDB's single-writer constraint means pool size of 1 writer is correct for write connections.
- In-memory: `sql.Open("duckdb", "")`.

The `go-duckdb` package also exposes DuckDB-specific APIs (Appender, Arrow) via type assertion on the `*sql.DB`.

> [!warning] CGo dependency means `GOOS=linux GOARCH=arm64` cross-compilation from macOS requires the DuckDB library compiled for the target. Plan for this in your CI/CD pipeline if you cross-compile.

@feynman

Like using `database/sql` with any other driver — the interface is standard but CGo adds a build-time wrinkle that pure-Go users sometimes overlook.

@card
id: wdd-ch02-c008
order: 8
title: Rust Bindings
teaser: The duckdb-rs crate wraps the DuckDB C API for Rust — ergonomic, fast, and suitable for high-performance data processing tools written in Rust.

@explanation

```toml
# Cargo.toml
[dependencies]
duckdb = "1.1"
```

Basic usage:

```rust
use duckdb::{Connection, Result};

fn main() -> Result<()> {
    let conn = Connection::open("data.duckdb")?;

    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS events (ts TIMESTAMP, value DOUBLE)"
    )?;

    let mut stmt = conn.prepare(
        "SELECT ts, value FROM events WHERE value > ?1"
    )?;
    let rows = stmt.query_map([100.0], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, f64>(1)?))
    })?;

    for row in rows {
        let (ts, value) = row?;
        println!("{}: {}", ts, value);
    }
    Ok(())
}
```

The `duckdb-rs` crate provides:
- `Connection::open(path)` and `Connection::open_in_memory()`.
- Prepared statements with positional and named parameters.
- Arrow integration via the `arrow` feature flag.
- Appender API for bulk inserts.
- Type-safe result extraction via `FromSql` trait implementations.

Building requires the DuckDB C library. The crate's default build downloads and compiles it from source — slow on first build but hermetic. Alternatively, link against a pre-installed system DuckDB.

> [!info] `duckdb-rs` is the natural choice for building DuckDB-powered data tools in Rust — CLI ETL tools, embedded analytics servers, file format converters. The Arrow integration means zero-copy data passing between DuckDB and Rust Arrow arrays.

@feynman

Like `rusqlite` for SQLite — idiomatic Rust API wrapping a C library, with the build complexity that CGo and FFI dependencies always bring.

@card
id: wdd-ch02-c009
order: 9
title: Choosing the Right Binding
teaser: Each DuckDB binding has the same SQL engine underneath — the choice of binding is about the ecosystem, build complexity, and interop with adjacent libraries.

@explanation

All DuckDB bindings wrap the same C library. SQL behavior is identical across Python, Go, Java, and R. The choice is about ecosystem fit and operational concerns.

**Python:** default choice for data science and pipeline work. Best ecosystem integration (Pandas, Polars, Arrow, dbt). Most documentation and examples. `pip install duckdb` and done.

**CLI:** best for one-off queries, exploration, and shell scripts. No code needed.

**JavaScript/Wasm:** only option for browser-side analytics. Works in Node.js too but native Python or Go is typically preferable for server-side work.

**Java/Kotlin:** use when the rest of your stack is JVM. JDBC interface means it slots into existing JVM database tooling. The JDBC driver bundles the native library so Maven/Gradle users don't need a separate install.

**R:** natural fit for statistical analysis and visualization workflows. `dbplyr` integration makes large-dataset analytics feel like standard tidyverse.

**Go:** for CLI tools, services, or data engineering code where Go is already the language. CGo build complexity is the main friction.

**Rust:** for performance-critical tools where you want both DuckDB's query engine and Rust's systems programming model.

Decision signals:
- Data science notebook → Python
- CLI utility for a data team → CLI or Python
- Production analytics API → Python (embedded) or Java (JDBC + connection pool)
- Browser-side analytics product → JavaScript/Wasm
- Internal Go service → Go

> [!tip] If you are building something new and have no language constraint, start with Python. The ecosystem, documentation, and interop are unmatched, and you can always drop to the CLI for exploratory work.

@feynman

Like choosing a database driver — the wire protocol is the same, the binding is just the adapter between your language and the engine.

@card
id: wdd-ch02-c010
order: 10
title: First Queries — What DuckDB Can Do Immediately
teaser: Without creating a single table, DuckDB can query CSV, Parquet, and JSON files on disk — the file is the table.

@explanation

One of DuckDB's most useful properties is that it can query files without an import step. The file path is the table reference.

```sql
-- Query a local CSV file
SELECT * FROM read_csv_auto('sales.csv') LIMIT 5;

-- Or with the shorthand (DuckDB infers format from extension)
SELECT * FROM 'sales.csv' LIMIT 5;

-- Query a Parquet file
SELECT region, SUM(revenue) AS total
FROM 'data/sales.parquet'
GROUP BY region
ORDER BY total DESC;

-- Query multiple Parquet files with a glob
SELECT COUNT(*) FROM 'logs/2024/**/*.parquet';

-- Query a JSON file
SELECT json_extract(payload, '$.user_id') AS user_id
FROM 'events.json';

-- Query a remote file (requires httpfs extension)
SELECT * FROM 'https://example.com/data.parquet' LIMIT 10;
```

From Python:
```python
import duckdb
# Query starts immediately, no setup
result = duckdb.sql("SELECT * FROM 'large_file.parquet' WHERE year = 2024").df()
```

DuckDB infers schema, handles compressed files (`.parquet.gz`, `.csv.gz`), and supports glob patterns for multi-file queries. The `**` glob matches recursively through subdirectories.

This "file as table" behavior means you can run analytical SQL over a directory of Parquet files with exactly the same syntax as querying a table — because to DuckDB, they are the same thing.

> [!tip] `read_csv_auto` detects delimiters, quote characters, header rows, and data types automatically. Override with explicit parameters if auto-detection gets it wrong: `read_csv('file.csv', sep=';', header=true, columns={'id': 'INT', 'name': 'VARCHAR'})`.

@feynman

Like `cat file.csv | awk` but with a full SQL query optimizer instead of text processing.

@card
id: wdd-ch02-c011
order: 11
title: Persisting Data — Creating Tables and Loading Files
teaser: Moving from file queries to persisted tables adds performance benefits for repeated queries at the cost of one explicit load step.

@explanation

Querying files directly is convenient for one-off work. For repeated queries over the same data, materializing to a table is faster.

```sql
-- Create a DuckDB table from a Parquet file
CREATE TABLE sales AS SELECT * FROM 'raw/sales.parquet';

-- Create from multiple files
CREATE TABLE events AS SELECT * FROM 'raw/events/**/*.parquet';

-- Create from a CSV with explicit types
CREATE TABLE customers AS
SELECT * FROM read_csv('customers.csv',
    columns = {'id': 'INTEGER', 'name': 'VARCHAR', 'signup_date': 'DATE'}
);

-- Append to an existing table
INSERT INTO sales SELECT * FROM 'raw/sales_2025.parquet';

-- Or use COPY for bulk load
COPY sales FROM 'raw/sales_2025.parquet' (FORMAT PARQUET);
```

Tradeoffs of materializing vs querying files directly:

- **Materialized:** faster repeated queries (no file parsing overhead), enables indexing and statistics.
- **Direct file query:** no storage duplication, no load step, always reads fresh data from source.

A common hybrid: create a persistent DuckDB database for transformed/aggregated results, but query raw source files directly without import.

```sql
-- Create and persist an aggregated summary
CREATE TABLE daily_summary AS
SELECT
    date_trunc('day', event_time) AS day,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM 'raw/events/**/*.parquet'
GROUP BY 1;
```

> [!info] DuckDB uses a row-group-based storage format internally. For tables you query repeatedly with filters on a date or ID column, creating a sorted copy improves scan performance: `CREATE TABLE events_sorted AS SELECT * FROM events ORDER BY event_date`.

@feynman

Like caching a database query result — the source data still exists, but the cached version is faster to read again.

@card
id: wdd-ch02-c012
order: 12
title: Setting Up Extensions
teaser: DuckDB's extension system provides optional capabilities — HTTPFS for cloud storage, spatial for GIS, FTS for full-text search — installed and loaded in two commands.

@explanation

Extensions add capabilities that are not in the DuckDB core. Most are pre-compiled and hosted at `extensions.duckdb.org`.

Installing and loading an extension:

```sql
-- One-time installation (downloads compiled binary)
INSTALL httpfs;
INSTALL spatial;
INSTALL excel;

-- Load into the current session
LOAD httpfs;
LOAD spatial;

-- Install and load in one step
INSTALL delta; LOAD delta;
```

Extensions persist across sessions once installed — you only need `LOAD`, not `INSTALL`, in subsequent sessions. The installed extension binary lives in `~/.duckdb/extensions/`.

From Python:
```python
con = duckdb.connect()
con.install_extension('httpfs')
con.load_extension('httpfs')
```

Commonly used extensions:

- `httpfs` — HTTP file access, S3, GCS, Azure Blob Storage
- `spatial` — geospatial types and functions (PostGIS-like)
- `fts` — full-text search
- `excel` — read/write `.xlsx` files
- `iceberg` — Apache Iceberg catalog and table reads
- `delta` — Delta Lake table reads
- `json` — extended JSON functions (often auto-loaded)
- `parquet` — Parquet read/write (bundled but loadable)

> [!warning] Extensions are version-specific. An extension installed for DuckDB 1.0 will not load in DuckDB 1.1. After upgrading DuckDB, run `UPDATE EXTENSIONS` or reinstall extensions manually.

@feynman

Like browser extensions — they add capability to the base browser, are downloaded on first use, and need to be enabled per-session (or configured to auto-load).

@card
id: wdd-ch02-c013
order: 13
title: Configuring DuckDB
teaser: DuckDB's behavior is tunable through SET statements — memory limit, thread count, and home directory are the three most commonly adjusted settings.

@explanation

DuckDB exposes configuration via `SET` statements. Settings take effect immediately and persist for the connection lifetime.

Common settings:

```sql
-- Limit memory usage (default: 80% of available RAM)
SET memory_limit = '8GB';

-- Limit thread count (default: number of CPU cores)
SET threads = 4;

-- Set temp directory for spilling to disk (default: OS temp)
SET temp_directory = '/fast-nvme/duckdb-temp/';

-- Enable/disable progress bar in CLI
SET enable_progress_bar = true;

-- Set timezone for TIMESTAMP operations
SET TimeZone = 'UTC';

-- Enable external file access (required for httpfs file reads from SQL)
SET enable_external_access = true;
```

Checking current settings:

```sql
SELECT * FROM duckdb_settings() WHERE name LIKE '%memory%';
```

From Python:
```python
con = duckdb.connect()
con.execute("SET memory_limit='16GB'")
con.execute("SET threads=8")
```

Persistent configuration:
DuckDB does not have a config file by default. The recommended pattern for persistent settings is to create the connection and immediately apply settings before running queries:

```python
def get_connection(db_path: str) -> duckdb.DuckDBPyConnection:
    con = duckdb.connect(db_path)
    con.execute("SET memory_limit='8GB'")
    con.execute("SET threads=4")
    return con
```

> [!info] On a machine with 32GB RAM, leaving DuckDB at its default 80% (about 25.6GB) is usually fine for single-user workloads. On shared CI runners or containers with 4GB RAM, explicitly setting `memory_limit='2GB'` prevents OOM kills.

@feynman

Like `ulimit` for the database — you set resource bounds once at startup and the engine respects them throughout the session.
