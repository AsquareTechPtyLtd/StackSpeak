@chapter
id: edv-ch13-modern-tools-accessibility
order: 13
title: Modern Tools and Accessibility
summary: The 2026 visualization tooling landscape — Observable Plot, Vega-Lite, D3, deck.gl, ggplot2, and notebook-native reactive charts — plus what accessibility actually requires from the charts you build.

@card
id: edv-ch13-c001
order: 1
title: The 2026 Visualization Tooling Landscape
teaser: The web visualization space has consolidated around a grammar-of-graphics layer (Observable Plot, Vega-Lite) for most use cases, with D3 underneath for custom work and deck.gl for large-scale geospatial.

@explanation

The 2026 tooling landscape has clearer tiers than it did five years ago:

**High-level declarative (most work should happen here):**
- **Observable Plot:** the 2026 primary choice for exploratory and communication web charts. Grammar-of-graphics API, composable marks, excellent defaults, TypeScript-native, fast iteration. v0.6+ has direct integration with Observable notebooks and Marimo.
- **Vega-Lite:** JSON-based declarative spec. Best for charts that need to be generated programmatically, shared as configuration, or rendered in non-JavaScript environments (Jupyter, Julia, R via `vegawidget`). Excellent for building BI-style chart configuration systems.

**Programmatic libraries (when you need code-level control):**
- **D3 v7:** the low-level building block. Most visualization work should not use D3 directly in 2026; it's too verbose for standard charts. Use D3 for custom interactive charts that Observable Plot or Vega-Lite cannot express.
- **Plotly:** good for scientific/analytics charts with built-in interactivity. Strong Python and R support. The default for Dash applications.

**Statistical/academic:**
- **ggplot2 (R):** still the dominant tool for statistical visualization in R. The grammar-of-graphics reference implementation. `ggplot2` + `ggdist` + `patchwork` handles 95% of statistical visualization needs.
- **matplotlib/seaborn (Python):** the default for Python data science. `seaborn` provides a higher-level API that is significantly faster than raw `matplotlib` for standard chart types.

**Large-scale and geospatial:**
- **deck.gl:** WebGL-based, handles millions of points in real time in a browser. The standard for interactive large-scale geospatial visualization.
- **Apache ECharts:** strong in enterprise BI contexts, particularly where large-scale chart rendering performance matters or where React integration is required.

> [!info] Observable Plot superseded Vega-Lite as the default for new Observable notebooks in 2023. In 2026, it is the recommended starting point for any web-based chart that isn't generated from a BI tool.

@feynman

Like frontend framework choices — React is the default for most new web work; specialized tools (Three.js, D3) are used when the general-purpose tool can't express the required behavior; and no single tool is right for all use cases.

@card
id: edv-ch13-c002
order: 2
title: Observable Plot — Grammar and Marks
teaser: Observable Plot's core model is composable marks added to a plot — understanding the four most common marks (dot, line, bar, area) covers 80% of use cases.

@explanation

Observable Plot uses a **marks-based composition model**: a chart is a `Plot.plot()` call with an array of marks. Each mark is a visual encoding of data:

```js
import * as Plot from "@observablehq/plot";

// Scatterplot: two marks — dots and a trend line
Plot.plot({
  marks: [
    Plot.dot(data, {x: "gdp", y: "life_expectancy",
                    fill: "region", r: 4}),
    Plot.linearRegressionY(data, {x: "gdp", y: "life_expectancy",
                                   stroke: "gray"})
  ],
  color: {legend: true},
  x: {label: "GDP per capita ($)"},
  y: {label: "Life expectancy (years)"}
})
```

Core marks:
- `Plot.dot()` — scatterplot points.
- `Plot.line()` — line chart (connects ordered points).
- `Plot.barY()` / `Plot.barX()` — bar charts (vertical/horizontal).
- `Plot.areaY()` — area charts.
- `Plot.ruleX()` / `Plot.ruleY()` — reference lines.
- `Plot.text()` — direct labels.

The composition model means complex charts are built by layering marks, not by configuring a complex chart type. A violin plot is `Plot.areaX()` (density) + `Plot.ruleX()` (median). A Gantt chart is `Plot.barX()` with a time scale.

