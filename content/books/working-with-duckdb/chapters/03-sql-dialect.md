@chapter
id: wdd-ch03-sql-dialect
order: 3
title: The DuckDB SQL Dialect
summary: DuckDB's SQL dialect extends standard SQL with FROM-first syntax, GROUP BY ALL, friendly type coercion, list and struct types, and powerful range joins — features that matter daily in analytical work.

@card
id: wdd-ch03-c001
order: 1
title: FROM-First SELECT
teaser: DuckDB lets you write SELECT queries starting with FROM — a syntax that matches how most people actually think about queries.

@explanation

Standard SQL requires SELECT before FROM, which means you write the column list before knowing which table you are selecting from. DuckDB supports FROM-first syntax:

```sql
-- Standard SQL (SELECT first)
SELECT id, name, revenue
FROM orders
WHERE revenue > 1000;

-- DuckDB FROM-first equivalent
FROM orders
SELECT id, name, revenue
WHERE revenue > 1000;

-- FROM-only (selects all columns, like SELECT *)
FROM orders
WHERE revenue > 1000;
```

The FROM-first form is particularly useful in the CLI and notebook contexts where you start by identifying the table, then refine the column selection.

It also composes naturally with pipes in shell scripts and makes reading query diffs easier — the table reference comes first, so you immediately know what data the query operates on.

The two forms produce identical query plans. This is purely a syntactic preference. Both are valid in DuckDB 1.0+.

Limitations: FROM-first syntax is DuckDB-specific. It does not work in PostgreSQL, BigQuery, Snowflake, or SQLite. If you are writing portable SQL, use the standard form.

> [!tip] In Jupyter notebooks, FROM-first queries make iterative column selection feel natural — write `FROM my_table LIMIT 5` to explore, then add `SELECT col1, col2` once you know what you want.

@feynman

Like starting a sentence with the subject before the verb — it reads in the order you think, even if the traditional grammar says otherwise.

@card
id: wdd-ch03-c002
order: 2
title: GROUP BY ALL
teaser: GROUP BY ALL automatically groups by every non-aggregated column in the SELECT list — eliminating the most tedious part of writing aggregation queries.

@explanation

Standard SQL requires explicitly listing all non-aggregated columns in the GROUP BY clause, which duplicates them from the SELECT list:

```sql
-- Standard SQL — must repeat the GROUP BY columns
SELECT region, product_category, year, SUM(revenue)
FROM sales
GROUP BY region, product_category, year;
```

DuckDB's `GROUP BY ALL` groups by every column that is not an aggregation:

```sql
-- DuckDB GROUP BY ALL — no repetition
SELECT region, product_category, year, SUM(revenue)
FROM sales
GROUP BY ALL;
```

DuckDB identifies non-aggregate columns automatically. If you add or remove a column from the SELECT list, the grouping adjusts without touching the GROUP BY clause.

This also works with column aliases:

```sql
SELECT
    date_trunc('month', order_date) AS month,
    customer_tier,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue
FROM orders
GROUP BY ALL;
-- Groups by: month, customer_tier
```

`GROUP BY ALL` is a DuckDB extension. It does not appear in standard SQL or most other databases. For portable queries, write the explicit GROUP BY list.

> [!info] `GROUP BY ALL` is evaluated after alias resolution — so the alias `month` in the example above is recognized as non-aggregate. This is one of several places where DuckDB resolves aliases earlier in the query pipeline than strict SQL standard requires.

@feynman

Like TypeScript's `typeof` inference — instead of explicitly typing every variable, the compiler figures out the type from context and you only specify when you need to override.

@card
id: wdd-ch03-c003
order: 3
title: Friendly Type Coercion
teaser: DuckDB converts between compatible types automatically in most contexts — fewer explicit CAST calls, but some surprises if you expect strict typing.

@explanation

DuckDB applies implicit type coercion where the conversion is safe and unambiguous:

```sql
-- String to number (works in DuckDB, fails in strict ANSI SQL)
SELECT '42'::INTEGER + 1;  -- returns 43

-- String to date
SELECT '2024-01-15'::DATE + INTERVAL '1 day';

-- Number to string in concatenation context
SELECT 'Order #' || order_id FROM orders;  -- order_id is INTEGER, auto-coerced

-- Mixed numeric types
SELECT 1 + 1.5;  -- returns 2.5 (INTEGER + DOUBLE -> DOUBLE)
```

DuckDB also provides explicit casting with `::` syntax (PostgreSQL-style) and the standard `CAST()`:

```sql
SELECT CAST(revenue AS VARCHAR) FROM orders;
SELECT revenue::VARCHAR FROM orders;  -- equivalent
```

The `TRY_CAST` variant returns NULL instead of raising an error on failed conversion:

```sql
SELECT TRY_CAST(user_input AS INTEGER);  -- NULL if not a valid integer
```

Where strict typing matters:

- Column definitions in `CREATE TABLE` are strict — the declared type constrains what can be inserted.
- Comparison between incompatible types (e.g., a STRUCT vs an INTEGER) raises an error.
- JSON values extracted with `->` operators are JSON-typed and require explicit casting for arithmetic.

> [!warning] Friendly coercion from string to number works in queries but is not a substitute for correct data types in table schemas. Storing integers as VARCHAR avoids coercion errors but breaks sort order, comparisons, and aggregations in subtle ways.

@feynman

Like JavaScript's loose equality — convenient in the common case, but you need to understand the rules to avoid surprises at the edges.

@card
id: wdd-ch03-c004
order: 4
title: List and Array Types
teaser: DuckDB has a native LIST type for variable-length arrays and fixed-size ARRAY type — with SQL functions that make working with nested data natural.

@explanation

DuckDB supports native list and array types, enabling you to store and query nested collections without JSON serialization.

```sql
-- Create a table with a list column
CREATE TABLE tags (
    post_id INTEGER,
    tag_names VARCHAR[]  -- list of strings
);

INSERT INTO tags VALUES (1, ['sql', 'duckdb', 'analytics']);

-- Access list elements (1-indexed)
SELECT tag_names[1] FROM tags;  -- 'sql'

-- List length
SELECT len(tag_names) FROM tags;

-- Unnest a list into rows
SELECT post_id, unnest(tag_names) AS tag FROM tags;

-- Check if a list contains a value
SELECT * FROM tags WHERE list_contains(tag_names, 'duckdb');

-- List comprehension (SQL macro style)
SELECT list_transform(tag_names, x -> upper(x)) FROM tags;

-- Aggregate into a list
SELECT user_id, list(product_id ORDER BY order_date) AS purchase_history
FROM orders GROUP BY user_id;
```

Fixed-size arrays (DuckDB 1.0+):
```sql
CREATE TABLE vectors (embedding FLOAT[384]);
-- Fixed-size arrays are more memory-efficient than LIST for uniform-length data
```

List functions available: `list_contains`, `list_distinct`, `list_intersect`, `list_union`, `list_sort`, `list_reverse`, `list_slice`, `list_aggregate`, `list_transform`, `list_filter`.

> [!info] DuckDB's LIST type maps naturally to Python lists and JSON arrays. When reading Parquet files with list columns (common in ML feature stores), DuckDB preserves the nested structure natively without flattening.

@feynman

Like a database column that holds a Python list — operations that would require a join in a row-oriented database are direct function calls on the nested type.

@card
id: wdd-ch03-c005
order: 5
title: Struct and Map Types
teaser: DuckDB's STRUCT type holds named fields of different types in a single column — useful for nested objects from JSON, Parquet, or Iceberg schemas.

@explanation

STRUCT is a named, ordered collection of fields with heterogeneous types — essentially an inline record within a column.

```sql
-- Define a table with a struct column
CREATE TABLE users (
    id INTEGER,
    address STRUCT(
        street VARCHAR,
        city VARCHAR,
        zip VARCHAR,
        country VARCHAR
    )
);

INSERT INTO users VALUES (
    1,
    {'street': '123 Main St', 'city': 'Portland', 'zip': '97201', 'country': 'US'}
);

-- Access struct fields with dot notation
SELECT address.city FROM users;

-- Or with bracket notation
SELECT address['city'] FROM users;

-- Reconstruct a struct in a query
SELECT id, {'city': address.city, 'country': address.country} AS location FROM users;

-- Unnest a struct into columns
SELECT id, unnest(address) FROM users;
```

