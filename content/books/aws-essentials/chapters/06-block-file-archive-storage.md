@chapter
id: aws-ch06-block-file-archive-storage
order: 6
title: Block, File, and Archive Storage
summary: AWS offers six distinct storage categories — block, file, object, archive, hybrid, and physical transfer — and matching your workload to the right one is the decision that separates a cost-efficient, performant architecture from one you'll regret at scale.

@card
id: aws-ch06-c001
order: 1
title: EBS Volume Types and When to Use Each
teaser: Picking the wrong EBS volume type is a quiet performance tax — gp3, gp2, io2, st1, and sc1 each have a different cost and IOPS model, and the right choice depends on your workload's access pattern

@explanation

EBS offers five volume types, and each targets a different part of the performance/cost spectrum:

- **gp3 (General Purpose SSD):** The default for most workloads. Baseline 3,000 IOPS and 125 MB/s throughput included at no extra cost, regardless of volume size. You can independently scale IOPS up to 16,000 and throughput up to 1,000 MB/s for an additional charge. This decoupling from size is the key advantage over gp2 — you don't have to over-provision capacity to get IOPS.
- **gp2 (General Purpose SSD, legacy):** Runs a burst bucket model — you earn 3 IOPS per GB of storage, and a credit system allows burst up to 3,000 IOPS for small volumes. Max is 16,000 IOPS at 5,333 GB. The model punishes small volumes with variable performance. For new workloads, prefer gp3.
- **io2 Block Express (Provisioned IOPS SSD):** Purpose-built for I/O-intensive databases (Oracle, SQL Server, high-throughput NoSQL). Supports up to 256,000 IOPS and 4,000 MB/s throughput per volume with 99.999% durability (vs 99.8–99.9% for gp3). Costs roughly 3–4x gp3 — justified only when single-digit millisecond consistent latency is a hard requirement.
- **st1 (Throughput Optimized HDD):** Sequential workloads: log processing, data warehouse ETL, big data. Max 500 IOPS and 500 MB/s, but cost is ~40% of gp3 for equivalent capacity. Not suitable for random access.
- **sc1 (Cold HDD):** The cheapest EBS option at ~$0.015/GB/month. Max 250 IOPS and 250 MB/s. Use it for infrequently accessed sequential data — backups you rarely read, archival copies, compliance-mandated cold data.

> [!tip] If you're running a new workload and defaulting to gp2, stop. gp3 is cheaper per GB and lets you tune IOPS independently. The only reason to stay on gp2 is an existing volume you haven't migrated yet.

@feynman

Choosing between gp3 and io2 is like choosing between a general-purpose web server and a dedicated database server — the price gap only makes sense if the latency requirements genuinely justify it.

@card
id: aws-ch06-c002
order: 2
title: EBS Snapshots — Incremental, Cross-Region, and Fast Restore
teaser: EBS snapshots are more than a backup mechanism — they're the foundation for AMIs, cross-region DR, and lifecycle automation, and they have operational gotchas worth knowing before your first restore under pressure

@explanation

EBS snapshots are stored in S3 (managed by AWS, not visible in your bucket) and work incrementally: the first snapshot copies all used blocks, and each subsequent snapshot stores only blocks that changed since the last one. A volume with 100 GB used that has only a 5 GB daily change rate costs you 100 GB for snapshot 1 and ~5 GB per day thereafter.

Key mechanics and workflows:

- **Snapshot to AMI:** You can register a snapshot as an AMI to create a launchable machine image. This is how you bake golden AMIs — snapshot a configured instance, register it, launch identical copies across regions.
- **Cross-region copy:** Use `CopySnapshot` to replicate snapshots to another region. This is a foundational DR pattern — RPO is determined by how frequently you snapshot and replicate. Cross-region copies are independent copies, not references.
- **AWS DLM (Data Lifecycle Manager):** Create policies that automate snapshot creation, retention, and cross-region copy on a schedule. A typical policy: daily snapshot at 03:00, retain 7 days, copy to `us-west-2`. Without DLM, snapshot management becomes a manual operational burden at scale.
- **Fast Snapshot Restore (FSR):** When you restore an EBS volume from a snapshot, AWS uses lazy loading — blocks are pulled from S3 on first access, which can cause spiky latency until the volume is fully hydrated. FSR pre-warms the volume in a specific AZ so it delivers full IOPS immediately. It costs extra (per-AZ, per-hour) and makes sense for time-sensitive restores like recovering a production database.

