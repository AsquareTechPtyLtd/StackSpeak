@chapter
id: eiw-ch04-feedback-and-difficult-conversations
order: 4
title: Feedback and Difficult Conversations
summary: The SBI model (Situation-Behavior-Impact) makes feedback specific and non-judgmental. Receiving feedback well is a separate skill from giving it. Difficult conversations follow a structure — they don't have to be improvised.

@card
id: eiw-ch04-c001
order: 1
title: Giving Feedback: The SBI Model
teaser: Situation, Behavior, Impact — a three-part structure that makes feedback specific, observable, and non-judgmental.

@explanation

Most feedback fails not because the giver is wrong, but because the delivery triggers defensiveness before the message lands. The SBI model addresses this by forcing precision at every step.

The three components:

- **Situation:** When and where did this happen? Anchor the feedback to a specific event, not a pattern you've inferred. "In yesterday's architecture review" is a situation. "You always" is not.
- **Behavior:** What did the person actually do or say? Observable actions only — not intentions, not character. "You interrupted three people before they finished their sentences" is a behavior. "You were dismissive" is an interpretation.
- **Impact:** What was the concrete effect? On the team, the project, the meeting, the output. "Two engineers stopped contributing for the rest of the session" is an impact. "It felt bad" is not.

What SBI eliminates:

- Ambiguity about what specifically needs to change
- Character attacks that put people on defense
- Vague positives that feel hollow ("great job this sprint")

The model works equally well for positive and corrective feedback. A positive SBI ("In the incident review on Tuesday, you walked us through the timeline without assigning blame, and the team left with action items instead of anxiety") is more useful than "you're good at that stuff."

> [!tip] If you can't fill in all three slots concretely, you're not ready to give the feedback yet. Vagueness is a signal to observe more before speaking.

@feynman

Like a well-formed bug report: reproduce steps (Situation), observed behavior (Behavior), expected vs. actual outcome (Impact) — no speculation about why the bug exists.

@card
id: eiw-ch04-c002
order: 2
title: Timing and Frequency of Feedback
teaser: Feedback loses fidelity the longer it sits. The best time is close to the event — the second-best time is now.

@explanation

Delayed feedback has two failure modes. First, the memory of the specific event degrades — for both parties. You lose the detail that makes SBI work; the receiver can't recall the context well enough to evaluate what you're saying. Second, the accumulation problem: feedback held for weeks tends to arrive as a summary judgment rather than a specific observation, which is exactly the form most likely to land as an attack.

Timing principles that hold up in practice:

- **Give it while the situation is fresh.** Within 24–48 hours is ideal for corrective feedback. Positive feedback can be immediate.
- **Don't give it in the heat of the moment.** If you're still reactive, wait until you can describe behavior without loaded language. Hours, not weeks.
- **Frequency matters more than completeness.** Small, regular feedback loops are more effective than a comprehensive annual download. Code review is the engineering team's best-functioning feedback mechanism for exactly this reason — it's continuous, not batched.
- **Don't save it for the 1:1.** The 1:1 is for discussion and coaching, not for delivering feedback that should have been given three weeks ago.

The frequency point has organizational implications. Teams that give feedback only in performance cycles produce engineers who are surprised by their ratings. Teams that normalize short-loop feedback produce engineers who course-correct continuously.

> [!warning] Saving a list of corrective feedback items for a formal review is a management failure, not a scheduling preference. By the time it's delivered, the receiver can't act on most of it.

@feynman

Like CI/CD vs. release-train deploys — the smaller and more frequent the feedback loop, the cheaper it is to fix the defect.

@card
id: eiw-ch04-c003
order: 3
title: Code Review as a Feedback Delivery System
teaser: Code review is the highest-volume feedback channel on most engineering teams — and the SBI principles apply directly to how review comments land.

@explanation

Code review comments are feedback. They arrive in writing, often asynchronously, without tone of voice or body language to soften or clarify intent. That makes precision more important, not less.

The SBI mapping to review comments:

- **Situation:** the specific line, block, or file. Good review tools make this automatic — the comment is anchored to the code. Don't write a comment that could have been left anywhere.
- **Behavior:** what the code does, not what the author intended. "This function reads the database inside a loop" is behavior. "You clearly didn't think about N+1 queries" is interpretation.
- **Impact:** what the observable consequence is. "This will add one query per row returned by the outer query — at 1,000 rows that's 1,001 database calls per request" is impact. "This is inefficient" is a judgment.

Additional conventions that reduce friction:

- Prefix nits with `nit:` so the author knows scale. "nit: rename `res` to `response` for clarity" is a small thing; don't make it feel large.
- Separate blocking from non-blocking feedback. "This needs to change before merge" and "I'd do this differently but I'm not blocking on it" are different statements. Make the distinction explicit.
- Ask questions before making accusations. "Was there a reason to skip the cache here?" opens a conversation. "Skipping the cache is wrong" closes it.

> [!info] Harsh code review culture is an EI failure masquerading as a technical standards problem. The fix is SBI precision, not softer standards.

@feynman

Like writing a clear, reproducible bug report instead of "this is broken" — the precision protects the relationship and gets the problem fixed faster.

@card
id: eiw-ch04-c004
order: 4
title: Receiving Feedback: Separating Message from Messenger
teaser: How feedback is delivered is a separate variable from whether it's true. Conflating the two gets you defensive about accurate signals.

@explanation

Receiving feedback well is a skill that most engineers don't practice explicitly, because the receiving side feels passive. It isn't. The quality of your receiving determines whether you benefit from the signal.

The core move is separating two questions:

1. Is this feedback accurate? Does it describe something real about my behavior or output?
2. Was it delivered well? Was the delivery respectful, specific, timely?

These questions have independent answers. Feedback can be accurate and poorly delivered. It can be well-delivered and wrong. Conflating them is the default failure mode — people dismiss accurate feedback because the delivery was rough, or accept inaccurate feedback because it arrived politely.

Receiving practices that work:

- **Listen to completion before responding.** Interrupting to defend is a reflex, not a strategy.
- **Ask for specifics if they weren't given.** "Can you give me an example of where you saw that?" is a request for data, not a challenge.
- **Acknowledge before evaluating.** "I hear you saying X" is not agreement — it's confirmation that you understood what was said. Do it before you decide whether it's right.
- **Give yourself processing time.** "Let me think about this and come back to you" is a complete and acceptable response, especially for feedback that stings.
- **Evaluate it later, privately.** Once you're out of the conversation, ask: is there something true here? Even if only 10% is accurate, what's that 10%?

> [!tip] The most defensible response to any feedback is curiosity. "Tell me more about what you observed" buys time, gets more data, and signals that you take the input seriously.

@feynman

Like debugging with a colleague who found a bug in your code — your goal is to understand the bug, not to defend the code.

@card
id: eiw-ch04-c005
order: 5
title: Using Even Bad Delivery: Extracting Signal from Poorly-Delivered Criticism
teaser: The signal exists independently of the noise. Skilled receivers extract useful information even from criticism that arrives badly packaged.

@explanation

Poorly-delivered feedback is common. Someone delivers criticism in a meeting instead of privately. They use sweeping generalizations. They're visibly frustrated and it bleeds into the words. The instinct is to dismiss the whole thing because the delivery was wrong.

That instinct is expensive. Bad delivery doesn't make the underlying observation false.

The extraction process:

- **Strip the emotion from the statement.** "That was a terrible design, you clearly didn't think about scalability" contains a signal: someone believes the design has scalability problems. That's worth investigating regardless of the tone.
- **Look for the specific.** Even a poorly-formed criticism usually contains one concrete thing. Find it. "The schema change will break every existing query" is specific; the surrounding anger isn't the point.
- **Assume positive intent as a working hypothesis.** People rarely deliver bad feedback because they want to harm you. They're usually frustrated, under pressure, or just not skilled at feedback. Assuming malice closes the conversation; assuming frustration keeps it open.
- **Respond to the content, not the delivery.** In the moment, address the technical or behavioral point. "You're right that I didn't model the query volume — let me look at that." You can address the delivery separately, privately, later.

None of this means tolerating disrespectful treatment as a baseline. Repeated patterns of hostile feedback warrant a direct conversation about how you'd like to receive input. But that's a separate conversation from evaluating whether today's criticism was correct.

> [!warning] Dismissing feedback because the delivery was bad is a self-protection reflex that limits growth. The delivery is a separate problem to address, not a reason to drop the content.

@feynman

Like reading a poorly formatted log file — the format is annoying, but the error message is still in there, and that's what you need.

@card
id: eiw-ch04-c006
order: 6
title: Difficult Conversations in Engineering
teaser: Architecture disagreements, performance issues, and teammate conflict all follow the same structure — the subject matter changes, the approach doesn't.

@explanation

"Difficult conversation" in engineering most often means one of three things:

**Architecture disagreement.** Two engineers have fundamentally different views on how to build something. The technical dimension is real, but the interpersonal dimension — who has authority, who feels heard, who is willing to change position — determines whether the team reaches a good decision or just the decision of whoever is most persistent.

