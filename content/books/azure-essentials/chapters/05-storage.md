@chapter
id: azr-ch05-storage
order: 5
title: Storage
summary: Azure Storage spans blob objects, file shares, queues, tables, managed disks, and data lake semantics — this chapter maps every service to its right use case, explains the redundancy and security options you will actually be asked about, and covers the tooling for moving data in and out.

@card
id: azr-ch05-c001
order: 1
title: Storage Accounts — The Root Container
teaser: Every Azure Storage service — Blob, Queue, Table, Files — lives inside a storage account, and the choices you make at account creation time set the ceiling for everything beneath it

@explanation

A storage account is not a storage service itself. It is the management boundary that groups services together and enforces account-wide settings: redundancy tier, performance tier, networking rules, and access keys. You can have multiple storage accounts in a subscription, and you usually should — separating production data from dev/test, or isolating compliance-sensitive data, is much easier when the boundary is at the account level.

Two decisions matter most at creation time:

- **Performance tier.** Standard uses magnetic HDD and supports all four services (Blob, Queue, Table, Files). Premium uses SSD and is scoped: you pick either block blob storage, file storage, or page blob storage — not all four from one account.
- **Redundancy.** LRS, ZRS, GRS, and GZRS are set at account creation. You can upgrade (LRS → GRS) but not freely downgrade; changing redundancy copies data and may incur a brief write-throttle window.

The account name must be globally unique across all of Azure — it becomes part of the endpoint URL (`<accountname>.blob.core.windows.net`). Names are 3–24 lowercase alphanumeric characters with no hyphens. If your preferred name is taken, it is taken by someone else's account anywhere in the world.

One concrete trap: a Standard general-purpose v2 account supports all tiers and services, but a Premium block blob account cannot serve Azure Files. Plan the account type before you start provisioning services inside it.

> [!warning] You cannot switch a storage account between Standard and Premium after creation. Migrating requires creating a new account and copying data — plan your performance tier before you build around it.

@feynman

A storage account is like a database server instance — you configure it once at the top level, and all the databases (services) inside inherit the server's connection limits, backup policy, and network rules whether you think about it or not.

@card
id: azr-ch05-c002
order: 2
title: Blob Storage — Objects, Tiers, and Lifecycle
teaser: Blob Storage is Azure's unstructured object store, and the access tier you assign to a blob directly controls both your latency and your monthly bill

@explanation

Blob Storage has three blob types with distinct write patterns:

- **Block blobs** — optimized for streaming and sequential writes; the default type for files, images, video, backups. Each block blob is composed of up to 50,000 blocks, each up to 4,000 MB, giving a maximum blob size of ~190.7 TB.
- **Append blobs** — write-only at the tail; designed for log files where you're always appending, never modifying earlier content.
- **Page blobs** — random-read/write 512-byte pages; used to back Azure Virtual Machine disks (VHDs).

Access tiers control cost vs latency for block blobs:

- **Hot** — frequent access; highest storage cost, lowest retrieval cost.
- **Cool** — infrequent access (30-day minimum); lower storage cost, higher retrieval cost.
- **Cold** — rare access (90-day minimum); lower storage cost than Cool.
- **Archive** — offline storage; cheapest at rest, but rehydration to Hot or Cool takes up to 15 hours for standard priority (or up to 1 hour with high-priority rehydration at extra cost). Archive blobs cannot be read in place — you must rehydrate first.

Lifecycle management policies let you automate tier transitions and deletions. A typical policy: move blobs to Cool after 30 days of no access, move to Archive after 90 days, delete after 365 days. You write the policy as JSON rules attached to the storage account.

> [!info] Rehydration from Archive is not instant. If your SLA requires data within minutes, Archive is wrong — use Cold or Cool and accept the higher storage cost.

@feynman

Access tiers are like S3 storage classes: you're trading access latency for storage cost per GB, and the Archive tier is the equivalent of Glacier — cheap to park, expensive and slow to retrieve.

