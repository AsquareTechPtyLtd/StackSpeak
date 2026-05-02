@chapter
id: cwd-ch02-stripping-the-chart
order: 2
title: Stripping the Chart
summary: Most charts have too much on them. Removing the elements that don't help the reader understand the data is the fastest way to make a chart more communicative.

@card
id: cwd-ch02-c001
order: 1
title: The Decluttering Principle
teaser: Every element on a chart must earn its place by helping the reader understand the data — if it doesn't earn that place, it gets removed.

@explanation

The default output of most charting tools is cluttered. Excel, Tableau, matplotlib, and Plotly all ship with defaults designed to look complete rather than to communicate. Gridlines, chart borders, background fills, bold axis titles, legend boxes — they're all on by default because an empty chart looks unfinished. That default is not a design decision; it's a placeholder.

The decluttering principle inverts that default:

- Start from zero visual elements.
- Add back only what helps the reader understand the data.
- If you can't articulate why an element is on the chart, remove it.

This is a strict standard. "It looks more finished" is not a reason. "It helps the reader see the value" is a reason.

The practical version: after you've built a chart, go element by element and ask whether removing it would make the chart harder to understand. If the answer is no, remove it. Do this pass after every chart you publish until it becomes instinct.

This principle doesn't produce minimalist charts for aesthetic reasons. It produces charts that direct attention to the data instead of splitting it across decoration.

> [!info] The goal is not to make the chart look sparse — it's to make the data the most visually prominent thing on the page.

@feynman

Like code review where every line of code must justify its existence — if it doesn't do something necessary, it's a bug waiting to happen.

@card
id: cwd-ch02-c002
order: 2
title: The Bar Chart as Default
teaser: When in doubt, use a bar chart. Most charts that aren't bar charts are trying to be clever when being clear is the job.

@explanation

Before getting into what to remove, it's worth addressing what chart type to use. Most data can be encoded in one of these types:

- Bar chart (vertical or horizontal)
- Line chart (time series or ranked sequence)
- Scatter plot (relationship between two continuous variables)
- Dot plot (when precision matters more than volume)

The bar chart is the best default because:

- Readers learn to read bar charts before they enter school — the encoding is automatic.
- Length from a common baseline is one of the most accurately decoded visual encodings humans use.
- It works for comparisons, rankings, distributions, and part-to-whole with stacking.

Charts that frequently appear where bar charts would do better:

- **Pie charts:** humans are poor at comparing arc lengths and angles. A bar chart of the same data is almost always clearer.
- **Donut charts:** a pie chart with a hole, adding aesthetic complexity without improving readability.
- **Radar charts:** comparing multiple attributes across multiple categories using area in a polygon. A grouped bar chart handles this more accurately.
- **3D charts:** add a dimension that encodes no data, distorts the visual proportions, and forces the reader to mentally flatten the chart to read it.

The rule is not that these charts are always wrong. The rule is that whenever you reach for one, you should be able to name what it shows that a bar chart couldn't. If you can't name it, use the bar chart.

> [!warning] 3D charts are almost never justified. The third dimension adds visual complexity but encodes no additional data — the only reason to use one is to look impressive, which is the opposite of communicating clearly.

@feynman

Like choosing between writing a custom data structure and using a hashmap — the custom one might be slightly better for a narrow case, but the hashmap is correct 90% of the time and everyone already knows how to read it.

@card
id: cwd-ch02-c003
order: 3
title: What Counts as Clutter
teaser: Clutter is any visual element that consumes ink and attention without adding information — and most charts are full of it.

@explanation

Clutter is not always obvious because individual elements look reasonable in isolation. The problem is cumulative: each element that doesn't earn its place splits the reader's attention from the data.

Common clutter elements:

- **Gridlines at full opacity:** in most charts, gridlines at full weight compete visually with the data. If they're helping the reader compare values, they should be faint — if they're not helping, remove them.
- **Chart borders:** the box drawn around the chart area. It adds no information. Removing it opens the chart visually.
- **Background fills:** a colored or shaded background behind the chart area. Unless the background encodes something (which it rarely does), it's visual noise.
- **Excess colors:** using a different color for each bar in a single-category bar chart. Color encodes category — if all bars represent the same category, all bars should be the same color.
- **Redundant axis labels and data labels:** if you have both an axis and data labels on each bar, one of them is redundant. Usually the data labels are sufficient for precision and the axis can be reduced or removed.
- **Legend boxes:** if the chart has one data series, the legend is redundant — the chart title carries that information. Legends only earn space when multiple series are present and can't be labeled directly.
- **Decorative tick marks:** short tick lines along axes that serve no positioning purpose when the gridlines already provide position reference.

> [!tip] If you're not sure whether something is clutter, cover it with your hand. If the chart is equally readable with it covered, remove it.

@feynman

Like removing dead code — the lines don't throw an error, but they increase cognitive overhead for every reader without contributing to behavior.

@card
id: cwd-ch02-c004
order: 4
title: The Declutter Checklist
teaser: A repeatable step-by-step process for stripping a chart — apply it after every chart build until it's automatic.

@explanation

A checklist makes the decluttering pass systematic rather than judgment-dependent in the moment.

Apply this pass after building the first version of any chart:

1. **Remove the chart border.** Delete the box around the plot area. Almost always an immediate improvement.

2. **Remove or lighten gridlines.** If the chart needs gridlines for value comparison, reduce their weight to 20–30% opacity and use a neutral gray. If the chart has direct data labels, consider removing gridlines entirely.

3. **Remove background fills.** Set the chart area background to white or the document background color. Background fills rarely encode data.

4. **Reduce tick marks.** If gridlines provide position reference, tick marks are redundant. Remove them or reduce them to the axis intersection only.

5. **Remove the legend if avoidable.** If only one series is plotted, the legend is redundant — encode the series name in the chart title or a direct label. If multiple series are present, consider direct labeling at the line ends or bar tops instead of a legend box.

