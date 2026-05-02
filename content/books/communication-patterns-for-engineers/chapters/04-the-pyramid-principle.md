@chapter
id: cpe-ch04-the-pyramid-principle
order: 4
title: The Pyramid Principle for Technical Writing
summary: Answer first, support second, detail third — the most consistently violated rule in technical writing, and the one that wastes more engineering-hours in meetings and Slack threads than almost anything else.

@card
id: cpe-ch04-c001
order: 1
title: The Pyramid Principle
teaser: Start with the conclusion. Everything else is support. The reader should never have to read to the end to understand what you're saying.

@explanation

The Pyramid Principle, developed by Barbara Minto at McKinsey, inverts the order most people naturally write in. Instead of building toward a conclusion — laying out context, then analysis, then the point — you lead with the answer and use everything that follows to justify it.

The structure has three levels:

- **The apex:** your conclusion, recommendation, or key finding. One sentence. At the top.
- **The supporting arguments:** the two to four reasons the apex is true or the right call. Each one is a complete thought.
- **The detail:** data, examples, implementation specifics, and caveats. Only for readers who need them.

Why this matters for engineers: technical audiences are expensive to interrupt. A reader scanning a Slack message, a PR description, or a design doc should be able to extract your conclusion from the first sentence and decide in five seconds whether they need the rest. If they have to read three paragraphs to reach your point, many won't bother — or they'll misread you.

The principle also makes you a better thinker. Writing the conclusion first forces you to have one. Discovery-order writing often reveals that the author hasn't actually decided yet.

> [!info] The pyramid is a reading structure, not a writing structure. You may need to draft bottom-up to think things through — then invert before you send.

@feynman

Like a newspaper front page: the headline tells you the story, the lede paragraph fills it in, and the rest of the article is for people who want the full account.

@card
id: cpe-ch04-c002
order: 2
title: BLUF — Bottom Line Up Front
teaser: The military communication pattern that strips away every courtesy and leads with the single thing the reader must know.

@explanation

BLUF is the military's implementation of conclusion-first writing. The principle is simple: the first sentence of any communication states the action required or the decision made. Everything after that is context.

A BLUF-formatted message has a recognizable shape:

- **First sentence:** what you need, what happened, or what the recommendation is. No preamble.
- **Subsequent sentences:** why, what led here, what comes next.
- **Optional detail:** only if the recipient needs it to act.

Non-BLUF: "Hey, I've been looking at the latency numbers from Friday's deploy, and after digging through the logs and comparing with the week before, it looks like the p99 is up about 40%. I think we should roll back the cache config change."

BLUF: "Recommend rolling back the cache config change — p99 latency is up 40% since Friday's deploy."

The BLUF version is shorter, but more importantly it's faster to act on. The reader knows the recommendation before they decide whether to keep reading.

Engineers should adopt BLUF for:
- Escalation messages
- On-call handoffs
- Status updates to managers
- Any message sent to someone with more context-switching cost than you

> [!tip] If you can't write a single BLUF sentence, you haven't yet decided what you want. That's useful information — figure it out before sending.

@feynman

Like a function that returns its value immediately and then logs the reasoning — the caller gets the result without waiting for the computation to narrate itself.

@card
id: cpe-ch04-c003
order: 3
title: Why Engineers Write Bottom-Up (and Why It Fails Readers)
teaser: Engineers write the way they think — discovery order. Readers need the opposite: answer order.

@explanation

Discovery-order writing mirrors the thought process: "I noticed X, then I checked Y, then I found Z, therefore the conclusion is W." This is the natural output of solving a problem. It's also the wrong shape for communicating the result.

Why engineers default to it:

- Code comments are narrative. Explaining what a function does as you write it trains discovery-order prose.
- Engineering culture prizes showing your work. Leading with a conclusion without visible reasoning can feel arrogant or sloppy.
- Writing the conclusion first requires committing to it. Discovery-order writing lets you hedge until the end.
- Most engineers were trained in academic writing, which buries the thesis after the introduction and argument setup.

Why it fails readers:

- It hides the point. Readers who skim — which is most readers — miss it.
- It buries urgency. If the conclusion is urgent, the reader doesn't know that until they've already context-switched away.
- It signals unclear thinking. A reader who reaches your conclusion through a wall of context often isn't sure what you wanted them to take away.
- It wastes the reader's decision-making bandwidth. They've processed paragraphs of detail before they know whether the detail applies to them.

The fix isn't to stop showing reasoning — it's to reorder: conclusion, then reasoning, then detail. The reader decides how deep to go.

> [!warning] "I wanted to give you full context before the conclusion" is a rationalization. It prioritizes the writer's comfort over the reader's time.

@feynman

Like returning a result at the end of a long computation versus streaming the result as soon as it's known — the same work happens either way, but one lets the caller act immediately.

