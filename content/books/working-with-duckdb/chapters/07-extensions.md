@chapter
id: wdd-ch07-extensions
order: 7
title: Extensions
summary: DuckDB's extension system turns a focused SQL engine into a platform — from spatial queries to cloud storage access to Excel reading.

@card
id: wdd-ch07-c001
order: 1
title: The Extension System Overview
teaser: DuckDB ships lean and grows on demand — extensions add capabilities without bloating the core binary or violating the zero-dependency philosophy.

@explanation

DuckDB's core library has no external dependencies and a narrow feature surface by design. Extensions fill in everything beyond basic SQL: cloud storage access, geographic queries, full-text search, file format readers, and more. You load only what your workload needs.

How extensions work:

- **Auto-install:** When you run a query that requires an extension (e.g., `SELECT * FROM read_parquet('s3://...')`), DuckDB can automatically install and load the required extension if `autoinstall_known_extensions` is enabled.
- **Manual install:** `INSTALL extension_name;` downloads the extension binary from the repository. `LOAD extension_name;` activates it in the current session.
- **Persistence:** Installed extensions persist across sessions. Loaded extensions must be re-loaded each session unless you configure autoload.

Where extensions come from:

- **Core extensions:** Bundled with the DuckDB binary — `parquet`, `json`, `icu`. Always available, zero install.
- **Official extensions:** Distributed by the DuckDB team from `extensions.duckdb.org` — `httpfs`, `spatial`, `fts`, `iceberg`, `delta`, `excel`, `aws`, `azure`.
- **Community extensions:** Third-party, hosted in the community registry. Require explicit trust acknowledgment before install.

```sql
-- Install and load an official extension
INSTALL httpfs;
LOAD httpfs;

-- Check what's loaded
SELECT * FROM duckdb_extensions() WHERE loaded = true;
```

> [!info] Starting with DuckDB 1.1, autoload is enabled by default for known official extensions. A query that needs `httpfs` will trigger install automatically in interactive sessions. In production scripts, prefer explicit `INSTALL` + `LOAD` calls for reproducibility.

@feynman

Like a language's standard library vs its package manager — the core ships with essentials, and the registry provides the rest without requiring you to vendor everything upfront.

@card
id: wdd-ch07-c002
order: 2
title: The httpfs Extension
teaser: httpfs is the foundation for all remote data access in DuckDB — it adds HTTP, S3, GCS, and Azure Blob support to any file-reading function.

@explanation

The `httpfs` extension makes DuckDB's file-reading functions location-agnostic. Once loaded, functions like `read_parquet()`, `read_csv()`, and `read_json()` accept remote URLs in addition to local paths.

Supported URL schemes:

- `https://` — public HTTP/HTTPS URLs
- `s3://bucket/key` — AWS S3 (and S3-compatible stores like MinIO, Cloudflare R2)
- `gs://bucket/key` — Google Cloud Storage
- `az://container/blob` — Azure Blob Storage
- `hf://` — Hugging Face dataset hub (added in DuckDB 1.1)

```sql
LOAD httpfs;

-- Public HTTPS file
SELECT COUNT(*) FROM read_parquet('https://example.com/data/sales.parquet');

-- S3 (credentials from environment or aws extension)
SELECT * FROM read_csv('s3://my-bucket/logs/2026-01/*.csv');

-- Glob over S3 prefix
SELECT month, SUM(revenue)
FROM read_parquet('s3://my-bucket/sales/year=2025/month=*/*.parquet')
GROUP BY month;
```

httpfs respects:

- **AWS credential chain:** environment variables, `~/.aws/credentials`, instance metadata — automatically when the `aws` extension is also loaded.
- **Explicit credentials:** set via `SET s3_access_key_id`, `SET s3_secret_access_key`, `SET s3_region`.
- **HTTP proxy settings** via standard `http_proxy`/`https_proxy` environment variables.

> [!tip] httpfs streams data rather than downloading files in full before querying. A Parquet file with row group metadata on S3 allows DuckDB to fetch only the row groups that satisfy a filter predicate — significantly reducing egress costs on large datasets.

@feynman

Like a filesystem driver that teaches your application to treat S3 URLs the same way it treats local file paths — you get the same API, different storage backend.

