@chapter
id: edv-ch03-color-in-data-visualization
order: 3
title: Color in Data Visualization
summary: How to choose palettes that encode the right information, respect colorblind constraints, and use color to emphasize rather than decorate.

@card
id: edv-ch03-c001
order: 1
title: Three Types of Color Palettes
teaser: Sequential, diverging, and qualitative palettes each match a different data type — using the wrong type encodes a false relationship into the chart.

@explanation

Color palettes in data visualization are not decorative — each type encodes a specific relationship between values:

**Sequential palettes:** light-to-dark (or low-saturation to high-saturation) progression encoding ordered magnitude. Use when all values are on one side of zero and ordered comparison is the task. Examples: population density (0 to max), temperature (minimum to maximum), sales volume.

**Diverging palettes:** two hues meeting at a meaningful midpoint (usually zero or a reference value), each darkening away from the center. Use when values span positive and negative, or when the deviation from a reference matters. Examples: profit/loss (red for negative, blue for positive), opinion polls (disagree → neutral → agree), correlation coefficients (−1 to +1).

**Qualitative (categorical) palettes:** distinct hues for unordered categories. No implied ordering or magnitude. Use for nominal data: company names, product categories, countries, species. The maximum practical size is 8–10 categories; beyond that, readers cannot reliably distinguish the hues.

The mismatch errors:
- Using a qualitative palette for ordered data (star ratings 1–5 as five distinct hues) implies the categories are equal and unordered when they are not.
- Using a sequential palette for nominal data implies a hierarchy between categories that doesn't exist.
- Using a single-hue sequential palette for diverging data makes negative and positive values indistinguishable.

> [!warning] Excel's default "color by series" palette is a qualitative palette. If you apply it to an ordinal or quantitative variable (e.g., years 2020–2025 as six distinct colors), you are asserting the years are unordered nominal categories. The chart is visually incorrect.

@feynman

Like choosing the correct data type — using a qualitative palette for ordered data is like storing a month as a VARCHAR; the values render correctly but comparisons and orderings are wrong.

@card
id: edv-ch03-c002
order: 2
title: Colorblind-Safe Palette Choices
teaser: Roughly 8% of men and 0.5% of women have some form of color vision deficiency — a chart that only works in full color is inaccessible to a material fraction of any audience.

@explanation

Red-green color blindness (deuteranopia and protanopia) affects roughly 8% of men in Northern European descent populations. These readers cannot reliably distinguish:
- Red from green.
- Orange from yellow-green.
- Brown from olive green.

A chart that uses red/green for "above/below target," "pass/fail," or "positive/negative" is unreadable for this audience. This includes roughly 1 in 12 male readers — in a company with 60 engineers, 5 of them likely cannot read the chart.

Colorblind-safe palette choices:

**For diverging data:** blue/orange instead of red/green. Both hues are distinguishable to deuteranopes and protanopes.

**ColorBrewer palettes** (colorbrewer2.org): designed specifically for data visualization with colorblind-safe options clearly marked. Available in matplotlib, ggplot2, D3, and Observable Plot by name.

**Okabe-Ito palette**: the standard colorblind-safe qualitative palette in academic visualization. 8 colors, distinguishable under all common color vision deficiency types:
- `#000000` (black), `#E69F00` (orange), `#56B4E9` (sky blue), `#009E73` (green), `#F0E442` (yellow), `#0072B2` (blue), `#D55E00` (vermilion), `#CC79A7` (pink)

**Testing tools:** the `colorblindly` Chrome extension and `dichromacy` R package simulate how any chart looks under various color vision deficiencies. Run all charts through these before publishing.

```python
# matplotlib: use a colorblind-safe colormap
import matplotlib.pyplot as plt
plt.colormaps['viridis']   # sequential, colorblind-safe
plt.colormaps['RdBu']      # diverging, colorblind-safe
# Or from seaborn:
import seaborn as sns
sns.color_palette("colorblind")
```

@feynman

Like UTF-8 encoding — the default behavior works for the majority, but the 8% edge case fails silently and the fix is a one-line switch to a known-good alternative.

@card
id: edv-ch03-c003
order: 3
title: Sequential Palettes — Choosing the Right One
teaser: Perceptually uniform sequential palettes (viridis, inferno, cividis) were designed to encode magnitude accurately — older rainbow palettes actively distort perception.

@explanation

Not all sequential palettes are perceptually equal. A **perceptually uniform** palette changes lightness at a constant rate as the data value changes. The reader's perception of "more" or "less" maps linearly to the actual data difference.

The rainbow/jet palette (red → orange → yellow → green → blue) is **not** perceptually uniform. Yellow appears much brighter than red or blue in the palette, creating an artificial "bright band" at intermediate values that readers perceive as a peak when no peak exists in the data. The palette creates false patterns in the data.