> [!warning] If you've never tested a restore from snapshot in your environment, your backup strategy is theoretical. FSR aside, first-access latency on a cold restore can spike 5–10x normal for large volumes.

@feynman

Incremental snapshots are like Git commits — each snapshot is a diff, and restoring is replaying the chain, except AWS handles the merge and you just get the final volume.

@card
id: aws-ch06-c003
order: 3
title: Amazon EFS — Shared File System for Linux Workloads
teaser: EFS gives you a managed NFS file system that multiple EC2 instances can mount simultaneously — which is the thing EBS fundamentally cannot do, and the reason EFS exists

@explanation

EBS volumes are attached to one EC2 instance at a time (io2 supports multi-attach but with significant constraints). When you need multiple instances to read and write the same file system — shared application state, CMS assets, machine learning training data, developer home directories — you need EFS.

EFS runs NFSv4.1/4.2 and scales storage automatically. You don't provision capacity; you pay for what you use (~$0.30/GB/month for Standard, ~$0.16/GB/month for One Zone).

**Storage tiers:**
- **Standard (multi-AZ):** Data is stored redundantly across multiple AZs. Use for production data that must survive an AZ failure.
- **One Zone:** Data lives in a single AZ. ~50% cheaper. Acceptable for dev/test or workloads with data you can reconstruct.

**Performance modes:**
- **General Purpose (default):** Low latency, suitable for most use cases. Cap at ~35,000 IOPS.
- **Max I/O:** Higher throughput and parallelism, but higher latency per operation. Use for highly parallelized workloads (hundreds of EC2 clients, Hadoop, etc.) that are throughput-bound, not latency-bound.

**Throughput modes:**
- **Elastic (recommended):** Automatically scales throughput up and down. Pay for what you use. Best default.
- **Provisioned:** Set a fixed throughput level (useful if your workload bursts unpredictably and Elastic pricing surprises you).
- **Bursting:** Throughput scales with storage size (50 MB/s per TB). Only makes sense for large file systems with bursty access patterns.

> [!info] EFS is Linux-only (NFS). If your workload runs on Windows and needs shared file storage, you want FSx for Windows File Server, not EFS.

@feynman

EFS is the distributed file system you'd build yourself on top of NFS — except you don't have to manage the servers, the replication, or the capacity planning.

@card
id: aws-ch06-c004
order: 4
title: Amazon FSx — Managed File Systems for Every Protocol
teaser: FSx is four different managed file systems under one brand — Windows SMB, Lustre for HPC, NetApp ONTAP, and OpenZFS — and the right flavor depends entirely on what your application already speaks

@explanation

FSx exists because EFS only speaks NFS and only runs on Linux. Many workloads need SMB, or an HPC-grade parallel file system, or multi-protocol access, or a specific feature set they've already built on. FSx wraps those in managed infrastructure so you don't run the servers yourself.

**FSx for Windows File Server:**
- Full SMB 3.0/3.1.1, Active Directory integration, NTFS, DFS namespaces.
- The lift-and-shift target for Windows workloads that currently mount a NAS or Windows file server on-premises.
- Supports shadow copies (VSS-based backups) and deduplication.

**FSx for Lustre:**
- Parallel file system built for HPC — ML training, computational fluid dynamics, rendering, genomics.
- Sub-millisecond latency, up to hundreds of GB/s aggregate throughput.
- Native S3 integration: you can link an S3 bucket as the backing data source, read from it lazily, and export results back. This keeps your persistent storage cheap (S3) while giving your compute jobs fast scratch storage (Lustre).

**FSx for NetApp ONTAP:**
- Multi-protocol (NFS, SMB, iSCSI) in a single file system.
- The migration target for on-premises NetApp users who want to move to AWS without re-platforming.
- Supports snapshots, SnapMirror replication, storage efficiency (dedup, compression, tiering).

**FSx for OpenZFS:**
- NFS-based, but with ZFS semantics: snapshots, clones, compression.
- Low-latency workloads (sub-millisecond) that need NFS and ZFS data management features.
- Good fit for migrating Linux workloads currently on ZFS.

> [!tip] If your team is coming from an on-premises environment, the FSx flavor to pick is usually the one that matches what you already run — SMB → FSx for Windows, NFS + ONTAP → FSx for NetApp ONTAP, Lustre → FSx for Lustre. Don't re-architect the storage layer as part of your lift-and-shift.

@feynman

