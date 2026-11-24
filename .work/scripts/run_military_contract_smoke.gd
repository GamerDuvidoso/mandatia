extends SceneTree

const Military := preload("res://scripts/sim/military_system.gd")

var failures: Array[String] = []
var checks := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _state(with_maintenance: bool) -> Dictionary:
	var program: Array = []
	if with_maintenance:
		program.append({
			"id": "equip-1", "item": "equipamento", "label": "Equipamento",
			"months_left": 1, "months_total": 1, "effects": {"equipment": 7.0},
			"maintenance": 0.12, "status": "em aquisição"
		})
	return {
		"country_id": "BR", "gdp": 2000000.0, "date_year": 2027, "date_month": 1,
		"government": true, "treasury": 100000.0,
		"geopolitics": {"military": {"BR": {
			"id": "BR", "base_share": 1.2, "defense_share": 1.2, "budget_billions": 0.0,
			"equipment": 38.0, "personnel_index": 25.0, "logistics": 40.0,
			"readiness": 55.0, "training": 42.0, "tech": 36.0, "industry": 28.0,
			"navy": 24.0, "air": 28.0, "procurement": program,
			"maintenance_load": 0.0, "stockpile_days": 30
		}}}
	}

func _initialize() -> void:
	var calm := _state(false)
	var threatened := _state(false)
	var calm_result := Military.monthly(calm, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 0.0, 2027, 1)
	var threat_result := Military.monthly(threatened, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 60.0, 2027, 1)
	_check(float(threat_result.get("share", 0.0)) > float(calm_result.get("share", 0.0)), "ameaça maior deveria elevar a trajetória do gasto defensivo")
	_check(float(threatened.geopolitics.military.BR.defense_share) > float(calm.geopolitics.military.BR.defense_share), "ameaça deveria alterar defense_share")
	threatened.geopolitics["conflicts"] = [{"a": "BR", "b": "AR", "status": "hostilidades", "intensity": 60.0}]
	_check(absf(Military.threat_for(threatened, "BR") - 60.0) <= 0.01, "ameaça deveria ser derivada do conflito ativo")

	var maintained := _state(true)
	var baseline := _state(false)
	Military.monthly(maintained, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 0.0, 2027, 1)
	Military.monthly(baseline, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 0.0, 2027, 1)
	_check((maintained.geopolitics.military.BR.procurement as Array).is_empty(), "aquisição entregue não deveria permanecer na fila")
	_check(float(maintained.geopolitics.military.BR.maintenance_load) > 0.0, "aquisição entregue deveria registrar carga de manutenção")
	var maintained_result := Military.monthly(maintained, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 0.0, 2027, 2)
	var baseline_result := Military.monthly(baseline, "BR", {"debt": 60.0, "growth": 2.0, "inflation": 4.5}, false, 0.0, 2027, 2)
	_check(float(maintained_result.get("share", 0.0)) > float(baseline_result.get("share", 0.0)), "carga de manutenção deveria pressionar gradualmente o esforço defensivo")

	if failures.is_empty():
		print("MILITARY_SMOKE_PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("MILITARY_SMOKE: " + failure)
		print("MILITARY_SMOKE_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
