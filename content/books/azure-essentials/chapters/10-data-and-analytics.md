@chapter
id: azr-ch10-data-and-analytics
order: 10
title: Data and Analytics
summary: Azure's data and analytics platform spans every layer of the modern data stack — from ingestion and streaming to governed lakehouses, AI APIs, and IoT — and understanding which service owns which job keeps you from stitching the wrong pieces together.

@card
id: azr-ch10-c001
order: 1
title: Azure Data Factory for ETL/ELT
teaser: ADF is Azure's managed orchestration engine for moving and transforming data at scale — from 100 sources to 100 sinks — without managing servers or writing glue infrastructure.

@explanation

Azure Data Factory is a cloud-native ETL/ELT service. You build **pipelines** composed of **activities** (Copy, Data Flow, Stored Procedure, Web, etc.), point those activities at **datasets** that describe the shape of the data, and wire datasets to **linked services** that hold the connection strings. The result is a visual, auditable orchestration graph that runs on Azure-managed compute.

The **copy activity** is the workhorse. It moves data between 90+ source/sink combinations — on-premises SQL Server to ADLS Gen2, Salesforce to Azure SQL, S3 to Blob — with built-in parallelism, schema mapping, and fault tolerance. For most data movement needs, you configure a copy activity rather than writing code.

When you need transforms, **Data Flows** give you a code-free Spark authoring surface. You build column derivations, aggregations, joins, and pivots in a GUI, and ADF compiles them to Spark jobs that run on an auto-managed Databricks-like cluster.

**Integration Runtimes** are the compute bridge:
- **Azure IR** — fully managed, runs in Azure, handles cloud-to-cloud movement.
- **Self-hosted IR** — a Windows agent you install on-premises or in another cloud, enabling ADF to reach databases and file shares that aren't internet-accessible.

Pipelines fire on three trigger types: **schedule** (cron-style), **tumbling window** (fixed non-overlapping intervals with backfill support), and **event-based** (new file in storage, custom events from Event Grid).

> [!tip] Use tumbling window triggers over schedule triggers whenever you need guaranteed at-least-once execution with automatic backfill — they track watermarks so a failed run retries correctly, whereas a schedule trigger just skips missed windows.

@feynman

ADF is the airport hub of your data estate: it doesn't store the passengers, but it makes sure every connection between planes is scheduled, monitored, and rerouted when something is delayed.

@card
id: azr-ch10-c002
order: 2
title: Azure Event Hubs for High-Throughput Streaming
teaser: Event Hubs is Azure's managed streaming backbone — Apache Kafka-compatible, partitioned, and built to absorb millions of events per second without you touching a broker.

@explanation

Event Hubs ingests event streams at scale. The fundamental unit of parallelism is the **partition** — a durable ordered log. You can configure 1 to 2,048 partitions per namespace (up to 32 on the Basic/Standard tiers by default, higher on Premium/Dedicated). Consumers in the same **consumer group** each read from their own partition cursor independently, so you can fan out to multiple downstream processors without coordination.

Events are retained for 1 to 90 days depending on the tier. After retention expires, they're gone — Event Hubs is not a database. If you need to replay beyond the retention window, enable **Capture**: Event Hubs writes Avro files to ADLS Gen2 or Blob Storage on a configurable time/size interval, giving you a permanent archive at low cost.

**Kafka protocol compatibility** is the key differentiator from raw queue services. Existing Kafka producers and consumers connect by swapping the bootstrap server URL — no code changes needed. This makes Event Hubs a drop-in migration target for teams already running Kafka workloads.

Event Hubs vs Service Bus in one sentence: **Event Hubs** is for high-volume telemetry streams where multiple consumers replay events at their own pace; **Service Bus** is for transactional message queues with per-message delivery guarantees, dead-lettering, and sessions — choose it when order or exactly-once delivery of individual messages matters more than throughput.

> [!info] The Dedicated tier gives you a single-tenant cluster with up to 2,048 partitions and 90-day retention. If you're ingesting more than 40 MB/s sustained or need SLA isolation, Dedicated is the path.

@feynman

Event Hubs is a conveyor belt: producers drop items on one end, multiple observers watch from their own vantage point along the belt, and the belt keeps moving regardless of whether anyone is watching.

