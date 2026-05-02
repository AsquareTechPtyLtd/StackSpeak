@chapter
id: ttp-ch10-modern-engineering-2026
order: 10
title: Modern Engineering (2026)
summary: The practitioner in 2026 works with AI tools, distributed defaults, and infrastructure-as-code expectations that didn't exist a decade ago — but the underlying discipline of building systems that last is the same as it ever was.

@card
id: ttp-ch10-c001
order: 1
title: Treat AI-Generated Code Like a Stranger's PR
teaser: LLMs produce confident, plausible-looking code that can be subtly wrong in ways that survive a casual read — reviewing it with less rigor than a PR is how you accumulate invisible debt.

@explanation

An LLM has no stake in your system's correctness. It doesn't know your invariants, your edge cases, or the implicit assumptions baked into your codebase from three years of production incidents. It will produce code that compiles, passes the tests you thought to write, and looks authoritative — and it will do all of this while misunderstanding the problem at the level that matters.

The mental model that protects you: treat every block of AI-generated code the way you'd treat a PR from a contractor you've never worked with. That means:

- Read it completely before merging it. Not skimming — reading.
- Understand what it does, not just what it appears to do. Trace the execution path.
- Ask whether it handles the failure modes you know exist in your system. The LLM doesn't know them.
- Test it against your edge cases, not just the happy path the LLM demonstrated.
- If you can't explain it to a teammate, you don't understand it well enough to ship it.

The failure mode is not that AI-generated code is always wrong. It's that it's wrong in ways that look right until production. A misunderstood authentication check, an off-by-one in a rate limiter, a retry loop that doesn't handle idempotency — these don't fail loudly. They fail at 2am with an incident that's hard to trace back to the pasted block you approved six weeks ago.

The engineer who ships AI output without reading it is not moving faster. They are borrowing speed against an unknown debt that will come due.

> [!warning] The confidence of the output is not correlated with its correctness. LLMs don't flag uncertainty the way a human reviewer would say "I'm not sure about this part."

@feynman

It's the same due diligence you'd apply to any code you didn't write — the fact that it was generated in three seconds doesn't change what it does in production.

@card
id: ttp-ch10-c002
order: 2
title: Observability Is an Architectural Decision
teaser: The system you instrument from day one is the system you can actually operate — bolting on observability after the first production incident costs ten times what it would have cost at design time.

@explanation

Observability is not a monitoring tool you add to a finished system. It is a set of architectural decisions — about what your system emits, in what format, at what granularity — that determine whether you can understand your system's behavior in production.

The three pillars that belong in every system design:

**Structured logs.** Not `console.log("error occurred")`. Structured JSON with consistent field names, correlation IDs, severity levels, and enough context to reconstruct what the system was doing at the time. A log you can't query is noise.

**Metrics.** Named, labeled, incrementable signals that tell you the shape of your system's behavior over time. Request rates, error rates, latency percentiles (p50, p95, p99), queue depths, cache hit rates. You need to know what normal looks like to recognize abnormal.

**Traces.** Distributed trace IDs that follow a request across service boundaries. In a system with five services, a 500ms latency spike with no tracing is a mystery. With tracing, it's a 10-second investigation.

The cost of retrofitting these is high because they require changes throughout the call stack — every service, every function boundary, every external call. The engineer who says "we'll add observability when we need it" is the engineer who is debugging a production incident at 2am with `grep` and prayer.

Design observability in at the same time you design the API contract. It is not optional infrastructure.

> [!info] A system you can't observe is a system you're guessing about. You may be guessing correctly, but you don't know that you are.

@feynman

You wouldn't build a car engine without gauges — observability is the instrument panel that tells you whether the system is running the way you think it is.

@card
id: ttp-ch10-c003
order: 3
title: Write for the Maintainer with No Context
teaser: The reader of your code at 2am during a production incident has no memory of your design decisions, no access to you, and no time — write everything as if that person is your only audience.

@explanation

The default assumption engineers make when writing code is that the reader has roughly the same context they do right now. This is wrong in three ways: the reader may be a different person, it may be months later, and it may be a crisis.

"Write for the maintainer with no context" is a rule that changes specific behaviors:

- **Code:** name variables and functions for what they represent in the domain, not what they happen to be in the implementation. `expiresAt` is better than `ts`. `isEligibleForPromotion` is better than `flag`.
- **Comments:** explain why, not what. The code already says what. The comment that saves an incident responder is "This timeout is intentionally high — the downstream service has a 30s cold start on the first request."
- **Commit messages:** the subject line is the what; the body is the why. "Fix auth bug" is useless. "Reject tokens issued before the key rotation on 2025-11-03 — tokens from that window bypassed scope validation" is useful six months later.
- **Runbooks:** written for someone who has never operated this system. Every step explicit, every assumption stated, every "it depends" resolved into a concrete decision tree.
- **PR descriptions:** enough context that a reviewer who has never seen this code can evaluate whether the change is correct, not just whether it compiles.

None of this requires more time than writing the undocumented version. It requires a different mental model of your audience. The 20 seconds you spend writing a clear commit message is insurance against the 45 minutes the incident responder spends reconstructing what changed.

> [!tip] Before you commit, ask: if the person reading this has never seen this codebase and is in the middle of an incident, does this give them what they need?

@feynman

You're writing letters to a future stranger in a burning building — clarity isn't a courtesy, it's the difference between a fast resolution and a long outage.

@card
id: ttp-ch10-c004
order: 4
title: LLMs as Accelerators, Not Decision-Makers
teaser: AI tools reliably speed up boilerplate, test scaffolding, and documentation — they reliably produce plausible-looking errors on architecture, security, and system design decisions.

@explanation

The honest picture of where LLMs add value in 2026:

**Reliable:** boilerplate generation (CRUD endpoints, migration scripts, serialization code), translating between syntactically similar languages, generating test cases for known behavior, explaining unfamiliar code in plain language, writing first-draft documentation that you edit into accuracy.

**Unreliable:** architecture decisions with system-specific constraints, security-sensitive logic (authentication, authorization, cryptography), performance-sensitive code where the bottleneck requires understanding your specific workload, novel problem-solving that requires genuine reasoning about tradeoffs.

The failure mode is applying the tool outside its reliable range. An LLM that writes your authentication middleware with a subtle bypass is not saving you time — it's creating work you haven't discovered yet.

A useful heuristic: use LLMs aggressively for work where the correctness is easily verifiable (you can read it, test it, or compare it to a known-good reference). Use them cautiously or not at all for work where "looks right" is a dangerous proxy for "is right."

The design decisions — what to build, how to structure the system, what tradeoffs to accept — belong to the engineer. The AI is a tool in that process, not a principal. An engineer who lets an LLM make architecture choices is outsourcing judgment to a system that has no understanding of their constraints, their team's capabilities, or their operational environment.

> [!info] The question is not whether to use AI tools — it's whether you're using them in the zone where they're reliable or in the zone where they confidently produce wrong answers.

@feynman

An LLM is like a power drill — dramatically faster than doing it by hand on the tasks it's built for, and actively harmful if you use it as a hammer.

@card
id: ttp-ch10-c005
order: 5
title: Infrastructure as Code Is the Baseline
teaser: In 2026, click-ops is technical debt — any environment you manually configured is an environment you can't reliably reproduce, audit, or recover from a failure.

@explanation

Infrastructure as Code (IaC) means your infrastructure configuration is version-controlled, reviewable, reproducible, and auditable — the same properties you require of application code. In 2026, this is not an advanced practice. It is the minimum bar for any environment you intend to maintain past the first week.

The tools vary by context: Terraform and OpenTofu for multi-cloud resource provisioning, Pulumi if you prefer general-purpose languages, AWS CDK or Bicep for cloud-specific stacks. The choice matters less than the principle: the console is for exploration, not for anything that needs to last.

The cost of "I'll just do it in the console" compounds predictably:

- **Disaster recovery:** when the environment needs to be rebuilt after a failure, you have no playbook. You're guessing from memory and CloudTrail logs at 3am.
- **Auditability:** you can't tell what changed, when, or who made the change. The security team asks; you have no answer.
- **Reproducibility:** staging doesn't match production because someone made a manual change six months ago that was never documented. The bug you can't reproduce in staging is running in production.
- **Scaling:** you provision one environment manually in an hour. You provision ten the same way and the tenth is subtly different from the first.

IaC also forces a design exercise: you have to specify what you're building explicitly, which surfaces decisions that click-ops lets you defer until they become incidents.

> [!warning] "The console was faster" is true the first time and false every time after. The debt is in every future operation on that environment.

@feynman