@card
id: azr-ch05-c003
order: 3
title: ADLS Gen2 — Blob Storage Built for Analytics
teaser: Azure Data Lake Storage Gen2 is not a separate service — it is Blob Storage with a hierarchical namespace switched on, and that single flag changes everything about how analytics workloads interact with it

@explanation

Standard Blob Storage uses a flat namespace. A "folder" is just a prefix in the blob name (`logs/2024/01/app.log`). Moving or renaming a "folder" requires copying every blob that shares the prefix — an O(n) operation that gets slow at millions of files.

ADLS Gen2 adds a **hierarchical namespace (HNS)**: true directories exist as first-class objects. Renaming a directory is an O(1) metadata operation regardless of how many files are inside. This matters enormously for Spark and Hive jobs that stage intermediate data in directories and rename them atomically on completion.

Other things HNS enables that flat Blob Storage cannot do:

- **POSIX-style ACLs** at the file and directory level, not just RBAC at the container level. You can grant a service principal read access to one subdirectory without exposing the whole container.
- **ABFS driver** (`abfs://`) — a Hadoop-compatible filesystem driver that Azure Databricks, HDInsight, and Synapse Analytics use natively. It replaces the older WASB driver (`wasb://`) with a protocol that maps to ADLS Gen2's REST API efficiently.
- **Atomic directory operations** — critical for analytics pipelines that commit results by renaming a staging directory to a final directory.

HNS is enabled at account creation and cannot be toggled after the fact on existing data. The storage account must use the StorageV2 kind.

> [!tip] If you are building any analytics workload — Databricks, Synapse, or custom Spark — enable HNS from the start. Retrofitting it onto a blob account with existing data requires a migration.

@feynman

Enabling the hierarchical namespace is like switching from a filesystem that stores everything in one flat directory (with path-as-filename tricks) to a real filesystem — the data is the same, but the operations the OS exposes are fundamentally different.

@card
id: azr-ch05-c004
order: 4
title: Azure Files — Managed File Shares for Lift-and-Shift
teaser: Azure Files gives you a fully managed SMB or NFS share that you can mount on VMs, containers, or on-premises servers without running a file server yourself

@explanation

Azure Files is the right service when your workload assumes a shared filesystem — legacy apps that write to `\\server\share`, lift-and-shift migrations from on-prem NAS, or containerized apps that need a ReadWriteMany persistent volume.

Protocol support:
- **SMB 3.0/2.1** — the default; mounts on Windows, Linux, and macOS.
- **NFS 4.1** — available only on Premium file shares; requires a VNet with a service endpoint or private endpoint (NFS traffic is not encrypted in transit at the protocol level, so network isolation is required).

Tiers:
- **Transaction Optimized, Hot, Cool** — all on Standard (HDD); Transaction Optimized is the default for most workloads.
- **Premium** — SSD-backed, low latency; priced on provisioned capacity rather than used capacity.

**Azure File Sync** extends Azure Files to on-premises Windows Server. You install the agent, register the server, and configure cloud tiering: files accessed recently stay local; cold files are replaced with a reparse point (a stub) and pulled from Azure on demand. This gives you a limitless on-prem file server where the hot working set stays local and the cold tail lives in Azure. The sync endpoint is the Azure file share itself — not a blob container.

> [!tip] If you need a shared drive that both VMs in Azure and servers in your datacenter can see simultaneously, Azure File Sync is the intended solution — not replicating the share at the OS level.

@feynman

Azure Files with File Sync is like having a distributed cache in front of blob storage: the local server holds the hot working set, and the cloud holds the full dataset, with transparent cache-miss fills.

@card
id: azr-ch05-c005
order: 5
title: Azure Queue Storage — Simple Distributed Work Queue
teaser: Queue Storage is the lowest-overhead way to decouple producers from consumers in Azure — no broker clusters to manage, no per-message routing rules, just enqueue and dequeue

@explanation

Queue Storage is a simple HTTP-accessible queue. Producers POST messages; consumers GET messages, process them, and DELETE them to acknowledge. The design is deliberately minimal:

