@chapter
id: wdd-ch11-duckdb-in-pipelines
order: 11
title: DuckDB in Data Pipelines
summary: DuckDB as a transform layer in production pipelines, a local development and CI testing engine, and a local-first analytics platform — when it replaces heavier tools and when it doesn't.

@card
id: wdd-ch11-c001
order: 1
title: DuckDB as a Transform Layer
teaser: For medium-scale batch transforms, DuckDB on a single machine beats a Spark cluster on cost, latency, and operational complexity — up to a point.

@explanation

Most pipelines reach for Spark because the data "might be big." In practice, a large fraction of production batch jobs process datasets that fit comfortably on one machine. DuckDB runs those jobs faster and with less operational overhead.

The scale threshold where DuckDB wins:

- **Under ~500GB uncompressed** (often 1-2TB of Parquet) on a well-provisioned single node
- Transforms that are embarrassingly local — no shuffle required, no cross-node join
- Teams that want zero cluster management and no JVM tuning

A realistic comparison for a 50GB daily aggregation job:

```python
import duckdb

con = duckdb.connect()
con.execute("""
    COPY (
        SELECT
            user_id,
            DATE_TRUNC('day', event_time) AS day,
            COUNT(*) AS events,
            SUM(revenue_cents) AS revenue_cents
        FROM read_parquet('s3://data-lake/events/dt=*/part-*.parquet')
        GROUP BY 1, 2
    )
    TO 's3://data-lake/aggregates/daily/' (FORMAT PARQUET, PARTITION_BY (day))
""")
```

That runs on a single EC2 instance (`r7g.4xlarge`, ~$1/hr) in minutes. The equivalent EMR Spark job costs more and takes longer to provision than to run.

> [!tip] A well-provisioned single node (64 vCPU, 256GB RAM) can process 500GB–1TB of Parquet in a single DuckDB job. Profile first before assuming you need a cluster.

@feynman

Like realizing you don't need a forklift to move furniture — a strong truck handles most jobs faster and at a tenth of the cost; the forklift is for the warehouse.

@card
id: wdd-ch11-c002
order: 2
title: dbt + DuckDB for Local Development
teaser: The `dbt-duckdb` adapter lets you run your full dbt project against local Parquet files — no warehouse credentials, no cloud costs, sub-second model runs.

@explanation

dbt is the de facto SQL transformation framework for analytics teams. Its typical development loop requires a live warehouse connection (Snowflake, BigQuery, Redshift), which means cloud costs, latency on every `dbt run`, and credentials in every developer's local environment.

`dbt-duckdb` swaps the warehouse for a local DuckDB instance:

```bash
pip install dbt-duckdb
```

A minimal `profiles.yml` for local development:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: /tmp/dev.duckdb
      threads: 4
    prod:
      type: snowflake
      # ... warehouse credentials
```

Point your sources at local Parquet files:

```yaml
# sources.yml
sources:
  - name: raw
    meta:
      external_location: "read_parquet('data/raw/{{ source.name }}/*.parquet')"
```

With this setup:

- `dbt run` executes against local files in seconds
- No warehouse charges during development
- No shared dev environment conflicts
- CI can run `dbt test` against fixture data without credentials

The same models run unchanged against the production warehouse when the target switches to `prod`.

> [!info] `dbt-duckdb` is the officially supported community adapter maintained by the dbt-labs community. As of 2026 it tracks dbt-core closely and supports materializations, snapshots, seeds, and most dbt features.

@feynman

Like using `sqlite3` for local Django development before deploying to PostgreSQL — the adapter pattern lets you iterate fast locally without changing any application code.

@card
id: wdd-ch11-c003
order: 3
title: CI/CD Testing Against Real Data
teaser: Replace test databases and mocked fixtures with DuckDB plus real Parquet snapshots — CI runs full integration tests against production-representative data in seconds, with no credentials.

@explanation

The standard CI testing problem for data pipelines: you need representative data to test against, but production data requires credentials, has privacy implications, and is slow to query. Common workarounds — mocked fixtures, tiny synthetic datasets — miss real-world edge cases.

DuckDB solves this with committed Parquet snapshots:

```
tests/
  fixtures/
    events_sample.parquet       # 10k rows from production, PII stripped
    users_sample.parquet
  test_daily_aggregation.py
