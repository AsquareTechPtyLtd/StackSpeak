@chapter
id: cwd-ch10-building-the-habit
order: 10
title: Building the Habit
summary: Good data communication is a craft, not a talent. The patterns that turn deliberate practice into fluency — the critique habit, the personal chart library, and the team norms that make everyone's charts better over time.

@card
id: cwd-ch10-c001
order: 1
title: The Critique Workshop
teaser: Applying the analytical lens to an existing chart — not to judge it, but to diagnose it — is the fastest way to internalize what good looks like.

@explanation

A critique workshop is a structured exercise: take a real chart from your own work or a public source, then systematically disassemble it using the same questions you'd ask during design.

The diagnostic questions to run in sequence:

- **What is the claim?** If you can't state the chart's argument in one sentence, the chart hasn't made one.
- **Does the encoding support the claim?** Is the right visual channel doing the heaviest work — position for magnitude, color only for categorical difference?
- **What is adding noise?** Gridlines, borders, redundant labels, dual axes, decoration — anything that consumes attention without contributing information.
- **What would the reader need to know that isn't here?** Missing units, missing context, an unlabeled baseline.
- **What is the first thing the eye goes to?** Is that the most important thing? If not, why not?

The critique is not a verdict. It's a structured observation. Run it on five charts a week for a month and the questions start running automatically when you open a chart tool. That automatic questioning is what "having a chart eye" actually means.

> [!tip] Run a critique on your own chart before sharing it. The act of switching from author to critic takes thirty seconds and catches most of the obvious problems.

@feynman

Like a code review checklist run before you open the PR — the discipline of asking the same questions in the same order is what makes the review useful rather than optional.

@card
id: cwd-ch10-c002
order: 2
title: The Five-Second Test
teaser: What the reader takes away in the first five seconds is usually what they'll remember — test that explicitly before shipping.

@explanation

The five-second test is blunt: show someone a chart for five seconds, then ask what they remember. Their answer tells you what your chart is actually communicating — which may be very different from what you intended.

What the test reliably catches:

- **Title-claim misalignment.** The reader remembers the title, not the data. If the title is generic ("Revenue by Region, Q3") they remember nothing. If the title is specific ("Southeast overtook Midwest in Q3"), they remember the finding.
- **Salience failures.** The element the reader mentions first is the most visually prominent element — not always the most important one. If they lead with the legend or a secondary series, the encoding has misfired.
- **Confusing legends.** If the reader can't pair series to labels without searching, the legend is too far from the data.
- **Missing context.** If the reader's first question is "compared to what?" the baseline or benchmark is absent.

Running the test informally is fine. Show a colleague on Slack, give them five seconds, ask one question: "What does this chart say?" The gap between their answer and your intended message is the revision target.

> [!info] Five seconds is calibrated to match the attention a busy reader gives a chart in a dashboard or deck. Designing for the focused reader is designing for an audience that doesn't exist.

@feynman

Like testing your README by asking a new hire to read it for thirty seconds and then explain the project — the summary they produce tells you what the document actually communicates.

@card
id: cwd-ch10-c003
order: 3
title: Deliberate Practice for Data Communication
teaser: Improvement in data communication is not passive — it requires intentional repetition of specific sub-skills with feedback.

@explanation

Deliberate practice, in the sense K. Anders Ericsson documented, means working at the edge of current ability with immediate feedback on errors. For data communication, that translates into a concrete practice structure.

The sub-skills to practice separately:

- **Chart type selection.** Given a described dataset and claim, choose a chart type before opening a tool. Check against a reference. Build pattern recognition without tool-specific friction.
- **Critique without building.** Take one public chart per day and run the diagnostic questions from the critique workshop. Volume builds speed and automaticity.
- **Annotation writing.** Draft a chart title and one-sentence annotation for a dataset you're given. Practice making the claim explicit without hedging.
- **Simplification passes.** Take an over-crowded chart and produce a version that removes every element that doesn't earn its space. Count what you removed.
- **Replication.** Find a chart you admire. Reproduce it from scratch in your tool of choice. Understanding the construction choices by building them is more durable than analyzing them abstractly.

The feedback loop matters as much as the repetition. Practice without feedback produces fluency with bad habits. Use the critique framework, the five-second test, and a colleague's honest reaction as feedback mechanisms — not approval, diagnosis.

> [!warning] Practicing only on new charts prevents you from building the revision reflex. Reworking an older chart you once thought was finished is more instructive than building a new one from scratch.

@feynman

Like practicing scales on an instrument — isolated, deliberate repetition of sub-skills at speed, not only playing full pieces, is what builds the underlying capability.

