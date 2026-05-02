@chapter
id: cwd-ch06-dashboard-patterns
order: 6
title: Dashboard Patterns
summary: Dashboards are not collections of charts. They're answers to recurring questions — and the difference between a dashboard that gets used and one that doesn't is whether it was designed around the question or around the available data.

@card
id: cwd-ch06-c001
order: 1
title: What a Dashboard Is For
teaser: A dashboard is a designed answer to a specific recurring question — not a portal to all available data, but a purpose-built view of the metrics that drive a decision.

@explanation

A dashboard exists because someone asks the same question repeatedly: "How is the system performing right now?" or "Are we on track this week?" The value of the dashboard is not the charts — it is that it answers that question faster than any other means available.

This framing is operationally important. Before building a dashboard, you should be able to write the question it answers in a single sentence. If you can't, you don't have a dashboard problem; you have a question-formation problem. Build the question first.

A well-scoped dashboard:
- Answers one primary question at a glance, with supporting context one level below.
- Is designed for a specific audience who has a specific decision to make or action to take.
- Has a known refresh cadence — the question is asked hourly, daily, or weekly, and the dashboard reflects that.

What a dashboard is not for:
- Exploratory analysis — that's a notebook or a BI tool in query mode.
- Telling a complete story — that's a report or a written narrative with charts.
- Satisfying every stakeholder's curiosity — that's a data catalog or a self-serve analytics environment.

When a dashboard tries to serve all three, it ends up serving none of them well.

> [!info] The one-sentence test: "This dashboard answers the question: ___." If you cannot fill in that blank before building, stop and fill it in first.

@feynman

Like a well-designed status page — not everything about the system, just the answer to "is it working right now?"

@card
id: cwd-ch06-c002
order: 2
title: Operational vs Analytical Dashboards
teaser: Operational dashboards are about now and action; analytical dashboards are about trends and insight. Building one when you need the other is a common source of frustration.

@explanation

These two types of dashboards look similar — both have charts, both have numbers — but they are designed for fundamentally different use cases, and the design decisions that work for one tend to work against the other.

**Operational dashboards:**
- Answer the question "what is happening right now?"
- Optimized for real-time or near-real-time refresh — seconds to minutes.
- Action-oriented: the person reading it is deciding whether to intervene.
- Metrics that matter are current value against threshold, not historical trend.
- Common in: on-call engineering monitoring, live sales floors, support queue management.

**Analytical dashboards:**
- Answer the question "what has been happening, and what does it mean?"
- Optimized for trend visibility over a meaningful time window — days, weeks, quarters.
- Insight-oriented: the person reading it is forming conclusions, not making real-time decisions.
- Metrics that matter are direction, rate of change, and comparison against prior periods.
- Common in: weekly product reviews, quarterly business reviews, growth analysis.

Where they fail:
- An operational dashboard with a 24-hour refresh cycle doesn't help an on-call engineer.
- An analytical dashboard with a 5-second refresh and no trend lines produces noise, not insight.

> [!tip] Ask the audience: "What action would you take if this number changed right now?" If they'd act immediately, you're building operational. If they'd note it for a weekly review, you're building analytical. Build accordingly.

@feynman

Like the difference between a cockpit instrument panel and a post-flight data analysis — one is for flying, one is for improving.

@card
id: cwd-ch06-c003
order: 3
title: Dashboard Hierarchy: Summary to Detail
teaser: Good dashboards follow a drill-down pattern — the top level shows the answer, lower levels show why.

@explanation

A dashboard built around a flat grid of equally-sized charts forces the reader to do the hierarchy themselves: which of these twelve charts is the one I should look at first? If the design doesn't guide attention, the reader's eye wanders and the dashboard fails at the one thing it's supposed to do quickly.

The drill-down pattern solves this with explicit hierarchy:

**Level 1 — Summary:** the headline answer to the primary question. One or two numbers, prominently displayed, immediately visible on load. Green or red before coffee. The reader should be able to determine "normal" or "investigate" without reading anything else.

