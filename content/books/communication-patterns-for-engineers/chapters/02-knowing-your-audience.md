@chapter
id: cpe-ch02-knowing-your-audience
order: 2
title: Knowing Your Audience
summary: Who's reading, what context they bring, and what they need to walk away with — the three questions that shape every technical communication before you write a word.

@card
id: cpe-ch02-c001
order: 1
title: The Audience Question
teaser: Every piece of technical writing has a reader. Knowing who that reader is — and what they already know — is the first decision, not the last.

@explanation

Before you write a single sentence, ask: who is actually going to read this?

Not "who might read this" or "who would I like to read this" — who will encounter this document in practice, under what circumstances, and with what existing knowledge. The answer shapes everything that follows: vocabulary, depth, structure, tone, and what you can safely leave out.

The audience question has three parts:

- **Who are they?** Their role, their relationship to the system, and their technical background.
- **What do they already know?** What context can you assume? What will they need you to supply?
- **What do they need to walk away with?** A decision? An action? A mental model? A reference to come back to?

Getting one of these wrong is usually enough to make a document fail. A runbook written for senior engineers is dangerous in the hands of an on-call who joined six months ago. An architecture doc written for a tech lead will lose a PM on the third paragraph if it never answers "why does this exist."

> [!info] The audience question isn't answered once — it's checked at every structural decision: section order, vocabulary choice, how much context to provide before the technical content begins.

@feynman

Like setting a compiler target — write for the wrong runtime and the code won't run, even if it's perfectly correct for a different machine.

@card
id: cpe-ch02-c002
order: 2
title: The Curse of Knowledge
teaser: The more you know about a system, the harder it becomes to remember what it's like not to know it — and that gap is the source of most confusing documentation.

@explanation

The curse of knowledge is a cognitive bias: once you understand something deeply, you lose access to the mental state of not understanding it. You can't unsee what you know. This is catastrophic for technical writing.

It manifests in recognizable ways:

- Starting an explanation with an acronym you never define, because it's obvious to you.
- Skipping the "why does this exist" section because the problem is self-evident — to you.
- Referencing another system or concept without linking or explaining it, because you've been using it for two years.
- Writing a three-step setup guide that assumes the reader has already done four undocumented steps.
- Using words like "simply," "just," or "obviously" — signals that the writer has forgotten the reader's starting point.

The practical problem: experts write the documentation their colleagues complain about. The engineer who knows the system best is the worst-positioned person to write the first draft for newcomers, because they've lost the ability to see the gaps.

The countermeasure is deliberate: write for a specific named person you know who doesn't have your context, then ask them to follow the doc and watch where they get stuck. The confusion they hit is real; your certainty that it's "obvious" is the bug.

> [!warning] "This is well-documented" is often said by the person who wrote the docs. Check with the people who were handed them cold.

@feynman

Like trying to unhear a song — once you know the melody, you can't hear the tune as noise anymore, even when someone else clearly does.

@card
id: cpe-ch02-c003
order: 3
title: Audience Profiles in Engineering Organizations
teaser: Different roles bring radically different contexts to the same document — and each profile has a distinct question they need answered first.

@explanation

Six audience profiles appear repeatedly in engineering organizations, each with a different starting context and a different primary need:

- **IC engineer:** technically fluent in the domain; wants implementation detail, edge cases, failure modes, and API contracts. Their first question is "how does this actually work?"
- **Tech lead:** understands the technical space; wants to see tradeoffs, risks, and how the design fits adjacent systems. Their first question is "why this approach instead of the alternatives?"
- **Engineering manager:** understands delivery, scope, and team dynamics; needs to understand impact, timeline risk, and escalation paths. Their first question is "what does this mean for the team?"
- **Product manager:** owns the problem space, not the solution space; needs to connect technical decisions to user impact and roadmap. Their first question is "what does this mean for the product?"
- **Executive:** has the broadest context and the least time; needs the situation, the decision or ask, and the consequence of each option. Their first question is "what do you need from me?"
- **External user:** knows nothing about your internals; needs enough context to act, with no jargon that isn't defined on first use. Their first question is "what is this and can I trust it?"

One document rarely serves all six equally. The mistake is trying to write a single doc that does — usually by burying the executive summary on page three and putting the API reference on page one.

> [!tip] Before writing, name the primary audience and the secondary audience. Optimize structure for the primary. Serve the secondary with a clearly labeled section, not by blending everything together.

@feynman

Like a product with a primary user and an admin user — the interface serves both, but the primary flow is designed for one and the admin panel for the other.

