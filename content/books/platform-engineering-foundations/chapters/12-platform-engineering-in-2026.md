@chapter
id: plf-ch12-platform-engineering-in-2026
order: 12
title: Platform Engineering in 2026
summary: AI-augmented platforms are already showing up — LLM-driven runbooks, agent-readable service catalogs, MCP-style integrations between platforms and agents — and the platform team's role is shifting from "abstract the cloud" to "abstract the agent's view of the cloud" while keeping judgment human.

@card
id: plf-ch12-c001
order: 1
title: What AI Changes About the Platform's Job
teaser: AI doesn't replace the platform — it changes what the platform needs to abstract, adding a new class of consumer that reads docs, calls APIs, and makes autonomous decisions without a human in the loop.

@explanation

For most of this book, the platform's user has been a human developer: someone who reads your golden-path templates, opens your service catalog, files a ticket, and waits for provisioning. That assumption is eroding.

In 2026, the platform's users include agents — automated systems driven by large language models that scaffold new services, respond to incidents, review PRs for golden-path conformance, and query your catalog via API. They do not read documentation the way humans do. They parse structured schemas, call tool endpoints, and expect consistent machine-readable responses.

What stays the same:

- The platform still abstracts infrastructure complexity.
- The platform still enforces organizational standards through its interfaces rather than through social pressure.
- The platform still needs to be usable without deep knowledge of what's underneath.
- The golden path is still the mechanism by which you scale good decisions.

What changes:

- A growing share of your "users" cannot give you feedback directly or file a GitHub issue when the docs are confusing. You infer their failures from error logs and agent traces.
- Machine-readable formats (OpenAPI specs, JSON schemas, structured catalog entries) become first-class design concerns, not afterthoughts you add for the API team.
- The platform team gains a new governance problem: deciding what agents are allowed to do, and ensuring they cannot exceed those boundaries at runtime.

The shift is not dramatic yet. Most platforms in 2026 are still primarily human-facing. But the teams that are designing for this dual audience now will spend far less time retrofitting later.

> [!info] As of 2026-Q2, the majority of platform teams report that less than 20% of platform API calls originate from automated agents or CI systems rather than human-triggered actions. The number is growing quarter over quarter.

@feynman

AI doesn't make the platform obsolete — it adds a second type of user who can't read the README, so you have to make the platform legible to machines as well as people.

@card
id: plf-ch12-c002
order: 2
title: LLM-Driven Runbooks
teaser: LLMs can draft incident response playbooks from alert history and architecture docs — and they are genuinely useful as a starting point, which is different from being reliable enough to execute autonomously.

@explanation

A runbook is a structured document describing how to respond to a specific operational event: what to check, what to restart, what to escalate, and in what order. Writing and maintaining runbooks is expensive work that most platform teams do inconsistently. LLMs have become a practical tool for generating first drafts.

What LLM-generated runbooks are good at:

- Producing a structured starting point from an alert definition and a description of the affected service.
- Summarizing past incident timelines into a proposed response sequence.
- Translating human-written postmortems into structured step-by-step procedures.
- Generating multiple runbook variants for different severity levels.

What they are not good at:

- Knowing the organizational context your team has accumulated over three years of incidents. Who actually owns this service today? What changed last Tuesday that broke the canary deployment?
- Accurately describing a system they have not been given authoritative documentation about. Hallucinated runbook steps look plausible and are dangerous.
- Staying current with infrastructure changes automatically. A runbook generated from a six-month-old architecture diagram will confidently describe services that no longer exist.

The practical model that works: LLMs generate the draft, a human engineer reviews and annotates, and the runbook is versioned alongside the service that owns it. This is faster than writing from scratch, and the human review step catches the hallucinations before they matter.

Running an LLM autonomously against a production incident without human review of the runbook content is a different and significantly riskier proposition.

> [!warning] As of 2026-Q2, no major incident management vendor recommends fully autonomous LLM-executed remediation for Sev-1 production incidents without a human approval step. Tools like PagerDuty AIOps and Datadog Watchdog use AI for triage and recommendation, not for autonomous action in high-severity cases.

@feynman

An LLM runbook is like a very fast junior engineer who has read all your docs but has never been on call — useful to have draft something at 2 a.m., but you still want a senior engineer to read it before anyone follows it.

