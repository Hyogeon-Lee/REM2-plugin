# 타깃 준비, 배포, LabVIEW 없이 실행 확인

아래 명령의 `<target>`은 SSH 접속 대상입니다(`admin@<target-ip>` 또는 `%USERPROFILE%\.ssh\config`에 등록한 SSH 별칭). `<deploy-dir>`의 기본값은 `/home/lvuser/models`입니다. 비밀번호는 명령이나 파일에 넣지 않습니다.

## 1. 타깃 준비

- 먼저 타깃에 이미 설치된 것을 확인합니다. 설치 상태는 SSH로 봅니다.

```powershell
ssh <target> "opkg list-installed | grep -E 'labview-realtime|model-interface|veristand|ni-rio|daqmx'"
```

- 공용 타깃이면 다시 설치하지 않습니다. 예제 타깃의 MIT는 20.4.0으로 호스트(20.0.0)보다 높았지만, 호스트 MIT 20.0.0으로 만든 VI가 그대로 실행됐습니다. 호스트에서 NI MAX로 다시 설치하면 타깃이 호스트 버전으로 바뀌어 다른 사람의 작업에 영향을 줍니다. 먼저 지금 상태로 배포해 보고, LabVIEW가 버전 불일치를 알릴 때만 사용자에게 알려 관련된 사람과 맞추게 합니다.
- 새 타깃이거나 설치가 필요하면 사용자가 NI MAX에서 진행합니다(MIT 도움말 "Installing Support on an RT Target"과 같은 절차).
  1. NI MAX → Remote Systems → 타깃 → Software.
  2. Add/Remove Software → LabVIEW Real-Time Software Wizard. 타깃 admin 비밀번호는 사용자가 입력합니다.
  3. "Custom software installation"을 고릅니다.
  4. LabVIEW Real-Time(이미 있으면 유지), Model Interface Toolkit, Network Streams(호스트로 데이터를 보낼 때), FPGA·DAQ를 쓰는 경우에만 해당 드라이버(호스트와 같은 버전).
  5. 설치가 끝나면 타깃이 재부팅됩니다.
- SSH가 꺼져 있으면 NI MAX의 타깃 System Settings에서 "Enable Secure Shell Server (sshd)"를 켭니다.

## 2. `.so` 복사

