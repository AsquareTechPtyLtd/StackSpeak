@chapter
id: sa-ch01-thinking-in-architecture
order: 1
title: Thinking in Architecture
summary: What architecture actually is, what an architect actually does, and the mindset that separates structural decisions from coding ones.

@card
id: sa-ch01-c001
order: 1
title: Architecture Is Decisions That Are Hard To Reverse
teaser: Code can be rewritten in an afternoon. Architecture is the set of decisions you can't easily change once you've built the rest of the system on top of them.

@explanation

Architecture isn't a category of *task*; it's a category of *decision*. Some choices in a system are easy to undo — rename a function, swap a sorting algorithm, refactor a class. Others — the database engine, the deployment topology, whether services talk synchronously or async — calcify the moment other code depends on them.

A useful definition: architecture is the set of decisions that, in retrospect, you'd really like to have gotten right. Everything else is implementation.

What lands in this bucket:

- **Boundaries** — what's a module, a service, a deployable unit.
- **Style** — how those boundaries communicate (synchronous, async, shared DB, queues).
- **Characteristics** — what the system optimises for (latency, throughput, availability, cost).
- **Constraints that shape everything else** — language stack, runtime, data store, infrastructure tier.

> [!info] If you can change a decision without coordinating across teams or rewriting at scale, it's not architectural. The reversibility test is the cleanest filter for what deserves architect-level attention.

@feynman

Architecture is the load-bearing wall; code is the wallpaper. Both matter; only one of them is annoying to move after the building's done.

@card
id: sa-ch01-c002
order: 2
title: The Job Is Tradeoff Selection
teaser: The architect's deliverable isn't a "best" answer — it's the documented tradeoff that this team is prepared to live with. Every architecture optimises for some -ility at the cost of others.

@explanation

There are no perfect architectures. Optimising for low latency tends to push you toward fewer hops, which costs flexibility. Optimising for flexibility tends to push toward more services, which costs latency. Optimising for cost tends to push toward simplicity, which costs scalability. The list goes on.

The architect's job is to make the tradeoff explicit and the team's choice deliberate:

1. **Surface the dimensions** the system is actually being optimised for.
2. **Document what's being traded away** to get them.
3. **Get team agreement** on the priority order.
4. **Revisit when conditions change** — what was a reasonable tradeoff at year one rarely holds at year five.

The biggest mistake young architects make is hunting for the right answer. There isn't one — there's only the answer best matched to the constraints you've been given (and the constraints you've inherited).

> [!tip] When two engineers disagree about the architecture, they're usually disagreeing about which characteristics matter most. Surface the priority debate, not the solution debate.

@feynman

Same lesson as picking a database. The "best" database depends on what you're optimising for. The architect's job is to know what they're optimising for — and to write it down so the next person doesn't have to guess.

@card
id: sa-ch01-c003
order: 3
title: Structure, Characteristics, Decisions, Principles
teaser: Architecture has four layers worth distinguishing — what it's made of, what it's good at, what's been decided, and how to decide the rest. Conflating them muddies every conversation.

@explanation

A clean way to organise the architect's vocabulary:

- **Structure** — the shapes. Layered, microservices, event-driven. The visible topology of the system.
- **Characteristics** — the qualities. Throughput, availability, security, observability, evolvability. What the structure is supposed to enable.
- **Decisions** — the explicit choices. "We use Postgres, not MySQL." "Cross-team APIs are HTTPS+JSON." Recorded in ADRs.
- **Principles** — the meta-rules. "Default to async for cross-team boundaries." "No service owns more than one bounded context." Guidelines for the decisions still to come.

In conversation these get conflated. Someone says "our architecture is microservices" (structure), but the real claim might be about availability (characteristic), about a past decision to split a monolith, or about a principle that new features land as services. Untangling which layer the speaker means is half the work in any architecture review.

> [!info] Architecture decision records (ADRs) — short, dated, append-only — are the standard documentation pattern. The book covers them in a later chapter; the habit is worth starting now.

@feynman

Same instinct as the difference between a car's chassis, its handling, the engineer's notes on why they picked rear-wheel drive, and the principles behind the brand's design language. All four exist; talking about one when you mean another causes long meetings.

@card
id: sa-ch01-c004
order: 4
title: Architect vs Senior Engineer
teaser: The skills overlap, but the shape of the job doesn't. An architect is paid to think across systems and over years; a senior engineer is paid to ship features inside one. Both are necessary; neither is a promotion path for the other by default.

@explanation

