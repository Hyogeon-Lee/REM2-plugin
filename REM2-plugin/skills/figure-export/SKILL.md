---
name: figure-export
version: 0.3.0
description: prepare and export MATLAB figures for journal submission — exact column-width sizing in centimeters, print-size fonts, vector pdf via exportgraphics, and grayscale-survivable curve discrimination (line styles + markers, never color alone). includes journal presets (ieee transactions — default, elsevier) loaded on demand. use when the user asks for paper/journal/submission/camera-ready figures, names a journal (tmech, tie, tec, tim, tte, mechatronics, precision engineering, sensors and actuators, jsv, ijmtm), mentions column width, or says 논문용/제출용/투고용 figure. complements plot-style: plot-style governs what is in the axes, this skill governs physical size, fonts at print scale, grayscale check, and the export itself. not for lab reports, slides, or on-screen review figures.
---

# Figure Export (journal submission)

## Priority

User instructions override every default here. When both this skill and `plot-style` apply, **plot-style governs axes content** (labels, units, limits, ticks, grid, legend logic, series cap, no title, English figure text / Korean comments) and **this skill overrides the physical values**: figure size, font size, line widths, aspect ratio, the color order (replaced by a lightness-spread palette for grayscale survival), and the save/export block. When modifying user code, preserve existing variable names and return the complete updated script — "complete script" governs code emitted in the response; in an agent harness with file access, edit the file in place instead.

## How to use

1. Pick the **journal preset** and load its module (each inherits Common below and overrides only what it lists):

| Target | Module |
|---|---|
| IEEE Transactions (TMECH, TEC, TIE, TIM, TTE, …) — **default when unspecified** | [`references/ieee.md`](references/ieee.md) |
| Elsevier (Mechatronics, Precision Engineering, Sensors and Actuators A, JSV, IJMTM, …) | [`references/elsevier.md`](references/elsevier.md) |

2. Apply every **Common rule** below.
3. Check the MATLAB release before emitting version-gated arguments — `'GridLineWidth'` is R2023a+ and `exportgraphics` `'Padding'` is R2025a+; gate both with `isMATLABReleaseOlderThan` exactly as the snippets below do (the gate function itself needs R2020b+, which becomes the effective floor).
4. Run the **Export → review → revise** loop (bottom of this file) — including the grayscale pass. Never report a journal figure done from code alone.

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
% ax = 플롯이 들어있는 축 핸들 (플롯 시 ax = axes(fig); 로 생성한 것)
set(ax, 'Units', 'normalized');
for fillIter = 1:2
    drawnow;
    ti = get(ax, 'TightInset');
    set(ax, 'Position', [ti(1), ti(2), 1 - ti(1) - ti(3), 1 - ti(2) - ti(4)]);
end
drawnow;
```

If a computed width (`1 - ti(1) - ti(3)`) or height (`1 - ti(2) - ti(4)`) comes out ≤ 0, the insets have swallowed the canvas — abandon the fill loop and switch to the tiledlayout path below.

**Validity limit:** the loop works only on a single plain 2-D axes with the legend **inside** it and no colorbar — `TightInset` ignores legends and colorbars, so the fill reclaims their reserved space and silently pushes them off-canvas (verified: a `northoutside` legend lands above the figure and vanishes from the export). `yyaxis`, 3-D axes (`view(3)`, `surf`), and colorbars — inner ones included — also invalidate the fill loop. In every such case, wrap the axes in `tiledlayout(1, 1, 'Padding', 'tight')` instead.

For multi-panel figures, likewise skip the per-axes fill and use a `tiledlayout` with `'Padding','tight','TileSpacing','compact'`.

## Fonts at print scale

- One rule, every preset: target **8 pt** at final print size; **hard fail below 7 pt** after export — no text in the exported figure may measure under 7 pt.
- Pin label sizes exactly — MATLAB scales axis labels by 1.1 by default:

```matlab
set(ax, 'FontSize', fontSize, 'FontName', fontName, ...
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);
```

- One font size for everything in the figure (labels, ticks, legend, panel labels). If text crowds at the preset size, the figure is overloaded — split panels or drop series; never shrink below the 7 pt hard floor.

## Grayscale-survivable discrimination

Color is free — use it for on-screen readability — but it must **never be the only discriminator**. The figure must read correctly printed in black and white:

- **1st discriminator: line style.** Curves 1–4 get `lineStyles{k}`, no marker.
- **2nd discriminator: markers.** From the 5th curve (when line styles start repeating), add `markerSet` markers thinned with `MarkerIndices` — never a marker on every sample of a dense signal:

```matlab
ci = mod(k-1, size(colorOrder, 1)) + 1;               % 색 순환 — colorOrder 행 수 초과 시 index 에러 방지
if k <= 4
    plot(ax, t, y, 'LineStyle', lineStyles{k}, 'Color', colorOrder(ci, :), 'LineWidth', lineWidth);
