# REM2 Plugin

MATLAB 과학/공학 플롯 스타일을 일관되게 적용해주는 AI 코딩 에이전트용 플러그인입니다.

> **비공식 안내** — 연세대학교 또는 REM2 연구실의 공식 산출물이 아닙니다. 후배들의 도전적인 figure를 보다 못한 한 대학원생이 조금이나마 해소하고자 만든 개인 프로젝트입니다.

## 수록 스킬

| 스킬 | 내용 |
|---|---|
| `plot-style` | MATLAB 플롯 공통 규칙(폰트·격자·범례·라벨·축 한계·종횡비) + 케이스별 모듈(time-series / X–Y / 3-D / frequency-response) + 실행 가능한 before/after 예제 |

플롯 코드를 새로 작성하거나 수정할 때 자동으로 적용됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다.

## 설치

### Claude Code

```
/plugin marketplace add Hyogeon-Lee/REM2
/plugin install REM2@rem2-lab
```

업데이트:

```
/plugin marketplace update rem2-lab
```

제거 후 재설치:

```
/plugin uninstall REM2@rem2-lab
/plugin marketplace update rem2-lab
/plugin install REM2@rem2-lab
```

### Codex CLI

저장소 루트의 `.agents/plugins/marketplace.json`이 이 저장소를 Codex marketplace로 등록합니다. Codex의 plugin marketplace 명령으로 이 저장소를 추가한 뒤 `rem2-plugin`을 설치하세요.

### ChatGPT (workspace skill)

`dist/chatgpt/plot-style.zip`을 ChatGPT workspace skill 관리 화면에서 업로드합니다. 절차는 [`dist/chatgpt/README.md`](dist/chatgpt/README.md) 참고.

## 사용법

설치 후 별도 호출 없이, 플롯 관련 요청 시 스킬이 자동 트리거됩니다.

```
이 MATLAB 스크립트에 REM2 plot style 적용해줘
REM2 스타일로 Bode plot 그려줘
이 플롯 규칙을 matplotlib로 변환해줘
```

규칙 전문은 [`REM2-plugin/skills/plot-style/SKILL.md`](REM2-plugin/skills/plot-style/SKILL.md), 케이스별 세부 규칙은 [`references/`](REM2-plugin/skills/plot-style/references), 실행 예제는 [`examples/`](REM2-plugin/skills/plot-style/examples) 참고.

## 저장소 구조

```
.agents/plugins/marketplace.json     ← Codex marketplace 등록
.claude-plugin/marketplace.json      ← Claude Code marketplace 등록
REM2-plugin/                         ← 플러그인 본체
  .claude-plugin/plugin.json         ← Claude Code 매니페스트
  .codex-plugin/plugin.json          ← Codex 매니페스트
  skills/plot-style/                 ← 스킬 (SKILL.md + references/ + examples/)
dist/chatgpt/                        ← ChatGPT 업로드용 zip
```

## 라이선스

MIT — [Hyogeon Lee](https://github.com/Hyogeon-Lee)
