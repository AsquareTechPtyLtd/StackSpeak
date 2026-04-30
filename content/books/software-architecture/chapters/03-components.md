@chapter
id: sa-ch03-components
order: 3
title: Components
summary: The granularity question — what's a component, where do you split, and how do you decide whether a feature lives here or in the next module over.

@card
id: sa-ch03-c001
order: 1
title: Components Are the Architect's Building Block
teaser: A component is the smallest unit the architect actually designs at. Below it, you're writing code; above it, you're drawing diagrams. Picking the right size is most of the work.

@explanation

Architects don't design at the function level — that's implementation. They don't design at the system level alone — that's vapor. They design at the *component* level: a packaged set of behaviours with a clear interface, deployable or replaceable, owned by a team.

Components in the wild look like:

- A package or namespace inside a monolith.
- A library that other code links against.
- A microservice with an API contract.
- A serverless function or job.
- A container image, a database, a queue.

The unit shifts; the principle doesn't. A component is the chunk you can replace with another implementation without rewriting the whole system.

> [!info] The component is the architect's atomic unit. Above it: relationships and styles. Below it: code and developers' decisions. Most architecture work is figuring out where the component boundaries should sit.

@feynman

A component is the LEGO brick. You're not designing the studs; you're designing how the bricks click together. Get the brick size wrong and the whole model fights you.

@card
id: sa-ch03-c002
order: 2
title: Granularity — Big or Small?
teaser: Coarse-grained components mean fewer pieces, less coordination, less network traffic. Fine-grained components mean independent deploys, focused teams, but more wiring. The choice is per-system, not universal.

@explanation

The granularity tradeoff sits at the heart of every architecture decision. Too coarse and you get a monolith that's hard to change; too fine and you get a distributed system that's hard to operate.

Coarse-grained components win on:

- **Simplicity** — fewer moving parts, fewer integration points.
- **Performance** — less network overhead, less serialization.
- **Transactional integrity** — easier to keep consistency inside one component.
- **Cognitive load** — engineers can hold the whole component in their head.

Fine-grained components win on:

- **Independent deployment** — change one without releasing the others.
- **Team autonomy** — small teams own small components.
- **Polyglot freedom** — different components can use different stacks.
- **Selective scaling** — scale only the bits that need it.

Most teams pick a granularity once and find out two years later it was the wrong one — usually too fine. The honest answer is to start coarse, only split when there's clear pressure to.

> [!warning] "We'll just split it into microservices later if needed" is harder than it sounds. The hardest part isn't the split — it's that the team has to learn distributed systems mid-migration, while keeping everything working.

@feynman

Same instinct as choosing apartment vs house vs commune. More walls mean more privacy and independence; they also mean more doorways to maintain. The right number depends on who's living there.

@card
id: sa-ch03-c003
order: 3
title: Identifying Components — Top-Down
teaser: Start from the user-facing actions. Trace each one to the data it touches. The clusters that emerge are candidate components.

@explanation

The top-down approach to identifying components:

1. **Enumerate the use cases** — what users want to do with the system. "Place an order." "View a report." "Cancel a subscription."
2. **Trace the data each use case touches** — which records get read, which get written, which external systems get called.
3. **Cluster by overlap** — use cases that touch the same data live in the same component.
4. **Name the clusters** — billing, inventory, identity, reporting. The names usually fall out.

What you get is a draft component map driven by user-visible behaviour rather than implementation accident. Useful when designing greenfield, refactoring a monolith, or arguing about which team owns what.

The technique is rough and fast. The clusters won't be perfect; you'll move things between components later. But the first pass produces a defensible structure rooted in actual use, not in convenience.

> [!info] The cluster overlap is what tells you whether a candidate component is well-defined. If half the use cases reach into it, the component is too big. If only one does, it might not need to be its own component.

@feynman

The same instinct as drawing the rooms in a house plan from how the family lives. You watch where everyone spends time; you put walls where the activities don't cross. Use cases are the activities; components are the rooms.

@card
id: sa-ch03-c004
order: 4
title: Identifying Components — Workflow
teaser: For systems built around processes, components emerge from the steps. Each step is a candidate; consecutive steps that share data are candidate clusters.

@explanation

Workflow-based component identification works better for systems whose value is the process, not the data: order fulfilment, content publishing, lab automation, deployment pipelines.

The method:

1. **Map the workflow as steps** — accept order → validate payment → reserve inventory → ship → notify.
2. **Each step becomes a candidate component** — owns the data and behaviour for that stage.
3. **Identify hand-offs** — what crosses each boundary; that's your interface contract.
4. **Group steps that share state and team** — adjacent steps with the same owner usually become one component.

