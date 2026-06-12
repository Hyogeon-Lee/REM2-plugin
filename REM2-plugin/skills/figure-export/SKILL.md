---
name: figure-export
version: 0.1.0
description: prepare and export MATLAB figures for journal submission — exact column-width sizing in centimeters, print-size fonts, vector pdf via exportgraphics, and grayscale-survivable curve discrimination (line styles + markers, never color alone). includes journal presets (ieee transactions — default, elsevier) loaded on demand. use when the user asks for paper/journal/submission/camera-ready figures, names a journal (tmech, tie, tec, tim, tte, mechatronics, precision engineering, sensors and actuators, jsv, ijmtm), mentions column width, or says 논문용/제출용/투고용 figure. complements plot-style: plot-style governs what is in the axes, this skill governs physical size, fonts at print scale, grayscale check, and the export itself. not for lab reports, slides, or on-screen review figures.
---

# Figure Export (journal submission)

## Priority

User instructions override every default here. When both this skill and `plot-style` apply, **plot-style governs axes content** (labels, units, limits, ticks, grid, legend logic, series cap, no title, English figure text / Korean comments) and **this skill overrides the physical values**: figure size, font size, line widths, aspect ratio, the color order (replaced by a lightness-spread palette for grayscale survival), and the save/export block. When modifying user code, preserve existing variable names and return the complete updated script.

## How to use

1. Pick the **journal preset** and load its module (each inherits Common below and overrides only what it lists):

| Target | Module |
|---|---|
| IEEE Transactions (TMECH, TEC, TIE, TIM, TTE, …) — **default when unspecified** | [`references/ieee.md`](references/ieee.md) |
| Elsevier (Mechatronics, Precision Engineering, Sensors and Actuators A, JSV, IJMTM, …) | [`references/elsevier.md`](references/elsevier.md) |

2. Apply every **Common rule** below.
3. Run the **Export → review → revise** loop (bottom of this file) — including the grayscale pass. Never report a journal figure done from code alone.

---

# Common rules

## Size first — draw at final print size, never scale down

The single most common failure: drawing a large figure and letting LaTeX/Word shrink it, which wrecks fonts and line widths. Instead, create the figure at the **exact column width in centimeters** from the preset and design everything at that size:

```matlab
% 논문용 figure 스타일 (값은 프리셋에서 — 아래는 IEEE single column 기본값)
figWidth    = 8.89;                % 칼럼 폭 (cm) — 프리셋 값, 절대 임의 변경 금지
figHeight   = 6.0;                 % 높이 (cm) — 폭의 0.6~0.75 권장
fontSize    = 8;                   % 최종 인쇄 크기 기준 (pt)
fontName    = 'Times New Roman';
lineWidth   = 1.0;                 % 데이터 곡선 (pt) — 0.75 미만은 인쇄 시 끊김
axLineWidth = 0.5;                 % 축 박스·그리드 (pt)
gridStyle   = '--';
gridAlpha   = 0.25;
lineStyles  = {'-', '--', ':', '-.'};   % 흑백 구분 1순위
markerSet   = {'o', 's', '^', 'd', 'v', '>'};   % 흑백 구분 2순위 (5번째 곡선부터)
numMarkers  = 10;                  % 곡선당 마커 개수 (MarkerIndices로 솎기)
colorOrder  = [                    % 명도 간격 확보 — 회색조 변환 시 보조 구분 (plot-style colorOrder 대체)
    0,    0,    0;
    0.85, 0.10, 0.10;
    0,    0.20, 0.80;
    0.93, 0.60, 0;
    0.45, 0.45, 0.45;
    0,    0.60, 0.30
];

fig = figure('Units', 'centimeters', 'Position', [2 2 figWidth figHeight], 'Color', 'w');
```

- Aspect ratio is set by `figWidth`/`figHeight` — **do not** add `pbaspect` on top (it would shrink the axes inside the fixed canvas). This overrides the plot-style default.
- The figure will look tiny on screen. That is correct — judge it from the exported preview at zoom, not the live window.

**Fill the canvas before exporting.** `exportgraphics` crops to the content's tight bounding box — with MATLAB's default axes margins the exported file comes out ~1 cm *narrower* than `figWidth` (verified: 7.80 cm from an 8.89 cm canvas). After all plotting, labels, and legend are in place, expand the axes to fill the figure; run the inset fit twice because tick-label extents shift after the first move:

```matlab
% 축이 캔버스를 채우도록 — tight crop 후에도 내보낸 폭 = 칼럼 폭 유지
set(ax, 'Units', 'normalized');
for fillIter = 1:2
    drawnow;
    ti = get(ax, 'TightInset');
    set(ax, 'Position', [ti(1), ti(2), 1 - ti(1) - ti(3), 1 - ti(2) - ti(4)]);
end
drawnow;
```

**Validity limit:** the loop works only when the legend lives **inside** the axes and there is no colorbar — `TightInset` ignores both, so the fill reclaims their reserved space and silently pushes them off-canvas (verified: a `northoutside` legend lands above the figure and vanishes from the export). With an outside legend or a colorbar, wrap the axes in `tiledlayout(1, 1, 'Padding', 'tight')` instead.

For multi-panel figures, likewise skip the per-axes fill and use a `tiledlayout` with `'Padding','tight','TileSpacing','compact'`.

## Fonts at print scale

- Base `fontSize` from the preset (IEEE/Elsevier: **8 pt**); tick labels ≥ 7 pt, never below the preset minimum after export.
- Pin label sizes exactly — MATLAB scales axis labels by 1.1 by default:

