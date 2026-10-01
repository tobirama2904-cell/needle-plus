class_name Joy
extends Control
# Виртуальный стик (мышь/тач). Двигает игрока по вектору, тянет бег при полном отклонении.

var touch_id := -1
var base := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 92.0
var active := false
var player: Node = null

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(24, -284)
	size = Vector2(260, 260)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var c := size * 0.5
	c.y = size.y * 0.5
	draw_circle(c, radius + 8, Color(0, 0, 0, 0.25))
	draw_circle(c, radius + 6, Color(1, 1, 1, 0.10))
	draw_arc(c, radius + 6, 0, TAU, 48, Color(1, 1, 1, 0.28), 2.0)
	var k := c + knob
	draw_circle(k, 30, Color(1, 0.9, 0.6, 0.85 if active else 0.55))
	draw_arc(k, 30, 0, TAU, 32, Color(0, 0, 0, 0.4), 2.0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and touch_id == -1:
			touch_id = ev.index
			base = ev.position
			active = true
			_apply(ev.position)
		elif not ev.pressed and ev.index == touch_id:
			touch_id = -1
			active = false
			knob = Vector2.ZERO
			_set_move(Vector2.ZERO)
			queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == touch_id:
		_apply(ev.position)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		active = ev.pressed
		if ev.pressed:
			base = ev.position
			_apply(ev.position)
		else:
			knob = Vector2.ZERO
			_set_move(Vector2.ZERO)
		queue_redraw()
	elif ev is InputEventMouseMotion and active:
		_apply(ev.position)

func _apply(pos: Vector2) -> void:
	var d := pos - base
	if d.length() > radius:
		base = pos - d.normalized() * radius
		d = d.normalized() * radius
	knob = d
	_set_move(d / radius)
	queue_redraw()

func _set_move(v: Vector2) -> void:
	if player == null: return
	player.move_input = v
	player.sprint_touch = v.length() > 0.9