FSx is like having four different database engines offered as managed services — you don't pick the best one in the abstract, you pick the one that speaks the protocol your application already uses.

@card
id: aws-ch06-c005
order: 5
title: AWS Storage Gateway — Bridging On-Premises to the Cloud
teaser: Storage Gateway puts an AWS storage endpoint inside your data center so your existing on-premises applications can write to S3, S3 Glacier, or EBS without changing a line of code

@explanation

Storage Gateway runs as a VM (or hardware appliance) on-premises and presents a standard storage interface locally while asynchronously backing or caching data to AWS. It's the answer to "I need to use AWS storage, but my application is on-premises and I can't migrate it yet."

Three gateway modes:

**File Gateway:**
- Presents an NFS or SMB mount point to your on-premises servers.
- Files written to that mount are stored as objects in S3 (one file = one S3 object).
- A local cache tier keeps recently accessed files on disk for low-latency reads.
- Use case: replacing a NAS while keeping the same NFS interface, cloud-backing file shares, content repositories.

**Volume Gateway:**
- Presents iSCSI block volumes to your servers.
- Two sub-modes:
  - **Cached volumes:** primary data in S3, frequently accessed data cached on-premises. Up to 32 TB per volume.
  - **Stored volumes:** primary data on-premises, asynchronously backed up to S3 as EBS snapshots. Low-latency access to full dataset.
- Use case: DR for on-premises servers (snapshots become EBS volumes you can restore in EC2), extending block storage to AWS.

**Tape Gateway:**
- Presents a virtual tape library (VTL) interface via iSCSI to existing backup software (Veeam, Backup Exec, NetBackup).
- Virtual tapes stored in S3; "archived" tapes go to Glacier.
- Use case: replacing physical tape infrastructure without changing the backup software or workflow.

> [!info] Storage Gateway is a hybrid integration pattern, not a migration tool. The goal is to let legacy on-premises workloads use AWS storage durably and cheaply while you work toward a longer-term cloud migration.

@feynman

Storage Gateway is an adapter pattern — it translates the protocol your existing application speaks (NFS, iSCSI, VTL) into the API AWS storage actually uses, invisibly, at the edge.

@card
id: aws-ch06-c006
order: 6
title: AWS Snow Family — Physical Data Transfer at Scale
teaser: When your internet connection would take more than a week to move your data to AWS, the fastest network path is a truck — and AWS has three hardware options sized from terabytes to 100 petabytes

@explanation

The Snow family solves a simple math problem: at 100 Mbps sustained, transferring 100 TB to S3 takes about 100 days. That's not a theory — it's the actual timeline for many enterprises with multi-terabyte on-premises datasets. Physical shipping is faster.

**Snowcone (smallest):**
- 8 TB usable HDD (14 TB usable SSD variant also available).
- Rugged, 4.5 lb, designed for edge compute in harsh environments (military, remote sites, IoT).
- Also runs AWS DataSync and small EC2 instances for edge processing.
- Use case: small data transfers, edge compute where connectivity is intermittent.

**Snowball Edge:**
- 80 TB usable (Storage Optimized) or 42 TB usable with more compute (Compute Optimized, includes GPU option).
- Supports S3-compatible API, NFS, and SMB interfaces locally for seamless application integration.
- Can run EC2 instances and Lambda functions locally for preprocessing before transfer.
- Use case: large-scale migration (hundreds of TB), edge processing where you need local compute plus bulk transfer.

**Snowmobile:**
- A literal 45-foot shipping container pulled by a semi-truck, holding up to 100 PB.
- AWS sends the truck to your data center, you fill it, AWS drives it back to an AWS region.
- Use case: data center migrations at exabyte scale (e.g., a large media company moving a petabyte-scale video archive).

The decision rule AWS states explicitly: if transferring over the network would take more than one week, use Snow.

> [!warning] Snow devices are encrypted (256-bit AES), and the keys never leave AWS KMS — but you are responsible for physical chain of custody while the device is on-site and in transit. Treat it like a hard drive containing your most sensitive data, because it is.

@feynman

Snow is the same principle as deploying a read replica close to users to reduce latency — except instead of reducing query latency, you're reducing transfer time from months to days by moving the storage physically.

@card
id: aws-ch06-c007
order: 7
title: AWS Backup — Centralized Backup Across AWS Services
teaser: AWS Backup is a single control plane for backup policies, schedules, and retention rules across EBS, RDS, DynamoDB, EFS, FSx, S3, and more — replacing the per-service backup configuration that becomes unmanageable at scale

