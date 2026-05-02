@chapter
id: cwd-ch09-common-pitfalls
order: 9
title: Common Pitfalls and Misleading Charts
summary: Most misleading charts aren't deliberately deceptive — they're the result of default settings, lazy choices, and unexamined conventions. Knowing the patterns makes them easy to spot and correct.

@card
id: cwd-ch09-c001
order: 1
title: Truncated Y-Axes
teaser: Cutting the y-axis to make differences look dramatic is sometimes justified, often deceptive — and the difference is whether the truncation is disclosed and the scale is honest about the data's natural range.

@explanation

A truncated y-axis starts above zero. In a bar chart, that is almost always wrong — bar height encodes a magnitude, and a bar that doesn't start at zero implies that the visual height is proportional to the raw value. If it isn't, you're lying with geometry.

Line charts and scatter plots are different. They encode the position of a point, not the height of a bar. Starting a line chart at zero when the values are all in the range 97–103 compresses all variation into a flat line and hides the signal entirely. Truncation is appropriate there, but it requires:

- A visible axis break (the `//` mark) or an explicit note on the axis
- A subtitle or annotation that contextualizes the range ("Y-axis from 80 to 100, not from 0")
- Awareness that the chart will be misread if stripped of its context (e.g., copied into a slide without the subtitle)

The failure mode to avoid: a bar chart where revenue of $98M vs $102M is shown with a y-axis from $95M to $105M, making a 4% difference look like a 2× difference. The visual lie happens at the level of the reader's first impression, before they read the axis label.

> [!warning] Default charting tools often produce truncated axes automatically. "The tool did it" is not a defense — always audit the axis origin before publishing.

@feynman

A bar chart with a truncated y-axis is like a ruler that starts at 95 — technically accurate, but it implies sizes that aren't there.

@card
id: cwd-ch09-c002
order: 2
title: The Dual-Axis Trap
teaser: Two y-axes let you imply any correlation you want between two variables simply by choosing the right scales — which is why they almost always mislead.

@explanation

A dual-axis chart overlays two data series with different scales on the same x-axis — one series mapped to the left axis, the other to the right. The problem is not the implementation, it's the mathematics: any two time series can be made to appear correlated or inversely correlated by adjusting the scales on either axis independently.

Why this matters:

- The visual impression is "these two things move together" — but that impression is produced by the scale choice, not the data
- There is no visual encoding that distinguishes coincidence from causation
- Readers rarely check both axis scales; they read the shape

Specific misuse patterns:
- Overlaying revenue and headcount to imply efficiency
- Overlaying a macro index and a product metric to imply causation
- Overlaying seasonally-adjusted and non-adjusted series without labeling which is which

The alternatives that actually work:
- **Separate panels:** two charts stacked vertically with aligned x-axes; the reader can compare trends without the axes interfering
- **Index both series to a common baseline:** set both to 100 at a reference point and show percent change; now the scales are comparable
- **Scatterplot:** if the question is "do these two variables correlate?", a scatterplot is the honest encoding

> [!warning] If you find yourself adjusting the right-hand axis scale until the lines look "right," you're tuning the chart to confirm a story, not to show the data.

@feynman

A dual-axis chart is like two thermometers with different scales next to each other — you can make them agree on any temperature just by choosing the right units for each.

@card
id: cwd-ch09-c003
order: 3
title: Pie Chart Abuse
teaser: A pie chart is a part-to-whole encoding that works only under narrow conditions — and most real data violates at least one of them.

@explanation

A pie chart encodes magnitude as arc angle. Human visual perception is poor at comparing arc angles, especially when slices don't share a common baseline. This is not a stylistic complaint — it is a documented limitation of visual cognition.

Pie charts fail reliably in these conditions:

- **More than five categories:** with six or more slices, most share similar angles and become indistinguishable without data labels — at which point the chart is just a labeled list displayed in a circle
- **Similar-sized values:** slices of 18%, 21%, 23%, and 20% cannot be ranked by eye; a bar chart makes the ordering immediate
- **Sequential or time-series data:** a pie chart has no time axis; using one for quarterly breakdowns across four years requires four separate pies with no common baseline
- **Negative values:** a pie with a negative slice is undefined; the encoding breaks entirely

When a pie chart is appropriate:
- Exactly two or three categories
- One category is notably dominant (>50%)
- The message is "rough share" not "precise comparison"

The bar chart is almost always the correct replacement. A horizontal bar chart with sorted categories gives the reader both the order and the magnitude in a single visual scan.

> [!tip] If you need to add data labels to make a pie chart readable, the pie is no longer doing the visual work — replace it with a bar chart that lets the bars speak for themselves.

@feynman

A pie chart is like reading a clock to compare durations — it works fine for 12 o'clock vs 6 o'clock, but not for 10:47 vs 11:03.

@card
id: cwd-ch09-c004
order: 4
title: 3D Chart Effects
teaser: Three-dimensional effects on charts have no legitimate use case — they introduce systematic distortion without encoding any additional information.

@explanation

3D effects on charts — 3D bars, 3D pie slices, perspective grids, extruded columns — are not a stylistic preference. They introduce a specific and predictable failure mode: bars or slices in the foreground appear larger than bars or slices of equal value in the background, because perspective rendering makes objects farther away look smaller.

In a 3D bar chart:
- The front bars cast shadows on and visually compete with back bars
- The perceived height of a bar depends on its position in the composition, not its value
- The baseline is visually obscured by the projection

In a 3D pie chart:
- Front slices appear larger than rear slices of identical area
- The distortion is not uniform and cannot be corrected by the reader without the underlying data

There is no information encoded by the third dimension. It is visual noise that actively degrades the accuracy of perception. The entire argument for 3D charts is that they look impressive in presentations. The cost is that readers cannot accurately read the values they were built to communicate.

The fix is always the same: remove the 3D effect. All major charting libraries have this as a one-line change.

> [!warning] 3D effects are a presentation affordance, not a data visualization technique. If a chart looks more impressive in 3D, ask what it is hiding.

@feynman

A 3D bar chart is like reading code with a random font-size gradient applied — the content is still there, but you've made it harder to parse for purely aesthetic reasons.

@card
id: cwd-ch09-c005
order: 5
title: Cherry-Picked Time Ranges
teaser: A chart that shows only a favorable window without disclosing what happened before or after it is technically accurate and functionally deceptive.

@explanation

Time range selection is one of the most common forms of misleading visualization because it requires no visual manipulation — only a data filter. Selecting a window where a metric trends upward and presenting it as representative of overall performance is a choice the chart cannot expose to the reader.

Common forms:
- Starting the time axis after a major dip to show a recovery as a growth story
- Ending the axis before a recent reversal to preserve a positive narrative
- Selecting a high-volatility period to show either consistent growth or consistent decline depending on the desired story
- Choosing a comparison baseline year that was anomalously bad, making current performance look stronger

How to make time ranges honest:
- Show the longest meaningful history available, not the most favorable window
- Annotate the chart with events that explain major inflections — if you're showing a growth curve that starts post-restructuring, label the restructuring
- If the time window is constrained (e.g., only 12 months of data exists), say so explicitly in the chart subtitle
- When comparing periods, use equal-length windows; comparing this month to last quarter is an asymmetric baseline

The defense is transparency, not completeness. You cannot show all context in every chart — but you can disclose the limits of what you are showing.

> [!info] Benchmark the chart against the question it answers. If the question is "is this metric growing?" and you've shown only the months it grew, the chart answers a different question.

@feynman

Cherry-picking a time range is like showing a code review only for the commits you're proud of — the commits you show are accurate, but the selection is doing work you haven't disclosed.

@card
id: cwd-ch09-c006
order: 6
title: Area Chart Size Illusions
teaser: Area charts encode values as two-dimensional space — but human perception of area is non-linear, which means viewers systematically underestimate differences between large areas and overestimate differences between small ones.

