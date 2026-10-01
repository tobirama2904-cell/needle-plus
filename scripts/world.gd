class_name World
extends Node3D
# Мир: ангар, свет, пыль, стог, игрок, HUD, меню, магазин. Плюс режим скриншотов для проверки в песочнице.

var pile: Node3D
var player: Node3D
var hud: CanvasLayer
var menu: CanvasLayer
var shots_dir := ""
var shot_i := 0
var shot_t := 0.0
var shot_mode := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var money_cheat := 0.0
	var test_mode := false
	for i in args.size():
		if args[i] == "--shots" and i + 1 < args.size():
			shots_dir = args[i + 1]
			shot_mode = true
		if args[i] == "--test":
			test_mode = true
		if args[i] == "--money" and i + 1 < args.size():
			money_cheat = float(args[i + 1])
	if money_cheat > 0:
		Game.money = money_cheat
	Sfx.init(self)
	_build_environment()
	_build_warehouse()
	_build_floor()
	_build_dust()
	pile = HayPile.new()
	pile.name = "HayPile"
	pile.position = Vector3(0, 0, -3)
	add_child(pile)
	pile.build()
	Machines.pile_ref = pile
	_spawn_player()
	_build_store()
	_build_signs()
	_build_ui()
	Sfx.loop_play("wind", -26)
	if test_mode:
		var t: Node = load("res://scripts/selftest.gd").new()
		add_child(t)
	elif shot_mode:
		await get_tree().create_timer(2.0).timeout
		_run_shots()

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = Color(0.50, 0.62, 0.80)
	skm.sky_horizon_color = Color(0.75, 0.82, 0.9)
	skm.ground_bottom_color = Color(0.35, 0.3, 0.25)
	skm.ground_horizon_color = Color(0.6, 0.55, 0.45)
	skm.sky_energy_multiplier = 1.1
	sky.sky_material = skm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.56, 0.46)
	env.ambient_light_energy = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.6
	env.tonemap_exposure = 0.85
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.8, 0.68)
	env.fog_density = 0.0035
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(1.0, 0.93, 0.78)
	var wenv := WorldEnvironment.new()
	wenv.environment = env
	add_child(wenv)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 34, 0)
	sun.light_energy = 2.0
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.light_angular_distance = 0.6
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-18, -150, 0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.95, 0.86, 0.72)
	fill.shadow_enabled = false
	add_child(fill)

func _build_warehouse() -> void:
	var wall := Fab.mat_tex(Tex.planks())
	wall.uv1_scale = Vector3(6, 4, 6)
	var steel := Fab.mat(Color(0.32, 0.34, 0.38), 0.5, 0.7)
	var W := 46.0
	var H := 13.0
	# пол/стены/потолок
	Fab.box(self, "wall_n", Vector3(0, H / 2, -W / 2), Vector3(W, H, 0.4), wall, Vector3.ZERO, true)
	Fab.box(self, "wall_s", Vector3(0, H / 2, W / 2), Vector3(W, H, 0.4), wall, Vector3.ZERO, true)
	Fab.box(self, "wall_e", Vector3(W / 2, H / 2, 0), Vector3(0.4, H, W), wall, Vector3.ZERO, true)
	Fab.box(self, "wall_w", Vector3(-W / 2, H / 2, 0), Vector3(0.4, H, W), wall, Vector3.ZERO, true)
	# крыша с щелями под солнце
	var z := -W / 2
	var slat := 2.0
	var gap := 1.0
	while z < W / 2:
		Fab.box(self, "roof", Vector3(0, H, z + slat / 2), Vector3(W, 0.25, slat), steel)
		z += slat + gap
	# балки
	for x in [-14.0, 0.0, 14.0]:
		Fab.box(self, "beam", Vector3(x, H - 0.5, 0), Vector3(0.5, 0.7, W), steel)
	# столбы
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Fab.box(self, "post", Vector3(sx * (W / 2 - 1.4), H / 2, sz * (W / 2 - 1.4)), Vector3(0.6, H, 0.6), steel, Vector3.ZERO, true)
	# фальш-лучи света под щелями (для мобильной графики, где нет объёмного тумана)
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.05)
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var zz := -W / 2 + 1.0
	while zz < W / 2:
		var q := QuadMesh.new()
		q.size = Vector2(2.6, 13.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = shaft_mat
		mi.position = Vector3(0, H / 2 - 0.4, zz)
		mi.rotation = Vector3(deg_to_rad(-38), 0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		zz += 4.4

func _build_floor() -> void:
	var floor_mat := Fab.mat_tex(Tex.concrete())
	floor_mat.uv1_scale = Vector3(10, 10, 10)
	Fab.box(self, "floor", Vector3(0, -0.1, 0), Vector3(46, 0.2, 46), floor_mat, Vector3.ZERO, true)
	# разметка зон
	Fab.box(self, "zone1", Vector3(-14, 0.005, 8), Vector3(9, 0.01, 6), Fab.mat(Color(0.35, 0.3, 0.22), 0.95))
	Fab.box(self, "zone2", Vector3(12, 0.005, 10), Vector3(10, 0.01, 7), Fab.mat(Color(0.3, 0.28, 0.24), 0.95))

func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 260
	dust.lifetime = 14.0
	dust.preprocess = 6.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 5, 20)
	pm.direction = Vector3(1, -0.15, 0.3)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, -0.06, 0)
	pm.scale_min = 0.4; pm.scale_max = 1.4
	pm.color = Color(1, 0.96, 0.85, 0.5)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1, 0.95, 0.85, 0.5)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = qm
	dust.draw_pass_1 = quad
	dust.process_material = pm
	dust.position = Vector3(0, 5, 0)
	add_child(dust)

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.pile = pile
	add_child(player)
	player.global_position = Vector3(4, 0.4, 12)
	player.yaw = deg_to_rad(190)

