# Case: Time-series

Signals versus time — step, impulse, transient, sensor traces, controller I/O. Inherits all Common rules; overrides/adds below.

## Axes

- **X axis = time, linear.** Label `Time (s)` (or correct unit in parentheses). Never log x.
- **Start at 0 by default.** Both the time vector and `xlim(1)` begin at `0`; set `xlim = [0, t_end]` explicitly. Only exception: zooming a transient — then state why the start is non-zero.
- `ylim` padded ~5–10% beyond signal min/max.
- Aspect ratio `pbaspect([2 1 1])` (wide) — time series read left-to-right.

## Multi-signal layout

- Different physical quantities (e.g. position vs current vs voltage) → **stacked subplots sharing the x axis**, one quantity per panel:

```matlab
fig = figure;
ax1 = subplot(3, 1, 1, 'Parent', fig);
ax2 = subplot(3, 1, 2, 'Parent', fig);
ax3 = subplot(3, 1, 3, 'Parent', fig);
linkaxes([ax1, ax2, ax3], 'x');       % x축 공유
xlabel(ax3, 'Time (s)');              % 맨 아래 패널만 x라벨
```

- Same quantity, several cases (≤6) → one axes, color order from style block, legend per Common.
- Only the bottom panel needs the `Time (s)` xlabel; upper panels can omit it (still set xlim).

## Dual y-axis (two different units)

When **exactly two** quantities of different units share the time axis (e.g. displacement `mm` and current `A`) and you want them overlaid, use `yyaxis left/right` instead of stacked subplots. For three or more quantities, use stacked subplots.

**Align the grids:** give both sides the **same number of y-ticks (3–5)** with round bounds so the left and right grid lines coincide — otherwise two mismatched grids overlap and look noisy. Match each ruler's color to its series so the reader maps line → axis.

```matlab
fig = figure;
ax  = axes('Parent', fig);
nYTicks = 5;                       % 양쪽 동일 개수 → grid line 정렬

yyaxis(ax, 'left');                % 좌측: 변위
plot(ax, t, disp_mm, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
ylabel(ax, 'Displacement (mm)');
ylim(ax, [0, 4]);                  % round 경계
yticks(ax, linspace(0, 4, nYTicks));
ax.YColor = colorOrder(1, :);      % 좌측 축 색 = 변위 시리즈

yyaxis(ax, 'right');               % 우측: 전류
plot(ax, t, curr_A, 'LineStyle', '-', 'Color', colorOrder(2, :), 'LineWidth', lineWidth);
ylabel(ax, 'Current (A)');
ylim(ax, [0, 2]);                  % round 경계
yticks(ax, linspace(0, 2, nYTicks));   % 동일 nYTicks → 좌우 grid 공유
ax.YColor = colorOrder(2, :);      % 우측 축 색 = 전류 시리즈

xlabel(ax, 'Time (s)');
xlim(ax, [0, t(end)]);
% per-axes styling(font/box/grid) 적용 — grid 하나로 좌우 공유됨
```

- Here `linspace` is acceptable **because equal tick count is the goal**; pick round `ylim` bounds (start at `0`) so the ticks still land on round values incl. `0`.
- The grid is shared: with matched tick counts a single grid serves both rulers. Do not draw two separate grids.
- Legend must name both series with their units (e.g. `Displacement`, `Current`).

## Notes

- Reference/setpoint lines: dashed (`'LineStyle', '--'`), include in legend.
- For sampled/discrete data use `stairs` instead of `plot`; all style rules still apply.
