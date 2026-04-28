---
name: md-convert
description: Convert documents (DOCX, PPTX, XLSX, PDF, HWP, HWPX, images, CSV/HTML/EPUB/audio) to Markdown with all images converted to PNG (WMF/EMF rasterized via Windows GDI) and saved per-document into `md_convert/<stem>/images/`. Use this skill whenever the user wants to convert a document, parse a file to markdown, or extract content from .docx/.pptx/.xlsx/.pdf/.hwp/.hwpx files — even if they don't say "markdown" explicitly (e.g. "이 PDF 내용 정리해줘", "한글 파일 파싱", "convert this report"). Use this skill before reading the document content into context, because the script writes the result to disk and only file paths come back — that's the whole point. Do NOT use for translating documents, summarizing content, or anything that requires understanding the document semantically; this skill is purely a format conversion.
---

# md-convert

문서를 마크다운으로 변환합니다. 모든 이미지는 **PNG로 통일 변환**되며, 각 문서는 자기 격리 폴더(`md_convert/<stem>/`) 안에 `<stem>.md` + `images/` 서브폴더로 저장됩니다.

## 핵심 동작 원리

이 스킬은 **변환된 텍스트를 컨텍스트에 로드하지 않습니다.** Python 스크립트가 파일을 디스크에 쓰고, 저장 경로와 메타데이터(이미지 개수, 경고)만 반환합니다. 사용자가 내용에 대해 질문하기 전까지는 결과 마크다운을 읽지 마세요.

## 사용법

```bash
python -m scripts.convert <input_file> [-o <output_dir>] [--json] [--yes]
```

기본 동작: `<output_dir>/md_convert/<stem>/` 폴더 생성 → 그 안에 `<stem>.md` + `images/img_001.png`, `img_002.png` ... 저장.

`<output_dir>` 미지정 시 입력 파일과 같은 폴더 사용.

### 예시

```bash
# 기본 (입력 파일 폴더에 md_convert/<stem>/ 생성)
python -m scripts.convert /path/to/report.docx

# 출력 폴더 지정
python -m scripts.convert /path/to/report.pdf -o /path/to/converted/

# 출력 .md 경로 직접 지정 (md_convert/<stem>/ 삽입 안함)
python -m scripts.convert /path/to/file.hwpx --output-md /custom/result.md

# JSON 결과 + 의존성 자동설치 진행
python -m scripts.convert /path/to/file.hwpx --json --yes
```

### 출력 구조 (다중 파일)

```
<out_dir>/md_convert/
├── doc_A/
│   ├── doc_A.md
│   └── images/
│       ├── img_001.png
│       └── ...
├── doc_B/
│   ├── doc_B.md
│   └── images/
│       └── ...
└── ...
```

각 문서가 자기 폴더 + 자기 `images/` 보유. 다른 문서와 폴더 공유 없음.

### JSON 출력 형태

```json
{
  "output_md": "/path/to/md_convert/report/report.md",
  "image_dir": "/path/to/md_convert/report/images",
  "image_count": 12,
  "warnings": [],
  "format": "docx"
}
```

## 이미지 변환 정책

모든 이미지는 PNG로 통일됩니다:

| 입력 포맷 | 처리 |
|---|---|
| WMF, EMF (벡터) | Windows GDI(ctypes)로 래스터화 — 400 DPI 기본, A4 fallback |
| BMP, JPEG, GIF, TIFF, WEBP | Pillow로 PNG 재인코딩 |
| PNG | 통과 (10MB 초과 시에만 다운샘플) |

**10MB 안전장치**: 픽셀 수 기준 추정 크기가 10MB 초과하면 자동 다운스케일.
- 벡터: DPI sqrt 스케일링 (최소 150 DPI)
- 래스터: LANCZOS 다운샘플

**Windows 외**: ctypes.windll 미지원이면 WMF/EMF는 원본 그대로 저장 (warning 출력).

## 지원 포맷별 동작

