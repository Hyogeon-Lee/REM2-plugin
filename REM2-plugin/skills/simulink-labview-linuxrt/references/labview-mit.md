# LabVIEW RT에서 MIT로 모델 실행

LabVIEW VI는 바이너리 파일이라 스크립트로 만들 수 없습니다(LabVIEW ActiveX 자동화로는 블록 다이어그램을 만들 수 없음). 아래 순서대로 사용자가 직접 작성합니다. 예시는 예제 두 모델(`noise_gen`, `signal_filter`)을 씁니다. 다른 모델이면 경로, 포트, 파라미터를 바꿉니다.

| 단계 | 내용 | 확인 상태 |
| --- | --- | --- |
| A (2절) | 모델별 로드 테스트 VI | 확인 |
| A 확장 (2.1절) | 두 모델을 한 Timed Loop에서 연결, 실행 중 파라미터 변경 | 확인 (10 kHz, 호스트 MIT 20.0.0, 타깃 MIT 20.4.0) |
| B (3절) | 완성형 RT VI: RT FIFO, Network Streams, 명령 처리 | 미확인 |
| 호스트 VI (4절) | 그래프, 오차 지표, 명령 전송 | 미확인 |

## 0. 준비

1. 타깃에 LabVIEW RT와 MIT가 있고 `.so`가 `<deploy-dir>`(기본 `/home/lvuser/models`)에 복사된 상태여야 합니다(`deploy-and-smoke.md`). `mit_smoke`로 먼저 확인해 두면 LabVIEW 문제와 `.so` 문제를 나눌 수 있습니다.
2. LabVIEW 프로젝트에 RT 타깃을 추가하고, 타깃을 마우스 오른쪽 버튼으로 눌러 Connect합니다. VI는 프로젝트의 **RT 타깃 아래**에 만듭니다.
3. 참고용 NI 예제: `C:\Program Files (x86)\National Instruments\LabVIEW 2020\examples\Control and Simulation\Model Interface\`의 `MIT Simple Load and Run Model.vi`, `MIT Multiple models.vi`, `MIT Parameter Management.vi`. 아래 VI와 같은 결선 패턴이 있습니다.

## 1. 사용할 MIT VI와 규칙

팔레트: Functions → Control Design & Simulation → Model Interface. 단자 이름은 MIT 2020 도움말(`vsmitref.chm`)에서 확인했습니다.

| VI | 입력 | 출력 | 용도 |
| --- | --- | --- | --- |
| Load Model | `Model Path`, `Multirate Options`(단일 rate면 무시), `error in` | `Model out`, `error out` | `.so`를 올리고 모델 참조를 만듦. 형식이 맞지 않으면 -383200 |
| Create Inports Array | `Model in`, `error in` | `Model out`, `Inports Array out`(0으로 채운 DBL 1D), `Inports Array size`, `error out` | 루프 밖에서 inport 배열을 미리 할당 |
| Take Model Time Step | `Model in`, `Inport Array`(DBL 1D, column-major), `error in` | `Model out`, `Outports Array out`(DBL 1D), `error out` | inport 쓰기 → 1 스텝 → outport 읽기 |
| Get Information by Path (다형성: Inport/Outport/Parameter/Signal) | `Model in`, `... Path`, `error in` | `Model out`, `... Information`(Parameter: `Name`, `Index`, `Dimensions`, `Type` / Outport: `Path`, `Dimensions`, `offset`, `Type`), `Found?`, `error out` | 경로로 파라미터 index, outport offset 조회 |
| Set Parameter Inline | `Model In`, `Parameter index`, `Parameter value`, `Offset within parameter`(스칼라는 0), `error in` | `Model out`, `error out` | 제어 루프 안에서 스칼라 파라미터 변경. 같은 스텝에 반영 |
| Unload Model | `Model in`, `error in` | `error out` | 모델 해제 |

모델 참조의 Property Node(모델 참조 출력에서 마우스 오른쪽 → Create → Property Node):

| 속성 | 읽기/쓰기 | 용도 |
| --- | --- | --- |
| `Inport Paths`, `Outport Paths`, `Parameter Paths` | 읽기 | 경로 문자열 배열 |
| `Model Period` | 읽기 | 빌드 시점의 기본 주기 |
| `Update Parameters In Line?` | 쓰기 | TRUE여야 Set Parameter Inline을 쓸 수 있음. FALSE(기본)면 -383700 |

규칙:

- **모델 경로는 문자열 → String to Path로 넘깁니다.** Windows 화면의 Path 컨트롤에 Linux 경로를 넣으면 `<Not A Path>`(오류 1)가 납니다. String to Path는 타깃에서 실행되므로 Linux 경로로 변환됩니다.
- **모델 와이어는 루프 경계에서 시프트 레지스터로 넘깁니다.** 모델 와이어는 by-value LabVIEW 클래스(`vi.lib\Model Interface Toolkit\Model Interface Toolkit.lvclass`)라서, 터널로 넘기면 Take Model Time Step이 갱신한 모델 객체가 다음 반복에 전달되지 않습니다. 실제로 필터 모델 줄만 터널로 연결했을 때 오류 없이 출력이 입력과 같았고 `filter_mode`를 바꿔도 그대로였습니다. inport 배열과 error 와이어도 시프트 레지스터로 넘깁니다.
- **Set Parameter Inline은 `Update Parameters In Line?` = TRUE를 쓴 Property Node 뒤쪽 와이어에 직렬로 연결합니다.** 이 값도 클래스 객체 안의 값이라 Property Node를 지난 와이어에만 실립니다. 모델 입력이 미연결이거나(기본 객체 = FALSE), Property Node 앞에서 분기했거나, 와이어가 노드 위를 지나가기만 하고 연결되지 않았으면 -383700이 납니다. 노드를 마우스로 끌어 보면 연결된 와이어만 따라 움직입니다.
- 모델 참조 와이어를 병렬로 분기하지 않습니다. MIT는 한 모델을 여러 곳에서 동시에 다루도록 만들어지지 않았습니다.
- Set Parameter Inline(제어 루프 안 변경)과 Set Parameter + Commit Parameters(배경 루프 변경)는 한 애플리케이션에서 함께 쓸 수 없습니다. 여기서는 Set Parameter Inline만 씁니다.
- Take Model Time Step을 처음 실행할 때 모델 시작 함수가 자동으로 호출되므로 Call Model Start Routine은 쓰지 않아도 됩니다.
- Unload Model은 정지 경로에서 항상 실행되도록 Clear Errors를 거친 error 와이어를 넣고, 원래 오류와 Merge Errors로 합칩니다.

## 2. 단계 A: 로드 테스트 VI

목적: 타깃에서 MIT가 각 `.so`를 로드하고 스텝을 실행하는지 확인하고, 포트와 파라미터의 실제 경로 문자열을 기록합니다. 먼저 NI 예제 모델 `libsinewave64.so`로 해 봅니다. 이 파일은 타깃에 기본으로 있지 않으므로 `deploy-and-smoke.md` 2절대로 먼저 복사합니다. 이것이 실패하면 MIT 설치 문제, 이것은 되는데 빌드한 `.so`만 실패하면 빌드 문제입니다.

RT 타깃 → New → VI로 `MIT_LoadTest.vi`를 만듭니다.

프런트 패널:

| 종류 | 이름 | 타입 | 기본값 |
| --- | --- | --- | --- |
| Control | `Model Path` | String | `/home/lvuser/models/libsinewave64.so` |
| Control | `Steps` | I32 | 1000 |
| Indicator | `Inport Paths`, `Outport Paths`, `Parameter Paths` | String 1D array | |
| Indicator | `Model Period (s)` | DBL | |
| Indicator | `Last Outports` | DBL 1D array | |
| Indicator | `Max Step Time (us)` | U32 | |
| Indicator | `error out` | error cluster | |

블록 다이어그램(error 와이어로 순서 고정):

1. `Model Path` → String to Path → Load Model.
2. Property Node(모델 참조)로 `Inport Paths`, `Outport Paths`, `Parameter Paths`, `Model Period`를 읽어 표시기로 연결합니다.
3. Create Inports Array → `Inports Array out`.
4. For Loop(N = `Steps`). 모델 참조, inport 배열, error, 최대 스텝 시간(U32, 초기값 0)을 시프트 레지스터로 넘깁니다.
   - 안에서 Tick Count(Real-Time → Timing, µs) → Take Model Time Step → Tick Count를 Flat Sequence로 실행하고, 차이와 이전 최댓값 중 큰 값을 넘깁니다.
   - 마지막 반복의 `Outports Array out`을 `Last Outports`로 내보냅니다. 출력 터널을 Tunnel Mode → Last Value로 바꿉니다.
5. 루프 뒤 Unload Model(Clear Errors를 거친 error 와이어), Merge Errors → `error out`.

Run 버튼으로 실행합니다(타깃에 배포한 뒤 대화식 실행). `Model Path`를 바꿔 모델을 차례로 확인합니다.

예제의 기대 결과:

| 모델 | 기대 결과 |
| --- | --- |
| `libsinewave64.so` | 오류 없이 로드, 스텝, 해제 |
| `noise_gen.so` | Inport 0, Outport 2, Parameter 5, `Model Period` = 1e-4. `Last Outports` 0번(`y_clean`)은 -1~1, 1번(`y_noisy`)은 0번 ± 노이즈(표준편차 0.2) |
| `signal_filter.so` | Inport 1(`u`), Outport 1(`y_filt`), Parameter 7, `Model Period` = 1e-4. 입력이 0이므로 `y_filt`는 0 근처 |

표시된 경로 문자열과 `Max Step Time (us)`를 기록합니다. 파라미터 경로 형식(`<모델>/<이름>`)과 index, outport offset은 `mit_smoke`로 확인했습니다(`model-authoring.md` 4.1절). Property Node로 읽는 inport·outport 경로 문자열은 확인하지 않았습니다. 10 kHz(100 µs)에서는 모든 모델의 스텝 시간 합이 100 µs보다 충분히 작아야 합니다.

### 2.1 두 모델 연결과 실행 중 파라미터 변경 (실제 작성본)

`MIT_LoadTest.vi`를 다음 구조로 확장해, 두 모델을 한 Timed Loop에서 연결하고 실행 중에 `filter_mode`를 바꾸면 출력이 바뀌는 것을 확인했습니다.

```text
[루프 앞]
  "/home/lvuser/models/noise_gen.so"     → String to Path → Load Model → Create Inports Array (빈 배열)
  "/home/lvuser/models/signal_filter.so" → String to Path → Load Model
      → Property Node(쓰기): Update Parameters In Line? ← TRUE
      → Create Inports Array

