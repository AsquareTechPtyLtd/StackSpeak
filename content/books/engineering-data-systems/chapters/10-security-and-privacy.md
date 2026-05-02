@chapter
id: eds-ch10-security-and-privacy
order: 10
title: Security and Privacy
summary: Data systems sit on top of an organization's most sensitive assets. The security and privacy practices that turn that responsibility into something you can actually defend.

@card
id: eds-ch10-c001
order: 1
title: Data Engineers Are First Responders
teaser: When data leaks, breaches, or gets misused, the data team is on the call. Building security in from the start is the only defensible posture.

@explanation

Data systems hold the highest-leverage targets in most organizations: customer PII, payment information, internal financials, intellectual property. Attackers know this; regulators know this; the data team should know this best of all.

The data engineer's posture must be defensive by default:

- **Treat every dataset as sensitive until proven otherwise.** Default to restrictive access; loosen with deliberate decisions.
- **Encrypt everywhere.** At rest, in transit, in backup, in derived artifacts.
- **Audit everything.** Who accessed what, when, from where. Immutable logs.
- **Plan for breach response.** When (not if) something happens, you'll need to know what was exposed and to whom.
- **Stay current with regulation.** GDPR, CCPA, HIPAA, PCI — the rules change; the team must keep up.

The reactive posture — "we'll add security when we need to" — is what causes the breaches that make the news. Once data is exposed, no amount of subsequent hardening helps.

> [!info] If your team can't quickly answer "who accessed customer table X in the last 30 days?", you have an audit gap that will surface during the next incident or regulatory review. Solve it before the pressure is on.

@feynman

Same default posture as defensive programming — assume malice or accident; design so that errors don't compound into disasters.

@card
id: eds-ch10-c002
order: 2
title: Identity And Access Management
teaser: Who can access what data is the most basic security question. Modern IAM gives you the controls; the discipline is using them well.

@explanation

The principle of least privilege: every user and service has only the access required for their job, and no more. In practice:

- **Users get access to specific datasets via roles**, not to "the warehouse" wholesale.
- **Service accounts are scoped to specific operations**, not given admin keys.
- **Temporary access for ad-hoc work** — granted with expiry, not added to permanent roles.
- **Production access is gated** — separate from dev access; logged when used.

Where IAM lives in modern data systems:

- **Cloud IAM** — AWS IAM, GCP IAM, Azure RBAC. Foundation layer for service accounts and broad permissions.
- **Warehouse roles** — Snowflake's role hierarchy, BigQuery's IAM integration, Redshift's grants. Application-level access controls.
- **Catalog-driven access** — Unity Catalog, Polaris, Apache Ranger enforce permissions across tools.
- **Application-level** — BI tool permissions (who sees which dashboard), reverse-ETL permissions (which sync runs as which identity).

The challenges:

- **Role explosion** — too many fine-grained roles become impossible to audit.
- **Drift** — access granted for a project lingers years after the project ends.
- **Service account sprawl** — every pipeline gets its own creds; secrets scattered across tools.
- **Manual provisioning** — humans granting access ad-hoc; trail evaporates.

What helps: role hierarchies (groups that aggregate permissions), automated provisioning (Terraform-managed IAM), regular audits (quarterly review of who has access to sensitive datasets).

> [!warning] "Just give them admin for now" is the start of every long-term access disaster. Take the extra ten minutes to scope properly the first time.

@feynman

Same hygiene as filesystem permissions — coarse "everyone can read" has the same end state as "no one knows who can access what."

@card
id: eds-ch10-c003
order: 3
title: Encryption At Rest And In Transit
teaser: Two baseline protections that should be assumed-on by default. Failures on either are not just bad practice — they're newsworthy incidents.

@explanation

**Encryption at rest** — data stored on disk is encrypted; reading the raw files reveals nothing without the key.

- **Cloud storage** — S3, GCS, Azure Blob all encrypt by default with provider-managed keys; customer-managed keys (CMEK) available for stronger control.
- **Warehouses** — Snowflake, BigQuery, Redshift all encrypt at rest by default.
- **Operational databases** — RDS encryption, GCP Cloud SQL encryption — turn it on; the cost is negligible.
- **Backups** — explicitly verify encrypted; backups are a common attack vector.

**Encryption in transit** — data moving between systems is encrypted; intercepting the network reveals nothing without breaking TLS.

