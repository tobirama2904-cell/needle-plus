class_name Player
extends CharacterBody3D
# Игрок: вид от первого лица, мобильное управление, копание, выносливость, инструменты.

var pile: Node3D
var cam: Camera3D
var held_root: Node3D          # руки с инструментом и сеном
var tool_nodes := {}           # имя инструмента -> Node3D
var detector_visual: Node3D
var detector_on := false
var yaw := 0.0
var pitch := 0.0
var stamina := 100.0
var tired_until := 0.0
var last_dig := 0.0
var bob := 0.0
var swing := 0.0
var swing_dir := 1.0
var carry_lift := 0.0
var carried_visual: Node3D
var move_input := Vector2.ZERO      # от виртуального стика
var look_input := Vector2.ZERO      # от тача/мыши за кадр
var sprint_touch := false
var want_jump := false
var want_use := false
var want_interact := false
var target: Node = null             # интерактивный объект под прицелом
var sfx_t := 0.0
var placing: String = ""            # режим установки машины
var ghost: Node3D = null
var lamp: SpotLight3D

signal prompt_changed(text: String)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

	var head := Node3D.new(); head.name = "Head"; head.position = Vector3(0, 1.62, 0)
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Game.settings.fov
	cam.near = 0.05
	head.add_child(cam)
	lamp = SpotLight3D.new()
	lamp.light_energy = 0.0
	lamp.spot_range = 18.0
	lamp.spot_angle = 34.0
	cam.add_child(lamp)

	held_root = Node3D.new()
	held_root.name = "Held"
	cam.add_child(held_root)
	_build_tools()
	_build_carried_visual()
	set_tool(Game.tool)
	stamina = Game.stam_max()