Perceptually uniform palettes to use:
- **viridis**: purple-blue-green-yellow. Widely available, colorblind-safe, good for print.
- **inferno**: black-purple-red-yellow. High-contrast, colorblind-safe.
- **cividis**: blue-yellow, specifically designed to look similar under deuteranopia as under normal vision.
- **mako / rocket** (seaborn): newer options with good perceptual uniformity.

The test for perceptual uniformity: convert the palette to grayscale. If the grayscale is a smooth ramp from dark to light, the palette is perceptually uniform. If the grayscale has bright and dark bands, it isn't.

```r
# R: viridis is available as a package or via ggplot2 scales
library(ggplot2)
ggplot(df, aes(x, y, fill = value)) +
  geom_tile() +
  scale_fill_viridis_c()  # continuous viridis scale
```

> [!warning] The rainbow/jet palette is still the default in some legacy tools (MATLAB pre-2014, some versions of matplotlib before 2015). Always check which colormap is being applied and replace jet/rainbow with a perceptually uniform alternative.

@feynman

Like linear vs non-linear activation functions — the choice looks neutral from outside but the internal properties determine whether information is faithfully preserved or systematically distorted.

@card
id: edv-ch03-c004
order: 4
title: Diverging Palettes and Meaningful Midpoints
teaser: Diverging palettes only work when the midpoint is a meaningful reference value in the data — applying them when no such midpoint exists creates a misleading implied neutral.

@explanation

A diverging palette encodes two directions from a center. The design contract with the reader: values at the center are "neutral" or "zero"; values moving toward either end are moving away from that neutral in opposite directions.

This contract breaks when:
- The "midpoint" is set to the mean of the data rather than a meaningful reference value. A temperature map diverging from the average temperature encodes "above average" as red and "below average" as blue — which implies average is meaningful when it may not be.
- The midpoint doesn't correspond to a data value any items actually have. A diverging scale from −100 to +100 applied to data ranging from +40 to +90 puts everything in one half of the palette.

Correct uses:
- **Profit/loss:** zero is a meaningful neutral. Positive = one hue, negative = the other.
- **Opinion scale:** "strongly disagree / neutral / strongly agree" — neutral is the meaningful midpoint.
- **Deviation from target:** a budget variance map where 0% variance is neutral.
- **Correlation coefficient:** −1 and +1 are the extremes; 0 is meaningful neutral.

Implementation checklist:
- Center the diverging palette at the meaningful midpoint, not the data minimum.
- Ensure both arms of the palette have equal visual weight at equal distance from center.
- Label the midpoint value on the legend.

```python
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
# Center a diverging colormap at zero when data is -3 to +10
norm = mcolors.TwoSlopeNorm(vmin=-3, vcenter=0, vmax=10)
plt.scatter(x, y, c=values, cmap='RdBu_r', norm=norm)
```

@feynman

Like a signed integer with a meaningful zero — the type implies a midpoint, and using a signed type for data that doesn't have a meaningful zero (like temperature in Kelvin vs Celsius) encodes a false reference.

@card
id: edv-ch03-c005
order: 5
title: Qualitative Palettes and Category Limits
teaser: Qualitative palettes break down above 7–8 categories because the human eye cannot reliably distinguish more simultaneous hues — when you have more categories, merge or facet.

@explanation

A qualitative palette assigns a distinct hue to each category. The constraint is perceptual: the human eye can simultaneously distinguish approximately 5–8 colors in a chart context. Beyond that, readers cannot reliably assign a legend entry to a chart element without visual effort proportional to the number of categories.

Signs that a qualitative palette has too many categories:
- Any two colors in the legend look similar.
- The reader needs to scan the legend repeatedly to identify a specific series.
- Two adjacent colored regions in the chart look like the same category.

Solutions when categories exceed 8:

**Aggregate small categories.** Group categories below a threshold into "Other." If 15 product categories but 5 account for 90% of revenue, show 5 + "Other."

**Highlight the important, gray the rest.** Give 1–3 categories the meaningful hues; make all others a neutral gray. The reader's attention goes where the color is.

```python
# seaborn: highlight one category
colors = {cat: '#C84A50' if cat == 'target_category' else '#CCCCCC'
          for cat in df['category'].unique()}
sns.scatterplot(data=df, x='x', y='y', hue='category', palette=colors)
```

**Facet instead of color.** Use small multiples — one panel per category — instead of one panel with many colors. Position is more accurate than color, and the reader can compare panels.

> [!tip] The "highlight + gray" technique is consistently more effective than multi-color palettes for communication. Most charts are making a point about one or two categories. The other categories provide context; they don't need individual colors.