@card
id: wdd-ch07-c003
order: 3
title: The Iceberg Extension
teaser: DuckDB reads Apache Iceberg tables natively as of 1.1 — no Spark, no JVM, just a SQL scan over a catalog-registered or path-based Iceberg table.

@explanation

Apache Iceberg is an open table format that adds schema evolution, time travel, partition pruning, and ACID transactions on top of Parquet files. DuckDB's `iceberg` extension reads Iceberg tables directly.

As of DuckDB 1.1 (late 2024), the `iceberg` extension supports:

- **Direct path reads:** Point at the table's metadata directory on local disk or S3.
- **REST catalog integration:** Connect to a Polaris, Nessie, or AWS Glue catalog via the Iceberg REST Catalog spec.
- **Snapshot time travel:** Query a table as it existed at a specific snapshot ID or timestamp.
- **Partition pruning:** The query planner respects Iceberg partition specs to avoid scanning unnecessary files.

```sql
INSTALL iceberg;
LOAD iceberg;

-- Read from a local or S3 path
SELECT * FROM iceberg_scan('s3://my-lakehouse/warehouse/sales/');

-- Time travel to a specific snapshot
SELECT COUNT(*) FROM iceberg_scan(
  's3://my-lakehouse/warehouse/sales/',
  snapshot_id = 3821593847302
);

-- Attach a REST catalog (Polaris, Nessie, Glue)
ATTACH 'https://catalog.example.com/v1' AS cat (
  TYPE iceberg,
  CLIENT_ID 'my-client-id',
  CLIENT_SECRET 'my-secret'
);
SELECT * FROM cat.prod.sales LIMIT 100;
```

Current limitations:

- Write support (INSERT, UPDATE, DELETE into Iceberg tables) is not yet available as of early 2026 — reads only.
- V1 and V2 table specs are supported; V3 (in-progress at the Iceberg project) is partial.

> [!warning] For production Iceberg reads, always pin your DuckDB version. Iceberg's metadata parsing improvements between DuckDB patch versions can change query plans and performance characteristics in ways that matter for large tables.

@feynman

Like a database that can mount an NFS share directly — you do not need to import the data; you query it in place through a standard protocol.

@card
id: wdd-ch07-c004
order: 4
title: The Delta Extension
teaser: DuckDB reads Delta Lake tables via the delta extension, using the official delta-kernel-rs library — the same Rust kernel that powers Spark's Delta reader.

@explanation

Delta Lake is the other dominant open table format alongside Iceberg. DuckDB's `delta` extension uses `delta-kernel-rs`, the official Rust-based Delta Lake kernel contributed by Databricks, ensuring compatibility with Delta protocol versions written by Spark, Databricks, and other engines.

```sql
INSTALL delta;
LOAD delta;

-- Read a Delta table from local path
SELECT * FROM delta_scan('/path/to/delta-table/');

-- Read from S3 (requires httpfs loaded first)
LOAD httpfs;
SELECT region, SUM(amount)
FROM delta_scan('s3://my-bucket/delta/transactions/')
GROUP BY region
ORDER BY SUM(amount) DESC;
```

What the Delta extension supports:

- **Delta protocol V2 and V3:** Supports deletion vectors, column mapping, and V3 table features available in Databricks Unity Catalog tables.
- **Partition pruning:** Respects Delta partition columns to skip files.
- **Change data feed:** Reading Delta's Change Data Feed (CDF) to extract row-level change history.
- **Schema evolution:** Handles tables where columns have been added or dropped over time.

What it does not support:

- Write operations — reads only as of early 2026.
- Deletion vector application on very old Delta tables written with protocol V1 only.

> [!info] If your data team uses Databricks and you need to query their tables from a Python pipeline without a Spark dependency, `delta_scan()` over S3 is the practical solution. The delta-kernel-rs backing means protocol compatibility is maintained by the same team that writes the Delta spec.

@feynman

Like a read-only mount of a filesystem format your OS did not natively support — a compatible driver lets you access the files without converting them.

@card
id: wdd-ch07-c005
order: 5
title: The Spatial Extension
teaser: The spatial extension adds geometry types, dozens of ST_ functions, and the ability to read GeoJSON, Shapefiles, and GeoParquet directly into SQL queries.

@explanation

The `spatial` extension brings geographic and GIS capabilities to DuckDB. It wraps GDAL (for format reading) and GEOS/PROJ (for geometry operations) and exposes them through a standard SQL geometry type and `ST_` function API compatible with PostGIS conventions.

