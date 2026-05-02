@chapter
id: edv-ch07-visualizing-relationships
order: 7
title: Visualizing Relationships
summary: Scatterplots, line charts, bubble charts, and connected scatterplots — how to show the relationship between two or more variables without implying false causation or obscuring real correlation.

@card
id: edv-ch07-c001
order: 1
title: The Scatterplot as the Primary Two-Variable Tool
teaser: A scatterplot encodes two quantitative variables as position — the most accurate encoding for both — and lets the reader see correlation, clusters, outliers, and nonlinearity simultaneously.

@explanation

The scatterplot is the most information-dense chart for two continuous variables. Each observation is a dot; its x-position encodes one variable and its y-position encodes another. Nothing else is added.

What a scatterplot reveals that other charts cannot:
- **Correlation:** the slope and tightness of the dot cloud shows the direction and strength of the relationship.
- **Nonlinearity:** a curved relationship shows immediately in the dot distribution. A linear correlation coefficient hides curvature.
- **Clusters:** distinct groups of dots reveal segmentation that averages hide.
- **Outliers:** individual extreme points are visible; they would be invisible in aggregated charts.
- **Heteroscedasticity:** increasing spread at higher x values (common in economic data) shows as a funnel shape.

Design requirements for readable scatterplots:
- Equal aspect ratio when both axes are on the same scale.
- Axis ranges that include all data without excessive whitespace.
- A reference line (y = x or y = 0) when deviation from reference is the message.
- Trend line only when a linear relationship is expected and the line adds meaning beyond the dot cloud.

```python
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.scatter(df['x'], df['y'], alpha=0.6, s=30, color='#2A8C8B')
ax.set_xlabel('Variable A')
ax.set_ylabel('Variable B')
```

> [!info] The scatterplot was introduced by Francis Galton in 1875 to show the relationship between parental and child height. Regression to the mean — one of the most important statistical concepts — was discovered by examining a scatterplot, not by calculating a correlation coefficient.

@feynman

Like a 2D index — two lookup keys plotted simultaneously, and the cluster structure tells you about the joint selectivity that either key alone would miss.

@card
id: edv-ch07-c002
order: 2
title: Overplotting in Scatterplots
teaser: When thousands of points overlap in a scatterplot, the chart becomes a solid blob — the solutions are alpha transparency, 2D density, and beeswarm, each with different tradeoffs.

@explanation

Overplotting occurs when multiple data points map to the same or nearly the same pixel position. The result is a chart that looks like a solid region, hiding the density variation that makes the chart informative.

Solutions by data size:

**n < 500: Alpha transparency (alpha = 0.2–0.5).**
Overlapping points create darker regions, encoding density visually. The number of distinct points is still apparent.

```python
ax.scatter(x, y, alpha=0.3, s=20)
```

**n = 500–5,000: 2D histogram or hexbin.**
The plot area is divided into a grid of rectangles or hexagons; each cell is colored by the count of points within it. Individual points are lost; the density surface is visible.

```python
ax.hexbin(x, y, gridsize=30, cmap='viridis')
```

**n = 5,000–100,000: 2D kernel density estimate.**
A smooth density surface overlaid on (or replacing) the points.

```python
import seaborn as sns
sns.kdeplot(data=df, x='x', y='y', fill=True, cmap='viridis')
```

**n > 100,000: Sample + density.**
Plot a random 1,000–5,000 point sample as dots (for outlier visibility) overlaid on a hexbin or KDE background for the full dataset.

The wrong solution: reducing point size to dots so small they're invisible. Tiny dots still overlap; the result is a slightly less visible blob.

> [!tip] In interactive web charts (Observable Plot, D3, Vega-Lite), adding pan and zoom is often the best overplotting solution: the reader can zoom into dense regions to see individual points.

@feynman

Like log sampling in distributed tracing — full trace capture produces unmanageable volume; sampling at 1% with density estimation gives the shape of the traffic distribution while keeping extreme cases visible.

@card
id: edv-ch07-c003
order: 3
title: Correlation vs Causation in Scatterplots
teaser: A scatterplot shows correlation — the design choices (axis labels, titles, trend lines) determine whether the chart implies causation, which the chart alone cannot establish.

@explanation

A scatterplot can show that two variables move together. It cannot show that one causes the other. This distinction is completely invisible in the chart geometry — a scatterplot of ice cream sales vs drowning deaths looks identical to a scatterplot of cigarette smoking vs lung cancer incidence.

Design choices that imply causation (intended or not):