- **Max message size:** 64 KB. If you need larger payloads, store the payload in Blob Storage and put the blob URL in the message.
- **Max TTL:** 7 days (the default). You can set up to 7 days explicitly; messages that expire are automatically discarded.
- **Visibility timeout:** when a consumer dequeues a message, it becomes invisible to other consumers for a configurable window (default 30 seconds). If the consumer crashes before deleting it, the message reappears after the timeout and can be picked up by another worker. This is the at-least-once delivery guarantee — your consumers must be idempotent.
- **Max queue depth:** ~500 TB worth of messages.

When to use Queue Storage vs Azure Service Bus:

- Queue Storage — simple FIFO, dead-letter not required, message size under 64 KB, costs essentially nothing, SDK support in every Azure language client.
- Service Bus — you need topics/subscriptions (pub-sub fan-out), dead-letter queues, duplicate detection, sessions for ordered processing, or message sizes up to 256 KB (standard) or 100 MB (premium).

Queue Storage URL format: `https://<account>.queue.core.windows.net/<queue-name>`.

> [!info] At-least-once delivery means duplicate processing is possible. Build consumers that handle the same message twice without side effects before you rely on Queue Storage in a financial or inventory-sensitive workflow.

@feynman

Queue Storage's visibility timeout is the same pattern as SQS — the message isn't gone until you explicitly delete it, so a crashed worker's message automatically returns to the queue like an unacknowledged TCP segment triggering a retransmit.

@card
id: azr-ch05-c006
order: 6
title: Azure Table Storage — Cheap NoSQL Key-Value at Scale
teaser: Table Storage is a schemaless NoSQL store optimized for fast point lookups by composite key — when you need cheap, durable key-value storage and don't need Cosmos DB's global distribution or SLAs

@explanation

Every entity in Table Storage has three system properties: `PartitionKey`, `RowKey`, and `Timestamp`. The combination of `PartitionKey + RowKey` is the primary key — globally unique within the table and used for all indexed lookups. Entities in the same partition are stored together and can be retrieved in a single round trip.

Consistency model:
- **Within a partition:** strong consistency. Writes are immediately visible to subsequent reads from any client.
- **Cross-partition:** eventual consistency. A write to one partition may not immediately reflect in a scan across partitions.

Typical query patterns that perform well:
- Point lookup by exact `PartitionKey + RowKey` — O(1), very fast.
- Range scan within a single partition — fast; all data is co-located.
- Full table scans or cross-partition queries — slow; Table Storage has no secondary indexes. Filter on non-key properties requires a full scan.

Table Storage costs ~$0.045 per GB/month (Standard LRS). It is dramatically cheaper than Cosmos DB for simple workloads. The right time to upgrade to Cosmos DB Table API:
- You need global multi-region writes.
- You need 99.999% availability SLA.
- You need single-digit millisecond reads at the 99th percentile.
- You need secondary indexes on non-key properties.

Table Storage endpoints: `https://<account>.table.core.windows.net/<table>`.

> [!warning] Scanning a table on a non-key property is a full table scan with per-request charges. Design your PartitionKey and RowKey access pattern before inserting data — changing the key schema requires a full table rewrite.

@feynman

Table Storage is like DynamoDB Lite — same composite key design and partition-local consistency guarantees, but without DynamoDB's global tables, GSIs, or sub-millisecond p99 SLA.

@card
id: azr-ch05-c007
order: 7
title: Managed Disks — Block Storage for VMs
teaser: Azure Managed Disks abstract away the storage account plumbing behind VM disks and give you SSD tiers, shared disks for clustering, and Ultra Disk for latency-sensitive workloads

@explanation

Before Managed Disks, VM disks were VHD blobs in storage accounts you managed. Managed Disks remove that: Azure handles placement, replication, and scaling. You provision a disk and attach it to a VM; Azure handles the rest.

Disk tiers by performance:

