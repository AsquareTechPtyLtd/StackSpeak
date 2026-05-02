@chapter
id: edv-ch06-visualizing-proportions
order: 6
title: Visualizing Proportions and Part-of-Whole
summary: When the question is "what fraction of the whole does each part represent?" — pie charts, stacked bars, treemaps, and waffle charts each answer it with different tradeoffs.

@card
id: edv-ch06-c001
order: 1
title: What Part-of-Whole Visualization Requires
teaser: For a chart to honestly show proportions, all parts must sum to a meaningful whole — if the denominator is unclear, the chart is showing fractions of nothing.

@explanation

A part-of-whole visualization makes a specific claim: the sum of all displayed parts equals 100% of some meaningful total. If the parts don't sum to a clear whole, or if the whole is not interpretable, the chart is geometrically correct but semantically misleading.

The common failure: showing "top 5 products by revenue" as a pie chart. The 5 products don't constitute the whole unless they are the only 5 products. The pie implies the 5 slices are 100% of revenue, which is false.

Requirements before making a part-of-whole chart:
- Confirm that all categories that constitute the whole are included.
- If categories are omitted (e.g., for clarity), explicitly label the omitted portion as "Other" and include it in the chart.
- Confirm the denominator is interpretable: "fraction of total Q1 revenue" is interpretable; "fraction of selected products" is ambiguous.
- Confirm the parts are mutually exclusive. If a customer can belong to multiple segments, a pie chart of segment counts shows overlapping slices, not parts of a whole.

> [!tip] The test: do all the parts in the chart sum to 100%? If "Other" would need to be a large slice to make them sum to 100%, either include it or reconsider whether a part-of-whole chart is the right choice.

@feynman

Like a JOIN in SQL — the result is only meaningful if the joining key is actually a one-to-one correspondence; a cartesian product produces rows that look like results but count the wrong total.

@card
id: edv-ch06-c002
order: 2
title: Pie Charts — When They Work and When They Don't
teaser: Pie charts work for 2–3 parts when the message is "this one dominates" or "these are roughly equal" — they fail for precise comparison of more than 3 slices.

@explanation

Pie charts are the most criticized chart type in visualization literature, often with valid reasons. But the criticism overgeneralizes: there are specific use cases where pie charts work.

**When a pie chart works:**
- 2 slices: comparing a majority vs minority (68% voted yes vs 32% voted no). The two-slice comparison is fast and intuitive.
- 3 slices where one clearly dominates or all are clearly different in size. "Product A = 60%, B = 25%, C = 15%" reads well as a pie.
- The question is binary or ternary and the audience is non-technical. Pie charts are culturally familiar and the two-slice version communicates immediately.

**When a pie chart fails:**
- 4+ slices of similar size. Comparing the angle of adjacent slices is less accurate than comparing bar lengths.
- Any comparison of similar-sized slices. "32% vs 28% vs 25%" — the slices look nearly equal; a bar chart shows the difference clearly.
- Slices need to be compared across two pie charts (e.g., Q1 vs Q2 composition). Two pie charts are nearly impossible to compare; two stacked bar charts are easy.

**The rule:** if you would struggle to rank the slices by size without reading the labels, use a bar chart. If you can instantly see which is largest and roughly how dominant it is, the pie chart may be fine.

> [!warning] 3D pie charts are unconditionally wrong. The perspective distortion makes front slices appear larger than identically-sized back slices. They encode false data. No legitimate use case requires a 3D pie chart.

@feynman

Like a hash map vs a sorted array — the hash map is fast for key lookup but terrible for range queries; the pie chart is fast for "does one thing dominate?" but terrible for "which of these four things is second largest?"

@card
id: edv-ch06-c003
order: 3
title: Stacked Bar Charts for Proportions
teaser: Stacked bars show both absolute totals and proportional composition in one chart — at the cost of being readable only for the bottom and top segments.

@explanation

A stacked bar chart places each category's components on top of each other. The total bar height represents the whole; each segment's height or width represents its contribution.

**100% stacked bars:** every bar is the same height (100%), showing proportional composition. Absolute totals are invisible but composition is comparable across groups.

**Absolute stacked bars:** total heights differ, showing both composition and absolute magnitude simultaneously.

What stacked bars reveal:
- The **bottom segment** has a shared baseline (zero), making it easy to compare across groups.
- The **top segment** has a shared top-of-bar line (in 100% stacked), making it easy to compare.
- **Middle segments** float in space with different starting points per group — these are hard to compare.