Plot's defaults are good: sensible color palettes, automatic axis ranges, responsive sizing. The starting point is usually close to the desired output without extensive configuration.

> [!tip] Observable Plot's documentation at observablehq.com/plot includes hundreds of interactive examples. For any visualization task, searching the examples gallery is faster than reading the full API.

@feynman

Like composing middleware in an HTTP framework — each mark is middleware that processes the data and produces visual output; the composition order determines the final result.

@card
id: edv-ch13-c003
order: 3
title: Vega-Lite — When JSON Specs Are the Right Choice
teaser: Vega-Lite's JSON specification format is portable, version-controllable, and language-agnostic — making it the right tool when charts are generated programmatically or shared across language boundaries.

@explanation

Vega-Lite charts are pure JSON specifications. The spec describes what data to show and how to encode it; the Vega-Lite runtime handles the rendering. This makes Vega-Lite uniquely portable:

```json
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": {"url": "data/penguins.csv"},
  "mark": "point",
  "encoding": {
    "x": {"field": "bill_length_mm", "type": "quantitative"},
    "y": {"field": "flipper_length_mm", "type": "quantitative"},
    "color": {"field": "species", "type": "nominal"}
  }
}
```

When Vega-Lite is the right choice:
- **Multi-language projects.** The same JSON spec renders in Python (`altair`), R (`vegawidget`), JavaScript, and any environment with a Vega-Lite renderer.
- **Chart specs as configuration.** When charts are stored in a database and rendered by a service, JSON specs are more manageable than code.
- **Jupyter notebooks.** `altair` (Python Vega-Lite wrapper) integrates natively with Jupyter and outputs Vega-Lite specs.
- **Interactive features.** Vega-Lite's `selection` object supports cross-filtering, linked brushing, and interactive filtering without custom JavaScript.

```python
import altair as alt
# Altair = Python wrapper for Vega-Lite
chart = alt.Chart(df).mark_circle().encode(
    x='bill_length_mm',
    y='flipper_length_mm',
    color='species'
)
```

> [!info] Vega-Lite's `selection` + `condition` pattern enables linked views without writing JavaScript — filter one chart by brushing another. This is the most powerful standard interactive visualization pattern available without custom code.

@feynman

Like a Docker Compose file vs a shell script — the declarative spec is portable, version-controllable, and auditable; the script has more power but is harder to share and reason about across environments.

@card
id: edv-ch13-c004
order: 4
title: D3 v7 — When and Why to Use the Low-Level Tool
teaser: D3 handles data-driven DOM manipulation and custom SVG — reach for it when Observable Plot and Vega-Lite can't express the interaction pattern or chart type you need.

@explanation

D3 (Data-Driven Documents) is a JavaScript library for binding data to DOM elements and applying transforms. D3 v7 is the current major version; it removed the global `d3` namespace in favor of ES modules.

D3 is the foundation that Observable Plot and many other visualization libraries are built on. Using D3 directly gives:
- Complete control over every visual element and interaction.
- Access to D3's powerful layout algorithms (force simulation, treemap, pack, chord, hierarchy).
- Custom SVG animations and transitions.
- Complex linked interactions across multiple charts.

When not to use D3 directly:
- Standard chart types (bar, line, scatter, area). Observable Plot or Vega-Lite are 5–10× faster to implement and maintain.
- When the team doesn't have JavaScript expertise. D3's API is powerful but has a steep learning curve.
- When the chart will be maintained by data scientists who work primarily in Python/R.

When D3 is appropriate:
- Custom interactive network graphs (force-directed layout).
- Animated data transitions where specific timing and easing control is required.
- Chord diagrams, sunburst charts, and other radial layouts.
- Entirely custom chart types that don't fit the standard grammar.

```js
// D3 v7: ES module import
import { select, scaleLinear, axisBottom } from "d3";
// Not: import * as d3 from "d3" (the old pattern)
```

> [!tip] In 2026, Observable Plot can handle ~85% of what people reached for D3 for in 2019. Before writing D3, check whether Plot has a mark or transform that covers the use case. Start with Plot; escalate to D3 only when Plot is genuinely insufficient.

@feynman