```

```python
import duckdb
import pytest

@pytest.fixture
def con():
    return duckdb.connect(':memory:')

def test_daily_aggregation_excludes_cancelled(con):
    result = con.execute("""
        SELECT COUNT(*) AS ct
        FROM read_parquet('tests/fixtures/events_sample.parquet')
        WHERE status != 'cancelled'
        GROUP BY DATE_TRUNC('day', event_time)
    """).fetchone()
    assert result[0] > 0

def test_no_negative_revenue(con):
    result = con.execute("""
        SELECT COUNT(*) FROM read_parquet('tests/fixtures/events_sample.parquet')
        WHERE revenue_cents < 0
    """).fetchone()
    assert result[0] == 0
```

This CI job:
- Requires no environment variables or secrets
- Runs in the same CI container as any Python test
- Executes in seconds, not minutes
- Can be run locally with a single `pytest` invocation

> [!warning] Keep fixture files small (under 50MB compressed) and strip PII before committing. For larger fixtures, store on S3 and download as a CI step — don't commit multi-GB Parquet to git.

@feynman

Like using SQLite in-memory databases for Django unit tests — the test suite runs the real query logic against a real engine, just against a controlled dataset instead of production.

@card
id: wdd-ch11-c004
order: 4
title: Local-First Analytics in CLI Tools
teaser: Embed DuckDB in a CLI tool and ship full analytical SQL capability to anyone who can run a binary — no server, no setup, no network required.

@explanation

CLI tools that need to query structured data typically reach for SQLite or in-memory Pandas operations. DuckDB is a better fit when the queries are analytical: aggregations, window functions, multi-file joins.

A minimal analytics CLI using DuckDB and Typer:

```python
import typer
import duckdb
from pathlib import Path

app = typer.Typer()

@app.command()
def summary(data_dir: Path, group_by: str = "region"):
    con = duckdb.connect(':memory:')
    result = con.execute(f"""
        SELECT
            {group_by},
            COUNT(*) AS events,
            SUM(revenue_cents) / 100.0 AS revenue
        FROM read_parquet('{data_dir}/**/*.parquet')
        GROUP BY 1
        ORDER BY revenue DESC
    """).df()
    typer.echo(result.to_string(index=False))

if __name__ == "__main__":
    app()
```

Practical patterns for CLI analytics tools:

- Accept a directory of Parquet files or a glob pattern as input — let DuckDB's multi-file reader handle it
- Use `:memory:` connections for one-shot queries; persist to a `.duckdb` file if the user needs to re-query
- Stream results with `fetchmany()` for large outputs rather than loading everything into a DataFrame
- Ship the tool as a single binary using PyInstaller — DuckDB's zero-dependency core bundles cleanly

> [!tip] The DuckDB CLI binary (`duckdb`) itself is a complete SQL REPL for Parquet and CSV files with zero installation beyond downloading the binary. It is the fastest way to let non-developers run analytical queries on local data.

@feynman

Like shipping `ripgrep` instead of a grep wrapper script — the compiled-in engine is what makes it fast and portable, not the query layer you build around it.

@card
id: wdd-ch11-c005
order: 5
title: Edge Analytics and IoT Deployments
teaser: DuckDB's small binary footprint and zero-dependency build make it practical for edge nodes and IoT devices — run analytical SQL on collected sensor data without a network hop.

@explanation

Edge analytics requirements are in direct tension with most database tooling: you need analytical capability (aggregations, downsampling, anomaly detection), but you have constrained RAM, no reliable network, and no operations team to manage a database server.

DuckDB fits these constraints because:

- The DuckDB binary is ~30MB. The shared library is smaller.
- It runs on ARM64 (Raspberry Pi, Apple Silicon, AWS Graviton) without modification
- In-memory mode leaves no state on the filesystem — useful for stateless edge nodes
- It processes Parquet natively, which is the right format for edge telemetry (compressed, columnar)

A Raspberry Pi telemetry aggregation pattern:

```python
import duckdb
import schedule
import time