@explanation

An area chart (including bubble charts and area-fill line charts) encodes a value as the size of a filled region. The problem is that human perception of area does not scale linearly with the actual area. Studies in psychophysics consistently show that perceived area grows more slowly than actual area — specifically, perceived magnitude scales as roughly the 0.7 power of actual magnitude.

In practice this means:
- A region that is twice the area of another looks only about 60% bigger to most viewers
- Small areas look more similar than they are
- Large areas look more similar than they are
- The direction of the error is not constant across the range, making it impossible to "read around"

Area charts are not universally wrong — they communicate approximate magnitude efficiently when exact comparison is not required. They fail when:
- The chart is used to compare specific values
- The values are close in magnitude (the difference disappears perceptually)
- The audience needs to rank the categories accurately

The bar chart alternative:
- Encodes each value as a length along a common baseline
- Length comparison along a shared axis is one of the most accurate visual tasks humans perform
- Supports both ranking and precise value reading

> [!tip] Reserve area charts for contexts where the message is "roughly how big" rather than "exactly how different." For comparisons, use bars.

@feynman

Reading an area chart for precise comparison is like estimating runtime from a file's size — the correlation is real but the perception is too noisy to be relied on.

@card
id: cwd-ch09-c007
order: 7
title: Stacked Bar Chart Confusion
teaser: Stacked bars make one comparison easy and every other comparison hard — the baseline problem means only the bottom segment can be read accurately.

@explanation

A stacked bar chart encodes multiple categories as vertically stacked segments within each bar. The tradeoff is well-defined: you can compare the total bar height accurately, and you can compare the bottom segment accurately (it shares a zero baseline), but every other segment is compared floating-to-floating, with no common baseline.

The cognitive cost of floating comparisons:

Consider a four-segment stacked bar. To compare the third segment across five bars, the reader must mentally subtract the first two segments from each bar, then compare the remainders. This is not a visual task — it is arithmetic the reader is being asked to perform with noisy visual inputs.

Specific failure modes:
- When the interesting category is not the bottom segment, the chart actively obscures the comparison it was built to show
- When segment sizes are similar, the floating comparison becomes impossible
- When segment order differs between series, the chart loses all coherence

When stacked bars work:
- When the question is "what is the total, broken down by part?" and the bottom segment is the interesting comparison
- When the number of segments is two (the top segment is a simple complement of the bottom)

Alternatives that preserve the breakdown without the comparison cost:
- **Grouped bars:** each category gets its own bar in a cluster; all share a zero baseline
- **Small multiples:** one panel per category with consistent axes; preserves the breakdown while enabling direct comparison

> [!info] If the chart requires a legend and the reader has to trace each color back to a floating segment to compare values, the stacked bar is hiding more than it reveals.

@feynman

Comparing non-bottom segments in a stacked bar is like comparing the middle floors of two buildings when neither is sitting at ground level — the visual anchor you need isn't there.

@card
id: cwd-ch09-c008
order: 8
title: Simpson's Paradox
teaser: A trend that appears in aggregate data can reverse — or disappear entirely — when the data is broken down by a lurking variable. Aggregates can lie even when every data point is accurate.

@explanation

Simpson's paradox occurs when a trend observed in aggregate data reverses when the data is partitioned into subgroups. The aggregate is not wrong — it is a mathematically accurate summary of the combined data. The reversal happens because the subgroups are not equally represented and the lurking variable that determines group membership is correlated with the outcome.

A concrete example structure:
- Group A has a 70% success rate in treatment and a 40% success rate in control.
- Group B has a 30% success rate in treatment and a 20% success rate in control.
- In both groups, treatment outperforms control.
- But Group A is larger and has lower baseline outcomes than Group B; when data is pooled without controlling for group, the aggregate can show control outperforming treatment.

