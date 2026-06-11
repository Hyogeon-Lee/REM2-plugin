# 03 — Materials

Two ways to put material on a body: assign an existing library material, or
create a custom one then assign it.

## Assign an existing material

```python
# 방법 1: 생성 시 지정 (가장 간단)
core = m3d.modeler.create_box([0,0,0], [10,10,10], name="core", material="ferrite")

# 방법 2: 사후 할당 (app 레벨, 여러 객체 한 번에) — application/analysis_3d.py:718
m3d.assign_material(assignment=["core", "yoke"], material="steel_1008")

# 방법 3: Object3d 속성
core.material_name = "copper"
```

Material names are AEDT library names: `"copper"`, `"aluminum"`, `"steel_1008"`,
`"ferrite"`, `"iron"`, `"vacuum"`, `"air"`, `"polyamide"`, `"FR4_epoxy"`, …
`m3d.materials.checkifmaterialexists("copper")` verifies.

## Create a custom material (`modules/material_lib.py:305`)

```python
mat = m3d.materials.add_material(
    name="my_steel",
    properties={
        "permeability": 1000,
        "conductivity": 2e6,
        "permittivity": 1,
    },
)
# 또는 객체 속성으로 세밀 조정
mat = m3d.materials.add_material("nl_steel")
mat.permeability = 2000
mat.conductivity = 1.1e7
mat.mass_density = 7800
mat.update()
m3d.assign_material("core", "nl_steel")
```

Common property keys: `permittivity`, `permeability`, `conductivity`,
`dielectric_loss_tangent`, `magnetic_loss_tangent`, `mass_density`,
`specific_heat`, `thermal_conductivity`, `youngs_modulus`, `poissons_ratio`.

## Nonlinear B-H curve (saturation)

```python
mat = m3d.materials.add_material("BH_steel")
mat.permeability.value = [[0, 0], [200, 1.0], [400, 1.5], [1000, 1.8],
                          [10000, 2.0]]   # [[H (A_per_meter), B (tesla)], ...]
mat.update()
```

`mat.permeability` becomes a nonlinear dataset; set it as a list of `[H, B]`
points. For anisotropic, assign a 3-element list.

## Surface materials (radiation / Icepak)

```python
sm = m3d.materials.add_surface_material(name="black_paint", emissivity=0.9)
```

## Inspect / export

```python
m3d.materials.material_keys          # dict of loaded materials
m3d.materials["copper"].conductivity
m3d.materials.export_materials_to_file("mats.json")
```