@card
id: azr-ch10-c003
order: 3
title: Azure Stream Analytics for Real-Time SQL on Streams
teaser: Stream Analytics lets you query live event streams with familiar SQL syntax — no cluster to manage, no JVM tuning — and push results to 30+ output sinks in seconds.

@explanation

Stream Analytics is a fully managed real-time processing service. You define an **input** (Event Hubs, IoT Hub, or Blob), write a query in **Stream Analytics Query Language** (SAQL — T-SQL with streaming extensions), and route results to an **output** (Power BI, Azure SQL, Cosmos DB, ADLS Gen2, Service Bus, Azure Functions, and 25+ others).

The streaming extensions that matter most are the **windowing functions**:
- **Tumbling:** fixed, non-overlapping windows. `GROUP BY TumblingWindow(minute, 5)` — counts per 5-minute bucket, no overlap.
- **Hopping:** fixed-size windows that slide by a hop interval. A 10-minute window hopping every 5 minutes means each event appears in two windows — useful for rolling averages.
- **Sliding:** windows that open on an event and close when no new event arrives within the window size. Produces output only when something changes.
- **Session:** variable-length windows that group events within a gap timeout — natural for user session modeling.

**Reference data joins** let you enrich streaming events with a slowly changing lookup table stored in Blob or ADLS Gen2. Stream Analytics reloads it on a configurable schedule, so you can join live telemetry against a product catalog or device registry without a roundtrip to a database.

Capacity scales in **Streaming Units (SUs)**. 1 SU ≈ 1% CPU + 1.5 MB/s input throughput (rough guideline). Most workloads start at 3 SUs and scale to 192. Unlike Databricks or HDInsight, there are no cluster nodes to size — just dial the SU count.

> [!warning] Stream Analytics queries run in a serverless environment that doesn't preserve local state across restarts. If your job stops for maintenance, it resumes from the last checkpoint — but complex stateful logic that crosses restart boundaries needs careful watermark design to avoid event loss or duplication.

@feynman

Stream Analytics is a standing SQL query that never stops running — as if you'd written `SELECT ... FROM events WHERE timestamp > NOW()` and it kept printing new rows forever without any infrastructure to maintain.

@card
id: azr-ch10-c004
order: 4
title: Azure Databricks for Managed Apache Spark
teaser: Databricks is the strategic Spark platform on Azure — co-engineered, deeply integrated with ADLS and Azure AD, and the right choice for large-scale ML, streaming, and lakehouse workloads.

@explanation

Azure Databricks is a managed Apache Spark platform built jointly by Microsoft and Databricks. It runs on Azure compute inside your subscription but is managed by the Databricks control plane, which handles cluster provisioning, autoscaling, and the runtime itself.

Two cluster types cover different use patterns:
- **Interactive clusters** — shared, long-running, used by notebooks and exploratory work. Idle autoscale down; terminate after inactivity.
- **Job clusters** — ephemeral, spun up for a single pipeline run, terminated immediately after. Lower cost, stronger isolation.

The **Databricks Runtime** is an optimized Spark distribution — not vanilla open-source Spark. It adds 3–5x performance improvements over stock Spark for common workloads via Photon (vectorized C++ query engine), adaptive query execution, and Delta Lake optimizations.

**Delta Lake** is the default table format. It adds ACID transactions, schema enforcement, time travel (query data as of any past version), and `OPTIMIZE`/`ZORDER` for file compaction — all on top of Parquet files in ADLS Gen2. You get database-quality reliability on cheap object storage.

**Unity Catalog** is the governance layer: one metastore across all workspaces, fine-grained table/column/row-level access control, data lineage tracking, and audit logs. If you're running multiple Databricks workspaces, Unity Catalog is the control plane that keeps them consistent.

**Databricks SQL** surfaces a SQL endpoint for BI tools (Power BI, Tableau, dbt) that query Delta tables directly — no ETL into a separate warehouse required.

> [!info] Databricks is the strategic direction for big data on Azure. HDInsight has not received major feature investment since 2022. New Spark/ML workloads should start on Databricks unless a specific open-source component (HBase, Hive LLAP) forces the choice.

@feynman

Databricks is Spark with the rough edges filed off — the same engine, but with an optimized runtime, a governed table format, and a control plane that handles the operations you'd otherwise write runbooks for.

