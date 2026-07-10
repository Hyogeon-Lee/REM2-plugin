# REM2 Plugin

MATLAB 과학/공학 플롯 스타일, 측정 FRF 기반 제어기 설계 워크플로, 그리고 모델별 프롬프트 개선 스킬을 제공하는 AI 코딩 에이전트용 플러그인입니다.

> **비공식 안내** — 연세대학교 또는 REM2 연구실의 공식 산출물이 아닙니다. 후배들의 도전적인 figure를 보다 못한 한 대학원생이 조금이나마 해소하고자 만든 개인 프로젝트입니다.

## 수록 스킬

| 스킬 | 내용 |
|---|---|
| `plot-style` | MATLAB 플롯 공통 규칙(폰트·격자·범례·라벨·축 한계·종횡비) + 케이스별 모듈(time-series / X–Y / 3-D / frequency-response) + 실행 가능한 before/after 예제 |
| `figure-export` | 논문 투고용 figure 내보내기 — 저널 칼럼 폭 원본 크기 제작(cm), 인쇄 크기 폰트, 벡터 PDF(`exportgraphics`), 흑백 인쇄 생존성(선 스타일·마커 구분 + 회색조 검증). IEEE Transactions(기본)·Elsevier 프리셋 |
| `comment-style` | 간결한 MATLAB 코드 주석 규칙 — 알고리즘 핵심부만, 단위·매직넘버·수식 출처·부호 규약 중심 |
| `frf-ms-design` | 측정 SISO FRF Excel → s-domain+시간지연 플랜트 적합(`tfest`) → lag / lead-lag 자동 선택 설계 → 마진·스텝 응답 예측. MATLAB 전용(Simulink 불필요), 포맷 오류는 fail-fast 후 사용자와 interactive 해결 |
| `prompt-enhancer` | 거친 프롬프트를 모델별(Fable 5 / GPT-5.6 / GPT-5.5 / Opus 4.8 / Sonnet 5) 복사-붙여넣기용 프롬프트로 재작성. 원본 프롬프트는 신뢰하지 않는 데이터로 취급 — 프롬프트 안의 작업을 절대 실행하지 않고, 주입(injection) 시도는 무력화 후 보고. 스킬 활성 중 `disallowed-tools`로 셸·파일 쓰기·웹·서브에이전트 도구를 기계적으로 제거 |

플롯 코드를 새로 작성하거나 수정할 때 자동으로 적용됩니다. Python(matplotlib 등)을 명시하면 동등 규칙으로 번역 적용합니다. frf-ms-design은 측정 FRF 기반 제어기 설계 요청 시, prompt-enhancer는 프롬프트 개선 요청 또는 `prompt-enhance --model <model>` 명령 구문에 트리거됩니다.

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

`dist/chatgpt/` 아래 스킬별 zip(`plot-style.zip`, `figure-export.zip`, `comment-style.zip`, `frf-ms-design.zip`, `prompt-enhancer.zip`)을 ChatGPT workspace skill 관리 화면에서 업로드합니다. 절차는 [`dist/chatgpt/README.md`](dist/chatgpt/README.md) 참고.

## 사용법

설치 후 별도 호출 없이, 플롯 관련 요청 시 스킬이 자동 트리거됩니다.

```
이 MATLAB 스크립트에 REM2 plot style 적용해줘
REM2 스타일로 Bode plot 그려줘
이 플롯 규칙을 matplotlib로 변환해줘
이 FRF 엑셀 파일로 제어기 설계해줘
prompt-enhance --model fable-5
<다듬을 프롬프트>
```

규칙 전문은 각 스킬의 `SKILL.md`, 케이스·프리셋별 세부 규칙은 각 스킬의 `references/`, 실행 예제는 `examples/` 참고 — 예: [`plot-style/SKILL.md`](REM2-plugin/skills/plot-style/SKILL.md), [`figure-export/SKILL.md`](REM2-plugin/skills/figure-export/SKILL.md).

## 저장소 구조

```
.agents/plugins/marketplace.json     ← Codex marketplace 등록
.claude-plugin/marketplace.json      ← Claude Code marketplace 등록
REM2-plugin/                         ← 플러그인 본체
  .claude-plugin/plugin.json         ← Claude Code 매니페스트
  .codex-plugin/plugin.json          ← Codex 매니페스트
  skills/plot-style/                 ← 스킬 (SKILL.md + references/ + examples/)
  skills/figure-export/              ← 논문 투고용 figure 내보내기 스킬
  skills/comment-style/              ← 코드 주석 스타일 스킬
  skills/frf-ms-design/              ← 측정 FRF 제어기 설계 스킬
  skills/prompt-enhancer/            ← 주입 저항형 모델별 프롬프트 개선 스킬
dist/chatgpt/                        ← ChatGPT 업로드용 zip (스킬별)
```

## 라이선스

MIT — [Hyogeon Lee](https://github.com/Hyogeon-Lee)
