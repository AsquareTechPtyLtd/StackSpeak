@chapter
id: plf-ch07-service-catalogs-and-discovery
order: 7
title: Service Catalogs and Discovery
summary: A service catalog is the platform's organizational memory — what services exist, who owns them, how they depend on each other, what state they're in — and the value of the catalog is directly proportional to whether the data inside it is fresh.

@card
id: plf-ch07-c001
order: 1
title: The Catalog as Organizational Memory
teaser: Without a catalog, the organization's knowledge of its own systems lives in people's heads — and it leaves every time someone does.

@explanation

Every engineering organization eventually builds up a mental model of what they run: which services exist, who built them, what they call, what calls them. For a team of five, that model fits in a shared Slack channel and a few sticky notes. For a team of five hundred, it fits in no one's head — and the absence of a structured record has real costs.

The costs of not having a catalog:

- **Incident response slows down.** An on-call engineer gets paged on a service they've never touched and spends twenty minutes finding who owns it, what it depends on, and where its runbook lives — time that could have been seconds with a catalog.
- **Duplicate services multiply.** Without visibility into what already exists, teams build the same service twice. This is more common than it sounds, especially in organizations that have grown through acquisitions or rapid hiring.
- **Decommissioning becomes archaeology.** Deprecating a service requires knowing everything that calls it. Without a dependency map, you guess, you ask around, and you deploy and hope nothing breaks.
- **Compliance audits become expensive.** Auditors want to know what processes personal data, what runs in production, who is accountable for each. Reconstructing that without a catalog takes weeks.

A service catalog is not a document — it is a live system of record that the platform maintains, not a wiki that engineers update when they remember to. The distinction matters enormously for catalog freshness.

> [!info] The CNCF Platform Engineering maturity model lists service catalog adoption as one of the earliest indicators of platform maturity. Teams that invest in it early report significantly lower mean time to recovery during incidents.

@feynman

A service catalog is the platform's equivalent of a city's property register — a maintained record of what exists, who owns it, and where it is, so that nobody has to rediscover that information from scratch every time they need it.

@card
id: plf-ch07-c002
order: 2
title: Backstage's Software Catalog
teaser: Backstage, open-sourced by Spotify in 2020 and now a CNCF incubating project, is the dominant OSS implementation of the service catalog — and its entity model has become the de facto vocabulary for the space.

@explanation

Backstage models the engineering organization as a graph of entities. Each entity has a kind, a name, a namespace, a set of metadata fields, and a set of relations to other entities. The catalog is built by ingesting entity descriptor files — YAML files that live alongside the code they describe.

The core entity kinds:

- **Component** — a deployable artifact: a service, a library, a website, a pipeline. The most common entity kind.
- **API** — an interface exposed by a Component. Linked to an OpenAPI, GraphQL, Async API, or gRPC spec.
- **System** — a logical grouping of Components and APIs that together serve a product or business function.
- **Domain** — a higher-level grouping of Systems, typically mapped to a business domain.
- **Resource** — a piece of infrastructure a Component depends on: an S3 bucket, a database, a queue.
- **Group** — a team or organizational unit that owns entities.
- **User** — an individual mapped to a Group.

A minimal component descriptor:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payments-service
  description: Handles payment processing and settlement
  annotations:
    github.com/project-slug: acme/payments-service
    pagerduty.com/integration-key: "abc123"
spec:
  type: service
  lifecycle: production
  owner: group:payments-team
  dependsOn:
    - component:ledger-service
    - resource:payments-postgres
