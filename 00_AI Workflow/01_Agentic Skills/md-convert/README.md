# md-convert

문서를 마크다운으로 변환하면서 **이미지를 본문 위치에 맞게 in-place로 매칭**하는 Claude Skill. 모든 이미지는 **PNG로 통일 변환**되어 격리된 문서별 폴더에 저장됨.

## 핵심 동작

```
input.docx
   │
   ▼
out_dir/md_convert/input/
├── input.md              ← 본문 + ![](images/img_001.png) 상대 경로
└── images/               ← PNG로 변환된 이미지들
    ├── img_001.png
    ├── img_002.png
    └── ...
```

- 각 문서가 자기 폴더(`md_convert/<stem>/`) + 자기 `images/` 보유 (다른 문서와 공유 없음)
- 이미지 파일명은 본문 등장 순서대로 `img_001`, `img_002`, ...
- 모든 이미지는 PNG로 통일 변환 (WMF/EMF 벡터 → Windows GDI 래스터화, 그 외 래스터 → Pillow 재인코딩)
- 동일 이미지(같은 SHA-1, 변환 전 원본 기준)는 한 번만 저장
- 마크다운 안의 이미지 참조는 항상 POSIX 스타일 상대 경로 (`images/img_NNN.png`)
- 10MB 안전장치: 추정 크기 초과 시 자동 다운스케일

## 지원 포맷과 처리 전략

| 포맷 | 라이브러리 | 이미지 위치 매칭 | 보존 요소 |
|---|---|---|---|
| `.docx` | python-docx + lxml | ✅ XML 순서 | 헤딩, 표, 리스트, inline/floating 이미지, VML 레거시, `<wp:extent>` 크기 힌트 |
| `.pptx` | python-pptx | ✅ shape (top, left) 좌표 | 슬라이드 분리, 발표자 노트, 그룹, 표, 들여쓰기 리스트, shape EMU 크기 힌트 |
| `.xlsx` | openpyxl | ⚠️ 시트별 끝에 모음 | 시트 분리, 표, anchor 셀 정보 |
| `.pdf` | PyMuPDF (fitz) | ✅ 좌표 기반 reading order | 페이지 구분, 텍스트 블록, 이미지 |
| `.hwpx` | 자체 ZIP/XML 파서 | ✅ section XML 순서 | 문단, 표, 이미지, `<hp:sz>` HWPUNIT 크기 힌트 |
| `.hwp` | olefile (텍스트만) | ❌ 미지원 | 문단 텍스트 (best-effort) |
| 단일 이미지 | 직접 PNG 변환 | — | png/jpg/gif/webp/bmp/tiff |
| 기타 | markitdown fallback | ❌ | csv, html, json, xml, epub, mp3, wav, m4a, xls, doc, ppt |

### 포맷별 매칭 메커니즘 상세

**DOCX**: `body.iterchildren()`로 paragraph/table을 순서대로 순회. paragraph 안의 `<w:drawing>`을 만나면 `<wp:extent cx cy>` (EMU → mm)을 ImageSaver에 힌트로 전달, `a:blip/@r:embed`의 rId로 `word/media/`에서 blob 추출 후 PNG 변환·저장.

**PPTX**: 슬라이드별 `slide.shapes`를 `(top, left)`로 정렬. PICTURE 타입은 `shape.image.blob` + `shape.width/height` (EMU → mm) 힌트와 함께 ImageSaver에 전달. GROUP은 재귀, `has_table`은 마크다운 표, `has_text_frame`은 들여쓰기 레벨 리스트.

**XLSX**: `iter_rows(values_only=True)`로 그리드 → 마크다운 표. 이미지는 `ws._images`에서 추출, anchor (row, col)을 alt text + 주석으로 보존.

**PDF**: `page.get_text("dict")`로 텍스트/이미지 블록 모두 받아 `(y0, x0)`로 정렬. 이미지 블록은 `block["image"]` 또는 `xref → doc.extract_image()`.

**HWPX**: `.hpf`/`.opf` 매니페스트에서 `id → href` 매핑 (`posixpath.normpath`로 `..` 정규화). `section*.xml`을 순서대로 처리. `<hp:sz w h>` HWPUNIT 크기를 ImageSaver에 힌트로 전달. table 내부 `<p>`는 _walk_section에서 skip하여 중복 출력 방지.