This produces a different shape from the data-centric approach. Workflow components are aligned with process; data-centric components are aligned with entity. Same system, different cuts — and the right cut depends on what changes most.

If your business logic changes (new step in the workflow, new approval, new branch), workflow components hold up. If your data shape changes (new fields, new entities, new relationships), data-centric components hold up. Most teams pick the cut that matches their change pattern.

> [!tip] When in doubt, draw both — workflow cuts and data cuts — for the same system. The argument over which is better is itself the design conversation.

@feynman

The factory's assembly line versus the warehouse's inventory zones. Same building, two ways to think about the components inside. Both useful for different kinds of changes.

@card
id: sa-ch03-c005
order: 5
title: Component Cohesion
teaser: A component should change for one reason, not five. The single-responsibility principle scales up — a component with too many responsibilities will be the place every team has to coordinate.

@explanation

Component-level cohesion is the same idea as module-level cohesion, applied one tier up. A high-cohesion component has all its parts working toward one purpose. A low-cohesion component is a junk drawer with a name.

Signs of low cohesion at the component level:

- The component changes on every release because three different teams ship into it.
- You can't summarise what the component does in one sentence without "and."
- Different parts of the component have different release cadences, scaling profiles, or owners.
- The component's tests fall into clusters that don't share state.

The fix is splitting. Identify the natural seams; pull each into its own component. Costs you a deployable unit, an interface, some operational overhead. Buys you focus, independent change, smaller blast radius.

The reverse failure also exists: components so cohesive they become trivial — a thousand microservices, each owning one method. The right cohesion is at the level of a *capability* the business cares about, not at the level of an individual operation.

> [!info] The "capability" framing is the bridge between business and architecture. Each component owns one capability; the capability has a name your product manager would recognise.

@feynman

Same as well-named functions. A function called "doStuff" is low-cohesion in miniature; a component called "platform" is the same problem at scale. Name it precisely or admit it's a junk drawer.

@card
id: sa-ch03-c006
order: 6
title: Component Coupling
teaser: Components should depend on each other only through stable contracts. The number of dependencies, and the kind, determines whether you can change anything without coordinating with five teams.

@explanation

Component coupling at the architecture level shows up through the interfaces components expose to each other:

- **Synchronous API calls** — caller depends on callee being up. Tight in availability terms.
- **Async messages** — caller publishes, callee consumes. Loose in availability; tight in message contract.
- **Shared database** — both read/write the same tables. Worst form; couples deployment, schema, and behaviour.
- **Shared library** — both link the same code. Couples versioning.
- **Shared file format / protocol** — looser; both must agree on the format.

The asymmetry matters. A component with fan-out 1 (depends on one other component) is loosely coupled. A component with fan-out 20 is the integration hub of the system, and changes to it ripple everywhere.

Fitness functions for component coupling:

- Maximum number of synchronous dependencies per component.
- Forbidden coupling pairs (no service may depend on the database service directly).
- Required coupling shapes (cross-team coupling must be async).

> [!warning] "Just share the database" is the most common shortcut and the hardest one to undo. The schema becomes a contract you can't change because nobody knows who reads what column.

@feynman

The handshake versus the hug. Components can shake hands through APIs and stay independent; they hug each other through shared databases and become inseparable.

@card
id: sa-ch03-c007
order: 7
title: Domain-to-Architecture Quanta
teaser: An architecture quantum is a deployable unit with high functional cohesion and synchronous coupling within. Whether your system is one quantum or many is one of the most consequential structural choices.

@explanation

Architecture quantum (a coined term but a useful one) is the chunk of your architecture that ships, scales, and fails together. The system is an architecture monolith if everything is in one quantum; it's a microservices system if each component is its own quantum.

The defining properties:

- **Independent deployability** — can be released without releasing anything else.
- **Synchronous functional cohesion** — all the parts inside need to be available together for the quantum to work.
- **Static and dynamic coupling** — both compile-time dependencies and runtime dependencies stay inside.

The number of quanta in your system is the most consequential structural decision you'll make:

- **One quantum (monolith / modular monolith)** — simple ops, simple consistency, hard to scale teams.
- **Few quanta (service-based, modular monolith with extracted services)** — moderate ops, mostly-simple consistency, modest team independence.
- **Many quanta (microservices)** — complex ops, complex consistency, full team independence.

Most teams underestimate the operational cost of more quanta. The architectural benefit (independent deploy) is real; the operational cost (more pipelines, more monitoring, more failure modes) is also real and rarely the topic of the decision.

