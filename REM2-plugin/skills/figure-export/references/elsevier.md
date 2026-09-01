# Preset: Elsevier

Applies to Elsevier journals — including the lab's venues: Mechatronics, Precision Engineering, Sensors and Actuators A: Physical, Journal of Sound and Vibration, Int. J. Machine Tools and Manufacture. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/figure_export_example.m`](../examples/figure_export_example.m) — built with the IEEE preset; for Elsevier only the Dimensions block below differs.

## Dimensions

```matlab
% Elsevier 칼럼 폭 선택 — 패널 배치가 폭을 결정
numPanelsAcross = 1;               % 가로로 나란히 놓이는 패널 수
if numPanelsAcross >= 2
    figWidth = 14.0;               % 1.5 column: 140 mm — 나란한 패널 2개 이상이면 기본 선택
else
    figWidth = 9.0;                % single column: 90 mm — 패널 1개 또는 세로로 쌓일 때
end
% figWidth = 19.0;                 % double column: 190 mm — 1.5 column도 좁을 때만
figHeight = 0.7 * figWidth;        % 높이 — 폭의 0.6~0.75, 최대 24 cm - 캡션
```

- **Default choice:** **14 cm (1.5 column)** when the figure has ≥2 side-by-side panels; **single column (9 cm)** when panels stack vertically or there is one panel. This default is Elsevier-only — IEEE has no 1.5-column option and keeps its **ask-before-double-column** rule unchanged.
- Elsevier adds a **1.5-column** option IEEE lacks — prefer it over double column when single is too narrow; less page disruption.
- Max height: 24 cm minus caption.

## Fonts

- Elsevier accepts Arial/Helvetica, Times New Roman, Courier, Symbol. Keep `Times New Roman` for consistency with the lab default unless the journal's guide for authors says otherwise.
- Target **8 pt**; **hard fail below 7 pt** after export (same rule as Common and IEEE).

## Files

- Vector **PDF or EPS** for line art (the Common default).
- Raster panels — Elsevier's official minimums are higher than IEEE's: **1000 dpi** pure line art, **500 dpi** combination (line + halftone), **300 dpi** halftone/photo.
- These minimums apply to **submission raster files only**. The review preview PNG from Common stays at **600 dpi** regardless — it is a review artifact, never a submission file: do not bump the preview to 1000 dpi, and do not ship a 600 dpi heatmap as the submission raster.
- Naming per the submission system (usually one file per figure, any descriptive name at first submission).

## Notes

- Elsevier prints online in color at no charge; print color may cost — the grayscale pass keeps the print edition readable either way.
- Check the specific journal's Guide for Authors before submission; a few (e.g. JSV) add their own artwork quirks.
