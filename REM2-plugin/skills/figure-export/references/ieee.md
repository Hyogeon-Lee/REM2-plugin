# Preset: IEEE Transactions

Default preset. Applies to all IEEE Transactions two-column templates — including the lab's venues: IEEE/ASME Trans. Mechatronics (TMECH), Trans. Energy Conversion (TEC), Trans. Industrial Electronics (TIE), Trans. Instrumentation & Measurement (TIM), Trans. Transportation Electrification (TTE). Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/figure_export_example.m`](../examples/figure_export_example.m)

## Dimensions

```matlab
figWidth = 8.89;     % single column: 3.5 in = 8.89 cm — 기본값
% figWidth = 18.16;  % double column: 18.16 cm — 가로로 긴 다중 패널일 때만
```

- **Single column is the default.** Use double column only when the content genuinely needs the width (≥3 side-by-side panels, long time histories); ask before switching — it changes page layout.
- Height: 0.6–0.75 × width typical (single column ≈ 5.3–6.7 cm). Hard ceiling: text height 23.5 cm minus caption.

## Fonts

- `Times New Roman` — matches the IEEE body font. Helvetica/Arial acceptable for figures but do not mix within a paper.
- Target **8 pt** at final size; IEEE's readable floor is ~6 pt — treat anything that needs <7 pt as a layout problem.

## Files

- **Vector PDF** for line art (the Common default). EPS also accepted.
- Raster panels: **600 dpi** for line/combination art, **300 dpi** for photographs.
- Submission naming: `fig1.pdf`, `fig2.pdf`, … one file per figure; multi-panel `(a)(b)` panels stay in one file.

## Notes

- IEEE redraws nothing — what you submit is what prints. The grayscale pass matters here: print IEEE Xplore PDFs default to color, but print editions and reader printouts are commonly grayscale.
- Caption is set by the template (8 pt) in the manuscript — never bake caption text into the figure.
