class_name Tex
extends RefCounted
# Процедурные текстуры — рисуем кодом, без внешних файлов (быстро и весит копейки).

static func concrete(size := 512) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	img.fill(Color(0.42, 0.40, 0.37))
	for i in size * 14:
		var x := rng.randf() * size
		var y := rng.randf() * size
		var r := rng.randf_range(3, 26)
		var c := 0.34 + rng.randf() * 0.16
		_disc(img, x, y, r, Color(c, c * 0.98, c * 0.93), 0.25)
	for i in 90:
		var x := rng.randf() * size
		var y := rng.randf() * size
		var c2 := Color(0.3, 0.29, 0.27)
		_line(img, Vector2(x, y), Vector2(x + rng.randf_range(-90, 90), y + rng.randf_range(-90, 90)),
			rng.randf_range(0.6, 2.0), c2)
	return ImageTexture.create_from_image(img)

static func straw_texture(size := 512) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.83, 0.62, 0.24))
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var cols := [Color(0.92, 0.74, 0.32), Color(0.80, 0.58, 0.20), Color(0.95, 0.82, 0.44),
		Color(0.72, 0.51, 0.17), Color(0.88, 0.68, 0.27)]
	for i in 4200:
		var x := rng.randf() * size
		var y := rng.randf() * size
		var a := rng.randf() * TAU
		var l := rng.randf_range(14, 46)
		var col: Color = cols[rng.randi() % cols.size()]
		_line(img, Vector2(x, y), Vector2(x + cos(a) * l, y + sin(a) * l),
			rng.randf_range(1.0, 2.6), col)
	for i in 700:
		var x := rng.randf() * size
		var y := rng.randf() * size
		_line(img, Vector2(x, y), Vector2(x + rng.randf_range(-26, 26), y + rng.randf_range(-8, 8)),
			rng.randf_range(0.8, 1.8), Color(0.65, 0.45, 0.14))
	return ImageTexture.create_from_image(img)

static func planks(size := 512) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 33
	img.fill(Color(0.30, 0.235, 0.17))
	var row := 0
	var y := 0.0
	while y < size:
		var h := rng.randf_range(52, 74)
		var c := 0.26 + rng.randf() * 0.10
		var base := Color(c, c * 0.79, c * 0.58)
		for x in size:
			for yy in range(int(y), int(min(y + h, size))):
				var g := 1.0 + 0.10 * sin(x * 0.05 + row * 3.0) * rng.randf_range(0.6, 1.4)
				img.set_pixel(x, yy, Color(base.r * g, base.g * g, base.b * g))
		for i in 220:
			var lx := rng.randf() * size
			var ly := y + rng.randf() * h
			_line(img, Vector2(lx, ly), Vector2(lx + rng.randf_range(-40, 40), ly + rng.randf_range(-2, 2)),
				1.0, Color(base.r * 0.7, base.g * 0.7, base.b * 0.7))
		_line(img, Vector2(0, y + h - 1), Vector2(size, y + h - 1), 2.0, Color(0.12, 0.09, 0.07))
		y += h
		row += 1
	return ImageTexture.create_from_image(img)

static func metal(size := 256, tint := Color(0.55, 0.58, 0.62)) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 44
	img.fill(tint)
	for i in 900:
		var x := rng.randf() * size
		var y := rng.randf() * size
		var c := tint.darkened(rng.randf_range(0.0, 0.25))
		_line(img, Vector2(x, y), Vector2(x + rng.randf_range(-30, 30), y), 0.8, c)
	return ImageTexture.create_from_image(img)

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color, alpha: float) -> void:
	var w := img.get_width(); var h := img.get_height()
	for y in range(int(max(0, cy - r)), int(min(h, cy + r))):
		for x in range(int(max(0, cx - r)), int(min(w, cx + r))):
			var d := Vector2(x - cx, y - cy).length()
			if d <= r:
				var a := alpha * (1.0 - d / r)
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.lerp(c, a))

static func _line(img: Image, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	var W := img.get_width(); var H := img.get_height()
	for s in steps:
		var p := a.lerp(b, float(s) / steps)
		for ox in range(-int(w) , int(w) + 1):
			for oy in range(-int(w), int(w) + 1):
				if Vector2(ox, oy).length() <= w * 0.5:
					var x := int(p.x) + ox
					var y := int(p.y) + oy
					if x >= 0 and y >= 0 and x < W and y < H:
						img.set_pixel(x, y, c)
