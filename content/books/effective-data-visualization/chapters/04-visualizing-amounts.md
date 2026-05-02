@chapter
id: edv-ch04-visualizing-amounts
order: 4
title: Visualizing Amounts
summary: When you have one number per category and want to compare them, the chart type and sort order determine whether the comparison is fast or slow — and whether the bars mislead or inform.

@card
id: edv-ch04-c001
order: 1
title: The Bar Chart Is the Default for Amounts
teaser: A bar chart encodes each value as a length from a shared zero baseline — the most accurate encoding for amount comparison, which is why it has dominated for 200 years.

@explanation

The bar chart encodes amounts as lengths from a common zero baseline. Because the baseline is shared, the comparison task reduces to "which length is longer?" — a question the visual system answers accurately and quickly.

Key properties that make it the default choice:
- The zero baseline is always visible, preventing the reader from misjudging relative magnitudes.
- All bars are comparable because they start from the same point.
- Ordering the bars by value turns the chart into an implicit ranking.

When a bar chart is the right choice:
- One quantitative value per categorical item.
- The reader needs to compare values across categories.
- Categories are nominal (countries, products, departments) or ordinal (age groups, star ratings).
- There are 2–20 categories. More than 20 bars become hard to read without scrolling or abbreviating labels.

When a bar chart is not the right choice:
- The data is continuous and ordered in time → use a line chart instead.
- You need to show a distribution → use a histogram or density plot.
- You need to show two variables → use a scatterplot.

The invariant rule for bar charts: **the y-axis must start at zero.** Bar height encodes the amount; a truncated y-axis encodes a different amount (the deviation from the truncation point) while appearing to show the full amount. This is covered in depth in chapter 12.

> [!info] William Playfair invented the bar chart in 1786 for "Commercial and Political Atlas." The fact that the bar chart has been the dominant tool for amount comparison for 240 years is not convention — it is because position encoding on a shared baseline genuinely outperforms all alternatives for this task.

@feynman

Like a sorted array — the structure enforces the comparison that the data is about, and anything that distorts the structure (truncated axis = fake zero) corrupts the query result.

@card
id: edv-ch04-c002
order: 2
title: Sort Order Is a Design Decision, Not an Afterthought
teaser: An unsorted bar chart forces the reader to mentally sort before comparing — pre-sorting by value is one of the highest-leverage improvements in visualization design.

@explanation

The default sort order in most tools is alphabetical (by label) or the order data appears in the source. Neither serves the reader's comparison task.

**Alphabetical order:** useful only when the reader is looking up a specific item. For "which product has the highest sales?" alphabetical order means reading every bar to find the max.

**Data order (sorted by value):** the correct default for comparison tasks. The reader sees immediately which items are highest and lowest and can read the ranking without any mental sorting.

Sorting rules:
- **Descending (highest to lowest):** when the question is "which is best/most?"
- **Ascending (lowest to highest):** when the question emphasizes the worst/least performers.
- **Grouped by category, then sorted within group:** when two-level structure (region > product) matters.
- **Maintained sort order over time:** in a time-series small-multiple bar chart, use the sort order from the most recent period and maintain it across all panels so the reader can track movement.

The one exception where natural order beats value order: **ordinal categories with inherent sequence** (January–December, age 18–24 / 25–34 / 35–44). Sorting these by value would disrupt the expected sequence the reader uses to orient.

```python
# Sort bars by value descending in matplotlib
df_sorted = df.sort_values('value', ascending=True)  # True = bottom-to-top in horizontal
ax.barh(df_sorted['category'], df_sorted['value'])
```

> [!tip] In a horizontal bar chart (see next card), sort ascending in the data frame to get the visual sort descending from top to bottom — the typical reading direction. The highest value should be at the top, the lowest at the bottom.

@feynman

Like ORDER BY in a SQL query — running a query without ORDER BY gives you the answer in heap order, which is correct but slower to use than explicitly sorted output.

@card
id: edv-ch04-c003
order: 3
title: Horizontal vs Vertical Bars
teaser: Vertical bars fit time-based data and short labels; horizontal bars work for longer category labels and large numbers of categories — the choice is functional, not aesthetic.

@explanation

The orientation decision is driven by practical constraints:

**Vertical bars (columns) work best when:**
- Categories are time periods (months, quarters, years). Time reads left-to-right conventionally, and vertical bars reinforce the time axis as horizontal.
- Labels are short (3–6 characters: "Jan", "Feb", "Mar").
- There are fewer than ~12 categories. More than 12 vertical bars in a typical chart width require narrow bars and cramped labels.

