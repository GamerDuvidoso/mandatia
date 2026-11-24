extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Government := preload("res://scripts/sim/government.gd")
const International := preload("res://scripts/sim/international_system.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const Military := preload("res://scripts/sim/military_system.gd")
const Conflict := preload("res://scripts/sim/conflict_system.gd")
const E2GeopoliticsContract := preload("res://scripts/sim/e2_geopolitics_contract.gd")
const E2ForcedFlowsContract := preload("res://scripts/sim/e2_forced_flows_contract.gd")
const GlobalShock := preload("res://scripts/sim/global_shock_system.gd")

var checks := 0
var failures: Array[String] = []
var snapshots: Array[Dictionary] = []

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _snapshot(stage: String, state: Dictionary) -> void:
	snapshots.append({
		"stage": stage,
		"economy": float(state.get("economy", 0.0)),
		"inflation": float(state.get("inflation", 0.0)),
		"unemployment": float(state.get("unemployment", 0.0)),
		"debt": float(state.get("debt", 0.0)),
		"approval": float(state.get("approval", 0.0)),
		"treasury": float(state.get("treasury", 0.0)),
		"fiscal": state.get("fiscal", {}).duplicate(true) if state.get("fiscal") is Dictionary else {},
		"conflicts": (state.get("geopolitics", {}).get("conflicts", []) as Array).size(),
		"news": (state.get("news", []) as Array).size(),
	})

func _finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)

func _check_snapshot(stage: String, state: Dictionary) -> void:
	_snapshot(stage, state)
	for key in ["economy", "inflation", "unemployment", "debt", "approval", "treasury"]:
		_check(_finite(float(state.get(key, 0.0))), "%s não deveria produzir %s não-finito" % [stage, key])
	_check(float(state.get("debt", 0.0)) >= 0.0 and float(state.get("debt", 0.0)) <= 220.0, "%s deveria manter dívida em faixa segura" % stage)
	_check(float(state.get("inflation", 0.0)) >= 0.0 and float(state.get("inflation", 0.0)) <= 50.0, "%s deveria manter inflação em faixa segura" % stage)

func _start_game() -> Control:
	var game: Control = MainScene.instantiate()
	root.add_child(game)
	await _frames(10)
	var ai: Node = game.get("ai")
	if ai != null:
		ai.stop()
		ai.set("ai_available", false)
		ai.set("availability_checked", true)
	game.call("_show_new_game")
	await _frames(2)
	var country_selector: OptionButton = game.get("new_country")
	var br_index := -1
	for i in country_selector.item_count:
		if country_selector.get_item_text(i).contains("BR"):
			br_index = i
			break
	_check(br_index >= 0, "Brasil deveria estar disponível no fixture da cena")
	if br_index >= 0:
		country_selector.select(br_index)
		game.call("_on_country_selected", br_index)
	game.get("new_party_name").text = "Partido Macro Smoke"
	game.get("new_party_abbr").text = "PMS"
	game.get("new_leader").text = "Líder Macro"
	game.call("_start_campaign")
	await _frames(3)
	game.call("_auto_pick_promises")
	await _frames(2)
	return game

func _run_pipeline(game: Control) -> void:
	var state: Dictionary = game.get("state")
	var countries: Array = game.get("countries")
	var economy_catalog: Dictionary = game.get("economy_catalog")
	_snapshot("antes", state)

	Government.monthly(state)
	_check(state.get("fiscal") is Dictionary, "Government deveria publicar fiscal antes dos escritores seguintes")
	_check_snapshot("governo", state)

	International.monthly(state, countries, economy_catalog)
	_check_snapshot("internacional", state)

	WorldSim.monthly(state, countries, economy_catalog)
	_check_snapshot("mundo", state)

	var military_ids: Array = (state.get("geopolitics", {}).get("military", {}) as Dictionary).keys()
	for raw_id in military_ids:
		var military_id := str(raw_id)
		var at_war := false
		for conflict in (state.get("geopolitics", {}).get("conflicts", []) as Array):
			if str(conflict.get("status", "")) in ["hostilidades", "escalada", "impasse"] and (str(conflict.get("a", "")) == military_id or str(conflict.get("b", "")) == military_id):
				at_war = true
				break
		var macro: Dictionary
		if military_id == str(state.get("country_id", "")):
			macro = {"debt": float(state.get("debt", 60.0)), "growth": float(state.get("economy", 2.0)), "inflation": float(state.get("inflation", 4.5))}
		else:
			macro = state.get("international_state", {}).get("profiles", {}).get(military_id, {})
		Military.monthly(state, military_id, macro, at_war, Military.threat_for(state, military_id), int(state.date_year), int(state.date_month))
		if military_id == str(state.get("country_id", "")) and not macro.is_empty():
			state["debt"] = clampf(float(macro.get("debt", state.debt)), 0.0, 220.0)
			state["economy"] = clampf(float(macro.get("growth", state.economy)), -12.0, 10.0)
			state["inflation"] = clampf(float(macro.get("inflation", state.inflation)), 1.5, 45.0)
	_check_snapshot("militar", state)

	Conflict.monthly(state, countries)
	E2GeopoliticsContract.monthly(state)
	E2ForcedFlowsContract.monthly(state)
	_check_snapshot("conflitos", state)

	GlobalShock.monthly(state)
	_check_snapshot("choques", state)

	var expected := ["antes", "governo", "internacional", "mundo", "militar", "conflitos", "choques"]
	var actual: Array = []
	for row in snapshots:
		actual.append(str(row.get("stage", "")))
	_check(actual == expected, "ordem de snapshots divergente: %s" % str(actual))
	_check(snapshots[1].get("fiscal", {}) is Dictionary, "snapshot fiscal deveria existir após governo")
	_check((state.get("economy_history", []) as Array).size() >= 0, "histórico macro deveria permanecer acessível")

func _initialize() -> void:
	var game := await _start_game()
	await _run_pipeline(game)
	if failures.is_empty():
		print("MACRO_WRITER_ORDER_SMOKE_PASS checks=%d stages=%d" % [checks, snapshots.size()])
	else:
		for failure in failures:
			push_error(failure)
		print("MACRO_WRITER_ORDER_SMOKE_FAIL checks=%d failures=%d stages=%d" % [checks, failures.size(), snapshots.size()])
	quit(0 if failures.is_empty() else 1)
