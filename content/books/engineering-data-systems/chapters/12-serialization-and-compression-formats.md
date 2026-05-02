@chapter
id: eds-ch12-serialization-and-compression-formats
order: 12
title: Serialization and Compression Formats
summary: The byte-level details of how data is encoded, compressed, and stored. Most data engineers can stay productive without this — but the ones who know it debug faster and design better.

@card
id: eds-ch12-c001
order: 1
title: Why Format Matters Underneath The Abstraction
teaser: You usually think in tables and queries, not in bytes on disk. But every storage choice rests on a serialization format with specific cost, performance, and compatibility trade-offs.

@explanation

The format your data lives in dictates:

- **Storage cost** — JSON vs Parquet for the same data is often a 5-10× difference.
- **Query speed** — column-oriented formats let queries skip irrelevant columns; row-oriented formats force full reads.
- **Schema evolution** — some formats handle adding/removing fields gracefully; others require regeneration.
- **Tool compatibility** — every engine reads Parquet; not every engine reads ORC; very few read Avro natively.
- **Streaming vs batch fit** — Avro's per-record framing makes it good for streams; Parquet's columnar structure makes it bad.
- **Compression effectiveness** — column-oriented formats compress dramatically better than row-oriented.

For most day-to-day data engineering, the choice is "Parquet for analytical storage, Avro for streaming records, JSON for human-debuggable transit." Knowing why those defaults exist — and when to deviate — is the substance of this appendix.

> [!info] Data engineers who can't explain why Parquet beats CSV at scale tend to have warehouse bills they can't explain either.

@feynman

Same as understanding file formats in software — you can write apps without it, but debugging is much harder when you don't.

@card
id: eds-ch12-c002
order: 2
title: Row-Oriented Versus Column-Oriented Storage
teaser: The most fundamental design choice in data formats. Determines what's fast, what's slow, and what's affordable to query.

@explanation

**Row-oriented.** All values for one row stored contiguously.

```
Row 1: [name=Ada,    age=37, city=Austin]
Row 2: [name=Linus,  age=54, city=Helsinki]
Row 3: [name=Grace,  age=42, city=NYC]
```

Reading row 1 means reading one chunk: name + age + city together. Optimal for "give me everything about row 1" — the OLTP workload.

**Column-oriented.** All values for one column stored contiguously.

```
Names:   [Ada, Linus, Grace, ...]
Ages:    [37, 54, 42, ...]
Cities:  [Austin, Helsinki, NYC, ...]
```

Reading "all names" means reading one contiguous chunk. Optimal for "compute average age" — analytical workloads scanning many rows but few columns.

Implications:

- **Compression** — column storage compresses dramatically better. The `Cities` column has many repeated values; the row stream interleaves cities with names and ages.
- **Skipping** — analytical queries can read only the columns they need. Row formats force reading everything.
- **Update cost** — row storage handles single-row inserts cleanly. Column storage prefers batch writes.

The split:

- **Row-oriented formats** — Avro, JSON, CSV (ish), protobuf. Used in OLTP, streaming, RPC.
- **Column-oriented formats** — Parquet, ORC, Arrow (in-memory). Used in analytics, data lakes.

> [!info] If your warehouse is built on row-oriented storage, you're paying 10-50× more for analytical queries than you should. The fix is migrating to columnar, not tuning queries.

@feynman

Same trade-off as struct-of-arrays vs array-of-structs in low-level programming. Choose the layout matching how you'll iterate.

@card
id: eds-ch12-c003
order: 3
title: Parquet — The Columnar Default
teaser: Parquet has become the de facto standard for analytical data. Knowing its structure explains why it's so much faster than CSV at scale.

@explanation

A Parquet file is structured as:

- **File** — top-level container.
- **Row groups** — subsets of rows (typically 100k-1M each), the unit of parallelism.
- **Column chunks** — within each row group, one chunk per column. Each is independently compressed and encoded.
- **Pages** — within column chunks, smaller units (typically 1MB) that are individually encoded.
- **Footer** — metadata: schema, row group offsets, statistics for each column chunk (min, max, null count).

Why this matters:

- **Predicate pushdown.** A query `WHERE date > '2026-01-01'` reads the footer first, skips row groups whose date column max is below the threshold. Only relevant row groups are read from disk.
- **Column pruning.** A query `SELECT name FROM users` reads only the name column chunks. The rest stays on disk.
- **Parallelism.** Different row groups can be read by different threads or workers.
- **Per-column encoding.** Strings dictionary-encoded; integers run-length-encoded; floats bit-packed. Each column gets the encoding that compresses it best.

