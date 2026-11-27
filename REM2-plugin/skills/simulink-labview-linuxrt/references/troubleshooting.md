# 문제 해결 (단계별 증상 → 원인 → 조치)

"실제 발생"은 예제 프로젝트에서 실제로 겪고 고친 문제입니다.

## 1. Simulink 모델

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| MATLAB Function 블록 오류 "블록 출력의 크기 및/또는 유형을 확인할 수 없습니다" | `*_core.m`을 찾지 못함 | 모델 폴더를 현재 폴더로 두거나 경로에 추가. 한 번 실패한 캐시(`slprj`, `*.slxc`)를 지우고 다시 실행 |
| 생성 코드에 큰 정적 버퍼(예: 999×999, 약 8 MB)나 `emxArray`/`malloc` | 가변 크기로 추론된 대입(실제 발생: `z = filtic(...)`), 동적 할당이 필요한 함수(`trackingPF`) | `z(:) = ...`로 고정 크기 배열에 대입. 동적 할당 함수는 고정 크기 직접 구현으로 대체 |
| 필터 차단 주파수나 신호 주파수가 이상함 | 모델 `Ts`와 실제 루프 주기가 다름 | 모든 모델의 `Ts`와 Timed Loop `dt`를 같은 반복에서 함께 바꿈 |

## 2. 빌드

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| `build_mit:noTlc` | Model Framework 경로 미등록 | `addpath('C:\VeriStand'); NIVeriStandAddPaths` |
| `build_mit:noToolchain`, `### VeriStand Linux64 toolchain not found` | 크로스 컴파일러 미설치 또는 레지스트리 키 `gccToolchain\17.0` 없음 | 2017판 설치, `reg query`로 키 확인, MATLAB 재시작 후 `NIVeriStandAddPaths` (`environment.md` 2.3절) |
| `build_mit:noModel` | 모델이 `OutputDir`에도 MATLAB 경로에도 없음 | 모델 폴더를 `OutputDir`로 주거나 `addpath` |
| `build_mit:otherCopyLoaded` | 같은 이름의 모델이 다른 폴더에서 이미 로드됨. 로드된 모델이 디스크 파일보다 우선하므로 그 사본이 빌드될 상태 | 메시지대로 `close_system('<모델>')` 후 다시 실행 |
| `NIVeriStand_Linux_64.tlc`를 찾을 수 없음 | MF 2020에는 OS별 target이 없음 | `VeriStand.tlc` + Linux64 툴체인(`build_mit` 기본값) |
| `Unable to find BlockIdx within the ExternalInput scope` (실제 발생) | R2025b + MF 2020, 루트 Inport가 있는 모델 | 패치 1 (`mf2020-r2025b-patches.md`) |
| `'<모델>_DW' undeclared`, `<모델>.c`가 비정상적으로 짧음 (실제 발생) | R2025b TLC의 `"r+"` 동작 | 패치 2, 그다음 캐시 삭제 |
| `.so`에 `U rt_InitInfAndNaN` (실제 발생) | R2025b `rt_nonfinite.c`에 이 함수가 없음 | 패치 3, 캐시 삭제 |
| 패치 후에도 같은 오류 (실제 발생) | 빌드 캐시로 이전 코드 재사용 | `slprj`, `*.slxc`, `*_veristand_rtw` 삭제 후 재빌드 |
| `'<모델>.bat' is not recognized as an internal or external command` (실제 발생) | `NoDefaultCurrentDirectoryInExePath`가 있는 MATLAB에서 `slbuild`를 직접 부름 | `build_mit` 사용(자동 처리). 환경변수를 끄지 않음 |
| `patch: **** malformed patch` 또는 hunk 실패 | MF 버전이 20.0.0이 아니거나 이미 패치됨, 또는 패치 파일의 줄 끝이 바뀜 | `.orig` 존재와 `patch -R --dry-run` 확인. 패치 파일을 다시 저장하지 않음, `--binary` 사용 |
| `build_mit:noSo` | 빌드는 끝났지만 `.so`가 없음 | 빌드 로그의 컴파일러 출력 확인. `GenCodeOnly`가 아닌지 확인 |
| 컴파일 옵션이 `-O0` | 기본 빌드 구성 `Faster Builds` | `build_mit`이 `Faster Runs`로 설정. 직접 빌드할 때 확인 |