MAP type — for key-value data where keys are dynamic:
```sql
CREATE TABLE attributes (
    product_id INTEGER,
    props MAP(VARCHAR, VARCHAR)
);

INSERT INTO attributes VALUES (1, map(['color', 'size'], ['red', 'large']));

SELECT props['color'] FROM attributes WHERE product_id = 1;
```

STRUCT vs MAP:
- STRUCT: fixed named fields, different types per field. Accessed by field name.
- MAP: dynamic keys, uniform value type. Accessed by key string.

These types read naturally from Parquet nested schemas and JSON objects.

> [!tip] When querying a Parquet file with nested struct columns, DuckDB preserves the nesting. Use `SELECT nested_col.field` to access sub-fields without a full JSON extraction dance.

@feynman

Like a struct in C or a dataclass in Python — named fields with types, stored in a single column rather than spread across multiple columns.

@card
id: wdd-ch03-c006
order: 6
title: Range Joins
teaser: DuckDB's range join optimization handles inequality join conditions efficiently — a query pattern that is notoriously slow in most databases becomes fast.

@explanation

A range join is a join where the condition involves an inequality or interval overlap — not just equality. Examples: "find all events that occurred during each session," "find all prices effective at each transaction date."

In most databases, range joins degrade to nested-loop joins, which are O(n×m) — slow for large tables. DuckDB implements a specialized range join algorithm that is significantly faster.

```sql
-- Find all log events that fall within each user session
SELECT
    s.user_id,
    s.session_id,
    e.event_type,
    e.event_time
FROM sessions s
JOIN events e
  ON e.user_id = s.user_id
  AND e.event_time >= s.session_start
  AND e.event_time < s.session_end;
```

```sql
-- Temporal price lookup: find the price effective at each order's date
SELECT
    o.order_id,
    o.product_id,
    o.order_date,
    p.price
FROM orders o
JOIN price_history p
  ON o.product_id = p.product_id
  AND o.order_date >= p.effective_from
  AND o.order_date < p.effective_to;
```

DuckDB's range join optimization activates automatically when the planner detects eligible interval conditions. No hint or special syntax required.

Benchmark reference: on a 10M-row events table joined with a 100K-row sessions table, DuckDB's range join completes in seconds where a naive nested-loop join takes minutes.

> [!info] DuckDB's range join optimization applies to TIMESTAMP, DATE, INTEGER, and DOUBLE range conditions. For TIMESTAMP ranges, ensure both sides of the join use the same timezone to avoid silent errors.

@feynman

Like a B-tree index scan vs a full table scan — the same logical operation, but the algorithm knows about the sorted structure and skips irrelevant work.

@card
id: wdd-ch03-c007
order: 7
title: Lambda Functions and List Comprehensions
teaser: DuckDB supports inline lambda functions for list operations — transform, filter, and reduce list elements with concise SQL syntax.

@explanation

DuckDB's lambda syntax (`x -> expression`) lets you define inline functions for list operations without writing a UDF.

```sql
-- Filter a list
SELECT list_filter([1, 2, 3, 4, 5], x -> x > 2);
-- Result: [3, 4, 5]

-- Transform a list
SELECT list_transform(['alice', 'bob', 'carol'], x -> upper(x));
-- Result: ['ALICE', 'BOB', 'CAROL']

-- Reduce a list to a single value
SELECT list_reduce([1, 2, 3, 4, 5], (acc, x) -> acc + x);
-- Result: 15

-- Combine filter and transform
SELECT list_transform(
    list_filter(scores, x -> x >= 60),
    x -> x / 100.0
) AS passing_scores_normalized
FROM student_results;
```

