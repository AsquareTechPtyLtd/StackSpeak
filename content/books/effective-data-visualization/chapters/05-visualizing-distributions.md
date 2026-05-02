@chapter
id: edv-ch05-visualizing-distributions
order: 5
title: Visualizing Distributions
summary: Showing how data is spread across a range — histograms, density plots, violin plots, box plots, and ridgeline plots — and knowing when each reveals something the others hide.

@card
id: edv-ch05-c001
order: 1
title: Why Showing the Distribution Matters
teaser: A bar chart of means hides bimodal distributions, wide variance, and outliers — the average is often the least informative single statistic about how values actually behave.

@explanation

The mean is a lossy compression of a distribution. Two datasets with identical means can have completely different distributions:
- One tightly clustered around the mean (low variance).
- One with two separated groups (bimodal).
- One with a long tail of extreme outliers.
- One uniformly distributed across a range.

A bar chart of means cannot distinguish these. The reader sees four equal bars and concludes the groups are the same. They may be nothing alike.

Anscombe's Quartet (1973) is the classic demonstration: four datasets with identical mean, variance, correlation, and regression line — but completely different distributions and relationships. A plot of the raw data reveals in 1 second what a summary table hides entirely.

In 2026, the same failure happens constantly in product dashboards:
- "Average response time" hides the P95/P99 latency tail.
- "Average user session length" hides that half the users bounce in 5 seconds.
- "Average satisfaction score" hides a bimodal distribution of delighted and frustrated users.

The rule: for any metric where variability matters (performance, satisfaction, revenue, usage), show the distribution, not the mean. Show the mean only after the reader understands the shape of the data.

> [!warning] A bar chart of means with error bars is better than a bar chart of means alone, but still hides whether the data is normally distributed, bimodal, or skewed. Show the actual distribution when the data shape matters.

@feynman

Like profiling vs measuring average wall time — the mean tells you it runs in 50ms on average; the distribution shows that 95% complete in 10ms and 5% take 800ms, which is a completely different problem.

@card
id: edv-ch05-c002
order: 2
title: Histograms
teaser: A histogram divides a continuous variable into bins and counts occurrences per bin — the most fundamental distribution visualization, with one critical parameter: bin width.

@explanation

A histogram encodes a distribution by:
1. Dividing the value range into equal-width bins.
2. Counting how many observations fall in each bin.
3. Drawing a bar proportional to the count (or frequency) per bin.

The histogram's one critical parameter is **bin width**. The choice changes what pattern is visible:
- Too narrow (many bins): the histogram shows noise. Random variation between adjacent bins dominates; the underlying shape is obscured.
- Too wide (few bins): the histogram hides structure. Bimodal distributions look unimodal; skewed distributions look symmetric.

There is no universally correct bin width. The right bin width is the one that shows the shape you're trying to understand. Common heuristics:
- **Sturges' rule:** k = log₂(n) + 1 bins. Too few for large datasets.
- **Freedman-Diaconis rule:** bin width = 2 × IQR × n^(−1/3). More robust; good default for exploration.
- **Square root rule:** k = √n bins. Simple, works reasonably for n < 1000.

Always try at least three different bin widths before settling on one.

Histograms work best for:
- Single continuous variable, n > 30.
- Understanding overall shape, not comparing groups.
- Finding outliers, gaps, and multimodality.

```python
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 3, figsize=(12, 4))
for ax, bins in zip(axes, [10, 30, 100]):
    ax.hist(data, bins=bins, edgecolor='white')
    ax.set_title(f'{bins} bins')
```

> [!tip] Always show all three bin widths in exploratory work. Commit to one for communication only after understanding which width reveals the relevant structure.

@feynman

Like resolution when sampling a signal — too few samples miss the pattern; too many samples amplify noise; the right sample rate depends on the frequency you're trying to resolve.

@card
id: edv-ch05-c003
order: 3
title: Density Plots
teaser: A kernel density estimate (KDE) smooths a histogram into a continuous curve — better than histograms for comparing multiple groups, worse for reading exact counts.

@explanation

A **density plot** uses kernel density estimation (KDE) to produce a smooth curve approximating the probability density of the data. It is conceptually a very-fine-grained histogram with a smoothing function applied.

Advantages over histograms:
- No bin-width decision needed. Instead, a bandwidth parameter controls smoothness, but is less sensitive to misspecification than bin width.
- Overlapping distributions are clearly visible when multiple groups are shown on the same axes. Overlapping histograms become confusing; overlapping density curves remain readable.
- Works well for continuous comparison across 3–5 groups.

