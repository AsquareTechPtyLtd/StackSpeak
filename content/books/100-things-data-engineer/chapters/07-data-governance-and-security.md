@chapter
id: tde-ch07-data-governance-and-security
order: 7
title: Data Governance and Security
summary: Governance is the set of agreements, policies, and enforcement mechanisms that make data trustworthy, discoverable, and safe — and when it's treated as an engineering practice rather than a compliance checkbox, it actually works.

@card
id: tde-ch07-c001
order: 1
title: What Data Governance Actually Is
teaser: Governance is not the data quality report your manager sends on Fridays — it's the organizational agreements that determine who owns data, what it means, and who can do what with it.

@explanation

Data governance is the system of policies, processes, and standards by which an organization manages data as a shared organizational asset. It answers questions like: who is accountable for this dataset being correct? what does this column actually measure? who is allowed to access customer PII? what happens when a table schema changes?

It's important to distinguish governance from adjacent concerns:
- **Data quality** asks "is the data we have correct?" Governance asks "have we agreed what correct means, who is responsible, and how we enforce it?"
- **Data catalog** is a governance tool. Governance is the broader practice that gives the catalog its meaning.
- **Compliance** (SOC 2, HIPAA, GDPR) is one driver of governance, but compliance-only governance produces checkbox exercises that nobody uses. Engineering-driven governance produces policies that are enforced in code.

The failure mode is treating governance as a documentation project owned by a data governance committee that meets monthly. In practice, governance fails when it's disconnected from the systems engineers actually run. Effective governance is:
- Encoded in catalog tags, warehouse policies, and pipeline contracts — not just a spreadsheet
- Owned by data engineers in partnership with domain owners, not by a separate team
- Enforced automatically where possible, not relied on manually

A company with 50 engineers and no governance documentation can still have strong governance if access policies are tight, lineage is tracked, and ownership is clear. A company with 500-page governance documentation but no enforcement has nothing.

> [!warning] If your governance program lives primarily in a wiki that engineers don't read and policies that aren't enforced in code, you have governance theater — not governance.

@feynman

Governance is like a type system for your organization's data: it doesn't prevent you from writing the code, but it catches the category errors before they cost you in production.

@card
id: tde-ch07-c002
order: 2
title: Data Catalogs and Discoverability
teaser: The average data engineer spends more time hunting for the right table than they do actually querying it — a catalog is the index that makes your data estate navigable.

@explanation

A data catalog is the searchable index of your data estate. At minimum it answers: what datasets exist, what columns do they contain, what do those columns mean, who owns the dataset, when was it last updated, and is it safe to use in production?

Without a catalog, engineers discover data through Slack messages, lunch conversations, and grep. This doesn't scale past about 20 tables. At 200 tables it becomes a serious drag on productivity. At 2,000 tables it's a reliability hazard — engineers build on datasets they don't understand because they found them first, not because they're correct.

The major catalog tools differ in their focus:
- **Datahub** (LinkedIn, open source): strong lineage, good for engineering-heavy orgs
- **Atlan**: SaaS, strong on collaboration and data contracts
- **Collibra**: enterprise, strong on governance workflows and stewardship
- **AWS Glue Data Catalog**: tight integration with the AWS ecosystem; the implicit catalog if you're already on Glue/Athena
- **Unity Catalog** (Databricks): first-class governance and lineage within the Databricks lakehouse

A good catalog entry for a table includes: a description written by the owning team (not auto-generated), column-level descriptions for non-obvious fields, a designated owner, a freshness SLA, and a tag indicating whether it's safe for production use or experimental. If a dataset takes more than 30 seconds to discover and understand in your catalog, the catalog isn't doing its job.

> [!tip] Treat catalog documentation the same way you treat README files: write it when you create the dataset, update it when the semantics change, and make it a code review requirement for new pipelines.

@feynman

A data estate without a catalog is a library where all the books are piled on the floor and the only way to find the one you want is to ask someone who was there when it was shelved.