@card
id: cpe-ch02-c004
order: 4
title: Calibrating Technical Depth
teaser: Technical depth isn't about how much you include — it's about the match between what you assume and what your reader actually brings to the page.

@explanation

Technical depth is a dial, not a toggle. The common failure modes are at both ends:

**Too deep for the audience:**
- Referencing implementation details (specific library versions, internal service names, database schema fields) when the reader needs a conceptual model.
- Assuming familiarity with domain terminology that hasn't been established.
- Leading with the solution before establishing the problem, so the reader can't evaluate whether the solution fits.

**Too shallow for the audience:**
- Over-explaining concepts the reader knows well, which reads as condescending and wastes their time.
- Avoiding technical precision in the name of accessibility, leaving out the detail an IC needs to act.
- Abstracting away the exact behavior the reader needs to debug an issue.

Calibration is an active process. For any given concept, ask:

- Does this reader already have this term? If yes, use it. If no, define it or avoid it.
- Does this reader need to know how this works, or just that it works? The answer determines depth.
- Is the detail I'm including useful to this reader, or useful to me for feeling thorough?

The last question is the uncomfortable one. A lot of unnecessary technical depth is the writer demonstrating competence, not serving the reader.

> [!info] A useful signal: if you find yourself writing a paragraph your reader already knows, cut it. It's not kindness to re-explain what someone knows — it's time they won't get back.

@feynman

Like choosing a gear in a manual transmission — there's a right gear for the current speed and load, and being in the wrong one burns fuel without going faster.

@card
id: cpe-ch02-c005
order: 5
title: The 5-Second Test
teaser: A document passes the 5-second test if a reader can answer "what is this and why should I care?" before they've made a decision to keep reading.

@explanation

Most documents fail in the first five seconds. A reader opens a doc, scans the title and the first paragraph, and makes a binary decision: "this is for me" or "this isn't for me." If they can't determine which, they usually pick the second option.

The 5-second test: hand your document to someone in your target audience who hasn't seen it. After five seconds, ask them:

- What is this document about?
- Who is it for?
- Why should they read it?

If they can't answer all three, the opening isn't working. The fix is almost always the same: the actual answer to those three questions belongs in the first two sentences, not in the third paragraph.

Common opening anti-patterns:

- Starting with background history ("In 2021, when we migrated to Kubernetes...").
- Starting with scope disclaimers ("This document does not cover...").
- Starting with a definition that isn't the point ("A circuit breaker is a pattern that...").
- Starting with a table of contents before a single orienting sentence.

The document's first sentence should answer: "what is this and who should read it." The second sentence should answer: "why does it matter." Everything after that is earned by the reader who decides to continue.

> [!tip] Write the opening last. It's easier to summarize what a document says after you've written it than to predict the right framing before.

@feynman

Like a function signature — the name and parameters should tell you what the function does before you read the body.

@card
id: cpe-ch02-c006
order: 6
title: Writing for the Future Reader
teaser: The person most likely to need your documentation is you, six months from now, at 3am, when the system is broken and you can't remember what you were thinking.

@explanation

Most documentation is written for an imagined present reader: a colleague who has the same context you have today, who can ask follow-up questions, who knows which Slack channel to ping. That reader is rarely the one who actually needs the doc in a crisis.

The real readers of operational documentation:

- You, during a post-incident review six months after the incident you thought you'd remember.
- A new engineer on-call for the first time, with the system throwing an alert they've never seen.
- A colleague debugging a system you built, two timezones away, with no way to reach you.
- Your future self, trying to understand why you made a specific design decision.

Writing for the future reader means:

- Including the "why" alongside the "what." Decisions that seemed obvious when you made them won't be obvious to someone reading the doc without your context.
- Naming the failure modes. What breaks? What does it look like when it breaks? What do you check first?
- Dating your assumptions. "As of Q3 2024, this service handles X" ages better than "this service handles X."
- Writing runbooks that don't assume you're on Slack. They should work if the only available channel is the doc itself.

The test: if you were paged at 3am, handed this doc, and asked to diagnose a failure in the system it describes — would the doc be enough?

> [!warning] "I'll update this later" is how runbooks end up describing systems that no longer exist.

@feynman

Like writing a commit message — the code tells you what changed; the message tells you why, and the why is what your future self actually needs.

@card
id: cpe-ch02-c007
order: 7
title: Making One Document Serve Multiple Audiences
teaser: Layered structure lets a single document answer the executive's question in 30 seconds and the IC's question in 30 minutes — without making either reader wade through what they don't need.

@explanation

When you can't write separate documents for separate audiences — a common constraint — the solution is layered structure. The document is organized so each reader can get what they need without reading everything.