func _build_tools() -> void:
	var metal := Fab.mat(Color(0.62, 0.65, 0.70), 0.45, 0.75)
	var wood := Fab.mat(Color(0.45, 0.33, 0.20), 0.9)
	var steel := Fab.mat(Color(0.75, 0.78, 0.82), 0.3, 0.9)
	var dark := Fab.mat(Color(0.16, 0.17, 0.19), 0.6)

	# руки: рукава с плеча вниз + кисти
	var hands := Node3D.new(); hands.name = "hands"
	var sleeve := Fab.mat(Color(0.30, 0.34, 0.42), 0.85)
	var skin := Fab.mat(Color(0.87, 0.69, 0.55), 0.75)
	for sx in [-1.0, 1.0]:
		var up := Node3D.new()
		up.position = Vector3(sx * 0.22, -0.62, -0.52)
		up.rotation = Vector3(deg_to_rad(72), sx * deg_to_rad(12), 0)
		up.scale = Vector3(0.55, 0.55, 0.55)
		hands.add_child(up)
		Fab.box(up, "sleeve", Vector3(0, 0, -0.16), Vector3(0.115, 0.115, 0.34), sleeve)
		Fab.box(up, "forearm", Vector3(0, 0, -0.40), Vector3(0.085, 0.085, 0.22), skin)
		Fab.box(up, "palm", Vector3(0, -0.01, -0.54), Vector3(0.10, 0.055, 0.14), skin)
	held_root.add_child(hands); tool_nodes["hands"] = hands

	# лопата
	var sh := Node3D.new(); sh.name = "shovel"
	Fab.cyl(sh, "handle", Vector3(0.16, -0.30, -0.55), 0.018, 0.95, wood, Vector3(deg_to_rad(78), 0, deg_to_rad(-8)), 10)
	Fab.box(sh, "blade", Vector3(0.30, -0.62, -0.86), Vector3(0.20, 0.24, 0.02), steel, Vector3(deg_to_rad(78), 0, deg_to_rad(-8)))
	Fab.box(sh, "arm", Vector3(0.20, -0.30, -0.35), Vector3(0.08, 0.08, 0.32), Fab.mat(Color(0.86, 0.68, 0.55), 0.8))
	held_root.add_child(sh); tool_nodes["shovel"] = sh

	# вилы
	var pf := Node3D.new(); pf.name = "pitchfork"
	Fab.cyl(pf, "handle", Vector3(0.15, -0.28, -0.55), 0.016, 1.0, wood, Vector3(deg_to_rad(76), 0, deg_to_rad(-6)), 10)
	for i in 4:
		Fab.cyl(pf, "tine%d" % i, Vector3(0.15 + (i - 1.5) * 0.045, -0.66, -1.02), 0.008, 0.30, metal, Vector3(deg_to_rad(76), 0, 0), 8)
	held_root.add_child(pf); tool_nodes["pitchfork"] = pf

	# грабли
	var rk := Node3D.new(); rk.name = "rake"
	Fab.cyl(rk, "handle", Vector3(0.15, -0.3, -0.55), 0.016, 1.0, wood, Vector3(deg_to_rad(74), 0, 0), 10)
	Fab.box(rk, "head", Vector3(0.15, -0.68, -0.95), Vector3(0.42, 0.03, 0.06), metal, Vector3(deg_to_rad(74), 0, 0))
	for i in 7:
		Fab.box(rk, "tooth%d" % i, Vector3(0.15 + (i - 3) * 0.06, -0.70, -0.97), Vector3(0.012, 0.07, 0.012), metal, Vector3(deg_to_rad(74), 0, 0))
	held_root.add_child(rk); tool_nodes["rake"] = rk

	# ведро
	var bk := Node3D.new(); bk.name = "bucket"
	var bm := CylinderMesh.new(); bm.top_radius = 0.17; bm.bottom_radius = 0.13; bm.height = 0.30
	var bmi := MeshInstance3D.new(); bmi.mesh = bm; bmi.material_override = Fab.mat(Color(0.35, 0.55, 0.62), 0.5, 0.4)
	bmi.position = Vector3(0.2, -0.5, -0.6); bmi.rotation = Vector3(deg_to_rad(20), 0, 0)
	bk.add_child(bmi)
	Fab.box(bk, "arc", Vector3(0.2, -0.34, -0.6), Vector3(0.3, 0.02, 0.02), dark)
	held_root.add_child(bk); tool_nodes["bucket"] = bk

	# пылесос
	var vc := Node3D.new(); vc.name = "vacuum"
	Fab.box(vc, "body", Vector3(0.22, -0.42, -0.5), Vector3(0.18, 0.18, 0.34), Fab.mat(Color(0.8, 0.25, 0.2), 0.6))
	Fab.cyl(vc, "pipe", Vector3(0.14, -0.5, -0.75), 0.03, 0.5, dark, Vector3(deg_to_rad(68), 0, 0), 10)
	held_root.add_child(vc); tool_nodes["vacuum"] = vc

	# металлоискатель
	var dt := Node3D.new(); dt.name = "detector"
	Fab.cyl(dt, "rod", Vector3(0.18, -0.34, -0.6), 0.015, 0.9, dark, Vector3(deg_to_rad(80), 0, 0), 10)
	Fab.cyl(dt, "head", Vector3(0.26, -0.72, -0.92), 0.13, 0.03, Fab.mat(Color(0.2, 0.2, 0.22), 0.5), Vector3(deg_to_rad(80), 0, 0), 18)
	var lamp2 := OmniLight3D.new()
	lamp2.light_energy = 0.6; lamp2.omni_range = 2.0; lamp2.light_color = Color(0.3, 1.0, 0.4)
	lamp2.position = Vector3(0.26, -0.72, -0.92)
	dt.add_child(lamp2)
	held_root.add_child(dt); tool_nodes["detector"] = dt
	detector_visual = dt

	# сфера сигнала детектора
	var sph := SphereMesh.new(); sph.radius = 0.45; sph.height = 0.9
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 1.0, 0.45, 0.16)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.2, 0.9, 0.4)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var smi := MeshInstance3D.new(); smi.mesh = sph; smi.material_override = sm
	detector_visual.add_child(smi)

func _build_carried_visual() -> void:
	carried_visual = Node3D.new()
	carried_visual.name = "carried"
	held_root.add_child(carried_visual)
	_rebuild_carried()

func _rebuild_carried() -> void:
	for c in carried_visual.get_children(): c.queue_free()
	var n: int = clamp(Game.carried / 12, 0, 12)
	var mat := Fab.mat_tex(Tex.straw_texture())
	mat.uv1_scale = Vector3(3, 3, 3)
	mat.albedo_color = Color(1.0, 0.86, 0.55)
	for i in n:
		var b := BoxMesh.new()
		b.size = Vector3(0.34, 0.16, 0.22)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = mat
		mi.position = Vector3(0.05 + randf_range(-0.05, 0.05), -0.42 + i * 0.055, -0.62 + randf_range(-0.04, 0.04))
		mi.rotation = Vector3(deg_to_rad(randf_range(-12, 12)), deg_to_rad(randf_range(-25, 25)), deg_to_rad(randf_range(-12, 12)))
		carried_visual.add_child(mi)

