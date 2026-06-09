---
name: plot-style
description: apply consistent scientific and engineering plotting conventions when writing or modifying code that creates figures, axes, legends, labels, limits, aspect ratios, subplots, or any visualization. use for matlab plotting by default when no language is specified. covers common rules plus case modules (time-series, xy-plot, 3d-plot, frequency-response) loaded on demand. when the user requests another language (python matplotlib, pandas, seaborn, plotly, etc.), apply the closest equivalent of every matlab rule. use when modifying user-provided plotting code, generating new plotting scripts, styling frf/bode/nyquist/step/impulse/time-series/xy/scatter/surface visualizations, or enforcing lab/report plot formatting.
---

# Plot Style

## Priority

User instructions override every default below. When modifying user code, preserve existing variable, function, and data-structure names; return the complete updated script (not a diff). Default language is MATLAB.

## How to use this skill

1. Apply **all Common rules** below to every plot.
2. Identify the plot type, then read and apply the matching **case module** in `references/`:

| Plot type | Read |
|---|---|
| Time / signal vs time, step, impulse, transient | [`references/time-series.md`](references/time-series.md) |
| X–Y curve, scatter, trajectory, phase portrait, parametric | [`references/xy-plot.md`](references/xy-plot.md) |
| Surface, mesh, `plot3`, scatter3, volumetric | [`references/3d-plot.md`](references/3d-plot.md) |
| Bode, FRF, Nyquist, magnitude/phase vs frequency | [`references/frequency-response.md`](references/frequency-response.md) |

A case module **inherits** Common and overrides only the listed items. If a plot mixes types, apply each relevant module to its panel. If no module fits, Common alone is sufficient.

## Other languages

All rules are written for MATLAB. For Python (matplotlib, pandas `.plot`, seaborn, Plotly) or any other plotting language, translate every rule into the closest equivalent: same style-block structure, same axes properties, same colors, same legend logic, same series-count rule, same log-frequency rule, same English-in-figures / Korean-in-comments convention. When a target cannot implement a rule exactly, use the closest available equivalent and keep the rest intact.

---

# Common rules (apply to every plot)

## Style block (top of script)

```matlab
set(0, 'DefaultFigureWindowStyle', 'docked');

% 플롯 스타일 기본 설정 (Common)
fontSize   = 24;
fontName   = 'Times New Roman';
lineWidth  = 3.0;
gridStyle  = '--';                 % 점선 그리드
gridAlpha  = 0.25;                 % 그리드 투명도
maxDefaultSeries = 6;              % 기본 시리즈 최대 개수 (= 범례 항목 최대)
legendLocationCandidates = {'northeast', 'northwest', 'southeast', 'southwest', 'northoutside'};
colorOrder = [
    0, 0, 0;
    1, 0, 0;
    0, 0, 1;
    0, 0, 0;
    0, 0.5, 0;
    1, 1, 0;
    0, 1, 1;
    0, 1, 0
];
```

Reference these throughout the script instead of hard-coding repeated values.

## Language in output

- Figure-rendered text (axis labels, legend, ticks, annotations, colorbar, text objects): **English**.
- Code comments and inline explanations: **Korean**.
- Override only when the user explicitly requests otherwise.

## Figure organization

- **Always dock figures by default** via `set(0, 'DefaultFigureWindowStyle', 'docked');` at the top, even for a single figure. Override only when the user explicitly asks for floating/undocked.
- Consolidate related plots into one figure with multiple panels rather than many separate figures, unless the user asks for separates.
- Prefer `figure` + `subplot`. Do not use `tiledlayout` by default; use it only when explicitly requested, when existing user code already uses it, or when the layout cannot be done with `subplot`.

## Series-count rule

- ≤6 candidate series: plot all.
- More than 6 candidates: plot only the first `maxDefaultSeries` (6) by default. Plot more only if the user explicitly asks; then cycle the color order.
- The legend always describes exactly the series plotted, capped at `maxDefaultSeries` (6). If the user forces more than 6 series, list the first 6 in the legend and note the omission.

## Universal axes rules

Apply to every axes object (incl. subplots and secondary axes):

1. Font set from the style block (`fontName`, `fontSize`) — applied to every axes.
2. Box/border visible (`'Box', 'on'`).
3. Grid on, with `gridStyle`/`gridAlpha` from the style block (see per-axes styling below).
4. `xlabel` and `ylabel` present.
5. `xlim` and `ylim` set. If the user gives no limits, compute padded limits from data or use domain-appropriate values.
6. Aspect ratio set (default `pbaspect([2 1 1])`; case modules may override).
7. Legend present.
8. **No title** unless the user explicitly requests one.
9. Units in **parentheses**, not brackets: `Time (s)`, never `Time [s]`.
10. Ticks: **target 3–5 grid lines per axis**; keep MATLAB's automatic ticks (never force `linspace`). See Tick rule.