[Timed Loop: 1 MHz clock, Period 100 µs (10 kHz), Priority 100]
  ※ 두 모델 모두 모델 와이어와 error 와이어를 시프트 레지스터로 넘김
  noise_gen     Take Model Time Step → Outports Array out ─┬─ Index Array → y_clean [0], y_noisy [1]
                                                          └─ Array Subset (index 1) → [y_noisy]
  signal_filter Set Parameter Inline (Parameter index 1, Offset 0, Parameter value ← filter_mode 컨트롤)
                → Take Model Time Step (Inport Array ← [y_noisy]) → Index Array [0] → y_filt
  Bundle (y_clean, y_noisy, y_filt) → output cluster 표시기
  Finished Late? [i-1] → Boolean To (0,1) → 누적 → late count 표시기
  Stop 버튼 → 루프 정지

[루프 뒤]
  Unload Model ×2 → Simple Error Handler
```

작성하면서 확인한 점:

- `filter_mode` 컨트롤과 Set Parameter Inline은 루프 **안**에 둡니다. 루프 밖이면 Run할 때 한 번만 실행되어 실행 중 바꾼 값이 반영되지 않습니다. 매 반복 호출해도 하는 일은 파라미터 메모리 한 곳에 값을 쓰는 것뿐입니다(`ni_modelframework.c`의 `NIRT_SetScalarParameterInline`: index·offset 범위 검사 후 대입).
- 같은 파라미터의 컨트롤은 하나만 둡니다. 루프 밖과 안에 하나씩 두면 안쪽 값이 매 스텝 덮어씁니다.
- Set Parameter Inline의 `Parameter index`와 `Offset within parameter`는 둘 다 정수라 바꿔 꽂아도 끊어진 와이어 표시가 나오지 않습니다. Ctrl+H로 단자 이름을 확인합니다. 바꿔 꽂으면 `Parameter subindex is out of bounds.` 오류가 납니다.
- Array Subset은 반복마다 새 배열을 만들 수 있습니다. 테스트 VI에서는 문제없었지만 단계 B에서는 미리 만든 배열에 Replace Array Subset을 씁니다.
- LabVIEW 안에서의 RMSE와 스텝 시간은 이 VI에서 재지 않았습니다. 같은 `.so`를 LabVIEW 없이 돌린 값은 `deploy-and-smoke.md` 3.4절에 있습니다.

## 3. 단계 B: 완성형 RT VI (미확인)

아래 구조는 MIT 도움말과 단계 A 결과를 바탕으로 한 설계이며, 실제로 작성해 실행하지 않았습니다.

```text
[초기화] Load Model ×2 → Update Parameters In Line? = TRUE ×2 → 파라미터 index 조회
         → Create Inports Array → RT FIFO 2개 생성
           │
