@chapter
id: wdd-ch05-querying-remote-data
order: 5
title: Querying Remote Data
summary: DuckDB queries S3, GCS, and Azure Blob Storage directly — no download, no import — with predicate pushdown to remote storage that keeps network traffic minimal.

@card
id: wdd-ch05-c001
order: 1
title: The HTTPFS Extension
teaser: HTTPFS is DuckDB's gateway to remote files — it adds HTTP(S), S3, GCS, and Azure support to any file-reading function you already know.

@explanation

The `httpfs` extension intercepts file path resolution and handles HTTP and cloud storage URLs transparently. Once loaded, any DuckDB function that reads files works with remote paths.

```sql
INSTALL httpfs;
LOAD httpfs;

-- Read a remote Parquet file over HTTPS
SELECT COUNT(*) FROM 'https://example.com/dataset/2024.parquet';

-- Read from S3
SELECT * FROM 's3://my-bucket/data/events.parquet' LIMIT 10;

-- Read from GCS
SELECT * FROM 'gs://my-gcs-bucket/data/events.parquet' LIMIT 10;

-- Read from Azure Blob Storage
SELECT * FROM 'azure://my-container/data/events.parquet' LIMIT 10;

-- Multi-file glob over S3
SELECT COUNT(*) FROM 's3://my-bucket/events/**/*.parquet';
```

The extension is available in all DuckDB language bindings:
```python
import duckdb
con = duckdb.connect()
con.install_extension('httpfs')
con.load_extension('httpfs')
result = con.execute("SELECT * FROM 's3://bucket/data.parquet'").df()
```

HTTPFS implements:
- Range requests — only fetches the byte ranges needed for the query, not the whole file.
- Metadata caching — caches Parquet footer and row group metadata locally to avoid repeated metadata fetches.
- Parallel range requests — issues multiple parallel byte-range requests for large files.

> [!info] In DuckDB 1.1+, HTTPFS is auto-loaded for S3 and HTTPS paths when the extension is installed. You may not need an explicit `LOAD httpfs` if you have previously installed it. The behavior depends on whether auto-loading is enabled in your build.

@feynman

Like mounting a remote filesystem — after the extension loads, remote paths look like local paths to every other DuckDB function.

@card
id: wdd-ch05-c002
order: 2
title: S3 Authentication and Configuration
teaser: DuckDB supports all standard AWS credential mechanisms for S3 — IAM roles, environment variables, credential files, and explicit key configuration.

@explanation

DuckDB resolves S3 credentials in this order:

1. Explicit SET configuration in the session
2. AWS environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
3. AWS credential file (`~/.aws/credentials`)
4. IAM instance profile / ECS task role (when running on AWS)

**Explicit credential configuration:**
```sql
LOAD httpfs;
SET s3_access_key_id = 'AKIAIOSFODNN7EXAMPLE';
SET s3_secret_access_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
SET s3_region = 'us-east-1';
```

**From Python with environment variables:**
```python
import os
import duckdb

# Set credentials via environment (boto3/AWS SDK pattern)
os.environ['AWS_ACCESS_KEY_ID'] = 'AKIAIOSFODNN7EXAMPLE'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'

con = duckdb.connect()
con.load_extension('httpfs')
# Credentials picked up from environment automatically
result = con.execute("SELECT * FROM 's3://my-bucket/data.parquet'").df()
```

**Using named credentials (DuckDB 1.1+):**
```sql
CREATE SECRET aws_prod (
    TYPE s3,
    KEY_ID 'AKIAIOSFODNN7EXAMPLE',
    SECRET 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    REGION 'us-east-1'
);
```

Named secrets persist in the database file and can be scoped to specific S3 endpoints — useful when accessing buckets across multiple AWS accounts.

**S3-compatible endpoints (MinIO, R2, etc.):**
```sql
SET s3_endpoint = 'minio.mycompany.com:9000';
SET s3_url_style = 'path';  -- Use path-style instead of virtual-hosted-style
```

> [!warning] Never hardcode AWS credentials in SQL files committed to version control. Use environment variables, IAM roles, or the named secret mechanism with the secret stored outside the repository.

@feynman