**HWP 5.x**: `olefile.OleFileIO`로 OLE2 컨테이너. `BodyText/Section*` 스트림을 numeric sort 후 레코드 단위 파싱. `HWPTAG_PARA_HEADER`/`HWPTAG_PARA_TEXT`만 처리, 이미지/표 미지원.

## 이미지 변환 정책

```
to_png(data, physical_size_mm=None, target_dpi=400, max_bytes=10MB, min_dpi=150)
```

**포맷 감지** (매직 바이트):
- PNG (`89 50 4E 47 ...`) → 통과 (10MB 초과 시 다운샘플)
- Placeable WMF (`D7 CD C6 9A`) → GDI 래스터화
- Non-placeable WMF (`01 00 09 00` / `02 00 09 00`) → GDI 래스터화
- EMF (`01 00 00 00` + offset 40 = `" EMF"`) → GDI 래스터화
- 그 외 → Pillow 래스터 재인코딩

**물리 크기 결정 우선순위**:
1. 벡터 헤더의 frame rect (placeable WMF / EMF rclFrame)
2. 호출자 힌트 (PPTX shape, DOCX `<wp:extent>`, HWPX `<hp:sz>`)
3. A4 fallback (210 × 297 mm)

**10MB 안전장치 (sqrt 스케일링)**:
```
estimated_bytes = pixels × 1.5  # PNG 추정
if estimated_bytes > max_bytes:
    scale = sqrt(max_bytes / estimated_bytes)
    new_dpi = max(min_dpi, target_dpi × scale)  # 벡터
    또는
    target_pixels = max_bytes / 1.5             # 래스터 LANCZOS
```

**Failure fallback**: GDI ImportError, 헤더 파싱 실패, Pillow 디코딩 실패 → 원본 그대로 저장 + warning. 절대 raise 안함.

## 사용법

### CLI

```bash
# 기본 (입력 파일 폴더에 md_convert/<stem>/ 생성)
python -m scripts.convert report.docx
# → ./md_convert/report/report.md + ./md_convert/report/images/

# 출력 폴더 지정
python -m scripts.convert report.pdf -o ./converted/
# → ./converted/md_convert/report/report.md

# 출력 .md 경로 직접 지정 (md_convert/<stem>/ 삽입 안함)
python -m scripts.convert report.hwpx --output-md ./out/custom_name.md
# → ./out/custom_name.md + ./out/images/

# JSON 출력 + 의존성 자동설치 진행
python -m scripts.convert document.pptx --json --yes
```

### CLI 플래그

| 플래그 | 동작 |
|---|---|
| `-o`, `--output-dir` | 출력 디렉토리 (기본: 입력 파일 폴더) |
| `--output-md` | 출력 .md 경로 직접 지정 (md_convert 삽입 안함) |
| `--json` | 결과를 JSON으로 stdout 출력 |
| `-y`, `--yes` | 의존성 누락 시 프롬프트 없이 설치 |
| `--no-install` | 누락 검출만 하고 안내 후 종료 |

### Python API

```python
from pathlib import Path
from scripts.convert import convert_file

result = convert_file(
    input_path=Path("report.docx"),
    out_dir=Path("./converted"),
)
# result = {
#     "output_md": "./converted/md_convert/report/report.md",
#     "image_dir": "./converted/md_convert/report/images",
#     "image_count": 12,
#     "warnings": [],
#     "format": "docx",
# }
```

### 어댑터 직접 호출

특정 포맷만 처리하고 싶거나 라우팅을 우회하고 싶으면:

```python
from pathlib import Path
from scripts.adapters import docx_adapter

result = docx_adapter.convert(
    input_path=Path("report.docx"),
    output_md_path=Path("./out/report.md"),
)
# 어댑터 내부의 ImageSaver는 image_dir_name="images"로 ./out/images/ 생성
```

## 출력 결과 보장 사항

- 마크다운 파일은 항상 UTF-8 인코딩
- 이미지 확장자는 항상 `.png` (변환 실패 fallback 시에만 매직바이트로 추론)
- 마크다운 표의 `|` 문자는 `\|`로 이스케이프
- alt text의 `[`, `]`는 이스케이프
- 셀 내 줄바꿈은 `<br>`로 변환
- 모든 이미지 파일은 10MB 이하 (안전장치 동작 시 warning 출력)

## 의존성

