"""HWPX → Markdown 변환 어댑터.

전략:
- HWPX는 ZIP 컨테이너 안에 OPF manifest + Contents/section*.xml + BinData/* 구조
- section XML을 순서대로 파싱 → 문단/표/이미지 추출
- 이미지 참조는 manifest.xml에서 ID → BinData 파일 경로 매핑
- ZIP 내부 BinData/에서 이미지 바이트 추출 → ImageSaver로 저장

복잡도: 중간. HWPX는 ECMA 표준이라 스키마가 공개되어 있어 안정적.
"""
from __future__ import annotations

import io
import posixpath
import zipfile
from pathlib import Path

from lxml import etree

from ..common import ImageSaver, make_image_markdown


# HWPX 네임스페이스 (버전마다 약간 다를 수 있음 — 자주 쓰는 것들만)
HP_NS = "http://www.hancom.co.kr/hwpml/2011/paragraph"
HS_NS = "http://www.hancom.co.kr/hwpml/2011/section"
HC_NS = "http://www.hancom.co.kr/hwpml/2011/core"
HM_NS = "http://www.hancom.co.kr/hwpml/2011/master-page"
OPF_NS = "http://www.idpf.org/2007/opf/"


def convert(input_path: Path, output_md_path: Path) -> dict:
    saver = ImageSaver(output_md_path, output_md_path.stem, image_dir_name="images")
    md_lines: list[str] = [f"# {output_md_path.stem}"]
    warnings: list[str] = []

    with zipfile.ZipFile(str(input_path)) as zf:
        # 1) manifest 파싱: ID → 파일경로 매핑
        manifest = _parse_manifest(zf, warnings)

        # 2) section 파일들을 순서대로 처리
        section_paths = _find_section_paths(zf)
        for sec_path in section_paths:
            try:
                xml_bytes = zf.read(sec_path)
            except KeyError:
                continue
            tree = etree.fromstring(xml_bytes)
            for block in _walk_section(tree, zf, manifest, saver, warnings):
                md_lines.append(block)

    output_md_path.write_text("\n\n".join(md_lines) + "\n", encoding="utf-8")
    warnings.extend(saver.warnings)
    return {"image_count": saver.saved_count, "warnings": warnings}


def _parse_manifest(zf: zipfile.ZipFile, warnings: list[str]) -> dict:
    """OPF manifest에서 ID → ZIP 내부 경로 매핑."""
    mapping = {}
    candidates = ["Contents/content.hpf", "content.hpf", "META-INF/container.xml"]
    for name in zf.namelist():
        if name.endswith(".hpf") or name.endswith(".opf"):
            try:
                tree = etree.fromstring(zf.read(name))
                for item in tree.iter():
                    tag = etree.QName(item).localname
                    if tag == "item":
                        item_id = item.get("id")
                        href = item.get("href")
                        if item_id and href:
                            # href는 hpf 파일 위치 기준 상대경로 — posixpath로 ../  정규화
                            base_dir = name.rsplit("/", 1)[0] if "/" in name else ""
                            full = posixpath.normpath(posixpath.join(base_dir, href)) if base_dir else href
                            mapping[item_id] = full
            except Exception as e:
                warnings.append(f"manifest 파싱 실패 ({name}): {e}")
    return mapping


def _find_section_paths(zf: zipfile.ZipFile) -> list[str]:
    """section*.xml 파일들을 순서대로."""
    sections = [
        n for n in zf.namelist()
        if "section" in n.lower() and n.lower().endswith(".xml")
    ]
    sections.sort()
    return sections


def _walk_section(
    root, zf: zipfile.ZipFile, manifest: dict, saver: ImageSaver, warnings: list[str]
):
    """section XML을 순회하며 마크다운 블록 yield."""
    # tbl 내부 p는 _render_table이 처리하므로 여기서 skip
    table_p_ids: set[int] = set()
    for tbl in root.iter():
        if etree.QName(tbl).localname == "tbl":
            for p in tbl.iter():
                if etree.QName(p).localname == "p":
                    table_p_ids.add(id(p))

    for el in root.iter():
        tag = etree.QName(el).localname
        if tag == "p" and id(el) not in table_p_ids:
            line = _render_paragraph(el, zf, manifest, saver, warnings)
            if line:
                yield line
        elif tag == "tbl":
            md = _render_table(el, zf, manifest, saver, warnings)
            if md:
                yield md


