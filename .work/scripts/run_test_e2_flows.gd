extends SceneTree

const TestScript := preload("res://test/test_e2_forced_flows_contract.gd")

func _initialize() -> void:
	var test := TestScript.new()
	root.add_child(test)
