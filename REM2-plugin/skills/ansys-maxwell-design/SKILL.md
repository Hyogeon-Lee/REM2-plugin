---
name: ansys-design
description: >-
  Generate PyAEDT (ansys.aedt.core) Python scripts that drive ANSYS Electronics
  Desktop end-to-end: launch AEDT, build geometry, assign materials, set coil/
  winding/current excitations, apply boundary conditions, mesh, create analysis
  setups, solve, post-process (field plots, reports, solution data export), and
  run parametric/optimization studies. Use for the high-level object-oriented
  PyAEDT API (Maxwell3d, Maxwell2d, Hfss, Q3d, Icepak, etc.) — NOT the low-level
  IronPython oEditor/oModule scripting (that is the ansys-maxwell skill). Trigger
  keywords: PyAEDT, ansys.aedt.core, Maxwell3d, Maxwell2d, modeler.create_box,
  create_cylinder, create_polyline, assign_material, assign_winding, assign_coil,
  assign_current, assign_voltage, assign_vector_potential, assign_insulating,
  assign_symmetry, assign_master_slave, create_setup, analyze, create_fieldplot,
  create_report, get_solution_data, parametrics.add, optimizations.add, solenoid,
  magnetostatic, eddy current, transient, electromagnetic FEA.
---

# ansys-design — PyAEDT electromagnetic design workflow

PyAEDT (`ansys.aedt.core`) is the high-level Python API for ANSYS Electronics
Desktop (AEDT). One application object (e.g. `Maxwell3d`) owns the whole project:
`.modeler` (geometry), materials, excitations, boundaries, `.mesh`, setups,
`.post` (results), `.parametrics` / `.optimizations`. This skill maps the full
design loop to that API.

## When to use this skill vs `ansys-maxwell`

| Need | Skill |
|------|-------|
| High-level Python, `from ansys.aedt.core import Maxwell3d`, object API, runs in CPython | **ansys-design** (this) |
| Low-level IronPython, `oEditor.CreateBox`, `oModule.AssignCurrent`, runs inside AEDT's embedded interpreter | ansys-maxwell |

If unsure which API the user wants: PyAEDT is the modern default. Use ansys-maxwell
only when the user explicitly needs in-AEDT IronPython / `oProject` scripting.

## The workflow loop

```
1. Connect      → launch/attach AEDT, pick app + solution type   → 01-connection.md
2. Geometry     → modeler primitives + boolean ops + CS          → 02-geometry.md
3. Materials    → assign_material / add_material                 → 03-materials.md
4. Excitation   → coil / winding / current / voltage            → 04-excitation.md
5. Boundary     → vector potential / insulating / symmetry / m-s → 05-boundary.md
6. Mesh+Setup   → mesh ops, create_setup, sweeps, analyze        → 06-mesh-setup-solve.md
7. Post-process → field plots, reports, solution data export     → 07-postprocessing.md
8. Optimize     → parametrics.add / optimizations.add            → 08-optimization.md
```

Read the reference file for the stage you are scripting. `examples/solenoid_magnetostatic.py`
is a complete end-to-end run touching every stage.

## Non-negotiable rules

1. **Import root is `ansys.aedt.core`** (not legacy `pyaedt`):
   `from ansys.aedt.core import Maxwell3d`.
2. **Solution type decides which methods are legal.** `assign_winding`,
   `assign_coil`, `assign_vector_potential` etc. are solver-specific. Pick the
   solution type first (`Magnetostatic`, `EddyCurrent`, `Transient`,
   `Electrostatic`, `DCConduction`, `ElectroDCConduction`, `ACConduction`,
   `ElectricTransient`). State the chosen solver in a comment.
3. **Geometry methods return `Object3d`** — keep the handle, reference it by
   `.name`, `.faces`, `.edges`, `.top_face_z`, `.bottom_face_z`, `.id`. Do not
   hard-code generated names.
4. **Units**: set `m3d.modeler.model_units = "mm"` once. Excitation/boundary
   helpers accept either a number (default SI-ish unit applied) or a string with
   units (`"2mA"`, `"0deg"`). Prefer explicit unit strings.
5. **Variables/parameters**: define design variables via `m3d["coil_turns"] = 20`
   then reference the string `"coil_turns"` in primitives — required for any
   parametric/optimization step (08).
6. **Always solve via `m3d.analyze(setup=...)`** (or `analyze_setup`). Validate
   first with `m3d.validate_simple()` when debugging.
7. **Clean shutdown**: end scripts with `m3d.save_project()` then
   `m3d.release_desktop()` (keep AEDT open) or `m3d.desktop_class.close_desktop()`
   (full close). Never leave a locked project.
8. **Code comments in Korean** (per user convention); identifiers/strings English.

## Quickstart skeleton

```python
from ansys.aedt.core import Maxwell3d

# AEDT 실행 + Magnetostatic 솔버로 디자인 생성
m3d = Maxwell3d(
    project="coil_study",
    solution_type="Magnetostatic",
    version="2025.1",
    non_graphical=False,
    new_desktop=True,
)
m3d.modeler.model_units = "mm"

# 2~6단계: geometry / material / excitation / boundary / setup
# (각 reference 파일 참고)

# 7단계: 해석
m3d.analyze(setup="MySetup")

# 8단계: 결과
sol = m3d.post.get_solution_data(expressions="Matrix1.L(Coil,Coil)")

m3d.save_project()
m3d.release_desktop()
```

## API resolution discipline

PyAEDT is large and version-sensitive. When the exact signature of a method
matters, confirm it against the installed package source under
`src/ansys/aedt/core/` (this repo is PyAEDT itself) rather than guessing kwargs.
Key source locations:

- App classes: `maxwell.py`, `hfss.py`, `q3d.py`, `icepak.py`
- Geometry: `modeler/cad/primitives_3d.py`, `primitives_2d.py`, `primitives.py`, `object_3d.py`
- Materials: `modules/material_lib.py`, `modules/material.py`
- Excitation/boundary: `maxwell.py` (methods on the app), `modules/boundary/maxwell_boundary.py`
- Setup/solve: `modules/solve_setup.py`, `application/analysis.py`
- Post: `visualization/post/post_common_3d.py`, `visualization/post/common.py`
- Optimization: `modules/design_xploration.py`
