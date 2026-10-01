class_name HayPile
extends Node3D
# Стог сена: сетка ячеек 1 м, у каждой — высота и количество соломинок.
# Визуал: MultiMesh с соломинками (гасим сверху при копании) + плотная «поверхность» стога.
# Физика: HeightMapShape3D, который перестраивается при копании.

const CX := 22
const CZ := 22
const H_MAX := 9.6
const STRANDS_PER_M := 2200.0    # счётных соломинок на 1 м высоты (стог ≈ 4-5 млн)
const MAX_PER_CELL := 260        # визуальных соломинок на ячейку
const VIS_DIV := 70.0          # сколько счётных приходится на одну визуальную

var heights := PackedFloat32Array()
var left_strands := PackedInt32Array()
var cells: Array[MultiMeshInstance3D] = []
var body: StaticBody3D
var hmap: HeightMapShape3D
var needles: Array = []           # {cell, pos, found, node}
var rng := RandomNumberGenerator.new()
var initial_total := 0

signal needle_revealed(idx: int)

func cell_index(cx: int, cz: int) -> int:
	return cz * CX + cx

func cell_of_pos(p: Vector3) -> int:
	var cx := int(floor(p.x - position.x + CX * 0.5))
	var cz := int(floor(p.z - position.z + CZ * 0.5))
	if cx < 0 or cz < 0 or cx >= CX or cz >= CZ: return -1
	return cell_index(cx, cz)

func cell_center(idx: int) -> Vector3:
	var cx := idx % CX
	var cz := idx / CX
	return position + Vector3(cx - CX * 0.5 + 0.5, 0, cz - CZ * 0.5 + 0.5)

func _init() -> void:
	rng.seed = 20261001

func build() -> void:
	heights.resize(CX * CZ)
	left_strands.resize(CX * CZ)
	var straw_tex := Tex.straw_texture()
	var strand_mat := Fab.mat_tex(straw_tex)
	strand_mat.vertex_color_use_as_albedo = true
	strand_mat.roughness = 0.95
	var surface_mat := Fab.mat_tex(straw_tex)
	surface_mat.uv1_scale = Vector3(3, 3, 3)
	surface_mat.albedo_color = Color(0.72, 0.55, 0.26)

	for cz in CZ:
		for cx in CX:
			var idx := cell_index(cx, cz)
			var wx := (cx - CX * 0.5 + 0.5)
			var wz := (cz - CZ * 0.5 + 0.5)
			var r := Vector2(wx, wz).length() / (CX * 0.5)
			var h := 0.0
			if r < 1.0:
				# мягкий купол: сглаженная косинусная форма
				var dome := cos(r * PI * 0.5)
				h = H_MAX * dome * (1.0 + 0.045 * sin(wx * 1.7) * cos(wz * 1.3))
				h = maxf(0.0, h + rng.randf_range(-0.18, 0.18))
			heights[idx] = h
			left_strands[idx] = int(h * STRANDS_PER_M)
			_make_cell_strands(cx, cz, idx, strand_mat)

	initial_total = strands_left_total()
	_make_surface(surface_mat)
	_make_scattered(strand_mat)
	_make_collision()
	_place_needles()