- **TLS for everything** — never plain HTTP; never plain database connections from outside the network.
- **Mutual TLS for service-to-service** — both sides authenticate, not just the server.
- **VPN or private endpoints** — when crossing networks, prefer private connectivity over public TLS.

Common gaps:

- **Replication traffic** — primary-to-replica DB replication sometimes runs unencrypted; verify.
- **Internal RPC** — service-to-service calls inside the VPC sometimes skip TLS; modern practice is to encrypt anyway.
- **Logs** — sensitive values logged in plaintext; encrypted storage doesn't help if the log content is the leak.

> [!info] Encryption at rest doesn't protect from queries — anyone with database access reads decrypted values. It protects against disk theft, hostile cloud staff, and exfiltrated backups.

@feynman

Same as locking your house — protects against opportunistic intruders; doesn't help if you handed someone a key.

@card
id: eds-ch10-c004
order: 4
title: Secret Management
teaser: Database passwords, API tokens, encryption keys — the credentials your pipelines use to do their jobs. Where they live and who can read them is one of the highest-stakes operational questions.

@explanation

Secrets are the keys to your data infrastructure. Common patterns for handling them:

**Bad patterns** (still depressingly common):
- Hardcoded in pipeline code, in version control.
- In `.env` files committed to the repo.
- In Airflow connection UI as plaintext.
- In Slack messages or shared docs.

**Acceptable patterns**:
- Environment variables sourced from a secret manager at runtime.
- Encrypted in version control via Sealed Secrets, SOPS, git-crypt.
- In a managed secret store with audit logs.

**Good patterns**:
- **Cloud secret managers** — AWS Secrets Manager, GCP Secret Manager, Azure Key Vault. Versioned, audited, IAM-controlled.
- **Vault** (HashiCorp) — self-hosted enterprise secret management with dynamic credentials.
- **Workload identity** — services authenticate via their own identity (IAM role, service account); short-lived tokens issued automatically.
- **Database passwordless auth** — IAM-based authentication to RDS / Cloud SQL eliminates static DB passwords entirely.

The advanced pattern: **dynamic credentials**. Vault generates a fresh DB password for each pipeline run; expires after the run completes. Even if a credential leaks, the blast radius is one run.

> [!warning] Searching your codebase for `password` or `api_key` strings periodically catches a depressing number of accidentally-committed secrets. Schedule it.

@feynman

Same problem as keys to a building — losing them is a breach; rotating them carefully is hygiene; never writing them down beats both.

@card
id: eds-ch10-c005
order: 5
title: Data Classification — Know What You Have
teaser: Not all data is equally sensitive. Classifying datasets by sensitivity is the prerequisite to applying proportional controls.

@explanation

A common classification scheme:

- **Public** — fine to share externally. Marketing content, public reports.
- **Internal** — for employees only. Most operational data.
- **Confidential** — restricted to specific roles. Customer data, business plans, financials.
- **Restricted / Sensitive** — narrow access. PII, payment data, health information, source code, trade secrets.

Each tier earns specific controls:

- **Access** — who can read; how it's granted; how it's audited.
- **Encryption** — sometimes additional field-level encryption beyond at-rest defaults.
- **Retention** — how long it's kept; how it's deleted.
- **Logging** — what's logged about access; how long the logs are kept.
- **Network exposure** — public, VPC-only, on-prem-only.

Building the classification:

- **Inventory** — catalog every dataset.
- **Tag at the source** — Snowflake column tags, BigQuery policy tags, dbt model `meta` blocks all support classification metadata.
- **Propagate downstream** — classification follows the data through transformation; PII columns in raw tables produce PII columns in derived tables.
- **Enforce automatically** — masking policies, access policies, retention schedules driven by classification tags.

The hardest part: getting the classification right initially. The PII column you missed is the one that ends up unencrypted in a backup that ends up exposed.

> [!tip] Treat any new dataset as restricted by default until you've classified it. The cost of a few unnecessary controls is much lower than the cost of one missed classification.

@feynman

Same idea as security clearance levels — proportional controls based on what you're protecting.

@card
id: eds-ch10-c006
order: 6
title: PII, PHI, And Regulated Data
teaser: Some data classes carry legal obligations that go far beyond best practice. Recognizing them is the start of compliance.

@explanation

Common regulated data classes:

- **PII (Personally Identifiable Information)** — names, addresses, emails, phone numbers, government IDs. Regulated by GDPR (EU), CCPA (California), and equivalents elsewhere.
- **PHI (Protected Health Information)** — health-related personal data. Regulated by HIPAA (US) and equivalents.
- **PCI (Payment Card Industry data)** — card numbers, CVVs. Regulated by PCI-DSS.
- **Financial data** — bank account numbers, financial records. Various jurisdictional regulations.
- **Children's data** — under-13 in US (COPPA), under-16 in EU. Stricter rules.
- **Sensitive personal data under GDPR** — race, ethnicity, religion, political views, biometric data, sexual orientation.

Each carries specific obligations:

- **GDPR** — explicit consent, right to access/delete, breach notification within 72 hours, DPO appointment for large orgs.
- **HIPAA** — strict access controls, audit logs, BAA contracts with vendors, breach notification to affected individuals.
- **PCI-DSS** — segmentation, tokenization, regular audits, prohibited storage of certain card data.

The data engineer's role: identify these data classes early, build the controls in, document compliance. Working with privacy/compliance teams is a regular part of the job.

> [!warning] "We don't store PII" is rarely true; usually it means "we haven't found where we store PII yet." Audit before incidents force the discovery.

@feynman

Same as building code — the regulations exist because the failures are common, costly, and avoidable with discipline.

@card
id: eds-ch10-c007
order: 7
title: Tokenization And Pseudonymization
teaser: Two techniques that let you work with sensitive data while limiting the blast radius of a breach. Both protect identity; neither is full anonymization.

@explanation

**Tokenization** replaces sensitive values with non-sensitive surrogate values. The mapping is stored in a secure vault; the surrogate is meaningless without the mapping.

Example: replace credit card `4111-1111-1111-1111` with token `tok_abc123`. The warehouse holds tokens; the vault holds the actual card number; only authorized services with vault access can resolve.

Wins: pipelines that don't need real values can work with tokens — analytics, ML, reporting. The vault is the only thing that needs maximum security.

**Pseudonymization** replaces identifying values with consistent but non-identifying substitutes. A customer's actual email gets replaced with a hash; the same email always produces the same hash; cross-table joins still work.

Example: `john@example.com` → `f4a8b2c9...`. Across tables, joining by hashed email still finds the same person, but the warehouse never holds the original email.

The trade-off: pseudonymized data is reversible by anyone who knows the algorithm or who can re-hash known emails. It's not anonymous — it's deidentified.

When each fits:

- **Tokenization** — for high-sensitivity data where access to the original value is rarely needed (payment cards, SSNs).
- **Pseudonymization** — for moderately sensitive data where joins and analysis matter (emails for cohort analysis, IPs for fraud).
- **Full anonymization** — for data shared externally; aggregated to the point of irreversibility.

> [!info] GDPR considers pseudonymized data still personal data — the protections still apply. Only true anonymization (which is hard) escapes the regulation.

@feynman

Same trade-off as redacting a document vs blacking out — redacted you can re-derive if you know the algorithm; truly removed you can't.

@card
id: eds-ch10-c008
order: 8
title: Right To Be Forgotten And Data Deletion
teaser: GDPR and similar regulations require you to delete personal data on request. Building pipelines that can actually do this is harder than it sounds.

@explanation

The right to deletion ("right to be forgotten" under GDPR; equivalents under CCPA and others) requires that on a verified request, you delete a person's data within a defined timeframe (usually 30 days).

The hard parts:

- **Find every copy.** Personal data lives in operational DBs, raw landing zones, transformed tables, ML training datasets, backups, logs, exports, third-party integrations.
- **Delete vs anonymize.** Sometimes regulation allows pseudonymization in lieu of deletion (where research value is high and irreversibility can be proven).
- **Backups.** Strictly, backups must be deleted from too — but backups are immutable for good operational reasons. Common compromise: documented retention policy where backups age out within months.
- **Derived data.** Aggregated reports often don't need to track per-individual data; transformations should preserve aggregation, not retain identifying records.
- **Third parties.** If you've sent data to a vendor (CRM, email tool, ad platform), you must trigger their deletion too.

Architectural patterns that help:

- **Centralized identity table** — every PII reference goes through a single user table; deletion can cascade.
- **Soft-delete with hard-delete sweep** — mark for deletion immediately; sweep on a schedule.
- **Pseudonymization at landing** — raw data lands pseudonymized; the original identifier vault is the only source needing per-record deletion.
- **Lifecycle-aware retention** — data that's old enough to be deleted by default has fewer per-request deletion needs.

> [!warning] Designing deletion in is much cheaper than retrofitting. Building a pipeline today without thinking about how you'd delete a user's footprint is borrowing from your future incident-response budget.

@feynman

Same engineering reality as undo — has to be designed in; bolting it on later is a major refactor.

@card
id: eds-ch10-c009
order: 9
title: Audit Logging — The Records You'll Need Eventually
teaser: When something goes wrong, the difference between a quick recovery and a multi-week investigation is the quality of your audit logs.

@explanation

Categories of audit logs that matter for data systems:

- **Access logs** — who queried which tables, from where, when. Available natively in most warehouses (Snowflake's `ACCESS_HISTORY`, BigQuery's audit logs).
- **Schema-change logs** — DDL operations on schemas, tables, views. Who altered what.
- **Role-change logs** — grants and revokes; new users; permission elevations.
- **Pipeline execution logs** — what pipelines ran, on what data, with what outcome.
- **Data-export logs** — anything leaving the system (downloads, reverse-ETL syncs, file exports).
- **Authentication logs** — successful and failed login attempts; SSO events.

What makes audit logging useful:

- **Immutable** — written to a separate, append-only store. Attackers shouldn't be able to delete their tracks.
- **Long retention** — compliance often requires 1-7 years; investigations sometimes look back further.
- **Searchable** — when you need to know "who accessed table X in March 2024," the answer should be reachable in minutes.
- **Aggregated** — many systems produce logs; one investigation often spans several. Centralized log analysis (SIEM, Splunk, Datadog) is the answer.

The investment: nontrivial. Centralized logging at scale costs money. Audit-quality logs are larger than typical operational logs. But the cost of *not* having them shows up at the worst possible time.

> [!info] During an incident, you discover what your logging coverage actually is. Audit log gaps that didn't matter Monday become career events on Tuesday.

@feynman

Same insurance shape as backups — quietly expensive to maintain, decisive when needed.

@card
id: eds-ch10-c010
order: 10
title: Threat Modeling For Data Systems
teaser: Sit down before building. Ask: what could go wrong, who would do it, and what would it cost? Threat modeling makes security choices specific and grounded.

@explanation

A lightweight threat-modeling pass for any new system or significant change:

1. **Identify assets.** What data, what systems, what credentials are in scope?
2. **Identify threat actors.** External attackers? Disgruntled employees? Curious analysts? Competitors? Each has different capabilities and motivations.
3. **Identify attack vectors.** How could the assets be compromised? Phishing, credential leak, SQL injection, misconfigured access, vendor breach, physical access.
4. **Identify impact.** What's the cost if each scenario plays out? Regulatory fines, customer churn, IP loss, operational disruption.
5. **Identify mitigations.** What controls reduce likelihood or impact? Encryption, access reviews, monitoring, response plans.
6. **Prioritize.** Not all threats are equal; focus on high-likelihood + high-impact first.

Frameworks help structure this:

- **STRIDE** — Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege.
- **DREAD** — Damage, Reproducibility, Exploitability, Affected users, Discoverability.

The goal isn't producing a 50-page document; it's surfacing risks the team would otherwise miss and making decisions about which to mitigate.

> [!tip] Even a 30-minute threat-modeling session for a new pipeline catches design issues that would otherwise live for years. Bake it into the design process.

@feynman

Same hygiene as adversarial thinking in code review — assume someone might do something bad, design so it doesn't matter.

@card
id: eds-ch10-c011
order: 11
title: Privacy By Design
teaser: Building privacy into the system from the first sketch — not as a phase-2 retrofit. Cheaper, more effective, and increasingly a regulatory expectation.

@explanation

Privacy by design (a GDPR principle) means privacy considerations are built into systems from the start, not bolted on after concerns arise. The seven principles:

1. **Proactive not reactive** — prevent privacy invasions before they happen.
2. **Privacy as default setting** — the most privacy-protective option is the default.
3. **Privacy embedded in design** — built into the architecture, not added later.
4. **Full functionality** — privacy doesn't require accepting reduced functionality (positive-sum, not zero-sum).
5. **End-to-end security** — protection through the full data lifecycle.
6. **Visibility and transparency** — users know what's collected and how it's used.
7. **Respect for user privacy** — user-centric defaults; user control.