```
python-docx>=1.0.0    # DOCX
python-pptx>=0.6.21   # PPTX
openpyxl>=3.1.0       # XLSX
PyMuPDF>=1.23.0       # PDF
lxml>=4.9.0           # XML 파싱
olefile>=0.46         # HWP 5.x

Pillow>=10.0.0        # 이미지 PNG 통일 변환
markitdown[all]>=0.1.0  # 선택: csv/html/epub/오디오 등
```

**ctypes (stdlib)**로 Windows GDI 호출 — pywin32 불필요.

CLI 첫 실행 시 누락된 패키지 자동 검출 → 사용자 확인 후 설치. 또는 수동:

```bash
pip install -r scripts/requirements.txt
```

라이선스 호환성: 모든 의존성이 MIT/BSD/Apache 2.0 (markitdown은 MIT). pyhwp(AGPLv3)는 의도적으로 사용하지 않음.

## 디렉토리 구조 (스킬 자체)

```
md-convert/
├── SKILL.md                       # Claude가 읽는 가이드
├── README.md                      # 이 파일
└── scripts/
    ├── __init__.py
    ├── convert.py                 # CLI 엔트리 + 라우터 + 의존성 체크
    ├── requirements.txt
    ├── common/
    │   ├── __init__.py
    │   ├── image_utils.py         # ImageSaver (PNG 통일, dedup)
    │   └── image_convert.py       # to_png + GDI 래스터화 + Pillow 재인코딩
    └── adapters/
        ├── __init__.py
        ├── docx_adapter.py
        ├── pptx_adapter.py
        ├── xlsx_adapter.py
        ├── pdf_adapter.py
        ├── hwpx_adapter.py
        ├── hwp_adapter.py
        ├── image_adapter.py
        └── markitdown_fallback.py
```

## 한계와 우회 방법

### Windows 외 환경의 WMF/EMF

`ctypes.windll`은 Windows 전용. 비-Windows에서는 WMF/EMF가 원본 그대로 저장되며 마크다운 뷰어에서 안 보일 수 있음 (warning 출력). 우회: 입력 문서를 한 번 Windows에서 변환하거나, LibreOffice headless로 사전 처리.

### HWP 5.x 이미지/표

`hwp_adapter`는 텍스트만 추출. 이미지/표가 필요하면 한컴오피스에서 "다른 이름으로 저장 → HWPX"로 변환 후 사용.

### PDF 2단 레이아웃

현재 단순 (y, x) 좌표 정렬이라 좌우 2단 PDF는 reading order가 꼬일 수 있음. 칼럼 분석을 추가하려면 `pdf_adapter._collect_page_blocks`에서 x좌표로 클러스터링 후 칼럼별 정렬 로직 삽입 필요.

### DOCX inline 수식

OMML 수식은 무시됨. 필요하면 `_render_paragraph`에서 `m:oMath` 태그 처리 추가.

### PPTX 차트 데이터

차트는 PICTURE shape로 잡혀 이미지로만 추출됨. 원시 데이터 표가 필요하면 `chart.plots[0].categories` / `series.values`를 별도로 처리.

### XLSX 이미지 inline 위치

XLSX는 본질적으로 그리드라 본문 흐름 개념이 약해 시트 끝에 모음. anchor 셀 정보를 주석으로 보존하므로 후처리로 위치 복원 가능.

### WMF/EMF에서 폰트 누락

GDI 래스터화 시 시스템에 없는 폰트가 사용되면 검은 비트맵이 나올 수 있음. `Image.getextrema()`로 감지하여 warning 출력 (PNG는 그대로 반환). 우회: 원본 작성 환경의 폰트를 시스템에 설치 또는 폰트 임베딩된 PDF로 사전 변환.

## 변환 결과 예시

입력 DOCX: 헤딩, 문단 사이에 이미지 2장, 3×3 표

출력 `md_convert/test/test.md`:
```markdown
# 테스트 문서

이것은 첫 번째 문단입니다.

## 이미지 섹션

아래 첫 번째 이미지:

![image](images/img_001.png)

두 이미지 사이의 텍스트입니다.

![image](images/img_002.png)

두 번째 이미지 다음의 문단입니다.

## 표 섹션

| R0C0 | R0C1 | R0C2 |
|---|---|---|
| R1C0 | R1C1 | R1C2 |
| R2C0 | R2C1 | R2C2 |

문서 끝.
```

출력 폴더:
```
out/md_convert/test/
├── test.md
└── images/
    ├── img_001.png
    └── img_002.png
```

## 라이선스

MIT
