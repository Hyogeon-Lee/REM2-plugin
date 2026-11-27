# Tailoring a vault

The bundled `scripts/build_db.py` builds the default described in SKILL.md. Each section below covers one change users ask for and the smallest edit that gives it. The edits go into `00_candidates.json` or into the copy of `build_db.py` inside the user's vault; the bundled script stays as it is. After editing a vault copy, run it once on the user's data and check one note, the Base and the canvas.

## Grouping other than research claims

`tracks` is an ordered set of labels, and the script attaches no meaning to them. Method families, application areas, periods or research groups work the same way as claims:

```json
"tracks": {"N": "2023–", "M": "2018–2022", "O": "–2017"}
```

- A paper can carry several keys. It shows up in every matching Base view and in the canvas group of its key that comes first in the `tracks` object (not first in the paper's own array).
- List first the group that should hold a paper carrying several keys.
- When the grouping follows a field such as `year`, derive each paper's key from that field while writing the entries.
- Regrouping a vault that already has a canvas: placed cards stay in their old groups and the Base keeps the old track views. Delete `00_Map.canvas` (hand layout and edge labels are lost, so ask first) and an uncustomised `00_Database.base`, then re-run; or move the cards by hand.

## Labels and language

The Korean UI strings are in the vault copy of `build_db.py`:

| Where | Strings |
|---|---|
| `HAS_PDF` | status written when the PDF is present (`다운로드 완료`) |
| `auto_block()` | `트랙`, the callout titles `넣은 이유 · 핵심 수치` and `그림 후보: …`, `이유`, `수치` |
| `read_note()` | the memo heading `## 메모` of new notes |
| `write_base()` | view names `그림 갤러리`, `트랙 <key>: …`, `전체 목록`, and the `names` display-name map |
| `main()` | the `PDF 있으나 대표 그림 없음` line |

The Base is written once, and its gallery filters compare `status` with the `HAS_PDF` text. Change `HAS_PDF` before the first run; after it, also change the filter strings in `00_Database.base`, or delete an uncustomised Base and re-run. The `status` values in the JSON (`대기`, `접근 불가`) are free text. Translate the vault's `00_Guide.md` as well when its readers need another language.

## Extra fields per paper

Add the key to each entry in `00_candidates.json`, then in the vault copy:

- As a property (filterable and sortable in the Base): add it to the `new` dict in `main()` and its name to `MANAGED`. Without the `MANAGED` entry, the value already in the note wins over the JSON from the second run on, because kept properties are merged over the generated ones.
- In the note body: add a line in `auto_block()`.
- On the cards: add `note.<key>` to a card view's `order` in `00_Database.base`, or in `write_base()` before the first run.

## Switching outputs off

- No Base: delete the two lines `if not BASE.exists():` / `write_base(tracks)` in `main()`. Deleting `00_Database.base` alone does not last, because the script writes it again whenever it is missing.
- No canvas: replace `added, linked = update_canvas(with_cover, tracks, by_id)` with `added = linked = 0`.
- Notes only: both of the above.

## Other card pictures

| Wanted on the card | How |
|---|---|
| Device or prototype photo, system overview | Default; pick from the auto candidates with `hw` |
| A result plot or another vector figure | Not extracted automatically; crop it by hand as `_c7` or higher (`references/figures.md`) |
| The first page | Hand crop of page 0 with `clip=page.rect` |
| No picture | `hw: []` in each note after the first run, or, for the whole vault, `fm["hw"] = []` instead of `fm["hw"] = sorted(cands)[:2]` in the vault copy. The canvas takes only papers with a cover; to place every paper, call `update_canvas(papers, tracks, by_id)` instead of `update_canvas(with_cover, tracks, by_id)` |

## Inside an existing vault

Obsidian resolves the canvas `file` paths and the Base `file.inFolder()` filter from the vault root, while the script writes them relative to its own folder. That is why the default is a standalone vault. To keep the DB in a subfolder `<sub>` of a bigger vault (path from that vault's root, e.g. `Research/Papers`), change three places in the vault copy before the first run:

1. `note_rel()`: `return f"<sub>/detail/{db_name(p)}.md"`. The canvas uses this path.
2. In `main()`: `path = NOTES / f"{db_name(p)}.md"`, so notes are still written below the script's folder.
3. In `write_base()`: `'file.inFolder("<sub>/detail")'` (or the same filter in an existing `00_Database.base`).

Run the script from `<sub>`. The path budget it prints then applies to the full path of `<sub>`. A canvas built before the change holds the old paths; delete its file cards and re-run.

Copy the template without `.obsidian/` (the host vault's own settings apply), check that Bases and Canvas are enabled in the host vault (Settings → Core plugins), and rewrite the guide's "이 폴더 자체가 Obsidian vault다" paragraph and its "Base가 비어 있음" row.

## PDF sourcing

Ask once per DB and record the answer in the vault's `00_Guide.md`, so later sessions follow it without asking.

- The user supplies every PDF (bundled default). Papers without one stay in the table view, with the reason in `status` and `status_note`.
- When the user asks Claude to look for open-access copies: arXiv, the publisher's open-access version, or `best_oa_location.pdf_url` from OpenAlex (`https://api.openalex.org/works/doi:<doi>`). Save each in `pdf/` under its exact `filename`. Paywalled copies stay with the user, since publisher terms and institutional quotas apply to them.
