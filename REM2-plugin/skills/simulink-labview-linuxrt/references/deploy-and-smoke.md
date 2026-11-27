# 타깃 준비, 배포, LabVIEW 없이 실행 확인

아래 명령의 `<target>`은 SSH 접속 대상입니다(`admin@<target-ip>` 또는 SSH 별칭, 예: `pxi8840`). `<deploy-dir>`의 기본값은 `/home/lvuser/models`입니다. 비밀번호는 명령이나 파일에 넣지 않습니다.

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

배포할 파일: 빌드한 모델 `.so`와, NI MIT 예제 모델 `libsinewave64.so`(`C:\Program Files (x86)\National Instruments\LabVIEW 2020\examples\Control and Simulation\Model Interface\Models\`, x86-64용). `libsinewave64.so`는 타깃에서 모델이 로드되지 않을 때 원인이 MIT 설치인지 빌드인지 가르는 기준 모델입니다.

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
| `scripts/mit_smoke.c` | 일반 도구. 모델 N개 로드, 인터페이스 출력, 경로로 파라미터 설정, 포트 연결, N 스텝 실행, 출력 범위·스텝 시간 출력 | WSL(x86-64 Linux)에서 확인. 타깃 실행은 미확인 |
| `examples/mit_smoke_example.c` | 예제 두 모델 전용 시나리오. 단계별 파라미터 변경과 참값 대비 RMSE | 타깃에서 확인 |

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

WSL Ubuntu 24.04에서 R2025b Update 7 빌드로 실행한 결과(발췌): 두 모델의 인터페이스가 `model-authoring.md` 4.1절 표와 같고, bypass에서 `model 1 outport element 0`의 min/max/last가 `model 0 outport element 1`(`y_noisy`)과 같았습니다. 잘못된 연결, 없는 파라미터, 잘못된 값, 없는 파일은 각각 오류 메시지와 `FAIL`(또는 사용법 출력)로 끝났습니다.

### 3.3 타깃 전에 WSL에서 확인 (선택)

호스트에 WSL(x86-64 Linux)이 있으면 공용 타깃을 쓰기 전에 같은 바이너리와 `.so`를 확인할 수 있습니다. NI 툴체인 바이너리의 로더 경로(`/lib/ld-linux-x86-64.so.2`)가 Ubuntu와 달라 로더를 직접 지정합니다.

```bash
/lib64/ld-linux-x86-64.so.2 ./mit_smoke -n 0 ./noise_gen.so ./signal_filter.so
```

- Git Bash에서 `wsl.exe`에 `/mnt/...` 경로를 넘길 때는 `MSYS_NO_PATHCONV=1`을 앞에 붙입니다.
- WSL에서 잰 스텝 시간은 타깃 성능과 관계없습니다. 로드, 인터페이스, 수치 결과만 봅니다.

### 3.4 예제 시나리오 (`examples/mit_smoke_example.c`)

빌드 명령은 3.1과 같고 소스만 다릅니다. 실행 인자는 `[모델 폴더, 기본 /home/lvuser/models] [단계별 스텝 수, 기본 10000]`입니다.

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
- 스텝 시간은 일반 우선순위 프로세스에서 잰 값이라 최대값에 다른 작업에 의한 지연이 섞여 있습니다. 10 kHz(100 µs)에서 `pf_N` 1000은 평균만 46 µs이므로, `pf_N`은 500 이하에서 시작해 `Finished Late?`로 확인합니다. Timed Loop(실시간 우선순위)에서의 스텝 시간은 재지 않았습니다.
