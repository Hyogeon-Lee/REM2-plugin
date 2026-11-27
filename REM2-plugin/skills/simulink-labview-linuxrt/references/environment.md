# 환경: 버전 조합과 호스트 설치

모든 값은 2026-11-27에 한 PC와 PXIe-8840에서 확인한 것입니다. 다른 조합은 확인하지 않았습니다.

## 1. 확인한 버전 조합

| 구분 | 확인한 버전 | 다른 PC에서 |
| --- | --- | --- |
| MATLAB | R2025b Update 6 (`25.2.0.3312555`)에서 전체 흐름 확인. R2025b Update 7 (`25.2.0.3360999`)에서 같은 빌드 결과 확인 | 같은 버전 권장. 다른 버전은 `mf2020-r2025b-patches.md` 4절 |
| LabVIEW | LabVIEW 2020 SP1 32-bit (`LabVIEW.exe` 20.0.1f1, 패키지 `ni-labview-2020-core-x86-en` 20.1.1) | 같아야 함 |
| LabVIEW Real-Time Module | 2020 (`ni-labview-2020-rt-module-x86-en` 20.0.0) | 같아야 함 |
| Model Interface Toolkit (MIT) | 2020 (`ni-labview-2020-model-interface-toolkit-x86` 20.0.0) | 같아야 함 |
| VeriStand Model Framework | 2020 (`ni-veristand-2020-matlab-support-x86` 20.0.0), 기본 위치 `C:\VeriStand\2020` | 같아야 함. R2020a보다 새 MATLAB이면 패치 필요 |
| 크로스 컴파일러 | C & C++ Development Tools for NI Linux Real-Time, Eclipse Edition 2017 (gcc 4.9.2), 기본 위치 `C:\build\17.0` | 같은 제품(2017판). 다른 연도판은 확인하지 않음 |
| NI MAX / PXI Platform Services | 20.5 / 20.5 | 비슷한 버전이면 됨 |
| 드라이버 | NI-DAQmx 20.1, FlexRIO 20.6, CompactRIO 20.5, LabVIEW FPGA Module 20.0.1 | 사람마다 다름. 3절 |
| 타깃 (예) | NI PXIe-8840 (Intel Core i7-5700EQ, 4코어), NI Linux Real-Time 8.6 x64, kernel `4.14.146-rt67-cg-8.6.0f0`, glibc 2.24 | x64 NI Linux RT 타깃 |
| 타깃의 NI 소프트웨어 (`opkg list-installed`) | `ni-labview-realtime` 20.0.0, `ni-model-interface-toolkit` 20.4.0, `ni-veristand-engine`/`ni-veristand-model-framework-runtime` 20.4.0, `ni-rio` 20.0.0, `ni-flexrio` 20.6.0, `ni-daqmx` 20.1.0 | 공용 장비면 다시 설치하지 않음(`deploy-and-smoke.md` 1절) |

호스트 MIT 20.0.0으로 만든 VI가 타깃 MIT 20.4.0에서 문제없이 실행됐습니다.

## 2. 호스트 설치

### 2.1 MATLAB toolbox

| 제품 | 용도 | 필수 |
| --- | --- | --- |
| MATLAB, Simulink | 모델 | 예 |
| MATLAB Coder, Simulink Coder | C 코드 생성 (`VeriStand.tlc`) | 예 |
| 모델이 쓰는 toolbox | 예제: Signal Processing Toolbox(`butter`, `filter`, `filtic`), Sensor Fusion and Tracking Toolbox(`trackingKF`). 빌드할 때만 필요하고 생성된 C 코드는 toolbox 없이 동작 | 모델에 따라 |
| Embedded Coder | `VeriStand.tlc` 빌드에는 필요 없음. MIT 없이 `ert_shrlib.tlc`로 가는 대안 경로에서만 사용 | 아니오 |

설치 여부 확인(빈 배열이면 모두 설치됨):

```matlab
need = ["Simulink", "MATLAB Coder", "Simulink Coder"];   % 모델이 쓰는 toolbox를 추가
have = string({ver().Name});
missing = need(~ismember(need, have))
```

### 2.2 NI 소프트웨어 (NI Package Manager 패키지 이름)