- **Standard HDD (S-series)** — dev/test workloads, non-critical backups. Up to 500 IOPS and 60 MB/s per disk.
- **Standard SSD (E-series)** — web servers, lightly used apps. Consistent latency improvement over HDD at modest cost increase. Up to 6,000 IOPS for E80.
- **Premium SSD (P-series)** — production databases, latency-sensitive apps. P80 reaches 20,000 IOPS and 900 MB/s. Requires a VM size with Premium Storage support.
- **Ultra Disk** — when nothing else is fast enough. Sub-millisecond latency, configurable IOPS (up to 160,000) and throughput (up to 4,000 MB/s) independent of disk size. Not available in all regions; cannot be used as an OS disk; cannot be snapshotted.

**Disk bursting** lets smaller P/E disks burst above their baseline IOPS for short periods using a credit model (P1–P20 burst to 3,500 IOPS; credit-based bursting).

**Shared disks** allow a single managed disk to be attached to multiple VMs simultaneously, enabling Windows Server Failover Clustering and similar HA patterns. Shared disks are available on Premium SSD and Ultra Disk.

**Snapshots** are point-in-time copies; you can export a snapshot as a VHD to a storage account or create a new disk from it.

> [!info] Ultra Disk IOPS and throughput are billed separately from the provisioned size. You can provision 1 TB and configure 80,000 IOPS — or 500 IOPS. You pay for what you configure, not what you use, so right-size the performance tier at provision time.

@feynman

Managed Disks are like EBS volumes: you pick a type and size, attach to an instance, and the underlying storage placement is Azure's problem — but the IOPS ceiling you buy at provisioning is the ceiling you get.

@card
id: azr-ch05-c008
order: 8
title: Blob Storage Security — SAS, Managed Identity, and Firewalls
teaser: Shared access signatures let you grant scoped, time-limited access to specific blobs or containers without handing out account keys — and managed identity lets you skip credentials entirely

@explanation

Azure Blob Storage access control has three layers you will use in practice:

**Shared Access Signatures (SAS)** are signed URL tokens that grant specific permissions on specific resources for a specific time window. Three variants:

- **Service SAS** — scoped to one service (Blob, Queue, Table, or Files). Signed with the account key.
- **Account SAS** — spans multiple services and resource types in one account. Signed with the account key.
- **User Delegation SAS** — scoped to Blob or Data Lake only. Signed with an Entra ID (AAD) credential rather than the account key. This is the most secure variant: the key is never exposed, and you can revoke it by revoking the user delegation key rather than rotating the account key.

**Stored access policies** let you define SAS parameters (permissions, expiry) server-side and reference the policy ID in the SAS token. Revoking the policy revokes all tokens that reference it — without rotating the account key. Use stored access policies for any SAS token you intend to distribute broadly.

**Managed identity + RBAC** is the preferred pattern for service-to-service access. Assign a managed identity to your VM, Function, or AKS pod, then assign it a Storage Blob Data Reader or Storage Blob Data Contributor role on the container. No credentials are stored or rotated; the identity is bound to the resource lifecycle.

**Storage firewall and private endpoints** control network access: whitelist specific IP ranges, VNet subnets, or disable public access entirely and require a private endpoint inside your VNet.

> [!warning] Account keys give unrestricted access to every service in the account and cannot be scoped. Avoid distributing account keys in application code or config files — use SAS tokens with minimal permissions or managed identity instead.

@feynman

A User Delegation SAS is like a signed JWT scoped to a single API endpoint with an expiry — the server validates the signature without needing to store the token, and you revoke it by invalidating the signing key rather than changing the password.

@card
id: azr-ch05-c009
order: 9
title: Storage Redundancy — LRS, ZRS, GRS, GZRS
teaser: Azure replicates your storage data automatically — the redundancy tier you choose determines how many datacenters are involved, in how many regions, and what happens to your reads during a regional failure

@explanation

Azure Storage always writes at least 3 copies. Where those copies live depends on the redundancy option:

- **LRS (Locally Redundant Storage)** — 3 copies within a single datacenter in the primary region. Protects against disk and rack failure; does not protect against datacenter-level failure. Cheapest option (~$0.018/GB for Standard). Durability: 11 nines (99.999999999%).
- **ZRS (Zone-Redundant Storage)** — 3 copies each in a separate Availability Zone in the primary region. Protects against AZ failure; data remains accessible if one zone goes down. Durability: 12 nines. ~25% premium over LRS.
- **GRS (Geo-Redundant Storage)** — LRS in the primary region plus async replication to LRS in a paired secondary region. Protects against regional disaster. Data in the secondary region is readable only after Microsoft initiates a failover — you cannot read from it during normal operation. Durability: 16 nines.
- **GZRS (Geo-Zone-Redundant Storage)** — ZRS in the primary plus async replication to LRS in a paired secondary. Combines AZ-level and regional-level protection. Most expensive standard tier.
- **RA-GRS / RA-GZRS** — Read-Access variants. Same replication as GRS/GZRS, but the secondary endpoint is readable during normal operation (with eventual consistency). Your secondary read endpoint URL is `<account>-secondary.blob.core.windows.net`.

RTO/RPO tradeoff: GRS and GZRS protect your data from a regional outage, but the RPO for async replication is typically under 15 minutes in normal conditions. During a failover, recently written data not yet replicated will be lost.

> [!info] The secondary endpoint in RA-GRS returns data that may be behind the primary by seconds to minutes. Design applications that read from the secondary to tolerate stale reads — it is not a read replica with strong consistency.

@feynman

LRS, ZRS, GRS, and GZRS map directly to the replication topology you would design manually for a database: single-DC RAID, multi-AZ synchronous commit, async cross-region standby, and async cross-region standby with AZ fault isolation in the primary.

@card
id: azr-ch05-c010
order: 10
title: AzCopy and Data Transfer — Moving Data In and Out
teaser: AzCopy is the purpose-built CLI for bulk Azure Storage transfers, and for anything that won't fit in a reasonable network window, Azure Data Box ships a physical appliance to your datacenter

@explanation

**AzCopy** is Microsoft's recommended tool for transferring data to and from Azure Storage. It transfers data using the Azure Storage REST API and runs concurrent transfers internally, saturating your network link more efficiently than copying file by file.

Core commands:

- `azcopy copy <source> <destination>` — copy blobs, files, or local directories. Supports wildcards and recursive flags.
- `azcopy sync <source> <destination>` — incremental sync; only transfers changed files. Useful for ongoing replication rather than one-time migrations.
- `azcopy list <container-url>` — list blobs in a container.
- `azcopy jobs show <job-id>` — monitor a running or completed job.

Authentication options:

- **OAuth (Entra ID):** run `azcopy login`, authenticate interactively or via service principal. No credentials in command-line arguments; tokens are cached. Recommended for user-initiated operations.
- **SAS token:** append `?<SAS>` to the storage URL. Works without a login session; suitable for scripted pipelines where interactive auth is not possible.

AzCopy supports server-side copy between Azure Storage accounts — data flows through Azure's backbone network, not through your machine. Useful for migrating between accounts or regions without paying egress costs.

**Azure Data Box** is the offline migration path for large datasets (typically 40 TB or more) where network transfer would take weeks. Microsoft ships you a ruggedized appliance (80 TB usable for Data Box; up to 800 TB for Data Box Heavy), you load data onto it in your datacenter, ship it back, and Microsoft uploads it to your storage account. The service encrypts data with AES-256 and the encryption key never leaves your control. This is Azure's answer to AWS Snowball.

> [!tip] For one-time migrations under roughly 40 TB with a reliable network connection, AzCopy with a SAS token is usually the fastest path. Above that threshold, run the numbers on Data Box: appliance rental is often cheaper than egress fees and weeks of network bandwidth.

@feynman

AzCopy is to Azure Storage what rsync is to Linux file systems — the same sync-not-copy mental model, but the transport layer is the Azure backbone instead of SSH.