```sql
INSTALL spatial;
LOAD spatial;

-- Create a point geometry
SELECT ST_Point(37.7749, -122.4194) AS sf_location;

-- Distance between two points (in meters with EPSG:4326)
SELECT ST_Distance_Spheroid(
  ST_Point(-122.4194, 37.7749),
  ST_Point(-118.2437, 34.0522)
) / 1000 AS distance_km;

-- Read a GeoJSON file directly
SELECT name, ST_Area(geometry) AS area
FROM ST_Read('neighborhoods.geojson')
ORDER BY area DESC
LIMIT 10;

-- Spatial join — points within polygons
SELECT p.name, n.neighborhood
FROM points p, neighborhoods n
WHERE ST_Within(p.geometry, n.geometry);
```

Supported input formats (via GDAL):

- GeoJSON (`.geojson`, `.json`)
- Shapefile (`.shp`)
- GeoParquet (Parquet with WKB geometry column)
- FlatGeobuf (`.fgb`)
- GeoPackage (`.gpkg`)
- OpenStreetMap PBF (`.osm.pbf`) — read-only

Key function categories:

- **Constructors:** `ST_Point`, `ST_MakeLine`, `ST_GeomFromText`, `ST_GeomFromWKB`
- **Predicates:** `ST_Within`, `ST_Intersects`, `ST_Contains`, `ST_Touches`
- **Measurements:** `ST_Area`, `ST_Length`, `ST_Distance`, `ST_Distance_Spheroid`
- **Transformations:** `ST_Buffer`, `ST_Centroid`, `ST_Simplify`, `ST_Union`

> [!tip] For city-scale spatial analysis — joining user locations to neighborhood polygons, computing drive-time buffers, aggregating event counts by region — the spatial extension handles workloads that would otherwise require PostGIS or a dedicated GIS platform.

@feynman

Like PostGIS but as a library — the same ST_ function vocabulary you already know, loaded on demand without running a PostgreSQL server.

@card
id: wdd-ch07-c006
order: 6
title: The Full-Text Search Extension
teaser: The FTS extension adds inverted index-based full-text search to DuckDB tables — useful for document search on datasets too large to scan with LIKE but too small to justify Elasticsearch.

@explanation

The `fts` (full-text search) extension provides BM25-ranked inverted index search for text columns. It sits in the gap between `LIKE '%keyword%'` (no index, full scan) and a dedicated search engine like Elasticsearch (infrastructure overhead).

```sql
INSTALL fts;
LOAD fts;

-- Create a table and build an FTS index
CREATE TABLE articles (id INTEGER, title TEXT, body TEXT);
INSERT INTO articles VALUES
  (1, 'DuckDB Extensions', 'The extension system allows modular capability loading...'),
  (2, 'Query Optimization', 'DuckDB uses a dynamic programming join order optimizer...');

PRAGMA create_fts_index('articles', 'id', 'title', 'body');

-- Search with BM25 ranking
SELECT id, title, fts_main_articles.match_bm25(id, 'extension loading') AS score
FROM articles
WHERE score IS NOT NULL
ORDER BY score DESC;
```

How it works:

- `PRAGMA create_fts_index(table, id_column, text_columns...)` builds an inverted index stored as auxiliary DuckDB tables alongside the original.
- The `match_bm25()` function scores documents against a query using BM25 relevance ranking.
- Indexes must be rebuilt manually after INSERT/UPDATE/DELETE — there is no incremental update.

Limitations worth knowing:

- No support for fuzzy matching, stemming (English only), or phonetic similarity.
- Index rebuild is required after any data change — not suitable for high-write tables.
- Not competitive with dedicated search engines for very large text corpora (millions of documents, complex query syntax).

> [!warning] FTS indexes are stored as plain DuckDB tables. They are not transactionally linked to the source table — if you insert new rows without rebuilding the index, new documents are invisible to search. Always rebuild after bulk loads.

@feynman

Like adding a search index to a SQLite table — useful for the "small dataset, no infrastructure" tier, with the same caveats about manual rebuild that SQLite's FTS5 has.

@card
id: wdd-ch07-c007
order: 7
title: The Excel Extension
teaser: The Excel extension adds `read_xlsx()`, letting you query `.xlsx` files directly with SQL — no conversion step, no pandas.read_excel() intermediary.