| 패키지 | 확인한 버전 | 용도 | 필수 |
| --- | --- | --- | --- |
| `ni-labview-2020-core-x86-en` | 20.1.1 | LabVIEW 2020 SP1 32-bit | 예 |
| `ni-labview-2020-rt-module-x86-en` | 20.0.0 | RT 타깃용 VI 작성과 배포 | 예 |
| `ni-labview-2020-model-interface-toolkit-x86` | 20.0.0 | MIT VI 팔레트 | 예 |
| `ni-veristand-mit-labview-2020-support-x86` | 20.0.0 | MIT의 LabVIEW 지원 파일. MIT와 함께 설치됨 | 예 |
| `ni-veristand-2020-mit-realtime-bin` | 20.0.0 | NI MAX가 타깃에 설치하는 MIT RT 바이너리 | 예 |
| `ni-veristand-2020-matlab-support-x86` | 20.0.0 | VeriStand Model Framework 2020. target 파일과 툴체인 정의 | 예 |
| `ni-max` | 20.5 | 타깃 소프트웨어 설치 | 예 |
| `ni-pxiplatformservices` | 20.5 | PXI 섀시 지원 | PXI일 때 |
| `ni-labview-command-line-interface-x86` | 3.1 | LabVIEWCLI | 아니오 |
| `ni-labview-2020-simulation-x86` | 20.1 | Control Design & Simulation Module. MIT가 이것을 필요로 하는지는 확인하지 않음 | 미확인 |

`.so` 빌드에 꼭 필요한 것은 Model Framework와 크로스 컴파일러입니다. LabVIEW, RT Module, MIT는 타깃에서 모델을 실행할 때 필요합니다.

### 2.3 크로스 컴파일러

- 제품: **C & C++ Development Tools for NI Linux Real-Time, Eclipse Edition 2017**. NI Package Manager 피드가 아니라 ni.com의 단독 설치 파일입니다. 기본 위치 `C:\build\17.0`.
- 2017판이어야 하는 이유: Model Framework 2020의 Linux64 툴체인 정의(`veristand_linux64_tc.m`)가 레지스트리 키 `HKLM\SOFTWARE\WOW6432Node\National Instruments\gccToolchain\17.0`에서 컴파일러 위치를 읽습니다. 이 키는 2017판 설치 프로그램이 만듭니다. 키가 없으면 Linux64 툴체인이 등록되지 않습니다.
- 설치 후 MATLAB을 다시 시작하고 `NIVeriStandAddPaths`를 실행합니다.

확인:

```powershell
reg query "HKLM\SOFTWARE\WOW6432Node\National Instruments\gccToolchain\17.0"
```

정상이면 다음 값이 보입니다(ARM 항목도 함께 있음).

```text
gccVersion     REG_SZ    4.9.2
x64Path        REG_SZ    C:\build\17.0\x64
x64_gccPath    REG_SZ    C:\build\17.0\x64\sysroots\i686-nilrtsdk-mingw32\usr\bin\x86_64-nilrt-linux\x86_64-nilrt-linux-gcc.exe
```

```powershell
& "C:\build\17.0\x64\sysroots\i686-nilrtsdk-mingw32\usr\bin\x86_64-nilrt-linux\x86_64-nilrt-linux-gcc.exe" --version
```

첫 줄에 `4.9.2`가 나오면 됩니다.

### 2.4 설치 확인 명령

NI 패키지 버전을 한 번에 봅니다.

```powershell
& "C:\Program Files\National Instruments\NI Package Manager\nipkg.exe" list-installed | Select-String "ni-labview-2020-core-x86-en |rt-module-x86-en |model-interface-toolkit|veristand|ni-max |pxiplatformservices|ni-daqmx |ni-flexrio "
```

MATLAB에서 Model Framework 등록을 확인합니다. 출력에 `### VeriStand Linux64 toolchain not found`가 없어야 합니다.

```matlab
addpath('C:\VeriStand'); NIVeriStandAddPaths
which('VeriStand.tlc')
```

## 3. 드라이버 (사람마다 다른 부분)

- 하드웨어 I/O를 쓰지 않는 모델과 RT VI는 NI-DAQmx, NI-RIO, FlexRIO 없이 빌드와 MIT 실행이 됩니다.
- LabVIEW 프로젝트에 FPGA Target이 있으면 그 항목을 열거나 빌드할 때 LabVIEW FPGA Module과 해당 보드의 RIO 드라이버가 필요합니다. FPGA를 쓰지 않으면 프로젝트에 "missing"으로 표시돼도 RT VI 실행에는 영향이 없습니다.
- 드라이버를 쓰면 타깃의 드라이버 버전이 호스트와 같아야 합니다. NI MAX는 호스트에 있는 버전만 타깃에 설치할 수 있으므로, 공용 타깃은 마지막에 설치한 사람의 버전으로 바뀝니다. 누가 어떤 버전으로 설치했는지 기록합니다.
- 모델 입력을 DAQ 신호로 바꾸면 NI-DAQmx가 호스트와 타깃 양쪽에 필요합니다.
