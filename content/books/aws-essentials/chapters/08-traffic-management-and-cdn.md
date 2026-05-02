@chapter
id: aws-ch08-traffic-management-and-cdn
order: 8
title: Traffic Management and CDN
summary: AWS gives you three load balancers, a global DNS service, a CDN, a WAF, DDoS protection, and a global accelerator — knowing when to reach for each one is the difference between a resilient system and an over-engineered one.

@card
id: aws-ch08-c001
order: 1
title: Application Load Balancer Fundamentals
teaser: ALB operates at Layer 7, so it can inspect HTTP headers, paths, and query strings before deciding where to send traffic — that's the capability that separates it from every other AWS load balancer.

@explanation

ALB is the right choice for the vast majority of HTTP/HTTPS workloads. It terminates TLS, parses the HTTP request, evaluates rules you define, and routes to the appropriate target group. The model has three layers: a listener (port + protocol), rules (conditions evaluated top-down with a final default), and actions (forward, redirect, return a fixed response, or authenticate via Cognito/OIDC).

Routing conditions you can match on:
- **Host header** — route `api.example.com` and `app.example.com` to different target groups from the same ALB.
- **Path** — send `/images/*` to a different fleet than `/api/*`.
- **Query string and HTTP method** — useful for A/B routing or splitting GET vs POST to different handlers.

Target groups can contain EC2 instances, ECS tasks, Lambda functions, or raw IP addresses (useful for on-premises targets via Direct Connect). ALB supports sticky sessions via cookies so stateful apps can pin users to the same instance, and it has native WebSocket and HTTP/2 support — connections are upgraded transparently.

One limitation to be aware of: ALB introduces measurable latency (single-digit milliseconds) because it terminates the connection. For pure TCP workloads where that matters, NLB is the better fit.

> [!info] ALB charges per Load Balancer Capacity Unit (LCU), which combines new connections, active connections, processed bytes, and rule evaluations. High rule complexity can raise your bill even with modest traffic.

@feynman

ALB is the smart receptionist who reads your request and sends you to the right department based on what you asked for, not just which door you walked through.

@card
id: aws-ch08-c002
order: 2
title: Network Load Balancer for Layer 4 Traffic
teaser: NLB passes TCP and UDP packets at wire speed with microsecond latency — it doesn't inspect application-layer content, and that's precisely the point.

@explanation

NLB operates at Layer 4 (TCP/UDP/TLS). It makes forwarding decisions based on IP protocol data alone — no HTTP parsing, no rule evaluation overhead. This makes it capable of handling millions of requests per second at latencies in the hundreds of microseconds, and it scales to extreme throughput without manual intervention.

The feature that sets NLB apart architecturally: each NLB gets a **static Elastic IP per Availability Zone**. You can tell a customer "whitelist these three IPs" and they never change, even if you scale the fleet behind it. ALB cannot offer this.

TLS termination is optional — you can configure NLB to terminate TLS itself (handing plaintext to backends) or pass the TLS stream through untouched to the target, which is required if your backend needs the raw TLS handshake (e.g., for mutual TLS or custom certificate validation at the application layer).

When NLB beats ALB:
- Pure TCP protocols (databases over non-HTTP ports, SMTP, custom binary protocols).
- UDP workloads (DNS resolvers, game servers, VoIP).
- Static IP requirement — NLB is the only AWS load balancer that supports Elastic IPs.
- AWS PrivateLink backing — PrivateLink endpoint services must be backed by an NLB.
- Lowest latency requirements where even ALB's few milliseconds matter.

> [!warning] NLB preserves the client's source IP by default for TCP targets. This can cause asymmetric routing issues if your targets are in multiple AZs with cross-zone load balancing disabled. Verify your routing tables before enabling cross-zone.

@feynman

NLB is the post office that delivers sealed packages based on the address on the envelope — it doesn't open them to decide the route, so it moves far faster than the sorting office that reads the contents.

@card
id: aws-ch08-c003
order: 3
title: Gateway Load Balancer for Security Appliances
teaser: GWLB lets you insert third-party firewalls and IDS/IPS appliances into your traffic path transparently, without changing the source or destination of the packets flowing through them.

@explanation

Gateway Load Balancer solves a specific problem: you want to route all traffic through a fleet of security appliances (firewalls, intrusion detection, deep packet inspection) before it reaches your workload, but you don't want the appliance to be aware that it's sitting in the path — and you don't want to change routing on the endpoints being protected.

GWLB handles this using the **GENEVE protocol** (port 6081). Traffic is encapsulated in a GENEVE tunnel, forwarded to the appliance fleet, inspected, and re-encapsulated back to the original destination. The original source IP is preserved throughout. Appliances don't need to know about the routing; they just see and process the inner packet.

