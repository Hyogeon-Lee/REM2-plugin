# 빌드와 `.so` 검증

## 1. 빌드 (`scripts/build_mit.m`)

MATLAB 세션마다 한 번 Model Framework 경로와 툴체인을 등록한 뒤 빌드합니다.

```matlab
addpath('C:\VeriStand'); NIVeriStandAddPaths     % 세션마다 1회. Linux64 툴체인 등록
addpath('<skill>\scripts')
so = build_mit(["noise_gen", "signal_filter"], OutputDir='<project>')
```

| 호출 | 동작 |
| --- | --- |
| `build_mit(models)` | 현재 폴더에서 전체 빌드. 결과 `<모델>.so`가 현재 폴더에 생김 |
| `build_mit(models, OutputDir=dir)` | `dir`로 이동해 빌드하고 원래 폴더로 돌아옴. 빌드 폴더(`<모델>_veristand_rtw`, `slprj`, `*.slxc`)와 `.so`가 `dir`에 생김 |
| `build_mit(models, GenCodeOnly=true)` | 코드만 생성. 크로스 컴파일러 없이도 동작 |
| `build_mit(models, SystemTargetFile=stf)` | 다른 NI target 파일을 쓸 때 |
| `so = build_mit(...)` | 만든 `.so`의 전체 경로(string 열 벡터) |

- 모델 파일과 MATLAB Function 블록이 부르는 파일(`*_core.m` 등)은 `OutputDir`에 있거나 MATLAB 경로에 있어야 합니다. 모델이 없으면 `build_mit:noModel`로 멈추고, `*_core.m`이 없으면 MATLAB Function 블록 오류가 납니다(`troubleshooting.md` 1절).
- `OutputDir`는 스킬 폴더 밖의 프로젝트 폴더로 줍니다. 예제를 빌드할 때는 `examples/`를 그 폴더로 복사합니다. 빌드 폴더와 캐시가 `OutputDir`에 생기기 때문입니다.
- 같은 이름의 모델이 다른 폴더에서 이미 로드되어 있으면 `build_mit:otherCopyLoaded`로 멈춥니다. 로드된 모델이 디스크 파일보다 우선하기 때문입니다. `close_system`으로 닫고 다시 실행합니다.
- `NIVeriStandAddPaths` 출력에 `### VeriStand Linux64 toolchain not found`가 없어야 합니다.
- 각 모델의 active configuration set을 복사해 target(`VeriStand.tlc`), 툴체인(`VeriStand Compiler for Linux64 targets | gmake makefile (64-bit Linux)`), 하드웨어(`Intel->x86-64 (Linux 64)`), 빌드 구성(`Faster Runs`, `-O2`), `StopTime = inf`를 넣고, 빌드 후(오류가 나도) 원래 설정으로 되돌린 뒤 복사본을 지웁니다. `.slx` 파일과 미저장 편집은 바뀌지 않습니다.
- MATLAB 프로세스에 `NoDefaultCurrentDirectoryInExePath`가 있으면(에이전트·MCP가 띄운 MATLAB) 코드만 생성한 뒤 빌드 폴더에서 `.\<모델>.bat`를 명시적 경로로 실행합니다. 이 환경변수를 끄는 방식으로 우회하지 않습니다. 변수가 없는 MATLAB에서 Simulink 표준 make 경로로 끝까지 빌드하는 것은 확인하지 않았습니다.
- 빌드가 끝났는데 `.so`가 없으면 `build_mit:noSo`로 멈춥니다.
- MF 패치를 적용하거나 바꾼 뒤 첫 빌드 전에는 `slprj`, `*.slxc`, `*_veristand_rtw`를 지웁니다.

정상 빌드에서 나오는 경고(결과에 영향 없음):

- `Parameter 'FixedStep' of 'Configuration' is non-tunable but refers to tunable variables (Ts)`
- `VeriStand: Bus diagnostics are set to 'warning' or 'none' ...` (VeriStand가 해당 진단을 `error`로 바꿈)
- `Update the system target file 'VeriStand.tlc' to support the enhanced TLC block interface ...`
- 루트 수준 출력을 `Dataset` 형식으로 기록할 수 없다는 경고

빌드 시간(예제, 확인한 PC): `noise_gen` 약 20 s, `signal_filter` 약 70 s(캐시 없는 첫 빌드).

## 2. 검증 명령

타깃에 올리기 전에 호스트에서 확인합니다. `.so`가 있는 폴더에서 PowerShell로 실행하고, 모델마다 반복합니다.