func set_tool(t: String) -> void:
	Game.tool = t
	for k in tool_nodes:
		tool_nodes[k].visible = (k == t)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input += event.relative
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		velocity = Vector3.ZERO
		return
	# --- обзор
	var sens: float = 0.0022 * float(Game.settings.sens)
	yaw -= look_input.x * sens
	pitch = clamp(pitch - look_input.y * sens, deg_to_rad(-82), deg_to_rad(82))
	look_input = Vector2.ZERO
	rotation.y = yaw
	head_look()
	# --- движение
	var mv := move_input
	if InputMap.has_action("move_f"):
		mv += Vector2(
			(1.0 if Input.is_action_pressed("move_r") else 0.0) - (1.0 if Input.is_action_pressed("move_l") else 0.0),
			(1.0 if Input.is_action_pressed("move_b") else 0.0) - (1.0 if Input.is_action_pressed("move_f") else 0.0))
	mv = mv.limit_length(1.0)
	var sprinting := (Input.is_action_pressed("run") or sprint_touch or mv.length() > 0.92) and stamina > 5.0
	var spd: float = Game.run_speed() if sprinting else Game.walk_speed()
	if stamina < 10.0: spd *= 0.75
	var dir := (transform.basis * Vector3(mv.x, 0, mv.y)).normalized()
	velocity.x = dir.x * spd * mv.length()
	velocity.z = dir.z * spd * mv.length()
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = 0.0
	if (Input.is_action_just_pressed("jump") or want_jump) and is_on_floor() and stamina > 8.0:
		velocity.y = Game.jump_vel()
		stamina -= 4.0
		Sfx.play("whoosh", -10)
	want_jump = false
	move_and_slide()
	# --- шаги и покачивание
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.5 and is_on_floor():
		bob += delta * flat * 2.4
		sfx_t -= delta
		if sfx_t <= 0:
			Sfx.play3d("step", global_position, -16, randf_range(0.92, 1.08))
			sfx_t = 0.42 if not sprinting else 0.30
	else:
		bob = lerp(bob, 0.0, delta * 6.0)
	# --- выносливость
	var acting := want_use
	if acting:
		stamina -= Game.tool_data().stamina * 0.55 * delta / max(Game.tool_cd(), 0.05)
	stamina = max(0.0, min(Game.stam_max(), stamina))
	if not acting:
		stamina = min(Game.stam_max(), stamina + Game.stam_regen() * delta)
	# --- копание
	_do_dig()
	# --- интеракции
	want_interact = want_interact or Input.is_action_just_pressed("interact")
	if want_interact:
		want_interact = false
		_interact()
	_update_target()
	# --- детектор
	if Input.is_action_just_pressed("detector"):
		toggle_detector()
	if det_toggle_queued:
		det_toggle_queued = false
		toggle_detector()
	_update_detector(delta)
	# --- магнит (авто-сбор с лент рядом)
	pass

func head_look() -> void:
	var head: Node3D = get_node_or_null("Head")
	if head: head.rotation.x = pitch

var det_toggle_queued := false

func toggle_detector() -> void:
	if not Game.unlocked_tools.get("detector", false):
		Game.toast.emit("Сначала купи металлоискатель в магазине")
		return
	detector_on = not detector_on
	set_tool("detector" if detector_on else Game.tool)
	Sfx.play("ui", -14)

func _update_detector(delta: float) -> void:
	detector_visual.visible = detector_on
	if not detector_on: return
	var nfo: Dictionary = pile.nearest_needle(global_position)
	var d: float = nfo.dist
	var r := Game.det_radius()
	var s := 0.0
	if d < r:
		s = 1.0 - d / r
	var mesh: MeshInstance3D = detector_visual.get_child(3)
	var m: StandardMaterial3D = mesh.material_override
	var col := Color(0.25, 1.0, 0.45).lerp(Color(1.0, 0.25, 0.2), clamp(s * 1.6, 0.0, 1.0))
	m.albedo_color = Color(col.r, col.g, col.b, 0.10 + 0.25 * s)
	m.emission = col
	detector_beep(s, delta)

var beep_t := 0.0
func detector_beep(s: float, delta: float) -> void:
	if s <= 0.02: return
	beep_t -= delta
	if beep_t <= 0.0:
		Sfx.play("beep", -22 + 10 * s, 0.9 + 0.5 * s)
		beep_t = lerp(1.15, 0.07, clamp(s, 0.0, 1.0))

