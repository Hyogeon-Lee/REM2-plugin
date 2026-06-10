---
title: REM2-plugin
type: skill
language: none
category: [claude-plugin, codex-plugin]
author: Hyogeon Lee
year: 2026
dependencies: [Claude Code, Codex CLI, MATLAB MCP]
status: draft
tags: [plugin, skill, matlab, plotting]
related: ["[[plot-style]]"]
---

# REM2 Plugin

MATLAB 과학/공학 플롯 스타일을 일관되게 적용해주는 **비공식** 플러그인입니다. 연세대학교나 정밀생산메카트로닉스 연구실(REM2)의 공식 산출물이 아니며, 후배들의 도전적인 figure를 보다 못한 한 대학원생이 조금이나마 해소하고자 만들었습니다.

Claude Code와 Codex CLI 양쪽에서 같은 스킬 소스를 공유합니다. English version: [`README_EN.md`](README_EN.md)

## 구조

```
REM2-plugin/
  .claude-plugin/plugin.json       ← Claude Code 매니페스트
  .codex-plugin/plugin.json        ← Codex 매니페스트
  skills/
    plot-style/
      SKILL.md                     ← 항상 로드되는 공통 규칙 + case 디스패치
      references/                  ← case별 규칙 모듈 (필요 시 on-demand 로드)
        time-series.md
        xy-plot.md
        3d-plot.md
        frequency-response.md
      examples/                    ← case별 실행 가능 MATLAB 예제 (before/after)
        time_series_example.m
        xy_plot_example.m
        three_d_plot_example.m
        frequency_response_example.m
        image_fig/                 ← 예제가 생성하는 PNG (before/after)
  README.md / README_EN.md
```

저장소 루트의 `.claude-plugin/marketplace.json`(Claude Code)과 `.agents/plugins/marketplace.json`(Codex)이 이 플러그인을 각 marketplace에 등록합니다.

## 설치

### Claude Code

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install rem2@rem2-lab
```

업데이트: `/plugin marketplace update rem2-lab`

### Codex CLI

```
codex plugin marketplace add Hyogeon-Lee/REM2
codex /plugins
```

`codex /plugins`로 열리는 plugin 디렉터리(TUI)에서 `rem2-lab` 탭의 `rem2-plugin`을 선택해 설치합니다. 마켓플레이스 갱신: `codex plugin marketplace upgrade rem2-lab`.

### ChatGPT (workspace skill)

`dist/chatgpt/plot-style.zip` 업로드 — 절차는 [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) 참고.

## 현재 수록 스킬

| 스킬 | 용도 | 상태 |
|---|---|---|
| `plot-style` | MATLAB 과학/공학 플롯 일관 스타일 — 공통 규칙 + time-series / X–Y / 3-D / frequency-response 모듈, before/after 예제 포함 | stable |

플롯 코드를 새로 작성·수정할 때 자동 트리거됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다.

## 로드맵 (다음 드래프트 후보)

- `em-design-maxwell` — ANSYS Maxwell/AEDT IronPython 스크립팅
- `manufacturing` — 제조 워크플로우 헬퍼

## 비고

- 플러그인 스킬은 lab vault frontmatter 규칙과 별개로 Claude 표준 `name`/`description` frontmatter를 씁니다 (스킬 자동 발견에 필요).