```powershell
$bin = "C:\build\17.0\x64\sysroots\i686-nilrtsdk-mingw32\usr\bin\x86_64-nilrt-linux"
& "$bin\x86_64-nilrt-linux-readelf.exe" -h noise_gen.so | Select-String "Class|Type:|Machine"
(& "$bin\x86_64-nilrt-linux-nm.exe" -D --defined-only noise_gen.so | Select-String " NIRT_").Count
& "$bin\x86_64-nilrt-linux-nm.exe" -D noise_gen.so | Select-String "rt_InitInfAndNaN"
& "$bin\x86_64-nilrt-linux-nm.exe" -D --undefined-only noise_gen.so
& "$bin\x86_64-nilrt-linux-objdump.exe" -T noise_gen.so | Select-String "GLIBC_"
```

## 3. 기준값

| 항목 | 기대값 |
| --- | --- |
| `readelf -h` | `ELF64`, `DYN (Shared object file)`, `Advanced Micro Devices X86-64` |
| `NIRT_*` export 수 | 29 |
| `rt_InitInfAndNaN` | `W`(약한 심볼, 정의됨). `U`이면 패치 3이 빠진 것 |
| 미해결 심볼 | C 런타임(`malloc`, `fopen`, `printf` 등), 수학 함수(`sin`, `exp`, `sqrt` 등), 세마포어(`sem_*`)만. `rt_` 또는 모델 이름으로 시작하는 미해결 심볼이 있으면 안 됨 |
| 필요한 glibc | 최대 `GLIBC_2.14`. 타깃 glibc가 2.14 이상이어야 함(예제 타깃 2.24) |
| 크기 (예제) | `noise_gen.so` 95,663 B, `signal_filter.so` 119,545 B. R2025b Update 6과 Update 7에서 같음. 해시는 빌드마다 다름 |

- 미해결 `malloc`은 NI 래퍼 코드(신호 이름 조회 등)가 씁니다. 모델 스텝 함수에는 동적 할당이 없습니다.
- 의존 라이브러리(`readelf -d`의 `NEEDED`)는 `libstdc++.so.6`, `libm.so.6`, `libgcc_s.so.1`, `libc.so.6`입니다. `sem_*`를 쓰지만 `libpthread.so.0`은 없습니다. MF 2020의 Linux64 툴체인(`veristand_linux64_tc.m`)이 `-lpthread`를 넣지 않기 때문입니다(NI 예제 `libsinewave64.so`에는 있음). LabVIEW RT 프로세스(`lvrt`)에는 `libpthread`가 이미 올라와 있어(`/proc/<pid>/maps`로 확인) MIT에서는 문제가 없었습니다. LabVIEW 밖에서 `.so`를 여는 프로그램은 `-lpthread`로 링크합니다.

## 4. 같은 이름의 전역 심볼

모델 `.so`는 모두 같은 이름의 전역 심볼을 공개합니다. Model Framework 래퍼와 GRT 코드가 모델마다 같은 이름을 쓰기 때문입니다(`MdlOutputs`, `MdlUpdate`, `S`, `rtParameter`, `READSIDE`, `SetExternalInputs`, `SetExternalOutputs`, `NIRT_*` 등, 예제 두 모델에서 103개 공통, `readelf --dyn-syms`로 확인). `-Bsymbolic` 링크 플래그도 없습니다.

- 한 프로세스가 두 `.so`를 `RTLD_GLOBAL`로 열면 나중에 연 모델의 내부 호출이 먼저 연 모델의 심볼로 연결됩니다. 타깃에서 재현했을 때 `signal_filter`가 `noise_gen`의 포트 수(inport 0, outport 2)를 보고했고, 출력이 섞였으며, 파라미터 설정 실패 후 segfault가 났습니다.
- LabVIEW 2020 RT(MIT)에서 두 모델을 함께 로드했을 때는 이런 증상이 없었습니다.
- 다른 로더에서 여러 모델을 한 프로세스에 올릴 때는 `RTLD_LOCAL`로 엽니다. `.so`를 `-Wl,-Bsymbolic`으로 링크하는 방안은 확인하지 않았습니다.

## 5. MIT 없이 가는 대안 (확인하지 않음)

Model Framework 경로가 막히면 (a) R2020a 이하 MATLAB으로 빌드하거나, (b) Embedded Coder `ert_shrlib.tlc`로 크로스 컴파일한 `.so`를 LabVIEW Call Library Function Node로 호출하는 방법이 있습니다.
