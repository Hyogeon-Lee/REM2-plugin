# MIT용 Simulink 모델 작성

모두 예제 프로젝트에서 확인했거나 실제로 문제가 나서 고친 규칙입니다. 4절은 예제 모델(`examples/`) 설명입니다.

## 1. 모델 구조

- 최상위에 MATLAB Function 블록 하나만 두고, 블록 본문은 `*_core.m`을 부르는 한 줄로 둡니다. 알고리즘을 MATLAB에서 단독으로 테스트할 수 있고 Simulink에서는 같은 코드가 C로 생성됩니다.
- `*_core.m`은 빌드 폴더나 MATLAB 경로에 있어야 합니다. 찾지 못하면 "블록 출력의 크기 및/또는 유형을 확인할 수 없습니다" 오류가 나고, 실패한 캐시(`slprj`, `*.slxc`)가 남아 같은 오류가 반복될 수 있습니다.
- 모델을 기능별로 나누면(예: 신호 생성 / 필터) LabVIEW에서 MIT 모델 여러 개를 연결해 쓰고, 나중에 한 모델의 입력만 실제 DAQ 신호로 바꿀 수 있습니다.

## 2. 파라미터와 시간

- 실행 중에 바꿀 값은 model workspace의 `Simulink.Parameter`(storage class `Model default`)로 만들고, 모델의 `DefaultParameterBehavior`는 `Inlined`로 둡니다. MATLAB Function 블록에서는 이 값들을 scope `Parameter` 데이터로 받습니다. 이 조합이면 각 파라미터가 생성 코드의 파라미터 구조체(`P_<모델>_T`)에 tunable 변수로 남고, MIT에서 `<모델>/<이름>` 경로(예: `signal_filter/filter_mode`)로 index를 찾아 바꿀 수 있습니다.
- Solver는 `FixedStepDiscrete`, `FixedStep`은 파라미터 `Ts`입니다. 단일 rate로 둡니다. 빌드 때 나오는 `Parameter 'FixedStep' ... refers to tunable variables (Ts)` 경고는 정상입니다. 모델이 MIT에 보고하는 기본 주기(`Model Period`)는 빌드 시점의 `Ts`로 고정됩니다.
- 시간에 의존하는 계산(사인 위상, 필터 계수)은 모델 시간 대신 `Ts` 파라미터로 합니다. 실제 스텝 간격은 LabVIEW 루프가 정하므로, `Ts`와 루프 주기를 함께 바꾸면 다시 빌드할 필요가 없습니다. 둘 중 하나만 바꾸면 주파수 특성이 실제와 어긋납니다.
- LabVIEW에서 들어오는 파라미터는 `*_core.m` 안에서 허용 범위로 자릅니다(0으로 나누기, Nyquist 초과 방지).
- 모드 전환형 모델은 모드가 바뀔 때 새로 선택된 상태를 현재 입력으로 초기화합니다. 오래된 상태에서 출발하지 않게 하기 위해서입니다.

## 3. 메모리와 실시간성

- 배열은 고정 크기만 씁니다. 크기 추론이 바뀔 수 있는 대입은 `z(:) = ...`로 기존 배열에 넣습니다. 예: `z = filtic(...)`로 쓰면 가변 크기로 추론되어 999×999 정적 버퍼(약 8 MB)가 생겼습니다.
- `trackingPF`는 생성 코드에서 동적 할당이 필요해서(내부 `ResamplingPolicy`가 가변 크기 char 사용) 쓰지 않았습니다. `trackingKF`는 문제없습니다.
- 이 조건에서 GRT 생성 코드의 `malloc`과 `emxArray`는 0개입니다(모델의 `MATLABDynamicMemAlloc`은 기본값 `on` 그대로). 생성 코드에서 `malloc`, `emxArray`를 검색해 확인합니다.
- 큰 배열은 정적으로 잡혀 모델 로드 때 한 번 할당됩니다. 길이가 바뀌는 연산(이동평균 창, 파티클 수)은 최대 크기 배열을 두고 앞부분만 씁니다.
- `build_mit`은 `StopTime = inf`로 빌드합니다. 모델의 `LifeSpan`이 `auto`면 수명도 무한이 되어 장시간 운전 시 시간 카운터가 wrap되지 않습니다.
- NI 래퍼의 신호 이름 조회 함수는 일치하는 신호를 찾으면 임시 문자열을 해제하지 않고 반환합니다(조회 1회당 수십 바이트). 신호 이름 조회는 초기화 때만 하고 루프 안에서 반복하지 않습니다. 모델 스텝 함수에는 `malloc`이 없습니다.
- 저장된 모델은 GRT 기본 설정(`grt.tlc`, 하드웨어 Windows64)으로 둬도 됩니다. MIT 빌드 설정은 `build_mit`이 임시 configuration set에만 넣습니다.

