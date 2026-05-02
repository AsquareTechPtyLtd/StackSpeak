@chapter
id: edv-ch02-mapping-data-to-aesthetics
order: 2
title: Mapping Data to Aesthetics
summary: How to translate data variables into visual properties — position, color, size, shape, and transparency — and why the hierarchy of those properties determines what a chart communicates.

@card
id: edv-ch02-c001
order: 1
title: What an Aesthetic Mapping Is
teaser: Every chart is a set of decisions about which data variable controls which visual property — making those decisions explicitly rather than by default is the core skill of visualization design.

@explanation

An **aesthetic mapping** is an assignment: "variable X controls visual property Y." In a scatterplot of engine displacement vs fuel efficiency:
- Displacement → x-position
- Fuel efficiency → y-position
- Car class → color hue
- Cylinder count → point size

Each of those four assignments is a design decision. The chart software will choose defaults for you; those defaults are rarely optimal. Understanding what makes a good aesthetic mapping is what separates charts that communicate from charts that confuse.

The vocabulary:
- **Aesthetic** (or "channel"): a visual property that can vary — position, length, color hue, color saturation, size, shape, angle, transparency.
- **Variable** (or "field"): a column of data — quantitative (numeric), ordinal (ordered categories), or nominal (unordered categories).
- **Mapping**: the assignment of a variable to an aesthetic.
- **Scale**: the transformation that converts data values to visual values (e.g., a linear scale maps 0–100 to 0px–200px; a log scale maps 1–1000 to 0px–200px).

Not all mappings are equally effective. The accuracy with which humans perceive differences in a visual property varies enormously — which means some mappings are far better than others for a given task.

> [!info] In Vega-Lite, every chart is literally a set of explicit encoding declarations: `{"x": {"field": "displacement", "type": "quantitative"}, "color": {"field": "class", "type": "nominal"}}`. The DSL forces the mapping explicit, which is why it's a good learning tool even if you don't use it in production.

@feynman

Like a function signature — you are declaring the relationship between input (data variables) and output (visual properties), and the mapping is the contract the reader uses to decode the chart.

@card
id: edv-ch02-c002
order: 2
title: The Aesthetic Hierarchy
teaser: Position is the most accurate visual encoding; angle and area are the least — this ordering is empirical, not aesthetic, and should drive every mapping decision.

@explanation

Cleveland and McGill's 1984 experiments (replicated and extended many times since) measured how accurately people perceive differences across visual encodings. The hierarchy from most to least accurate:

1. **Position on a common scale** — two bars on the same baseline. Most accurate. Bar charts and scatterplots exploit this.
2. **Position on identical but non-aligned scales** — small multiples with the same axis range per panel but panels not adjacent.
3. **Length** — bar height, line segment length. Very accurate; the basis of bar charts.
4. **Angle and slope** — line chart slope, pie chart angle. Moderately accurate for relative comparison; bad for absolute value.
5. **Area** — circle area, square area. Substantially less accurate. People underestimate area differences by 20–40%.
6. **Volume and 3D position** — 3D charts. Highly inaccurate; humans are poor at judging 3D volume from 2D projections.
7. **Color saturation and density** — sequential gradients. Coarse; works for 4–5 levels, fails for 10+.
8. **Color hue** — categorical distinction. Excellent for "which group" tasks; useless for "how much" tasks.
9. **Shape** — nominal distinction only. Useful for a secondary categorical encoding; impractical as a primary encoding.

Practical rules:
- If the reader needs to compare quantities precisely, map to position or length.
- If the reader needs to see which group a point belongs to, map to color hue.
- Never map a quantitative variable to area as the primary encoding if size differences are small.
- Never use 3D encoding for quantitative comparison.

@feynman

Like CPU registers vs cache vs RAM vs disk — the hierarchy is empirical performance data, not convention, and violating it has measurable consequences for read latency.

@card
id: edv-ch02-c003
order: 3
title: Position as the Primary Encoding
teaser: Most effective charts put the primary quantitative comparison on a positional axis — everything else is secondary, and most charts only need one non-positional channel.

@explanation

Position on a common scale is the most accurate visual encoding because:
- Comparing two bar heights against the same baseline is a simple linear subtraction the visual system performs automatically.
- Aligning points along an axis with tick marks allows values to be read and compared precisely.
- Position works equally well for quantitative, ordinal, and categorical variables.

Consequences for design:
- The most important quantitative comparison should always go on an axis.
- If you have two quantitative variables, put both on axes (a scatterplot), not one on an axis and one on color.
- If you're tempted to use bubble size to encode a third quantitative variable, first check whether a second chart or a faceted small multiple would be clearer.