**Horizontal bars work best when:**
- Category labels are long (country names, product names, job titles). Long labels fit naturally to the left of a horizontal bar without rotation or abbreviation.
- There are many categories (12–40). Horizontal bars extend downward, allowing more items without sacrificing readability.
- The ranking aspect is the primary message. Sorted horizontal bars read like a ranked list, which matches how many readers mentally model rankings.

**Label rotation is a failure mode.** Rotating x-axis labels 45° or 90° to fit long category names is a sign that vertical bars are the wrong orientation. Rotate the chart instead: use horizontal bars.

In mobile or narrow-screen contexts (less than 400px wide), vertical bars become crowded. Horizontal bars are often the better default for charts embedded in mobile products.

> [!warning] Rotating axis labels 45–90 degrees reduces label readability substantially. If your vertical bar chart requires rotated labels, switch to horizontal bars. Rotated text is a chart design failure, not an accepted solution.

@feynman

Like choosing row-major vs column-major storage — the choice is determined by which access pattern (reading labels vs reading values) is the primary use case, not by which looks more familiar.

@card
id: edv-ch04-c004
order: 4
title: Grouped vs Stacked Bars
teaser: Grouped bars enable direct comparison between subcategories; stacked bars show part-of-whole; neither does both well — choose based on the primary question.

@explanation

When each category has multiple subcategory values, bars can be arranged two ways:

**Grouped (clustered) bars:** subcategory bars placed side by side within each group. Enables direct comparison between subcategories across groups (e.g., comparing company A's retail revenue to company B's retail revenue).

Reads well for: "How does subcategory X compare across groups?"
Struggles with: "What is the total for each group?"

**Stacked bars:** subcategory values stacked into one bar per group. The total bar height shows the sum; internal segments show the components.

Reads well for: "What is the total per group?" and "What does the top segment contribute across groups?" (the top segment shares a common baseline with the bar top).
Struggles with: "How does the middle segment compare across groups?" — middle segments float in space with different starting points, making comparison inaccurate.

**100% stacked bars** (every bar the same height, showing percentages): show proportion composition. The absolute totals are invisible. Use when the proportional breakdown is the message and totals don't matter.

The rule of thumb: if direct subcategory comparison is the question, use grouped. If the total and the contribution of one segment (bottom or top) are the message, use stacked.

> [!tip] Never use stacked bars with more than 4–5 segments. Each additional stacked segment makes the internal segments harder to compare. For complex compositions, a treemap or small-multiple bar charts are cleaner.

@feynman

Like normalizing a database vs denormalizing — each structure makes one query fast at the cost of making another query slower, and the right choice depends on which query matters.

@card
id: edv-ch04-c005
order: 5
title: Lollipop Charts
teaser: A lollipop chart is a bar chart with most of the bar removed — it reduces visual weight while preserving the length encoding, which makes it better when categories are dense or labels matter more.

@explanation

A **lollipop chart** replaces each bar with a thin line ending in a dot (or circle). The encoding is identical to a bar chart — the dot's position encodes the value, the line marks the extent from the baseline. The visual weight is much lower.

When lollipop charts work better than bar charts:
- **Many categories (15–40):** dense bar charts become visually heavy; lollipop dots are readable with much less visual mass.
- **Value labels needed:** lollipop dots have natural space for adjacent labels without the label overlapping the bar.
- **Small differences between values:** when bars are all similar heights, the bars dominate the chart space; lollipop lines let the dots cluster naturally.

When bar charts work better:
- **Fewer than 10 categories:** bars provide more visual stability and are easier for less-data-literate audiences.
- **The magnitude itself is the message:** a tall bar conveys "this is a lot" through area; a lollipop line does not.
- **Audience unfamiliarity:** some audiences (executives, non-data teams) find lollipop charts unusual and spend time interpreting the format instead of the content.

```python
# matplotlib: lollipop chart
import matplotlib.pyplot as plt
ax.hlines(y=categories, xmin=0, xmax=values, color='#CCCCCC', linewidth=1)
ax.scatter(values, categories, color='#C84A50', s=80, zorder=3)
```

> [!info] Observable Plot 0.6 supports lollipop-style charts with `Plot.ruleX` (for the stem) + `Plot.dot` (for the head). This is a clean compositional model for building lollipops without custom rendering.

@feynman

