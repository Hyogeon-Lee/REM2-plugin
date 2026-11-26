# Case: Time-series

Signals versus time — step, impulse, transient, sensor traces, controller I/O. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/time_series_example.m`](../examples/time_series_example.m)

## Axes

- **X axis = time, linear.** Label `Time (s)` (or correct unit in parentheses). Never log x.
- **Start at 0 by default.** Both the time vector and `xlim(1)` begin at `0`; set `xlim = [0, t_end]` explicitly. Only exception: zooming a transient — then state why the start is non-zero.
- `ylim` padded ~5–10% beyond signal min/max; Common `finalizeYLimits` then adds legend headroom and the y-tick inset.
- Aspect ratio `pbaspect([2 1 1])` (wide) — time series read left-to-right.

## Multi-signal layout

- Different physical quantities (e.g. position vs current vs voltage) → **stacked subplots sharing the x axis**, one quantity per panel:

```matlab
tab = uitab(tabGroup, 'Title', 'Time Response');   % 결합 패널 → 한 탭 안에 subplot (Common: Figure organization)
ax1 = subplot(3, 1, 1, 'Parent', tab);
ax2 = subplot(3, 1, 2, 'Parent', tab);
ax3 = subplot(3, 1, 3, 'Parent', tab);
linkaxes([ax1, ax2, ax3], 'x');       % x축 공유
for ax = [ax1, ax2, ax3]
    xlabel(ax, 'Time (s)');           % 패널별 PNG 분리 저장 → 모든 패널에 x라벨
end
```

- Same quantity, several cases (≤6) → one axes, color order from style block, legend per Common.
- Every panel carries the `Time (s)` xlabel and its own xlim — panels are exported as separate PNGs, so none may depend on a neighbor's label.

## Dual y-axis (two different units)

When **exactly two** quantities of different units share the time axis (e.g. displacement `mm` and current `A`) and you want them overlaid, use `yyaxis left/right` instead of stacked subplots. For three or more quantities, use stacked subplots.

**Align the grids:** give both sides the **same number of y-ticks (3–5)** over a round tick range, and the **same relative inset** between that range and `ylim`, so the left and right grid lines coincide — otherwise two mismatched grids overlap and look noisy. Match each ruler's color to its series so the reader maps line → axis.

```matlab
tab = uitab(tabGroup, 'Title', 'Displacement and Current');
ax  = axes('Parent', tab);
nYTicks = 5;                       % 양쪽 동일 개수 → grid line 정렬

yyaxis(ax, 'left');                % 좌측: 변위
plot(ax, t, disp_mm, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
ylabel(ax, 'Displacement (mm)');
yTickRange = [0, 6];               % round 눈금 범위 — 위쪽은 범례 자리만큼 여유 (데이터 최대 약 4)
ylim(ax, yTickRange + yTickInsetFrac * diff(yTickRange) * [-1, 1]);   % 양 끝 눈금을 박스 안쪽으로
yticks(ax, linspace(yTickRange(1), yTickRange(2), nYTicks));
ax.YColor = colorOrder(1, :);      % 좌측 축 색 = 변위 시리즈

yyaxis(ax, 'right');               % 우측: 전류
plot(ax, t, curr_A, 'LineStyle', '-', 'Color', colorOrder(2, :), 'LineWidth', lineWidth);
ylabel(ax, 'Current (A)');
yTickRange = [0, 3];               % round 눈금 범위 — 좌측과 같은 비율의 여유 (데이터 최대 약 2)
ylim(ax, yTickRange + yTickInsetFrac * diff(yTickRange) * [-1, 1]);   % 좌측과 같은 상대 여유 → 좌우 grid 공유
yticks(ax, linspace(yTickRange(1), yTickRange(2), nYTicks));          % 동일 nYTicks
ax.YColor = colorOrder(2, :);      % 우측 축 색 = 전류 시리즈

xlabel(ax, 'Time (s)');
xlim(ax, [0, t(end)]);
% per-axes styling(font/box/grid) 적용 — grid 하나로 좌우 공유됨
```

- Here `linspace` is acceptable **because equal tick count is the goal**; pick a round tick range (start at `0`) so the ticks still land on round values incl. `0`.
- The grid is shared: with matched tick counts a single grid serves both rulers. Do not draw two separate grids.
- Legend must name both series with their units (e.g. `Displacement`, `Current`).
- **Do not call `finalizeYLimits` on a dual axis** — it would move the two rulers by different amounts and break the grid alignment. Put the legend headroom into the tick ranges instead: keep both series below ~65% of their tick range where they pass under the legend (a 2-entry legend at `fontSize` 24 takes ~25% of the box height), and confirm in the review image. The legend still goes inside at the Common count-based location.

## Notes

- Reference/setpoint lines: dashed (`'LineStyle', '--'`), include in legend.
- For sampled/discrete data use `stairs` instead of `plot`; all style rules still apply.