배포할 파일: 빌드한 모델 `.so`와, NI MIT 예제 모델 `libsinewave64.so`(`C:\Program Files (x86)\National Instruments\LabVIEW 2020\examples\Control and Simulation\Model Interface\Models\`, x86-64용). `libsinewave64.so`는 타깃에서 모델이 로드되지 않을 때 원인이 MIT 설치인지 빌드인지 가르는 기준 모델입니다. 타깃에 기본으로 있지 않고 다른 사람이 지울 수도 있으므로, 쓰기 전에 `ls`로 확인하고 없으면 직접 복사합니다.

```powershell
ssh <target> "mkdir -p <deploy-dir>"
```

```powershell
scp <folder>\*.so <target>:<deploy-dir>/
```

복사 후 확인합니다. 다른 사용자도 읽을 수 있어야 합니다(`-rw-r--r--`). LabVIEW RT는 `lvuser` 계정으로 실행됩니다.

```powershell
ssh <target> "ls -l <deploy-dir>; sha256sum <deploy-dir>/*.so; /lib/libc.so.6 | head -1"
```

- 로컬 SHA-256(`Get-FileHash -Algorithm SHA256 <파일>`)과 타깃 값이 같아야 합니다.
- NI Linux RT에는 `ldd`가 없습니다. glibc 버전은 `/lib/libc.so.6`을 실행해 봅니다. 2.14 이상이어야 합니다.
- SSH 키를 등록하면 비밀번호 없이 복사할 수 있습니다(`%USERPROFILE%\.ssh\config`에 별칭과 `IdentityFile`). 키 등록은 사용자가 계정마다 한 번 합니다.
- 접속할 때마다 NI 배너("NI Linux Real-Time (run mode)" 등)가 출력됩니다. 명령 출력을 파싱할 때는 이 줄을 걸러냅니다.

## 3. LabVIEW 없이 실행 확인 (`mit_smoke`)

`mit_smoke`는 MIT가 내부에서 쓰는 Model Framework 함수(`NIRT_InitializeModel`, `NIRT_ModelStart`, `NIRT_Schedule`, `NIRT_ModelUpdate`, `NIRT_SetScalarParameterInline`, `NIRT_GetParameterSpec`, `NIRT_FinalizeModel`)를 직접 호출합니다. `.so`가 로드되고 스텝과 파라미터 변경이 동작하는지를 LabVIEW 없이 확인합니다. 여기서 `dlopen`이 실패하면 MIT에서도 로드되지 않습니다.

| 파일 | 용도 | 확인 상태 |
| --- | --- | --- |
| `scripts/mit_smoke.c` | 일반 도구. 모델 N개 로드, 인터페이스 출력, 경로로 파라미터 설정, 포트 연결, N 스텝 실행, 출력 범위·스텝 시간 출력 | 타깃(PXIe-8840)과 WSL에서 확인(아래 세 곳을 고친 소스 포함) |
| `examples/mit_smoke_example.c` | 예제 두 모델 전용 시나리오. 단계별 파라미터 변경과 참값 대비 RMSE | 타깃과 WSL에서 확인 |

`scripts/mit_smoke.c`는 첫 타깃 실행 뒤에 세 곳을 고쳤습니다. 고친 소스를 WSL과 타깃에서 다시 실행했고, 3.2절의 모든 경우에서 고치기 전과 결과가 같았습니다. 오류 문구 출력과 `NIRT_FinalizeModel` 생략 경로는 해당 오류가 나지 않아 실행되지 않았습니다.

- NIRT 오류 문구 출력: `NIRT_ModelError`는 오류 문구가 있을 때 `NI_ERROR`(1)를 반환합니다. 반환값이 0일 때만 문구를 출력하던 조건을 문구 길이로 판단하게 바꿨습니다.
- inport 버퍼 크기: MF 2020의 `tmw\codegen\NiPortLib.tlc`를 보면 `NIRT_InitializeModel`이 돌려주는 inport 수는 신호 수라서 벡터 inport도 1로 셉니다(outport 수는 `niTotalNumOutports`, 즉 각 outport의 `Dimensions[0] × Dimensions[1]` 합이라 원소 수). 스텝 함수는 원소마다 값을 하나씩 읽으므로, inport 원소 수를 `NIRT_GetExtIOSpec`의 포트 목록(각 inport의 `dimX × dimY` 합)에서 구합니다. 스칼라가 아닌 inport를 가진 실제 모델로는 확인하지 않았습니다.
- 필요한 심볼이 없는 `.so`: 초기화하지 않은 모델에 `NIRT_FinalizeModel`을 부르지 않습니다.

### 3.1 크로스 컴파일 (호스트)

```powershell
$bin = "C:\build\17.0\x64\sysroots\i686-nilrtsdk-mingw32\usr\bin\x86_64-nilrt-linux"
& "$bin\x86_64-nilrt-linux-gcc.exe" --sysroot=C:/build/17.0/x64/sysroots/core2-64-nilrt-linux -std=gnu99 -O2 -Wall -o mit_smoke <skill>\scripts\mit_smoke.c -ldl -lm -lpthread
```

- `-lpthread`: MF 2020 `.so`가 `sem_*`를 쓰면서 `libpthread`를 의존성에 넣지 않으므로 로드하는 프로세스가 제공해야 합니다(`build-and-verify.md` 3절). 빠지면 `undefined symbol: sem_init`.
- 코드는 `RTLD_NOW | RTLD_LOCAL`로 엽니다. `RTLD_GLOBAL`로 바꾸지 않습니다(`build-and-verify.md` 4절).
- 출력은 버퍼링하지 않습니다(`setvbuf`). segfault가 나도 그 전까지의 출력이 남습니다.

### 3.2 일반 도구 사용법

```text
mit_smoke [-n steps] [-s model/param=value]... [-w dst:in=src:out]... a.so [b.so ...]
  -n steps               실행할 스텝 수 (기본 10000, 0이면 로드와 인터페이스 출력만)
  -s model/param=value   스텝 전에 스칼라 파라미터를 MIT 경로로 설정 (반복 가능)
  -w dst:in=src:out      모델 dst가 스텝하기 전에 모델 src의 outport 원소 out을 dst의 inport 원소 in에 복사.
                         모델 번호는 인자 순서로 0부터, src < dst (반복 가능). 연결하지 않은 inport는 0
```

- 모델 인자는 `/`가 들어간 경로로 줍니다(현재 폴더면 `./noise_gen.so`). 파일 이름만 주면 `dlopen`이 현재 폴더를 찾지 않아 `cannot open shared object file`로 실패합니다.
- `-w`의 `in`, `out`은 포트 번호가 아니라 원소 번호입니다. 모델의 모든 inport(또는 outport)를 포트 순서대로 펼친 배열에서 0부터 셉니다. 예제에서는 LabVIEW `Outports Array out`의 순서(0번 `y_clean`, 1번 `y_noisy`)와 같았습니다.
- 모델은 인자 순서대로 같은 스텝 안에서 실행됩니다. RT VI에서 Take Model Time Step을 차례로 부르는 것과 같아서 모델 사이에 한 샘플 지연이 없습니다.
- 단일 rate 모델만 지원합니다(태스크가 2개 이상이면 FAIL).
- 로드·파라미터·스텝 오류나 NaN/Inf 출력이 있으면 `FAIL`, 아니면 `PASS`. 종료 코드 0/1(인자 오류는 2).
- `*** Using a default buffer of size 1024 for logging variable tout`는 GRT 로깅 코드가 출력하는 정상 메시지입니다.

타깃에 복사해 실행하고 지웁니다.

```powershell
scp mit_smoke <target>:/tmp/
```

```powershell
ssh <target> "chmod +x /tmp/mit_smoke && /tmp/mit_smoke -n 0 <deploy-dir>/noise_gen.so <deploy-dir>/signal_filter.so; rm -f /tmp/mit_smoke"
```

예제 두 모델을 RT VI처럼 연결해 bypass로 실행하는 명령(`signal_filter.u ← noise_gen.y_noisy`):

```text
/tmp/mit_smoke -s signal_filter/filter_mode=0 -w 1:0=0:1 <deploy-dir>/noise_gen.so <deploy-dir>/signal_filter.so
```

2026-11-27 PXIe-8840(NI Linux RT 8.6) 결과(`<deploy-dir>` = `/home/lvuser/models`, 3.1절 명령으로 경고 없이 빌드. 위의 세 곳을 고치기 전 소스와 고친 소스에서 값이 같음):

| 인자 (모델 인자 `noise_gen.so signal_filter.so` 생략) | 결과 |
| --- | --- |
| `-n 0` | `noise_gen` inport 0 / outport 2 / 파라미터 5, `signal_filter` inport 1 / outport 1 / 파라미터 7. 경로와 index가 `model-authoring.md` 4.1절 표와 같음. PASS |
| `-w 1:0=0:1` (기본값, Kalman) | PASS. `y_noisy` -1.703~1.618, `y_filt` -1.136~1.161. 스텝 시간 평균 0.3 µs, 최대 12.8 µs |
| `-s signal_filter/filter_mode=0 -w 1:0=0:1` | PASS. `y_filt`의 min/max/last가 `y_noisy`와 정확히 같음(bypass) |
| `-s noise_gen/Ts=1e-3 -s signal_filter/Ts=1e-3 -w 1:0=0:1` | PASS. `y_filt` -1.433~1.329. 10 kHz보다 덜 평활(3.4절 RMSE 0.1011과 같은 경향) |
| `-s signal_filter/filter_mode=5 -s signal_filter/pf_N=1000 -w 1:0=0:1` | PASS. 첫 스텝 전에 `pf_N` 1000을 설정하면 스텝 시간 평균 110 µs(1000·10000·40000 스텝에서 같음), 최대 176~245 µs. 3.4절처럼 `pf_N` 200 실행 뒤 1000으로 바꾸면 평균 46 µs. 같은 타깃 상태, 같은 코어(`taskset`)에서 재현했고 원인은 찾지 못함 |
| 없는 파라미터, `-w 0:0=1:0`(연결 순서 오류), `-w 1:1=0:1`(범위 밖 element), 없는 `.so` | 각각 `parameter ... not found`, `bad wire ...`, `dlopen ... No such file` 메시지 후 FAIL, exit 1 |

- WSL Ubuntu 24.04에서 R2025b Update 7 빌드로 실행했을 때도 인터페이스와 bypass 결과, 오류 처리가 같았습니다. 인자 형식이 틀리면(예: `-s signal_filter/filter_mode=`) 사용법을 출력하고 exit 2로 끝납니다.

### 3.3 타깃 전에 WSL에서 확인 (선택)

호스트에 WSL(x86-64 Linux)이 있으면 공용 타깃을 쓰기 전에 같은 바이너리와 `.so`를 확인할 수 있습니다. NI 툴체인 바이너리의 로더 경로(`/lib/ld-linux-x86-64.so.2`)가 Ubuntu와 달라 로더를 직접 지정합니다.

```bash
/lib64/ld-linux-x86-64.so.2 ./mit_smoke -n 0 ./noise_gen.so ./signal_filter.so
```

- Git Bash에서 `wsl.exe`에 `/mnt/...` 경로를 넘길 때는 `MSYS_NO_PATHCONV=1`을 앞에 붙입니다.
- WSL에서 잰 스텝 시간은 타깃 성능과 관계없습니다. 로드, 인터페이스, 수치 결과만 봅니다.

### 3.4 예제 시나리오 (`examples/mit_smoke_example.c`)

빌드 명령은 3.1과 같고 소스와 출력 이름만 다릅니다. 실행 인자는 `[모델 폴더, 기본 /home/lvuser/models] [단계별 스텝 수, 기본 10000]`입니다. 모델 폴더에 `noise_gen.so`와 `signal_filter.so`가 있어야 합니다.

```powershell
& "$bin\x86_64-nilrt-linux-gcc.exe" --sysroot=C:/build/17.0/x64/sysroots/core2-64-nilrt-linux -std=gnu99 -O2 -Wall -o mit_smoke_example <skill>\examples\mit_smoke_example.c -ldl -lm -lpthread
```

```powershell
scp mit_smoke_example <target>:/tmp/
```

```powershell
ssh <target> "chmod +x /tmp/mit_smoke_example && /tmp/mit_smoke_example <deploy-dir> 10000; rm -f /tmp/mit_smoke_example"
```

단계별로 10000 스텝을 실행하고, 오차 통계는 각 단계의 처음 0.05 s를 제외합니다. 2026-11-27 PXIe-8840 결과:

| 단계 | RMSE | bias | max\|e\| | 노이즈 표준편차 | 스텝 시간 평균 / 최대 (두 모델 합) |
| --- | --- | --- | --- | --- | --- |
| Ts 1e-4, mode 4 (Kalman) | 0.0442 | -0.00030 | 0.1681 | 0.1982 | 0.3 µs / 13.8 µs |
| Ts 1e-4, mode 0 (bypass) | 0.1982 | -0.00098 | 0.8181 | 0.1982 | 0.2 µs / 13.5 µs |
| Ts 1e-4, mode 1 (Butterworth 1차) | 0.0563 | -0.00038 | 0.1985 | 0.1994 | 0.2 µs / 6.4 µs |
| Ts 1e-3, mode 4 (Kalman) | 0.1011 | -0.00028 | 0.3556 | 0.1970 | 0.3 µs / 3.4 µs |
| Ts 1e-4, mode 5, `pf_N` 200 | 0.0466 | -0.00206 | 0.1725 | 0.2026 | 9.3 µs / 34.0 µs |
| Ts 1e-4, mode 5, `pf_N` 1000 | 0.0446 | -0.00157 | 0.1610 | 0.2004 | 45.7 µs / 170.0 µs |

읽는 법:

- 노이즈 표준편차는 `y_noisy − y_clean`의 표준편차입니다. 0.2에 가까우면 outport 순서(0번 `y_clean`, 1번 `y_noisy`)가 맞습니다.
- RMSE는 Simulink 결과(`model-authoring.md` 4.4절)와 같은 수준입니다. Kalman 0.0457 → 0.0442, bypass 0.1988 → 0.1982.
- 같은 RMSE 값이 R2025b Update 7 빌드를 WSL에서 실행했을 때도 그대로 나왔습니다(난수 순서가 같음).
- 스텝 시간은 일반 우선순위 프로세스에서 잰 값이라 최대값에 다른 작업에 의한 지연이 섞여 있습니다. `pf_N` 1000의 평균은 실행 순서에 따라 46 µs 또는 110 µs(3.2절)이고, 110 µs는 10 kHz 주기(100 µs)를 넘습니다. `pf_N`은 500 이하에서 시작해 `Finished Late?`로 확인합니다. Timed Loop(실시간 우선순위)에서의 스텝 시간은 재지 않았습니다.