@card
id: cwd-ch10-c004
order: 4
title: Getting Feedback on Charts
teaser: The useful feedback is specific and diagnostic — not "looks good" or "I don't like the colors," but "I didn't know what to look at first."

@explanation

Most feedback on charts is vague because reviewers don't have a vocabulary for what they're responding to. Your job as the chart author is to ask questions precise enough to generate useful signal.

Who to ask:

- **A domain expert** who didn't make the chart: they'll tell you if the numbers feel right and if the claim is credible.
- **A non-expert colleague**: they'll tell you if the chart is self-explanatory or requires insider context to read.
- **The intended audience directly**: when the chart is headed into a leadership deck, a manager who sits in those meetings is worth more than five data colleagues.

What to ask for:

- "Tell me in one sentence what this chart says." (Reveals what the title and structure are actually communicating.)
- "Where does your eye go first?" (Reveals salience — correct or misfired.)
- "What's missing that you'd want to know?" (Reveals assumed context the author forgot to surface.)
- "Is there anything here you'd question?" (Reveals credibility issues with the data or claim.)

What not to ask:

- "What do you think?" produces aesthetic reactions.
- "Is this clear?" produces "yes" because people don't want to seem slow.
- "Does this look good?" produces color opinions.

> [!tip] Ask for feedback before you're attached to the chart. Once you've spent two hours on a design, the sunk cost makes honest responses harder to hear and act on.

@feynman

Like user testing — the question you ask determines the quality of the signal you get; vague questions produce polite noise, specific questions produce actionable findings.

@card
id: cwd-ch10-c005
order: 5
title: Building a Personal Chart Library
teaser: A personal collection of charts that work — annotated with why they work — is a reference system that compounds over time.

@explanation

A personal chart library is a curated collection of charts you've encountered that solved a communication problem well. It is not a gallery of pretty charts — it is a reference of effective patterns with the reasoning made explicit.

What to collect:

- Charts from publications (The Economist, FT, NYT graphics), industry dashboards, or your own past work where you successfully communicated a difficult claim.
- Charts that solved a specific problem: showing a distribution without a histogram's baggage, communicating uncertainty without confusing confidence intervals, comparing more than two time series without a spaghetti chart.

How to annotate them:

- **The claim:** what the chart argues.
- **The encoding choice:** which channel carries the primary information and why it was the right one.
- **The simplification moves:** what was removed to make the claim readable.
- **The reuse trigger:** the problem shape this chart solves (e.g., "use when comparing ranked items with a range, not a point estimate").

The library becomes useful when it reaches about thirty charts. Below that, the patterns aren't clear. Above thirty, you start recognizing problem shapes and reaching for a reference instead of improvising.

> [!info] A shared team chart library — even ten annotated examples of how this team communicates well — is more valuable than a style guide that covers everything abstractly and nothing concretely.

@feynman

Like a pattern catalog in software engineering — not a rule book, but a named vocabulary of solutions to recurring problems, accumulated deliberately rather than by accident.

@card
id: cwd-ch10-c006
order: 6
title: The Iteration Loop
teaser: First draft → critique → revise → done. The discipline is in running the loop, not in getting the first draft right.

@explanation

Most charts that ship badly weren't designed badly — they were designed once. The iteration loop is the practice of treating the first draft as a starting point, not a deliverable.

The loop:

1. **First draft.** Build the chart to get the data into visual form. Don't optimize. The goal is to see what you're working with.
2. **Critique pass.** Step away from it, then return and run the diagnostic questions: What's the claim? Does the encoding support it? What's adding noise? What would the reader need that isn't here?
3. **One revision.** Address the highest-priority issue from the critique. Usually this is one of: the title isn't the claim, the encoding is wrong for the data shape, or there's too much visual noise. Fix one thing at a time — fixing everything at once makes it harder to evaluate what change produced what improvement.
4. **Second critique.** Run the five-second test if possible. If the chart is clear after the revision, it's done. If not, one more loop.

Most charts need one revision cycle, not five. The discipline is not extensive iteration — it is doing at least one cycle rather than zero.

> [!warning] "Done when the deadline hits" is not done. A chart shipped without a single critique pass is a first draft in production.

@feynman

Like a red-green-refactor loop in TDD — the first pass gets something working, the second pass gets it right; skipping the second pass ships technical debt in every chart.

@card
id: cwd-ch10-c007
order: 7
title: Chart Critique in Team Processes
teaser: PR review for code is standard. PR review for dashboards isn't yet — but the same reasoning applies.

@explanation

A chart that ships to a company-wide dashboard is effectively a commit to shared infrastructure. It will be read by dozens of people, cited in decisions, and is expensive to correct once it's been seen. Treating it as a casual deliverable is the equivalent of skipping code review.