```

Relations between entities — `ownedBy`, `dependsOn`, `providesApi`, `consumesApi` — form a graph that Backstage renders as a visual dependency map.

> [!tip] Backstage's catalog is a pull model: the platform ingests YAML files that teams commit to their own repos. This is intentional — it keeps ownership co-located with the code rather than in a central admin panel that no one updates.

@feynman

Backstage's catalog is like a city directory where every resident files their own entry in a standard form — the platform collects all those entries and assembles them into a searchable map that everyone in the organization can query.

@card
id: plf-ch07-c003
order: 3
title: Ownership Metadata
teaser: The owner field is the most load-bearing field in any catalog entity — without it, everything else in the catalog is just inventory with no accountability attached.

@explanation

Ownership is what converts a catalog from a passive list into an actionable system. Every service, every API, every resource in the catalog should have an owning team. That single field does more work than any other piece of metadata.

What ownership enables:

- **Incident routing.** Alerting systems, PagerDuty integrations, and on-call schedules can be populated automatically from the catalog's owner field. An alert fires; the platform looks up the service in the catalog; it pages the owning team's on-call rotation.
- **Access control.** Which team can deploy to production, rotate secrets, or merge to a protected branch can be driven from catalog ownership rather than managed as a separate list.
- **Blast radius scoping.** When a platform change is risky, the catalog tells you which teams own the affected services and who to notify.
- **Organizational reporting.** Engineering leadership can see, at a glance, how many services each team owns, which teams own deprecated services, and which services have no owner — the orphan problem.

The hardest part of ownership is not the data model — it is the organizational discipline to keep it updated. Teams reorganize, people leave, services get transferred. A catalog with stale ownership is worse than a catalog with no ownership, because it routes incidents to the wrong team with false confidence.

Conventions that help: require the owner field to be a Group entity (never an individual User), enforce non-null ownership via CI validation, and review orphaned entities — those whose owner Group no longer exists — on a regular cadence.

> [!warning] Assigning ownership to a named individual rather than a team is a common mistake. When that individual leaves, the service becomes an orphan overnight and no automated system catches it.

@feynman

The owner field in a catalog entity is the link between a piece of software and the humans accountable for it — without that link, you have inventory, but you don't have anyone to call when it breaks.

@card
id: plf-ch07-c004
order: 4
title: Service Dependencies — Declared vs Discovered
teaser: You can ask teams to declare their dependencies, or you can infer them from runtime traffic — both approaches have gaps, and mature catalogs use both.

@explanation

A dependency map tells you what a service calls and what calls it. It's the foundation for impact analysis, blast radius assessment, and safe decommissioning. The challenge is keeping it accurate.

**Declared dependencies** are explicit: a team adds a `dependsOn` field to their catalog entity listing the services and resources they call. This is cheap to implement and easy to read. The failure mode is that declared dependencies drift from reality. A team adds a call to a new service, forgets to update the catalog YAML, and the catalog silently lies.

**Discovered dependencies** are inferred from real traffic. Service mesh data (Istio, Linkerd), distributed tracing systems (Jaeger, Tempo), and APM platforms (Datadog, Honeycomb) observe actual network calls and build a dependency map from what they see. Discovered maps are accurate by definition — they reflect what is really happening, not what someone documented. The failure mode is that they only capture dependencies that have been exercised recently, and they require service mesh or instrumentation coverage that many organizations don't have uniformly.

**The practical answer** is to use both: declared dependencies as the authoring surface that engineers maintain, and discovered dependencies as a validation layer that surfaces discrepancies. A CI check that compares the declared catalog YAML against the last 30 days of trace data and opens a PR to fix drift is a concrete implementation of this pattern.

> [!info] Service meshes make discovered dependency maps essentially free as a side effect. If your platform runs Istio or Linkerd, ingesting the traffic graph into your catalog is a high-value, low-effort integration.

@feynman

Declaring dependencies is like asking someone to list every person they called last month — discovered dependencies are what you get when you just look at the phone records; ideally you use both, because memory is fallible and records can be incomplete.

@card
id: plf-ch07-c005
order: 5
title: Service Maturity Scoring
teaser: A catalog that only records what services exist tells half the story — a maturity lifecycle field tells you whether each service is something you should build on, watch carefully, or stay away from.

@explanation

Not all services in a catalog are equal. Some are actively maintained production systems. Some are experimental prototypes that are still being validated. Some are legacy services that are on their way out but still receiving traffic. Without a lifecycle field, every service looks equally trustworthy — which is misleading and creates real risk.

Backstage uses a `lifecycle` field on Component entities. Common lifecycle values:

- **experimental** — proof-of-concept or early-stage service; not stable, not supported for external consumption.
- **production** — actively maintained, monitored, and supported. This is the default expectation for anything running real traffic.
- **deprecated** — still running, but teams should stop consuming it and migrate away. The owning team has committed to a sunset date.
- **sunset** — end-of-life date has passed or is imminent; the service will be decommissioned.

Beyond a simple lifecycle label, some organizations implement production readiness reviews (PRRs) that score services against a checklist: Does the service have an SLO? Does it have runbooks? Is it monitored? Does it have a defined on-call rotation? Does it have load testing results? A catalog that surfaced these scores per service would give consumers a much richer picture than a single lifecycle label.

Cortex and OpsLevel, two commercial catalog alternatives, have scoring built in as a first-class feature — a "service scorecard" that shows, for every service, how many of the defined production-readiness criteria it meets.

> [!tip] A catalog search filter for lifecycle is one of the highest-value UI features a platform team can implement. Developers looking for a service to depend on should be able to exclude everything that isn't in the `production` lifecycle with a single click.

@feynman

A lifecycle field on a catalog entity is the platform's way of telling you whether a service is a stable foundation to build on, a work in progress, or a condemned building you should move out of as soon as possible.

@card
id: plf-ch07-c006
order: 6
title: Catalog Freshness and Rot
teaser: A catalog that was accurate six months ago and hasn't been updated since is not a historical record — it is a liability, because people will trust it and act on stale data.

@explanation

Catalog rot is the universal failure mode. The problem is not that teams don't want to maintain their catalog entries — most teams, when they first adopt a catalog, are enthusiastic about keeping it up to date. The problem is that updating the catalog is a separate action from the work itself. When a team migrates a service to a new database, the catalog entry for the old database dependency stays in place unless someone consciously goes back and removes it.

The patterns that slow catalog rot:

- **Co-location of catalog YAML with code.** When the catalog descriptor file lives in the same repository as the service, changes to the service and updates to the catalog descriptor are more likely to happen in the same pull request. This reduces — but does not eliminate — drift.
- **CI validation.** A CI pipeline that lints the catalog YAML, validates that referenced owner Groups exist, and checks that declared resource dependencies exist in the catalog surfaces obvious errors before they merge.
- **Automated staleness detection.** Track the last time each catalog entry was reviewed or updated. Surface entries older than 90 days as "potentially stale" in the catalog UI. Make staleness visible rather than silent.
- **Periodic ownership reviews.** Quarterly, surface a list of all catalog entities and ask each owning team to confirm their entries are still accurate. Five minutes of review per team keeps the catalog healthy at scale.

The anti-pattern is a catalog maintained by a central team. When a platform team owns the data rather than each product team owning their own entries, updates require routing through a bottleneck, and the catalog perpetually lags reality.

> [!warning] A catalog with stale dependency data actively harms incident response — on-call engineers see the documented dependency graph, miss the undocumented ones, and diagnose in the wrong direction. Stale data is worse than missing data in this context.

@feynman

Catalog rot is what happens when the platform's memory is only as fresh as the last time someone bothered to update it — and the only reliable defense is making the update a natural part of the work rather than a separate chore.

@card
id: plf-ch07-c007
order: 7
title: Auto-Discovery from Infrastructure
teaser: Kubernetes labels, AWS resource tags, and GitHub repository topics are structured metadata already attached to your infrastructure — ingesting them into the catalog lets you discover services without waiting for teams to register themselves.

@explanation

The pull model of catalog population — teams commit YAML files that get ingested — is the right long-term pattern, but it has a bootstrapping problem. In the early stages of catalog adoption, or for infrastructure that predates the catalog, you need a way to populate entries without requiring every team to act first.

Auto-discovery ingests structured metadata that already exists on infrastructure and generates catalog entities from it:

**Kubernetes:** Every Deployment, StatefulSet, and DaemonSet can carry arbitrary labels. Labels like `backstage.io/kubernetes-id`, `team`, and `component` can be read by a catalog ingestion job that creates or updates catalog entities from what it finds in the cluster. Backstage ships a Kubernetes plugin that does this out of the box.

```yaml
# Kubernetes Deployment labels used for auto-discovery
labels:
  app: payments-service
  team: payments-team
  backstage.io/kubernetes-id: payments-service
  lifecycle: production
