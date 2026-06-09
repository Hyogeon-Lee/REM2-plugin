---
name: plot-style
description: apply consistent scientific/engineering style to plotting code (figures, axes, legends, labels, limits, aspect ratios, subplots). use only when writing or modifying code that generates plots — matlab by default, or the closest equivalent when the user names another language (python matplotlib, pandas, seaborn, plotly). covers common rules plus case modules (time-series, xy-plot, 3d-plot, frequency-response) loaded on demand. triggers: styling user-provided plotting code, generating new plotting scripts, or formatting frf/bode/nyquist/step/impulse/time-series/xy/scatter/surface plots for lab reports. not for non-code image generation or general visualization requests.
---

# Plot Style

## Priority

User instructions override every default here. When modifying user code, preserve existing variable, function, and data-structure names, and return the complete updated script (not a diff). Default language is MATLAB.

## How to use

1. Apply **every Common rule** to all plots.
2. Identify the plot type and also apply the matching **case module** in `references/` (each inherits Common and overrides only what it lists):

| Plot type | Module |
|---|---|
| Time / signal vs time, step, impulse, transient | [`references/time-series.md`](references/time-series.md) |
| X–Y curve, scatter, trajectory, phase portrait, parametric | [`references/xy-plot.md`](references/xy-plot.md) |
| Surface, mesh, `plot3`, scatter3, volumetric | [`references/3d-plot.md`](references/3d-plot.md) |
| Bode, FRF, Nyquist, magnitude/phase vs frequency | [`references/frequency-response.md`](references/frequency-response.md) |

A mixed plot → apply each relevant module to its panel. No module fits → Common alone is sufficient.

## Other languages

Rules are written for MATLAB. When the user explicitly requests Python (matplotlib, pandas `.plot`, seaborn, Plotly) or any other package, translate every rule into its closest equivalent — same style-block values, axes properties, colors, legend logic, series cap, log-frequency rule, and English-figures / Korean-comments convention. If a target cannot match a rule exactly, use the nearest equivalent and keep the rest intact.

---

# Common rules

## Style block (top of script)

Single source of truth for every style value. Reference these variables throughout; never hard-code the values again.

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

## Required on every axes

Apply to every plotting **axes** — including subplots and secondary (`yyaxis`) axes. Box and grid are **always on** for a plotting axes. A `colorbar` is **not** an axes object — it has its own `Box` (keep the default on) but **no** `XGrid`/`YGrid`/`ZGrid` (grid does not apply to a colorbar). Do **not** pass it to the `set(ax, ...)` line below — the grid properties error on a colorbar; style it separately (see "Colorbar").

- **Font / box / grid** — set in one line:

```matlab
set(ax, 'FontSize', fontSize, 'FontName', fontName, 'Box', 'on', 'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', 'GridLineStyle', gridStyle, 'GridAlpha', gridAlpha);
```

- **Labels** — `xlabel` and `ylabel` always present (`zlabel` too for 3-D). Units in **parentheses**, never brackets: `Time (s)`, not `Time [s]`.
- **Limits** — set `xlim`/`ylim` (`zlim` for 3-D) explicitly; never leave them to auto when data could clip. With no user limits, pad ~5% beyond the data range.
- **Ticks** — target **3–5 grid lines per axis**. Keep MATLAB's automatic ticks; **never** force a count with `xticks(ax, linspace(...))` — it drops `0`, peaks, and crossings onto arbitrary positions. Adjust only with round spacing that includes the characteristic values, e.g. `xticks(ax, 0:0.25:1)`. On a log axis, keep the decade ticks.
- **Aspect ratio** — always set it; default `pbaspect([2 1 1])` unless a case module or the data dictates otherwise.
- **Lines / colors** — set `LineStyle`, `Color`, and `LineWidth` explicitly via name-value pairs; take `Color` from `colorOrder` and `LineWidth` from the style block. **Never** use shorthand format strings (`'r-'`, `'b--'`, `'k:'`).

```matlab
plot(ax, x, y, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
```

- **No title** unless the user explicitly asks for one.
- **Language** — all figure-rendered text (labels, legend, ticks, annotations, colorbar) in **English**; code comments in **Korean**. Override only on explicit request.

