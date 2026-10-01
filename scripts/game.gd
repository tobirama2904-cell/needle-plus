extends Node
# Game — автозагрузка: экономика, инструменты, апгрейды, технологии, звук, сохранение.

signal changed
signal toast(text: String)

const PRICE := 0.05           # базовая цена за соломинку
const NEEDLES_TOTAL := 6

var money: float = 0.0
var carried: int = 0
var straws_dug: int = 0
var straws_sold: int = 0
var needles_found: int = 0
var tool: String = "hands"
var unlocked_tools := {"hands": true}
var tools := {
	"hands":     {"name": "Руки",        "scoop": 40,   "cd": 0.55, "stamina": 3.0,  "price": 0,   "reach": 2.6},
	"shovel":    {"name": "Лопата",      "scoop": 200,  "cd": 0.50, "stamina": 6.5,  "price": 45,  "reach": 3.0},
	"pitchfork": {"name": "Вилы",        "scoop": 420,  "cd": 0.62, "stamina": 9.0,  "price": 160, "reach": 3.3},
	"rake":      {"name": "Грабли",      "scoop": 900,  "cd": 0.72, "stamina": 11.0, "price": 420, "reach": 3.4},
	"bucket":    {"name": "Ведро",       "scoop": 1800, "cd": 0.95, "stamina": 15.0, "price": 980, "reach": 3.0},
	"vacuum":    {"name": "Пылесос",     "scoop": 3600, "cd": 1.15, "stamina": 20.0, "price": 2400,"reach": 3.6},
	"detector":  {"name": "Металлоискатель","scoop": 0, "cd": 1.0, "stamina": 0.0, "price": 90,  "reach": 3.0},
}

# 15 категорий апгрейдов × 16 уровней = 240 записей, у каждой — реальный эффект
const UPG := [
	{"id": "arms",    "name": "Грузоподъёмность", "base": 30.0,  "desc": "+25 соломы к переносу"},
	{"id": "stam",    "name": "Выносливость",     "base": 25.0,  "desc": "+12 к максимуму сил"},
	{"id": "regen",   "name": "Восстановление",   "base": 35.0,  "desc": "+1.6 сил/сек"},
	{"id": "speed",   "name": "Скорость шага",    "base": 30.0,  "desc": "+4% к ходьбе"},
	{"id": "run",     "name": "Бег",              "base": 40.0,  "desc": "+5% к бегу"},
	{"id": "dig",     "name": "Скорость копания", "base": 45.0,  "desc": "−3% к задержке удара"},
	{"id": "scoop",   "name": "Загребание",       "base": 55.0,  "desc": "+30 соломы за удар"},
	{"id": "detr",    "name": "Чутьё детектора",  "base": 40.0,  "desc": "+0.5 м радиуса"},
	{"id": "magnet",  "name": "Магнит",           "base": 60.0,  "desc": "+0.6 м авто-сбора"},
	{"id": "price",   "name": "Торговля",         "base": 70.0,  "desc": "+3% к цене сена"},
	{"id": "mspeed",  "name": "Скорость машин",   "base": 90.0,  "desc": "+5% к темпу машин"},
	{"id": "meff",    "name": "КПД машин",        "base": 110.0, "desc": "+4% к выработке"},
	{"id": "capacity","name": "Кузов тачки",      "base": 80.0,  "desc": "+120 к переносу"},
	{"id": "jump",    "name": "Прыгучесть",       "base": 35.0,  "desc": "+3% к прыжку"},
	{"id": "lamp",    "name": "Фонарь",           "base": 20.0,  "desc": "+8% яркости света"},
]

# Технологии — гейты для высоких уровней апгрейдов и машин
const TECH := [
	{"id": "engineering1", "name": "Инженерия I",   "price": 250,   "req": [],            "desc": "Открывает уровни апгрейдов 5–8"},
	{"id": "engineering2", "name": "Инженерия II",  "price": 3000,  "req": ["engineering1"],"desc": "Открывает уровни 9–12"},
	{"id": "engineering3", "name": "Инженерия III", "price": 25000, "req": ["engineering2"],"desc": "Открывает уровни 13–16"},
	{"id": "belts",        "name": "Конвейеры",     "price": 300,   "req": ["engineering1"],"desc": "Магазин: конвейерная лента"},
	{"id": "harvester",    "name": "Харвестер",     "price": 1200,  "req": ["belts"],     "desc": "Машина сама копает сено"},
	{"id": "autosell",     "name": "Автопродажа",   "price": 2500,  "req": ["belts"],     "desc": "Лента сама продаёт сено"},
	{"id": "scanner",      "name": "Сканер иголок", "price": 6000,  "req": ["harvester"], "desc": "Сканер подсвечивает иголки"},
	{"id": "drones",       "name": "Дроны",         "price": 4000,  "req": ["engineering2"],"desc": "Магазин: дроны-копатели"},
]

var upg := {}      # id -> level
var tech := {}     # id -> true
var machines_owned := {}   # id -> count
var settings := {"sens": 1.0, "shadows": true, "fov": 78.0}

func _ready() -> void:
	for c in UPG:
		upg[c.id] = 0
	init_input()
	load_game()

