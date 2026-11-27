---
name: obsidian-research-db
description: Build and maintain an image-first prior-research (literature) database as an Obsidian vault, shaped to what the user needs it for. The default is one note per paper with a cover cut from its own PDF, a Bases card gallery, and a Canvas map grouping papers and drawing their relations, generated from one JSON list by a re-runnable script. Use whenever the user wants to organize prior work / related work / reference papers in Obsidian, turn a folder of paper PDFs into a visual DB, add new papers or PDFs to such a DB, pick or crop representative figures, or lay papers out on a canvas by claim, topic or relation, even if they do not say "Bases" or "Canvas" — including korean requests like 선행 연구 DB 구축, 옵시디언 선행연구 정리, 논문 DB 만들기, 옵시디언 논문 DB, 논문 갤러리, 대표 그림 넣기, 캔버스 지도, 관련 연구 연결 관계, 00_Guide.md 규칙대로 논문 추가. Not for formatting a single Obsidian note (obsidian-markdown) or writing literature-review prose.
---

# Obsidian Research DB

Requires: Python 3.9+, `pip install pymupdf pyyaml`, Obsidian 1.9+ (Bases core plugin).

## The idea, and the bundled default

People remember a paper by its device or system picture far longer than by its title, and they understand a field by seeing which papers back which point. The bundled template and `scripts/build_db.py` implement one way of showing both:

| View | File | What the reader gets |
|---|---|---|
| Card gallery | `00_Database.base` | One card per paper with a PDF, showing 1–2 figures from that paper; one view per track; a table of every paper |
| Map | `00_Map.canvas` | Cards grouped by track, with an edge for every `related` pair |
| Paper note | `detail/DB_<PDF name>.md` | Cover, metadata, why the paper is in the DB, key numbers, figure candidates, the reader's own memo |

`00_candidates.json` (tracks + papers) is the single source of truth, and `build_db.py` regenerates everything else from it, so the DB stays consistent past 100 papers. Every user's DB serves a different purpose, so this default is a starting point to adjust with the user, not a specification.

## Ask before building

What the DB is for decides which papers go in, what a card shows, how the map is grouped and whether Claude fetches PDFs. These are the user's decisions, and changing them after 100 notes exist costs far more than asking first. Before creating any file:

1. Collect what is already known: the request itself, the PDF folder if one is named, and for an existing vault its `00_Guide.md` and `00_candidates.json`, which record the decisions made for that DB.
2. Ask the questions that are still open, in one message, with the bundled default next to each, so the user can accept most defaults in one word. Put first the questions without a default and the ones that are expensive to change later (purpose, grouping, card picture); list the rest as defaults to accept or change.
3. Restate the resulting plan in a few lines (vault folder, groups, card picture, extra fields, outputs, PDF source). When questions were asked, start building after the user agrees. When the request already settles everything (for example a named folder plus "use the defaults"), state the plan and build without another round.

| Question | Why it matters | Bundled default |
|---|---|---|
| What is the DB for, and who reads it? (thesis related-work chapter, review paper, lab onboarding, a personal reading list) | Decides which papers belong and how much text a note needs | Prior research behind the user's own thesis or paper |
| Where do the papers come from? (PDFs in a folder, DOIs or a reference list, a Zotero/BibTeX export) | Decides whether collecting metadata or PDFs is part of the job | — |
| Should Claude look for open-access PDFs, or does the user supply every PDF? | Publisher terms and institutional download quotas are the user's to manage | The user supplies PDFs; papers without one stay in the table view |
| What should a card show? (device or prototype photo, system diagram, a key result figure, the first page) | Decides which figures become the cover; result plots are usually vector graphics that need manual crops | Device photo, else system overview; 1–2 figures |
| How should papers be grouped? (research claims, method family, application, period, research group) | Becomes `tracks`; of a paper's tracks, the one that comes first in the `tracks` object decides its canvas group | Claims, novelty first: `[Novelty]`, `[한계]`, `[선행 연구]` |
| Which relations matter? (follow-up, same lab, same mechanism, compared against) | Becomes `related`, one undirected edge per pair; the user can label edges on the canvas | Direct relations only, unlabelled |
| Which outputs? (Canvas, Base, both, notes only) | Unwanted outputs are switched off in the vault's copy of the script | Both |
| Label language? | UI strings live in the vault's copy of the script and guide | Korean |
| A new standalone vault, or inside an existing vault? Where on disk? | Canvas and Base paths are vault-relative; Windows paths stop at 259 characters | A new folder opened as its own vault |
| Extra fields per paper? (sensor type, DOF, dataset, …) | Each becomes a JSON key, and a property or note line if wanted | The fields in `references/candidates-schema.md` |

A question the request already answers needs no asking. For an existing vault, ask only what its guide leaves open, typically the PDF source when a paper arrives without one.

## Building

