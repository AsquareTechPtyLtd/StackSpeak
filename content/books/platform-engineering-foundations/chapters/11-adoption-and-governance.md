@chapter
id: plf-ch11-adoption-and-governance
order: 11
title: Adoption and Governance
summary: Once a platform exists, the campaign shifts from "build" to "expand and govern" — migrating teams onto golden paths, sunsetting old infrastructure, and running governance structures that work in days instead of weeks.

@card
id: plf-ch11-c001
order: 1
title: Build Is the Easy Part
teaser: Most platform teams spend eighteen months building a platform, then discover that the harder problem — getting engineers to actually use it — was never planned for.

@explanation

Platform adoption fails for a predictable reason: the team that built the platform is not the team that needs to change their behavior. The builders are already bought in. The users aren't.

The pattern plays out like this. A platform team spends a year delivering self-service provisioning, a service catalog, golden paths for deploying services, and an internal portal. They demo it at an all-hands. The engineering org nods. Six months later, adoption is at 12%. Teams are still manually provisioning infrastructure with one-off scripts. The platform is technically excellent and practically invisible.

Why adoption stalls:

- **Switching costs are real.** A team with a functioning, battle-tested deployment pipeline has no immediate incentive to migrate to the new one, even if the new one is better. The migration cost lands on them; the benefit lands on the platform team's metrics.
- **Documentation is not onboarding.** Teams don't read docs. They copy examples from teams that have already done the thing.
- **The platform isn't done when it launches.** It's done when the last migration is complete. That framing rarely appears in platform roadmaps.
- **Visibility gaps.** Adoption problems are invisible if you aren't measuring them. Most platform teams measure velocity of feature delivery, not breadth of actual use.

Platforms that succeed at adoption treat it as a distinct workstream, not an afterthought. They assign engineers specifically to migration work, track adoption metrics weekly, and maintain an explicit list of every team that hasn't migrated yet.

> [!warning] Shipping the platform is not the goal. Getting every team onto it is. Treat those as two separate projects — the second one usually takes longer than the first.

@feynman

Building a platform that nobody uses is like opening a restaurant, getting great reviews from food critics, and then noticing the dining room is always empty because you forgot to put up a sign.

@card
id: plf-ch11-c002
order: 2
title: Migration Patterns — Strangler Fig at the Platform Layer
teaser: You don't migrate teams to a new platform all at once — you route new workloads to the golden path first, then strangle the old infrastructure from underneath.

@explanation

The Strangler Fig pattern, originally described by Martin Fowler for application modernization, applies directly to platform migrations. The idea: don't replace the old thing in one big-bang cutover. Instead, stand up the new system alongside the old one, route new workloads to it, and incrementally migrate old workloads until the legacy system has no traffic left and can be decommissioned.

At the platform layer, this looks like:

- **New services go on the golden path by default.** When a team spins up a new microservice, the only supported path is through the platform's provisioning system. The old manual process is still available but undocumented and unsupported.
- **Existing services migrate on a team-by-team schedule.** Each team is given a migration window — typically a quarter — to move their existing services. The platform team provides tooling, documentation, and office hours support during that window.
- **The old infrastructure stays up until the last tenant leaves.** Decommissioning before the migration is complete forces teams to scramble. The strangler fig approach decouples "build new" from "remove old."

The per-team rollout sequence:

1. Onboard one reference team early, before the platform is fully polished.
2. Use their feedback to harden the platform.
3. Roll out to the next cohort of teams with the reference team's case study in hand.
4. Expand in waves, with each wave larger than the last.

The reference team is not a pilot program. They're the first production users. Treat their migration as the platform's real launch.

> [!tip] Pick your reference team carefully. You want one that's influential enough that other teams notice, technical enough to give useful feedback, and willing enough to tolerate rough edges. The skeptical senior team is usually the worst first choice.

@feynman