Lambda in aggregate context:
```sql
-- Build a sorted list of distinct values
SELECT user_id, list_sort(list_distinct(list(product_id))) AS unique_products
FROM orders
GROUP BY user_id;
```

Lambda functions work on:
- `list_transform(list, x -> expr)` — apply function to each element
- `list_filter(list, x -> bool_expr)` — keep elements matching predicate
- `list_reduce(list, (acc, x) -> expr)` — fold list to a value

Two-argument lambdas (for reduce): `(acc, x) -> expr`.

> [!tip] Lambda functions over lists are particularly useful when working with Parquet or JSON data that contains nested arrays. Instead of `unnest` + aggregate + GROUP BY, a single `list_transform` can be cleaner for simple per-row operations.

@feynman

Like Python's `map()`, `filter()`, and `reduce()` but as SQL functions — the same functional patterns, applied to list columns inline.

@card
id: wdd-ch03-c008
order: 8
title: PIVOT and UNPIVOT
teaser: DuckDB supports PIVOT and UNPIVOT natively — rotating rows to columns and columns to rows without hand-written CASE WHEN chains.

@explanation

PIVOT converts unique row values into columns. UNPIVOT does the reverse.

```sql
-- Sample data
CREATE TABLE sales (
    region VARCHAR,
    quarter VARCHAR,
    revenue DECIMAL
);

-- PIVOT: turn quarters into columns
SELECT * FROM (SELECT region, quarter, revenue FROM sales)
PIVOT (SUM(revenue) FOR quarter IN ('Q1', 'Q2', 'Q3', 'Q4'));

-- Result: one row per region, columns for Q1, Q2, Q3, Q4
```

Dynamic PIVOT (DuckDB 1.0+ extension):
```sql
-- Don't know the values ahead of time
PIVOT sales
ON quarter
USING SUM(revenue)
GROUP BY region;
```

UNPIVOT — turn columns into rows:
```sql
CREATE TABLE quarterly_revenue (
    region VARCHAR,
    q1 DECIMAL,
    q2 DECIMAL,
    q3 DECIMAL,
    q4 DECIMAL
);

UNPIVOT quarterly_revenue
ON q1, q2, q3, q4
INTO NAME quarter VALUE revenue;
-- Result: (region, quarter, revenue) — one row per (region, quarter) combination
```

Before native PIVOT support, this required verbose `CASE WHEN` expressions repeated per value. DuckDB's syntax is significantly more concise, especially for dynamic pivots where the column values are not known at query-write time.

> [!info] Dynamic PIVOT (without `IN (...)`) executes two passes — one to discover distinct values, one to execute the pivot. For very high cardinality pivot columns (thousands of distinct values), performance degrades proportionally. Prefer static PIVOT with `IN (...)` for known value sets.

@feynman

Like a spreadsheet pivot table in a single SQL statement — restructure the data layout without writing a row for every possible value.

@card
id: wdd-ch03-c009
order: 9
title: Window Functions and Frames
teaser: DuckDB supports the full standard window function set with efficient vectorized execution — running totals, lag/lead, percentile, and moving aggregations.

@explanation

Window functions compute a value for each row based on a set of related rows (the window) defined by PARTITION BY and ORDER BY clauses.

```sql
-- Running total
SELECT
    order_date,
    amount,
    SUM(amount) OVER (ORDER BY order_date) AS running_total
FROM orders;

-- Rank within a group
SELECT
    region,
    product,
    revenue,
    RANK() OVER (PARTITION BY region ORDER BY revenue DESC) AS rank_in_region
FROM sales;

-- Lag and lead (previous/next row values)
SELECT
    day,
    metric,
    LAG(metric, 1) OVER (ORDER BY day) AS prev_day,
    metric - LAG(metric, 1) OVER (ORDER BY day) AS day_over_day_change
FROM daily_metrics;

-- Moving average (last 7 days)
SELECT
    day,
    value,
    AVG(value) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d
FROM daily_values;

-- Percentile within group
SELECT
    category,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS median_price
FROM products
GROUP BY category;
```

DuckDB executes window functions using its vectorized engine, which handles large windows efficiently. For very large datasets with many partitions, execution is parallelized across cores.