@card
id: plf-ch12-c003
order: 3
title: AI Scaffolding Agents
teaser: Tools like Cursor, Claude Code, and Aider can generate a new microservice from a natural-language description — and the platform team's job is ensuring that what those tools generate actually conforms to your standards.

@explanation

In 2026, a developer can open Cursor or Claude Code, describe a new service ("a Python FastAPI service that reads from our Postgres events table and publishes to the notifications topic"), and receive a working project scaffold in minutes. This is genuinely productive. It is also a new surface area for golden-path drift.

The tension: AI scaffolding tools optimize for "something that compiles and looks reasonable," not for "something that matches your organization's specific conventions." They do not know that your org requires a specific Dockerfile base image, a particular health check pattern, a Backstage `catalog-info.yaml` at the root, or that you want all services to emit structured logs to stdout rather than a log file.

Three response patterns emerging in platform teams:

**Template enforcement at intake.** Wrap your golden-path template in a prompt that the scaffolding agent is given before generating. Cursor and Claude Code both support custom system prompts and rules files (`.cursorrules`, `CLAUDE.md`). A well-written rules file embeds your golden-path constraints into every AI-assisted scaffold in that repo.

**AI-assisted PR review for conformance.** After the scaffold is generated, a CI step runs an LLM that checks the output against golden-path criteria and flags deviations before human review. Discussed further in card 9.

**Platform-provided starting points.** Rather than letting developers start from scratch with AI, the platform provides canonical service templates that developers fork. The AI then modifies an already-conformant base.

The worst outcome is treating AI scaffolding as a reason to relax golden-path expectations. The output quality of AI scaffolding tools is high enough that non-conformant services now arrive looking polished and production-ready, which makes golden-path drift harder to catch by eye.

> [!info] As of 2026-Q2, Cursor, Claude Code (Anthropic), and Aider all support project-level rules files that can encode organizational conventions. None of them enforce those conventions — they follow instructions, not contracts.

@feynman

AI scaffolding gives developers a very fast starting point, but it doesn't know your rules — so the platform's job is to make your rules part of the starting point, not a checklist someone reads afterward.

@card
id: plf-ch12-c004
order: 4
title: MCP-Style Integration
teaser: Model Context Protocol gives LLMs a standard way to call your platform's APIs as tools — turning your self-service portal into something an agent can operate directly, without a human typing commands.

@explanation

Model Context Protocol (MCP), introduced by Anthropic in late 2024 and adopted by a growing number of tooling vendors by 2025, is a standard interface for exposing capabilities to LLMs as callable tools. An MCP server describes its available actions in a structured schema; an LLM client discovers those actions and can invoke them with arguments.

For a platform team, MCP integration means this: you can expose your platform's self-service operations — provision a new namespace, create a service account, query the cost dashboard, list active incidents — as MCP tools that an LLM can call during an agentic workflow.

A minimal MCP tool definition looks like:

```json
{
  "name": "provision_namespace",
  "description": "Creates a new Kubernetes namespace with standard RBAC, resource quotas, and network policies applied. Returns the namespace name and kubeconfig snippet.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": { "type": "string", "description": "Namespace name. Must match ^[a-z][a-z0-9-]{2,62}$." },
      "team": { "type": "string", "description": "Owning team slug from the service catalog." },
      "environment": { "type": "string", "enum": ["dev", "staging", "prod"] }
    },
    "required": ["name", "team", "environment"]
  }
}
```

This is directly analogous to OpenAI Function Calling, which predates MCP and serves the same purpose in OpenAI-compatible clients. The distinction: MCP is a transport-level protocol (server-sent events over HTTP) designed to be model-agnostic; function calling is a model API convention. In practice, both approaches result in an LLM being able to invoke platform operations as structured tool calls.

The platform design implication: every self-service operation you want agents to be able to use must be expressed as a structured, machine-callable endpoint — not a web form, not a Slack command, not a wiki page with manual steps.

> [!info] As of 2026-Q2, MCP adoption is accelerating in developer tooling. Anthropic Tools, major CI vendors, and several internal developer platform vendors have shipped or announced MCP server support. The protocol is not yet a standard, but it is the closest thing to one in this space.

@feynman

MCP is a standard plug shape — instead of every LLM having to learn a different way to call your platform's API, they all use the same connector, and your platform just needs to fit that shape.