> [!info] The quantum count is one of the few decisions that's genuinely irreversible at scale. Going from many to one is a multi-quarter rewrite. Going from one to many is the same. Pick deliberately.

@feynman

Same as picking how many separate buildings your campus has. One big building is easy to manage but hard to expand. Many small buildings let each tenant work independently but the campus needs roads, lighting, and a security team.

@card
id: sa-ch03-c008
order: 8
title: Component Reuse — Less Than You Think
teaser: "We'll reuse this component across products" is the architectural promise least often kept. Reuse has costs; pretending it's free is how you get over-engineered components nobody actually shares.

@explanation

The seduction of component reuse is that one team writes a component, two teams use it, total work goes down. The reality is messier:

- The first team writes the component for their use case.
- The second team needs slight variation; the component grows configuration options.
- The third team needs another variation; configuration becomes a mini-language.
- Now nobody understands the component, every change requires aligning three teams, and any new use case requires the component-owners' attention.

The pattern repeats so consistently that it's worth defaulting to: **don't extract for reuse until you have at least three real consumers.** Two consumers is coincidence; three is a signal.

When reuse does work:

- **Stable, narrow contract** — the component does one thing, will do that one thing forever.
- **Owner with bandwidth** — the team owning the shared component has time to support consumers.
- **Versioning discipline** — consumers can stay on old versions; new versions don't break old.
- **Real shared need** — not "we might use it later" but "we are using it now in three places."

Otherwise, two slightly-different copies are cheaper than one shared version with parameters.

> [!warning] The DRY principle is right at the function level and wrong at the component level. Two services repeating themselves is fine; two services sharing a brittle library both have to coordinate on is not.

@feynman

Same lesson as a shared kitchen in an office. In theory it saves space; in practice everyone fights about the dishes and someone ends up taking it over. Sharing has overhead; pricing it correctly avoids fake savings.

@card
id: sa-ch03-c009
order: 9
title: Component-Level Tests
teaser: Most testing happens at the unit level. Component tests — exercising the public interface of a whole component — are where most architectural-violation bugs actually surface.

@explanation

The testing pyramid most teams build:

- Tons of unit tests at the bottom.
- Some integration tests in the middle.
- A few end-to-end tests at the top.

What's missing in many real codebases: tests at the *component* level. A component test exercises the public interface of one component, with its real internal code, but with its dependencies stubbed at the boundary.

Why this layer matters:

- **Unit tests** verify a single function. They miss integration bugs inside the component.
- **End-to-end tests** verify the whole system. Slow, flaky, hard to debug when they fail.
- **Component tests** verify the component's contract. Fast enough to run on every commit; specific enough to point at which component broke.

The component test is also where architectural rules show up: "this component handles its own retries" is a contract; the test asserts it. "This component handles requests in any order" is a contract; the test asserts it. Without component tests, contracts are wishful prose in the README.

> [!tip] The right ratio is roughly 60% unit, 30% component, 10% end-to-end. Most codebases I see are 90% unit, 0% component, 10% end-to-end — and they pay for the missing layer in production.

@feynman

The same instinct as integration testing in any system. Each part works alone (unit); the parts work together (integration); the whole works (end-to-end). Component is the middle layer doing the heavy lifting.

@card
id: sa-ch03-c010
order: 10
title: Picking Component Boundaries
teaser: There's no formula. The boundaries that work are the ones that match how the system actually changes — and that's something you only learn by living with the architecture.

@explanation

A short heuristic for component boundaries:

1. **Start with use cases.** Cluster by data overlap. This is the first cut.
2. **Check against teams.** If a candidate component crosses team lines, you'll get coordination cost; consider whether the component or the team should change.
3. **Check against change patterns.** Components should change for one reason. If three different change types all hit one component, it's too coarse.
4. **Check against scale shape.** If parts of the candidate component need different scaling, that's a hint to split.
5. **Check against blast radius.** Components are also fault-isolation units. If a failure here would take down something unrelated, that's a hint to split.

Then live with it. Six months in, audit:

- Which components changed most? (high churn → too cohesive or too coupled)
- Which components changed least? (stable → good)
- Which boundaries had the most cross-component PRs? (hint that the boundary is in the wrong place)

Adjust. Architecture is continuous; the first set of components isn't the last.

> [!info] No team gets the boundaries right on day one. The teams that succeed are the ones who treat boundaries as adjustable — and adjust them on a quarter-by-quarter cadence based on how the system is actually being used.

@feynman

The same instinct as drawing org charts. The lines on the diagram are the team's first guess at how work flows; the actual flow either matches or it doesn't, and the chart updates accordingly. Components are no different.
