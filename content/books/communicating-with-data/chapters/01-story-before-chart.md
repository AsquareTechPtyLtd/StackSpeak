@chapter
id: cwd-ch01-story-before-chart
order: 1
title: Story Before Chart
summary: The chart is the last thing you build. Before touching a visualization tool, you need to know what question you're answering, for whom, and what you want them to do with the answer.

@card
id: cwd-ch01-c001
order: 1
title: The Communication-First Mindset
teaser: A chart is not a display of data — it is an answer to a question. If you don't know the question, you cannot build a useful chart.

@explanation

Most charts fail before a single pixel is drawn. The failure happens when someone opens a BI tool, drags in a measure, picks a bar chart, and ships it. The data is accurate. The chart is useless.

The communication-first mindset flips the build order: the question comes first, the audience comes second, the required action comes third. The chart is the last thing you touch — and only once the first three are settled.

A chart is useful when it:
- Answers a specific question the audience is actually asking.
- Is designed for the way that audience reads data.
- Makes it obvious what the reader should do next.

A chart is not useful when it:
- Shows everything that was in the dataset because nothing was left out.
- Exists because someone asked for "a dashboard."
- Looks impressive at the cost of being readable.

The communication-first mindset is not about making charts simpler or prettier. It's about treating visualization as a tool for changing what someone understands or does — the same way a function call is a tool for changing program state. Both have a specific contract: input, output, side effect. A chart with no defined output is a function that returns void.

> [!info] Every chart answers a question. The only choice is whether you define that question before or after you build the chart. Defining it after is how you end up with six revisions.

@feynman

Writing a function with no return type and no side effect — technically valid, practically useless.

@card
id: cwd-ch01-c002
order: 2
title: Defining the Question
teaser: "Show me sales data" is not a question. A question has a specific, falsifiable answer — and forcing yourself to write it down is the first filter that removes bad charts.

@explanation

Before building anything, write down the question in a single sentence. Not a topic — a question. The difference matters:

Topics (not questions):
- "Revenue by region"
- "User engagement over time"
- "Churn analysis"

Questions (specific, answerable):
- "Which region missed its Q3 revenue target by more than 10%?"
- "Did the onboarding redesign improve 30-day retention in the cohort launched in August?"
- "Which customer segments had churn rates above the baseline in the last 90 days?"

The question defines everything downstream: what data you need, which chart type fits, what the headline should say, who needs to see it. A topic leaves all of those open — which is why stakeholders keep asking for changes after the chart is built.

How to pressure-test your question:
- Can a yes/no or a specific value answer it? If not, it's still a topic.
- Would two different people, given the same data, agree on what chart answers it? If not, sharpen it.
- Is it the question the audience is actually asking, or the question you found interesting while exploring the data?

The third test is the hardest. Analysts fall in love with patterns they discover in the data and present them as if the stakeholder asked. The stakeholder did not ask. Present it as an additional finding, not as the answer.

> [!tip] If your question can be answered by more than three different chart types, it's still too broad. Keep narrowing until one chart type is clearly right.

@feynman

Like writing an acceptance criterion before a feature — the spec is what makes the implementation reviewable.

@card
id: cwd-ch01-c003
order: 3
title: Who Is the Audience and What Will They Do?
teaser: A chart designed for a data scientist and a chart designed for a VP answering the same question look entirely different. Audience determines complexity, annotation, and required action.

@explanation

The same underlying data can produce charts that are correct for one audience and completely wrong for another. "Audience" is not a soft concern about aesthetics — it's a hard constraint on what the chart must communicate and how.

Two dimensions that define the audience:

**Familiarity with the data domain.** A data engineer reading pipeline latency charts has internalized what normal looks like. A product manager reading the same chart needs context: what's the baseline, what's the alert threshold, what's a bad number. Annotations that are redundant for an expert are load-bearing for a non-expert.

**Decision authority and time horizon.** An operator making a real-time decision needs to know: is something wrong right now, and what do I do? An executive making a quarterly decision needs to know: is the trend right, and does it match what I expected? The same question — "is the system healthy?" — requires completely different chart designs depending on which of these two people is reading it.