Migrating a platform is like replacing a highway while traffic is still running — you build a new lane beside the old one, redirect cars one exit at a time, and only close the old lane once the last car has moved over.

@card
id: plf-ch11-c003
order: 3
title: Carrots vs Sticks — Incentivising vs Mandating
teaser: Incentives get early adopters; mandates get the stragglers — and knowing which lever to pull at which stage is one of the most consequential decisions a platform team makes.

@explanation

There is no universal answer to whether adoption should be voluntary or compulsory. Both approaches have real tradeoffs, and most successful platform rollouts use both in sequence.

**Carrots (incentivising):**

- Reduced toil for teams that migrate — the platform handles security patching, compliance controls, and cost optimization automatically.
- Better developer experience — faster deploys, self-service without a ticket, integrated observability.
- Recognition and priority support for early adopters.
- Access to features (like advanced deployment strategies or cost dashboards) only available on the golden path.

Incentives work well in the early adopter phase. Teams that are already unhappy with the status quo will migrate voluntarily if the new path is clearly better. But incentives stall when you reach teams that are locally optimized — their current setup works for them, and the migration cost is real even if the long-run benefit is real too.

**Sticks (mandating):**

- New services must use the platform (usually enforced from day one of a rollout).
- Existing services have a hard migration deadline, after which the old infrastructure receives no support and eventually no funding.
- Security or compliance posture that cannot be maintained on non-platform infrastructure.

Mandates are less popular and more effective at clearing the tail of non-adopters. The failure mode is mandating too early — before the platform is stable enough to absorb the load — which generates backlash that can set adoption back by months.

The typical sequence: incentives for the first 60% of adoption, hard deadline for the remaining 40%.

> [!info] "The platform team provides the carrot; organizational leadership provides the stick." If the platform team doesn't have executive backing for mandates, adoption will permanently stall at whatever the voluntary ceiling is.

@feynman

Carrots get the hungry to the table; sticks get the ones who weren't hungry but need to eat anyway — and you need both because the table has a fixed number of seats and someone else needs to sit down eventually.

@card
id: plf-ch11-c004
order: 4
title: Deprecating Old Infrastructure
teaser: Deprecation without a credible deadline is not deprecation — it's a suggestion, and engineers will ignore suggestions when they have production systems to run.

@explanation

Old infrastructure rarely disappears on its own. Teams don't migrate voluntarily from something that works, even if it's costing more or creating risk. Deprecation requires structure: a timeline, escalating communications, and actual enforcement.

A deprecation playbook that works:

**Phase 1 — Announce (T-6 months).** Send an email to all teams using the deprecated resource or path. Document the migration path clearly. Assign a point of contact. Set the sunset date publicly.

**Phase 2 — Runtime warnings (T-3 months).** Where technically possible, add warnings into the deprecated path itself. CI pipelines print a deprecation notice. The old API returns a `Deprecation` header. The old Terraform module emits a warning. Engineers see the message when they're already working in the system.

**Phase 3 — Soft cutoff (T-1 month).** New usage of the deprecated path is blocked. Existing users still run, but cannot provision new resources using it. Escalations to team leads begin for unmigrated teams.

**Phase 4 — Sunset date enforcement.** The old infrastructure is shut down or removed. No extensions without director-level approval and a written migration commitment.

The "deprecate by date" model is critical: the date must be fixed and public. Slipping the date signals that the deadline is negotiable, which signals that the next deadline is negotiable, which means you never actually deprecate anything.

> [!warning] Sunset date slippage is the single most common reason deprecations fail. Every extension you grant teaches every remaining team that extensions are available.

@feynman

Deprecating infrastructure without a hard deadline is like telling your team to clean out the storage room "sometime soon" — the room never gets cleaned, and in six months you're holding another meeting about the same storage room.

@card
id: plf-ch11-c005
order: 5
title: Adoption Metrics
teaser: You cannot manage what you do not measure — and most platform teams measure output (features shipped) instead of outcome (teams actually using those features).