**Axis assignment.** Placing variable X on the x-axis and Y on the y-axis implies X is the independent variable and Y is the dependent variable. This implication is strong: readers interpret the x-axis as "the cause" even when no text says so.

**Trend line label.** A trend line labeled "regression of Y on X" implies X predicts Y. Without careful wording, readers interpret prediction as causation.

**Title language.** "Higher R&D spend is associated with revenue growth" is accurate. "R&D spend drives revenue growth" implies causation. "How to increase revenue: invest in R&D" is causal and requires causal evidence to support.

Responsible scatterplot design for correlation:
- Use "is associated with" rather than "drives" or "causes" in titles and labels.
- If showing a regression line, label it "regression line" not "trend" (which implies direction of causality).
- Acknowledge confounders in the chart notes or caption when they are likely to exist.

> [!warning] In 2026, AI-generated chart titles and summaries frequently convert correlation findings into causal language. If an AI tool writes chart titles for you, review every title that uses causal verbs: "increases," "drives," "causes," "leads to."

@feynman

Like a high correlation coefficient between two API metrics — the metrics move together because they're both downstream of the same slow database query, not because one causes the other. The correlation is real; the causal model is wrong.

@card
id: edv-ch07-c004
order: 4
title: Line Charts for Continuous Relationships
teaser: A line chart draws a line between consecutive observations — appropriate only when the x-axis variable is continuous and ordered, and the line represents a real physical or logical connection between adjacent points.

@explanation

A line chart encodes a relationship between an x-axis variable (usually time, but not always) and a y-axis variable by connecting consecutive observations with a line.

The line implies something specific: **the value exists at every point between observed values.** Connecting dot A at x=10 to dot B at x=20 with a line implies values exist at x=11, x=12, …, x=19, even if no observations were made. For continuous data (time, temperature, distance), this is correct. For categorical data (months named "Jan", "Feb", "Mar"), this is technically false.

When a line chart is correct:
- **Time series:** values are measured at regular intervals; the line between measurements represents the true continuous change.
- **Any ordered continuous x variable:** distance, temperature gradient, frequency response.
- **Multiple series compared over time:** one line per series, showing how each changes relative to the others.

When a line chart is wrong:
- **Nominal categories on the x-axis.** Using a line to connect "Asia", "Europe", "Americas" implies a continuous transition between these regions. Use a bar chart.
- **Sparse observations with large gaps.** A line between an observation in January and one in June implies values in February through May. If no measurements were made, the line is fiction.

> [!tip] If your x-axis labels are categorical names (not numeric or date values), use a bar chart. Connecting categorical observations with a line implies an ordering and continuity that doesn't exist in the data.

@feynman

Like interpolating between two known function values — linear interpolation is valid if the function is continuous and you expect it to behave linearly between measurements; it's wrong if the function is discontinuous or the gap is too large.

@card
id: edv-ch07-c005
order: 5
title: Connected Scatterplots
teaser: A connected scatterplot plots two variables against each other over time, connecting consecutive time periods with a line — it shows path and evolution in a way separate time series cannot.

@explanation

A **connected scatterplot** is a scatterplot where the dots represent time periods, connected in time order with a line. Both axes encode quantitative variables; time is the ordering dimension that flows along the connecting line, not its own axis.

What it shows: the joint trajectory of two variables over time. The path of the line reveals how the relationship between the variables evolved.

Example: a connected scatterplot of unemployment rate (x) vs inflation (y) by month over 10 years. A typical Phillips Curve relationship would show an oval path — as unemployment falls, inflation rises; as unemployment rises, inflation falls. The oval's tightness, orientation, and any deviations from an oval are visible in the path.

This information is impossible to read from two separate time series charts. You would need to mentally align two time series and read their co-evolution, which is slow and error-prone.

When connected scatterplots work:
- The relationship between two variables over time is more interesting than each variable individually.
- The path (loops, direction changes, breakpoints) is meaningful.
- The audience is comfortable with non-standard chart formats.

Annotation is critical: label key time periods (years, major events) on the path so the reader can orient. Without annotation, connected scatterplots are unreadable.

> [!info] Connected scatterplots require careful labeling of arrows or time markers along the path to show direction of travel. Without arrows, the reader cannot determine which end is the start or which direction the path moves.

@feynman

Like a 3D camera path exported from a renderer — the trajectory through 3D space shows the full motion; viewing the x, y, z channels separately loses the spatial relationship that defines the path.

@card
id: edv-ch07-c006
order: 6
title: Bubble Charts
teaser: A bubble chart extends a scatterplot with a third quantitative variable encoded as circle area — useful when a rough-magnitude third variable matters, but the area encoding is less precise than position.

