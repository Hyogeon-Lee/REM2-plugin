# Figures: candidates, covers, manual crops

## Automatic candidates

`extract_candidates()` runs once per paper, only when `img/` holds no `DB_<name>_cN` file for it.

1. Pages searched: the first 6 pages, excluding the last page when the PDF has 3 or more pages (references, author bios). Later pages are searched only if the first pass finds nothing.
2. Every placed raster image on those pages is a candidate unless it is
   - larger than 85 % of the page (a scanned page, not a figure),
   - smaller than 2 % of the page or with either side shorter than 60 pt (logo, icon, author photo),
   - under more than 80 words of text (a background image behind body text).
3. Score:

   ```text
   score = A · (1 − u_top) / (1 + 0.2 · p)
   ```

   - `A`: image area on the page in pt²; large figures are usually the main device or system figure.
   - `u_top`: share of the most frequent colour in a 40-dpi render (`Pixmap.color_topusage()`); a photo has many colours (small `u_top`), a line drawing or mostly white diagram has one dominant colour (large `u_top`).
   - `p`: zero-based page index; the hardware figure tends to be on page 1–3, so the score is divided by 1 + 0.2 · p.
4. The top 6 are rendered at 120 dpi to `img/DB_<name>_c1.jpg` … `_c6.jpg` (JPEG quality 85).

Vector graphics (plots drawn with PDF paths) are not images and are never picked. A paper whose key figure is vector-only needs a manual crop.

## Cover

`make_cover()` scales each figure listed in `hw` to a height of 300 pt, places them left to right with an 8 pt gap, and renders the strip at 144 dpi to `img/DB_<name>_cover.jpg`.

The Base card shows covers with `imageFit: contain` and `imageAspectRatio: 0.5` (height = 0.5 × width), so a cover whose width is about twice its height fills the card. One landscape figure or two near-square figures give that shape; three or more figures shrink each one too much to recognise.

## Choosing `hw`

Look at the candidates before accepting the default `[1, 2]`. Pick by what the user wants a card to show, not by score. When the user chose no other card picture, the bundled default order is:

1. Photo of the device, prototype or experimental setup
2. System overview or mechanism diagram (if it is a raster figure)
3. A characteristic result image (e.g. a sensor image), only when nothing above exists

Plots, tables, block diagrams with mostly text, and photos of people rarely identify a paper at a glance. Other card pictures (a result plot, the first page): `references/tailoring.md`.

## Manual crop

Use numbers from 7 upward (`_c7`, `_c8`, …) so a crop never collides with the auto candidates 1–6. JPG and PNG both work.

### From a PDF with a text layer

```python
import pymupdf
doc = pymupdf.open("pdf/<filename>.pdf")
page = doc[2]                                   # zero-based page index
rect = pymupdf.Rect(60, 90, 540, 330)           # x0, y0, x1, y1 in pt, origin top-left
page.get_pixmap(clip=rect, dpi=200).save("img/DB_<name>_c7.png")
```

Find `rect` from the figure caption position (`page.search_for("Fig. 1")` returns its rect; the figure is usually just above the caption) or from the grid method below.

### From a scanned PDF (no text layer)

Every page is one big image, so automatic extraction finds nothing. Draw a labelled coordinate grid on an in-memory copy, look at it, and read the figure's bounding box off the grid:

```python
import pymupdf
doc = pymupdf.open("pdf/<filename>.pdf")        # changes below are never saved
page = doc[8]
W, H = page.rect.width, page.rect.height
for x in range(0, int(W), 50):
    page.draw_line((x, 0), (x, H), color=(1, 0, 0), width=0.3)
    page.insert_text((x + 1, 8), str(x), fontsize=6, color=(1, 0, 0))
for y in range(0, int(H), 50):
    page.draw_line((0, y), (W, y), color=(1, 0, 0), width=0.3)
    page.insert_text((1, y - 1), str(y), fontsize=6, color=(1, 0, 0))
page.get_pixmap(dpi=100).save("grid_p9.png")    # open this image, read x0, y0, x1, y1
```

Then crop from a freshly opened document (so the grid is not in the crop) with the rect read off the grid, as in the text-layer recipe. Delete the grid images afterwards.

Without Python, a screen capture works too (Win+Shift+S on the PDF at 200 % zoom or more), saved under the same `_c7.png` name.

After saving: set `hw: [7]` (or `[7, 8]`) in the note's properties and re-run `build_db.py`.
