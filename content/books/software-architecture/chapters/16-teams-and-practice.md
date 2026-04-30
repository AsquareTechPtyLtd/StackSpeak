@chapter
id: sa-ch16-teams-and-practice
order: 16
title: Teams and Practice
summary: The soft side of the role. Working with teams, negotiating, leading without authority, and the laws of architecture revisited as practice.

@card
id: sa-ch16-c001
order: 1
title: The Architect Doesn't Have a Team
teaser: Most architects influence many teams without managing any. The skill is leadership without authority — getting alignment, surfacing trade-offs, owning decisions while others own execution.

@explanation

Architects rarely have direct reports. They influence engineering teams across an organisation. The work happens via:

- **Conversations** — 1:1s with engineering leads, design discussions, roadmap reviews.
- **Written artifacts** — ADRs, design docs, diagrams. The asynchronous channel.
- **Reviews** — design reviews, RFC processes, architecture reviews. The structured intervention point.
- **Office hours** — open time for engineers to bring questions. Often the most useful single hour of the architect's week.
- **Pairing** — sitting with a team for a sprint or two. Highest bandwidth; most expensive of the architect's time.

The skills required are different from those of an engineer or manager:

- **Influence without authority** — you can't tell teams what to do; you have to convince them.
- **Reading the room** — different teams need different framings of the same idea.
- **Patience** — alignment takes longer than coding.
- **Strategic communication** — knowing when to push, when to compromise, when to escalate.

> [!info] The architects who succeed have written communication and verbal communication both at a high level. The role is mostly communication; if either channel is weak, the work suffers.

@feynman

Same role as a tech lead at scale. The tech lead doesn't manage the team but sets technical direction. The architect does the same thing across many teams — without the proximity that makes a tech lead effective.

@card
id: sa-ch16-c002
order: 2
title: Effective Teams Look Different
teaser: Some teams own one service; some own a domain across many services. Some are 4 engineers; some are 12. The architect's job is matching team shape to architecture, then living with the result.

@explanation

Team topologies that work in 2026:

- **Stream-aligned teams** (Skelton & Pais, *Team Topologies*) — own a value stream end-to-end. The default productive shape. 4-9 engineers; cross-functional.
- **Platform teams** — build internal tools that other teams consume. Customers are other engineers; product mindset matters.
- **Enabling teams** — temporary; help stream teams adopt new practices or tech. Disband when the help isn't needed.
- **Complicated subsystem teams** — own a piece of the system that's deep enough to require specialists (ML platforms, data infrastructure, embedded systems).

Team patterns to avoid:

- **Component teams** — own a horizontal layer (UI team, API team, DB team). Every feature requires coordinating across teams; velocity suffers.
- **Outsourced/offshore as a separate team** — communication overhead dominates; ownership is unclear.
- **Centralised architecture team** — becomes a constraint on every team's velocity instead of an enabler.

The architect's role in team shape:

- Match the team structure to the architecture (and vice versa). Conway's Law in both directions.
- Surface team-shape pain in retrospectives and re-orgs.
- Push for stream-aligned teams as the default; reach for other shapes only when warranted.

> [!info] *Team Topologies* by Matthew Skelton and Manuel Pais is the canonical reference for this. The patterns it describes have largely held up; the book is still the right starting point.

@feynman

Same instinct as picking the right corporate structure for the work. A retail business needs store managers; a research lab needs principal investigators. The work shapes the team, and forcing a mismatch hurts both.

@card
id: sa-ch16-c003
order: 3
title: Negotiation as Daily Work
teaser: Architects negotiate constantly — between teams competing for resources, between technical needs and product timelines, between ideal designs and what the team can build. The skill is getting durable agreement, not winning arguments.

@explanation

Architecture negotiation looks like:

- "Team A wants to ship feature X next quarter; team B owns the service that needs to change. How do we sequence this without blocking either?"
- "Engineering wants to refactor the database layer. Product wants the next feature shipped. The architect navigates the trade-off."
- "Two teams disagree about which one owns a piece of capability. The architect mediates; the resolution sticks."

