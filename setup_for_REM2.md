# Claude Code 셋업 가이드 (REM2)

저장소 관리자가 Claude Code에서 쓰는 MCP 서버·플러그인·전역 지침 가운데 권장 항목을 설치하는 절차입니다.

**사람이 읽는 경우** — 직접 따라 할 필요 없습니다. Claude Code를 열고 아래처럼 입력하면 됩니다.

```
https://github.com/Hyogeon-Lee/REM2-plugin 의 setup_for_REM2.md 를 읽고 그대로 셋업해줘
```

## 설치되는 것

| 단계 | 이름 | 종류 | 구분 | 효과 |
|---|---|---|---|---|
| 1 | MATLAB Agentic Toolkit | MCP 서버 + 스킬 | **필수** | Claude가 MATLAB·Simulink를 직접 실행·검사 |
| 2 | `rem2` | 플러그인 | 권장 | MATLAB 플롯 스타일, FRF 제어기 설계, Git 규약 스킬 |
| 3 | `superpowers` | 플러그인 | 권장 | 계획 → 구현 → 검증 절차를 지키게 하는 스킬 묶음 |
| 4 | `ponytail` | 플러그인 (훅 포함) | 권장 | 요청 범위 안에서 가장 작은 변경만 하도록 제한 |
| 5 | `caveman` | 플러그인 (훅 포함) | 권장 | 응답을 압축해 출력 토큰 절감 |
| 6 | Karpathy Guidelines | `CLAUDE.md` | 권장 | 과잉 구현과 임의 가정을 줄이는 전역 지침 |
| 7 | `codegraph`, `kordoc`, `stack-diagram`, 스킬 노출 줄이기 | — | 선택 | 사용자가 고른 것만 설치 |

---

## AI 에이전트가 지킬 규칙

이 문서를 읽고 셋업을 수행하는 AI 에이전트는 아래 규칙을 따릅니다.

1. **0단계부터 8단계까지 번호 순서대로 진행합니다.** 단계를 건너뛰거나 순서를 바꾸지 않습니다.
2. **각 단계는 "확인 → 실행 → 검증" 순서입니다.** "확인"에서 이미 설치되어 있으면 "실행"을 건너뛰고 "이미 있음"으로 기록합니다.
3. **셸에서 `claude ...` 명령을 실행합니다.** `/plugin ...` 같은 슬래시 명령은 사람이 입력창에 치는 명령이라 에이전트가 실행할 수 없습니다. 이 문서의 명령은 모두 셸 명령입니다.
4. **`~/.claude/settings.json`과 `~/.claude/CLAUDE.md`를 통째로 덮어쓰지 않습니다.** 기존 내용을 읽고, 이 문서가 지정한 부분만 추가합니다.
5. **이 문서에 없는 것은 설치하지 않습니다.** 명령이 실패했을 때 다른 패키지나 다른 명령으로 대체하지 않습니다.
6. **단계가 실패하면 오류 메시지 한 줄을 기록하고 다음 단계로 넘어갑니다.** 같은 명령은 한 번만 다시 시도합니다.
7. **사용자에게 묻는 지점은 문서에 "사용자에게 묻기"라고 표시된 곳뿐입니다.** 그 밖에는 묻지 않고 진행합니다.
8. **`~`는 사용자 홈 폴더입니다.** Windows에서는 `C:\Users\<사용자 이름>`, macOS·Linux에서는 `$HOME`입니다.
9. **Windows PowerShell에서는 `curl` 대신 `curl.exe`를 씁니다.** PowerShell의 `curl`은 다른 명령의 별칭이라 옵션이 다릅니다.
10. **마지막에 8단계의 결과표를 사용자에게 보여 줍니다.**

---

## 0단계. 사전 확인

아래 명령을 하나씩 실행해 버전이 출력되는지 봅니다.

```bash
claude --version
```

```bash
git --version
```

```bash
node --version
```