@explanation

Three metrics that actually tell you whether your platform is working:

**1. Percentage of services on the golden path.**
The most direct adoption signal. Divide the number of services deployed through the platform's supported path by the total number of services in the organization. Track this per team, not just in aggregate — aggregate numbers hide stragglers.

**2. Time to First Deployment (T2FD) across cohorts.**
How long does it take a new team, using the platform, to get from "I have a repository" to "my service is running in production"? Measure this for every new team that onboards. T2FD trending upward means the platform is getting more complex, not less. T2FD under one day is a reasonable target for mature golden paths.

**3. Defect rate by cohort.**
Compare the production incident rate, change failure rate, or MTTR for services on the golden path versus services not on it. If the platform is actually delivering value, the golden-path cohort should outperform the non-golden-path cohort. If it doesn't, that's a product problem, not a marketing problem.

Secondary metrics worth tracking:

- Support ticket volume per team (decreasing is good)
- Self-service success rate (did the team complete the action without filing a ticket?)
- Rollback rate for deployments through the platform

These metrics belong in a dashboard that the platform team reviews weekly and that engineering leadership can see. Adoption data locked inside a spreadsheet on someone's laptop is not a metric — it's a historical artifact.

> [!tip] Report adoption metrics to engineering leadership in the same meeting where you report feature velocity. Adoption is a business outcome, not a platform-team-internal detail.

@feynman

Measuring platform adoption is like measuring whether a new road is actually being used — you don't judge it by how many lanes you built, you judge it by whether cars are driving on it and getting where they're going faster.

@card
id: plf-ch11-c006
order: 6
title: The Platform RFC Process
teaser: An RFC process transforms "the platform team decides everything" into "decisions are made transparently, with input, and at a predictable pace" — but only if the SLA on review is real.

@explanation

RFC stands for Request for Comments. The format was invented at IETF in the 1960s and has been adapted by software organizations — notably Rust, Ember.js, and many large engineering teams — into a lightweight process for proposing and reviewing significant technical decisions.

For platform teams, RFCs serve a specific function: they create a record of why decisions were made, who was consulted, and what alternatives were considered. Without them, platform decisions happen in Slack threads or 1:1 meetings, and the institutional knowledge evaporates when engineers leave.

What a platform RFC should contain:

- **Problem statement.** What is being solved and why it matters.
- **Proposed solution.** What the platform team intends to do.
- **Alternatives considered.** What else was evaluated and why it was rejected.
- **Affected teams.** Who will be impacted and how.
- **Migration path.** If this deprecates or changes existing behavior, what does migration look like?
- **Success criteria.** How will you know this worked?

The SLA on RFC review is as important as the template. If an RFC sits unreviewed for three weeks, teams learn that RFCs are theater. A functioning RFC process commits to a review window — typically five business days for an initial response — and assigns a named reviewer, not a committee.

Google's Design Doc format and the Rust RFC template (available on GitHub at rust-lang/rfcs) are both practical references. Neither needs to be adopted wholesale — adapt the structure to the team's context.

> [!info] RFCs do not require consensus. They require transparency. The platform team makes the final call; the RFC process ensures that call is informed and documented.

@feynman

An RFC is like publishing the agenda before a meeting — it doesn't change who makes the decision, but it ensures everyone who cares had a chance to read the plan and object before work starts.

@card
id: plf-ch11-c007
order: 7
title: Architecture Review Boards — When They Help, When They Bottleneck
teaser: An Architecture Review Board that must approve every decision is a platform bottleneck; one that operates as a consultative body is a force multiplier — the difference is whether the board can say "no" or only "here's what I'd consider."

@explanation

Architecture Review Boards (ARBs) are governance bodies that review significant technical decisions — new services, major architectural changes, technology introductions. In theory, they prevent bad decisions and enforce consistency. In practice, they often become the slowest part of the delivery pipeline.

**When ARBs help:**