@feynman

Like a status page with 20 services each a different color — by the time you have 8+ distinct color-coded services, the legend is the bottleneck and grouping into "healthy / degraded / down" is more informative.

@card
id: edv-ch03-c006
order: 6
title: Semantic Color Conventions
teaser: Colors carry cultural meaning that readers apply automatically — working with those conventions makes charts faster to read; fighting them creates cognitive friction.

@explanation

Some color-meaning associations are robust enough across Western, English-speaking technical audiences that violating them slows comprehension:

**Established conventions:**
- Red = negative, danger, decrease, loss. Using red for "profitable" requires the reader to override a strong prior.
- Green = positive, success, increase, healthy. Using green for "at-risk" requires override.
- Blue = informational, neutral, baseline. Widely used as the default "no particular meaning" color.
- Orange / yellow = warning, caution, intermediate. Between green (safe) and red (danger).
- Gray = background, context, inactive, not the focus.

**Domain-specific conventions:**
- In financial charts: red = losses, green = gains. In some Asian contexts, the convention is reversed (red = gains). Know your audience.
- In political maps: in the US, red = Republican, blue = Democrat. In the UK, red = Labour, blue = Conservative. In most other countries, the assignment is different.
- In health/safety contexts: green = pass, yellow = warning, red = fail (traffic light pattern). Using a non-traffic-light palette for a safety dashboard fights deeply embedded training.

**Temperature:** blue = cold, red = hot. Universal across cultures with no known exceptions.

When to break conventions: sometimes a brand palette requires a non-conventional assignment. Document the assignment clearly in the legend and title. Never break the convention silently.

> [!info] The traffic light convention (green/yellow/red for good/warning/bad) is so pervasive in operations and monitoring contexts that deviating from it causes genuine comprehension errors — readers apply the color meaning before they read the legend.

@feynman

Like HTTP status codes — the range 2xx meaning success and 5xx meaning server error is convention, not requirement, but clients that violate it cause integration failures even when the documentation says otherwise.

@card
id: edv-ch03-c007
order: 7
title: Color as Decoration vs Color as Encoding
teaser: Color that does not encode data is noise — it adds cognitive load without adding information, and worse, readers will search for meaning in it that isn't there.

@explanation

When a design choice adds a color that does not represent a data variable, readers will attempt to decode it anyway. The human pattern-detection system does not distinguish "meaningful color" from "decorative color." If the blue bars and orange bars look different, readers assume they encode something different even when they don't.

Common forms of decorative color that should be removed:

**Rainbow bars on a single-category bar chart.** Each bar in a different color when all bars are the same category (e.g., monthly revenue for one product). The colors imply distinct categories. Use one color for all bars.

**Gradient fills on bars or backgrounds.** A bar that fades from dark at the bottom to light at the top implies magnitude varies along the bar height — which it does not. Use solid fills.

**Alternating row shading.** Zebra-striping on a chart background adds visual complexity with no encoding benefit. If gridlines are needed for alignment, use thin, low-contrast gridlines instead.

**Logo colors as chart colors.** Brand colors applied to chart series without regard for the data relationships they encode. Brand consistency is a presentation goal; accurate encoding is a communication goal. The communication goal wins.

The test: for every color in the chart, ask "what data variable does this encode?" If the answer is "nothing" or "the brand," remove it or replace it with a neutral gray.

> [!warning] The hardest case is inherited chart templates where decorative colors are baked into a style guide. "But that's our brand" is not a communication argument. The chart is making false claims about the data whether the colors are intentional or inherited.

@feynman

Like dead code — it takes up space, it can be confusing to readers who try to understand its purpose, and removing it makes the system clearer without changing its behavior.

@card
id: edv-ch03-c008
order: 8
title: Color Contrast and Accessibility Requirements
teaser: WCAG contrast requirements apply to chart labels and annotations — text on colored backgrounds must meet a 4.5:1 ratio or readers with low vision cannot read it.

@explanation

The Web Content Accessibility Guidelines (WCAG 2.1, also enforced in WCAG 2.2) specify minimum contrast ratios between text and its background. These apply to charts when text appears on colored surfaces:

- **Normal text** (under 18pt): minimum 4.5:1 contrast ratio.
- **Large text** (18pt+ or 14pt bold): minimum 3:1 contrast ratio.
- **Non-text visual elements** (chart borders, data point outlines, axes): minimum 3:1 against adjacent colors.

Practical implications:

**Direct labels on colored bars:** white text on a red or dark blue bar typically passes. White text on a yellow or light green bar fails. Test every label color.

**Legend text:** legend text is almost always on a white or near-white background, so contrast is usually fine. Watch out for gray legend text on white backgrounds — light grays frequently fail.