@explanation

Before AWS Backup, configuring backups meant navigating six different service-specific backup mechanisms. AWS Backup centralizes this into a single API and console with consistent policy primitives.

**Core concepts:**

- **Backup plan:** A set of rules defining what to back up, how often (cron or rate expression), and how long to retain. Example: daily backup at 02:00 UTC, retain 35 days, copy to `eu-west-1` weekly.
- **Backup vault:** An encrypted container where backups are stored. You can create multiple vaults with different encryption keys and access policies. Vaults can be locked with a retention policy that prevents any principal (including root) from deleting backups before the retention period expires — this satisfies ransomware-protection requirements.
- **Resource assignment:** Assign resources to a backup plan by tag or by ARN. Tag-based assignment (e.g., `backup:daily=true`) scales cleanly — new resources with the right tag are automatically covered without updating the plan.

**Cross-region and cross-account backup:**
- You can copy backup recovery points to another region for DR.
- Cross-account backup copies vaults into a separate AWS account — useful for protecting against accidental or malicious deletion in the source account.

**Compliance reporting:**
- AWS Backup Audit Manager generates compliance reports showing which resources are covered by backup plans, whether backups completed successfully, and whether vault locks are in place.
- Reports export to S3 and integrate with Athena for querying.

Supported services include EBS, RDS (all engines), Aurora, DynamoDB, EFS, FSx, S3, EC2 instances, Storage Gateway volumes, and more.

> [!tip] Use vault lock for any backup vault that stores regulated or compliance-sensitive data. Once locked in compliance mode, not even your own IAM admin can delete the vault or shorten retention — which is the point.

@feynman

AWS Backup is like a centralized CI/CD pipeline for backups — instead of each team writing their own backup scripts and cron jobs with different retention logic, you define the policy once and the platform applies it consistently.

@card
id: aws-ch06-c008
order: 8
title: S3 Glacier and Archive Tiers — Cold Storage and Compliance
teaser: Glacier is not one thing — it's three retrieval speed tiers with radically different costs and latencies, and choosing the wrong one either wastes money or introduces hours of delay when you actually need your data

@explanation

S3 Glacier covers three distinct storage classes, all designed for data you write once and rarely read. The tradeoff across all three is simple: slower retrieval = cheaper storage.

**S3 Glacier Instant Retrieval:**
- Retrieval in milliseconds (same as Standard S3 reads).
- $0.004/GB/month — about 68% cheaper than S3 Standard.
- Minimum storage duration: 90 days.
- Use case: compliance archives, medical imaging, news media — data you might not touch for months but occasionally need immediately.

**S3 Glacier Flexible Retrieval (formerly "S3 Glacier"):**
- Three retrieval speeds: Expedited (1–5 minutes, higher cost), Standard (3–5 hours, lower cost), Bulk (5–12 hours, lowest cost).
- $0.0036/GB/month.
- Minimum storage duration: 90 days.
- Use case: backup and DR archives where a multi-hour retrieval window is acceptable.

**S3 Glacier Deep Archive:**
- Retrieval in 12–48 hours.
- ~$0.00099/GB/month — roughly $1/TB/month, the cheapest durable storage AWS offers.
- Minimum storage duration: 180 days.
- Use case: regulatory retention data, audit logs you must keep for 7 years but will almost never read, tape replacement.

**Vault Lock (compliance immutability):**
You can apply a Vault Lock policy to a Glacier vault using a Write Once Read Many (WORM) model. Once locked, the policy cannot be deleted or modified — not by IAM admins, not by root. This satisfies SEC Rule 17a-4 and similar financial compliance requirements.

Lifecycle rules in S3 automatically transition objects to colder tiers over time: Standard → Intelligent-Tiering → Glacier Instant Retrieval → Glacier Flexible Retrieval → Deep Archive.

> [!warning] Glacier retrieval has per-GB retrieval fees on top of storage costs. For Flexible Retrieval Expedited, retrieval can cost more than a month of storage. Always model total cost (storage + expected retrieval frequency) before choosing a tier.

@feynman

Glacier tiers are like cache eviction levels — the data is still there, but how long it takes to page it back in depends on which tier it settled into, and paging it back from Deep Archive is measured in hours, not milliseconds.

@card
id: aws-ch06-c009
order: 9
title: AWS DataSync — Accelerated Hybrid Data Transfer
teaser: DataSync is an agent-based transfer service that moves data between on-premises storage and AWS at up to 10 Gbps per agent, with task scheduling, filtering, and verification built in — purpose-built for the hybrid migration pattern