```

**AWS:** Resource tags on EC2 instances, RDS clusters, Lambda functions, S3 buckets, and EKS clusters can be read by a catalog ingestion job using the AWS SDK. Tags like `Owner`, `Service`, and `Environment` map directly to catalog entity fields.

**GitHub:** A Backstage plugin can scan all repositories in a GitHub organization, find `catalog-info.yaml` files, and ingest them automatically — without teams needing to explicitly register their repos.

The value of auto-discovery is coverage: it surfaces services that teams haven't registered manually, flags undocumented infrastructure, and gives the catalog a floor of completeness even when voluntary registration is incomplete.

> [!info] Auto-discovered entities are often marked with a `generated` annotation to distinguish them from manually curated entries. This lets catalog consumers know that auto-discovered metadata may be less complete than a team-authored entry.

@feynman

Auto-discovery from infrastructure labels is like reading the name tags on every machine in the building instead of waiting for each machine's owner to come to the front desk and introduce themselves.

@card
id: plf-ch07-c008
order: 8
title: TechDocs — Documentation in the Catalog
teaser: TechDocs is Backstage's documentation system — it renders Markdown from a service's repository directly inside the catalog, so documentation lives next to the service it describes and travels with it.

@explanation

The failure mode of most internal documentation is that it lives somewhere else. The service lives in GitHub. The API reference lives in Confluence. The runbook lives in a Notion page. The architecture diagram lives in someone's Google Drive. Finding the right document for a service in an incident requires knowing where to look, which requires prior knowledge, which is exactly what new team members and incident responders don't have.

TechDocs solves this by treating documentation as a build artifact of the service repository:

- Engineers write documentation as Markdown files alongside their code, organized with a `mkdocs.yml` configuration file.
- The TechDocs build pipeline renders that Markdown into a static documentation site.
- Backstage's catalog entry for the service includes a "Docs" tab that renders the built documentation inline.
- Navigating to a service in the catalog and clicking "Docs" takes you directly to that service's documentation — no context-switching, no hunting.

The annotation in the catalog YAML that enables TechDocs:

```yaml
metadata:
  annotations:
    backstage.io/techdocs-ref: dir:.