else
    idx = unique(round(linspace(1, numel(t), min(numMarkers, numel(t)))));         % 마커 솎기 — 촘촘한 신호에 전체 마커 금지
    idx = unique(min(idx + round((k-5)*numel(t)/(2*numMarkers)), numel(t)));       % 곡선별 오프셋 — 인접 곡선 마커 겹침 방지
    plot(ax, t, y, 'LineStyle', lineStyles{mod(k-1, 4) + 1}, 'Color', colorOrder(ci, :), 'LineWidth', lineWidth, ...
         'Marker', markerSet{mod(k-5, numel(markerSet)) + 1}, 'MarkerIndices', idx, 'MarkerSize', 3);
end
```

- The `unique(... min(numMarkers, numel(t)) ...)` form keeps `MarkerIndices` valid for short signals (`numel(t) < numMarkers`) — duplicate and out-of-range indices are what break it.
- **Log-x data** (Bode/FRF): linear index spacing bunches every marker at the right edge — use log-spaced indices instead, e.g. `idx = unique(round(logspace(0, log10(numel(t)), min(numMarkers, numel(t)))));` (`t` = the plotted abscissa vector, same as the canonical snippet).
- **Curves 5+:** the per-curve offset (`(k-5)` term above) staggers markers so adjacent curves' markers do not stack at identical abscissae.

- Practical cap: **6 curves per axes** (same as plot-style's series cap). The `mod` wrap above only prevents the index error — beyond 6 curves, split panels or drop series instead of inventing a 7th style combination.

- The style block's `colorOrder` spreads **lightness** deliberately — a bonus discriminator after grayscale conversion. Keep it instead of plot-style's palette.
- The grayscale pass in the review loop verifies this on the actual rendered image.

## Vector vs raster

- Line plots, Bode/FRF, schematics → **vector PDF** (`ContentType','vector'`). Infinite zoom, small file.
- Heatmaps, FEA contours, `surf`/`pcolor` with many faces, photographs → **raster** at the preset dpi. A 100k-polygon vector PDF chokes the publisher's renderer.
- **Preview dpi vs submission dpi — two different numbers.** The preview PNG is **always 600 dpi**: it is a review artifact for the grayscale/size checks, never a submission file, and its resolution does not change with the preset. **Submission raster** files take their dpi from the journal preset table instead (IEEE 600 line/combination, 300 photo; Elsevier 1000 line, 500 combination, 300 photo). Never bump the preview to the submission dpi, and never ship the 600 dpi preview (e.g., a heatmap) as the submission file.
- **Mixed line-art + dense-surface figures:** MATLAB cannot rasterize a single panel — `exportgraphics` applies one `ContentType` to the whole figure. Pick one: (a) export the whole figure with `'ContentType', 'image'` at the preset combination-art dpi (IEEE 600 / Elsevier 500), (b) export the panels as separate files and assemble in LaTeX, or (c) `'ContentType', 'auto'` and verify in the PDF what it actually produced. Such figures usually carry a colorbar, so the TightInset fill loop is invalid there — use the `tiledlayout` path.

```matlab
% 출력 폴더 + 의미 있는 파일명
if ~exist('image_fig', 'dir'); mkdir('image_fig'); end
outDir  = 'image_fig';
figName = 'step_response_comparison';        % 의미 있는 이름으로 (제출 시 figN으로 개명)
ax.Toolbar.Visible = 'off';                  % 마우스 호버 시 axes toolbar가 내보내기에 섞이는 것 방지

% 제출용 벡터 PDF + 검토용 PNG — 'Padding', 0: 기본 여백 제거 (R2025a+, 구버전은 자동 생략)
padArgs = {};                                % 버전 게이트 — R2025a 미만에는 'Padding' 인수가 없음
if ~isMATLABReleaseOlderThan("R2025a")
    padArgs = {'Padding', 0};
end
exportgraphics(fig, fullfile(outDir, [figName '.pdf']), 'ContentType', 'vector', padArgs{:});
exportgraphics(fig, fullfile(outDir, [figName '_preview.png']), 'Resolution', 600, padArgs{:});

% 치수 자가 검증 — 600 dpi PNG 픽셀 수로 실제 내보낸 크기 확인
info = imfinfo(fullfile(outDir, [figName '_preview.png']));
fprintf('exported: %.2f x %.2f cm (target %.2f x %.2f cm)\n', ...
        info.Width/600*2.54, info.Height/600*2.54, figWidth, figHeight);
```