func _build_store() -> void:
	# стойка продажи перед стогом (бесплатная, как в оригинале)
	var ss := Machines.SellStand.new()
	ss.name = "SellStand"
	add_child(ss)
	ss.global_position = Vector3(9.5, 0, 9.0)
	ss.rotation.y = deg_to_rad(-30)
	ss.setup()
	Machines.placed.append(ss)
	# магазин
	var shop := Machines.Kiosk.new()
	shop.name = "Store"
	add_child(shop)
	shop.global_position = Vector3(-13, 0, 8.5)
	shop.rotation.y = deg_to_rad(35)
	shop.setup()

func _build_signs() -> void:
	var post := Fab.mat(Color(0.28, 0.2, 0.14), 0.9)
	Fab.box(self, "hint_post", Vector3(0, 1.1, 13.5), Vector3(0.16, 2.2, 0.16), post, Vector3.ZERO, true)
	Fab.label3d(self, "НАЙДИ ИГОЛКИ\nв стоге сена", Vector3(0, 2.6, 13.5), 2.4, Color(1, 0.92, 0.6))

func _build_ui() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.player = player
	hud.pile = pile
	menu = Menu.new()
	add_child(menu)
	menu.player = player
	hud.menu_ref = menu
	hud.stick.player = player
	player.prompt_changed.connect(hud.show_prompt)
	Game.toast.connect(hud.toast)

# ------------------------------------------------------------- скриншоты
func _run_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var views := [
		{"pos": Vector3(7, 1.7, 12),  "target": Vector3(0, 4, -3),   "pitch": -2.0,  "name": "01_player_view"},
		{"pos": Vector3(16, 9.0, 16), "target": Vector3(0, 4, -3),   "pitch": -26.0, "name": "02_overview"},
		{"pos": Vector3(-11, 1.7, 9.5),"target": Vector3(-13, 1.2, 8.5), "pitch": -4.0, "name": "03_store"},
		{"pos": Vector3(8.0, 1.7, 6.5),"target": Vector3(9.5, 1.2, 9.0), "pitch": -6.0, "name": "04_sell"},
		{"pos": Vector3(0, 12.0, 14), "target": Vector3(0, 3, -3),   "pitch": -22.0, "name": "05_pile_top"},
		{"pos": Vector3(-3, 1.7, 8),  "target": Vector3(0, 3.5, -3), "pitch": -3.0,  "name": "06_walkaround"},
	]
	for v in views:
		player.global_position = v.pos
		var d: Vector3 = (v.target as Vector3) - (v.pos as Vector3)
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = deg_to_rad(v.pitch)
		player.head_look()
		player.move_input = Vector2.ZERO
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(shots_dir.path_join(String(v.name) + ".png"))
		print("shot: ", v.name, " ", img.get_size())
	# отдельно: меню
	menu.toggle(true)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png(shots_dir.path_join("07_menu.png"))
	print("shot: 07_menu")
	menu.toggle(false)
	# стог подкопан + машины для кадра «фабрика»
	print("доготавливаю сцену фабрики…")
	player.global_position = Vector3(15, 2.4, 11)
	var d2: Vector3 = Vector3(2, 2, 2) - player.global_position
	player.yaw = atan2(-d2.x, -d2.z)
	player.pitch = deg_to_rad(-9)
	player.head_look()
	Game.money = 100000.0
	for t in Game.TECH:
		Game.tech[t.id] = true
	# небольшой лоток рядом с игроком
	Machines.try_place(self, "belt", Vector3(4.5, 0, 6.0), deg_to_rad(180), player)
	Machines.try_place(self, "harvester", Vector3(1.5, 0, 7.6), deg_to_rad(200), player)
	Machines.try_place(self, "sellstand", Vector3(6.5, 0, 2.0), deg_to_rad(160), player)
	Machines.try_place(self, "scanner", Vector3(-2.0, 0, 10.0), 0.0, player)
	Machines.try_place(self, "drone", Vector3(-4.0, 3.0, 4.0), 0.0, player)
	# подкопаем стог, чтобы было видно ямку и иголку
	for i in 900:
		pile.dig(150 + (i % 40), 3)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img3 := get_viewport().get_texture().get_image()
	img3.save_png(shots_dir.path_join("08_factory.png"))
	print("shot: 08_factory")
	print("готово: ", shots_dir)
	get_tree().quit()
