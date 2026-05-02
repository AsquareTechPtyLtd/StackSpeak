@chapter
id: eds-ch13-cloud-networking-essentials
order: 13
title: Cloud Networking Essentials
summary: The networking layer that data systems sit on top of. Most pipeline failures that look like "the database is broken" are actually networking issues in disguise.

@card
id: eds-ch13-c001
order: 1
title: Why Data Engineers Need Networking
teaser: When pipelines fail with timeouts, can't reach databases, or rack up surprise bills, the cause is usually networking. Knowing the basics turns hours of confusion into minutes of diagnosis.

@explanation

A non-trivial fraction of data engineering incidents trace back to networking:

- **"The pipeline can't connect to the database."** Usually a security group, VPC peering, or DNS issue.
- **"Reads are slow today."** Network congestion, cross-region traffic, or routing change.
- **"Our cloud bill jumped 30% last month."** Egress fees from cross-region or cross-cloud traffic.
- **"The CDC stream lags."** Network throughput between source DB and processor.
- **"This worked from my laptop but not from the production cluster."** Almost always a network reachability issue.

Without basic networking knowledge, these incidents become long debugging sessions involving DBAs, networking teams, cloud support. With it, you skip the confusion and ask the right questions immediately.

This appendix covers the minimum networking concepts a data engineer should be fluent in: VPCs, security groups, peering, private endpoints, DNS, and the cost dynamics that make some traffic free and other traffic surprisingly expensive.

> [!info] Senior data engineers consistently know more networking than the job description suggests. It's an underadvertised but high-leverage skill area.

@feynman

Same as understanding HTTP for backend developers — the layer underneath the abstraction; you can ignore it until you can't.

@card
id: eds-ch13-c002
order: 2
title: VPCs — Your Private Network In The Cloud
teaser: A Virtual Private Cloud is your own isolated network in someone else's data center. Every cloud resource sits inside one, and the boundaries dictate what can talk to what.

@explanation

A VPC (Virtual Private Cloud) is a logically isolated network in the cloud. Inside it:

- **Your own IP address space** — you assign CIDR blocks (e.g., 10.0.0.0/16).
- **Subnets** — smaller blocks of IPs, typically per availability zone (10.0.1.0/24, 10.0.2.0/24).
- **Resources placed inside subnets** — EC2 instances, RDS databases, EKS pods all live in subnets.
- **Routing tables** — control how traffic flows between subnets and out to the internet.
- **Internet gateways and NAT gateways** — control outbound and inbound internet access.

Why this matters:

- **Network isolation.** Nothing in another VPC can reach your VPC by default. Even other accounts owned by you.
- **Public vs private subnets.** Public subnets have a route to the internet; private don't. Most production data infrastructure (databases, processing) lives in private.
- **Security group enforcement.** Firewall rules at the resource level — which sources can reach which destinations on which ports.

The day-to-day implication for data engineers: when your pipeline can't reach a source database in another VPC, you're hitting VPC isolation. The fix is one of: VPC peering, transit gateway, private endpoint, or routing through a NAT.

> [!tip] Drawing the network topology of your data systems on a whiteboard once is one of the higher-ROI ten minutes you can spend. Many connectivity issues become obvious in the diagram that aren't obvious in the abstract.

@feynman

Same isolation idea as Docker networks — by default, nothing reaches anything else; you explicitly create the connections you want.

@card
id: eds-ch13-c003
order: 3
title: Security Groups And Network ACLs
teaser: Two layers of firewall in cloud networks. Security groups are stateful and per-resource; network ACLs are stateless and per-subnet. Both have to allow traffic for it to flow.

@explanation

**Security groups** — stateful firewalls attached to individual resources (EC2 instances, RDS databases, ALBs).

- **Allow rules only.** "Allow inbound on port 5432 from this CIDR or this security group."
- **Stateful.** If inbound is allowed, the response is automatically allowed.
- **Default-deny.** If nothing matches, traffic is dropped.
- **Composable.** A security group can reference another security group, letting you express "allow from anything in the app-server group."

**Network ACLs (NACLs)** — stateless firewalls at the subnet level.

- **Allow and deny rules** — explicit ordering matters.
- **Stateless.** You must explicitly allow both inbound and outbound (including ephemeral response ports).
- **Default-allow on creation** — unlike security groups.
- **Less commonly used** than security groups; security groups handle most needs.

The common gotchas:

- **"It works from my laptop, not from the pipeline server."** Different source IPs; security group on the destination only allows your laptop's IP.
- **"It worked yesterday."** Security group rule got tightened; previous source no longer permitted.
- **"Outbound seems blocked."** Either the source's outbound security group rule, or a NACL on the source's subnet, or a routing issue.

Debugging tools: VPC Flow Logs (records all traffic for analysis), Reachability Analyzer (AWS), connectivity tester tools that simulate the path.

> [!info] When in doubt about a connectivity issue, log into the source machine and try `nc -zv host port` or `curl -v host:port`. The error message often tells you whether it's a routing issue, security group issue, or DNS issue.

@feynman

Same as iptables on a Linux host — explicit allow rules; default deny; debugging requires checking both ends of the connection.

@card
id: eds-ch13-c004
order: 4
title: Private Endpoints And Service Connectivity
teaser: For talking to managed cloud services without going over the internet. Lower latency, more secure, often required for compliance — and sometimes the source of mysterious connection problems.

@explanation

When your VPC needs to talk to a managed service (S3, Snowflake, RDS in another VPC), there are a few options:

- **Public internet** — traffic leaves your VPC, hits the public internet, reaches the service. Simplest; goes through NAT gateway; costs egress fees; slower.
- **VPC peering** — direct routing between two VPCs. No internet hop. Limited to a single region typically.
- **Transit gateway** — central routing hub for many VPCs in a single region. More scalable than full-mesh peering.
- **Private endpoints (PrivateLink, Private Service Connect)** — private connection from your VPC to a managed service, without going over the internet. Service appears as if it's in your VPC.
- **Privatelink for SaaS** — increasingly, SaaS providers (Snowflake, Databricks, MongoDB Atlas) offer private endpoint connectivity into customer VPCs.

When private endpoints matter:

- **Compliance** — many regulations require traffic to stay off the public internet.
- **Latency** — same-region private endpoint adds ~1ms vs ~10-50ms over public internet.
- **Cost** — eliminates NAT gateway and inter-region egress fees.
- **Security** — service is reachable only from your VPC; not exposed publicly.

The complications:

- **DNS** — private endpoints often use private DNS names that resolve only inside the VPC.
- **Cost** — private endpoints aren't free; per-hour charges plus per-GB processing.
- **Setup complexity** — more moving parts; failures are harder to diagnose.

> [!tip] If your data infrastructure costs include large NAT gateway charges, evaluating PrivateLink for the largest data flows often pays back fast.

@feynman

Same as the difference between a phone call routed through a public exchange vs a direct line — same conversation, different path, very different cost and latency.

@card
id: eds-ch13-c005
order: 5
title: DNS — The Quiet Source Of Many Mysteries
teaser: DNS turns names into addresses. When it fails or behaves unexpectedly, every system that depends on names starts breaking in confusing ways.

@explanation

What DNS does:

- Maps `db.example.com` to an IP address.
- Caches results based on TTL (time to live).
- In cloud VPCs, can resolve private endpoint names to private IPs.

Common DNS-related issues:

- **DNS caching.** Your system has cached `db.example.com → 10.0.1.5` with a 1-hour TTL; the database moved to 10.0.1.6 yesterday; your connection still tries the old IP for up to an hour.
- **Wrong resolver.** Your container is using the public 8.8.8.8 resolver; it can't see your VPC's private DNS zones; private endpoint names fail to resolve.
- **Split-horizon DNS.** Same name resolves to different IPs depending on whether you're in or out of the VPC. Tools that test from outside don't reproduce production behavior.
- **Stale resolver cache.** Long-running processes keep stale resolution; restarting fixes it; root cause hidden.

Tools to debug:

- `dig hostname` — show what your system resolves the name to.
- `dig +trace hostname` — show the full resolution path.
- `nslookup hostname` — older but still useful.
- `cat /etc/resolv.conf` (Linux) — show which resolvers are configured.

In cloud environments:

- **VPC DNS** — each AWS/GCP VPC has its own DNS resolver that knows about VPC-internal names and integrates with public DNS.
- **Private DNS zones** — Route 53 (AWS), Cloud DNS (GCP) let you publish names visible only within your VPCs.
- **Private endpoints** automatically register names that resolve to private IPs from inside the VPC.

> [!warning] When a service "suddenly stops working" with no related changes, DNS is on the short list of suspects. Always check resolution before deeper debugging.

@feynman

Same role as the phone book — the systems that depend on it work fine until the names stop pointing where they should.

