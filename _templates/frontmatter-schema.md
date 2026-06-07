# Frontmatter 스키마 (YAML Properties)

이 폴더의 모든 `.md` 항목은 맨 위에 `---`로 감싼 **YAML frontmatter**를 둡니다. Obsidian이 이를 **Properties**로 인식해, 속성 기반 검색·필터(Dataview/Bases)와 그래프 연결에 활용할 수 있습니다.

> YAML = *YAML Ain't Markup Language*. `key: value` 형태로 데이터를 적는 형식입니다.

---

## 필드 정의

| 필드 | 필수 | 타입 | 허용값 / 형식 | 설명 |
|---|---|---|---|---|
| `title` | ✅ | 문자열 | 자유 | 항목 이름 (함수명·스킬명 등) |
| `type` | ✅ | 문자열 | `function` · `skill` · `reference` · `data` · `template` | 항목 종류 |
| `language` | ✅ | 문자열 | `matlab` · `labview` · `python` · `none` | 코드 언어 (코드 아니면 `none`) |
| `category` | ✅ | 문자열 | 자유(소문자-하이픈) 예: `signal-processing` | 세부 주제 |
| `author` | ✅ | 문자열 | 이름 | 작성자 |
| `year` | ✅ | 숫자 | 예: `2026` | 작성/등록 연도 |
| `dependencies` | ⬜ | 리스트 | 예: `[Signal Processing Toolbox]` | 필요한 toolbox·패키지·버전. 없으면 `[]` |
| `status` | ⬜ | 문자열 | `draft` · `stable` · `deprecated` | 성숙도 (기본 `stable`) |
| `tags` | ⬜ | 리스트 | 예: `[filter, bandpass]` | Obsidian 네이티브 태그 (검색용 키워드) |
| `related` | ⬜ | 리스트 | wikilink 예: `["[[notch_filter]]"]` | 연관 항목 링크 (그래프 연결) |

- 필수 5개(`title` `type` `language` `category` `author` `year`)는 이전의 "5줄 헤더"와 1:1로 대응합니다 — 기계가 읽을 수 있게 옮긴 것뿐입니다.
- 선택 필드는 비워도 되지만, `tags`와 `related`를 채울수록 Obsidian에서 검색·연결성이 좋아집니다.
- `dependencies`가 없으면 빈 리스트 `[]`로 명시합니다.

---

## 복사용 양식

```yaml
---
title: bandpass_filter
type: function
language: matlab
category: signal-processing
author: 홍길동
year: 2026
dependencies: [Signal Processing Toolbox]
status: stable
tags: [filter, bandpass, frequency]
related: ["[[notch_filter]]"]
---
```

종류별 최소 예시:

```yaml
# AI 스킬
---
title: md-convert
type: skill
language: python
category: document-conversion
author: REM2
year: 2026
dependencies: [python-docx, PyMuPDF, Pillow]
status: stable
tags: [markdown, conversion, hwp]
---
```

```yaml
# 참고자료 / 큐레이션
---
title: recommend_GitHub
type: reference
language: none
category: curation
author: REM2
year: 2026
status: stable
tags: [github, tools, ai-agent]
---
```

```yaml
# 데이터 / 템플릿
---
title: motor_test_dataset
type: data
language: none
category: dataset
author: 홍길동
year: 2026
status: stable
tags: [motor, measurement]
---
```

---

## 코드 파일(`.m`, `.vi`) 처리 — 사이드카 방식

YAML frontmatter는 **`.md` 파일에서만** Obsidian이 인식합니다. 코드 본문에 넣어도 무시되므로:

1. 코드 파일에는 기존처럼 **헤더 주석**을 남깁니다 (사람이 코드 열었을 때 보라고).
2. 같은 이름의 **사이드카 `.md`** 를 함께 두고 거기에 frontmatter를 넣습니다.

```
bandpass_filter.m      ← 헤더 주석 + 실제 코드
bandpass_filter.md     ← frontmatter + 간단한 설명 (Obsidian이 읽음)
```

폴더 단위 항목(스크립트 묶음, 스킬)은 사이드카 대신 폴더 `README.md` 맨 위에 frontmatter를 넣으면 됩니다.

---

## 활용 (참고)

이 속성들이 채워지면 Obsidian에서 이런 게 가능해집니다:

- `type: function` 이면서 `language: matlab` 인 항목만 모은 목록을 자동 생성 (Dataview/Bases)
- `tags`로 "filter 관련 함수" 한 번에 검색
- `related` wikilink로 함수 간 의존·연관 관계를 그래프로 시각화

원하면 이 스키마를 그대로 읽어 표/카드로 보여주는 Obsidian **Base(`.base`)** 뷰도 만들어 줄 수 있습니다.
