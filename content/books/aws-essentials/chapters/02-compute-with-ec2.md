@chapter
id: aws-ch02-compute-with-ec2
order: 2
title: Compute with EC2
summary: EC2 is AWS's foundational compute service — understanding instance types, purchasing options, storage, networking, and scaling is the prerequisite for architecting almost anything else on AWS.

@card
id: aws-ch02-c001
order: 1
title: EC2 Instance Types and Families
teaser: The instance name is a compact spec sheet — once you can read `m7g.xlarge` you know the workload fit, generation, chip architecture, and size before you open a single pricing page.

@explanation

Every EC2 instance name follows the same pattern: `<family><generation><attributes>.<size>`. For example, `m7g.xlarge` means:

- `m` — general-purpose family (balanced CPU/memory)
- `7` — 7th generation
- `g` — Graviton (AWS-designed ARM processor)
- `xlarge` — 4 vCPU / 16 GB RAM

The main families and their intended workloads:

- **m** (general-purpose) — web servers, small databases, dev environments; no dominant resource constraint
- **c** (compute-optimized) — CPU-heavy work: gaming, batch processing, scientific modeling
- **r** (memory-optimized) — in-memory databases, real-time analytics, SAP HANA; `r7g.16xlarge` gives you 512 GB RAM
- **i** (storage-optimized) — high-IOPS local NVMe, Cassandra, Kafka
- **p / g / trn** (accelerated) — GPU/ML training and inference; `p4d.24xlarge` has 8 x A100 GPUs
- **t** (burstable) — `t3.micro` earns CPU credits at idle, burns them for short spikes; good for low-traffic apps with occasional bursts

Graviton (`g` suffix) instances deliver 20–40% better price-performance for most workloads versus equivalent x86 instances — but require ARM-compatible binaries. Most major Linux distributions and runtimes (Go, Node, Python, Java) publish ARM builds.

> [!tip] Default to Graviton (e.g., `m7g`, `c7g`) for new workloads unless you have a specific x86 dependency. The price-performance gap is real and it compounds at scale.

@feynman

Reading an instance type is like reading a Docker image tag — the name encodes the base, the variant, and the version so you can predict what you're getting without pulling it.

@card
id: aws-ch02-c002
order: 2
title: Amazon Machine Images (AMIs)
teaser: An AMI is a frozen snapshot of a root volume plus metadata — it's the unit of "what the machine looks like before anyone touches it," and building a good AMI is the difference between a 2-minute launch and a 20-minute one.

@explanation

An AMI contains:

- A root volume snapshot (the OS, installed packages, your application if baked in)
- Launch permissions (who can use it)
- Block device mappings (which volumes to attach at launch)
- A virtualization type (HVM is the current standard)

**AMI sources:**

- **AWS-managed** — Amazon Linux 2023, Ubuntu official, Windows Server; maintained and patched by AWS or the OS vendor
- **AWS Marketplace** — commercial and community AMIs, often with software pre-licensed (e.g., a hardened CIS benchmark image, or a pre-configured Kafka node); some have per-hour software charges on top of instance cost
- **Community AMIs** — public but unvetted; treat with the same caution you'd give an unsigned Docker image from a random user
- **Custom / baked AMIs** — you build these yourself

**The bake workflow** is the recommended pattern for production:

1. Start from a trusted base AMI (AWS-managed or Marketplace).
2. Install your app, runtime dependencies, and config via a tool like Packer or EC2 Image Builder.
3. Run hardening (remove SSH keys, lock root, etc.).
4. Register the result as a new AMI.
5. Use that AMI in your launch template.

Baking means your instances boot ready to serve traffic in under two minutes rather than running a 15-minute bootstrap script on every launch. You can share AMIs across accounts by specifying account IDs in launch permissions, or make them public.

> [!warning] Never share a custom AMI publicly without auditing it for hardcoded credentials, SSH authorized_keys, or application secrets baked into the image.

@feynman

An AMI is a Docker image for a whole machine — same idea of immutable, versioned, buildable from a Dockerfile equivalent (Packer template), and deployable anywhere the runtime supports it.

@card
id: aws-ch02-c003
order: 3
title: EC2 Purchasing Options
teaser: On-demand is the credit card of EC2 — convenient but expensive at scale; Reserved Instances, Savings Plans, and Spot are how you trade flexibility for discounts of 30–90%.

@explanation

**On-demand** — pay per second (Linux) or per hour (Windows), no commitment. Right for: unpredictable workloads, short-term dev, anything you can't commit to. Highest unit price.

**Reserved Instances (RIs)** — 1- or 3-year commitments for a specific instance family, size, and region. Two variants:
- *Standard RIs* — up to 72% discount; locked to the exact instance type
- *Convertible RIs* — up to 66% discount; can exchange for a different instance family/OS mid-term