The deployment pattern uses a **Gateway Load Balancer Endpoint (GWLBE)**, which is a VPC endpoint you place in the consumer VPC. Route tables in that VPC direct traffic to the GWLBE, which sends it to the GWLB in the security appliance VPC. This works across accounts, making it the standard pattern for centralized inspection in AWS Organizations environments.

GWLB distributes traffic across your appliance fleet with health checking, so if an appliance instance fails, traffic is rerouted to healthy ones within seconds.

> [!tip] GWLB is almost always used with third-party appliances from the AWS Marketplace (Palo Alto, Fortinet, Check Point). If you're building a greenfield environment and considering whether to use it, the answer depends on whether your compliance requirements mandate specific appliance vendors — native AWS security tools (WAF, Shield, Security Hub) cover most workloads without the GWLB complexity.

@feynman

GWLB is the invisible toll booth on the highway — every car passes through a security check before reaching its destination, but the driver just sees the road they were already on.

@card
id: aws-ch08-c004
order: 4
title: Amazon Route 53 DNS and Routing
teaser: Route 53 is AWS's authoritative DNS service — it resolves your domain names globally and, unlike most DNS services, it can actively monitor your endpoints and reroute traffic when they fail.

@explanation

Route 53 manages hosted zones — containers for DNS records for a domain. A **public hosted zone** answers queries from the public internet. A **private hosted zone** answers queries only from within one or more VPCs, letting you use custom domain names internally without exposing them publicly.

Record types you'll use constantly:
- **A** — maps a name to an IPv4 address.
- **AAAA** — maps a name to an IPv6 address.
- **CNAME** — maps a name to another name. Cannot be used at the zone apex (e.g., `example.com` itself — only subdomains).
- **Alias** — an AWS-specific extension that maps a name to an AWS resource (ALB, CloudFront, S3 website endpoint, etc.) and *can* be used at the zone apex. Alias records are free for queries to AWS resources and automatically follow IP changes.

**Health checks** are the feature that makes Route 53 more than a DNS directory. You configure health checks against endpoints (HTTP, HTTPS, TCP, or via CloudWatch alarms), and Route 53 uses them to determine whether to include a record in responses. A healthy endpoint is served; an unhealthy one is excluded until it recovers. This is the foundation for DNS-based failover.

> [!info] Route 53 uses a global anycast network of DNS servers across 13 globally distributed infrastructure locations plus an extended network of PoPs. Query latency to Route 53 is typically under 10ms from most regions.

@feynman

Route 53 is the phone book that not only has everyone's number but also knows when lines are disconnected and routes your call to the backup automatically.

@card
id: aws-ch08-c005
order: 5
title: Route 53 Routing Policies in Depth
teaser: Route 53's routing policies turn DNS into a traffic controller — you can shift load, route by geography, failover automatically, and roll out changes gradually, all without touching application code.

@explanation

Each policy fits a specific use case:

**Simple** — returns one or more values with no logic. Use for single-endpoint or round-robin scenarios. No health checks.

**Weighted** — assigns a numeric weight (0–255) to each record; traffic is distributed proportionally. A weight of 0 removes the record from rotation. Use for A/B deployments or gradual traffic shifts: start a new deployment at weight 10, old at 90, then shift incrementally.

**Latency-based** — Route 53 measures latency from the resolver's region to each configured AWS region and routes to the lowest-latency option. There is no geographic rule — a user in London will be sent to `eu-west-1` only if it's actually faster than `us-east-1` for their resolver. Update your configuration when you add new regions; stale records serve traffic to regions that may no longer exist.

**Failover** — designates one record as primary and one as secondary. Traffic goes to primary when healthy; Route 53 automatically serves the secondary when the primary's health check fails. Recovery is automatic when the primary comes back.

**Geolocation** — routes based on the geographic origin of the query (country or continent). Unlike latency-based, this is a policy decision: "users in Germany must be served by `eu-central-1`." Useful for data residency compliance. Always configure a default record for queries that don't match any location.

**Geoproximity** — routes to the nearest region but allows a **bias** adjustment (–99 to +99) to expand or shrink each region's effective coverage area. Unlike geolocation, it's distance-based, not rules-based. Requires Route 53 Traffic Flow.

**Multivalue answer** — returns up to 8 healthy records in response to each query. Not a load balancer substitute, but improves client-side resilience when one returned IP is unreachable.

@feynman

Route 53 routing policies are like different dispatch strategies for a taxi fleet — you can route by proximity, by capacity, by rules about who's allowed in which zone, or just send everyone to whoever answers the phone first.

@card
id: aws-ch08-c006
order: 6
title: Amazon CloudFront CDN Architecture
teaser: CloudFront caches your content at 450+ edge locations worldwide so users retrieve assets from a server near them instead of making a round-trip to your origin — the difference between 20ms and 200ms.

