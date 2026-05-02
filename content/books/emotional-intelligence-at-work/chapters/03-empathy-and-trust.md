@chapter
id: eiw-ch03-empathy-and-trust
order: 3
title: Empathy, Reading the Room, and Building Trust
summary: Empathy in engineering is understanding the upstream/downstream perspective — the constraint your PM is under, the context the on-call engineer was in. Trust is built in small consistent acts, not grand gestures.

@card
id: eiw-ch03-c001
order: 1
title: Empathy in Technical Settings
teaser: Empathy at work isn't about feelings — it's about modeling the constraint space the other person is operating in.

@explanation

In a technical context, empathy is a reasoning skill before it's a relational one. It means holding a model of the pressures, information, and incentives another person has — and using that model to predict what they need, why they made a decision, or why a conversation is going sideways.

Your PM who keeps changing the scope isn't irrational. They're downstream of a sales call or an executive decision that you haven't seen. Your on-call colleague who shipped a quick workaround instead of a clean fix wasn't being lazy — they were managing the blast radius of a 2am incident with limited options.

Understanding upstream and downstream perspectives means:
- Upstream: who handed this person the problem, and what constraints came with it?
- Downstream: who does this person's work affect, and what do they need from it?
- What information is this person missing that I have, and vice versa?

This is not about agreeing with every decision. It's about having an accurate model of why the decision was made before you respond to it. An accurate model makes your pushback more effective — you're addressing the real constraint, not a caricature.

> [!info] Empathy in a technical setting is closer to systems thinking than emotional support. You're modeling the state of another node in the system.

@feynman

Like reading a stack trace — you're not just seeing the error at the top, you're tracing back through the call frames to understand what constraint the code was operating under when it failed.

@card
id: eiw-ch03-c002
order: 2
title: The User's Actual Problem vs the Technical Problem as Stated
teaser: The problem as stated is a symptom. The actual problem is the goal the person had before they hit this obstacle.

@explanation

When someone files a bug, writes a ticket, or asks for a feature, what they hand you is a proposed solution dressed up as a requirement. "Can you add a CSV export button?" is not the problem — it's one possible answer to an unstated problem. The actual problem might be: "I need to get this data into my finance team's spreadsheet every Monday."

If you build exactly what's asked, you've answered the symptom. If you understand the actual problem, you have options:
- Build the CSV export — works, but may be the expensive path.
- Point at the existing API that the finance system can call directly — solves it without new UI.
- Ask one question and save both teams a week of work.

This matters for engineers because we're expensive problem-solvers. Solving the wrong problem efficiently is waste. The gap between "problem as stated" and "actual problem" is where most over-engineering lives.

Practical habits:
- Before estimating, ask: "What's the outcome you need? What breaks if you don't have this?"
- Look at what the user does immediately after the thing you built — that often reveals the real goal.
- When a request seems oddly specific, the specificity is usually cargo-culted from a previous partial solution.

> [!tip] "What are you trying to do with this?" is one of the highest-ROI questions an engineer can ask. Ask it before writing a line of code.

@feynman

Like a doctor who asks "what made you come in today" instead of immediately treating whatever symptom the patient mentions first — the stated symptom is an entry point, not a diagnosis.

@card
id: eiw-ch03-c003
order: 3
title: Reading the Room: Meeting Dynamics and Power
teaser: Every meeting has a social topology — who holds power, who's uncomfortable, who's performing versus who's deciding. Missing that topology makes you less effective.

@explanation

Meetings are not just information exchanges. They're negotiations, performances, and decision arenas running simultaneously. Technical people who treat meetings as purely informational miss half of what's happening.

The signals worth tracking:

**Who talks last.** In many organizations, the highest-status person defers their opinion until others have spoken. They're not withholding — they're shaping. The last opinion often determines what gets decided.

**Who's gone quiet.** If someone who usually engages has stopped contributing, they're either disengaged, uncomfortable, or have already made up their mind. Either way, their silence is data.

**When the energy changes.** A topic that was moving fast suddenly slows — someone in the room has a concern they haven't voiced yet. The room is waiting for them to say it, or waiting for someone to give them permission to.

**The body language of rank.** People orient toward whoever they perceive as most senior, even in flat organizations. Watch where people look when they're uncertain — that's who they think holds the decision.

Reading the room doesn't mean playing politics. It means having an accurate model of what's happening so you can communicate more effectively — knowing when to push, when to wait, and when to name the thing nobody has said yet.