[Timed Loop, 1 MHz, dt = 100 µs, 높은 우선순위]          [통신 루프, While Loop, 보통 우선순위]
  CMD FIFO 읽기(timeout 0) → 바뀐 값만 Set Parameter Inline     Network Stream 생성(rt_data, rt_cmd)
  noise_gen 스텝 → y_clean, y_noisy                            데이터 FIFO → rt_data 스트림 (M개마다 1개)
  signal_filter 스텝(u = y_noisy) → y_filt                     rt_cmd 스트림 → CMD FIFO
  e = y_filt − y_clean
  [t, y_clean, y_noisy, y_filt, e] → 데이터 FIFO(timeout 0)
           │
[정지] Unload Model ×2 → Network Stream 해제 → RT FIFO 삭제
```

### 3.1 명령 형식

호스트 → RT 명령은 DBL 3개 배열 `[code, id, value]`입니다. RT FIFO는 문자열과 클러스터를 받지 않으므로 숫자 배열로 정했습니다.

| code | 동작 | id | value |
| --- | --- | --- | --- |
| 0 | 모델 1(`noise_gen`) 파라미터 설정 | 표 A의 번호 | 새 값 |
| 1 | 모델 2(`signal_filter`) 파라미터 설정 | 표 B의 번호 | 새 값 |
| 2 | 샘플 주기 변경(모든 모델의 `Ts`와 Timed Loop 주기) | 무시 | 새 Ts (s) |
| 3 | 정지 | 무시 | 무시 |

표 A(`noise_gen`): 0 `sig_amp`, 1 `sig_freq`, 2 `sig_offset`, 3 `noise_std`.
표 B(`signal_filter`): 0 `filter_mode`, 1 `lpf_fc`, 2 `ma_len`, 3 `proc_q`, 4 `meas_r`, 5 `pf_N`.

`Ts`는 code 2로만 바꿉니다. 모든 모델의 `Ts`와 루프 주기가 항상 같아야 하기 때문입니다. 초기값은 모델에 컴파일된 기본값이므로 초기화 단계에서 따로 설정하지 않습니다.

### 3.2 초기화 (루프 앞)

1. Load Model: 문자열 상수 → String to Path.
2. 각 모델 참조에 Property Node(쓰기)로 `Update Parameters In Line?` = TRUE.
3. 파라미터 index 조회: 표 A·B의 경로를 문자열 배열 상수로 두고 For Loop 안에서 Get Information by Path(Parameter)로 `Index` 배열(`idxA`, `idxB`)을 만듭니다. 각 모델의 `Ts` index(`idxTsN`, `idxTsF`)도 따로 조회합니다. 모델 참조는 For Loop에서도 시프트 레지스터로 넘깁니다. `Found?`가 하나라도 FALSE면 오류를 만들어 루프를 시작하지 않습니다.
4. Create Inports Array를 모델마다 실행합니다.
5. RT FIFO Create 2개:

| 이름 | type | elements in array | size | read mode | write mode |
| --- | --- | --- | --- | --- | --- |
| `data_fifo` | DBL 1D | 5 | 10000 (10 kHz에서 1 s) | blocking | polling |
| `cmd_fifo` | DBL 1D | 3 | 64 | polling | polling |

6. 기록용 배열 `rec`를 Initialize Array(0, 5)로 미리 만듭니다.

### 3.3 Timed Loop

설정: Timing source 1 MHz Clock, Period 100(µs), Priority 100(통신 루프보다 높게). 시프트 레지스터: 모델 참조 2개, inport 배열, `rec`, `t`(DBL, 0), `Ts`(DBL, 1e-4), `late count`(U32, 0), error.

반복 안의 순서(error 와이어로 고정):

1. **명령 처리.** `cmd_fifo`를 RT FIFO Read(timeout 0)로 읽고 `timed out?`이 FALSE일 때만 Case Structure를 실행합니다. code는 Index Array 0번을 반올림해 I32로 바꿔 선택자로 씁니다.
   - code 0/1: id가 표 범위 안인지 In Range and Coerce로 확인하고, 범위 안일 때만 `idxA[id]`/`idxB[id]`로 Set Parameter Inline(`Offset within parameter` = 0)을 실행합니다. 확인하지 않으면 Index Array가 범위 밖에서 0을 돌려줘 index 0 파라미터가 바뀝니다.
   - code 2: `dt = round(value · 1e6)`, 1 이상으로 제한. `Ts_eff = dt · 1e-6`을 `idxTsN`, `idxTsF`에 Set Parameter Inline으로 쓰고, `dt`를 오른쪽 데이터 노드의 Period에 넣습니다(다음 반복부터 적용). `Ts` 시프트 레지스터도 `Ts_eff`로 바꿉니다. 모델에는 루프 주기와 정확히 같은 값(1 µs 정수배)이 들어갑니다.
   - code 3: 정지 플래그 TRUE. Default: 아무것도 하지 않음.
2. **모델 1 스텝.** Take Model Time Step(빈 inport 배열) → Index Array로 0번 `y_clean`, 1번 `y_noisy`.
3. **모델 2 스텝.** Replace Array Subset으로 inport 배열 0번을 `y_noisy`로 바꾸고 Take Model Time Step. 출력 0번이 `y_filt`. 같은 반복에서 차례로 실행하므로 모델 사이에 한 샘플 지연이 없습니다.
4. **오차.** `e = y_filt − y_clean`.
5. **기록.** Replace Array Subset으로 `rec`의 0~4번에 `t`, `y_clean`, `y_noisy`, `y_filt`, `e`를 넣고 RT FIFO Write(`data_fifo`, timeout 0). `overwrite on timeout?`은 기본값 TRUE로 둬서 호스트가 느려도 제어 루프가 기다리지 않게 합니다.
6. **시간.** `t + Ts`를 `t` 시프트 레지스터로.
7. **지연 확인.** 왼쪽 데이터 노드의 `Finished Late? [i-1]`이 TRUE면 `late count`를 1 올립니다.
8. **정지 조건.** 정지 플래그 OR error status.

Timed Loop 안에서 Build Array, 문자열 연결, 그래프 갱신을 쓰지 않습니다. 매 반복 메모리를 할당해 지터가 생기고 장시간 실행 시 메모리가 줄어듭니다. 배열은 모두 루프 밖에서 만들고 Replace Array Subset으로 갱신합니다.

### 3.4 통신 루프 (같은 VI, 일반 While Loop)

루프 앞(Data Communication → Network Streams):

- Create Network Stream Writer Endpoint: `writer name` = `rt_data`, DBL 1D, `writer buffer size` = 100000.
- Create Network Stream Reader Endpoint: `reader name` = `rt_cmd`, DBL 1D.
- 두 함수 모두 URL을 비워 두고 호스트가 연결해 오기를 기다립니다. 처음에는 timeout -1(무한 대기).
- 타깃에 Network Streams가 없다는 오류가 나면 사용자가 NI MAX에서 그 항목만 추가로 설치합니다(`deploy-and-smoke.md` 1절).

루프 안:

1. 안쪽 While Loop로 `data_fifo`를 비웁니다. RT FIFO Read(timeout 0)가 `timed out?` TRUE를 줄 때까지 읽고, 카운터가 `M`의 배수일 때만 Write Single Element to Stream(`rt_data`). `M`은 프런트 패널 control(기본 10 → 호스트에 1 kHz).
2. Read Single Element from Stream(`rt_cmd`, timeout 0) → 새 명령이 있으면 RT FIFO Write(`cmd_fifo`). code 3이면 넘긴 뒤 이 루프도 정지.
3. 프런트 패널 `stop`(대화식 실행용)이 TRUE면 `[3, 0, 0]`을 `cmd_fifo`에 쓰고 정지.
4. Wait(ms) 10.

Network Streams의 Read/Write Multiple Elements는 스칼라 타입에만 쓸 수 있으므로 배열 원소에는 Single Element 함수를 씁니다.

### 3.5 정지 경로와 실행

1. Unload Model ×2(Clear Errors를 거친 error 와이어) → Destroy Stream Endpoint ×2 → RT FIFO Delete ×2 → Merge Errors → `error out`.
2. 처음에는 RT VI를 Run으로 대화식 실행합니다. 동작을 확인한 뒤 RT 타깃 → Build Specifications → New → Real-Time Application으로 빌드하고 "Run as startup"으로 배포하면 부팅 시 자동 실행됩니다. 이 경우 정지와 파라미터 변경은 호스트 VI로만 합니다.

## 4. 호스트 VI (미확인)

프로젝트의 My Computer → New → VI.

- 연결(루프 앞): Create Network Stream Reader Endpoint(`reader name` = `host_data`, `writer url` = `//<target-ip>/rt_data`, DBL 1D, `reader buffer size` = 100000), Create Network Stream Writer Endpoint(`writer name` = `host_cmd`, `reader url` = `//<target-ip>/rt_cmd`, DBL 1D).
- 표시 루프: Read Single Element from Stream(`host_data`, timeout 100) → 원소 `[t, y_clean, y_noisy, y_filt, e]`. Waveform Chart에 신호, 다른 Chart에 `e`. `RMS PtByPt`(`sample length` 1000)에 `e`를 넣으면 최근 1000 샘플의 RMSE `sqrt((1/N)·Σe²)`, `Mean PtByPt`면 bias `(1/N)·Σe`.
- 명령 루프(Event Structure): 각 control의 Value Change에서 Build Array로 `[code, id, value]`를 만들어 Write Single Element to Stream(`host_cmd`). 호스트는 실시간 루프가 아니므로 Build Array를 써도 됩니다. `Stop`은 `[3, 0, 0]` 후 호스트 루프도 정지.
- 정리: Destroy Stream Endpoint ×2.
- Ts를 바꿀 때는 `lpf_fc ≤ 0.45/Ts`인지 확인합니다. 넘으면 모델이 0.45/Ts로 잘라 의도와 다른 필터가 됩니다.
- Windows 방화벽이 Network Streams 연결을 막으면 LabVIEW를 허용 목록에 추가합니다.