@explanation

CloudFront is a global CDN that sits in front of your origin (S3 bucket, ALB, API Gateway, or any publicly reachable HTTP server). You create a **distribution**, which is the configuration object that defines origins, cache behaviors, and access controls. Each distribution gets a `*.cloudfront.net` domain; you alias it to your own domain via Route 53.

**Origins** CloudFront can pull from:
- **S3** — the most common pattern for static sites and asset delivery.
- **ALB or API Gateway** — for dynamic API responses that benefit from edge caching or geo-filtering.
- **Custom origin** — any HTTP/HTTPS server, including on-premises.

**Cache behaviors** define which requests go to which origin and with what cache settings. You configure path patterns (`/images/*`, `/api/*`) and each behavior can have its own TTL, compression, and allowed HTTP methods. This lets you cache static assets aggressively while bypassing the cache for API calls entirely.

**Origin Access Control (OAC)** replaced the older Origin Access Identity (OAI) in 2022. OAC uses IAM policies to restrict your S3 bucket so only CloudFront can read it — the bucket itself stays private. Prefer OAC for all new distributions; OAI is legacy.

CloudFront supports HTTPS everywhere — you can enforce HTTPS-only between viewers and CloudFront, and separately between CloudFront and your origin. Free SSL certificates via ACM for CloudFront distributions.

> [!warning] CloudFront caches are eventually consistent across PoPs. An invalidation propagates within seconds on average but can take up to a few minutes globally. Plan your cache TTLs and deployment strategy accordingly — don't assume a cache flush is instantaneous.

@feynman

CloudFront is like having a local warehouse in every major city stocked with your most popular products — customers get same-day delivery instead of waiting for a cross-country shipment from your main warehouse.

@card
id: aws-ch08-c007
order: 7
title: CloudFront Caching, Invalidation, and Edge Functions
teaser: A high cache hit ratio is the metric that actually tells you whether your CloudFront distribution is saving money and latency — and it's entirely determined by how you configure your cache key.

@explanation

CloudFront's cache key is the fingerprint that determines whether two requests share a cached response. By default, the cache key is just the URL path. Every header, query string, or cookie you add to the cache key creates a new cache dimension — which increases fidelity but fragments your cache, reducing the hit ratio.

The TTL hierarchy:
- **Minimum TTL** — CloudFront will not cache for less than this, regardless of origin headers.
- **Default TTL** — used when the origin sends no `Cache-Control` header.
- **Maximum TTL** — CloudFront will not cache for longer than this, regardless of what the origin says.

For a high hit ratio: keep the cache key narrow (only vary on what genuinely produces different content), set long TTLs for versioned assets (cache-bust with filename hashing), and set short or zero TTLs for truly dynamic responses.

**Invalidations** remove objects from the cache before TTL expires. AWS charges $0.005 per path after the first 1,000 paths/month. A wildcard (`/images/*`) counts as one path, so use wildcards for bulk invalidations during deployments. Invalidations are operationally expensive in terms of consistency — they are eventually propagated and create a thundering herd against your origin until the cache refills.

**Edge compute options:**
- **CloudFront Functions** — JavaScript only, sub-millisecond execution, viewer request/response only. Use for URL rewrites, header manipulation, and A/B routing at scale. Free tier: 2 million invocations/month.
- **Lambda@Edge** — Node.js or Python, up to 5 seconds, runs at viewer and origin events. Use for auth, dynamic origin selection, and content personalization. More powerful but ~10x more expensive per invocation.

@feynman

Cache key design is like designing a database index — the more columns you include, the more precise your lookups, but also the larger and more fragmented your index becomes.

@card
id: aws-ch08-c008
order: 8
title: AWS WAF Web Application Firewall
teaser: WAF inspects HTTP requests before they reach your application and blocks or counts them based on rules you define — it's your first line of defense against OWASP attacks, bots, and volumetric abuse.

@explanation

AWS WAF attaches to CloudFront, ALB, API Gateway, or AppSync as a **web ACL**. The web ACL contains rules evaluated in priority order; each rule can allow, block, count, or CAPTCHA the request. If no rule matches, the web ACL's default action applies.

Rule sources:
- **Managed rule groups** — pre-built sets maintained by AWS or third-party vendors. AWS-managed groups include the OWASP Core Rule Set (SQLi, XSS, command injection), AWS Bot Control (known bots, scrapers, crawlers), IP Reputation lists (anonymizers, Tor exit nodes), and Amazon IP reputation lists.
- **Custom rules** — you define the match conditions (IP set, geo match, rate limit, string match on any request component).