> [!warning] Misreading a meeting as purely technical when it's actually about organizational approval means you'll optimize for the wrong outcome. Good technical arguments lose to unaddressed organizational concerns all the time.

@feynman

Like reading a diff with context lines — you can apply the patch without the context, but the context is what tells you whether the change is safe.

@card
id: eiw-ch03-c004
order: 4
title: The Async Tone Problem
teaser: Text strips the metadata that prevents misreading — no tone, no pacing, no facial expression. The receiver fills that gap with their current mood.

@explanation

Written communication drops roughly 80% of the signal present in spoken conversation. Tone of voice, pacing, facial expression, and body language all carry information about intent. Async text has none of that. What's left is ambiguous — and the reader's brain fills in the missing metadata with whatever emotional context they happen to be in when they read it.

A message that the sender wrote in a neutral, focused state reads differently to someone who's stressed, or who had a difficult conversation with the sender last week.

What this produces in practice:
- A direct message reads as curt or passive-aggressive when it was just efficient.
- A message with hedging language reads as weak when it was just careful.
- A question reads as an accusation when the context is a recent conflict.
- Enthusiasm in uppercase reads as shouting in a tense thread.

What to do about it:

- Add one sentence of framing before the ask: "Saw this in the code review, wanted to flag it — not urgent:" changes how the next line lands.
- Use explicit tone signals where the message could go either way: "I'm genuinely curious here, not pushing back" is not redundant — it's error correction for a lossy channel.
- If something reads as aggressive in your inbox, ask yourself what the neutral interpretation is before responding to the aggressive one.
- When something needs precision, use a call. Async text is a poor medium for anything where the stakes of misreading are high.

> [!info] Async text is a lossy channel. Adding redundancy — a sentence of context, an explicit tone signal — is not over-explaining. It's compensating for channel loss.

@feynman

Like sending data over a noisy network without checksums — the payload arrives but the error bits are undetected, and the receiver reconstructs whatever makes sense to them locally.

@card
id: eiw-ch03-c005
order: 5
title: When a Slack Message Is More Loaded Than It Appears
teaser: Some messages carry subtext. Missing the subtext means responding to the surface and not addressing what's actually happening.

@explanation

Not every "just checking in on this" is a neutral status inquiry. Organizational context, relationship history, and timing all load messages with meaning beyond their literal content.

Patterns that signal a loaded message:

**The public poke.** A question asked in a public channel that could have been a DM. It's not primarily a question — it's a signal. The sender wants visibility into whether the thing is being handled, or they want others to see that they asked.

**The short reply to a long message.** You sent a detailed async update. You get "ok." That's not acknowledgment — that's unresolved tension or disagreement expressed as disengagement.

**The escalation-shaped question.** "Do you know if leadership is aware of this?" is almost never a genuine information request. It's a warning that escalation is being considered.

**The "just wanted to make sure" opener.** It's almost always covering for "I don't think this is on track and I want to say so without saying so."

**The late-night message with no urgency.** Someone sends you a non-urgent work message at 11pm on a Tuesday. That's not about the work — it's about their own state. Responding immediately is optional and potentially counterproductive.

Reading these signals doesn't mean assuming bad intent. It means responding to the real communication, not just the surface text. A loaded message usually wants acknowledgment of the underlying concern, not just an answer to the literal question.

> [!tip] When a message feels off, address the surface and add one line that opens the door: "Happy to jump on a call if there's something broader to discuss." It signals that you read between the lines without forcing the person to expose their real concern in writing.

@feynman

Like a compiler warning that doesn't block the build but is pointing at something real — you can ship past it, but it's worth reading before you do.

@card
id: eiw-ch03-c006
order: 6
title: Building Trust Through Small Consistent Acts
teaser: Trust isn't built in a crisis — it's the balance in an account you've been making deposits into for months.

@explanation

The trust account metaphor: every interaction is either a deposit or a withdrawal. Small deposits — doing what you said you'd do, responding when you said you would, flagging a problem early — accumulate. Withdrawals — missing commitments, surprising people with bad news, being inconsistent — draw the balance down.

Grand gestures don't build trust. A 90-hour crunch week that saves a launch creates goodwill, but it doesn't build the baseline trust that comes from consistent behavior at normal operating tempo. The crisis performance is visible; the consistent small acts are what people rely on.

Specific deposits that compound:

- **Following through on small things.** "I'll send you that link" and then actually sending it. Not a big thing — but the pattern of small follow-throughs builds a model of reliability.
- **Predictability under pressure.** If someone can predict how you'll behave in a hard conversation, they'll have harder conversations with you. Unpredictability makes people defensive.
- **Flagging problems early.** The engineer who surfaces a risk two weeks before it becomes a crisis is a trust asset. The engineer who surfaces it the day before a deadline is a liability, even if the risk was the same.
- **Not optimizing your own outcomes at others' expense.** Taking the unglamorous task. Not over-promising to look good in a planning meeting.

The account metaphor matters because it explains why trust takes time and can be spent quickly. A single high-stakes inconsistency can zero out months of deposits.

> [!info] Trust is a lagging indicator. It reflects behavior over time, not performance in any single moment. That's why rebuilding it is slow — the account has to be refilled one deposit at a time.

@feynman

Like a credit score — built slowly through a long history of mundane, consistent behavior, and much easier to damage in a single event than to raise over months.

@card
id: eiw-ch03-c007
order: 7
title: Trust vs Liking: A Critical Distinction
teaser: You can trust someone's work and judgment without enjoying their company. Conflating the two makes both worse.

@explanation

Trust and liking are separate dimensions. High trust, low liking is the colleague you'd want on your incident call but would never choose for lunch. Low trust, high liking is the person who's fun to work with but whose estimates you can't rely on. The confusion between them causes real dysfunction.

In engineering teams, conflating trust and liking produces:

- **Talent mis-allocation.** Assigning critical work to people you like, rather than people you trust to deliver it — and calling this "culture fit."
- **Overvaluing social fluency.** Engineers who are socially smooth get treated as more reliable than their track record warrants. Engineers who are direct or awkward get treated as less reliable than their track record warrants.
- **Avoidance of necessary friction.** If you can't separate "I don't enjoy working with this person" from "this person is wrong," you'll either suppress useful disagreement or amplify unnecessary conflict.

Working effectively with people you don't like requires two things:
- A clear model of what you do trust them on. Even a difficult colleague usually has a domain where their judgment is sound. Use that.
- Keeping interactions scoped to work. You don't have to resolve the personal friction — you just have to not let it contaminate the professional interaction.

The inverse matters too: liking someone is not a substitute for checking their work. Trust has to be earned through track record, not assigned through affinity.

> [!warning] "We work well together" and "we get along" often mean different things. Make sure you know which one you mean when it counts.

@feynman

Like using a library you don't enjoy reading the source of — you don't have to like it to rely on it, and trusting its interface doesn't mean you'd maintain it.

@card
id: eiw-ch03-c008
order: 8
title: The Trust-Destroying Behaviors
teaser: Most trust damage is not from big betrayals — it's from a pattern of small, predictable behaviors that signal someone optimizes for themselves.

@explanation

Trust erodes through a set of recognizable patterns. Most engineers have worked with someone who exhibits these and knows exactly how it felt to rely on them.

**Inconsistency.** The most fundamental trust-destroyer. Behaving differently depending on who's watching, what's at stake, or what the incentives are. Teams stop relying on people who are only consistent when it's convenient.

**Taking credit.** Presenting shared work as individual work. Letting a narrative of solo contribution stand when the reality is collaborative. This is often subtle — not outright lying, just not correcting the record. Teams track this carefully.

**Blame-shifting.** When something goes wrong, the first move is external attribution. The spec was unclear. The other team didn't deliver. This is a powerful trust signal — it tells observers that this person will shift the blame to them next time.

**Selectively sharing information.** Withholding context that would change how someone else makes a decision. This can be passive — not mentioning a known risk — or active — framing information to produce a desired outcome. Either way, people eventually notice.

**Over-promising.** Consistently committing to more than can be delivered, then underdelivering. Often motivated by wanting to look ambitious or to win a planning conversation. The net effect is that estimates become worthless and planning becomes harder for everyone.

What makes these behaviors so damaging is that they're predictable. Once someone has done one of these things, the team builds a model: this person optimizes for themselves. That model then filters every future interaction.

> [!warning] You can apologize for a single incident. A pattern is different — it takes sustained counter-evidence over time to update the model, and most people won't wait around for that.

@feynman

Like a service that has an occasional timeout — annoying but manageable. A service that lies about its error state is pulled from production, because you can't build anything reliable on top of something you can't trust to tell you the truth.
