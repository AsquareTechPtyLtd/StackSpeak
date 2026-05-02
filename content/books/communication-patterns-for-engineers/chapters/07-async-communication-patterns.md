@chapter
id: cpe-ch07-async-communication-patterns
order: 7
title: Async Communication Patterns
summary: The default should be async — and most teams don't know how to do it well. The channel decision (Slack vs email vs doc vs meeting), writing that unblocks without a reply, and building a culture where real-time interruptions are the exception.

@card
id: cpe-ch07-c001
order: 1
title: The Async-First Principle
teaser: Async should be your default, not your fallback — most communication doesn't require a real-time response, and treating it as if it does is a hidden tax on the whole team.

@explanation

Async-first doesn't mean never synchronous. It means your default assumption is: "this can be resolved without a live conversation," and you only abandon that assumption when you have a specific reason to.

The tax is real. Every interruption for synchronous communication imposes a context-switch on the recipient. Research on developer productivity consistently shows that recovering from a context switch takes 10–20 minutes. A team of ten engineers interrupted twice a day each is burning 20–40 engineer-hours per week on overhead alone.

The more important shift is structural: async-first forces the sender to do more work upfront. You can't ask a half-formed question asynchronously and get an instant clarification loop. You have to think the question through before sending it. That thinking is not extra work — it's work that was always necessary and was previously being offloaded to the recipient in the form of back-and-forth conversation.

What async-first produces:
- Decisions that are documented by default, because they happened in writing.
- Teams that function across time zones without coordination overhead.
- Fewer meetings, because most meetings are just async decisions waiting to be made.
- A written record that scales — the answer to "why did we do X" exists somewhere.

What async-first requires:
- Clear writing. Ambiguous async messages produce clarification threads that are worse than a meeting.
- Agreed response windows. Async only works if everyone knows what "in time" means for a given channel.
- Trust that silence isn't blocking. Engineers need to feel safe not responding immediately.

> [!info] Async-first is a team discipline, not a personal habit. One person defaulting to sync overrides the whole system for anyone in their path.

@feynman

Like test-driven development — it feels like extra work upfront, but it catches the ambiguity before it ships downstream.

@card
id: cpe-ch07-c002
order: 2
title: The Four-Channel Decision
teaser: Slack, email, doc, meeting — each channel has a different audience, permanence, urgency, and interaction model. Choosing wrong creates friction that compounds across the organization.

@explanation

There is no universally correct channel — there is a correct channel for each type of communication. The decision criteria:

**Slack (or equivalent persistent chat):**
- Short-lived, low-stakes questions and answers.
- Status updates with a short shelf life (deploy is done, PR is ready).
- Quick coordination between people who are both actively working.
- Audience: specific individuals or a small, named group.
- Not for: decisions that need a record, anything that people not currently online need to find later.

**Email:**
- Stakeholder communication outside engineering (legal, finance, external partners).
- Announcements with a permanent, formal character (incident report, policy change).
- Threads that need a stable, searchable record outside a chat tool.
- Not for: anything that evolves through discussion — threads fragment badly.

**Document (Notion, Confluence, Google Doc, etc.):**
- Proposals, RFCs, architectural decisions, postmortems, onboarding guides.
- Anything that needs to be discoverable by someone who wasn't in the original conversation.
- Anything that will be referenced more than once.
- Not for: quick Q&A or status that will be stale by tomorrow.

**Meeting:**
- High-ambiguity, high-stakes decisions where the back-and-forth is the point.
- Complex emotional or interpersonal situations where tone matters.
- Kickoffs that need shared context established quickly.
- Not for: status updates, decisions that one person can make, anything that could be a doc with a comment thread.

> [!tip] The permanent-record test: "Will someone need to find this in six months?" If yes, it belongs in a document, not Slack or email.

@feynman

Like choosing between a text message, a letter, a published article, and a phone call — the same content lives differently in each medium.

@card
id: cpe-ch07-c003
order: 3
title: Writing a Slack Message That Doesn't Need a Reply
teaser: Most Slack threads exist because the original message was incomplete — the sender wrote what they were thinking, not what the recipient needed to act.