```

This tells Backstage to look for a `docs/` folder and `mkdocs.yml` in the same directory as the `catalog-info.yaml` file.

The tradeoff: TechDocs documentation must be maintained in Markdown in the repository. For teams with existing documentation in Confluence or Notion, migration is non-trivial. Many organizations run TechDocs and Confluence in parallel for years. The value compounds over time as new services start in TechDocs from day one.

> [!tip] The highest-value TechDocs content is not architecture documents — it is the runbook for the service's most common failure modes. A catalog that shows a service's top three alerts and their runbooks in the same view dramatically improves incident response speed.

@feynman

TechDocs is the practice of keeping a service's documentation in the same repository as the service itself, so that when you find the service in the catalog, the documentation is already there — not filed somewhere separately and slowly going out of date.

@card
id: plf-ch07-c009
order: 9
title: API Discovery in the Catalog
teaser: An API entity in the catalog is not just a label — it links to a machine-readable spec, making every service's interface discoverable and testable without asking the owning team for documentation.

@explanation

Internal APIs are the connective tissue of a microservice architecture, and the most common way to learn about an internal API is still to ask the team that owns it. A catalog with first-class API entities changes this: every API has a discoverable entry with a machine-readable spec that can be browsed, rendered, and validated without human intervention.

A Backstage API entity:

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payments-api
  description: REST API for initiating and querying payments
spec:
  type: openapi
  lifecycle: production
  owner: group:payments-team
  definition:
    $text: https://raw.githubusercontent.com/acme/payments-service/main/openapi.yaml
```