**Savings Plans** — commitment to a dollar-per-hour spend (e.g., $0.10/hr) rather than a specific instance:
- *Compute Savings Plans* — apply to any EC2 family, size, region, and OS, plus Fargate and Lambda; most flexible, up to 66% discount
- *EC2 Instance Savings Plans* — tied to a specific family in a region; up to 72% discount

**Spot Instances** — use AWS's spare capacity at up to 90% discount. The catch: AWS can reclaim with a 2-minute warning. Right for: stateless workers, batch jobs, ML training checkpointed to S3. A *Spot Fleet* lets you specify a target capacity and have AWS fulfill it across instance types and AZs, improving availability.

**Dedicated Hosts vs Dedicated Instances:**
- *Dedicated Instances* — your instances run on hardware not shared with other AWS accounts; you don't control which physical host
- *Dedicated Hosts* — you rent a specific physical server; required for bring-your-own-license (BYOL) software like Windows Server or SQL Server that licenses to physical sockets

> [!tip] Most mature AWS accounts layer all four: Savings Plans for the steady-state baseline, on-demand for headroom, and Spot for elastic batch workloads. Reserved Instances are mostly superseded by Savings Plans for new commitments.

@feynman

On-demand is a taxi, Reserved Instances are a monthly transit pass, and Spot is a standby flight seat — each pricing model trades flexibility for cost, and you optimize by mixing all three.

@card
id: aws-ch02-c004
order: 4
title: EC2 Placement Groups
teaser: Where your instances land physically changes your latency floor, your fault blast radius, and your throughput ceiling — placement groups let you tell EC2 which of those you care about most.

@explanation

By default EC2 places instances wherever capacity exists. Placement groups override that with explicit placement strategies.

**Cluster placement group** — packs all instances into a single Availability Zone on the same physical rack (or close to it). Result: the lowest possible network latency and highest bandwidth between instances (up to 100 Gbps with enhanced networking). Right for: HPC, tightly coupled parallel jobs, low-latency in-memory grids. Downside: if the rack has a hardware failure, everything fails together.

**Partition placement group** — divides instances into logical partitions, each running on separate racks with independent power and networking. You can have up to 7 partitions per AZ. EC2 tells you which partition each instance is in, so your application can use that metadata for rack-aware replication. Right for: large distributed systems that need fault isolation and want to control replica placement — Kafka, HDFS, HBase.

**Spread placement group** — places each instance on a distinct underlying rack, guaranteeing no two instances share hardware. Limit: 7 instances per AZ per placement group. Right for: small groups of critical instances where you need the maximum possible fault isolation — primary and standby databases, critical control-plane nodes.

The decision rule:
- Need lowest latency → cluster
- Need rack-aware fault domains with many instances → partition
- Need strict instance-level isolation and have ≤7 instances per AZ → spread

> [!warning] You cannot merge placement groups or move running instances between them. Design your placement strategy before launch — retrofitting means replacement.

@feynman

Placement groups are like seating at a circuit board — cluster is all chips packed tight for signal speed, partition is chips grouped by power rail for fault containment, and spread is one chip per rail so no single failure takes more than one.

@card
id: aws-ch02-c005
order: 5
title: User Data and Instance Metadata
teaser: User data is how you hand a bootstrap script to a fresh instance; the IMDS is how the instance looks up its own identity — and IMDSv2 is the version you should be enforcing in 2024.

@explanation

**User data** is a script (or cloud-init config) you attach to a launch request. EC2 runs it once at first boot as root. Common uses:

```bash
#!/bin/bash
yum update -y
yum install -y amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
```

User data is base64-encoded and has a 16 KB size limit. For larger payloads, use user data to pull a script from S3 and execute it. You can view or update user data in the console, but changes only take effect on the next launch of a new instance (not a reboot of an existing one).

**Instance Metadata Service (IMDS)** is an HTTP endpoint at `169.254.169.254` that runs on every EC2 instance. From within the instance:

```bash
# IMDSv2 — token-based, required
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

IMDSv1 used simple GET requests with no auth — any code running on the instance (including SSRF attack payloads) could query it. IMDSv2 requires a PUT to get a session token first, which SSRF attacks (limited to GET) cannot do. Enforce IMDSv2 in your launch template by setting `HttpTokens: required`.

> [!warning] The 2019 Capital One breach exploited IMDSv1 via an SSRF vulnerability to retrieve IAM credentials from the metadata service. Always enforce IMDSv2.

@feynman

User data is the machine's `CMD` in a Dockerfile, and the IMDS is like a sidecar container that knows the pod's own IP, namespace, and service account — available only from within, not from outside.

@card
id: aws-ch02-c006
order: 6
title: EBS Volume Types
teaser: EBS has five volume types that cover completely different use cases — picking the wrong one doesn't just waste money, it can silently cap your application's IOPS.

@explanation

**gp3 (General Purpose SSD)** — the current default. 3,000 IOPS and 125 MB/s baseline, independently scalable up to 16,000 IOPS and 1,000 MB/s without changing volume size. Replaces gp2 for almost all general workloads at lower cost. Always prefer gp3 over gp2 for new volumes.

**gp2 (General Purpose SSD, legacy)** — IOPS are tied to size at 3 IOPS/GB, which means you sometimes over-provision storage just to get more IOPS. Still widely deployed; worth migrating to gp3.

**io2 Block Express** — designed for latency-sensitive, IOPS-hungry workloads. Up to 256,000 IOPS and 4,000 MB/s throughput. Sub-millisecond latency. Use for Oracle, SQL Server, and high-throughput databases. Priced per GB and per provisioned IOPS.

**st1 (Throughput HDD)** — magnetic, optimized for sequential reads. Up to 500 MB/s. Right for: big data, log processing, data warehouses that do large sequential scans. Cannot be a boot volume.

**sc1 (Cold HDD)** — cheapest EBS option. Up to 250 MB/s. Right for: infrequently accessed data archives. Cannot be a boot volume.

**Snapshots** are incremental backups stored in S3 (managed by EBS, not visible in your S3 console). The first snapshot is a full copy; subsequent ones store only changes. You can create AMIs from snapshots, copy snapshots across regions, or restore new volumes from them.

EBS encryption is free, hardware-accelerated, and should be enabled by default at the account level. Set the account-level default in EC2 → Settings → Default EBS encryption.

> [!tip] Enable account-level EBS encryption by default — there is no performance cost and it satisfies most compliance requirements without per-volume configuration.

@feynman

Choosing an EBS volume type is like choosing a database engine — pick the wrong storage primitive for your access pattern (sequential vs random, throughput vs IOPS) and you'll hit a wall that no amount of vertical scaling fixes.

@card
id: aws-ch02-c007
order: 7
title: Instance Store (Ephemeral Storage)
teaser: Instance store gives you NVMe-fast local storage at no extra charge — but it disappears the moment the instance stops, so if you treat it like a disk, you will lose data.

@explanation

Instance store volumes are physical disks (NVMe SSDs on current generation instances) directly attached to the host server running your EC2 instance. They are included in the instance price at no additional charge.

Performance characteristics are exceptional — an `i4i.32xlarge` delivers up to 4 million read IOPS from its 30 TB of local NVMe. No network hop to an EBS service means latency is consistently sub-100 microseconds.

**The critical constraint:** instance store is ephemeral. Data is lost when:

- The instance is **stopped** (even temporarily)
- The instance is **terminated**
- The underlying host hardware **fails**

Data survives a **reboot** of the OS — the instance stays on the same physical host, so the disks remain attached.

Right use cases:
- Temporary buffers: batch job intermediate results, sort scratch space
- Replication-aware distributed systems: Kafka, Cassandra, or Elasticsearch where data is replicated across multiple nodes — losing one node's disk is handled by the application layer
- Read replicas or caches that can be rebuilt from a primary

Wrong use cases:
- Primary database storage
- Any data you cannot reconstruct from another source

The contrast with EBS: EBS is a network-attached block device that persists independently of the instance lifecycle. You can detach an EBS volume from a stopped instance and reattach it elsewhere. You cannot do this with instance store.

> [!warning] Instance store is not listed in the AWS Free Tier and is easy to overlook in architecture diagrams. Mark it explicitly as ephemeral in any architecture doc — engineers inherit systems and assume persistence unless told otherwise.

@feynman

Instance store is RAM that survives a process restart but not a server reboot — blindingly fast when it's there, completely gone when the host goes away.

@card
id: aws-ch02-c008
order: 8
title: EC2 Auto Scaling
teaser: Auto Scaling is not just "add instances when CPU is high" — the policies, warm pools, lifecycle hooks, and instance refresh together let you build a fleet that scales, recovers, and deploys without manual intervention.

@explanation

Auto Scaling has two configuration layers:

**Launch templates** define what gets launched: AMI, instance type, key pair, security groups, user data, EBS config, and IAM instance profile. Launch templates version like code — you can test a new AMI by creating a new version and rolling it out via instance refresh rather than touching running instances.

**Scaling policies** define when to scale:

- *Target tracking* — the simplest and usually the right default. Specify a metric and a target (e.g., keep average CPU at 50%), and Auto Scaling continuously adjusts capacity. Works like a PID controller.
- *Step scaling* — define explicit tiers: at CPU > 60% add 2 instances, at CPU > 80% add 5 instances. Useful when the response needs to be non-linear.
- *Scheduled scaling* — pre-scale before known traffic events (e.g., add 10 instances at 08:00 UTC every weekday).

**Warm pools** solve the cold-start latency problem. Instances in the warm pool are pre-initialized (user data already run, app already loaded) but stopped or running at low cost. When a scale-out event fires, warm pool instances promote to the live fleet in seconds instead of minutes.

**Lifecycle hooks** let you pause an instance during launch or termination to run custom logic — drain connections, deregister from a service mesh, push final logs. The instance waits up to 2 hours (configurable) for a `CONTINUE` or `ABANDON` signal.

**Instance refresh** replaces running instances in a rolling fashion when you update a launch template — like a controlled rolling deployment for your EC2 fleet. You set the minimum healthy percentage (e.g., 90%) and AWS replaces instances in batches.

> [!info] Target tracking with ALB request count per target is often more accurate than CPU for web fleets — CPU can stay low while the application is saturated on I/O or thread pool limits.

@feynman

Auto Scaling with lifecycle hooks is like Kubernetes rolling deployments with readiness probes — the system waits until each new unit is actually ready before pulling the old one out of rotation.

@card
id: aws-ch02-c009
order: 9
title: EC2 Key Pairs and SSH Access
teaser: Key pairs were EC2's original access model in 2006 — AWS Systems Manager Session Manager is the modern replacement, and it eliminates the open port 22 that key-based SSH requires.

@explanation

The classic key-pair model: you generate an RSA or ED25519 key pair, give AWS the public key at launch, and EC2 injects it into `~/.ssh/authorized_keys` on the instance. You SSH in with:

```bash
ssh -i my-key.pem ec2-user@<public-ip>
```

The problems with this model at scale:

- Requires inbound port 22 open in the security group — that port gets probed constantly by the internet
- Key distribution is manual; rotating keys across a fleet is painful
- No audit trail of who ran which commands when
- Doesn't work for instances in private subnets without a bastion host or VPN

**AWS Systems Manager (SSM) Session Manager** solves all of these. It opens an interactive shell session over the SSM agent, which communicates outbound over HTTPS to the SSM service — no inbound port required, no key pair needed.

```bash
aws ssm start-session --target i-0123456789abcdef0
```

Session Manager logs every command and its output to CloudWatch Logs and/or S3, giving you a full audit trail. IAM policies control who can start a session. You can also use SSM for port forwarding and running commands without an interactive session.

The only requirements: the SSM agent (pre-installed on Amazon Linux 2023 and most AWS-managed AMIs) and an IAM instance profile with `AmazonSSMManagedInstanceCore` attached.

> [!tip] Close port 22 in your security groups for all production instances. If your team can't start a session without SSH, the SSM agent or its IAM role is misconfigured — fix that, don't reopen the port.

@feynman

SSH with key pairs is like issuing physical keys to a building — SSM Session Manager is like a keycard system with central access control, per-entry logs, and no need to ever hand anyone a physical key.

@card
id: aws-ch02-c010
order: 10
title: EC2 Networking Fundamentals
teaser: EC2 networking has four concepts you need to hold at once — ENIs, public vs Elastic IPs, security groups, and the stop-vs-terminate distinction — and confusing any of them is how you lose an IP address or expose a port you meant to close.

@explanation

**Elastic Network Interfaces (ENIs)** are virtual NICs. Every instance gets a primary ENI (`eth0`) in a VPC subnet. You can attach additional ENIs — useful for multi-homed instances, network appliances, or preserving an IP address across instance replacements by moving the ENI to a new instance.

**IP address types:**
- *Private IP* — from the VPC CIDR; stays with the instance for its lifetime
- *Public IP* — assigned automatically to instances in public subnets with auto-assign enabled; **released when the instance stops**
- *Elastic IP (EIP)* — a static public IPv4 address you allocate to your account; stays assigned until you explicitly release it, survives stop/start. Charged a small fee when not attached to a running instance (AWS discourages hoarding)

If your application needs a stable public IP, use an Elastic IP or put a load balancer in front (the load balancer's DNS name is stable even if its underlying IPs change).

**Security groups** are stateful firewalls applied at the ENI level. Stateful means: if you allow an outbound connection, the return traffic is automatically allowed without an explicit inbound rule. Security groups are allow-only — you cannot write deny rules. For deny rules, use Network ACLs (subnet level, stateless).

**Stop vs Terminate:**
- *Stop* — instance shuts down; EBS root volume persists; private IP and EIN are preserved; public IP (non-Elastic) is released; you are not billed for compute (you are billed for EBS and Elastic IPs)
- *Terminate* — instance is destroyed; EBS root volume is deleted by default (controlled by the `DeleteOnTermination` flag); private IP and ENI are released; the instance is gone permanently

> [!warning] Enabling termination protection is a one-line safety net that prevents accidental `terminate-instances` calls. Enable it on every long-lived production instance.

@feynman

A security group is like an iptables `conntrack` rule set — you write the initiating direction and the kernel tracks the session, so you never have to write the return rule explicitly.
