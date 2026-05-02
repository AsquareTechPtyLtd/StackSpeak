@chapter
id: cwd-ch04-annotation-as-message
order: 4
title: Annotation as Message
summary: The title is the most important element on the chart — not the axes, not the legend. An interpretive title combined with targeted annotation eliminates ambiguity about what the reader should take away.

@card
id: cwd-ch04-c001
order: 1
title: The Interpretive Title
teaser: "Revenue grew 28% in Q4" does the work your chart was built to do. "Revenue by Quarter" leaves that work to the reader — and readers rarely finish it.

@explanation

A chart title is not a filing label. It is not there to describe what data is plotted. It is there to deliver the conclusion the data supports.

Compare:
- "Revenue by Quarter" — tells the reader what the axes show.
- "Revenue grew 28% in Q4" — tells the reader what to believe after looking at the axes.

The first is a descriptive title. The second is an interpretive title. The interpretive title does the cognitive work the reader would otherwise have to do themselves — and most readers, especially in fast-paced contexts like a leadership review or a Slack share, won't do that work. They'll glance, infer something vague, and move on.

What makes a strong interpretive title:
- It states the conclusion, not the topic.
- It includes the key number or direction ("28%", "3× faster", "down for the third consecutive quarter").
- It is specific enough that a reader can evaluate whether they agree.
- It matches what the annotation and color emphasis in the chart are pointing at.

The last point is often skipped. A title that says "Q4 was the strongest quarter on record" but highlights Q2 in color creates confusion instead of clarity. The title, the visual emphasis, and the annotation must form a single coherent argument.

> [!info] The interpretive title is not spin — it is precision. You built the chart because you found something. Name it in the title so the reader starts from the finding, not the data.

@feynman

Like a function name that states what it returns rather than how it computes it — `getHighestRevenueQuarter()` beats `processRevenueData()` every time.

@card
id: cwd-ch04-c002
order: 2
title: Descriptive vs Interpretive Titles
teaser: The distinction is not stylistic preference — it determines whether the chart communicates or merely displays.

@explanation

Every chart title sits on a spectrum from purely descriptive to fully interpretive. Understanding where your title lands — and why it matters — is the first skill in chart communication.

**Descriptive title:** labels what is shown. Answers the question "what data is this?"
- "Monthly Active Users by Region"
- "API Error Rates, January–June"
- "Build Time Across CI Environments"

**Interpretive title:** states what the data means. Answers the question "what should I take away from this?"
- "North America Reached 2M MAU in March"
- "Error Rates Spiked After the June 14 Deploy"
- "Parallel Builds Cut Median CI Time by 40%"

When to use each:
- Use descriptive titles in exploratory contexts — dashboards where multiple analysts look for different things, data catalogs, appendix charts in a report. The reader is the analyst, and you do not want to pre-load a conclusion.
- Use interpretive titles in communication contexts — presentations, written reports, Slack updates, executive reviews, incident summaries. The reader is a decision-maker, and the chart's job is to transfer a specific conclusion.

Most charts produced for stakeholder communication should have interpretive titles. Most charts produced by engineering teams for internal dashboards use descriptive titles out of habit — the same habit used when naming variables, where neutrality is a virtue. In communication, that neutrality is a bug.

> [!tip] A quick test: cover the chart body and read only the title. If a smart person could not form a judgment from the title alone, it is probably descriptive rather than interpretive. Rewrite it.

@feynman

Like the difference between a commit message that says "changes to auth module" versus one that says "fix token expiry not refreshing on mobile" — the second one tells you what changed and why it matters.

@card
id: cwd-ch04-c003
order: 3
title: The Subtitle as Context
teaser: The subtitle is a single line that answers "why does this matter?" — timeframe, audience, methodology note, or stakes.

@explanation

An interpretive title states the conclusion. The subtitle answers the question that conclusion immediately raises: "why should I care?" or "what is the scope of this?"

The subtitle is not a second title. It is not a longer version of the title. It is a single line of supporting context — the framing that makes the conclusion usable.