Design rules:
- Place the segment most important for comparison at the bottom (shared baseline) or top.
- Use at most 4–5 segments. More segments produce an unreadable stack.
- Label segments directly within the bar if space allows; avoid separate legends.
- For more than 5 segments or when many middle-segment comparisons are needed, use a grouped bar chart or small-multiple bars instead.

```python
# pandas + matplotlib: 100% stacked bars
df_normalized = df.div(df.sum(axis=1), axis=0) * 100
df_normalized.plot(kind='bar', stacked=True, colormap='tab10')
```

> [!info] The 100% stacked bar (with 3–4 segments) is the most readable alternative to a pie chart for comparing proportions across multiple groups. It outperforms multiple pie charts because the groups are directly comparable on a common axis.

@feynman

Like a git diff — the bottom of the stack is the base (old code), and each segment stacked above it shows changes; comparing middle segments across commits requires careful reading, but the total and the bottom are obvious.

@card
id: edv-ch06-c004
order: 4
title: Treemaps
teaser: Treemaps encode hierarchical proportions as nested rectangles — useful when there are too many categories for a pie or stacked bar, but size comparison is still approximate.

@explanation

A **treemap** divides a rectangle into smaller rectangles, where each rectangle's area is proportional to its value. Hierarchical data (categories within categories) can be shown as nested rectangles.

When treemaps are useful:
- Showing proportions for 10–100 categories where a bar chart would be too long.
- Hierarchical data where both levels matter (e.g., budget by department → by team).
- Space is constrained and many categories need to fit in a fixed area.

Treemap limitations:
- **Area comparison is inaccurate.** Readers underestimate large-vs-small rectangle ratios. A rectangle with 4× the area looks roughly 2× as large.
- **Long, narrow rectangles are harder to compare than squares.** The squarified treemap algorithm minimizes the aspect ratio to produce more square-like rectangles; use it by default.
- **Reading exact values is impossible.** A treemap is for "which category dominates?" not "is this category 12% or 18%?"

When to prefer alternatives:
- 5–10 categories: use a bar chart.
- Two hierarchy levels with key comparisons across levels: use a small-multiple bar chart.
- The precise proportion matters: use a bar chart with labeled values.

```python
# plotly: interactive treemap
import plotly.express as px
fig = px.treemap(df, path=['department', 'team'], values='budget',
                 color='budget', color_continuous_scale='RdBu')
fig.show()
```

> [!tip] Treemaps work best as interactive charts where clicking a large rectangle drills into its subcategories. Static treemaps with many small rectangles have tiny text and unreadable labels.

@feynman

Like a file system tree view — directory sizes as proportional area, folders within folders, and you can see at a glance that `node_modules/` dominates the disk before you've read a single filename.

@card
id: edv-ch06-c005
order: 5
title: Waffle Charts
teaser: A waffle chart (a 10×10 grid of colored squares) is more readable than a pie chart for proportions and communicates percentages naturally — each square is 1%.

@explanation

A **waffle chart** is a 10×10 (or 5×20) grid of unit squares where each square represents 1% of the total. Categories are shown as differently colored blocks. The result is visually a proportion chart but one where exact percentages are readable by counting squares.

Advantages over pie charts:
- Each small square is 1%, so reading "about 35%" is counting to 35, not estimating a slice angle.
- Multiple waffle charts placed side by side for comparison work much better than multiple pie charts.
- Colorblind-safe with shape redundancy: the grid structure distinguishes categories even without color differences.
- Works well for percentages in non-data-literate communication: political polling, survey results, accessibility metrics.

Limitations:
- Only works for whole-number percentages (rounds to nearest 1%). Not appropriate for values like 23.7%.
- 10×10 grid means a minimum of 100 "cells." For very small proportions (< 5%), the category may have too few cells to label clearly.
- More novel than bar or pie charts — some audiences need a moment to understand the format.

Typical use case: "34% of employees use the feature at least weekly." A waffle chart of 34 blue squares and 66 gray squares in a 10×10 grid communicates this more precisely and more accessibly than a pie chart.

```r
# R waffle package
library(waffle)
waffle(c(active = 34, inactive = 66), rows = 10,
       colors = c("#2A8C8B", "#CCCCCC"))
```

> [!info] Waffle charts are increasingly used in data journalism and policy communication in 2026 because they work well on mobile screens (a grid of squares is more legible than a pie at 300px width).

@feynman

