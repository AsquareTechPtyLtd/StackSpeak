@chapter
id: aws-ch07-networking-with-vpc
order: 7
title: Networking with VPC
summary: A VPC is your private slice of the AWS network — and the decisions you make when designing it (CIDR sizing, subnet topology, connectivity patterns) are expensive to undo once production traffic is running through them.

@card
id: aws-ch07-c001
order: 1
title: VPC Fundamentals
teaser: A VPC is a logically isolated virtual network inside a single AWS region — you control the IP space, the routing, and what can reach what.

@explanation

When you create a VPC, you're carving out a private address space inside AWS and saying: "only my resources live here, and I control all the rules." Nothing enters or leaves without your explicit permission.

The key structural facts:

- **CIDR block sizing matters.** A VPC CIDR like `/16` gives you 65,536 addresses to subdivide into subnets. A `/24` gives you 256. You cannot expand a VPC's CIDR without adding a secondary block (a pain), and you cannot shrink it. The cost of choosing too small is re-architecting your network under live traffic.
- **The default VPC is a trap.** AWS creates a default VPC in every region with public subnets and an internet gateway already attached. It's convenient for quick tests, and a liability in production — default subnets route directly to the internet, there's no isolation between workloads, and every team that's ever used the account may have resources in it.
- **VPCs are regional; subnets are AZ-scoped.** A single VPC spans all Availability Zones in a region, but each subnet lives in exactly one AZ. High availability requires deploying resources across multiple subnets in multiple AZs.
- **IP allocation is non-trivial.** Plan your CIDR space assuming future VPC peering — overlapping CIDRs between peered VPCs are a hard blocker.

A `/16` VPC with `/24` subnets per AZ is a common and safe starting point for most production workloads.

> [!warning] The default VPC should be treated as a scratchpad, not a production environment. Create a purpose-built VPC for every real workload.

@feynman

A VPC is like leasing a private floor in a shared office building — you're in the same building as other tenants, but your floor has its own locked doors, its own wiring layout, and only you decide who gets a key.

@card
id: aws-ch07-c002
order: 2
title: Public vs Private Subnets
teaser: What makes a subnet public or private is not a flag you set — it's the route table attached to it, specifically whether there's a route pointing at an internet gateway.

@explanation

The public/private distinction is entirely a routing decision. A subnet is public if its route table contains a route to an internet gateway (`0.0.0.0/0 → igw-xxxxxxxx`). A subnet is private if it doesn't — or if its default route points at a NAT gateway instead.

The standard three-tier pattern for production systems:

- **Public subnet** — hosts load balancers (ALB/NLB) and bastion hosts. Anything here has a path to and from the public internet.
- **Private app subnet** — hosts EC2 instances, containers, and Lambda functions. Outbound internet access goes through a NAT gateway. No inbound internet path exists.
- **Private DB subnet** — hosts RDS, ElastiCache, and similar data stores. Often no internet route at all, not even outbound.

Five IPs per subnet are reserved by AWS and unavailable for your resources:

- `.0` — network address
- `.1` — VPC router
- `.2` — DNS server
- `.3` — reserved for future use
- `.255` — broadcast address (unusable in VPC)

This means a `/24` subnet gives you 251 usable addresses, not 256. Plan subnet sizes accordingly — a `/28` (16 addresses) leaves you only 11 usable IPs.

> [!tip] Deploy at least one public and one private subnet in each AZ you operate in. Single-AZ subnet designs are a reliability risk that comes back to bite you during AZ incidents.

@feynman

A public subnet is like a storefront with a street-facing door; a private subnet is the back office — customers can reach the storefront, but the back office only has an internal hallway, not a door to the street.

@card
id: aws-ch07-c003
order: 3
title: Internet Gateway and NAT Gateway
teaser: An internet gateway handles two-way public traffic; a NAT gateway handles outbound-only traffic from private subnets — and the difference in cost and operational complexity is significant.

@explanation

**Internet Gateway (IGW):** Attached to a VPC, not a subnet. It's what makes public subnets actually public — the route table entry pointing to the IGW is what connects resources to the internet. IGWs are horizontally scaled, redundant, and have no bandwidth cap. They cost nothing to run; you pay only for the data transfer.

**NAT Gateway:** Sits in a public subnet and translates outbound traffic from private subnet resources to a public IP. Private resources can reach the internet (for things like downloading packages or calling external APIs) but the internet cannot initiate connections back. Pricing: approximately $0.045/hour per NAT gateway plus $0.045/GB of data processed. A single NAT gateway running all month costs roughly $32 in the us-east-1 region, before data costs.

Key operational consideration:

- **NAT Gateway is AZ-scoped.** If your NAT gateway is in us-east-1a and that AZ has an outage, private resources in us-east-1b lose outbound internet access. The correct HA setup is one NAT gateway per AZ, with each AZ's private subnets routing to their own NAT gateway.
- **NAT Instance** is the budget alternative — a small EC2 instance configured to perform NAT. A `t4g.nano` runs around $3/month. The tradeoff: you own patching, scaling, and availability. Teams running dev or staging environments on a budget often use NAT instances; production usually warrants managed NAT gateways.

> [!info] NAT Gateway per-AZ HA doubles or triples your NAT costs. For most teams, this is worth it in production and not worth it in staging.

@feynman

An IGW is the front door of your building — people walk in and out freely; a NAT gateway is a one-way turnstile — your residents can leave, but nothing from outside can come back through it uninvited.

@card
id: aws-ch07-c004
order: 4
title: Security Groups vs NACLs
teaser: Security groups are stateful and operate at the resource level; NACLs are stateless and operate at the subnet level — understanding the difference tells you when you actually need both.

@explanation

**Security Groups** are attached to individual resources (EC2 instances, RDS clusters, load balancers, Lambda functions). They are stateful: if you allow inbound port 443, the response traffic is automatically allowed outbound without an explicit rule. Security groups support allow rules only — there is no deny rule. The default security group blocks all inbound and allows all outbound.

**Network ACLs (NACLs)** operate at the subnet boundary and evaluate traffic before it reaches any resource in the subnet. They are stateless: if you allow inbound TCP 443, you must also explicitly allow the return traffic on the ephemeral port range (1024–65535) outbound, or responses will be silently dropped. NACLs support both allow and deny rules, evaluated in order by rule number.

When you need each:

- **Security groups alone** are sufficient for the vast majority of VPC architectures. They provide fine-grained, resource-level control with less complexity.
- **NACLs** add value when you need subnet-wide deny rules — for example, blocking a specific IP range known to be malicious across all resources in a subnet, or enforcing network segmentation as a compliance requirement even if a security group misconfiguration occurs.

The failure mode is applying NACLs without accounting for statelessness. Blocking a port inbound without also blocking the ephemeral response range outbound leads to asymmetric behavior that is extremely difficult to debug.

> [!warning] NACLs are stateless. Forgetting to allow ephemeral return ports is the most common source of mysterious connectivity failures in VPC networks.

@feynman

A security group is a smart doorman who remembers every conversation — if you let someone in, he lets them out when they leave; a NACL is a strict bouncer with a checklist who checks every person in both directions with no memory of who's already inside.

@card
id: aws-ch07-c005
order: 5
title: VPC Peering
teaser: VPC peering connects two VPCs with a private network link — but the routing is non-transitive, and CIDR overlap makes it impossible, so design your address space before you peer.

@explanation

VPC peering creates a one-to-one network connection between two VPCs, allowing resources in each to communicate using private IP addresses. Peering works within a region, across regions, and across AWS accounts. Traffic stays on the AWS backbone — it doesn't traverse the public internet.

The critical constraints:

- **Non-transitive routing.** If VPC A is peered with VPC B, and VPC B is peered with VPC C, resources in A cannot reach resources in C through B. Peering is not a relay — each pair of VPCs that needs to communicate requires its own peering connection.
- **No overlapping CIDRs.** If VPC A uses `10.0.0.0/16` and VPC B also uses `10.0.0.0/16`, you cannot peer them. AWS has no way to route between overlapping address spaces.
- **Both sides need route table entries.** Creating the peering connection is not enough — you must add routes in each VPC's route table pointing the other VPC's CIDR at the peering connection.

For small numbers of VPCs (2–3), peering is simple and cost-effective. For larger environments — say, 5 VPCs that all need to talk to each other — a full mesh of peering connections becomes unwieldy: 5 VPCs require 10 peering connections, and 10 VPCs require 45. At that point, Transit Gateway is the right answer.

> [!info] Non-transitive routing is the most common misunderstanding about VPC peering. Draw your topology explicitly before provisioning — a hub-and-spoke shape with peering does not give spoke-to-spoke connectivity.

@feynman

VPC peering is like introducing two colleagues directly — they can talk to each other, but that introduction doesn't give either of them access to the other's other contacts.

@card
id: aws-ch07-c006
order: 6
title: AWS Transit Gateway
teaser: Transit Gateway is a regional hub-and-spoke router that connects hundreds of VPCs and on-premises networks without the CIDR and transitivity limitations of VPC peering.

@explanation

Transit Gateway (TGW) replaces the need for a full VPC peering mesh. Instead of connecting every VPC to every other VPC, each VPC attaches to a central TGW, and the TGW handles routing between all of them. One attachment — connectivity to everything else attached to the same TGW.

