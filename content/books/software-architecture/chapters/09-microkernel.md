@chapter
id: sa-ch09-microkernel
order: 9
title: Microkernel
summary: A small core with plug-ins for everything that varies. The right shape for IDEs, browsers, build tools, and any product that needs to be extensible by users.

@card
id: sa-ch09-c001
order: 1
title: The Plug-In Architecture
teaser: Microkernel separates the system into a stable core (the kernel) and a set of optional plug-ins. The kernel knows nothing specific about the plug-ins; the plug-ins do all the variable work.

@explanation

A microkernel architecture has two parts:

- **The core (kernel)** — a small, stable engine. Knows how to load plug-ins, route messages, manage common infrastructure. Does almost no domain work itself.
- **Plug-ins** — independent modules that provide specific functionality. Connect to the core through a well-defined contract.

Examples in the wild:

- **VS Code, IntelliJ, Eclipse** — small core; everything (language support, debuggers, themes) is plug-ins.
- **Web browsers** — rendering engine and tab management as core; everything else (extensions, bookmark managers, ad blockers) as plug-ins.
- **Build systems** — Bazel, Gradle. Core handles dependency resolution and execution; rules and tasks are plug-ins.
- **Notion, Obsidian** — core for content; plug-ins for everything from databases to graph views.
- **Salesforce** — core CRM; everything else is the AppExchange (plug-ins).

The architecture answers a specific need: a system whose value comes from being extensible by third parties or by the team itself, with a predictable contract.

> [!info] Microkernel is the architecture of platforms. The product isn't the core — it's the ecosystem the core enables.

@feynman

The same shape as a power strip. The strip itself does almost nothing — it provides outlets. The value comes from what you plug into it. The strip's design is about making plugging in easy and safe.

@card
id: sa-ch09-c002
order: 2
title: When Microkernel Is the Right Style
teaser: Products that need to be extended by others — by users, by partners, by your own team without core changes. If extensibility is part of the value proposition, microkernel is probably the answer.

@explanation

Microkernel earns its keep when:

- **Extensibility is a product requirement.** The system has to support cases the core team can't enumerate up front.
- **Variability is high but the contract is stable.** What changes is huge in scope; how it integrates is well-defined.
- **Third parties or end-users build extensions.** You're shipping a platform, not a closed product.
- **Your own team needs to ship customisations.** Different customers get different feature sets; you don't fork.
- **Plug-ins evolve independently.** Plug-in version 5 can run alongside core version 3.

It's a poor fit for:

- **Closed-world systems.** No third parties; no custom features. The plug-in machinery is overhead.
- **Tightly-coupled domains.** When every "extension" needs intimate knowledge of every other.
- **High-performance critical paths.** The plug-in dispatch overhead can hurt latency-sensitive systems.

> [!info] You'll often see microkernel attempted prematurely — "we'll make it pluggable so the team can add features later." Without an actual extension consumer, the plug-in machinery is engineering overhead with no payoff. Pluggability has a price.

@feynman

Same lesson as designing for "future flexibility." If you don't have a real third party building plug-ins, you're paying for an extensibility you may never use. Wait until the demand is real, or start without it.

@card
id: sa-ch09-c003
order: 3
title: The Kernel — Small, Stable, Boring
teaser: A successful microkernel is dull. It loads plug-ins, manages lifecycle, routes messages, enforces contracts. If your kernel is big or interesting, you've put domain logic in the wrong place.

@explanation

The discipline of microkernel design is in the kernel staying small. The recurring temptation:

- "We'll add this feature to the kernel because every plug-in needs it."
- "We'll have the kernel do this validation because plug-ins keep getting it wrong."
- "We'll make the kernel smarter so plug-ins can be simpler."

Each is reasonable; cumulatively they kill the architecture. The core grows; the plug-in contract becomes harder; the system stops being a microkernel.

A healthy kernel handles:

- **Plug-in loading and unloading** — discovery, instantiation, teardown.
- **Lifecycle events** — startup, shutdown, errors.
- **Communication infrastructure** — message bus, command dispatcher, event broker.
- **Resource management** — shared services (logging, config, persistence) plug-ins can use.
- **Security and sandboxing** — preventing one plug-in from breaking others.

A healthy kernel does not handle:

- **Specific domain logic** — that's what plug-ins are for.
- **Special cases for specific plug-ins** — one off-ramps the architecture.
- **UI rendering details** — those belong to UI plug-ins.

> [!warning] The kernel that's "100K LOC and still growing" is a sign the team has lost the discipline. Audit the kernel quarterly; what's in there that doesn't belong?

@feynman

The same instinct as keeping framework code small. The framework's job is to load and orchestrate; the application's job is to do the specific work. When the framework starts doing the application's job, you have a god framework, not a useful one.

@card
id: sa-ch09-c004
order: 4
title: Plug-In Contract — The Hard Part
teaser: Designing the contract between kernel and plug-ins is the hardest design decision. Too narrow and plug-ins can't do enough; too broad and the kernel can't change without breaking everyone.

@explanation

The plug-in contract — the API between kernel and plug-in — is where microkernel architectures succeed or fail.

A good contract:

- **Is small.** A few well-named operations beats fifty.
- **Is stable.** Backwards compatibility for years; new versions add to the contract, don't replace.
- **Is documented.** Plug-in authors are not on your team; they need explicit docs.
- **Is versioned.** Plug-ins target a version; the kernel supports multiple versions.
- **Has a discovery mechanism.** The kernel can ask "what does this plug-in do?" without running it.

A bad contract:

- **Leaks kernel internals.** Plug-ins reach into kernel data structures; refactoring breaks plug-ins.
- **Has no version negotiation.** Plug-ins assume "the latest"; old plug-ins break on upgrade.
- **Requires plug-ins to mutate shared state.** One plug-in's bug breaks another's expectations.
- **Is implicit.** Behaviour depends on order of plug-in loading or undocumented side effects.

The contract design is also the API design for an ecosystem. If you're going to attract third-party developers, the contract has to be inviting — clear, stable, well-tooled.

> [!info] VS Code's extension API is a master-class in plug-in contract design. It's small, well-documented, versioned, and the team has supported it for years. Read it as an example of what "good" looks like.

@feynman

Same as designing a public API for a SaaS. Once it's public, you can't change it without coordinating with every consumer. Plug-in contracts are public APIs you happen to ship inside your own product.

@card
id: sa-ch09-c005
order: 5
title: Plug-In Independence
teaser: Plug-ins should not depend on each other directly. Cross-plug-in coordination goes through the kernel. Otherwise the kernel stops being the only point of integration — and the architecture quietly dies.

@explanation

The discipline: plug-ins talk to the kernel, never to each other. When two plug-ins need to coordinate (e.g., a syntax-highlighter plug-in and an autocomplete plug-in for the same language), the kernel mediates.

How this looks in practice:

- **Plug-in registration** — each plug-in tells the kernel what it provides and what it needs.
- **Capability lookup** — the kernel exposes "give me all plug-ins that handle Python" without naming any specific plug-in.
- **Event publishing** — a plug-in emits an event; the kernel routes it to subscribers; the publisher doesn't know who's listening.
- **Service injection** — the kernel provides shared services (file system, settings, logging) to every plug-in that wants them.

What you avoid by enforcing this:

- **Tight coupling between plug-ins.** Plug-in A imports Plug-in B. Now A can't ship without B; B can't change without breaking A.
- **Hidden dependencies.** Plug-ins assume each other's presence. The system works if both are loaded; mysteriously breaks if one isn't.
- **Plug-in version hell.** Plug-in A v2 needs Plug-in B v3+; Plug-in C v1 needs Plug-in B v2 or earlier. The user is stuck.

> [!warning] When plug-ins start importing each other directly, the architecture has degenerated. Either re-establish kernel mediation or admit the system has become a normal modular monolith with extra steps.