Statistics in the footer make the difference. A 10TB Parquet table with good column statistics often serves analytical queries reading just GB of actual data.

> [!tip] When designing Parquet layouts, sort by the columns most often filtered. Sorting concentrates value ranges in fewer row groups, making predicate pushdown maximally effective.

@feynman

Same idea as a book index — read the index first, jump to the relevant pages, ignore everything else.

@card
id: eds-ch12-c004
order: 4
title: ORC, Avro, And Other Formats
teaser: Beyond Parquet, several other formats serve specific niches. Knowing which fits which use case prevents wasted effort.

@explanation

**ORC (Optimized Row Columnar).** Columnar like Parquet; originated in the Hortonworks/Hive ecosystem. Similar performance characteristics. Less common in cloud-native workflows; still seen in Hadoop-heritage stacks.

**Avro.** Row-oriented binary format with embedded schema. Each record carries enough metadata to deserialize. Designed for streaming and RPC. The default for Kafka payloads in many setups, often with a schema registry to avoid embedding the full schema in every message.

Wins: schema evolution is well-defined; RPC-friendly; per-record processing.
Losses: not analytical-query-friendly; no column pruning.

**Protobuf (Protocol Buffers).** Google's RPC serialization format. Highly compact, schema-defined, fast serialize/deserialize. Used heavily in microservices and Google-flavored systems.

Wins: smallest wire format; strongly typed; great cross-language support.
Losses: schema lives outside the data (in `.proto` files); not human-readable; not analytical-friendly.

**Apache Arrow.** In-memory columnar format. Not for storage; for analytical processing. Many engines (DuckDB, Pandas 2.x, Polars, Spark via Arrow) use it as their internal representation. Eliminates serialization cost between Arrow-aware tools.

**JSON / JSONL.** Text-based; schemaless; ubiquitous. Fine for APIs, configs, small datasets, debugging. Terrible for analytical storage at scale.

**CSV.** Plain text rows. Fine for human-readable export. Awful for almost everything else — no types, no schema, ambiguous parsing rules, terrible compression.

> [!info] Modern stacks use a small mix: Parquet at rest, Avro in streams, JSON for APIs, Arrow internally. CSV only for humans.

@feynman

Same toolbox as encodings in software — different tools for different jobs; misuse is a common source of pain.

@card
id: eds-ch12-c005
order: 5
title: Compression Algorithms — The Speed-Versus-Ratio Trade
teaser: All compression sits on a curve from "fast and modest ratio" to "slow but tight." Picking right depends on whether your bottleneck is CPU, disk, or network.

@explanation

The major algorithms in data systems:

- **Snappy.** Google's; very fast compress/decompress; modest ratio (~1.5-2.5×). Default for many engines because decompression doesn't slow queries.
- **LZ4.** Even faster than Snappy; similar ratio. Good when CPU is the bottleneck.
- **Gzip.** Older; slow compress, decent ratio (3-4×). Common for archive data; less common for hot tables.
- **Zstd.** Modern; tunable level (1-22). At default levels, faster than gzip with better ratio. Often the best general-purpose choice today.
- **Brotli.** Designed for web; high ratio, slow compress. Common for static content delivery.
- **LZMA / XZ.** Highest ratios; very slow compress; moderate decompress. Used for cold archive.

Where each fits in data systems:

- **Hot analytical tables** — Snappy or Zstd at low level. Decompression speed matters more than tightest ratio.
- **Streaming data in transit** — Snappy or LZ4. Speed dominates.
- **Cold archive in object storage** — Zstd at high level or Gzip. Ratio matters; access is rare.
- **Backup files** — Gzip or Zstd. Decent ratio, broadly compatible.

A common pattern: Zstd has been quietly displacing Gzip and even Snappy in many workloads — better ratio than Snappy, much faster than Gzip at default settings, tunable when needed.

> [!info] Most analytical workloads are I/O-bound, not CPU-bound. Spending CPU on better compression to save I/O is usually a net win — which is why Zstd and Snappy beat "no compression" for almost everything.

@feynman

Same trade-off as image compression — JPEG vs PNG vs WebP. Different sweet spots for different content and access patterns.

@card
id: eds-ch12-c006
order: 6
title: Column Encodings Within Parquet
teaser: Parquet doesn't just compress columns — it encodes them per-column based on what's most efficient for that data shape.

@explanation

Inside a Parquet column chunk, several encodings combine before final compression:

- **Plain encoding.** Just the raw values, one after another. Used for high-cardinality columns where nothing smarter helps.
- **Dictionary encoding.** Build a dictionary of unique values; replace each occurrence with a small integer index. Optimal for low-cardinality columns (country codes, status enums, repeated strings).
- **Run-length encoding (RLE).** When a column has runs of identical values, encode as `(value, count)` pairs. `[US, US, US, US, UK]` becomes `[(US, 4), (UK, 1)]`. Often combined with dictionary encoding.
- **Bit packing.** When integer values fit in fewer bits than a full int, pack them. A column of values 0-7 only needs 3 bits each.
- **Delta encoding.** For sorted or near-sorted numeric columns, store the difference from the previous value. `[1000, 1001, 1003, 1004]` → `[1000, 1, 2, 1]`.

Then on top of all that, the encoded column chunk is compressed (Snappy, Zstd, etc.).

The result: a column of 1B repeated country codes might land at a few KB on disk. The Parquet writer chooses encoding per column automatically; you usually don't tune it manually.

> [!info] Compression ratio of 10-100× on well-shaped analytical data is normal. If your Parquet files are barely smaller than the source CSV, your data has high cardinality everywhere or your writer is misconfigured.

@feynman

Same magic as compressing log files — repeated `INFO` prefixes, timestamps that monotonically increase, mostly-the-same source patterns. The compression algorithm finds the redundancy.

@card
id: eds-ch12-c007
order: 7
title: Schema Evolution In Practice
teaser: Different formats handle schema changes very differently. Picking a format that supports the changes you'll need saves expensive migrations later.

@explanation

What schema evolution scenarios you'll face:

- **Add a column.** Should be safe; readers ignore unknown columns or get null for missing ones.
- **Drop a column.** Old data still has the column; new data doesn't.
- **Rename a column.** Treat as drop + add; old data has the old name.
- **Change a column's type.** Often unsafe; readers expect specific types.

How major formats handle these:

**Parquet:**
- Schema lives in the file footer; readers detect and adapt.
- Adding columns is safe; readers get nulls for old files missing the column.
- Renaming is harder — newer Iceberg/Delta layers (column IDs) add support; raw Parquet doesn't track renames.
- Type changes generally require rewriting affected files.

**Avro:**
- Schema-on-write embedded in each file (or referenced from a schema registry).
- Reader and writer schemas can differ; resolution rules handle adds, drops, renames (with aliases).
- Type changes have well-defined compatibility rules.
- Strongest schema-evolution story of the major formats.

**Iceberg / Delta:**
- Maintain table metadata that handles evolution at a table level above Parquet.
- Column IDs decouple field identity from name — renames work cleanly.
- Hidden partitioning lets you change partition strategy without rewriting data.

**JSON / JSONL:**
- No enforced schema; evolution is "just write the new shape."
- Readers must handle missing or unexpected fields.
- Maximum flexibility, maximum operational burden.

> [!tip] If you expect schema evolution (you will), prefer Iceberg or Delta over raw Parquet. The metadata layer is what makes evolution survivable.

@feynman

Same problem as API versioning — backward compatibility is achievable with discipline, painful without.

@card
id: eds-ch12-c008
order: 8
title: Format Choices For Streaming Data
teaser: Streaming workflows have different format requirements from analytical storage. Picking the right one prevents the most common streaming pain.

@explanation

Streaming systems handle data record-by-record (or in small micro-batches). What this needs from a format:

- **Per-record framing.** Reader can decode individual records without reading the whole file.
- **Compact encoding.** Network bandwidth and broker storage matter.
- **Schema awareness.** Producers and consumers must agree on shape; ideally enforced.
- **Forward/backward compatibility.** Producers and consumers deploy independently; messages from old producers must remain readable.

Formats that fit:

- **Avro.** Default for Kafka in many setups. Per-record framing; embedded schema or schema-registry reference; mature compatibility model.
- **Protobuf.** Compact, fast, well-supported. Schema lives in `.proto` files; requires distribution to all producers/consumers.
- **JSON.** Easy for debugging, no compatibility tooling, larger wire size. Common for early-stage Kafka usage; teams usually migrate away as scale grows.

Schema registry adds:

- **Single source of truth** for schemas — produce against a registered schema; consumers fetch the schema by ID embedded in each message.
- **Compatibility enforcement** — incompatible schema changes are rejected at registration time.
- **Reduced message size** — messages carry a 5-byte schema ID instead of the full schema.

The trap to avoid: starting with JSON-on-Kafka for convenience and ending up with a coordination problem when the team grows. Schema registry + Avro from the start is more discipline; less pain later.

> [!info] If your Kafka setup is more than 10 producers / 10 consumers, you need a schema registry. Without one, every breaking change is a coordinated production incident.

@feynman

Same lesson as REST APIs — formal schema contracts (OpenAPI, JSON Schema) save you from coordination problems that grow with team size.