What belongs in a subtitle:
- **Timeframe:** "Q4 2024 vs Q4 2023" or "trailing 12 months as of April 30"
- **Scope qualifier:** "iOS users only" or "excluding enterprise tier"
- **Significance note:** "first time above the 90% threshold since launch"
- **Methodology shorthand:** "p50 latency, measured at gateway" or "revenue excludes refunds"

What does not belong in a subtitle:
- Restating the title in different words.
- A second conclusion that competes with the first.
- Dataset provenance details that belong in the caption or footnote.
- Internal ticket numbers or query names.

A subtitle should be 10–20 words. If it runs to two lines, the scope is too broad or the context belongs elsewhere.

The combination of title and subtitle should work as a standalone summary. If someone forwards a screenshot of just the chart header and footer, they should be able to explain the chart's argument to a colleague without ever seeing the chart body.

> [!tip] Write the subtitle after the title, not before. The title determines what conclusion needs supporting context — the subtitle serves that conclusion.

@feynman

Like a function's docstring first line — it says what the function does, then the second sentence qualifies the scope ("only applies to authenticated users," "assumes sorted input").

@card
id: cwd-ch04-c004
order: 4
title: Callout Annotations
teaser: A callout annotation is the chart equivalent of a code comment at exactly the line that would otherwise confuse the reader — placed at the data point that proves the argument.

@explanation

A callout annotation is a text label or arrow that points to a specific data point and explains its significance. It is the bridge between the visual and the conclusion.

The rule for callout placement: annotate the data point that proves the title. If your title says "Error rates spiked after the June 14 deploy," there should be an annotation on June 14 that either labels the deploy event or labels the spike value. The reader should never have to hunt for the evidence.

Anatomy of an effective callout:
- **Location:** at or adjacent to the relevant data point, not floating in white space.
- **Label:** the minimum text that identifies what the reader is looking at ("June 14 deploy", "28% growth", "SLA breach").
- **Leader line (optional):** only when the annotation text cannot sit adjacent to the point without overlapping other elements.
- **Visual hierarchy:** callout text should be smaller than the title, larger than axis labels. It should read second, after the title.

Callouts to avoid:
- An annotation that says "see spike" without identifying what caused it.
- An annotation that covers other data points.
- Multiple competing callouts that each seem equally important — this signals the title argument is not clear.

One well-placed callout beats three vague ones. If you find yourself writing more than two or three callouts per chart, that is often a sign the chart contains more than one argument.

> [!warning] A callout annotation that requires a legend to decode has defeated its own purpose. Callouts should be self-contained — readable without reference to anything else on the chart.

@feynman

Like an inline code comment on the exact line that's non-obvious — placed at the moment the reader needs it, not clustered at the top of the file.

@card
id: cwd-ch04-c005
order: 5
title: The Data Label Decision
teaser: Data labels add precision when the exact value is load-bearing. When the shape is the message, they add visual noise that competes with the argument.

@explanation

Data labels are the numbers placed directly on or adjacent to bars, points, or line values. The decision to include them is a decision about what the reader needs to do with the chart.

**Add data labels when:**
- Exact values are operationally necessary ("the threshold is 99.5% — is our uptime above or below it?").
- The chart will be used in a context where zooming into the axes is not feasible (printed reports, small-screen mobile, screenshots in documents).
- There are five or fewer data points and the values are the primary payload.
- The chart is a comparison table in disguise — the reader needs to rank or calculate differences between values.

**Omit data labels when:**
- The trend or shape is the argument, not the exact value at each point.
- There are more than six or seven points and full labeling creates visual congestion.
- The title and a single callout annotation already communicate the key number.
- Labels would overlap or require offset positioning that degrades chart clarity.

A common mistake: applying data labels uniformly across all charts as a house style rule, regardless of what the chart is trying to communicate. A line chart of 24 months of weekly data with every point labeled is not more precise — it is harder to see the trend that justifies having a line chart in the first place.

The format of data labels matters too: round to the precision that is actually meaningful. "28.3146%" is not more honest than "28%" — it is more distracting.

