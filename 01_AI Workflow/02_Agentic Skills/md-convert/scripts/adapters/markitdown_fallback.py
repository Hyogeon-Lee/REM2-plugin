"""기타 포맷 fallback 어댑터 — markitdown에 위임.

CSV, HTML, JSON, XML, EPUB, 오디오, 유튜브 URL 등 이미지 in-place 매칭이
의미 없거나 우리가 직접 다루지 않는 포맷에 사용. markitdown의 텍스트 추출만 활용.

이미지 추출은 시도하지 않음 (markitdown 자체가 이미지를 LLM 캡션으로만 처리하므로).
"""
from __future__ import annotations

from pathlib import Path


def convert(input_path: Path, output_md_path: Path) -> dict:
    try:
        from markitdown import MarkItDown
    except ImportError as e:
        raise RuntimeError(
            "markitdown이 설치되어 있지 않습니다. "
            "`pip install 'markitdown[all]'`로 설치하세요."
        ) from e

    md = MarkItDown(enable_plugins=False)
    result = md.convert(str(input_path))
    text = result.text_content or ""

    # 첫 줄에 제목 없으면 추가
    if not text.lstrip().startswith("#"):
        text = f"# {output_md_path.stem}\n\n{text}"

    output_md_path.write_text(text, encoding="utf-8")
    return {
        "image_count": 0,
        "warnings": [
            f"{input_path.suffix} 형식은 markitdown으로 텍스트만 추출합니다 (이미지 in-place 매칭 미지원)."
        ],
    }
