extends Node
## Tarefa 1 E2: regressão do tick de guerra após hostilidades.
## Não integra deslocados à demografia e não substitui a validação longa.

const Conflict := preload("res://scripts/sim/conflict_system.gd")
const E2Contract := preload("res://scripts/sim/e2_geopolitics_contract.gd")

func _military(id: String) -> Dictionary:
	return {
		"id": id, "name": id, "personnel": 100.0, "personnel_index": 35.0,
		"equipment": 45.0, "logistics": 45.0, "training": 45.0,
		"tech": 40.0, "industry": 35.0, "navy": 25.0, "air": 30.0,
		"readiness": 60.0, "mobilization": "nenhuma", "mobilized": 0.0,
	}

func _ready() -> void:
	var conflict := {
		"id": "C001", "a": "BR", "b": "AR", "a_name": "Brasil", "b_name": "Argentina",
		"status": "hostilidades", "intensity": 25.0, "front": 0.0, "months": 2,
		"casualties": {"BR": 0, "AR": 0}, "displaced": 0,
		"cost": {"BR": 0.0, "AR": 0.0}, "support": {"BR": 0.0, "AR": 0.0},
		"peace_pressure": 0.0, "ceasefire_months": 0, "frozen_months": 0,
		"history": [], "cause": "regressão E2",
	}
	var state := {
		"date_year": 2027, "date_month": 1, "country_id": "BR", "gdp": 1000000000.0,
		"debt": 60.0, "treasury": 100000.0, "economy": 2.0, "inflation": 4.5,
		"approval": 50.0, "funds": 1000.0, "government": true, "world": {"countries": {"BR": {"name": "Brasil"}, "AR": {"name": "Argentina"}}, "history": [], "news": []},
		"international_state": {"profiles": {"AR": {"name": "Argentina", "gdp": 1000000000.0, "debt": 60.0, "growth": 2.0, "inflation": 4.5, "unemployment": 8.0}}},
		"geopolitics": {"military": {"BR": _military("BR"), "AR": _military("AR")}, "conflicts": [conflict], "crises": [], "sanctions": [], "humanitarian": {}, "reconstruction": {}, "bilateral": {}, "stats": {}, "last_tick": ""},
		"social_groups": {}, "e2": {},
	}
	E2Contract.ensure(state)
	Conflict.monthly(state, [])
	var first: Dictionary = state.geopolitics.conflicts[0]
	var first_months := int(first.get("months", 0))
	var first_casualties := int(first.get("casualties", {}).get("BR", 0)) + int(first.get("casualties", {}).get("AR", 0))
	state.date_month = 2
	Conflict.monthly(state, [])
	var second: Dictionary = state.geopolitics.conflicts[0]
	var second_months := int(second.get("months", 0))
	var second_casualties := int(second.get("casualties", {}).get("BR", 0)) + int(second.get("casualties", {}).get("AR", 0))
	var progressed := second_months > first_months and second_casualties > first_casualties
	if not progressed:
		push_error("E2: _war_tick não progrediu em meses consecutivos")
		print("PHASE_E2_CONFLICT_FAIL")
		get_tree().quit(1)
		return
	print("PHASE_E2_CONFLICT_OK")
	get_tree().quit(0)