> [!info] When in doubt: label the key point (the one your callout annotation is already pointing at) and omit the rest. That gives precision where it matters without adding noise everywhere.

@feynman

Like logging — log the events that are actionable, not every state transition; the signal-to-noise ratio is what makes logs useful when something breaks.

@card
id: cwd-ch04-c006
order: 6
title: Direct Labeling vs Legends
teaser: A legend is a lookup table appended to the chart. Direct labeling puts the name at the data — eliminating the back-and-forth that legends require.

@explanation

A legend tells the reader: "to understand what the blue line means, find blue in this key, then read the label." Direct labeling tells the reader directly, at the line itself: "this is iOS."

Every legend lookup is a cognitive round trip. For a chart with two series, this is a minor inconvenience. For a chart with five or six series, it compounds — the reader forgets which series is highlighted by the time they return to the data.

How to apply direct labeling effectively:
- Place the label at the end of the line (rightmost point for a time-series) or at the line's peak if the end point is cluttered.
- Match the label color to the line color so the mapping is immediate.
- Use a concise label — "iOS" not "iOS Mobile Application Users" — since the title should already provide context.
- If two line endpoints are too close together to label without overlap, offset one slightly or use a leader line.

When a legend is acceptable:
- Static bar charts where direct labeling would require placing text inside narrow bars.
- Charts with more than five series where direct labeling creates label congestion — though at that point, the real fix is usually to reduce the number of series.
- Formal publications where style guides require legends.

The test: show the chart to someone unfamiliar with the data and ask them to identify a specific series. If they reach for the legend, direct labeling was not applied well enough.

> [!tip] Think of direct labeling as the chart equivalent of naming a variable at its declaration rather than in a comment at the top of the file — the context is where the thing is used.

@feynman

Like tooltips in a well-designed UI — the information appears in context, at the element you're looking at, instead of requiring you to open a separate help panel.

@card
id: cwd-ch04-c007
order: 7
title: The Caption and Data Source
teaser: The caption carries methodology, source, and caveats — everything that must be recorded but would clutter the chart body if placed there.

@explanation

The caption is the fine print that earns the chart credibility. It belongs at the bottom of the chart, in a smaller type size, and it should contain exactly two categories of content: the data source and any interpretation-affecting caveats.

**What belongs in the caption:**
- Data source: "Source: Mixpanel export, April 30 2025" or "Source: internal billing database, query [link]."
- Date of export or snapshot: when the data was pulled, not just what period it covers.
- Significant exclusions: "excludes churned accounts" or "enterprise tier only."
- Unit notes that do not fit on the axis: "revenue in USD thousands" if axis labels show "150, 200, 250."
- Methodology that affects interpretation: "7-day rolling average" or "latency measured at the load balancer, not the client."

**What does not belong in the caption:**
- Commentary on the conclusion ("as you can see, Q4 was exceptional") — that belongs in the title.
- Secondary arguments or additional findings — those belong in a separate chart.
- Apologies for data quality ("note: this data may not be 100% accurate") — either fix the data quality issue or state the specific limitation precisely.
- Internal query IDs, dashboard links, or jira tickets — these are operational metadata, not chart communication.

A caption that runs longer than two lines is usually trying to cover for a chart that has multiple conclusions or a data source that is not ready for the audience.

> [!info] Every chart shared outside the team should have a caption with at least the data source and snapshot date. Without it, the chart cannot be evaluated for freshness or provenance by anyone who receives it secondhand.

@feynman

Like a Git commit — the message is the "what and why," the metadata (author, hash, timestamp) is the provenance; both matter, but they live in different places.

@card
id: cwd-ch04-c008
order: 8
title: Axis Label Clarity
teaser: Axis labels are infrastructure — they should be readable, unambiguous, and formatted for the reader, not for the data export tool that generated them.

@explanation

Axis labels are not a place for creativity, but they are a common place for errors that undermine an otherwise clear chart.

