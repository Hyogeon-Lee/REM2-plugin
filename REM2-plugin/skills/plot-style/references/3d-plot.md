# Case: 3-D plot

Surface, mesh, `plot3` curves, `scatter3`, fields/volumetric. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/three_d_plot_example.m`](../examples/three_d_plot_example.m)

## Series count (override)

The Common ≤6 series cap **does not apply** here. 3-D plots often need more objects to convey spatial structure or highlight features, so plot as many as the scene requires. Still cycle the style-block color order, and keep the legend readable (legend only the entries worth naming; describe surfaces by colorbar, not legend).

## Aspect ratio

- x, y, z share the **same unit** (pure geometry) → `daspect(ax, [1 1 1])` for true proportions.
- **Mixed units** (e.g. position `mm` vs field `mT`) → data aspect is meaningless; set a readable plot box with `pbaspect`, e.g. `pbaspect(ax, [1 1 0.7])`.

## Axes

- **Three labels**: `xlabel`, `ylabel`, `zlabel`, all with units in parentheses.
- Set `xlim`, `ylim`, `zlim` explicitly.
- Grid on (Common dashed/alpha) — keeps depth cues on all three planes.
- Set an explicit viewpoint: **default `view(ax, 30, 15)`** (azimuth, elevation); adjust to expose the feature of interest. State the chosen view in a comment.

## Surfaces / meshes

Two acceptable looks — pick by intent:

- **Mesh form (default for structure):** keep the surface edges so the reader sees the grid. Use a subtle dark `EdgeColor` (not solid black on a dense grid) and a moderate grid resolution so the mesh reads.
- **Smooth shaded:** `'EdgeColor', 'none'` + `shading(ax,'interp')` for a continuous field where the mesh is noise.

```matlab
% mesh 형태 (격자 구조 강조)
surf(ax, X, Y, Z, 'EdgeColor', [0.2 0.2 0.2], 'FaceAlpha', 0.9);
% 또는 매끈한 면: surf(ax, X, Y, Z, 'EdgeColor', 'none'); shading(ax, 'interp');
colormap(ax, 'parula');
zlabel(ax, 'Magnitude (unit)');           % z축이 값을 나타냄 → colorbar 불필요
```

- `mesh` instead of `surf` for pure wireframe.
- Add `lighting gouraud` + `camlight` only if it improves readability; keep it subtle.

## Point cloud / scattered points

Measured or sampled 3-D points → `scatter3` colored by value, described by a colorbar (not a legend):

```matlab
scatter3(ax, px, py, pz, 14, pz, 'filled');   % 4번째 인자 = 색 = 값 (z와 동일 → 강조용)
clim(ax, [cmin, cmax]);                        % 여러 패널이면 색 범위 통일
% z축이 값을 나타내므로 colorbar 불필요
```

For a single discrete series with a fixed color, use `'MarkerFaceColor'`/`'MarkerEdgeColor'` from `colorOrder` instead of value-coloring.

## Curves in 3-D

```matlab
plot3(ax, x, y, z, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
```

## Comparing views / representations

To compare viewpoints or representations (e.g. surface vs point cloud), use `subplot(2,2,k)` panels of the **same field**: keep identical `clim`/limits across panels and vary only `view` (iso `view(30,15)` vs top-down `view(0,90)`). In dense multi-panel layouts, reduce the font from 24 for legibility.

## Legend / colorbar

- **No colorbar by default** — when the z axis already encodes the value, a colorbar is redundant; put the unit on `zlabel` instead.
- Add a colorbar **only** when color maps an independent quantity (a 4th variable not on the z axis); then label it with that quantity's unit.
- Use a legend only when discrete `plot3` series coexist; the ≤6 legend cap is relaxed here — name only entries that aid reading.
