@chapter
id: cwd-ch08-mobile-realtime
order: 8
title: Mobile-First and Real-Time Chart Design
summary: A chart designed for a 1440px desktop becomes illegible at 375px mobile — and a real-time dashboard that refreshes every second is solving a different problem than a weekly business review chart.

@card
id: cwd-ch08-c001
order: 1
title: What Doesn't Survive the 375px Viewport
teaser: Most desktop charts fail at mobile not because of screen size alone, but because they were designed with assumptions that 375px quietly destroys.

@explanation

A 375px viewport doesn't just shrink your chart — it invalidates the design decisions underneath it. Desktop charts carry a set of implicit assumptions:

- The viewer can see fine detail at a distance.
- Hover is available as an interaction primitive.
- Enough horizontal space exists to render a full x-axis with readable labels.
- A legend with multiple labeled series fits alongside the chart body.
- SVG paths at 1px stroke width remain visible.

At 375px, every one of these collapses. Axis labels with 12–14 data points overlap or become unreadable. Legends shift below the chart and take more vertical space than the chart itself. Multi-series line charts with five lines in five colors become an indistinguishable tangle. Fine gridlines disappear or merge visually with the chart content.

The failure isn't scaling — it's that the original design never had to earn its complexity at small sizes. A legend is cheap on desktop. A second y-axis costs nothing at 1200px. On mobile, both become liabilities.

> [!warning] Hiding desktop elements with CSS media queries is not mobile chart design. It's desktop chart design with parts removed. The structure underneath needs to be different, not selectively hidden.

@feynman

Like trying to run a full-page newspaper layout at paperback size — the problem isn't font size, it's that the information architecture was never designed to compress.

@card
id: cwd-ch08-c002
order: 2
title: Chart Types That Work at Mobile Scale
teaser: The mobile constraint isn't a limitation to fight — it's a forcing function that surfaces which chart type actually fits the information need.

@explanation

Some chart types scale to 375px without structural rework. Others require replacement, not resizing.

Charts that work at mobile scale:

- **Sparklines** — a trend line in ~120×40px, no axes, no labels, maximum information density per pixel.
- **Single-metric cards** — a large number, a label, and an optional delta indicator. Answers one question per card.
- **Horizontal bar charts** — bar labels on the left, values extend right. Labels don't overlap because they stack vertically.
- **Donut charts with a center number** — works for part-to-whole with two or three segments. More than four segments fails at any size.
- **Area charts, single series** — fill makes the trend readable even when the line itself is thin.

Charts that require replacement at mobile scale:

- **Multi-series line charts** — replace with small multiples (one chart per series, stacked vertically) or a ranked list.
- **Scatter plots** — too much density at small size; consider binning into a heatmap or switching to a ranked table.
- **Stacked bar charts with many segments** — reduce to two segments or replace with a proportional indicator.
- **Dual y-axis charts** — always a design smell; at mobile they become unreadable. Split into two single-axis charts.

> [!tip] A ranked list with inline sparklines often outperforms a complex chart at mobile scale — it's scannable, tappable for detail, and requires no legend.

@feynman

Like choosing the right tool for a pocket versus a workbench — a combination square belongs at the bench; a tape measure lives in the pocket.

@card
id: cwd-ch08-c003
order: 3
title: Label Strategy at Small Screen Sizes
teaser: Labels at mobile aren't a scaling problem — they're a prioritization problem. Not every label needs to survive; only the ones earning their space should stay.

@explanation

Desktop charts often label everything because the space cost is low. At 375px, the space cost of every label is high. The design decision is not "how small do I make the labels?" but "which labels are necessary?"

A hierarchy for mobile label decisions:

- **Axis titles:** usually removable if the chart title already establishes the variable. "Monthly Revenue ($K)" as an axis title is redundant when the chart title says "Revenue by Month."
- **Y-axis labels:** consider keeping only the top and bottom values to establish scale. Remove intermediate gridline labels.
- **X-axis labels:** for time series, show first, last, and one or two midpoints. For categorical axes, show only if the bars are wide enough — otherwise tooltip on tap.
- **Data labels (values on bars/lines):** on mobile, defer to tap-to-detail rather than cluttering every bar with a number.
- **Legend:** if you have one series, remove the legend entirely. For two or three series, consider labeling the last data point directly instead of a separate legend element.

