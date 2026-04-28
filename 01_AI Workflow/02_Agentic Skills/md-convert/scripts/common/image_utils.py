"""이미지 저장 및 상대 경로 관리 유틸리티.

모든 어댑터가 공통으로 사용하는 이미지 처리 헬퍼.
- 모든 이미지는 PNG로 통일 변환되어 저장 (image_convert.to_png)
- 마크다운 본문에는 상대 경로로 참조: ![](images_{문서명}/img_001.png)
- image_dir_name 파라미터로 디렉토리명 커스터마이징 가능 (Phase 2: "images")
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Optional


# 확장자 매핑 (MIME 또는 매직바이트로부터)
_MAGIC_BYTES = {
    b"\x89PNG\r\n\x1a\n": "png",
    b"\xff\xd8\xff": "jpg",
    b"GIF87a": "gif",
    b"GIF89a": "gif",
    b"BM": "bmp",
    b"II*\x00": "tif",
    b"MM\x00*": "tif",
    b"RIFF": "webp",  # RIFF....WEBP — 추가 검증 아래
}


def detect_image_extension(data: bytes, fallback: str = "png") -> str:
    """매직 바이트로 이미지 확장자 추론."""
    for magic, ext in _MAGIC_BYTES.items():
        if data.startswith(magic):
            if magic == b"RIFF":
                if len(data) >= 12 and data[8:12] == b"WEBP":
                    return "webp"
                continue
            return ext
    return fallback


class ImageSaver:
    """이미지를 PNG로 통일 변환하여 폴더에 저장하고 상대 경로를 반환.

    중복 이미지는 SHA-1 해시(원본 입력 기준)로 감지하여 한 번만 저장.
    벡터/래스터 모두 PNG로 변환됨 (image_convert.to_png).
    """

    def __init__(
        self,
        output_md_path: Path,
        doc_stem: str,
        image_dir_name: Optional[str] = None,
    ):
        """
        Args:
            output_md_path: 최종 마크다운 파일 경로
            doc_stem: 문서 파일명 (확장자 제외). 기본 폴더명 `images_{doc_stem}` 생성
            image_dir_name: 이미지 디렉토리명 직접 지정 (Phase 2에서 "images" 사용)
        """
        self.output_md_path = Path(output_md_path)
        self.doc_stem = doc_stem
        self.image_dir_name = image_dir_name or f"images_{doc_stem}"
        self.image_dir = self.output_md_path.parent / self.image_dir_name
        self._counter = 0
        self._hash_to_path: dict[str, str] = {}
        self._warnings: list[str] = []

    def _ensure_dir(self) -> None:
        self.image_dir.mkdir(parents=True, exist_ok=True)

    def save(
        self,
        data: bytes,
        suggested_name: Optional[str] = None,
        ext: Optional[str] = None,  # 정보용 — 실제 출력은 항상 PNG
        physical_size_mm: Optional[tuple[float, float]] = None,
    ) -> str:
        """이미지를 PNG로 변환·저장하고 마크다운 상대 경로 반환.

        Args:
            data: 이미지 바이너리 (모든 포맷)
            suggested_name: 정보용 (확장자 추출 fallback에 사용)
            ext: 정보용 — 실제 저장 확장자는 항상 .png (변환 실패 시 매직바이트로 결정)
            physical_size_mm: 벡터 이미지 물리 크기 힌트 (WMF/EMF에 사용)

        Returns:
            마크다운에서 사용할 상대 경로 (POSIX 스타일)
        """
        # 중복 검사 (원본 바이트 기준 — 변환 전)
        digest = hashlib.sha1(data).hexdigest()
        if digest in self._hash_to_path:
            return self._hash_to_path[digest]

        # PNG 통일 변환
        from .image_convert import to_png
        png_bytes, warns = to_png(data, physical_size_mm=physical_size_mm)
        self._warnings.extend(warns)

        # 변환 결과 → 확장자 결정 (성공 시 png, 실패 fallback 시 매직바이트)
        is_png = png_bytes[:8] == b"\x89PNG\r\n\x1a\n"
        if is_png:
            suffix = "png"
        else:
            # to_png 실패 fallback — 원본 데이터가 그대로 반환됨
            suffix = detect_image_extension(png_bytes, fallback="bin")

        self._counter += 1
        filename = f"img_{self._counter:03d}.{suffix}"

        self._ensure_dir()
        target = self.image_dir / filename
        target.write_bytes(png_bytes)

        rel_path = f"{self.image_dir_name}/{filename}"
        self._hash_to_path[digest] = rel_path
        return rel_path

    @property
    def saved_count(self) -> int:
        return self._counter

    @property
    def warnings(self) -> list[str]:
        """이미지 변환 중 발생한 경고 목록."""
        return self._warnings


def make_image_markdown(rel_path: str, alt: str = "") -> str:
    """마크다운 이미지 태그 생성. alt 텍스트의 특수문자는 이스케이프."""
    safe_alt = alt.replace("[", r"\[").replace("]", r"\]")
    return f"![{safe_alt}]({rel_path})"