@feynman

The same instinct as ESBs and message buses. Components publish; the bus routes. Two components that bypass the bus and call each other have just built a coupling the bus was supposed to prevent.

@card
id: sa-ch09-c006
order: 6
title: Plug-In Sandboxing
teaser: A bug or malicious behaviour in one plug-in shouldn't crash the kernel or other plug-ins. Sandboxing — process isolation, capability scoping, resource limits — is what makes the platform safe.

@explanation

Plug-ins are untrusted code from the kernel's perspective — even when they're written by the same team, they have bugs. The architecture has to protect against them.

Sandboxing techniques, by isolation strength:

- **In-process, language-level** — plug-ins run in the same process; the runtime enforces some isolation (sandboxed JS contexts, restricted Python imports). Lightest; most permeable.
- **In-process, language-level + capabilities** — plug-ins receive only the capabilities they need (no global access; pass in services explicitly). Stronger; harder to leak.
- **Separate processes** — each plug-in runs in its own subprocess; communication via IPC. Crash isolation; resource isolation.
- **Separate VMs / containers** — each plug-in in its own micro-VM. Strong isolation; higher overhead.
- **Separate machines** — plug-ins run on remote nodes. The strongest isolation; for distributed systems.

Most desktop microkernel applications (VS Code, browsers) use a combination: separate processes for major plug-ins (browser tabs, extensions), language-level sandbox for less risky ones.

> [!tip] Pick the isolation level that matches the trust model. Internal-only plug-ins from your own team can run in-process; third-party extensions need at least process isolation.

@feynman

The same concern as multi-tenancy in any system. Each tenant gets a sandbox; one tenant's runaway query doesn't take down the others. Plug-ins are tenants in your kernel.

@card
id: sa-ch09-c007
order: 7
title: Versioning the Plug-In Ecosystem
teaser: Once you ship plug-ins, you have to support multiple versions for years. The kernel that breaks plug-ins on every release loses its ecosystem fast.

@explanation

A microkernel architecture lives or dies by its plug-in compatibility story. Plug-in authors invest in your platform; they expect their work to keep running.

Practical patterns:

- **Semantic versioning of the plug-in API.** Major version = breaking change; minor = additive; patch = bug fix.
- **Multi-version support.** The kernel supports the current major and the previous major; plug-ins on either work.
- **Deprecation cycles.** When you change the contract, mark the old way deprecated; remove it only after a known interval (a year or more for healthy ecosystems).
- **Migration tools.** When breaking changes are necessary, ship tools that migrate plug-ins automatically when possible.
- **Beta channels for plug-in authors.** New API versions visible to authors before users; gives time to update.

What this means for the architect:

- The plug-in contract is much more expensive to change than internal code.
- Designing the contract carefully on day one saves years of migration pain.
- The team commits to long-term API support — that's a real ongoing cost.

> [!info] The "we'll fix the API later when we know better" approach almost always costs more than designing carefully on day one. The plug-in API is, in some sense, the architecture — get it right or live with mistakes for a long time.

@feynman

Same as releasing a public library. Every version you publish is a contract you keep, more or less, forever. The plug-in API of a microkernel is the same — public-facing, long-lived, slow to evolve.

@card
id: sa-ch09-c008
order: 8
title: Discovery and Configuration
teaser: How does the kernel know which plug-ins to load? How do plug-ins find their settings? Discovery and configuration are the wiring that makes a microkernel useable.

@explanation

Two infrastructure concerns every microkernel needs to solve:

**Plug-in discovery** — how the kernel knows what plug-ins exist:

- **Manifest-based** — each plug-in ships a manifest (`package.json`, `plugin.yaml`) the kernel reads on startup.
- **Convention-based** — plug-ins live in known directories; the kernel scans them.
- **Registry-based** — a central registry lists available plug-ins; the kernel queries it.

Most production systems use manifests. They're explicit, debuggable, and the format is well-understood.

**Plug-in configuration** — how plug-ins get their settings:

- **Per-plug-in config files** — each plug-in reads its own config.
- **Centralised settings** — the kernel exposes a settings service; plug-ins query for their keys.
- **User-facing settings UI** — for end-user-facing plug-ins, the kernel often provides a UI; plug-ins declare their settings schema.

The discoverability of plug-ins (and their settings) is a UX feature for the platform's users. If users can't find plug-ins, install them, configure them, and disable them easily, the ecosystem stalls.

> [!info] The "marketplace" pattern (VS Code Marketplace, Chrome Web Store, Salesforce AppExchange) is the user-facing endpoint of plug-in discovery. The architecture decisions about manifests, signing, and trust feed directly into the marketplace UX.

@feynman

Same as running a phone with apps. The OS finds apps in the app store; users browse, install, and configure them. The microkernel runs the same play at the architecture level.

@card
id: sa-ch09-c009
order: 9
title: Performance Considerations
teaser: Plug-in dispatch isn't free. Each lookup, each call across the contract, each cross-process boundary has overhead. For latency-critical paths, design the kernel API to be efficient — or batch the calls.

@explanation

The microkernel's flexibility has a performance cost:

- **Lookup overhead** — finding the right plug-in for a request takes time.
- **Cross-boundary calls** — function calls across the plug-in contract are slower than direct calls.
- **Cross-process boundaries** — IPC adds significant latency vs in-process calls.
- **Indirection** — dispatching through the kernel means an extra hop.

For most applications, this overhead is acceptable. An IDE can spend a millisecond dispatching a syntax-highlight request; the user doesn't notice.

For latency-critical applications, the overhead matters. Strategies:

- **Batch requests at the contract.** A single "highlight these 100 tokens" call is faster than 100 calls.
- **Cache plug-in lookups.** Once you know which plug-in handles a request, don't re-resolve.
- **Co-locate hot plug-ins in-process.** Trade isolation for speed where the call rate is high.
- **Pre-compile plug-in glue code.** Some systems generate optimised dispatch tables at startup.

> [!warning] If your microkernel's hot path involves dispatching through the contract on every request, the architecture is fighting your latency goals. Consider whether the path needs the flexibility — or whether it should be hard-coded in the kernel for performance.

@feynman

The same trade as virtual functions vs direct calls in OO. The flexibility costs cycles. Most of the time you don't notice; in the inner loop, you do — and that's where you compromise.

@card
id: sa-ch09-c010
order: 10
title: When to Stop Plugging
teaser: Microkernel works when the plug-in surface is well-defined. When you're tempted to make the kernel "configurable to do anything," you've lost the architecture. Either commit to a smaller kernel or admit you need a different style.

@explanation

The drift pattern in microkernel architectures: the kernel becomes more flexible to handle the cases plug-ins can't quite cover. Each addition is small. Cumulatively, the kernel becomes a god-object that does everything, and the plug-ins become thin shells around the kernel's actual work.

Symptoms of the drift:

- The kernel has feature flags and configuration switches in every code path.
- Plug-ins are mostly empty; they delegate everything to the kernel.
- Plug-in authors complain that "real" features are hardcoded in the kernel.
- The team can't articulate what's in the kernel and what's not.

The fix is to step back and ask: what's the genuine variability the system needs to support? If it's small and well-defined, the architecture is fine; tighten the kernel. If it's huge and ill-defined, microkernel might be the wrong style — a layered or service-based system might fit better.

The architecture has to match the actual problem. A microkernel that's been growing arms and legs for two years is signalling that the original premise — "we have a small core and lots of variable plug-ins" — wasn't true, or has stopped being true.

> [!info] Some of the most successful refactors in 2024-26 have been microkernel systems collapsing back into modular monoliths. The plug-in machinery wasn't earning its keep; the team admitted it and simplified.

@feynman

The same lesson as feature creep. Each feature was reasonable; the cumulative product is bloated. If the kernel keeps growing, the architecture isn't keeping pace with what the system actually needs to be — admit it and pick a different shape.