> [!tip] `QUALIFY` is a DuckDB shorthand for filtering on window function results without a subquery: `SELECT * FROM t QUALIFY RANK() OVER (PARTITION BY region ORDER BY revenue DESC) = 1` — equivalent to a `WHERE` clause on the window result.

@feynman

Like a sliding calculator that moves through rows — for each row, look at a defined neighborhood of rows and compute something over that neighborhood.

@card
id: wdd-ch03-c010
order: 10
title: CTEs and Recursive Queries
teaser: DuckDB fully supports Common Table Expressions including recursive CTEs — useful for hierarchical data, graph traversal, and complex multi-step transformations.

@explanation

Common Table Expressions (CTEs) name intermediate query results for reuse within a larger query.

```sql
-- Simple CTE
WITH
revenue_by_region AS (
    SELECT region, SUM(revenue) AS total
    FROM sales
    GROUP BY region
),
top_regions AS (
    SELECT region, total
    FROM revenue_by_region
    WHERE total > 1_000_000
)
SELECT * FROM top_regions ORDER BY total DESC;
```

Recursive CTE — traverse a tree or graph:
```sql
-- Organizational hierarchy traversal
WITH RECURSIVE org_tree AS (
    -- Anchor: start from root
    SELECT id, name, manager_id, 0 AS depth
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive: add direct reports
    SELECT e.id, e.name, e.manager_id, ot.depth + 1
    FROM employees e
    JOIN org_tree ot ON e.manager_id = ot.id
)
SELECT * FROM org_tree ORDER BY depth, name;
```

Materialized CTEs:
```sql
-- Force DuckDB to materialize the CTE result rather than inlining it
WITH expensive_subquery AS MATERIALIZED (
    SELECT ... FROM large_table WHERE ...
)
SELECT * FROM expensive_subquery a
JOIN expensive_subquery b ON a.id = b.parent_id;
```

By default, DuckDB inlines CTEs into the main query. `MATERIALIZED` forces a single evaluation when the CTE is used multiple times and the inline plan would re-execute it.

> [!info] Recursive CTEs in DuckDB execute iteratively: evaluate the anchor, add results to the working set, evaluate the recursive term with the current working set, repeat until no new rows are produced. Cycles in the data can cause infinite loops — add a depth limit (`WHERE depth < 20`) for safety.

@feynman

Like a named intermediate result in a programming language — give a name to a subquery so it reads like a well-structured function decomposition.

@card
id: wdd-ch03-c011
order: 11
title: ASOF Joins
teaser: ASOF joins find the nearest preceding match in a sorted sequence — the standard way to align time-series data with different sampling frequencies.

@explanation

An ASOF join (also called a "last known value" join) matches each row in the left table to the nearest row in the right table where the right table's key is less than or equal to the left table's key.

```sql
-- Find the exchange rate in effect at each trade's timestamp
SELECT
    t.trade_id,
    t.trade_time,
    t.amount_usd,
    r.rate AS eur_usd_rate,
    t.amount_usd * r.rate AS amount_eur
FROM trades t
ASOF JOIN exchange_rates r
  ON r.currency_pair = t.currency_pair
  AND r.rate_time <= t.trade_time;
-- For each trade, uses the most recent exchange rate before the trade time
```

Without ASOF JOIN, the equivalent query requires a correlated subquery or a lateral join:
```sql
-- Verbose equivalent without ASOF
SELECT t.*, r.rate
FROM trades t
JOIN exchange_rates r
  ON r.currency_pair = t.currency_pair
  AND r.rate_time = (
      SELECT MAX(rate_time)
      FROM exchange_rates
      WHERE currency_pair = t.currency_pair
        AND rate_time <= t.trade_time
  );
```

The ASOF JOIN is both more readable and more efficient — DuckDB uses a merge-join strategy on the sorted keys rather than executing a correlated subquery per row.

ASOF JOIN requirements:
- The right table must be sorted by the key column used in the join condition.
- The join condition must use `<=` (nearest preceding) or `>=` (nearest following).