Manually configuring infrastructure is like writing a deploy script that only works on your laptop — it looks like it works until someone else needs to use it.

@card
id: ttp-ch10-c006
order: 6
title: The Platform Engineering Shift
teaser: Platform teams build the self-service infrastructure layer that lets product engineers deploy, observe, and operate their services without becoming infrastructure experts — understanding your platform is not optional.

@explanation

Platform engineering is the discipline of treating developer experience as an internal product. Instead of every team building their own deploy pipelines, secrets management, observability stack, and container configuration, a platform team builds a golden path — a well-lit set of defaults that any engineer can follow to go from code to production with a single command.

What a mature platform provides:
- Deploy pipeline with security scanning, test gates, and rollback built in
- Observability defaults: your service gets logs, metrics, and traces without configuring them
- Secrets management that doesn't involve environment variables in `.bash_profile`
- Service-to-service authentication via mTLS or service mesh, not hardcoded tokens
- Cost visibility: you can see what your service costs to run

The engineer who understands the platform they're building on can use it effectively, debug it when it fails, and push back when it's wrong. The engineer who treats it as magic is blocked whenever it behaves unexpectedly — and at the worst possible time, they discover that the "one-command deploy" has constraints no one told them about.

The platform is not your problem to build. It is your environment to understand. That means reading the internal docs, understanding the abstraction leaks (and every abstraction leaks eventually), and knowing which knobs you can turn versus which are platform-enforced.

> [!info] The golden path exists to be used, not to be cargo-culted. Knowing why each constraint exists is what separates an engineer who can work within the platform from one who works around it.

@feynman

The platform is the operating system for your service — you don't need to have written it, but you need to understand what it does and what it doesn't do for you.

@card
id: ttp-ch10-c007
order: 7
title: Distributed Systems Are the Default
teaser: Most production code in 2026 runs in a distributed system — the failure modes that only appear in production require mental models that don't apply to single-process programs.

@explanation

The default deployment target in 2026 is not a single process on a single machine. It is a collection of services, functions, or containers communicating over a network — with all the failure modes that implies.

The failure modes that only appear in distributed systems:

**Partial failures.** Your service is healthy. The service you depend on is returning 200 but with stale data. Your service is technically working and producing quietly wrong results. A single-process program doesn't have this failure mode.

**Network partitions.** Your database is reachable but your cache is not. The fallback you wrote assumes the cache miss means the key doesn't exist — but it means you can't reach the cache. These distinctions matter and they behave differently.

**Clock skew.** Two services use timestamps to order events. The clocks on the underlying hosts drift by 50ms. Your ordering logic, which looks correct in tests, is nondeterministic in production.

**The cascade.** One slow service causes upstream services to queue requests, exhaust connection pools, and time out — even though the slow service recovers in 30 seconds. By then, the cascade has taken down three services that had nothing wrong with them.

Reasoning about distributed systems requires explicit thinking about: what happens when a downstream call is slow? What happens when it returns an error? What happens when it doesn't return at all? What is the retry behavior, and does retrying make the problem worse? These questions don't exist in single-process programs and they can't be deferred until after launch.

> [!warning] A distributed system with no timeout configuration, no circuit breakers, and no bulkheads is a cascade waiting for a trigger.

@feynman

A distributed system is not a fast single-process program — it's a different class of system with different failure modes, and treating it like the former is how you get outages that look inexplicable.

@card
id: ttp-ch10-c008
order: 8
title: Security as a Shift-Left Discipline
teaser: Security integrated into the development workflow catches vulnerabilities in minutes; security bolted on at deployment catches them in production — or doesn't catch them at all.

@explanation

"Shift-left security" means moving security checks earlier in the development cycle — into the IDE, the PR, and the CI pipeline — rather than running them as a separate audit gate before release or not at all.

The concrete practices that shift security left:

**SAST in CI.** Static application security testing runs on every PR. A SQL injection pattern, a hardcoded secret, an insecure deserialization — caught in the PR, not in a pentest six months later. Tools vary by language; the important property is that they run automatically.

**Dependency scanning.** Your application's dependencies have vulnerabilities. Tools like Dependabot, Snyk, or Grype scan your dependency tree and surface CVEs with severity ratings. A critical vulnerability in a transitive dependency you didn't know you had is not a theoretical problem.

**Secrets detection.** Engineers commit secrets to version control with a frequency that suggests this is a hard problem. Pre-commit hooks and CI checks that scan for API keys, credentials, and private keys before they reach the remote are cheap insurance.