@explanation

The `excel` extension (also referred to as `spatial` in some older documentation — they share a binary) provides `read_xlsx()` for reading Microsoft Excel files directly into DuckDB queries.

```sql
INSTALL excel;
LOAD excel;

-- Read the first sheet
SELECT * FROM read_xlsx('report.xlsx');

-- Read a specific named sheet
SELECT * FROM read_xlsx('report.xlsx', sheet = 'Q4 Sales');

-- Read a specific sheet by index (0-based)
SELECT * FROM read_xlsx('report.xlsx', sheet = 2);

-- Specify that the first row is a header
SELECT department, SUM(budget)
FROM read_xlsx('financials.xlsx', header = true)
GROUP BY department;

-- Infer types or treat all as strings
SELECT * FROM read_xlsx('messy_data.xlsx', all_varchar = true);
```

What `read_xlsx()` handles:

- String, integer, float, date, datetime, and boolean cell types.
- Named and unnamed sheets.
- Merged cell detection (merged cells return the value in the top-left cell; other cells in the range are NULL).
- Password-protected files — not supported; will error.

Common use case — finance and ops teams often deliver data in `.xlsx` files. Instead of writing a conversion script, query the file directly:

```sql
-- Join an Excel report against a database table
SELECT e.region, e.target, SUM(o.revenue) AS actual
FROM read_xlsx('targets.xlsx', header = true) e
JOIN orders o ON e.region = o.region
GROUP BY e.region, e.target;
```

> [!info] `read_xlsx()` reads the entire sheet into memory before returning results — it does not stream. For very large Excel files (100K+ rows), exporting to CSV and using `read_csv()` will be faster and use less memory.

@feynman

Like a file format driver — teaching your SQL engine to open `.xlsx` the same way it opens `.csv`, without an intermediate conversion.

@card
id: wdd-ch07-c008
order: 8
title: The JSON Extension
teaser: The JSON extension promotes JSON from a string column to a first-class queryable type — path extraction, nested array unnesting, and auto-schema inference all included.

@explanation

DuckDB's core includes basic JSON support, but the `json` extension (bundled as a core extension in 1.1+, so often pre-loaded) adds the full JSON path query API and format readers.

```sql
-- Extract a field from a JSON string column
SELECT json_extract(payload, '$.user.id') AS user_id
FROM events;

-- Arrow-style shorthand
SELECT payload -> '$.user.id' AS user_id,
       payload ->> '$.user.name' AS user_name  -- returns text, not JSON
FROM events;

-- Read a JSON lines file
SELECT * FROM read_json('events.jsonl');

-- Read a JSON array file with auto-schema
SELECT * FROM read_json('records.json', auto_detect = true);

-- Unnest a nested array
SELECT id, UNNEST(json_extract(payload, '$.tags')) AS tag
FROM articles;
```

Key functions:

- `json_extract(col, path)` — extract a value at a JSONPath; returns JSON type.
- `json_extract_string(col, path)` — extract and cast to VARCHAR.
- `->` / `->>` — shorthand operators for extract/extract-as-text.
- `json_array_length(col)` — length of a JSON array.
- `json_keys(col)` — keys of a JSON object as a VARCHAR[].
- `json_valid(col)` — returns true/false; useful for data quality checks.

Reading JSON files:

- `read_json()` handles JSON lines (`.jsonl`), JSON arrays, and newline-delimited JSON.
- `auto_detect = true` samples the file and infers column types — equivalent to Parquet's schema inference.
- Nested objects become STRUCT columns; arrays become LIST columns.

> [!tip] For JSON columns stored in a Parquet file or a DuckDB table, `->` and `->>` operators are usually fast enough for exploratory queries. For production pipelines that repeatedly extract the same nested field, materialize it into a dedicated column at ingest time — repeated JSON path evaluation on large tables adds up.

@feynman

Like jq embedded in SQL — the path query syntax is similar, but the result plugs directly into JOINs, GROUP BYs, and the rest of the query planner.

@card
id: wdd-ch07-c009
order: 9
title: The AWS Extension
teaser: The AWS extension wires DuckDB into the AWS credential chain — profiles, IAM roles, and SSO tokens all work without hardcoding keys.

@explanation

