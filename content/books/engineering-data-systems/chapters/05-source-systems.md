@chapter
id: eds-ch05-source-systems
order: 5
title: Source Systems
summary: Where data is born, the shapes it arrives in, and how to work with the systems and teams that produce it without becoming their support hotline.

@card
id: eds-ch05-c001
order: 1
title: The Source Is The Stage You Don't Own
teaser: Your pipelines start with someone else's data. The systems that produce it weren't designed for you, which makes them the most reliable source of unpleasant surprises.

@explanation

Source systems generate the data your pipelines depend on. They include:

- **Operational databases** — Postgres, MySQL, Oracle, MongoDB powering production applications.
- **Application logs** — structured or unstructured streams of what apps are doing.
- **Event streams** — Kafka, Kinesis, Pub/Sub topics carrying business events.
- **APIs** — third-party services like Stripe, Salesforce, Zendesk.
- **Files** — CSVs dropped on SFTP, exports from analytics tools, partner files.
- **IoT / sensors** — telemetry from physical devices.
- **Spreadsheets** — yes, still, frequently the source of truth for parts of the business.

The unifying property: they exist for their own purposes, and you're a downstream consumer they didn't sign up to support. Their schemas evolve to serve their owning team's needs, not yours. Their availability and performance optimize for their primary workload, not yours. The data engineer's job at this stage is mostly about making peace with this asymmetry.

> [!info] If you can list every source system feeding your pipelines and the team that owns each, you're already ahead of most data teams. Most can't.

@feynman

Same as integrating with someone else's API — they didn't ship it for you, so they don't owe you stability.

@card
id: eds-ch05-c002
order: 2
title: Schemas — Where Structure Lives
teaser: Every source has a schema, even when it claims not to. The difference is whether the schema is enforced at write, at read, or by accident.

@explanation

Three philosophies for where schema enforcement lives:

- **Schema-on-write** — the storage system enforces structure when data is added. Postgres rejects rows missing required columns. Strict, predictable, friction at write time.
- **Schema-on-read** — data lands as-is; the consumer interprets structure when reading. JSON files in a lake; whoever queries them imposes shape. Flexible, fast to ingest, expensive to keep correct.
- **Schemaless** — no enforced structure at all. MongoDB documents, key-value blobs. Maximum flexibility, maximum operational risk.

The choice isn't binary in practice. Modern lakehouses (Iceberg, Delta) blur the line — they enforce schema like a warehouse but on lake-format files. Streaming systems often combine schema registries (Confluent Schema Registry) with otherwise-loose payloads.

The data engineer's reality: you'll deal with all three. Operational source systems are usually schema-on-write. Lakes you control are often schema-on-read. Third-party APIs are wherever they happen to be.

> [!warning] "Schemaless" rarely means no schema. It means the schema lives in everyone's head and drifts silently. The bills come due downstream.

@feynman

Same as type checking — strict at write, strict at read, or strict at runtime when something blows up. Pick where you want the cost.

@card
id: eds-ch05-c003
order: 3
title: Schema Evolution Is Inevitable
teaser: Source schemas change. Columns get added, renamed, deprecated. Pipelines that assume a fixed schema break in proportion to how much they assumed.

@explanation

Common schema-evolution events you'll face:

- **New column added** — usually safe; ignore it or pick it up.
- **Column renamed** — silent breakage; your code references the old name.
- **Column type changed** — values you parsed as int now arrive as string.
- **Column dropped** — your downstream queries return null where they used to return values.
- **Semantics changed** — the column still exists with the same name and type, but means something different now (a status enum gets a new value, an integer changes its meaning).

Defensive strategies:

- **Subscribe to upstream change processes.** Be in the loop on releases that touch source schemas.
- **Alert on schema drift.** Tools like Great Expectations, dbt tests, Monte Carlo can catch unexpected shape changes before consumers do.
- **Use schema registries** for streaming data. Producers register schemas; consumers fetch them; incompatible changes fail at the registry, not in production.
- **Build pipelines that fail loudly** when assumptions break, rather than silently producing wrong output.

The hardest evolutions are semantic changes — the schema looks the same, the values are slightly different. Only the application team knows; only diligent communication catches it.

