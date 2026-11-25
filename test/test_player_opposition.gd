extends SceneTree
## P1 — governo NPC do país do jogador na oposição.
##
## 1. Com o jogador no governo, a função é inerte.
## 2. Na oposição, o NPC roda com a contingência do motor, grava o resumo do mês
##    e não repete o mesmo mês.
## 3. Decisão preparada da IA (gov_priority + executive_action) é aplicada e o
##    resumo marca `source = "ia"`.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_player_opposition.gd

const Fixture := preload("res://test/world_fixture.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const AiRuntime := preload("res://scripts/ai/ai_runtime.gd")

var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[player-opposition] " + message)

func _run() -> void:
	_player_governs()
	_opposition_contingency()
	_opposition_ai_plan()
	_finish()

func _player_governs() -> void:
	var st := Fixture.build_state()
	st["government"] = true
	Fixture.set_date(st, 2027, 2)
	var result := WorldSim.player_opposition_month(st, Fixture.countries(), Fixture.economy())
	_check(result.is_empty(), "governo do jogador não deve criar governo NPC")
	_check(not st.has("opposition_government"), "governo do jogador não deve gravar estado de oposição")

func _opposition_contingency() -> void:
	var st := Fixture.build_state()
	st["government"] = false
	Fixture.set_date(st, 2027, 2)
	var result := WorldSim.player_opposition_month(st, Fixture.countries(), Fixture.economy())
	_check(not result.is_empty(), "oposição deve criar o governo NPC")
	_check(st.get("opposition_government") is Dictionary, "resumo do governo NPC deve ir para o save")
	var saved: Dictionary = st.get("opposition_government", {})
	_check(str(saved.get("last_tick", "")) == "2027-02", "resumo deve carregar o mês")
	_check(str(saved.get("source", "")) == "contingencia", "sem IA a origem deve ser a contingência")
	_check(float(st.get("approval", 0.0)) >= 3.0 and float(st.get("approval", 100.0)) <= 92.0, "aprovação deve ficar na faixa")
	_check(float(st.get("debt", 0.0)) >= 5.0 and float(st.get("debt", 999.0)) <= 180.0, "dívida deve ficar na faixa")
	var snapshot := JSON.stringify(saved)
	var again := WorldSim.player_opposition_month(st, Fixture.countries(), Fixture.economy())
	_check(again.is_empty(), "o mesmo mês não deve rodar duas vezes")
	_check(JSON.stringify(st.get("opposition_government", {})) == snapshot, "resumo não pode mudar no mesmo mês")

func _opposition_ai_plan() -> void:
	var st := Fixture.build_state()
	st["government"] = false
	Fixture.set_date(st, 2027, 2)
	st["ai_priority_plan"] = {
		"BR|2027-02": {
			"decision": {"action": "empregos", "intensity": 0.8, "reason": "desemprego alto"},
			"source": "ia",
		},
	}
	st["ai_plan"] = {
		"executive_action|exec:BR|2027-02": {
			"decision": {"action": "discursar", "stance": "firme", "reason": "agenda do mês"},
			"source": "ia",
		},
	}
	var fake := preload("res://test/fake_ai_client.gd").new()
	var runtime := AiRuntime.new({
		"mode": "preferred",
		"active_model": "fake-ai",
		"budget": {"max_calls_per_month": 40, "per_contract": {"gov_priority": 14, "executive_action": 6}},
		"parallel": {"max_parallel": 2},
		"training_export": {"enabled": false, "only_validated": true},
	}, fake)
	var result := WorldSim.player_opposition_month(st, Fixture.countries(), Fixture.economy(), runtime)
	_check(str(result.get("source", "")) == "ia", "decisão preparada da IA deve ser aplicada pelo governo NPC")
	_check(str(result.get("policy_priority", "")) == "empregos", "prioridade da IA deve chegar ao resumo")
	_check(str(result.get("executive", "")) == "discursar", "ação do executivo da IA deve chegar ao resumo")
	var log: Array = st.get("ai_decision_log", [])
	_check(log.size() >= 2, "as duas decisões devem ser registradas no save")

func _finish() -> void:
	print("")
	print("=== governo NPC da oposição: %d checks, %d falhas ===" % [checks, failures.size()])
	for message in failures:
		print("FAIL  ", message)
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		print("FALHOU")
		quit(1)