Like reaching for assembly language in a systems project — sometimes you need the control, but most of the time the higher-level language produces the same result faster and with less maintenance burden.

@card
id: edv-ch13-c005
order: 5
title: Notebook-Native Reactive Visualization
teaser: Marimo and Observable notebooks support reactive charts that update automatically when upstream data or parameters change — this changes how exploratory visualization works in 2026.

@explanation

Traditional notebooks (Jupyter) execute cells manually. Changing a parameter in one cell requires re-running downstream cells manually. This makes exploratory chart iteration slow.

**Reactive notebooks** (Marimo, Observable) re-execute cells automatically when their dependencies change. A slider controlling a smoothing parameter automatically re-renders the chart. A date range picker updates all downstream charts instantly.

**Marimo (Python):** a 2026-native reactive notebook that replaces Jupyter for interactive Python visualization work. Any cell that references a variable is automatically re-executed when that variable changes. Charts update in real time as sliders, dropdowns, or text inputs are changed.

```python
# Marimo: reactive chart
import marimo as mo
import matplotlib.pyplot as plt

slider = mo.ui.slider(1, 30, value=7, label="Rolling window (days)")
# This cell re-runs automatically when slider changes:
fig, ax = plt.subplots()
df['value'].rolling(slider.value).mean().plot(ax=ax)
mo.mpl.interactive(fig)
```

**Observable notebooks:** JavaScript-native reactive notebooks from the Observable team. The original reactive notebook environment; Observable Plot is designed to work natively in Observable notebooks.

Reactive notebooks do not replace production dashboards (Grafana, Looker, Metabase). They replace the exploratory analysis workflow: iterating on chart parameters, trying different smoothing bandwidths, comparing chart types — workflows that were slow and friction-filled in Jupyter.

> [!info] Marimo's reactive model also means notebooks can be deployed as self-service web apps without a separate dashboard layer. A Marimo notebook with a date range picker and a chart is a functional mini-dashboard with no additional code.

@feynman

Like hot module reloading in a frontend development server — instead of restarting the entire process, only the affected cells re-execute when a dependency changes, reducing iteration time from seconds to milliseconds.

@card
id: edv-ch13-c006
order: 6
title: ggplot2 and the R Visualization Ecosystem
teaser: ggplot2 remains the dominant tool for statistical and academic visualization in R — the extension ecosystem (ggdist, gganimate, patchwork, ggtext) covers use cases the core package does not.

@explanation

**ggplot2** implements the grammar of graphics natively in R. In 2026, it is the reference implementation for grammar-of-graphics design: layers of geometric objects (geoms), scales, facets, and coordinate systems compose cleanly.

Core ggplot2 workflow:
```r
library(ggplot2)
ggplot(df, aes(x = gdp, y = life_expectancy, color = region)) +
  geom_point(alpha = 0.7, size = 3) +
  geom_smooth(method = "lm", se = TRUE) +
  scale_color_brewer(palette = "Set2") +
  facet_wrap(~continent) +
  theme_minimal() +
  labs(title = "GDP and life expectancy", x = "GDP per capita ($)", y = "Life expectancy (yrs)")
```

Key extension packages:
- **ggdist:** uncertainty visualization, quantile dot plots, rainclouds, halfeyeplots. The best tool for distribution visualization in R.
- **gganimate:** animates ggplot2 charts over time with a `transition_*()` layer.
- **patchwork:** combines multiple ggplots into publication-ready multi-panel layouts with a `+` operator.
- **ggtext:** enables markdown and HTML formatting in ggplot2 text elements (titles, labels, annotations).

When to use R/ggplot2 over Python:
- Statistical modeling output (regression coefficients, mixed models, survival curves). R's statistical modeling ecosystem is deeper.
- Academic publication figures. ggplot2's output quality is standard in journals.
- When the analysis is already in R and the visualization is part of the same document (Quarto / R Markdown).

> [!tip] `ggplot2`'s extension system is one of the most mature in data visualization. Before writing custom visualization code, check `exts.ggplot2.tidyverse.org` for an extension that handles the chart type.

@feynman

Like a framework with a plugin architecture — the core handles 80% of use cases, the ecosystem covers the rest, and the composable grammar means extensions integrate cleanly without fighting the core abstractions.

