@chapter
id: plf-ch03-internal-developer-platforms
order: 3
title: Internal Developer Platforms (IDPs)
summary: An IDP is the integrated set of components — service catalog, scaffolding, CI/CD, secrets, observability, environment provisioning — that turn a collection of tools into a coherent platform; what's in the bundle and how it composes is the architecture choice.

@card
id: plf-ch03-c001
order: 1
title: What an IDP Actually Is
teaser: An Internal Developer Platform is the integrated layer above raw infrastructure that turns a pile of tools into a coherent, self-service developer experience — it's the assembly, not the individual parts.

@explanation

Raw infrastructure is not a platform. Having Kubernetes, Terraform, GitHub Actions, and Vault available to your developers is not the same as having a platform. The difference is integration and abstraction: an IDP connects those tools, exposes them through a consistent interface, and removes the cognitive overhead of wiring them together on every new project.

What an IDP provides:

- **A unified entry point.** Developers interact with the platform through a portal, a CLI, or a set of APIs rather than logging into five separate tools with five separate access models.
- **Opinionated defaults.** The platform encodes your organization's choices — which observability stack, which secrets manager, which CI/CD system — so teams don't re-litigate them per project.
- **Self-service provisioning.** Developers can create services, spin up environments, and manage their software lifecycle without filing tickets or waiting on a platform team.
- **Organizational paving.** The "golden path" concept: the platform makes the right way to do things the easiest way to do things.

The distinction that matters: an IDP is a product, not a project. It has users (developers), it has a roadmap, and it requires ongoing investment. Organizations that treat it as a one-time infrastructure configuration always end up with something that breaks when the original builder leaves.