Truncation is a last resort, not a first move. "Software Eng..." communicates less than removing the label and letting a tap show the full value. When you must truncate, use a consistent character limit and a tooltip or detail view for the full string.

> [!info] The goal is not a readable version of the desktop chart. The goal is a chart that answers the same question the viewer came to ask, with the minimum label overhead needed to do it.

@feynman

Like a billboard — the constraint (read at 70mph) forces the copy down to what actually needs to be said, not what would fit if the reader had more time.

@card
id: cwd-ch08-c004
order: 4
title: Touch Interaction Patterns: Tap vs Hover
teaser: Hover is a free affordance on desktop. On mobile there is no hover — and designing as if there were produces charts that hide data with no way to retrieve it.

@explanation

Hover tooltips are the dominant desktop interaction for chart detail. They're frictionless — no click required, no state change, just proximity. On mobile, hover doesn't exist. A user who taps a bar or data point expects a state change: a tooltip, a slide-up panel, or navigation to a detail view.

The shift in interaction primitives requires a different architecture:

**Tap-to-tooltip:** A tap on a data point shows a floating tooltip at the tap location. Works well for single data points. Requires a hit area large enough to target reliably — minimum 44×44px target per iOS HIG guidelines. Fine-grained data points on a dense line chart fail this test.

**Tap-to-detail:** A tap navigates to or reveals a detail view — a full card, a drawer, or a new screen. Works well for ranked lists with inline charts where each row represents an entity. The chart is the summary; the detail view is the data.

**Tap-and-hold for context:** Available but rarely used in data contexts. Adds complexity for minor gain.

**Pinch-to-zoom on time series:** Useful for financial or operational charts where users need to inspect fine-grained intervals. Requires engineering investment; use only when the user's task genuinely requires temporal zoom.

Design decisions that follow from the tap model:
- Hit areas must be explicit and minimum 44px. Data points smaller than this need enlarged invisible tap targets.
- Tooltips must be anchored to not be obscured by the user's thumb — position above the tap point, not below.
- Tap-activated state must be dismissible — either a second tap, or a dismiss gesture.

> [!tip] Audit every tooltip in a desktop chart and ask: "is the information in this tooltip available on a tap in the mobile version?" If not, it's hidden data — redesign the interaction or promote the data into the visible layer.

@feynman

Like the difference between browsing a shelf (hover) and picking up a book to read the back (tap) — the same information, but the action cost and the design contract are different.

@card
id: cwd-ch08-c005
order: 5
title: The Sparkline on Mobile: Maximum Trend per Pixel
teaser: The sparkline isn't a stripped-down chart — it's a purpose-built primitive for communicating trend in constrained space, and mobile is the environment it was designed for.

@explanation

Edward Tufte defined the sparkline as a "data-intense, design-simple, word-sized graphic." On mobile, this is the design brief for half the chart problems you'll encounter.

A sparkline encodes one thing: the shape of a trend. It has no axes, no labels, no legend. Its job is to let a viewer answer the question "is this going up, down, or sideways?" without requiring focused reading.

Sparklines work on mobile because:
- They fit in the space of a single line of text — ~120×40px.
- They require no label overhead.
- They compose well in lists — a ranked table where each row has a name, a value, and a sparkline communicates trend across all entities simultaneously.
- A delta indicator (a small number, a colored arrow) adds the "how much?" without axes.

Implementation decisions that matter on mobile:
- **Stroke width:** 1.5–2px on a 2× or 3× screen. Thinner disappears at small size; thicker reads as decoration.
- **Baseline:** don't always start the y-axis at zero. For a sparkline, relative shape matters more than absolute scale — show the full range of the data unless cross-row comparison is required.
- **Color:** a single semantic color (green for up, red for down) communicates direction faster than value. Use it for the terminal segment or the fill.
- **Length:** 12–20 data points is the practical range. Fewer flattens the shape; more makes individual points unreadable.

> [!info] When using sparklines in a list, keep y-axis scaling consistent across rows only if cross-row comparison is the task. If each row represents an independent entity, scale each sparkline to its own range — the shape, not the magnitude, is what the viewer needs.

@feynman