Backstage renders OpenAPI specs using Swagger UI inline in the catalog. GraphQL specs get an interactive explorer. AsyncAPI specs for event-driven interfaces get a topic and message browser.

The Component that exposes the API declares the relation:

```yaml
spec:
  providesApis:
    - payments-api
```

And the Component that consumes it declares:

```yaml
spec:
  consumesApis:
    - payments-api
```

This gives the catalog a complete, queryable map of which services expose which APIs and which services depend on them — the input to impact analysis when an API changes or is deprecated.

For organizations that expose APIs to partners or customers, a subset of the internal catalog can be published as a partner API directory — the same data model, restricted to entities tagged as externally consumable.

> [!info] API discovery in the catalog also enables automated contract testing. If both the producer and consumer declare the API relation, a CI pipeline can automatically verify that the producer's current implementation still satisfies the OpenAPI spec that consumers depend on.

@feynman

An API entity in the catalog is the service's front door made discoverable — it says what the API does, what shape its inputs and outputs take, and who is responsible for keeping it working, all in one findable place.

@card
id: plf-ch07-c010
order: 10
title: The Platform Inventory View
teaser: A service catalog that only covers application services misses half the picture — the clusters, databases, queues, feature flag systems, and secrets stores that those services run on are infrastructure entities that belong in the catalog too.

@explanation

Application services don't exist in isolation. A payment service depends on a PostgreSQL cluster, a Redis cache, an SQS queue, and a secrets manager. When that payment service's latency spikes, knowing which infrastructure components it touches is as important as knowing which other services call it. A catalog that only covers application components leaves the infrastructure layer invisible.

Backstage's Resource kind is the mechanism for cataloging infrastructure:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: payments-postgres
  description: Primary PostgreSQL cluster for the payments domain
  annotations:
    aws.amazon.com/arn: arn:aws:rds:us-east-1:123456789:db:payments-postgres
spec:
  type: database
  owner: group:payments-team
  system: payments-system
