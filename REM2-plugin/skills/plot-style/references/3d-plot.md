# Case: 3-D plot

Surface, mesh, `plot3` curves, `scatter3`, fields/volumetric. Inherits all Common rules; overrides/adds below.

## Series count (override)

The Common ≤6 series cap **does not apply** here. 3-D plots often need more objects to convey spatial structure or highlight features, so plot as many as the scene requires. Still cycle the style-block color order, and keep the legend readable (legend only the entries worth naming; describe surfaces by colorbar, not legend).

## Aspect ratio

- Use **`daspect`** (data aspect), not `pbaspect`, so x/y/z scale to physical proportions.
- Spatial geometry with shared units → `daspect(ax, [1 1 1])` (`axis equal`).
- Otherwise pick a `daspect` that keeps the surface readable.

## Axes

- **Three labels**: `xlabel`, `ylabel`, `zlabel`, all with units in parentheses.
- Set `xlim`, `ylim`, `zlim` explicitly.
- Grid on (Common dashed/alpha) — keeps depth cues on all three planes.
- Set an explicit viewpoint: **default `view(ax, 30, 15)`** (azimuth, elevation); adjust to expose the feature of interest. State the chosen view in a comment.

## Surfaces / meshes

```matlab
surf(ax, X, Y, Z, 'EdgeColor', 'none');   % 큰 격자는 EdgeColor none
shading(ax, 'interp');
colormap(ax, 'parula');
cb = colorbar(ax);
ylabel(cb, 'Magnitude (unit)');           % 컬러바도 단위 표기
cb.FontSize = fontSize;
cb.FontName = fontName;
```

- `mesh` instead of `surf` for wireframe; `EdgeColor` from a single style-block color.
- Add `lighting gouraud` + `camlight` only if it improves readability; keep it subtle.

## Curves / points in 3-D

```matlab
plot3(ax, x, y, z, 'LineStyle', '-', 'Color', colorOrder(1, :), 'LineWidth', lineWidth);
scatter3(ax, x, y, z, sz, 'MarkerEdgeColor', colorOrder(2, :), 'LineWidth', 3);
```

## Legend / colorbar

- Surfaces are described by a **colorbar**, not a legend. Use a legend only when discrete `plot3` series coexist; the ≤6 legend cap is relaxed here, but only name entries that aid reading.
- Do not put both a dense legend and a colorbar competing for the same corner; prefer colorbar right, legend `northoutside`.