The layered pattern:

- **Layer 1: Summary (1–3 sentences or bullets).** Answers "what is this, why does it matter, what is the outcome or ask." The executive reads this and stops or continues.
- **Layer 2: Context and decision (1–2 paragraphs or a short list).** Answers "what led here, what were the options, what was chosen and why." The EM and PM read through here.
- **Layer 3: Technical detail.** Answers "how does it work, what are the tradeoffs, what are the edge cases." The tech lead and IC read this section.
- **Layer 4: Reference material.** API contracts, config options, error codes, command syntax. The IC comes back to this section repeatedly.

The structure is announced, not implied. Headers like "Summary," "Background," "Technical Design," and "Reference" tell each reader where to stop and where to go deeper.

What breaks layering:

- Mixing layers — putting a critical implementation detail in the summary, or burying a key business constraint in the reference section.
- Writing a thin summary that doesn't actually summarize — padding that forces every reader to read everything to get the point.
- Using jargon in the summary layer that only the technical audience understands.

> [!info] A layered document doesn't mean a padded document. Each layer should be the minimum length to serve its audience, not a filled-out section for the sake of structure.

@feynman

Like a progressive JPEG — it loads a low-resolution version first, and each additional pass adds detail for the reader who wants it.

@card
id: cpe-ch02-c008
order: 8
title: The Reader's Question Hierarchy
teaser: Readers don't ask all their questions at once — they work through a hierarchy, and a document that answers question three before question one has already lost them.

@explanation

Readers approach a new document with a predictable sequence of questions. They don't move to the next question until the current one is answered. A document that answers them out of order creates friction at each step.

The hierarchy:

1. **"What is this?"** — What is the subject of this document? What system, feature, process, or decision does it describe? If this isn't answered in the first two sentences, the reader is already disoriented.

2. **"Why does it exist?"** — Why was this built, decided, or written? What problem does it address? A document that skips this produces readers who can follow the instructions but don't understand when to apply them.

3. **"How do I use it?"** — What do I actually do? The steps, the commands, the configuration, the API calls. The reader reaches for this only after they understand what and why.

4. **"What if it breaks?"** — What are the failure modes? What does a bad state look like? How do I recover? This section is skipped on first read and searched during incidents.

Documents that invert this hierarchy — starting with failure modes, or leading with "how to use it" before explaining what it is — create confusion that readers often blame on their own understanding rather than the document's structure.

The hierarchy applies at every scale: a section, a paragraph, even a sentence. "Use --force-with-lease instead of --force" is more useful than "To avoid overwriting changes in a shared branch, which can cause data loss, use --force-with-lease instead of --force" — but only if the reader already has the why. If they don't, the second form is correct.

> [!tip] When editing a document, read it with one question in mind at a time. Find where each question is answered. If the sequence is out of order, reorder the sections.

@feynman

Like a function call with dependencies — you can't execute step three until the return value of step one is in scope.

@card
id: cpe-ch02-c009
order: 9
title: Pre-Writing Audience Analysis
teaser: Five minutes of structured thinking before you open a text editor prevents thirty minutes of structural revision after the first draft.

@explanation

Most documentation problems are diagnosed late — during review, or after the confused Slack messages start arriving. The point at which they're easiest to fix is before you write a word.

A pre-writing audience analysis takes five minutes and answers five questions:

- **Who is the primary reader?** Name a role or, better, a specific person. "IC engineer on the platform team" is more useful than "technical reader."
- **What do they already know?** What context can you assume? What background do you need to provide? What terms need definition?
- **What do they need to walk away able to do or decide?** The answer shapes the structure — a doc meant to produce a decision has a different structure than a doc meant to produce an action.
- **When will they read this?** During onboarding, in a crisis, before a meeting, as a reference? The context of use determines the format (narrative vs. reference, long vs. short, searchable vs. linear).
- **What's the one thing they must not get wrong?** This becomes the most prominent piece of content in the document, not an afterthought in a footnote.

The analysis doesn't have to be written down — though writing it produces better results than thinking it. What matters is that the answers exist before the document does, not after.

> [!tip] If you can't answer "what does this reader need to walk away with," you're not ready to write. The uncertainty is a signal to clarify the purpose of the document, not to start drafting and hope the purpose emerges.

@feynman

Like schema design before writing a query — the structure you choose up front determines whether the query you write later is efficient or a full table scan.

@card
id: cpe-ch02-c010
order: 10
title: What the Reader Wants vs. What They Actually Need
teaser: Readers frequently ask for one thing and need another — the job of the writer is to deliver both, in the right order.