```

Infrastructure entities that belong in the catalog:

- **Compute clusters** — Kubernetes clusters, ECS clusters, or VM groups. Which teams' services run on which cluster?
- **Databases and caches** — RDS instances, ElastiCache clusters, DynamoDB tables. Who owns each? What services depend on each?
- **Message queues and event streams** — SQS queues, Kafka topics, EventBridge buses. What publishes? What consumes?
- **Feature flag systems** — LaunchDarkly projects, Unleash instances. Which services use which feature flag configurations?
- **Secrets stores** — AWS Secrets Manager paths, Vault namespaces. Which services consume which secrets?

This "platform inventory" view is what a platform team needs to run its own operations effectively — to know what they manage, who depends on it, and what the impact would be of a planned maintenance window or an unplanned failure.

> [!info] Cloud provider auto-discovery is particularly valuable for infrastructure entities. An ingestion job that reads AWS resource tags and creates Resource entities in the catalog is more reliable than asking teams to manually maintain resource entries.

@feynman

Adding infrastructure to the catalog is like putting the building's mechanical systems — the wiring, plumbing, and HVAC — on the same floor plan as the offices, so anyone troubleshooting knows where all the dependencies actually are.

@card
id: plf-ch07-c011
order: 11
title: The Catalog as Authorization Signal
teaser: If the catalog knows who owns every service, it can drive access control decisions — who can deploy, who can rotate secrets, who can approve changes — directly from catalog ownership rather than a separately managed permissions system.

@explanation

Most organizations manage access control separately from their service catalog: a list of who can deploy to production lives in a CI system or a cloud IAM policy, and that list has no structural connection to the catalog's ownership data. When teams change, the two systems drift. A service changes owners; the IAM policy doesn't update; the old team retains access and the new team spends a day getting permissions.

Using catalog ownership as the authorization signal eliminates this drift by making ownership the single source of truth for access:

- **Deployment authorization.** A CI/CD pipeline that checks the catalog before executing a deployment can verify that the deploying user is a member of the owning Group for the target service. No separate permissions list to maintain.
- **Secret access.** A secrets management system that integrates with the catalog can grant access to a secret based on catalog ownership — the team that owns the service that declares a dependency on the secret gets read access, automatically.
- **On-call paging.** PagerDuty, OpsGenie, and similar systems can sync their escalation policies from catalog Group membership. The catalog is the source of truth; the alerting system reflects it.

A concrete example: when a developer opens a deployment PR, the platform checks whether they are in the catalog Group that owns the target Component. If not, the deployment is blocked and the PR is labeled for review by the owning team. This is a repeatable, auditable access control decision that requires no separate ACL to maintain.

The tradeoff: this integration requires that catalog data is timely and accurate. Authorization decisions made on stale ownership data create either access denials for legitimate users or continued access for users who should have lost it. Catalog freshness is not just a documentation concern — when the catalog drives authorization, it becomes a security control.

> [!warning] Using the catalog as an authorization signal raises the stakes of catalog freshness significantly. A stale ownership record is no longer just misleading — it is a security and operational risk. Teams that adopt this pattern must invest in ownership review processes proportionate to the risk.

@feynman

Using the catalog for authorization means that when ownership changes, access changes with it — there is no separate permissions list to update, because ownership is the permissions list.

@card
id: plf-ch07-c012
order: 12
title: Alternatives to Backstage
teaser: Backstage is the dominant open-source option, but it is not the only one — Cortex, OpsLevel, and Roadie solve the same problem with different tradeoffs around self-hosting, scoring, and operational overhead.

@explanation

Backstage's breadth is both its strength and its weakness. It is a plugin-based framework that can do nearly anything — but that flexibility comes with significant operational overhead. Running Backstage in production requires a PostgreSQL backend, a hosted Node.js application, regular upgrades, and someone who understands the plugin ecosystem. For large organizations with a dedicated platform team, this is acceptable. For smaller teams, it can be too much to maintain.

**Cortex** is a SaaS service catalog that emphasizes service scorecards — a configurable set of production-readiness criteria that each service is scored against. Cortex integrates with GitHub, PagerDuty, Datadog, and similar tools to pull score-relevant data automatically rather than requiring teams to declare it. It charges per user per month. The tradeoff: you get a managed service with less operational overhead, but you are dependent on Cortex's data model and pricing.

**OpsLevel** is similar to Cortex — a SaaS catalog with a strong focus on service maturity scoring, automated checks, and team-based reporting. OpsLevel positions itself explicitly around software quality standards: define what "production ready" means for your organization, and OpsLevel continuously evaluates every service against that definition. The tradeoff is the same as Cortex: managed convenience versus vendor lock-in.

**Roadie** is a managed hosting layer for Backstage. You get Backstage's entity model, plugin ecosystem, and TechDocs support, but Roadie handles the infrastructure, upgrades, and security patching. This is a middle path — the open-source data model without the operational burden. It is more expensive than self-hosting but cheaper in engineering time than running Backstage from scratch.

**Custom-built catalogs** are more common than they should be. A simple internal service registry implemented as a database with a basic UI is fast to build and perfectly adequate for organizations with fewer than 50 services. The failure mode is that custom catalogs stop at inventory — they rarely get the plugin integrations, scoring, and graph rendering that make a catalog genuinely useful. As the organization grows, the custom catalog becomes a liability rather than an asset.

The decision framework:

- Under 50 services, small team: start with a simple registry or a managed SaaS tool.
- 50–200 services, platform team of 2–4: Roadie or OpsLevel balances capability and overhead.
- 200+ services, dedicated platform team: Backstage with custom plugins gives the most flexibility.

> [!info] All of these tools use a similar underlying data model — entities, owners, dependencies, lifecycle — because the problem they are solving is the same. Migrating between them is non-trivial but not impossible. The data is more portable than the integrations.

@feynman

Choosing a catalog tool is really a choice about how much operational burden your platform team can absorb — Backstage gives you the most control at the highest maintenance cost, SaaS tools give you less control at lower operational cost, and the right answer depends entirely on the size of your team.