@explanation

A Slack message that generates a clarification thread is a failed async communication. The goal is to write a message complete enough that the recipient can respond with the answer, not with more questions.

Structure for an actionable async message:

**Context (one sentence).** What is this about? Don't assume the recipient has your context. "I'm looking at the auth service's retry logic in PR #412."

**The specific question or request.** Be precise. "Are we intentionally retrying on 401s, or is that a bug?" is better than "quick question about retry logic."

**What you've already tried or checked.** This prevents the obvious clarification question and shows you're not asking something trivially Google-able. "I checked the original PR and didn't see a comment on it."

**What decision hangs on the answer.** "If it's intentional I'll leave it; if it's a bug I'll file a ticket."

**Time sensitivity, if any.** "No rush — I'm just leaving a note before I move on."

The complete message takes 60 seconds to write and saves 10 minutes of back-and-forth. The incomplete message saves 30 seconds and costs everyone more.

What to cut:
- "Can I ask you something?" — just ask.
- "Do you have a minute?" — use the "no hello" pattern.
- Unnecessary pleasantries before the actual content. Save those for in-person or video.

> [!warning] A long Slack message that requires no reply is better than a short one that spawns a five-message thread. Length is not the problem — incompleteness is.

@feynman

Like writing a well-formed bug report — all the context is in the ticket so the reader can act without interviewing you first.

@card
id: cpe-ch07-c004
order: 4
title: The "No Hello" Pattern
teaser: Sending "hello" and waiting for a response before asking your actual question is synchronous communication disguised as async — it doubles the latency for no benefit.

@explanation

The pattern is named after nohello.net and is widely adopted in distributed engineering teams. The anti-pattern:

```
Engineer A: "Hey, got a minute?"
[waits]
Engineer B: "Sure, what's up?"
[waits]
Engineer A: "Quick question about the deploy pipeline..."
```

Three messages. Two context switches for Engineer B. One round-trip before the actual content is even on the table. This is synchronous behavior in an async medium.

The async version:

```
Engineer A: "Hey — quick question about the deploy pipeline:
does the build cache get invalidated when we bump a Go
module version, or only on full cache flush? Trying to
figure out why yesterday's build was slower. No rush."
```

One message. One context switch. Engineer B can respond when it fits their schedule.

This matters more at scale. If you have 20 engineers on Slack and each sends one "hello" before their real question per day, you've created 20 unnecessary interruptions and 20 unnecessary response cycles.

The pattern applies to more than just "hello":
- "Can I ask you something?" — just ask.
- "Do you have time to review this?" — just share the link and ask.
- "Quick question" with no question following — include the question.

The cultural piece: this isn't rudeness. It's respect for the recipient's time and flow. Teams that establish this norm report less friction, not more.

> [!info] Add a nohello.net link to your team onboarding doc. One URL handles the explanation so you don't have to have the conversation individually with each new hire.

@feynman

Like calling an API — you pass all the parameters in the request, not in a pre-flight "are you ready?" handshake.

@card
id: cpe-ch07-c005
order: 5
title: Async Decision-Making with RFCs
teaser: The RFC (Request for Comments) format turns decisions into structured async conversations — one document, one clear proposal, collected feedback, explicit outcome.

@explanation

Most engineering decisions don't require a meeting. They require one person to think carefully, write down a proposal, and give others a structured way to respond. That's what an RFC does.

A minimal RFC format that works:

**Title and status.** "RFC: Replace Redis session cache with JWT — Status: Open for comment until May 10"

**Context.** One to three paragraphs. What's the current state, what's the pressure that's driving this decision? Assume the reader hasn't been in the relevant recent meetings.

**Proposal.** What are you proposing, specifically? Be concrete enough that someone could implement it from this section alone.

**Alternatives considered.** Two or three other approaches you evaluated and why you're not proposing them. This is the most important section for building trust — it shows you did the thinking.

**Open questions.** Anything you're uncertain about that you want input on. This guides comments toward what's actually useful.

**Decision criteria.** What would make you change the proposal? Giving reviewers a target makes feedback more actionable.

