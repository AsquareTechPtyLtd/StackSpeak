@chapter
id: edv-ch12-misleading-visualizations
order: 12
title: Misleading Visualizations
summary: The most common ways charts lie — truncated axes, dual scales, area illusions, cherry-picked ranges, and 3D distortions — and how to identify them in charts you're reading as well as ones you're building.

@card
id: edv-ch12-c001
order: 1
title: Truncated Y-Axis on Bar Charts
teaser: Starting a bar chart's y-axis above zero makes small differences look large — it's technically labeled but visually dishonest, and it's the most common misleading chart technique in business.

@explanation

A bar chart's visual contract: bar height = value. When the y-axis starts at zero, a bar twice as tall represents twice the value. When the y-axis starts at, say, 95, a bar that is twice as tall might represent a value that is only 1.05× as large (the difference between 95.1 and 100.5 on a scale starting at 95).

The truncation doesn't remove data — the actual values are still on the axis. But the visual impression is wrong because readers decode bar height as proportional to value before they check the axis scale.

Example: a bar chart of approval ratings (candidate A: 52%, candidate B: 48%) on a y-axis from 46% to 54%. The 52% bar looks 6× as tall as the 48% bar. On a 0–100 scale, the difference is visually small. The truncated scale makes a 4-point difference look overwhelming.

Tests for truncated y-axis:
- Does the y-axis start at zero or near the data range minimum?
- If the tallest and shortest bars were compared, does the visual height ratio match the actual value ratio?
- Would the chart look like it's making a weaker argument if the y-axis started at zero?

When non-zero baselines are legitimate: only for line charts and dot plots (not bar charts). For continuous time series, a non-zero y-axis is often appropriate if the focus is on variation, not absolute magnitude. The key: use a line chart or dot plot, not a bar chart, for data that doesn't have a meaningful zero reference.

> [!warning] The existence of an axis label showing the non-zero starting point does not make a truncated bar chart honest. The label is text; the reader processes the bar heights preattentively before reading the axis. The mislabeled visual impression is already in place.

@feynman

Like an integer overflow that shows the correct modular value in the debugger — the value displayed is technically correct by the encoding rules, but it produces a wrong result in every downstream calculation that assumes linear arithmetic.

@card
id: edv-ch12-c002
order: 2
title: Misleading Dual-Axis Charts
teaser: When two series share a chart with different y-axes, the visual relationship between the lines is determined by the designer's axis scaling choices — not by the data.

@explanation

A dual-axis chart places one y-axis on the left (for one series) and one on the right (for a different series). Both series appear to share a common chart space, creating an apparent visual relationship between them.

The problem: the visual relationship between the lines is a function of the axis scales, which are arbitrary. By choosing where to set the left and right axis ranges, the designer can make the two lines:
- Perfectly overlapping (implying strong correlation).
- Cross at any specific date (implying a meaningful intersection).
- Look parallel (implying no relationship).

None of these visual relationships are in the data. They are all consequences of axis scaling choices.

The implicit message: when two lines appear close together or overlapping on the same chart, readers infer they are related. The dual-axis format exploits this inference.

Common misleading use: a chart showing "revenue" (in millions) and "marketing spend" (in thousands) on dual axes, scaled so they appear to move together. The correlation is in the eye of the designer, not the data.

Solutions:
- **Separate charts, shared time axis.** Same information, no misleading visual alignment.
- **Index both to 100 at period start.** Now both series are on the same scale (% change from baseline) and visual alignment is meaningful.
- **Show the actual correlation separately** as a scatterplot of the two variables, with an honest label.

> [!warning] Many BI tools (Tableau, Power BI, Looker Studio) offer dual-axis charts as a standard chart type. The tool's availability of the format doesn't make it honest. Reject requests for dual-axis charts and offer the indexed-to-100 alternative.

@feynman

Like a unit test that compares two different functions by wrapping them to return values on different numeric scales and declaring them equivalent when both return a positive number — the comparison looks valid but is not.

@card
id: edv-ch12-c003
order: 3
title: Area and Size Illusions
teaser: When a quantity is encoded as the area of a 2D shape or the volume of a 3D shape, small values look proportionally larger than they are — the human visual system compresses area and volume perception.

@explanation

**Area illusions** occur because humans perceive size differences as smaller than they are. A circle with 4× the area appears roughly 2–2.5× as large, not 4×. This means:
- A bubble chart's largest bubble looks much less dominant than its data value suggests.
- An area chart's visual peaks look smaller than bar charts of the same data.
- Proportional symbol maps understate the dominance of large values.

