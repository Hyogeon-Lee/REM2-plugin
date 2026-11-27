# Model Framework 2020 패치 (MATLAB R2025b)

Model Framework 2020은 공식적으로 MATLAB R2020a까지 지원합니다(`NiEnumSimulinkCoderVersions` 기준). R2025b는 최소 버전 검사를 통과하지만 실제 빌드에서 아래 문제가 차례로 생깁니다. 패치 파일 3개는 `scripts/patches/`에 있습니다.

## 1. 경위 (발생 순서)

| # | 증상 | 원인 | 조치 |
| --- | --- | --- | --- |
| 1 | `NIVeriStand_Linux_64.tlc`를 찾을 수 없음 | MF 2020에는 OS별 target 파일이 없음. target은 `VeriStand.tlc` 하나이고 OS는 툴체인으로 고름. `NIVeriStand.tlc`는 Pharlap용 구버전 | `build_mit`이 `VeriStand.tlc` + 툴체인 `VeriStand Compiler for Linux64 targets \| gmake makefile (64-bit Linux)`를 씀 |
| 2 | `NIVeriStandAddPaths` 출력에 `### VeriStand Linux64 toolchain not found` | 크로스 컴파일러 미설치. 레지스트리 키 `gccToolchain\17.0`이 없으면 Linux64 툴체인이 등록되지 않음 | 2017판 설치 후 MATLAB 재시작, `NIVeriStandAddPaths` |
| 3 | 루트 Inport가 있는 모델에서 TLC 오류 `Unable to find BlockIdx within the ExternalInput scope` | R2025b의 `LibGetBlockPath`는 `block.BlockIdx`를 요구하는데 루트 Inport(`ExternalInput`) 레코드에는 이 필드가 없음 | 패치 1 |
| 4 | `'<모델>.bat' is not recognized as an internal or external command` | MATLAB 프로세스에 `NoDefaultCurrentDirectoryInExePath`가 있으면 `cmd`가 현재 폴더의 `.bat`를 이름만으로 찾지 않음. 에이전트가 띄운 MATLAB에서 생김 | `build_mit`이 코드만 생성한 뒤 `.\<모델>.bat`를 명시적 경로로 실행 |
| 5 | 컴파일 오류 `'<모델>_DW' undeclared`. `<모델>.c`에 모델 코드가 없음 | R2025b TLC는 `%openfile ..., "r+"`로 연 파일을 비움. NI 코드는 앞부분만 덮어쓰는 동작을 전제로 함 | 패치 2 |
| 6 | 패치 2 후에도 같은 오류 | 빌드 캐시. Simulink가 "up to date"로 판정해 이전 생성 코드를 다시 씀 | `slprj`, `*.slxc`, `*_veristand_rtw` 삭제 후 재빌드 |
| 7 | 빌드는 성공했지만 `.so`에 미해결 심볼 `rt_InitInfAndNaN` (`nm`으로 발견, 타깃 로드 시 실패할 상태) | R2025b의 `rt_nonfinite.c`는 Inf/NaN을 정적으로 초기화하고 이 함수를 만들지 않음. NI 래퍼는 여전히 호출 | 패치 3 |
| 8 | 컴파일 옵션이 `-O0` | 기본 빌드 구성 `Faster Builds` | `build_mit`이 `Faster Runs`(`-O2`)로 설정 |
| 9 | (예방) | Windows 64 하드웨어 설정은 `long`이 32 bit. Linux는 64 bit라 `rtwtypes.h` 크기 검사에 걸림 | `build_mit`이 `ProdHWDeviceType = 'Intel->x86-64 (Linux 64)'`로 설정 |

1, 4, 8, 9번은 `build_mit` 안에서 처리합니다. 2번은 설치 문제이고, 3, 5, 7번에 패치가 필요합니다.

## 2. 적용 절차