6. **Audit colors.** Count how many colors are being used. If a color is not encoding distinct categories or highlighting specific values, replace it with a neutral tone (gray or the document's base color).

7. **Reduce axis label density.** Axis labels that repeat every single value are often unnecessary. Show enough to establish scale; skip intermediate labels if the reader can interpolate.

8. **Add direct labels where needed for precision.** After reducing axis density, if the reader needs specific values, add data labels directly to the marks rather than forcing them to read the axis.

> [!info] The checklist is not a prescription for what a finished chart must look like — it's a forcing function to make deliberate choices rather than accepting tool defaults.

@feynman

Like a pre-commit hook that checks for console.log statements and unused imports — the check doesn't write your code, but it catches the things you stop noticing when you're deep in building.

@card
id: cwd-ch02-c005
order: 5
title: Chart Junk
teaser: Edward Tufte named chart junk in 1983 and data visualization has been fighting it ever since — understanding the concept makes cluttered charts visible in a way that "it looks busy" doesn't.

@explanation

Edward Tufte introduced the term "chart junk" in *The Visual Display of Quantitative Information* (1983) to describe graphical elements that do not represent data. The term has held because it's precise and memorable.

Tufte's categories of chart junk:

- **Unintentional optical art:** patterns and fills applied to chart elements (hatching, cross-hatching, gradients) that create visual vibration without encoding information.
- **The grid:** gridlines that dominate the chart rather than serve as a quiet reference.
- **The duck:** charts where the chart itself is distorted into a visual shape (a chart shaped like a dollar sign, a map, a person) to represent the subject. The shape distorts the data representation.

The chart junk concept is useful because it identifies the pattern behind individual bad decisions: decoration is being confused with communication. Every chart element is an act of communication — it should either encode data or support the encoding of data. If it does neither, it's junk.

This is not a call for austerity. A chart can have whitespace, careful typography, and visual hierarchy without having chart junk. The distinction is whether the element encodes or supports information, not whether the chart looks "plain."

The practical benefit of the chart junk lens: once you understand the category, cluttered charts in the wild become obviously fixable rather than vaguely uncomfortable.

> [!info] Tufte's data-ink ratio (covered in a later card) is the quantitative form of the same insight: maximize the proportion of ink that represents data.

@feynman

Like distinguishing between comments that explain why versus comments that restate what the code does — the first is useful, the second is noise that degrades the signal-to-noise ratio of the codebase.

@card
id: cwd-ch02-c006
order: 6
title: The Before/After Transformation
teaser: The fastest way to internalize decluttering is to see the same data before and after — the readability improvement is usually larger than expected.

@explanation

A typical before state for a sales-by-region bar chart built in a standard charting tool:

- Bold chart title and subtitle in the chart frame
- Thick chart border around the entire plot area
- Heavy gray background fill inside the chart area
- Full-weight gridlines at every 10-unit interval
- Vertical axis with bold label ("Sales ($)")
- Horizontal axis with rotated labels at 45 degrees
- Each bar filled with a different color (six regions, six colors)
- A legend box listing all six colors in the top-right corner
- Tick marks at every bar
- Drop shadow on the chart frame

After applying the declutter checklist:

- Chart border removed
- Background fill removed
- Gridlines reduced to 20% gray at 3 major intervals
- All bars the same neutral blue (color is not encoding category here — region name on the axis is encoding category)
- Legend removed (labels on the axis are sufficient)
- Axis label rotated upright by shortening region names
- Tick marks removed
- Drop shadow removed
- Chart title moved to the document text, not embedded in the chart frame

The data is identical. The before version takes 5–8 seconds to parse. The after version is readable in under 2 seconds because the reader's attention goes directly to the bar heights rather than navigating decoration first.

> [!tip] Keep your before/after examples. They're the most effective tool for teaching decluttering to others — showing is faster than explaining the principle.

@feynman

Like a code diff where 80% of the lines are removals and the result is both shorter and clearer — the additions are the exception, not the rule.

@card
id: cwd-ch02-c007
order: 7
title: Gridlines — When They Help and When They Hurt
teaser: Gridlines are not always clutter — they help when the reader needs to estimate values, and hurt when the data labels already provide that information.

@explanation

Gridlines do one job: help the reader estimate a value by providing a visual reference grid. Whether they earn their place depends on whether the reader needs that estimation.

When gridlines help:

- **No data labels:** if the bars, points, or lines don't carry direct value labels, gridlines are the only way to estimate a value. Keeping them light is the refinement; removing them entirely would hurt the reader.
- **Dense series:** a line chart with 50 data points over 5 years makes direct labels impractical. A light horizontal gridline grid gives the reader reference without cluttering every point.
- **Relative comparison is the point:** a chart showing market share changes over time benefits from gridlines at 25%, 50%, and 75% — the reader is trying to estimate whether something crossed a threshold.

When gridlines hurt:

- **Direct data labels on each mark:** if every bar already has its value labeled, the gridlines are redundant. They add visual weight without adding information.
- **Ordinal-only data:** a chart where the values are ranks (1st, 2nd, 3rd) and the precise value is irrelevant doesn't need a continuous grid reference.
- **Few bars with obvious relative ordering:** a 3-bar chart where the reader only needs to see which is largest doesn't need a reference grid — the bar lengths make the comparison directly.

The refinement when keeping gridlines: reduce their visual weight until they're barely visible. The goal is a reference that the reader can use when needed but that doesn't compete with the data for attention.

> [!tip] A useful test: if you removed the gridlines, would the chart still answer its core question? If yes, remove them. If no, keep them light.

@feynman

Like log statements — critical during development when you need reference points, but stripped from the production build where they add noise without contributing to output.

@card
id: cwd-ch02-c008
order: 8
title: Chart Borders and Background Fills
teaser: Chart borders and background fills are almost always removable — they create visual containers that the reader has to work around to reach the data.

@explanation

Chart borders and background fills exist in charting tool defaults because they visually delimit the chart as a distinct object on the page. This made more sense in printed documents where charts were pasted into text. In modern dashboards and reports, the chart's own whitespace and positioning already delimit it.

Chart borders:

- Add a closed rectangle around the plot area that the reader's eye has to pass through before reaching the data.
- Create a hard visual edge that makes the chart feel contained rather than integrated with the surrounding document.
- Almost never encode information.

The one case where a border might be warranted: a chart embedded in a complex layout where white-on-white bleed makes the boundary ambiguous. Even then, a subtle drop shadow or background color on the chart container (not the plot area) is usually sufficient.

Background fills:

- A colored or gray fill behind the plot area draws attention to the container rather than the data.
- Gray backgrounds in particular create foreground/background contrast with the data marks, but the contrast is usually uneven and distracting.
- The exception: encoding a categorical region as a background color (a recession period shaded on a time series) — but this is annotation, not decoration, and should be deliberate.

Removing both elements produces an "open" chart where the data marks exist directly in the document space. This integration reduces the cognitive step of "reading into" the chart.

> [!info] In presentation tools (PowerPoint, Keynote), charts often arrive with dark themed borders and backgrounds from the template. These should be explicitly reset to match the slide background — the template defaults are designed for visual variety, not for data readability.

@feynman

Like removing wrapper divs from HTML that aren't doing layout work — the DOM is shallower, the styles are simpler, and the content is where the reader expects it.

@card
id: cwd-ch02-c009
order: 9
title: Tick Marks and Axis Label Density
teaser: More tick marks and axis labels don't make a chart more precise — they make it harder to read by forcing the eye to process values it doesn't need.

@explanation

Tick marks are the small perpendicular lines on an axis that indicate value positions. They're useful when gridlines are absent and the reader needs to anchor values to position. When gridlines are present, tick marks are redundant.

Axis label density — how many labels appear on an axis — is a calibration, not a setting to maximize.

The right density depends on how the reader will use the chart:

- **If the reader needs exact values:** direct data labels on marks are more precise and more readable than dense axis labels. Reduce the axis to a few anchor values (0, 50, 100) and use labels directly.
- **If the reader needs approximate values:** a few evenly spaced labels establish scale. Labeling every value (every year, every country, every category) adds processing cost without adding precision.
- **If the reader only needs relative ordering:** category labels on the axis are sufficient. The axis scale adds nothing if the chart is communicating "A is larger than B," not "A is 47 and B is 32."

Axis labels that require rotation (angled or vertical text) are a signal that there are too many labels. Options before rotating:

- Skip alternate labels.
- Use abbreviated versions of the labels.
- Flip to a horizontal bar chart, where the labels are horizontal by default.
- Truncate with an ellipsis if the labels are long strings.

Rotated axis labels increase reading time because the eye has to change orientation for every label. Horizontal labels are read with a single scanning motion.

> [!warning] Rotating axis labels to 45 degrees is a workaround for too many labels, not a solution. If labels need rotation, there are too many of them.

@feynman

Like pagination — show the reader enough to establish context and navigate, not every record in the database on a single page.

@card
id: cwd-ch02-c010
order: 10
title: When Simplification Is Wrong
teaser: There are real cases where decoration reduces cognitive load rather than adding it — knowing when to apply that exception is as important as knowing the default.

@explanation

The decluttering principle is a strong default, not an absolute rule. There are documented cases where elements that look like clutter are actually doing work.

Cases where "extra" elements earn their place:

- **Novice audiences unfamiliar with the chart type:** a simple icon or pictogram alongside a bar chart can anchor the reader to the subject without requiring them to read the title first. A chart of hospital beds per region with a small bed icon is not decoration — it reduces the cognitive step of reading the title.
- **Long reading sessions:** a report that will be read over 30 minutes benefits from light visual variety. A chart with a subtle background color that groups related charts is using decoration as an organizational tool, which is different from using decoration for aesthetics.
- **Brand-required formatting:** a chart published as part of a company report with specific brand guidelines may need to include elements that wouldn't appear in a purely functional context. Brand consistency is a real user need, not chart junk.
- **Accessibility:** some background color combinations improve contrast for readers with color vision deficiencies. An element that looks redundant to a typical viewer may be essential for accessibility compliance.
- **Cultural context:** certain charts read in certain industries (financial charts, scientific publications) have established conventions that readers expect. Removing the convention breaks the reader's pattern recognition.

The test for these exceptions is the same as the test for everything else: can you name what the element does for the reader? If yes, it earns its place. If the answer is "it looks more professional" or "the template has it," that's not a reason.

> [!tip] When in doubt, run both versions by someone who hasn't seen the data. Ask which version they understand faster. Let the reader, not your aesthetic instinct, make the call.

@feynman

Like defensive programming — most of the time it adds complexity for no reason, but in production code handling untrusted input, it's not optional.

@card
id: cwd-ch02-c011
order: 11
title: The Data-Ink Ratio in Applied Context
teaser: Tufte's data-ink ratio gives a name to the intuition behind decluttering — maximizing the proportion of ink on the chart that represents data rather than decoration.

@explanation

Tufte defined the data-ink ratio as the proportion of a chart's ink that is used to present actual data, versus the total ink used to produce the chart. The ideal is a high ratio — most of the ink is encoding data.

The formula is conceptual, not literal:

```
data-ink ratio = data ink / total ink used to print the graphic
```

In practical terms: for every element on a chart, ask whether it represents data. Bars represent data. The spaces between gridlines represent data. The axis labels represent data. The chart border does not. The background fill does not. The legend box border does not.

Maximizing the ratio doesn't mean removing all non-data ink — axis labels, titles, and annotations are supporting ink that helps the reader interpret the data ink. Supporting ink earns its place. Decorative ink doesn't.

Applied to a dashboard:

- A dashboard with six charts, each with a chart border, a background fill, heavy gridlines, and a legend box has a low data-ink ratio across the board.
- The same six charts stripped to data marks, light gridlines, direct labels, and chart titles embedded in the document have a high ratio.

The reader experience of the two dashboards is not subtle: the first requires 5–10 minutes of scanning to form a complete picture; the second is usually graspable in 60–90 seconds.

Signal-to-noise in data visualization is not a metaphor — it's a measurable difference in the time required to extract the information.

> [!info] The data-ink ratio is a diagnostic lens, not a score to optimize. A chart can have a high ratio and still communicate poorly if the data itself is poorly chosen or the encoding is wrong.

@feynman

Like the signal-to-noise ratio in a communication channel — a high ratio means more of what you're transmitting is information, and the receiver spends less effort filtering out interference.

@card
id: cwd-ch02-c012
order: 12
title: The Reader's Experience of Clutter
teaser: Cognitive load is what clutter produces in the reader's brain — understanding what that feels like makes it easier to design against it.

@explanation

Cognitive load is the mental effort required to process information. It comes in two forms relevant to data visualization:

- **Intrinsic load:** the complexity inherent in the data itself. A chart of 50 variables over 10 years has high intrinsic load; a chart of 3 countries over 5 years does not.
- **Extraneous load:** complexity added by the presentation rather than the data. A chart border, a background fill, and six unnecessary colors add extraneous load regardless of how complex the underlying data is.

Designers control extraneous load. The reader's working memory budget is finite — every unit of extraneous load is a unit that doesn't go toward understanding the data.

What clutter feels like from the reader's perspective:

- Eye movement that doesn't resolve into an answer. The reader looks at the chart, scans across multiple elements, and can't identify where to focus.
- Repeated re-reading. The reader needs to cross-reference the legend, the axis, the title, and the data marks to get a single data point.
- The sensation that the chart is "busy" without a clear takeaway — the chart has information but doesn't have a message.

What a decluttered chart feels like:

- Immediate focus on the highest bars, the sharpest trend, the outlier.
- Single scan to get the main point.
- Detail available on demand (data labels, axis labels) without being forced on every reader.

Every second of unnecessary processing time is a second where the reader might stop engaging. In a business context, a chart that takes 15 seconds to understand will often be skipped.

> [!warning] "The reader can figure it out" is not a defense of a cluttered chart. The reader's effort is a cost that you've imposed on them. Minimizing that cost is the job.

@feynman

Like API latency — 200ms is invisible, 2000ms breaks the user's flow, and the difference is entirely on the server side, not the user side.