@card
id: azr-ch10-c005
order: 5
title: Azure HDInsight for Open-Source Cluster Workloads
teaser: HDInsight is Azure's managed open-source cluster service — Hadoop, Kafka, HBase, Hive LLAP — and the right choice when you need a component that Databricks doesn't offer, not as a general Spark alternative.

@explanation

HDInsight provisions fully managed clusters running Apache Hadoop, Spark, Kafka, HBase, or Interactive Query (Hive LLAP). You pick the cluster type at creation, and Azure provisions the underlying VMs, installs the software, and configures networking. You still SSH into the nodes and manage Ambari like a traditional cluster — it's managed infrastructure, not a fully abstracted PaaS.

The cases where HDInsight beats Databricks:
- **HBase** — wide-column NoSQL with millisecond random read/write. Databricks has no equivalent. If you need a billion-row table with sub-5ms point lookups, HDInsight HBase is the Azure answer.
- **Hive LLAP / Interactive Query** — in-memory Hive with sub-second query latency. Some legacy Hive-dependent BI tools integrate here rather than against Spark SQL.
- **Existing Hadoop workloads** — if you have a lift-and-shift from on-premises HDFS with MapReduce jobs and custom ecosystem components, HDInsight gives you the closest familiar surface.
- **Kafka on HDInsight** — when you need Kafka with ZooKeeper and full broker control, rather than the Event Hubs Kafka emulation layer.

The honest tradeoff: HDInsight clusters take 15–20 minutes to provision, require you to manage node sizing manually, and have not received major feature investment since 2022. For net-new Spark or ML work, Databricks is the strategic path. HDInsight is a migration bridge or a HBase host, not a greenfield recommendation.

> [!warning] HDInsight is not being deprecated, but the product roadmap has shifted. Microsoft's official guidance for new Spark workloads points to Databricks. Budget your architectural decisions accordingly.

@feynman

HDInsight is like a managed VM that comes pre-loaded with the Hadoop ecosystem — you get the software without the installation, but you still get the knobs.

@card
id: azr-ch10-c006
order: 6
title: Microsoft Purview for Data Governance
teaser: Purview is the unified governance layer for your Azure data estate — scan, classify, catalog, and control access across hundreds of sources without building a bespoke metadata system.

@explanation

Microsoft Purview (formerly Azure Purview) is a data governance platform that spans four capability areas:

**Data Map** — the foundation. Purview scans registered data sources (ADLS Gen2, Azure SQL, Synapse, on-premises SQL Server, Power BI, S3, and 100+ others), extracts metadata and schema, and runs automated **classification** against 100+ built-in patterns (credit card numbers, email addresses, national IDs). After a scan, every column in every table has a detected sensitivity label. You can also define custom classifiers with regex or dictionary patterns.

**Data Catalog** — a searchable layer over the Data Map. Business users find datasets by keyword, owner, sensitivity, or glossary term. The **business glossary** lets data stewards define authoritative terms ("customer," "revenue," "active user") and map them to physical columns — closing the gap between how business and engineering talk about the same data.

**Data Lineage** — end-to-end flow of data from source to consumption, automatically captured from ADF pipelines, Synapse Analytics, and Databricks (via Apache Atlas integration). You can trace a Power BI dashboard column back to the raw source file in 3 clicks.

**Data Policy** — access control managed through Purview rather than individual service IAM. A data owner grants "read data" on a collection in Purview, and the policy propagates to the underlying ADLS Gen2 storage ACLs automatically.

> [!info] Purview pricing is based on capacity units (CUs) and the number of data map objects. For most organizations, a single Purview account per tenant covers the entire estate — it's a governance plane, not a per-environment resource.

@feynman

Purview is the card catalog of your data library: it doesn't store the books, but it tells you what every book contains, where it came from, who's allowed to check it out, and which chapters are sensitive.

@card
id: azr-ch10-c007
order: 7
title: Azure OpenAI Service for Enterprise AI Models
teaser: Azure OpenAI gives you GPT-4o, DALL-E, Whisper, and Embeddings inside your Azure tenant — with private networking, content filtering, and Microsoft's SLA — rather than calling OpenAI's public API.

@explanation

