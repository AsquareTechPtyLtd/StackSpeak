@chapter
id: wdd-ch10-python-ecosystem
order: 10
title: DuckDB and the Python Ecosystem
summary: DuckDB's Python API, zero-copy Arrow exchange, pandas and Polars interop, and writing UDFs — how DuckDB fits into a Python data stack.

@card
id: wdd-ch10-c001
order: 1
title: Python API Basics
teaser: The DuckDB Python API is three calls deep for most use cases — connect, execute, and fetch — and the defaults are deliberately sensible.

@explanation

Install with `pip install duckdb`. No server to start, no config to write.

The core objects:

- **Connection:** `duckdb.connect()` returns an in-memory database. `duckdb.connect('mydb.duckdb')` opens or creates a persistent file.
- **execute():** runs a SQL string against the connection. Returns the connection itself, so you can chain.
- **fetchall():** returns a list of tuples — standard Python data types, no external dependency required.
- **fetchdf():** returns a pandas DataFrame. Requires pandas installed; raises if not.
- **fetchone():** returns a single row tuple, or `None` if no rows remain.

```python
import duckdb

con = duckdb.connect()  # in-memory
con.execute("CREATE TABLE events AS SELECT * FROM 'events.parquet'")
rows = con.execute("SELECT count(*) FROM events").fetchone()
print(rows[0])  # e.g. 4_200_000

df = con.execute("SELECT event_type, count(*) AS n FROM events GROUP BY 1").fetchdf()
```

The module-level shorthand `duckdb.sql(...)` uses a per-process default connection — convenient for scripts, but avoid it in multi-connection code where connection isolation matters.

> [!tip] Close the connection explicitly with `con.close()` or use it as a context manager (`with duckdb.connect(...) as con:`) to release the write lock promptly. This matters most when other processes may need write access to the same file.

@feynman

Like sqlite3's `connection.execute().fetchall()` pattern — the API shape is intentionally familiar, the execution engine underneath is not.

@card
id: wdd-ch10-c002
order: 2
title: Relation API and Lazy Evaluation
teaser: `duckdb.sql()` returns a Relation — a lazy query plan you can chain and filter before triggering any actual computation.

@explanation

The Relation API builds a query plan without executing it. Execution happens only when you materialize — `.df()`, `.arrow()`, `.fetchall()`, or `.show()`.

```python
import duckdb

rel = duckdb.sql("SELECT * FROM 'orders.parquet'")

# Chain operations — nothing runs yet
result = (
    rel
    .filter("total > 100")
    .aggregate("region, sum(total) AS revenue", "region")
    .order("revenue DESC")
    .limit(10)
)

# Materialize
df = result.df()
```

Available chaining methods on a Relation:

- `.filter("predicate")` — WHERE clause
- `.project("col1, col2")` — SELECT columns
- `.aggregate("cols, agg_expr", "group_cols")` — GROUP BY
- `.order("col DESC")` — ORDER BY
- `.limit(n)` — LIMIT
- `.join(other_rel, "condition")` — JOIN another Relation

The Relation API is useful when building queries programmatically — you avoid string concatenation and get a cleaner call chain. For straightforward queries, plain SQL strings with `execute()` are more readable.

> [!info] A Relation prints its schema when you `print(rel)` or inspect it in a notebook — useful for verifying the plan before materializing a large result.

@feynman

Like a SQLAlchemy `select()` object before you call `.all()` — the object describes what you want, not what you've computed.

@card
id: wdd-ch10-c003
order: 3
title: Zero-Copy Arrow Integration
teaser: DuckDB and PyArrow can exchange data without copying memory — the data lives in one place and both systems share a pointer to it.

@explanation

Apache Arrow defines a standard in-memory columnar format. DuckDB's internal columnar format is Arrow-compatible. When both sides speak Arrow, the transfer is a pointer exchange — no serialization, no copy.

**DuckDB → Arrow:**