**Level 2 — Dimension breakdown:** the same headline metric broken down by the most important dimensions — region, product line, team, service. Answers "where is the problem?" without requiring the reader to know what to filter by.

**Level 3 — Drill-down detail:** individual component metrics, time-series at fine granularity, or raw event counts. This level is only reached when the reader already knows something is worth investigating.

Implementation discipline:
- Most readers never reach Level 3 on a normal day. If Level 3 is always crowded, the Level 1 signal is weak.
- Each level should be reachable via a click or filter from the level above, not via a separate URL the reader has to find.
- Labels at each level should indicate what question that level answers, not just what data it contains.

> [!info] If the most-used dashboard element is the free-text search filter, the hierarchy is missing. The audience has to build their own structure because the dashboard didn't provide one.

@feynman

Like a well-structured error message — status first, context second, stack trace only if you need it.

@card
id: cwd-ch06-c004
order: 4
title: The KPI Card
teaser: One number, one trend indicator, one threshold — the KPI card is the most reused dashboard element because it delivers a complete micro-narrative in a single visual unit.

@explanation

The KPI card (key performance indicator card) is a self-contained visual unit that shows: the current value of a single metric, how it compares to the previous period, and whether it is within an acceptable range. It is small, dense, and immediately readable — which is why it appears in virtually every operational and analytical dashboard.

The three components of a well-formed KPI card:

**The number.** The current value, formatted for the audience — revenue in millions with one decimal, latency in milliseconds without scientific notation, completion rate as a percentage. Formatting decisions here are not cosmetic; they determine whether the reader can compare values mentally.

**The trend.** A delta from the previous period with a direction indicator — up or down, better or worse. Avoid raw deltas without context: "+12" means nothing; "+12% vs. last week" anchors the reader.

**The threshold.** The range the reader considers acceptable. This is often expressed as a target line, a color (green / amber / red), or a comparison to a goal. The threshold converts a measurement into a judgment — "this is fine" vs. "this needs attention."

What to leave out:
- Secondary metrics crowding the same card — they reduce the signal-to-noise ratio.
- Trend sparklines on KPI cards where the exact shape doesn't matter (use a separate sparkline element instead).
- Conditional formatting that changes meaning mid-dashboard — pick a color convention and hold it.

> [!warning] A KPI card with no threshold is a number with formatting. The threshold is what makes it an answer instead of a data point.

@feynman

Like a unit test result — pass/fail, the name of the test, and the delta from the last run. Everything needed to know whether to keep going.

@card
id: cwd-ch06-c005
order: 5
title: The Sparkline
teaser: A sparkline is a micro-chart that communicates trend without requiring full chart real estate — the visual equivalent of "has this been going up or down?"

@explanation

Introduced by Edward Tufte, a sparkline is a small, dense, word-sized chart embedded alongside text or numbers to show the shape of a trend. It is not designed to be read precisely — it is designed to be read directionally: "has this been going up, down, or flat over the relevant time window?"

Where sparklines earn their place:

**Inside KPI cards.** A KPI card with a sparkline communicates both the current value and recent trajectory in the same glance. The reader sees that revenue is $4.2M *and* that it has been consistently rising for six weeks without needing a separate chart.

**In tables.** A table of metrics with a sparkline column communicates relative trend across all rows in a single view — instantly showing which dimensions are improving and which are declining, without requiring the reader to switch between charts.

**Alongside monitoring thresholds.** A current value near a threshold becomes more actionable if the sparkline shows it has been approaching steadily, rather than fluctuating around that level.

Design rules:
- No axes, no labels, no gridlines. The sparkline is context, not the primary chart.
- Use consistent time windows across all sparklines in a dashboard — comparing a 7-day sparkline to a 30-day sparkline produces misleading visual comparisons.
- Scale each sparkline to its own data range, not a shared range, unless the absolute comparison is the point.

> [!tip] If the reader needs to know the exact shape of the trend — specific peaks, seasonality, year-over-year comparison — use a full time-series chart. Sparklines are for "still going up?" not "what happened in week 3?"