@explanation

A **bubble chart** is a scatterplot where each dot is replaced by a circle, and the circle's area encodes a third quantitative variable. x-position encodes one variable, y-position a second, and circle area a third.

When bubble charts add value:
- A third variable genuinely matters to the story.
- The third variable spans a wide range (so differences are visible in area).
- Approximate size comparison is sufficient — the reader needs to know "this is much larger" not "this is 23% larger."

Design requirements for readable bubble charts:
- **Map to area, not radius.** If radius is proportional to value, area grows as the square of the value — a data value of 2 looks 4× bigger than 1, not 2×. Always use `r = sqrt(value)` for the radius calculation.
- **Include a size legend with representative circles and their values.** Without this, the reader cannot decode the area encoding.
- **Don't use more than ~30 bubbles.** Larger numbers produce an unreadable overlapping mess.
- **Allow transparency** (alpha = 0.5–0.7) for overlapping bubbles.

Classic use case: Gapminder-style charts. x = GDP per capita, y = life expectancy, size = population. The GDP/life-expectancy relationship is the scatterplot; the population variable adds a rough-magnitude third dimension.

```python
import matplotlib.pyplot as plt
sizes = [(pop / max_pop) * 2000 for pop in df['population']]  # area proportional
ax.scatter(df['gdp_per_capita'], df['life_expectancy'],
           s=sizes, alpha=0.6, color='#2A8C8B')
```

> [!warning] Never use bubble charts for precise quantitative comparison of the size dimension. If you need precise comparison of the third variable, encode it as color intensity or show it in a separate bar chart panel.

@feynman

Like disk usage reporting in a filesystem — you can see at a glance that one directory is much larger than another, but you can't judge whether it's 10× or 100× without reading the exact numbers.

@card
id: edv-ch07-c007
order: 7
title: Trend Lines and Smoothing
teaser: Adding a trend line to a scatterplot imposes a model on the data — the choice between linear, LOESS, and polynomial fits is a modeling decision with correctness requirements, not a visual preference.

@explanation

A trend line is a model of the relationship between two variables, overlaid on the raw data. Adding it changes the chart from "here is the data" to "here is the data and my claim about its underlying relationship."

Types of trend lines and when they apply:

**Linear regression (y = mx + b):** claims the relationship is approximately linear. The correct choice when you expect a constant rate of change and the residuals are approximately normal. Adding a linear line to a clearly nonlinear scatterplot is a false claim about the data.

**LOESS / LOWESS (locally weighted regression):** a flexible smoother that fits the local trend without imposing a functional form. Shows the general shape of the relationship. Appropriate for exploratory analysis where the functional form is unknown.

**Polynomial regression (y = ax² + bx + c):** claims a specific nonlinear form. Generally avoid unless there is a theoretical reason to expect that exact polynomial form.

**Confidence bands:** the shaded region around a trend line showing the uncertainty in the fitted line. Include them when the line is being interpreted as a model (regression inference), not just a visual smoother.

```python
import seaborn as sns
# LOESS smoother — non-parametric, appropriate for exploration
sns.regplot(x='x', y='y', data=df, lowess=True, scatter_kws={'alpha': 0.3})
```

> [!warning] A trend line on a scatterplot implies that the relationship exists and has the shown shape. If you're using a trend line for visual interest rather than as a genuine model, remove it. Every trend line is a claim that will be held against you.

@feynman

Like fitting a function to experimental data — the choice of function family (linear, polynomial, sigmoid) encodes a hypothesis about the underlying system, and the wrong function family fits the data but makes wrong predictions.

@card
id: edv-ch07-c008
order: 8
title: Correlation Matrices
teaser: A correlation matrix heatmap shows pairwise correlations across many variables at once — useful for exploratory analysis but too dense for communication charts.

@explanation

A **correlation matrix** displays the pairwise Pearson (or Spearman) correlation coefficients between every pair of variables in a dataset. Visualized as a heatmap, it lets the reader identify which variable pairs are most strongly related.

Design for correlation matrix heatmaps:
- Use a **diverging palette** centered at zero. Positive correlations (0 to +1) in one hue, negative (−1 to 0) in another. White or light gray at zero.
- Show only the **lower triangle** (or upper triangle). The matrix is symmetric; showing both halves wastes space and implies the reader needs to check both.
- **Order variables by similarity** (hierarchical clustering) so correlated variables are adjacent and the block structure becomes visible.
- **Annotate cells** with the correlation value when n of variables < 15. For larger matrices, rely on color and add a legend.

