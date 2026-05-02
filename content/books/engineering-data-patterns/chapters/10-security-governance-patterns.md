@chapter
id: depc-ch10-security-governance-patterns
order: 10
title: Security and Governance Patterns
summary: Column masking, row-level security, audit logs, classification propagation, and deletion cascades — the patterns that make data systems compliant by construction rather than by process.

@card
id: depc-ch10-c001
order: 1
title: Security as a Structural Concern
teaser: Security that depends on people following a process fails when someone doesn't. Security patterns enforce access control and auditing structurally — in the pipeline and the schema, not the documentation.

@explanation

Data security governance fails in two common ways:

**Process-based governance:** "only the analytics team should query PII columns." The control is a policy in a wiki. When a new analyst joins, queries an unmasked PII column, and exports it to a spreadsheet, the breach was discoverable from audit logs — after the fact.

**Structural governance:** "PII columns are masked by policy for any user without the `pii_reader` role." The warehouse enforces the control; analysts without the role see a masked value; no policy compliance required.

Structural controls are enforcement; process controls are documentation. Both are needed, but structural controls are the foundation.

The patterns in this chapter operationalize structural governance for the most common requirements:
- Column-level access control (masking, encryption).
- Row-level access control (each consumer sees only their data).
- Audit trails (who read what and when).
- Classification and propagation (PII tags that follow data as it moves).
- GDPR/CCPA deletion compliance (removing a person's data from the entire system).

> [!warning] "We'll add governance after launch" is a risky bet. Adding column masking retroactively to a table with 50 downstream consumers means updating 50 consumers' queries. Build governance into the schema from the start.

@feynman

Like access control in a backend service — the control in the code beats the policy in the README every time.

@card
id: depc-ch10-c002
order: 2
title: Column Masking
teaser: Sensitive columns present a masked value to unauthorized users while returning the real value to authorized ones — transparently, without schema changes.

@explanation

**Column masking** applies a function to a column's value based on the querying user's roles, transparently returning a different value (masked, hashed, partially redacted) without changing the schema or requiring application code changes.

Example in Snowflake (dynamic data masking):
```sql
CREATE OR REPLACE MASKING POLICY email_mask AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('PII_ANALYST', 'ADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '(.+)@', '****@')
  END;

ALTER TABLE users MODIFY COLUMN email SET MASKING POLICY email_mask;
```

Now any query on `users.email` from an unauthorized role returns `****@example.com`; authorized roles see the real value.

Masking patterns:
- **Full redaction:** replace with NULL or a constant. Simplest; complete.
- **Partial masking:** show the last 4 digits of a credit card; mask the rest.
- **Tokenization:** replace the real value with a consistent token. The token is the same every time for the same input, enabling analytics on the token without exposing the real value.
- **Hashing:** one-way hash. Enables checking "is this the same person?" without reversibility.

Where column masking applies:
- PII fields (email, name, phone, SSN, health data).
- Financial data (account numbers, full card data).
- Credentials or secrets accidentally stored in data tables.

> [!info] Column masking in the warehouse doesn't protect against someone exporting a table before the mask is in place. Implement masking before the data lands, not after it's been accessed.

@feynman

Like a driver's license that shows age but not the actual birthdate to bar staff — the information needed for the decision is available without exposing the underlying record.

@card
id: depc-ch10-c003
order: 3
title: Row-Level Security
teaser: Each consumer sees only the rows they're permitted to see — enforced in the warehouse, not in application logic.

@explanation

**Row-level security (RLS)** filters the rows returned by a query based on the querying user's identity or role, enforced at the warehouse layer without requiring consumers to add WHERE clauses to every query.

When RLS applies:
- A multi-tenant SaaS platform where each tenant's users should only see their own rows.
- A regional data warehouse where EU analysts should only see EU customer data.
- A shared analytics environment where each team sees only their cost center's spend data.

Implementation in BigQuery:
```sql
-- Row access policy: each analyst sees only their region's rows
CREATE ROW ACCESS POLICY region_filter
ON analytics.orders
GRANT TO ('user:emea-analyst@company.com')
FILTER USING (region = 'EMEA');
```

In Snowflake: row access policies use a policy function that returns a boolean.

Without RLS, the control has to live in application code — every query must include the right WHERE clause, every BI tool must be configured with the right filter, every new consumer must remember the rule. One missed filter exposes all tenants' data.

RLS limitations:
- **Performance:** complex row filters (subqueries, JOINs in the policy) can make every query expensive.
- **Aggregations:** aggregations across filtered rows may still expose information through the aggregate value. A user who can't see individual rows but can query the sum may be able to infer individual values if the cardinality is low.
- **Audit trail:** RLS filters rows silently; it doesn't log that someone tried to access rows they couldn't see.

> [!tip] For multi-tenant data warehouses, RLS combined with separate warehouse roles per tenant is the most robust access control pattern. The role controls column masking; RLS controls row visibility.

@feynman

Like a view that's enforced for everyone whether they remember to use it or not — the filter is in the warehouse, not in every downstream query.

@card
id: depc-ch10-c004
order: 4
title: Audit Log Tee-Off
teaser: Copy every data access event to an append-only audit log. Who queried what, when, from which role — the record that answers "did anyone access this sensitive data?"

@explanation

**Audit log tee-off** routes access events — query execution, table reads, column touches, role changes — to a separate, append-only log store that can be queried for compliance and investigation purposes.

What an audit log should capture:
- **Who:** username or role identity.
- **What:** the query text (or at minimum the accessed tables and columns).
- **When:** timestamp to millisecond precision.
- **From where:** IP address, application name, query tool.
- **Result:** did the query succeed? How many rows were returned?

Sources of audit events:
- **Snowflake:** `ACCOUNT_USAGE.QUERY_HISTORY` view captures all queries across the account with user, role, query text, duration, and row count.
- **BigQuery:** Cloud Audit Logs captures every API call. Data Access Audit Logs capture table-level reads.
- **AWS:** CloudTrail captures Glue, Athena, and Redshift API calls.

Making audit logs useful:
- Write audit data to an immutable store (S3 with Object Lock, append-only Kafka topic).
- Build alerts on sensitive access patterns: "notify the data governance team when anyone queries the `users.ssn` column."
- Retain audit logs for the legally required period (HIPAA requires 6 years; GDPR requires it as long as the personal data exists).

> [!warning] Audit logs that are readable only by the security team are less useful. Build a self-service audit query interface so teams can answer "did our pipeline ever access this user's data" without filing a ticket.

@feynman

Like server access logs in an application — not prevention, but the record that enables investigation and accountability.

@card
id: depc-ch10-c005
order: 5
title: Classification and Tag Propagation
teaser: Tag sensitive data at the source and propagate those tags automatically as data moves through transformations. Manual re-tagging on every new derived table doesn't scale.

@explanation

**Classification and tag propagation** means sensitive data (PII, financial, health) gets tagged at the point of ingestion, and those tags follow the data automatically through every downstream transformation and table.

Without propagation: a data engineer manually tags the raw `users.email` column. Months later, a new `customer_profile` model is built that includes `email`. The engineer forgets to tag the new column. The audit report shows `customer_profile.email` as unclassified, compliance fails.

With propagation: when the transformation engine detects that a column in the output derives from a tagged column in the input, it automatically applies the same tags to the output column.

Tools and approaches:
- **dbt column-level lineage + tags:** dbt tracks column lineage and allows tag propagation through the lineage graph.
- **Snowflake object tagging:** tags can be set on individual columns and propagated to downstream views.
- **Data catalog integration:** Collibra, Atlan, and DataHub build tag propagation on top of lineage graphs from multiple sources.
- **LLM-assisted classification:** newer tools use LLMs to scan column names, sample values, and descriptions and suggest PII classifications. Human review confirms; the tool applies tags.

Classification taxonomy example:
```
pii:email, pii:name, pii:phone, pii:ssn
financial:account_number, financial:transaction_amount
health:diagnosis_code, health:medication
internal:cost, internal:salary
```

> [!info] Classification is only as good as its coverage. Schedule quarterly reviews of new tables against the classification taxonomy. New tables are the most likely to be unclassified.

@feynman

Like metadata tags on a photo that travel with it when you share it — the label stays attached, not on the original file only.

@card
id: depc-ch10-c006
order: 6
title: Deletion Cascades for Compliance
teaser: GDPR and CCPA require that a person's data be deletable on request. In a normalized operational database, this is a few rows. In a denormalized data warehouse, it's a multi-system operation.

@explanation

**Right to erasure** (GDPR Article 17) requires that a person's personal data be deleted across all systems when they request it. In an operational database with foreign key constraints, this is manageable. In a data warehouse with bronze/silver/gold layers, denormalized fact tables, and ML training sets, it's a cross-system coordination problem.

The challenge: a single user's data may exist in:
- Bronze raw event logs.
- Silver cleaned tables (deduplicated, parsed).
- Gold aggregated tables (may be impossible to fully remove — aggregates don't support individual deletion without full recomputation).
- ML training datasets (potentially in many model training artifacts).
- BI tool cached query results.
- Snapshot tables in multiple stages of the medallion architecture.

Patterns for deletable data systems:

**Tokenization at ingest:** replace PII with a token at the bronze layer. Store the PII-to-token mapping in a separate, tightly-controlled key vault. On deletion request: delete the key. All tokenized references become unresolvable. No pipeline changes required.

**Partition-aligned identifiers:** structure the data so that a single user's data is isolatable within a manageable number of partitions. On deletion, rewrite those partitions with the user's rows removed.

**Deletion log pattern:** maintain a `deleted_users` table. Downstream queries join to exclude deleted users. Simple to implement; requires every downstream query to include the anti-join.

**Regular snapshot purging:** if historical snapshots contain PII, define a retention period after which snapshots are deleted. Compliance by expiration rather than targeted deletion.

> [!warning] Aggregated tables (daily active users, revenue by segment) may include a deleted user in the aggregate. Whether this constitutes a GDPR violation depends on whether the individual is re-identifiable from the aggregate. Seek legal guidance for your specific case.

@feynman

Like unsubscribing from email — simple in principle; complicated when you've CC'd fifty mailing lists and don't know which ones have your address.