대상 파일은 모두 `C:\VeriStand\2020\ModelInterface\` 아래에 있습니다.

| 패치 파일 | 대상 | 해결하는 문제 |
| --- | --- | --- |
| `NiUtilityLib.tlc.patch` | `tmw\codegen\NiUtilityLib.tlc` | 1절 3번 |
| `NIVeriStand_codegen.tlc.patch` | `tmw\codegen\NIVeriStand_codegen.tlc` | 1절 5번 |
| `ni_modelframework.source.patch` | `tmw\src\ni_modelframework.source` | 1절 7번 |

시스템 설치 파일을 고치는 작업이므로 사용자에게 먼저 확인합니다. Git Bash에서 다음 순서로 진행합니다. `<skill>`은 이 스킬 폴더입니다.

1. 이미 적용됐는지 확인합니다. `.orig` 파일이 있으면 누군가 이미 패치했을 가능성이 큽니다. 역방향 dry-run이 오류 없이 끝나면 이미 적용된 상태이므로 다시 적용하지 않습니다.

```bash
cd /c/VeriStand/2020/ModelInterface
ls tmw/codegen/*.orig tmw/src/*.orig
for p in "<skill>"/scripts/patches/*.patch; do patch -p1 -R --dry-run --binary < "$p"; done
```

2. 적용 전 dry-run. 오류가 없어야 합니다.

```bash
for p in "<skill>"/scripts/patches/*.patch; do patch -p1 -b --binary --dry-run < "$p"; done
```

3. 적용. `-b`가 원본을 `<파일>.orig`로 백업합니다. `C:\VeriStand`에 쓰기 권한이 없으면 Git Bash를 관리자 권한으로 실행합니다.

```bash
for p in "<skill>"/scripts/patches/*.patch; do patch -p1 -b --binary < "$p"; done
```

4. 패치 후 첫 빌드 전에 빌드 폴더의 캐시를 지웁니다(1절 6번).

```powershell
Remove-Item -Recurse -Force slprj, *_veristand_rtw, *.slxc -ErrorAction SilentlyContinue
```

- 패치 파일은 원본(`.orig`)에 적용하면 패치된 파일과 바이트 단위로 같아지는 것을 확인했습니다(2026-11-27). 줄 끝이 CRLF/LF로 섞여 있으므로 `--binary`로 적용하고, 패치 파일을 편집기로 다시 저장하지 않습니다.
- Git Bash가 없으면 3절의 diff를 보고 직접 고칩니다. `+` 줄을 넣고 `-` 줄을 지웁니다.
- Model Framework를 재설치하거나 복구하면 패치가 지워집니다. 다시 적용합니다.
- 되돌리려면 각 `.orig`를 원래 이름으로 복사합니다.

## 3. 패치 내용

**패치 1: `NiUtilityLib.tlc`** (`NiLibGetBlockPath` 함수). `BlockIdx`가 없는 레코드에는 R2025b가 내부에서 쓰는 것과 같은 대체 경로 `LibUnmangledPathName(block.Name)`을 씁니다.

```diff
-        %else
+        %elseif ISFIELD(block, "BlockIdx")
             %assign fullPath = LibGetBlockPath(block)
+        %else
+            %assign fullPath = LibUnmangledPathName(block.Name)
         %endif
```

**패치 2: `NIVeriStand_codegen.tlc`**. NI 원본은 `<모델>.c`를 `"r+"`로 열어 맨 앞에 `#define NI_VERISTAND_MAINMODELFILE`을 덮어썼습니다. 패치는 파일 전체를 먼저 읽고(`fileread`, CR 제거) `"w"`로 다시 열어 define과 원래 내용을 차례로 씁니다. 결과는 원본 동작과 같고 TLC의 `"r+"` 동작에 의존하지 않습니다.

```diff
 		%if EXISTS(target)
-			%openfile fileHandle = target, "r+"
+			%assign niSrcPath = target
 		%else
-			%openfile fileHandle = "%<NiModelInformation.sourceFile>", "r+"
+			%assign niSrcPath = "%<NiModelInformation.buildDirectory>\\%<NiModelInformation.sourceFile>"
 		%endif
+		%assign niSrcText = FEVAL("regexprep", FEVAL("fileread", niSrcPath), "\\r", "")
+		%openfile fileHandle = niSrcPath, "w"
 		%selectfile fileHandle
-		%assign ::NiMainDefine = "\r\n#define NI_VERISTAND_MAINMODELFILE\n/*"
-		%<::NiMainDefine>
+		#define NI_VERISTAND_MAINMODELFILE
+		%<niSrcText>
 		%closefile fileHandle
```

**패치 3: `ni_modelframework.source`**. NI 래퍼가 모델 초기화 때 부르는 `rt_InitInfAndNaN`을 GCC 약한 심볼(weak)의 빈 함수로 정의합니다. R2025b는 Inf/NaN을 정적으로 초기화하므로 할 일이 없습니다. 구버전 MATLAB처럼 실제 정의가 생성되면 링커가 그쪽(strong 심볼)을 씁니다.

```diff
+#if defined(__GNUC__)
+__attribute__((weak)) void rt_InitInfAndNaN(size_t realSize) { (void)realSize; }
+#endif
```

## 4. 다른 MATLAB 버전에서

- R2020a 이하: MF 2020의 공식 지원 범위입니다. 패치 없이 빌드되어야 합니다(확인하지 않음).
- R2020b~R2025a: 확인하지 않았습니다. 세 패치는 원래 동작이 유지되는 경우에도 결과가 같게 작성했습니다(패치 1은 `BlockIdx`가 있으면 원래 경로, 패치 2는 `"r+"` 동작에 의존하지 않음, 패치 3은 실제 정의가 있으면 무시됨). 적용해 두는 편이 안전하지만 빌드와 타깃 로드를 다시 확인해야 합니다.
- R2025b: Update 6에서 전체 흐름, Update 7에서 빌드와 `.so` 검증값을 확인했습니다.
- R2025b 이후: 새 비호환이 생길 수 있습니다. 빌드 출력과 `build-and-verify.md` 3절의 검증값을 비교합니다.