The systematic error: researchers measure the perceived ratio S to the actual ratio R as S ≈ R^0.87 (Stevens' psychophysical law for area). For a 4:1 ratio, perceived ratio ≈ 4^0.87 ≈ 3.3, not 4.

**Volume illusions** are worse. For 3D volumes, the perceived ratio is even more compressed. A 3D sphere with 8× the volume looks roughly 4× as large. 3D bar charts use this to make differences appear smaller (or larger, by reversing perspective) than they are.

Practical consequences:
- Bubble charts where the key comparison is between very similar values are useless. The values need to differ by at least 2–3× to be reliably distinguishable.
- Area charts (where area below the line encodes magnitude) systematically understate the dominance of high values.
- 3D pie charts make back slices look smaller than front slices even when the angles are identical.

The solution is to use position or length encodings where precision matters, and to reserve area encodings for rough-order-of-magnitude comparisons.

> [!info] Providing exact values as labels inside or adjacent to circles/spheres does not eliminate the area illusion — the visual impression is already formed before the reader reads the label. Label values are a supplement to, not a substitute for, accurate encoding.

@feynman

Like hash collision rate — in theory your hash is distributed uniformly; in practice the human brain's hash function for visual area has a systematic bias, and designing for theory (area = value) produces predictable misreads.

@card
id: edv-ch12-c004
order: 4
title: 3D Charts
teaser: 3D charts introduce perspective distortion that makes the same value look different depending on its position in the 3D space — there is no legitimate use case for a 3D bar or pie chart.

@explanation

3D bar charts, 3D pie charts, and 3D line charts apply a perspective transform to a 2D chart. The result:
- Bars at the front of the chart appear taller (closer to the viewer) than identical bars at the back.
- Pie slices at the front of the chart appear larger than identical slices at the back.
- Values in the "foreground" of the 3D perspective are systematically distorted relative to background values.

This distortion is not a display artifact — it is inherent to the 3D perspective transform. There is no way to render a 3D chart without this distortion.

Why 3D charts persist:
- They look impressive in PowerPoint and Excel.
- They give the impression of analytical sophistication.
- Default templates in many presentation tools are 3D.

Arguments made for 3D charts and why they fail:
- "The perspective helps readers understand depth." There is no depth dimension in the data. The "depth" is decoration that distorts the actual values.
- "Readers can still read the values from the labels." Label reading is serial cognition; the preattentive visual impression of height is already set before the reader reads labels. The chart still misleads on first impression.
- "The 3D effect is just aesthetic." Perspective distortion changes apparent bar heights and slice angles. It is not aesthetic; it is a factual error.

**There is no chart type where a 3D version is more accurate than the 2D equivalent.** The 3D version is always worse for comprehension.

> [!warning] If a stakeholder requests a 3D chart, explain the perspective distortion using a concrete example: make two adjacent bars of equal height and show how the perspective transform makes them appear different heights. This is usually sufficient to convert the request.

@feynman

Like rendering a function's execution trace in fake 3D in a profiler UI — the visual impression of "depth" implies information that isn't there, and the perspective distortion makes actual time differences harder to read than a flat bar.

@card
id: edv-ch12-c005
order: 5
title: Cherry-Picked Date Ranges
teaser: Starting or ending a time series at a date chosen to support the conclusion is one of the most pervasive forms of misleading visualization — and the most defensible to the author, who can claim they "just showed recent data."

@explanation

A time series chart can be made to tell almost any story by choosing the start and end date carefully. A company with declining 5-year revenue can show "record growth" by starting the chart at the lowest point of the trough. A company with growing revenue can show "flattening" by starting the chart at the most recent peak.

Common forms of cherry-picked date ranges:
- **Starting at a trough:** shows maximum growth from the selected start point.
- **Ending before a decline:** the chart shows a rising trend that reversed after the chart's end date.
- **Showing only the favorable period:** selecting the 12 months that look best out of 36 months.
- **"Latest data":** charts that show the last 30 days when the longer trend is different.

The reader's defense: always check the chart's time range against what you know about the domain. "Why does this start in March 2023?" If there's no methodological reason (data availability, policy change, etc.), ask.

The author's defense: explicitly acknowledge the time range limitation in the subtitle or caption. "Showing 2024–2025; earlier periods showed different patterns." This does not fully eliminate the misleading impression but makes the limitation visible.

Best practice: show the longest available time range in the primary chart, and add a "zoomed" inset or linked chart for recent detail. This allows both the long-term context and the recent trend to be visible.

> [!tip] When reviewing a chart for a decision, ask "what does this chart look like with the full available history?" If the stakeholder can't answer or the full history looks different, the date range is suspect.

@feynman

Like A/B test analysis that starts analyzing at day 3 of a 14-day experiment because that's when the metric crossed significance — the date was chosen for its result, not for its methodological validity.

@card
id: edv-ch12-c006
order: 6
title: Misleading Cumulative Charts
teaser: A cumulative chart that never decreases looks like sustained growth even when the underlying rate is declining — because the cumulative total can only go up, it hides the deceleration.

@explanation

A **cumulative chart** plots the running total of a metric over time. Total users ever registered, total revenue since launch, total commits in a repository. A cumulative total can only increase; it can never decrease (ignoring deletions). As a result, cumulative charts look like growth charts even when:
- The daily/weekly/monthly rate is flat.
- The rate is declining.
- The metric is dead and has been for months.

A cumulative user chart for a product with 1M users that acquired its last user 2 years ago shows a perfectly upward-sloping line. The product looks healthy. The daily rate chart would show a flat line at zero.

When cumulative charts are appropriate:
- Showing total investment, total infrastructure deployed, total events processed — quantities where the total is the meaningful metric.
- Burn down charts in reverse: showing remaining work rather than completed work.

When they are misleading:
- Showing user growth when the actual user count matters (total registered ≠ total active).
- Showing cumulative revenue instead of periodic revenue when momentum is the question.
- Comparing cumulative metrics across groups with different ages (an older group will almost always have a higher cumulative total regardless of performance).

The fix: always show the periodic rate (daily, weekly, monthly increments) alongside or instead of the cumulative total when velocity is the message.

> [!warning] "We've served 10 billion requests" as a cumulative metric could mean the service is high-volume and healthy, or that it served 9.9 billion requests three years ago and now processes nearly nothing. The chart doesn't tell you which.

@feynman

Like a git blame showing a file last modified in 2019 — the file exists and has content, but the cumulative line count is stable and reveals nothing about whether anyone is actively maintaining it.

@card
id: edv-ch12-c007
order: 7
title: Base Rate Neglect and Misleading Rates
teaser: A chart showing absolute counts without normalizing for the underlying base rate misleads whenever groups have different sizes — comparisons of raw counts imply proportionality that isn't there.

@explanation

**Base rate neglect** is showing absolute counts when rates or proportions are the appropriate comparison.

Example: "Hospital A had 50 patients die from a procedure; Hospital B had 30 patients die." Hospital A looks much worse. But if Hospital A performed 1,000 procedures and Hospital B performed 200, the death rates are 5% vs 15%. Hospital B is dramatically worse.

The raw count comparison is meaningless for comparing hospitals; the rate comparison is meaningful. But the bar chart of absolute counts is visually compelling and tells the wrong story.

Common forms:
- **User counts without active user base normalization.** "Feature X was used by 10,000 users in Group A and 5,000 users in Group B" — meaningful only if you know Group A has 100,000 users and Group B has 20,000.
- **Revenue comparisons across age cohorts.** Older cohorts have had more time to generate revenue; per-cohort-day revenue is the fair comparison.
- **Bug counts without code size normalization.** A service with 10 bugs might be more reliable than one with 5 bugs if it handles 20× the code complexity.

The visualization fix: normalize before plotting. Compute the rate (count / denominator), plot the rate, and label the denominator clearly in the subtitle or caption.

> [!tip] Before committing to a visualization of counts, ask: "Is this group larger in the denominator?" If yes, normalize. The normalization step is a data transformation decision that must happen before the chart, not a chart formatting choice.

@feynman

Like comparing memory leak sizes in absolute bytes without normalizing for runtime — a process that allocated 10 GB and leaked 100 MB is leaking 1%; a process that allocated 200 MB and leaked 50 MB is leaking 25%; the absolute number misleads about relative severity.

@card
id: edv-ch12-c008
order: 8
title: Misleading Pie Charts and Donut Charts
teaser: Pie charts with unlabeled "Other" slices, slices that don't sum to 100%, or 3D perspective distortion produce systematically wrong impressions of proportion.

@explanation

Pie charts are misused in three specific ways that produce false impressions:

**Missing or small "Other" slice:** a pie chart showing 7 named categories plus "Other" where "Other" is unlabeled or very small implies the 7 categories are nearly the whole. If "Other" is 30% of the total, showing it as a thin unlabeled sliver creates a false impression that the named categories dominate.

**Slices that don't sum to 100%:** a pie chart where the slices sum to 110% (because the categories overlap or the data was wrong) is geometrically incorrect. Every slice is drawn smaller than its proportion of the total. This is a data error rendered as a chart, but the error is invisible to most readers.

**3D distortion:** front slices appear larger. A 15% slice at the front of a 3D pie looks larger than an identical 15% slice at the back. This is the most obvious form of visual dishonesty in commercial charts.

**Starting angle manipulation:** pie charts are typically drawn starting at 12 o'clock. The starting slice gets a "top" position that makes it visually prominent. Choosing which slice to start with is a rhetorical choice.

For donut charts specifically: the hole in the center should never contain anything except a summary total or a key number. Text, icons, or imagery inside a donut chart obscure the slice comparison and create more visual confusion.

> [!info] Accessible pie and donut charts must include explicit percentage labels on each slice. Color alone is insufficient — colorblind readers cannot distinguish slices by hue.

@feynman

Like a compiler warning suppressed with a pragma comment — the error is real; the suppression makes it invisible to readers who don't know to look for it; the output behaves incorrectly for anyone who trusts the surface appearance.

@card
id: edv-ch12-c009
order: 9
title: Smoothing That Hides Volatility
teaser: An over-smoothed trend line can make a volatile or declining metric look stable and healthy — the smoothing parameter is a rhetorical choice that deserves disclosure.

@explanation

Smoothing converts a noisy time series into a cleaner trend. When applied honestly, it reveals the underlying pattern beneath the noise. When applied to mislead, it removes real signals:

**Hiding recent decline:** a 6-month rolling average applied to a metric that started declining 2 months ago will still show a flat or gently declining line — not the sharp drop that's actually happening. The rolling average lags by half the window size.

**Hiding volatility:** a heavily smoothed line that looks like steady growth may correspond to a metric that gyrates ±30% weekly. The underlying volatility represents risk; the smoothed line hides it.

**Ignoring outliers:** some smoothing methods remove extreme points. If the extreme points are real events (a large deal, a major outage, a viral moment), removing them distorts the trend.

The disclosure test: if a chart shows a smoothed trend, it must also show:
- What smoothing method was used.
- The window size or bandwidth.
- The raw underlying data (as a faint line or dots).

A chart that shows only a smooth line without the raw data, without disclosing the smoothing parameters, is making a claim about the trend that the reader cannot verify.

> [!warning] In AI-assisted data analysis tools (ChatGPT Data Analysis, Claude Code, Gemini), default plot outputs sometimes apply smoothing without disclosure. Check every AI-generated trend visualization for undisclosed smoothing before using it in a decision context.

@feynman

Like minifying and obfuscating JavaScript before code review — the output is technically equivalent but the review process cannot verify correctness because the intermediate steps are hidden.

@card
id: edv-ch12-c010
order: 10
title: How to Read a Chart Critically
teaser: A systematic set of questions applied to any chart before trusting it catches the most common misleading techniques in under 2 minutes.

@explanation

Before trusting a chart that will influence a decision, run these checks:

**Axis checks:**
- Does the y-axis start at zero? If not, is it a bar chart (always wrong) or a line chart with a justified non-zero baseline?
- Are the axis scales the same for both axes on a dual-axis chart? If not, is the visual alignment claimed as evidence of something?
- Is the x-axis (time axis) showing the full available history, or a selected range? Why was that range chosen?

**Data checks:**
- What is the denominator? Are counts normalized to rates?
- Are all categories shown, including "Other"?
- Is the cumulative or periodic metric being shown? Are they appropriately labeled?

**Design checks:**
- Are there 3D effects? If yes, reject the chart and request a 2D version.
- Is smoothing applied? What method, what window?
- Are uncertainty ranges shown? Why not, if not?

**Source checks:**
- What is the data source?
- What date range?
- What filters or exclusions were applied?

Failing any of these checks does not automatically mean the chart is dishonest — it may just be incomplete or hastily made. But it does mean the conclusion the chart implies cannot be trusted without investigation.

> [!tip] Apply this checklist to every chart in a weekly business review or executive presentation. The goal is not to undermine the presenter but to build organizational norms where these questions are asked before major decisions.

@feynman

Like a security audit checklist — not every failing item is an exploit, but every unchecked box is an attack surface; the checklist ensures systematic coverage rather than relying on intuition about which items to check.