def aggregate_and_forward():
    con = duckdb.connect(':memory:')
    summary = con.execute("""
        SELECT
            sensor_id,
            DATE_TRUNC('minute', ts) AS minute,
            AVG(temperature) AS avg_temp,
            MAX(temperature) AS max_temp,
            MIN(temperature) AS min_temp
        FROM read_parquet('/var/data/sensors/today/*.parquet')
        WHERE ts >= NOW() - INTERVAL '5 minutes'
        GROUP BY 1, 2
    """).fetchall()
    # forward summary to central store
    upload_to_central(summary)

schedule.every(5).minutes.do(aggregate_and_forward)
```

The edge node writes raw sensor readings to rolling Parquet files. DuckDB aggregates them every 5 minutes and forwards only the summary — reducing bandwidth by 100x.

> [!info] DuckDB-Wasm extends edge analytics to web browsers and serverless runtimes. A Cloudflare Worker or Deno Deploy function can run DuckDB-Wasm against a downloaded Parquet file without any server infrastructure.

@feynman

Like running `ffmpeg` on a Raspberry Pi to transcode video before uploading — the heavy computation happens at the edge in the capable binary, not in a cloud service.

@card
id: wdd-ch11-c006
order: 6
title: DuckDB-Wasm for Browser Analytics
teaser: DuckDB-Wasm runs the full DuckDB engine in a browser tab — users can query Parquet files locally with no server, no upload, and no privacy risk.

@explanation

DuckDB-Wasm compiles the DuckDB engine to WebAssembly. It runs entirely in the browser, executing analytical SQL against data the user provides — no data ever leaves the client machine.

Setup:

```javascript
import * as duckdb from '@duckdb/duckdb-wasm';

const JSDELIVR_BUNDLES = duckdb.getJsDelivrBundles();
const bundle = await duckdb.selectBundle(JSDELIVR_BUNDLES);

const worker = new Worker(bundle.mainWorker);
const logger = new duckdb.ConsoleLogger();
const db = new duckdb.AsyncDuckDB(logger, worker);
await db.instantiate(bundle.mainModule, bundle.pthreadWorker);

const conn = await db.connect();
```

Query a user-uploaded CSV or Parquet file:

```javascript
await db.registerFileHandle(
    'upload.parquet',
    file,                    // File from <input type="file">
    duckdb.DuckDBDataProtocol.BROWSER_FILEREADER,
    true
);

const result = await conn.query(`
    SELECT region, SUM(revenue) AS total
    FROM 'upload.parquet'
    GROUP BY region
    ORDER BY total DESC
`);
```

Use cases where DuckDB-Wasm is the right call:

- Analytics tools for sensitive data (financial, medical) where server-upload is unacceptable
- Offline-capable web apps that query a bundled dataset
- Developer tools that need SQL over user-provided files
- "Query your own data" product features without a backend

The ~7MB Wasm bundle is the only download. No server required after the initial page load.

> [!warning] DuckDB-Wasm is single-threaded in Safari due to `SharedArrayBuffer` restrictions. Multi-threaded performance (available in Chrome and Firefox with appropriate COOP/COEP headers) is substantially better for large scans.

@feynman

Like running a Python script in Pyodide — the entire language runtime is in the browser, and the user's data never leaves their machine.

@card
id: wdd-ch11-c007
order: 7
title: Embedded Analytics in Applications
teaser: Serve analytics queries from within your application process using DuckDB — no separate analytics database, no extra infrastructure, no network hop between app and data.

@explanation

The traditional embedded analytics architecture for application developers: ship to a warehouse (Snowflake, BigQuery), query from the app via an API, cache aggressively to hide latency. DuckDB offers a simpler model when data fits within a single node.

Patterns for embedded application analytics:

**Read-only analytics alongside a primary database:**
```python
# Primary writes go to PostgreSQL; a periodic job exports
# aggregates to Parquet. The app queries those with DuckDB.
analytics = duckdb.connect('analytics.duckdb', read_only=True)

