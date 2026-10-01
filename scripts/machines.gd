class_name Machines
extends RefCounted
# Машины: конвейер, харвестер, авто-стойка продажи, дрон, сканер.
# Все placed-устройства складываются в общий список, ленты сами находят приёмник впереди.

static var placed: Array = []
static var pile_ref: Node3D = null

const PRICES := {"belt": 18.0, "harvester": 260.0, "sellstand": 220.0, "drone": 900.0, "scanner": 1500.0}
const TECH_REQ := {"belt": "belts", "harvester": "harvester", "sellstand": "autosell",
	"drone": "drones", "scanner": "scanner"}
const NAMES := {"belt": "Конвейер", "harvester": "Харвестер", "sellstand": "Авто-продажа",
	"drone": "Дрон-копатель", "scanner": "Сканер иголок"}

static func price(m: String) -> float: return float(PRICES.get(m, 999.0))

static func unlocked(m: String) -> bool:
	var t: String = TECH_REQ.get(m, "")
	if t == "": return true
	if not Game.tech.get(t, false): return false
	return true

static func make_ghost(m: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ghost"
	var col := Color(0.3, 1.0, 0.4, 0.35)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = col
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true
	gm.emission = Color(0.2, 0.9, 0.3)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match m:
		"belt":
			Fab.box(root, "b", Vector3.ZERO, Vector3(1.0, 0.16, 0.7), gm).position = Vector3(0, 0.08, 0)
		"harvester":
			Fab.box(root, "b", Vector3.ZERO, Vector3(1.6, 1.2, 1.6), gm).position = Vector3(0, 0.6, 0)
		"sellstand":
			Fab.box(root, "b", Vector3.ZERO, Vector3(2.0, 1.6, 1.2), gm).position = Vector3(0, 0.8, 0)
		"drone":
			Fab.box(root, "b", Vector3.ZERO, Vector3(0.5, 0.2, 0.5), gm).position = Vector3(0, 0.5, 0)
		"scanner":
			Fab.cyl(root, "b", Vector3(0, 0.8, 0), 0.5, 1.6, gm, Vector3.ZERO, 12)
	return root

static func try_place(world: Node3D, m: String, pos: Vector3, yaw: float, player) -> bool:
	if not unlocked(m):
		Game.toast.emit("Нужна технология: %s" % NAMES.get(m, m))
		return false
	if Game.money < price(m):
		Game.toast.emit("Не хватает денег: %s" % Game.fmt(price(m)))
		return false
	if m == "harvester" or m == "scanner":
		var d := Vector2(pos.x, pos.z).length()
		if d > 14.0:
			Game.toast.emit("Ставь ближе к стогу")
			return false
	var node: Node3D = null
	match m:
		"belt": node = Belt.new()
		"harvester": node = Harvester.new()
		"sellstand": node = SellStand.new()
		"drone": node = Drone.new()
		"scanner": node = Scanner.new()
	if node == null: return false
	world.add_child(node)
	node.global_position = pos
	node.rotation.y = yaw
	if node.has_method("setup"):
		node.setup()
	Game.money -= price(m)
	Game.machines_owned[m] = Game.machines_owned.get(m, 0) + 1
	placed.append(node)
	Game.emit_changed()
	Game.save_game()
	Game.toast.emit("%s установлен (−%s)" % [NAMES.get(m, m), Game.fmt(price(m))])
	if player and player.ghost == null:
		pass
	return true

static func find_receiver(from: Vector3, fwd: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 1.6
	for n in placed:
		if not is_instance_valid(n): continue
		var d: float = n.global_position.distance_to(from)
		if d < best_d and d > 0.2:
			best_d = d
			best = n
	return best

# ------------------------------------------------------------------- лента
class Belt extends Node3D:
	var items: Array = []
	var out: Node3D = null
	var speed := 1.6
	var meshes: Array = []

	func setup() -> void:
		var metal := Fab.mat_tex(Tex.metal(128, Color(0.34, 0.36, 0.4)))
		var dark := Fab.mat(Color(0.12, 0.12, 0.14), 0.7)
		var base := Fab.box(self, "base", Vector3(0, 0.02, 0), Vector3(1.0, 0.06, 0.7), dark)
		base.create_trimesh_collision()
		Fab.box(self, "belt", Vector3(0, 0.09, 0), Vector3(0.96, 0.05, 0.56), metal)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = Vector3(1.0, 0.3, 0.7)
		cs.shape = sh
		var area := Area3D.new()
		area.collision_layer = 8
		area.set_meta("interact_name", "Конвейер — крутить (R)")
		area.position = Vector3(0, 0.25, 0)
		area.add_child(cs)
		add_child(area)
		# боковые ролики
		for s in [-1, 1]:
			Fab.cyl(self, "roll%d" % s, Vector3(s * 0.5, 0.09, 0), 0.06, 0.6, Fab.mat(Color(0.5, 0.5, 0.55), 0.4, 0.7), Vector3(deg_to_rad(90), 0, 0), 10)
		speed = 1.5 * Game.machine_speed()

	func _process(delta: float) -> void:
		if out == null or not is_instance_valid(out):
			out = Machines.find_receiver(global_position + (-global_transform.basis.z) * 1.0, -global_transform.basis.z)
		var keep := []
		for it in items:
			if not is_instance_valid(it): continue
			var target := out.global_position + Vector3(0, 0.25, 0) if out else global_position + (-global_transform.basis.z) * 0.45
			it.global_position = it.global_position.move_toward(target, speed * delta)
			if out and it.global_position.distance_to(target) < 0.15:
				if out.has_method("receive"):
					out.receive(it)
					continue
			keep.append(it)
		items = keep

	func receive(it: Node3D) -> void:
		items.append(it)

	func interact(_p) -> void:
		rotation.y += deg_to_rad(90)
		out = null
		Sfx.play("ui", -12)

# ---------------------------------------------------------------- харвестер
class Harvester extends Node3D:
	var t := 0.0
	var hopper := 0
	var out_dir: Node3D = null
	var lamp: OmniLight3D

	func setup() -> void:
		var orange := Fab.mat(Color(0.85, 0.42, 0.12), 0.6)
		var gray := Fab.mat(Color(0.55, 0.57, 0.6), 0.4, 0.6)
		var dark := Fab.mat(Color(0.15, 0.16, 0.18), 0.7)
		Fab.box(self, "body", Vector3(0, 0.6, 0), Vector3(1.5, 1.1, 1.5), orange)
		Fab.box(self, "cab", Vector3(0, 1.45, -0.25), Vector3(1.0, 0.6, 0.8), dark)
		Fab.cyl(self, "pipe", Vector3(0, 1.1, 0.9), 0.22, 1.3, gray, Vector3(deg_to_rad(70), 0, 0), 12)
		Fab.cyl(self, "wheel1", Vector3(-0.6, 0.35, 0.55), 0.35, 0.2, dark, Vector3(0, 0, deg_to_rad(90)), 12)
		Fab.cyl(self, "wheel2", Vector3(0.6, 0.35, 0.55), 0.35, 0.2, dark, Vector3(0, 0, deg_to_rad(90)), 12)
		Fab.cyl(self, "wheel3", Vector3(-0.6, 0.35, -0.55), 0.35, 0.2, dark, Vector3(0, 0, deg_to_rad(90)), 12)
		Fab.cyl(self, "wheel4", Vector3(0.6, 0.35, -0.55), 0.35, 0.2, dark, Vector3(0, 0, deg_to_rad(90)), 12)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = Vector3(1.6, 1.4, 1.6)
		cs.shape = sh
		var bodyc := StaticBody3D.new(); bodyc.collision_layer = 1 | 16
		bodyc.add_child(cs)
		bodyc.set_meta("interact_name", "Харвестер — собрать сено")
		add_child(bodyc)
		lamp = OmniLight3D.new()
		lamp.light_energy = 0.8
		lamp.light_color = Color(1.0, 0.6, 0.25)
		lamp.position = Vector3(0, 1.8, 0)
		add_child(lamp)
		Fab.label3d(self, "ХАРВЕСТЕР", Vector3(0, 2.2, 0), 1.2, Color(1, 0.85, 0.4))

	func _process(delta: float) -> void:
		if Machines.pile_ref == null: return
		t -= delta
		if t > 0: return
		t = 0.55 / Game.machine_speed()
		var idx: int = Machines.pile_ref.cell_of_pos(global_position)
		if idx < 0:
			# берём ближайшую ячейку к машине
			idx = _nearest_cell()
		if idx < 0: return
		var got: int = Machines.pile_ref.dig(idx, int(1500 * Game.machine_eff()))
		if got <= 0: return
		Sfx.play3d("ratchet", global_position, -18, 0.8)
		hopper += got
		if hopper >= 6000:
			_drop_bale()

	func _nearest_cell() -> int:
		var best := -1
		var bd := 6.0
		var pile: Node3D = Machines.pile_ref
		for cz in range(0, 18):
			for cx in range(0, 18):
				var idx := cz * 18 + cx
				if pile.left_strands[idx] <= 0: continue
				var p: Vector3 = pile.cell_center(idx)
				var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
				if d < bd:
					bd = d
					best = idx
		return best

	func _drop_bale() -> void:
		var n := int(hopper / 6000)
		hopper -= n * 6000
		for i in n:
			var bale: Node3D = Bale.new()
			get_parent().add_child(bale)
			bale.global_position = global_position + (-global_transform.basis.z) * 1.2 + Vector3(0, 0.5, 0)
			if out_dir == null or not is_instance_valid(out_dir):
				out_dir = Machines.find_receiver(global_position + (-global_transform.basis.z) * 1.4, -global_transform.basis.z)
			if out_dir and out_dir.has_method("receive"):
				out_dir.receive(bale)
			else:
				# без ленты — копим у машины
				bale.queue_free()
				hopper += 6000
				if int(Time.get_ticks_msec() / 1000.0) % 4 == 0:
					Game.toast.emit("Нет конвейера — сено копится в бункере")
				return

	func interact(_p) -> void:
		if hopper > 0:
			var put := Game.add_carried(hopper)
			hopper -= put
			Sfx.play("rustle", -10)
			Game.toast.emit("Забрал из бункера: %d" % put)
		else:
			Game.toast.emit("Бункер пуст")


# -------------------------------------------------------------- авто-продажа
class SellStand extends Node3D:
	var lamp: OmniLight3D
	var t := 0.0
	var pending := 0

	func setup() -> void:
		var wood := Fab.mat_tex(Tex.planks())
		var dark := Fab.mat(Color(0.2, 0.16, 0.12), 0.8)
		Fab.box(self, "counter", Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 1.0), wood)
		Fab.box(self, "top", Vector3(0, 1.05, 0), Vector3(2.3, 0.1, 1.1), dark)
		Fab.label3d(self, "ПРОДАЖА СЕНА", Vector3(0, 1.6, 0), 1.6, Color(1, 0.92, 0.55))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = Vector3(2.2, 1.3, 1.0)
		cs.shape = sh
		var b := StaticBody3D.new(); b.collision_layer = 1 | 16
		b.add_child(cs)
		b.set_meta("interact_name", "Продать сено из рук (E)")
		add_child(b)
		lamp = OmniLight3D.new()
		lamp.light_energy = 0.7
		lamp.light_color = Color(1.0, 0.85, 0.5)
		lamp.position = Vector3(0, 1.9, 0)
		add_child(lamp)

	func receive(it: Node3D) -> void:
		if not is_instance_valid(it): return
		it.queue_free()
		var gain: float = 6000.0 * Game.PRICE * Game.sell_mult()
		Game.add_money(gain)
		Game.straws_sold += 6000
		Sfx.play3d("ding", global_position, -6, randf_range(0.98, 1.05))

	func interact(p) -> void:
		if Game.carried <= 0:
			Game.toast.emit("Нечего продавать — накопай сена")
			return
		var gain := Game.sell_carried()
		p._rebuild_carried()
		Sfx.play("ding", -4)
		Game.toast.emit("Продано! +%s" % Game.fmt(gain))

# -------------------------------------------------------------------- дрон
class Drone extends Node3D:
	var t := 0.0
	var target := Vector3.ZERO
	var hopper := 0

	func setup() -> void:
		Fab.box(self, "body", Vector3.ZERO, Vector3(0.5, 0.14, 0.5), Fab.mat(Color(0.25, 0.28, 0.34), 0.5, 0.5))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				Fab.cyl(self, "rotor%d%d" % [sx, sz], Vector3(sx * 0.26, 0.06, sz * 0.26), 0.14, 0.02,
					Fab.mat(Color(0.1, 0.1, 0.12), 0.4), Vector3.ZERO, 12)
		var lamp := OmniLight3D.new()
		lamp.light_energy = 0.9
		lamp.light_color = Color(0.3, 0.8, 1.0)
		lamp.position = Vector3(0, -0.1, 0)
		add_child(lamp)
		position.y = 3.0

	func _process(delta: float) -> void:
		if Machines.pile_ref == null: return
		t -= delta
		var hover := 3.0 + sin(Time.get_ticks_msec() * 0.002) * 0.15
		if t <= 0:
			t = 1.1 / Game.machine_speed()
			var pile: Node3D = Machines.pile_ref
			for tries in 12:
				var cx := randi() % 18
				var cz := randi() % 18
				var idx := cz * 18 + cx
				if pile.left_strands[idx] > 4:
					target = pile.cell_center(idx)
					var got: int = pile.dig(idx, int(700 * Game.machine_eff()))
					hopper += got
					if hopper >= 9000:
						Game.add_money(9000 * Game.PRICE * Game.sell_mult() * 0.8)
						Game.straws_sold += 9000
						hopper -= 9000
						Sfx.play3d("ding", global_position, -14)
					break
		var dst := Vector3(target.x, hover, target.z)
		global_position = global_position.move_toward(dst, 3.2 * delta)

# ------------------------------------------------------------------ сканер
class Scanner extends Node3D:
	var t := 0.0
	var beacons: Array = []

	func setup() -> void:
		Fab.cyl(self, "pole", Vector3(0, 0.9, 0), 0.06, 1.8, Fab.mat(Color(0.3, 0.32, 0.36), 0.5, 0.6), Vector3.ZERO, 10)
		Fab.cyl(self, "dish", Vector3(0, 1.9, 0), 0.5, 0.08, Fab.mat(Color(0.5, 0.55, 0.6), 0.4, 0.6), Vector3(deg_to_rad(20), 0, 0), 16)
		var lamp := OmniLight3D.new()
		lamp.light_energy = 1.2
		lamp.light_color = Color(0.4, 0.9, 1.0)
		lamp.position = Vector3(0, 2.0, 0)
		add_child(lamp)

	func _process(delta: float) -> void:
		t -= delta
		if t > 0: return
		t = 6.0
		if Machines.pile_ref == null: return
		var pile: Node3D = Machines.pile_ref
		for n in pile.needles:
			if n.found or n.node != null: continue
			if Vector2(pile.global_position.x + n.pos.x, pile.global_position.z + n.pos.z).distance_to(Vector2(global_position.x, global_position.z)) > 22.0:
				continue
			var pillar := Fab.cyl(get_parent(), "beacon", Vector3.ZERO, 0.3, 12.0,
				Fab.mat(Color(0.35, 0.9, 1.0, 0.18), 0.2), Vector3.ZERO, 8)
			var m: StandardMaterial3D = pillar.material_override
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color(0.3, 0.8, 1.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pillar.position = pile.global_position + n.pos + Vector3(0, 6.0, 0)
			beacons.append(pillar)
			Sfx.play3d("beep", global_position, -8, 1.4)
			while beacons.size() > 3:
				var old = beacons.pop_front()
				if is_instance_valid(old): old.queue_free()
			return

# ------------------------------------------------------------------- магазин
class Kiosk extends Node3D:
	func setup() -> void:
		var wood := Fab.mat_tex(Tex.planks())
		var dark := Fab.mat(Color(0.18, 0.14, 0.11), 0.85)
		var copper := Fab.mat(Color(0.72, 0.45, 0.22), 0.4, 0.6)
		Fab.box(self, "counter", Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 1.0), wood)
		Fab.box(self, "top", Vector3(0, 1.15, 0), Vector3(3.3, 0.1, 1.1), dark)
		Fab.box(self, "board", Vector3(0, 2.2, -0.4), Vector3(3.0, 1.1, 0.12), dark)
		Fab.label3d(self, "МАГАЗИН", Vector3(0, 2.3, -0.3), 2.0, Color(1, 0.85, 0.45))
		Fab.label3d(self, "инструменты · апгрейды · машины", Vector3(0, 1.9, -0.3), 1.1, Color(0.85, 0.9, 1.0))
		# витрина: пара инструментов на прилавке
		Fab.box(self, "show_shovel", Vector3(-1.0, 1.26, 0.1), Vector3(0.9, 0.06, 0.14), copper)
		Fab.box(self, "show_box", Vector3(1.0, 1.3, 0.1), Vector3(0.5, 0.3, 0.4), wood)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = Vector3(3.2, 1.4, 1.0)
		cs.shape = sh
		var b := StaticBody3D.new(); b.collision_layer = 1 | 16
		b.add_child(cs)
		b.set_meta("interact_name", "Открыть магазин (E)")
		add_child(b)
		var lamp := OmniLight3D.new()
		lamp.light_energy = 0.9
		lamp.light_color = Color(1.0, 0.85, 0.55)
		lamp.position = Vector3(0, 2.6, 0.4)
		add_child(lamp)

	func interact(p) -> void:
		var world = p.get_parent()
		if world and world.get("menu"):
			world.menu.toggle(true)
		Sfx.play("ui", -10)