@card
id: tde-ch07-c003
order: 3
title: Data Lineage in Practice
teaser: Lineage tells you where data came from and what depends on it — which makes it the first thing you reach for when an upstream table changes and you need to know what breaks.

@explanation

Data lineage is the record of how data flows through your system: which upstream sources feed which tables, which columns derive from which source columns, and which downstream consumers depend on a given dataset.

There are two granularities you care about in practice:

**Table-level lineage** shows that `reporting.weekly_revenue` is built from `dw.orders`, `dw.refunds`, and `dw.products`. This is enough to answer "if I deprecate `dw.products`, what breaks?" Most orchestration tools (Airflow, dbt) can produce this automatically.

**Column-level lineage** goes further: this specific `revenue_usd` output column derives from `orders.amount_cents` divided by 100, adjusted by `refunds.amount_cents`. Column-level lineage is critical for impact analysis of schema changes ("if I rename `amount_cents` to `amount_raw_cents`, which downstream columns break?") and for PII propagation tracking ("this column carries PII because it derives from `users.email`").

**OpenLineage** is the open standard for emitting lineage events. It defines a spec for producers (Spark, Airflow, dbt, Flink) to emit structured lineage events to a backend (Marquez, Datahub) without coupling to a specific catalog. If you're building lineage capability today, build against OpenLineage rather than a proprietary API.

The impact analysis use case is where lineage earns its keep. Before making a breaking schema change, query your lineage graph for all downstream consumers. Without lineage, you rely on engineers knowing or a manual search through dbt refs — both of which miss things.

> [!info] Column-level lineage is 10x more valuable than table-level lineage for impact analysis, but also 10x harder to capture. Start with table-level; add column-level for high-churn tables first.

@feynman

Lineage is the git blame of your data pipeline — you can trace any value back to its origin and understand every transformation it passed through on the way.

@card
id: tde-ch07-c004
order: 4
title: Column Masking and Dynamic Data Masking
teaser: Masking lets you show the same table to different users while hiding sensitive values based on their role — without maintaining multiple copies of the data.

@explanation

Column masking is the practice of returning a transformed (obscured) version of a sensitive column to users who don't have permission to see the raw value, while users with sufficient privilege see the real value. The masking is applied dynamically at query time by the warehouse, not by maintaining separate tables.

A typical example: a `phone_number` column returns `XXX-XXX-1234` for analysts and `415-555-1234` for customer support agents with PII access. The underlying data is unchanged — only the view changes based on the caller's role.

Masking is available natively in all major cloud warehouses:
- **Snowflake**: masking policies attached to columns, evaluated by role
- **BigQuery**: column-level security with taxonomy tags + data policies
- **Databricks**: column masks defined in Unity Catalog
- **AWS Lake Formation**: column-level permissions on Glue tables

It's worth being precise about what masking is and isn't:
- **Masking**: replace the value with an obfuscated version (`415-555-1234` → `XXX-XXX-1234`). Not reversible from the masked output, but the raw value still exists in storage.
- **Tokenization**: replace the value with a consistent opaque token (`415-555-1234` → `tok_a8f3c2`). The same input always produces the same token, which allows joining across tables without exposing the real value. Token mapping is stored separately.
- **Redaction**: replace the value with null or a fixed string (`415-555-1234` → `REDACTED`). No relationship between original and output.

Choose based on your use case: masking for display, tokenization for joinable anonymization, redaction for hard removal.

> [!warning] Masking protects the column value in query results but does not prevent someone with storage access from reading the underlying file directly — warehouse-level masking and storage-level encryption are both needed for defense in depth.

@feynman

Dynamic masking is like a bank vault where the teller sees your balance but the window shopper outside sees only asterisks — same ledger, different views based on who's looking.

@card
id: tde-ch07-c005
order: 5
title: Row-Level Security
teaser: RLS restricts which rows a user sees based on their identity — so your regional sales reps each see their own region's data without you building five separate tables.

@explanation