> [!tip] When a downstream consumer reports "the numbers look weird" and the pipeline is green, your first hypothesis should be a semantic change in the source.

@feynman

Same as API versioning — backward compatibility is a contract you have to maintain on purpose, not a default state.

@card
id: eds-ch05-c004
order: 4
title: Operational Databases As Sources
teaser: Most source data still lives in production OLTP databases. Reading from them safely without hurting the application is a craft of its own.

@explanation

Production databases are the most common source. The constraints:

- **Don't impact application performance.** Long-running analytical queries can lock tables, exhaust connections, or evict working-set pages from cache.
- **Get a consistent snapshot.** Reading rows over many minutes risks seeing updates mid-stream.
- **Handle large tables.** Full-table scans on multi-billion-row tables don't fit normal HTTP timeouts.
- **Don't depend on internals.** The application team will refactor schema; your reads should not block their freedom to do so.

Approaches:

- **Read replicas.** Replicate the database; query the replica. Shifts the load off the primary but requires replica infrastructure.
- **Snapshots.** Periodic snapshot of the primary; query the snapshot. Loses some freshness, fully isolates the production database.
- **Change data capture (CDC).** Stream the database's transaction log; reconstruct state externally. Near-real-time and zero impact on the primary.
- **API layer.** The application team exposes data through APIs you query. Most isolated; depends on the team prioritizing your needs.

CDC has won as the modern default for high-volume operational sources. Tools like Debezium make it production-ready.

> [!warning] Querying production databases directly works fine until it doesn't. The first time your analytical query takes the application down, you'll wish you had a replica.

@feynman

Same as scraping a website — you might get away with it for a while, until the rate limits or page structure or admin team catches you.

@card
id: eds-ch05-c005
order: 5
title: Change Data Capture Reads The Database's Diary
teaser: Instead of querying for new rows, CDC tails the database's transaction log to capture every change as it happens. Real-time, low-impact, and increasingly the default for operational sources.

@explanation

Every transactional database keeps a write-ahead log (WAL) of every change — inserts, updates, deletes — for crash recovery. CDC tools tail that log and emit each change as an event.

The wins:

- **Near real-time.** Changes available downstream within seconds.
- **Low impact on source.** Reading the log doesn't compete with application queries.
- **Captures everything.** Updates and deletes show up too, not just new rows.
- **Order preserved.** Transactions arrive in the order they committed.

The mechanics:

- **Postgres** — logical replication slots stream WAL records.
- **MySQL** — binlog reading.
- **MongoDB** — change streams API.
- **SQL Server** — built-in CDC features.

Tools that productionize this: Debezium (open source, the de facto standard), Fivetran's CDC connectors, AWS DMS, Striim.

The challenges:

- **Schema changes** still require coordination — CDC streams what the schema is, not what you wished it were.
- **Replication lag** — when the WAL grows faster than you read it, you fall behind.
- **Truncates and bulk operations** — these often produce tricky CDC events that downstream consumers handle poorly.
- **Initial snapshot** — CDC starts from a point in time; you need to backfill historical data separately.

> [!info] CDC has steadily replaced batch full-table refreshes as the default for ops-to-analytics pipelines. The freshness and impact wins are big enough to justify the operational complexity.

@feynman

Same idea as following a git commit log instead of diffing the whole repo every hour. Cheaper, more current, requires more setup.

@card
id: eds-ch05-c006
order: 6
title: APIs And Webhooks As Sources
teaser: Third-party SaaS systems mostly expose data through APIs. Pulling efficiently while respecting rate limits is the daily craft of API-based ingestion.

@explanation

When the source is a third-party service (Stripe, Salesforce, Zendesk, Hubspot, GitHub), you're querying or receiving from APIs.

**Pull patterns** — your code requests data on a schedule:

- **Full refresh** — re-fetch everything every run. Simple, expensive, often required if there's no incremental field.
- **Incremental by timestamp** — fetch records changed since last successful run. Requires the API to support a `modified_since` filter, which not all do.
- **Incremental by cursor** — fetch records after a returned cursor token. Vendor-specific; each API does it differently.

**Push patterns** — the source sends data to you when it changes:

- **Webhooks** — the API POSTs to your endpoint when an event occurs. Fast, but you must run a reliable receiver, handle retries, and reconcile missed events.
- **Event streams** — some vendors (Shopify, Stripe with Connect) offer stream subscriptions.

Cross-cutting concerns:

- **Rate limits** — every API has them; respect them or get throttled or banned.
- **Auth refresh** — OAuth tokens expire; bearer tokens rotate; build retry around 401s.
- **Pagination** — most APIs return pages; assume you'll need to traverse them all.
- **Idempotency** — replaying events should not double-count.

This is where managed connectors (Fivetran, Airbyte) earn their fee — they handle the API quirks for hundreds of sources so you don't.

> [!tip] If you're tempted to write a custom Salesforce connector, look at what the managed vendors charge first. The build cost is almost always worse than the recurring fee.

@feynman

Same job as scraping a third-party service — politeness, reliability, and reconciliation are the unglamorous half of it.

@card
id: eds-ch05-c007
order: 7
title: Files As Sources — Still Everywhere
teaser: SFTP drops, S3 buckets full of CSVs, partner-shared exports — file-based sources are unfashionable but they're not going away.

@explanation

File sources remain common because they're the lowest common denominator. The patterns:

- **Periodic drops** — a partner uploads a daily file to SFTP or S3.
- **Push delivery** — the source service pushes a file to your endpoint when ready.
- **Pull from a remote location** — your job fetches files from a known source.

The challenges file sources bring:

- **Format inconsistency** — CSVs with different delimiters, quotes, null handling between batches.
- **Partial files** — half-uploaded files mistaken for complete ones; use checksums or markers (`_SUCCESS` files).
- **Naming conventions** — mid-month a vendor changes the filename pattern and your job breaks.
- **Encoding** — UTF-8 vs Latin-1; BOMs; mixed encodings within a single file.
- **Volume spikes** — a file that was 100MB last month is 5GB this month.

What helps:

- **Standardized landing zones** — every file lands in a predictable location with a predictable naming pattern.
- **Validation as the first step** — schema, row count, format checks before any further processing.
- **Quarantine on failure** — bad files move to a quarantine directory so they don't block the pipeline.
- **Idempotent ingestion** — if the same file arrives twice, your pipeline handles it correctly.

> [!warning] "It's just a CSV" is the phrase that precedes 80% of file-ingestion incidents. CSV is one of the worst data formats ever; assume it will misbehave.

@feynman

Same as parsing user-uploaded files — assume malice or incompetence in the source; validate early.

@card
id: eds-ch05-c008
order: 8
title: Streaming Sources And Event Logs
teaser: Many systems now publish events as they happen. Consuming streaming sources is operationally different from polling — and increasingly the default for high-velocity data.

@explanation

Streaming sources publish events continuously to a message bus (Kafka, Kinesis, Pub/Sub, Pulsar). Examples:

- Application events ("user clicked button," "order placed").
- Transaction events from financial systems.
- IoT telemetry from devices.
- CDC streams from operational databases.

What's different about consuming them:

- **Continuous consumption.** You run a long-lived consumer process, not a scheduled job.
- **Offsets matter.** You track which event you last read; restart from there.
- **Backpressure.** When you can't keep up, the broker holds events; you must catch up before retention expires.
- **Ordering guarantees** vary — per partition usually, global rarely.
- **Exactly-once semantics** — possible in some setups, hard in general; aim for at-least-once with idempotent processing.

What this enables:

- Real-time analytics, dashboards that update within seconds.
- Reactive pipelines — downstream actions fire as events arrive.
- Decoupling — producers don't know who consumes.

The cost: streaming infrastructure (Kafka, Flink, schema registries, monitoring) is more complex than batch. Reach for streaming when the freshness requirement justifies the operational burden.

> [!info] Many teams default to streaming and regret it. If your downstream consumer reads daily, your source can be batch. Streaming when you don't need it is expensive complexity.

@feynman

Same trade-off as polling vs WebSocket — push is more current, more complex; pull is simpler, less fresh.

@card
id: eds-ch05-c009
order: 9
title: Source Quality — Garbage In, Garbage Out
teaser: Every quality issue downstream traces back to either the source data or a transformation bug. Sources are usually the first place to look — and the hardest place to fix.

