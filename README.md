# REM2 Plugin

MATLAB 과학/공학 플롯 스타일과 측정 FRF 기반 제어기 설계 워크플로를 제공하는 AI 코딩 에이전트용 플러그인입니다.

> **비공식 안내** — 연세대학교 또는 REM2 연구실의 공식 산출물이 아닙니다. 후배들의 도전적인 figure를 보다 못한 한 대학원생이 조금이나마 스트레스를 사전에 해소하고자 만든 개인 프로젝트입니다.

## 수록 스킬

| 스킬 | 내용 |
|---|---|
| `plot-style` | MATLAB 플롯 공통 규칙(figure 1개 + 플롯별 탭, 폰트·격자·범례·라벨·축 한계·종횡비) + 케이스별 모듈(time-series / X–Y / 3-D / frequency-response) + 실행 가능한 before/after 예제 |
| `frf-ms-design` | 측정 SISO FRF Excel → s-domain+시간지연 플랜트 적합(`tfest`) → lag / lead-lag 자동 선택 설계 → 마진·스텝 응답 예측. MATLAB 전용(Simulink 불필요), 포맷 오류는 fail-fast 후 사용자와 interactive 해결 |
| `git-commit` | Conventional Commits 규칙으로 diff 분석 → type/scope 판별 → 메시지 생성·스테이징·커밋 실행 (github/awesome-copilot 이식) |
| `conventional-commit` | Conventional Commits 메시지 구조(type/scope/description/body/footer)·예제·검증 규칙을 XML 템플릿으로 안내 (awesome-copilot 이식) |
| `commit-message-storyteller` | diff에서 "왜" 바꿨는지 서술하는 Conventional Commits 메시지 생성 — 메시지만 작성, git 명령은 실행하지 않음 (awesome-copilot 이식) |
| `lean-comments` | 소스 코드 주석 최소화 규칙 — 코드에서 복원할 수 없는 비자명 정보만 남기고 나머지는 삭제, 언어 무관 (awesome-copilot 이식) |
| `github-release` | `gh`+`git`으로 릴리스 end-to-end — 마지막 태그 이후 diff 분석 → SemVer 결정 → Keep a Changelog 작성 → 릴리스 브랜치·PR (awesome-copilot 이식) |

플롯 코드를 새로 작성하거나 수정할 때 자동으로 적용됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다. frf-ms-design은 측정 FRF 기반 제어기 설계 요청 시 트리거됩니다. Git 규약 스킬 5종(`git-commit`, `conventional-commit`, `commit-message-storyteller`, `lean-comments`, `github-release`)은 [github/awesome-copilot](https://github.com/github/awesome-copilot/tree/main/skills)의 스킬을 이식한 것입니다(MIT, 스킬 폴더별 LICENSE 포함). frontmatter를 Claude Code·Codex 호환으로 맞추고, Copilot 전용 문구(확인 없는 자동 커밋, "Copilot에 붙여넣기" 등)만 에이전트 중립으로 고쳤으며 규칙 본문은 그대로입니다.

## 설치

### Claude Code

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install rem2@rem2-lab
```

업데이트:

```
/plugin marketplace update rem2-lab
```

제거 후 재설치:

```
/plugin uninstall rem2@rem2-lab
/plugin marketplace update rem2-lab
/plugin install rem2@rem2-lab
```

### Codex CLI

```
codex plugin marketplace add Hyogeon-Lee/REM2
codex /plugins
```

저장소 루트의 `.agents/plugins/marketplace.json`이 이 저장소를 Codex marketplace(`rem2-lab`)로 등록합니다. `codex /plugins`로 열리는 plugin 디렉터리(TUI)에서 `rem2-lab` 탭의 `rem2-plugin`을 선택해 설치하세요. 갱신: `codex plugin marketplace upgrade rem2-lab`.

### ChatGPT (workspace skill)

`dist/chatgpt/` 아래 스킬별 zip(`plot-style.zip`, `frf-ms-design.zip`, `git-commit.zip`, `conventional-commit.zip`, `commit-message-storyteller.zip`, `lean-comments.zip`, `github-release.zip`)을 ChatGPT workspace skill 관리 화면에서 업로드합니다. 절차는 [`dist/chatgpt/README.md`](dist/chatgpt/README.md) 참고.

## 사용법

설치 후 별도 호출 없이, 플롯 관련 요청 시 스킬이 자동 트리거됩니다.

```
이 MATLAB 스크립트에 REM2 plot style 적용해줘
REM2 스타일로 Bode plot 그려줘
이 플롯 규칙을 matplotlib로 변환해줘
이 FRF 엑셀 파일로 제어기 설계해줘
```

규칙 전문은 각 스킬의 `SKILL.md`, 케이스·프리셋별 세부 규칙은 각 스킬의 `references/`, 실행 예제는 `examples/` 참고 — 예: [`plot-style/SKILL.md`](REM2-plugin/skills/plot-style/SKILL.md).

## 저장소 구조

```
.agents/plugins/marketplace.json     ← Codex marketplace 등록
.claude-plugin/marketplace.json      ← Claude Code marketplace 등록
REM2-plugin/                         ← 플러그인 본체
  .claude-plugin/plugin.json         ← Claude Code 매니페스트
  .codex-plugin/plugin.json          ← Codex 매니페스트
  skills/plot-style/                 ← 스킬 (SKILL.md + references/ + examples/)
  skills/frf-ms-design/              ← 측정 FRF 제어기 설계 스킬
  skills/git-commit/                 ← Conventional Commits 커밋 스킬 (awesome-copilot 이식)
  skills/conventional-commit/        ← Conventional Commits 메시지 템플릿 스킬 (awesome-copilot 이식)
  skills/commit-message-storyteller/ ← 서술형 커밋 메시지 스킬 (awesome-copilot 이식)
  skills/lean-comments/              ← 최소 주석 규칙 스킬 (awesome-copilot 이식)
  skills/github-release/             ← SemVer·Changelog 릴리스 스킬 (awesome-copilot 이식)
dist/chatgpt/                        ← ChatGPT 업로드용 zip (스킬별)
```

## 라이선스

MIT — [Hyogeon Lee](https://github.com/Hyogeon-Lee)