Row-level security (RLS) is a policy that filters query results based on the identity of the user making the query. Instead of building separate tables per user group or filtering in application code, you define a policy once and the warehouse enforces it transparently on every query.

The canonical use case: a `sales_data` table has a `region` column. You define an RLS policy that compares `region` to the current user's `user_region` attribute. When a rep in the APAC team runs `SELECT * FROM sales_data`, they automatically get only APAC rows. No code change required in any downstream report or pipeline that queries the table.

RLS is implemented at different layers:
- **Warehouse-native**: Snowflake row access policies, BigQuery row-level security filters, Databricks row filters in Unity Catalog. Policy is enforced by the warehouse regardless of which tool queries it.
- **dbt meta**: dbt exposes RLS configuration in model YAML for some warehouses; the underlying mechanism is still warehouse-native.
- **Application layer**: filtering in the application query before hitting the database. Easier to implement, but leaks if any tool bypasses the application layer and queries the warehouse directly.

Prefer warehouse-native RLS over application-layer filtering for anything security-critical. Application-layer filters are a single bypass away from a data exposure.

Two real performance implications to plan for:
- RLS adds a predicate to every query on the table. For a well-partitioned table with region as a partition key, this is essentially free. For a table where region is a non-selective column on a full scan, it can be expensive.
- RLS policies that call external functions (e.g., look up the user's attributes from a mapping table) add join overhead to every query. Cache or pre-materialize role mappings where possible.

> [!info] RLS at the warehouse layer is enforced for every tool that queries the warehouse — BI tools, notebooks, direct SQL clients. This is the only layer that provides a universal security boundary.

@feynman

Row-level security is like an apartment building where each tenant's keycard only unlocks their own floor — the building is one structure, but the access boundaries are enforced by the infrastructure, not by asking people nicely.

@card
id: tde-ch07-c006
order: 6
title: PII Identification and Classification
teaser: You can't protect data you haven't found — automated PII scanning locates sensitive columns across your estate so you can tag them and let policy engines do the rest.

@explanation

PII classification is the process of identifying which columns in your data estate contain personally identifiable information and tagging them so downstream systems can enforce appropriate controls automatically.

The classification taxonomy most orgs use has a few tiers:
- **PII**: data that identifies a person (name, email, phone, IP address, device ID, government ID)
- **SPII (Sensitive PII)**: higher-risk PII where exposure causes more harm (Social Security numbers, passport numbers, biometrics, precise geolocation)
- **Financial**: payment card data, bank accounts, transaction amounts tied to individuals
- **Health**: PHI under HIPAA, diagnoses, prescriptions, provider relationships

Manual classification at scale is not viable. A data estate with 10,000 columns cannot be reviewed by hand on any reasonable cadence. Automated scanning tools identify PII candidates:
- **AWS Macie**: S3-native, scans files for PII patterns using ML classifiers
- **Microsoft Presidio**: open source, pattern + ML-based, integrates into pipelines
- **Catalog classifiers**: Datahub, Atlan, and Collibra all offer column-level auto-classification based on column name patterns and sampled values

The output of classification is catalog tags. A column tagged `pii:email` can then be picked up by governance policies automatically: auto-apply a masking policy, auto-restrict access to users in the `pii_approved` group, auto-flag any pipeline that writes the column to an untagged output table.

The key is closing the loop: tag → policy → enforcement. Classification that produces a spreadsheet of PII columns but doesn't drive any automated controls is documentation, not governance.

> [!tip] Start classification with column names — `email`, `ssn`, `phone`, `dob`, `ip_address` catch the majority of PII with simple pattern matching before you spend budget on ML classifiers.

@feynman

PII classification is like a smoke detector system — you place sensors everywhere and connect them to the sprinklers, so when something hazardous shows up anywhere in the building, the response is automatic, not dependent on someone noticing.

@card
id: tde-ch07-c007
order: 7
title: Data Access Audit Logging
teaser: Audit logs answer the compliance question "who accessed what data and when" — and they're only useful if you enable them before the regulator asks.

@explanation

An audit log is a record of every query or access event against your data warehouse: who executed it, when, what they ran, and what data was touched. It is the evidentiary record that compliance frameworks — SOC 2, HIPAA, GDPR, PCI-DSS — require you to produce when demonstrating that you've controlled access to sensitive data.

Every major warehouse ships with audit logging; you have to turn it on:
- **Snowflake**: `QUERY_HISTORY` view in `ACCOUNT_USAGE` schema; captures all queries with user, timestamp, SQL text, rows produced. Retained for 365 days.
- **BigQuery**: Cloud Audit Logs via Google Cloud Logging; `DATA_ACCESS` logs capture reads/writes; `ADMIN_ACTIVITY` logs capture schema changes.
- **Redshift**: STL tables (`STL_QUERY`, `STL_SCAN`) plus S3 audit log export for longer retention.

A few things audit logs need to be actually useful:
- **Retention**: 90 days is often too short for annual compliance reviews. Export to S3/GCS/cold storage.
- **Alerting**: audit logs are reactive by default. Add alerts for high-volume scans of PII tables, off-hours access, and access by service accounts that shouldn't be querying certain tables.
- **Immutability**: logs should be write-once in a separate account or bucket that the compromised credential cannot modify. An attacker who can delete the audit log can cover their tracks.

Audit logging is also useful beyond compliance: it tells you which tables are actually queried (helps identify unused tables to deprecate), who the power users of a dataset are (helps identify the real consumers when you're planning changes), and when unusual access patterns emerge.

> [!info] The security boundary evidence in a compliance audit is the audit log showing that only authorized users accessed PII tables — not the policy document that says they should. The log is the proof.

@feynman

An audit log is the security camera footage for your warehouse — the access controls are the lock on the door, but the log is what you show the auditor when they ask who came in.

@card
id: tde-ch07-c008
order: 8
title: GDPR and the Right to Erasure
teaser: GDPR's right to erasure is a data engineering problem disguised as a legal one — deleting a user's data from append-only systems requires deliberate architectural choices, not a DELETE statement.

@explanation

GDPR Article 17 gives EU residents the right to request deletion of their personal data. This is straightforward in a traditional relational database: run a DELETE, vacuum, done. In a modern data stack built on append-only systems, it's an architectural challenge.

The problem shows up in three places:

**Data lakes on S3/GCS**: data is stored in immutable Parquet or ORC files. You can't run a DELETE. The naive approach — rewrite every file that contains the user's data — is expensive and error-prone at scale. The right approach: use a lakehouse table format.

**Delta Lake** and **Apache Iceberg** both support GDPR deletes via their MERGE or DELETE operations, which rewrite only the affected data files and update the transaction log. On Delta Lake, `DELETE FROM users WHERE user_id = 'x'` is a first-class operation. Iceberg's `EqualityDeleteFile` format records which rows to exclude on read, deferring the physical rewrite.

**Kafka / event streams**: events are immutable by design. Compaction helps if the user's identifier is the partition key, but it doesn't guarantee removal. The architectural fix is **tombstoning** — write a tombstone event for the user_id; consumers are expected to process it as a deletion.

**The tokenization approach** offers an elegant solution: instead of storing PII directly, store a token. The token maps to the real PII in a separate, small token store. To "delete" a user, delete their entry from the token store. Every token in the data lake now maps to nothing — the data is effectively anonymized without touching any data files.

The tokenization approach scales better than physical deletion for large append-only estates, but requires buy-in at ingestion time — you can't retrofit it easily.

> [!warning] GDPR deletion obligations extend to backups. If you restore a backup after a deletion request, you re-introduce the deleted data. Your deletion runbooks must account for backup retention and restoration policy.

@feynman

Deleting from an append-only data lake is like trying to un-ring a bell — the tokenization approach doesn't un-ring it, it just makes the sound unrecognizable without the key.

@card
id: tde-ch07-c009
order: 9
title: Data Contracts Between Teams
teaser: A data contract is the formal agreement between a data producer and its consumers — schema, semantics, SLA, quality expectations — and it shifts ownership from "whoever made this" to "whoever made a promise about this."

@explanation

A data contract is a formal, versioned agreement between a team that produces a dataset and the teams that consume it. It specifies: the schema (column names, types, nullability), the semantics (what does `order_status = 'completed'` actually mean?), the SLA (data is available by 9 AM UTC with no more than 15 minutes of lag), and the quality expectations (no null `user_id`, `amount` is always positive).

Without contracts, the default data culture is: data teams produce whatever is convenient, consumers adapt to whatever shows up, and breaking changes happen because the producer didn't know anyone depended on a column. This is the "data swamp" pattern.

With contracts, producers have obligations. The contract creates accountability:
- The producer cannot rename a column without bumping the contract version and notifying consumers.
- The consumer knows what to expect and can write quality checks against the contract's assertions.
- Disputes about what the data means have a documented answer, not a Slack argument.

Contracts enforced in CI make the obligations real:
- **Schema tests** in dbt (`not_null`, `unique`, `accepted_values`) run on every pipeline execution. A contract violation fails the pipeline.
- **Schema registry** (Confluent Schema Registry for Kafka) enforces schema compatibility — BACKWARD, FORWARD, or FULL — at publish time.
- **Great Expectations / Soda** run expectation suites against fresh data; a freshness or range violation breaks the job.

The shift contracts require is cultural as much as technical: producers have to accept that they're accountable to downstream consumers, not just to their own team's needs. This is a harder sell than the tooling.

> [!tip] Start with a lightweight contract — a YAML file in the producer's repo with schema, owner, SLA, and three quality assertions. A contract enforced in CI beats a 10-page contract doc no one reads.

@feynman

A data contract is the API contract for your pipeline — without it, every consumer is reverse-engineering the producer's implementation and hoping it doesn't change.

@card
id: tde-ch07-c010
order: 10
title: Principle of Least Privilege for Data
teaser: Every user and process should have access to exactly the data they need for their job — no more — and the default answer to any new access request should be "no" until justified.

@explanation

The principle of least privilege (PoLP) applied to data means: users see only the tables they need. Service accounts read only the schemas they process. Analysts in marketing don't have access to the engineering team's raw infrastructure logs. No one has blanket access to PII tables by default.

The starting posture is default-deny. When a new dataset is created, it is accessible to its owner and a set of explicitly approved roles — not to everyone in the organization. Access is granted on a needs-justified basis, time-bounded where possible, and reviewed on a cadence.

Why this matters beyond compliance:
- **Breach blast radius**: if a credential is compromised, the attacker can only access what that credential was permitted to access. A service account that only reads one schema can't exfiltrate the entire warehouse.
- **Compliance evidence**: demonstrating that only authorized users accessed sensitive data is easier when "authorized users" is a small, auditable set — not "everyone."
- **Data hygiene**: over-permissive access leads to data sprawl. When anyone can query anything, datasets get used in ways the owner never intended and can't safely change.

The operational practice that makes PoLP real:
- **Access review cadence**: quarterly review of who has access to sensitive datasets. Remove access that is no longer needed. In practice, 20–40% of access grants are stale after 6 months.
- **Role-based access**: grant access to roles, not individuals. Users are members of roles. When someone leaves, removing them from the role revokes all their data access.
- **Break-glass access**: for on-call engineers who need emergency access, a short-lived elevated role with mandatory audit logging — not permanent broad access "just in case."

The most common failure is granting broad access to unblock a deadline and never revisiting it. That deadline access is still live three years later.

> [!info] The cost of over-permissive access is paid in two currencies: compliance risk (a breach that exposes data the user shouldn't have had) and organizational trust (the user who saw data they weren't supposed to see, intentionally or not).

@feynman

Least privilege for data is like a hospital badge system — the cardiologist has access to cardiology records, not the entire patient database, because the blast radius of a lost badge should be proportional to the job, not the institution.
