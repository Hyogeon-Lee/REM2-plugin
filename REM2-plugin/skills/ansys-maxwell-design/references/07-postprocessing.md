# 07 — Post-processing (field plots, reports, data export)

Everything hangs off `m3d.post` (`visualization/post/`). Two output families:
**field plots** (3D overlays on geometry) and **reports/solution data** (X-Y
curves, scalar results, matrices).

## Solution data (numbers out → Python) — `common.py:1677`

```python
sol = m3d.post.get_solution_data(
    expressions="Matrix1.L(phaseA,phaseA)",   # 또는 리스트
    setup_sweep_name=None,        # None=nominal, 또는 "MySetup : LastAdaptive"
    domain="Sweep",               # "Sweep" | "Time"
    variations=None,              # {"freq": ["1kHz"], "air_gap": ["0.5mm"]}
    primary_sweep_variable=None,  # x축 변수
    report_category="Fields",
)
sol.primary_sweep_values         # x값
sol.data_real()                  # y값 (실수부)
sol.data_magnitude()
sol.full_matrix_real_imag        # 행렬형 결과
sol.export_data_to_csv("L.csv")
```

`get_solution_data` is the workhorse for inductance/force/loss vs. parameter.
Common Maxwell expressions: `Matrix1.L(c,c)`, `Matrix1.R(c,c)`,
`Force_mover.Force_x`, `Torque_rotor.Torque_z`, `SolidLoss`, `CoreLoss`,
`InputCurrent(phaseA)`.

## Reports (X-Y plots inside AEDT) — `common.py:1472`

```python
report = m3d.post.create_report(
    expressions="Matrix1.L(phaseA,phaseA)",
    setup_sweep_name="MySetup : LastAdaptive",
    primary_sweep_variable="air_gap",
    variations={"air_gap": ["All"]},
    plot_type="Rectangular Plot",      # "Rectangular" | "Data Table" | "Polar" …
    plot_name="L_vs_gap",
)
m3d.post.plots                          # 생성된 리포트 리스트
report.export_to_file("L_vs_gap.csv")
report.export_image("L_vs_gap.jpg")
```

## Field plots (3D field overlays) — `post_common_3d.py`

```python
# 객체 표면에 필드 (B, H, J, Energy…)
fp_s = m3d.post.create_fieldplot_surface(
    assignment=["core"], quantity="Mag_B", plot_name="B_surface")

# 단면(cut plane)에 필드
m3d.modeler.create_coordinate_system(origin=[0,0,0], name="cut")  # 또는 기존 plane
fp_c = m3d.post.create_fieldplot_cutplane(
    assignment="Global:XY", quantity="Mag_B", plot_name="B_cut")

# 체적(volume) 필드
fp_v = m3d.post.create_fieldplot_volume(
    assignment=["core"], quantity="Energy", plot_name="E_vol")
```

`quantity` examples (Maxwell): `Mag_B`, `B_Vector`, `Mag_H`, `Mag_J`, `Ohmic_Loss`,
`Energy`, `Mag_E`, `Volume_Force_Density`.

## Export field plot to image / animation

```python
m3d.post.export_field_jpg("B_surface.jpg", plot_name="B_surface",
                          project_path=m3d.working_directory)
fp_s.export_image("B_surface.png")

# pyvista 기반 인터랙티브/오프스크린 플롯 — post_common_3d.py:2095
m3d.post.plot_field(quantity="Mag_B", assignment=["core"],
                    plot_type="Surface", show=False,
                    export_path="B_field.jpg")
```

`plot_field` renders via PyVista (works in non-graphical too) — best for
scripted/headless image generation.

## Field calculator (derived scalars)

```python
m3d.post.ofieldsreporter         # 저수준 calculator 핸들
# 또는 고수준
val = m3d.post.get_scalar_field_value(quantity="Mag_B", scalar_function="Maximum",
                                      object_name="core")
```

## Export everything

```python
m3d.post.export_report_to_csv(m3d.working_directory, "L_vs_gap")
m3d.export_results()                 # 솔버 결과 일괄
m3d.post.export_model_picture("model.jpg")
```
