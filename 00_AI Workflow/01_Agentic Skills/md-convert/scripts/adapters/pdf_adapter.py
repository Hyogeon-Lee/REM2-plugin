"""PDF → Markdown 변환 어댑터.

전략 (PyMuPDF / fitz 기반):
- 페이지별로 텍스트 블록과 이미지 블록을 모두 추출
- 두 종류를 (y0, x0) 좌표 기준으로 정렬 → 시각적 reading order 보존
- 이미지는 추출하여 ImageSaver로 저장, 해당 위치에 ![]() 삽입
- 텍스트는 블록 단위로 보존, 폰트 크기 휴리스틱으로 헤딩 추정 (선택)

이게 가장 정확한 inline 매칭 전략. PDF는 본질적으로 좌표 기반이라
좌표를 정직하게 따라가는 게 정답.
"""
from __future__ import annotations

from pathlib import Path

import fitz  # PyMuPDF

from ..common import ImageSaver, make_image_markdown


def convert(input_path: Path, output_md_path: Path) -> dict:
    doc = fitz.open(str(input_path))
    saver = ImageSaver(output_md_path, output_md_path.stem, image_dir_name="images")
    md_lines: list[str] = [f"# {output_md_path.stem}"]
    warnings: list[str] = []

    for page_num, page in enumerate(doc, start=1):
        md_lines.append(f"\n<!-- 페이지 {page_num} -->")
        page_blocks = _collect_page_blocks(page, doc, saver, warnings, page_num)
        for block in page_blocks:
            md_lines.append(block)

    doc.close()
    output_md_path.write_text("\n\n".join(md_lines) + "\n", encoding="utf-8")
    warnings.extend(saver.warnings)
    return {"image_count": saver.saved_count, "warnings": warnings}


def _collect_page_blocks(
    page, doc, saver: ImageSaver, warnings: list[str], page_num: int
) -> list[str]:
    """페이지의 텍스트/이미지 블록을 좌표 순으로 정렬해 마크다운 라인 리스트로 반환."""
    items: list[tuple[float, float, str]] = []  # (y0, x0, markdown)

    # get_text("dict")는 텍스트 블록 + 이미지 블록 모두 좌표와 함께 반환
    page_dict = page.get_text("dict")
    blocks = page_dict.get("blocks", [])

    for block in blocks:
        bbox = block.get("bbox", [0, 0, 0, 0])
        y0, x0 = bbox[1], bbox[0]
        btype = block.get("type", 0)  # 0=text, 1=image

        if btype == 0:
            text = _block_text(block)
            if text.strip():
                items.append((y0, x0, text))
        elif btype == 1:
            md = _extract_image_block(block, page, doc, saver, warnings, page_num)
            if md:
                items.append((y0, x0, md))

    # 추가 보완은 하지 않음. dict 블록의 image bytes는 ImageSaver가 SHA-1 해시로
    # 중복 제거하므로 같은 이미지면 같은 경로가 반환됨.
    # page.get_images() 보완은 inline 이미지를 페이지 끝에 다시 넣는 부작용이 있어 제거.

    # 좌표 정렬: y 우선, 같은 y면 x 우선
    items.sort(key=lambda t: (round(t[0], 1), round(t[1], 1)))
    return [it[2] for it in items]


def _block_text(block: dict) -> str:
    """텍스트 블록에서 자연스러운 문자열 조립."""
    lines = []
    for line in block.get("lines", []):
        spans = line.get("spans", [])
        text = "".join(span.get("text", "") for span in spans)
        if text.strip():
            lines.append(text)
    return "\n".join(lines).strip()


def _extract_image_block(
    block: dict, page, doc, saver: ImageSaver, warnings: list[str], page_num: int
) -> str:
    """dict의 image 블록 → 마크다운 이미지 태그."""
    try:
        # 이미지 블록은 image 키에 raw bytes를 가질 수 있음
        if "image" in block and isinstance(block["image"], (bytes, bytearray)):
            blob = bytes(block["image"])
            ext = block.get("ext", "png")
            rel_path = saver.save(blob, ext=ext)
            return make_image_markdown(rel_path, alt=f"page {page_num}")

        # xref 기반으로 추출
        xref = block.get("xref")
        if xref:
            base_image = doc.extract_image(xref)
            blob = base_image["image"]
            ext = base_image.get("ext", "png")
            rel_path = saver.save(blob, ext=ext)
            return make_image_markdown(rel_path, alt=f"page {page_num}")
    except Exception as e:
        warnings.append(f"페이지 {page_num} 이미지 블록 추출 실패: {e}")
    return ""