func _do_dig() -> void:
	want_use = want_use or Input.is_action_pressed("use_mouse")
	var holding := want_use
	if not holding or Game.tool_data().scoop <= 0:
		return
	if Time.get_ticks_msec() / 1000.0 - last_dig < Game.tool_cd():
		return
	if stamina <= 1.0:
		if Time.get_ticks_msec() - last_toast > 2500:
			last_toast = Time.get_ticks_msec()
			Game.toast.emit("Кончились силы — отдышись")
		return
	var from := cam.global_position
	var reach: float = Game.tool_data().reach
	var to := from + (-cam.global_transform.basis.z) * reach
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 4 | 1
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var idx: int = pile.cell_of_pos(hit.position)
	if idx < 0:
		return
	var amount: int = int(Game.tool_data().scoop) + Game.scoop_extra()
	if Game.carried >= Game.cap():
		if Time.get_ticks_msec() - last_toast > 2000:
			last_toast = Time.get_ticks_msec()
			Game.toast.emit("Руки полны — продай сено у стойки SELL HAY")
		return
	var got: int = pile.dig(idx, amount)
	if got > 0:
		var put := Game.add_carried(got)
		_rebuild_carried()
		swing = 1.0                      # взмах инструментом
		carry_lift = 0.14
		stamina = max(0.0, stamina - Game.tool_data().stamina)
		last_dig = Time.get_ticks_msec() / 1000.0
		Sfx.play3d("dig", hit.position, -8, randf_range(0.94, 1.06))
		Sfx.play3d("rustle", hit.position, -12, randf_range(0.9, 1.1))
		_burst(hit.position)
		if put < got:
			Game.toast.emit("Часть сена не влезла — апгрейдни перенос")

var last_toast := 0
var _dust: GPUParticles3D = null

func _burst(pos: Vector3) -> void:
	if _dust == null:
		_dust = GPUParticles3D.new()
		_dust.amount = 24
		_dust.lifetime = 0.9
		_dust.one_shot = true
		_dust.explosiveness = 0.9
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 55.0
		pm.initial_velocity_min = 1.2
		pm.initial_velocity_max = 3.0
		pm.gravity = Vector3(0, -6, 0)
		pm.scale_min = 0.3; pm.scale_max = 0.9
		var quad := QuadMesh.new(); quad.size = Vector2(0.06, 0.06)
		var qm := StandardMaterial3D.new()
		qm.albedo_texture = Tex.straw_texture()
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = qm
		_dust.draw_pass_1 = quad
		_dust.process_material = pm
		add_child(_dust)
	_dust.global_position = pos
	_dust.restart()
	_dust.emitting = true

func _update_target() -> void:
	var from := cam.global_position
	var to := from + (-cam.global_transform.basis.z) * 3.4
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collision_mask = 8 | 16        # интерактивные зоны и машины
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var t: Node = null
	if not hit.is_empty():
		var c = hit.collider
		if c and c.has_meta("interact_name"):
			t = c
	if t != target:
		target = t
		if t:
			prompt_changed.emit(str(t.get_meta("interact_name")))
		else:
			prompt_changed.emit("")

func _interact() -> void:
	if placing != "":
		_place_machine()
		return
	if target == null: return
	var n = target.get_parent()
	if target.has_meta("needle_idx"):
		pile.take_needle(int(target.get_meta("needle_idx")))
		Sfx.play("win", -6)
		Game.toast.emit("Иголка найдена! (%d/%d)" % [Game.needles_found, Game.NEEDLES_TOTAL])
		Game.save_game()
		return
	if n and n.has_method("interact"):
		n.interact(self)

# ------------------------------------------------------------- установка машин
func start_placing(machine: String) -> void:
	placing = machine
	if ghost: ghost.queue_free()
	ghost = Machines.make_ghost(machine)
	add_child(ghost)

func _place_machine() -> void:
	if ghost == null: return
	var pos := ghost.global_position
	if Machines.try_place(get_parent(), placing, pos, yaw, self):
		Sfx.play("ratchet", -8)
		placing = ""
		ghost.queue_free()
		ghost = null
	else:
		Game.toast.emit("Здесь нельзя поставить")

func _process(d: float) -> void:
	# анимация: взмах, покачивание при ходьбе, дёрганье инструмента при беге
	if held_root:
		if swing > 0.0:
			swing = maxf(0.0, swing - d * 4.2)
			var k: float = sin((1.0 - swing) * PI)
			held_root.rotation.x = -k * 0.75
			held_root.position.y = -k * 0.12
		else:
			held_root.rotation.x = lerp(held_root.rotation.x, 0.0, d * 8.0)
			var bobf: float = sin(bob * 2.0) * 0.012 * clampf(Vector2(velocity.x, velocity.z).length() / 4.0, 0.0, 1.5)
			held_root.position.y = bobf + carry_lift
			held_root.position.x = cos(bob) * 0.010
		carry_lift = lerp(carry_lift, 0.0, d * 5.0)
	if ghost and ghost.visible:
		var from := cam.global_position
		var to := from + (-cam.global_transform.basis.z) * 6.0
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1 | 2
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			ghost.global_position = hit.position
			ghost.rotation.y = yaw