**Comment window.** A date. "Please comment by Friday EOD." Without a deadline, RFCs collect open comment threads indefinitely.

The RFC owner synthesizes feedback, makes the call, updates the document with the decision and rationale, and closes it. The document becomes the decision record.

> [!tip] If you're writing an RFC and can't fill in "Alternatives considered," you haven't thought about the problem long enough. The alternatives section is where the real thinking happens.

@feynman

Like a design document review at a company like Google or Amazon — the meeting, if there is one, is a formality after the real work happened in the doc.

@card
id: cpe-ch07-c006
order: 6
title: The Decision Log
teaser: A decision log makes "why did we do X" a query, not an interview — every significant technical choice recorded in one place with context, date, and owner.

@explanation

Teams without a decision log accumulate what is sometimes called "archaeology debt" — the cost of reverse-engineering why things are the way they are. A decision that took a day to make gets re-litigated across multiple conversations because no one wrote it down. New engineers make the same mistakes their predecessors made because the reasons for past choices aren't accessible.

A decision log is a lightweight, persistent document where significant decisions are recorded.

Each entry has:
- **Date** — when was this decided?
- **Title** — a short, searchable description. "Switch auth tokens from HS256 to RS256" not "auth changes."
- **Context** — one paragraph on the situation that drove the decision.
- **Decision** — what was decided. Be specific. "We will use RS256 JWTs signed with a rotating key pair managed by Vault."
- **Rationale** — why this option over the alternatives.
- **Who decided** — the person or group who made the call.
- **Links** — to the RFC, PR, or Slack thread where the discussion happened.

What belongs in the decision log:
- Architecture choices with multi-year implications.
- Technology selections (this library over that one).
- Decisions to accept known technical debt intentionally.
- Policy decisions (when we do code review, branching strategy, deployment windows).

What doesn't belong:
- Day-to-day implementation choices.
- Decisions that will be revisited in days anyway.

> [!info] The decision log is most valuable six months after a decision, when the person who made it has moved on or forgotten the context. Write for that future reader.

@feynman

Like git blame, but for architectural choices — the log tells you who decided what and why, without having to read the commit history hoping for a useful message.

@card
id: cpe-ch07-c007
order: 7
title: Write It So No One Has to Ask
teaser: Every question a teammate asks that is answered by documentation that doesn't exist yet is a documentation bug — it has a root cause and a fix.

@explanation

Most documentation gets written after someone asks a question for the third time. The cost of that pattern is paid by everyone who asked before the third time, and by the engineer who had to answer the same question three times.

The better frame: every question is a documentation bug. When someone asks "how do I run the integration tests locally?", the answer to that question belongs in a README, a runbook, or an onboarding doc. When someone asks "what does the `--dry-run` flag do on the deploy script?", the answer belongs in the script's help output or comments.

The practical workflow:

1. When you answer a question verbally or in Slack, pause before responding. Ask: "where should this answer live?"
2. Write the answer in the right place first — the README, the runbook, the code comment, the onboarding doc.
3. Send the link, not the prose. "I just added this to the runbook: [link]"

This takes 5–10 extra minutes per question the first time. It eliminates the question for everyone who comes after.

What to document proactively:
- Local development setup (the most common pain point for new engineers).
- Non-obvious environment variables and their effects.
- The "why" behind surprising architectural choices.
- Known sharp edges — things that will break in non-obvious ways.
- How to run tests, how to deploy, how to roll back.

> [!tip] If you find yourself writing the same Slack message more than once, that message belongs in a doc. Move it; then paste the link in Slack.

@feynman

Like a well-maintained FAQ — it doesn't answer the question after the fact, it answers it before anyone has to ask.

@card
id: cpe-ch07-c008
order: 8
title: Async Code Review Culture
teaser: Code review becomes a source of friction when timing expectations are undefined — async review culture is about setting clear windows, not reading minds.

@explanation

Code review is inherently async, but most teams treat it as pseudo-synchronous — the reviewer is supposed to respond quickly, but there's no agreement on what "quickly" means. The result is either constant review-request pings or PRs sitting for days without comment.

The patterns that make async review work:

**Defined review windows.** The team agrees on what a normal review turnaround looks like. "We aim to give first-pass feedback within one business day" is a policy. Without it, every review is a negotiation.

**The "not blocking" tag.** Reviewers distinguish between comments that must be addressed before merge and comments that are suggestions or nitpicks. A clear signal (a label, a comment prefix, or a specific word like "nit:") means the author doesn't have to ask "is this blocking?" for every comment.

**Review request etiquette.** When you request review, give context. "This PR changes the retry budget for external API calls — focused review on the backoff logic would be most useful" is more respectful of the reviewer's time than dropping a link with no context.

**PR size discipline.** Large PRs are a structural barrier to async review. A PR that takes three hours to review properly generates sync pressure — it's easier for the reviewer to ask for a walkthrough than to read it cold. Keep PRs small enough that a competent reviewer can give a first pass in 20–30 minutes.

**Response to review.** When you address review comments, reply to each one. "Done" or "Addressed in 8f3a2d" on each comment closes the loop asynchronously and prevents a follow-up "did you handle my feedback?" message.

> [!warning] Responding to review comments by pushing new commits without replying to the comments is the fastest way to create a second round of sync review. Close the loop in writing.

@feynman

Like a well-structured pull request workflow — the contract between author and reviewer makes async coordination possible without a status call.

@card
id: cpe-ch07-c009
order: 9
title: Time-Zone Respectful Async
teaser: "Can we chat?" is a synchronous request disguised as a question — time-zone respectful async replaces it with "please respond by," which respects the recipient's schedule.

@explanation

Distributed teams break down not because people are in different time zones, but because they communicate as if they aren't. The most common failure mode: a message sent at 9 AM in one time zone arrives at 11 PM in another, and the sender is blocked waiting for a response that won't come for eight hours because they never specified what they actually needed.

The pattern: replace "can we chat?" with a structured async request.

Instead of:
```
"Hey, are you free for a quick call about the migration plan?"
```

Write:
```
"I'm making a call on the migration plan by Thursday EOD PT.
Would you review this doc and leave comments on the timeline
section before then? [link] — specifically the rollback
window estimate. Let me know if Thursday is too tight."
```

The second version:
- Contains the full context (migration plan, specific section).
- States a concrete ask (review and comment).
- Gives a deadline with time zone specified.
- Names what the decision hangs on (rollback window).
- Acknowledges the deadline might not work and opens the door to adjust.

Conventions that make time-zone async work:
- Always include the time zone on any deadline. "By Thursday" is ambiguous across time zones; "Thursday 5 PM UTC" is not.
- Establish "core overlap hours" for the team — a 2–3 hour window where everyone is expected to be online. Meetings live there; everything else is async.
- Treat responses outside overlap hours as a bonus, not an expectation.

> [!info] "Async by default, sync during overlap" is a policy, not a courtesy. Make it explicit in team norms so no one has to guess.

@feynman

Like a well-structured API request — you include everything the server needs to respond without a round-trip to ask what you meant.

@card
id: cpe-ch07-c010
order: 10
title: When Async Escalates to Sync
teaser: Async has a failure mode — some problems require real-time back-and-forth to resolve, and the skill is recognizing which ones before you've wasted a day on a thread.

@explanation

Async-first doesn't mean async-always. The failure mode is grinding through a document thread or Slack conversation on a problem that needed a 15-minute conversation to resolve. The cost is real: by the time the participants agree to get on a call, they've spent more time on the failed async than the call would have taken.

Criteria that signal escalation to sync:

**High ambiguity, high stakes.** If the outcome of a decision is hard to reverse and the proposal is being read differently by different reviewers, a call is faster than cycling through draft revisions.

**Emotional signal.** If the tone of comments is escalating, or someone has expressed frustration, the medium is wrong. Emotional conversations don't resolve well in text.

**More than two rounds of back-and-forth.** If you've exchanged three or more messages and the question isn't resolved, the communication isn't converging. Stop and sync.

**Blocking the team.** If the async discussion is holding up a deploy, a merge, or another team's work, the cost of waiting for async resolution has exceeded the cost of interrupting schedules for a call.

