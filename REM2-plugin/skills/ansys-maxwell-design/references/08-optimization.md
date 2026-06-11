# 08 — Parametric sweeps & optimization

`modules/design_xploration.py`. Access via `m3d.parametrics` (sweeps) and
`m3d.optimizations` (goal-seeking: optimization, sensitivity, DOE, tuning).

**Prerequisite**: the quantities you sweep must be **design variables**
(`m3d["air_gap"] = "0.5mm"`) and referenced as strings in geometry/excitation.

## Parametric sweep (`parametrics.add`, line 1016)

```python
param = m3d.parametrics.add(
    variable="air_gap",
    start_point="0.2mm",
    end_point="1.0mm",
    step="0.2mm",
    variation_type="LinearStep",   # "LinearCount" | "LinearStep" | "LogScale" | "SingleValue"
    name="gap_sweep",
)

# 추가 변수 (다차원 sweep)
param.add_variation(sweep_variable="coil_turns", start_point=10, end_point=30,
                    step=5, variation_type="LinearStep")

# 결과로 뽑을 양 등록
param.add_calculation(calculation="Matrix1.L(phaseA,phaseA)",
                      report_category="Fields", ranges={})

param.analyze()        # 스윕 실행
```

After solving, pull results with `get_solution_data(..., variations={"air_gap":["All"]})`
(see 07).

## Optimization (`m3d.optimizations.add`)

```python
opt = m3d.optimizations.add(
    calculation="Matrix1.L(phaseA,phaseA)",   # 목적함수
    ranges={},                                 # 평가 조건 (freq/time 등)
    optimization_type="Optimization",          # "Optimization"|"Sensitivity"|"Tuning"|"DXDOE"|"DesignExplorer"
    name="maximize_L",
)

# 설계 변수 범위 + 목표
opt.add_variation(sweep_variable="air_gap", start_point="0.2mm",
                  end_point="1mm", step=0.05)
opt.add_goal(calculation="Matrix1.L(phaseA,phaseA)",
             ranges={}, condition="Maximize")   # "Maximize"|"Minimize"|"="
opt.analyze()
```

Optimizer choices (set on `opt.props["Optimizer"]`): `"Quasi Newton"`,
`"Pattern Search"`, `"Sequential Nonlinear Programming"`,
`"Sequential Mixed Integer Nonlinear Programming"`, `"Genetic Algorithm"`.

```python
opt.props["Optimizer"] = "Genetic Algorithm"
opt.props["MaxIterations"] = 50
opt.update()
```

## Sensitivity / DOE / Tuning

Same `optimizations.add` with `optimization_type`:

- `"Sensitivity"` — local gradient of output w.r.t. each variable.
- `"DXDOE"` — design of experiments table.
- `"Tuning"` — interactive single-variable tuning.

## Read optimization results

```python
opt.analyze()
sol = m3d.post.get_solution_data(
    expressions="Matrix1.L(phaseA,phaseA)",
    setup_sweep_name=f"{opt.name} : LastAdaptive",
    variations={"air_gap": ["All"]},
)
# 최적점 변수값은 AEDT optimetrics 결과 또는 m3d["air_gap"] (옵티마이저가 갱신)
print(m3d["air_gap"])
```

## Output variables (composite objectives)

Define derived expressions once, optimize against them:

```python
m3d.create_output_variable("L_per_turn", "Matrix1.L(phaseA,phaseA)/coil_turns")
opt.add_goal(calculation="L_per_turn", condition="Maximize")
```

## Practical loop

1. Parameterize geometry with design variables (stage 02, using strings).
2. Verify a single nominal solve works (stages 06–07).
3. `parametrics.add` to scan the design space and eyeball trends.
4. `optimizations.add` + `add_goal` to drive to an objective.
5. Pull the optimum with `get_solution_data` / read back `m3d["var"]`.
