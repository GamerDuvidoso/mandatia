extends Node
## Tarefa 2 E2/E: contrato de fluxos forçados sem mutação demográfica.
## O teste é direcionado e não substitui a validação integrada do fechamento mensal.

const FlowsContract := preload("res://scripts/sim/e2_forced_flows_contract.gd")

func _ready() -> void:
	var state := {
		"date_year": 2027,
		"date_month": 1,
		"country_id": "BR",
		"demography": {"population": 1000.0, "last_tick": ""},
		"geopolitics": {
			"humanitarian_events": [
				{"event_id": "HF-C001-2027-01", "date": "2027-01", "origin": "BR", "destination": "AR", "category": "deslocamento_forcado_beligerante", "quantity": 120.0, "source_conflict_id": "C001", "provenance": {"source": "test", "status": "model"}},
				{"event_id": "HF-C002-2027-01", "date": "2027-01", "origin": "BR", "destination": "", "category": "deslocamento_forcado_beligerante", "quantity": 80.0, "source_conflict_id": "C002", "provenance": {"source": "test", "status": "model"}},
			]
		},
		"e2": {},
	}
	var population_before := float(state.demography.population)
	FlowsContract.ensure(state)
	var first := FlowsContract.monthly(state)
	if int(first.get("flows_recorded", 0)) != 2:
		_fail("dois eventos válidos deveriam gerar dois fluxos")
		return
	if float(state.demography.population) != population_before:
		_fail("contrato E2/E não pode alterar a demografia")
		return
	if int(state.e2.humanitarian_flows.reconciliation.unreconciled) != 1:
		_fail("evento sem destino deveria permanecer não reconciliado")
		return
	var same_tick := FlowsContract.monthly(state)
	if not bool(same_tick.get("skipped", false)):
		_fail("last_tick deveria impedir reaplicação no mesmo mês")
		return
	state.date_month = 2
	state.geopolitics.humanitarian_events.append({"event_id": "HF-C003-2027-02", "date": "2027-02", "origin": "AR", "destination": "BR", "category": "reassentamento_forcado", "quantity": 50.0, "source_conflict_id": "C003", "provenance": {"source": "test", "status": "model"}})
	var second := FlowsContract.monthly(state)
	if int(second.get("flows_recorded", 0)) != 1 or int(second.get("duplicates_ignored", 0)) < 2:
		_fail("deduplicação incremental não foi aplicada")
		return
	if state.e2.humanitarian_flows.flows.size() != 3:
		_fail("ledger deveria conter três fluxos únicos")
		return
	print("PHASE_E2_FORCED_FLOWS_OK")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("E2/E: " + message)
	print("PHASE_E2_FORCED_FLOWS_FAIL")
	get_tree().quit(1)