## Tick rule

- **Default: leave MATLAB's automatic ticks.** They fall on round values and usually include `0` and characteristic points.
- Do **not** use `xticks(ax, linspace(...))` to force a count — that drops meaningful numbers (`0`, peaks, crossings) onto arbitrary positions.
- If an axis needs adjustment, use **round spacing that includes the characteristic values**, e.g. `xticks(ax, 0:0.25:1)` — keep the visible count in 3–5.
- Log axis (frequency response): let the decade ticks stand; do not override.

## Render–review–revise workflow (run for every figure)

Produce every figure in two passes — never report a plot done from code alone; verify the rendered image.

1. **Draft (1st figure).** Build the figure applying all Common rules + the relevant case module.
2. **Save.** Write to an `image_fig/` subfolder (create if missing): a review PNG + an editable FIG.

```matlab
% 결과 figure 저장 (검토용 PNG + 편집용 FIG)
if ~exist('image_fig', 'dir'); mkdir('image_fig'); end
figName = 'plot_name';                         % 의미 있는 이름으로
exportgraphics(fig, fullfile('image_fig', [figName '.png']), 'Resolution', 200);
savefig(fig, fullfile('image_fig', [figName '.fig']));
```

3. **Review.** Read the saved PNG back (via the MATLAB MCP) and check it against the checklist below — actually look at the rendered image, not just the code.
4. **Ask before fixing.** For any item that looks violated or ambiguous (sparse ticks, clipped data, legend overlap, distorted aspect), tell the user what looks off and **propose a fix — do not silently change it**.
5. **Revise (2nd figure).** Apply only the user-approved changes, re-save, re-review until the checklist passes.

### Verification checklist

- [ ] Font Times New Roman, size 24 on all axes (incl. colorbar)
- [ ] Box on; grid on, dashed, alpha 0.25
- [ ] `xlabel` + `ylabel` (+ `zlabel` for 3-D); units in parentheses, not brackets
- [ ] `xlim`/`ylim` (/`zlim`) set; data not clipped; ~5% padding
- [ ] 3–5 grid lines per axis; `0`/characteristic values visible (no `linspace`-forced ticks)
- [ ] Aspect ratio set — `pbaspect`/`daspect`/`axis equal` as the case dictates
- [ ] Legend present, ≤6 entries, describes only plotted series, minimal overlap
- [ ] No title (unless the user asked)
- [ ] All figure text English; explicit `Color`/`LineStyle`/`LineWidth` (no `'r-'` shorthand)
- [ ] ≤6 series unless the user asked for more

**Tick check (most common miss):** if an axis shows fewer than 3 grid lines, ask the user for a round tick set (suggest one including `0`/characteristic values) or to leave the default — never force ticks silently.

## Color and line rules

- Never use shorthand format strings (`'r-'`, `'b--'`, `'k:'`).
- Always set `LineStyle` and `Color` explicitly via name-value pairs, `LineWidth` from the style block.
- Use the color order from the style block; drop the alpha (4th element) when the target function does not support it. Cycle the sequence only when more than 6 series are explicitly plotted.

```matlab
plot(ax, x, y, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
```

## Legend rules

- Choose location from `legendLocationCandidates` only (unless overridden). Pick the one minimizing data overlap; prefer `northoutside` for crowded plots.
- Columns by displayed entry count: **1–3 → 1 column, 4–6 → 2 columns**.
- The legend describes only series actually plotted (≤6).

```matlab
% 범례 항목 개수에 따라 열 수 설정 (최대 6개)
numLegendEntries = min(numel(legendLabelsDisplayed), maxDefaultSeries);
if numLegendEntries <= 3
    numLegendColumns = 1;
else
    numLegendColumns = 2;
end

legend(ax, hPlot(1:numLegendEntries), legendLabelsDisplayed(1:numLegendEntries), ...
       'Location', 'northoutside', ...
       'NumColumns', numLegendColumns, ...
       'FontSize', fontSize, ...
       'FontName', fontName);
```

## Per-axes styling

Apply to every axes (font, box, grid) in one place:

```matlab
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha);
```

## Output behavior

- Editing existing code: return the complete revised script.
- New code: include all style commands inline so the figure renders correctly without manual editing.