## 4. 예제: `noise_gen` + `signal_filter`

노이즈 신호 생성 모델과 선택형 필터 모델을 MIT `.so`로 빌드해 한 Timed Loop(10 kHz)에서 연결 실행한 예제입니다.

### 4.1 신호 흐름과 인터페이스

```text
 noise_gen.so                         signal_filter.so
┌──────────────────────┐   y_noisy   ┌───────────────────────────────┐
│ NoiseGen              ├───────────▶│ u → SignalFilter → y_filt      │
│  Ts, sig_amp,         │            │  filter_mode, Ts, lpf_fc,      │
│  sig_freq, sig_offset,│   y_clean  │  ma_len, proc_q, meas_r, pf_N  │
│  noise_std            ├──┐         └───────────────────────────────┘
└──────────────────────┘  └──▶ (오차 계산용 참값)
```

| 모델 | Inport | Outport (offset) | 파라미터 (index, 모두 `real_T` 스칼라) |
| --- | --- | --- | --- |
| `noise_gen` | 없음 | `y_clean` (0), `y_noisy` (1) | 0 `Ts`, 1 `noise_std`, 2 `sig_amp`, 3 `sig_freq`, 4 `sig_offset` |
| `signal_filter` | `u` | `y_filt` (0) | 0 `Ts`, 1 `filter_mode`, 2 `lpf_fc`, 3 `ma_len`, 4 `meas_r`, 5 `pf_N`, 6 `proc_q` |

index와 offset은 `mit_smoke`로 타깃에서 확인한 값입니다. 이 예제에서 파라미터 index는 이름의 ASCII 순서와 같았지만, 다른 모델에서는 index를 가정하지 말고 경로로 조회합니다.

### 4.2 파라미터

`noise_gen`: `Ts` 1e-4 s, `sig_amp` 1, `sig_freq` 10 Hz, `sig_offset` 0, `noise_std` 0.2.

| `signal_filter` | 기본값 | 범위(모델 안에서 자름) | 사용 모드 | 의미 |
| --- | --- | --- | --- | --- |
| `filter_mode` | 4 | 0~5 | 전체 | 0 bypass, 1 Butterworth 1차, 2 Butterworth 2차, 3 이동평균, 4 Kalman, 5 Particle |
| `Ts` | 1e-4 | ≥ 1e-6 s | 전체 | 샘플 주기. 루프 주기와 같아야 함 |
| `lpf_fc` | 200 | 1e-3 Hz ~ 0.45/Ts | 1, 2 | 차단 주파수 |
| `ma_len` | 20 | 1~1000 | 3 | 이동평균 창 길이(샘플) |
| `proc_q` | 1e5 | ≥ 0 | 4, 5 | 가속도 백색잡음 스펙트럼 밀도 (unit²/s³) |
| `meas_r` | 0.04 | > 0 | 4, 5 | 측정 노이즈 분산. 보통 `noise_std²` |
| `pf_N` | 200 | 1~1000 | 5 | 파티클 수 |

### 4.3 알고리즘

노이즈 생성(`noise_gen_core.m`). 위상을 모델 시간이 아니라 `Ts`로 누적해 `Ts`를 바꿔도 주파수가 유지됩니다.

```text
y_clean[k] = sig_offset + sig_amp · sin(φ[k])
y_noisy[k] = y_clean[k] + noise_std · w[k],     w[k] ~ N(0, 1)
φ[k+1]     = (φ[k] + 2π · sig_freq · Ts) mod 2π
```

필터(`signal_filter_core.m`):

