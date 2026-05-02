@chapter
id: edv-ch09-geography-uncertainty-overlap
order: 9
title: Geography, Uncertainty, and Overlapping Data
summary: How to encode geographic data without letting projection choice mislead, how to represent uncertainty honestly rather than hiding it, and how to handle overplotted data without losing the signal.

@card
id: edv-ch09-c001
order: 1
title: Choropleths and Their Pitfalls
teaser: A choropleth map fills geographic regions with colors encoding values — powerful for geographic patterns, but area-normalized data is required or large sparse regions dominate visually.

@explanation

A **choropleth map** fills geographic regions (countries, states, census tracts) with a color encoding a quantitative value. The color intensity typically uses a sequential palette for one-directional values or a diverging palette for deviation-from-reference values.

When choropleths work:
- Data is inherently geographic and regional.
- Values are normalized per area or per population. Raw counts require normalization.
- Broad geographic patterns (northeast vs southeast, coastal vs inland) are the story.

The normalization requirement: a choropleth of raw voter counts makes populous states look dominant. California has 40M people; Wyoming has 0.6M. A choropleth of votes per 1,000 people shows the actual pattern. Always normalize by area, population, or a relevant denominator before choropleth-mapping counts.

Classification scheme affects the visual:
- **Equal intervals:** equal-sized bins across the value range. Appropriate for uniformly distributed data.
- **Quantile classification:** equal numbers of regions per bin. Good for identifying relative position regardless of distribution.
- **Natural breaks (Jenks):** breaks at natural clusters in the distribution. Matches the actual data distribution.

The choice of classification scheme can reverse the apparent message of a choropleth. Always show the legend with the actual bin boundaries.

```python
# geopandas: choropleth
import geopandas as gpd
world = gpd.read_file(gpd.datasets.get_path('naturalearth_lowres'))
merged = world.merge(df, on='iso_a3')
merged.plot(column='gdp_per_capita', cmap='YlOrRd',
            legend=True, classification_kwds={'k': 5})
```

> [!warning] A choropleth where Alaska and Canada are the same color as the continental US legend implies geographic regions are the unit, not population. Always verify the reader can see the most important regions clearly at the chart's intended display size.

@feynman

Like a coverage map for a cellular network — region size encodes geographic area, not user population, and rural areas with low population look equally prominent to dense urban areas that matter more to the business.

@card
id: edv-ch09-c002
order: 2
title: Projection Choice Changes the Story
teaser: Every map projection distorts shape, area, distance, or direction — the choice of projection implicitly argues about what matters, and the most common projections are systematically wrong for most use cases.

@explanation

The Earth is a sphere; a flat map is always a distortion. Different projections make different tradeoffs:

**Mercator projection:** preserves angles (conformal) and shows correct compass directions, making it ideal for navigation. Distorts area massively: Greenland appears larger than Africa; in reality, Africa is 14× larger. The Mercator projection is wrong for any map where regional size comparison matters.

**Web Mercator (EPSG:3857):** the projection used by Google Maps, OpenStreetMap, and most web mapping tiles. It is a modified Mercator with the same area distortion. Ubiquitous in web mapping; wrong for data visualization.