Senior engineers are deep specialists. They know one stack, one codebase, one product domain at a level nobody else does. Their leverage is in the code they write and the patterns they teach the team.

Architects are generalists with depth. They've worked across stacks, products, and team shapes. Their leverage is in the decisions they make and the decisions they unblock for others.

The skills the role actually requires:

- **Pattern recognition across systems** — having seen this kind of problem solved (and failed) in multiple shapes.
- **Stakeholder communication** — translating between engineering, product, ops, and business.
- **Comfort with incomplete information** — making decisions that will hold up against unknown future requirements.
- **Willingness to be wrong publicly** — and update the record when reality disagrees.

Architects who can't code are dangerous; engineers who can't communicate aren't architects. The role lives at the intersection — and most of the friction in software organisations is teams that have one without the other.

> [!warning] "Architect who doesn't code" and "architect who codes too much" are both common failure modes. The first loses touch with implementation reality; the second never leaves the trees long enough to see the forest.

@feynman

The senior engineer is the lead surgeon; the architect is the chief medical officer. Different roles, different time horizons, both clinical, both essential.

@card
id: sa-ch01-c005
order: 5
title: Conway's Law Is Not Optional
teaser: Your system architecture will mirror your team structure. You can fight it; you will lose. The fix isn't a better architecture — it's a better team shape that produces it.

@explanation

Mel Conway's 1968 observation: "Organisations which design systems are constrained to produce designs which are copies of the communication structures of these organisations." Every team learns this the hard way.

If three teams build a service together, the service will have three internal seams. If your billing team and your account team don't talk, the integration between billing and account will be painful. If you reorganise the team, the architecture will drift to match — whether you wanted it to or not.

The implication for architects: team shape is part of the design space. You don't get a clean architecture from a tangled team. The "inverse Conway maneuver" — designing the team to match the architecture you want — is one of the more powerful tools in the role.

> [!tip] When an architecture diagram has weird seams that nobody can explain, look at the org chart. Usually you'll find the team boundary that produced them. Either move the team or accept the seam.

@feynman

Same instinct as why a band's sound matches the personalities of the members. The shape of the artifact echoes the shape of the people producing it. Software is no exception.

@card
id: sa-ch01-c006
order: 6
title: First Law — Everything Is a Tradeoff
teaser: There are no architectural silver bullets. Every benefit you grant comes from somewhere — usually a characteristic you've quietly traded away.

@explanation

The first law in this book is the most important: every architecture decision is a tradeoff. The skill is in knowing which.

A short tour of common tradeoffs:

- **Microservices** — you trade simplicity, latency, and operational overhead for evolvability and team independence.
- **Event-driven** — you trade immediate consistency and easy debugging for decoupling and async scale.
- **Caching** — you trade memory, complexity, and staleness risk for latency.
- **Eventual consistency** — you trade developer ergonomics and edge-case correctness for availability under partition.
- **Synchronous APIs** — you trade availability under failure for simplicity and immediate consistency.

The architects who get into trouble are the ones who hear about a benefit and don't ask "at the cost of what?" The ones who succeed treat that question as reflexive.

> [!info] When a vendor or a blog post pitches an architecture as "scalable, flexible, and reliable," they're describing benefits without naming the costs. Find the costs before adopting; they're always there.

@feynman

The economist's law applied to systems. There is no free lunch. Every architectural lunch you've been told is free has someone else paying for it — usually you, six months later.

@card
id: sa-ch01-c007
order: 7
title: Second Law — Why Beats How
teaser: A well-documented "why" survives a decade of context loss. A clever "how" without a why becomes the thing junior engineers refactor in five years because they can't tell why it was done that way.

@explanation

The why is always more valuable than the how because:

- The how is recoverable from the code.
- The why is not, unless someone wrote it down.

When a future engineer encounters a pattern they don't understand, they have two options: assume there was a reason and leave it, or assume there wasn't and refactor. Without documented why, they choose based on temperament and you get inconsistent decisions.

The why is also what protects an architecture from drift. New feature comes in; someone proposes a shortcut that violates a pattern. If the original constraint is documented, the team can ask "does the constraint still hold?" If it isn't, the team has a fight that's about who's loudest.

What "why" looks like in practice:

- **ADRs** — Architecture Decision Records. Date, context, decision, consequences. One page each.
- **Code comments at the load-bearing places** — "This sleep is here because of [bug X]; remove only after Y is migrated."
- **Commit messages that explain motivation** — the diff shows what changed; the message should say why.
- **Public design docs** — searchable, dated, owned.