@feynman

Like the battery indicator on a phone — not the voltage, just the direction and rough magnitude.

@card
id: cwd-ch06-c006
order: 6
title: The Above-the-Fold Principle
teaser: The information that drives the primary question must be visible without scrolling — anything below the fold is information the reader may never see.

@explanation

The phrase comes from newspaper design: the most important story appears on the top half of the front page, visible before the reader unfolds the paper. On a dashboard, the fold is the bottom of the visible viewport on load. Everything below it requires active effort — a scroll, a tab switch, a click — that many readers will never take.

In practice, above-the-fold discipline means:

**The primary question's answer is always visible on load.** The headline KPI, the current status, the "everything is fine" or "something needs attention" signal — this lives at the top, full stop.

**Supporting context is below, detail is last.** Trend breakdowns, dimension splits, and drill-downs are progressively lower, ordered by decreasing importance to the primary question.

**Dense is not the same as above-the-fold.** Cramming twelve charts into the top quarter of the screen using tiny dimensions satisfies the letter of the principle but not the intent. If the reader can't read the critical number clearly, the position doesn't help.

Common violations:
- A dashboard where the most important metric is in row 4 because rows 1–3 show "background context."
- A navigation-heavy header that pushes all content below the fold on laptop screens.
- A two-column layout where the left column has decorative branding and the right column has the actual data.

> [!info] Test the fold empirically: open the dashboard on the device your primary audience uses and screenshot the initial view without scrolling. That screenshot is what most of your readers see. If the primary question's answer isn't in it, fix the layout.

@feynman

Like a CLI tool that prints the result on the first line — the exit code, the summary, then the verbose output below if you scroll.

@card
id: cwd-ch06-c007
order: 7
title: Avoiding Dashboard Clutter
teaser: Fewer metrics at higher quality beats more metrics at lower quality — every additional element on a dashboard is a fraction of the reader's attention budget.

@explanation

The path to a cluttered dashboard is always well-intentioned. Someone adds a metric "just for reference." A stakeholder asks for their department's number to be included. An engineer adds a technical health metric that's useful during incidents. Each addition seems reasonable in isolation. After six months, the dashboard has forty charts and no one knows which ones matter.

Clutter is a design problem with a structural cause: no metric was ever removed.

The cost of additional metrics:
- Every chart on a dashboard competes with every other chart for attention. Adding a 21st chart doesn't add 1/21 more value — it reduces the signal-to-noise ratio of the 20 that were already there.
- Readers learn to ignore cluttered dashboards. The cognitive cost of parsing forty charts on every visit is high enough that most readers will develop a shortcut — a different tool, a Slack message, a weekly email summary.
- Stale metrics on a dashboard implicitly communicate that the dashboard owner doesn't know what matters. If three of the forty charts have been showing "N/A" for two months, the reader questions the trustworthiness of the others.

Practical clutter reduction:
- For each metric on the dashboard, name the decision it informs. If no one can name it, the metric is decorative.
- Apply a one-in-one-out policy: adding a new metric requires removing one.
- Review the dashboard with usage analytics quarterly. Charts that receive zero clicks in 90 days are candidates for removal.

> [!warning] A dashboard that tries to serve every stakeholder ends up owned by none of them. Audience focus is not a political decision — it is the reason the dashboard gets used.

@feynman

Like a good API surface — smaller and coherent beats larger and exhaustive, because the caller can reason about what's there.

@card
id: cwd-ch06-c008
order: 8
title: The Three Governance Questions
teaser: Who updates it, who reads it, and how often — these three questions determine whether a dashboard stays healthy over time or slowly becomes a liability.

@explanation

A dashboard built without governance answers is a dashboard on a countdown timer. Every change to the underlying data model is a silent risk. Every team change is a gap in ownership. Every undocumented metric definition is a future argument.

The three questions to answer before launching any dashboard:

**Who updates it?**
- Which person or team owns the data pipelines the dashboard depends on?
- Who is responsible for updating the dashboard when the underlying schema changes?
- Is that person aware they have this dependency? Have they agreed to it?