One non-positional channel is usually enough. Most charts are most effective when they use:
- x-position: one variable
- y-position: one variable
- Optional: color hue for one categorical variable (3–6 groups maximum)

Adding a third non-positional channel (say, both color and shape for different categorical variables) exceeds what most readers can track simultaneously. The cognitive cost of decoding multiple channels simultaneously is additive.

Example: in a scatterplot of R&D spend vs revenue growth with 3 industry sectors, color hue for sectors works well. Adding marker shape for company size and transparency for founding decade has diminishing returns — readers stop tracking the extra encodings.

> [!tip] Before adding a third aesthetic channel, ask: is the reader's question actually "where does this point sit across all three variables simultaneously?" If the questions are separate — location, then group membership — small multiples are usually cleaner than channel stacking.

@feynman

Like a function with too many parameters — the first two are natural to use; parameters 5 and 6 require callers to stop and check the signature, and are usually a sign the function is doing too much.

@card
id: edv-ch02-c004
order: 4
title: Color as an Aesthetic Channel
teaser: Color hue is excellent for categorical distinctions and bad for quantitative comparisons — using it for the wrong task is one of the most common aesthetic mapping errors.

@explanation

Color operates in two distinct modes in data visualization:

**Color hue (distinct colors):** encodes nominal categories. Blue = category A, orange = category B, green = category C. Works well for 3–6 groups. Fails beyond 8–10 groups because humans cannot reliably distinguish many simultaneous hues.

**Color saturation / lightness (sequential gradient):** encodes magnitude. Dark = high value, light = low value. Works for 4–7 distinguishable levels. Fails for continuous quantitative data because the number of distinct perceptible steps in a gradient is limited to roughly 5–7.

The mapping error to avoid: using a gradient (saturation) to encode a nominal variable, or using hue to encode a quantitative variable. Both produce charts that cannot be read correctly.

Correct mappings:
- Revenue category (retail, wholesale, enterprise) → hue. Each category gets a distinct color.
- Temperature value (0°C to 40°C) → sequential saturation. One hue, varying from light to dark.
- Net change (−20 to +20) → diverging palette. Two hues meeting at zero; one for negative, one for positive.

Incorrect mappings:
- Rating (1–5 stars) → five distinct hues. Hue implies "different type," not "more/less." Use a sequential palette.
- Product category (50 categories) → 50 distinct hues. Unreadable. Use faceted small multiples or aggregate categories.

> [!warning] Tableau and Excel both default to giving every series a distinct hue. This is correct when series are nominal categories, but produces misleading charts when the variable is ordinal or quantitative. The default is wrong roughly half the time — always check.

@feynman

Like data type mismatch — using hue to encode an ordinal variable is like storing an integer as a string: technically representable, but the operations (ordering, comparison) produce wrong results.

@card
id: edv-ch02-c005
order: 5
title: Size and Area Encodings
teaser: Size is tempting as a third quantitative channel but produces systematically inaccurate comparisons — use it only when rough-order-of-magnitude differences are sufficient.

@explanation

Size encoding (mapping a quantitative variable to the area of a circle, square, or marker) is less accurate than position or length because:
- People perceive size differences as smaller than they are. A circle with 4× the area looks roughly 2–2.5× bigger.
- Comparing sizes of non-adjacent circles is imprecise even when readers are trying to be careful.
- Overlapping sized marks obscure each other in ways that bars do not.

When size encoding is appropriate:
- **Bubble charts** where the question is "roughly how large is this?" not "precisely how large?" Size works when the answer is "this one is clearly much bigger than that one" rather than "this one is 23% bigger."
- **Proportional symbol maps** where point size on a map encodes a quantity. Exact comparison is not expected; general geographic distribution is the message.

When size encoding is not appropriate:
- As the primary encoding for precise comparisons. Use a bar chart instead.
- When values span only a narrow range (e.g., 90–110). The size differences will be imperceptible.
- When many points overlap. Overlapping circles produce unreadable charts regardless of how they're sized.

Encoding rules for bubble charts:
- Map the quantitative variable to **area**, not radius. If you map to radius, the perceived size grows as the square of the radius — a bubble with 2× the radius looks 4× as big.
- Provide a size legend with representative circles and their values.
- Keep to fewer than ~50 bubbles. Beyond that, the chart is unreadable.

> [!info] In Vega-Lite, size encoding maps to area by default: `{"size": {"field": "population", "type": "quantitative"}}`. D3 requires you to explicitly use `Math.sqrt()` in the radius scale to achieve area encoding: `r = Math.sqrt(value / Math.PI)`.

@feynman

