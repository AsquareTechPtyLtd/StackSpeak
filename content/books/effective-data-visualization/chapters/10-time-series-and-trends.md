@chapter
id: edv-ch10-time-series-and-trends
order: 10
title: Time Series and Trends
summary: Line charts, smoothing, seasonality, and common mistakes in trend visualization — how to show what's happening over time without creating false impressions of momentum or change.

@card
id: edv-ch10-c001
order: 1
title: The Line Chart Is the Default for Time Series
teaser: Time series data implies continuity between observations — the line chart encodes this assumption explicitly, and every design decision should either confirm or qualify that continuity.

@explanation

A time series is a sequence of values indexed by time. The canonical visualization is a line chart: time on the x-axis, the measured variable on the y-axis, with consecutive observations connected by a line.

The line between observations is an assertion: the value existed and changed continuously between those points. For daily sales data, the line between Monday and Tuesday asserts that sales changed smoothly through the week, which is approximately correct. For quarterly earnings data, the line between Q3 and Q4 asserts a smooth transition that may be misleading — earnings could have changed abruptly.

Design decisions that match the data:
- **Regular, frequent observations (hourly, daily):** a line is appropriate. The interpolation is physically plausible.
- **Irregular or sparse observations (monthly or less):** consider showing dots for each observation AND a line, making the measurement points visible.
- **Categorical time periods (fiscal quarters, named product releases):** use bars, not a line. Connecting named categories with a line implies they exist on a continuous scale.

Line chart requirements:
- Time axis runs left to right.
- The most recent time period is at the right.
- The y-axis should start at zero or have a clearly justified non-zero starting point (see: dot plot alternative).
- Gaps in data should be shown as actual gaps in the line, not interpolated.

```python
import matplotlib.pyplot as plt
# Show data gaps explicitly
ax.plot(dates, values)  # matplotlib interpolates over NaN by default
# To show gaps: split the series at NaN values
```

> [!tip] Use `plot_date` or explicitly handle NaN values so that missing periods appear as breaks in the line, not interpolated bridges. A bridge over missing data implies the data exists when it doesn't.

@feynman

Like HTTP keep-alive connections — the line implies the connection between two points is maintained and the state is known; a break in the line signals that the connection was lost and the intermediate state is unknown.

@card
id: edv-ch10-c002
order: 2
title: Aspect Ratio and Slope Perception
teaser: The visual slope of a line chart depends on the aspect ratio of the chart — the same data can look like explosive growth or near-flat stability depending on the width-to-height ratio chosen.

@explanation

The visual impression of growth rate, volatility, and trend depends on the aspect ratio (width / height) of the chart canvas. The same data:

- In a wide, short chart (aspect ratio 4:1): the line looks nearly flat. Small changes are invisible.
- In a narrow, tall chart (aspect ratio 1:2): the line looks dramatically volatile. Small changes look large.
- At aspect ratio 1:1 with 45° average slope: the Cleveland banking principle — this is the "neutral" aspect ratio that doesn't visually exaggerate or suppress the trend.

The **banking to 45°** principle: set the aspect ratio so the average absolute slope is approximately 45°. This minimizes the distortion of visual slope perception relative to actual rate of change.

In practice:
- Charts embedded in reports are typically wider than they are tall. This suppresses apparent volatility.
- Charts sized to fit a square area (e.g., dashboard tiles) may exaggerate volatility.
- The "correct" aspect ratio depends on what comparison matters. If week-over-week change is the message, a taller chart helps. If the long-term trajectory is the message, a wider chart is appropriate.

Tool support: ggplot2 provides `coord_fixed(ratio)` to control aspect ratio. Matplotlib uses `ax.set_aspect()`. Vega-Lite uses the `width` and `height` encoding properties.

> [!warning] Dashboards that automatically resize chart tiles based on screen width can dramatically change the apparent trend magnitude between mobile and desktop views. Always test line charts at the range of widths they'll be displayed.

@feynman

Like zooming in on an audio waveform — the same signal looks like random noise at 1ms resolution and a clear melody at 100ms resolution; the zoom level changes what patterns are visible even though the underlying data is identical.

@card
id: edv-ch10-c003
order: 3
title: Multiple Time Series on One Chart
teaser: Comparing multiple time series on one chart requires consistent scales and thoughtful color choices — when series overlap heavily or have different scales, small multiples are usually better.

@explanation

Placing multiple time series on one chart enables direct comparison. It also creates problems when the series differ in scale, overlap significantly, or have more than 5–6 lines that all need to be distinguished.