What chart review in a team process looks like:

- **For dashboard changes:** a review step before merging to production, with the same diagnostic questions used in individual critique — claim, encoding, noise, missing context.
- **For presentation charts:** a peer review from someone outside the immediate team, run twenty-four hours before the meeting. Enough time to revise, not enough pressure to skip.
- **For recurring reports:** a quarterly audit of the charts still in rotation. Charts accumulate; few are ever retired. An audit catches charts that no longer reflect the current framing of the business.

What it doesn't need to be:

- A formal committee process.
- A blocker for every chart.
- A design critique that takes longer than building the chart.

The minimum effective version: one colleague, one pass, two questions — "What does this say?" and "What would you remove?" — before any chart with a large audience ships.

> [!tip] If the review process is too heavy, it will be skipped. The standard is "did at least one other person look at this before it shipped," not "did it pass a design committee."

@feynman

Like code review — the value isn't that reviewers catch every bug, it's that the expectation of review changes how carefully the author writes the first draft.

@card
id: cwd-ch10-c008
order: 8
title: The Ruthless Simplicity Habit
teaser: When in doubt, remove. The default move is subtraction, not decoration.

@explanation

Ruthless simplicity is a default, not an absolute. Every element in a chart either earns its space by contributing to the reader's understanding or costs attention without return. The discipline is starting from subtraction rather than addition.

The elements most often removable without loss:

- **Gridlines** — horizontal reference lines at major values are enough; a full grid of minor lines almost never earns its space.
- **Chart borders and panel backgrounds** — the data region doesn't need a box around it.
- **Redundant labels** — a value label on every bar when the y-axis already provides the scale; a legend when the chart has only one series.
- **Dual axes** — almost always removable by faceting or by choosing a single normalized metric.
- **Gradient fills** — a single hue encodes magnitude more accurately than a color gradient that implies a second variable.
- **Decorative icons and logos** — in analytical charts, not in consumer-facing infographics.
- **Sub-titles that repeat the title** — the sub-title should add context, not restate.

The test for any element: cover it. Does the chart lose information? If no, remove it. If yes, keep it.

The habit is not minimalism as aesthetic preference. It is a systematic bias toward clarity over completeness — motivated by the knowledge that readers skim, time is short, and the cognitive cost of noise is real.

> [!info] A chart can be too sparse. If removing an element makes it harder to read the data accurately, it stays. The goal is earned complexity, not zero complexity.

@feynman

Like code review feedback that says "delete the dead code" — not a style preference, but a recognition that every line costs future readers time, and lines that don't do work should go.

@card
id: cwd-ch10-c009
order: 9
title: Common Data Environments and Their Constraints
teaser: The tool you're working in shapes what's possible — BI tools, notebooks, and slide decks have different constraints, and fighting them is usually the wrong call.

@explanation

Every data environment imposes constraints on chart design. Working within them is more efficient than fighting them.

**BI tools (Tableau, Looker, Metabase, Power BI):**
- Strong at interactive filtering, drill-down, and refreshing against live data.
- Weak at precise annotation, unconventional chart types, and fine-grained layout control.
- The constraint: design for audiences who will interact with the chart, not just read a snapshot. Default views matter most — many users never touch the filters.

**Notebooks (Jupyter, Observable, Databricks):**
- Strong at inline analysis, reproducibility, and showing the code alongside the output.
- Weak at presentation polish and stable layout for non-technical readers.
- The constraint: notebook charts are often audience-zero (the analyst themselves) or a technical peer. Lower polish bar is acceptable; higher accuracy bar is not.

**Slide decks (Google Slides, PowerPoint, Keynote):**
- Strong at precise layout control, annotation, and narrative sequencing across slides.
- Weak at interactivity and data freshness.
- The constraint: one claim per slide. The chart doesn't live on its own — it exists in a sequence with a specific argument to advance.

**The common failure across all three:** trying to replicate the strengths of one environment in another. A dashboard that tries to tell a narrative story is a bad dashboard. A slide chart that tries to serve as an exploration tool is a bad slide.

> [!warning] Exporting a dashboard screenshot into a slide is the worst of both worlds — it loses interactivity and has too much information for a presentation context. Build the slide chart separately.

@feynman

Like choosing the right data structure for the problem — a hashmap is excellent until you need ordered traversal, at which point fighting the structure is the wrong answer; switch to one that fits.

@card
id: cwd-ch10-c010
order: 10
title: Building Team Norms Around Chart Quality
teaser: A shared definition of "good" makes every chart review faster and every disagreement shorter — because the standard is explicit, not personal.