**Axis labels and tick marks:** thin, light gray axis labels on white backgrounds often fail the 3:1 threshold. Use `#767676` or darker for axis text (this is the lightest gray that passes 4.5:1 on white).

Tools for testing:
- `contrast-ratio.com` for manual checks.
- Chrome DevTools accessibility panel shows contrast ratios for any element.
- `accessible-colors.com` for finding the nearest passing color.

```python
# matplotlib: ensure readable axis labels
ax.tick_params(colors='#444444')  # Not #999999 — too light
ax.xaxis.label.set_color('#444444')
```

> [!info] In 2026, browser-rendered charts (Observable Plot, Vega-Lite, D3) can be tested with automated accessibility tools like axe-core. Static image charts (matplotlib, ggplot2 to PNG) require manual contrast checks or specialized testing pipelines.

@feynman

Like minimum memory allocation — if your label contrast is below the threshold, it simply doesn't work for a portion of the audience, exactly as an under-allocated buffer causes failures silently rather than explicitly.

@card
id: edv-ch03-c009
order: 9
title: Background and Surface Colors
teaser: Chart background color affects how every data color appears — white and dark-mode backgrounds require different palette choices for the same perceptual result.

@explanation

Color perception is relative. A mid-saturation blue on a white background looks different from the same blue on a dark gray background because the eye calibrates to the surrounding field. What reads as "strong contrast" on white can look washed out on black.

**White/light backgrounds:** the standard and easiest case. Most color palettes are designed and tested against white backgrounds. High-saturation hues maintain good contrast. Light colors (yellow, light cyan) lose contrast against white and should be avoided as primary encodings.

**Dark backgrounds (dark mode):** require palette adjustments:
- Reduce saturation slightly; saturated colors on black look harsh and bloom visually.
- Increase lightness of colors that would be too dark on white.
- The viridis palette performs well on dark backgrounds. Jet/rainbow becomes worse.
- Text contrast requirements are symmetric — WCAG 4.5:1 applies regardless of whether background is white or black.

**Gray chart backgrounds:** popular in some design systems (e.g., the default ggplot2 theme). Gridlines appear as white (reversed) against the gray background. Data colors need to be tested against the specific gray used, not against white.

In practice: design for light mode first, test dark mode explicitly. Don't assume your palette transfers. In Vega-Lite and Observable Plot, define two theme configurations and toggle them:

```js
// Observable Plot: dark theme
Plot.plot({
  style: {background: "#1a1a2e", color: "#e8e8e8"},
  marks: [Plot.dot(data, {x: "x", y: "y", stroke: "#56B4E9"})]
})
```

> [!tip] In 2026, mobile-first dashboards must handle both light and dark OS themes. Build a `prefers-color-scheme` media query into any web chart that will be embedded in a product UI.

@feynman

Like a theme system in an iOS app — the same design token means something different in light and dark mode, and you need to test both modes explicitly rather than assuming the same values work in both.

@card
id: edv-ch03-c010
order: 10
title: Highlight Colors and Gray as a Tool
teaser: Making everything gray except the one element you want the reader to see is consistently more effective than using multiple colors to indicate importance.

@explanation

The highest-contrast technique in visualization design is not finding the right multi-color palette — it is making everything unimportant gray and making the one important thing a single accent color.

The technique works because:
- Gray elements recede visually. They become context.
- A single non-gray element captures attention immediately due to preattentive color pop.
- The reader's eye goes to the colored element first, then the gray context provides comparison.

Implementation:

**Highlighted series:** in a line chart of 10 companies' stock prices, gray out 9 lines and highlight the target company in red. The comparison is still available; the attention is directed.

**Highlighted bars:** in a bar chart of 12 monthly revenue values, gray all bars and highlight the anomalous one in orange. The anomaly pops without cluttering the chart with explanatory text.

**Highlighted data points:** in a scatterplot of 500 employees, gray all points and color the 5 who are high-attrition risks. The distribution is visible; the individuals of interest are identifiable.

```python
# pandas + matplotlib: highlight one country in a multi-line chart
colors = {country: '#C84A50' if country == 'target' else '#CCCCCC'
          for country in df['country'].unique()}
for country, group in df.groupby('country'):
    ax.plot(group['year'], group['value'], color=colors[country],
            linewidth=3 if country == 'target' else 1,
            zorder=10 if country == 'target' else 1)
```

> [!tip] Gray + one accent color is the most reliable approach for explanatory charts. Reserve multi-color palettes for exploratory charts where the reader is the analyst who needs to distinguish all categories simultaneously.

@feynman

Like a compiler warning with a specific error code vs a wall of INFO log output — the single red warning is visible in 50 lines of gray; the same message at INFO level is invisible.