@card
id: cpe-ch04-c004
order: 4
title: Pyramid in Slack Messages
teaser: The first sentence of a Slack message is the only sentence most people fully read. Make it count.

@explanation

Slack messages are read in notification previews, in sidebar scans, and while someone is mid-task. The first sentence is often the only one that gets full attention. Structure every non-trivial message so that sentence carries the full weight.

Applying the pyramid to Slack:

- **Lead with the point, not the context.** "The staging deploy is blocked — SSH key rotated but not updated in CI secrets" beats "Hey, so I was trying to run the staging deploy and ran into an issue."
- **Put asks before explanations.** "Can you review the auth PR before 3pm? I have a hard dependency for tomorrow's cut." The ask is the first thing. The reason follows.
- **State status before detail in updates.** "The migration is done — all 4.2M rows moved, no errors, indexes rebuilt. Here's the timing breakdown." The status is complete before the detail arrives.
- **One message, one point.** Threading is for detail and discussion, not for housing the actual conclusion of a train of thought.

Common mistakes:

- Starting with "Hey [name]," followed by a paragraph of context before the actual question. The recipient now has to read to the end to know if it's urgent.
- Posting a block of logs with "does this mean anything to you?" instead of leading with your hypothesis.
- Splitting the conclusion across three short messages, each adding a piece of it.

> [!tip] Before sending a Slack message longer than two sentences, read the first sentence alone. If someone only read that, would they know what you wanted?

@feynman

Like a tweet — the constraint forces you to put the real point first because you can't afford to bury it.

@card
id: cpe-ch04-c005
order: 5
title: Pyramid in PR Descriptions
teaser: What changed and why comes before how it was implemented. Reviewers need the conclusion first, the approach second, the implementation detail last.

@explanation

PR descriptions are read by reviewers who are context-switching from their own work. They need to orient quickly: what is this change, why does it exist, and what should I focus on? Most PR descriptions answer none of these questions at the top and leave the reviewer to reconstruct intent from the diff.

A pyramid-structured PR description:

- **First: what and why.** One or two sentences. "Replaces the in-memory rate limiter with Redis-backed storage so limits survive pod restarts." That's the conclusion. The reviewer now knows the intent before they see a single line of diff.
- **Second: the approach.** How the change achieves the intent. Which components were modified, what the key decision was, what alternatives were ruled out.
- **Third: review guidance.** Where to focus attention, what to watch for, what has already been verified.
- **Last: testing and follow-up.** How you verified it, what's out of scope, what comes next.

What to cut entirely:

- Summaries of every file changed (that's what the diff is for)
- Changelog-style lists of implementation steps
- Apologetic hedges ("this is a bit rough, I know the test coverage isn't great")

The goal is to give the reviewer enough signal in the first two sentences to route the PR: urgent/non-urgent, risky/safe, needs careful read/quick approval.

> [!info] If your PR description starts with "This PR..." you've already wasted the reader's first words. The title says it's a PR.

@feynman

Like a movie trailer that gives you the premise and stakes up front — you decide whether to watch the full film based on thirty seconds, not the credits.

@card
id: cpe-ch04-c006
order: 6
title: Pyramid in Design Proposals
teaser: Put the recommendation first. Reviewers don't need to earn the conclusion by reading through your analysis.

@explanation

Design proposals are one of the most common places engineers violate the pyramid. The typical structure is: background, problem statement, constraints, options analysis, comparison table, then recommendation. The reader gets the answer on page four.

An inverted pyramid structure for a design proposal:

- **Recommendation.** "We should use a single Postgres instance with row-level read replicas rather than sharding." One sentence. First paragraph.
- **Key reasons.** Two to four bullet points that justify the recommendation. Not the full analysis — the conclusions of the analysis.
- **Context and problem statement.** Now that the reader knows where you're going, they can read the context with that lens.
- **Options considered.** What else was evaluated and why each was ruled out.
- **Detail.** Schema sketches, query patterns, failure mode analysis, migration notes.

Why this works better for reviewers:

- Senior stakeholders can engage with the recommendation immediately without wading through context they already have.
- Junior reviewers can evaluate the reasoning chain from conclusion to support rather than trying to anticipate what it leads to.
- Comments cluster around the recommendation and key reasons, not scattered across the analysis section.
- Disagreements surface faster — if the recommendation is wrong, that's visible in the first paragraph.

> [!tip] Write the proposal bottom-up if that helps you think. Then rewrite the opening so the recommendation appears in paragraph one before you share it.

@feynman

Like an ADR (Architecture Decision Record) where the decision header comes before the context — the format enforces conclusion-first so future readers don't have to reconstruct it.

@card
id: cpe-ch04-c007
order: 7
title: Pyramid in Incident RCAs
teaser: Impact and resolution belong at the top of a post-mortem. The timeline is for people who need to understand how, not whether.

@explanation

Post-mortem and RCA documents often open with an incident timeline because the author lived through it in that order. Readers — including executives, on-call engineers reviewing past incidents, and teams building mitigations — need a different order entirely.

A pyramid-structured RCA:

- **Impact summary.** Duration, affected services, customer impact, severity. Three to five bullet points. First section.
- **Root cause.** One to two sentences. What actually caused the incident, not how it unfolded.
- **Resolution.** What was done to stop it and restore service. Short and specific.
- **Contributing factors.** The conditions that let the root cause cause an incident. This is the analysis that supports the root cause statement.
- **Action items.** Concrete follow-up with owners and dates.
- **Timeline.** The full chronology, for those who need to audit or understand the sequence.

The timeline is valuable — but it belongs at the bottom, as reference material. It's the detail layer of the pyramid. The root cause and resolution are the apex.

Why the order matters for RCAs specifically:

- Leadership wants impact and resolution first to assess whether the incident is closed.
- On-call engineers reviewing the doc want root cause first to know if similar systems are at risk.
- No reader comes to an RCA to read a narrative — they come for specific facts.

> [!warning] A timeline-first RCA trains teams to narrate incidents rather than diagnose them. Root-cause thinking belongs at the top.

@feynman

Like a bug report where the reproduction steps are informative but the actual bug description goes in the title — the conclusion is the navigational anchor.

@card
id: cpe-ch04-c008
order: 8
title: The Executive Summary Pattern
teaser: One paragraph that makes everything else optional — if you write it correctly, the rest of the document is detail for people who want it.

@explanation

An executive summary is not a table of contents or an introduction. It is a self-contained communication that conveys the full point of the document in one paragraph. A reader who only reads the executive summary should be able to make any decision the document asks them to make.

What belongs in a well-written executive summary:

- **The situation.** One sentence of context. Not the full background — just enough to place the recommendation.
- **The recommendation or conclusion.** Explicit, specific, and actionable. Not "we should consider options" but "we should migrate to PostgreSQL by Q3."
- **The key supporting reasons.** Two or three, no more. Not the analysis — the outputs of the analysis.
- **The ask or next step.** What you need from the reader. Approval, a decision, a review, a resource.

What does not belong:

- Methodology description ("we evaluated four options using a weighted matrix")
- Caveats and qualifications that dilute the recommendation
- Summaries of sections that follow ("Section 3 covers the performance analysis")
- History and background that isn't necessary to evaluate the recommendation

The test: can a reader who reads only the executive summary take the action you want? If not, the executive summary contains the wrong content.

> [!info] An executive summary written after the document is done is almost always a table of contents in disguise. Write it first, as the actual message — then write the document to support it.

@feynman

Like a function signature with a clear return type — it tells the caller exactly what they're getting before they look at the implementation.

@card
id: cpe-ch04-c009
order: 9
title: The SCQA Framework
teaser: Situation, Complication, Question, Answer — a four-part structure that earns the reader's attention before delivering the point.

@explanation

SCQA is the Minto Pyramid's narrative wrapper. Used when the recommendation alone is too abrupt — when the reader doesn't yet understand why there's a problem worth solving. It earns the right to deliver a conclusion by establishing the stakes first.

The four parts:

- **Situation:** the stable context the reader already knows or accepts. "Our API gateway handles 200k requests per second at peak."
- **Complication:** the thing that disturbs the situation. "Certificate rotation now takes 45 minutes and causes a 2% error rate during rollover."
- **Question:** the problem the rest of the document answers. "How do we rotate certificates without service disruption?"
- **Answer:** the apex of the pyramid. "We should implement zero-downtime certificate rotation using a dual-bind approach."

SCQA is useful when:

- The reader doesn't know there's a problem yet
- The recommendation is counterintuitive and needs the setup to land
- You're writing to a mixed audience: some who have context and some who don't

SCQA is not needed when:

- The reader already knows the situation and complication (skip to Q and A)
- The document is an update, not a proposal (skip to answer directly)
- The audience is the team that created the problem (they know the situation)

Used well, SCQA is the setup that makes the pyramid's apex land with force instead of appearing out of nowhere.

> [!tip] A useful shortcut: write the C and A first. The complication defines the problem; the answer defines your solution. S and Q are scaffolding around them.

@feynman

Like a good bug report title: "X breaks when Y happens" (Situation + Complication) followed by the recommended fix — you know what you're reading and why before opening it.

@card
id: cpe-ch04-c010
order: 10
title: The Problem-Solution-Tradeoff Structure
teaser: For technical decisions, three sections are almost always enough — and in that order.

@explanation

Most technical decision documents contain more structure than they need. Problem-Solution-Tradeoff (PST) is a minimal pattern that covers the necessary ground without excess.

The three sections:

- **Problem:** what is broken, constrained, or needs to change. Specific and observable. "The current in-process queue drops messages on pod restart, causing silently lost jobs." Not "we need better reliability."
- **Solution:** the proposed approach. What it does, not just what it is. "A Redis-backed queue with at-least-once delivery and consumer deduplication via idempotency keys."
- **Tradeoffs:** what the solution costs and what it doesn't solve. "Adds an operational Redis dependency. Requires dedup logic in every consumer. Doesn't address downstream processing failures — that's a separate problem."

Why tradeoffs belong in the structure, not as a footnote:

- A solution without explicit tradeoffs looks like advocacy, not analysis.
- Reviewers will find the tradeoffs anyway; listing them first builds trust and frames the review correctly.
- It separates this decision from adjacent decisions ("downstream failures are out of scope") and prevents scope creep in review.

PST scales from a Slack message ("Problem: the deploy is broken. Solution: roll back to v2.3.1. Tradeoff: we lose the feature, needs to re-land next sprint.") to a full design document.

> [!info] If the tradeoffs section is empty, you either haven't thought hard enough or you haven't been honest. Every real solution has costs.

@feynman

Like a pull request that includes a "why not X" section alongside the implementation — the absence of alternatives discussed is itself a smell.

@card
id: cpe-ch04-c011
order: 11
title: Common Anti-Patterns: Buried Lede, Caveats First, Hedge Explosion
teaser: Three structural habits that dilute your message before it reaches the reader.

@explanation

These three anti-patterns share a root cause: prioritizing the writer's anxiety over the reader's comprehension.

**Burying the lede.** The conclusion appears in the last paragraph after pages of context. The reader either skims and misses it, or reads the full document and only then understands what was being asked. Fix: move the conclusion to the first paragraph, always.

**Caveats before the point.** "While it's worth noting that there are some conditions under which this may not hold, and with the caveat that we haven't fully benchmarked edge cases, and understanding that there are multiple reasonable views on this, we think the migration is probably worth considering." The hedge comes first and swamps the recommendation. Fix: make the recommendation first, put the caveats in their own section after the recommendation, at the appropriate level of detail.

**Hedge-word explosion.** "It seems like it might potentially be worth exploring whether we could possibly look into this." Every hedge word removes signal. "Might," "potentially," "possibly," and "sort of" don't make statements more accurate — they make them harder to act on. Fix: write the claim without hedges, then add back only hedges that carry specific meaning (e.g., "this holds for p99 but not average latency").

A useful diagnostic: read your message and ask whether every word earns its place. A recommendation buried under four layers of qualification isn't humble — it's evasive.

> [!warning] Engineers often hedge to avoid being wrong. But a recommendation no one can act on because it's drowned in qualifications is more costly than a confident recommendation that turns out to need revision.

@feynman

Like a variable name that's so cautiously generic it conveys nothing — the hedge feels safe but removes the information.

@card
id: cpe-ch04-c012
order: 12
title: Editing for Structure: Turning a Bottom-Up Draft into a Top-Down Communication
teaser: A practical rewrite protocol for taking discovery-order prose and inverting it into a conclusion-first structure.

@explanation

Most pyramid violations are drafts, not finished writing. The fix is a structural edit, not a line edit. Here's a repeatable protocol:

**Step 1: Identify the conclusion.** Read your draft and ask: what is the one thing I want the reader to know or do? Write that sentence on its own. If you can't write it, you're not done thinking — stop editing and think first.

**Step 2: Find the supporting arguments.** What are the two to four reasons the conclusion is correct or the right call? These should be in your draft. Extract them as a list.

**Step 3: Classify the rest as detail.** Everything in the draft that isn't the conclusion or a supporting argument is detail. It may be important detail, but it belongs below the structure you've already identified.

**Step 4: Rewrite the opening.** Replace whatever was first with the conclusion. Add the supporting arguments immediately after. Now the pyramid exists.

**Step 5: Reorganize the detail.** Group detail under the supporting argument it supports. Cut detail that doesn't support any argument — it's probably noise.

**Step 6: Check the first sentence.** Read only the first sentence. Does it carry the full weight of your message? If someone read nothing else, would they know what you were saying?

The full edit can be done in five minutes on most documents. The bottleneck is usually Step 1 — clarifying what the conclusion actually is. That's not an editing problem; it's a thinking problem. Solve it first.

> [!tip] A quick proxy: paste your draft into a doc, bold every sentence that is a conclusion or recommendation, and count them. If there are zero in the first paragraph, the edit starts there.

@feynman

Like refactoring: you don't rewrite the logic, you reorganize it so the most important parts are visible at the call site instead of buried in a helper three files down.