1. Copy `assets/template/` (including `.obsidian/`) and `scripts/build_db.py` into the vault folder. That copy of the script belongs to the vault.
2. Apply the answers. Groups go into `tracks` in `00_candidates.json`. Labels, extra fields, switched-off outputs and a subfolder location are edits to the vault's copy of `build_db.py`, described in `references/tailoring.md`. The bundled `scripts/build_db.py` changes only for a bug that affects every vault, because an option added there for one user makes every other copy harder to read.
3. Add papers to `papers` (fields, filename rule, dedupe: `references/candidates-schema.md`) and obtain PDFs the way the user chose. PDFs from a folder the user named are copied into the vault under their `filename`; the originals stay where they are.
4. Run `python build_db.py` in the vault root and read the output: `notes N, covers M, canvas +K cards +E edges`, the Windows path budget, and the list of PDFs without a usable cover.
5. Review the covers against the card picture the user asked for (see Covers), then re-run.
6. Fill `related` with the relation kinds the user named, then re-run to add the edges.
7. Fill the `## 이 DB의 결정 사항` table at the top of the vault's `00_Guide.md` with the user's answers (purpose and readers, grouping, card picture, relations, PDF source), and change any guide section the tailoring affected. Later sessions and labmates read this file instead of asking again.
8. Tell the user to open the vault folder itself with "폴더를 보관함으로 열기" (Open folder as vault). Opened from a parent folder, the Base stays empty and canvas cards break, unless the subfolder setup in `references/tailoring.md` was applied.

## Adding papers to an existing DB

The vault's `00_Guide.md` lists the steps (dedupe, JSON entry, PDF, run, cover review) and the decisions made for that DB. When several PDFs arrive at once, match each to an entry by DOI or title. Duplicates (same DOI, or byte-identical files) are removed only after telling the user which ones.

## Covers

The first run cuts up to 6 raster figures per PDF into `img/DB_<name>_c1..c6.jpg` and puts the two best-scored numbers into the note's `hw` property. The score favours large, colourful figures on early pages and cannot tell what a figure shows, so open the candidates (Read tool on the jpgs) and set `hw` to the figures that match the card picture the user chose. When no candidate fits, a hand crop saved as `img/DB_<name>_c7.png` with `hw: [7]` becomes the cover. Scoring, cover geometry and crop recipes, including scanned PDFs: `references/figures.md`.

## How the generator behaves

These are properties of the bundled `build_db.py`. A tailored copy keeps them unless it was changed on purpose.

| Behaviour | Consequence |
|---|---|
| Managed properties (`title aliases authors year venue tracks tier status doi url pdf cover related`) are rewritten from the JSON on every run. | Corrections belong in the JSON; edits to these properties inside a note are lost. |
| The block between `<!-- auto:start -->` and `<!-- auto:end -->` is rewritten; text below `<!-- auto:end -->` and every other property, `hw` included, is kept. | Memos go below the auto block; `hw` chooses the cover. |
| Every file name derives from `filename`: note `DB_<filename − .pdf>.md`, images `DB_<…>_cN`, cover `DB_<…>_cover.jpg`. | Renaming the note alone creates a second note on the next run; renaming the PDF alone makes the paper count as having no PDF. The JSON value, PDF, note and images are renamed together. |
| Figure candidates are extracted only for a paper that has no `DB_<name>_cN` file yet. | A hand crop added before the first run blocks auto extraction for that paper. |
| `00_Database.base` is written only when it does not exist. | A new track needs its view added by hand, or an uncustomised Base deleted and the script re-run. |
| The canvas only grows: missing cards go into the first free slot of their group (5 columns, 440 × 400), missing `related` edges are added. Existing edges are never changed or removed; existing cards are never removed or moved sideways. When a group gains a row, the nodes below its columns move down by one row, together with the cards of any group that moves; a group placed beside it stays where it is. A new card finds its group by the label `<key> · <track text>`. | Edge labels and a hand layout survive, whether groups are stacked or side by side. Moved nodes are not checked against unmoved nodes below them, so groups that only partly overlap in width can end up overlapping. After a track's text changes, the next new card of that track creates a second group unless the canvas label is renamed to match. A card or `related` edge deleted on the canvas comes back on the next run. |
| Only papers with a cover go on the canvas; the gallery and track views show only papers whose PDF is in `pdf/`. | Papers without a PDF appear in the table view only. |
| PDFs in the vault root are moved to `pdf/` unless that name already exists there; no file is ever deleted. | Removing a paper means deleting its JSON entry, any `related` references to it, its note, images, PDF and canvas card by hand. |
| Invalid input (missing required key, unknown track, unknown `related` id, duplicate `id` or `filename`) stops the run with an error list before any note, image, Base or canvas is written (the folders are already created and root PDFs already moved by then). | The fix goes into the JSON, not the script. |
| The run prints the longest path inside the vault and the resulting maximum length of the vault folder path (Windows limit 259). | The user needs that number before copying or moving the vault. A 150-character `filename` leaves 95 characters for the vault folder path. |

## Validation

`python scripts/selftest.py` builds a throwaway vault from the template with synthetic PDFs, runs the generator twice, and checks notes, covers, Base views, canvas groups and edges, a side-by-side group staying in place while its neighbour grows, preservation of user edits, and the input-error path. Run it after any change to the bundled script.

## References

- `references/tailoring.md`: grouping other than claims, labels and language, extra fields, switching outputs off, other card pictures, a DB inside an existing vault, PDF sourcing
- `references/candidates-schema.md`: `00_candidates.json` structure, fields, filename rule, dedupe, an entry template
- `references/figures.md`: candidate scoring, cover geometry, choosing `hw`, manual crops and scanned PDFs
- `assets/template/00_Guide.md`: the in-vault guide for people who add papers later (Korean)
