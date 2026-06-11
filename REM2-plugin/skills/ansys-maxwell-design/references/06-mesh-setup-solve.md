# 06 — Mesh, analysis setup, solve

## Mesh operations (`m3d.mesh`, `modules/mesh.py`)

AEDT auto-meshes, but refine where fields concentrate (gaps, conductors, edges):

```python
mesh = m3d.mesh

mesh.assign_length_mesh(
    assignment=["core", "coil"],
    maximum_length="1mm",          # 최대 요소 길이
    maximum_elements=None,
    name="len_core",
)
mesh.assign_surface_mesh(assignment="core", surface_deviation="0.01mm")
mesh.assign_skin_depth(assignment="coil", skin_depth="0.5mm", maximum_elements=5000)  # EddyCurrent
mesh.assign_model_resolution(assignment="core", defeature_length="0.1mm")
mesh.assign_initial_mesh_from_slider(level=5)   # 0(coarse)~9(fine)
```

Operations show in `mesh.meshoperations`.

## Analysis setup (`maxwell.py:2537`, `modules/solve_setup.py`)

```python
setup = m3d.create_setup(name="MySetup")
setup.props["MaximumPasses"] = 12        # 적응 메시 최대 패스
setup.props["PercentError"] = 1          # 수렴 기준 (%)
setup.props["MinimumPasses"] = 2
setup.props["NonlinearResidual"] = 1e-4  # 비선형 재료
setup.update()
```

Or pass props at creation via kwargs. Key props differ by solver:

| Solver | Important props |
|--------|-----------------|
| Magnetostatic / Electrostatic | `MaximumPasses`, `PercentError`, `PercentRefinement`, `NonlinearResidual` |
| EddyCurrent (AC Magnetic) | above + `Frequency` (e.g. `"60Hz"`), `HasSweepSetup` |
| Transient | `StopTime`, `TimeStep`, `SaveFieldsType` |

```python
# EddyCurrent 주파수
setup = m3d.create_setup("Eddy")
setup.props["Frequency"] = "1kHz"
setup.update()

# Transient 시간 설정
tr = m3d.create_setup("Tr")
tr.props["StopTime"] = "20ms"
tr.props["TimeStep"] = "0.5ms"
tr.update()
```

## Frequency sweep (EddyCurrent / HFSS / Q3D)

```python
sweep = m3d.create_setup("Eddy").add_sweep(sweep_type="Discrete")   # 또는 app별 헬퍼
# 일반적으로:
hfss.create_linear_count_sweep(setup="Setup1", units="GHz",
                               start_frequency=1, stop_frequency=10, num_of_freq_points=51)
```

For Maxwell EddyCurrent multi-frequency, set up via the setup's sweep editor or
`create_setup` then `setup.add_eddy_current_sweep(...)` depending on version —
confirm in `modules/solve_setup.py`.

## Solve (`application/analysis.py:1523`)

```python
m3d.analyze(
    setup="MySetup",        # None=모든 setup
    cores=4,                # CPU 코어
    tasks=1,                # 분산 태스크
    gpus=0,
    use_auto_settings=True,
    blocking=True,          # True=완료까지 대기
)
# 또는 단일 setup
m3d.analyze_setup("MySetup", cores=4)
```

## Pre-solve validation

```python
ok = m3d.validate_simple()          # 빠른 검증
m3d.validate_full_design()          # 상세 (있으면)
print(m3d.setups)                   # 정의된 setup 리스트
```

## After solve — check convergence

```python
setup = m3d.setups[0]
data = setup.get_convergence_data()     # 패스별 에러
m3d.export_convergence("MySetup", output_file="conv.prop")
```

Then move to 07 (post-processing).
