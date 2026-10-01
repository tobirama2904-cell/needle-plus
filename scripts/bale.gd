class_name Bale
extends Node3D
# Тюк сена — груз, который едет по конвейеру.

func _ready() -> void:
	var m := Fab.mat_tex(Tex.straw_texture())
	m.uv1_scale = Vector3(2, 2, 2)
	Fab.box(self, "bale", Vector3.ZERO, Vector3(0.34, 0.22, 0.26), m)
	Fab.box(self, "ring", Vector3(0, 0.02, 0), Vector3(0.36, 0.05, 0.28), Fab.mat(Color(0.25, 0.3, 0.35), 0.6, 0.4))
