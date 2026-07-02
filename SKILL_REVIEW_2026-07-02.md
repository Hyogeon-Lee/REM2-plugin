# REM2 Plugin 스킬 검토 결과 (2026-07-02)

> 검토 방식: 병렬 multi-agent 검토 (스킬별 검토 4 + 반박검증 4, 총 8 agents).
> Finding 34건 중 반박검증 생존 **23건**. 기각 12건은 문서 하단 참고.
> 기준 버전: plugin v0.6.0 (commit 95e7b89).

## 우선순위 요약

1. **comment-style evals `inputs/` fixture 생성** — eval이 현재 완전히 실행 불가
2. **주석 언어 충돌 해소** (comment-style 영어 기본 ↔ plot-style/figure-export 한국어) — 배포 품질 직결
3. **figure-export colorOrder k=7 crash + comment-style help-block 자기모순** — 스킬 지시대로 하면 깨지는 것들
4. **README 갱신** — 스킬 3개 중 1개만 기재됨

---

## 1. comment-style (6건)

### [HIGH] evals 실행 불가 — fixture 부재
- 파일: `REM2-plugin/skills/comment-style/evals/evals.json`
- 문제: 3개 eval 모두 `inputs/coilFluxCalc.m`, `inputs/computeThd.m`, `inputs/abc2dq.m` 참조하는데 `evals/inputs/` 폴더 자체가 없음.
- 수정: `evals/inputs/` 생성 + fixture 3개 작성 (과잉 주석 flux 함수 / 주석 없는 THD 함수 / 주석 없는 abc2dq 함수). 각 fixture에 실제 help block 포함시켜 eval 0이 help-block 보존 규칙도 검증하게.

### [HIGH] SKILL.md:47-48 자기모순 — help block 판정
- 문제: 47행 "help block 절대 손대지 마라" ↔ 48행 "function 직후 주석도 body 규칙으로 판정, restatement 삭제". MATLAB에서 function 직후 연속 주석 = `help` 출력이고, H1 line은 형식상 코드를 restate함 → 48행 따르면 47행이 보호하는 블록을 지움. "genuine help block"은 체크 불가능한 기준.
- 수정: 기계적 판정 규칙으로 교체 — "function 직후 첫 주석이 H1(대문자 함수명 + 한 줄 요약)이면 연속 주석 블록 전체를 help block으로 간주하고 불변. H1 없을 때만 body 규칙 적용."

### [HIGH] pragma 주석 보호 규칙 없음
- 문제: `%#ok<...>`, `%#codegen`, `%#function`, `%#exclude` 전부 `%` 주석이라 declutter 시 삭제 대상 → codegen/배포 의존성 탐지 깨짐, analyzer 경고 재발. TODO/FIXME도 미규정.
- 수정: "Never" 목록에 추가 — "pragma 주석(%#ok, %#codegen, %#function, %#exclude)은 지시자이지 주석이 아님, 절대 삭제·이동 금지. TODO/FIXME는 사용자가 요청하지 않는 한 보존."

### [MED] AFTER 예제가 스킬 자체 규칙 위반
- 파일: `examples/before_after_example.m` + SKILL.md 예제 블록
- 문제 3건:
  1. `R_gap  =`, `theta   =` 식 `=` 정렬 패딩 — self-check 3번(주석 외 diff 금지) 위반. Format 절은 주석 컬럼 정렬만 허용.
  2. 25행 `% L = N^2 / R_total` — 코드 restate 주석 (스킬 Core principle이 첫 줄에서 금지).
  3. AFTER가 BEFORE의 `R_total` 중간 변수를 제거하고 `L = N^2/(R_core+R_gap)`로 **코드 자체 변경** — "never change code logic / never rename variables" 위반.
- 수정: 정렬 패딩 제거(또는 Format에 대입 정렬 명시 허용), restate 주석 삭제, AFTER에서 `R_total` 변수 복원.

