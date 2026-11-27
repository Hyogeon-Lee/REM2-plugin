"""Build an image-first prior-research database for Obsidian (Bases gallery + Canvas map).

Usage: python build_db.py [vault_dir]      (default: the folder this script is in)

Reads <vault>/00_candidates.json ({"tracks": {...}, "papers": [...]}) and the PDFs in pdf/
(PDFs dropped in the vault root are moved there), then writes:
  detail/DB_<PDF name>.md      one note per paper: frontmatter + auto block + your own notes
  img/DB_<PDF name>_cN.jpg     figure candidates cut from the PDF (only when none exist yet)
  img/DB_<PDF name>_cover.jpg  side-by-side composite of the candidates listed in `hw`
  00_Database.base             card gallery + one view per track (created once, then yours to edit)
  00_Map.canvas                track map (created once; later runs only append new cards and edges)
Re-run any time: text below the auto block and properties not listed in MANAGED are kept.
To change a paper's figures, edit its `hw` property (candidate numbers), or save your own crop
as img/DB_<PDF name>_c7.png and put 7 in `hw`, then re-run.
"""
import collections
import itertools
import json
import os
import pathlib
import re
import sys

import pymupdf
import yaml

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent
PDFS = ROOT / "pdf"
NOTES = ROOT / "detail"
IMG = ROOT / "img"
CANVAS = ROOT / "00_Map.canvas"
BASE = ROOT / "00_Database.base"
N_CAND, DPI = 6, 120
HAS_PDF = "다운로드 완료"  # status written to the note when the PDF is in pdf/
REQUIRED = ["id", "title", "year", "venue_abbrev", "tracks", "status", "filename"]
MANAGED = ["title", "aliases", "authors", "year", "venue", "tracks", "tier", "status", "doi", "url", "pdf", "cover",
           "related"]
AUTO_START, AUTO_END = "<!-- auto:start -->", "<!-- auto:end -->"


def extract_candidates(pdf, name):
    """Save the N_CAND most photo-like raster figures of the PDF. Vector plots are never picked."""
    doc = pymupdf.open(pdf)
    last = len(doc) - 1 if len(doc) > 2 else len(doc)  # last page: references / author bios
    found, seen = [], set()
    for pages in (range(min(6, last)), range(6, last)):  # widen to later pages only if needed
        for pno in pages:
            page = doc[pno]
            parea = page.rect.width * page.rect.height
            for info in page.get_image_info():
                r = pymupdf.Rect(info["bbox"]) & page.rect
                key = (pno, *(round(v) for v in r))
                area = r.width * r.height
                # >85 %: scanned page, <2 %: logo or author photo
                if key in seen or area > 0.85 * parea or area < 0.02 * parea or min(r.width, r.height) < 60:
                    continue
                seen.add(key)
                if len(page.get_text("words", clip=r)) > 80:
                    continue  # image lying under body text, not a figure
                top_share = page.get_pixmap(clip=r, dpi=40).color_topusage()[0]
                found.append((area * (1 - top_share) / (1 + 0.2 * pno), pno, r))
        if found:
            break
    found.sort(key=lambda c: -c[0])
    for i, (_, pno, r) in enumerate(found[:N_CAND], 1):
        doc[pno].get_pixmap(clip=r, dpi=DPI).save(IMG / f"{name}_c{i}.jpg", jpg_quality=85)
    return len(found)


def candidates(name):
    """Candidate number -> image path, including crops the user added (any image extension)."""
    out = {}
    for p in IMG.iterdir():  # not glob: paper titles may contain glob characters
        m = re.fullmatch(rf"{re.escape(name)}_c(\d+)", p.stem)
        if m:
            out[int(m.group(1))] = p
    return out


def make_cover(paths, out, h=300, gap=8):
    widths = [(px := pymupdf.Pixmap(str(p))).width * h / px.height for p in paths]
    doc = pymupdf.open()
    page = doc.new_page(width=sum(widths) + gap * (len(paths) - 1), height=h)
    x = 0
    for p, w in zip(paths, widths):
        page.insert_image(pymupdf.Rect(x, 0, x + w, h), filename=str(p))
        x += w + gap
    page.get_pixmap(dpi=144).save(out, jpg_quality=85)