```python
import duckdb
import pyarrow as pa

con = duckdb.connect()
arrow_table = con.execute("SELECT * FROM 'events.parquet'").arrow()
# arrow_table is a pyarrow.Table — no copy occurred
```

**Arrow → DuckDB:**

```python
import pyarrow.parquet as pq

table = pq.read_table('big_table.parquet')  # pyarrow reads the file
con = duckdb.connect()
con.register('big_table', table)  # register the Arrow table as a DuckDB view
result = con.execute("SELECT region, sum(amount) FROM big_table GROUP BY region").df()
```

Alternatively, reference the Arrow variable directly in SQL using DuckDB's automatic variable scanning:

```python
result = duckdb.sql("SELECT * FROM table").arrow()
# DuckDB resolves 'table' from the local Python scope if it's an Arrow table
```

The zero-copy guarantee holds when:
- Data is already in Arrow format on both sides.
- No type conversion is required.
- The buffer is not mutated between the two accesses.

> [!warning] The zero-copy guarantee breaks silently if DuckDB needs to cast a type during the exchange. For example, a DuckDB `HUGEINT` column has no Arrow equivalent and will be copied with a type conversion. Check your schema if zero-copy performance is critical.

@feynman

Like passing a reference instead of a value in a function call — both sides hold a pointer to the same data region rather than each keeping their own copy.

@card
id: wdd-ch10-c004
order: 4
title: pandas Interop
teaser: DuckDB can query a pandas DataFrame directly in SQL by name — no import step, no copy required for read queries.

@explanation

DuckDB automatically scans Python local variables that are DataFrames when you reference their name in SQL. This works in both `duckdb.sql()` (module-level) and connection-scoped `con.execute()` when the DataFrame is in scope.

```python
import duckdb
import pandas as pd

orders = pd.read_csv('orders.csv')        # a local DataFrame
customers = pd.read_csv('customers.csv')

result = duckdb.sql("""
    SELECT c.region, SUM(o.total) AS revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    GROUP BY c.region
    ORDER BY revenue DESC
""").df()
```

`orders` and `customers` are referenced in SQL as table names — DuckDB resolves them from the local scope.

**Writing results back:**

`.df()` returns a pandas DataFrame. `.fetchdf()` is an alias on the cursor. Both copy the result into a new DataFrame.

**Performance notes:**

- Read queries over a DataFrame use zero-copy Arrow internally where possible.
- Writing results back with `.df()` does copy — you get a new DataFrame.
- For very large DataFrames, prefer writing to Parquet first and querying the Parquet file — DuckDB's Parquet reader is faster than scanning an in-memory DataFrame for large scans.
- Avoid `df.to_sql()` into DuckDB via SQLAlchemy — it inserts row by row and is dramatically slower than `con.register()` or direct SQL scanning.

> [!tip] `con.register('name', df)` explicitly registers a DataFrame as a named view, which is clearer in connection-scoped code and avoids relying on Python scope resolution across function boundaries.

@feynman

Like how Jupyter notebooks let you reference a variable from a previous cell — DuckDB resolves DataFrame names from the surrounding Python scope without you having to pass them explicitly.

@card
id: wdd-ch10-c005
order: 5
title: Polars Interop
teaser: DuckDB and Polars have native Arrow-based interop — each is fast in different situations, and combining them avoids being constrained to either API.

@explanation

Polars is a DataFrame library with a columnar, Arrow-native in-memory format. Since DuckDB and Polars both speak Arrow, they exchange data without copies.

**DuckDB result → Polars:**

```python
import duckdb
import polars as pl

arrow_result = duckdb.sql("SELECT * FROM 'events.parquet' WHERE ts > '2024-01-01'").arrow()
df = pl.from_arrow(arrow_result)
```

**Polars DataFrame → DuckDB:**

```python
import polars as pl
import duckdb

df = pl.read_parquet('orders.parquet')

# DuckDB scans the Polars DataFrame directly (Arrow under the hood)
result = duckdb.sql("SELECT region, sum(total) FROM df GROUP BY region").pl()
```