When one-chart multiple-series works:
- 2–5 series with similar scales.
- The comparison across series at specific time points is the message.
- The series are well-separated (don't overlap much).
- Each series gets a distinct color with a direct label (no legend hunting).

When to use small multiples instead:
- More than 6 series. Distinguishing 10 colored lines in a dense tangle requires more effort than reading 10 separate panels.
- Series have very different scales (e.g., revenue in millions and conversion rate in percent). Use separate charts with appropriate y-axes, not a single dual-axis chart.
- The within-series pattern matters as much as the cross-series comparison.

Direct labeling beats legends: for time series charts, place the series label at the right end of each line, not in a legend box. The reader's eye is already at the right end of the chart (the present); having to travel to a legend and back for each series doubles the reading effort.

```python
# Direct labels instead of legend
for col in df.columns:
    ax.plot(df.index, df[col], label=col)
    ax.annotate(col, xy=(df.index[-1], df[col].iloc[-1]),
                xytext=(5, 0), textcoords='offset points', va='center')
ax.legend().remove()
```

@feynman

Like a diff between two branches — the comparison is only useful if you're looking at the same lines; if the files have diverged structurally, you need to diff the files separately before comparing their histories.

@card
id: edv-ch10-c004
order: 4
title: Smoothing Without Misleading
teaser: A smoothed trend line reduces noise to show the underlying pattern — but over-smoothing hides real changes, and the smoothing method must be disclosed or the line is presenting fiction as fact.

@explanation

Raw time series data contains noise: random measurement error, day-of-week effects, one-time events. A trend line or smoothing curve extracts the underlying pattern by averaging away the noise.

**Moving average:** the simplest smoother. Each value is replaced by the average of the N surrounding periods. Easy to understand; the window size (N) must be stated. A 7-day moving average for daily data removes weekly seasonality.

```python
df['7d_rolling_avg'] = df['value'].rolling(window=7, center=True).mean()
```

**LOESS (Locally Weighted Scatterplot Smoothing):** a nonparametric smoother that fits a polynomial regression at each point using nearby observations. More flexible than moving average; the bandwidth parameter controls smoothness. Available via `scipy.stats.loess` or `statsmodels`.

**Exponential Smoothing:** weights recent observations more heavily. Produces a smooth line that tracks recent changes more quickly than a symmetric moving average. Used in forecasting (Holt-Winters).

Over-smoothing failures:
- A heavily smoothed line that lags real change implies the change happened later than it did.
- Over-smoothing a volatile series can make a temporary dip look like a long-term trend.

Always disclose:
- What smoothing method was applied.
- The window size or bandwidth.
- Whether the raw data is also shown.

> [!tip] Show the raw data as faint dots or a light thin line and the smooth as a bold line. The reader sees both the signal and the noise. This is standard in scientific visualization and increasingly expected in data journalism.

@feynman

Like a low-pass filter in signal processing — filtering removes high-frequency noise but also degrades the signal if the cutoff frequency is too low; the raw signal and the filtered output are different claims about the same underlying process.

@card
id: edv-ch10-c005
order: 5
title: Seasonal Decomposition
teaser: Seasonal patterns in time series (weekly cycles, annual cycles) can hide real trends or exaggerate apparent trends — decomposing the series into trend + seasonal + residual is the honest way to present each component.

@explanation

Many time series contain multiple overlapping patterns:
- **Trend:** the long-term direction (growing, declining, stable).
- **Seasonality:** regular periodic patterns (higher on weekdays, peaks in December, dips in January).
- **Residual:** what's left after removing trend and seasonality — true noise plus unexpected events.

Plotting the raw series without decomposition can mislead:
- A rising annual seasonality peak can look like sustained growth when the underlying trend is flat.
- A strong weekly cycle can obscure a real positive trend if the viewer focuses on the weekly dip.
- Decomposing and presenting each component separately is more informative than presenting the raw series alone.

```python
from statsmodels.tsa.seasonal import seasonal_decompose
result = seasonal_decompose(df['value'], model='additive', period=7)
fig = result.plot()  # 4-panel chart: observed, trend, seasonal, residual
```

Choosing model type:
- **Additive:** seasonal fluctuations have constant amplitude. Appropriate when the seasonal swings are similar in size regardless of the trend level.
- **Multiplicative:** seasonal fluctuations scale with the trend level. Appropriate when percentage variation (not absolute variation) is constant.

> [!info] For exploratory dashboards, the raw series is appropriate. For reports claiming "we see X% growth," the decomposed trend component is the honest number to report. "Q4 growth" that includes holiday seasonality is not comparable to Q2 growth.

@feynman

Like profiling with wall time vs CPU time vs I/O wait — the raw metric conflates multiple sources of variance; decomposition separates them so you can optimize the right component.

@card
id: edv-ch10-c006
order: 6
title: Year-over-Year and Period Comparisons
teaser: Comparing the same period across different years removes seasonality from the comparison — but the baseline year choice and the exact period definition both change the apparent trend.

@explanation

**Year-over-year (YoY) comparison** compares the same period (e.g., Q4 2025 vs Q4 2024) to remove seasonal effects. A business growing 20% YoY is growing even accounting for the fact that Q4 is naturally bigger than Q1.

The design choices that change the conclusion:

**Baseline year:** "revenue is 40% higher than 2 years ago" uses a different reference than "revenue is 20% higher than last year" — even if the actual trend is linear. A bad baseline year (one that was unusually low or high) makes the comparison misleading.

**Period definition:** "full year 2025 vs full year 2024" vs "trailing 12 months ending March 2025 vs trailing 12 months ending March 2024." These measure the same thing conceptually; in practice they produce different numbers when there is recent acceleration or deceleration.

**Normalization:** raw YoY revenue growth includes the effect of price changes (inflation). Revenue growth adjusted for price changes is a different and often more honest metric.

When to show YoY explicitly:
- Business metrics where seasonality is strong (retail, travel, media).
- Any comparison that crosses a seasonal boundary (comparing Q1 to Q4 without YoY framing is misleading).

When YoY is insufficient:
- When the question is about recent acceleration/deceleration. The YoY rate smooths out recent changes.
- When the year had unusual events (a pandemic, a product launch, a major outage).

> [!warning] "Growth vs last year" and "growth vs the same period last year" are different metrics. Be specific. A YoY chart without explicit specification of what "year ago" means is ambiguous.

@feynman

Like diff between commits vs diff from merge-base — "changed vs last commit" is a different question from "changed since we branched from main," and confusing them produces wrong code reviews.

@card
id: edv-ch10-c007
order: 7
title: Forecasts and Prediction Intervals
teaser: When showing a forecast extending beyond the observed data, the prediction interval must be shown — a point forecast without uncertainty is presenting one scenario as the expected future.

@explanation

A **forecast chart** shows the historical time series followed by projected future values. Without uncertainty bands, a forecast looks like a plan or a commitment rather than a probabilistic prediction.

The standard forecast visualization:
- Historical data as a solid line.
- Forecast as a dashed or differently styled line (visually distinct from observed).
- **Prediction interval** as a shaded band around the forecast. The most common choice is 80% and 95% prediction intervals as two shaded regions (narrower inner band = 80%, wider outer band = 95%).

Why the distinction between confidence intervals and prediction intervals matters:
- A 95% **confidence interval** for the mean says: the mean response is expected to be in this range.
- A 95% **prediction interval** for a new observation says: a new single observation is expected to be in this range.
- Prediction intervals are always wider than confidence intervals because they include individual observation variability.

For forecast charts, prediction intervals are the correct choice — the reader wants to know where the actual future value might land, not just where the mean forecast is.

```python
# statsmodels: forecast with prediction interval
result = model.fit()
forecast = result.get_forecast(steps=12)
ci = forecast.conf_int(alpha=0.05)  # 95% prediction interval
ax.plot(forecast.predicted_mean, color='red', linestyle='--')
ax.fill_between(ci.index, ci['lower'], ci['upper'], alpha=0.2, color='red')
```

> [!info] In 2026, Marimo and Observable notebooks support reactive forecast charts where dragging a slider changes the horizon length and the prediction intervals update in real time. This makes forecast uncertainty intuitive in a way static charts cannot.

@feynman

Like a type inference algorithm's output — the most-likely type is the point forecast; the set of all valid types at that point is the prediction interval; presenting only the most-likely type without the uncertainty is sound for optimization but incorrect for specification.

@card
id: edv-ch10-c008
order: 8
title: Anomaly Visualization in Time Series
teaser: Flagging anomalous observations in a time series requires defining "anomalous" relative to expected baseline — the visualization must make both the baseline and the deviation visible.

@explanation

Anomaly detection in time series identifies observations that deviate significantly from expected behavior. Visualizing anomalies requires showing:
1. The actual observed values.
2. The expected baseline (trend + seasonality).
3. Which observations are flagged and why.

Common visualization approaches:

**Residual plot:** plot the difference between observed and expected values. Anomalies appear as large positive or negative residuals. The expected value is defined by a model (ARIMA, Prophet, LOESS); deviations beyond ±2 or ±3 standard deviations of the residuals are flagged.

**Threshold bands:** show upper and lower bounds on the time series. Observations outside the bounds are flagged. The bounds can be static (fixed thresholds from SLOs) or dynamic (based on the moving mean ± k standard deviations).

**Highlighted points:** mark flagged observations with a different marker (color, size, shape) on the raw time series. The flag itself doesn't explain why it was flagged; the visualization is the starting point for investigation.

```python
# matplotlib: time series with anomaly highlights
ax.plot(dates, values, color='#444444', linewidth=1)
anomalies = df[df['is_anomaly']]
ax.scatter(anomalies['date'], anomalies['value'],
           color='#C84A50', s=60, zorder=5, label='Anomaly')
ax.fill_between(dates, lower_bound, upper_bound,
                alpha=0.15, color='#2A8C8B', label='Expected range')
```

> [!tip] A good anomaly visualization shows both false positives and false negatives: annotate a few cases where the algorithm flagged something that wasn't anomalous, and a few cases where an anomaly was missed. This calibrates the reader's trust in the detection.

@feynman

Like a log analysis dashboard with highlighted ERROR lines — the raw log stream is the baseline; the red highlights are the anomaly flags; and the tool is only as useful as the threshold definition that determines what gets flagged.

@card
id: edv-ch10-c009
order: 9
title: Dual-Axis Time Series Charts
teaser: Two y-axes on one chart allow different-scale series to be compared — but the visual comparison is always misleading because the relationship between the two axes is arbitrary and can be set to show any desired correlation.

@explanation

A **dual-axis (dual-y) chart** uses two y-axes — one on the left, one on the right — to plot two series with different scales on the same chart. It is commonly used to compare a primary metric (e.g., revenue) with a rate or percentage (e.g., churn rate) over the same time period.

Why dual-axis charts mislead:
- **The visual relationship between the lines is determined by the y-axis scaling.** If I want the revenue line and the churn line to cross in October, I scale the axes so they cross. If I want them to look parallel, I scale them differently. The apparent correlation is an artifact of a choice made by the chart designer.
- **The reader assumes the visual alignment is meaningful.** When two lines appear to overlap or cross, readers infer a relationship. That relationship may not exist in the data.
- **No common baseline.** You cannot visually compare the magnitude of the two series.

Better alternatives:
- **Two separate charts with shared time axis.** One below the other, same time x-axis. The reader can compare timing without a misleading visual overlap.
- **Index normalization.** Index both series to 100 at the start period. Both series are on the same scale (percent change from baseline) and can be compared directly.

> [!warning] Dual-axis charts are commonly used to imply a causal relationship between two correlated metrics. The visual alignment is not evidence of a relationship. Use separate panels and state the correlation separately if it exists.

@feynman

Like z-score normalizing two different metrics to compare them — normalizing makes the comparison fair; putting them on different arbitrary scales (dual axes) makes the comparison look meaningful when the relationship is scale-dependent.

@card
id: edv-ch10-c010
order: 10
title: Horizon Charts for Dense Time Series
teaser: A horizon chart collapses a line chart into a fraction of its vertical space by layering color-coded bands, making it possible to compare 10–20 time series at a glance without sacrificing pattern visibility.

@explanation

A **horizon chart** is a space-efficient encoding of a time series that compresses a line chart vertically while preserving the ability to detect relative changes.

How it is constructed:
- Divide the y-axis range into equal-sized bands (typically 3–4 bands above and below the midpoint).
- Values above the midpoint are encoded in increasingly saturated positive-direction color (e.g., progressively darker blue); values below use an opposing negative-direction color (e.g., progressively darker red).
- All bands are folded back down to the same baseline. The result is a filled rectangle showing color intensity: dark positive color means a high value, dark negative color means a low value.
- The chart height for one series is the height of a single band — roughly one-quarter to one-third the height of the original line chart.

What horizon charts enable:
- 10–20 time series in the vertical space a single line chart would occupy.
- Spotting which series are highest or lowest at any given time by scanning color intensity across rows.
- Cross-series alignment at a glance when the time axis is shared.

Optimal use cases:
- Monitoring dashboards with many metrics (server latency per endpoint, user engagement per cohort, revenue per region).
- Any context where the relative pattern (higher/lower than baseline, recent spike or dip) is more important than the exact numeric value.

Tradeoffs:
- Requires a legend explaining the band-to-value mapping. Readers unfamiliar with the format will misread color intensity as magnitude.
- Not suitable for reports or presentations to non-technical audiences — reserve for analyst-facing or engineering dashboards.
- Exact values are not recoverable from color alone; pair with hover tooltips in interactive tools.

Tool support:
- Vega-Lite has native horizon chart support via the `fold` transform and `rect` mark.
- A D3 horizon chart plugin (`d3-horizon-chart`) provides a reusable component.
- Observable Plot supports horizon charts via the `rectY` mark with custom color scales.

> [!tip] Start with 3 bands (not 4 or 5) when introducing horizon charts to a new audience. Fewer bands mean a simpler legend, less color mixing, and a gentler learning curve — at the cost of some compression ratio.

@feynman

Like log-scale compression in audio mastering — the technique preserves the shape of the signal while fitting a wider dynamic range into a smaller physical space; the compression is lossless for pattern detection but lossy for exact amplitude recovery.