Like floating-point precision — the encoding is technically there but the resolution is much lower than you'd get from the same range on a positional scale, so errors that would be visible as bar height differences are invisible as circle size differences.

@card
id: edv-ch02-c006
order: 6
title: Shape and Transparency
teaser: Shape is useful for a secondary categorical channel when color is already used; transparency is useful for overplotting but harmful when used decoratively.

@explanation

**Shape encoding** (mapping nominal categories to point marker shapes: circle, square, triangle, cross, etc.) is useful when:
- Color is already encoding a different categorical variable and a second categorical distinction is needed.
- The chart will be printed in black and white.
- Colorblind accessibility requires a non-color distinction.

Limitations of shape:
- Works only for nominal categories (unordered groups), not quantitative data.
- Maximum practical limit: 5–6 distinct shapes. Beyond that, readers cannot reliably distinguish shapes under normal reading conditions.
- Shapes must be large enough to be distinguishable. At small sizes, a diamond and a circle are indistinguishable.

**Transparency (alpha) encoding** has two distinct uses:

1. **Overplotting reduction:** setting alpha = 0.3 on a scatterplot with 10,000 points allows overlapping regions to appear darker, revealing density that would be invisible at alpha = 1. This is data-carrying transparency.

2. **Decorative transparency:** gradients, background opacity effects, semi-transparent chart backgrounds. This adds no information and increases visual complexity.

Only the first use of transparency adds information. The second reduces readability without benefit.

Combined example: in a scatterplot of 50,000 GPS pings with alpha = 0.05, the density of movement paths becomes visible as dark regions — information that would be invisible in a fully opaque plot. The transparency is encoding density.

> [!tip] When using transparency for overplotting, test with alpha values between 0.02 and 0.2 depending on data density. For 100–500 points, 0.4–0.6 is typical. For 10,000+ points, 0.05–0.1.

@feynman

Like request sampling rate in distributed tracing — at 100% opacity you see individual events but lose the density pattern; at 1–5% opacity you see the statistical distribution emerge.

@card
id: edv-ch02-c007
order: 7
title: Scales and Transformations
teaser: The scale applied to an axis is an aesthetic choice that changes what comparison the chart is making — linear, log, square root, and percentage scales ask fundamentally different questions.

@explanation

A scale transforms data values to visual positions. The choice of scale determines what comparison the chart performs for the reader:

**Linear scale:** equal visual distances represent equal data differences. "How much more?" is the readable question. Appropriate when absolute differences matter.

**Log scale:** equal visual distances represent equal data ratios. "How many times more?" is the readable question. Appropriate when:
- Values span multiple orders of magnitude (1 to 1,000,000).
- The relevant comparison is proportional growth, not absolute growth.
- Exponential growth looks like a straight line on a log scale, making trend detection easier.

**Square root scale:** a compromise between linear and log. Useful for count data where values span 1–10,000 and extreme outliers would compress the rest of the chart on a linear scale.

**Percentage / normalized scale:** when comparing compositions across groups of different sizes. A stacked bar at 100% height shows proportions; the absolute sizes of the groups are not visible.

The mistake to avoid: using a log scale without labeling it clearly. Readers default to assuming linear scales. A log-scaled bar chart with unlabeled log axis makes bars visually equal that represent 10× differences in data.

```python
# matplotlib: log scale on y-axis
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot(years, values)
ax.set_yscale('log')
ax.set_ylabel('Values (log scale)')  # Label the scale explicitly
```

> [!warning] Never use a log scale starting at zero — log(0) is undefined, and a log scale does not have a meaningful zero point. If your chart requires comparing to zero, use a linear scale.

@feynman

Like database index types — a B-tree index gives O(log n) lookup for range queries; a hash index gives O(1) for equality; neither is universally better, and using the wrong type degrades the operation you care about.

@card
id: edv-ch02-c008
order: 8
title: Redundant Encoding
teaser: Mapping the same variable to two aesthetics simultaneously — position and color, or length and label — reinforces the encoding and improves accessibility at the cost of some visual simplicity.

@explanation

**Redundant encoding** assigns the same data variable to two different aesthetic channels. The most common example: encoding category both by color hue (different colors per bar) and by position on the x-axis (different bars per category). The color adds no new information because position already distinguishes the bars.

When redundant encoding is worth it:

**Accessibility.** If a chart encodes category by color alone, it is inaccessible to colorblind readers. Adding shape or direct text labels as a second encoding makes the chart work without the color channel.

**Print fidelity.** Charts printed in grayscale lose color distinctions. A chart that encodes a key variable in both color and position (or color and pattern) survives printing.