> [!info] The term "IDP" is sometimes conflated with "developer portal." A portal (like Backstage's UI) is one component of an IDP — the front door, not the whole building.

@feynman

An IDP is what happens when a platform team stops handing developers a toolbox and starts handing them a finished workshop with the tools already wired together, labeled, and ready to use.

@card
id: plf-ch03-c002
order: 2
title: The Five IDP Components
teaser: A complete IDP bundles five capability layers — service catalog, scaffolding, environment provisioning, CI/CD integration, and observability defaults — and the architecture choice is how tightly you couple them.

@explanation

No single tool ships all five layers out of the box, and the canonical IDP stack is always assembled from multiple components. The five layers and what they do:

- **Service catalog.** A registry of every service, API, and data pipeline in the organization — who owns it, what it depends on, where its documentation lives, and what its current health is. Backstage is the most widely adopted catalog.
- **Scaffolding.** Templated creation of new services. A developer picks a template, fills in a few fields, and gets a repository with working CI, runbook stubs, observability hooks, and security defaults already in place.
- **Environment provisioning.** The ability to create, clone, and destroy deployment environments on demand — dev, staging, preview, ephemeral — without manual infrastructure work.
- **CI/CD integration.** The platform owns the pipeline skeleton (build, test, scan, deploy) and teams customize within defined extension points. GitHub Actions, GitLab CI, and Argo CD are the most common underlying tools.
- **Observability defaults.** Every service deployed through the platform automatically gets traces, logs, dashboards, and alerting. Opt-out, not opt-in.

The coupling question is the architecture decision: a tightly integrated IDP (like Humanitec or Port) owns more of the surface area and exposes it through a unified API. A loosely coupled IDP (like Backstage plus custom glue) gives more flexibility but puts the integration work on the platform team.

> [!tip] Build the catalog first. It has no runtime risk, immediately delivers value (discoverability, ownership clarity), and gives you the foundation every other layer references.

@feynman

An IDP's five components are like the departments in a well-run office: the directory tells you who does what, HR onboards new people instantly, facilities creates your workspace, IT connects your tools, and building management keeps the lights on without you asking.

@card
id: plf-ch03-c003
order: 3
title: Service Catalog — the Organizational Memory
teaser: A service catalog is the single source of truth for what runs in production, who owns it, and how it connects to everything else — and Backstage has become the de-facto open-source implementation.

@explanation

A service catalog answers three questions that are otherwise surprisingly hard in large engineering organizations: what services exist, who owns each one, and what does each one depend on?

What a catalog tracks per service:

- **Ownership metadata.** Team, on-call rotation, Slack channel, escalation policy. This is the highest-ROI data in the catalog — it turns "what is this and who do I ask?" from a 20-minute investigation into a five-second lookup.
- **API contracts.** OpenAPI specs, gRPC definitions, event schemas. The catalog becomes the API marketplace.
- **Dependencies.** Which other services, databases, and queues does this service consume? Dependency graphs let you model blast radius before a change ships.
- **Runtime state.** CI/CD pipeline status, recent deployments, open incidents. The catalog becomes the operational dashboard.
- **Documentation and runbooks.** Linked from the catalog entry so they're findable without searching Confluence.

Backstage, open-sourced by Spotify in 2020, structures this data using a YAML-based entity model (`catalog-info.yaml` files committed alongside the service code). Teams declare their service; the catalog discovers and indexes it. The model supports services, APIs, teams, domains, resources, and systems as first-class entity types.

The catalog is only as good as its data. Stale ownership metadata is worse than no metadata because it sends incidents to the wrong team. The catalog must be kept fresh — automated checks against the repository and on-call tool are a minimum.

> [!warning] A catalog populated in a big-bang migration and then neglected goes stale within months. Build automated staleness detection from day one, not as a follow-up.

@feynman

A service catalog is the engineering equivalent of a building's floor plan posted at every entrance: it tells you what's in each room, who's responsible for it, and how the rooms connect — so you can find what you need without wandering the halls.

@card
id: plf-ch03-c004
order: 4
title: Scaffolding — the Two-Minute New Service
teaser: Scaffolding turns starting a new service from a multi-day copy-paste exercise into a two-minute self-service operation, and the template is where the platform team's architecture decisions live.

@explanation

Without scaffolding, every new service starts the same way: a developer clones a reference repo, strips out the service-specific bits, updates the CI configuration, registers the service in the catalog, hooks up the secrets manager, and adds the Prometheus annotations. This takes a day or two and is done inconsistently across teams.

Scaffolding replaces that with a template-driven wizard. The developer provides a service name, picks a runtime (Go microservice, Python worker, React frontend), and gets a repository that already has:

- Working CI/CD pipeline (GitHub Actions or GitLab CI)
- Dockerfile and container registry configuration
- Observability annotations (OpenTelemetry instrumentation)
- Secrets injection pattern
- `catalog-info.yaml` pre-populated and registered with the catalog
- README and runbook stubs

Backstage's Software Templates feature is the most used implementation. Templates are defined in YAML with a parameter schema and a set of actions (fetch skeleton, run cookiecutter, create GitHub repo, register in catalog). The developer fills in a form; the platform executes the steps.

The "two-minute new service" is a measurable goal. Teams that achieve it report a meaningful reduction in the time-to-first-deploy for new projects and — more importantly — higher consistency across services, since the template is the single place where architectural decisions about logging format, tracing conventions, and secrets patterns are enforced.

The template is not a one-time artifact. It needs to evolve with the platform. Version management (what happens to the 50 services already created from an older template?) is the hard operational problem.

> [!info] Backstage templates use Nunjucks templating and a step-based action model. The template fetches a skeleton, runs substitution, creates the repository, and registers the service — all in sequence from one YAML definition.

@feynman

Scaffolding is the platform team's way of saying: "we solved the hard setup problems once and encoded the answers in a template — you just fill in the name and we hand you a running foundation."

@card
id: plf-ch03-c005
order: 5
title: Provisioning — Infrastructure as an API
teaser: Declarative infrastructure tools like Crossplane, Pulumi, and Terraform Cloud let the platform expose infrastructure as self-service APIs, so developers can request a database the same way they request a microservice.

@explanation

Environment provisioning is the layer that lets developers create infrastructure without writing Terraform or filing a ticket. The platform team defines what resources are available (a Postgres database, a Redis cache, an S3 bucket) and exposes them as a catalog of composable resources. Developers declare what they need; the platform provisions it.

The three tools most commonly used for this layer:

**Crossplane** runs inside Kubernetes and extends the Kubernetes API with custom resource definitions for cloud infrastructure. A developer creates a `PostgreSQLInstance` Kubernetes resource; Crossplane reconciles that declaration against AWS RDS (or GCP Cloud SQL, or Azure Database). The developer interacts with Kubernetes; the platform team owns the mapping to the underlying cloud. Crossplane's composites allow platform teams to build opinionated abstractions — a `PlatformDatabase` that always provisions RDS with the right size, backup policy, and security group settings.

**Pulumi** is an infrastructure-as-code tool that uses real programming languages (TypeScript, Python, Go). For IDPs, it's used to build internal provisioning automation where Crossplane's Kubernetes-centric model is too heavy or when the team prefers code over YAML.

**Terraform Cloud** provides a managed run environment for Terraform, with a workspace-per-environment model. Teams trigger plans and applies through its API rather than running Terraform locally, which makes it suitable as a provisioning backend for an IDP.

The architectural choice is where the abstraction boundary sits. Crossplane is the right answer when your infrastructure target is Kubernetes-first. Terraform Cloud is the right answer when your organization has significant existing Terraform investment. Pulumi fits teams that want the flexibility of a programming language and have the Go or TypeScript expertise to use it well.

> [!warning] Exposing raw Terraform to developers is not self-service provisioning — it's self-service infrastructure-as-code, which still requires understanding Terraform. The IDP must abstract below that level for non-platform engineers.

@feynman

Infrastructure provisioning through an IDP is like ordering from a restaurant menu instead of cooking yourself: you declare what you want, the kitchen (platform) uses whatever tools it has to make it, and you get the result — you don't need to know if they used an oven or a grill.

@card
id: plf-ch03-c006
order: 6
title: CI/CD Integration — What the Platform Owns
teaser: A mature IDP owns the CI/CD pipeline skeleton — the compliance, security, and deployment stages — and leaves teams extension points for their build and test logic, not a blank YAML file.

@explanation

CI/CD in an IDP context is not about choosing GitHub Actions versus GitLab CI versus Argo CD. It's about the division of responsibility between the platform team and application teams.

What the platform should own:

- **Security scanning stages.** Container image scanning, SAST, dependency vulnerability checks. These run on every build regardless of what the application team wants.
- **Artifact publishing.** Pushing images to the internal container registry with a consistent tagging scheme (commit SHA, semantic version, environment tag).
- **Deployment mechanics.** The Argo CD Application resource, the Helm release, the Kubernetes rollout strategy. Teams declare which environment they want to deploy to; the platform executes it.
- **Compliance gates.** Approval steps, change-management integrations, production deploy windows.

What teams should own:

- **Build commands.** `go build`, `npm run build`, `cargo build` — the platform cannot know this.
- **Test commands and test data setup.** The application team owns its test suite.
- **Environment-specific configuration.** Feature flags, integration test targets, service-specific environment variables.

GitHub Actions achieves this split through reusable workflows — the platform team publishes a shared workflow; teams call it with their specific inputs. GitLab CI uses `include` with project templates. The platform enforces the skeleton by requiring that all services reference the shared template as a step they cannot remove.

Argo CD handles the continuous delivery half: it watches the Git repository for changes to Kubernetes manifests and reconciles the cluster state. The platform team owns the Argo CD ApplicationSet configuration; teams push manifests to a designated path.

> [!tip] Reusable GitHub Actions workflows with required inputs are the lowest-friction way to enforce platform-owned pipeline stages without forking every team's CI configuration.

@feynman

A platform-owned CI/CD pipeline is like a building's fire safety system: the platform installs the sprinklers and smoke detectors in every room (non-negotiable), but tenants still decide how to arrange their furniture (their build and test steps).

@card
id: plf-ch03-c007
order: 7
title: Secrets and Credentials — Invisible Integration
teaser: The goal for secrets in an IDP is invisibility: the developer declares they need a database password, and the platform delivers it to the running service without the developer ever seeing or storing the credential.

@explanation

Secrets management is one of the highest-security-impact components of an IDP, and also one of the most disruptive if done poorly. The failure mode is either insecure (secrets in environment variables committed to Git, or rotated manually) or too high-friction (developers must understand Vault's auth methods before they can run their first service).

The IDP's job is to make the secure path the default path.

**HashiCorp Vault** is the most widely deployed secrets manager in platform engineering contexts. Vault stores secrets, manages dynamic credentials (generating short-lived database users on demand rather than storing long-lived passwords), and integrates with Kubernetes via the Vault Agent Injector or the Vault Secrets Operator. The platform team manages the Vault cluster, auth methods, and policies. Developers declare which secrets their service needs via an annotation or a manifest — they never interact with Vault directly.

**AWS Secrets Manager** serves the same function for AWS-native deployments. The platform provisions the secret and grants the service's IAM role access to read it. The ESO (External Secrets Operator) syncs AWS Secrets Manager values into Kubernetes Secrets automatically, so the service sees a standard Kubernetes Secret without knowing where it came from.

The IDP integration pattern:

- Developers declare secret requirements in a manifest (or a template parameter at scaffolding time).
- The platform provisions the secret store entry and the access policy.
- The platform injects the secret into the running container as a file or environment variable using the secrets operator.
- Rotation is handled by the platform, not the developer.

The "invisible" standard means a developer should be able to add a new secret dependency by editing one line of their service manifest — and never log into Vault or Secrets Manager to do it.

> [!warning] Storing secrets in ConfigMaps, `.env` files committed to Git, or unencrypted environment variables in CI is the baseline insecure state that an IDP's secrets layer is specifically designed to eliminate.

@feynman

Secrets management in an IDP should feel like electricity in a building: you declare that you need power in your room, the building wires it for you, and you just plug in — you never need to understand the electrical panel.

@card
id: plf-ch03-c008
order: 8
title: Observability Defaults — Opt-Out, Not Opt-In
teaser: An IDP should wire every service it deploys into the observability stack automatically — traces, logs, metrics, and dashboards — because opt-in observability means the services you care about most in an incident are often the ones not opted in.

@explanation

Opt-in observability produces a systematic gap: new services, quick experiments, and high-churn microservices are the ones most likely to skip instrumentation setup. They are also the ones most likely to cause incidents during their early production life. The IDP closes this gap by making observability a platform responsibility, not a developer checklist item.

What "observability by default" means in practice:

- **Distributed traces.** Every service deployed through the platform gets an OpenTelemetry sidecar or auto-instrumentation injected. Traces flow to Jaeger, Tempo, or a managed service (Datadog, Honeycomb) without any code changes from the developer.
- **Structured logs.** The platform defines a logging format (JSON, with required fields: service name, trace ID, environment). The scaffold template includes a logger initialized to this format.
- **Metrics and dashboards.** Kubernetes-level metrics (CPU, memory, restart counts) are available automatically. The platform provisions a Grafana dashboard template per service on deploy.
- **Alerting baselines.** Every service gets a default alert on high error rate and high latency. Teams tune thresholds for their specific service; they don't have to write the alert from scratch.

The tooling is secondary to the architecture decision. Whether you use Datadog, Grafana + Prometheus + Loki + Tempo, or a cloud-native stack (AWS CloudWatch + X-Ray), the principle is the same: the platform provisions and configures it; developers inherit it.

The tradeoff: automatic instrumentation has overhead. Auto-injected OpenTelemetry agents add startup time and CPU overhead. For high-performance services, teams may need to replace the auto-instrumentation with manual SDK-level instrumentation. The platform should support this opt-out without losing the observability contract.

> [!info] The single highest-ROI observability default is injecting a trace ID into every service's log output. It costs almost nothing and turns "find the logs for this request" from a multi-tool investigation into a single query.

@feynman

Observability defaults in an IDP are like the smoke detectors a building installs in every room before you move in — you didn't ask for them and you might never need them, but when something is on fire at 2am you're very glad they were already there.

@card
id: plf-ch03-c009
order: 9
title: Environment Management — Preview, Ephemeral, Production-Like
teaser: Environment management is the hardest IDP capability to get right — preview and ephemeral environments accelerate development feedback loops, but "production-like" is a goal that most platforms never fully achieve.

@explanation

Environment management covers the lifecycle of the environments a service runs in: how they are created, how they are configured, how long they live, and how faithfully they represent production.

Three environment patterns and their tradeoffs:

**Persistent environments (dev, staging, production):** Simple to reason about, expensive to maintain, and usually diverge from each other over time. The classic model. Teams know where their service lives; the cost is that staging invariably becomes a different configuration from production because changes accumulate out of order.

**Preview environments:** A dedicated environment per pull request, spun up on branch push and torn down on merge. Teams get a real deployment to review before code lands in main. GitHub Actions with a cluster and a dynamic Ingress can provision a preview environment in under two minutes. The challenge is cost and data: preview environments need realistic test data without containing real user data, and running ten open PRs means ten active deployments.

**Ephemeral environments:** Created on demand for a specific test run, integration test suite, or load test scenario, then immediately destroyed. Infrastructure cost approaches zero (you pay for the duration of the test). The problem is boot time: if spinning up the environment takes longer than the test, the feedback loop is broken.

The "production-like" question is the honest tradeoff. A real production-like environment requires the same data volumes, the same external service integrations, the same network topology, and the same secret rotation policies. In practice, staging environments compromise on all four. The IDP can improve the situation — by scripting data seeding, by wiring staging to the same secrets backend as production, by using feature flags to isolate staging-specific behavior — but it cannot make staging fully production-equivalent at reasonable cost.

> [!warning] The most common environment management mistake is treating staging as production-equivalent and being surprised by production-only bugs. Document explicitly what staging does and does not simulate — false confidence is worse than acknowledged gaps.

@feynman

Environment management is like maintaining a test kitchen for a restaurant: you want it to mirror the actual kitchen as closely as possible, but the test kitchen always has slightly different equipment, smaller quantities, and no real dinner rush — so you still get surprises on opening night.

@card
id: plf-ch03-c010
order: 10
title: Backstage — the Open-Source Reference IDP
teaser: Backstage, open-sourced by Spotify in 2020 and now a CNCF project, is the most widely adopted IDP framework — it gives you a catalog, a plugin model, and a UI scaffold, but substantial engineering investment is required to make it production-ready.

@explanation

Backstage is the closest thing the industry has to a reference IDP architecture. Spotify built it to solve their own internal platform problem (hundreds of services, dozens of teams, no shared discovery layer) and open-sourced it in 2020. It became a CNCF incubating project in 2022 and graduated in 2024.

What Backstage gives you out of the box:

- **Software Catalog.** The entity model (`catalog-info.yaml`), discovery via GitHub/GitLab/Bitbucket, and the UI for browsing services, APIs, and teams.
- **Software Templates.** The scaffolding system for new services, with a YAML DSL for template definition and a plugin-based action model.
- **TechDocs.** Documentation-as-code: Markdown in the repository, rendered as a documentation site inside Backstage.
- **Plugin architecture.** A React + Node.js plugin model that lets you add integrations with virtually any tool: Kubernetes cluster view, CI/CD pipeline status, cost data, incident management, and more.

What Backstage does not give you:

- A working deployment. Backstage is a framework, not a SaaS product. You provision the infrastructure, manage upgrades, and maintain the database.
- Plugins for your specific stack. The plugin catalog has hundreds of community plugins, but quality varies and few are production-hardened. Integrating your internal tools requires custom plugin development.
- Out-of-the-box secrets management, provisioning, or CI/CD. Backstage is primarily a catalog and portal — the other IDP layers need to come from elsewhere.

The total ownership cost is significant. Teams that have deployed Backstage at scale report that it functions as a small product requiring 1–2 full-time engineers to keep current, add plugins, and manage its own reliability.

> [!info] Backstage's plugin model means it can theoretically integrate with anything, but "can" and "already exists at production quality" are different statements. Budget engineering time for plugin development, not just deployment.

@feynman

Backstage is like getting a well-designed building shell with plumbing roughed in — you have the structure and the connections mapped out, but you still need to furnish every room, finish the wiring, and maintain the building yourself.

@card
id: plf-ch03-c011
order: 11
title: Port, Humanitec, Cycloid — Commercial IDP Alternatives
teaser: Commercial IDPs like Port, Humanitec, and Cycloid offer faster time-to-value than a self-built Backstage stack, at the cost of vendor lock-in, lower customizability, and a recurring license.

@explanation

Backstage is not the only option. A growing set of commercial platforms offer IDP capabilities as a managed product, removing the infrastructure and maintenance burden at the cost of flexibility and pricing.

**Port** (port.io) is a developer portal and catalog product with a heavily data-model-driven approach. Port's core concept is a "Blueprint" — a schema for any entity (service, environment, deployment, PR) — and a flexible UI that renders scorecards, dashboards, and self-service actions on top of those blueprints. Port's strength is rapid onboarding: organizations report getting a working catalog and self-service actions in days, not months. Its limitation is that it's a portal layer — the underlying provisioning and CI/CD tools are still your responsibility.

**Humanitec** (humanitec.com) takes a more opinionated approach built around the concept of a "Platform Orchestrator." Humanitec provides a workload specification model (the Score format, which has become an open standard) that abstracts containers, resources, and environments behind a developer-facing API. The platform orchestrator translates Score declarations into concrete infrastructure. Humanitec's strength is its deployment model; its limitation is that the Score abstraction has a learning curve and the orchestrator is a central dependency for every deployment.

**Cycloid** (cycloid.io) targets infrastructure-heavy organizations and focuses on infrastructure catalog and environment-as-a-service patterns. It integrates tightly with Terraform and provides a self-service environment provisioning UI without requiring developers to learn Terraform syntax.

The tradeoff table that matters:

- **Speed to first value:** Commercial wins. Backstage is faster at first than it looks from the outside, but commercial platforms have pre-built integrations.
- **Customization ceiling:** Backstage wins. Commercial platforms are limited by their data models and plugin ecosystems.
- **Operational overhead:** Commercial wins. You don't run the SaaS product.
- **Cost:** Backstage wins at scale. SaaS pricing scales with teams or deployments; Backstage engineering costs are fixed.

> [!tip] Evaluate commercial IDPs against your organization's Backstage customization requirements before committing. If your internal tooling is standard (GitHub, AWS, Datadog), commercial platforms can cover 80% of your needs without custom code.

@feynman

Choosing a commercial IDP over Backstage is like buying a furnished apartment instead of an empty one: you move in faster and skip a lot of setup, but you can't knock down every wall, and you pay rent indefinitely instead of building equity.

@card
id: plf-ch03-c012
order: 12
title: Build vs Buy Your IDP
teaser: Building an IDP from open-source components (primarily Backstage plus glue) gives maximum control; buying a commercial platform gives faster time-to-value — and most organizations end up somewhere in the middle.

@explanation

The build vs buy decision for an IDP is more nuanced than most infrastructure decisions because a "built" IDP is never built from scratch — it's assembled from open-source and commercial components with custom integration code between them.

The case for building (Backstage plus open-source tooling):

- Full control over the developer experience, data model, and integrations.
- No per-seat or per-deployment pricing that scales with your organization.
- Direct access to the source: you can fix bugs, contribute improvements, and pin to known-good versions.
- Backstage has broad community support (thousands of companies, large plugin ecosystem, CNCF governance).

The case for buying (Port, Humanitec, Cycloid, or others):

- Engineering capacity is finite. Platform teams that choose Backstage should expect to spend 30–50% of their time on the platform itself, not the organization's product infrastructure.
- Commercial platforms have pre-built integrations with common tooling. The first 80% of an IDP (catalog, templates, basic self-service) arrives in weeks, not months.
- Support, upgrades, and reliability are the vendor's problem.

The "Backstage plus glue" middle ground is where most mature platform teams land: Backstage for the catalog and portal, commercial tools for specific layers (Vault for secrets, Humanitec's Score spec for deployment, Terraform Cloud for provisioning), with custom plugin code connecting the seams. This gives the organizational control of open-source with commercial-quality implementations for the highest-risk components.

The honest answer is that an IDP is never done. Regardless of build vs buy, the platform is a product. It needs product management, prioritization, and a team that treats developer experience as their primary success metric.

> [!warning] The biggest risk in building an IDP is underestimating ongoing maintenance. Backstage has a release cadence, plugins drift, and integrations break when downstream tools change their APIs. Staff accordingly or the platform becomes a maintenance liability rather than a productivity multiplier.

@feynman

Choosing between building and buying an IDP is like deciding whether to hire a full kitchen staff or use a catering service: building gives you exactly the menu you want but requires permanent staff; buying means someone else cooks, and you accept their menu with minor customizations.