Like a stock ticker's mini chart — the single line in 100 pixels communicates more about the last year than any table of numbers would.

@card
id: cwd-ch08-c006
order: 6
title: Real-Time Dashboard Patterns: When Freshness Drives Action
teaser: A real-time dashboard is only justified when stale data would cause a wrong decision. Most "real-time" dashboards don't clear that bar.

@explanation

"Real-time" is a word that signals intent more than it describes a requirement. Before designing a dashboard with live refresh, the relevant question is: what decision does this data inform, and how stale can it be before the decision degrades?

Three categories, by data freshness requirement:

**Operational dashboards (seconds to minutes):** the user is responding to events as they occur. Examples: incident response dashboard, payment fraud queue, CDN error rate monitor. Stale data would cause the responder to act on a condition that no longer exists or miss a condition that just started. Sub-minute refresh is justified.

**Analytical-operational dashboards (minutes to hours):** the user is tracking a trend or a KPI and making tactical decisions. Examples: sales pipeline view, marketing campaign CTR, daily active users. Five-minute staleness rarely changes the decision. Fifteen-minute refresh is usually sufficient.

**Analytical dashboards (hours to days):** the user is building understanding, not reacting to events. Examples: weekly cohort retention, quarterly revenue trend, A/B test results. Real-time refresh is wasted infrastructure and wasted rendering cycles. Daily or hourly refresh is correct.

The cost of incorrect freshness classification:
- Under-refreshed operational data → wrong decisions or missed incidents.
- Over-refreshed analytical data → unnecessary infrastructure cost, higher battery drain, and a chart that jitters when the viewer is trying to read it.

> [!warning] A dashboard that refreshes every second but whose users make decisions every hour is an infrastructure and battery problem disguised as a feature. Match the refresh rate to the decision cadence, not to what's technically possible.

@feynman

Like the difference between a hospital vital signs monitor and a quarterly earnings chart — one needs the last five seconds, the other needs the last ninety days; building both with the same refresh rate is a category error.

@card
id: cwd-ch08-c007
order: 7
title: Operational vs Analytical Refresh Rates
teaser: The refresh rate is a product decision, not a technical setting. It should match the cadence at which the viewer's decisions change, not the cadence at which the data changes.

@explanation

Data freshness and refresh rate are not the same thing. Data can arrive continuously at the backend while the UI refreshes at a fixed interval. The UI refresh rate is a separate decision with separate consequences.

Appropriate refresh rates by use case:

**Sub-10 seconds:** incident response, live service health, fraud detection queues. The user is actively watching and reacting. Justified only when a 10-second lag changes the response.

**30 seconds to 2 minutes:** live operational metrics (requests per second, queue depth, error rate) where a user monitors and intervenes. A 60-second chart refresh that shows a 30-second rolling window is the right balance for most SRE dashboards.

**5 to 15 minutes:** campaign performance, conversion rates, A/B test live results. The user glances periodically, not continuously. A stale-while-revalidate pattern works well — show cached data immediately, refresh in the background.

**Hourly:** business metrics, DAU/MAU, revenue. Intraday freshness adds noise without insight. A scheduled refresh or a "refresh" button gives the user control without constant background polling.

**Daily or batch:** cohort analysis, retention curves, strategic KPIs. These should not auto-refresh. They should reflect a defined reporting period.

The implementation pattern for each tier differs:
- Sub-10 second: WebSocket or SSE.
- Sub-2 minute: short-interval polling or SSE with client-side buffer.
- 5–15 minute: polling with stale-while-revalidate.
- Hourly+: scheduled batch; manual refresh button sufficient.

> [!tip] Publish the refresh rate visibly on every dashboard panel. "Updated every 60s" is information the viewer needs to calibrate how much to trust what they see.

@feynman

Like the difference between a minute hand and a second hand on a clock — both are "real-time," but only one is useful to glance at from across the room.

@card
id: cwd-ch08-c008
order: 8
title: The "Updated X Minutes Ago" Pattern
teaser: Data freshness metadata is as important as the data itself — a metric without a timestamp is an assertion without a source.

@explanation

Every chart on a dashboard should answer the question: "when was this data last accurate?" Without that, a viewer looking at a metric that shows "0 errors" cannot distinguish between "no errors occurred" and "data collection broke 20 minutes ago."