**Units:** always include units on the axis if they are not in the title. "Revenue" on the Y axis is ambiguous. "Revenue (USD thousands)" is not. If the unit is obvious from context and repeated in the title, skip it on the axis — do not repeat it in both places.

**Formatting for scale:**
- Large numbers: format `1,200,000` as `1.2M` on the axis. Do not rely on automatic scientific notation from charting libraries — `1.2e6` is not readable in a business context.
- Percentages: display as `28%` not `0.28`. The percentage format is the correct representation for human reading; the decimal is correct for computation.
- Dates: use consistent, unambiguous formats. "Jan 2025" or "2025-01" works. "1/25" is ambiguous (January 2025 or the 25th of an unstated month).

**Axis label density:** do not label every tick when the axis has more than six or seven values — the labels will overlap or require rotation. Rotate is the last resort, not the default. Better options: skip every other tick, use a coarser granularity (months instead of weeks), or reduce the chart's time range.

**Zero baseline:** bar charts should almost always start at zero. Line charts do not have to, but if the baseline is not zero, the axis must make the non-zero start visually obvious — a broken axis indicator or explicit minimum label.

> [!warning] Rotated axis labels are a strong signal that the chart has too many categories or too fine a time granularity for its size. Fix the data density rather than rotating the labels.

@feynman

Like readable variable names — the axis label is the name; if it requires a comment to understand what unit it is in, the name is doing insufficient work.

@card
id: cwd-ch04-c009
order: 9
title: Combining Title, Annotation, and Color
teaser: When the title, a single callout, and a highlight color all point at the same element, the chart delivers its message unambiguously — even to a reader who spends five seconds on it.

@explanation

The three highest-leverage annotation elements in any chart are the title, callout annotations, and color. When they are coordinated, they create a layered argument that works across attention levels — the five-second glance, the thirty-second read, and the two-minute analysis.

The pattern:
- **Title** states the conclusion: "API error rate peaked at 4.1% during the incident window."
- **Color** directs the eye: the incident window is rendered in red or a high-contrast color; all other time periods are in a muted gray.
- **Callout** provides precision: a label at the peak point reads "4.1% — June 14 02:30–04:15 UTC."

These three elements are redundant by design. A reader who only registers the color knows something was abnormal. A reader who reads the title knows what it was and its magnitude. A reader who finds the callout knows the exact time range. Each layer adds fidelity without requiring the others.

What breaks this coordination:
- Title mentions Q4, but the color highlights Q3.
- Callout points to a different data point than the one that justifies the title.
- Multiple data series highlighted in different colors — the reader does not know which element to read the title against.
- No color differentiation at all — the annotated element looks identical to everything around it.

Audit a chart for coordination by asking: "if I removed the title, would the color and callout still point at the same thing?" If yes, the three are coordinated. If no, one of them is misaligned.

> [!tip] Apply color last, after the title and callout are finalized. Color emphasis is the visual confirmation of the verbal argument — it cannot be correctly applied before the argument is clear.

@feynman

Like the three-part convention of a good test — the "given" sets context, the "when" triggers the action, and the "then" asserts the outcome; each layer reinforces the same claim.

@card
id: cwd-ch04-c010
order: 10
title: Annotation Patterns for Time-Series
teaser: Time-series charts earn their annotation complexity — events on the timeline are often the explanation for every interesting feature in the data.

@explanation

Time-series charts carry a specific annotation challenge: the interesting features in the data (spikes, drops, inflections, plateaus) are almost always caused by external events — deploys, incidents, campaigns, policy changes, seasonality. Without event markers, readers are left to speculate about causes.

Common time-series annotation patterns:

**Event markers:** vertical lines or small triangles on the x-axis at the moment an event occurred. Label them with a short identifier ("v2.4 deploy," "Black Friday," "pricing change"). Keep labels short — the chart body is not the place for the event's full description.

**Range shading:** a shaded background region for a time interval — an incident window, a migration period, a campaign run. Pair with a label at the top of the shaded region. Use a low-opacity fill so underlying data remains visible.

**Before/after annotation:** a callout that labels a value before an event and a value after it ("median latency: 180ms → 42ms after cache layer"). This makes the event's impact quantitative, not just visual.