Azure OpenAI Service is Microsoft's managed gateway to OpenAI models deployed within Azure infrastructure. The available model families include GPT-4o and GPT-4 (chat/completion), GPT-4 Turbo with Vision, Whisper (speech-to-text), DALL-E 3 (image generation), and text-embedding models (ada-002, text-embedding-3-small/large).

The critical enterprise differentiator: **your data does not leave your Azure tenant and is not used to train OpenAI models.** Prompts and completions stay within your subscription boundary. This unlocks use cases that are blocked by data residency, privacy, or compliance requirements when using the OpenAI public API.

Security controls available on Azure but not on OpenAI directly:
- **Virtual network integration** — route API calls through a private endpoint in your VNet, never over the public internet.
- **Azure AD authentication** — use managed identities and RBAC rather than raw API keys.
- **Content filtering** — configurable harm categories (hate, violence, self-harm, sexual content) applied at the service level, not in application code.
- **Diagnostic logging** — request/response logs to Log Analytics for audit trails.

**Quota** is assigned per model per region in tokens-per-minute (TPM). The default quota is modest (~240K TPM for GPT-4o); you request increases through the Azure portal. For latency-sensitive workloads, **Provisioned Throughput Units (PTUs)** give you reserved model capacity at a fixed hourly rate — deterministic latency, predictable cost, no noisy-neighbor risk.

> [!tip] Start with pay-as-you-go quota while prototyping. Switch to PTUs only when you have a production workload with a measurable p95 latency requirement or sustained throughput above ~100K RPM.

@feynman

Azure OpenAI is a private VIP entrance to the same club — same models, same quality, but your conversations stay in your private room and the bouncer follows your employer's rules.

@card
id: azr-ch10-c008
order: 8
title: Azure AI Services for Pre-Built AI APIs
teaser: Azure AI Services are production-ready AI capabilities you call over HTTP — no training, no GPU cluster, no data science team required — covering language, vision, speech, and document understanding.

@explanation

Azure AI Services (formerly Cognitive Services) is a family of pre-built AI REST APIs that cover five domains:

**Language** — text analytics: sentiment analysis, named entity recognition (NER), key phrase extraction, language detection, abstractive summarization, personally identifiable information (PII) detection, and question answering. The Conversational Language Understanding (CLU) service handles intent classification with custom training data.

**Vision** — Image Analysis (object detection, captioning, dense captions, smart cropping), OCR (extract printed and handwritten text from images and PDFs), Face (detection, verification, attribute analysis — restricted API requiring access approval), and Custom Vision for training image classifiers on your own dataset.