@app.get('/reports/revenue')
async def revenue_report(start: date, end: date):
    result = analytics.execute("""
        SELECT
            DATE_TRUNC('week', day) AS week,
            SUM(revenue_cents) / 100.0 AS revenue
        FROM daily_revenue
        WHERE day BETWEEN ? AND ?
        GROUP BY 1
        ORDER BY 1
    """, [start, end]).df()
    return result.to_dict(orient='records')
```

**Materialized analytics table from an export job:**
- Run a nightly or hourly job that exports from PostgreSQL to Parquet
- DuckDB queries the Parquet directly — no import step needed
- Reads are instant; the export job is the only I/O boundary

**Serving dashboards from a DuckDB file:**
Tools like Evidence and Rill embed DuckDB as the query engine and build the entire BI layer around it. The `.duckdb` file is the database; the dashboard tool is the presentation layer.

Where this approach fits:
- Internal tools and dashboards with datasets under a few hundred GB
- Teams that want analytics without a second database to manage
- Applications where read latency is more important than write concurrency

> [!tip] Multiple application processes can open a DuckDB file in `read_only=True` mode simultaneously. Reserve write access for a single background job that updates the analytics file. This pattern supports concurrent dashboard readers without violating the single-writer constraint.

@feynman

Like bundling SQLite for application config instead of running a separate MySQL instance — the embedded model eliminates a whole tier of your architecture.

@card
id: wdd-ch11-c008
order: 8
title: ML Feature Engineering with DuckDB
teaser: DuckDB's vectorized SQL engine computes ML features over local event data faster than Pandas for most aggregation-heavy patterns — and hands off to training frameworks via Arrow with zero copy.

@explanation

Feature engineering is often the bottleneck in ML training pipelines. The typical Python pattern — load data into Pandas, compute aggregations, write to a feature store — is slow and memory-intensive on large datasets. DuckDB handles the compute step faster and with less memory pressure.

A concrete feature computation example:

```python
import duckdb
import pyarrow as pa

con = duckdb.connect()

# Compute user-level features from an event log
features = con.execute("""
    WITH user_stats AS (
        SELECT
            user_id,
            COUNT(*) AS event_count_30d,
            COUNT(DISTINCT DATE_TRUNC('day', event_time)) AS active_days_30d,
            SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count_30d,
            MAX(event_time) AS last_event_time,
            AVG(session_duration_s) AS avg_session_duration
        FROM read_parquet('data/events/dt=*/part-*.parquet')
        WHERE event_time >= NOW() - INTERVAL '30 days'
        GROUP BY user_id
    )
    SELECT
        u.user_id,
        u.event_count_30d,
        u.active_days_30d,
        u.purchase_count_30d,
        DATEDIFF('day', u.last_event_time, NOW()) AS days_since_last_event,
        u.avg_session_duration,
        p.lifetime_value   -- join with entity table
    FROM user_stats u
    LEFT JOIN read_parquet('data/profiles/profiles.parquet') p USING (user_id)
""").arrow()  # Returns a PyArrow Table, zero-copy to training frameworks

# Hand off to PyTorch / XGBoost / scikit-learn
import pandas as pd
df = features.to_pandas()  # Or use Arrow directly with torch.utils.data
```

Advantages over Pandas for this pattern:

- DuckDB scans only the needed columns from each Parquet file
- Multi-file glob patterns avoid manual file concatenation
- The optimizer rewrites the join order automatically
- `arrow()` output is zero-copy to Arrow-native frameworks

> [!info] For feature stores (Feast, Hopsworks), DuckDB can serve as the offline store engine — computing point-in-time correct feature joins locally before registering features. The `duckdb-feast` integration is maintained by the Feast community.

@feynman

Like using a database's GROUP BY instead of a Python for-loop for aggregations — the vectorized engine processes columns in bulk, not one row at a time, and the speedup is the same reason.

@card
id: wdd-ch11-c009
order: 9
title: Pipeline Orchestration with Airflow and Prefect
teaser: DuckDB integrates with Airflow and Prefect as a lightweight operator — run SQL transforms as pipeline tasks without a warehouse connection or cluster to provision.

@explanation

DuckDB works naturally within orchestration frameworks because it is a library, not a service. You do not need an Airflow connection object pointing to a running server — you instantiate DuckDB inside the task function.

**Airflow PythonOperator pattern:**

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import duckdb

def transform_daily_events(**context):
    ds = context['ds']  # execution date, e.g. '2026-04-15'
    con = duckdb.connect('/data/pipeline.duckdb')
    con.execute(f"""
        INSERT INTO daily_summary
        SELECT
            user_id,
            '{ds}'::DATE AS day,
            COUNT(*) AS events,
            SUM(revenue_cents) AS revenue_cents
        FROM read_parquet('/data/raw/dt={ds}/*.parquet')
        GROUP BY user_id
    """)
    con.close()

with DAG('daily_transform', start_date=datetime(2026, 1, 1), schedule='@daily') as dag:
    transform = PythonOperator(
        task_id='transform_daily_events',
        python_callable=transform_daily_events,
    )
```

