extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	_check(str(ProjectSettings.get_setting("application/config/name")).begins_with("Mandatia"), "exported identity")
	_check(FileAccess.file_exists("res://config/countries.json"), "pack file: config/countries.json")
	_check(FileAccess.file_exists("res://config/ai_examples.json"), "pack file: config/ai_examples.json")
	_check(FileAccess.file_exists("res://assets/template/fonts/Figtree-VF.subset.woff2"), "pack file: fontes do tema")
	_check(ResourceLoader.exists("res://config/countries.json"), "pack resource: config/countries.json")
	_check(ResourceLoader.exists("res://scripts/sim/election.gd"), "pack resource: scripts/sim/election.gd")
	_check(not ResourceLoader.exists("res://test/test_suite.tscn"), "test scene excluded")
	_check(not ResourceLoader.exists("res://tools/capture_native.gd"), "native capture tool excluded")
	_check(not root.has_node("GlobalLeaderboard"), "no dormant network autoload")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(str(main.get("screen")) == "menu", "pack boots to title")
		_check(not main.has_method("_open_tuning"), "release tuning entry point excluded")
		main.call("_show_new_game")
		await process_frame
		_check(main.get("new_party_name") != null, "pack exposes campaign setup")
		var state: Dictionary = main.get("state")
		_check(state.get("region_support", []).size() == 8, "pack keeps eight regions")
		main.call("_start_campaign")
		await process_frame
		_check(bool((main.get("state") as Dictionary).get("started", false)), "pack starts campaign")
		main.call("_advance_month")
		_check(int((main.get("state") as Dictionary).get("date_month", 0)) == 2, "pack advances month")
		main.queue_free()
		await process_frame
	if failures.is_empty():
		print("[exported-pack] PASS: identity, resources, boot, campaign and month advance")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[exported-pack] " + failure)
		quit(1)

func _check(condition: bool, context: String) -> void:
	if not condition and context not in failures:
		failures.append(context)