**Who reads it?**
- Who is the primary audience? (A dashboard with no named audience will drift toward serving everyone and no one.)
- Do they have the context to interpret what they see correctly — especially thresholds, which require knowing what "good" looks like?
- Who handles questions when a reader misinterprets the data?

**How often?**
- What is the refresh cadence, and does it match the cadence at which the question is being asked?
- Is the dashboard reviewed on a schedule, or passively monitored? If passively monitored, what triggers a review?
- When is the dashboard itself reviewed for accuracy and continued relevance?

The answers should be documented alongside the dashboard — in the description, a linked wiki page, or a dashboard metadata field. A dashboard without documented owners is a shared liability that everyone assumes someone else is handling.

> [!tip] Treat a dashboard launch the same way as a service launch: document the owner, the SLA, the dependency graph, and the on-call path for "the dashboard is wrong."

@feynman

Like a cron job without a pagerduty integration — it may be working fine, but when it stops, no one knows whose problem it is.

@card
id: cwd-ch06-c009
order: 9
title: Common Anti-Patterns
teaser: The data dump dashboard, traffic lights for everything, and the dashboard nobody opens — three patterns that appear constantly and fail consistently.

@explanation

**The data dump dashboard.** Every available metric from the source system is included, organized by table or API endpoint rather than by question. The implicit belief is that if the data is visible, the insight will follow. It doesn't. Readers face a uniform grid of numbers with no hierarchy, no threshold guidance, and no clear primary question. The dashboard is technically comprehensive and practically useless.

Signs you have one:
- The dashboard has more than twenty distinct metrics.
- There is no clear "headline" element — all charts are the same size.
- Different teams use the dashboard for entirely different questions.

**Traffic lights for everything.** Every metric gets a red/yellow/green indicator. The intent is to make status scannable at a glance. The effect, when all forty metrics have traffic lights, is that readers can no longer distinguish a critical alert (revenue is down 30%) from a minor drift (page load time is 5ms above target). When everything is red, nothing is red.

Traffic lights are useful when:
- The set of metrics being colored is small (three to five).
- The thresholds are documented and agreed upon by the audience.
- The severity distinction between yellow and red is meaningful and actionable.

**The dashboard nobody opens.** Built by an engineer for a stakeholder who asked once, launched to polite acknowledgment, opened twice in the first week, never opened again. The root cause is almost always that the dashboard was built around available data rather than a recurring question the audience actually asks.

> [!info] The dashboard nobody opens is not a design failure — it is a scoping failure. The question was never real, or the audience found a better answer before the dashboard was ready.

@feynman

Like dead code — it was written with intent, it compiles, and it runs, but no one calls it anymore.

@card
id: cwd-ch06-c010
order: 10
title: Monitoring vs Reporting Dashboards
teaser: Monitoring dashboards are designed to catch something going wrong; reporting dashboards are designed to summarize what happened. The same dashboard rarely does both well.

@explanation

Monitoring and reporting are fundamentally different information needs, and the design requirements for each diverge sharply. Conflating them produces a dashboard that is slow for monitoring and too noisy for reporting.

**Monitoring dashboards:**
- Refresh at sub-minute intervals — often seconds for critical services.
- Optimized for detection speed: how quickly does an anomaly become visible?
- Alert integration is part of the design — the dashboard and the alert fire from the same threshold logic.
- Audience is on-call or actively watching; they are not summarizing, they are watching for deviation.
- Typical elements: current value vs threshold, recent time window (last hour, last 24 hours), event markers for deployments or config changes.

**Reporting dashboards:**
- Refresh at daily or weekly intervals — freshness matters less than accuracy and context.
- Optimized for pattern recognition: what trends, anomalies, and comparisons are worth attention?
- No alert integration — the audience reviews on schedule, not in response to a trigger.
- Audience reads in context: they bring background knowledge about what happened this week and use the dashboard to confirm or challenge it.
- Typical elements: week-over-week or month-over-month comparisons, cumulative metrics, benchmark lines against targets or prior periods.