Key capabilities:

- **Scale.** A single TGW supports up to 5,000 VPC attachments. Contrast that with the 125-peering-connection limit per VPC.
- **Transitive routing.** Unlike peering, TGW is a real router. VPCs attached to the same TGW can communicate with each other through it, with routing controlled by TGW route tables.
- **On-premises connectivity.** VPNs and Direct Connect connections attach to the TGW directly, giving all attached VPCs access to your on-premises network without configuring separate VPN tunnels per VPC.
- **Multi-region.** TGW peering connects Transit Gateways in different regions, enabling global hub-and-spoke architectures.

Cost: approximately $0.05/hour per VPC or VPN attachment, plus $0.02/GB of data processed. An environment with 10 VPCs attached to one TGW costs roughly $36/month in attachment fees before data transfer.

The tradeoff over VPC peering: TGW is more expensive and adds a centralized routing hop. For 2–3 VPCs, peering is cheaper and simpler. For anything resembling a multi-account, multi-environment AWS organization, TGW is the right default.

> [!tip] If you're building a landing zone or an AWS Organization with more than three accounts, start with Transit Gateway rather than trying to manage a peering mesh and migrating later.

@feynman

Transit Gateway is like installing a central switchboard in an office building — instead of running a dedicated cable between every pair of desks, each desk plugs into the switchboard and the switchboard handles all the routing.

@card
id: aws-ch07-c007
order: 7
title: AWS PrivateLink and VPC Endpoints
teaser: VPC Endpoints let your resources reach AWS services without leaving the AWS network — keeping traffic private and, in the case of Gateway Endpoints, free.

@explanation

By default, when an EC2 instance in a private subnet calls the S3 API, the traffic routes through the NAT gateway to the public internet endpoint for S3, then back. VPC endpoints short-circuit this: the traffic stays entirely within AWS's private network.

Two types:

**Gateway Endpoints** — available only for S3 and DynamoDB. Free. Added as an entry in your route table that directs S3 or DynamoDB traffic to the endpoint rather than the internet. No ENI, no IP address, no cost. If you're using S3 or DynamoDB from a private subnet, there is no reason not to use Gateway Endpoints.

**Interface Endpoints (PrivateLink)** — used for most other AWS services (SSM, Secrets Manager, ECR, CloudWatch, SQS, and hundreds more) as well as partner services and your own internal services. An Interface Endpoint creates an Elastic Network Interface (ENI) in your subnet with a private IP address. Traffic to the service resolves to this private IP. Cost: approximately $0.01/hour per endpoint per AZ, plus $0.01/GB of data processed.

Why it matters:

- Resources in fully private subnets with no internet route can still reach AWS service APIs.
- Traffic doesn't touch the public internet, reducing attack surface.
- In regulated environments (PCI, HIPAA), keeping AWS API traffic off the internet is often a compliance requirement.

For a service like SSM Parameter Store, an Interface Endpoint in each AZ costs roughly $14/month — often worth it to avoid the NAT gateway data costs and to eliminate the public internet path.

> [!info] Gateway Endpoints for S3 and DynamoDB are free and take five minutes to add. There is almost no reason to route S3 traffic through a NAT gateway when Gateway Endpoints exist.

@feynman

A VPC endpoint is like adding a private tunnel from your office directly into the AWS data center — instead of sending a courier out through city traffic to reach AWS, you have a direct internal passage that never touches a public street.

@card
id: aws-ch07-c008
order: 8
title: VPN and Direct Connect
teaser: Site-to-Site VPN gives you hybrid connectivity in hours over the public internet; Direct Connect gives you dedicated fiber in weeks — and the decision between them comes down to bandwidth, latency, and how much you trust the internet.

@explanation

**AWS Site-to-Site VPN** creates an IPSec tunnel between your on-premises network and your VPC. It runs over the public internet, with two redundant tunnels for availability. Setup takes a few hours. Cost: approximately $0.05/hour (~$36/month) plus data transfer. Maximum bandwidth is around 1.25 Gbps per tunnel, with latency subject to internet variability.

**AWS Direct Connect** is a dedicated physical fiber connection from your data center (or a colocation facility) to an AWS Direct Connect location. Speeds range from 1 Gbps to 100 Gbps. Latency is consistent and low. Cost: the Direct Connect port (starting around $0.30/hour for 1 Gbps) plus your cross-connect fees plus the data transfer rate. Provisioning takes days to weeks and requires working with a Direct Connect partner.

**Direct Connect Gateway** extends a single Direct Connect connection to multiple VPCs across multiple regions, avoiding the need for separate physical connections per region.