## 5. 확인 기준

| 항목 | 방법 | 기준 |
| --- | --- | --- |
| 모델 로드 | 단계 A | 모든 모델 오류 없음, 경로와 개수가 2절 표와 같음 |
| 실시간성 | `late count` | 10 kHz에서 0 유지. 예제는 `filter_mode` 4에서 확인 후 5(`pf_N` 200)로 늘려 봄. 10 kHz에서 `pf_N`은 500 이하에서 시작. LabVIEW 밖에서 잰 스텝 시간 참고값은 `deploy-and-smoke.md` 3.4절 |
| 성능 | 호스트 RMSE(`RMS PtByPt`, 1000 샘플) | 기본 파라미터, `M` = 1에서 Simulink 결과와 비슷(예제: bypass 약 0.199, Kalman 약 0.046) |
| Ts 변경 | `Ts` = 1e-3 전송 | 주파수 특성 유지(예제: 사인 10 Hz), `late count` 증가 없음 |
| 모드 전환 | 실행 중 모드 변경 | 출력이 발산하지 않고 큰 과도 응답이 없음 |
| 메모리 | NI Distributed System Manager → 타깃 → Memory | 30분 이상 실행해도 여유 메모리가 계속 줄지 않음 |

`M` > 1이면 호스트 RMSE는 M개 중 1개 샘플로 계산하므로 값이 약간 달라질 수 있습니다.