@card
id: eds-ch13-c006
order: 6
title: Bandwidth, Latency, And Throughput
teaser: Three different things often confused. Knowing what's actually limiting a pipeline's data movement saves expensive misdiagnosis.

@explanation

**Bandwidth** — capacity. The maximum theoretical data rate of a link. Measured in Mbps or Gbps. Like the diameter of a pipe.

**Latency** — round-trip time. How long a single packet takes to make the trip. Measured in milliseconds. Like how long water takes to traverse the pipe.

**Throughput** — actual sustained rate. What you can actually move in practice, often less than bandwidth due to protocol overhead, latency-bandwidth product limits, or contention. The water you actually deliver per second.

In practice for data systems:

- **Same-AZ traffic** — high bandwidth (10 Gbps+), sub-millisecond latency. Throughput close to bandwidth.
- **Cross-AZ same-region** — high bandwidth, ~1-2ms latency. Throughput close to bandwidth.
- **Cross-region same-cloud** — moderate bandwidth, 30-100ms latency. Throughput limited by latency-bandwidth product for single connections.
- **Cross-cloud or to on-prem** — variable bandwidth, high latency, often unpredictable. Throughput much harder to predict.
- **Public internet** — variable everything; usually adequate for control-plane traffic, problematic for bulk data.

What this means for design:

- **Co-locate compute and storage.** Spark cluster in us-east-1 reading from S3 in us-east-1; not us-west-2.
- **Bulk transfers prefer parallelism.** A single connection across high-latency links underperforms; many parallel connections fill the bandwidth.
- **Compress before moving across regions.** Egress is billed by bytes; compression cuts the bill and the time.
- **Cache where the consumers are.** Don't make every read traverse the same network.

> [!info] When a pipeline transfer is slow, ask "is it bandwidth-limited or latency-limited?" The answers point to different fixes.

@feynman

Same as moving water — wider pipe (bandwidth) helps when many things flow; shorter pipe (latency) helps when each individual thing is slow.

@card
id: eds-ch13-c007
order: 7
title: Egress Costs — The Cloud Bill You Forget About
teaser: Cloud providers charge for traffic leaving their network. The bills compound silently and surprise teams every quarter.

@explanation

The basic shape of cloud egress pricing:

- **Same-region, same-cloud** — usually free.
- **Cross-AZ same-region** — small per-GB fee on AWS (a cent or so).
- **Cross-region same-cloud** — moderate per-GB fee (a few cents).
- **Cross-cloud or to internet** — most expensive (5-15 cents per GB depending on cloud and volume).
- **To on-prem via direct connect** — discounted but still real.

Where data systems get hit:

- **Cross-region warehouse access** — your warehouse in us-east-1; consumers in eu-west-1 querying directly. Every query result crosses regions.
- **Multi-region replication** — keeping copies of data in multiple regions for resilience or compliance.
- **Reverse ETL syncs** — pushing data out to SaaS systems that may be in other clouds.
- **External data sharing** — sending datasets to partners or customers.
- **Backup and DR** — replicating to a different region for disaster recovery.

Architectural ways to cut egress:

- **Compute close to data.** Process data in the region it lives in; only ship the small results out.
- **Compress aggressively** before shipping; cuts bills proportional to the compression ratio.
- **Use private connectivity** — same-cloud privatelink, direct connect to on-prem — often cheaper than public internet at scale.
- **Cache results** — repeat queries hit the cache instead of re-incurring egress.
- **Tier replication** — only critical data multi-region; the rest stays single-region.

> [!warning] The first time a team builds a multi-region pipeline without thinking about egress, the bill arrives a month later and costs more than the underlying compute. It's the silent compounding tax of cloud architecture.

@feynman

Same trap as international roaming — cheap inside the network, expensive when you cross boundaries, easy to incur without realizing.

@card
id: eds-ch13-c008
order: 8
title: When Pipelines Fail, Network Is The First Suspect
teaser: A practical heuristic for diagnosing data pipeline failures faster — start by ruling out network, then move to application logic.

@explanation

A debugging checklist for the most common pipeline-fails-mysteriously scenarios:

**1. Can the source even be reached?**
- `nc -zv host port` from the source machine.
- `dig host` to verify DNS resolution.
- Check security group rules, NACLs, route tables.

**2. Is authentication succeeding?**
- Look at error messages; "connection refused" is networking; "authentication failed" is creds.
- Check that secrets manager is providing fresh creds.
- Verify IAM role hasn't changed.

**3. Is the source healthy?**
- Database CPU, connections, disk space.
- Source API status page.
- Cross-check with another consumer of the same source.

