# 04 — Excitations (coil / winding / current / voltage)

All excitation helpers are **methods on the Maxwell app object** (`maxwell.py`).
They return a `BoundaryObject` (truthy) or `False`. Validity depends on the
solution type — noted per method.

## Coil + winding (stranded/solid driven conductors)

The standard magnetics pattern: create a **winding** (the circuit/source), create
**coil terminals** on conductor cross-section faces, then bind coils to the
winding.

```python
# 1) 권선(winding) 생성 — 전류원
winding = m3d.assign_winding(
    assignment=None,            # 여기서 바로 면 리스트를 줘서 coil 자동 생성도 가능
    winding_type="Current",     # "Current" | "Voltage" | "External"
    is_solid=True,              # True=solid, False=stranded
    current=3,                  # A
    resistance=0,               # ohm
    inductance=0,               # H
    voltage=0,                  # V
    parallel_branches=1,
    phase=0,                    # deg
    name="phaseA",
)

# 2) 코일 터미널 생성 (도체 단면 / 면 ID 에)
coil = m3d.assign_coil(
    assignment=conductor.faces[0].id,   # 객체/이름/면ID 리스트
    conductors_number=20,               # 권선 수 (stranded turns)
    polarity="Positive",                # "Positive" | "Negative"
    name="coil_A1",
)

# 3) 코일을 권선에 연결
m3d.add_winding_coils(assignment=winding.name, coils=[coil.name])
```

Shortcut — pass faces straight to `assign_winding(assignment=[...])` and PyAEDT
creates and links the coils for you.

**2D note**: in Maxwell 2D, `assign_coil` takes the conductor object directly
(the cross-section is the object); `add_winding_coils` uses `AddWindingCoils`. In
3D it uses `AddWindingTerminals` on faces. PyAEDT picks the right one.

## Current excitation (`maxwell.py:757`)

Direct current into a face/object — Magnetostatic, EddyCurrent, Transient,
ElectroDCConduction (A-Phi solvers support `excitation_model`).

```python
cur = m3d.assign_current(
    assignment=cyl.top_face_z.id,   # 면 ID / 객체 / 리스트
    amplitude="2mA",                # 숫자(=A) 또는 단위 문자열
    phase="0deg",
    solid=True,                     # True=solid, False=stranded
    swap_direction=False,           # 전류 방향 반전
    name="I_in",
    excitation_model="Single Potential",  # A-Phi 전용
)
```

## Voltage excitation (`maxwell.py:1084`)

```python
v = m3d.assign_voltage(assignment=face.id, amplitude=1, name="V1")          # Electrostatic/DC
m3d.assign_voltage_drop(assignment=[f1, f2], amplitude=1)                    # 도체 양단 전압강하
```

## Current density (volumetric, Magnetostatic)

```python
m3d.assign_current_density(
    assignment="coil_solid",
    current_density_name="Jsrc",
    phase="0deg",
    current_density_x="1e6",        # A/m^2
    current_density_y="0",
    current_density_z="0",
)
```

## Force / torque / matrix (parameters to compute, set at excitation stage)

```python
m3d.assign_force(assignment="mover", is_virtual=True, force_name="F_mover")
m3d.assign_torque(assignment="rotor", is_positive=True, torque_name="T_rotor")
m3d.assign_matrix(assignment=["phaseA", "phaseB"], matrix_name="Inductance")
```

`assign_matrix` over windings yields the inductance/resistance matrix —
post-process as `Matrix1.L(phaseA,phaseA)` (see 07).

## Picking the terminal face

- Cylinder conductor along Z: `cyl.top_face_z.id` / `cyl.bottom_face_z.id`.
- Swept coil: `coil.faces[0].id` (the cut cross-section), or query with
  `mod.get_faceid_from_position(pos, assignment=coil.name)`.
- Always pass face **IDs** (ints) for 3D coil/current terminals, object **names**
  for 2D.