**Prefect task pattern:**

```python
from prefect import task, flow
import duckdb

@task
def compute_features(partition_date: str) -> int:
    with duckdb.connect(':memory:') as con:
        result = con.execute("""
            SELECT COUNT(DISTINCT user_id)
            FROM read_parquet(?)
        """, [f's3://bucket/events/dt={partition_date}/*.parquet']).fetchone()
        return result[0]

@flow
def feature_pipeline(partition_date: str):
    n_users = compute_features(partition_date)
    print(f"Processed {n_users} users for {partition_date}")
```

Key integration points:

- Use `:memory:` connections for stateless tasks; persist to a file for incremental builds
- DuckDB's S3 support (via `httpfs` extension) works in any environment with S3 credentials
- Each task gets its own DuckDB connection — no shared state to manage between workers

> [!warning] When running DuckDB tasks in parallel on the same Airflow worker, point each task at a different DuckDB file or use `:memory:`. Two tasks writing to the same `.duckdb` file simultaneously will contend on the write lock.

@feynman

Like using a subprocess call to `jq` in a bash pipeline stage — the tool runs inside the task, not as a service the task connects to.

@card
id: wdd-ch11-c010
order: 10
title: Incremental Transforms with DuckDB
teaser: DuckDB's INSERT SELECT and COPY patterns support efficient incremental pipeline runs — process only new partitions, append to existing tables, without reprocessing history.

@explanation

Production pipelines need incremental processing: on each run, process only the new data since the last run. DuckDB supports this through standard SQL patterns combined with its Parquet partition-pruning.

**Append-only incremental pattern:**

```python
import duckdb
from datetime import date, timedelta

def run_incremental(con: duckdb.DuckDBPyConnection, partition_date: date):
    # Skip if partition already processed
    existing = con.execute("""
        SELECT COUNT(*) FROM daily_summary WHERE day = ?
    """, [partition_date]).fetchone()[0]

    if existing > 0:
        print(f"Partition {partition_date} already processed, skipping")
        return

    con.execute("""
        INSERT INTO daily_summary
        SELECT
            user_id,
            ?::DATE AS day,
            COUNT(*) AS events,
            SUM(revenue_cents) AS revenue_cents
        FROM read_parquet(?)
        GROUP BY user_id
    """, [partition_date, f"s3://bucket/raw/dt={partition_date}/*.parquet"])
```

**Overwrite a date partition (idempotent):**

```sql
DELETE FROM daily_summary WHERE day = ?;

INSERT INTO daily_summary
SELECT ...
FROM read_parquet(?)
GROUP BY user_id;
```

**Export incremental output as partitioned Parquet:**

```sql
COPY (
    SELECT *, ?::DATE AS dt FROM staging_table
)
TO 's3://bucket/output/' (
    FORMAT PARQUET,
    PARTITION_BY (dt),
    OVERWRITE_OR_IGNORE true
);
```

The `PARTITION_BY` clause writes Hive-partitioned Parquet (`dt=2026-04-15/part-0.parquet`), compatible with downstream Iceberg, Delta, or Hive Metastore catalogs.

> [!tip] DuckDB's Parquet reader prunes partitions at the file-discovery level. A query filtering on `dt = '2026-04-15'` reads only the files in that partition directory — the equivalent of Spark partition elimination, but automatic.