def _render_paragraph(
    p_el, zf: zipfile.ZipFile, manifest: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """문단 하나에서 텍스트와 이미지를 추출."""
    parts: list[str] = []
    # p 안에는 run, ctrl(컨트롤 객체 = 표/그림/도형 등) 등이 있음
    for child in p_el.iter():
        tag = etree.QName(child).localname
        if tag == "t":  # 텍스트
            if child.text:
                parts.append(child.text)
        elif tag == "pic":  # picture 컨트롤
            img_md = _extract_pic(child, zf, manifest, saver, warnings)
            if img_md:
                parts.append(img_md)
        elif tag == "lineBreak":
            parts.append("  \n")
    return "".join(parts).strip()


def _extract_pic(
    pic_el, zf: zipfile.ZipFile, manifest: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """<pic> 또는 <hp:pic> 요소에서 이미지 추출.

    HWPX는 보통 hc:img의 binaryItemIDRef 속성으로 manifest의 ID를 참조.
    """
    ref_id = None
    size_mm: tuple[float, float] | None = None
    for sub in pic_el.iter():
        # img 요소를 찾아 binaryItemIDRef 추출
        bin_ref = sub.get("binaryItemIDRef")
        if bin_ref and ref_id is None:
            ref_id = bin_ref
        # <hp:sz w="..." h="..."> HWPUNIT (1/7200 inch) → mm
        if etree.QName(sub).localname == "sz" and size_mm is None:
            try:
                w = int(sub.get("w") or 0)
                h = int(sub.get("h") or 0)
                if w > 0 and h > 0:
                    size_mm = (w * 25.4 / 7200.0, h * 25.4 / 7200.0)
            except (ValueError, TypeError):
                pass

    if not ref_id:
        return ""

    zip_path = manifest.get(ref_id)
    if not zip_path or zip_path not in zf.namelist():
        # manifest 경로가 잘못되었거나 없음 → fallback: ZIP 전체에서 ID 부분문자열 검색
        candidates = [
            n for n in zf.namelist()
            if ("BinData" in n) and (ref_id in n or _id_matches(n, ref_id))
        ]
        if candidates:
            zip_path = candidates[0]
        else:
            warnings.append(f"이미지 참조 {ref_id} 못 찾음")
            return ""

    try:
        blob = zf.read(zip_path)
    except KeyError:
        warnings.append(f"ZIP에 {zip_path} 없음")
        return ""

    name = zip_path.rsplit("/", 1)[-1]
    rel_path = saver.save(blob, suggested_name=name, physical_size_mm=size_mm)
    return make_image_markdown(rel_path, alt="image")


def _id_matches(zip_name: str, ref_id: str) -> bool:
    """파일명(stem)이 ref_id와 일치하는지 확인."""
    base = zip_name.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    return base == ref_id


def _render_table(
    tbl_el, zf: zipfile.ZipFile, manifest: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """HWPX 표 → 마크다운 표.

    HWPX 표 구조: tbl > tr > tc > subList > p
    colSpan/rowSpan은 단순화하여 무시 (best-effort).
    """
    rows = []
    for tr in tbl_el.iter():
        if etree.QName(tr).localname != "tr":
            continue
        cells = []
        for tc in tr.iter():
            if etree.QName(tc).localname != "tc":
                continue
            cell_lines = []
            for p in tc.iter():
                if etree.QName(p).localname == "p":
                    line = _render_paragraph(p, zf, manifest, saver, warnings)
                    if line:
                        cell_lines.append(line)
            cell_text = "<br>".join(cell_lines).replace("|", r"\|")
            cells.append(cell_text or " ")
        if cells:
            rows.append(cells)

    if not rows:
        return ""

    n_cols = max(len(r) for r in rows)
    rows = [r + [" "] * (n_cols - len(r)) for r in rows]
    out = ["| " + " | ".join(rows[0]) + " |", "|" + "|".join(["---"] * n_cols) + "|"]
    for r in rows[1:]:
        out.append("| " + " | ".join(r) + " |")
    return "\n".join(out)
