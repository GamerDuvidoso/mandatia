extends SceneTree

const Coalition := preload("res://scripts/sim/coalition.gd")
const Legislature := preload("res://scripts/sim/legislature.gd")

var failures: Array[String] = []
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	var deal := Coalition.minimum_winning(
		{"P": 90, "Q": 70, "R": 40, "S": 30},
		{"P": 0.0, "Q": 0.1, "R": 0.8, "S": -0.8},
		"P", 116)
	_check(not deal.is_empty(), "coalizão vencedora deveria ser encontrada")
	_check((deal.get("partners", []) as Array).size() == 1, "menor coalizão deveria usar apenas um parceiro")
	_check(str((deal.get("partners", []) as Array)[0]) == "Q", "parceiro mais próximo deveria ser Q")
	_check(int(deal.get("seats", 0)) >= 116, "coalizão deveria atingir a maioria")

	var ordinary := Legislature.bill("investment")
	var ordinary_seats := {"P": 80, "Q": 70, "R": 50}
	var ordinary_axes := {"P": -0.3, "Q": -0.1, "R": 0.8}
	var ordinary_vote := Legislature.vote(ordinary, ordinary_seats, ordinary_axes, ["Q"], 75.0)
	_check(int(ordinary_vote.get("ayes", 0)) + int(ordinary_vote.get("nayes", 0)) + int(ordinary_vote.get("abstain", 0)) == 200, "votação ordinária deveria conservar todas as cadeiras")
	_check(Legislature.passes(ordinary, ordinary_vote, 200), "investimento deveria passar com apoio da coalizão")

	var constitutional := Legislature.bill("pension")
	var hostile_seats := {"P": 40, "Q": 35, "R": 25}
	var hostile_axes := {"P": -1.0, "Q": -0.8, "R": -0.6}
	var hostile_vote := Legislature.vote(constitutional, hostile_seats, hostile_axes, [], 20.0)
	_check(not Legislature.passes(constitutional, hostile_vote, 100), "constitucional hostil deveria falhar sem 3/5")
	_check(Legislature.passes(constitutional, {"ayes": 60, "nayes": 25, "abstain": 15}, 100), "constitucional deveria passar com 3/5 e maioria favorável")

	if failures.is_empty():
		print("GOVERNMENT_SMOKE_PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("GOVERNMENT_SMOKE: " + failure)
		print("GOVERNMENT_SMOKE_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