The "updated X minutes ago" pattern communicates freshness without overloading the chart:

- A small timestamp below or beside the chart title: "Updated 3 min ago."
- A relative time ("3 min ago") is more readable at a glance than an absolute timestamp ("14:37:02"). Absolute time is appropriate when the viewer needs to correlate across data sources.
- Stale data should change visual state — a muted color, a clock icon, a warning badge. The chart should not look identical at 30 seconds stale and 30 minutes stale.
- For dashboards with multiple panels, each panel's freshness should be independently displayed, not a single global "last updated" footer. Different panels often have different backends and refresh rates.

Implementation decisions:
- The timestamp should reflect when the data was last fetched and successful, not when the page loaded.
- If a refresh fails, show the last successful fetch time, not silence. "Updated 47 min ago" is better than a spinner that never resolves.
- For mobile, consider showing freshness only on tap — it's metadata, not primary content, and mobile screen space is expensive.

> [!info] A dashboard that doesn't surface data freshness forces every viewer to wonder whether they're looking at live data or a stale snapshot. That uncertainty is a cost paid by every session.

@feynman

Like "best by" dates on food — the value is in the package, but the date is what tells you whether to trust it.

@card
id: cwd-ch08-c009
order: 9
title: Streaming Data Visualization
teaser: Streaming data is not the same as fast-refreshing data — it arrives continuously, and the chart must decide what window of history to show and how to handle the arrival visually.

@explanation

A chart connected to a stream is not a chart that refreshes frequently. It's a chart with a continuously advancing data window. The design decisions differ substantially from a batch-refresh chart.

The core question for any streaming chart: **what time window does the viewer care about?**

- A 60-second rolling window chart shows the last minute of data. As new data arrives, old data exits the left edge.
- A fixed-epoch chart shows data from a defined start time (e.g., the start of the current deployment). Data accumulates from left to right until the epoch ends.
- A landmark-relative chart shows data relative to an event (e.g., time since last error, time since deploy). The x-axis resets when the landmark resets.

Visual update patterns:
- **Append and scroll:** new data appends to the right edge; the chart scrolls left. Simple to implement; natural for the viewer.
- **Overwrite with fade:** incoming data overwrites the rightmost position and older data fades in opacity. Useful for dashboards with a fixed window where the viewer is comparing "now" to "a few seconds ago."
- **Accumulate and rebase:** data accumulates from the start of a session or period; a "reset" action clears the chart and starts over. Useful for per-deployment or per-experiment contexts.

Performance note: appending data at the DOM level with every frame is expensive. Batch DOM updates to 1–2 per second even if data arrives at 10Hz. The viewer cannot read 10Hz anyway.

> [!tip] Decide the time window and the update pattern before choosing a chart type. The window defines how much data is ever visible; the update pattern defines how arrival is communicated. Both are product decisions, not implementation details.

@feynman

Like a train departure board — new trains appear, old ones drop off, and the viewer always sees the current window, not the full history of every train that ever ran.

@card
id: cwd-ch08-c010
order: 10
title: Performance Considerations: Rendering, Battery, and Data
teaser: A chart that updates every second on mobile is burning battery and data. These aren't technical footnotes — they're product quality signals that users feel.

@explanation

Rendering cost is invisible on a desktop plugged into power and ethernet. On a mobile device on cellular, it surfaces as heat, battery drain, and data overage. A dashboard that feels fast on a developer's laptop can feel hostile on a user's iPhone.

The performance budget for mobile charts:

**Rendering:** SVG re-render on every data update is expensive at high frequency. For charts refreshing faster than every 5 seconds, consider canvas-based rendering, or update only the changed elements rather than re-rendering the full chart. React-based chart libraries that diff and reconcile are better than full redraws, but they still have overhead at high frequency.

**Battery:** JavaScript polling at 5-second intervals keeps the CPU active and prevents the device from entering low-power state. This is the difference between a dashboard that's usable for an afternoon and one that drains the battery in 90 minutes. Use background fetch APIs and event-driven updates where available. Pause polling when the app is backgrounded or the screen is off.