The decision framework:

- **Use VPN** for dev/test connectivity, as a backup for Direct Connect, for quick migrations, or when bandwidth needs are low (sub-1 Gbps).
- **Use Direct Connect** when you need consistent low latency, high bandwidth (1 Gbps+), large-volume data transfer where per-GB Direct Connect pricing beats internet transfer pricing, or compliance requirements that prohibit internet-routed traffic.
- **Use both** for production: Direct Connect as primary, VPN as failover.

> [!tip] Run the math on data transfer costs before deciding. At high volumes, Direct Connect's lower per-GB rate can make the upfront provisioning cost pay for itself in months.

@feynman

VPN is a secure phone call over a shared phone network — it works and it's encrypted, but you're sharing the line with everyone else; Direct Connect is a private leased line — you have the whole cable, and no one else is on it.

@card
id: aws-ch07-c009
order: 9
title: VPC Flow Logs
teaser: VPC Flow Logs give you a record of every accepted and rejected network connection in your VPC — indispensable for security forensics, but only if you know what you're paying for.

@explanation

Flow Logs capture metadata about IP traffic flowing through network interfaces in your VPC. They don't capture packet contents — just the who, what, when, and whether it was accepted or rejected.

Default fields in each log record include:

- Source and destination IP and port
- Protocol
- Bytes and packets transferred
- Start and end time
- Action (ACCEPT or REJECT)
- Log status

You can also enable custom format fields including the VPC ID, subnet ID, instance ID, TCP flags, and traffic type.

**Destinations:** Flow Logs can be sent to CloudWatch Logs, S3, or Kinesis Data Firehose. S3 is cheapest for bulk storage and querying with Athena. CloudWatch Logs is more convenient for real-time alerting. Kinesis is the right path if you're streaming to a SIEM.

**Cost:** Flow Logs themselves are free to create. You pay for the destination — CloudWatch Logs ingestion (~$0.50/GB), S3 storage and PUT requests, or Kinesis Data Firehose record processing. For a high-traffic VPC, flow log data can add up quickly; filter at the ENI level or on traffic type to reduce volume.

**What you use them for:**
- Identifying which security group rule rejected a connection (REJECT entries)
- Detecting unexpected traffic patterns or lateral movement
- Understanding bandwidth usage between specific services
- Confirming that a VPC endpoint is actually being used

> [!info] Flow Logs with REJECT action only is a common cost-saving filter — you capture the security-relevant signal (blocked traffic) at a fraction of the data volume of full logging.

@feynman

VPC Flow Logs are like the access log on a web server — you're not recording what was in every request, just who showed up, what door they tried, and whether they were let in.

@card
id: aws-ch07-c010
order: 10
title: VPC Design Patterns
teaser: The VPC topology you choose early becomes the skeleton of your AWS architecture — and refactoring a production network is painful enough that getting the broad shape right before you scale matters more than most teams expect.

@explanation

**Single VPC vs multi-VPC:** A single VPC with environment-level segmentation via subnets and security groups is simple and sufficient for small teams. As you scale to multiple teams, multiple products, or compliance isolation requirements, a multi-VPC model (typically one VPC per environment per account) provides stronger blast radius isolation and clearer ownership boundaries.

**Multi-account landing zone:** The AWS recommended pattern is one account per environment (dev, staging, prod) with VPCs connected through a shared Transit Gateway. Compromising the dev account doesn't touch production. Billing is isolated. IAM blast radius is contained.

**CIDR allocation strategy:** Assign non-overlapping CIDR ranges to each VPC from the start, assuming you will eventually peer or connect them. A common scheme: `10.0.0.0/16` for prod, `10.1.0.0/16` for staging, `10.2.0.0/16` for dev. This costs nothing and avoids the hardest constraint in VPC peering.

**Shared services VPC:** DNS resolvers, monitoring infrastructure, Active Directory, and internal tooling often live in a dedicated "shared services" VPC that peers to all other VPCs or connects via Transit Gateway. This avoids duplicating that infrastructure in every account.

**The "large CIDR now, subnet later" rule:** Start with a `/16` VPC even if you only need a handful of subnets today. Subnets are free to create and easy to add. Expanding or re-IPing a VPC under live traffic is not. A `/24` VPC that seemed more than enough will constrain you once you add two new AZs, a shared services segment, and a dedicated DB tier.

> [!warning] CIDR overlap is an unrecoverable design mistake without re-IPing. Allocate from a central registry the first day you create your second VPC.

@feynman

Designing a VPC is like planning a city's street grid — the decisions you make about block size and neighborhood boundaries before the first building goes up are far cheaper to change than the ones you make after a thousand buildings are already there.