Disadvantages:
- Does not show counts. The y-axis is density, not frequency. Readers cannot see that Group A has 50 observations and Group B has 5,000.
- Implies data exists beyond the actual data range. A KDE for non-negative data (age, height, price) will extend below zero, suggesting impossible values.
- Hides sample size. A density curve looks equally "real" for n = 30 and n = 30,000.

```python
import seaborn as sns
# Compare distributions of two groups
sns.kdeplot(data=df, x='value', hue='group', fill=True, alpha=0.3)
```

The fix for count visibility: plot density curves alongside a rug plot (tick marks at each data point) or add sample size annotations.

> [!info] In seaborn, `kdeplot()` defaults to bandwidth via Scott's rule (h = n^(−1/5) × σ). This is a good default for unimodal distributions; for multimodal distributions, reduce the bandwidth manually with `bw_adjust < 1` to reveal structure.

@feynman

Like smoothing a noisy signal with a moving average — you trade exact values for a cleaner trend, and the bandwidth is the window size that determines how much smoothing you apply.

@card
id: edv-ch05-c004
order: 4
title: Box Plots
teaser: A box plot summarizes a distribution in five statistics — median, quartiles, and whisker extent — which is efficient for comparison but catastrophically hides bimodal and multimodal distributions.

@explanation

A **box plot** (also box-and-whisker plot) displays:
- **Box:** spans the interquartile range (IQR) — Q1 (25th percentile) to Q3 (75th percentile).
- **Median line:** the horizontal line inside the box.
- **Whiskers:** extend to the furthest observation within 1.5 × IQR from the box edges.
- **Points beyond whiskers:** plotted individually as outliers.

When box plots are useful:
- Comparing 5+ groups on a single variable where the distributions are approximately unimodal.
- Quickly summarizing central tendency, spread, and outliers for many groups side by side.
- Space is constrained: 20 groups × 1 box plot is more readable than 20 groups × 1 density plot.

The critical limitation: box plots look identical for unimodal and bimodal distributions with the same median and IQR. A bimodal distribution with two peaks at Q1 and Q3 and few observations at the median produces a box plot that looks like a uniform distribution.

The rule: **never use a box plot as the only visualization when sample size allows a better one.** For n < 100, show all data points. For n > 100, use a violin plot that shows the density shape.

```python
# seaborn: box plot comparison
sns.boxplot(data=df, x='group', y='value')
# Better: add strip plot to show individual points
sns.stripplot(data=df, x='group', y='value', alpha=0.3, jitter=True)
```

> [!warning] Box plots were designed for audiences that understand what they show. In general-audience or executive communication, few readers can interpret a box plot correctly. Use a bar chart of medians with IQR range indicators instead.

@feynman

Like a commit log with only merge commits — the summary is correct but the individual changes are invisible, and the things hidden are exactly the interesting things (conflicts, reverts, experimental paths).

@card
id: edv-ch05-c005
order: 5
title: Violin Plots
teaser: A violin plot combines a box plot with a density estimate — showing the shape of the distribution on both sides of a central axis, which reveals bimodality that box plots hide.

@explanation

A **violin plot** wraps a mirrored kernel density estimate around a central axis, with an optional box plot summary inside. It shows:
- Distribution shape (the density outline).
- Spread (the width at each value).
- Central tendency (the embedded median marker).
- Sample size (implicitly via density width, though this should be labeled separately).

Violin plots beat box plots when:
- Groups may have bimodal or skewed distributions.
- n > 50 per group (enough to estimate density reliably).
- Comparing 3–8 groups.

Violin plots beat density plots when:
- Multiple groups need to be compared in a small space.
- The summary statistics (median, quartile range) are also needed.

Violin plot design considerations:
- **Show the quartiles inside the violin.** The box-plot-within-violin combination is the most informative standard variant.
- **Scale all violins to the same maximum width** when comparing groups of different sizes. If violins are width-proportional to sample size, annotate the sample sizes explicitly.
- **Avoid very small n.** A violin plot for n = 15 shows a smooth density curve that is mostly noise. For small samples, use a strip plot or beeswarm instead.

```python
# seaborn: violin plot with inner quartile box
sns.violinplot(data=df, x='group', y='value',
               inner='box',  # show quartiles inside
               palette='colorblind')
```

> [!info] Observable Plot supports violin-style distributions via `Plot.binX` + `Plot.areaY` combination. As of 2026, the Observable Plot documentation includes a violin plot recipe in the community examples.

@feynman

Like a flame graph vs a profiler table — the violin shape lets you read the distribution topology (where time clusters, whether there are two modes) in a way the table of numbers cannot.