| 결과 | 처리 |
|---|---|
| `claude`가 없음 | 중단합니다. 사용자에게 Claude Code 설치가 필요하다고 알립니다. |
| `git`이 없음 | 중단합니다. 플러그인 마켓플레이스를 받을 수 없습니다. |
| `node`가 없음 | 계속 진행합니다. 다만 4단계(`ponytail`)와 5단계(`caveman`)의 훅이 Node.js로 실행되므로 마지막에 "Node.js를 설치해야 두 모드가 자동으로 켜집니다"라고 안내합니다. |

현재 설치 상태를 확인해 둡니다. 이후 단계의 "확인"에서 이 출력을 씁니다.

```bash
claude plugin list
```

```bash
claude mcp list
```

---

## 1단계. MATLAB Agentic Toolkit (필수)

**이 문서에서 가장 중요한 단계입니다. 건너뛰지 않습니다.**

MathWorks가 배포하는 공식 도구입니다. 설치하면 Claude가 로컬 MATLAB에서 코드를 실행하고, 정적 분석과 테스트를 돌리고, Simulink 모델을 읽고 편집합니다. 생성한 MATLAB 코드를 Claude가 직접 실행해 오류를 확인하고 고칩니다. 그래서 `rem2` 플러그인의 `plot-style`과 `frf-ms-design`이 제대로 동작하려면 이 단계가 필요합니다.

설치 프로그램 하나가 아래 세 가지를 함께 설치합니다.

| 구성 요소 | 역할 |
|---|---|
| MATLAB MCP Server | Claude Code와 MATLAB을 연결하는 `matlab` MCP 서버 |
| MATLAB Agentic Toolkit | MATLAB용 스킬 |
| Simulink Agentic Toolkit | Simulink용 스킬과 모델 편집 도구 |