> [!tip] ASOF JOINs are invaluable in time-series analytics: aligning metrics with SLO thresholds, joining sensor readings with calibration tables, or matching events with the active configuration at the time of the event.

@feynman

Like `bisect_left` in Python's `bisect` module — find the insertion point in a sorted list, then use the element just to the left as the "current value."

@card
id: wdd-ch03-c012
order: 12
title: Positional and Named Parameter Binding
teaser: DuckDB supports both positional ($1, $2) and named (?name) parameters in prepared statements — parameterize queries to prevent injection and improve plan reuse.

@explanation

Prepared statements with parameter binding prevent SQL injection and allow the query planner to cache the execution plan.

**Positional parameters ($1-based):**
```python
import duckdb

con = duckdb.connect()
result = con.execute(
    "SELECT * FROM orders WHERE region = $1 AND year = $2",
    ['West', 2024]
).fetchall()
```

**Question mark placeholders (positional):**
```python
result = con.execute(
    "SELECT * FROM orders WHERE region = ? AND year = ?",
    ['West', 2024]
).fetchall()
```

**Named parameters (Python dict):**
```python
result = con.execute(
    "SELECT * FROM orders WHERE region = $region AND year = $year",
    {'region': 'West', 'year': 2024}
).fetchall()
```

**Prepared statement with multiple executions:**
```python
stmt = con.prepare("INSERT INTO events VALUES (?, ?, ?)")
for row in incoming_batch:
    stmt.execute([row.ts, row.user_id, row.event_type])
```

Parameter types are inferred from the Python value. Pass `None` for SQL NULL.

From JDBC (Java):
```java
PreparedStatement pstmt = conn.prepareStatement(
    "SELECT * FROM orders WHERE region = ? AND year = ?"
);
pstmt.setString(1, "West");
pstmt.setInt(2, 2024);
ResultSet rs = pstmt.executeQuery();
```

> [!warning] Never use string formatting to interpolate user input into SQL queries with DuckDB, even though it is embedded and "safer" than a server. SQL injection through file paths and identifiers is still possible, and prepared statements have negligible overhead.

@feynman

Like parameterized routes in a web framework — the pattern is compiled once, the variable parts are filled in per-request without re-parsing the whole structure.

@card
id: wdd-ch03-c013
order: 13
title: SQL Macros — Reusable Inline Functions
teaser: DuckDB's SQL macros let you define reusable SQL expressions without writing a UDF in Python or C — the macro expands at query planning time.

@explanation

SQL macros are named, parameterized SQL expressions. They are expanded by the query planner before execution — similar to C preprocessor macros but SQL-aware.

**Scalar macro:**
```sql
-- Define a macro
CREATE OR REPLACE MACRO safe_divide(a, b) AS
    CASE WHEN b = 0 THEN NULL ELSE a / b END;

-- Use it in a query
SELECT product_id, safe_divide(revenue, cost) AS margin
FROM products;
```

**Table macro (returns a result set):**
```sql
CREATE OR REPLACE MACRO recent_orders(days) AS TABLE
    SELECT * FROM orders
    WHERE order_date >= current_date - INTERVAL (days || ' days');

-- Call it in a FROM clause
SELECT * FROM recent_orders(30);
SELECT * FROM recent_orders(7) WHERE amount > 1000;
```

Macros vs UDFs:
- Macros expand to SQL before execution — the query planner sees the full expanded expression and can optimize it.
- UDFs are called at runtime — the planner treats them as black boxes.
- Macros are SQL-only. UDFs can contain arbitrary Python or C logic.

Macros are persisted with the database when using a file-backed connection. In-memory connections lose macros on close.

```sql
-- List all macros
SELECT * FROM duckdb_functions() WHERE function_type = 'macro';
```

> [!tip] SQL macros are ideal for encoding business logic that belongs in the database layer — date normalization, unit conversion, safe arithmetic — without the overhead of a Python UDF call for every row.

@feynman

Like a typed alias for a code block — defined once, expanded inline at compile time, so the optimizer can see through it.
