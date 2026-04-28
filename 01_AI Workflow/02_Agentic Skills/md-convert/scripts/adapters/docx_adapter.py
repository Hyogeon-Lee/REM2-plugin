"""DOCX → Markdown 변환 어댑터.

전략:
- python-docx로 문서를 열되, body의 element 순서(paragraph, table, drawing)를 그대로 따라감
- 이미지(<w:drawing>)를 만나면 ZIP의 `word/media/`에서 추출 → ImageSaver로 저장 → 상대 경로 삽입
- 이렇게 하면 본문 흐름에서의 이미지 순서/위치가 그대로 유지됨

이미지 위치 매칭 메커니즘:
1. paragraph 안의 inline image: 해당 문단 위치에 ![]() 삽입
2. paragraph 안에 이미지만 있는 경우: 별도 줄로 ![]()
3. floating image: drawing 요소가 속한 paragraph 위치에 그대로 둠 (정확도 90%+)
"""
from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Iterable, Optional

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph
from lxml import etree

from ..common import ImageSaver, make_image_markdown


# DOCX XML 네임스페이스
NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
}


def convert(input_path: Path, output_md_path: Path) -> dict:
    """DOCX 파일을 마크다운으로 변환.

    Args:
        input_path: 입력 DOCX 경로
        output_md_path: 출력 .md 파일 경로 (이미지는 같은 폴더의 images_{stem}/에 저장)

    Returns:
        {"image_count": int, "warnings": list[str]}
    """
    doc = Document(str(input_path))
    # docx 패키지의 Part에서 이미지 blob 가져오기 위한 매핑
    image_parts = _build_image_parts_map(doc)

    saver = ImageSaver(output_md_path, output_md_path.stem, image_dir_name="images")
    md_lines: list[str] = []
    warnings: list[str] = []

    # body 직속 자식들을 순서대로 순회
    body = doc.element.body
    for child in body.iterchildren():
        tag = etree.QName(child).localname
        if tag == "p":
            para = Paragraph(child, doc)
            line = _render_paragraph(para, doc, image_parts, saver, warnings)
            if line:
                md_lines.append(line)
        elif tag == "tbl":
            table = Table(child, doc)
            md_lines.append(_render_table(table, doc, image_parts, saver, warnings))
        elif tag == "sectPr":
            continue  # section properties — 무시
        # 그 외 sdt 등은 fallback으로 텍스트만
        else:
            text = "".join(child.itertext()).strip()
            if text:
                md_lines.append(text)

    output_md_path.write_text("\n\n".join(md_lines) + "\n", encoding="utf-8")
    warnings.extend(saver.warnings)
    return {"image_count": saver.saved_count, "warnings": warnings}


def _build_image_parts_map(doc) -> dict:
    """rId → (filename, blob) 매핑 생성."""
    mapping = {}
    for rel_id, rel in doc.part.rels.items():
        if "image" in rel.reltype:
            try:
                target_part = rel.target_part
                # 파일명 추출 (예: word/media/image1.png → image1.png)
                name = target_part.partname.rsplit("/", 1)[-1]
                mapping[rel_id] = (name, target_part.blob)
            except Exception:
                continue
    return mapping


def _render_paragraph(
    para: Paragraph, doc, image_parts: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """문단 하나를 마크다운으로 변환. inline 이미지 포함."""
    style_name = (para.style.name if para.style else "") or ""
    style_lower = style_name.lower()

    # 헤딩 처리
    heading_prefix = ""
    if style_lower.startswith("heading"):
        try:
            level = int("".join(c for c in style_name if c.isdigit()) or "1")
            level = max(1, min(level, 6))
            heading_prefix = "#" * level + " "
        except ValueError:
            heading_prefix = "# "
    elif style_lower == "title":
        heading_prefix = "# "

    # 리스트 처리 (간이판: numbering element가 있으면 - 로 처리)
    list_prefix = ""
    numpr = para._p.find(qn("w:pPr"))
    if numpr is not None and numpr.find(qn("w:numPr")) is not None:
        list_prefix = "- "

    # run 단위 순회하며 텍스트와 이미지 추출
    parts: list[str] = []
    for run_el in para._p.iter():
        tag = etree.QName(run_el).localname
        if tag == "t":
            parts.append(run_el.text or "")
        elif tag == "tab":
            parts.append("\t")
        elif tag == "br":
            parts.append("  \n")  # 마크다운 강제 줄바꿈
        elif tag == "drawing":
            img_md = _extract_drawing_image(run_el, image_parts, saver, warnings)
            if img_md:
                parts.append(img_md)
        elif tag == "pict":
            # VML 레거시 이미지
            img_md = _extract_vml_image(run_el, image_parts, saver, warnings)
            if img_md:
                parts.append(img_md)

    text = "".join(parts).strip()
    if not text:
        return ""

    return f"{heading_prefix}{list_prefix}{text}"


def _extract_drawing_image(
    drawing_el, image_parts: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """<w:drawing> 안의 이미지 추출 → 마크다운 이미지 태그."""
    # <wp:extent cx="..." cy="..."/> EMU → mm (914400 EMU = 1 inch = 25.4 mm)
    size_mm = None
    extent_tag = f"{{{NS['wp']}}}extent"
    for extent in drawing_el.iter(extent_tag):
        try:
            cx = int(extent.get("cx") or 0)
            cy = int(extent.get("cy") or 0)
            if cx > 0 and cy > 0:
                size_mm = (cx / 36000.0, cy / 36000.0)
                break
        except (ValueError, TypeError):
            pass

    # a:blip의 r:embed 속성에서 rId 찾기
    blip_tag = f"{{{NS['a']}}}blip"
    embed_attr = f"{{{NS['r']}}}embed"
    for blip in drawing_el.iter(blip_tag):
        rid = blip.get(embed_attr)
        if rid and rid in image_parts:
            name, blob = image_parts[rid]
            rel_path = saver.save(blob, suggested_name=name, physical_size_mm=size_mm)
            return make_image_markdown(rel_path, alt="image")
    return ""


def _extract_vml_image(
    pict_el, image_parts: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """<w:pict>의 VML 이미지 (레거시) 추출."""
    # v:imagedata의 r:id 속성 찾기
    for imagedata in pict_el.iter():
        if etree.QName(imagedata).localname == "imagedata":
            rid = imagedata.get(f"{{{NS['r']}}}id")
            if rid and rid in image_parts:
                name, blob = image_parts[rid]
                rel_path = saver.save(blob, suggested_name=name)
                return make_image_markdown(rel_path, alt="image")
    return ""


def _render_table(
    table: Table, doc, image_parts: dict, saver: ImageSaver, warnings: list[str]
) -> str:
    """표를 마크다운 표로 변환. 셀 내부 이미지도 보존."""
    rows = []
    for row in table.rows:
        row_cells = []
        for cell in row.cells:
            cell_parts = []
            for para in cell.paragraphs:
                line = _render_paragraph(para, doc, image_parts, saver, warnings)
                if line:
                    cell_parts.append(line)
            # 셀 내 줄바꿈은 <br>로
            cell_text = "<br>".join(cell_parts).replace("|", r"\|")
            row_cells.append(cell_text or " ")
        rows.append(row_cells)

    if not rows:
        return ""

    # 마크다운 표 작성
    n_cols = max(len(r) for r in rows)
    rows = [r + [" "] * (n_cols - len(r)) for r in rows]
    out = []
    out.append("| " + " | ".join(rows[0]) + " |")
    out.append("|" + "|".join(["---"] * n_cols) + "|")
    for r in rows[1:]:
        out.append("| " + " | ".join(r) + " |")
    return "\n".join(out)