The overlap trap: a monitoring dashboard reviewed once a week in a business review is used as a reporting dashboard but not designed for it. It shows the last 24 hours when the audience needs the last 30 days. The audience learns to extract what they need, but the friction is avoidable.

> [!warning] Do not use a live monitoring dashboard as the anchor for a weekly business review. The time window, refresh rate, and chart design are wrong for that use case. Build a separate reporting view.

@feynman

Like the difference between a smoke detector and a fire marshal's incident report — one is for now, one is for after.

@card
id: cwd-ch06-c011
order: 11
title: The Dashboard as a Shared Agreement
teaser: A dashboard isn't just a visualization — it is a team's documented agreement about what gets measured, how it is defined, and what counts as success.

@explanation

When a team rallies around a dashboard, something important happens beyond data visualization: the team has agreed on what matters. The act of putting a metric on a dashboard — and getting a team to use it — is the act of formalizing that metric as the definition of a thing the team cares about.

This is more consequential than it appears. Consider what it means for a growth team to display "weekly active users" as their headline KPI:
- They have agreed that a "user" means a specific thing (logged in? performed an action? triggered a specific event?).
- They have agreed that "active" means a specific thing (how many actions? in how many sessions?).
- They have agreed that "weekly" is the right cadence for evaluating this, not daily or monthly.
- They have agreed that this is the number that reflects whether the product is working.

Each of those agreements is nontrivial. Teams that haven't made them explicitly make them implicitly — and then discover the disagreement during a business review when two people pull the same metric and get different numbers.

Practical implications:
- Every metric on a shared dashboard should have a documented definition — not "monthly signups" but "count of distinct user accounts created in the calendar month, excluding test accounts."
- When the definition changes, update the dashboard and notify the audience. Silent definition changes are how trust in dashboards erodes.
- The dashboard is a contract. Treat changes to it with the same communication discipline as changes to a shared API.

> [!tip] If two people on the same team pull the headline metric and get different answers, the dashboard is not the problem — the missing definition is. Fix the definition before fixing the chart.

@feynman

Like a shared API contract — the value isn't just the data, it's that everyone calling it agrees on what the response means.

@card
id: cwd-ch06-c012
order: 12
title: Designing Around the Question, Not the Data
teaser: Every good dashboard was designed backward from the question it answers, not forward from the data available to populate it.

@explanation

The most common dashboard failure mode is also the most invisible: building around the data instead of the question. It happens because the data is concrete and available immediately, while the question requires conversation, prioritization, and sometimes organizational clarity that is harder to come by.

The data-first approach produces dashboards that:
- Reflect the schema of the source system rather than the logic of the audience's work.
- Include metrics because they exist and are easy to pull, not because they inform a decision.
- Require the reader to do the analysis themselves — extracting what matters from what's available.

The question-first approach starts differently:

1. Write the question the dashboard will answer: "Are we delivering features faster this quarter than last?"
2. Identify the metrics that answer it: cycle time, deployment frequency, lead time.
3. Define the thresholds that distinguish "yes" from "needs attention."
4. Find or build the data that populates those metrics.
5. Design the layout so the primary question's answer is immediately visible.

The sequence matters. Step 4 — finding or building the data — is done after steps 1 through 3, not before them. When the data doesn't exist, that is not a reason to change the question. It is a reason to build the pipeline.

Dashboard quality checklist:
- The primary question is written down somewhere — in the dashboard description, a linked doc, or the title.
- Every metric on the dashboard can be traced to that question or a named sub-question.
- The dashboard has a named primary audience who confirms the question is the right one.
- Metrics that exist "just in case" have been removed.

> [!info] A dashboard designed around the question will survive a data platform migration. A dashboard designed around the available data will be rebuilt every time the schema changes, because there was never a design — just a query.

@feynman

Like designing a test before writing the code — the question is the spec, and the dashboard is the implementation that proves you're meeting it.
