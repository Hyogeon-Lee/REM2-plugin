# 02 — Geometry (modeler)

All geometry goes through `m3d.modeler` (a `Modeler3D` / `Modeler2D`). Primitive
creators return an `Object3d` handle — **keep it**.

## Primitives — 3D (`modeler/cad/primitives_3d.py`)

```python
mod = m3d.modeler
mod.model_units = "mm"

box  = mod.create_box(origin=[0, 0, 0], sizes=[10, 20, 5],
                      name="core", material="ferrite")
cyl  = mod.create_cylinder(orientation="Z", origin=[0, 0, 0], radius=5,
                           height=30, num_sides=0, name="post", material="copper")
sph  = mod.create_sphere(origin=[0, 0, 0], radius=8, name="ball")
rect = mod.create_rectangle(orientation="XY", origin=[0, 0, 0], sizes=[10, 5],
                            name="sheet")              # 면(surface) 객체
circ = mod.create_circle(orientation="Z", origin=[0, 0, 0], radius=4, name="disc")
bw   = mod.create_bondwire(start=[0,0,0], end=[5,0,0], h1=0.2, h2=0.1, diameter=0.05)
reg  = mod.create_region(pad_percent=200)              # air/벨류 region (해석 영역)
```

`orientation` accepts `"X"/"Y"/"Z"` or `0/1/2`. `num_sides=0` → true circle.

## Primitives — 2D (`modeler/cad/primitives_2d.py`)

Maxwell 2D works in the XY plane. Use `create_rectangle`, `create_circle`,
`create_regular_polygon`, `create_ellipse`, `create_polyline`. `create_region`
makes the solve region.

## Polyline (sweep profiles, coils, paths) — `primitives.py:7069`

```python
pl = mod.create_polyline(
    points=[[0, 0, 0], [10, 0, 0], [10, 10, 0]],
    segment_type=None,              # "Line"/"Arc"/"Spline" 또는 세그먼트 리스트
    cover_surface=False,            # True=닫힌 단면을 면으로 덮음
    close_surface=False,
    name="path",
    xsection_type=None,             # "Circle"/"Rectangle"… → 단면 있는 와이어
    xsection_width="1mm",
    xsection_height="1mm",
)
```

## Boolean & transform ops (`primitives.py`, also methods on `Object3d`)

```python
mod.subtract(blank_list=core, tool_list=[hole1, hole2], keep_originals=False)
mod.unite([part_a, part_b])
mod.intersect([a, b], keep_originals=False)

# Object3d 메서드 형태도 가능
core.subtract([hole1])
a.unite([b])
```

### Duplication / sweep (coils, windings)

```python
mod.duplicate_around_axis(coil, axis="Z", angle=45, clones=8,
                          create_new_objects=True)
mod.duplicate_along_line(obj, vector=[0, 0, 5], clones=4)
mod.sweep_along_vector(rect, sweep_vector=[0, 0, 20])        # 면→솔리드 압출
mod.sweep_around_axis(profile, axis="Z", sweep_angle=360)    # 회전 스윕
```

`sweep_around_axis` on a closed polyline profile is the canonical way to build a
toroidal/round coil.

## Object3d handle — what you reference downstream

```python
cyl.name            # 이름 (생성 시 자동/지정)
cyl.id              # 정수 ID
cyl.faces           # Face 객체 리스트
cyl.edges           # Edge 객체 리스트
cyl.vertices
cyl.top_face_z      # +Z 방향 끝면 (excitation 터미널로 자주 사용)
cyl.bottom_face_z
cyl.faces[0].id     # 면 ID — assign_current / assign_coil 에 전달
cyl.material_name = "copper"
cyl.color = (255, 0, 0)
cyl.transparency = 0.6
cyl.solve_inside = True     # 내부 필드 계산 여부
```

`m3d.modeler.convert_to_selections(obj, return_list=True)` normalizes a handle,
name, or list into the name/ID list the low-level boundary calls expect (PyAEDT
does this internally — you usually pass the handle or `.name` directly).

## Coordinate systems

```python
cs = mod.create_coordinate_system(origin=[0, 0, 10], name="cs_coil",
                                  reference_cs="Global",
                                  x_pointing=[1, 0, 0], y_pointing=[0, 1, 0])
# 이후 primitive 의 reference_cs 인자로 사용하거나 mod.set_working_coordinate_system(cs.name)
```

## Querying geometry

```python
mod.get_objects_in_group("Solids")
mod.object_names
mod.get_object_from_name("core")
mod.get_bodynames_from_position([0, 0, 0])
mod.get_faceid_from_position([0, 0, 5], assignment="core")
```