def read_note(path):
    """Return (frontmatter dict, the user's text below the auto block)."""
    if not path.exists():
        return {}, "\n\n## 메모\n\n"
    text = path.read_text(encoding="utf-8")
    fm = {}
    if text.startswith("---\n"):
        end = text.index("\n---", 4)
        fm = yaml.safe_load(text[4:end]) or {}
        text = text[end + 4:].removeprefix("\n")
    # no end marker (deleted by hand): keep the whole body as user text, nothing is lost
    return fm, text.split(AUTO_END, 1)[1] if AUTO_END in text else "\n\n" + text


def auto_block(p, has_pdf, cover, cands):
    lines = [f"![[{cover}]]", ""] if cover else []
    links = []
    if p.get("doi") or p.get("landing_url"):
        links.append(f"[DOI]({'https://doi.org/' + p['doi'] if p.get('doi') else p['landing_url']})")
    if has_pdf:
        links.append(f"[[{p['filename']}|PDF]]")
    tier = [f"tier {p['tier']}"] if p.get("tier") else []
    lines += [
        f"**{p['title']}**",
        " · ".join([str(p["year"]), p["venue_abbrev"], "트랙 " + ", ".join(p["tracks"]), *tier, *links]),
        p.get("authors", ""),
    ]
    if p.get("reason") or p.get("key_numbers"):
        lines += [
            "",
            "> [!info]- 넣은 이유 · 핵심 수치",
            f"> **이유**: {p.get('reason', '')}",
            ">",
            f"> **수치** ({p.get('numbers_source', '')}): {p.get('key_numbers', '')}",
        ]
    if cands:
        nums = sorted(cands)
        lines += [
            "",
            "> [!example]- 그림 후보: `hw` 속성에 번호를 넣고 build_db.py 재실행",
            "> | " + " | ".join(map(str, nums)) + " |",
            "> |" + "---|" * len(nums),
            "> | " + " | ".join(f"![[{cands[n].name}\\|160]]" for n in nums) + " |",
        ]
    return "\n".join(lines)


def db_name(p):
    """Shared base name of a paper's note and images: DB_ + PDF file name without .pdf."""
    return "DB_" + p["filename"].removesuffix(".pdf")


def note_rel(p):
    return f"{NOTES.relative_to(ROOT).as_posix()}/{db_name(p)}.md"


def main_track(p, tracks):
    """Canvas group of a paper: its track listed first in the "tracks" config (put the novelty claim first)."""
    return next(k for k in tracks if k in p["tracks"])


def write_base(tracks):
    """Card gallery, one card view per track, and a table of every paper."""
    has_pdf = f'status == "{HAS_PDF}"'

    def cards(name, filters, extra=()):
        return {"type": "cards", "name": name, "filters": filters, "order": ["title", "formula.meta", *extra],
                "sort": [{"property": "year", "direction": "ASC"}], "image": "note.cover",
                "imageFit": "contain", "imageAspectRatio": 0.5, "cardSize": 320}

    names = {"formula.meta": "연도 · 게재지", "note.title": "제목", "note.year": "연도", "note.venue": "게재지",
             "note.tracks": "트랙", "note.tier": "우선순위", "note.status": "상태", "note.hw": "대표 그림 번호"}
    base = {
        "filters": {"and": ['file.inFolder("detail")', 'file.ext == "md"']},
        "formulas": {"meta": 'year.toString() + " · " + venue'},
        "properties": {k: {"displayName": v} for k, v in names.items()},
        "views": [
            cards("그림 갤러리", has_pdf),
            *(cards(f"트랙 {k}: {v}", {"and": [has_pdf, f'tracks.contains("{k}")']}, ["tracks"])
              for k, v in tracks.items()),
            {"type": "table", "name": "전체 목록",
             "order": ["file.name", "title", "year", "venue", "tracks", "tier", "status", "hw"],
             "sort": [{"property": "year", "direction": "ASC"}]},
        ],
    }
    BASE.write_text(yaml.safe_dump(base, allow_unicode=True, sort_keys=False, width=float("inf")), encoding="utf-8")


