---
name: simulink-labview-linuxrt
description: Workflow for running Simulink models inside LabVIEW Real-Time on an NI Linux Real-Time x64 target (e.g. PXIe-8840) through the NI Model Interface Toolkit (MIT). Covers MIT-ready model authoring, building MIT .so files with VeriStand Model Framework 2020 and the NI Linux RT cross compiler (build_mit), patching Model Framework 2020 for MATLAB R2025b, .so verification, deployment, a LabVIEW-free smoke test on the target (mit_smoke), and wiring MIT VIs (Load Model, Take Model Time Step, Set Parameter Inline) in an RT Timed Loop. Use when building, deploying, or debugging a Simulink→MIT→LabVIEW RT chain, including korean requests like Simulink LabVIEW 연동, Simulink 모델을 LabVIEW RT에서 실행, MIT .so 빌드, VeriStand Model Framework 빌드 오류, NI Linux RT 배포, PXIe-8840 모델 실행, Set Parameter Inline 오류, Load Model 오류.
---

# Simulink → MIT `.so` → LabVIEW RT (NI Linux RT x64)

Requires on the Windows host: MATLAB + Simulink + MATLAB Coder + Simulink Coder (plus the toolboxes the model uses), NI VeriStand Model Framework 2020, C & C++ Development Tools for NI Linux Real-Time 2017, LabVIEW 2020 + Real-Time Module + Model Interface Toolkit 2020. Version table and checks: `references/environment.md`.

Everything here was confirmed on 2026-11-27 with one PC and one PXIe-8840 (MATLAB R2025b, MF 2020, LabVIEW 2020 SP1 32-bit). Other versions are unverified; say so when the user's setup differs.

## When to use

- Turn a Simulink model into an MIT `.so` for an NI Linux RT x64 target and run it from a LabVIEW RT VI.
- Diagnose a failure at any step: TLC/compile errors, missing symbols in the `.so`, Load Model errors, parameters that do not change at run time.
- Not covered: ARM targets (cRIO-906x etc.), Pharlap/VxWorks, VeriStand system definitions, FPGA I/O.

## Inputs to collect

Ask for these when not given. Use the example values only as examples.

| Input | Example (from the verified project) | Default |
| --- | --- | --- |
| Target address or SSH alias, user | `admin@<target-ip>`, alias `pxi8840` | none — ask |
| Deploy folder on the target | `/home/lvuser/models` | `/home/lvuser/models` |
| Models to build | `["noise_gen", "signal_filter"]` | none — ask |
| Model chaining (which outport feeds which inport) | `signal_filter.u ← noise_gen.y_noisy` | none |
| Parameters to change at run time (MIT paths) | `signal_filter/filter_mode` | none |
| Loop rate | 10 kHz (`Ts = 1e-4`) | none — ask |
| MATLAB release | R2025b | `version` in MATLAB |
| Host install paths | `C:\VeriStand\2020`, `C:\build\17.0` | these defaults |

## Safety rules (MUST)

- Never put passwords in scripts, commands, environment variables, or files. Use SSH keys; let the user type a password when asked.
- The target is often shared. Never reinstall or upgrade target software (NI MAX "Add/Remove Software", `opkg`) on your own: a host with different versions overwrites other users' setups. Deploy first; only when LabVIEW reports a version mismatch, tell the user and let them coordinate.
- The Model Framework patches modify a system install (`C:\VeriStand\2020`). Before applying: confirm with the user, check whether `.orig` files exist and whether the patches are already applied (`patch -R --dry-run`), run `--dry-run`, and keep `-b` backups. Details: `references/mf2020-r2025b-patches.md`.
- Copy files only to the deploy folder; run test binaries from `/tmp` and delete them afterwards.

## Workflow

| # | Step | Action | Pass criterion | Reference |
| --- | --- | --- | --- | --- |
| 1 | Author the model | One MATLAB Function block calling `*_core.m`; tunable `Simulink.Parameter`s in the model workspace | Rules in `model-authoring.md` met | `model-authoring.md` |
| 2 | Verify in MATLAB | Simulate; assert-based test (example: `examples/test_filters.m`) | Asserts pass | `model-authoring.md` |
| 3 | Host environment | Toolboxes, NI packages, cross compiler, registry key `gccToolchain\17.0` | Matches the version table; `reg query` shows `x64_gccPath` | `environment.md` |
| 4 | MF patches (MATLAB > R2020a) | `patch -p1 -b --binary` from `scripts/patches` | `--dry-run` clean, or reverse dry-run shows already applied | `mf2020-r2025b-patches.md` |
| 5 | Build | `addpath('C:\VeriStand'); NIVeriStandAddPaths` then `build_mit(models, OutputDir=dir)` | One `<model>.so` per model | `build-and-verify.md` |
| 6 | Verify the `.so` | `readelf`, `nm`, `objdump` from the cross toolchain | ELF64 x86-64, 29 `NIRT_*` exports, `rt_InitInfAndNaN` = `W`, no undefined `rt_*`/model symbols, glibc ≤ 2.14 | `build-and-verify.md` |
| 7 | Deploy | `scp` to the deploy folder | `-rw-r--r--`, SHA-256 matches | `deploy-and-smoke.md` |
| 8 | Smoke test without LabVIEW | Cross-compile `scripts/mit_smoke.c`, run on the target (optionally first on WSL) | `PASS`; outputs plausible (example: RMSE as in Simulink) | `deploy-and-smoke.md` |
| 9 | LabVIEW load test | Load NI's `libsinewave64.so` first, then each model | No error; port and parameter counts match | `labview-mit.md` §2 |
| 10 | Chain models, change parameters at run time | Timed Loop, Set Parameter Inline inside the loop, model wires on shift registers | Parameter change shows in the output | `labview-mit.md` §2.1 |
| 11 | Full RT VI + host VI | RT FIFO, Network Streams, commands `[code, id, value]` | `late count` stays 0; host RMSE close to Simulink | `labview-mit.md` §3–5 (unverified) |