@explanation

Without shared norms, chart quality reviews are conversations about taste. With them, they're conversations about standards. The difference matters at scale.

The norms worth making explicit:

- **Every chart has a title that states the claim.** Not the data ("Revenue by Quarter"), the claim ("Revenue growth slowed in Q3").
- **No chart ships without at least one peer review.** The minimum bar, not the aspirational one.
- **A shared chart type guide.** When to use a bar chart vs. a line chart vs. a scatter — the team's agreed answers to the recurring questions. Not a comprehensive style guide; just the decisions that cause repeated disagreement.
- **A "good example" gallery.** Three to five annotated charts that represent what quality looks like in this team's work. Concrete examples outperform abstract descriptions of quality.
- **A definition of chart retirement.** Charts accumulate in dashboards. A norm for when a chart is stale or no longer needed prevents the slow degradation of dashboard quality over time.

How to establish norms without a formal process:

- Start with the question "what would a new analyst need to know to produce a chart this team would be proud of?" Write down the answers. That's the norm.
- Revisit quarterly. Norms that aren't reviewed become outdated.

> [!info] The goal is not uniformity — different chart types, colors, and structures are appropriate for different contexts. The goal is shared vocabulary for evaluating whether a choice was intentional and whether it served the claim.

@feynman

Like a team coding style guide — not to make everyone write identically, but to eliminate the debates that have a correct answer so the team can focus on the decisions that don't.

@card
id: cwd-ch10-c011
order: 11
title: Developing a Chart Eye
teaser: After deliberate practice, you stop analyzing charts consciously — the flaws surface automatically, the way a programmer sees a missing null check without searching for it.

@explanation

"Having a chart eye" is not a mystical faculty. It is the result of deliberate practice accumulated to the point of automaticity. The same way a fluent reader doesn't decode individual letters, a fluent chart reader doesn't consciously run through a diagnostic checklist — the problems surface as immediate perceptions.

What changes at each stage of development:

**Stage 1 — Naive reader:** charts are either clear or confusing, and the distinction feels subjective. Can't articulate why a chart isn't working.

**Stage 2 — Checklist practitioner:** can diagnose a chart by applying the critique framework step by step. Catches most problems but the process is deliberate and slow.

**Stage 3 — Pattern recognizer:** common failure modes trigger immediate recognition without running the checklist. "Dual axis" or "legend too far" or "title is not the claim" surfaces as a perception before a thought.

**Stage 4 — Fluent practitioner:** designs well instinctively, explains why instinctively, and can teach the framework because the principles behind the checklist are explicit. Catches novel failure modes — ones not in any checklist — because the underlying reasoning is available.

The transition from stage 2 to stage 3 requires volume. In practice: critique fifty to one hundred charts with the explicit framework applied each time. The automaticity comes from repetition, not from talent or taste.

> [!tip] The most useful early signal that you're developing a chart eye: you start seeing problems in charts before you consciously look for them. That involuntary recognition is the skill taking root.

@feynman

Like learning to read code — at first you parse syntax consciously, then patterns emerge automatically, and eventually bugs register as a feeling before you can explain what's wrong.

@card
id: cwd-ch10-c012
order: 12
title: Anti-Pattern: The One-and-Done Chart
teaser: No iteration, no feedback, no improvement — the most common reason charts stay bad longer than they need to.

@explanation

The one-and-done chart is built once, shipped, and never revisited. It's the default workflow when no process exists to require anything else — and it produces the majority of poor charts in production dashboards.

The recognizable markers:

- The title describes the data, not the claim.
- There is no annotation — no "here" arrows, no highlighted region, no explanatory note.
- The chart type was the default in the tool, not a considered choice.
- No one outside the author saw it before it shipped.
- It has been in the dashboard for fourteen months and no one knows if it's still accurate.

Why it happens:

- **Time pressure:** the chart was built to answer a question in a meeting. It stayed.
- **No feedback loop:** no one told the author what wasn't working.
- **Invisible cost:** the author moved on. The cost of a confusing chart is paid by readers, not authors.
- **No retirement process:** charts accumulate; none are removed.

The fix is not to demand perfect charts on the first pass. It is to require one iteration pass before anything ships to a large audience, and to maintain a retirement cadence for dashboards. Neither requires significant process — they require treating the chart as a deliverable rather than a byproduct.

> [!warning] A chart that was built in ten minutes and never revised will be read for months by people who assume it was intentional. The author's time investment and the reader's interpretation are not calibrated.

@feynman

Like code written to pass the first test and never refactored — it works until it doesn't, and by then the author is two projects away and the next person inherits the confusion.
