extends Node
## Teste curto G1; não executa a suíte completa do projeto.

const Demography := preload("res://scripts/sim/demography_system.gd")

func _ready() -> void:
	var state := {"date_year": 2027, "date_month": 1, "country_id": "BR", "unemployment": 8.0, "service_index": 55.0, "services": {"habitacao": {"coverage": 50.0}}}
	var economy := {"BR": {"population": {"value": 1000000.0}}}
	Demography.init_state(state, economy)
	var initial := Demography.summary(state)
	var first := Demography.monthly(state, economy)
	var after := Demography.summary(state)
	var cohort_sum := 0.0
	for row in Demography.cohort_rows(state): cohort_sum += float(row.get("population", 0.0))
	var stable := absf(cohort_sum - float(after.get("population", 0.0))) <= 0.5
	var positive := float(after.get("population", 0.0)) > 0.0 and float(first.get("births", 0.0)) > 0.0
	var before_tick := str(after.get("last_tick", ""))
	var second := Demography.monthly(state, economy)
	var idempotent := bool(second.get("skipped", false)) and str(after.get("last_tick", "")) == before_tick
	if not stable or not positive or not idempotent or float(initial.get("population", 0.0)) <= 0.0:
		push_error("G1: invariantes demográficas falharam")
		print("PHASE_G1_DEMOGRAPHY_FAIL")
		get_tree().quit(1)
		return
	print("PHASE_G1_DEMOGRAPHY_OK")
	get_tree().quit(0)
