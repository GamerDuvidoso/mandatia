extends SceneTree

const TestScript := preload("res://test/test_phase_g_demography.gd")

func _initialize() -> void:
	var test := TestScript.new()
	root.add_child(test)
