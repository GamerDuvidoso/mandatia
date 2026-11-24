extends Node
## Validação de horizonte longo da Fase G1.
## Executa 240 meses apenas quando chamado explicitamente; não é a suíte completa.

const Demography := preload("res://scripts/sim/demography_system.gd")

func _ready() -> void:
	var state := {
		"date_year": 2027, "date_month": 1, "country_id": "BR",
		"unemployment": 8.0, "service_index": 55.0,
		"services": {"habitacao": {"coverage": 50.0}},
	}
	var economy := {"BR": {"population": {"value": 1000000.0}}}
	Demography.init_state(state, economy)
	var initial := Demography.summary(state)
	var initial_population := float(initial.get("population", 0.0))
	var min_population := initial_population
	var max_population := initial_population
	var max_dependency := 0.0
	var min_urban_share := 1.0
	var max_urban_share := 0.0
	var previous_urban_share := float(initial.get("urban_share", 0.0))
	var failures: Array = []
	for month in 240:
		state["date_month"] = int(state.get("date_month", 1)) + 1
		if int(state.date_month) > 12:
			state["date_month"] = 1
			state["date_year"] = int(state.get("date_year", 2027)) + 1
		Demography.monthly(state, economy)
		var data := Demography.summary(state)
		var population := float(data.get("population", 0.0))
		var cohorts: Dictionary = data.get("cohorts", {}) if data.get("cohorts") is Dictionary else {}
		var cohort_sum := 0.0
		for key in Demography.COHORT_KEYS:
			cohort_sum += maxf(0.0, float(cohorts.get(key, 0.0)))
		min_population = minf(min_population, population)
		max_population = maxf(max_population, population)
		max_dependency = maxf(max_dependency, float(data.get("dependency_ratio", 0.0)))
		min_urban_share = minf(min_urban_share, float(data.get("urban_share", 0.0)))
		max_urban_share = maxf(max_urban_share, float(data.get("urban_share", 0.0)))
		if float(data.get("urban_share", 0.0)) + 0.000001 < previous_urban_share: failures.append("urbanização retrocedeu sem causa")
		previous_urban_share = float(data.get("urban_share", 0.0))
		if population <= 0.0: failures.append("população não positiva")
		if absf(cohort_sum - population) > 0.5: failures.append("coortes não reconciliadas")
		if float(data.get("urban_share", -1.0)) < 0.0 or float(data.get("urban_share", 2.0)) > 1.0: failures.append("urbanização fora do intervalo")
		if float(data.get("dependency_ratio", -1.0)) < 0.0 or float(data.get("dependency_ratio", 1000.0)) > 300.0: failures.append("dependência fora do intervalo")
		if str(data.get("source_status", "")) != "catalog_anchor": failures.append("rastreabilidade da âncora perdida")
		if failures.size() > 0: break
	var growth := max_population / maxf(1.0, initial_population)
	var urban_monotonic := max_urban_share >= min_urban_share
	var bounded := growth < 1.35 and min_population > initial_population * 0.85 and max_dependency < 300.0
	if failures.is_empty() and bounded and urban_monotonic:
		print("PHASE_G1_LONG_HORIZON_OK months=240 growth=%.4f urban=[%.4f,%.4f] dependency_max=%.2f" % [growth, min_urban_share, max_urban_share, max_dependency])
		get_tree().quit(0)
		return
	push_error("G1 horizonte longo falhou: %s" % ", ".join(PackedStringArray(failures)))
	print("PHASE_G1_LONG_HORIZON_FAIL")
	get_tree().quit(1)