@card
id: plf-ch12-c005
order: 5
title: Agent-Readable Service Catalogs
teaser: A service catalog entry written only for human readers is only half as useful as it could be — agents querying Backstage or its equivalents need structured, consistent, unambiguous metadata to do useful work with it.

@explanation

Service catalogs — Backstage being the most widely deployed example — were designed for human browsing: a developer looking for a service, its owner, its runbook link, and its API docs. That use case remains valid. A new use case is emerging alongside it: agents querying the catalog programmatically to answer questions, route incidents, identify dependencies, and make provisioning decisions.

An agent querying your catalog might be asking:

- "Which services depend on the payments-api? I need to notify their owners about a schema change."
- "What is the on-call contact for the service that owns the fraud-detection topic?"
- "Does any service owned by the identity team have an SLA below 99.9%?"

For these queries to return useful answers, catalog entries must be complete, consistent, and machine-parseable. The gaps that a human can overlook — an owner field left blank, a lifecycle tag missing, a dependency list that's three months out of date — are the exact gaps where agent queries fail silently or return wrong answers.

Practical shifts this drives:

- Catalog completeness becomes a platform metric, not a nice-to-have. Incomplete entries fail agent workflows.
- The catalog API surface (Backstage's catalog API, or equivalent) needs to be documented and stable, because agents will call it programmatically.
- Consider adding machine-oriented fields alongside human-oriented ones: explicit dependency graphs in a structured format, tags that agents can filter on, SLA values as numeric fields rather than prose.
- Backstage AI plugins (as of 2026-Q2, several are in development or early release) extend the catalog with semantic search and natural-language query support.

The underlying principle is the same one that drives good API design: structure your data for the consumer, and your consumers now include automated systems.

> [!info] As of 2026-Q2, Backstage's catalog API is stable and widely used for programmatic access. Purpose-built AI plugins for Backstage are in active development across the ecosystem but not yet standardized.

@feynman

An agent-readable catalog is just a well-structured catalog — the discipline of filling in every field, using consistent tags, and keeping dependencies current is what makes it useful to both humans and machines.

@card
id: plf-ch12-c006
order: 6
title: AI-Augmented On-Call
teaser: LLMs can summarize log bursts, correlate alerts across services, and draft a postmortem in under a minute — genuinely useful, but useful in a way that requires the on-call engineer to remain the one making decisions.

@explanation

On-call is expensive in both money and human attention. AI augmentation in this space is one of the more mature and useful applications of LLMs in the platform context, because the tasks involved — log summarization, alert correlation, postmortem drafting — are well-suited to what LLMs do well.

What is working in production as of 2026-Q2:

**Log summarization.** Tools like Datadog Watchdog and PagerDuty AIOps ingest log bursts during an incident and surface a plain-language summary of the anomalous patterns. This is faster than manual grep and genuinely reduces time-to-diagnosis.

**Alert correlation and noise reduction.** LLMs can group related alerts that fire in sequence and present a single incident hypothesis rather than a storm of individual notifications. The on-call engineer sees "likely cause: memory pressure on the cache tier" rather than forty individual alerts.

**Draft postmortems.** Given a timeline of events, alerts, and mitigation actions, an LLM can produce a structured postmortem draft in minutes. Engineers then review and correct rather than write from a blank page. Teams report this meaningfully reduces the tax on the on-call engineer in the hours following a resolution.

The failure mode to guard against: the same pattern-matching that makes LLMs fast at summarization also makes them confidently wrong. A log summary that focuses on the wrong anomaly will send the on-call engineer down the wrong path. A draft postmortem that misattributes root cause is worse than a blank page if the engineer accepts it without scrutiny.

Treat LLM on-call assistance as a fast first pass from a very well-read colleague who has never been in your specific system and may confidently misread what they see.

> [!warning] As of 2026-Q2, no production incident management platform recommends replacing the on-call engineer's judgment with autonomous LLM decision-making. The tools that work best are the ones that present analysis and wait for a human decision before taking action.

@feynman

AI on-call assistance is like having a fast analyst hand you a briefing when the pager fires — it saves you time getting oriented, but you still have to decide what to do.

@card
id: plf-ch12-c007
order: 7
title: The Platform as an AI Substrate
teaser: When the platform's primary day-to-day user becomes an agent rather than a human, the design priorities invert — availability, schema stability, and auditability matter more than good documentation and polished UIs.

@explanation

Most platforms are still primarily human-facing. But it is worth thinking through what changes when the primary consumer of your platform's APIs is an automated agent running on behalf of a developer, rather than the developer directly.

The inversion of priorities:

**API stability over UI polish.** A human can adapt to a UI change in a day. An agent breaks silently when an API schema changes. If agents are calling your provisioning API, that API needs a versioning contract and a deprecation policy.

**Auditability over convenience.** When a human makes a mistake, you can usually ask them what they intended. When an agent takes a sequence of actions, you need a complete audit trail to reconstruct what happened and why. Every action an agent takes against the platform should produce a structured log entry: who authorized the agent, what it was asked to do, what API calls it made, and what it changed.

**Predictable failure modes over graceful degradation.** Platforms designed for humans often degrade gracefully — a partial response is better than nothing, and a human can usually work around a missing field. An agent following a structured workflow is more likely to take a wrong action on a partial response than a human is.

**Rate limiting and quota enforcement.** A human clicks slowly; an agent can call your provisioning API hundreds of times in a minute. Platform rate limits designed for human usage patterns need to be reconsidered when agents enter the picture.

**Least-privilege scoping.** The agent provisioning a dev namespace should not have the same credentials as the agent performing a production deploy. Agent credential scope needs the same rigor you apply to service account permissions.

This framing does not mean redesigning the platform from scratch. It means treating the API surface with the same care you would treat a public API, even if it is still nominally internal.

> [!info] As of 2026-Q2, the concept of "platform as AI substrate" is more analytical framing than established practice. Teams worth watching are those building explicit agent-facing API layers on top of existing platform tooling rather than exposing internal systems directly.

@feynman

When an agent is your main user, the platform has to behave like a public API — consistent, versioned, auditable — because machines don't tolerate ambiguity the way humans can.

@card
id: plf-ch12-c008
order: 8
title: AI-Driven Cost Optimization
teaser: Automated right-sizing, idle resource detection, and anomaly-based cost alerting are maturing fast — the tools are useful today, but the judgment about what to actually do with their recommendations still belongs to a human.

@explanation

FinOps — the discipline of understanding and managing cloud spend — has always been data-heavy and recommendation-heavy. LLMs and ML-based anomaly detection are making the recommendation layer faster and more contextual.

What is working as of 2026-Q2:

**Automated right-sizing recommendations.** Tools like AWS Compute Optimizer, Azure Advisor, and GCP Recommender have used ML for years. In 2025-2026, these tools have incorporated more contextual reasoning — identifying not just that a resource is over-provisioned, but correlating it with specific workload patterns and suggesting the smallest change that achieves the target utilization.

**Idle resource detection.** Datadog Watchdog and similar AIOps platforms surface idle compute, unattached volumes, and stale load balancers with natural-language explanations. The output is a prioritized list of cleanup candidates with estimated savings.

**Anomaly-based spend alerting.** LLMs trained on cost history can distinguish between expected spend spikes (a monthly data processing job) and unexpected ones (a runaway API that started calling an expensive ML endpoint at 3x normal frequency). The alert is faster and more specific than a threshold-based budget alarm.

**Draft optimization reports.** For platform teams presenting cost analysis to leadership, LLMs can produce a first draft of the monthly cost review — "here is where spend grew, here is the likely cause, here are the three highest-impact actions" — in minutes rather than hours.

The limitation: all of these tools produce recommendations, not decisions. The recommendation to shut down an environment or resize a database in production requires human judgment about timing, risk, and organizational context that the tool does not have.

> [!info] As of 2026-Q2, most major cloud providers and observability vendors have integrated AI-based cost recommendations into their core products. The quality varies significantly. Treat recommendations as a prioritized backlog, not an action queue.

@feynman

AI cost optimization hands you a sorted list of things to fix and an estimate of what each one is worth — you still have to decide which ones to touch and when.

@card
id: plf-ch12-c009
order: 9
title: Code Review as a Platform Feature
teaser: AI PR review for golden-path conformance is the most direct way to enforce platform standards at scale — checking whether a service's Dockerfile, CI config, and catalog entry match the golden path before a human reviewer sees it.

@explanation

PR review is where golden-path drift is caught or not caught. Human reviewers are inconsistent — an experienced platform engineer will catch a non-standard base image; a busy one reviewing twenty PRs in a day will not. AI-assisted PR review is a practical approach to making golden-path enforcement more systematic.

What this looks like in practice:

A CI job runs on every PR that touches infrastructure-adjacent files — Dockerfiles, CI configuration, Kubernetes manifests, Backstage catalog entries, Terraform modules. The job sends those files to an LLM with a prompt that encodes the golden-path criteria:

```yaml
golden_path_checks:
  - "Dockerfile must use the approved base image: gcr.io/company-infra/base-python:3.12-slim"
  - "All services must include a catalog-info.yaml at the repository root with 'owner', 'lifecycle', and 'system' fields populated"
  - "Resource limits must be set on all container specs; requests must be at least 50% of limits"
  - "Liveness and readiness probes must be defined for all containers"
```

The LLM returns a structured result: which checks passed, which failed, and a plain-language explanation of each failure. The CI job posts this as a PR comment or check status.

The benefit: golden-path conformance feedback is instant, consistent, and doesn't consume human review bandwidth for mechanical checks.

The limitation: an LLM cannot verify runtime behavior, cannot catch logic errors, and can miss conformance issues in configurations it was not explicitly prompted to check. This is a supplement to human review, not a replacement. It handles the mechanical checks so human reviewers can focus on the design questions.

Cursor, Claude Code, and similar tools are also being used in the pre-commit phase to catch golden-path issues before the PR is even opened, using project-level rules files. The CI check provides a second layer.

> [!info] As of 2026-Q2, AI-assisted PR review for infrastructure conformance is being adopted by platform teams at mid-to-large organizations. Most implementations use a model via API (Anthropic or OpenAI) rather than a purpose-built product, because the golden-path criteria are organization-specific.

@feynman

AI PR review for golden-path conformance is a tireless checker that reads every Dockerfile with the same attention — freeing your human reviewers to think about the things that actually require judgment.

@card
id: plf-ch12-c010
order: 10
title: Self-Healing Platforms
teaser: Agents that detect and revert misconfigurations, retry failed deploys, and file tickets for unresolved issues are moving from research papers into production — with significant governance questions that the platform team must answer before deployment.

@explanation

Self-healing platforms attempt to close the loop between detection and remediation: rather than alerting an engineer who then reads the alert, diagnoses the issue, and runs a command, the system identifies the issue and takes a corrective action automatically.

What self-healing looks like at varying levels of autonomy:

**Automated retry (low risk, widely deployed).** A failed deployment is automatically retried once before paging an engineer. A failed health check triggers an automatic pod restart. This is standard Kubernetes behavior and not controversial.

**Automated rollback (medium risk, in production).** A deployment that causes error rate or latency to degrade past a threshold is automatically rolled back to the previous version. This is supported by most modern deployment platforms (Argo Rollouts, Spinnaker, Flagger) and is in production use.

**Agent-driven config revert (higher risk, emerging).** An agent monitors Kubernetes resources or Terraform state, detects drift from the desired state, and reverts the change automatically. This requires careful scoping: which resources are in scope, what counts as drift, and who authorized the revert.

**Agent-driven incident response (highest risk, experimental).** An agent takes a sequence of actions during an active incident — restarting services, rerouting traffic, scaling resources — based on an LLM-generated runbook. This is being explored but is not recommended for Sev-1 production incidents without a human in the decision loop.

The governance question the platform team must answer: for each class of automated action, who authorized it, what are the bounds, and how is every action logged and attributed? A runaway self-healing agent that repeatedly restarts a service can amplify an incident rather than resolve it.

> [!warning] As of 2026-Q2, the most mature self-healing implementations are limited to well-understood, reversible actions with clear success criteria (rollback, restart, scale). Broader autonomous remediation remains an area where the failure modes are not yet well understood in production.

@feynman

A self-healing platform is only as safe as the boundaries you set on what it is allowed to fix — because an agent that can fix anything can also break anything if it misreads the situation.

@card
id: plf-ch12-c011
order: 11
title: AI Agent Governance
teaser: Giving agents access to your platform's APIs without a governance model is the same mistake as giving a contractor root access without an offboarding plan — the capability exists, but the controls don't.

@explanation

Every AI agent that calls your platform's APIs is a principal — an identity that can take actions, consume resources, and make changes. Treating agents as first-class principals in your governance model is the prerequisite for deploying them safely.

The governance questions the platform team needs to answer:

**Identity and authentication.** How does an agent authenticate to the platform? Service accounts are the standard answer, with credentials scoped to the agent's specific role. An agent that provisions dev namespaces should not have credentials that allow production changes.

**Scope and least privilege.** What is the agent allowed to do? Write this down explicitly, not as an assumption. An agent given broad platform access will use it, sometimes in ways you did not intend. Scope should be defined per-agent, per-environment, and reviewed on a cadence.

**Action logging and audit trail.** Every action an agent takes must be logged with: the agent's identity, the human or system that triggered the agent, the specific action taken, the parameters passed, and the result. If an agent makes a change you didn't expect, you need to be able to reconstruct exactly what happened.

**Rate limiting and spend controls.** Agents can call APIs at machine speed. Your platform's rate limits and quota enforcement need to account for agent-level throughput, not just human-level throughput.

**Approval gates for high-risk actions.** For actions above a defined risk threshold — production deploys, deletion of resources, changes to security group rules — require explicit human approval before the agent proceeds. The agent can prepare the action; a human clicks approve.

**Revocation.** Can you revoke an agent's credentials instantly if it behaves unexpectedly? This needs to be a five-minute operation, not a multi-step process requiring a ticket.

The governance model for agents does not need to be novel. It is mostly the same access control discipline you already apply to service accounts and CI pipelines, applied with the same rigor to a new class of principal.

> [!info] As of 2026-Q2, there is no widely adopted standard for AI agent governance in platform engineering contexts. Most teams are adapting existing identity and access management practices rather than building new frameworks. The conversations happening in OpenID Connect working groups and in the MCP ecosystem around agent identity are worth following.

@feynman

AI agent governance is just access control for a new kind of principal — the same questions you ask about a service account, asked about a system that can take actions on its own initiative.

@card
id: plf-ch12-c012
order: 12
title: What Stays Human
teaser: AI accelerates the mechanical work of platform engineering — it does not replace the judgment, political navigation, and taste that determine whether the platform actually serves the organization well.

@explanation

This chapter has covered a lot of change. It is worth being precise about what is not changing.

The platform's core value has always been reducing cognitive load for application teams by absorbing complexity into a well-maintained layer. That value does not depend on whether the tools the platform provides are provisioned by a human or by an agent. The discipline — treating the platform as a product, maintaining a roadmap, measuring adoption, listening to users — is unchanged.

What stays human:

**Judgment under ambiguity.** An agent can execute a runbook. It cannot decide whether this incident is severe enough to page the VP at 2 a.m., or whether a 5% error rate is acceptable given what you know about the upstream partner's behavior this week.

**Organizational navigation.** The hardest parts of platform engineering are not technical. Convincing three different teams to adopt the same CI standard, negotiating which security controls are mandatory versus optional, deciding when the golden path has accumulated enough friction that it needs to be redesigned — these are social and political acts that require understanding of the organization's history, power dynamics, and culture.

**Taste.** Good platform design requires the ability to distinguish between a self-service interface that developers will actually use and one they will route around. This is harder to describe than to recognize, and it is not yet something agents do well.

**Accountability.** When the platform fails, someone is responsible. That accountability cannot be delegated to an agent. The platform team owns the outcomes.

This book has built from the fundamentals across eleven chapters — from what platform engineering is, through internal developer platforms, golden paths, service catalogs, observability, cost, and organizational patterns. The tools from the companion books in this series — *Refactoring Existing Systems*, *AI-Assisted Refactoring*, and *Designing APIs That Last* — apply here too: the platform's own APIs should be designed with the same rigor you'd apply to any API that serves real users.

AI is making the platform team faster at the mechanical parts of their work. The hard parts are still hard. The judgment is still yours.

> [!info] As of 2026-Q2, the platform engineering role is not shrinking due to AI adoption — if anything, the scope is expanding as organizations discover that agent infrastructure needs the same kind of principled abstraction layer that application infrastructure does. The platform team's job just got more interesting.

@feynman

The platform team's job is still about judgment, trust, and organizational design — AI handles the parts that were always mechanical; the parts that were never mechanical remain untouched.