func _make_scattered(m: Material) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "scattered"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.008, 0.30)
	mm.mesh = bm
	var n := 2600
	mm.instance_count = n
	for i in n:
		var a := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * (CX * 0.5 + 3.6)
		var px := cos(a) * rad
		var pz := sin(a) * rad
		var t := Transform3D()
		t = t.rotated(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
		t.origin = Vector3(px, 0.015, pz)
		mm.set_instance_transform(i, t)
		var sh := rng.randf_range(0.8, 1.1)
		mm.set_instance_color(i, Color(sh * 0.80, sh * 0.62, sh * 0.30))
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _make_cell_strands(cx: int, cz: int, idx: int, m: Material) -> void:
	var count: int = int(min(float(left_strands[idx]) / VIS_DIV, float(MAX_PER_CELL)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "cell_%d_%d" % [cx, cz]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.030, 0.010, 0.46)
	mm.mesh = bm
	mm.instance_count = max(count, 1)
	var listed := []
	for i in max(count, 1):
		var px := (cx - CX * 0.5 + 0.5) + rng.randf_range(-0.62, 0.62)
		var pz := (cz - CZ * 0.5 + 0.5) + rng.randf_range(-0.62, 0.62)
		var u := rng.randf()
		var py: float = maxf(heights[idx], 0.05) * (0.25 + 0.75 * sqrt(u))   # гуще у поверхности
		var yaw := rng.randf() * TAU
		var pitch := rng.randf_range(-0.5, 0.5)
		listed.append([py, px, pz, yaw, pitch])
	listed.sort_custom(func(a, b): return a[0] < b[0])   # снизу вверх: гасим сверху
	for i in listed.size():
		var e: Array = listed[i]
		var t := Transform3D()
		t = t.rotated(Vector3.UP, e[3]).rotated(Vector3.RIGHT, e[4])
		t.origin = Vector3(e[1], max(e[0], 0.02), e[2])
		mm.set_instance_transform(i, t)
		var shade := rng.randf_range(0.62, 0.92)
		mm.set_instance_color(i, Color(shade, shade * rng.randf_range(0.70, 0.84), shade * rng.randf_range(0.34, 0.50)))
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = count > 0
	add_child(mmi)
	if cells.size() <= idx: cells.resize(idx + 1)
	cells[idx] = mmi

func _make_surface(m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0
	for cz in CZ:
		for cx in CX:
			var x0 := (cx - CX * 0.5) * step
			var z0 := (cz - CZ * 0.5) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var h00 := heights[cell_index(cx, cz)]
			var h10 := heights[cell_index(min(cx + 1, CX - 1), cz)]
			var h01 := heights[cell_index(cx, min(cz + 1, CZ - 1))]
			var h11 := heights[cell_index(min(cx + 1, CX - 1), min(cz + 1, CZ - 1))]
			_quad(st, x0, z0, x1, z1, h00, h10, h01, h11)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "pile_surface"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = Vector3(0, -0.30, 0)   # чуть ниже соломинок
	add_child(mi)

func _quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float,
		h00: float, h10: float, h01: float, h11: float) -> void:
	st.set_uv(Vector2(x0, z0) * 0.25); st.add_vertex(Vector3(x0, h00, z0))
	st.set_uv(Vector2(x1, z0) * 0.25); st.add_vertex(Vector3(x1, h10, z0))
	st.set_uv(Vector2(x1, z1) * 0.25); st.add_vertex(Vector3(x1, h11, z1))
	st.set_uv(Vector2(x0, z0) * 0.25); st.add_vertex(Vector3(x0, h00, z0))
	st.set_uv(Vector2(x1, z1) * 0.25); st.add_vertex(Vector3(x1, h11, z1))
	st.set_uv(Vector2(x0, z1) * 0.25); st.add_vertex(Vector3(x0, h01, z1))

func _make_collision() -> void:
	body = StaticBody3D.new()
	body.name = "pile_body"
	body.collision_layer = 2
	body.collision_mask = 0
	hmap = HeightMapShape3D.new()
	hmap.map_width = CX
	hmap.map_depth = CZ
	hmap.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = hmap
	body.add_child(cs)
	add_child(body)

func _place_needles() -> void:
	var chosen := []
	while chosen.size() < Game.NEEDLES_TOTAL:
		var cx := rng.randi_range(3, CX - 4)
		var cz := rng.randi_range(3, CZ - 4)
		var idx := cell_index(cx, cz)
		if heights[idx] > 3.0 and not chosen.has(idx):
			chosen.append(idx)
	for idx_v in chosen:
		var idx: int = idx_v
		var cx: int = idx % CX
		var cz: int = idx / CX
		var pos := Vector3(cx - CX * 0.5 + 0.5 + rng.randf_range(-0.3, 0.3), 0.0,
			cz - CZ * 0.5 + 0.5 + rng.randf_range(-0.3, 0.3))
		needles.append({"cell": idx, "pos": pos, "found": false, "node": null})

func top_height_of_cell(idx: int) -> float:
	return heights[idx]

# ------------------------------------------------------------------ копание
func dig(idx: int, amount: int) -> int:
	if idx < 0 or idx >= left_strands.size(): return 0
	var have := left_strands[idx]
	if have <= 0: return 0
	var take: int = min(amount, have)
	left_strands[idx] = have - take
	var mmi := cells[idx]
	var vis: int = int(min(float(left_strands[idx]) / VIS_DIV, float(MAX_PER_CELL)))
	if mmi and mmi.multimesh:
		mmi.multimesh.visible_instance_count = max(vis, 0)
		mmi.visible = vis > 0
	var new_h: float = float(left_strands[idx]) / STRANDS_PER_M
	heights[idx] = new_h
	hmap.map_data = heights
	# открылась ли иголка?
	for i in needles.size():
		var n: Dictionary = needles[i]
		if n.cell == idx and not n.found and n.node == null and left_strands[idx] <= 600:
			_reveal_needle(i)
	_update_surface()
	return take

var _surface: MeshInstance3D

func _update_surface() -> void:
	if _surface == null:
		for c in get_children():
			if c is MeshInstance3D and c.name == "pile_surface": _surface = c
	if _surface == null: return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cz in CZ:
		for cx in CX:
			var x0 := float(cx - CX * 0.5); var z0 := float(cz - CZ * 0.5)
			var x1 := x0 + 1.0; var z1 := z0 + 1.0
			var h00 := heights[cell_index(cx, cz)]
			var h10 := heights[cell_index(min(cx + 1, CX - 1), cz)]
			var h01 := heights[cell_index(cx, min(cz + 1, CZ - 1))]
			var h11 := heights[cell_index(min(cx + 1, CX - 1), min(cz + 1, CZ - 1))]
			_quad(st, x0, z0, x1, z1, h00, h10, h01, h11)
	st.generate_normals()
	_surface.mesh = st.commit()

func _reveal_needle(i: int) -> void:
	var n: Dictionary = needles[i]
	var holder := Node3D.new()
	var m := Fab.mat(Color(0.85, 0.88, 0.95), 0.25, 0.9)
	Fab.cyl(holder, "needle_body", Vector3.ZERO, 0.012, 0.42, m, Vector3(0, 0, deg_to_rad(65)), 8)
	var eye := TorusMesh.new()
	eye.inner_radius = 0.012; eye.outer_radius = 0.028
	var eye_mi := MeshInstance3D.new(); eye_mi.mesh = eye; eye_mi.material_override = m
	eye_mi.position = Vector3(0.11, 0.19, 0); eye_mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	holder.add_child(eye_mi)
	var h_top: float = maxf(float(heights[int(n.cell)]), 0.4)
	holder.position = n.pos + Vector3(0, h_top + 0.05, 0)
	holder.name = "needle_%d" % i
	var area := Fab.area_box(holder, "pick", Vector3.ZERO, Vector3(0.7, 0.7, 0.7))
	area.set_meta("interact_name", "Взять иголку")
	area.set_meta("needle_idx", i)
	add_child(holder)
	n.node = holder
	needles[i] = n
	needle_revealed.emit(i)

func needle_node(i: int) -> Node3D:
	return needles[i].node

func take_needle(i: int) -> void:
	var n: Dictionary = needles[i]
	n.found = true
	needles[i] = n
	if n.node: n.node.queue_free()
	Game.needles_found += 1
	Game.add_money(25.0)
	Game.save_game()

func nearest_needle(from: Vector3) -> Dictionary:
	var best := {"dist": 1e9, "found": true, "pos": Vector3.ZERO}
	for n in needles:
		if n.found: continue
		var p: Vector3 = position + n.pos + Vector3(0, maxf(float(heights[int(n.cell)]), 0.0), 0)
		var d := from.distance_to(p)
		if d < best.dist:
			best = {"dist": d, "found": false, "pos": p}
	return best

func dug_percent() -> float:
	if initial_total <= 0: return 0.0
	return clampf(1.0 - float(strands_left_total()) / float(initial_total), 0.0, 1.0)

func strands_left_total() -> int:
	var s := 0
	for v in left_strands: s += v
	return s