**Key dimension emphasis.** If you want the reader to focus on one variable above all others, encoding it twice reinforces it visually. A bar chart where bars above a threshold are both taller and red is more emphatic than a bar chart where only bar height conveys the threshold crossing.

When redundant encoding is not worth it:

**Noise.** Coloring every bar a different hue when position already distinguishes them adds cognitive load — readers look for meaning in the colors that isn't there.

The test: if removing the redundant channel does not change what question the chart answers or who can answer it, remove it. If removing it loses accessibility or emphasis, keep it.

> [!info] Direct value labels on bars are a form of redundant encoding — position already encodes the value, and the label redundantly encodes it as text. Whether to include them depends on whether the reader needs the exact value or just the comparison.

@feynman

Like adding an index on a foreign key column that already has a unique constraint — the second encoding adds no logical information but improves access performance for a specific use case.

@card
id: edv-ch02-c009
order: 9
title: Aesthetic Mappings in Modern Tooling
teaser: Vega-Lite and Observable Plot encode aesthetics as first-class grammar objects — understanding the mapping vocabulary makes you faster in any tool because the concepts transfer directly.

@explanation

Modern declarative visualization tools implement the aesthetic mapping grammar explicitly. Learning to read and write these declarations is more portable than learning any single tool's UI.

**Vega-Lite** (JSON-based, runs in browsers and notebooks):
```json
{
  "mark": "point",
  "encoding": {
    "x": {"field": "displacement", "type": "quantitative"},
    "y": {"field": "mpg", "type": "quantitative"},
    "color": {"field": "cylinders", "type": "ordinal"},
    "size": {"field": "horsepower", "type": "quantitative"}
  }
}
```

**Observable Plot** (JavaScript, 2026 primary web tool):
```js
Plot.dot(cars, {
  x: "displacement",
  y: "mpg",
  stroke: "cylinders",  // color in Plot's vocabulary
  r: "horsepower"        // radius → size encoding
}).plot()
```

**ggplot2** (R, dominant in statistical/academic work):
```r
ggplot(cars, aes(x = displacement, y = mpg,
                  color = factor(cylinders),
                  size = horsepower)) +
  geom_point()
```

All three tools use the same underlying mapping model. Learning the grammar in one tool accelerates learning in all others. The vocabulary changes (`color` vs `stroke` vs `color`); the concept is identical.

> [!tip] When a chart doesn't look right, the bug is usually in the aesthetic mapping. Print or log the mapping explicitly — which field is mapped to which channel, and what type (quantitative/ordinal/nominal). Type mismatches are the most common source of unexpected chart behavior.

@feynman

Like REST API conventions — GET, POST, PUT, DELETE mean the same thing across frameworks; once you understand HTTP semantics, learning a new HTTP framework takes minutes, not days.

@card
id: edv-ch02-c010
order: 10
title: Coordinate Systems
teaser: Most charts use Cartesian coordinates, but polar, geographic, and specialized coordinate systems unlock chart types that are impossible to express in x-y space.

@explanation

The coordinate system is the space in which aesthetic mappings are drawn. Most charts use Cartesian coordinates (x-y), but the choice of coordinate system is itself a design decision.

**Cartesian (x, y):** the default for most charts. Supports all comparison tasks accurately because position on aligned axes is the most accurate encoding.

**Polar (angle, radius):** maps x-axis to angle and y-axis to radius. This transformation turns:
- Bar charts → pie charts (bars wrapped into a circle).
- Line charts → radar/spider charts.
- Histograms → rose diagrams.

Polar coordinates should be used with caution. Angle is a less accurate encoding than length, so pie charts made from polar bars are less accurate than the original bar charts. Rose diagrams and spider/radar charts are usually worse than standard bar charts for comparison tasks.

**Geographic (longitude, latitude):** maps data to a 2D projection of the Earth's surface. Used for choropleth maps, point maps, and cartograms. The projection choice (Mercator, Albers, Robinson) changes the visual area of regions and distorts the chart in different ways.

**Faceted small multiples:** not a different coordinate system, but a different spatial arrangement — multiple instances of the same Cartesian chart, each showing a subset of the data. One of the most powerful tools in visualization because it avoids stacking multiple channels into one chart.

> [!info] Observable Plot 0.6+ supports faceting with `facet: {data, x: "field"}` natively. ggplot2's `facet_wrap()` and `facet_grid()` are the canonical reference implementations. Vega-Lite supports faceting via the `facet` encoding channel.

@feynman

Like choosing between a relational database and a time-series database — the coordinate system is the fundamental structure you embed your data into, and the wrong choice makes certain operations expensive or impossible.
