"""End-to-end PyAEDT 예제: 솔레노이드 코일 + 철심 Magnetostatic 해석.

워크플로 전 단계를 한 번에 보여준다:
  01 연결 → 02 형상 → 03 재료 → 04 여자 → 05 경계 → 06 메시/셋업/해석
  → 07 후처리(필드플롯+인덕턴스) → 08 에어갭 파라메트릭 스윕.

실행 전제: ANSYS Electronics Desktop(AEDT) 2025.1 설치, pyaedt 설치.
    pip install pyaedt
"""

from ansys.aedt.core import Maxwell3d

# ----------------------------------------------------------------------
# 01. 연결 — Magnetostatic 솔버로 새 디자인 생성
# ----------------------------------------------------------------------
m3d = Maxwell3d(
    project="solenoid_study",
    design="mag_3d",
    solution_type="Magnetostatic",
    version="2025.1",
    non_graphical=False,
    new_desktop=True,
)
m3d.modeler.model_units = "mm"

# 설계 변수 (파라메트릭/최적화 대비 — 문자열로 참조)
m3d["core_radius"] = "5mm"
m3d["core_height"] = "40mm"
m3d["coil_turns"] = 200
m3d["coil_current"] = "1A"
m3d["air_gap"] = "2mm"

mod = m3d.modeler

try:
    # ------------------------------------------------------------------
    # 02. 형상 — 철심(코어) + 코일(회전 스윕) + 공기 영역
    # ------------------------------------------------------------------
    # 철심: Z축 원기둥
    core = mod.create_cylinder(
        orientation="Z", origin=[0, 0, 0],
        radius="core_radius", height="core_height",
        name="core", material="steel_1008",
    )

    # 코일 단면(사각형)을 Z축 둘레로 회전 스윕 → 토로이달 코일 솔리드
    coil_profile = mod.create_rectangle(
        orientation="XZ",
        origin=["core_radius + air_gap", 0, "5mm"],
        sizes=["3mm", "30mm"],          # [너비(r방향), 높이(z방향)]
        name="coil_profile",
    )
    coil = mod.sweep_around_axis(coil_profile, axis="Z", sweep_angle=360)
    coil.name = "coil"
    coil.material_name = "copper"

    # 공기 해석 영역
    region = mod.create_region(pad_percent=300)

    # ------------------------------------------------------------------
    # 03. 재료 — 비선형 B-H 철심 (옵션)
    # ------------------------------------------------------------------
    # 라이브러리 재료를 이미 할당했음(steel_1008, copper).
    # 커스텀 비선형이 필요하면:
    # bh = m3d.materials.add_material("bh_core")
    # bh.permeability.value = [[0, 0], [200, 1.0], [1000, 1.8], [10000, 2.0]]
    # bh.update(); m3d.assign_material("core", "bh_core")

    # ------------------------------------------------------------------
    # 04. 여자 — 코일에 전류 권선
    # ------------------------------------------------------------------
    # 코일 단면(스윕 시작 단면)에 coil terminal 생성
    coil_face = coil.faces[0].id
    winding = m3d.assign_winding(
        winding_type="Current",
        is_solid=False,            # stranded
        current="coil_current",
        parallel_branches=1,
        name="W1",
    )
    coil_term = m3d.assign_coil(
        assignment=coil_face,
        conductors_number="coil_turns",
        polarity="Positive",
        name="coil_term",
    )
    m3d.add_winding_coils(assignment=winding.name, coils=[coil_term.name])

    # 인덕턴스 행렬 계산 등록
    m3d.assign_matrix(assignment=[winding.name], matrix_name="Matrix1")

    # ------------------------------------------------------------------
    # 05. 경계 — 코일 절연 (3D Magnetostatic 은 영역 자연경계로 충분)
    # ------------------------------------------------------------------
    m3d.assign_insulating(assignment="coil", insulation="coil_ins")

    # ------------------------------------------------------------------
    # 06. 메시 + 셋업 + 해석
    # ------------------------------------------------------------------
    m3d.mesh.assign_length_mesh(
        assignment=["core", "coil"], maximum_length="2mm", name="len_main",
    )

    setup = m3d.create_setup(name="MySetup")
    setup.props["MaximumPasses"] = 10
    setup.props["PercentError"] = 1
    setup.props["NonlinearResidual"] = 1e-4
    setup.update()

    assert m3d.validate_simple(), "디자인 검증 실패"
    m3d.analyze(setup="MySetup", cores=4)

    # ------------------------------------------------------------------
    # 07. 후처리 — 인덕턴스 값 + B 필드 플롯
    # ------------------------------------------------------------------
    sol = m3d.post.get_solution_data(
        expressions="Matrix1.L(W1,W1)",
        setup_sweep_name="MySetup : LastAdaptive",
    )
    print("Self inductance L(W1,W1) =", sol.data_magnitude())

    # 코어 단면 B 필드 플롯 → 이미지 저장
    m3d.post.create_fieldplot_cutplane(
        assignment="Global:XZ", quantity="Mag_B", plot_name="B_cut",
    )
    m3d.post.plot_field(
        quantity="Mag_B", assignment=["core"], plot_type="Surface",
        show=False, export_path=m3d.working_directory + "/B_core.jpg",
    )

    # ------------------------------------------------------------------
    # 08. 파라메트릭 — 에어갭 vs 인덕턴스
    # ------------------------------------------------------------------
    sweep = m3d.parametrics.add(
        variable="air_gap",
        start_point="0.5mm",
        end_point="3mm",
        step="0.5mm",
        variation_type="LinearStep",
        name="gap_sweep",
    )
    sweep.add_calculation(
        calculation="Matrix1.L(W1,W1)", report_category="Fields", ranges={},
    )
    sweep.analyze()

    L_vs_gap = m3d.post.get_solution_data(
        expressions="Matrix1.L(W1,W1)",
        setup_sweep_name="MySetup : LastAdaptive",
        variations={"air_gap": ["All"]},
        primary_sweep_variable="air_gap",
    )
    L_vs_gap.export_data_to_csv(m3d.working_directory + "/L_vs_gap.csv")
    print("에어갭 스윕 결과 저장 완료")

finally:
    # ------------------------------------------------------------------
    # 정리 — 항상 저장 후 분리 (락 방지)
    # ------------------------------------------------------------------
    m3d.save_project()
    m3d.release_desktop(close_projects=False, close_desktop=False)
