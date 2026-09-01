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
related: ["[[plot-style]]", "[[figure-export]]", "[[comment-style]]", "[[frf-ms-design]]"]
---

# REM2 Plugin

MATLAB 과학/공학 플롯 스타일·FRF 제어기 설계를 제공하는 **비공식** 플러그인입니다. 연세대학교나 정밀생산메카트로닉스 연구실(REM2)의 공식 산출물이 아니며, 후배들의 도전적인 figure를 보다 못한 한 대학원생이 조금이나마 해소하고자 만들었습니다.

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
      evals/                       ← 트리거·규칙 적용 검증 케이스 (+ inputs/)
    figure-export/
      SKILL.md                     ← 논문 투고용 공통 규칙 + 저널 프리셋 디스패치
      references/                  ← 저널 프리셋 (ieee.md — 기본, elsevier.md)
      examples/                    ← 단일 패널 + 다중 패널(tiledlayout) 예제
      evals/
    comment-style/
      SKILL.md                     ← 간결 주석 규칙 (references/ 없는 단일 파일 스킬)
      examples/                    ← before/after 예제
      evals/                       ← eval 케이스 + inputs/ fixture
    frf-ms-design/
      SKILL.md                     ← FRF 루프쉐이핑 규약 (플랜트 모델·구조 선택·ZOH)
      references/                  ← Excel 포맷 + 워크플로 순서
      scripts/                     ← read → fit → design → analyze → plot 파이프라인
      examples/                    ← 예제 워크북 + 빈 템플릿
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

`dist/chatgpt/` 아래 스킬별 zip(`plot-style.zip`, `figure-export.zip`, `comment-style.zip`, `frf-ms-design.zip`)을 업로드 — 절차는 [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) 참고.

## 현재 수록 스킬

| 스킬              | 용도                                                                                                                                              | 상태     |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `plot-style`    | MATLAB 과학/공학 플롯 일관 스타일 — 공통 규칙 + time-series / X–Y / 3-D / frequency-response 모듈, before/after 예제 포함                                            | stable |
| `figure-export` | 논문 투고용 figure 내보내기 — 저널 칼럼 폭 원본 크기 제작(cm), 인쇄 크기 폰트, 벡터 PDF(`exportgraphics`), 흑백 인쇄 생존성(선 스타일·마커 + 회색조 검증). IEEE Transactions(기본)·Elsevier 프리셋 | stable |
| `comment-style` | 간결한 코드 주석 규칙 — 알고리즘 핵심부만, 단위·매직넘버·수식 출처·부호 규약 중심. 영어 기본(플롯 스킬 적용 코드는 한국어)                                                                       | stable |
| `frf-ms-design` | 측정 SISO FRF Excel → s-domain+시간지연 플랜트 적합(`tfest`) → lag / lead-lag 자동 선택 설계 → 마진·스텝 응답 예측. MATLAB 전용(Simulink 불필요), 포맷 오류는 fail-fast 후 사용자와 interactive 해결 | stable |

플롯 코드를 새로 작성·수정할 때 자동 트리거됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다. plot-style은 축 내부(라벨·범례·한계), figure-export는 물리적 크기·폰트·내보내기를 담당하며 두 스킬은 함께 동작합니다. frf-ms-design은 측정 FRF 기반 제어기 설계 요청 시 트리거됩니다.

## 비고

- 플러그인 스킬은 lab vault frontmatter 규칙과 별개로 Claude 표준 `name`/`description` frontmatter를 씁니다 (스킬 자동 발견에 필요).