**New information mid-thread.** If a comment surfaces a constraint that changes the problem framing fundamentally, the existing thread is obsolete. Sync to reset.

The escalation message: "I think we should sync on this — a 15-minute call will get us further than this thread. I'll set something up during our overlap window."

> [!tip] When you escalate to sync, summarize the async thread before the call so everyone arrives with the same context. Don't re-read the thread on the call.

@feynman

Like a debugger breakpoint — most of the time you run the program straight through, but you drop into interactive mode exactly when the state is too complex to reason about statically.

@card
id: cpe-ch07-c011
order: 11
title: Thread Discipline in Slack
teaser: Threads are the unit of async organization in Slack — flooding a channel with sequential messages instead of threading is the equivalent of console-logging every variable in production.

@explanation

Unthreaded Slack channels are the async equivalent of a noisy open-plan office — high information, low signal, constant ambient cost. Thread discipline is the primary lever for fixing this.

The rule: any message that is a response to, or continuation of, a prior message lives in the thread of that message. A new top-level message is for a new topic.

Why this matters:
- Threads keep the context together. Someone catching up later can read the full thread instead of scrubbing a channel timeline.
- Threads reduce channel noise. A six-message technical discussion takes one slot in the channel; without threading, it takes six.
- Threads make it clear when a topic is resolved. A thread that ends in "great, done" is closed. A channel full of unthreaded messages has no resolution signal.

Thread patterns that work:
- Post the initial question or announcement in the channel.
- All follow-up replies, including "thanks," clarifications, and answers, go in the thread.
- If the thread produces a decision or an action item, post a short summary message in the thread and optionally a brief "resolved" note in the channel.

Channel hygiene:
- Separate channels for separate concerns. One channel for deploys, one for incidents, one for general engineering. Cross-posting noise is a sign the channel structure is wrong.
- Archive inactive channels. Ghost channels with no traffic for 60 days add ambient confusion.
- Pin important decisions, runbook links, and recurring references to the channel. Pinned messages answer "where do I find X" without a thread.

> [!info] "Send to channel" on a thread reply should be rare. It's the right choice when the thread resolution is relevant to people who didn't join the thread — and wrong in most other cases.

@feynman

Like git commits — individual changes belong in commits (threads), not all in one giant staging area (the channel).

@card
id: cpe-ch07-c012
order: 12
title: Anti-Pattern: The Meeting That Should Have Been a Doc
teaser: A meeting exists to do something that only real-time interaction can do — when the meeting could be replaced by a document with a comment deadline, it should be.

@explanation

The most common async failure in engineering organizations is not the refusal to go async — it's the inability to identify which meetings don't need to exist.

Meetings that should be docs, and what to replace them with:

**The status update meeting.** Fifteen people gather to hear reports on project status that each person could have written in five minutes. Replace with: a shared status doc where each team posts an async update by Monday morning. Readers read it when it fits their schedule.

**The decision briefing.** A lead presents a decision they've already made to a group that has no real input. Replace with: a brief email or Slack message announcing the decision with the rationale. Save the meeting slot.

**The design review where no design has circulated beforehand.** Participants arrive cold, the first 20 minutes is context transfer, and the remaining 10 minutes is rushed feedback. Replace with: a doc circulated 48 hours before with a comment deadline. The live review (if held at all) handles only the unresolved questions.

**The recurring sync that has become habit.** A weekly meeting that was useful six months ago but now runs out of content by the 20-minute mark. Replace with: cancel it. Replace with an async standup or status post if the signal is still needed.

The test for whether a meeting should be a doc:

- Is the interaction read-only? (Status updates, announcements) — use a doc.
- Does a decision need live back-and-forth? — maybe a meeting.
- Could the back-and-forth happen via comment thread with a deadline? — use a doc.
- Is there emotional or interpersonal complexity? — use a meeting.

> [!warning] Defaulting to a meeting because writing the doc feels like more work is the most expensive form of laziness in a distributed team. The doc's cost is paid once; the meeting's cost is paid by every attendee, every recurrence.

@feynman

Like running a database query without an index — it works, but it forces a full scan of everyone's schedule when a targeted read would have been cheaper.