@explanation

Categories of source-data quality issues:

- **Missing values** — fields that are null when they shouldn't be.
- **Duplicate records** — the same event recorded multiple times.
- **Inconsistent encoding** — names with weird characters, dates in mixed formats, mixed timezones.
- **Stale data** — values that should have updated but haven't.
- **Reference inconsistency** — foreign keys pointing to nothing.
- **Out-of-range values** — ages of 800, negative quantities, future dates of birth.
- **Semantic ambiguity** — `status = 'closed'` meaning either "complete" or "abandoned" depending on context.

Approaches:

- **Profile the source** — actually look at the data; understand its quirks.
- **Define quality expectations** — ranges, uniqueness, freshness, completeness.
- **Test continuously** — Great Expectations, dbt tests, Monte Carlo run quality checks on every pipeline run.
- **Push back upstream** — the cheapest fix is at the source; data engineers spend disproportionate time advocating for upstream changes.

You won't fix all of it. The realistic goal is knowing about quality issues before downstream consumers do, and making informed decisions about what to fix vs what to document and live with.

> [!tip] When you discover a source-data issue, the question isn't only "how do I clean it?" — it's also "should this be fixed at the source so other consumers don't suffer the same problem?"

@feynman

Same as input validation in software — fix at the boundary if you can, defend internally where you can't.

@card
id: eds-ch05-c010
order: 10
title: Schemas Need Owners, Not Just Definitions
teaser: A schema everyone uses but no one owns is a schema that drifts silently. Source systems and the tables they feed need explicit human ownership for quality to hold.

@explanation

Ownership in data systems means:

- **Someone is responsible** for the source's correctness, freshness, and stability.
- **Someone gets paged** when the source breaks downstream consumers.
- **Someone decides** when the schema can change and how to communicate it.
- **Someone documents** what the source means semantically.

Without ownership, sources accrete entropy. Columns get added with names like `temp_field_2`. Tables get joined to other tables in ways no one remembers why. Definitions drift as new use cases bolt on.

Mature data orgs assign explicit owners — usually a team, sometimes an individual — to each significant source. The owner:

- Maintains the source's documentation.
- Approves or rejects schema changes.
- Communicates breaking changes to consumers ahead of time.
- Owns the on-call for outages.

Where the ownership model gets interesting is at the boundary between application teams (who own the source database) and data teams (who own the pipelines). The data mesh push has been about making domain teams own data products, not just operational databases.

> [!warning] "Everyone owns it" means no one owns it. If you can't name the owner of a source within 30 seconds, the source has no owner.

@feynman

Same as code ownership — without a CODEOWNERS-equivalent, every change becomes someone else's problem.

@card
id: eds-ch05-c011
order: 11
title: Working With Application Teams
teaser: The application engineers who own your sources are your most important relationship. Treating them like a service desk wastes the relationship; treating them like collaborators makes the pipelines more reliable.

@explanation

The data team often has a fraught relationship with application teams. Common patterns of friction:

- **Surprise schema changes** — application team ships a release that breaks pipelines.
- **Performance complaints** — application team blames the data team for read load on their database.
- **Definition drift** — application team renames or repurposes a column without telling anyone.
- **Asymmetric knowledge** — application team doesn't know which pipelines depend on what.

What helps:

- **Show up before you need something.** Build the relationship in normal time, not during incidents.
- **Make your dependencies visible.** Document which application team owns which sources. Share the list with them.
- **Invest in their tooling.** A schema-change checklist, an automated test in their CI that flags breaking changes — these reduce surprise and don't require their bandwidth ongoing.
- **Bring solutions, not just problems.** "Your DB is slow because of our queries; here's a CDC pipeline that fixes it" goes further than complaint.
- **Acknowledge their constraints.** They have product deadlines too; data team needs are usually not their top priority.

The teams with the strongest data quality and the fewest incidents are not the teams with the best tools — they're the teams whose data engineers and application engineers know each other's names.

> [!tip] A monthly informal sync between the data team and the largest source-owning teams pays for itself in incidents avoided. Doesn't have to be formal; needs to be regular.

@feynman

Same as cross-team API contracts — works because of the relationship, not the document.