Diagnose failures with `references/troubleshooting.md` (symptom → cause → fix, by step).

## Core rules (details in the references)

Model:
- Run-time parameters: model-workspace `Simulink.Parameter`, storage class `Model default`, model `DefaultParameterBehavior = Inlined`, passed into the MATLAB Function block as scope `Parameter`. MIT then sees them as `<model>/<name>`.
- Single rate, `FixedStepDiscrete`, `FixedStep = Ts`. Compute every time-dependent quantity from the `Ts` parameter, not model time, so changing `Ts` and the loop period together needs no rebuild.
- Clamp LabVIEW-supplied parameters inside the model. Fixed-size arrays only (no `malloc`/`emxArray` in generated code).

Build:
- MF 2020 has one target, `VeriStand.tlc`; the OS comes from the toolchain `VeriStand Compiler for Linux64 targets | gmake makefile (64-bit Linux)`. Hardware `Intel->x86-64 (Linux 64)`, build configuration `Faster Runs`, `StopTime = inf`. `build_mit` sets these on a temporary configuration-set copy and restores the model afterwards.
- With `NoDefaultCurrentDirectoryInExePath` set (MATLAB started by an agent), Simulink's make step cannot find `<model>.bat`; `build_mit` generates code, then runs the `.bat` by explicit path. Do not unset the variable.
- After patching, delete `slprj`, `*.slxc`, `*_veristand_rtw` before the first build, or Simulink reuses stale code.

`.so` and target:
- The MF 2020 `.so` lacks `libpthread` in `NEEDED`: fine inside LabVIEW (`lvrt` has it); standalone loaders link `-lpthread`.
- Every model `.so` exports the same global names; standalone loaders must use `RTLD_LOCAL`.
- NI Linux RT has no `ldd`; run `/lib/libc.so.6` to see the glibc version. SSH prints an NI banner on every login; filter it when parsing output.

LabVIEW MIT:
- Model path: string → String to Path (a Path control filled on Windows yields `<Not A Path>`, error 1).
- The model wire is a by-value class: pass it across loop borders with shift registers (a tunnel silently drops the state), and connect Set Parameter Inline in series after the Property Node that sets `Update Parameters In Line?` = TRUE (otherwise -383700).
- Set Parameter Inline goes inside the loop, one control per parameter. Unload Model always runs (error wire through Clear Errors). No array-building nodes inside the Timed Loop. Change model `Ts` and the Timed Loop `dt` in the same iteration.

## Verification status

Confirmed (2026-11-27): Simulink simulation and error analysis of the example; MATLAB R2025b Update 6 + MF 2020 (3 patches) + cross compiler 2017 build; R2025b Update 7 rebuild with this skill's `build_mit` (same `.so` sizes and verification values); `malloc`/`emxArray` = 0 in generated code; deployment and `mit_smoke` on the PXIe-8840 (Kalman RMSE 0.0442, bypass 0.1982, parameter and `Ts` changes); the same `mit_smoke` results reproduced on WSL Ubuntu 24.04 from the Update 7 build; two models chained in one LabVIEW Timed Loop at 10 kHz with run-time `filter_mode` switching (host MIT 20.0.0, target MIT 20.4.0); `RTLD_GLOBAL` loading breaks two models in one process.

Not confirmed — state this when relevant:
- The full RT VI (RT FIFO, Network Streams) and host VI (`labview-mit.md` §3–4).
- RMSE and Timed Loop step time measured inside LabVIEW; inport/outport path strings from the MIT Property Node.
- MATLAB releases other than R2025b Update 6/7; cross compilers other than the 2017 edition.
- The standard Simulink make path (MATLAB without `NoDefaultCurrentDirectoryInExePath`).
- Linking the `.so` with `-Wl,-Bsymbolic`.
- Whether `ni-labview-2020-simulation-x86` is needed for MIT.
- The generalized `scripts/mit_smoke.c` on the target itself (checked on WSL only; `examples/mit_smoke_example.c` is the target-verified original).

## Files

- `scripts/build_mit.m` — `build_mit(models, OutputDir=..., GenCodeOnly=..., SystemTargetFile=...)`; returns the `.so` paths.
- `scripts/mit_smoke.c` — general smoke test: load N models, print interfaces, set parameters by path, chain ports, step, report. Usage in its header and `deploy-and-smoke.md`.
- `scripts/patches/*.patch` — MF 2020 patches for R2025b (keep byte-exact; `.gitattributes` disables line-ending conversion).
- `examples/` — worked example: `noise_gen.slx` (sine + noise), `signal_filter.slx` (6 selectable filters), `*_core.m`, `test_filters.m` (Simulink verification), `mit_smoke_example.c` (the target-verified scenario for these two models).
- `references/` — `environment.md`, `mf2020-r2025b-patches.md`, `model-authoring.md`, `build-and-verify.md`, `deploy-and-smoke.md`, `labview-mit.md`, `troubleshooting.md`.