@explanation

DataSync solves the problem of getting large amounts of data from on-premises NAS, NFS, SMB, HDFS, or object storage into AWS (S3, EFS, FSx) reliably and at speed. It's not a manual rsync — it handles parallelism, checksums, and scheduling.

**Architecture:**
- Deploy a DataSync agent (a VM) on-premises or in your colocation.
- Create a task: define a source location, a destination location, and transfer settings.
- DataSync parallelizes transfers internally, verifying data integrity end-to-end with checksums.
- One agent can achieve up to 10 Gbps throughput (limited by your network, not DataSync itself).

**Key features:**
- **Scheduling:** Run tasks on a recurring schedule (hourly, daily) or on-demand.
- **Bandwidth throttling:** Set a maximum bandwidth window to avoid saturating your internet link during business hours.
- **Filtering:** Include or exclude files by name, extension, or modification time.
- **Incremental transfers:** After the initial full transfer, subsequent runs only move changed files.
- **Same-region transfers:** DataSync also moves data between AWS services in the same region (e.g., S3 to EFS, EFS to FSx) — useful for data lake reshaping without involving on-premises.

**DataSync vs S3 Transfer Acceleration:**
- **S3 Transfer Acceleration** optimizes client-to-S3 uploads over the public internet by routing through AWS edge locations. It's for same-cloud or client-initiated uploads, not agent-based hybrid transfers.
- **DataSync** is for agent-mediated on-premises-to-AWS (or AWS-to-AWS) transfers with orchestration, scheduling, and verification. These solve different problems.

> [!info] DataSync is a migration and sync tool, not a real-time replication tool. If you need sub-second replication of block storage, you want Storage Gateway or a database-native replication mechanism, not DataSync.

@feynman

DataSync is like a managed parallel rsync — it handles the split-brain problem of "did everything actually arrive?" by running checksums on both ends, and it schedules itself so you don't have to write cron jobs.

@card
id: aws-ch06-c010
order: 10
title: Choosing the Right Storage Type
teaser: AWS has six storage categories and the right answer is almost always obvious once you understand three questions — who accesses it, how often, and does it need a file system or just a URL

@explanation

The single most common storage mistake is reaching for S3 for everything, or mounting an EBS volume where EFS belongs, because the engineer didn't think through the access pattern. Here's the decision framework:

**Block storage (EBS, instance store):**
- Single-instance access (one EC2 or one container).
- Needs a traditional file system or raw block device.
- Use cases: OS root volumes, relational databases (MySQL, PostgreSQL data directory), high-IOPS applications.
- Wrong choice signals: you need two instances to write to the same volume simultaneously (EBS can't do this; use EFS).

**File storage (EFS, FSx):**
- Multiple instances need concurrent read/write access to the same directory tree.
- Use cases: shared application code, CMS assets, ML training datasets read by a fleet, Windows home drives.
- Wrong choice signals: only one instance ever accesses it (you're paying for shared-access overhead you don't need — use EBS instead).

**Object storage (S3):**
- Unstructured data at any scale, accessed via HTTP API (not a file system mount).
- Use cases: static assets, backups, data lake raw storage, application artifacts, logs.
- Wrong choice signals: your application tries to use S3 like a file system with many small sequential writes (terrible performance — use EFS or EBS).

**Archive storage (Glacier):**
- Data you must retain but almost never read.
- Use cases: compliance archives, audit logs, replaced tape backups.
- Wrong choice signals: you're archiving data you might need within the hour (use Glacier Instant Retrieval or just S3 Intelligent-Tiering).

**Common wrong choices and their symptoms:**
- S3 for a database backend → high latency, not designed for transactional access.
- EBS for shared state across multiple EC2 → works until you try to attach to a second instance and get an error.
- Glacier Deep Archive for data you query monthly → 48-hour retrieval plus per-GB retrieval fees.
- EFS for a single-instance high-IOPS database → NFS overhead where you needed raw block performance.

> [!info] S3 Intelligent-Tiering is an underused escape hatch for uncertain access patterns — it automatically moves objects between access tiers based on actual usage, eliminating the cost of over-storing hot data in Standard or wrongly classifying data as cold.

@feynman

Picking storage is like picking the right data structure — a linked list isn't wrong, it's just wrong for random access; matching the access pattern to the abstraction is the whole job.