Like a progress bar with 100 tick marks — instead of an analog percentage fill you get a countable discrete representation that any reader can verify by counting.

@card
id: edv-ch06-c006
order: 6
title: Parallel Sets (Sankey for Categorical Flow)
teaser: Parallel sets (also called alluvial diagrams) show how categorical groups flow and redistribute across multiple classification axes — nothing else shows this multi-level composition in one view.

@explanation

A **parallel sets** (or alluvial) diagram shows how a population is classified across multiple categorical dimensions simultaneously. The width of each "ribbon" connecting categories is proportional to the number of observations that belong to both categories.

Typical use case: a population of 10,000 customers classified by:
- Acquisition channel (organic, paid, referral).
- Plan tier (free, starter, enterprise).
- Status at 90 days (retained, churned).

An alluvial diagram shows the flow from acquisition channel → plan tier → retention status simultaneously. You can see, for example, that "paid acquisition → enterprise → retained" is a thick ribbon while "paid acquisition → free → churned" is also thick.

When parallel sets work:
- 3–5 categorical dimensions, each with 3–6 categories.
- The question is "how does classification on one dimension relate to classification on another?"
- Flow between states is the message (customer journey, conversion funnel, organizational transition).

When they don't:
- More than 5 categories per dimension: ribbons become too thin to follow.
- More than 5 dimensions: the chart becomes unreadable.
- Quantitative (not categorical) data: use a parallel coordinates plot instead.

```python
# plotly: sankey/alluvial diagram
import plotly.graph_objects as go
fig = go.Figure(go.Sankey(
    node=dict(label=["Organic", "Paid", "Free", "Enterprise", "Retained", "Churned"]),
    link=dict(source=[0,0,1,1], target=[2,3,2,3], value=[500,200,300,800])
))
```

@feynman

Like a dependency graph for a build system — nodes are categories, edges are the flows, and the width of each edge encodes how many units traverse that path.

@card
id: edv-ch06-c007
order: 7
title: Mosaic Plots
teaser: A mosaic plot shows the joint distribution of two categorical variables as a grid of rectangles where both width and height encode proportions — a 2D stacked bar chart.

@explanation

A **mosaic plot** divides a rectangle based on two categorical variables. The width of each column is proportional to the marginal distribution of one variable; the height of each tile within a column is proportional to the conditional distribution of the other variable.

Example: customer churn (churned/retained) vs plan tier (free/starter/enterprise). The mosaic plot shows:
- Column widths: proportion of customers in each tier.
- Tile heights: proportion churned vs retained within each tier.

If the churn rate were independent of tier, all tiles within each column would have equal height. Deviation from equal height is the signal — it shows where the relationship exists.

Mosaic plots are useful for:
- Detecting whether two categorical variables are associated.
- Showing the full joint distribution of two categoricals in one chart.
- Comparing conditional distributions across categories of one variable.

Limitations:
- Requires the reader to understand that both dimensions encode proportions (not counts). More cognitively demanding than a grouped bar chart.
- Doesn't scale to more than 4–5 categories per variable.
- For general audiences, a grouped bar chart of percentages is clearer.

```r
# R: mosaic plot
mosaicplot(~ tier + churn, data = customers,
           color = TRUE, main = "Churn Rate by Plan Tier")
```

> [!info] Mosaic plots with residuals (colored by chi-squared residual) show exactly where the association between variables is strongest. This is useful for exploratory analysis but usually too technical for communication charts.

@feynman

Like a contingency table rendered as a chart instead of a table — the structure is identical but the area encoding makes the patterns visible that would require calculation to see in the numbers.

@card
id: edv-ch06-c008
order: 8
title: Choosing Between Part-of-Whole Chart Types
teaser: The right choice between pie, stacked bar, treemap, and waffle chart depends on the number of parts, whether multiple groups are compared, and how precisely the reader needs to read proportions.

@explanation

Decision guide for part-of-whole chart selection:

**One group, 2 parts:**
- Pie chart or donut chart is acceptable. "67% vs 33%" reads clearly.
- Waffle chart if the audience is non-technical.

**One group, 3–5 parts:**
- Horizontal stacked bar (100%) is better than a pie.
- Pie is acceptable if one part clearly dominates.

**Multiple groups, 3–5 parts each:**
- 100% stacked bar chart. Comparison across groups is the primary task.
- Never multiple pie charts.

**One group, 6–20 parts:**
- Bar chart sorted by value. Each category gets a bar; comparison is accurate.
- Waffle chart if the exact percentage per category matters and they're all whole numbers.