**4. Is the data shape what you expected?**
- Schema drift in the source.
- Volume spike or drop.
- Format change (CSV delimiter, JSON structure).

**5. Is downstream healthy?**
- Warehouse running; not throttled.
- Storage not full.
- Downstream consumer not in maintenance.

**6. Is it environmental?**
- New cloud account or region rollout.
- Recent infrastructure change (Terraform apply, manual edit).
- VPN or VPC peering recently modified.

In experience, the priority of investigation should be: networking → authentication → upstream health → schema → downstream → recent infrastructure changes. Most actual incidents land in the first two; misallocating debugging time to deeper layers wastes hours.

> [!tip] Build a runbook for your most-paged pipelines. The first three steps should always be "can you reach it, can you authenticate, is the source healthy" — in that order.

@feynman

Same triage logic as ER medicine — eliminate the most common, most fixable issues first; deep workup only when basics are ruled out.

@card
id: eds-ch13-c009
order: 9
title: VPNs, Direct Connect, And Hybrid Connectivity
teaser: When your cloud needs to talk to on-prem (or another cloud), three options span the space from "easy and slow" to "fast and expensive."

@explanation

**Site-to-site VPN.** Encrypted tunnel over the public internet. AWS Site-to-Site VPN, GCP Cloud VPN, Azure VPN Gateway. Cheapest; throughput limited by your internet pipe; latency variable.

Wins: simple to set up; works anywhere with internet; cheap.
Losses: limited bandwidth (1-5 Gbps practical); inconsistent latency; depends on public internet stability.

**Direct Connect / Cloud Interconnect / ExpressRoute.** Dedicated private circuit from your data center to the cloud provider. AWS Direct Connect, GCP Cloud Interconnect, Azure ExpressRoute.

Wins: predictable bandwidth (1-100 Gbps options); consistent low latency; doesn't traverse public internet; compliance-friendly.
Losses: physical setup time (weeks to months); recurring cost; vendor coordination.

**SD-WAN / managed connectivity providers** — Equinix, Megaport, AT&T, etc. Aggregate connectivity to multiple clouds; can simplify multi-cloud connectivity.

Wins: single contract for connectivity to multiple clouds; faster to provision than direct connect.
Losses: another vendor in the chain; pricing varies; not always the cheapest.

For data engineering specifically:

- **Hybrid pipelines** (on-prem source → cloud warehouse) often need Direct Connect once volumes get large; VPN works for smaller flows.
- **Multi-cloud pipelines** are where managed connectivity providers become attractive.
- **DR scenarios** — replicating to a different cloud requires reliable bandwidth between them.

> [!info] If you're piping more than ~10 TB/month between on-prem and cloud, Direct Connect usually beats VPN on both performance and cost. Below that, VPN is fine.

@feynman

Same trade-off as residential broadband vs business fiber vs leased line — each gets you connectivity; each fits a different scale and reliability need.

@card
id: eds-ch13-c010
order: 10
title: Networking Knowledge Compounds
teaser: Every other infrastructure skill builds on networking basics. Investing in this layer pays off across debugging, design, and cost optimization for the rest of your career.

@explanation

The data engineer who knows networking has compounding advantages:

- **Faster debugging.** When a pipeline fails, you can quickly tell whether the issue is network, auth, application, or data — instead of escalating to a network team and waiting.
- **Better design.** Architectural decisions account for bandwidth, latency, and egress cost; choices that look elegant on paper but trigger massive bills get caught early.
- **More credibility.** Cross-team conversations with networking, security, and DevOps go better when you speak their vocabulary.
- **Cost insight.** Most surprising cloud bills involve networking; understanding the cost dynamics lets you prevent or fix them.

Where to invest first:

- **VPCs, subnets, security groups** — the basic units of cloud networking.
- **DNS** — almost every weird connectivity issue involves it.
- **Private endpoints** — increasingly important as data infrastructure moves to managed services.
- **Egress pricing** — the silent cost driver in cloud data architecture.
- **Basic TCP** — connections, retries, keep-alives; how databases and APIs actually move data.

You don't need CCNA-level networking depth. You need enough to diagnose, design, and discuss confidently. Invest a weekend; reap the benefits for the rest of your career.

> [!info] The data engineers who get promoted into staff and principal roles consistently know more networking than the job descriptions advertise. It's an underadvertised but high-leverage area.

@feynman

Same investment as learning shell scripting — annoying to invest in initially; pays back daily for the rest of your career.