### [MED] classdef 미다룸
- 문제: `properties` 트레일링 주석·`classdef` 아래 주석 블록은 `help`/`doc`이 property help로 노출 — body 규칙 적용 시 기능적 문서 삭제. `arguments` 블록은 보호하면서 classdef는 누락.
- 수정: MATLAB specifics에 추가 — "classdef 파일에서 `classdef`/`properties`/property 정의에 직접 붙은 주석은 help text로 간주해 보존. body 규칙은 method 내부에만 적용." Live script 포함 여부도 명시.

### [MED] eval 커버리지 공백
- 누락: (a) 로직 보존 adversarial 케이스 (버그·dead code 있는 입력 — 고치고 싶은 유혹), (b) help block/H1 보존, (c) `%#ok` pragma 생존, (d) 타 언어 (Other languages 섹션 있는데 미검증), (e) 한국어 프롬프트인데 명시 요청 없음 → 영어 주석 나와야 하는 경계 케이스.
- 수정: eval 3-4개 추가 — help block + pragma + dead code 든 declutter 파일 (help/pragma 불변, dead code는 삭제 아닌 flag, 로직 diff 0 기대) / Python 또는 C 함수 / "thd.m 주석 정리해줘" (영어 주석 기대).

---

## 2. figure-export (7건)

### [HIGH] colorOrder k=7 index out of bounds
- 파일: `SKILL.md:98-104` grayscale 분기 코드
- 문제: `lineStyles`(4)·`markerSet`(6)은 mod-wrap 하면서 `colorOrder(k,:)`는 wrap 없음 — colorOrder 6행이라 k=7에서 crash.
- 수정: `colorOrder(mod(k-1, size(colorOrder,1)) + 1, :)` 로 wrap 하거나 최대 곡선 수 명시(예: "max 6, 초과 시 패널 분리") + guard. plot-style의 series cap(6)과 상호 참조해 두 스킬 한도 일치시키기.

### [MED] "rasterize those panels" 실행 불가
- 문제: MATLAB에 패널별 rasterization API 없음 — `exportgraphics`는 figure 전체에 ContentType 하나. 혼합 figure(선도 + surf/contour)에서 문자 그대로 따를 방법 없음.
- 수정: 실제 옵션 명시 — (a) 전체를 `ContentType 'image'` + combination-art dpi(IEEE 600/Elsevier 500), (b) 패널 분리 export 후 LaTeX 조립, (c) `'auto'` 후 결과 확인. colorbar 있는 heatmap 경로도 worked example로 (TightInset fill loop invalid 케이스와 정확히 겹침).

### [MED] R2025a Width/Height/Units 미활용
- 문제: R2025a `exportgraphics`의 `Width`/`Height`/`Units` 옵션이 TightInset 2-pass fill loop이 풀려는 문제를 직접 해결하는데 미사용·미언급. Padding은 이미 R2025a 게이트함.
- 수정: Width/Units가 캔버스 리사이즈인지 콘텐츠 스케일인지 검증 후 — 스케일이면 "never scale down" 위반이라 기각 사유 명시, 리사이즈면 R2025a+ 기본 경로로 채택 + TightInset loop은 pre-R2025a fallback.

### [MED] evals 없음
- 미검증 행동: 저널 미지정 시 IEEE 기본 선택, Elsevier 저널명("Mechatronics") 인식, grayscale 블록 필수 방출, no-MCP fallback의 "미검증" 선언, 슬라이드/랩 리포트 anti-trigger.
- 수정: 프리셋별 trigger eval (영어+한국어, 예: "TMECH 제출용 figure"), anti-trigger ("발표 슬라이드용 figure"), 출력 내용 eval (vector PDF + grayscale 변환 + imfinfo self-check 포함 여부).

### [MED] 예제가 쉬운 경로만 시연
- 파일: `examples/figure_export_example.m`
- 문제: 3곡선, line style만, 범례 내부, 단일 패널 — 5곡선+ marker 분기(MarkerIndices), tiledlayout 탈출로(외부 범례/colorbar), (a)/(b) 다중 패널 등 실수 잦은 케이스 레퍼런스 없음.
- 수정: 5-6곡선 marker 로직 패널 + `tiledlayout('Padding','tight','TileSpacing','compact')` 2패널 (a)/(b) + 외부 범례 예제 추가.