| 포맷 | 어댑터 | 이미지 위치 매칭 | 비고 |
|---|---|---|---|
| `.docx` | python-docx + lxml | ✅ 정확 (XML 순서 = 본문 순서) | `<wp:extent>` EMU 크기 힌트 |
| `.pptx` | python-pptx | ✅ 정확 (shape top/left 좌표 정렬) | shape EMU 크기 힌트 |
| `.xlsx` | openpyxl | ⚠️ 시트별 끝에 모음 | anchor 셀 정보 주석 |
| `.pdf` | PyMuPDF (fitz) | ✅ 좌표 기반 reading order | 가장 정교 |
| `.hwpx` | 자체 ZIP/XML 파서 | ✅ section XML 순서 | `<hp:sz>` HWPUNIT 크기 힌트 |
| `.hwp` | olefile (텍스트만) | ❌ 미지원 | best-effort 텍스트만 |
| 단일 이미지 | 직접 PNG 변환 | — | png/jpg/gif/webp/bmp 등 |
| 기타 (csv/html/epub/audio) | markitdown fallback | ❌ | 텍스트만 추출 |

## 사용자가 HWP 파일을 줬을 때

HWP 5.x는 텍스트만 추출됩니다 (이미지/표 미지원). 이미지 보존이 필요한 상황이면, 한컴오피스에서 "다른 이름으로 저장 → HWPX"로 변환 후 다시 시도하라고 안내하세요.

## 의존성

CLI 첫 실행 시 누락된 패키지 자동 검출 → 사용자 확인 후 설치합니다.

```
- python-docx, python-pptx, openpyxl, PyMuPDF, lxml, olefile (직접 파싱)
- Pillow (이미지 PNG 통일 변환)
- markitdown[all] (기타 포맷 fallback)
- ctypes (stdlib) — Windows GDI 호출. pywin32 불필요.
```

수동 설치 (격리 환경 등):
```bash
pip install -r scripts/requirements.txt
```

CLI 플래그:
- `--yes` / `-y`: 누락 의존성 프롬프트 없이 설치 진행 (CI/스크립트용)
- `--no-install`: 누락 검출만 하고 안내 후 종료 (자동 설치 시도 안 함)

## 어댑터 직접 호출 (고급)

```python
from pathlib import Path
from scripts.convert import convert_file

result = convert_file(
    input_path=Path("report.docx"),
    out_dir=Path("./converted"),  # ./converted/md_convert/report/report.md 생성
)
print(result)
```

## 디렉토리 구조 (스킬 자체)

```
md-convert/
├── SKILL.md
├── README.md
└── scripts/
    ├── convert.py            # 메인 CLI + 의존성 체크
    ├── requirements.txt
    ├── common/
    │   ├── image_utils.py    # ImageSaver (PNG 통일)
    │   └── image_convert.py  # to_png + GDI 래스터화
    └── adapters/
        ├── docx_adapter.py
        ├── pptx_adapter.py
        ├── xlsx_adapter.py
        ├── pdf_adapter.py
        ├── hwpx_adapter.py
        ├── hwp_adapter.py
        ├── image_adapter.py
        └── markitdown_fallback.py
```

## 주의사항

- 변환 결과는 디스크에 저장됩니다. 사용자가 내용을 묻기 전엔 결과 .md를 본 컨텍스트로 읽지 마세요 — 토큰 낭비입니다.
- 경고(`warnings`) 메시지가 있으면 사용자에게 간단히 전달하세요 (예: "HWP 5.x는 텍스트만 추출됩니다", "DPI 400 → 278 다운스케일").
- 이미지가 0장이어도 정상 동작입니다 (텍스트만 있는 문서). `images/` 폴더는 첫 이미지 저장 시에만 생성됩니다.
- WMF/EMF 래스터화는 Windows 전용입니다. 비-Windows에서는 원본 그대로 저장됩니다 (마크다운 뷰어에서 안 보일 수 있음).
