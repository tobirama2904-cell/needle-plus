class_name Hud
extends CanvasLayer
# HUD + мобильное управление: виртуальный стик, кнопки, прицел, подсказки, всплывающие сообщения.

var player: Node3D
var pile: Node3D
var money_l: Label
var stats_l: Label
var prompt_l: Label
var toast_box: VBoxContainer
var det_bar: ProgressBar
var det_l: Label
var stick: Control
var look_area: Control
var dialogs := []
var menu_ref: Node = null

func _ready() -> void:
	layer = 10
	build()

func _mk_label(text: String, size: int, color := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l

func _panel(col := Color(0.06, 0.07, 0.09, 0.55)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_width_left = 1
	sb.border_color = Color(1, 1, 1, 0.12)
	p.add_theme_stylebox_override("panel", sb)
	return p

func build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- левый верх: деньги и статистика
	var top := VBoxContainer.new()
	top.position = Vector2(14, 12)
	root.add_child(top)
	var p1 := _panel()
	top.add_child(p1)
	var v1 := VBoxContainer.new()
	p1.add_child(v1)
	money_l = _mk_label("$0.00", 30, Color(1, 0.88, 0.45))
	v1.add_child(money_l)
	stats_l = _mk_label("", 18)
	v1.add_child(stats_l)

	# --- прицел
	var ch := Control.new(); ch.set_anchors_preset(Control.PRESET_FULL_RECT); ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ch)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(6, 6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-3, -3)
	ch.add_child(dot)

	# --- подсказка взаимодействия
	prompt_l = _mk_label("", 22, Color(1, 1, 1))
	prompt_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_l.position = Vector2(-200, -190)
	prompt_l.size = Vector2(400, 30)
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_l)

	# --- сигнал детектора
	var dp := _panel()
	dp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dp.position = Vector2(-120, 14)
	root.add_child(dp)
	var dv := VBoxContainer.new(); dp.add_child(dv)
	det_l = _mk_label("МЕТАЛЛОИСКАТЕЛЬ", 14, Color(0.7, 1, 0.75))
	dv.add_child(det_l)
	det_bar = ProgressBar.new()
	det_bar.custom_minimum_size = Vector2(220, 12)
	det_bar.show_percentage = false
	det_bar.max_value = 1.0
	dv.add_child(det_bar)

	# --- всплывающие сообщения
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.position = Vector2(-260, -280)
	toast_box.size = Vector2(520, 100)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(toast_box)

	# --- зона обзора (свайпы справа)
	look_area = Control.new()
	look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_area.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(look_area)
	look_area.gui_input.connect(_on_look_input)

	# --- виртуальный стик
	stick = preload("res://scripts/joystick.gd").new()
	root.add_child(stick)

	# --- кнопки действий
	var acts := Control.new()
	acts.set_anchors_preset(Control.PRESET_FULL_RECT)
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(acts)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.position = Vector2(-430, -120)
	box.add_theme_constant_override("separation", 10)
	acts.add_child(box)
	_add_action(box, "КОПАТЬ", func(down): player.want_use = down, true)
	_add_action(box, "ВЗЯТЬ\n(E)", func(down): if down: player.want_interact = true, false)
	_add_action(box, "ПРЫЖОК", func(down): if down: player.want_jump = true, false)
	_add_action(box, "ДЕТЕКТОР\n(Q)", func(down): if down: player.det_toggle_queued = true, false)

	var menu_b := Button.new()
	menu_b.text = "МЕНЮ"
	menu_b.custom_minimum_size = Vector2(110, 96)
	menu_b.add_theme_font_size_override("font_size", 20)
	menu_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_b.position = Vector2(-124, 12)
	menu_b.pressed.connect(func(): if menu_ref: menu_ref.toggle())
	acts.add_child(menu_b)

func _add_action(box: HBoxContainer, text: String, cb: Callable, hold: bool) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 96)
	b.add_theme_font_size_override("font_size", 18)
	if hold:
		b.button_down.connect(func(): cb.call(true))
		b.button_up.connect(func(): cb.call(false))
	else:
		b.pressed.connect(func(): cb.call(true); cb.call(false))
	box.add_child(b)

func _on_look_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag:
		player.look_input += ev.relative * 2.2
	elif ev is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or true:
			pass

func _process(_d: float) -> void:
	if player == null: return
	money_l.text = Game.fmt(Game.money)
	var left := 0
	if pile: left = pile.strands_left_total()
	var left_m := 0.0
	if pile: left_m = float(pile.strands_left_total()) / 1_000_000.0
	stats_l.text = "Сено в руках: %d / %d\nВыкопано: %s   Продано: %s\nИголки: %d / %d\nВ стоге: %.2f млн (выкопано %d%%)" % [
		Game.carried, Game.cap(), _fmt_num(Game.straws_dug), _fmt_num(Game.straws_sold),
		Game.needles_found, Game.NEEDLES_TOTAL, left_m,
		int(round(pile.dug_percent() * 100.0)) if pile else 0]
	if player.detector_on:
		det_bar.visible = true; det_l.visible = true
		var nfo: Dictionary = pile.nearest_needle(player.global_position)
		var s: float = 1.0 - clampf(float(nfo.dist) / Game.det_radius(), 0.0, 1.0)
		det_bar.value = s
		det_l.text = "СИГНАЛ: %s" % ("ЕСТЬ!" if s > 0.25 else "слабый")
	else:
		det_bar.visible = false; det_l.visible = false
	if player.placing != "":
		prompt_l.text = "Куда поставить → тап по «ВЗЯТЬ». Сейчас: %s" % player.placing

func _fmt_num(n: int) -> String:
	if n >= 1_000_000: return "%.2f млн" % (n / 1_000_000.0)
	if n >= 10_000: return "%.1f тыс" % (n / 1000.0)
	return str(n)

func show_prompt(text: String) -> void:
	if player.placing == "": prompt_l.text = text

func toast(text: String) -> void:
	var p := _panel(Color(0.08, 0.09, 0.12, 0.8))
	var l := _mk_label(text, 19, Color(1, 0.95, 0.8))
	p.add_child(l)
	toast_box.add_child(p)
	dialogs.append(p)
	if dialogs.size() > 5:
		var old = dialogs.pop_front()
		if is_instance_valid(old): old.queue_free()
	get_tree().create_timer(3.4).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
			dialogs.erase(p))
