extends Node
## Teste direcionado da fundação G; não executa a suíte completa do projeto.

const Demography := preload("res://scripts/sim/demography_system.gd")
const PhaseGContract := preload("res://scripts/sim/phase_g_contract.gd")

func _ready() -> void:
	var state := {
		"date_year": 2027,
		"date_month": 1,
		"country_id": "BR",
		"unemployment": 8.0,
		"service_index": 55.0,
		"services": {"habitacao": {"coverage": 50.0}},
		"phase_g": {"schema_version": 0, "legacy_marker": "preservar"},
	}
	var economy := {"BR": {"population": {"value": 1000000.0}}}
	Demography.init_state(state, economy)
	var population_before := float(state.demography.population)
	PhaseGContract.ensure(state)
	var migrated := PhaseGContract.summary(state)
	var additive := str(migrated.get("legacy_marker", "")) == "preservar"
	var schema_ok := int(migrated.get("schema_version", 0)) == 1
	var ref := PhaseGContract.population_reference(state)
	var ref_ok := str(ref.get("path", "")) == "state.demography.population" and is_equal_approx(float(ref.get("value", 0.0)), population_before)
	var first := PhaseGContract.monthly(state)
	var last_tick := str(state.phase_g.last_tick)
	var second := PhaseGContract.monthly(state)
	var idempotent := not bool(first.get("skipped", false)) and bool(second.get("skipped", false)) and str(second.get("tick", "")) == last_tick
	var population_unchanged := is_equal_approx(float(state.demography.population), population_before)
	var provenance_ok := state.phase_g.provenance.get("population", {}).get("source", "") == "state.demography"
	if not additive or not schema_ok or not ref_ok or not idempotent or not population_unchanged or not provenance_ok:
		push_error("G0: contrato phase_g falhou")
		print("PHASE_G0_CONTRACT_FAIL")
		get_tree().quit(1)
		return
	print("PHASE_G0_CONTRACT_OK")
	get_tree().quit(0)
