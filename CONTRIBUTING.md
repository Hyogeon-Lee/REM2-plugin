# 업로드 규칙 (CONTRIBUTING)

이 폴더에 자료를 올리는 방법입니다. **핵심은 두 가지뿐입니다: ① 알맞은 폴더에 넣기, ② 5줄 헤더 붙이기.** 나머지는 권장 사항입니다.

---

## 1. 어디에 올릴까 — 폴더 고르기

| 올리는 것 | 폴더 |
|---|---|
| AI 스킬, 에이전트/프롬프트 워크플로우, MCP 구성 | `00_AI Workflow` |
| MATLAB 함수·스크립트 | `01_Software Functions/MATLAB` |
| LabVIEW VI·코드 | `01_Software Functions/LabVIEW` |
| 다른 언어 코드 | `01_Software Functions` 아래 언어명 폴더를 새로 만들어 사용 (예: `Python`) |
| 추천 도구·논문·튜토리얼 링크 모음 | `02_References` |
| 예제 데이터, 보고서·문서 템플릿, 매뉴얼 | `03_Data & Templates` |

**고민되면** 가장 가까운 폴더에 넣고 헤더에 용도를 분명히 적으면 됩니다. 분류는 나중에 정리할 수 있습니다.

---

## 2. 어떻게 올릴까 — frontmatter 붙이기 (필수)

이 폴더는 Obsidian으로 보는 것을 전제로, 항목 정보를 **YAML frontmatter(Properties)** 로 적습니다. 속성 기반 검색·필터와 항목 간 연결에 쓰입니다. 필수 필드는 `title` `type` `language` `category` `author` `year`이고, 권장 필드는 `dependencies` `status` `tags` `related`입니다. 필드 정의는 [`_templates/frontmatter-schema.md`](_templates/frontmatter-schema.md), 복사용 양식은 [`_templates/HEADER.md`](_templates/HEADER.md)에 있습니다.

- **폴더 단위 항목**(스크립트 묶음, 스킬 등): 폴더 `README.md` 맨 위에 frontmatter를 넣습니다. [`_templates/README_TEMPLATE.md`](_templates/README_TEMPLATE.md) 복사.
- **단일 코드 파일**(`.m` 등): 코드 맨 위에 헤더 주석을 두고, **같은 이름의 사이드카 `.md`** 에 frontmatter를 넣습니다 (frontmatter는 `.md`에서만 Obsidian이 인식).
- **LabVIEW VI**: VI Description 칸에 설명을 적고, 같은 이름의 사이드카 `.md`에 frontmatter를 둡니다.
- **데이터·템플릿 파일**: 같은 폴더에 설명용 `.md`를 두고 frontmatter(`type: data` 또는 `template`)를 넣습니다.

frontmatter가 없으면 검색·연결에 잡히지 않고 다른 사람이 쓰기 어려우니, 이 한 가지는 꼭 지켜 주세요.

---

## 3. 파일·폴더 이름 규칙 (권장)

- **공백 대신 밑줄**: `signal filter.m` ❌ → `signal_filter.m` ✅
- **영문·숫자·밑줄·하이픈**만 사용. 한글 파일명은 피합니다 (도구 호환성).
- **이름만 봐도 알 수 있게**: `test1.m` ❌ → `bandpass_filter.m` ✅
- **버전은 파일명이 아니라 헤더에**: `func_final_v2_real.m` ❌. 정말 필요하면 `_v2`처럼 끝에만.
- **폴더 단위 항목**은 항목 이름의 폴더로 묶습니다 (예: `md-convert/`).

---

## 4. 올리기 전 체크리스트

- [ ] 알맞은 카테고리 폴더에 넣었다
- [ ] 5줄 헤더(또는 폴더 `README.md`)를 채웠다
- [ ] 파일명이 명확하고 공백이 없다
- [ ] **민감정보 없음** — 비밀번호·API 키·토큰·미공개 연구데이터·개인정보가 들어있지 않다
- [ ] 큰 파일(대략 100MB 초과 데이터/바이너리)은 직접 올리지 않고 링크나 보관 위치를 헤더에 적었다

---

## 5. 하지 말 것

- 비밀번호·API 키·토큰 등 **인증정보 커밋 금지**. 한 번 올라가면 이력에 남습니다.
- 미공개 논문 데이터, 외부 비밀유지 대상 자료 업로드 금지.
- 라이선스가 불분명하거나 재배포가 금지된 외부 코드 통째로 복사 금지 — 대신 `02_References`에 링크로.
- 남의 항목을 **임의로 삭제·수정 금지**. 개선 제안은 작성자에게 알리거나 별도 항목으로.

---

## 6. 관리 (옵션)

- 새 카테고리·하위 폴더가 필요하면 만들고, 그 폴더에 한 줄짜리 `README.md`로 용도를 적어 둡니다.
- 더 이상 안 쓰는 항목은 삭제하기보다 `_archive/` 폴더(필요 시 생성)로 옮기는 것을 권장합니다.
- 분류·정리에 대한 의견은 폴더 관리자에게 알려 주세요.