Like configuring an AWS SDK client — the same credential resolution chain you know from boto3 applies to DuckDB's S3 access.

@card
id: wdd-ch05-c003
order: 3
title: Predicate Pushdown to Remote Storage
teaser: DuckDB pushes WHERE clause filters into Parquet row group metadata, reading only the byte ranges that could match — minimizing network traffic for remote queries.

@explanation

When querying Parquet files on S3, network bandwidth is the bottleneck. DuckDB's predicate pushdown reduces data transfer by exploiting Parquet's metadata structure.

Parquet stores column statistics (min, max values) per row group in the file footer. DuckDB reads the footer first (a small range request), then evaluates predicates against the statistics before issuing data reads.

Example: a 1GB Parquet file with 10 row groups (100MB each). Each row group stores min/max for every column.

```sql
-- Query on a filtered column where pushdown applies
SELECT user_id, event_type FROM 's3://bucket/events.parquet'
WHERE event_date = '2024-06-15';
```

If `event_date` values in each row group don't overlap with '2024-06-15', DuckDB skips those row groups entirely — potentially reducing a 1GB read to 100MB.

The pushdown works because:
1. DuckDB fetches the Parquet footer (file metadata) — small range request.
2. Evaluates WHERE clause against row group statistics.
3. Issues range requests only for row groups that could contain matching rows.
4. Within each row group, reads only the columns referenced in the query (column pruning).

Factors that limit pushdown effectiveness:
- **Low-cardinality sort order.** If the Parquet file is sorted by `event_date`, each row group contains a narrow date range, and statistics are tight. If the file is unsorted, many row groups will have overlapping date ranges.
- **Statistics quality.** Parquet files written without statistics (rare but possible) have no min/max metadata; pushdown cannot occur.
- **Complex predicates.** `LIKE`, `IN` with many values, and UDF calls cannot use statistics-based pushdown.

> [!tip] Write Parquet files sorted by your most-common filter column. `COPY (SELECT * FROM events ORDER BY event_date) TO 's3://bucket/events.parquet'` produces a file where date filters push down to a fraction of the row groups.

@feynman

Like a database index scan vs a full table scan — instead of reading the whole file, DuckDB checks a small metadata entry for each row group and skips the ones that can't match.

@card
id: wdd-ch05-c004
order: 4
title: GCS Authentication
teaser: DuckDB queries Google Cloud Storage via HMAC keys or application default credentials — the configuration parallels S3 with GCS-specific endpoint settings.

@explanation

DuckDB accesses Google Cloud Storage using S3-compatible HMAC credentials or by treating GCS as an S3-compatible endpoint.

**Option 1 — GCS HMAC keys (S3-compatible access):**
```sql
LOAD httpfs;
SET s3_endpoint = 'storage.googleapis.com';
SET s3_access_key_id = 'GOOGEXAMPLEKEY';
SET s3_secret_access_key = 'your-hmac-secret';
SET s3_url_style = 'path';

-- Now use gs:// prefix or s3:// with the GCS endpoint
SELECT * FROM 'gs://my-gcs-bucket/data.parquet';
```

**Option 2 — gcs:// prefix (DuckDB 1.1+):**
DuckDB 1.1 added a `gcs` secret type for Application Default Credentials:
```sql
CREATE SECRET gcs_creds (
    TYPE gcs,
    TOKEN 'ya29.your-oauth-token'
);

SELECT * FROM 'gs://my-bucket/data.parquet';
```

**Using Application Default Credentials from Python:**
```python
import google.auth
import google.auth.transport.requests
import duckdb

# Get an access token from ADC
credentials, _ = google.auth.default()
auth_req = google.auth.transport.requests.Request()
credentials.refresh(auth_req)

con = duckdb.connect()
con.load_extension('httpfs')
con.execute(f"""
    CREATE SECRET gcs_creds (
        TYPE gcs,
        TOKEN '{credentials.token}'
    )
""")
result = con.execute("SELECT * FROM 'gs://my-bucket/data.parquet'").df()
```

GCS uniform bucket-level access (UBLA): requires IAM-based access rather than HMAC. Use the OAuth token approach above.

