# Preset: Elsevier

Applies to Elsevier journals — including the lab's venues: Mechatronics, Precision Engineering, Sensors and Actuators A: Physical, Journal of Sound and Vibration, Int. J. Machine Tools and Manufacture. Inherits all Common rules; overrides/adds below.

> Runnable before/after example: [`../examples/figure_export_example.m`](../examples/figure_export_example.m) — built with the IEEE preset; for Elsevier only the Dimensions block below differs.

## Dimensions

```matlab
figWidth = 9.0;      % single column: 90 mm — 기본값
% figWidth = 14.0;   % 1.5 column: 140 mm — 단일 칼럼에 안 들어가는 중간 폭
% figWidth = 19.0;   % double column: 190 mm
```

- Elsevier adds a **1.5-column** option IEEE lacks — prefer it over double column when single is too narrow; less page disruption.
- Max height: 24 cm minus caption.

## Fonts

- Elsevier accepts Arial/Helvetica, Times New Roman, Courier, Symbol. Keep `Times New Roman` for consistency with the lab default unless the journal's guide for authors says otherwise.
- Target **8 pt**, floor 7 pt at final size.

## Files

- Vector **PDF or EPS** for line art (the Common default).
- Raster panels — Elsevier's official minimums are higher than IEEE's: **1000 dpi** pure line art, **500 dpi** combination (line + halftone), **300 dpi** halftone/photo.
- Naming per the submission system (usually one file per figure, any descriptive name at first submission).

## Notes

- Elsevier prints online in color at no charge; print color may cost — the grayscale pass keeps the print edition readable either way.
- Check the specific journal's Guide for Authors before submission; a few (e.g. JSV) add their own artwork quirks.