Why this matters for data visualization:
- A chart showing aggregate performance is not necessarily showing the right comparison
- Presenting a single aggregate trend line as "the finding" when subgroup trends reverse it is a substantive error, not just a presentation flaw
- The paradox is not always obvious — it requires checking whether aggregate trends are homogeneous across subgroups

How to guard against it:
- Segment the data by any variable plausibly correlated with both group membership and outcome before drawing conclusions
- Use faceted or small-multiple charts to compare trends across subgroups alongside the aggregate
- When presenting aggregate results, check whether the aggregate trend holds in the largest subgroups

> [!warning] Simpson's paradox is most common in data about demographics, healthcare outcomes, and A/B test results where group sizes are unequal. These are exactly the contexts where aggregate charts get the most attention.

@feynman

Simpson's paradox is like a weighted average that hides the weights — the number is correct, but it's answering a question you didn't ask.

@card
id: cwd-ch09-c009
order: 9
title: Correlation Presented as Causation
teaser: The chart doesn't make the causal claim — the caption does. Framing is where the confusion between correlation and causation lives, and it's invisible in the visual encoding itself.

@explanation

A scatterplot showing two correlated variables is neutral about causation. The chart can show that two things move together; it cannot show that one causes the other. The confusion between correlation and causation is almost always introduced by the text that surrounds the chart, not the chart itself.

The verbal patterns that introduce the confusion:

- "Customers who use feature X retain at higher rates" — plausible observation
- "Feature X drives retention" — causal claim; requires evidence beyond the chart
- "Increasing feature X usage will improve retention" — intervention claim; requires experimental evidence

The gap between these three statements is large. Moving from the first to the third is the progression from description to policy recommendation, and each step requires a different kind of evidence.

Why developers should care specifically:
- Product metrics dashboards are the highest-density environment for this mistake
- Engagement metrics correlate with retention for structural reasons (active users use features more); showing this correlation as evidence that a feature drives retention is a common product analytics error
- The chart gets shared as a proof point without the analysis that would validate or invalidate the causal story

How to frame charts that show correlation correctly:
- Use observation language: "customers who do X also tend to Y"
- Flag the causal interpretation explicitly as a hypothesis, not a finding
- Note whether the comparison controls for obvious confounders (tenure, plan level, activation state)

> [!info] If the chart is being used to justify a product decision, it needs to answer "does X cause Y?" — and a correlation chart cannot answer that question alone.

@feynman

A correlation chart is like a commit log — it shows what happened and in what order, but it doesn't tell you why, and assuming causation from sequence is how you end up reverting the wrong fix.

@card
id: cwd-ch09-c010
order: 10
title: Map Distortion and Choropleth Misuse
teaser: Choropleth maps encode data as color intensity across geographic regions — but large, sparsely populated regions dominate the visual even when they contribute little to the data.

@explanation

A choropleth map fills geographic regions with color to represent a variable — darker color for more, lighter for less. The problem is that geographic area and data quantity are independent, but the visual implies a relationship between them. Large land-area regions dominate the visual impression regardless of their contribution to the underlying metric.

The canonical failure case: a choropleth of total cases of a condition fills a large rural state with dark red while small dense urban states look light. The visual impression is that the rural state has a severe problem; the reality is it has a large area. The correct encoding would be cases per capita, but even then the geographic size creates a visual weight that skews the first impression.

Specific misuses:

- **Encoding totals on geographic area:** always wrong; use rate or density
- **Using sequential color scales on diverging data:** implies a linear ordering when the data has a meaningful center point
- **Country or state-level aggregation for city-level phenomena:** the unit of geography is wrong for the unit of analysis
- **Missing data shown as white:** visually identical to "zero," which implies data where there is none

When maps are the right choice:
- When geographic distribution is the actual question ("where is this concentrated?")
- When the reader needs to locate regions they recognize by shape, not by label
- When the geographic unit matches the unit of analysis (city-level data at city resolution)