def edge_sides(a, b):
    dx = b["x"] + b["width"] / 2 - a["x"] - a["width"] / 2
    dy = b["y"] + b["height"] / 2 - a["y"] - a["height"] / 2
    if abs(dx) >= abs(dy):
        return ("right", "left") if dx > 0 else ("left", "right")
    return ("bottom", "top") if dy > 0 else ("top", "bottom")


def update_canvas(papers, tracks, by_id):
    """Put each paper missing from the map into the first free grid slot of its track group, then draw
    an edge for every `related` pair that has no edge yet.
    A full group grows by one row; the nodes below its columns move down with it, together with the cards of any
    group that moves, while a group placed beside it stays. A missing group is created at the bottom.
    Nodes already on the map are never moved sideways, so a hand-made layout survives."""
    canvas = json.loads(CANVAS.read_text(encoding="utf-8")) if CANVAS.exists() else {"nodes": [], "edges": []}
    nodes, edges = canvas["nodes"], canvas.setdefault("edges", [])
    have = {n.get("file") for n in nodes}
    order = list(tracks)
    todo = sorted((p for p in papers if note_rel(p) not in have),
                  key=lambda p: (order.index(main_track(p, tracks)), p["year"]))
    w, h, gap, cols = 440, 400, 40, 5

    def inside(n, grp):
        """True when the centre of node n lies in group grp."""
        return (grp["x"] <= n["x"] + n["width"] / 2 <= grp["x"] + grp["width"]
                and grp["y"] <= n["y"] + n["height"] / 2 <= grp["y"] + grp["height"])

    for p in todo:
        k = main_track(p, tracks)
        label = f"{k} · {tracks[k]}"  # groups are found by label: renaming a track creates a new group
        g = next((n for n in nodes if n["type"] == "group" and n.get("label") == label), None)
        if g is None:
            g = {"id": os.urandom(8).hex(), "type": "group", "x": 0,
                 "y": max((n["y"] + n["height"] for n in nodes), default=-200) + 200,
                 "width": cols * (w + gap) + gap, "height": gap, "label": label}
            nodes.insert(0, g)  # groups first so the cards render on top
        # grid slot (col, row) of every card whose centre lies in the group
        taken = {(round((n["x"] - g["x"] - gap) / (w + gap)), round((n["y"] - g["y"] - gap) / (h + gap)))
                 for n in nodes if n["type"] == "file" and inside(n, g)}
        i = next(i for i in itertools.count() if (i % cols, i // cols) not in taken)
        x, y = g["x"] + gap + (i % cols) * (w + gap), g["y"] + gap + (i // cols) * (h + gap)
        grow = y + h + gap - (g["y"] + g["height"])
        if grow > 0:
            bottom, left, right = g["y"] + g["height"], g["x"], g["x"] + g["width"]
            # move what lies below this group's columns; a group beside it keeps its place
            # shortcut: moved nodes are not checked against unmoved nodes below them; enough for groups that are
            # stacked or side by side, revisit if partly overlapping layouts collide
            shift = {n["id"]: n for n in nodes if n["y"] >= bottom and n["x"] < right and n["x"] + n["width"] > left}
            for grp in [n for n in shift.values() if n["type"] == "group"]:
                shift.update((n["id"], n) for n in nodes if n["type"] == "file" and inside(n, grp))
            for n in shift.values():
                n["y"] += grow
            g["height"] += grow
        nodes.append({"id": os.urandom(8).hex(), "type": "file", "file": note_rel(p),
                      "x": x, "y": y, "width": w, "height": h})

    card = {n["file"]: n for n in nodes if n["type"] == "file"}
    linked = {frozenset((e["fromNode"], e["toNode"])) for e in edges}
    new_edges = 0
    for p in papers:
        for r in p.get("related", []):
            a, b = card.get(note_rel(p)), card.get(note_rel(by_id[r]))
            if a and b and frozenset((a["id"], b["id"])) not in linked:
                fs, ts = edge_sides(a, b)
                edges.append({"id": os.urandom(8).hex(), "fromNode": a["id"], "fromSide": fs,
                              "toNode": b["id"], "toSide": ts})
                linked.add(frozenset((a["id"], b["id"])))
                new_edges += 1
    if todo or new_edges:
        CANVAS.write_text(json.dumps(canvas, ensure_ascii=False, indent=1), encoding="utf-8")
    return len(todo), new_edges


def check(tracks, papers, by_id):
    """Stop with a readable list instead of a KeyError halfway through writing notes."""
    errors = []
    for i, p in enumerate(papers):
        who = p.get("id", f"papers[{i}]")
        errors += [f"{who}: missing key '{k}'" for k in REQUIRED if k not in p]
        errors += [f"{who}: track '{t}' is not in \"tracks\"" for t in p.get("tracks", []) if t not in tracks]
        errors += [f"{who}: related id '{r}' not found" for r in p.get("related", []) if r not in by_id]
        if "tracks" in p and not p["tracks"]:
            errors.append(f"{who}: tracks is empty")
    for key in ("id", "filename"):
        counts = collections.Counter(p.get(key) for p in papers)
        errors += [f"duplicate {key}: {v}" for v, n in counts.items() if n > 1 and v]
    if errors:
        sys.exit("00_candidates.json:\n  " + "\n  ".join(errors))


def main():
    sys.stdout.reconfigure(errors="replace")  # cp949 consoles cannot print every title character
    for d in (PDFS, NOTES, IMG):
        d.mkdir(exist_ok=True)
    for f in ROOT.glob("*.pdf"):  # downloads land in the vault root; never overwrite a PDF already in pdf/
        if not (PDFS / f.name).exists():
            f.rename(PDFS / f.name)
    data = json.loads((ROOT / "00_candidates.json").read_text(encoding="utf-8"))
    tracks, papers = data["tracks"], data["papers"]
    by_id = {p.get("id"): p for p in papers}
    check(tracks, papers, by_id)

    with_cover, manual = [], []
    for p in papers:
        name, pdf = db_name(p), PDFS / p["filename"]
        has_pdf = pdf.exists()
        cands = candidates(name)
        if has_pdf and not cands and extract_candidates(pdf, name):
            cands = candidates(name)

        path = ROOT / note_rel(p)
        fm, user = read_note(path)
        fm = {k: v for k, v in fm.items() if k not in MANAGED}
        if cands and "hw" not in fm:
            fm["hw"] = sorted(cands)[:2]
        hw = fm.get("hw") if isinstance(fm.get("hw"), list) else [fm.get("hw")]
        picks = [cands[int(n)] for n in hw if str(n).strip().isdigit() and int(n) in cands]
        cover = f"{name}_cover.jpg" if picks else None
        if cover:
            make_cover(picks, IMG / cover)
            with_cover.append(p)
        elif has_pdf:
            manual.append(p["filename"])

        new = {"title": p["title"], "aliases": [p["title"]], "authors": p.get("authors", ""), "year": p["year"],
               "venue": p["venue_abbrev"], "tracks": p["tracks"], "tier": str(p.get("tier", "")),
               "status": HAS_PDF if has_pdf else p["status"], "doi": p.get("doi", ""), "url": p.get("landing_url", "")}
        if has_pdf:
            new["pdf"] = f"[[{p['filename']}]]"
        if cover:
            new["cover"] = f"[[{cover}]]"
        if p.get("related"):
            new["related"] = [f"[[{db_name(by_id[r])}]]" for r in p["related"]]
        front = yaml.safe_dump({**new, **fm}, allow_unicode=True, sort_keys=False, width=float("inf"))
        body = auto_block(p, has_pdf, cover, cands)
        path.write_text(f"---\n{front}---\n{AUTO_START}\n{body}\n{AUTO_END}{user}", encoding="utf-8")

    if not BASE.exists():
        write_base(tracks)
    added, linked = update_canvas(with_cover, tracks, by_id)
    print(f"notes {len(papers)}, covers {len(with_cover)}, canvas +{added} cards +{linked} edges")
    longest = max(len(p.relative_to(ROOT).as_posix()) for p in ROOT.rglob("*"))
    print(f"Windows path budget: keep the vault folder path <= {258 - longest} chars (longest inner path {longest})")
    if manual:
        print("PDF 있으나 대표 그림 없음 (후보 없음 또는 hw 비어 있음, 수동 크롭 필요):", *manual, sep="\n  ")


if __name__ == "__main__":
    main()
