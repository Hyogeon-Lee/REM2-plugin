# 05 — Boundary conditions

Boundary helpers are methods on the Maxwell app object (`maxwell.py`). Each is
valid only for certain solvers. Returns a `BoundaryObject` or `False`.

## Vector potential (A=const, truncate the field region) — `maxwell.py:4064`

Maxwell **2D** Eddy Current / Magnetostatic / Transient. Set A=0 on the outer
region edges → flux tangential to boundary (flux contained).

```python
region = m3d.modeler.create_region(pad_percent=200)
m3d.assign_vector_potential(
    assignment=region.edges,    # edge 이름/ID 리스트
    vector_value=0,
    boundary="A0",
)
```

## Insulating (zero normal current/flux between touching bodies) — `maxwell.py:2860`

```python
m3d.assign_insulating(assignment="coil", insulation="ins_coil")
```

## Symmetry (cut the model on a symmetry plane) — `maxwell.py:1838`

```python
m3d.assign_symmetry(
    assignment=[face.id],       # 대칭면 (faces 2D edges)
    symmetry_name="sym1",
    is_odd=True,                # True=odd(접선 H=0), False=even(법선 B=0)
)
```

`is_odd=True` (odd / "flux normal") vs `False` (even / "flux tangential") — choose
by whether field is normal or tangential to the cut plane.

## Master / Slave (matching, periodic) — `maxwell.py:3111` & `4113`

```python
m3d.assign_master_slave(
    master_edge=master_face_or_edge,
    slave_edge=slave_face_or_edge,
    reverse_master=False,
    reverse_slave=False,
    same_as_master=True,        # True=even/matching, False=odd/anti
    boundary_name="periodic1",
)
```

Use for rotating-machine sector models (e.g. one pole pitch) to avoid meshing the
full 360°.

## Other Maxwell boundaries

```python
m3d.assign_flux_tangential(assignment=[face], flux_name="ft1")          # Transient A-Phi
m3d.assign_resistive_sheet(assignment=face, resistance="1ohm")          # thin sheet
m3d.assign_impedance(assignment=face, ...)                              # EddyCurrent skin
m3d.assign_current_density_terminal(assignment=face)                    # CD terminal
```

## Solve region & "balloon"/radiation

For open-boundary 3D, the air `create_region(pad_percent=...)` plus default
behaviour is usually enough; truncate with vector potential (2D) or leave the
region's natural Neumann (3D). HFSS/eddy radiation boundaries live on the
respective app (`hfss.assign_radiation_boundary_to_objects`, etc.).

## Pattern: contain the field in a 2D magnetostatic model

```python
region = m3d.modeler.create_region(pad_percent=300)
m3d.assign_vector_potential(region.edges, vector_value=0, boundary="A0")
```

## Inspecting boundaries

```python
m3d.boundaries            # 현재 정의된 BoundaryObject 리스트
b = m3d.boundaries[0]
b.name; b.type; b.props   # props dict 로 세부값 수정 후 b.update()
b.delete()
```