> [!warning] Tribal knowledge is technical debt with a one-person dependency. The senior engineer who knows why everything was built is a single point of failure dressed up as a hero.

@feynman

The same instinct as good code comments. The "what" is in the code itself. The "why" needs a comment because it's not in the code, and it's the part future-you will want most.

@card
id: sa-ch01-c008
order: 8
title: Third Law — All Architectures Are Continuous
teaser: There is no "the architecture is now done." Every change to the system is a small architecture decision. The architect's job is ongoing curation, not a one-time blueprint.

@explanation

The legacy view of architecture: a senior engineer draws diagrams, hands them to the team, leaves. The team builds against the diagrams. The architecture is "done."

The reality: every PR is a small architecture decision. Most of them respect the existing patterns. Some quietly drift. Over months and years, drift compounds into "the architecture doesn't match the diagrams anymore." The team didn't decide to drift; the diagrams just stopped reflecting reality.

The continuous view changes the architect's role:

- **Curation** — periodically auditing whether the system still reflects the documented decisions.
- **Fitness functions** — automated checks that catch drift in CI rather than at the next architecture review.
- **Lightweight gating** — review for the changes that *might* be architectural, leaving the rest to the team.
- **Documentation that updates** — diagrams and ADRs that move when the system moves.

The architect who treats their job as a one-time deliverable is documenting an architecture that no longer exists.

> [!info] Fitness functions — automated tests that assert architectural properties (no service depends on more than three others, no module imports the database module directly) — are the hands-on tool for keeping a continuous architecture honest.

@feynman

Garden-tending, not building. Buildings are finished and stable; gardens shift with the seasons and need maintenance, or they revert to weeds. Architectures are gardens.

@card
id: sa-ch01-c009
order: 9
title: AI in the Architect's Toolkit
teaser: In 2026, models help with the boring half of architecture work — analysis, drafting, evaluation. They're useful collaborators, not replacements. Knowing which half is which matters.

@explanation

A useful update to this book's framing: AI tools have changed which parts of the architect's day still take real time.

Where AI is now genuinely useful:

- **Drafting ADRs and design docs** — give it the context and the decision; it produces a passable first draft you edit.
- **Summarising codebases and dependencies** — Claude Code, Cursor, and similar can answer "what depends on this module" faster than grep + your brain.
- **Evaluating tradeoffs against past systems** — "we built this same shape three years ago and it failed because of X" — the model surfaces patterns from documentation if you've stored them.
- **Translating between stakeholder vocabularies** — the model rephrases an architectural concern in product or business terms.

Where AI is not (yet) replacing the architect:

- **Knowing what your team can actually execute** — taste, lived experience.
- **Reading the room in a stakeholder meeting** — politics, constraints unspoken.
- **Deciding what tradeoff is acceptable** — value judgement.
- **Owning the decision** — accountability stays with humans.

> [!tip] Treat AI like a junior architect who's read every book but never shipped a system. Useful for drafts and analysis; never the final say.

@feynman

The IDE didn't replace the engineer; it changed which parts of the engineer's day were the bottleneck. AI is doing the same thing one tier up — for the architect, not the developer.

@card
id: sa-ch01-c010
order: 10
title: The Mindset Shift
teaser: Engineers ship features. Architects ship decisions. The transition is mostly about getting comfortable owning ambiguity instead of resolving it.

@explanation

The hardest mindset shift moving into architecture isn't technical — it's epistemic.

Engineers operate with feedback loops measured in hours: write code, run tests, ship feature, see metrics. The reward signal is fast and clear.

Architects operate with feedback loops measured in months and years: document decision, system runs against it, team grows or shrinks, requirements shift, the decision either holds up or breaks. The signal is slow and noisy. By the time you know whether you were right, you've made fifty more decisions on top.

The skills that develop in the role:

- **Comfort with incomplete information** — you'll never have the data you wish you had.
- **Comfort with being publicly wrong** — and updating the record when you are.
- **Long-time-horizon thinking** — what does this look like at 5× the team size, 10× the load, year three?
- **Patience with conversation** — most architecture is alignment, not coding.

The architects who burn out are the ones who can't tolerate the loop length. The ones who succeed treat the slowness as a feature: it forces clarity in writing, since that's how the decision survives the time gap.

> [!info] If you find yourself missing the dopamine of shipping features, consider whether you actually want the architect role — or whether you'd be happier as a senior engineer who occasionally does architecture work. The roles are different jobs.

@feynman

The shift from playing chess to coaching chess. You stop scoring points yourself; your job is to set up the people who do. Some people love it; others miss the board.
