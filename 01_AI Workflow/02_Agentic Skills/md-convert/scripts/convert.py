"""md-convert: 다양한 문서를 이미지 위치 보존 마크다운으로 변환.

사용법:
    python -m scripts.convert <input> [-o OUT_DIR]
    python -m scripts.convert <input> [--output-md PATH]
    python -m scripts.convert <input> [--yes]   # 의존성 누락 시 묻지 않고 설치

출력 구조 (각 문서별 isolate된 폴더):
    OUT_DIR/md_convert/<stem>/
    ├── <stem>.md
    └── images/
        ├── img_001.png
        └── ...

여러 파일 변환 시 각 문서가 자기 폴더 + 자기 images/ 보유 (공유 없음).
모든 이미지는 PNG로 통일 변환됨 (WMF/EMF는 Windows GDI로 래스터화).

`--output-md PATH` 명시 시: PATH 부모 폴더에 .md 저장 + 같은 폴더에 images/ 생성
(md_convert/<stem>/ 삽입 안함).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Callable


# 확장자 → (어댑터 모듈 경로, 함수명)
ADAPTER_MAP: dict[str, str] = {
    ".docx": "scripts.adapters.docx_adapter",
    ".pptx": "scripts.adapters.pptx_adapter",
    ".xlsx": "scripts.adapters.xlsx_adapter",
    ".pdf": "scripts.adapters.pdf_adapter",
    ".hwpx": "scripts.adapters.hwpx_adapter",
    ".hwp": "scripts.adapters.hwp_adapter",
    ".png": "scripts.adapters.image_adapter",
    ".jpg": "scripts.adapters.image_adapter",
    ".jpeg": "scripts.adapters.image_adapter",
    ".gif": "scripts.adapters.image_adapter",
    ".webp": "scripts.adapters.image_adapter",
    ".bmp": "scripts.adapters.image_adapter",
    ".tif": "scripts.adapters.image_adapter",
    ".tiff": "scripts.adapters.image_adapter",
    ".csv": "scripts.adapters.markitdown_fallback",
    ".html": "scripts.adapters.markitdown_fallback",
    ".htm": "scripts.adapters.markitdown_fallback",
    ".json": "scripts.adapters.markitdown_fallback",
    ".xml": "scripts.adapters.markitdown_fallback",
    ".epub": "scripts.adapters.markitdown_fallback",
    ".txt": "scripts.adapters.markitdown_fallback",
    ".md": "scripts.adapters.markitdown_fallback",
    ".mp3": "scripts.adapters.markitdown_fallback",
    ".wav": "scripts.adapters.markitdown_fallback",
    ".m4a": "scripts.adapters.markitdown_fallback",
    ".xls": "scripts.adapters.markitdown_fallback",
    ".doc": "scripts.adapters.markitdown_fallback",
    ".ppt": "scripts.adapters.markitdown_fallback",
}


# (import_name, pip_spec) — pywin32 불필요 (ctypes로 GDI 호출)
_REQUIRED_DEPS: list[tuple[str, str]] = [
    ("PIL", "Pillow>=10.0.0"),
    ("docx", "python-docx>=1.0.0"),
    ("pptx", "python-pptx>=0.6.21"),
    ("openpyxl", "openpyxl>=3.1.0"),
    ("fitz", "PyMuPDF>=1.23.0"),
    ("lxml", "lxml>=4.9.0"),
    ("olefile", "olefile>=0.46"),
    ("markitdown", "markitdown[all]>=0.1.0"),
]


def _ensure_deps(assume_yes: bool = False, no_install: bool = False) -> None:
    """필수 패키지 누락 시 사용자 확인 후 pip install.

    Args:
        assume_yes: 프롬프트 없이 설치 진행 (--yes)
        no_install: 누락 검출만 하고 설치 시도 안 함 (--no-install)
    """
    import importlib
    import subprocess

    missing: list[str] = []
    for mod, spec in _REQUIRED_DEPS:
        try:
            importlib.import_module(mod)
        except ImportError:
            missing.append(spec)

    if not missing:
        return

    print(
        f"[md-convert] 누락된 의존성: {', '.join(missing)}", file=sys.stderr
    )

    if no_install:
        print(
            "수동 설치: pip install " + " ".join(missing), file=sys.stderr
        )
        sys.exit(2)

    if assume_yes:
        ans = "y"
    elif sys.stdin.isatty():
        try:
            ans = input("지금 설치할까요? [y/N]: ").strip().lower()
        except EOFError:
            ans = ""
    else:
        print(
            "비대화형 환경: --yes 플래그 또는 수동 설치 필요\n"
            "수동 설치: pip install " + " ".join(missing),
            file=sys.stderr,
        )
        sys.exit(2)

    if ans not in ("y", "yes"):
        print("설치 취소. 변환 중단.", file=sys.stderr)
        sys.exit(2)

    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", *missing]
        )
    except subprocess.CalledProcessError as e:
        print(
            f"[md-convert] pip install 실패 (exit {e.returncode}). "
            "권한 문제면 --user 옵션 시도: "
            f"pip install --user {' '.join(missing)}",
            file=sys.stderr,
        )
        sys.exit(2)


def get_adapter(ext: str) -> Callable:
    """확장자로 어댑터 함수 로드."""
    ext = ext.lower()
    module_path = ADAPTER_MAP.get(ext)
    if not module_path:
        module_path = "scripts.adapters.markitdown_fallback"
    import importlib
    mod = importlib.import_module(module_path)
    return mod.convert


def convert_file(
    input_path: Path, out_dir: Path, output_md: Path | None = None
) -> dict:
    """단일 파일 변환.

    Args:
        input_path: 입력 파일
        out_dir: 출력 디렉토리 (output_md가 지정되지 않은 경우 사용)
        output_md: 출력 .md 파일 경로 직접 지정 (선택)

    Returns:
        {"output_md": str, "image_dir": str, "image_count": int,
         "warnings": list[str], "format": str}
    """
    if not input_path.exists():
        raise FileNotFoundError(f"입력 파일 없음: {input_path}")

    if output_md is None:
        # 각 문서별 격리 폴더: <out_dir>/md_convert/<stem>/<stem>.md
        doc_dir = out_dir / "md_convert" / input_path.stem
        doc_dir.mkdir(parents=True, exist_ok=True)
        output_md = doc_dir / f"{input_path.stem}.md"
    else:
        output_md.parent.mkdir(parents=True, exist_ok=True)

    ext = input_path.suffix.lower()
    adapter = get_adapter(ext)
    result = adapter(input_path, output_md)

    return {
        "output_md": str(output_md),
        "image_dir": str(output_md.parent / "images"),
        "image_count": result.get("image_count", 0),
        "warnings": result.get("warnings", []),
        "format": ext.lstrip("."),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="문서 → 이미지 위치 보존 Markdown 변환기 (PNG 통일)"
    )
    parser.add_argument("input", type=Path, help="입력 파일 경로")
    parser.add_argument(
        "-o", "--output-dir", type=Path, default=None,
        help="출력 디렉토리 (기본값: 입력 파일과 같은 폴더)",
    )
    parser.add_argument(
        "--output-md", type=Path, default=None,
        help="출력 .md 파일 경로 직접 지정 (--output-dir보다 우선)",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="결과를 JSON으로 stdout 출력 (기계 처리용)",
    )
    parser.add_argument(
        "-y", "--yes", action="store_true",
        help="의존성 누락 시 프롬프트 없이 설치 진행",
    )
    parser.add_argument(
        "--no-install", action="store_true",
        help="의존성 자동 설치 시도 안함 (누락 시 안내 후 종료)",
    )
    args = parser.parse_args()

    _ensure_deps(assume_yes=args.yes, no_install=args.no_install)

    out_dir = args.output_dir or args.input.parent
    try:
        result = convert_file(args.input, out_dir, args.output_md)
    except Exception as e:
        if args.json:
            print(
                json.dumps(
                    {"error": str(e), "type": type(e).__name__},
                    ensure_ascii=False,
                )
            )
        else:
            print(f"[ERROR] {type(e).__name__}: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"변환 완료: {result['output_md']}")
        if result["image_count"]:
            print(
                f"  이미지 {result['image_count']}장 → {result['image_dir']}"
            )
        for w in result["warnings"]:
            print(f"  [warning] {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