> [!info] HMAC keys for GCS must be created explicitly in the Google Cloud Console under Storage > Settings > Interoperability. They are distinct from service account keys.

@feynman

Like configuring S3-compatible access to a non-AWS provider — the protocol is the same, only the endpoint URL and key format change.

@card
id: wdd-ch05-c005
order: 5
title: Azure Blob Storage
teaser: DuckDB's azure extension reads from Azure Blob Storage and ADLS Gen2 using connection strings or Azure Active Directory credentials.

@explanation

The `azure` extension provides Azure Blob Storage and Azure Data Lake Storage Gen2 support.

```sql
INSTALL azure;
LOAD azure;

-- Connection string authentication
SET azure_storage_connection_string = 'DefaultEndpointsProtocol=https;AccountName=myaccount;AccountKey=key;EndpointSuffix=core.windows.net';

-- Read a file
SELECT * FROM 'azure://my-container/data/events.parquet';

-- ADLS Gen2 path (abfss prefix)
SELECT * FROM 'abfss://my-container@myaccount.dfs.core.windows.net/data/*.parquet';
```

Named secret with explicit credentials:
```sql
CREATE SECRET azure_creds (
    TYPE azure,
    ACCOUNT_NAME 'myaccount',
    ACCOUNT_KEY 'base64-encoded-account-key'
);
```

SAS token authentication:
```sql
CREATE SECRET azure_sas (
    TYPE azure,
    ACCOUNT_NAME 'myaccount',
    SAS_TOKEN '?sv=2023-01-03&ss=b&srt=sco&sp=rwdlacupitfx...'
);
```

Azure CLI credential (managed identity or `az login`):
```python
con.execute("""
    CREATE SECRET azure_managed (
        TYPE azure,
        PROVIDER credential_chain
    )
""")
```

The `credential_chain` provider uses the same credential resolution order as the Azure SDK — managed identity first, then environment variables, then CLI credentials.

> [!tip] For Azure pipelines running in Azure Container Apps or Azure Functions, use managed identity with `PROVIDER credential_chain`. No credentials to manage, no rotation required.

@feynman

Like configuring an Azure Storage client — the same credential types (connection strings, SAS tokens, managed identity) apply, just specified as DuckDB secret configuration.

@card
id: wdd-ch05-c006
order: 6
title: Querying S3 at Scale — Multi-File Patterns
teaser: DuckDB handles multi-file S3 queries with glob patterns, parallel reads, and Hive partition pruning — the combination that makes it viable for querying datasets with thousands of files.

@explanation

A production data lake on S3 typically has thousands of Parquet files organized by date or partition. DuckDB handles this efficiently.

```sql
-- Read all Parquet files in a prefix (recursive glob)
SELECT COUNT(*) FROM 's3://datalake/events/**/*.parquet';

-- Read with Hive partition pruning
SELECT event_type, COUNT(*)
FROM read_parquet('s3://datalake/events/**/*.parquet', hive_partitioning=true)
WHERE year = 2024 AND month = 6
GROUP BY event_type;
-- DuckDB skips all directories except year=2024/month=6/

-- Union multiple explicit paths
SELECT * FROM 's3://datalake/events/2024-01/*.parquet'
UNION ALL
SELECT * FROM 's3://datalake/events/2024-02/*.parquet';
```

Parallel reads:
DuckDB issues parallel range requests across files. With 8 threads and 40 Parquet files, each thread handles ~5 files concurrently. The bottleneck shifts from query execution to S3 network throughput.

S3 metadata operations:
Glob expansion requires listing S3 prefixes (LIST operations). For datasets with thousands of partitions, the LIST calls can add latency. Strategies to minimize:
- Use explicit paths instead of deep globs where possible.
- Cache the file list in a DuckDB table: `CREATE TABLE file_list AS SELECT filename FROM glob('s3://bucket/**/*.parquet')`.
- Use Iceberg or Delta metadata instead of file listing for very large datasets.

```sql
-- Cache glob expansion
CREATE TABLE file_list AS
SELECT unnest(glob('s3://datalake/events/**/*.parquet')) AS path;

-- Query against cached file list
SELECT * FROM read_parquet(
    (SELECT list(path) FROM file_list WHERE path LIKE '%2024-06%')
);
```

