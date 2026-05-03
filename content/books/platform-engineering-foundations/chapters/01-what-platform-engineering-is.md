@chapter
id: plf-ch01-what-platform-engineering-is
order: 1
title: What Platform Engineering Is
summary: Platform engineering is the discipline of treating internal developer infrastructure as a product — distinct from DevOps, SRE, and ops, with its own metrics, audience, and design constraints.

@card
id: plf-ch01-c001
order: 1
title: The Platform Engineering Definition
teaser: Platform engineering treats internal developer infrastructure as a product — built for an internal audience, maintained on a roadmap, and measured by whether developers actually adopt it.

@explanation

The term was popularized in part by Manuel Pais and Matthew Skelton through their work on *Team Topologies* (2019) and related writing. The core idea is simple but consequential: infrastructure and tooling provided to application teams should be designed, maintained, and evolved the way any product is — with users, feedback loops, versioning, and success metrics.

What that means in practice:

- The platform team has a defined set of internal "customers" — application engineers, data engineers, or ML practitioners depending on the organization.
- The platform has a public interface: APIs, CLIs, documentation, and a clear contract about what it provides and what it doesn't.
- Adoption is voluntary or semi-voluntary — if the platform isn't genuinely better than rolling your own, engineers will route around it.
- The team maintains a roadmap driven by user pain rather than by what the ops team finds interesting to build.

The CNCF Platforms White Paper (2023) formalizes this framing in the cloud-native context, describing an internal developer platform as a layer that "accelerates how development teams deliver software" by abstracting away infrastructure complexity.

Platform engineering is not a job title or a tool. It is a discipline — a way of organizing the work of providing internal infrastructure.

> [!info] The lineage matters: Skelton and Pais drew heavily on Conway's Law and sociotechnical systems theory. Platform engineering is not primarily a technical decision — it is an organizational one.

@feynman

Platform engineering means treating the tools you build for your own developers the same way a product company treats the tools it sells to customers.

@card
id: plf-ch01-c002
order: 2
title: The Problem Platform Engineering Solves
teaser: Without a platform team, every application team ends up building and maintaining their own CI pipelines, deployment scaffolding, and observability stacks — duplicating work at scale and burning cognitive budget on infrastructure rather than product.

@explanation

The failure mode is well-documented. As an organization grows from a handful of engineers to dozens or hundreds, each team independently solves the same set of infrastructure problems:

- How do we build and test code on push?
- How do we deploy to staging and production?
- How do we collect logs and metrics?
- How do we manage secrets?
- How do we provision a new service?

Without a platform, each team answers these questions independently. The result is 12 slightly different CI pipelines, 8 incompatible observability setups, 5 different approaches to secret management — all requiring maintenance by teams whose primary job is building product features.

Matthew Skelton and Manuel Pais identify this as a **cognitive load** problem. Cognitive load is the mental overhead required of a team to do their job. Infrastructure complexity that application teams are forced to own directly eats into the cognitive budget they have available for building product.

The platform engineering answer is to centralize that infrastructure complexity in a specialist team — one that treats infrastructure as their product — and to expose it to application teams through well-designed interfaces that reduce the cognitive load required to use it.

This is distinct from "all infrastructure goes to ops." The platform team's goal is to make application teams *faster and more autonomous*, not to become a bottleneck.

> [!warning] A platform team that becomes a gatekeeper — where every deployment requires a ticket and an approval — has inverted the value proposition. The goal is self-service, not control.

@feynman

Platform engineering exists because asking every team to build their own CI pipeline is like asking every office worker to also be their own IT department.

@card
id: plf-ch01-c003
order: 3
title: Platform Engineering vs DevOps
teaser: DevOps is a culture of shared responsibility between development and operations; platform engineering is a structural answer to how you scale that culture — they are complementary, not competing.

@explanation

The distinction matters because conflating them leads to bad organizational decisions.

**DevOps** is a philosophy and cultural practice. It breaks down the wall between development and operations by giving developers ownership of their services end-to-end — you build it, you run it. DevOps is not a team, a tool, or a role (despite many job postings to the contrary). It is a way of working.