@feynman

Like Git's incremental index — only tracking what changed rather than re-scanning every file on every commit.

@card
id: wdd-ch11-c011
order: 11
title: DuckDB with MotherDuck for Hybrid Pipelines
teaser: MotherDuck lets you push DuckDB queries to a shared cloud instance — the same SQL runs locally in development and against cloud-hosted data in production with a connection string change.

@explanation

MotherDuck is the managed cloud service built on DuckDB. It adds multi-user access, persistent shared databases, and a web query UI while preserving the DuckDB SQL dialect exactly.

The connection model:

```python
import duckdb

# Local development
con = duckdb.connect('/tmp/dev.duckdb')

# Production — switch by changing the connection string
con = duckdb.connect('md:my_database?motherduck_token=...')
```

The same SQL runs unchanged. MotherDuck's query planner decides whether to execute locally, in the cloud, or split across both (hybrid execution).

Hybrid execution — the key differentiator:

```sql
-- This query joins a local file (processed on the laptop)
-- with a cloud table (processed in MotherDuck)
-- MotherDuck's planner pushes what it can to the cloud
-- and streams the join result back locally
SELECT local.user_id, cloud.lifetime_value
FROM read_parquet('local_events.parquet') local
JOIN my_database.user_profiles cloud USING (user_id);
```

When MotherDuck makes sense over plain DuckDB:

- Shared data access: multiple analysts query the same dataset concurrently (reads are concurrent; writes still serialize)
- Cloud-scale storage: datasets that don't fit on a single developer machine
- Audit and access control: MotherDuck adds user-level access policies on top of DuckDB files
- Web UI: non-engineers need a browser-based query interface

> [!info] MotherDuck's pricing model as of 2026 is compute-time based, similar to serverless warehouses. For bursty analytical workloads it can be cheaper than an always-on Snowflake warehouse at the same scale.

@feynman

Like SQLite plus Turso for edge-replicated database access — the local-first model extends to a cloud tier without changing the programming model.

@card
id: wdd-ch11-c012
order: 12
title: Testing Data Quality in Pipelines
teaser: DuckDB makes it practical to assert data quality expectations in-pipeline — run SQL assertions against Parquet outputs as a pipeline step, not a post-hoc audit.

@explanation

Data quality testing in pipelines typically happens too late: a downstream consumer notices bad data and traces it back to a pipeline bug from three days ago. Inline assertions — SQL checks that run immediately after each transform — catch issues at the source.

A lightweight assertion framework using DuckDB:

```python
import duckdb
from dataclasses import dataclass
from typing import Optional

@dataclass
class QualityCheck:
    name: str
    query: str
    expected: int = 0
    description: str = ""

def run_checks(con: duckdb.DuckDBPyConnection, checks: list[QualityCheck]):
    failures = []
    for check in checks:
        result = con.execute(check.query).fetchone()[0]
        if result != check.expected:
            failures.append(f"{check.name}: expected {check.expected}, got {result}")
    if failures:
        raise ValueError("Data quality checks failed:\n" + "\n".join(failures))

checks = [
    QualityCheck(
        name="no_null_user_ids",
        query="SELECT COUNT(*) FROM daily_summary WHERE user_id IS NULL",
        description="user_id must never be null"
    ),
    QualityCheck(
        name="no_negative_revenue",
        query="SELECT COUNT(*) FROM daily_summary WHERE revenue_cents < 0",
        description="revenue cannot be negative"
    ),
    QualityCheck(
        name="row_count_sanity",
        query="SELECT COUNT(*) < 1000 FROM daily_summary",  # returns 0 if >= 1000 rows
        description="expect at least 1000 rows after transform"
    ),
]

con = duckdb.connect('pipeline.duckdb')
run_checks(con, checks)
```

This pattern integrates naturally with dbt tests, Great Expectations, or custom pipeline validation. The DuckDB query engine handles millions of rows per assertion in milliseconds.

> [!tip] Run quality checks against the output Parquet directly — not the DuckDB table. This validates the actual artifact the downstream consumer will read, not just the intermediate state.