@card
id: edv-ch13-c007
order: 7
title: Accessibility Requirements for Charts
teaser: An accessible chart provides equivalent information to screen reader users, passes color contrast requirements, and doesn't rely solely on color to encode data — these are requirements, not optional enhancements.

@explanation

Accessibility in data visualization has legal (WCAG 2.1/2.2 compliance) and ethical dimensions. The technical requirements:

**1. Alternative text for static images.**
Every chart rendered as a PNG, SVG, or embedded image needs an `alt` attribute describing the data and conclusion. "Chart showing revenue" is not sufficient. "Bar chart showing Q4 revenue of $4.2M, the highest quarterly revenue since Q1 2024" is sufficient.

**2. Accessible data tables as supplements.**
For any chart showing quantitative data, the underlying data should be available as an accessible HTML table for screen reader users. In HTML contexts, use `<table>` with correct `<caption>`, `<th scope>`, and `<td>` markup.

**3. Colorblind-safe palettes.**
Use palettes that are distinguishable under deuteranopia and protanopia. The Okabe-Ito palette, ColorBrewer colorblind-safe palettes, and viridis family all qualify.

**4. Non-color encoding redundancy.**
Categories should not be encoded by color alone. Add shape or direct text labels so colorblind users can distinguish groups.

**5. Minimum contrast ratios.**
Labels, axis text, and annotations must meet WCAG 4.5:1 contrast ratio against their background. Use `#767676` or darker for text on white backgrounds.

**6. No reliance on motion.**
Animated charts must have a non-animated alternative or pause/stop controls. Users with vestibular disorders can be harmed by motion.

```html
<!-- SVG chart with accessibility markup -->
<svg role="img" aria-labelledby="chart-title chart-desc">
  <title id="chart-title">Q4 2025 Revenue by Region</title>
  <desc id="chart-desc">Bar chart showing Q4 revenue. North America leads at $4.2M, followed by Europe at $2.8M and APAC at $1.6M.</desc>
  <!-- chart content -->
</svg>
```

> [!warning] In 2026, WCAG 2.2 is the current standard and WCAG 3.0 is in development. Many organizations have legal requirements for WCAG 2.1 AA compliance. Data visualization tools that ship charts in web contexts must meet these requirements.

@feynman

Like writing API documentation — the chart is the implementation; the alt text is the documentation; users who cannot see the chart (screen readers, broken image loads) rely on the documentation to get the same information.

@card
id: edv-ch13-c008
order: 8
title: AI-Assisted Chart Review
teaser: In 2026, LLMs can review charts for clarity, accessibility, and misleading design with useful accuracy — not as a replacement for judgment but as a fast first-pass audit.

@explanation

Large language models with vision capabilities (GPT-4o, Claude 3.5 Sonnet, Gemini 1.5 Pro) can analyze chart images and identify common issues. In 2026, this is a practical workflow tool:

**What AI chart review reliably catches:**
- Missing axis labels and units.
- Descriptive vs interpretive titles.
- Obvious truncated y-axes.
- Colorblind accessibility issues (when the palette is visible in the image).
- Missing or ambiguous legends.
- Cluttered annotations.

**What AI chart review misses or gets wrong:**
- Whether the underlying data supports the conclusion (requires data access).
- Subtle scale manipulations.
- Whether the date range was cherry-picked.
- Context-dependent issues (whether a non-zero y-axis is appropriate depends on the data type).

A practical workflow:
1. Export the chart as a PNG.
2. Submit to an LLM with the prompt: "Review this chart for clarity, accessibility, and potential misleading elements. Identify any missing labels, contrast issues, or design choices that could mislead readers."
3. Use the output as a checklist starting point, not as a final verdict.

The value is speed, not authority. Running an AI review takes 30 seconds; it catches the mechanical issues faster than a manual checklist review. But it cannot replace domain knowledge about what the data should show.

> [!info] Observable's 2026 AI integration features allow submitting charts to an LLM for review directly from the notebook interface. The AI can also suggest Observable Plot code to fix identified issues — a useful accelerant for the iteration cycle.

@feynman