Useful negotiation patterns:

- **Surface the underlying interests, not just the positions.** "We want microservices" is a position; the interest is "we want to ship independently." The interest opens up alternatives.
- **Find shared criteria.** What does both sides agree on? Use that as the basis.
- **Generate options before deciding.** The first proposal is rarely the best. Brainstorm; then evaluate.
- **Document the agreement.** Verbal agreements decay. The agreement that survives is the one in writing.
- **Escalate carefully.** Some disagreements need a manager's call; most don't. Escalating too eagerly makes you look unable to resolve; escalating too late lets disagreements fester.

The architects who succeed treat negotiation as a craft. The ones who don't end up with decisions that look like wins on paper but unwind over the next quarter as teams quietly route around them.

> [!tip] Read *Getting to Yes* (Fisher and Ury). The framing of interests vs positions translates directly to architecture negotiations. It's an old book; the lessons haven't aged.

@feynman

The same skill as any negotiation. The architect who insists on being right wins arguments and loses influence. The one who finds agreements that work for both sides keeps the relationship that lets them be effective tomorrow.

@card
id: sa-ch16-c004
order: 4
title: Mentorship vs Direction
teaser: Tell an engineer the answer and they ship one feature; teach them the framework and they make ten architecturally-aligned decisions. Mentorship scales the architect's influence.

@explanation

The architect can solve problems directly — answer the question, write the ADR, design the system. Or they can teach engineers to solve the same problem themselves the next time.

Direct solving:

- Fast for one decision.
- The architect's bandwidth becomes the bottleneck.
- Engineers don't develop architectural judgement.
- Decisions are centralised; the architect is consulted on everything.

Mentoring:

- Slower for one decision.
- Engineers develop their own architectural judgement.
- Decisions get made closer to the work, faster.
- The architect is consulted on the genuinely hard decisions, not the routine ones.

The investment of time in mentoring pays back over months. The team that has 10 engineers thinking architecturally outperforms the team that has 1 architect plus 10 implementers.

What mentoring looks like in practice:

- Pairing on a design problem; talking through the trade-offs out loud.
- Reviewing an ADR together; explaining why one alternative is better.
- Recommending reading and discussing it.
- Inviting engineers to architecture reviews; explaining the framework as it's applied.
- Noticing engineers ready to take on more architectural work and creating opportunities.

> [!info] The most effective architects have a track record of engineers who became architects themselves. The lineage matters; it's evidence of teaching, not just doing.

@feynman

Same instinct as any senior role. The senior who solves every problem becomes irreplaceable; the senior who teaches becomes a leader. The team's capacity grows when the senior teaches.

@card
id: sa-ch16-c005
order: 5
title: Saying No
teaser: Architects say no a lot — to features that break the architecture, to shortcuts that create debt, to vendor solutions that don't fit. The skill is saying no while keeping the relationship.

@explanation

Saying no is part of the role. Done badly, the architect becomes "the person who blocks things." Done well, the architect becomes "the person whose pushback I trust."

The patterns that keep the relationship:

- **Lead with the why.** Not "no, we can't do that." But "we can't do that because of X. What's the actual goal? Maybe there's another way."
- **Offer alternatives.** A flat no is a wall; a no-but suggests a path.
- **Acknowledge the trade-off.** "I see why this is appealing; here's what it would cost us long-term."
- **Pick battles.** Not every shortcut is worth a fight. Save the no for the ones that actually matter.
- **Be willing to be overruled.** Sometimes the right call is "I disagree, but I understand why we're doing it this way." Disagreement on record; commitment in execution.

The patterns that destroy the relationship:

- **Procedural no.** "We have a process; we have to follow it." Without context, this reads as bureaucracy.
- **Aesthetic no.** "I don't like this." Without rationale, it's preference, not architecture.
- **Late no.** Surface objections during the proposal, not after the team has built half of it.
- **Personal no.** "I don't trust this engineer." Even if true, it's not architecturally productive.