```matlab
set(ax, 'FontSize', fontSize, 'FontName', fontName, ...
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);
```

- One font size for everything in the figure (labels, ticks, legend, panel labels). If text crowds at the preset size, the figure is overloaded — split panels or drop series; never shrink below the preset minimum.

## Grayscale-survivable discrimination

Color is free — use it for on-screen readability — but it must **never be the only discriminator**. The figure must read correctly printed in black and white:

- **1st discriminator: line style.** Curves 1–4 get `lineStyles{k}`, no marker.
- **2nd discriminator: markers.** From the 5th curve (when line styles start repeating), add `markerSet` markers thinned with `MarkerIndices` — never a marker on every sample of a dense signal:

```matlab
if k <= 4
    plot(ax, t, y, 'LineStyle', lineStyles{k}, 'Color', colorOrder(k, :), 'LineWidth', lineWidth);
else
    idx = round(linspace(1, numel(t), numMarkers));   % 마커 솎기 — 촘촘한 신호에 전체 마커 금지
    plot(ax, t, y, 'LineStyle', lineStyles{mod(k-1, 4) + 1}, 'Color', colorOrder(k, :), 'LineWidth', lineWidth, ...
         'Marker', markerSet{mod(k-5, numel(markerSet)) + 1}, 'MarkerIndices', idx, 'MarkerSize', 3);
end
```

- The style block's `colorOrder` spreads **lightness** deliberately — a bonus discriminator after grayscale conversion. Keep it instead of plot-style's palette.
- The grayscale pass in the review loop verifies this on the actual rendered image.

## Vector vs raster

- Line plots, Bode/FRF, schematics → **vector PDF** (`ContentType','vector'`). Infinite zoom, small file.
- Heatmaps, FEA contours, `surf`/`pcolor` with many faces, photographs → **raster** at the preset dpi. A 100k-polygon vector PDF chokes the publisher's renderer — rasterize those panels.

```matlab
% 출력 폴더 + 의미 있는 파일명
if ~exist('image_fig', 'dir'); mkdir('image_fig'); end
outDir  = 'image_fig';
figName = 'step_response_comparison';        % 의미 있는 이름으로 (제출 시 figN으로 개명)
ax.Toolbar.Visible = 'off';                  % 마우스 호버 시 axes toolbar가 내보내기에 섞이는 것 방지

% 제출용 벡터 PDF + 검토용 PNG — 'Padding', 0: 기본 여백 제거 (R2025a+)
exportgraphics(fig, fullfile(outDir, [figName '.pdf']), 'ContentType', 'vector', 'Padding', 0);
exportgraphics(fig, fullfile(outDir, [figName '_preview.png']), 'Resolution', 600, 'Padding', 0);

% 치수 자가 검증 — 600 dpi PNG 픽셀 수로 실제 내보낸 크기 확인
info = imfinfo(fullfile(outDir, [figName '_preview.png']));
fprintf('exported: %.2f x %.2f cm (target %.2f x %.2f cm)\n', ...
        info.Width/600*2.54, info.Height/600*2.54, figWidth, figHeight);
```

`exportgraphics` embeds fonts — prefer it over `print -depsc`/`saveas`. Without `'Padding', 0` it adds a fixed ~3 pt margin (verified on R2025b: 9.00 cm from an 8.89 cm canvas); on MATLAB older than R2025a the argument does not exist — drop it and absorb the ~1% oversize with `width=\columnwidth` in LaTeX. Always keep the `imfinfo` self-check — it catches sizing mistakes the live window hides.

## In-figure content

- **No title** ever — the caption lives in the manuscript, not the figure.
- Axis labels with units in parentheses (`Time (s)`, `Torque (N·m)`); all figure text in English.
- Multi-panel figures: label panels `(a)`, `(b)`, … at the same `fontSize`, placed consistently (below each panel or top-left inside); the caption references them.
- Same variable = same line style and color **across every figure in the paper**; compared quantities share axis limits across figures.

## Export → review → revise (run for every figure)

1. **Draft** with Common + preset rules, export PDF + 600-dpi preview PNG into `image_fig/`.
2. **Grayscale pass** — convert the preview and save it for review:

```matlab
% 흑백 인쇄 생존성 확인용 회색조 변환본
rgb  = imread(fullfile(outDir, [figName '_preview.png']));
imwrite(rgb2gray(rgb), fullfile(outDir, [figName '_gray.png']));
```

3. **Review** both PNGs (via the MATLAB MCP / image read-back): every curve distinguishable **in the grayscale image**; no clipped data, legend overlap, or text collision at print size; fonts not below the preset minimum; the `imfinfo` size self-check printout matches the preset column width.
4. **Fix vs ask.** Fix unambiguous violations directly (color-only discrimination, wrong size, font too small, marker flooding). Ask only when the fix changes interpretation (which curves to drop when overloaded, single vs double column for a wide layout).
5. **Revise once**, re-export, re-review. If violations remain after one pass, list them with suggested fixes instead of looping.

**Fallback when no MATLAB MCP:** still emit the full export + grayscale block, self-check the code against every Common rule, state the image was **not** visually verified, and list what the user must check by eye (grayscale distinguishability first).

## Output behavior

- Editing existing code → return the complete revised script.
- New code → include the full style block, export block, and grayscale block inline so the figure is submission-ready with no manual edits.
- At actual submission time, rename to the journal's scheme (`fig1.pdf`, `fig2.pdf`, …) — keep descriptive names during work.