### Colorbar (only when present)

A colorbar is a separate object — style it through its own handle, **not** the axes `set(ax, ...)` line. Set only the properties it actually has:

```matlab
cb = colorbar(ax);
set(cb, 'FontSize', fontSize, 'FontName', fontName);   % Box는 기본 on 유지, grid는 colorbar에 해당 없음
cb.Label.String = 'Flux Density (mT)';                 % 매핑된 양 + 단위 (괄호)
```

Add a colorbar only when color encodes a quantity not already on an axis (see 3-D case: no colorbar when the z axis already carries the value).

## Series and legend

- Plot ≤ `maxDefaultSeries` (6) series by default. More than 6 candidates → plot the first 6 only; plot more only when the user asks, then cycle `colorOrder`.
- The legend lists exactly the plotted series, capped at `maxDefaultSeries`. If the user forces more than 6, list the first 6 and note the omission.
- A legend is present on every axes. Choose location from `legendLocationCandidates` only — the one with least data overlap, preferring `northoutside` when crowded.
- Columns by entry count: **1–3 → 1 column, 4–6 → 2 columns**.

```matlab
% 범례: 표시 개수 제한 + 개수에 따른 열 수
numLegendEntries = min(numel(legendLabelsDisplayed), maxDefaultSeries);
if numLegendEntries <= 3
    numLegendColumns = 1;
else
    numLegendColumns = 2;
end
legend(ax, hPlot(1:numLegendEntries), legendLabelsDisplayed(1:numLegendEntries), ...
       'Location', 'northoutside', 'NumColumns', numLegendColumns, ...
       'FontSize', fontSize, 'FontName', fontName);
```

## Figure organization

- **Dock every figure**: `set(0, 'DefaultFigureWindowStyle', 'docked');` at the top, even for a single figure. Override only on explicit request.
- Consolidate related plots into one multi-panel figure rather than many figures, unless the user wants separates.
- Use `figure` + `subplot`. Use `tiledlayout` only when the user asks, when existing code already uses it, or when `subplot` cannot express the layout.

## Render → review → revise (run for every figure)

Never report a plot done from code alone — verify the rendered image.

1. **Draft.** Build the figure with all Common rules + the case module.
2. **Save** to an `image_fig/` subfolder (create if missing): a review PNG + an editable FIG.

```matlab
% 결과 figure 저장 (검토용 PNG + 편집용 FIG)
if ~exist('image_fig', 'dir'); mkdir('image_fig'); end
figName = 'plot_name';                         % 의미 있는 이름으로
exportgraphics(fig, fullfile('image_fig', [figName '.png']), 'Resolution', 300);
savefig(fig, fullfile('image_fig', [figName '.fig']));
```

3. **Review.** Read the saved PNG back (via the MATLAB MCP) and verify it against **every rule in "Required on every axes" and "Series and legend"**, plus rendered-image faults: clipped data, legend overlap, distorted aspect, or fewer than 3 grid lines on an axis.
4. **Fix vs ask.** **Fix unambiguous style violations directly** — missing units, shorthand color, wrong font/grid/linewidth, absent limits, distorted aspect, clipped data, legend overlap — and note what you changed. **Ask only when the fix changes interpretation**: which tick values to force on a sparse axis (<3 grid lines), whether a non-zero time start is intended, choosing a colormap/representation, or anything where multiple valid readings of the data exist.
5. **Revise.** Apply the fixes (and any user-approved interpretive changes), re-save, re-review until clean.

**Fallback when no MATLAB MCP (or non-MATLAB language).** If you cannot render/read the image back — MATLAB MCP unavailable, or the target is Python/another package run elsewhere — skip the image-reading step but keep the rest:

- Still emit the save block (PNG + FIG, or the language's equivalent) so the user can render and review.
- Self-check the **code** against every rule in "Required on every axes" and "Series and legend".
- State explicitly that the image was **not** visually verified, and list the rendered-image faults the user should check by eye (clipped data, legend overlap, distorted aspect, <3 grid lines).
- Never claim a plot is verified from code alone.

## Output behavior

- Editing existing code → return the complete revised script.
- New code → include all style commands inline so the figure renders correctly with no manual edits.
