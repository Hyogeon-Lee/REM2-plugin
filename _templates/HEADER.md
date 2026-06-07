# 헤더 템플릿 (필수)

올리는 **모든 항목**은 무엇이고 어떻게 쓰는지 한눈에 알 수 있어야 합니다.
이 폴더는 Obsidian으로 보는 것을 전제로, 항목 정보를 **YAML frontmatter(Properties)** 로 적습니다.
필드 정의와 허용값은 [`frontmatter-schema.md`](frontmatter-schema.md)에 있습니다.

핵심 필드(필수): `title` · `type` · `language` · `category` · `author` · `year`
권장 필드: `dependencies` · `status` · `tags` · `related`

---

## 1. Markdown / 폴더 단위 항목 (`.md`, `README.md`)

파일 맨 위에 `---`로 감싼 frontmatter를 넣고, 아래에 사람이 읽을 본문을 적습니다.

```markdown
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

# bandpass_filter

(한 줄 용도 설명, 사용법 등 — 자세한 본문은 README_TEMPLATE.md 참고)
```

## 2. 코드 파일 (`.m`) — 헤더 주석 + 사이드카 `.md`

YAML frontmatter는 `.md`에서만 Obsidian이 인식합니다. 코드 파일은 **두 개를 같이** 둡니다.

코드 본문 맨 위 주석 (사람이 코드 열었을 때 보라고):

```matlab
% 이름      : bandpass_filter
% 용도      : (한 줄 설명)
% 작성자    : 홍길동 / 2026
% 사용법    : y = bandpass_filter(x, fs, band)
% 의존성    : Signal Processing Toolbox / 없음
```

같은 이름의 사이드카 `bandpass_filter.md` (Obsidian이 읽는 메타데이터):

```markdown
---
title: bandpass_filter
type: function
language: matlab
category: signal-processing
author: 홍길동
year: 2026
dependencies: [Signal Processing Toolbox]
status: stable
tags: [filter, bandpass]
---

`bandpass_filter.m` — (한 줄 용도). 사용법: `y = bandpass_filter(x, fs, band)`
```

## 3. LabVIEW (`.vi`)

VI는 본문 주석이 어려우므로:

- **VI Properties → Documentation → VI Description** 칸에 이름·용도·작성자·사용법·의존성을 적고,
- 같은 이름의 사이드카 `<VI이름>.md`에 위 frontmatter를 넣습니다. `language: labview`, `dependencies`에 LabVIEW 버전(예: `[LabVIEW 2023 Q3]`).

## 4. 데이터·템플릿 파일

헤더를 넣을 수 없으므로 같은 폴더에 설명용 `.md`를 두고 frontmatter(`type: data` 또는 `template`)를 넣습니다.

---

폴더 단위로 올리는 큰 항목은 [`README_TEMPLATE.md`](README_TEMPLATE.md)를 복사해 폴더 `README.md`로 쓰는 것을 권장합니다.
