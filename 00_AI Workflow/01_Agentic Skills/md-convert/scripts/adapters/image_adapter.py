"""단일 이미지 파일 → Markdown 래퍼.

이미지 파일을 입력받았을 때, 별도 처리 없이 images_{stem}/img_001.{ext}로 저장하고
이미지 한 장만 들어있는 마크다운 문서를 만든다.
"""
from __future__ import annotations

from pathlib import Path

from ..common import ImageSaver, make_image_markdown


def convert(input_path: Path, output_md_path: Path) -> dict:
    saver = ImageSaver(output_md_path, output_md_path.stem, image_dir_name="images")
    blob = input_path.read_bytes()
    ext = input_path.suffix.lstrip(".").lower() or None
    rel_path = saver.save(blob, suggested_name=input_path.name, ext=ext)

    md = f"# {output_md_path.stem}\n\n{make_image_markdown(rel_path, alt=input_path.stem)}\n"
    output_md_path.write_text(md, encoding="utf-8")
    return {"image_count": saver.saved_count, "warnings": list(saver.warnings)}