```python
import seaborn as sns
import numpy as np
corr = df.corr()
mask = np.triu(np.ones_like(corr, dtype=bool))  # upper triangle
sns.heatmap(corr, mask=mask, cmap='RdBu_r', center=0,
            vmin=-1, vmax=1, annot=True, fmt='.2f')
```

Limitation: Pearson correlation assumes linear relationships. A strong nonlinear relationship (e.g., quadratic) can have r ≈ 0. Supplement correlation matrices with a pairs plot (Chapter 8) for nonlinear detection.

> [!info] For exploratory feature selection in ML, correlation matrices identify multicollinear features (correlation > 0.9) that are candidates for removal. Seaborn's `heatmap()` with clustering (`method='ward'`) groups correlated features visually.

@feynman

Like an adjacency matrix for a graph — you can see the edge density and the cluster structure at a glance, but the detailed structure of each edge requires zooming in or looking at the row/column directly.

@card
id: edv-ch07-c009
order: 9
title: Slope Graphs
teaser: A slope graph shows how values change between exactly two points — two time periods or two categories — for multiple items simultaneously, making rank changes and winners vs losers immediately readable.

@explanation

A slope graph places two vertical axes side by side, one for each time point or category. Each item gets a single line connecting its left-axis value to its right-axis value. The slope of each line encodes the direction and magnitude of change. Items that rose have upward slopes; items that fell have downward slopes; crossing lines reveal rank reversals.

Where slope graphs outperform alternatives:
- **Ranking changes:** a bar chart grouped by time point requires the reader to mentally compare bar heights across groups. A slope graph makes the same rank-change visible as a crossing line.
- **Winners vs losers framing:** items are instantly sorted into upward (winning) and downward (losing) groups by slope direction.
- **Relative change for many items at once:** up to ~15 items can coexist in a slope graph without excessive tangling.

Design requirements:
- Label both endpoints of each line (left and right axis values) so the reader can read exact values without a separate legend.
- Use color or line weight to highlight the items that carry the story; mute the rest to gray.
- Sort items on the left axis by their starting value, not alphabetically.

Pitfalls:
- More than 2 time points turns a slope graph into a spaghetti multi-line chart. Use a small-multiple or indexed line chart instead.
- Very similar values produce tangled crossing slopes that are unreadable. If items cluster closely, switch to a dot plot or bar chart.

> [!tip] Slope graphs shine in editorial and business dashboards — "which teams improved vs declined from Q1 to Q2?" is a natural slope graph question. Reserve them for the exactly-two-comparison case.

@feynman

Like a git diff for rankings — two snapshots side by side, with lines showing what moved up, what moved down, and what stayed flat, so the delta is legible without holding both states in working memory simultaneously.

@card
id: edv-ch07-c010
order: 10
title: Log Scales for Skewed Relationships
teaser: When a variable spans several orders of magnitude, a linear scale compresses most data into a corner — a log scale linearizes exponential growth and makes power-law distributions readable.

@explanation

A linear scale allocates equal pixel distance to equal numeric differences. When data spans several orders of magnitude — say, company revenues from $1 million to $500 billion — a linear scale devotes 99.8% of the axis to the top 0.1% of companies. Everything else is squashed into a sliver near zero. The relationship is unreadable.

A log scale allocates equal pixel distance to equal multiplicative factors. Each decade (10×) gets the same visual width: 1–10 occupies the same space as 10–100 or 100–1,000. This expands the low end and compresses the high end.

Two common configurations:
- **Semi-log (log y-axis, linear x-axis):** appropriate when y grows exponentially with x — population over time, compound interest, viral spread. Exponential growth appears as a straight line on a semi-log chart. A bend in the line means the growth rate is changing.
- **Log-log (both axes log-scaled):** appropriate when both variables span orders of magnitude, or when you expect a power-law relationship. Power laws (y = ax^b) appear as straight lines on a log-log chart; the slope equals the exponent b.

Cognitive costs to manage:
- Label the axis explicitly as "log scale" — readers who miss this will misread distances as linear.
- Tick marks should be at powers of 10 (1, 10, 100, 1,000) or at 1×, 2×, 5× multiples within each decade — never at equal linear intervals.
- Annotate a few reference points with their exact values so readers can calibrate.

> [!warning] Never use a log scale when data includes zero or negative values — log(0) is undefined, and the visual will either error or silently drop those points. If zeros are meaningful in your data, a log scale is the wrong tool.

@feynman

Like switching from absolute timestamps to log-scale elapsed time in a profiler — the microsecond-level operations that dominate the count but not the wall time become visible, while the one 5-second database call still anchors the right end of the scale.