@explanation

A reader's stated request and their actual need are often different. A new engineer asks for "a list of all the services" when they actually need an oriented mental model of how the services relate. A PM asks for "the status of the migration" when they actually need to know whether to reschedule a customer demo. An on-call engineer asks "what does this error mean" when they actually need "what do I do right now."

Serving only the stated want produces documentation that answers the question but doesn't help the person. Serving only the inferred need without acknowledging the stated want produces documentation the reader doesn't trust — they asked for X, you gave them Y, they assume you misunderstood.

The right approach is to answer the want first, then lead to the need:

- Start with the direct answer to the question asked.
- Follow with the context that explains it or expands it.
- End with the action or implication — the thing that serves their actual need.

This pattern is visible in good Stack Overflow answers: direct answer first, explanation second, caveats and related information third. The reader who only needed the direct answer exits at step one. The reader who needs more continues.

The failure mode is reversing the order: context first, then answer. The reader who needs the answer immediately has to work through context they didn't ask for before they can act. In a crisis, they stop reading.

> [!info] "Answer first" is not the same as "answer only." The explanation earns the trust that the direct answer alone doesn't always produce.

@feynman

Like a doctor visit — the patient describes a symptom, the doctor treats the underlying condition, but they explain the connection so the patient understands what's happening.

@card
id: cpe-ch02-c011
order: 11
title: Feedback Loops — How to Know If You've Reached Your Audience
teaser: The only real test of whether a document works is whether the right people can use it correctly without asking follow-up questions.

@explanation

A document you believe is clear is not evidence of clarity. The author is the worst judge of their own documentation. The signal that matters is how the intended audience performs when using it cold.

Practical feedback mechanisms:

- **Follow-along review:** ask someone in the target audience to follow the document in real time — do the steps, make the decisions — while you watch. Note where they pause, re-read, or ask clarifying questions. Those pauses are the gaps.
- **Post-incident review:** when a runbook is used in an incident, include a step at the end: "was this runbook sufficient? What was missing?" The answer arrives in the moment of highest need.
- **First-day reads:** new engineers are the best test audience for onboarding and setup docs. Their confusion is the clearest signal of gaps that experts have learned to work around.
- **Support volume:** if the same question keeps appearing in Slack or support tickets after a document exists, the document isn't reaching its audience or isn't answering what they actually need.
- **Explicit doc reviews:** treating documentation as a reviewable artifact the same way code is reviewed, with comments on gaps, ambiguities, and missing context.

The feedback loop is closed when the document is updated based on what you learn — not filed away as "known issues." A doc with known gaps and no plan to fix them is worse than no doc, because it creates false confidence.

> [!tip] The most valuable person to review a new document is someone who just experienced the confusion the document is meant to prevent.

@feynman

Like a unit test — it's not proof of correctness until someone else can run it in an environment you didn't control.

@card
id: cpe-ch02-c012
order: 12
title: Anti-Pattern — Writing the Doc You Wish Existed
teaser: Writing the document you wished you had when you were learning the system is almost never the document your audience needs now.

@explanation

There's a seductive framing for technical documentation: write the document you wish had existed when you were figuring this out. It's well-intentioned. It often produces documentation that is thorough, empathetic to the newcomer experience, and organized around how the writer developed their understanding.

It's also frequently wrong for the current audience.

The problem: your learning path was shaped by your prior context, your specific confusions, and the questions you happened to ask. Your audience has a different prior context, different confusions, and different questions. A document organized around your learning journey optimizes for one person — a past version of you — who is not the actual reader.

Specific failure modes:

- **Optimizing for the day-one experience when the reader is day-90.** A doc written for a newcomer's first encounter with a system becomes noise for an IC who knows the system and just needs the reference section.
- **Documenting the journey instead of the destination.** Explaining all the dead ends and false starts that led to the current design teaches the writer's history, not the system's present.
- **Writing for your confusion, not theirs.** The things you found confusing may not be the things your audience finds confusing. The gaps in your mental model may not be the gaps in theirs.
- **Organizing around how you learned it, not how they'll use it.** Linear narrative documentation is hard to use as a reference. It's structured for reading once, not for returning to during an incident.

The alternative is harder: start from an explicit audience profile, identify their questions and context, and build the document from there — not from your experience of not knowing, but from their experience of needing to know.

> [!warning] "This is the doc I wish I'd had" is a useful starting point for identifying topics, not a useful guide for structure, depth, or audience calibration.

@feynman

Like designing an API by writing the implementation you found intuitive to build, rather than the interface your callers actually need to use.