### [MED] interpreter 정책 없음
- 문제: 예제 `\zeta`가 기본 tex interpreter에서 math font로 렌더 → Times New Roman과 혼합 폰트 PDF. underscore escape 등 통상 결정사항 침묵.
- 수정: 규칙 추가 — 기본 interpreter 명시, TeX math 글리프는 FontName 미상속 주의, latex 전환 시점 + latex는 FontSize/FontName 무시(크기는 LaTeX 문자열에서), 단일 기호는 Unicode 대안.

### [LOW] 주석 언어 — comment-style과 모순
- 문제: 예제·SKILL.md 코드블록 주석 전부 한국어 ↔ comment-style은 영어 기본. (Cross-skill #2와 동일 사안 — 그쪽에서 일괄 해결.)

---

## 3. plot-style (7건)

### [HIGH] description에 한국어 트리거 전무
- 파일: `SKILL.md:4` frontmatter
- 문제: figure-export는 논문용/제출용/투고용 넣었는데 plot-style은 영어만 — "그래프 그려줘", "플롯 스타일 맞춰줘", "이 figure 정리해줘" 류 실사용 언어 미포함 → 트리거 신뢰성 저하.
- 수정: description에 한국어 트리거 추가 (figure-export 패턴 미러링).

### [HIGH] "Read the saved PNG back (via the MATLAB MCP)" 오기
- 파일: SKILL.md Render loop 3단계
- 문제: MATLAB MCP 도구는 코드 실행 + 텍스트 반환 — 이미지 반환 불가. 문자 그대로 따르면 리뷰 실패 또는 'no MCP' fallback으로 오폭.
- 수정: "저장된 PNG는 Read tool로 읽는다 (MATLAB MCP는 저장 코드 실행만)" 로 수정. fallback 조건도 'no MATLAB MCP'가 아니라 '이미지 파일을 읽을 수 없을 때'로.

### [MED] 버전 게이트 비일관
- 문제: `GridLineWidth`(R2023a+)는 게이트+fallback ↔ 필수 save 블록 `exportgraphics`(R2020a+), 3d-plot.md·three_d_plot_example.m의 `clim`(R2022a+)은 게이트 없음.
- 수정: save 블록에 "exportgraphics R2020a+; 구버전은 `print(fig,...,'-dpng','-r300')`", 3d-plot.md에 "clim R2022a+; 구버전은 `caxis`".

### [MED] bode 데이터 추출 스니펫 오류
- 파일: `references/frequency-response.md` Notes
- 문제: `[mag, phase, w] = bode(sys)` 는 1×1×N 반환 — `squeeze()` 없이 `loglog` 에러/쓰레기. w는 rad/s인데 모듈 예제 라벨은 Frequency (Hz) — `/(2*pi)` 변환 미기재.
- 수정: `mag = squeeze(mag); phase = squeeze(phase); f = w/(2*pi); % rad/s -> Hz` 로 copy-paste 가능하게 확장.

### [MED] scatter 스니펫 하드코딩
- 파일: `references/xy-plot.md`
- 문제: `'LineWidth', 3` 하드코딩 — Common "never hard-code" 규칙 직접 위반. `sz` 미정의 ("pick marker size for visibility"만 — 체크 불가).
- 수정: `'LineWidth', lineWidth` 사용 + style block에 markerSize 기본값 추가 (또는 구체 기본값 명시: scatter 60 pt², plot marker 12 — xy_plot_example.m이 이미 MarkerSize 12 사용).

### [MED] interpreter 규칙 없음
- 문제: figure-export와 동일 공백 — ζ, ω_n, μm, 아래첨자 렌더링 비일관 + latex interpreter는 Times New Roman을 Computer Modern으로 무단 교체.
- 수정: Common 규칙 1줄 — 기본 tex interpreter(FontName 유지), micro는 `\mu`, 아래첨자 `x_{ab}`; latex는 명시 요청 시에만 + FontName override 경고.

### [MED] evals 없음
- 문제: 규칙이 체크 가능한 형태(단위 괄호, shorthand 금지, grid 3-5개, 범례 열 수, log-first-then-hold)라 eval 최적인데 미비.
- 수정: trigger 2-3개 (한국어 프롬프트 + should-NOT-trigger 이미지 생성 요청) + 변환 2-3개 (기존 examples의 before 블록 재활용, 규칙 기반 채점 체크리스트).

---

## 4. Cross-skill (3건)

### [HIGH] README에 스킬 1개만 기재
- 파일: `REM2-plugin/README.md`
- 문제: '현재 수록 스킬' 표와 구조 트리에 plot-style만 존재. figure-export·comment-style 완전 누락 (frontmatter `related`도 plot-style만). v0.6.0인데 README는 스킬 1개 시절.
- 수정: 스킬 표에 2행 추가(용도/상태), 구조 트리 확장, related 갱신, roadmap 섹션 재검토.

### [HIGH] 주석 언어 정면 충돌
- 문제: comment-style "영어 기본, 한국어는 명시 요청 시" ↔ plot-style:86 "code comments in Korean" ↔ figure-export도 Priority에서 한국어 주석 관례 재선언 + 자체 코드블록 한국어. comment-style은 "새 MATLAB 코드 작성 시" 트리거라 새 플로팅 코드에서 세 스킬 동시 발동, 기본값 반대, tie-breaker 없음.
- 수정: 우선순위를 양쪽 파일에 명시 — 예: comment-style에 "plot-style/figure-export 활성 시 주석은 그 스킬의 한국어 관례를 따른다" 추가, 또는 영어를 전역 기본으로 정하고 plot-style:86 + figure-export 코드블록을 영어로 변경. 어느 쪽이든 두 파일이 서로를 명명해야 함.

### [LOW] plugin.json keywords 편중
- 파일: `REM2-plugin/.claude-plugin/plugin.json`
- 문제: keywords가 plot 계열만 ("matlab, plot, plotting, visualization, research") — figure-export(journal, publication, IEEE)·comment-style(comments, documentation) 색인 없음.
- 수정: `figure-export`, `journal`, `publication`, `comments` 추가. name 'rem2'는 kebab-case 유효, version 0.6.0 일치 — 변경 불필요.

---

## 참고: 반박검증에서 기각된 finding (12건)

수정하지 말 것 — 검증 agent가 근거와 함께 기각:

| 기각된 주장 | 기각 사유 |
|---|---|
| plot-style이 figure-export를 몰라서 저널 figure에서 위임 실패 | 스킬 description은 항상 전부 노출 — 라우팅은 description으로 동작, figure-export description이 분업 명시 |
| plot-style font 12–32 clamp가 figure-export 8pt와 충돌 | figure-export Priority가 이미 'font size'를 override 목록에 포함 |
| subplot vs tiledlayout 규칙 충돌 | plot-style:123 "subplot이 표현 못 할 때 tiledlayout" 조항이 이미 해소 |
| comment-style frontmatter version 필드 누락 | version은 기능 필드 아님 — 순수 cosmetic (원하면 통일해도 무방) |
| 예제 3행 colorOrder가 8행 팔레트 축소판 | 8행 팔레트의 첫 3행 그대로 + 예제 중 3시리즈 초과 없음 — 정상 |
| 단일 시리즈에도 범례 = 시각적 노이즈 | 예제 주석에 의도 명시된 설계 선택 ("범례: 모든 axes에 존재") |
| bar/heatmap 등 모듈 없는 타입 방치 | heatmap colorbar는 Common 조건부 규칙이 이미 처리 — 핵심 주장 오류 |
| comment-style 예제 파일이 dead-code 금지 규칙 위반 | Never 규칙은 사용자 코드의 dead code "설명" 금지 — 예제 파일의 before/after 형식은 표준 관행 |
| comment-style "새 MATLAB 코드마다 트리거" 과잉 | 의도된 설계 (스타일 강제 스킬) |
| figure-export Common 블록 IEEE 값 하드코딩 | '값은 프리셋에서' 라벨로 이미 처리 |
| figure-export "MCP / image read-back" 표현 오해 유발 | fallback 조건이 이미 올바르게 키잉됨 (plot-style 쪽 표현만 문제) |
| grayscale 트리거 문구 누락 | description에 'grayscale-survivable' 이미 명시 — 의미 매칭으로 충분 |
