"""Self-test for build_db.py: build a throwaway vault from the template with synthetic PDFs,
run the generator twice, and check notes, covers, Base, canvas groups/edges, and that user edits survive.

Usage: python selftest.py        (needs: pip install pymupdf pyyaml)
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

import pymupdf
import yaml

HERE = pathlib.Path(__file__).resolve().parent
TEMPLATE = HERE.parent / "assets" / "template"


def make_pdf(path, colors):
    """One page with a title line and one two-tone raster figure per colour."""
    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Synthetic paper", fontsize=14)
    for i, c in enumerate(colors):
        pix = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, 160, 120), False)
        pix.set_rect(pix.irect, c)
        pix.set_rect(pymupdf.IRect(0, 0, 80, 60), tuple(255 - v for v in c))
        page.insert_image(pymupdf.Rect(72, 120 + i * 260, 392, 360 + i * 260), pixmap=pix)
    doc.save(path)


def paper(pid, tracks, filename, **extra):
    return {"id": pid, "title": f"Title {pid}", "authors": "Kim, Lee", "year": 2020 + int(pid[1:]),
            "venue_abbrev": "ICRA", "tracks": tracks, "tier": 2, "doi": "", "landing_url": "",
            "filename": filename, "status": "대기", **extra}


def run(vault, ok=True):
    r = subprocess.run([sys.executable, str(vault / "build_db.py")], capture_output=True, text=True,
                       encoding="utf-8", env={**os.environ, "PYTHONIOENCODING": "utf-8"})
    assert (r.returncode == 0) == ok, r.stdout + r.stderr
    return r.stdout + r.stderr


def front(note):
    return yaml.safe_load(note.read_text(encoding="utf-8").split("---\n")[1])


def main():
    with tempfile.TemporaryDirectory() as tmp:
        vault = pathlib.Path(tmp) / "TestDB"
        shutil.copytree(TEMPLATE, vault)
        shutil.copy(HERE / "build_db.py", vault)
        cfg = vault / "00_candidates.json"
        data = json.loads(cfg.read_text(encoding="utf-8"))
        data["papers"] = [
            paper("P001", ["A"], "2021_ICRA_Alpha.pdf"),
            paper("P002", ["A", "C"], "2022_ICRA_Beta.pdf", related=["P001"], reason="r", key_numbers="1 ms"),
            paper("P003", ["B"], "2023_ICRA_Gamma.pdf"),  # list-only: no PDF
        ]
        cfg.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        make_pdf(vault / "2021_ICRA_Alpha.pdf", [(200, 40, 40)])  # dropped in the vault root
        (vault / "pdf").mkdir()
        make_pdf(vault / "pdf" / "2022_ICRA_Beta.pdf", [(40, 200, 40), (40, 40, 200)])

        out = run(vault)
        assert "notes 3, covers 2, canvas +2 cards +1 edges" in out, out
        assert (vault / "pdf" / "2021_ICRA_Alpha.pdf").exists() and not (vault / "2021_ICRA_Alpha.pdf").exists()

        beta = vault / "detail" / "DB_2022_ICRA_Beta.md"
        fm = front(beta)
        assert fm["status"] == "다운로드 완료" and fm["hw"] == [1, 2], fm
        assert fm["related"] == ["[[DB_2021_ICRA_Alpha]]"] and fm["cover"] == "[[DB_2022_ICRA_Beta_cover.jpg]]", fm
        assert "[!info]-" in beta.read_text(encoding="utf-8")
        gamma = front(vault / "detail" / "DB_2023_ICRA_Gamma.md")
        assert gamma["status"] == "대기" and "cover" not in gamma, gamma
        cover = vault / "img" / "DB_2022_ICRA_Beta_cover.jpg"
        width_two = pymupdf.Pixmap(str(cover)).width

        base = yaml.safe_load((vault / "00_Database.base").read_text(encoding="utf-8"))
        views = [v["name"] for v in base["views"]]
        assert views[0] == "그림 갤러리" and views[-1] == "전체 목록", views
        assert [v.split(":")[0] for v in views[1:-1]] == ["트랙 C", "트랙 B", "트랙 A"], views

        canvas = json.loads((vault / "00_Map.canvas").read_text(encoding="utf-8"))
        groups = {n["label"][0]: n for n in canvas["nodes"] if n["type"] == "group"}
        cards = {n["file"]: n for n in canvas["nodes"] if n["type"] == "file"}
        assert set(groups) == {"A", "C"}, groups  # P003 has no cover, so no B group yet
        b, g = cards["detail/DB_2022_ICRA_Beta.md"], groups["C"]  # tracks A+C -> C is listed first
        assert g["x"] <= b["x"] and b["x"] + b["width"] <= g["x"] + g["width"]
        assert g["y"] <= b["y"] and b["y"] + b["height"] <= g["y"] + g["height"]
        assert len(canvas["edges"]) == 1

        # user edits: keep one figure and add a memo; both must survive the re-run
        text = beta.read_text(encoding="utf-8")
        edited = text.replace(yaml.safe_dump({"hw": [1, 2]}), yaml.safe_dump({"hw": [2]})) + "내 메모\n"
        assert edited != text + "내 메모\n", "hw block not found"
        beta.write_text(edited, encoding="utf-8")
        canvas_before = (vault / "00_Map.canvas").read_bytes()
        out = run(vault)
        assert "canvas +0 cards +0 edges" in out, out
        assert front(beta)["hw"] == [2] and beta.read_text(encoding="utf-8").endswith("내 메모\n")
        assert pymupdf.Pixmap(str(cover)).width < width_two
        assert (vault / "00_Map.canvas").read_bytes() == canvas_before

        # group C moved beside group A, level with A's bottom edge, must stay put when A gains a row
        canvas = json.loads(canvas_before)
        groups = {n["label"][0]: n for n in canvas["nodes"] if n["type"] == "group"}
        ga, gc = groups["A"], groups["C"]
        beside = [gc, next(n for n in canvas["nodes"] if n.get("file") == "detail/DB_2022_ICRA_Beta.md")]
        dx, dy = ga["x"] + ga["width"] + 200 - gc["x"], ga["y"] + ga["height"] - gc["y"]
        for n in beside:
            n["x"] += dx
            n["y"] += dy
        (vault / "00_Map.canvas").write_text(json.dumps(canvas), encoding="utf-8")
        for i in range(4, 9):  # five more A papers: six cards need a second row
            data["papers"].append(paper(f"P00{i}", ["A"], f"202{i}_ICRA_A{i}.pdf"))
            make_pdf(vault / "pdf" / f"202{i}_ICRA_A{i}.pdf", [(30 * i, 90, 160)])
        cfg.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        assert "canvas +5 cards" in run(vault)
        after = {n["id"]: n for n in json.loads((vault / "00_Map.canvas").read_text(encoding="utf-8"))["nodes"]}
        assert after[ga["id"]]["height"] > ga["height"]
        assert [(after[n["id"]]["x"], after[n["id"]]["y"]) for n in beside] == [(n["x"], n["y"]) for n in beside]

        # bad input stops before writing anything
        data["papers"][2]["tracks"] = ["Z"]
        cfg.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        assert "track 'Z'" in run(vault, ok=False)
    print("selftest passed")


if __name__ == "__main__":
    main()