Alternatives for quantity comparisons by region: a bar chart sorted by value puts the comparison on a common baseline without the geographic distortion.

> [!tip] Before using a choropleth, ask: "Is the geographic shape of the region relevant to the message?" If the answer is no, a bar chart will communicate the comparison more accurately.

@feynman

A choropleth of raw totals is like coloring a world map by GDP without adjusting for population — the largest countries dominate the visual even when smaller ones are doing more with less.

@card
id: cwd-ch09-c011
order: 11
title: The Default Sort Order Mistake
teaser: Sorting bars by data value is almost never the default in charting tools, but it is almost always the correct choice — default alphabetical or categorical order implies a relationship that doesn't exist.

@explanation

Most charting libraries sort bar charts by the category label — alphabetically, or in the order the data appears in the source table. The result is a bar chart where the visual arrangement of bars implies nothing about the data, but readers instinctively try to read order as meaning.

The default order creates two specific problems:

**It obscures ranking.** If the question is "which category is largest?" — which is usually the question — the reader has to scan all bars, identify the tallest, and mentally rank them. Sorting by value descending answers the ranking question with a single visual scan: the bars are already in order.

**It implies categorical relationships that don't exist.** Alphabetical order implies that "Android" and "Baseline" are adjacent in some meaningful way. They're not. The adjacency is an artifact of the label, not the data.

When default or intentional non-value sort is appropriate:
- **Ordinal categories** with a meaningful order: days of week, months, stages of a funnel, age groups — here the category order conveys the natural sequence, and sorting by value would destroy the sequence
- **Comparison of a few named entities** where the reader already knows the expected order and is looking for deviations from it

The rule: sort by value unless the category order itself is the message. For nominal categories (countries, product names, team names, browsers), value sort is almost always correct.

> [!tip] Descending value sort is the default you want. Ascending value sort (smallest to largest) is useful when the chart is a horizontal bar and the reader scans from bottom to top — the most important bar lands at eye level.

@feynman

Alphabetical sorting on a bar chart is like listing function names in a performance profile alphabetically instead of by execution time — technically organized, but organized around the wrong thing.

@card
id: cwd-ch09-c012
order: 12
title: Chart Junk in Practice
teaser: Chart junk is any visual element that consumes ink without encoding data — and the audit to remove it is usually a series of deletions, not additions.

@explanation

Edward Tufte's concept of chart junk identifies visual elements that add complexity without adding information. The practical version of this principle is an audit list: elements to question before publishing any chart.

The audit, element by element:

**Grid lines:** heavy grid lines compete with the data. Use light, sparse grid lines (or none) for bar charts where the axis labels are sufficient. Reserve grid lines for charts where the reader needs to read off specific values.

**Background fills:** colored or patterned chart backgrounds add visual weight and interfere with color encodings in the data. Default to white or the page background.

**Decorative borders:** chart borders and shadows are presentation styling, not data encoding. Remove them.

**Redundant legends:** if the chart has one data series, a legend that says "Revenue" when the title already says "Monthly Revenue" is redundant. If the chart has color encoding and the x-axis labels already identify each category, the legend is redundant. Remove it.

**Excessive axis ticks:** ten evenly spaced tick marks on an axis where the reader needs to see "roughly 50, 100, or 150" is five times more ink than necessary. Use four to six ticks at round numbers.

**Data labels on all bars:** adding a numeric label to every bar in a bar chart collapses the visual encoding into a table. Use data labels for the single bar being called out, or omit them entirely and let the axis do the work.

**3D effects, gradient fills, rounded bars with complex shadows:** all chart junk. One deletion each.

The question for every element: "If I remove this, does the reader lose information?" If the answer is no, remove it.

> [!info] Chart junk is not always decorative. Overloaded legends, redundant axis labels, and excessive gridlines are functional elements that became junk through overuse. The audit applies to both.

@feynman

Removing chart junk is like removing dead code — each element seemed necessary when someone added it, but the system is cleaner and easier to read without it.