**Platform engineering** is an organizational structure that supports DevOps at scale. When you have 10 teams each running their own services, each owning their own reliability, you still need someone building the shared infrastructure they all depend on. That's the platform team.

The relationship is:

- DevOps establishes that developers own their services in production.
- Platform engineering provides the self-service infrastructure that makes owning services in production tractable rather than exhausting.

Without the platform, DevOps at scale often collapses: developers spend more time on infrastructure plumbing than on product. Without the DevOps culture, a platform team risks becoming old-style ops with a new name — a centralized bottleneck instead of an enabler.

The two concepts co-evolved. Gene Kim, Jez Humble, and Patrick Debois established DevOps culture; Skelton and Pais provided the organizational scaffolding for sustaining it past the first hundred engineers.

@feynman

DevOps is the principle that developers should own what they build; platform engineering is the infrastructure that makes that ownership practical at scale.

@card
id: plf-ch01-c004
order: 4
title: Platform Engineering vs SRE
teaser: SRE owns the reliability of services running on the platform; platform engineering owns the platform itself — the two disciplines have different users, different success metrics, and different failure modes.

@explanation

Site Reliability Engineering (SRE), as defined by Google's *Site Reliability Engineering* book (Beyer et al., 2016), is the practice of applying software engineering to operations problems. SREs define and defend service-level objectives, write postmortems, own oncall rotations, and reduce toil through automation.

Platform engineering and SRE overlap significantly in skills but differ in scope and primary user:

- **SRE's primary users** are the services running in production — the SRE is accountable for those services staying reliable.
- **Platform engineering's primary users** are the developers who write and deploy those services — the platform team is accountable for those developers having fast, reliable infrastructure to work with.

In a mature organization, SREs often consume the platform like everyone else. The platform team provides the deployment pipelines, the observability infrastructure, the Kubernetes clusters. The SREs use those to run reliable services and hold SLOs.

The failure mode of conflation: asking an SRE team to also own the developer platform creates a team with two distinct sets of stakeholders and two potentially conflicting success metrics. Service reliability and developer experience are both important — but they are optimized differently.

Some organizations combine the functions deliberately, especially at smaller scale. The key is clarity about which user you are serving with each body of work.

> [!info] Google's original SRE model assumed a large internal platform already existed. Skelton and Pais describe what it takes to build and sustain that platform deliberately.

@feynman

SRE asks "is the service staying up?"; platform engineering asks "can developers deploy their service without calling anyone for help?"

@card
id: plf-ch01-c005
order: 5
title: Platform Engineering vs Traditional Ops
teaser: The shift from ops to platform engineering is not cosmetic — it changes the team's success metric from "infrastructure uptime" to "developer productivity," which changes everything about how the team prioritizes work.

@explanation

Traditional operations teams are measured on infrastructure availability and incident response. Their users are, in a sense, the infrastructure itself — servers, networks, databases. Work comes in as tickets; success is defined as systems staying up.

Platform engineering inverts several of these assumptions:

- **Success metric changes.** A platform team measures deployment frequency, time-to-first-deploy for new services, developer satisfaction (often through quarterly NPS surveys), and platform adoption rates — not just uptime.
- **Work intake changes.** Platform roadmaps are driven by developer pain points and usage data, not ticket queues.
- **Relationship to users changes.** Platform teams do user research, publish release notes, write migration guides, and deprecate APIs deliberately — the same activities a product team performs.
- **Funding model changes.** Ops is often treated as a cost center; a platform team can be justified through productivity metrics: if a platform reduces the time developers spend on infrastructure by 20%, that translates to engineering capacity recovered.

The organizational risk of the transition is real. Ops teams that are renamed "platform" without changing any of their incentives, metrics, or ways of working will not get the benefits. The product mindset has to be genuine.

> [!warning] Renaming an ops team "platform engineering" without changing its success metrics is cargo-culting. The outcome is new vocabulary on top of old incentives.