@card
id: edv-ch05-c006
order: 6
title: Ridgeline Plots
teaser: Ridgeline plots stack partially overlapping density curves for 10–30 groups along a y-axis — ideal for showing how a distribution shifts across an ordered categorical variable.

@explanation

A **ridgeline plot** (also called a joyplot) stacks density curves for many ordered groups along the y-axis, with each group's curve overlapping the one below it. The visual effect is a mountain range where each ridge is a distribution.

When ridgeline plots excel:
- **Many ordered groups** (10–30): months, age groups, years, geographic zones ordered by latitude/longitude.
- **The pattern of change across groups** is the message, not individual group statistics.
- The distributions shift in a predictable direction as the grouping variable increases — ridgeline plots make this gradient visible.

Classic use cases:
- Monthly distribution of temperature across 12 months.
- Distribution of test scores across grade levels.
- Distribution of response times across 20 API endpoints sorted by median response time.

Ridgeline design rules:
- **Order groups by a summary statistic** (median, mean) so the ridge heights shift systematically and the trend is readable.
- **Allow 30–50% overlap** between adjacent ridges. Too little overlap loses the mountain metaphor; too much overlap hides the ridges below.
- **Use a single hue** with lightness variation per group. Multiple hues add confusion; the position encoding already separates groups.

```r
# R ggridges package
library(ggridges)
library(ggplot2)
ggplot(df, aes(x = value, y = reorder(group, value, median))) +
  geom_density_ridges(fill = "#2A8C8B", alpha = 0.7) +
  theme_ridges()
```

> [!tip] Ridgeline plots are visually striking but require an informed audience. For general audiences, a small-multiple density plot grid communicates the same information without requiring the reader to interpret overlapping curves.

@feynman

Like git log --graph for a linear history — the visual stacking shows the progression over time at a glance, with each commit (group) positioned relative to those before and after it.

@card
id: edv-ch05-c007
order: 7
title: Strip Plots and Beeswarm Plots
teaser: When sample size is small (n < 200), showing every data point as a dot is more honest and more informative than any summary statistic — strip plots and beeswarm plots are the tools.

@explanation

For small samples, summary statistics (mean, median, IQR) are unstable and potentially misleading. Every visualization that compresses to summaries loses information that the small sample barely had to give.

**Strip plot:** plots every observation as a dot along one axis, with slight random jitter added horizontally to prevent overplotting. Simple, honest, readable for n < 100 per group.

**Beeswarm plot:** a deterministic layout algorithm places dots so they don't overlap, clustering them symmetrically around the central axis. Looks like a violin plot outline but is composed of individual dots. Better than a strip plot for n = 50–300 because no dots are hidden by overlap.

Both plots reveal:
- Sample size (count the dots).
- Gaps and clustering.
- Individual outliers (visible as isolated points, not aggregated into a whisker).
- Bimodal structure (two dot clusters instead of one).

When not to use individual-point plots:
- n > 500 per group: dots overlap even with beeswarm layout. Use a density-based visualization.
- The reader needs summary statistics (median, variance) without counting: add a box or bar overlay.

```python
# seaborn: strip plot with jitter
sns.stripplot(data=df, x='group', y='value',
              jitter=True, alpha=0.5, size=4)

# Better: beeswarm (requires beeswarm package or seaborn's swarmplot)
sns.swarmplot(data=df, x='group', y='value', size=4)
```

> [!info] For publication-quality figures with small samples, the standard is now box plot (or bar + CI) overlaid with individual data points. The convention is standardized in many journals: the raw data is required alongside any summary visualization.

@feynman

Like a commit history with all commits vs squashed — the individual points are the commits; summary statistics are the squashed view; for a repository with 50 commits, showing each one is more informative than the squash summary.

@card
id: edv-ch05-c008
order: 8
title: Comparing Distributions Across Groups
teaser: The right chart type for comparing distributions depends on the number of groups, sample size per group, and whether shape or summary statistics are the message.

@explanation

The decision matrix for multi-group distribution comparison:

**2–3 groups, n > 100 per group:**
- Density plots with fill, slightly transparent. Overlap regions are visible.
- Violin plots if quartiles also matter.

**4–8 groups, n > 50 per group:**
- Violin plots. Box plots if quartiles are sufficient.
- Ridgeline if groups have a natural order and the shift pattern is the story.

**9+ groups, n > 50 per group:**
- Box plots (space-efficient) with individual point overlay if n is small enough.
- Ridgeline plots if the groups are ordered and a gradient is expected.

**Any number of groups, n < 50 per group:**
- Strip plot or beeswarm. Show individual points.
- Add a mean bar or median dot overlay for orientation.

