extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Control = MainScene.instantiate()
	root.add_child(game)
	for _i in 12:
		await process_frame
	var state: Dictionary = game.get("state")
	state["started"] = true
	state["tutorial_done"] = true
	state["term_months_served"] = 8
	state["approval"] = 20.0
	state["funds"] = 10000.0
	state["credibility"] = 60.0
	state["lower_house_seats"] = 40
	state["chamber_seats"] = 100
	state["majority"] = 51
	state["seat_map"] = {"P": 40, "Q": 35, "R": 25}
	state["coalition_partners"] = ["Q"]
	state["coalition_seats"] = 75
	state["government"] = true
	state["news"] = []
	game.call("_motion_of_censure")
	await process_frame
	_check(float(state.get("funds", 0.0)) == 7000.0, "moção deveria cobrar o custo mesmo quando rejeitada")
	_check(float(state.get("credibility", 0.0)) == 50.0, "moção deveria cobrar 10 pontos de credibilidade mesmo quando rejeitada")
	_check(bool(state.get("government", false)), "coalizão com 75/100 cadeiras deveria sobreviver à censura")
	_check(int(state.get("coalition_seats", 0)) == 75, "censura rejeitada não deveria alterar a coalizão")
	_check(float(state.get("approval", 0.0)) == 23.0, "censura rejeitada deveria aplicar o efeito político previsto")

	if failures.is_empty():
		print("CENSURE_SMOKE_PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("CENSURE_SMOKE: " + failure)
		print("CENSURE_SMOKE_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