- 모드 1, 2: Butterworth 저역통과. 원형 `H(s) = ωc/(s + ωc)`, `H(s) = ωc²/(s² + √2·ωc·s + ωc²)`, `ωc = 2π·lpf_fc`. `butter(n, Wn)`, `Wn = 2·lpf_fc·Ts`로 사전 왜곡 후 쌍선형 변환한 계수를 `Wn`이 바뀔 때만 다시 계산하고, 매 샘플 `filter(b, a, u, z)`로 처리합니다. 모드 진입 시 `filtic(b, a, u, u)`로 정상상태 초기조건을 줍니다.
- 모드 3: 이동평균 `y[k] = (1/L)·Σ_{i=0}^{L−1} u[k−i]`. 길이 1000 고정 FIR 계수 `[1/L … 1/L 0 … 0]`. 군지연 `(L−1)/2` 샘플.
- 모드 4: Kalman(`trackingKF`, 1-D constant velocity). `x = [p; v]`, `F = [1 Ts; 0 1]`, `G = [Ts²/2; Ts]`, 가속도 분산 `σa² = proc_q/Ts`, `H = [1 0]`, 측정 분산 `meas_r`. 정상상태에서 감쇠비 약 0.707인 2차 저역통과처럼 동작하고 대역폭은 `ωn ≈ (proc_q/(meas_r·Ts))^(1/4)`(기본값 약 400 rad/s ≈ 63 Hz)입니다. `proc_q`를 키우면 추종이 빨라지고 노이즈가 더 통과합니다. `meas_r`를 키우면 그 반대입니다.
- 모드 5: bootstrap SIR 파티클 필터(직접 구현, 고정 크기 1000). 전파 `a_i ~ N(0, proc_q/Ts)`, 가중치 `w_i ∝ exp(−(z − p_i)²/(2·meas_r))`(log 가중치에서 최댓값을 빼서 underflow 방지), 추정 `y = Σw_i·p_i/Σw_i`, systematic resampling. 스텝당 연산량이 `pf_N`에 비례합니다.

### 4.4 MATLAB 검증 (`examples/test_filters.m`)

NI 소프트웨어 없이 실행됩니다. Signal Processing Toolbox와 Sensor Fusion and Tracking Toolbox가 필요합니다. 스크립트가 현재 폴더에 `slprj`, `*.slxc`, `image_fig/`를 만들므로 `examples/`를 작업 폴더로 복사한 뒤, 그 폴더를 현재 폴더로 두고 `test_filters`를 실행합니다. 다음을 확인합니다.

1. `noise_gen`을 10 kHz로 0.5 s 시뮬레이션해 `y_clean`, `y_noisy`를 얻습니다.
2. `y_noisy`를 `signal_filter`의 Inport에 넣고 `filter_mode` 0~5를 각각 시뮬레이션합니다.
3. 오차 `e = y_filt − y_clean`(수렴 구간 `t < 0.05 s` 제외)로 RMSE `sqrt(mean(e²))`, bias `mean(e)`, `max|e|`, 지연 `argmin_L RMSE(y_filt[k], y_clean[k−L])`(0~10 ms), 지연 보상 RMSE를 계산하고, 모든 필터가 raw noise RMSE를 절반 이하로 줄이는지 `assert`합니다.
4. `Ts = 1e-3`에서 FixedStep, 사인 주파수(10 Hz), Kalman 동작이 유지되는지 확인합니다.
5. 0.05 s마다 모드를 바꾸면서 출력이 유한하고 유계인지 확인합니다.
6. 그림을 `image_fig/`에 저장합니다.

결과(10 kHz, 0.5 s, 기본 파라미터, `t ≥ 0.05 s`):

| mode | 필터 | RMSE | bias | max\|e\| | delay (ms) | 지연 보상 RMSE |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Bypass | 0.1988 | 0.00493 | 0.7484 | 0.00 | 0.1988 |
| 1 | Butterworth 1차 | 0.0609 | 0.00516 | 0.1981 | 0.80 | 0.0495 |
| 2 | Butterworth 2차 | 0.0663 | 0.00521 | 0.1709 | 1.10 | 0.0435 |
| 3 | 이동평균 | 0.0624 | 0.00519 | 0.1752 | 1.00 | 0.0459 |
| 4 | Kalman | 0.0457 | 0.00340 | 0.1681 | 0.10 | 0.0455 |
| 5 | Particle | 0.0468 | 0.00180 | 0.1677 | 0.10 | 0.0467 |

- LPF 계열 오차의 대부분은 위상 지연(0.8~1.1 ms)에서 옵니다. Kalman과 Particle은 지연 0.1 ms(1 샘플)입니다.
- 1 kHz(`Ts = 1e-3`): 사인 피크 9.98 Hz 유지, Kalman RMSE 0.1932 → 0.0905.
- 0.05 s마다 모드 전환: 최대 |오차| 0.716(bypass 구간의 raw noise 수준), 발산 없음.
