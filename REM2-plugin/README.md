---
title: REM2-plugin
type: skill
language: none
category: claude-plugin
author: REM2
year: 2026
dependencies: [Claude Code, MATLAB MCP]
status: draft
tags: [plugin, skill, matlab, electromagnetic, control, plotting]
related: ["[[plot-style]]"]
---

# REM2 Claude Code Plugin

연세대 정밀생산메카트로닉스 연구실(REM2) 공용 Claude Code **플러그인**. 전자기 설계·제조·MATLAB 해석·플롯·제어 설계 워크플로우에서 재사용할 스킬과 명령을 한 패키지로 묶습니다.

> 일반 로컬 스킬 폴더(`01_Agentic Skills/`)와 달리, 이 폴더는 **설치형 플러그인** 형식입니다. 한 번 설치하면 lab 구성원 누구나 동일한 스킬/명령을 쓸 수 있습니다.

## 구조

```
REM2-plugin/
  .claude-plugin/plugin.json   ← 매니페스트 (이름·버전·설명)
  skills/
    plot-style/SKILL.md        ← 과학/공학 플롯 스타일 규칙
  README.md
```

저장소 루트의 `.claude-plugin/marketplace.json`이 이 플러그인을 marketplace 항목으로 등록합니다.

## 설치

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install REM2@rem2-lab
```

## 현재 수록 스킬

| 스킬 | 용도 | 상태 |
|---|---|---|
| `plot-style` | MATLAB(및 타 언어) 과학/공학 플롯 일관 스타일 — 축·범례·라벨·주파수응답 규칙 | stable |

## 로드맵 (다음 드래프트 후보)

- `matlab-analysis` — MATLAB MCP 연동 데이터 해석·신호처리 스캐폴드
- `em-design-maxwell` — ANSYS Maxwell/AEDT IronPython 스크립팅
- `control-design` — TF/상태공간, Bode/Nyquist/step 튜닝, PID/loop-shaping
- `manufacturing` — 제조 워크플로우 헬퍼

## 비고

- 플러그인 스킬은 lab vault frontmatter 규칙과 별개로 Claude 표준 `name`/`description` frontmatter를 씁니다 (스킬 자동 발견에 필요).
- `00_AI Workflow/01_Agentic Skills/plot-style/`의 원본 스킬과 내용이 동일합니다. 향후 이 플러그인 사본을 정본으로 유지합니다.