> [!warning] S3 LIST operations are billed separately from GET operations. For datasets with 10,000+ files, repeated glob expansions generate significant LIST API costs. Cache the file list or use a table format (Iceberg/Delta) to avoid listing.

@feynman

Like `find` piped into parallel file processing — the glob finds the files, and the parallel query engine processes them concurrently without you writing a loop.

@card
id: wdd-ch05-c007
order: 7
title: HTTP Direct Query
teaser: DuckDB reads Parquet, CSV, and JSON files directly over HTTP(S) — useful for public datasets, APIs that return data files, and ad-hoc analysis of web-hosted data.

@explanation

Any URL that returns a Parquet, CSV, or JSON file is queryable directly:

```sql
LOAD httpfs;

-- Query a public dataset
SELECT * FROM 'https://example.com/datasets/sales_2024.parquet' LIMIT 5;

-- New York Taxi dataset (classic DuckDB demo)
SELECT
    passenger_count,
    AVG(trip_distance) AS avg_distance,
    COUNT(*) AS trips
FROM 'https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet'
GROUP BY passenger_count
ORDER BY passenger_count;

-- Read multiple files from a known URL pattern
SELECT * FROM read_parquet([
    'https://example.com/data/2024-01.parquet',
    'https://example.com/data/2024-02.parquet',
    'https://example.com/data/2024-03.parquet'
]);
```

Range requests:
For Parquet files hosted on servers that support HTTP Range requests, DuckDB fetches only the byte ranges it needs (footer metadata, then selected row groups). Servers must return `Accept-Ranges: bytes` in their headers.

For CSV and JSON over HTTP, DuckDB must download the entire file before parsing — there is no byte-range optimization for row-oriented formats.

Authentication for private HTTP endpoints:
```sql
-- HTTP Basic auth
SELECT * FROM 'https://user:password@api.example.com/data.parquet';

-- Bearer token (set as header)
-- Direct header support is limited; use a pre-signed URL or API-key-in-URL pattern instead
```

> [!tip] For exploring public data from sites like data.gov, OpenDataSoft, or research repositories, HTTP direct query eliminates the download-then-import workflow entirely. Point DuckDB at the URL and query immediately.

@feynman

Like `curl` piped into a database — instead of downloading and then querying, you query the URL directly and DuckDB handles the fetching.

@card
id: wdd-ch05-c008
order: 8
title: Caching and Local Materialization Strategies
teaser: Remote queries are network-bound — knowing when to cache results locally versus querying remote on every run determines whether your pipeline is fast or expensive.

@explanation

Remote queries incur network costs (latency, bandwidth, API call pricing). The right caching strategy depends on data freshness requirements and query frequency.

**No caching — query remote on every run:**
Right when:
- Data changes frequently (streaming/near-real-time data).
- Query runs infrequently (once a week).
- Dataset is small (sub-100MB file transfer is fast).

**Materialize locally on first use:**
```python
import duckdb
from pathlib import Path

CACHE_PATH = Path('/tmp/events_cache.parquet')

con = duckdb.connect()
con.load_extension('httpfs')

if not CACHE_PATH.exists():
    con.execute(f"""
        COPY (SELECT * FROM 's3://bucket/events.parquet')
        TO '{CACHE_PATH}' (FORMAT PARQUET, COMPRESSION ZSTD)
    """)

result = con.execute(f"SELECT * FROM '{CACHE_PATH}'").df()
```

**Create a local DuckDB table from remote source:**
```sql
CREATE TABLE events AS SELECT * FROM 's3://bucket/events/**/*.parquet';
-- Subsequent queries run locally at full speed
```

**Incremental local mirror:**
```sql
-- Append only new data
INSERT INTO local_events
SELECT * FROM 's3://bucket/events/**/*.parquet'
WHERE event_date > (SELECT MAX(event_date) FROM local_events);
```

Cost awareness:
- S3 GET requests: $0.0004 per 1,000 requests (us-east-1, 2026 pricing).
- A 1,000-file Parquet dataset queried 10 times/day = 10,000 GET requests/day.
- Cache locally if the refresh rate is lower than the query rate.