In practice for data engineering:

- **Collect minimum necessary data.** Each new field captured is a future obligation.
- **Default short retention.** Justify keeping data, not deleting it.
- **Pseudonymize early.** Raw PII lands pseudonymized; only specific systems can re-identify.
- **Consent management.** Track what each user has consented to; honor it through the pipeline.
- **Privacy reviews on new pipelines.** Before launch, a privacy lens; not after consumers complain.

The cultural shift: privacy stops being a compliance checklist and becomes an engineering quality dimension.

> [!info] Companies that build privacy-by-design from the start find regulatory compliance dramatically easier. Companies that retrofit it find every regulatory cycle expensive.

@feynman

Same idea as accessibility-first design — building it in is cheap; bolting it on is a project; ignoring it has consequences.

@card
id: eds-ch10-c012
order: 12
title: Vendor Risk And Third-Party Data
teaser: Every vendor you give data access to extends your attack surface. Vendor risk management is part of the security posture, not a separate function.

@explanation

Modern data stacks integrate with many vendors: BI tools, ingestion connectors, observability platforms, ML services, reverse ETL targets. Each gets some access to your data. Each is a potential breach vector.

Categories of vendor risk:

- **Direct data access** — vendors with credentials to read your warehouse (BI tools, observability platforms, ML services).
- **Data transit** — vendors that data passes through (ingestion connectors, reverse ETL).
- **Vendor breach** — the vendor gets compromised; your data is in their environment.
- **Sub-processor risk** — your vendor uses other vendors; the chain extends.

What due diligence looks like:

- **Security questionnaires** — SOC 2 reports, ISO 27001, vendor security documentation.
- **Data processing agreements** — contractual obligations on data handling, breach notification, sub-processors.
- **Access scoping** — vendors get the minimum access required; not "select on all schemas."
- **Audit logging** — your audit logs cover vendor access too.
- **Periodic review** — vendors evaluated annually, not just at signing.

The hard cases:

- **Free-tier tools** — SaaS used informally that no one realized handled real data.
- **Internal champions** — a sales rep brought in a tool; it's now reading customer data; security review never happened.
- **Acquisitions** — your vendor was acquired; new owner has different security posture.

> [!tip] Maintain a registry of every vendor with data access. Annual review. Anything new added requires explicit approval. Keeps the surface area knowable.

@feynman

Same risk pattern as installing dependencies — each one extends what you trust; trusted dependencies that go bad cause the worst incidents.

@card
id: eds-ch10-c013
order: 13
title: The Security Mindset For Data Engineers
teaser: Beyond specific controls, security is a way of thinking. Internalize it and good controls follow naturally; skip it and even strong controls are misapplied.

@explanation

The security mindset asks specific questions on every change:

- **What changes about who can access what?** New table, new role, new vendor — does the access model still hold?
- **What new attack surface does this open?** A new API endpoint, a new integration, a new credential.
- **What's the worst case if this fails?** The breach scenario, the regulatory exposure, the reputational impact.
- **What's logged and observable?** Could you reconstruct what happened in this system from logs alone?
- **How do you revoke this if needed?** Can you turn off access quickly? Can you rotate credentials in minutes?
- **Who else needs to know?** Privacy team, legal, security — bring them in early, not at incident time.

Cultural practices that reinforce the mindset:

- **Postmortems for security incidents** — even small ones; lessons compound.
- **Security review as part of design review** — not a separate gate; integrated.
- **Brown-bag training** — keep the team educated on emerging threats and patterns.
- **Tabletop exercises** — walk through hypothetical breach scenarios; find the gaps before the real one.
- **Reward reporting** — engineers who flag vulnerabilities or near-misses get visibility, not blame.

The test of a security-mature data team: when a new project lands, security questions get raised in the design discussion, not as a phase-2 audit. That's a culture, not a checklist.

> [!info] Most data security failures aren't from sophisticated attacks — they're from sloppy defaults, expired access not revoked, and credentials stored where they shouldn't be. The mindset prevents most of them.

@feynman

Same internalization as defensive coding — once it's a habit, you do it without thinking; without it, you constantly leave doors open.