@feynman

Traditional ops keeps the lights on; a platform team builds the electrical system so developers can turn their own lights on.

@card
id: plf-ch01-c006
order: 6
title: The Platform as a Product Mindset
teaser: Treating the platform as a product means it has users, a roadmap, release notes, usage data, and a feedback loop — and that the team optimizes for adoption rather than compliance.

@explanation

The "platform as a product" concept is explicit in Skelton and Pais's *Team Topologies* and expanded in the CNCF Platforms White Paper. The premise is that internal developer infrastructure should be governed by the same product disciplines used for external software.

What product thinking requires from a platform team:

- **Know your users.** Who are the application teams? What are their workflows? Where do they spend time waiting or working around the platform? Platform teams should conduct user interviews, analyze support tickets, and review platform usage telemetry.
- **Maintain a roadmap.** Features should be prioritized by impact on developer productivity, not by what's technically interesting. A public roadmap communicates direction and invites input.
- **Measure adoption, not deployment.** A feature that exists but nobody uses is not a success. Track what percentage of teams use each platform capability.
- **Treat breaking changes like API breaks.** Deprecations require migration guides and timelines. Platform teams that change things without warning erode trust and force developers back to rolling their own.
- **Define service level objectives for the platform itself.** If the CI pipeline has 40% of builds failing, developers will work around it. Platform SLOs communicate what level of reliability the team commits to.

The hard part of the product mindset is accepting that adoption is voluntary. Developers who find the platform too slow, too opinionated, or too complex will build their own tooling. That's a signal the platform needs to improve, not a compliance violation to be corrected.

@feynman

A platform treated as a product earns adoption by being genuinely useful; a platform treated as a mandate gets worked around.

@card
id: plf-ch01-c007
order: 7
title: Golden Paths
teaser: A golden path is the opinionated, well-supported route through the platform — the path that works out of the box, has documentation, and is maintained with reliability commitments.

@explanation

The term is closely associated with Spotify's approach to internal developer tooling. A golden path is not a mandatory path — it's the best-lit road through a set of choices the platform team has already made on behalf of the developer.

The concept in practice:

- Deploying a new backend service has a golden path: a scaffold CLI generates the repo, wires up CI, provisions the Kubernetes namespace, configures logging and tracing, and sets up alerting templates. A developer can have a new service in production in a day.
- The platform team commits to maintaining this path, updating it as infrastructure evolves, and providing a clear upgrade process when things change.
- Developers can leave the golden path — they can use different tools, different patterns, different pipelines — but they lose the platform team's support and maintenance guarantees.

The deliberate framing is "many paths, but one paved." The platform team doesn't prohibit alternative approaches; it just invests maintenance resources in the golden path and makes that investment visible.

This creates a productive incentive gradient. Developers choose the golden path not because they have to but because it is genuinely the path of least resistance. When the golden path is not chosen, it signals either that the path is poorly designed or that the use case it doesn't cover is real and worth addressing.

> [!tip] A golden path that nobody uses is not a golden path — it's documentation for an aspiration. Adoption rate is the health metric.

@feynman

A golden path is the pre-paved route through your platform — you can go off-road, but the platform team only maintains the paved road.

@card
id: plf-ch01-c008
order: 8
title: The Thinnest Viable Platform
teaser: The Thinnest Viable Platform (TVP) principle says to start with the minimal platform that reduces cognitive load, and expand only when there is demonstrated demand — not anticipated demand.

@explanation

The TVP concept is articulated by Manuel Pais in his writing on platform engineering and elaborated in *Team Topologies*. The core argument is against over-engineering internal platforms before you know what developers actually need.

The failure mode the TVP addresses: platform teams, given mandate and headcount, build comprehensive platforms that mirror commercial products — full Kubernetes distributions, proprietary deployment DSLs, custom CLIs with dozens of commands — before a single application team has shipped anything using the platform.

The TVP framework says:

- Identify the highest-friction problems application teams face *right now*, and solve those. Don't speculate about future pain.
- A platform that does three things well is more valuable than a platform that does fifteen things poorly.
- Every capability added to the platform has a maintenance cost. Adding a capability before there is demand means paying that cost for zero benefit.
- Expand the platform incrementally, driven by documented demand: user research, support ticket volume, developer requests on the roadmap.

In practice, many organizations' first viable platform is just three things: a self-service environment provisioning mechanism, a CI/CD pipeline template, and a centralized observability stack. That's often enough to meaningfully reduce cognitive load while keeping the platform maintainable with a small team.

The TVP is an explicit counter to "build it and they will come" thinking in internal tooling.

> [!info] The TVP is not permanent minimalism — it's a strategy for building trust and learning from real usage before investing in complexity.

@feynman

The Thinnest Viable Platform means building only what developers are actually suffering from today, not what you expect they'll need next year.

@card
id: plf-ch01-c009
order: 9
title: The Internal Developer Platform
teaser: An Internal Developer Platform (IDP) is the integrated set of tools and services the platform team provides — the sum of capabilities that application teams interact with to build, deploy, and run software.

@explanation

The term "Internal Developer Platform" is used by the CNCF Platforms White Paper and the broader community to describe the integrated experience a platform team delivers. It is distinct from an "Internal Developer Portal," which is often just a UI layer (Backstage being the canonical example). The IDP is everything — the portal, the pipelines, the infrastructure APIs, the access management.

Components a mature IDP typically includes:

- **Application configuration management** — how services define their configuration, secrets, and environment variables, abstracted from the underlying infrastructure.
- **Infrastructure orchestration** — how teams provision databases, message queues, object storage, and compute, usually through a self-service interface or GitOps workflow.
- **Deployment and release management** — CI/CD pipelines, progressive delivery controls (canary, blue/green), rollback mechanisms.
- **Observability** — centralized logs, metrics, distributed tracing, and alerting templates, pre-wired for new services.
- **Service catalog and documentation** — a registry of running services, their owners, their SLOs, their runbooks, and their dependencies.
- **Access and security controls** — provisioning of credentials, role-based access, audit trails.

No single tool covers all of these. An IDP is an integration, not an installation. The platform team's job is to make the seams between these components invisible to application developers.

@feynman

An IDP is the full collection of tools and infrastructure your platform team maintains so that developers can build and ship without thinking about the underlying mechanics.

@card
id: plf-ch01-c010
order: 10
title: Buy vs Build for Platform Tooling
teaser: Backstage, Port, Humanitec, and Cycloid are real products that cover different slices of the IDP surface — deciding whether to buy, build, or borrow requires knowing which parts of the platform are differentiating and which are commodity.

@explanation

The platform engineering ecosystem has a growing set of commercial and open-source tools that cover large portions of what a platform team might otherwise build from scratch.

Notable options by category:

- **Developer portal / service catalog:** Backstage (open source, by Spotify) is the most widely adopted. Port and Cortex are commercial alternatives with faster time-to-value and managed hosting. The portal is usually the developer-facing layer over the rest of the platform.
- **Platform orchestration / workflow:** Humanitec's Platform Orchestrator automates environment provisioning and deployment workflows using a resource graph model. Cycloid provides a self-service portal with integrated infrastructure automation.
- **GitOps and deployment:** ArgoCD and Flux are the dominant open-source tools for Kubernetes-based deployment. They are not platforms on their own but are common platform building blocks.

The buy-build-borrow framework for platform decisions:

- **Build** what is genuinely differentiating — the integration layer, the specific golden paths, the organizational conventions.
- **Buy** commodity infrastructure abstractions where the market has solved the problem better than you will. A developer portal built on Backstage with custom plugins often costs less in engineering hours than one built from scratch.
- **Borrow** open-source tools and contribute back where they almost fit your needs.

The honest tradeoff: commercial tools add licensing cost and reduce flexibility. Open-source tools like Backstage require significant engineering investment to maintain and extend. There is no universally right answer — the choice depends on team size, existing tooling, and how opinionated the organization needs the platform to be.