**Supply chain awareness.** In 2024, a widely-used open-source library (xz-utils) was backdoored by a maintainer over three years of social engineering. Your CI pipeline, your container registry, and your dependency tree are attack surfaces. Pinning dependency versions, verifying checksums, and using private mirrors are not paranoid — they are the minimum bar for a production system.

The threat model in 2026 includes your toolchain, not just your application code.

> [!info] The cost of a security check in CI is milliseconds. The cost of a breached secret in production is measured in incident response hours, regulatory exposure, and customer trust.

@feynman

Shift-left security is the same principle as catching a type error at compile time vs. a null pointer exception at runtime — the earlier in the process you find it, the cheaper it is.

@card
id: ttp-ch10-c009
order: 9
title: Open Source as Load-Bearing Infrastructure
teaser: Most production systems run on open-source foundations that are maintained by a small number of people, many of them volunteers — that dependency is a responsibility, not just a convenience.

@explanation

The production system you're building almost certainly depends on Linux, PostgreSQL or MySQL, Nginx or a reverse proxy, an open-source language runtime, open-source libraries throughout its dependency tree, and possibly Kubernetes, Kafka, or Redis. These are not commodities you consume passively. They are infrastructure that needs to be understood, maintained, and — at some level — contributed to.

Three questions every engineer should have answers to for their critical open-source dependencies:

**Who maintains this?** For a library you depend on in production, do you know if it's maintained by a company, an individual, or a community of contributors? Is there a funded maintainer or is it a nights-and-weekends project? The answer tells you how quickly CVEs will be patched and whether the project will exist in three years.

**Who's scanning this?** Transitive dependencies in a typical Node.js or Python project number in the hundreds. Most teams have no systematic process for tracking CVEs across all of them. Dependency scanning tools automate this; the question is whether you have one running.

**Are you consuming or contributing?** Most teams consume exclusively. The sustainability problem in open source is that the projects production systems depend on are maintained by a small number of unpaid contributors absorbing a maintenance burden that scales with adoption. Contributing bug fixes, documentation, or issue triage is not altruism — it's investment in infrastructure you depend on.

None of this means you audit every dependency manually. It means you have a policy, not a blind spot.

> [!tip] Know your critical path. For the five open-source projects most load-bearing in your system, you should know who maintains them and how you'd respond if they stopped being maintained tomorrow.

@feynman

Depending on an open-source library without understanding who maintains it is like depending on a bridge you've never checked the inspection records for — it's probably fine, until it isn't.

@card
id: ttp-ch10-c010
order: 10
title: The Craft Mindset
teaser: The difference between the engineer who ships features and the engineer who ships systems that last is sustained attention to quality — not as perfectionism, but as a discipline applied consistently over time.

@explanation

Software engineering rewards velocity in the short term and quality in the long term. These are not always in conflict, but when they are, most incentive structures — sprint velocity, feature count, closed tickets — optimize for the short term. The craft mindset is the counterweight.

What the craft mindset looks like in practice:

**Finishing, not just shipping.** A feature that ships without tests, without documentation, without cleanup of the exploratory code used to build it is not finished — it's a liability that the next engineer inherits. Finishing means the feature works, it's maintainable, and it doesn't require the original author to be on-call forever.

**Caring about the quality of what you build, not just the existence of it.** The engineer who asks "does this work?" is at the beginning. The engineer who also asks "will this still work in a year, under load, without me?" is practicing craft.

**Noticing and addressing erosion.** Systems degrade by default — dependencies go stale, comments go stale, tests go stale, architectural decisions made in year one don't age well into year three. The craft mindset includes maintenance, not just creation.

**Taking pride without attachment.** The craftsperson who can't accept feedback on their work because they're attached to the decisions they made is not practicing craft — they're protecting ego. Craft includes the willingness to revisit, refactor, and delete your own work when the system requires it.

The engineer who finishes features that last is not working slower. They are working at a cadence that compounds. The engineer who ships fast and moves on leaves a codebase that gets progressively harder for everyone, including themselves.

> [!info] The best engineers you'll work with are not the ones who ship the most — they are the ones whose work is still running cleanly two years after they moved to another team.

@feynman

Craft is the difference between a carpenter who builds furniture that lasts twenty years and one who builds furniture that lasts until it's assembled — both shipped, but only one is done.