**Speech** — Speech-to-Text (real-time and batch), Text-to-Speech (neural voices in 140+ languages), Speech Translation (real-time spoken translation), and Custom Neural Voice (clone a speaker's voice with 300 samples).

**Document Intelligence** — structured extraction from forms, invoices, receipts, ID documents, and custom document layouts. Processes PDFs and images and returns structured JSON. At ~$10 per 1,000 pages for the prebuilt models, it replaces significant custom OCR + parsing engineering.

**Translator** — document and text translation across 100+ languages.

When to use pre-built APIs vs alternatives:
- **Pre-built APIs** — proven accuracy on standard tasks, usage-based pricing, zero model training. Start here.
- **Custom fine-tuned models** — when pre-built accuracy on your domain is measurably insufficient after prompt tuning.
- **Azure OpenAI** — when you need general-purpose reasoning, generation, or instruction following, not a narrowly scoped classification or extraction task.

> [!info] Azure AI Services are multi-tenant shared infrastructure. If you need a private endpoint, dedicated capacity, or SLA above 99.9%, check the pricing tier — Commitment tiers provide reserved capacity and stronger guarantees.

@feynman

Azure AI Services are the standard library of AI — functions that took years and millions of training samples to build, available with a single API call so you don't rewrite sentiment analysis from scratch.

@card
id: azr-ch10-c009
order: 9
title: Azure IoT Hub for Device Connectivity
teaser: IoT Hub is the managed bi-directional broker between your devices and the cloud — handling authentication, telemetry ingestion, command delivery, and device state management for fleets from 1 to millions.

@explanation

Azure IoT Hub sits between IoT devices and your cloud backend. It handles the hard parts of device connectivity at scale:

**Device registry** — every device gets a unique identity with an X.509 certificate or SAS token. The registry is the source of truth for which devices are authorized to connect. Provisioning at scale uses the **Device Provisioning Service (DPS)**, which auto-registers devices during first boot without pre-configuring individual connection strings.

**Device-to-cloud telemetry** — devices publish messages that arrive as a built-in Event Hub endpoint. Your backend consumers (Stream Analytics, Azure Functions, custom readers) subscribe to this endpoint. At the Premium tier, message routing lets you filter and fan out to multiple endpoints based on message body or properties — for example, route temperature alerts to a storage path separate from routine readings.

**Cloud-to-device messages** — the reverse channel. Your backend sends commands or firmware update triggers to individual devices. IoT Hub queues the message and delivers it when the device is connected, with configurable TTL and acknowledgment feedback.

**Device twins** — a JSON document per device with two sections: **desired** properties (set by the backend, represent target state) and **reported** properties (set by the device, represent actual state). If you want a device to switch from 5-second to 1-second telemetry interval, you write the desired interval — the device reads it on next connect and reports the actual interval back. This decouples your backend from knowing whether a device is online.

SDK support: C, C#, Python, Java, Node.js (official), plus MQTT/AMQP/HTTPS for anything else.

IoT Hub vs Event Hubs: Event Hubs is a pure ingest endpoint — no device registry, no cloud-to-device, no device twins. IoT Hub adds the device management layer on top of compatible telemetry ingestion. For pure high-volume streaming without device management, Event Hubs is simpler and cheaper.

> [!tip] Device twins are the correct pattern for durable device configuration. Do not use cloud-to-device messages for configuration state — they're fire-and-forget with no built-in reconciliation if the device misses the message.

@feynman

IoT Hub is the shipping company's tracking system: every package has a registered identity, you can push updates to its label, check its last known location, and send rerouting instructions — and the package reports back whether it followed them.

@card
id: azr-ch10-c010
order: 10
title: Analytics Architecture Patterns on Azure
teaser: Lambda, kappa, lakehouse, medallion — these aren't buzzwords, they're load-bearing architectural decisions that determine which Azure services you buy, wire together, and operate for years.

@explanation

**Lambda architecture** splits processing into two paths: a **batch layer** (ADF pipelines loading data into ADLS Gen2 or Synapse, running on hours-to-day latency) and a **speed layer** (Stream Analytics or Databricks Structured Streaming over Event Hubs, running on seconds-to-minutes latency). Results from both paths merge in a serving layer. The tradeoff: you maintain two codebases, one per path, with different semantics. This complexity is only justified when your SLA genuinely requires sub-minute freshness alongside batch-accurate historical data.

**Kappa architecture** eliminates the batch layer by routing everything through streaming. All historical reprocessing runs by replaying the Event Hubs stream (up to 90 days, or longer via Capture). Simpler to operate than lambda, but requires your streaming system to handle backfill at scale — Databricks Structured Streaming with Delta Lake handles this well. Adopt kappa when your event volume fits in the retention window and reprocessing speed is acceptable.

**Modern lakehouse** is the dominant pattern for net-new Azure architectures: raw data lands in **ADLS Gen2** (cheap, durable, hierarchical namespace for Spark), processed with **Databricks** or **Synapse Analytics**, stored as **Delta Lake** tables (ACID, time-travel, schema evolution), and served to BI via Databricks SQL or Synapse Serverless SQL. One storage layer, multiple compute engines, no separate data warehouse required.

**Medallion architecture** layers on top of any lakehouse: **bronze** (raw, as-arrived, schema-on-read), **silver** (cleaned, deduplicated, schema-on-write, joined to reference data), **gold** (aggregated, business-defined metrics, optimized for query). You land bronze via ADF copy activities, transform to silver with Databricks Data Flows or notebooks, and publish gold as Delta tables consumed by Power BI or Databricks SQL. Keep bronze indefinitely — it's your audit trail and reprocessing source.

> [!info] The medallion layers map directly to ADLS Gen2 containers (`bronze/`, `silver/`, `gold/`) and Unity Catalog schemas. Setting this structure up before you have data costs almost nothing and saves painful migrations later.

@feynman

Medallion is the data equivalent of Git commits: bronze is every raw push, silver is the reviewed PR merge, and gold is the tagged release that downstream consumers actually depend on.