After defining the audience, write down what action they should take after reading the chart:
- "The on-call engineer should page the storage team if the P99 is above 400ms."
- "The product lead should approve or defer the feature rollout based on whether the engagement lift held."
- "The director should understand that the retention problem is cohort-specific, not product-wide."

If you can't write the action, you don't understand what the chart is for.

> [!warning] "Stakeholders" is not an audience. Neither is "the team." Name a role and a decision. A chart designed for everyone is designed for no one.

@feynman

Like a function signature — you don't write the implementation until you know the caller, the arguments, and the return contract.

@card
id: cwd-ch01-c004
order: 4
title: The Three Chart-Reader Types
teaser: Exploratory analysts, decision-makers, and casual glancers have different needs from a chart — and a design optimized for one will actively fail for the others.

@explanation

Not all chart readers read the same way. Three archetypes cover most use cases:

**The exploratory analyst.** Reads charts to generate hypotheses and find unexpected patterns. Needs access to granularity, filters, and drill-down. Comfortable with density and unfamiliar chart types. Will spend 10–30 minutes with the visualization. Design priority: access to the data, not pre-digested conclusions.

**The decision-maker.** Reads charts to confirm or challenge a position before making a call. Needs a clear headline, the right comparison set, and confidence in the data quality. Will spend 2–5 minutes. Has no patience for charts that require explanation. Design priority: one clear message, supporting context, and a visible recommendation or threshold.

**The casual glancer.** Reads charts in a dashboard, email, or presentation slide — often while doing something else. Will spend 5–20 seconds. Needs to extract the key number or direction without reading axis labels or legends. Design priority: single-metric focus, large callout number, direct headline.

Common mistake: building exploratory charts for decision-makers. The analyst who built the chart spent three days with the data — they can navigate the density. The VP who receives it cannot, and will ask for a simpler version. The simpler version was the right deliverable from the start.

The archetypes are not mutually exclusive roles — the same person may be a decision-maker for one chart and a casual glancer for another in the same dashboard.

> [!info] Before choosing a chart type, name the archetype. The archetype determines whether you design for density, clarity, or glanceability — three fundamentally different constraints.

@feynman

Like choosing between an IDE, a diff viewer, and a deployment status badge — all show code state, but each is designed for a completely different reading mode.

@card
id: cwd-ch01-c005
order: 5
title: Exploratory vs Explanatory Visualization
teaser: Exploratory charts help you find the story. Explanatory charts tell the story you already found. Confusing the two produces charts that look like raw analysis instead of communication.

@explanation

There are two fundamentally different visualization modes, and they require different designs:

**Exploratory visualization** is what analysts do privately to understand data. It is high-density, often ugly, and not meant for an audience. The goal is to find the story — to surface anomalies, correlations, and distributions that were not anticipated before looking at the data. Tools like Jupyter notebooks, R exploratory plots, and BI pivot tables are designed for this mode. A good exploratory chart asks "what's in here?"

**Explanatory visualization** is what analysts communicate publicly to answer a specific question. It is the result of having already found the story. The goal is to make one point clearly and make the reader understand it without effort. A good explanatory chart says "here is what I found."

The mistake most analysts make: shipping exploratory charts as explanatory ones. The result is a chart with twelve series, three y-axes, no headline, and a legend that requires a map of the organization to decode. The analyst can read it — they built it. No one else can.

The discipline is in the transition: once you've found the story in exploratory mode, rebuild the chart from scratch with the audience, question, and action in mind. That second chart will look completely different from the first.

- Exploratory: all segments, all time periods, full granularity, no headline, filters available.
- Explanatory: the two segments that diverged, the six-month window that matters, one trend line, a direct headline.

> [!tip] If you're sharing a chart with anyone other than yourself, ask: "Did I build this to find the story or to tell it?" If you're still finding it, keep it exploratory and off the slide deck.

@feynman

Like the difference between a debugging session and a postmortem write-up — the debugging session is for you; the postmortem is for the team.