> [!info] DuckDB's HTTPFS extension caches Parquet file footers (metadata) in memory for the session. The row group data is not cached between queries — each query that needs a row group re-fetches it. For repeated queries over the same remote dataset, local materialization is almost always worth doing.

@feynman

Like HTTP caching headers — decide whether to re-fetch from origin or serve from cache based on how fresh the data needs to be vs the cost of each fetch.

@card
id: wdd-ch05-c009
order: 9
title: Controlling Network Parallelism
teaser: DuckDB's parallel remote reads are fast but can saturate bandwidth or trigger rate limits — tuning thread count and concurrency prevents these problems.

@explanation

DuckDB's remote reads are parallelized across threads. On a machine with 16 cores, DuckDB issues up to 16 concurrent HTTP range requests for different row groups or files. This is fast but can cause problems.

**Thread count configuration:**
```sql
-- Reduce thread count for remote reads
SET threads = 4;

-- Or per-query hint (DuckDB 1.1+)
SET threads = 8;
SELECT * FROM 's3://bucket/large/**/*.parquet' WHERE region = 'US';
SET threads = 16;  -- restore afterward
```

**S3 request parallelism:**
S3 has per-prefix throughput limits. A single S3 prefix supports 3,500 PUT/DELETE and 5,500 GET requests per second. With 16 threads making rapid range requests against the same prefix, you approach this limit for large datasets.

Mitigation:
- Partition data across multiple S3 prefixes (already done if using date-based Hive partitioning).
- Reduce DuckDB thread count for batch jobs sharing S3 capacity with other services.
- Use `SET http_retries = 3` to handle transient throttling errors.

**Timeouts and retries:**
```sql
SET http_timeout = 30000;    -- 30 second timeout per request (milliseconds)
SET http_retries = 3;        -- retry 3 times on failure
SET http_retry_wait_ms = 100; -- wait 100ms before first retry
```

**Proxy configuration:**
```sql
SET http_proxy = 'http://proxy.company.com:8080';
```

> [!tip] For CI pipelines that run DuckDB S3 queries alongside other processes, cap DuckDB's thread count to 4 or 8. The marginal throughput improvement from 16 threads rarely justifies the risk of starving other services.

@feynman

Like connection pool sizing — more parallel connections get more throughput until you hit the server's capacity limit, after which more connections just create contention.

@card
id: wdd-ch05-c010
order: 10
title: The Secrets Manager — Storing Credentials Securely
teaser: DuckDB 1.1 introduced a built-in secrets manager that stores cloud credentials as named secrets in the database, replacing the pattern of setting global configuration strings for every session.

@explanation

Before the secrets manager, cloud credentials were configured with `SET` statements at the start of every session or via environment variables. DuckDB 1.1 introduced `CREATE SECRET` to persist named credentials in the database — credentials survive sessions and can be referenced by name rather than repeated inline.

**Creating a secret:**
```sql
CREATE SECRET my_s3_prod (
    TYPE s3,
    KEY_ID 'AKIA...',
    SECRET 'abc123...',
    REGION 'us-east-1'
);
```

**Using a secret by scope:**
```sql
CREATE SECRET s3_dev (
    TYPE s3,
    PROVIDER credential_chain,
    SCOPE 's3://dev-bucket'
);

CREATE SECRET s3_prod (
    TYPE s3,
    KEY_ID 'AKIA...',
    SECRET '...',
    SCOPE 's3://prod-bucket'
);
```

DuckDB picks the secret automatically based on which bucket the query targets. No per-query configuration required.

**Supported secret types:** `s3`, `gcs`, `azure`, `r2`, `http`.

**Listing and dropping secrets:**
```sql
FROM duckdb_secrets();          -- inspect stored secrets
DROP SECRET my_s3_prod;
```

Secrets stored in a file-backed database persist to disk. For in-memory sessions, secrets last only for the connection lifetime.

> [!warning] Secrets stored in a `.duckdb` file are visible to anyone with read access to that file. Use the `TEMPORARY` keyword for secrets that should not persist to disk: `CREATE TEMPORARY SECRET ...`.

@feynman

Like a password manager integrated into the database — credentials are stored once and retrieved by name, rather than pasted into every script that needs them.
