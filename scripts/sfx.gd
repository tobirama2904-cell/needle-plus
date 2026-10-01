class_name Sfx
extends RefCounted
# Простой пул проигрывателей + 3D-звук в точке. Файлы .wav лежат в res://sounds/.

static var _lib := {}
static var _players: Array[AudioStreamPlayer] = []
static var _root: Node = null
static var _idx := 0

static func init(root: Node) -> void:
	_root = root
	for n in ["step", "rustle", "dig", "beep", "ding", "win", "wind", "ui", "thud", "ratchet", "whoosh"]:
		var p := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(p):
			var s: AudioStream = load(p)
			if s is AudioStreamWAV and n in ["wind", "hum"]:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = w.data.size() / (4 if w.stereo else 2)
			_lib[n] = s
	for i in 12:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		root.add_child(ap)
		_players.append(ap)

static func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if _players.is_empty() or not _lib.has(name): return
	var ap := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	ap.stream = _lib[name]
	ap.volume_db = vol_db
	ap.pitch_scale = pitch
	ap.play()

static func play3d(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if _root == null or not _lib.has(name): return
	var ap := AudioStreamPlayer3D.new()
	ap.stream = _lib[name]
	ap.volume_db = vol_db
	ap.pitch_scale = pitch
	ap.unit_size = 6.0
	ap.max_distance = 40.0
	_root.add_child(ap)
	ap.global_position = pos
	ap.play()
	ap.finished.connect(ap.queue_free)

static func loop_play(name: String, vol_db := -12.0) -> AudioStreamPlayer:
	if _root == null or not _lib.has(name): return null
	var ap := AudioStreamPlayer.new()
	ap.stream = _lib[name]
	ap.volume_db = vol_db
	_root.add_child(ap)
	ap.play()
	return ap