@card
id: cwd-ch01-c006
order: 6
title: The "So What" Test
teaser: If you can't complete the sentence "this chart shows that…" with a specific, actionable claim, the chart isn't ready to share.

@explanation

The "so what" test is the fastest quality filter for a chart before it reaches an audience. Complete this sentence:

"This chart shows that ___."

The blank must be filled with a specific, falsifiable claim — not a description of the axes.

Failing the test:
- "This chart shows that revenue by region over the last four quarters."
- "This chart shows that user engagement metrics across device types."

Passing the test:
- "This chart shows that the EMEA region is the only one that grew in Q3, while APAC and NA both declined."
- "This chart shows that mobile users complete onboarding at 22% lower rates than desktop users across every cohort since April."

Notice that passing answers are specific enough to be wrong. They make a claim. The EMEA claim could be falsified by showing that APAC also grew. The mobile claim could be falsified by finding a cohort where the gap closed. A claim that cannot be falsified is a description, not a message.

Why this matters: charts that fail the "so what" test make the reader do the analyst's job — they have to extract the message themselves. Busy decision-makers skip that step and either ignore the chart or ask a follow-up question that consumes more of everyone's time than writing the headline would have.

The "so what" test also reveals when the analyst hasn't finished the analysis. If you can't complete the sentence, you haven't decided what the chart is for yet. That's a signal to keep analyzing, not to send the chart and explain it verbally.

> [!warning] Completing the sentence verbally in a meeting is not the same as the chart communicating it. If you need to narrate the chart to make the "so what" legible, redesign the chart.

@feynman

Like a function that computes a value but doesn't return it — the work happened, but nothing receives the result.

@card
id: cwd-ch01-c007
order: 7
title: When a Table Is Better Than a Chart
teaser: Charts are not always better than tables. When the audience needs precise values, multiple dimensions simultaneously, or reference data — a table is the correct choice.

@explanation

Charts are optimized for showing patterns, trends, and comparisons across a single primary dimension. Tables are optimized for showing precise values across multiple dimensions simultaneously. Choosing a chart when a table fits better is one of the most common mistakes in data communication.

Use a table when:
- The audience needs to look up specific values, not see a pattern. A sales rep checking their own quota attainment number needs a table, not a bar chart.
- Multiple dimensions must be compared simultaneously. A chart showing revenue, margin, units, and YoY change for 20 product lines requires a table — no chart type handles four metrics across 20 items legibly.
- The values themselves are the communication, not their relative magnitudes. A regulatory report that must show exact figures is a table; a chart's visual encoding introduces interpretation that a regulator doesn't want.
- The audience will use the data as a reference to copy into another system. Charts are not copy-paste friendly.

Use a chart when:
- The pattern or trend is the message, not the individual values.
- The comparison across categories is more important than any single data point.
- A visual encoding (position, length, color) communicates the relationship faster than reading numbers.

The shortcut: if the chart's labels need to show every data value to be useful, use a table instead. Adding data labels to every bar is a sign that the chart is a poorly formatted table.

> [!info] Tables and charts are not competing options — they serve different communication purposes. A well-designed report often includes both: a chart for the headline and a table for the supporting detail.

@feynman

Like knowing when to use a comment and when to use a docstring — both communicate intent, but they are optimized for different reading modes and contexts.

@card
id: cwd-ch01-c008
order: 8
title: Matching Chart Type to the Question
teaser: Chart types are not aesthetic choices — each encodes a specific kind of relationship. Picking the wrong encoding actively misleads the reader, even with accurate data.

@explanation

Every chart type has a primary use case — a type of question it answers well. Choosing a chart type means choosing an encoding, and the encoding makes an implicit claim about the relationship in the data.

Common encodings and their correct use cases:

**Bar chart (vertical or horizontal):** comparing magnitudes across discrete categories. "Which regions had the highest revenue?" Bar length encodes magnitude. Do not use for trends over time.

**Line chart:** showing change over time for a continuous variable. "How has retention changed over the last 12 months?" The connecting line implies continuity — use only when the x-axis is a continuous dimension (time, temperature, frequency). Never use a line chart for categorical comparisons.