**Equal-area projections (Albers, Mollweide, Goode's Homolosine):** preserve area at the cost of shape distortion. Correct for choropleth maps where values are counts or densities (not normalized by area). The US Albers conic projection is standard for US-focused maps.

**Azimuthal equidistant:** preserves distance from the center point. Useful for maps centered on a specific location (e.g., flight routes from one hub).

Practical rules:
- For choropleth maps: use an equal-area projection.
- For navigation or route maps: Mercator or Web Mercator is acceptable.
- For global maps: Robinson or Winkel Tripel balance area and shape distortion.
- For US maps: Albers Equal Area Conic (CONUS standard).

> [!info] In geopandas, the CRS (coordinate reference system) determines the projection. `EPSG:4326` is geographic coordinates (unprojected); `EPSG:5070` is Albers Equal Area for the contiguous US. Always set the CRS before plotting.

@feynman

Like choosing float vs double precision — the projection is a transform that trades one kind of error for another, and the default (Web Mercator, like float precision) is wrong for applications where the discarded accuracy matters.

@card
id: edv-ch09-c003
order: 3
title: Point Maps and Proportional Symbol Maps
teaser: When geographic data attaches to points (events, facilities, incidents) rather than regions, point maps and proportional symbol maps are more accurate than choropleths.

@explanation

Choropleth maps attach values to regions. But much geographic data is point-based: store locations, incident reports, user sign-ups by lat/lon, earthquake epicenters.

**Point maps:** place a dot at each data point's geographic location. Shows where events occur and how dense they are spatially. For large numbers of points, use alpha transparency (0.1–0.3) or 2D density overlays to show density gradients.

**Proportional symbol maps:** place circles at each location, sizing circles proportional to a quantitative value. Shows both location and magnitude. Design rules are the same as bubble charts: map to area (not radius), include a size legend.

Advantages over choropleths for point data:
- No arbitrary regional boundaries distort the pattern. The pattern is visible at the actual geographic scale where it occurs.
- Multiple events in the same region are visible as clusters, not averaged into a regional value.
- The geographic density (events per square kilometer) is visible through clustering.

Limitations:
- For very dense data (millions of GPS pings), individual points cannot be shown. Use hexbin aggregation to a map tile grid.
- Proportional symbols near borders or edges of the map may bleed outside the expected region.

```python
# geopandas + matplotlib: proportional symbol map
ax = world.plot(color='lightgray', edgecolor='white')
cities.plot(ax=ax, markersize=(cities['population'] / 100000) ** 0.5 * 20,
            color='#C84A50', alpha=0.7, marker='o')
```

> [!tip] For exploratory geographic analysis of millions of points, use deck.gl's HexagonLayer or ScatterplotLayer. It renders millions of GPU-accelerated points in a browser and supports interactive filtering that matplotlib cannot handle at scale.

@feynman

Like a point index vs a region index in spatial databases — the region index aggregates, which is efficient and loses precision; the point index preserves the original location but requires spatial clustering algorithms to find patterns.

@card
id: edv-ch09-c004
order: 4
title: Cartograms — Distorting Geography to Encode Data
teaser: A cartogram resizes geographic regions to be proportional to a data variable rather than geographic area — showing "importance" rather than physical size.

@explanation

A **cartogram** is a map where the geographic area of each region is distorted to be proportional to a data variable (population, GDP, votes, cases). It answers the question "if region size reflected X, what would the map look like?"

Types of cartograms:
- **Contiguous cartogram (Gastner-Newman):** regions are resized to be data-proportional while maintaining adjacency relationships. The shapes distort but neighboring regions remain neighbors.
- **Non-contiguous cartogram:** regions are resized independently without maintaining adjacency. Gaps appear between regions. Easier to implement, harder to read.
- **Dorling cartogram:** regions are replaced with circles proportional to the data variable. Geographic position is preserved approximately; adjacency is not.

When cartograms are useful:
- The geographic size of a region is systematically misleading relative to its data importance (e.g., Wyoming has 0.6M people but its area is 250,000 km²).
- The audience needs to internalize the weighting difference between large-but-sparse and small-but-dense regions.

When cartograms fail:
- Geographic recognition is required. Heavily distorted regions become unrecognizable. Include labels.
- The audience is unfamiliar with map interpretation. Cartograms require significant cartographic literacy.
- The message requires accurate geographic positions (routing, distance, spatial proximity).

> [!info] Cartogram generation is complex and computationally intensive. The `cartogram` R package and `cartopy` Python library can produce contiguous cartograms, but processing time for a global cartogram can be minutes to hours depending on resolution.

@feynman

Like a weighted graph where edge distances encode relationship strength instead of physical distance — the layout distorts Euclidean space to reveal the weighted topology, at the cost of making absolute positions harder to interpret.

@card
id: edv-ch09-c005
order: 5
title: Why Uncertainty Is Routinely Hidden
teaser: Error bars, confidence intervals, and uncertainty bands are systematically omitted from charts because they complicate the narrative — but omitting them is a form of false precision.

@explanation

Every measurement has uncertainty. Sample statistics (means, proportions, correlations) have sampling error. Model predictions have confidence intervals. Survey results have margins of error. Forecast data has prediction intervals.

Despite this, most production charts show point estimates with no uncertainty markers. The reasons are understandable:

**Narrative clarity.** Uncertainty bands complicate a clean message. "Revenue will be $5M next quarter" is a cleaner slide than "$5M ± $1.5M."

**Audience literacy.** Many business audiences don't know how to interpret error bars. Showing them can generate confusion rather than insight.

**Data collection gaps.** Uncertainty is often never calculated. If the pipeline outputs point estimates only, there's nothing to show.

Why this matters:
- A decision made on "$5M revenue" with a ±$1.5M interval is different from the same decision without that context. The interval may change which option is the right choice.
- Two model forecasts with overlapping confidence intervals are not distinguishable — showing only the point estimates implies false precision in the comparison.
- A/B test results with p = 0.06 "are not significant" but a point-estimate chart looks like a clear winner.

The professional standard: show uncertainty wherever it can be calculated. Acknowledge it textually where it cannot. The visualization is not responsible for the audience's comfort; it is responsible for honesty.

> [!warning] Charts presented to decision-makers without uncertainty estimates imply false precision. In a business context, this is not just a visualization flaw — it is a material omission in the evidence supporting a decision.

@feynman

Like a function that returns a value without a documentation note that it can return null — the caller doesn't know to handle the edge case, and the bug only appears in production under conditions the documentation glossed over.

@card
id: edv-ch09-c006
order: 6
title: Error Bars — Which Kind and Why
teaser: Error bars mean different things depending on what they encode — standard deviation, standard error, 95% CI, and range are not interchangeable, and using the wrong one is a factual error.

@explanation

An error bar is a line extending above and below a point estimate. What the bar represents is not self-evident — it must be labeled. Common options:

**Standard deviation (SD):** the spread of individual observations. A bar of ±1 SD means "about 68% of observations fall within this range." Describes the data distribution, not the precision of the mean estimate.

**Standard error (SE):** the uncertainty in the sample mean. SE = SD / √n. A bar of ±1 SE encodes how much the sample mean might vary if the experiment were repeated. SE is narrower than SD; bars look more precise than they are.

**95% Confidence Interval:** the range within which the true population mean is expected to fall 95% of the time under repeated sampling. ≈ ±2 SE for large n. The correct choice for communicating the precision of a mean estimate.

**Range (min/max):** shows the full extent of the data. Sensitive to outliers.

The mismatch error: presenting SE bars instead of 95% CI bars makes results look more certain than they are. Two groups with overlapping SE bars can be significantly different; two groups with non-overlapping 95% CIs are definitely different.

```python
import matplotlib.pyplot as plt
# Plot with 95% CI bars
means = df.groupby('group')['value'].mean()
ci95 = df.groupby('group')['value'].sem() * 1.96  # approximate 95% CI
ax.bar(means.index, means, yerr=ci95, capsize=5)
ax.set_title("Mean ± 95% CI")  # Always label what the bars represent
```

> [!warning] Always label error bars explicitly — "Error bars = 95% CI" in the caption or axis label. An unlabeled error bar is interpreted differently by different readers, undermining the entire purpose of showing it.

@feynman

Like documenting an API's error response — the shape of the error object doesn't tell you what caused it; you have to read the documentation to know if it's a client error (SE) or a server error (95% CI), and the distinction changes how you handle it.

@card
id: edv-ch09-c007
order: 7
title: Confidence Bands for Regression Lines
teaser: A shaded band around a regression line shows where the line might plausibly run under different samples — it should always accompany regression lines used as evidence.

@explanation

A regression confidence band shows the uncertainty in the regression line itself (not in individual predictions). Technically: the 95% confidence band is the region within which we expect the true regression line to fall 95% of the time under repeated sampling.

A related but different concept is the **prediction interval**: the range within which a new individual observation is expected to fall. Prediction intervals are much wider than confidence bands and are appropriate when the question is "where will the next data point fall?" rather than "where does the true line run?"

When to show a confidence band:
- The regression line is being used as evidence for a relationship (slope ≠ 0).
- The dataset is small enough that there is meaningful uncertainty in the regression.
- The message includes "X is positively associated with Y" — the band shows whether this claim is defensible.

When a confidence band adds clutter without value:
- n > 1,000 and the CI band is imperceptibly thin. Omit it.
- The regression line is a visual smoother (LOESS for trend detection), not an estimated model.

```python
import seaborn as sns
# Shows regression line with 95% CI band by default
sns.regplot(x='x', y='y', data=df, ci=95,
            scatter_kws={'alpha': 0.3}, line_kws={'color': '#C84A50'})
```

> [!tip] For communication charts, if showing a regression line with a very tight CI band, you can omit the band and note "slope is statistically significant (p < 0.001)" in the caption. The band adds visual value only when it is meaningfully wide.

@feynman

Like a tolerance envelope in an engineering spec — the single nominal value (the line) tells you the target; the tolerance band tells you whether the manufacturing process is precise enough to make the claim actionable.

@card
id: edv-ch09-c008
order: 8
title: Quantile Dot Plots for Communicating Uncertainty
teaser: A quantile dot plot shows a probability distribution as a grid of dots where each dot represents a 1% or 2% probability mass — more readable than density plots for non-statistical audiences.

@explanation

A **quantile dot plot** displays a probability distribution as a grid of equally sized dots, where each dot represents a fixed probability mass (e.g., 1%). The dots are stacked into a histogram shape, but because each dot = 1%, the reader can count dots to read probabilities.

Example: a 100-dot quantile dot plot of a forecast showing 70% chance of revenue between $4M and $6M. The reader counts 70 dots in the $4M–$6M range without needing to understand probability density.

Why quantile dot plots communicate uncertainty better than density curves:
- Readers can count dots to read probability. "I can see 15 dots above $6M" is more intuitive than reading the area under a density curve.
- The discrete representation reduces the tendency to overread precision from smooth curves.
- They are accessible to audiences with minimal statistical background.
- They clearly communicate rare outcomes — a stack of 5 dots at an extreme value is visible as "a small but non-trivial probability."

```r
# R: quantile dot plot using ggdist
library(ggdist)
library(ggplot2)
data.frame(value = rnorm(1000, 5, 1)) |>
  ggplot(aes(x = value)) +
  stat_dots(quantiles = 100, fill = "#2A8C8B")
```

> [!info] Quantile dot plots have been adopted by the New York Times and other major data journalism outlets for communicating election probability distributions because they are significantly more accurate for general audiences than confidence intervals or probability density curves.

@feynman

Like a progress bar with tick marks instead of a smooth fill — the discrete representation makes 40% and 60% visually distinguishable in a way that a smooth gradient doesn't, because the reader counts ticks rather than estimating fill fraction.

@card
id: edv-ch09-c009
order: 9
title: Jittering and Beeswarm for Overlapping Points
teaser: When categorical data has many observations per category, adding random jitter or using a beeswarm algorithm makes all points visible without changing what they encode.

@explanation

When plotting individual data points along a categorical axis (e.g., satisfaction scores 1–5 for multiple users), points at the same categorical value stack on top of each other. The resulting chart shows N points but only 5 distinct visual positions.

Solutions:

**Jitter:** add a small random offset in the categorical direction to each point. Points at x="Group A" are spread across a narrow horizontal band around "Group A". The randomness means two identical points are still distinct visual elements.

Limitations of jitter:
- The offset is random — different seeds produce different-looking charts.
- Wide jitter implies more variation than exists in the data.
- Points that are identical by design (e.g., all scores are exactly 3) appear as if they have meaningfully different positions.

**Beeswarm:** a deterministic algorithm places each point as close to its true value as possible while avoiding overlap. The result is a symmetrical fan of points that mimics a violin outline with individual points visible. No randomness.

Advantages of beeswarm over jitter:
- Deterministic: same data → same layout. Reproducible for publications.
- Points are as close to their true position as the algorithm allows.
- The overall shape matches the density distribution.

```python
# seaborn: swarm plot (beeswarm)
import seaborn as sns
sns.swarmplot(data=df, x='category', y='score',
              palette='colorblind', size=4)
```

> [!tip] Combine a beeswarm or strip plot with a box plot or violin plot using `zorder` layering — the summary statistic gives context; the individual points give honesty about sample size and distribution.

@feynman

Like consistent hash ring placement vs random load balancing — beeswarm places each point deterministically at the nearest available slot, producing stable, repeatable layouts; jitter is random load balancing that changes on every render.

@card
id: edv-ch09-c010
order: 10
title: 2D Density Estimation for Dense Scatterplots
teaser: When a scatterplot has tens of thousands of points, hexbin aggregation and 2D KDE surfaces replace individual points with a density map that reveals the true data distribution.

@explanation

At large n, individual point rendering fails: 50,000 points at alpha = 0.1 still produce an unreadable dark blob in dense regions. The solution is to estimate and plot the 2D density rather than individual points.

**Hexbin plots:** divide the scatterplot area into a hexagonal grid. Each hexagon is colored by the count (or log count) of points within it. Fast to compute, accurate for count comparison. Hexagons tile more uniformly than squares, reducing artifacts at grid boundaries.

```python
import matplotlib.pyplot as plt
plt.hexbin(x, y, gridsize=40, cmap='YlOrRd', mincnt=1)
plt.colorbar(label='Count')
```

**2D KDE (bivariate density estimation):** smooths the point density into a continuous surface. Shows density contours or a filled heatmap. Slower to compute than hexbin but visually smoother.

```python
import seaborn as sns
sns.kdeplot(data=df, x='x', y='y', fill=True, cmap='viridis', levels=8)
```

**Hybrid approach:** 2D KDE or hexbin for the dense main population, individual labeled points for notable outliers that would be lost in the density map.

When to use each:
- **Hexbin:** when you want to preserve exact count information and the grid structure is acceptable.
- **2D KDE:** when a smooth surface is preferred (typically communication charts, presentations).
- **Alpha transparency + hexbin overlay:** for exploratory analysis where you want both individual point visibility and density context.

> [!info] deck.gl's ScatterplotLayer renders 1M+ points in real-time in a browser via WebGL. For dashboards with large point-based geographic datasets (GPS data, event logs), deck.gl is 1000× faster than matplotlib or Vega-Lite.

@feynman

Like sampling in reservoir computing — instead of keeping every data point (which saturates memory and compute), you maintain a density estimate that captures the distribution's structure while bounding the representation to a fixed size.