Like a linter for code — it catches the obvious syntactic and style issues faster than manual review, but it cannot reason about whether the algorithm is correct, only whether the code is well-formed.

@card
id: edv-ch13-c009
order: 9
title: Mobile-First Chart Considerations
teaser: A chart that works at 1200px wide may be unreadable at 375px — mobile-first visualization requires explicit design decisions about label strategy, chart type, and interaction patterns.

@explanation

In 2026, over 60% of dashboard views globally come from mobile devices. A chart designed for desktop rendering is often unusable on mobile without explicit mobile-first design choices.

The problems that appear on mobile:
- **Axis labels overlap or are too small to read** at 375px width.
- **Legends require scrolling** to see while also viewing the chart.
- **Small data points are too small to tap** for hover/tooltip interactions.
- **Rotated x-axis labels** (already a bad practice) are unreadable at mobile sizes.
- **Dense small multiples** require zooming, destroying the comparative purpose.

Mobile-first solutions:

**Chart type selection:** horizontal bar charts (labels on the left) work better on narrow screens than vertical bars (labels on the x-axis). Line charts with 2–3 series work; 10-series line charts do not.

**Responsive sizing:** in Observable Plot, set `width: Infinity` and it adapts to the container. In D3 and Vega-Lite, listen to `window.resize` and re-render.

**Touch targets:** for interactive charts, ensure clickable/tappable elements are at least 44×44px (Apple HIG) or 48×48px (Material Design). Tiny dots in a scatterplot are untappable.

**Label strategy:** for mobile, fewer axis labels and direct data labels within the chart instead of legends. A 6-item legend in a box requires 150px that don't exist on mobile.

```js
// Observable Plot: responsive width
Plot.plot({
  width: Math.min(640, window.innerWidth - 32),
  marginLeft: 40,
  marks: [Plot.barY(data, {x: "category", y: "value"})]
})
```

> [!tip] Test every chart at 375px, 768px, and 1280px widths before shipping. The 375px test is the most revealing — it catches every label and space assumption that breaks at mobile scale.

@feynman

Like responsive UI design in iOS — Auto Layout handles the geometry, but you still need to make explicit decisions about what gets hidden, condensed, or reformatted at each size class, because the layout system can't make those product decisions for you.

@card
id: edv-ch13-c010
order: 10
title: Choosing the Right Tool for the Job
teaser: The correct tool depends on where the chart lives, who builds it, how often it changes, and what interactions it needs — no single tool is optimal for all contexts.

@explanation

Tool selection is a decision based on context, not on which tool produces the best output in the abstract.

**Static charts for reports and documents:**
- R/ggplot2 → PDF via Quarto or R Markdown. Best-in-class static output quality.
- Python/matplotlib or seaborn → PNG for embedding in reports, Jupyter outputs.
- Plotly → static export with `write_image()` for non-interactive deliverables.

**Interactive charts embedded in web pages:**
- Observable Plot → first choice for new JavaScript projects.
- Vega-Lite / Altair → for projects that need language portability or JSON-spec sharing.
- D3 → for custom interactive charts that Plot/Vega-Lite can't express.

**BI dashboards for business users:**
- Tableau, Looker, Metabase, Grafana → drag-and-drop, self-service, SQL-connected.
- Apache ECharts → when a custom BI UI is being built in React.

**Data science exploration:**
- Python: matplotlib/seaborn + Marimo for reactive exploration.
- R: ggplot2 + plotly for occasional interactivity.

**Large-scale geospatial:**
- deck.gl → WebGL-powered, millions of points.
- Folium / Leaflet → simpler web maps for smaller datasets.

**When AI tools generate the chart:**
- Review the output against the quality checklists in chapters 11 and 12.
- AI-generated charts often produce correct chart types but miss interpretive titles, direct labeling, and clutter removal.

> [!tip] The best visualization tool is the one your team will actually use, maintain, and iterate on. A perfect ggplot2 chart that no one can modify is worse than a good-enough Tableau chart that the team can update in 10 minutes.

@feynman

Like programming language selection for a team project — the theoretically optimal language is irrelevant if the team has no expertise in it; the constraint is the team's capability to build, maintain, and debug whatever is chosen.