func init_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN],
		"move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "run": [KEY_SHIFT], "use": [KEY_F],
		"interact": [KEY_E], "menu": [KEY_TAB], "detector": [KEY_Q],
		"drop": [KEY_G], "rotate": [KEY_R], "place": [KEY_F],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			for k in keys[a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(a, ev)
	if not InputMap.has_action("use_mouse"):
		InputMap.add_action("use_mouse")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("use_mouse", mb)

# ---------------------------------------------------------------- апгрейды
func upg_avail_tier() -> int:
	if tech.get("engineering3"): return 16
	if tech.get("engineering2"): return 12
	if tech.get("engineering1"): return 8
	return 4

func upg_cost(id: String) -> float:
	var c := {}
	for u in UPG:
		if u.id == id: c = u
	var lvl: int = upg.get(id, 0)
	return float(c.base) * pow(1.34, lvl)

func can_buy_upg(id: String) -> bool:
	if upg.get(id, 0) >= upg_avail_tier(): return false
	return money + 0.0001 >= upg_cost(id)

func buy_upg(id: String) -> bool:
	if not can_buy_upg(id): return false
	money -= upg_cost(id)
	upg[id] = upg.get(id, 0) + 1
	emit_changed()
	return true

func lvl(id: String) -> int: return upg.get(id, 0)

# ---------------------------------------------------------------- эффекты
func cap() -> int: return 60 + 25 * lvl("arms") + 120 * lvl("capacity")
func stam_max() -> float: return 100.0 + 12.0 * lvl("stam")
func stam_regen() -> float: return 12.0 + 1.6 * lvl("regen")
func walk_speed() -> float: return 4.4 * (1.0 + 0.04 * lvl("speed"))
func run_speed() -> float: return 7.4 * (1.0 + 0.05 * lvl("run"))
func jump_vel() -> float: return 5.2 * (1.0 + 0.03 * lvl("jump"))
func dig_cd() -> float: return (1.0 - 0.03 * lvl("dig"))
func scoop_extra() -> int: return 30 * lvl("scoop")
func det_radius() -> float: return 6.0 + 0.5 * lvl("detr")
func magnet_radius() -> float: return 1.2 + 0.6 * lvl("magnet")
func sell_mult() -> float: return 1.0 + 0.03 * lvl("price")
func machine_speed() -> float: return 1.0 + 0.05 * lvl("mspeed")
func machine_eff() -> float: return 1.0 + 0.04 * lvl("meff")
func lamp_energy() -> float: return 3.0 * (1.0 + 0.08 * lvl("lamp"))

func tool_data() -> Dictionary: return tools[tool]
func tool_cd() -> float: return float(tools[tool].cd) * dig_cd()

# ---------------------------------------------------------------- действия
func add_carried(n: int) -> int:
	var room: int = cap() - carried
	var put: int = min(n, room)
	carried += put
	straws_dug += n
	emit_changed()
	return put

func sell_carried() -> float:
	var gain: float = carried * PRICE * sell_mult()
	money += gain
	straws_sold += carried
	carried = 0
	emit_changed()
	return gain

func add_money(x: float) -> void:
	money += x
	emit_changed()

func emit_changed() -> void: changed.emit()

func tech_available(id: String) -> bool:
	var t := {}
	for e in TECH:
		if e.id == id: t = e
	for r in t.req:
		if not tech.get(r, false): return false
	return true

func buy_tech(id: String) -> bool:
	var t := {}
	for e in TECH:
		if e.id == id: t = e
	if tech.get(id, false) or not tech_available(id) or money < t.price: return false
	money -= t.price
	tech[id] = true
	emit_changed()
	return true

func fmt(x: float) -> String:
	if x >= 1e9: return "$%.2fB" % (x / 1e9)
	if x >= 1e6: return "$%.2fM" % (x / 1e6)
	if x >= 1e4: return "$%.1fK" % (x / 1e3)
	if x >= 100.0: return "$%.0f" % x
	return "$%.2f" % x

# ---------------------------------------------------------------- сохранение
func save_path() -> String: return "user://needle_save.json"

func save_game() -> void:
	var d := {"money": money, "upg": upg, "tech": tech, "needles": needles_found,
		"sold": straws_sold, "dug": straws_dug, "unlocked": unlocked_tools,
		"machines": machines_owned}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d))

func load_game() -> void:
	if not FileAccess.file_exists(save_path()): return
	var f := FileAccess.open(save_path(), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	money = d.get("money", 0.0)
	straws_sold = d.get("sold", 0)
	straws_dug = d.get("dug", 0)
	needles_found = d.get("needles", 0)
	machines_owned = d.get("machines", {})
	var u = d.get("upg", {})
	for k in u: upg[k] = int(u[k])
	var t = d.get("tech", {})
	for k in t: tech[k] = bool(t[k])
	var un = d.get("unlocked", {})
	for k in un: unlocked_tools[k] = bool(un[k])

func reset_game() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
	money = 0.0; carried = 0; straws_dug = 0; straws_sold = 0; needles_found = 0
	for c in UPG: upg[c.id] = 0
	tech = {}
	unlocked_tools = {"hands": true}
	tool = "hands"
	emit_changed()