> [!info] The architect's reputation is built on the noes they don't say as much as the noes they do. The team learns over time which fights you pick — and trusts your judgement on the ones you do pick.

@feynman

Same as any veto power. Use it sparingly and people respect it. Use it constantly and people route around you. The architect who's perceived as a blocker stops being included in early conversations — and then stops being effective.

@card
id: sa-ch16-c006
order: 6
title: Working With Product
teaser: Product wants features shipped; the architect cares about long-term shape. The healthy partnership: product owns what gets built; architecture owns how. Tension is normal; antagonism isn't.

@explanation

The product-architecture relationship is one of the most important in the role:

- **Product** owns priorities, the customer view, the backlog.
- **Architecture** owns technical structure, long-term shape, system characteristics.
- **Both** are accountable for shipping value.

The healthy version:

- Product surfaces what the customer needs; architecture surfaces what the system can support.
- Trade-offs are explicit. "We can ship feature X this quarter; it'll cost us flexibility on Y for the next two years."
- Roadmap discussions include architectural items (refactoring, observability, infrastructure) alongside features.
- The architect contributes to product decisions by surfacing technical trade-offs in product terms.

The unhealthy versions:

- Product treats architecture as a brake. Every feature is a fight.
- Architecture treats product as the enemy. Every request is treated with suspicion.
- Architecture builds in secret without product alignment. Maintenance work appears mysteriously and product feels surprised.
- Product makes technical decisions without consulting architecture. The architect is informed after the fact and the system suffers.

The fix is a regular forum where both perspectives meet. Quarterly planning, monthly architecture reviews, weekly check-ins — pick a cadence; commit to it.

> [!warning] If your architect and product manager rarely talk, the relationship has failed silently. Both groups think the other is "just doing their job badly"; the system pays for the breakdown.

@feynman

Same as the dynamic between sales and engineering. Both pull in different directions; both are necessary. The healthy company has them in regular conversation; the dysfunctional company has them avoiding each other.

@card
id: sa-ch16-c007
order: 7
title: Working With Operations
teaser: Architecture decisions become operational realities. The team that has to run the architecture should have input into it — early, often, and with veto power on operational concerns.

@explanation

The classic dysfunction: architects design; ops runs; complaints flow upstream after the fact. The architecture works on paper and burns out the ops team.

The healthy alternative: ops is part of the architecture process from day one.

What that looks like:

- **Ops at design reviews.** Not as observers; as voting participants on operational concerns.
- **Operability as a first-class characteristic.** Treated alongside scalability, availability, etc.
- **Runbooks and on-call models** designed with the architecture, not after.
- **Capacity planning** done collaboratively. The architect describes the load profile; ops describes what the operational cost will be.
- **Incident response feedback** loops back into architecture. The system that pages the on-call most often is the system that gets architectural attention.

The DevOps and platform engineering movements of the 2010s and 2020s were largely a response to this dysfunction. The result: more teams have closer architecture/ops relationships than they did 15 years ago. Fewer "throw it over the wall" failures.

> [!info] In well-functioning teams, the on-call rotation includes architects (or at least very senior engineers). Carrying the pager grounds you in operational reality faster than any meeting.

@feynman

The same lesson as designing a product without ever using it. The user always finds the things the designer missed. Architecture without operational input is the same shape — and the surprises always cost more than including ops would have cost.

@card
id: sa-ch16-c008
order: 8
title: When the Architecture Disagrees with the Org
teaser: Sometimes the architecture and the org structure pull against each other. Conway's Law makes one of them win. The architect either changes the architecture, changes the org, or accepts the resulting friction.

@explanation

Three resolutions when architecture and team shape conflict:

**1. Change the architecture.** If three teams own one service, the service should probably be three. Restructure to match teams.

**2. Change the org.** If one team owns three services that should be one, the team is probably going to consolidate them anyway. Reorg the team to match what the system needs.

**3. Accept the friction.** Sometimes neither change is feasible; the architecture and org will fight; the team accepts ongoing coordination cost.

Which resolution fits depends on:

- **Reversibility of each change.** Reorgs are slow; some architectural changes are slower.
- **Strategic timing.** Don't reorg during a critical product launch.
- **Political cost.** Some reorgs are easy; others require executive sponsorship.
- **Team buy-in.** A change forced from above without team agreement creates resentment.

The architect rarely has authority to reorg. They have influence — surfacing the conflict, articulating the cost, suggesting alternatives. The decision goes to leadership.

> [!info] The "inverse Conway maneuver" — designing the team structure to produce the architecture you want — is one of the more powerful but politically tricky tools in the role. It works when leadership is engaged; it fails when leadership doesn't see the connection.

@feynman

The same realisation as in any organisation. The org chart shapes the work. If the work needs a different shape, you change the chart, change the work, or live with the mismatch. There is no fourth option.

@card
id: sa-ch16-c009
order: 9
title: The Laws Revisited
teaser: Three laws to live by — everything is a tradeoff, why beats how, all architectures are continuous. They aren't slogans; they're how the role is actually practiced day-to-day.

@explanation

The three laws first introduced in chapter 1, restated as practice:

**Everything is a tradeoff.** Every decision has costs. Every benefit comes from somewhere. The architect's job is making the trades explicit — naming what's gained and what's lost — so the team can decide deliberately.

The discipline: when someone proposes a benefit, ask "at the cost of what?" If they can't answer, the proposal is incomplete. When you propose a benefit, answer the question yourself before someone else has to.

**Why beats how.** The how is recoverable from the code. The why is not, unless someone wrote it down. The architect's most durable contribution is the documented rationale — the ADR that survives a decade of context loss.

The discipline: write down decisions when you make them. Not after. The context is freshest at the moment; reconstructing it later is harder and produces sanitised versions.

**All architectures are continuous.** There's no "the architecture is now done." Every PR is a small architectural decision. The architect's job is curation, not creation — keeping the system aligned with intent as it grows.

The discipline: review architecturally significant changes. Run fitness functions in CI. Audit periodically. Refactor as you ship; don't wait for "architecture day."

These three laws cover the day-to-day practice. The architect who internalises them ships well; the one who treats them as slogans ships eventually.

> [!info] Reading the laws is easy. Practicing them across years, through team turnover and product pivots, is the actual work. Most architects who succeed do so by being mediocre at architecture and excellent at practice.

@feynman

Same as the difference between knowing the rules of a sport and being able to play it. The rules fit on a card; the play takes years to develop. Architecture has rules; the play is what makes the role.

@card
id: sa-ch16-c010
order: 10
title: The Long View
teaser: Architecture's reward loop is measured in years. The team that ships well in five years is the team that designed for it now. Patience, written communication, and a stubborn focus on long-term shape are the role's real demands.

@explanation

The closing thought: the architect's effectiveness is measured over years, not quarters.

- **Decisions made today** show their value (or cost) in two to five years, when the system has been live and the team has churned.
- **Documentation written today** is read by engineers who haven't been hired yet.
- **Patterns established today** become the team's default in three years.
- **Mentorship today** produces architects in five years.

The role rewards:

- **Patience** — the loop is slow; the dopamine of shipping a feature daily isn't there.
- **Written communication** — the channel that survives time and turnover.
- **Stubborn focus on long-term shape** — pushing back on short-term shortcuts that calcify badly.
- **Intellectual humility** — most decisions you make will, in retrospect, look slightly wrong. The skill is being slightly wrong slightly less often than the alternatives.

The architects who burn out are the ones who can't tolerate the loop length. The ones who succeed treat the slowness as the work itself — every quarter of patient writing, mentoring, and designing pays off in the year three through year ten of the system.

> [!info] If you're considering the architect role, ask yourself whether you're comfortable with feedback loops measured in years. The role isn't for everyone — but the people it fits do work that lasts.

@feynman

The same shape as any long-arc craft. The novelist's first draft is years from publication; the architect's design is years from being a tested system. Both rely on the discipline of working without the immediate signal — and both reward the people who can.