**Scatter plot:** showing the relationship between two continuous variables. "Is there a correlation between support ticket volume and churn rate?" One variable per axis; a third can be encoded in dot size or color.

**Small multiples:** comparing the same chart across multiple segments. "How does the trend differ by user tier?" Repeat the same chart design for each segment side-by-side instead of overlaying all series on one chart.

**Area chart:** showing cumulative or part-to-whole relationships over time. Use sparingly — area charts are frequently misread when series overlap.

Wrong encoding examples:
- Pie chart to compare 12 categories — humans cannot accurately judge angle differences beyond 5 or 6 slices.
- Line chart connecting survey response categories — the connecting line implies a continuous relationship between discrete options.
- Bar chart with a non-zero y-axis baseline — visually exaggerates differences.

> [!warning] A chart that uses the wrong encoding is not just aesthetically wrong — it makes false claims about the data. A line chart connecting unrelated categories implies that the intermediate values are meaningful when they are not.

@feynman

Like choosing the right data structure — a hash map and a sorted array both store values, but choosing the wrong one gives you the wrong performance guarantees for your access pattern.

@card
id: cwd-ch01-c009
order: 9
title: Write the Headline First
teaser: Writing the chart's headline before building the chart forces the claim to exist before the visual — and makes the visual falsifiable.

@explanation

The most disciplined technique in data communication: write the headline before opening the visualization tool.

The headline is the "so what" sentence. It is the claim the chart must prove. Writing it first inverts the typical workflow — instead of building a chart and then describing what it shows, you commit to a claim and then verify whether the data supports it.

Why this works:

**It surfaces unverified assumptions.** Writing "EMEA growth offset NA decline in Q3" before building the chart forces you to check whether that's actually true, not just whether the chart looks like it might be.

**It prevents chart drift.** When you build the chart first, you often adjust the chart until it "looks right" and then describe what you see. This produces post-hoc rationalization, not communication. The headline-first approach makes the chart either confirm or contradict the headline — which is the correct epistemic position.

**It produces better charts.** Once the headline exists, you can remove everything that doesn't support it. Every axis label, series, and annotation that doesn't help prove the headline is visual noise that should be removed.

**It creates accountability.** A chart with a headline makes a claim. A claim can be wrong. That accountability is uncomfortable but correct — it's the same accountability that makes written analysis honest.

The headline format: write it as a declarative sentence, not a label. "Revenue by Quarter" is a label. "Q4 revenue grew 18% YoY, the strongest quarter since 2021" is a headline.

> [!tip] If you can't write the headline before building the chart, it means you don't know what the chart is for yet. Keep exploring in your notebook — don't move to a presentation chart until the headline exists.

@feynman

Like writing the test before the implementation — the test is the spec, and if you can't write it, you don't understand the requirement.

@card
id: cwd-ch01-c010
order: 10
title: The Chart Brief
teaser: A one-paragraph brief written before any visualization work forces the context, audience, and message to exist as explicit text — which makes every subsequent decision auditable.

@explanation

Borrowed from creative and editorial workflows, the chart brief is a short written statement produced before any visualization work begins. It takes 5–10 minutes to write and eliminates most of the revision cycles that happen after a chart is shared.

A minimal chart brief covers four elements:

**Context:** what decision or situation triggered this visualization request? "The product team is deciding whether to extend the onboarding experiment to the full user base. They need to understand the engagement lift in the treatment cohort."

**Audience and reading mode:** who will read this, and how? "The product lead (decision-maker) and one data analyst (exploratory reader). The product lead will see this in a slide with 90 seconds of attention; the analyst will want to explore the underlying data."

**The message:** the single claim the chart must communicate. "Users in the treatment cohort completed the onboarding flow at a 31% higher rate than the control group, and the lift held across all device types."

**The required action:** what should the reader do after seeing this? "The product lead should decide whether the 31% lift justifies the engineering cost of a full rollout."

With these four elements written down, the chart type, the headline, the level of annotation, and the data to include are all constrained. A bar chart comparing treatment vs control across device types satisfies the brief. A time-series showing daily completion rates does not — it doesn't isolate the key comparison.

