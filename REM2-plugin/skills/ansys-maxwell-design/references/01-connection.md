# 01 — Connection & project setup

## Launch / attach an application

```python
from ansys.aedt.core import Maxwell3d, Maxwell2d, Hfss, Q3d, Icepak, Desktop

m3d = Maxwell3d(
    project=None,            # None=활성 프로젝트, 또는 "name" / 전체 .aedt 경로
    design=None,             # None=활성 디자인
    solution_type=None,      # 솔버 타입 (아래 표) — 미지정 시 기본값
    setup=None,              # nominal setup 이름
    version="2025.1",        # "2025.1" / 251 / 25.1 / None(최신)
    non_graphical=False,     # True=GUI 없이 백그라운드 실행
    new_desktop=False,       # True=기존 인스턴스 무시하고 새 AEDT 실행
    close_on_exit=False,     # True=객체 소멸 시 AEDT 종료
    student_version=False,
    machine="",              # 원격 머신 이름 (RPC)
    port=0,                  # gRPC 포트
    aedt_process_id=None,    # 기존 AEDT 프로세스에 attach (new_desktop=False)
    remove_lock=False,       # .lock 파일 강제 제거
)
```

All AEDT app constructors share this signature (`Maxwell3d`, `Maxwell2d`, `Hfss`,
`Q3d`, `Icepak`, `Mechanical`, `Circuit`, …). The first positional is `project`.

## Solution types

### Maxwell 3D
`Magnetostatic`, `EddyCurrent` (AC Magnetic), `Transient`, `Electrostatic`,
`ElectroDCConduction` (DC conduction), `ElectricTransient`, `ACConduction`,
`TransientAPhiFormulation`, `DCBiasedEddyCurrent`.

### Maxwell 2D
`Magnetostatic`, `EddyCurrent`, `Transient` (z/xy via `TransientZ`/`TransientXY`),
`Electrostatic`, `ACConduction`, `DCConduction`.

The solution type gates which excitation/boundary methods are valid — set it at
construction time and keep a comment naming it.

## Multiple designs / desktop reuse

Launch the desktop once, add designs onto the same session:

```python
desktop = Desktop(version="2025.1", non_graphical=False, new_desktop=True)
m3d = Maxwell3d(project="study", design="mag", solution_type="Magnetostatic")
hfss = Hfss(project="study", design="rf")   # 같은 desktop 세션 재사용
```

## Design variables (parametric-ready from the start)

```python
m3d["coil_turns"] = 20          # 무차원 변수
m3d["air_gap"] = "0.5mm"        # 단위 포함 변수
m3d["$global_len"] = "10mm"     # $ 접두사 = 프로젝트 전역 변수
val = m3d["air_gap"]            # 읽기
```

Reference these names as strings in geometry/excitation args to make the model
parametric (needed for stage 08).

## Housekeeping

```python
m3d.modeler.model_units = "mm"          # 길이 단위
m3d.logger.info("setup complete")       # 로깅
m3d.validate_simple()                   # 디자인 유효성 검사
m3d.save_project()                      # 저장
m3d.release_desktop(close_projects=False, close_desktop=False)  # PyAEDT 분리, AEDT 유지
m3d.desktop_class.close_desktop()       # AEDT 완전 종료
```

Prefer a `try/finally` so AEDT never stays locked:

```python
m3d = Maxwell3d(solution_type="Magnetostatic", new_desktop=True)
try:
    ...
    m3d.analyze()
finally:
    m3d.save_project()
    m3d.release_desktop()
```