**Any number of groups, n > 1000 per group:**
- Density plots or violin plots. Individual points are unreadable at this scale.
- 2D density heatmap if plotting two continuous variables.

Common error: using a bar chart of means for a distribution comparison when the distributions overlap substantially. Two groups with mean = 50 may have completely non-overlapping distributions (one is 40–45, the other is 55–60) or completely overlapping ones (both are 10–90). The means are identical; the comparison problem is completely different.

> [!tip] Always look at the underlying distribution at least once during exploratory analysis, even if the final chart shows summary statistics. The distribution check is a data quality audit as much as a visualization decision.

@feynman

Like load testing at different concurrency levels — the summary metric (mean response time) hides whether the system degrades uniformly or has a cliff at 100 concurrent users; the distribution shows the cliff.

@card
id: edv-ch05-c009
order: 9
title: Logarithmic Scales for Skewed Distributions
teaser: Right-skewed distributions with extreme outliers are often better visualized on a log scale — the log transform makes the bulk of the data visible while keeping outliers in frame.

@explanation

Many real-world quantities follow power law or log-normal distributions: incomes, file sizes, city populations, bug counts, request rates. On a linear scale, these distributions look like a thin spike near zero with a few extreme outliers that dominate the axis range. The bulk of the data compresses into an unreadable region.

On a log scale, the same data spreads more evenly across the chart. The 10× difference between $10K and $100K income looks the same visually as the 10× difference between $100K and $1M — which matches the practical meaning of these differences for most analysis purposes.

When to use log scale for distributions:
- Data spans more than 2 orders of magnitude.
- Extreme outliers are compressing the main distribution into a sliver.
- Percentage differences are more meaningful than absolute differences.
- The distribution is expected to be log-normal (incomes, file sizes, biological measurements).

How to label a log-scale axis:
- Use actual values at labeled tick positions: 1, 10, 100, 1000 — not 0, 1, 2, 3.
- Always explicitly label the axis as "log scale."
- Do not use a log scale without a log axis label. Readers assume linear unless told otherwise.

```python
import matplotlib.pyplot as plt
ax.hist(data, bins=50, log=False)  # linear: right-skewed, unreadable
# Better:
import numpy as np
ax.hist(np.log10(data), bins=50)   # log-transformed data, linear axis
ax.set_xlabel('log₁₀(file size in bytes)')
```

> [!warning] A log scale hides the absolute differences that a linear scale shows. Using log for income data makes the rich and poor look closer together than they are in absolute terms. Scale choice is rhetorical as well as technical.

@feynman

Like git log --since for active projects — the raw timeline compresses years of initial development into nothing; a log-scaled time axis spreads activity across the chart proportionally to relative pace.

@card
id: edv-ch05-c010
order: 10
title: Empirical Cumulative Distribution Functions (ECDFs)
teaser: An ECDF plots each observation against the fraction of observations below it — it shows the full distribution without bin width decisions and enables precise percentile reading.

@explanation

An **empirical cumulative distribution function (ECDF)** is one of the most informative and underused distribution visualizations. For each data point, it answers: "what fraction of the data is at or below this value?"

Construction: sort all values and plot each as a dot at its value (x-axis) and its rank divided by n (y-axis). No bins, no parameters, no smoothing — it shows exactly what the data contains.

What ECDFs make easy:
- **Percentile reading:** "what value is the 90th percentile?" — read directly from the curve.
- **Distributional comparison:** multiple ECDFs on the same plot show which distribution has more extreme values, where the distributions cross, and where one has a longer tail.
- **Outlier visibility:** outliers appear as a flat plateau at the top of the curve (most observations cluster below, then a few extreme values extend the tail).
- **Gap detection:** missing ranges appear as vertical jumps — the probability mass goes from some percentile to a higher one with no observations in between.

Example: comparing P50, P90, P99 latency across five API endpoints on one ECDF chart. All five ECDFs on one plot with the 50th, 90th, 99th percentile lines marked.

```python
import numpy as np
import matplotlib.pyplot as plt

def plot_ecdf(data, ax, label=''):
    x = np.sort(data)
    y = np.arange(1, len(x) + 1) / len(x)
    ax.step(x, y, label=label, where='post')

for group, values in groups.items():
    plot_ecdf(values, ax, label=group)
ax.axhline(0.9, color='gray', linestyle='--', label='P90')
```

> [!info] ECDFs are standard in performance engineering and reliability work but underused in product and business analytics. They answer "what fraction of users see latency below X?" better than any histogram or mean/percentile table.

@feynman

Like a latency percentile chart in an SRE runbook — the ECDF is exactly that chart extended to the full distribution, not just the P50/P90/P99 summary.