출처: [matlab/agentic-toolkit-installer](https://github.com/matlab/agentic-toolkit-installer)

### 요구 사항

| 항목 | 조건 |
|---|---|
| MATLAB | R2021a 이상. Simulink까지 쓰려면 R2023a 이상 |
| 운영체제 | Windows (x64), Linux (x64), macOS (Intel 또는 Apple Silicon) |

### 확인

`claude mcp list` 출력에 `matlab`이 있으면 "이미 있음"으로 기록하고 [권한 허용](#권한-허용-사용자에게-묻기)으로 갑니다.

### MATLAB이 설치되어 있는지 확인

```bash
matlab -help
```

명령을 찾을 수 없다고 나오면 MATLAB 설치 폴더가 있는지 봅니다.

| 운영체제 | 기본 설치 폴더 |
|---|---|
| Windows | `C:\Program Files\MATLAB\R20xxx` |
| macOS | `/Applications/MATLAB_R20xxx.app` |
| Linux | `/usr/local/MATLAB/R20xxx` |

| 결과 | 처리 |
|---|---|
| `matlab` 명령이 동작함 | 아래 "실행"을 그대로 진행합니다. |
| 명령은 없지만 설치 폴더가 있음 | 가장 최신 버전의 폴더 경로를 기억해 두고, "실행"의 `install` 명령 끝에 `--matlab-root "<폴더 경로>"`를 붙입니다. 경로에 `bin`은 넣지 않습니다. |
| MATLAB이 없음 | 이 단계를 "실패 (MATLAB 없음)"으로 기록하고 2단계로 넘어갑니다. 8단계에서 결과를 보고할 때 **"MATLAB을 먼저 설치한 뒤 이 셋업을 다시 실행해야 합니다"**라고 가장 먼저 알립니다. MATLAB 자체는 라이선스 로그인이 필요해 에이전트가 설치하지 않습니다. |

### 실행

세 명령을 순서대로 실행합니다. 첫 번째는 설치 프로그램을 내려받고, 두 번째는 툴킷과 MATLAB 툴박스를 설치하고, 세 번째는 Claude Code에 MCP 서버와 스킬을 등록합니다.

**Windows (PowerShell)**

```powershell
curl.exe -L -o "$HOME\agentic-toolkit-installer.exe" https://github.com/matlab/agentic-toolkit-installer/releases/latest/download/agentic-toolkit-installer-windows-x64.exe
```

```powershell
& "$HOME\agentic-toolkit-installer.exe" install --non-interactive
```

```powershell
& "$HOME\agentic-toolkit-installer.exe" configure --non-interactive --scope user
```

**macOS, Linux** — 첫 명령의 URL 끝부분만 아래 표에서 골라 바꿉니다.

| 운영체제 | URL 끝부분 |
|---|---|
| macOS (Apple Silicon) | `agentic-toolkit-installer-macos-arm64` |
| macOS (Intel) | `agentic-toolkit-installer-macos-x64` |
| Linux (x64) | `agentic-toolkit-installer-linux-x64` |

```bash
curl -L -o ~/agentic-toolkit-installer https://github.com/matlab/agentic-toolkit-installer/releases/latest/download/agentic-toolkit-installer-macos-arm64 && chmod +x ~/agentic-toolkit-installer
```

```bash
~/agentic-toolkit-installer install --non-interactive
```

```bash
~/agentic-toolkit-installer configure --non-interactive --scope user
```

| 옵션 | 역할 |
|---|---|
| `install` | 툴킷을 내려받고, 찾아낸 MATLAB에 필요한 툴박스를 설치 |
| `configure` | 감지한 코딩 에이전트(Claude Code 등)에 MCP 서버와 스킬을 등록 |
| `--non-interactive` | 질문 없이 기본값으로 진행. 에이전트는 질문에 답할 수 없으므로 반드시 붙입니다. 이 옵션을 붙인 `install`은 `configure`를 자동으로 실행하지 않으므로 세 번째 명령이 따로 필요합니다. |
| `--scope user` | 모든 프로젝트에서 쓰도록 사용자 범위에 등록 |
| `--matlab-root "<경로>"` | `matlab`이 `PATH`에 없을 때 MATLAB 설치 폴더를 직접 지정 (`install`에만 사용) |

에이전트의 권한 설정 때문에 내려받기나 실행이 막히면 다른 방법을 찾지 말고 위 세 명령을 사용자에게 그대로 보여 주며 직접 실행해 달라고 요청합니다. 이때 결과는 "사용자 조치 필요"로 기록합니다.

### 검증

아래 명령의 출력에 `matlab`이 있어야 합니다.

```bash
claude mcp list
```

설치 프로그램의 `status` 명령으로 설치 상태 요약을 봅니다.

```powershell
& "$HOME\agentic-toolkit-installer.exe" status
```

### 권한 허용 (사용자에게 묻기)

`matlab` 서버가 등록된 경우에만 묻습니다.

> MATLAB MCP 도구를 매번 확인 창 없이 실행하도록 허용할까요?

"예"라고 하면 `~/.claude/settings.json`을 아래 순서로 수정합니다.

1. 파일이 있으면 같은 폴더에 `settings.json.bak-setup`이라는 이름으로 복사합니다.
2. 아래 표에서 현재 파일 상태에 맞는 행을 골라 수정합니다.

| 현재 상태 | 수정 방법 |
|---|---|
| 파일이 없음 | `{ "permissions": { "allow": ["mcp__matlab"] } }`를 내용으로 새 파일을 만듭니다. |
| `permissions` 키가 없음 | 최상위 객체에 `"permissions": { "allow": ["mcp__matlab"] }`를 추가합니다. |
| `permissions`는 있고 `allow`가 없음 | `permissions` 객체에 `"allow": ["mcp__matlab"]`를 추가합니다. |
| `permissions.allow` 배열이 있음 | 배열 끝에 `"mcp__matlab"`을 덧붙입니다. 이미 있으면 그대로 둡니다. 기존 항목은 지우지 않습니다. |

3. 아래 명령이 `OK`를 출력하는지 확인합니다. 오류가 나면 JSON 문법이 깨진 것이므로 `settings.json.bak-setup`을 `settings.json`으로 되돌리고 "실패"로 기록합니다. `node`가 없으면 파일을 다시 읽어 중괄호와 쉼표가 맞는지 눈으로 확인합니다.

```bash
node -e "JSON.parse(require('fs').readFileSync(require('os').homedir()+'/.claude/settings.json','utf8'));console.log('OK')"
```

### 사용자에게 전달할 안내

- Claude Code를 다시 시작한 뒤 "지금 실행 중인 MATLAB 버전과 설치된 툴박스를 알려줘"라고 물어 연결을 확인합니다.
- 기본 설치는 필수 스킬 묶음만 켭니다. 신호 처리, 제어, Simulink 등 추가 스킬 묶음은 터미널에서 `agentic-toolkit-installer configure`를 직접 실행해 고릅니다.
- 이미 열려 있는 MATLAB 창에 Claude를 연결하려면 그 MATLAB 명령 창에서 `shareMATLABSession()`을 실행합니다. 실행하지 않으면 Claude가 새 MATLAB 세션을 띄웁니다.

---

## 2단계. `rem2` 플러그인

이 저장소의 플러그인입니다. 스킬 목록과 사용법은 [README.md](README.md)에 있습니다.

**확인** — `claude plugin list` 출력에 `rem2@rem2-lab`이 있으면 건너뜁니다.

**실행**

```bash
claude plugin marketplace add Hyogeon-Lee/REM2-plugin
```

```bash
claude plugin install rem2@rem2-lab
```

**검증** — `claude plugin list` 출력에 `rem2@rem2-lab`이 있어야 합니다.

---

## 3단계. `superpowers` 플러그인

브레인스토밍, 계획 작성, TDD, 체계적 디버깅, 완료 전 검증을 다루는 스킬 묶음입니다. 세션이 시작될 때 "해당하는 스킬이 있으면 먼저 호출한다"는 규칙을 넣어 주므로 Claude가 절차를 건너뛰지 않습니다.

**확인** — `claude plugin list` 출력에 `superpowers@claude-plugins-official`이 있으면 건너뜁니다.

**실행**

```bash
claude plugin install superpowers@claude-plugins-official
```

"marketplace not found" 오류가 나면 아래를 먼저 실행한 뒤 위 명령을 다시 실행합니다.

```bash
claude plugin marketplace add anthropics/claude-plugins-official
```

**검증** — `claude plugin list` 출력에 `superpowers@claude-plugins-official`이 있어야 합니다.

---

## 4단계. `ponytail` 플러그인

[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) — "작성하지 않은 코드가 가장 좋은 코드"를 원칙으로, 요청받지 않은 기능·추상화·설정을 넣지 못하게 합니다.

**확인** — `claude plugin list` 출력에 `ponytail@ponytail`이 있으면 건너뜁니다.

**실행**

```bash
claude plugin marketplace add DietrichGebert/ponytail
```

```bash
claude plugin install ponytail@ponytail
```

**검증** — `claude plugin list` 출력에 `ponytail@ponytail`이 있어야 합니다.

---

## 5단계. `caveman` 플러그인

[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) — 관사·군말·인사말을 빼고 기술 내용만 남기는 응답 모드입니다. 코드, 명령어, 오류 메시지는 바꾸지 않습니다. 커밋 메시지·문서·코드 주석처럼 파일로 남는 글에도 적용되지 않습니다.

**확인** — 아래 중 하나라도 해당하면 이미 설치된 것이므로 건너뜁니다. 두 방식을 함께 쓰면 같은 규칙이 두 번 들어갑니다.

- `claude plugin list` 출력에 `caveman@caveman`이 있음
- `~/.claude/skills/caveman/SKILL.md` 파일이 있음 (스킬로 따로 설치한 경우)

**실행**

```bash
claude plugin marketplace add JuliusBrussee/caveman
```

```bash
claude plugin install caveman@caveman
```

**검증** — `claude plugin list` 출력에 `caveman@caveman`이 있어야 합니다.

### 훅에 대하여

`ponytail`과 `caveman`은 **플러그인을 설치하면 훅이 함께 등록됩니다.** 그래서 매 세션 자동으로 켜지며, `~/.claude/settings.json`에 훅을 직접 추가하지 않습니다.

| 훅 | 실행 시점 | 동작 |
|---|---|---|
| `SessionStart` | 세션 시작 | 모드 규칙을 Claude의 컨텍스트에 추가 |
| `SubagentStart` | 서브에이전트 시작 | 서브에이전트에도 같은 규칙을 전달 |
| `UserPromptSubmit` | 사용자가 프롬프트를 보낼 때 | `/caveman ultra`, `/ponytail lite` 같은 강도 변경을 추적 |

두 모드는 역할이 겹치지 않습니다. `caveman`은 응답 문장을 줄이고, `ponytail`은 코드 변경 범위를 줄입니다. 두 훅 모두 Node.js로 실행됩니다.

| 모드 | 끄기 | 강도 변경 |
|---|---|---|
| `caveman` | `stop caveman` 또는 `normal mode` | `/caveman lite\|full\|ultra` |
| `ponytail` | `stop ponytail` 또는 `normal mode` | `/ponytail lite\|full\|ultra` |

---

## 6단계. Karpathy Guidelines를 `~/.claude/CLAUDE.md`에 추가

[forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) 저장소의 `CLAUDE.md`를 내려받아 전역 지침 파일에 덧붙입니다. `~/.claude/CLAUDE.md`의 내용은 모든 프로젝트의 모든 세션에 항상 적용됩니다.

| 규칙 | 요지 |
|---|---|
| Think Before Coding | 가정을 명시하고, 해석이 여럿이면 드러내고, 불명확하면 멈춰서 묻는다 |
| Simplicity First | 요청받지 않은 기능·추상화·설정 가능성을 넣지 않는다 |
| Surgical Changes | 요청과 직접 연결되는 줄만 고친다 |
| Goal-Driven Execution | 검증 가능한 성공 기준을 세우고 통과할 때까지 반복한다 |

**확인** — `~/.claude/CLAUDE.md`가 있고 그 안에 `## 1. Think Before Coding`이라는 줄이 있으면 건너뜁니다.

**실행** — 내용을 직접 타이핑하거나 요약하지 않습니다. 반드시 내려받은 파일을 그대로 덧붙입니다.

1. 파일을 내려받습니다.

   bash (macOS, Linux, Windows의 Git Bash):

   ```bash
   mkdir -p ~/.claude && curl -fsSL https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md -o ~/.claude/karpathy-guidelines.md
   ```

   Windows PowerShell:

   ```powershell
   curl.exe -fsSL https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md -o "$HOME\.claude\karpathy-guidelines.md"
   ```

   내려받기가 실패했으면 2번을 실행하지 않고 "실패"로 기록합니다.

2. 내려받은 파일의 전체 내용을 `~/.claude/CLAUDE.md`의 **끝에** 덧붙입니다. `CLAUDE.md`가 없으면 새로 만들어집니다. 기존 내용은 지우지 않습니다.

   bash:

   ```bash
   printf '\n\n' >> ~/.claude/CLAUDE.md && cat ~/.claude/karpathy-guidelines.md >> ~/.claude/CLAUDE.md
   ```

   bash를 쓸 수 없으면 파일 읽기·편집 도구로 `karpathy-guidelines.md`를 읽어 `CLAUDE.md` 끝에 그대로 붙여 넣습니다.

3. 내려받은 임시 파일을 지웁니다.

   ```bash
   rm ~/.claude/karpathy-guidelines.md
   ```

| 부분 | 역할 |
|---|---|
| `curl -fsSL ... -o <파일>` | URL의 내용을 파일로 저장. `-f`는 HTTP 오류 시 실패 처리, `-sS`는 진행 표시 없이 오류만 출력, `-L`은 리다이렉트를 따라감 |
| `printf '\n\n' >>` | 기존 내용과 새 내용 사이에 빈 줄을 넣음 |
| `cat <파일> >>` | 파일 내용을 대상 파일 끝에 이어 붙임. `>>`는 덮어쓰지 않고 덧붙이는 연산자 |

**검증** — `~/.claude/CLAUDE.md`를 읽어 `## 1. Think Before Coding` 줄이 정확히 한 번 있는지 확인합니다.

---

## 7단계. 선택 항목

**사용자에게 묻기** — 아래 표를 보여 주고 설치할 것을 고르게 합니다. 아무것도 고르지 않으면 8단계로 갑니다. 고르지 않은 항목은 "건너뜀 (사용자 선택)"으로 기록합니다.

| 번호 | 이름 | 쓰는 경우 |
|---|---|---|
| A | `codegraph` MCP 서버 | C++·Python 등 여러 파일로 된 코드 저장소에서 작업할 때. Claude가 심볼과 호출 관계를 한 번에 조회 |
| B | `kordoc` 플러그인 | 한글(HWP 등) 문서를 다룰 때 |
| C | `stack-diagram` 스킬 | 시스템 구성도를 HTML·PNG로 만들 때 |
| D | 스킬 노출 줄이기 | 설치된 스킬이 많아 목록이 컨텍스트를 많이 차지할 때 |

### A. `codegraph`

[`@colbymchenry/codegraph`](https://www.npmjs.com/package/@colbymchenry/codegraph) — 저장소의 심볼, 호출 관계, 파일을 SQLite 그래프로 색인합니다. Claude가 grep과 파일 읽기를 반복하는 대신 한 번의 호출로 관련 소스와 호출 경로를 받습니다. Node.js가 필요합니다.

**확인** — `claude mcp list` 출력에 `codegraph`가 있으면 건너뜁니다.

**실행**

```bash
npm install -g @colbymchenry/codegraph
```

```bash
claude mcp add --scope user codegraph -- codegraph serve --mcp
```

| 부분 | 역할 |
|---|---|
| `--scope user` | 모든 프로젝트에서 쓰도록 사용자 범위에 등록 |
| `codegraph` (첫 번째) | Claude Code에 등록되는 서버 이름 |
| `--` 뒤 | 서버를 띄우는 실제 명령 |

**검증** — `claude mcp list` 출력에 `codegraph`가 있어야 합니다.

**`CLAUDE.md`에 규칙 추가** — `~/.claude/CLAUDE.md`에 `## CodeGraph`라는 줄이 없으면 파일 끝에 아래 블록의 안쪽 내용을 덧붙입니다. 맨 앞과 맨 뒤의 ```` 줄은 넣지 않습니다.

````markdown
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
````

**색인은 만들지 않습니다.** 사용자에게 아래 안내를 전달합니다.

> CodeGraph를 쓰려면 해당 저장소 폴더에서 `codegraph init`을 한 번 실행하세요. 색인(`.codegraph/`)이 없는 저장소에서는 동작하지 않습니다.

### B. `kordoc`

**확인** — `claude plugin list` 출력에 `kordoc@kordoc`이 있으면 건너뜁니다.

**실행**

```bash
claude plugin marketplace add chrisryugj/kordoc
```

```bash
claude plugin install kordoc@kordoc
```

**검증** — `claude plugin list` 출력에 `kordoc@kordoc`이 있어야 합니다.

### C. `stack-diagram`

[caru-ini/stack-diagram](https://github.com/caru-ini/stack-diagram) — Node.js가 필요합니다.

**확인** — `~/.claude/skills/stack-diagram/SKILL.md` 파일이 있으면 건너뜁니다.

**실행**

```bash
npx --yes skills add caru-ini/stack-diagram --global --agent claude-code --yes
```

| 옵션 | 역할 |
|---|---|
| `--global` | 현재 프로젝트가 아니라 사용자 홈(`~/.claude/skills/`)에 설치 |
| `--agent claude-code` | Claude Code용 위치에만 설치 |
| `--yes` | 확인 질문 없이 진행 |

**검증** — `~/.claude/skills/stack-diagram/SKILL.md` 파일이 있어야 합니다. 없으면 같은 명령 끝에 `--copy`를 붙여 한 번 다시 실행합니다. Windows에서 심볼릭 링크 권한이 없을 때 필요합니다.

### D. 스킬 노출 줄이기

Claude Code는 설치된 모든 스킬의 이름과 설명을 매 세션 컨텍스트에 싣습니다. MATLAB Agentic Toolkit에서 스킬 묶음을 여러 개 켜면 스킬이 100개를 넘으므로 `~/.claude/settings.json`의 `skillOverrides`로 스킬별 노출 방식을 지정해 줄입니다.

| 값 | 동작 |
|---|---|
| `"name-only"` | 이름만 목록에 싣고 설명은 생략 |
| `"user-invocable-only"` | 모델이 스스로 호출하지 않음. 사용자가 `/이름`으로 부를 때만 실행 |
| `"off"` | 완전히 끔 |

**사용자에게 묻기** — 어떤 스킬을 어떤 값으로 지정할지 사용자가 정합니다. 에이전트가 임의로 고르지 않습니다. `~/.claude/skills/` 폴더의 스킬 이름 목록을 보여 주고 고르게 합니다.

**실행** — `~/.claude/settings.json`의 최상위 객체에 `skillOverrides` 키를 추가하거나, 이미 있으면 그 안에 항목을 덧붙입니다. 백업과 JSON 검증은 1단계의 [권한 허용](#권한-허용-사용자에게-묻기)과 같은 방식으로 합니다.

```json
{
  "skillOverrides": {
    "matlab-analyze-data": "name-only",
    "simulink-linearize": "name-only"
  }
}
```

---

## 8단계. 마무리

**결과 보고** — 아래 표를 채워 사용자에게 보여 줍니다. 결과 칸에는 `설치함`, `이미 있음`, `건너뜀 (이유)`, `실패 (오류 한 줄)`, `사용자 조치 필요` 중 하나를 씁니다.

| 단계 | 항목 | 결과 |
|---|---|---|
| 1 | MATLAB Agentic Toolkit (필수) | |
| 2 | `rem2` 플러그인 | |
| 3 | `superpowers` 플러그인 | |
| 4 | `ponytail` 플러그인 | |
| 5 | `caveman` 플러그인 | |
| 6 | `CLAUDE.md` Karpathy Guidelines | |
| 7 | 선택 항목 (고른 것만) | |

**사용자에게 전달할 말**

1. 1단계가 `설치함` 또는 `이미 있음`이 아니면 그 사실과 해야 할 일을 가장 먼저 알립니다.
2. Claude Code를 완전히 종료한 뒤 다시 시작해야 MCP 서버·플러그인·훅·`CLAUDE.md`가 적용됩니다.
3. 새 세션을 시작하면 `caveman`과 `ponytail`이 자동으로 켜집니다. 끄려면 `stop caveman`, `stop ponytail`을 입력합니다.
4. `settings.json`을 수정했다면 백업이 `~/.claude/settings.json.bak-setup`에 있습니다.
5. 1단계의 [사용자에게 전달할 안내](#사용자에게-전달할-안내)와 7단계에서 기록한 안내(`codegraph init`)를 함께 전달합니다.

**되돌리기**

| 대상 | 방법 |
|---|---|
| MATLAB Agentic Toolkit | 설치 프로그램을 `uninstall` 인자로 실행 (`agentic-toolkit-installer uninstall`) |
| 플러그인 | `claude plugin uninstall <이름>@<마켓플레이스>` |
| 권한, `skillOverrides` | `~/.claude/settings.json.bak-setup`을 `settings.json`으로 복사 |
| `CLAUDE.md` | 덧붙인 Karpathy Guidelines 부분과 `## CodeGraph` 절을 삭제 |
| `codegraph` MCP 서버 | `claude mcp remove codegraph --scope user` |