**Performance issues.** Telling a peer or direct report that their work quality, output speed, or reliability isn't meeting expectations. The difficulty here is the personal stakes — it feels like an attack on identity, not a description of a gap.

**Teammate conflict.** Two people on the same team are producing friction — blocking each other's work, undermining each other in meetings, failing to communicate. Left unaddressed, it scales to a team morale problem.

What these have in common:

- Avoiding them increases the cost of resolution over time.
- The conversation itself is rarely as damaging as the anticipation of it.
- Both parties usually know something is off before it's named.
- The outcome depends on how the conversation is structured more than how the participants feel about each other.

The conversation structure is the same across all three types: establish shared context, describe the specific observation, explain the impact, state the desired outcome. What changes is the subject, not the frame.

> [!info] The most common mistake with difficult conversations is conflating the discomfort of having them with the harm of having them. The discomfort is real; the harm is usually smaller than anticipated.

@feynman

Like exception handling — the error type changes, but the catch-and-respond structure is the same regardless of what threw.

@card
id: eiw-ch04-c007
order: 7
title: Preparing for a Difficult Conversation
teaser: Structure the conversation before you start it — context, specific observation, impact, desired outcome. Improvisation is where difficult conversations go wrong.

@explanation

Difficult conversations fail most often in preparation, not execution. Walking in with a vague sense of grievance and no specific example is a recipe for a conversation that gets defensive fast and produces nothing.

The preparation structure:

- **Context:** Set the frame. Why are you having this conversation? "I wanted to talk about something I noticed in last week's sprint because I think it's worth addressing directly" tells the person what to expect and signals good intent.
- **Specific observation (SBI):** Have one specific, behavioral example ready. Not a pattern summary ("you always do X"), not an interpretation ("you seem unengaged"), but one observable instance. If you can't name one, you're not ready to have the conversation.
- **Impact:** Know what the concrete effect was. On the team, the project, the relationship, the output. The impact is what justifies having the conversation at all.
- **Desired outcome:** Know what you're asking for. A behavior change? An explanation? A joint decision? Walking in without knowing what you want is how conversations end with no resolution. "I'd like us to agree on how we'll handle architecture decisions going forward" is an outcome. "I just needed to say something" is not.

Write it down before you go in. Not a script to read — a set of anchors to come back to when the conversation gets uncomfortable and you lose the thread.

A final step: anticipate their perspective. What might they say? What's true in their view? What don't you know? Going in with only your side of the story makes you rigid; anticipating their position makes you responsive.

> [!tip] If you find yourself unable to name the desired outcome, ask whether you're trying to solve a problem or process an emotion. Both are valid — but they're different conversations.

@feynman

Like writing a design doc before a technical review — you may not follow it line by line, but preparing it forces you to clarify what you actually want to say.

@card
id: eiw-ch04-c008
order: 8
title: Escalation Criteria
teaser: Most conflicts between ICs should be resolved between ICs. Escalation is for the cases where that isn't possible — and knowing the difference matters.

@explanation

Escalating too early creates two problems: it signals that you can't handle peer-level conflict, and it puts the manager in a position of solving something they have less context on than you do. Escalating too late allows situations to calcify into team-wide problems.

The decision is clearer with explicit criteria.

Resolve it between ICs when:

- The disagreement is about approach, priority, or technical direction, and both parties are willing to engage.
- The conflict is a one-time or recent pattern, not a long-running dynamic.
- You've had a direct conversation and there's forward momentum, even slow.
- The issue affects the two of you but not the broader team's ability to deliver.

Escalate to a manager when:

- A direct conversation has happened and produced no change.
- The behavior is affecting team output or team morale beyond the two of you.
- There's a power imbalance that makes direct resolution unlikely (seniority gap, or the other person controls something you depend on).
- The issue involves conduct — harassment, discrimination, repeated disrespect — which is never IC-to-IC to resolve.
- You're at an impasse on a decision that needs to be made and can't be stalled further.

What escalation is not:

- A complaint session about a peer.
- A way to have the manager resolve a conversation you haven't tried to have.
- An attempt to have someone declared the winner of a technical argument.

When you do escalate, bring context, specific observations, and your desired outcome. The manager will ask; having them ready signals that you're problem-solving, not venting.

> [!info] A manager who hears "I already talked to them directly and here's what happened" can act. A manager who hears "I haven't said anything to them" will usually send you back to try.

@feynman

Like an on-call escalation policy — you resolve what you can at tier one, escalate with a summary of what you tried, and don't page the on-call engineer before you've read the runbook.
