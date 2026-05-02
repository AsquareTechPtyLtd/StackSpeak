@chapter
id: azr-ch06-networking-with-vnet
order: 6
title: Networking with VNet
summary: Azure Virtual Networks are the private networking foundation every cloud workload runs on — this chapter covers how to carve up address space, control traffic flow, connect to other networks, and extend that private boundary to PaaS services.

@card
id: azr-ch06-c001
order: 1
title: VNets Are Your Private Network Boundary
teaser: A Virtual Network is the first thing you create before almost anything else — it defines the private address space and regional boundary your resources live inside

@explanation

An Azure Virtual Network (VNet) is a logically isolated network in Azure that belongs to your subscription. Nothing gets in or out without you explicitly allowing it. By default, resources in a VNet can reach each other, and nothing outside the VNet can reach them.

A few fundamentals you need to know immediately:

- **Address space** — defined in CIDR notation when you create the VNet (e.g., `10.0.0.0/16`). This is the total IP range available to subnets. You can add more address spaces later, but you can't shrink or change existing ones without destroying the VNet.
- **Subnets** — you divide the VNet address space into one or more subnets (e.g., `10.0.1.0/24` for web, `10.0.2.0/24` for data). Resources are deployed into subnets, not directly into the VNet.
- **Implicit routing** — Azure automatically routes traffic between subnets in the same VNet. You don't need a router or gateway for intra-VNet communication; it just works.
- **Regional scope** — a VNet lives in one Azure region. Cross-region communication requires VNet peering or a gateway (covered in later cards).
- **RFC 1918 address space** — by strong convention, VNets use private, non-routable IP ranges: `10.0.0.0/8`, `172.16.0.0/12`, or `192.168.0.0/16`. Technically you can use public IP ranges as your address space (Azure won't stop you), but you almost never should — it creates routing confusion and blocks legitimate internet access to those public IPs.

Azure reserves 5 IP addresses per subnet (first four and the last), so a `/24` gives you 251 usable addresses, not 256.

> [!warning] Size your address space generously upfront. Adding a new non-overlapping address space to an existing VNet is supported, but shrinking or re-IPing a live VNet requires tearing it down. Over-allocating RFC 1918 space costs you nothing in Azure.

@feynman

Creating a VNet is like allocating a private CIDR block in a Docker Compose network — except it's regional, fully managed, and the "containers" are VMs and PaaS services instead of containers.

@card
id: azr-ch06-c002
order: 2
title: NSGs Filter Traffic at Layer 4
teaser: Network Security Groups are stateful firewalls attached to subnets or NICs — the first and most common way to control what traffic your Azure resources accept and emit

@explanation

A Network Security Group (NSG) is a set of inbound and outbound security rules that Azure evaluates against TCP/UDP traffic. NSGs operate at Layer 4 — they can filter on port, protocol (TCP/UDP/ICMP), source IP or range, and destination IP or range. They cannot inspect packet payloads (that's Azure Firewall or a third-party NVA).

**Priority ordering** — rules are evaluated lowest number first. A rule with priority 100 is evaluated before a rule with priority 200. The first matching rule wins; evaluation stops. Priority range is 100–4096.

**Default rules** — every NSG ships with three default rules you cannot delete:
- `AllowVNetInBound` (priority 65000): allows all inbound traffic from within the VNet.
- `AllowAzureLoadBalancerInBound` (priority 65001): allows health probes from the Azure load balancer.
- `DenyAllInBound` (priority 65500): denies everything else inbound.

Corresponding defaults exist for outbound, including `AllowInternetOutBound`. You override these defaults by adding higher-priority rules (lower numbers) above them.

**Subnet vs NIC attachment** — you can attach an NSG to a subnet (affects all resources in that subnet) or to a specific VM's NIC (affects only that VM). Both apply if present; Azure evaluates the subnet NSG first for inbound, the NIC NSG first for outbound.

**Stateful** — like most modern firewalls, NSGs are stateful. If you allow TCP port 443 inbound, the return traffic for established connections is automatically allowed without an explicit outbound rule.

**NSG flow logs** — enable flow logs (in Azure Monitor / Network Watcher) to record which traffic was allowed or denied. Indispensable for debugging connectivity issues or auditing traffic patterns.

> [!tip] Attach NSGs at the subnet level by default — it's easier to manage 5 subnet NSGs than 50 NIC-level NSGs. Reserve NIC-level NSGs for VMs that need rules different from the rest of their subnet.

@feynman

NSGs are iptables rules managed by Azure — the priority system is exactly the same as chain rule ordering, and the stateful behavior is conntrack under the hood.

@card
id: azr-ch06-c003
order: 3
title: ASGs Replace IP Ranges with Logical Names
teaser: Application Security Groups let you write NSG rules that reference "web-tier" or "db-tier" instead of a list of IP addresses that changes every time you scale

@explanation

When you write an NSG rule that allows port 1433 from `10.0.1.0/24` to `10.0.2.0/24`, that works — until you add a subnet, move a service, or scale up and the IP ranges no longer cleanly describe what you meant. Application Security Groups (ASGs) solve this by letting you attach a logical tag to a VM's NIC and then reference that tag in NSG rules.

How they work:

1. Create ASGs representing application tiers: `asg-web-tier`, `asg-app-tier`, `asg-db-tier`.
2. Associate each VM's NIC with the appropriate ASG(s). A NIC can belong to multiple ASGs.
3. Write NSG rules using ASGs as source and destination instead of IP ranges:
   - Allow TCP 443 from `Any` to `asg-web-tier`
   - Allow TCP 8080 from `asg-web-tier` to `asg-app-tier`
   - Allow TCP 1433 from `asg-app-tier` to `asg-db-tier`

When you add a new VM and assign its NIC to `asg-web-tier`, it automatically inherits all the rules that reference `asg-web-tier` — no IP updates, no NSG edits.

The constraints worth knowing:

- ASGs must be in the same region as the VNet.
- All NICs in an ASG must be in the same VNet.
- A single NSG rule can reference up to 10 ASGs combined across source and destination.

> [!info] ASGs don't replace NSGs — they work inside them. Think of ASGs as named sets of NICs that make NSG rules stable and readable as your environment scales and changes.

@feynman

ASGs are security group membership tags for VMs, the same way you'd tag EC2 instances and reference those tags in IAM policies instead of hardcoding instance IDs.

@card
id: azr-ch06-c004
order: 4
title: VNet Peering Connects Networks Without a Gateway
teaser: Peering two VNets creates a low-latency private connection between them — but peering is not transitive, which surprises almost everyone the first time they build a multi-VNet topology

@explanation

VNet peering establishes a direct network connection between two VNets using the Azure backbone, bypassing the public internet. Traffic between peered VNets is private, low-latency, and does not require a VPN gateway or public IPs. Bandwidth is not explicitly capped; it's limited by the VM SKU's NIC bandwidth.

Two peering flavors:
- **Regional peering** — both VNets are in the same Azure region. Lowest latency, no ingress/egress charges for peering traffic itself (only normal compute bandwidth applies).
- **Global peering** — VNets in different regions. Works the same way technically, but there are data transfer charges for traffic crossing region boundaries.

**Non-transitive peering** — this is the most important thing to understand. If VNet A is peered with VNet B, and VNet B is peered with VNet C, VNet A cannot reach VNet C through B. Peering is strictly point-to-point. If A needs to reach C, you must peer A↔C directly, or route through a hub that has User-Defined Routes and a Network Virtual Appliance/Azure Firewall enabling transit (covered in the UDR card).

**Peering vs VPN Gateway:**
- Peering: lower latency, no bandwidth ceiling, simpler setup, only works between Azure VNets.
- VPN Gateway: connects Azure to on-premises or non-Azure clouds, encrypted tunnel, limited bandwidth by SKU (up to ~10Gbps for VpnGw5), higher latency.

Peering is bidirectional but must be explicitly created in both directions — one peering from A to B, one from B to A. Both must be in the "Connected" state before traffic flows.

> [!warning] Non-transitive peering catches most people when they build a spoke-heavy topology and discover that spoke-to-spoke traffic doesn't work. Plan for a hub VNet with forced routing, not flat peering, if you have more than a handful of VNets.

@feynman

VNet peering is like adding a direct network link between two VPCs — but unlike some cloud providers, Azure won't route for you through an intermediate hop; you have to explicitly connect every pair that needs to talk.

@card
id: azr-ch06-c005
order: 5
title: Private Endpoints Bring PaaS onto Your VNet
teaser: A Private Endpoint gives a PaaS service like Azure Storage or SQL Database a private IP address inside your VNet, eliminating any path through the public internet

@explanation

By default, Azure PaaS services (Storage, SQL Database, Key Vault, Service Bus, etc.) are accessible over public internet endpoints — even if your VMs are inside a VNet. Private Endpoints close that gap by projecting a PaaS service into your VNet as a private IP address.

How it works:

1. You create a Private Endpoint resource in a subnet of your VNet.
2. Azure allocates a private IP (e.g., `10.0.3.5`) from that subnet and maps it to a specific PaaS resource (e.g., `myaccount.blob.core.windows.net`).
3. Traffic from your VNet to that service now travels entirely over the Azure private backbone, never leaving the private network.
4. You can optionally disable the public endpoint on the PaaS service entirely, forcing all access to go through Private Endpoints.

**The DNS override requirement** — this is where most implementations break. The PaaS service's public DNS name (`myaccount.blob.core.windows.net`) still resolves to a public IP by default. You need DNS to return the private IP instead. The standard pattern:

- Create an **Azure Private DNS Zone** (e.g., `privatelink.blob.core.windows.net`).
- Link it to the VNet.
- Azure automatically creates an A record mapping the service FQDN to the private IP.
- VMs in the VNet use Azure-provided DNS, which consults the private zone first and returns the private IP.

Without this DNS step, your traffic still routes over the internet even though a Private Endpoint exists.

> [!info] Each PaaS service type has its own `privatelink` DNS zone name. Azure documentation lists them all. If you're deploying many Private Endpoints, a centralized private DNS zone setup in a hub VNet (linked to all spokes) is the cleanest pattern.

@feynman

A Private Endpoint is the networking equivalent of localhost port-forwarding in kubectl — the service lives remotely, but from your network's perspective it has a local address and traffic never leaves the cluster.

@card
id: azr-ch06-c006
order: 6
title: VPN Gateway Bridges Azure to Other Networks
teaser: Azure VPN Gateway lets you connect on-premises networks or remote users to your VNet over encrypted IPsec tunnels — the configuration options matter a lot for reliability and throughput

@explanation

Azure VPN Gateway is a managed IPsec VPN service that runs inside a dedicated `GatewaySubnet` in your VNet. It supports two main scenarios:

**Site-to-site (S2S)** — connects your on-premises network to Azure VNet persistently. Your on-premises VPN device establishes an IKEv1/IKEv2 tunnel to the Azure gateway. Traffic is encrypted end-to-end. Use this when you have a datacenter, office, or colo that needs permanent connectivity to Azure.

**Point-to-site (P2S)** — individual clients (developers, remote workers) connect to Azure using VPN client software. Supports OpenVPN, SSTP, and IKEv2. Maximum 10,000 concurrent P2S connections on the highest SKU.

**Active-passive vs active-active:**
- Active-passive (default): one gateway instance is active, one is standby. Failover takes 90 seconds if the active instance fails.
- Active-active: both instances forward traffic simultaneously. Requires two public IPs and two on-premises VPN peers. Failover is near-instant; use this for production.

**SKUs and throughput:**
- `Basic`: up to 100 Mbps, no SLA, IKEv1 only — avoid for production.
- `VpnGw1` through `VpnGw5`: 650 Mbps to 10 Gbps aggregate, SLA backed.
- `VpnGw1AZ` through `VpnGw5AZ`: zone-redundant variants deployed across AZs — the right choice if the VNet region supports AZs.

**BGP support** — higher SKUs support BGP for dynamic route exchange. With BGP you don't have to manually maintain static route tables on both sides as your network topology changes.

> [!tip] Always deploy at least `VpnGw1AZ` in zone-enabled regions. The cost delta over `Basic` is significant, but the `Basic` SKU is being deprecated and has no SLA — it's not a production option.

@feynman

VPN Gateway is managed IKEv2 as a service — the same IPsec/IKEv2 you'd configure on a Cisco ASA or pfSense, but you don't manage the VM, the HA pair, or the BGP daemon yourself.

@card
id: azr-ch06-c007
order: 7
title: ExpressRoute Is Private Connectivity at Wire Speed
teaser: ExpressRoute gives you a dedicated, non-internet circuit between your on-premises network and Azure — higher throughput, predictable latency, and no encryption overhead, at a meaningfully higher price

@explanation

ExpressRoute is a private WAN connection to Azure that does not traverse the public internet. Your traffic goes from your on-premises edge router to a colocation provider, then over a dedicated circuit to Microsoft's network. You get:

- **Circuit speeds** from 50 Mbps up to 100 Gbps.
- **Predictable, low latency** — no shared internet contention.
- **No encryption overhead** — the circuit is private by nature, though you can layer MACsec or IPsec on top if your compliance requirements demand encryption at the wire level.

**Two connectivity models:**
- **Provider model** — you contract with one of Microsoft's 100+ connectivity partners (AT&T, Equinix, BT, etc.) who provision the circuit on your behalf and offer a managed service. Most organizations use this.
- **ExpressRoute Direct** — you physically connect at 10 Gbps or 100 Gbps directly into Microsoft's edge routers at a peering location. For carriers, very large enterprises, or anyone who needs the highest throughput and wants to cut out the intermediary provider.

**ExpressRoute Global Reach** — connects two on-premises locations to each other through the Microsoft backbone. If you have offices in New York and London, both connected to Azure via ExpressRoute, Global Reach lets New York-to-London traffic traverse Microsoft's backbone rather than the public internet.

**Cost comparison with VPN Gateway:**
- VPN Gateway: lower per-month cost, encrypted, max ~10 Gbps, internet-dependent latency.
- ExpressRoute: circuit fees + gateway fees, no built-in encryption, up to 100 Gbps, predictable SLA latency. Significantly more expensive — plan for at least $500–$2000+/month depending on bandwidth.

ExpressRoute is the right choice when you need consistent sub-10ms latency, high sustained throughput (hundreds of Gbps aggregate), or regulatory requirements that prohibit traffic over the public internet.

> [!warning] ExpressRoute has a higher operational burden than VPN Gateway — you need a connectivity partner or colo footprint, BGP configuration on your edge routers, and a plan for circuit redundancy. Deploying a redundant pair of circuits (two diverse paths) roughly doubles the cost.

@feynman

ExpressRoute is a leased line to Azure — the same category of decision as buying dark fiber or an MPLS circuit instead of using a VPN over broadband.

@card
id: azr-ch06-c008
order: 8
title: Azure DNS Covers Both Private and Public Resolution
teaser: Azure has two distinct DNS offerings that do very different things — one for name resolution inside your VNets, one for hosting public DNS zones — and you almost certainly need both

@explanation

Azure DNS is actually two separate services that share a brand name:

**Azure-provided DNS for VNet name resolution** — by default, every VM in a VNet can resolve other VMs in the same VNet by hostname. Azure's DNS server (`168.63.129.16`, the virtual IP Azure uses for platform services) handles this automatically. You don't configure anything for basic intra-VNet name resolution.

If you need to use your own DNS servers (for on-premises integration, split-horizon DNS, or a custom resolver), configure them under the VNet's DNS server settings. All VMs in the VNet will use those servers instead of Azure-provided DNS.

**Azure Private DNS Zones** — managed DNS zones that are only resolvable from within VNets. Key characteristics:
- Create a zone like `internal.mycompany.com` or `privatelink.blob.core.windows.net`.
- Link the zone to one or more VNets. A VNet can have up to 1,000 private zone links.
- Records in the zone are resolvable from any linked VNet, but not from the internet.
- Supports auto-registration: VMs in a linked VNet can automatically register their hostnames into the zone as they're created.

**Azure Public DNS** — a fully managed authoritative DNS hosting service for internet-facing domains. You delegate your public domain (e.g., `mycompany.com`) to Azure name servers, then manage records via the Azure portal, CLI, or Terraform. Azure DNS is backed by a global Anycast network with a 100% uptime SLA for name resolution.

> [!info] The Private Endpoint + Private DNS Zone integration is the most critical use of Azure Private DNS Zones in practice. When you create a Private Endpoint, Azure can auto-create the required DNS zone and A record — but only if you opt in. If you manage your own DNS infrastructure, you have to create and maintain these records yourself.

@feynman

Azure Private DNS Zones are Route 53 private hosted zones — same concept, same VNet-link model, same use case of giving internal services clean FQDNs without exposing them to the internet.

@card
id: azr-ch06-c009
order: 9
title: UDRs Override System Routes for Custom Traffic Paths
teaser: User-Defined Routes let you intercept subnet traffic and force it through a firewall or NVA instead of following Azure's default routing, which is how hub-spoke forced tunneling actually works

@explanation

Azure automatically creates system routes for every subnet: routes to other subnets in the VNet, routes to VNet peers, and a default `0.0.0.0/0` route pointing to the internet. These routes work without any configuration. But sometimes you want to override them — to send all outbound internet traffic through Azure Firewall for inspection, or to force traffic between spokes through a centralized NVA rather than directly over peering.

User-Defined Routes (UDRs) are custom route entries you define in a route table and associate with a subnet. Once associated, the route table's entries take precedence over system routes for matching prefixes.

A UDR entry has three parts:
- **Address prefix** — the CIDR range this route applies to (e.g., `0.0.0.0/0`, `10.0.0.0/8`).
- **Next hop type** — what Azure should forward matching traffic to:
  - `VirtualAppliance`: a specific IP address (your NVA or Azure Firewall private IP).
  - `VirtualNetworkGateway`: sends traffic to the VPN or ExpressRoute gateway.
  - `Internet`: explicit internet routing.
  - `None`: drop the traffic (used to create a black hole route for network segments that shouldn't be reachable).
- **Next hop IP** — required when next hop type is `VirtualAppliance`.

**The forced tunneling pattern** — a `0.0.0.0/0` UDR pointing to Azure Firewall's private IP, attached to every spoke subnet, ensures all outbound internet traffic passes through the firewall for inspection and logging before leaving Azure. Without this UDR, VMs with public IPs bypass the firewall entirely.

**Important constraint** — the VM or NVA that traffic is forwarded to must have **IP forwarding** enabled on its NIC. Azure drops forwarded traffic by default because it prevents IP spoofing. For Azure Firewall, this is handled automatically.

> [!tip] Always associate a route table with a subnet before deploying resources into it when you're building a hub-spoke topology. Adding the route table after resources are deployed works, but it causes a brief routing disruption as the association propagates.

@feynman

UDRs are custom iptables FORWARD rules in the VNet's routing layer — you're telling Azure "when traffic matches this prefix, don't use the default next hop, send it here instead."

@card
id: azr-ch06-c010
order: 10
title: Hub-and-Spoke Is the Standard Enterprise Topology
teaser: Hub-and-spoke organizes VNets into a shared services hub and isolated workload spokes — it's the dominant enterprise Azure network pattern and the basis for most compliance-friendly architectures

@explanation

A flat VNet mesh — where every VNet peers with every other — breaks down quickly. With 10 VNets you need up to 45 peering connections. Routing between spokes requires transitive hops that don't exist natively. Hub-and-spoke solves this by introducing hierarchy.

**The hub VNet** hosts shared services that every spoke needs:
- Azure Firewall (or a third-party NVA) for inspecting all north-south and east-west traffic.
- VPN Gateway or ExpressRoute Gateway for on-premises connectivity.
- Azure Bastion for secure VM access without public IPs.
- Shared DNS infrastructure (e.g., Azure DNS Private Resolver).
- Azure Monitor and logging agents.

**Spoke VNets** each contain one workload or environment (e.g., production app, dev environment, data platform). Each spoke is peered to the hub only. UDRs in each spoke force traffic through the hub's firewall before it leaves the spoke — this is what makes east-west isolation work. Spoke-to-spoke traffic that must be permitted goes: source spoke → hub firewall → destination spoke.

**Why not full mesh?** Full mesh peering grows as O(n²). It also means every spoke can potentially reach every other spoke if your NSGs aren't perfect — hub-spoke gives you a chokepoint (the firewall) that enforces inter-workload policies in one place.

**Azure Virtual WAN** — Microsoft's managed hub-and-spoke service. Instead of building your own hub VNet with manually configured peering and UDRs, you create a Virtual WAN and Virtual Hubs that handle peering, routing, and gateway management automatically. Virtual WAN supports:
- Any-to-any connectivity between spokes without manual UDRs.
- Integrated ExpressRoute and VPN gateways per hub.
- Up to 500 VNets per hub.

**The tradeoff:** Virtual WAN costs more than DIY hub-and-spoke and gives you less control over exact routing behavior. DIY is more flexible and cheaper; Virtual WAN is faster to operate at scale (50+ VNets) when routing complexity starts to dominate engineering time.

> [!info] For greenfield architectures with more than 3–5 workload VNets, start with hub-and-spoke from day one. Retrofitting the topology after workloads are deployed is painful — it requires reprovisioning gateways, updating peerings, and redeploying route tables across every subnet.

@feynman

Hub-and-spoke is the VNet equivalent of a star network topology from networking fundamentals — except the hub isn't a dumb switch, it's a firewall, gateway, and DNS server all sharing the same private address space.
