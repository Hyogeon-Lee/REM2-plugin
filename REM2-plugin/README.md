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
related: ["[[plot-style]]", "[[frf-ms-design]]", "[[git-commit]]", "[[conventional-commit]]", "[[commit-message-storyteller]]", "[[lean-comments]]", "[[github-release]]"]
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
    frf-ms-design/
      SKILL.md                     ← FRF 루프쉐이핑 규약 (플랜트 모델·구조 선택·ZOH)
      references/                  ← Excel 포맷 + 워크플로 순서
      scripts/                     ← read → fit → design → analyze → plot 파이프라인
      examples/                    ← 예제 워크북 + 빈 템플릿
    git-commit/                    ← Conventional Commits 커밋 워크플로 (awesome-copilot 이식)
    conventional-commit/           ← Conventional Commits 메시지 XML 템플릿 (awesome-copilot 이식)
    commit-message-storyteller/    ← 서술형 커밋 메시지 규칙 (awesome-copilot 이식)
      references/                  ← Conventional Commits 타입별 예제·안티패턴
    lean-comments/                 ← 최소 주석 규칙, 언어 무관 (awesome-copilot 이식)
    github-release/                ← SemVer + Keep a Changelog 릴리스 워크플로 (awesome-copilot 이식)
      references/                  ← semver-rules.md, commit-classification.md
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

`dist/chatgpt/` 아래 스킬별 zip(`plot-style.zip`, `frf-ms-design.zip`)을 업로드 — 절차는 [`../dist/chatgpt/README.md`](../dist/chatgpt/README.md) 참고.

## 현재 수록 스킬

| 스킬              | 용도                                                                                                                                              | 상태     |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `plot-style`    | MATLAB 과학/공학 플롯 일관 스타일 — 공통 규칙(figure 1개 + 플롯별 탭) + time-series / X–Y / 3-D / frequency-response 모듈, before/after 예제 포함                                            | stable |
| `frf-ms-design` | 측정 SISO FRF Excel → s-domain+시간지연 플랜트 적합(`tfest`) → lag / lead-lag 자동 선택 설계 → 마진·스텝 응답 예측. MATLAB 전용(Simulink 불필요), 포맷 오류는 fail-fast 후 사용자와 interactive 해결 | stable |
| `git-commit` | Conventional Commits 커밋 — diff 분석으로 type/scope 판별, 메시지 생성, 스테이징·커밋 실행. github/awesome-copilot 이식(MIT) | stable |
| `conventional-commit` | Conventional Commits 메시지 구조(type/scope/description/body/footer)·예제·검증 규칙을 XML 템플릿으로 안내. awesome-copilot 이식 | stable |
| `commit-message-storyteller` | "왜" 바꿨는지 서술하는 Conventional Commits 메시지 생성 — 메시지만 작성, git 명령은 실행하지 않음. awesome-copilot 이식 | stable |
| `lean-comments` | 소스 코드 주석 최소화 — 코드에서 복원할 수 없는 비자명 정보만 남김, 언어 무관. awesome-copilot 이식 | stable |
| `github-release` | `gh`+`git` 릴리스 end-to-end — 마지막 태그 이후 diff 분석 → SemVer 결정 → Keep a Changelog → 릴리스 브랜치·PR. awesome-copilot 이식 | stable |

플롯 코드를 새로 작성·수정할 때 자동 트리거됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다. frf-ms-design은 측정 FRF 기반 제어기 설계 요청 시 트리거됩니다. Git 규약 스킬 5종은 [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/main/skills)에서 이식했습니다(MIT, 스킬 폴더별 LICENSE). frontmatter를 Claude Code·Codex 호환으로 맞추고, Copilot 전용 문구(확인 없는 자동 커밋, "Copilot에 붙여넣기" 등)만 에이전트 중립으로 고쳤으며 규칙 본문은 그대로입니다. 출처 커밋은 각 SKILL.md의 `metadata.source-commit`에 기록되어 있습니다.

## 비고

- 플러그인 스킬은 lab vault frontmatter 규칙과 별개로 Claude 표준 `name`/`description` frontmatter를 씁니다 (스킬 자동 발견에 필요).