> [!warning] Backstage is a framework, not a product. A Backstage deployment requires ongoing engineering investment to keep plugins updated, integrate with internal systems, and manage the plugin ecosystem. Budget accordingly.

@feynman

Buying a platform product saves build time but adds a constraint on how you work; building your own adds flexibility but adds a permanent maintenance obligation.

@card
id: plf-ch01-c011
order: 11
title: Team Topologies and Platform Teams
teaser: Skelton and Pais's Team Topologies framework defines platform teams as one of four fundamental team types — and the way they interact with other teams determines whether the platform accelerates or slows the organization.

@explanation

*Team Topologies* (Skelton and Pais, 2019) defines four fundamental team types and three interaction modes. Understanding where platform teams fit clarifies both their purpose and their limits.

The four team types:

- **Stream-aligned teams** — the primary value-delivering teams, aligned to a product, user journey, or service. These are the platform's primary customers.
- **Enabling teams** — temporary consulting-style teams that help stream-aligned teams acquire new capabilities (e.g., introducing a new testing practice), then step back.
- **Complicated-subsystem teams** — teams that own components requiring deep specialist knowledge (e.g., a custom DSP algorithm, a proprietary ML feature store), which stream-aligned teams consume as a service.
- **Platform teams** — provide self-service internal services to stream-aligned teams, reducing their cognitive load.

The three interaction modes:

- **Collaboration** — two teams work closely together for a defined period, then separate.
- **X-as-a-service** — one team provides a capability the other consumes with minimal interaction.
- **Facilitating** — one team helps another develop new capabilities.

The critical design principle: a platform team should primarily interact with stream-aligned teams in **X-as-a-service** mode. If a stream-aligned team must open tickets, wait for approvals, or involve platform engineers for routine deployment tasks, the interaction mode has broken down. The platform exists to make the interaction minimal, not central.

Platform teams that operate in permanent collaboration mode with stream-aligned teams have failed at self-service.

@feynman

In Team Topologies, the platform team's job is to be so good at X-as-a-service that stream-aligned teams rarely need to think about them.

@card
id: plf-ch01-c012
order: 12
title: Signs You Need a Platform Team
teaser: The indicators that an organization is ready for a dedicated platform team are structural, not size-based — recurring rebuilds, slow onboarding, fragmented tooling, and pervasive cognitive overload are the signals to act on.

@explanation

Platform teams are not automatically justified by headcount. A 20-person startup almost certainly does not need a platform team. A 200-person engineering organization with five stream-aligned teams that are all reinventing deployment infrastructure is probably overdue.

The structural indicators:

- **Recurring rebuilds.** Multiple teams have independently built CI pipelines, deployment automation, or observability integrations. The same work has been done 3+ times with incompatible results.
- **Slow time-to-first-deploy for new services.** Provisioning a new service from code to production takes weeks — not because of approvals, but because the steps are manual, undocumented, and vary by team.
- **Fragmented developer experience.** Each team has a different workflow for secrets, different tooling for local development, different patterns for testing. Engineers moving between teams face a steep re-learning curve.
- **Cognitive overload on application teams.** Sprint reviews include significant time on infrastructure work rather than product features. Engineers cite infrastructure complexity as a blocker.
- **Oncall for infrastructure is owned by application teams.** Stream-aligned teams are woken up for infrastructure incidents that have nothing to do with their service logic.
- **No one owns the developer experience end-to-end.** When something in the developer workflow breaks, it falls between organizational cracks — nobody's job, nobody's OKR.

The counter-signal: if application teams are productive, deploying frequently, and not complaining about infrastructure friction, the existing setup is working. Don't add organizational complexity to solve a problem that doesn't exist.

> [!info] The most reliable signal is developer NPS for infrastructure tooling. If engineers consistently rate internal tooling below their external tooling experience, the gap is real and the cost is real.

@feynman

You need a platform team when the absence of one is visibly slowing your product teams — not when someone reads a blog post about platform engineering.