**Rate-based rules** are a key DDoS mitigation lever. You specify a threshold (e.g., 2,000 requests in 5 minutes) and a scope (all requests, or grouped by IP or other key). When the threshold is exceeded, WAF blocks further requests from that source until the rate drops below the threshold. This is effective against HTTP floods that the volumetric protections in Shield Standard don't cover.

WAF pricing: $5/month per web ACL, $1/month per rule, $0.60 per 1 million requests inspected. Managed rule groups have an additional per-group fee. At high traffic volumes, WAF costs can be significant — evaluate the managed rule groups you actually need rather than enabling all of them by default.

> [!tip] Start with the AWS Managed Rules Core Rule Set in Count mode before switching to Block mode. Count mode lets you verify what real traffic your rule set would block before you start dropping legitimate requests.

@feynman

WAF is the bouncer at the door checking each visitor against a list of known troublemakers and suspicious behavior patterns before letting them into the venue.

@card
id: aws-ch08-c009
order: 9
title: AWS Shield Standard and Advanced
teaser: Shield Standard is free DDoS protection you already have; Shield Advanced is the $3,000/month upgrade that makes sense only when the cost of a successful DDoS attack significantly exceeds that number.

@explanation

**Shield Standard** is automatically applied to all AWS accounts at no charge. It defends against the most common Layer 3 and Layer 4 attacks — SYN floods, UDP reflection, volumetric amplification attacks. It handles the majority of DDoS events you'll encounter without any configuration.

**Shield Advanced** upgrades your protection across four dimensions:

1. **Layer 7 DDoS protection** — Shield Advanced integrates with WAF to detect and auto-remediate application-layer attacks, not just volumetric ones. It can automatically create temporary WAF rules during an active attack.
2. **DDoS cost protection** — AWS credits you for scaling costs (EC2, ELB, CloudFront, Route 53) caused by a DDoS event. This is the primary financial reason to buy Shield Advanced at large scale.
3. **Shield Response Team (SRT)** — 24/7 access to AWS security specialists during active attacks. They can modify WAF rules, adjust rate limits, and triage in real time. Requires prior IAM permission delegation.
4. **Advanced attack visibility** — near-real-time metrics in CloudWatch and attack vectors visible in the Shield console.

Shield Advanced pricing: $3,000/month flat fee plus data transfer out fees. The flat fee covers an entire organization's consolidated billing accounts with one subscription. It makes financial sense when: your attack exposure is significant (large-scale consumer application, financial services, gaming), you need the SRT access for compliance, or the DDoS cost protection clause is worth the premium.

> [!info] Shield Advanced subscription includes AWS WAF at no additional charge for the resources it protects — if you were planning to deploy WAF anyway, factor that into the cost comparison.

@feynman

Shield Standard is the smoke alarm that's already in your building; Shield Advanced is the 24/7 fire monitoring service with a team standing by to respond — worthwhile if your building is large enough that a fire causes catastrophic business loss.

@card
id: aws-ch08-c010
order: 10
title: AWS Global Accelerator for TCP/UDP Acceleration
teaser: Global Accelerator routes your traffic into AWS's private backbone at the nearest edge location, cutting the number of public internet hops between your users and your application by routing over AWS infrastructure instead of the open internet.

@explanation

Global Accelerator gives you two static Anycast IP addresses that are advertised from all AWS edge locations globally. When a user connects to one of those IPs, traffic enters the AWS network at the nearest edge PoP and travels over AWS's private global backbone to your application endpoint — avoiding the congestion and variable latency of the public internet for most of the journey.

It works for **TCP and UDP**, not just HTTP. This is the key differentiator from CloudFront, which only accelerates HTTP/HTTPS. Global Accelerator is the right tool for:
- Non-HTTP protocols (game servers using UDP, IoT device communication, VoIP).
- Dynamic content that cannot be cached (real-time APIs, live data feeds).
- Applications that need static entry-point IPs (useful for customer firewall whitelisting, same benefit as NLB's Elastic IPs but at global scope).
- Gaming and real-time multiplayer (sub-100ms latency requirements where consistent routing matters).

**Health-check-based failover** operates in under 30 seconds — significantly faster than DNS-based failover via Route 53, which is bounded by DNS TTLs and caching behavior. This makes Global Accelerator better for active/active or active/standby architectures where fast automatic failover is a requirement.

Pricing: $0.025/hour per accelerator (about $18/month) plus a data transfer premium over standard AWS data transfer rates.

When **CloudFront beats Global Accelerator**: static or cacheable content (CloudFront serves from cache at the edge, eliminating the backend trip entirely), HTTP-only workloads where caching applies, or cost-sensitive scenarios (CloudFront data transfer pricing is typically lower).

@feynman

Global Accelerator is like getting a dedicated express lane on the highway that bypasses all public traffic — your packets travel on AWS's private road from the nearest on-ramp to your data center, instead of fighting through the public internet the whole way.
