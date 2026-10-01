extends Node
# Автотест игрового цикла: запускается как `--headless -- --test`.
# Проверяет: стог, копание, перенос, продажу, апгрейды, технологии, машины, иголки.

var fails := 0
var tests := 0

func check(name: String, cond: bool, extra := "") -> void:
	tests += 1
	if cond:
		print("  PASS  ", name, ("  " + extra) if extra != "" else "")
	else:
		fails += 1
		print("  FAIL  ", name, "  ", extra)

func _ready() -> void:
	print("=== SELFTEST NEEDLE+ ===")
	Game.reset_game()          # тест всегда с чистого листа
	var world = get_parent()
	var pile = world.pile
	var player = world.player

	# --- стог
	check("стог построен", pile.strands_left_total() > 1000000,
		"соломинок в стоге: %d" % pile.strands_left_total())
	check("прогресс 0%% в начале", abs(pile.dug_percent()) < 0.001)

	# --- копание
	var idx: int = pile.cell_of_pos(pile.cell_center(300))
	var before_cell: int = pile.left_strands[idx]
	var got: int = pile.dig(idx, 30)
	check("копание уменьшает ячейку", got > 0 and pile.left_strands[idx] == before_cell - got,
		"взяли %d" % got)
	check("прогресс вырос", pile.dug_percent() > 0.0,
		"%.4f%%" % (pile.dug_percent() * 100.0))

	# --- перенос и продажа
	Game.carried = 0
	var cap0 := Game.cap()
	var want := 10
	var put := Game.add_carried(want)
	check("перенос работает", put == mini(want, Game.cap()) and Game.carried == put,
		"взял %d из %d" % [put, want])
	var money0 := Game.money
	var gain := Game.sell_carried()
	check("продажа начисляет деньги", gain > 0 and Game.money > money0 and Game.carried == 0,
		"+%.2f" % gain)

	# --- апгрейды
	Game.add_money(100000)
	var buy := Game.buy_upg("arms")
	check("апгрейд покупается", buy and Game.lvl("arms") == 1)
	check("эффект апгрейда работает", Game.cap() == cap0 + 25,
		"перенос %d -> %d" % [cap0, Game.cap()])
	var tier0 := Game.upg_avail_tier()
	var tb := Game.buy_tech("engineering1")
	check("технология открывает уровни", tb and Game.upg_avail_tier() > tier0,
		"уровни 1-%d" % Game.upg_avail_tier())

	# --- машины
	Game.buy_tech("belts")
	var m0: float = Game.money
	var ok := Machines.try_place(world, "belt", Vector3(3, 0, 6), 0.0, player)
	check("конвейер ставится", ok and Game.money < m0)
	Game.buy_tech("harvester")
	var h_ok := Machines.try_place(world, "harvester", Vector3(0, 0, 6.5), 0.0, player)
	check("харвестер ставится", h_ok and Game.machines_owned.get("harvester", 0) >= 1)

	# --- харвестер копает сам: ждём 3 секунды игрового времени
	var harvested_before: int = pile.strands_left_total()
	for i in 200:
		await get_tree().process_frame
	check("харвестер копает сам", pile.strands_left_total() < harvested_before,
		"снято %d" % (harvested_before - pile.strands_left_total()))

	# --- авто-продажа через стойку
	var stand = null
	for n in Machines.placed:
		if n is Machines.SellStand: stand = n
	if stand:
		var money_before: float = Game.money
		var bale := Bale.new()
		world.add_child(bale)
		stand.receive(bale)
		check("авто-продажа принимает тюк", Game.money > money_before,
			"+%.2f" % (Game.money - money_before))

	# --- иголки
	var n0: Dictionary = pile.needles[0]
	var nidx: int = int(n0.cell)
	pile.dig(nidx, 999999)
	check("иголка открывается при копании", pile.needles[0].node != null)
	var pos: Vector3 = pile.global_position + n0.pos + Vector3(0, pile.heights[nidx], 0)
	var near: Dictionary = pile.nearest_needle(pos)
	check("поиск ближайшей иголки", near.dist < 1.5, "%.2f м" % near.dist)
	pile.take_needle(0)
	check("иголка берётся", Game.needles_found == 1 and pile.needles[0].found)

	# --- сохранение
	Game.save_game()
	check("сохранение создано", FileAccess.file_exists(Game.save_path()))

	print("=== ИТОГ: %d/%d прошло, %d ошибок ===" % [tests - fails, tests, fails])
	print("SELFTEST_", "OK" if fails == 0 else "FAILED")
	get_tree().quit(0 if fails == 0 else 1)