**Trend annotations:** a dashed reference line showing the pre-event trend, extended through the post-event period. The gap between the reference line and the actual data visualizes the event's effect.

Principles that apply to all time-series annotation:
- Annotate the cause of the feature, not just the feature itself.
- Vertical event markers should be subtle — thin, low-opacity lines — so they do not dominate the data.
- If more than three or four events are marked, consider whether the chart is trying to tell too many stories at once.

> [!info] Event markers are the chart equivalent of code comments on a breaking change — they prevent future readers from misattributing the effect to the wrong cause.

@feynman

Like annotated git history — the commit message explains why the line changed, not just that it changed; without it, every spike looks like noise instead of signal.

@card
id: cwd-ch04-c011
order: 11
title: Annotation as Argument
teaser: Every annotation on a chart should be able to answer the question "does this support the title?" If it cannot, it does not belong on the chart.

@explanation

The discipline of treating annotation as argument rather than as decoration changes how charts are built. Instead of asking "what interesting things are in this data that I should label?", the question becomes "what does the reader need to see to believe the title?"

That reframe narrows annotation to only what advances the argument:
- The callout that marks the data point proving the headline claim.
- The event marker that explains the feature that would otherwise undermine the claim.
- The reference line that makes the magnitude of the change legible.

It excludes:
- Interesting but off-argument facts ("this bar is interesting too, but not the point").
- Context that belongs in a separate chart.
- Data labels on every point when the argument requires only one number.

The practical workflow: write the interpretive title first. Then ask, "what objection would a skeptical reader raise?" The annotation is the answer to that objection. "Revenue grew 28% in Q4" invites the objection "is that growth or is Q3 just weak?" The annotation that answers it might be a year-over-year comparison label or a reference line at the Q4 mean from prior years.

This approach produces charts with fewer annotations that land harder. The reader is not processing ten data points of equal visual weight — they are following a guided argument with a clear destination.

> [!tip] Before finalizing a chart, read the title aloud and then look at each annotation. If an annotation does not connect to the title claim, delete it. Ruthlessness here is a design virtue.

@feynman

Like peer review of a technical argument — every cited source should support the claim, and any citation that supports a different claim belongs in a different paper.

@card
id: cwd-ch04-c012
order: 12
title: The Anti-Pattern — Annotating Everything
teaser: Annotation that annotates everything communicates nothing. When every data point is labeled, no data point is highlighted — the annotation system has become the axis labels, with more clutter.

@explanation

The most common annotation failure is not too little — it is too much. Engineers especially tend toward completeness: if the data has twelve bars, label all twelve bars. If the time-series has a noteworthy event every week, mark every event. The instinct is thorough; the output is unreadable.

What over-annotation produces:
- **Visual noise that flattens hierarchy.** When everything is labeled, nothing is emphasized. The reader cannot distinguish the load-bearing annotation from the background annotation.
- **Confirmation that no argument was formed.** A chart where every point is annotated is a chart where the author was unsure which point mattered. The reader inherits that uncertainty.
- **Label collision and illegibility.** Dense labeling forces offsets, leader lines, and small fonts that degrade readability below the baseline.
- **Cognitive load that causes abandonment.** Readers in business contexts do not process every element of a dense chart — they scan, form an impression, and move on. Over-annotated charts produce impressions like "this is complicated" rather than "error rates spiked after the deploy."

The diagnostic: count your annotations. More than three or four distinct annotation elements on a single chart is a signal to stop and ask what the chart is arguing.

The fix is not to annotate less randomly — it is to form the argument first and annotate in service of it. Delete every annotation that is not supporting the title claim. If deleting an annotation feels like hiding something important, the important thing probably belongs in its own chart.

> [!warning] A chart that requires a tour guide to explain is not a communication artifact — it is a dataset dump with visual formatting. The goal of annotation is to make the tour guide unnecessary.

@feynman

Like a codebase where every line has a comment — the comments stop being useful because there is no signal about which lines actually need explanation.