The brief also protects the analyst when stakeholders ask for changes. "Add a breakdown by traffic source" is easy to push back on when the brief documents that the chart's message is device-type comparison, not traffic attribution.

> [!info] The brief is not a deliverable — it's a working document for the analyst. It never goes to the stakeholder. Its value is the clarity it forces before the work starts.

@feynman

Like a PRD for a feature — not the feature itself, but the document that makes every implementation decision auditable against the original intent.

@card
id: cwd-ch01-c011
order: 11
title: The Big Idea Sentence
teaser: Every chart has one sentence it exists to communicate. If you can't write that sentence, the chart is not ready. If it takes more than one sentence, the chart is doing too much.

@explanation

The big idea is a single sentence that contains the complete message of the chart. It is not the headline (which is visible on the chart) — it is the internal standard the chart is built against.

A big idea sentence has two components:
- The unique point of view — what the data shows.
- The "so what" — why it matters or what it implies.

Without both components, it's not a big idea:
- "EMEA revenue grew in Q3" — has a point of view, no so what.
- "Q3 results were mixed" — has a so what framing, no point of view.

With both:
- "EMEA is the only region that grew in Q3, which means the global growth story now depends entirely on a single region's performance holding through Q4."

The big idea sentence is the test for whether the chart is doing too much. If one sentence can't contain the chart's message, the chart contains more than one message — which means it's two charts that have been combined into one. Split them.

It is also the test for whether the analyst has finished the analysis. An analyst who has done the work can write the big idea sentence in one try. An analyst who hasn't finished is still in exploratory mode and needs to keep analyzing before communicating.

Practical workflow: write the big idea sentence, build the chart, then check — does the chart communicate the sentence without narration? If yes, the chart is done. If no, identify what's blocking the communication and fix it.

> [!tip] Share the big idea sentence with a colleague before sharing the chart. If they say "I don't see that in the chart," you have a design problem. If they say "that's interesting," you have a message worth communicating.

@feynman

Like a thesis statement in an essay — the entire argument exists to prove one sentence, and if you don't know what the sentence is, the argument has no structure.

@card
id: cwd-ch01-c012
order: 12
title: Anti-Pattern — The Impressive Chart
teaser: Optimizing for visual complexity instead of communication clarity is the most common failure in data visualization — and the hardest to recognize because it feels like doing more work.

@explanation

The impressive chart anti-pattern: building the most technically sophisticated or visually striking chart possible, rather than the chart that best communicates the answer.

It surfaces in recognizable forms:

**The twelve-series line chart.** Every segment, every cohort, every device type on the same chart. The analyst did the work to slice the data sixteen ways; all sixteen slices are on the chart. The reader cannot isolate any single pattern. The chart proves that the analyst was thorough; it does not communicate what the data shows.

**The 3D chart.** Three-dimensional encodings in 2D space distort magnitude perceptions and add no information over a 2D chart. The effect is purely decorative. It signals effort; it reduces accuracy.

**The gradient color scale applied to categories.** Color gradients imply continuous order. Applied to unordered categories, they suggest a ranking that doesn't exist in the data — a visual claim that contradicts the analysis.

**The animation that loops.** Animated charts in presentations can be effective for showing transitions. Looping animations in dashboards are visual noise that fatigues the reader without adding information.

**The chart that requires a legend to decode.** If the reader must move their eyes between chart and legend repeatedly to understand the data, the encoding has failed. Direct labeling is almost always better.

What drives this anti-pattern: analysts are evaluated on visible effort. A complex chart looks like more work than a simple one. The incentive pushes toward visual complexity even when simplicity is the right call. The discipline is recognizing that the simplest chart that proves the headline is the hardest one to build — and the most useful one to receive.

> [!warning] If the first reaction to your chart is "wow, this is impressive," before the reader says "I see — so the story is X," the chart has optimized for the wrong outcome. Impressive is not the goal. Understood is the goal.

@feynman

Like an over-engineered solution to a simple problem — the complexity proves capability, but it also proves that the engineer was solving for the wrong success metric.