`exportgraphics` embeds fonts — prefer it over `print -depsc`/`saveas`. Without `'Padding', 0` it adds a fixed ~3 pt margin (verified on R2025b: 9.00 cm from an 8.89 cm canvas); on MATLAB older than R2025a the argument does not exist — the `padArgs` gate above drops it automatically; absorb the resulting ~1% oversize with `width=\columnwidth` in LaTeX. Always keep the `imfinfo` self-check — it catches sizing mistakes the live window hides.

**Exact-width acceptance:** the measured exported width must land within **1%** of the preset target. If it is outside, adjust (padding gate, canvas fill) and re-export — **one iteration**; if it is still outside after that, report the discrepancy (measured vs target, in cm) instead of looping.

R2025a also added `'Width'`/`'Height'`/`'Units'` name-values to `exportgraphics`, but they **scale the rendered content** to the requested size rather than resizing the canvas (verified on R2025b: `'Width', 8.89, 'Units', 'centimeters'` scales a 7.80 cm tight crop uniformly ×1.14, width and height alike — an 8 pt font prints at ~9.1 pt). That breaks the draw-at-final-size rule, so keep the TightInset fill loop and do **not** substitute `'Width'` for it.

## In-figure content

- **No title** ever — the caption lives in the manuscript, not the figure.
- Axis labels with units in parentheses (`Time (s)`, `Torque (N·m)`); all figure text in English.
- **Text interpreter:** keep the default `tex`. TeX math glyphs (`\zeta`, `\omega_n`, `x_{ab}`) render in MATLAB's math font, not `fontName` — acceptable for isolated symbols; when a whole label must stay in one font, prefer Unicode characters (ζ, ω), which inherit `fontName`. Switch to `'Interpreter', 'latex'` only on explicit request — it replaces the mandated font with Computer Modern: `FontName`/`FontWeight`/`FontAngle` are ignored, but `FontSize` **is** honored; use `\fontsize{}` inside the string only when one string needs mixed sizes.
- Multi-panel figures: label panels `(a)`, `(b)`, … at the same `fontSize`, placed consistently in a **data-empty spot** — lower-left inside the axes or below the panel; top-left collides with rising/overshooting curves. The caption references them.

```matlab
% 패널 라벨 — 데이터 없는 곳에 (좌하단 안쪽; 좌상단은 곡선과 충돌 위험)
text(ax, 0.03, 0.08, '(a)', 'Units', 'normalized', 'FontSize', fontSize, 'FontName', fontName);
```
- Same variable = same line style and color **across every figure in the paper**; compared quantities share axis limits across figures.

## Export → review → revise (run for every figure)

1. **Draft** with Common + preset rules, export PDF + 600-dpi preview PNG into `image_fig/`.
2. **Grayscale pass** — convert the preview and save it for review:

```matlab
% 흑백 인쇄 생존성 확인용 회색조 변환본 — Image Processing Toolbox 불필요
rgb = imread(fullfile(outDir, [figName '_preview.png']));
if exist('im2gray', 'file')                    % im2gray 있으면 사용
    grayImg = im2gray(rgb);
else                                           % 없으면 수동 luma 변환 (ITU-R BT.601)
    grayImg = uint8(0.2989*double(rgb(:,:,1)) + 0.5870*double(rgb(:,:,2)) + 0.1140*double(rgb(:,:,3)));
end
imwrite(grayImg, fullfile(outDir, [figName '_gray.png']));
```

No toolbox is required for this step — do not reach for `rgb2gray`; use `im2gray` when present, the manual luma fallback otherwise.

3. **Review** both PNGs (via the MATLAB MCP / image read-back): every curve distinguishable **in the grayscale image**; no clipped data, legend overlap, or text collision at print size; no text below the 7 pt hard floor; the `imfinfo` size self-check within 1% of the preset column width (outside → adjust and re-export once, then report the discrepancy instead of looping).
4. **Fix vs ask.** Fix unambiguous violations directly (color-only discrimination, wrong size, font too small, marker flooding). Ask only when the fix changes interpretation (which curves to drop when overloaded, single vs double column for a wide layout).
5. **Revise once**, re-export, re-review. If violations remain after one pass, list them with suggested fixes instead of looping.

**Fallback when no MATLAB MCP:** still emit the full export + grayscale block, self-check the code against every Common rule, state the image was **not** visually verified, and list what the user must check by eye (grayscale distinguishability first).

## Output behavior

- Editing existing code → return the complete revised script. This governs code emitted **in the response** (never a diff); in an agent harness with file access, edit the file in place instead of pasting the whole file back.
- New code → include the full style block, export block, and grayscale block inline so the figure is submission-ready with no manual edits.
- At actual submission time, rename to the journal's scheme (`fig1.pdf`, `fig2.pdf`, …) — keep descriptive names during work.