Like sparse vs dense matrix storage — the lollipop and the bar encode the same value; the lollipop wastes less visual space when the data is sparse relative to the chart area.

@card
id: edv-ch04-c006
order: 6
title: Dot Plots for Comparisons Without a Zero Baseline
teaser: When comparing values that don't meaningfully start from zero — test scores, rankings, rates — a dot plot shows the comparison without the misleading implication of a zero-anchored baseline.

@explanation

The zero-baseline requirement for bar charts is not arbitrary. Bars encode values as lengths from zero, so the zero point must be shown. But some quantities don't have a meaningful zero:
- Test scores from 60–95 (zero is not a meaningful reference).
- Satisfaction ratings from 3.2–4.8 (zero is not possible or relevant).
- Percentage changes from −5% to +12% (zero is meaningful, but the chart is not about absolute quantities).

For these quantities, a **dot plot** (also called a Cleveland dot plot) places a dot at each value on an axis scaled to the relevant range, without a zero baseline. The comparison is accurate because dots are compared on a common scale; the misleading implication that a bar of height 61 represents almost nothing is gone.

Dot plots also handle two-variable comparisons cleanly: a paired dot plot connects two related dots (e.g., before and after treatment for each subject) with a line, making the change visible without any bars.

When to use dot plot over bar chart:
- Continuous values without a meaningful absolute zero.
- Comparing change between two conditions per subject (paired data).
- Many categories where bars become visually heavy.

```r
# R ggplot2: dot plot (Cleveland)
ggplot(df, aes(x = value, y = reorder(category, value))) +
  geom_point(size = 3, color = "#2A8C8B") +
  labs(x = "Satisfaction Score", y = NULL) +
  theme_minimal()
```

> [!tip] If you feel like truncating a bar chart's y-axis to "zoom in" on meaningful differences, a dot plot is almost certainly the better solution. The dot plot shows the same comparison accurately without the misleading truncated bar.

@feynman

Like a p-value compared to a raw count — the quantity has a meaningful range that doesn't start at zero, and forcing it onto a zero-anchored axis creates more confusion than clarity.

@card
id: edv-ch04-c007
order: 7
title: Ordering Categories with a Secondary Variable
teaser: When categories can be sorted by two different variables, the choice of sort key changes the argument the chart is making — make the choice explicit and intentional.

@explanation

Sometimes categories have both a natural ordering (alphabetical, temporal) and a value ordering (sorted by the quantity being shown). The sort key is not a neutral technical choice — it determines which comparison the chart makes easy.

Example: a bar chart of 50 countries ranked by GDP. Sort options:
- **By GDP (descending):** the ranking is the message. Which countries are largest? Top/bottom 10? Easy to read.
- **By region, then by GDP within region:** the regional comparison is the message. Which region has the highest-GDP countries?
- **Alphabetically:** useful only if the reader is looking up a specific country. Makes comparison impossible.
- **By GDP per capita instead of total GDP:** a completely different argument — small, wealthy countries vs large, moderately wealthy ones.

When two quantitative variables could both drive the sort, choose the one that matches the question:
- "Which product has the most revenue?" → sort by revenue.
- "Which products have the worst revenue-to-cost ratio?" → sort by ratio.
- "Which products are growing fastest?" → sort by growth rate.

The same underlying data, sorted differently, makes four different arguments. Choosing the sort key without thinking about the question produces a chart that answers the wrong question confidently.

> [!warning] Defaulting to alphabetical sort because it's "neutral" is not neutral — it explicitly makes comparison by name easy and comparison by value hard. There is no neutral sort for a chart that exists to enable comparison.

@feynman

Like choosing an index on a database table — the index makes one query O(log n) and leaves others at O(n); sorting a chart makes one comparison O(1) and leaves others harder. Choose based on the query that matters.

@card
id: edv-ch04-c008
order: 8
title: Handling Negative Values in Bar Charts
teaser: Bars with negative values need a clearly marked zero baseline and a visual treatment that distinguishes positive from negative without relying solely on position.

@explanation

Bar charts with both positive and negative values (e.g., profit/loss by quarter, temperature deviation from average, year-over-year change) require explicit design decisions that standard bar charts don't need.

The zero line must be visible and distinct. When bars cross zero, the zero baseline becomes a meaningful reference that the reader needs to see clearly. Make it a solid line, not just a tick mark.

Color treatment for +/− bars: use distinct colors for positive and negative bars. The standard is:
- Green or blue for positive.
- Red or orange for negative.