The `aws` extension plugs the AWS SDK credential provider chain into DuckDB's S3 client. Without it, you must set S3 credentials manually. With it, DuckDB resolves credentials the same way the AWS CLI and boto3 do.

```sql
INSTALL aws;
LOAD aws;

-- Pull credentials from the default credential chain
-- (~/.aws/credentials, environment variables, EC2 instance metadata, ECS task role)
CALL load_aws_credentials();

-- Now S3 queries work without explicit key configuration
SELECT * FROM read_parquet('s3://my-private-bucket/data/*.parquet');

-- Use a specific named profile
CALL load_aws_credentials('my-profile');

-- Assume a role before querying
CALL load_aws_credentials('arn:aws:iam::123456789:role/data-reader');
```

The credential provider order (standard AWS SDK chain):

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
2. `~/.aws/credentials` file (default profile or named profile)
3. AWS SSO (`aws sso login` tokens)
4. EC2 instance metadata service (IMDS) — for EC2/ECS/Lambda execution environments
5. ECS task role

Why this matters:

- In a Lambda or ECS container, `CALL load_aws_credentials()` picks up the task role automatically — no key management.
- In CI, it picks up the environment variables set by GitHub Actions OIDC or similar systems.
- Locally, it respects `AWS_PROFILE` so developers with multi-account setups use the right credentials without configuration.

> [!warning] Do not hardcode AWS keys in SQL scripts or notebook cells. Use `load_aws_credentials()` with the credential chain instead — it is safer and works across all execution environments without modification.

@feynman

Like configuring boto3 with `boto3.Session()` — you delegate credential resolution to the SDK's standard chain rather than managing keys yourself.

@card
id: wdd-ch07-c010
order: 10
title: The Azure Extension
teaser: The Azure extension provides the same credential-chain convenience for Azure Blob Storage and ADLS Gen2 that the AWS extension provides for S3.

@explanation

The `azure` extension adds native Azure Blob Storage and Azure Data Lake Storage Gen2 (ADLS) access using the Azure SDK credential providers.

```sql
INSTALL azure;
LOAD azure;

-- Use the default Azure credential chain
-- (environment variables → managed identity → Azure CLI → interactive browser)
SET azure_transport_option_type = 'curl';

-- Connect using a connection string
SET azure_storage_connection_string = 'DefaultEndpointsProtocol=https;AccountName=...';

-- Or use an account + SAS token
SET azure_account_name = 'mystorageaccount';
SET azure_sas_token = 'sv=2021-12...';

-- Query Azure Blob Storage
SELECT * FROM read_parquet('azure://mycontainer/data/2026/*.parquet');

-- Query ADLS Gen2 (same syntax, hierarchical namespace)
SELECT * FROM read_csv('abfss://mycontainer@mystorageaccount.dfs.core.windows.net/logs/');
```

Supported URL schemes:

- `azure://container/path` — shorthand using the configured account
- `abfss://container@account.dfs.core.windows.net/path` — full ADLS Gen2 URL

Credential options:

- **Connection string:** Simple for local development and testing.
- **Managed identity:** On Azure VMs, AKS pods, or Azure Functions, a managed identity is picked up automatically — no stored secrets.
- **Azure CLI credentials:** After `az login`, DuckDB picks up the CLI's cached token via `azure_transport_option_type = 'curl'` combined with the DefaultAzureCredential chain.
- **Service principal:** Set via environment variables (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`).

> [!info] The Azure extension uses the Azure SDK's `DefaultAzureCredential` under the hood — the same credential resolution order used by the Azure SDK for Python, .NET, and Java. If your application already authenticates via managed identity, DuckDB will too.

@feynman

Like the AWS extension but for Azure — the SDK's credential chain handles environment, managed identity, and CLI login so you do not wire credentials manually.

@card
id: wdd-ch07-c011
order: 11
title: Community Extensions
teaser: Community extensions extend DuckDB beyond what the core team ships — the extension repository, trust levels, and discovery workflow are worth knowing before you need one.

@explanation

Beyond official extensions, DuckDB has a growing community extension registry. Any developer can publish an extension to the community repository; users install them with an explicit trust acknowledgment.

**Finding extensions:**

- Browse `https://community-extensions.duckdb.org/` — the official community extension index.
- Search via DuckDB's SQL interface:

```sql
-- List all available extensions (official + community)
SELECT * FROM duckdb_extensions();

-- Filter for uninstalled community extensions
SELECT extension_name, description, version
FROM duckdb_extensions()
WHERE installed = false AND extension_source = 'community';
```

**Installing a community extension:**

```sql
-- Requires explicit acknowledgment of unsigned/community status
SET custom_extension_repository = 'community';
INSTALL chsql FROM community;
LOAD chsql;
```

**Trust levels:**

- **Core extensions:** Bundled in the DuckDB binary. Fully trusted, signed by the DuckDB team.
- **Official extensions:** Distributed from `extensions.duckdb.org`, signed by the DuckDB team. Installed with `INSTALL name;`.
- **Community extensions:** Distributed from `community-extensions.duckdb.org`, signed by the extension author's key (not the DuckDB team). Require `FROM community` suffix.
- **Unsigned extensions:** Self-built or untrusted binaries. Require `FORCE INSTALL` and `allow_unsigned_extensions = true`. Only appropriate in controlled environments.

Notable community extensions in 2026:

- `chsql` — ClickHouse SQL dialect compatibility layer.
- `lindel` — Hilbert curve space-filling index for spatial locality.
- `prql` — PRQL language support as an alternative query syntax.
- `duckpgq` — Property graph query extension (openCypher-compatible).

> [!warning] Community extensions have not been audited by the DuckDB team. Review the extension source code and trust the author before installing in production environments with access to sensitive data.

@feynman

Like npm packages vs Node's built-in modules — the registry is rich and community-maintained, but you take on responsibility for vetting what you install.

@card
id: wdd-ch07-c012
order: 12
title: Writing a Custom Extension
teaser: Custom extensions are C++ shared libraries that hook into DuckDB's extension API — the investment pays off when you need a capability unavailable in any existing extension.

@explanation

DuckDB's extension API is a C++ interface that allows you to register custom functions, table functions, file system implementations, and parser extensions. Since DuckDB 1.0 stabilized the C extension ABI, custom extensions can be compiled once and loaded across DuckDB 1.x versions.

**When to invest in a custom extension:**

- You need to read a proprietary file format natively (e.g., your company's internal binary format).
- You want to expose a domain-specific function that DuckDB does not provide (e.g., a custom hash function, a proprietary encoding/decoding operation).
- You are building a DuckDB distribution (like MotherDuck) and need to add capabilities at the engine level.
- You need a custom virtual file system (e.g., reading from an internal blob store with non-standard auth).

**The basic structure:**

```cpp
#include "duckdb.hpp"
using namespace duckdb;

// Your custom scalar function
static void MyHashFunction(DataChunk &args, ExpressionState &state, Vector &result) {
    auto &input = args.data[0];
    UnaryExecutor::Execute<string_t, string_t>(
        input, result, args.size(),
        [&](string_t val) {
            // compute and return hash
            return StringVector::AddString(result, custom_hash(val.GetString()));
        }
    );
}

// Extension entry point — called by DuckDB on LOAD
extern "C" {
DUCKDB_EXTENSION_API void my_extension_init(duckdb::DatabaseInstance &db) {
    auto &catalog = duckdb::Catalog::GetSystemCatalog(db);
    CreateScalarFunctionInfo info(
        ScalarFunction("my_hash", {LogicalType::VARCHAR}, LogicalType::VARCHAR, MyHashFunction)
    );
    catalog.CreateFunction(nullptr, info);
}

DUCKDB_EXTENSION_API const char *my_extension_version() {
    return duckdb::DuckDB::LibraryVersion();
}
}
```

**Build and load:**

```bash
# Use the DuckDB extension template repository as a starting point
git clone https://github.com/duckdb/extension-template my-extension
cd my-extension && make

# Load the built extension
duckdb -c "LOAD '/path/to/my_extension.duckdb_extension'; SELECT my_hash('hello');"
```

Getting started is easier with the official `extension-template` repository on GitHub — it handles the CMake setup, CI configuration, and versioning scaffolding.

> [!tip] Before writing a custom extension, check whether a table macro or a Python UDF achieves the same goal. Python UDFs (available via the DuckDB Python API) can call arbitrary Python code and are far easier to write and maintain than C++ extensions for most use cases.

@feynman

Like writing a native Node.js addon with N-API — you drop down to C++ when the scripting layer cannot express the performance or capability you need, and you use the stable ABI to avoid recompiling on every engine update.