- Organizations with significant compliance, security, or regulatory exposure (financial services, healthcare) where a second set of eyes on architectural decisions reduces risk.
- Decisions that span multiple teams and cannot be made by any single team alone.
- Introducing a new technology stack that will have long-term implications for hiring, tooling, and training.

**When ARBs bottleneck:**

- When every service, even trivial ones, requires ARB approval.
- When the ARB meets infrequently (monthly) but services need to move weekly.
- When the ARB has blocking power but no accountability for the cost of delay.
- When the ARB's standards are undocumented and decisions appear inconsistent.

The consultative model: the ARB's default response is a written recommendation, not an approval or rejection. The requesting team takes the recommendation and proceeds. The ARB escalates to a blocking review only for decisions that cross defined thresholds — new technology categories, services processing regulated data, or changes to shared infrastructure.

Thoughtworks Technology Radar and the AWS Architecture Blog both document cases where consultative review structures outperformed blocking ones in engineering velocity without material increases in architectural incidents.

> [!warning] If teams are working around the ARB — starting work before review, framing proposals to avoid triggering review — the ARB has lost legitimacy. The process needs redesign, not more enforcement.

@feynman

An architecture review board that blocks decisions is like a city council that must vote before any resident can hang a picture frame — useful for building codes, counterproductive for interior decorating.

@card
id: plf-ch11-c008
order: 8
title: Compliance and Audit Support
teaser: The platform's most underappreciated value proposition is this: every team on the golden path inherits the platform's compliance controls automatically, without knowing what SOC 2 or ISO 27001 actually require.

@explanation

Compliance frameworks — SOC 2, HIPAA, ISO 27001, PCI DSS — require organizations to demonstrate that controls are in place, operating, and documented. Auditors ask for evidence. Without a platform, that evidence must be gathered from dozens of teams operating dozens of different infrastructure configurations. With a platform, the evidence comes from one place.

What the platform provides by default:

**SOC 2 (Trust Services Criteria):**
- Logical access controls — who can deploy, to what environment, with what authorization.
- Change management — every deployment goes through the platform, every deployment is logged and attributable.
- Monitoring and alerting — the platform's observability stack generates the logs that auditors want to see.

**HIPAA:**
- Encryption at rest and in transit enforced by the platform's infrastructure templates.
- Audit logs for access to systems that could touch PHI.
- Access control policies that map to the minimum-necessary standard.

**ISO 27001:**
- Information security controls embedded in the platform's golden path become auditable control implementations.
- The platform's RFC and change process satisfies requirements for documented change management.

The key framing for executives: "If your service is on the platform, it is compliant by default. If it is not on the platform, your team is responsible for independently demonstrating compliance." This framing alone accelerates migration for any team with a compliance obligation.

Concretely, the platform team should maintain an audit evidence package — a set of artifacts (pipeline logs, access control policies, encryption configurations, incident records) that can be handed directly to an auditor. Updating this package after every significant platform change is far less painful than reconstructing it at audit time.

> [!tip] Involve your security and compliance teams in the platform design phase, not the audit phase. Controls that are retrofitted onto a platform are always more expensive and less reliable than controls that are built in.

@feynman

A compliant platform is like a hotel that has already passed the health inspection — every guest who stays there inherits the cleanliness standards automatically, without having to pass their own inspection.

@card
id: plf-ch11-c009
order: 9
title: Inner Sourcing Patterns
teaser: Inner sourcing treats the internal platform like an open-source project — any engineer in the organization can contribute, but contributions follow a defined review process and go through named maintainers.

@explanation

The term "inner sourcing" was popularized by Tim O'Reilly and developed extensively by GitHub and PayPal as a model for applying open-source collaboration practices inside a company. For platform teams, it answers a question that becomes pressing as the platform grows: who can change the platform, and how?

The two failure modes:

- **Too closed:** Only the platform team can modify platform code. Every change requires a ticket, a sprint slot, and a platform engineer. Teams wait weeks for simple changes. Trust erodes.
- **Too open:** Any engineer can merge to the platform repo. Quality degrades. Breaking changes propagate to every downstream team. The platform becomes ungovernable.

The inner source model:

- **Maintainers** are named engineers on the platform team responsible for a given component (deployment templates, the service catalog, observability configs). They review and approve changes to their component.
- **Contributors** are engineers from any team in the organization. They can open PRs against any platform component, following the contribution guide.
- **Contribution guide** documents: how to open a PR, what makes a PR mergeable, expected review turnaround (typically two to five business days), how breaking changes are flagged.
- **Office hours or a #platform-contrib Slack channel** provides a path for contributors who are stuck.

The maintainer model is documented in detail by GitHub's InnerSource Commons (innersourcecommons.org), which publishes playbooks and case studies on contribution models that have worked in large engineering organizations.

The tradeoff to be honest about: inner sourcing requires the platform team to spend real time reviewing external PRs. If the team is already at capacity, inner sourcing can feel like more work, not less. The payoff is that external contributors fix their own problems rather than filing tickets — which reduces the platform team's long-run support load.

> [!info] The quality bar for a merged PR to the platform should be the same whether it comes from the platform team or an external contributor. Lowering the bar to be "nice" creates technical debt that the platform team pays down later.

@feynman

Inner sourcing is like a city letting residents propose and help build new bike lanes — the city engineers still approve the design and manage the construction, but they're not the only ones who can identify where a lane is needed.

@card
id: plf-ch11-c010
order: 10
title: Working with Security and Compliance Teams
teaser: The platform team that treats security as a gate to pass through will fight that gate for the entire life of the platform; the one that treats security as a co-author ships faster and produces better controls.

@explanation

Security and compliance teams have organizational authority that platform teams typically lack: they can block deployments, require remediation, and escalate to executives. This power dynamic, when mismanaged, turns security into an adversary. When managed well, it turns security into a platform accelerator.

What adversarial security relationships look like:

- Security reviews happen at the end of the development cycle, after the platform feature is built.
- Security requirements arrive as a list of findings that the platform team must remediate before launch.
- Controls are applied inconsistently because security teams review each team's infrastructure separately.
- Platform teams route around security review by reframing features as "minor changes."

What a partnership model looks like:

- A security engineer is embedded in or maintains a liaison relationship with the platform team. Not full-time necessarily — a regular sync and a shared Slack channel is enough.
- New platform capabilities are designed with security requirements in the initial spec. The question "what does this need to be compliant?" is answered before code is written.
- The platform team treats security policies as product requirements. If SOC 2 requires encryption at rest, the golden path enforces it by default — not via a checklist, but via code.
- The security team uses the platform to push controls broadly rather than auditing each team individually. Their leverage is multiplied by platform adoption.

The framing that works: "We want your controls in the platform code. If you can tell us what you need, we can make it the default for every team in the organization simultaneously."

> [!tip] Bring a compliance requirement to the security team with a proposed implementation, not a blank page. "We want to implement encryption at rest using AWS KMS CMKs managed through Terraform — does this satisfy your requirement?" gets a faster answer than "what do you need?"

@feynman

The security team isn't a firewall you have to get past — they're the co-authors of the rules that get baked into the platform, which means every team that uses the platform is automatically compliant without anyone filing a separate ticket.

@card
id: plf-ch11-c011
order: 11
title: Policies as Code
teaser: A compliance rule that lives in a wiki gets ignored; the same rule expressed in OPA, Conftest, or Kyverno gets enforced in CI on every commit, automatically, with no human reviewer required.

@explanation

"Policies as code" means expressing organizational rules — security requirements, naming conventions, cost controls, compliance mandates — as executable code that runs in CI/CD pipelines or as admission controllers in Kubernetes clusters.

The key tools:

**OPA (Open Policy Agent):** A general-purpose policy engine that evaluates Rego policies against JSON input. Used for Terraform plan evaluation, Kubernetes admission control, API authorization, and more. OPA is a CNCF graduated project maintained by Styra. A policy that blocks Terraform plans creating S3 buckets without encryption is around 10 lines of Rego.

**Conftest:** A CLI tool built on OPA that makes it easy to evaluate policies against configuration files — Terraform HCL, Kubernetes manifests, Dockerfile, and others. `conftest test terraform.plan.json` runs your Rego policies against a Terraform plan in CI. Conftest is open source and maintained by the Open Policy Agent community.

**Kyverno:** A Kubernetes-native policy engine that uses YAML instead of Rego. Easier to adopt for teams already working in YAML-heavy environments. Kyverno can validate, mutate, and generate Kubernetes resources based on policies. It is a CNCF graduated project.

What policies as code prevents in practice:

- S3 buckets created without server-side encryption
- Kubernetes deployments with containers running as root
- Terraform modules using unapproved provider versions
- Services deployed without required labels (team, environment, cost-center)
- Security groups opening port 22 to 0.0.0.0/0

The tradeoff: policy code is code, and it needs to be maintained. Policies that are too strict block legitimate work. Policies that never update become irrelevant. The platform team owns this code and must treat it with the same discipline as any other production system.

> [!info] Start with a small number of high-signal policies rather than encoding every rule from your security wiki at once. Five well-maintained policies that block real issues are more valuable than fifty policies that are ignored because they generate too many false positives.

@feynman

Policies as code are like a spell-checker that runs on every pull request — instead of relying on a human reviewer to catch every misspelling, the tool flags it automatically before the work goes out the door.

@card
id: plf-ch11-c012
order: 12
title: The Sunset Playbook
teaser: Retiring a service completely is harder than building one — it requires a coordinated sequence of communications, migrations, data archiving, and infrastructure teardown, all while keeping the lights on for remaining users.

@explanation

"Sunset" means a service is permanently decommissioned — not deprecated, not unsupported, but gone. This is the end state that all deprecation work is building toward. Without an explicit playbook, sunset becomes indefinitely deferred.

A sunset playbook covers five phases:

**1. Eligibility assessment (T-12 months).**
Confirm that all users have migrated or have a credible migration plan. Identify any data that must be archived before shutdown. Identify any dependent services that are not yet decoupled. Define the acceptance criteria for shutdown.

**2. Migration completion (T-6 to T-3 months).**
Work with remaining teams to complete migrations. This is the phase where sticks are most important — teams that have had the sunset date for six months and still haven't moved need escalation to their engineering leads.

**3. Traffic monitoring (T-4 weeks).**
Confirm that production traffic to the service is at or near zero. Log any remaining callers. Contact those teams directly. The goal is no surprises on shutdown day.

**4. Archiving and documentation (T-2 weeks).**
Archive any operational data that must be retained for compliance (typically 7 years for financial data, varies by regulation). Document the service's final state — architecture, dependencies, failure modes — in case of future audit or incident analysis. Archive the source code repository (read-only, not deleted).

**5. Infrastructure teardown (T-0).**
Shut down the service. Remove DNS entries. Terminate infrastructure. Revoke access credentials. Document the teardown in the incident log even though nothing went wrong — the record matters for compliance.

The communication plan matters as much as the technical plan. Engineering leads, affected team leads, and any external stakeholders should receive notifications at T-12 weeks, T-4 weeks, T-1 week, and on the day of shutdown.

> [!info] Archive, don't delete. Code repositories, runbooks, and audit logs for a sunset service should be preserved in read-only form for at least as long as your compliance regime requires. The team that dealt with the incident two years after sunset will thank you.

@feynman

Sunsetting a service is like decommissioning a power plant — you can't just turn it off on a Friday afternoon; you need to redirect every wire that was connected to it, archive the records, and leave a written account of what was there and when it stopped running.