Do not rely on position alone (bars above zero vs below zero) to distinguish positive from negative. Many readers will not notice bars below an axis line if the visual treatment is otherwise identical.

Axis label placement: if bars extend below zero, the category labels must not be placed on the zero line (they'll be in the middle of the chart). Place them to the left of the chart area or use them as direct bar labels.

```python
# matplotlib: color bars by sign
colors = ['#009E73' if v >= 0 else '#C84A50' for v in values]
ax.bar(categories, values, color=colors)
ax.axhline(y=0, color='black', linewidth=0.8)  # Explicit zero line
```

Avoid: placing all bars above zero by adding a constant offset. This eliminates the meaningful zero reference. If the data has negative values, show them as negative.

> [!tip] Add a zero reference line explicitly even in tools that draw it automatically. Explicit control ensures the line has the right weight and color to be visually distinct from gridlines.

@feynman

Like signed integers — the zero point is the boundary between two logically distinct states (positive/negative), and obscuring that boundary produces the same class of bugs as treating a signed integer as unsigned.

@card
id: edv-ch04-c009
order: 9
title: Baseline Matters — Never Truncate Bar Charts
teaser: Truncating a bar chart's y-axis makes bars of similar height look dramatically different — it's technically accurate but visually lies about the magnitude relationship.

@explanation

A bar chart's height encodes the full quantity from zero. When the y-axis starts at a value other than zero, the bar heights encode deviations from the truncation point — not the actual quantities. The reader reads a bar that is 4× taller as representing 4× the value, but the actual ratio might be only 1.08×.

Example: two bars at $98M and $102M on a y-axis from $96M to $104M. The right bar looks twice as tall as the left bar. The actual difference is 4%. The chart visually lies.

This is not a matter of interpretation. The bar chart geometry contract with the reader is: bar height = quantity. Truncating the axis breaks that contract.

The correct solutions when values are close together:
- **Use a dot plot.** Dots on a common scale, with a non-zero axis, accurately show the comparison without the false magnitude effect.
- **Add a deviation bar.** Show the deviation from a reference value, starting at zero. This is technically correct: bar height = deviation.
- **Show the exact values as labels.** If the comparison is "which is bigger by how much?", numbers are more honest than nearly-equal bars.

> [!warning] The dual motivation for y-axis truncation is "to zoom in on interesting differences." The correct zoom tool is a dot plot or a deviation chart. Truncating bar heights is misleading regardless of intent.

@feynman

Like rendering a progress bar at 97% vs 99% as 50% wide vs 100% wide by starting the scale at 95 — technically the scale is labeled, but every caller interprets the bar as the fraction of the total, not the fraction of the last 5%.

@card
id: edv-ch04-c010
order: 10
title: Small-Multiple Bar Charts
teaser: When you have amounts for multiple groups across multiple categories, small multiples — one bar chart per group — are almost always cleaner than a single chart with grouped or colored bars.

@explanation

A small-multiple (or trellis) display repeats the same chart type for each subset of the data, arranged in a grid. Each panel is a self-contained chart. The reader compares panels by scanning across the grid.

Small multiples beat grouped bar charts when:
- There are 3+ groups and 5+ categories. A grouped bar chart with 3 groups × 8 categories = 24 bars in one chart, with 24 different color assignments to track.
- The within-group trend is as important as the across-group comparison.
- The story is "each group has a different pattern," not "category X dominates in all groups."

Small-multiple design rules:
- **Shared axes.** All panels must use the same x and y axis ranges for cross-panel comparison to be accurate. If each panel has its own y-axis scale, cross-panel comparison is impossible.
- **Sorted panels.** Order the panels by a summary metric (highest average, earliest peak, most growth) so the reader's scan direction encodes information.
- **Minimal decoration.** When the same chart type repeats 9 times, any decoration multiplies 9×. Strip everything: no panel borders, no repeated axis labels (show once per row/column), no titles per panel (use a categorical label only).

```r
# ggplot2: small multiples of bar charts
ggplot(df, aes(x = reorder(category, value), y = value)) +
  geom_col(fill = "#2A8C8B") +
  facet_wrap(~group, ncol = 3) +
  coord_flip() +
  theme_minimal() +
  theme(strip.text = element_text(face = "bold"))
```

@feynman

Like microservice deployments vs a monolith — each panel is independent and comparable, the shared axis is the agreed-upon API contract, and the grid layout is the orchestration that makes them readable as a system.