## 3. `.so`, 타깃, 배포

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| `readelf`가 ELF32 또는 ARM | 다른 툴체인으로 빌드 | Linux64 툴체인, 하드웨어 `Intel->x86-64 (Linux 64)` |
| 타깃 크기 검사 오류(`rtwtypes.h`) | 하드웨어 Windows64(`long` 32 bit) | 하드웨어를 `Intel->x86-64 (Linux 64)`로(`build_mit` 기본값) |
| `undefined symbol: sem_init` | `libpthread`가 없는 프로세스에서 `.so`를 엶 | 테스트 프로그램은 `-lpthread`로 링크. LabVIEW Load Model에서 이 오류가 나면 `.so` 링크에 `libpthread`를 추가해 다시 빌드해야 함(확인하지 않은 경우) |
| 두 모델을 연 테스트 프로그램에서 포트 수가 바뀌거나 segfault (실제 발생) | `RTLD_GLOBAL`로 열어 같은 이름의 심볼이 섞임 | `RTLD_LOCAL`로 열기(`build-and-verify.md` 4절) |
| `ldd: command not found` | NI Linux RT에는 `ldd`가 없음 | `/lib/libc.so.6` 실행으로 glibc 확인 |
| WSL에서 `cannot execute: required file not found` | NI 툴체인 바이너리의 로더 경로 `/lib/ld-linux-x86-64.so.2`가 Ubuntu에 없음 | `/lib64/ld-linux-x86-64.so.2 ./mit_smoke ...` |
| SSH 출력 파싱이 깨짐 | 접속마다 NI 배너 출력 | 배너 줄을 걸러냄 |
| LabVIEW가 MIT 버전 불일치를 알림 | 호스트와 타깃 MIT 버전 차이 | 공용 타깃이면 사용자에게 알리고 관련된 사람과 맞춘 뒤 설치. 직접 다시 설치하지 않음 |

## 4. LabVIEW MIT VI

| 증상 | 원인 | 조치 |
| --- | --- | --- |
| Load Model 오류 1, 메시지 끝에 `<Not A Path>` (`File/Directory Info in ... Load Library.vi`) (실제 발생) | Windows 화면의 Path 컨트롤에 Linux 경로를 입력 | 문자열 상수나 String 컨트롤 → String to Path |
| Load Model 오류 -383200 | MIT 형식이 아닌 파일. 경로 오타, 32-bit/ARM `.so` | 경로와 `readelf -h` 확인 |
| `libsinewave64.so`도 로드되지 않음 | 타깃에 MIT가 없음 | 사용자가 NI MAX에서 MIT 설치(`deploy-and-smoke.md` 1절) |
| `libsinewave64.so`는 되고 빌드한 `.so`만 안 됨 | 빌드 문제 | `build-and-verify.md` 3절 기준값과 비교, `mit_smoke` 실행, 오류 코드와 메시지 기록 |
| Set Parameter Inline 오류 -383700 (실제 발생) | `Update Parameters In Line?` = TRUE를 쓰지 않았거나, Set Parameter Inline의 모델 입력이 Property Node 뒤쪽 와이어가 아님(미연결, 앞에서 분기, 노드 위를 지나가기만 함) | Property Node 뒤쪽 와이어에 직렬 연결. 노드를 끌어 연결 여부 확인 |
| 오류는 없는데 출력이 입력과 같고 파라미터를 바꿔도 그대로 (실제 발생) | 모델 와이어를 루프 경계에서 터널로 넘김 | 시프트 레지스터로 바꿈 |
| 실행 중 파라미터를 바꿔도 반영되지 않음 (실제 발생) | Set Parameter Inline이 루프 밖에 있어 시작 때 한 번만 실행됨, 또는 컨트롤이 루프 안팎에 하나씩 있어 안쪽 값이 덮어씀 | Set Parameter Inline과 컨트롤을 루프 안으로, 컨트롤은 하나만 |
| `Parameter subindex is out of bounds.` | `Parameter index`와 `Offset within parameter` 와이어를 바꿔 꽂음(둘 다 정수라 표시가 안 남) | Ctrl+H로 단자 확인 |
| 파라미터를 바꿨는데 다른 값이 바뀜 | id 범위 검사 누락으로 Index Array가 0을 돌려줘 index 0이 선택됨 | In Range and Coerce로 범위 안일 때만 설정 |
| `late count` 증가 | 스텝 시간이 루프 주기에 가까움 | 계산량 파라미터(예제: `pf_N`)를 줄이거나 Ts를 늘림. 단계 A의 `Max Step Time (us)` 참고. Timed Loop 안 배열 생성 노드 제거 |
| 호스트에 데이터가 오지 않음 | URL 오타(`//<target-ip>/rt_data`), 방화벽, RT VI 미실행 | URL, 방화벽 허용 목록, RT VI 실행 상태 확인 |
| RT VI 정지 후 다음 실행에서 Load 오류 | 이전 실행에서 Unload가 실행되지 않음 | Clear Errors를 거쳐 항상 Unload. 해결되지 않으면 사용자에게 타깃 재부팅을 요청 |
| 장시간 실행 시 여유 메모리 감소 | Timed Loop 안 배열 생성, 루프 안 신호 이름 조회 | 배열은 루프 밖에서 만들고 Replace Array Subset. 신호 이름 조회는 초기화 때만 |
