# Case: X–Y plot

Curve of y vs an independent x that is **not** time — scatter, trajectory, phase portrait, parametric curve, spatial path, I–V / B–H / force–displacement characteristic. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/xy_plot_example.m`](../examples/xy_plot_example.m)

## Aspect ratio — the key decision

- **X and Y share physical meaning / same units** (spatial path, trajectory, phase portrait, B–H loop in same scale): use **equal scaling** so geometry is undistorted.

```matlab
axis(ax, 'equal');     % 또는 daspect(ax, [1 1 1]);
```

- **X and Y are different quantities** (e.g. force vs displacement, current vs voltage): keep `pbaspect([1 1 1])` (square) by default unless the data aspect dictates otherwise. Do **not** force `axis equal`.

## Axes

- Label both axes with quantity and unit in parentheses.
- Set `xlim`/`ylim` with ~5% padding. For closed curves (loops, orbits) pad symmetrically so the curve is centered.

## Scatter vs line

- Continuous curve → `plot` with explicit `LineStyle`/`Color`/`lineWidth`.
- Discrete points → `scatter(ax, x, y, sz, 'MarkerEdgeColor', colorOrder(k,:), 'LineWidth', 3)`; pick marker size for visibility, no connecting line unless ordering is meaningful.
- Trajectory with direction → add sparse markers or an arrow/quiver to show progression; mark start/end distinctly and label them in the legend.

## Notes

- Multiple curves (≤6) share one axes with the style-block color order; legend per Common.
- For parametric/phase-portrait families, the legend labels the parameter value, not "x"/"y".
