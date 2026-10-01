class_name Menu
extends CanvasLayer
# Меню: Магазин / Апгрейды (240 записей) / Технологии / Настройки.

var player: Node3D
var root: Control
var tabs: HBoxContainer
var content: VBoxContainer
var cur := "shop"
var money_l: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	build()
	visible = false
	Game.changed.connect(refresh)

func _panel(col := Color(0.07, 0.08, 0.11, 0.94)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.12)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _lbl(t: String, sz: int, c := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	return l

func build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)

	var panel := _panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-460, -320)
	panel.custom_minimum_size = Vector2(920, 640)
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	head.add_child(_lbl("NEEDLE+  ·  СКЛАД №7", 26, Color(1, 0.9, 0.5)))
	money_l = _lbl("", 24, Color(0.6, 1, 0.7))
	head.add_child(money_l)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new(); close.text = "ЗАКРЫТЬ (TAB)"
	close.pressed.connect(func(): toggle(false))
	head.add_child(close)

	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in [["shop", "МАГАЗИН"], ["upg", "АПГРЕЙДЫ"], ["tech", "ТЕХНОЛОГИИ"], ["set", "НАСТРОЙКИ"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(180, 44)
		b.pressed.connect(func(): cur = t[0]; refresh())
		tabs.add_child(b)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	sc.add_child(content)

func toggle(force = null) -> void:
	var on: bool = (not visible) if force == null else bool(force)
	visible = on
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on: refresh()

func _row(name: String, desc: String, cost: float, enabled: bool, on_buy: Callable, extra := "") -> void:
	var p := _panel(Color(0.10, 0.11, 0.15, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_lbl(name + (("  " + extra) if extra != "" else ""), 20))
	if desc != "": v.add_child(_lbl(desc, 15, Color(0.75, 0.78, 0.85)))
	var b := Button.new()
	b.text = Game.fmt(cost) if cost > 0 else "ВЗЯТЬ"
	b.custom_minimum_size = Vector2(150, 46)
	b.disabled = not enabled
	b.pressed.connect(on_buy)
	h.add_child(b)
	content.add_child(p)

func refresh() -> void:
	if not visible: return
	money_l.text = "  " + Game.fmt(Game.money)
	for c in content.get_children(): c.queue_free()
	match cur:
		"shop": _fill_shop()
		"upg": _fill_upgrades()
		"tech": _fill_tech()
		"set": _fill_settings()

func _fill_shop() -> void:
	content.add_child(_lbl("ИНСТРУМЕНТЫ", 22, Color(1, 0.9, 0.6)))
	for id in Game.tools:
		var t: Dictionary = Game.tools[id]
		if id == "hands": continue
		var owned: bool = Game.unlocked_tools.get(id, false)
		var equipped: bool = Game.tool == id
		var d: String = "Копает %d за удар · силы %.1f · задержка %.2f с" % [t.scoop, t.stamina, t.cd]
		if id == "detector": d = "Ищет иголки: писк и сфера сигнала"
		_row(t.name, d, 0.0 if owned else t.price,
			(owned and not equipped) or Game.money >= t.price,
			func():
				if not owned:
					Game.money -= t.price
					Game.unlocked_tools[id] = true
					Game.toast.emit("Куплено: %s" % t.name)
					Game.save_game()
				player.set_tool(id)
				player.detector_on = (id == "detector")
				Game.emit_changed(),
			"НАДЕТО" if equipped else ("КУПЛЕНО" if owned else ""))
	content.add_child(_lbl("МАШИНЫ И АВТОМАТИЗАЦИЯ", 22, Color(1, 0.9, 0.6)))
	for m in ["belt", "harvester", "sellstand", "drone", "scanner"]:
		var unl := Machines.unlocked(m)
		var owned_n: int = Game.machines_owned.get(m, 0)
		var desc := "" 
		match m:
			"belt": desc = "Двигает тюки сена к стойке продажи"
			"harvester": desc = "Сам копает стог рядом с собой"
			"sellstand": desc = "Лента продаёт сено автоматически"
			"drone": desc = "Летает и копает сено сам"
			"scanner": desc = "Подсвечивает спрятанные иголки"
		_row(Machines.NAMES[m], desc, Machines.price(m), unl and Game.money >= Machines.price(m),
			func():
				player.start_placing(m)
				toggle(false),
			("нужна технология" if not unl else ("установлено: %d" % owned_n)))

func _fill_upgrades() -> void:
	content.add_child(_lbl("АПГРЕЙДЫ — доступны уровни 1–%d (остальные открывает Инженерия)" % Game.upg_avail_tier(), 18, Color(0.8, 0.85, 1)))
	for c in Game.UPG:
		var lvl: int = Game.lvl(c.id)
		var cap_t: int = Game.upg_avail_tier()
		var maxed: bool = lvl >= cap_t
		var cost := Game.upg_cost(c.id)
		_row(c.name, c.desc, cost, (not maxed) and Game.money >= cost,
			func(): if Game.buy_upg(c.id): Sfx.play("ui", -10),
			"ур. %d%s" % [lvl, "  (макс)" if maxed else ""])

func _fill_tech() -> void:
	content.add_child(_lbl("ТЕХНОЛОГИИ", 22, Color(1, 0.9, 0.6)))
	for t in Game.TECH:
		var owned: bool = Game.tech.get(t.id, false)
		var avail: bool = Game.tech_available(t.id)
		var req_txt := "" if t.req.is_empty() else "нужно: " + ", ".join(t.req)
		_row(t.name, t.desc + (("  ·  " + req_txt) if req_txt != "" else "") , t.price,
			(not owned) and avail and Game.money >= t.price,
			func(): if Game.buy_tech(t.id): Sfx.play("win", -12),
			"ОТКРЫТО" if owned else ("" if avail else "закрыто"))

func _fill_settings() -> void:
	content.add_child(_lbl("НАСТРОЙКИ", 22, Color(1, 0.9, 0.6)))
	var h := HBoxContainer.new()
	content.add_child(h)
	h.add_child(_lbl("Чувствительность обзора", 18))
	var sl := HSlider.new()
	sl.min_value = 0.3; sl.max_value = 3.0; sl.step = 0.1
	sl.value = Game.settings.sens
	sl.custom_minimum_size = Vector2(380, 30)
	sl.value_changed.connect(func(v): Game.settings.sens = v)
	h.add_child(sl)
	content.add_child(_lbl("Экономика: соломинок в руках %d, цена за соломину %s, множитель продажи ×%.2f" % [
		Game.cap(), Game.fmt(Game.PRICE), Game.sell_mult()], 16, Color(0.8, 0.85, 0.9)))
	content.add_child(_lbl("Всего выкопано соломы: %d · продано: %d" % [Game.straws_dug, Game.straws_sold], 16, Color(0.8, 0.85, 0.9)))
	_row("Сбросить прогресс", "Удаляет сохранение и начинает заново", 0.0, true,
		func(): Game.reset_game(); Game.toast.emit("Прогресс сброшен"))