**Data usage:** a chart that fetches a full JSON payload every 30 seconds is making ~120 requests per hour. On cellular, this is real cost. Use incremental data endpoints (delta payloads) rather than full refresh where possible. Cache aggressively on the client.

**Animation:** smooth transitions between data updates look polished and help the viewer track changes — but a 300ms animation running every 5 seconds means the chart is animating 12 times per minute. Keep transitions short (150ms) and ensure they complete before the next update arrives.

> [!warning] A real-time chart that doesn't consider battery and data usage is a desktop chart accidentally deployed to mobile. Performance requirements belong in the same design document as visual requirements.

@feynman

Like a background process that continuously polls a server — it works, but it's the wrong architecture once you realize it's running on battery instead of mains power.

@card
id: cwd-ch08-c011
order: 11
title: The Always-On Dashboard: Designing for Peripheral Awareness
teaser: Some dashboards aren't read — they're watched. The design contract for a display that lives on a TV or mounted tablet is completely different from a chart that someone navigates to.

@explanation

An always-on dashboard — a NOC wall display, a mounted tablet in a retail store, a TV in an office — is not read like a chart. It's perceived peripherally. The design contract is radically different:

**The viewer is not interacting.** There's no tap, no hover, no scroll. The entire information payload must be visible simultaneously and readable from a distance of 2–5 meters.

**The viewer is monitoring, not analyzing.** The question is always some variant of "is anything wrong?" not "what was revenue last quarter?" Anomaly detection is the primary job.

Design principles for peripheral awareness displays:

- **Large text and high contrast.** Numbers should be readable at 3 meters. 48px on a 1080p screen is the minimum for primary metrics. Dark background with light text reads better under varied lighting than light background.
- **Color semantics must be binary.** Green means fine. Red means attention needed. Amber means degraded. Don't use color for categorical comparison — save it entirely for status.
- **Animation for attention, not decoration.** Flashing or animated elements should signal anomaly, not aesthetics. If nothing is wrong, the display should be static.
- **Minimal information density per panel.** One metric per panel with a large number, a label, and a trend indicator. Viewers who need detail should go to a workstation.
- **Auto-cycling panels** (carousel mode) only if all panels are equal priority. For NOC displays, show all critical metrics simultaneously — never hide a problem behind a carousel rotation.

> [!info] If the display requires someone to walk closer to read it, the font size is wrong. Design for the farthest viewer in the room, not the person standing next to it.

@feynman

Like traffic lights — a binary color signal readable at 50 meters, not a detailed readout that requires stopping the car to interpret.

@card
id: cwd-ch08-c012
order: 12
title: Anti-Pattern: Shrinking a Desktop Chart to 375px
teaser: The most common mobile chart failure is not a design decision — it's the absence of one. A desktop chart at 375px is not a mobile chart; it's a broken desktop chart.

@explanation

The default behavior of most charting libraries at small viewport widths is to reflow or scale. The SVG shrinks. Labels overlap or disappear. The chart becomes technically present but practically unreadable. This is not mobile chart design.

The structural differences between a desktop chart and its mobile equivalent are not cosmetic:

- **Desktop:** multi-series line chart with five lines, a legend, two y-axes, hover tooltips, and x-axis labels at every data point.
- **Mobile:** small multiples — five separate single-series sparkline cards, each labeled with the series name, each tappable for a detail view.

The same data, a completely different structure.

What teams get wrong:
- Adding `max-width: 375px` and calling it responsive.
- Using `overflow: hidden` to cut off labels instead of redesigning the label strategy.
- Preserving complex interactions (hover, brush) that have no mobile equivalent.
- Keeping the legend because removing it would require refactoring the chart component.

The correct process is to start from the mobile use case as a first-class design problem:
1. What question is the mobile viewer asking?
2. What chart type answers that question at 375px?
3. What is the tap interaction model?
4. What information is deferred to a detail view?

Desktop and mobile can share data fetching, business logic, and component architecture. They should not share chart structure.

> [!warning] "Responsive chart" is not a chart property you configure. It's a design commitment that requires maintaining two different visual representations of the same data — one for desktop, one for mobile — and deciding where the handoff between them happens.

@feynman

Like translating a book — the content is the same, but the sentence structure, the idioms, and the length must all be reworked for the new language; copying the original and making the font smaller is not a translation.