@feynman

Like adding assertions to a function immediately after its critical computation — catching the error at the source rather than debugging a wrong answer three callsites later.

@card
id: wdd-ch11-c013
order: 13
title: When DuckDB Is Not Enough
teaser: DuckDB has clear upper bounds — knowing the concurrency, scale, and write-frequency thresholds where you need Spark or a warehouse prevents architectural debt.

@explanation

DuckDB is the right tool for a specific range. Being honest about the upper bound prevents building on DuckDB and then re-architecting under load.

**The scale ceiling:**
DuckDB processes data on a single node. A well-provisioned instance handles 500GB–1TB of Parquet well. Above ~2TB of active data per job, or when the data does not fit on one machine's disk, a distributed system is necessary. Spark, Trino, or a cloud warehouse replaces DuckDB at this tier.

**The concurrency ceiling:**
DuckDB has one writer. If your pipeline writes from multiple concurrent workers, you need either:
- A message queue to serialize writes through a single DuckDB writer
- A warehouse (Snowflake, BigQuery) with native write concurrency support

For multi-user write workloads, DuckDB is not the right tool regardless of data size.

**Write frequency:**
High-frequency single-row inserts — thousands per second from concurrent clients — are not what DuckDB was built for. A stream-processing system (Kafka + Flink, or a streaming warehouse like Apache Paimon) handles this pattern.

**Operational requirements:**
If you need:
- Point-in-time recovery beyond a single backup
- Multi-region replication
- Role-based access control at the row level
- Live query monitoring with query kill capabilities

...you need a managed warehouse or a server-based database. DuckDB does not provide these operationally.

Summary of when to graduate from DuckDB:

- Data per job consistently exceeds 2TB
- Multiple concurrent writers from separate processes
- High-frequency row-level inserts (>1000/sec)
- Multi-user analytics with row-level access control
- HA / replication requirements for the analytics tier

> [!warning] The temptation to "just add another DuckDB node" does not work. DuckDB is not a distributed system. There is no horizontal scaling story. When you need scale-out, the migration to Spark or a warehouse is a real re-architecture, not a configuration change.

@feynman

Like a single-threaded Node.js server — incredibly efficient for its intended workload, but the moment you need true parallelism across requests, you need a different model, not a bigger machine.

@card
id: wdd-ch11-c014
order: 14
title: Choosing DuckDB vs Spark vs Warehouse
teaser: The decision framework comes down to three axes — data size, write concurrency, and operational requirements — and DuckDB wins cleanly in the zone where all three are modest.

@explanation

A practical decision framework:

**Choose DuckDB when:**
- Batch jobs process under ~500GB of data per run
- One writer at a time is acceptable (scheduled jobs, not concurrent clients)
- No external service can be installed (CI, edge, browser, CLI tools)
- Fast local iteration matters more than horizontal scalability
- Dataset fits on a single node with room to spare

**Choose Spark/Trino/Flink when:**
- Data per job exceeds 1–2TB
- The transform requires a distributed shuffle (large joins on non-colocated keys)
- You already have a cluster and the operational cost is sunk
- Real-time or near-real-time stream processing is required

**Choose a managed warehouse (Snowflake, BigQuery, Redshift) when:**
- Multiple concurrent users query and write to shared data
- You need row-level access control and audit logs
- Data governance, data catalog integration, or compliance features are required
- The operations team is not equipped to manage the infrastructure

**The hybrid that works well in practice:**
- DuckDB for local development, CI testing, and medium-scale batch jobs
- A managed warehouse for the production shared tier
- `dbt-duckdb` in local dev, `dbt-snowflake` (or equivalent) in production

This is not a compromise — it is the correct tool at each layer. dbt makes switching between the two invisible to the SQL author.

> [!info] For teams currently running Spark for jobs under 500GB: a DuckDB migration typically reduces job runtime by 5-10x and eliminates cluster provisioning latency entirely. The migration is usually a SQL-for-SQL substitution — the queries change minimally, the infrastructure cost drops substantially.

@feynman

Like choosing between a laptop, a workstation, and a compute cluster — the right answer depends on the job size, not a general preference for one over the others.