`.pl()` is DuckDB's native Polars result method — equivalent to `.arrow()` followed by `pl.from_arrow()`, but a one-liner.

**When DuckDB wins over Polars:**

- Complex multi-table joins (DuckDB's optimizer handles join ordering better).
- Querying files directly without loading into memory first.
- SQL familiarity in a team that doesn't know the Polars API.

**When Polars wins over DuckDB:**

- Streaming large files row-by-row without materializing fully (Polars LazyFrame with `collect(streaming=True)`).
- DataFrame-style chaining with type inference and schema evolution.
- When you want Rust-level performance on DataFrame transforms without writing SQL.

> [!info] Many production pipelines combine both: DuckDB for SQL-heavy joins and aggregations over files, Polars for downstream DataFrame transforms and streaming ingest. They compose cleanly because Arrow is the common transport.

@feynman

Like using `jq` to filter JSON and then piping to `awk` for arithmetic — each tool does what it's best at, and the pipe between them costs nothing because they share a common representation.

@card
id: wdd-ch10-c006
order: 6
title: Python Scalar UDFs
teaser: You can register a Python function as a SQL scalar function — useful for logic that SQL can't express cleanly, at the cost of per-row Python overhead.

@explanation

A scalar UDF takes one row's worth of inputs and returns one value. Register it with `con.create_function()`.

```python
import duckdb

def clean_email(s: str) -> str:
    return s.strip().lower() if s else None

con = duckdb.connect()
con.create_function('clean_email', clean_email, ['VARCHAR'], 'VARCHAR')

result = con.execute("""
    SELECT clean_email(email) AS normalized_email
    FROM users
""").fetchdf()
```

Type annotations must be explicit — DuckDB uses them to validate call sites and plan the execution. Supported types: `VARCHAR`, `INTEGER`, `BIGINT`, `DOUBLE`, `BOOLEAN`, `DATE`, `TIMESTAMP`, `LIST`, `STRUCT`, and others.

**Performance considerations:**

- Each row calls back into the Python interpreter. For a 10-million row table, that is 10 million Python function calls.
- Vectorized UDFs (`type='arrow'`) receive and return Arrow arrays instead of single values — significantly faster for large tables:

```python
import pyarrow as pa
import pyarrow.compute as pc

def clean_email_vec(emails: pa.Array) -> pa.Array:
    return pc.utf8_lower(pc.utf8_strip_whitespace(emails))

con.create_function('clean_email', clean_email_vec, ['VARCHAR'], 'VARCHAR', type='arrow')
```

Use the `type='arrow'` path whenever the function can operate on arrays. The Python-per-row path is for logic that cannot be vectorized.

> [!warning] Python scalar UDFs bypass DuckDB's query optimizer — it cannot push predicates through them or estimate their selectivity. Avoid UDFs in the WHERE clause of large table scans if a native DuckDB expression can do the same job.

@feynman

Like a custom comparator function passed to `array.sort()` — you extend the system's behavior with your own logic, but you pay a per-element callback cost that the built-in path avoids.

@card
id: wdd-ch10-c007
order: 7
title: Python Aggregate UDFs
teaser: Aggregate UDFs let you define custom GROUP BY behavior in Python — useful for aggregations that DuckDB's built-in functions don't cover.

@explanation

An aggregate UDF accumulates state across rows within a group and emits one value per group. DuckDB exposes this via `duckdb.udaf`.

```python
import duckdb
from duckdb.typing import VARCHAR

class ModeAggregator:
    def __init__(self):
        self.counts = {}

    def step(self, value: str):
        if value is not None:
            self.counts[value] = self.counts.get(value, 0) + 1

    def finalize(self) -> str:
        if not self.counts:
            return None
        return max(self.counts, key=self.counts.get)

    def combine(self, other: 'ModeAggregator'):
        # Required for parallel aggregation
        for k, v in other.counts.items():
            self.counts[k] = self.counts.get(k, 0) + v

con = duckdb.connect()
con.create_aggregate_function('mode_str', ModeAggregator, [VARCHAR], VARCHAR)

result = con.execute("""
    SELECT category, mode_str(top_tag) AS most_common_tag
    FROM posts
    GROUP BY category
""").fetchdf()
```

The required interface:

- `__init__`: initialize per-group state.
- `step(value, ...)`: called once per row in the group.
- `finalize() -> return_type`: called once per group to produce the output.
- `combine(other)`: merges two partial aggregation states — required if DuckDB parallelizes the aggregation across threads.

> [!warning] Omitting `combine()` forces single-threaded aggregation, which loses parallelism on large groups. Always implement `combine()` for production UDAFs.

@feynman

Like writing a custom `reduce()` function — you define the initial state, how to fold each element in, and how to merge two partial results for parallel execution.

@card
id: wdd-ch10-c008
order: 8
title: SQL Macros
teaser: SQL macros are named, parameterized SQL snippets — often a faster and more optimizer-friendly alternative to Python UDFs for pure SQL transformations.

@explanation

A macro is a named SQL expression or query that accepts parameters and is inlined at query time. Unlike UDFs, macros are pure SQL — the optimizer can see through them and apply its full optimization passes.

**Scalar macro:**

```sql
CREATE OR REPLACE MACRO normalize_email(e) AS (
    lower(trim(e))
);

SELECT normalize_email(email) FROM users;
```

**Table macro (returns rows):**

```sql
CREATE OR REPLACE MACRO top_n_by(tbl, col, n) AS TABLE (
    SELECT * FROM query_table(tbl)
    ORDER BY query_column(col) DESC
    LIMIT n
);

SELECT * FROM top_n_by('orders', 'total', 10);
```

From Python:

```python
con = duckdb.connect()
con.execute("""
    CREATE OR REPLACE MACRO normalize_email(e) AS (lower(trim(e)))
""")
result = con.execute("SELECT normalize_email(email) FROM users").fetchdf()
```

Macros vs UDFs:

- Macros are SQL — the optimizer can push predicates, fold constants, and plan around them. UDFs are opaque black boxes.
- Macros cannot contain Python logic. UDFs can.
- Macros are persisted in the DuckDB file if created on a persistent connection. UDFs are registered at runtime and must be re-registered each connection.
- Macros have no per-row Python overhead. UDFs do.

> [!tip] Default to macros for any transformation that can be expressed in SQL. Reach for Python UDFs only when the logic genuinely requires Python — regex libraries, ML inference, external API calls.

@feynman

Like a SQL view but parameterized — it is a reusable, named query fragment that the database inlines and optimizes rather than treating as a black box.

@card
id: wdd-ch10-c009
order: 9
title: Parameterized Queries
teaser: DuckDB supports positional and named parameter binding — always use parameters for user-supplied values rather than string interpolation.

@explanation

SQL injection via string interpolation is as dangerous in DuckDB as anywhere else. Use parameter binding.

**Positional parameters (`?`):**

```python
con = duckdb.connect()
region = "us-west"
min_total = 500

result = con.execute(
    "SELECT * FROM orders WHERE region = ? AND total > ?",
    [region, min_total]
).fetchdf()
```

**Named parameters (`$name`):**

```python
result = con.execute(
    "SELECT * FROM orders WHERE region = $region AND total > $min_total",
    {"region": "us-west", "min_total": 500}
).fetchdf()
```

Parameters work with all statement types — SELECT, INSERT, UPDATE, DELETE, and COPY.

A common pattern for bulk inserts using `executemany()`:

```python
records = [("alice@example.com", "us-west"), ("bob@example.com", "us-east")]
con.executemany("INSERT INTO users (email, region) VALUES (?, ?)", records)
```

`executemany()` is significantly faster than calling `execute()` in a loop, but for large bulk loads, `INSERT INTO ... SELECT * FROM records_df` or `COPY` from a Parquet file is faster still.

> [!warning] Never construct SQL with f-strings or `.format()` when the inputs come from user-controlled data. Parameter binding is not optional — it is the correct API for variable values.

@feynman

Like prepared statements in any other database driver — the query plan is separated from the data, which prevents injection and often improves performance on repeated executions.

@card
id: wdd-ch10-c010
order: 10
title: Jupyter and Notebook Integration
teaser: DuckDB works in Jupyter notebooks with no special setup — and with the `jupysql` extension you get `%sql` magic, result rendering, and plot integration.

@explanation

The base DuckDB Python API works in any Jupyter notebook as-is. `.df()` results render as formatted DataFrames in notebook output automatically.

```python
import duckdb

con = duckdb.connect()
con.sql("SELECT * FROM 'sales.parquet' LIMIT 5").show()
```

`.show()` prints a formatted table to stdout — useful for quick inspection without materializing to a DataFrame.

**jupysql (`%sql` magic):**

```
pip install jupysql duckdb-engine
```

```python
%load_ext sql
%sql duckdb:///:memory:
```

```sql
%%sql
SELECT region, SUM(total) AS revenue
FROM 'orders.parquet'
GROUP BY region
ORDER BY revenue DESC
```

With jupysql, query results render as styled HTML tables in the notebook cell output. You can also plot directly:

```python
%sqlplot histogram --table orders --column total --bins 20
```

**Practical workflow tips:**

- Use `duckdb.connect(':memory:')` for exploratory work — nothing persists between sessions, which prevents stale state confusion.
- Use a named file connection when building something you want to persist across notebook sessions.
- Large result sets slow down notebook rendering. Apply a `LIMIT` or aggregate before calling `.df()` for display.
- DuckDB's `.show()` method truncates output automatically — safer than `.df()` for unknown-size result sets.

> [!info] DuckDB integrates with Evidence and Observable notebooks as well — the SQL-over-files model makes it a natural fit for notebook-based reporting tools that need to query local data files.

@feynman

Like using SQLite in a Jupyter notebook — you get a full database engine in the same process as your code, with results that render natively in the cell output.

@card
id: wdd-ch10-c011
order: 11
title: Connection Lifecycle and Thread Safety
teaser: DuckDB connections are not thread-safe — each thread needs its own connection, but multiple read-only connections to the same file are safe.

@explanation

The DuckDB connection object is not thread-safe. Using the same connection from multiple threads concurrently produces undefined behavior.

**Correct pattern for multi-threaded Python code:**

```python
import duckdb
import threading

def worker(query):
    # Each thread creates its own connection
    con = duckdb.connect('analytics.duckdb', read_only=True)
    result = con.execute(query).fetchdf()
    con.close()
    return result

threads = [threading.Thread(target=worker, args=("SELECT count(*) FROM events",))
           for _ in range(4)]
for t in threads:
    t.start()
for t in threads:
    t.join()
```

Multiple `read_only=True` connections to the same file from different threads (or processes) are supported. One `read_only=False` connection can coexist with multiple readers.

**In web frameworks (Flask, FastAPI):**

```python
from contextlib import contextmanager
import duckdb

@contextmanager
def get_db():
    con = duckdb.connect('analytics.duckdb', read_only=True)
    try:
        yield con
    finally:
        con.close()

# FastAPI route
@app.get("/stats")
def stats():
    with get_db() as con:
        return con.execute("SELECT count(*) FROM events").fetchone()[0]
```

Opening a new connection per request is cheap — DuckDB connections are lightweight. Do not pool DuckDB connections the way you would pool PostgreSQL connections; the overhead model is different.

> [!warning] DuckDB's internal query execution is already parallelized across threads using its own thread pool. Adding Python-level thread parallelism on top of a single shared connection is both unsafe and counterproductive — DuckDB is already using all your cores.

@feynman

Like how SQLite's connection object is not thread-safe — the right fix is one connection per thread, not locking around a shared connection.

@card
id: wdd-ch10-c012
order: 12
title: Ingesting Data at Scale from Python
teaser: For large data loads, the method you choose determines whether ingest takes seconds or hours — direct file ingestion always beats row-by-row Python.

@explanation

Ranked fastest to slowest for getting data into DuckDB from Python:

**1. Query files directly (no ingest at all):**

```python
# DuckDB reads the file directly — nothing is "ingested"
result = duckdb.sql("SELECT * FROM 'big.parquet'").fetchdf()
```

**2. CTAS from a file:**

```python
con.execute("CREATE TABLE events AS SELECT * FROM 'events/*.parquet'")
```

**3. Bulk insert from a DataFrame or Arrow table:**

```python
con.execute("INSERT INTO events SELECT * FROM arrow_table")
# or register and insert
con.register('staging', df)
con.execute("INSERT INTO events SELECT * FROM staging")
```

**4. executemany() with parameter binding:**

```python
con.executemany("INSERT INTO events VALUES (?, ?, ?)", list_of_tuples)
# Acceptable for thousands of rows; slow for millions
```

**5. Row-by-row execute() in a loop — avoid:**

```python
for row in data:  # Do not do this for large data
    con.execute("INSERT INTO events VALUES (?, ?, ?)", row)
```

The row-by-row path is 100-1000x slower than bulk methods for large datasets because it cannot use DuckDB's vectorized append path.

For streaming ingest (Kafka, event logs), batch records into lists of 10,000+ rows and use `executemany()` or convert to Arrow and insert in batch.

> [!tip] If your source data is a pandas DataFrame, `con.execute("CREATE TABLE t AS SELECT * FROM df")` is the fastest single-call ingest — DuckDB uses the Arrow path internally and the optimizer can run during table creation.

@feynman

Like the difference between `BULK INSERT` and a `for` loop in any SQL database — the batch path amortizes overhead across rows while the loop pays per-row cost for every record.

@card
id: wdd-ch10-c013
order: 13
title: Type Mapping Between Python and DuckDB
teaser: DuckDB's type system is richer than Python's built-ins — knowing the mapping prevents silent coercions and unexpected nulls.

@explanation

DuckDB-to-Python type mapping when using `fetchall()`:

- `INTEGER`, `BIGINT`, `SMALLINT` → `int`
- `FLOAT`, `DOUBLE` → `float`
- `VARCHAR`, `TEXT` → `str`
- `BOOLEAN` → `bool`
- `DATE` → `datetime.date`
- `TIMESTAMP` → `datetime.datetime`
- `INTERVAL` → `datetime.timedelta`
- `BLOB` → `bytes`
- `NULL` → `None`
- `LIST` → `list`
- `STRUCT` → `dict`
- `MAP` → `dict`
- `HUGEINT` → `int` (Python handles arbitrary precision; Arrow cannot represent this without copying)

When using `.fetchdf()` (pandas):

- `BIGINT` → `int64`
- `DOUBLE` → `float64`
- `VARCHAR` → `object` (Python strings)
- `DATE` → `datetime64[ns]` (note: timezone-naive unless `TIMESTAMPTZ`)
- `LIST` → `object` (a column of Python lists)
- `STRUCT` → `object` (a column of Python dicts)

When using `.arrow()` (PyArrow):

- All numeric types have direct Arrow equivalents.
- `HUGEINT` and `UHUGEINT` are cast to `large_string` or require explicit casting — no Arrow native 128-bit integer.
- `TIMESTAMP WITH TIME ZONE` maps to `pa.timestamp('us', tz='UTC')`.

> [!info] DuckDB's `TIMESTAMP` is timezone-naive by default. If your data has timestamps in multiple timezones, use `TIMESTAMPTZ` and ensure your Python code handles timezone-aware `datetime` objects. Silent UTC assumptions are a common source of off-by-hour bugs.

@feynman

Like learning the implicit type coercions in a new language — the mapping is deterministic once you know it, but surprises come from assuming it mirrors a system you already know.
