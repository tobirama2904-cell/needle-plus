class_name Fab
extends RefCounted
# Хелперы: быстро создаём геометрию, материалы, текстуры, коллайдеры.

static func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m

static func mat_tex(tex: Texture2D, color := Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.roughness = 0.9
	m.uv1_scale = Vector3(1, 1, 1)
	return m

static func box(parent: Node, name: String, pos: Vector3, size: Vector3, m: Material,
		rot := Vector3.ZERO, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi

static func cyl(parent: Node, name: String, pos: Vector3, radius: float, height: float,
		m: Material, rot := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func area_box(parent: Node, name: String, pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = name
	a.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh
	a.add_child(cs)
	parent.add_child(a)
	return a

static func label3d(parent: Node, text: String, pos: Vector3, size := 0.5,
		color := Color(1, 1, 1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = 0.0012 * size
	l.font_size = 128
	l.outline_size = 18
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	return l