**Hierarchical data, 10–100 parts:**
- Treemap. Two hierarchy levels, area comparison is approximate.
- Sunburst chart (treemap in polar form) — more visually striking, less accurate for area reading.

**One group, 2–5 parts, non-data audience:**
- Waffle chart (grid). More readable than pie for non-analysts.

The meta-rule: every part-of-whole chart is worse than a bar chart for precise comparison. Use part-of-whole charts only when the composition or fraction is the message, not the absolute comparison.

> [!tip] If you are debating between a pie chart and a bar chart for proportional data, make both and show each to a test reader. Ask "what is the second-largest category?" The bar chart will be answered faster and more accurately every time.

@feynman

Like choosing a data structure by access pattern — the right choice depends on whether the operation is "what fraction?" (part-of-whole chart) or "which is largest?" (sorted bar chart), and the two answer different questions at different costs.

@card
id: edv-ch06-c009
order: 9
title: Proportions Over Time
teaser: Showing how composition changes across time periods is a distinct problem from static proportions — the chart type changes because the question adds a temporal dimension.

@explanation

A static proportion question asks "what fraction does each part represent right now?" A temporal proportion question asks "how did that composition shift from period A to period B?" These require different encodings.

Primary chart types for compositional change over time:
- **100% stacked area chart:** every time point sums to 100%; the area bands show how each category's share rises or falls. Use when there are 3–5 categories and the trend over many time points is the message.
- **Slope graph:** two vertical axes (one per time point) connected by lines. Use when comparing just two points in time — start vs end. The slope makes direction and magnitude of change immediately readable.
- **Small-multiples:** one panel per category, each panel showing that category's share over time. Use when there are 6+ categories or when individual-category trends matter more than the composition as a whole.

The regular (non-normalized) stacked area chart encodes both total volume and proportional share simultaneously — the area bands convey both. Use it only when both messages are relevant. If only composition matters, use 100% stacked.

Key pitfall: 100% stacked area charts interpolate between data points with smooth curves. If the underlying data is categorical snapshots (quarterly surveys, annual reports), the smooth interpolation implies continuous change that doesn't exist in the data. Prefer step interpolation for discrete-time data.

> [!warning] Smooth interpolation in a 100% stacked area chart implies the data changes continuously between measurements. For annual or quarterly snapshot data, use step-style interpolation or connect only the actual data points with markers.

@feynman

Like git log with `--follow` vs `git diff A B` — the stacked area chart traces the full history like a graph of all commits, while a slope graph is just the diff between two specific commits: both show change, but at different granularities.

@card
id: edv-ch06-c010
order: 10
title: Donut Charts and Spacing
teaser: A donut chart is a pie chart with the center removed — the empty center is a design feature, not a flaw, because it can hold the single most important number or label.

@explanation

A donut chart is created by removing a circular center from a pie chart. The remaining ring is divided into arcs proportional to each category's share. All the strengths and weaknesses of the pie chart apply to the donut — the only structural difference is the center space.

When the donut center helps:
- A single dominant metric deserves a callout: "67% complete" with the ring showing 67% filled. The center reinforces the headline number without requiring a separate annotation.
- Dashboard contexts where a compact KPI widget is needed. A donut with a center label fits a small card format better than a bar chart.

When the center doesn't save it:
- 5+ segments: the same problem as a pie chart. The arcs become too small to compare reliably regardless of the center.
- When no single number is the message: using the center for a generic title wastes the space without adding information.

Segment spacing is a design choice with a semantic implication:
- **Gap between segments:** visually separates discrete categories. Reads as "these are distinct, countable items." Helps colorblind readers distinguish adjacent segments.
- **No gap (flush arcs):** reads as continuous. Appropriate when categories flow into each other (e.g., completion stages) or when the ring is a single-metric fill chart.

The donut center label pattern — a large number centered in the ring — is one of the most common and effective techniques in product dashboards and executive reporting. It combines a proportional chart with a direct numeric callout.

> [!tip] In a single-metric donut (e.g., "67% of onboarding complete"), use two arcs only: filled and unfilled. The center label carries the number. This is clearer than any multi-segment variant and avoids all the readability problems of pie charts with many slices.

@feynman

Like a circular progress indicator in a mobile UI — the ring encodes how complete something is, the center shows the exact percentage, and the empty space is intentional padding that makes the number legible rather than wasted whitespace.
