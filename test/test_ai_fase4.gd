extends SceneTree
## Fase 4 — prova dos cinco atores novos na ordem causal do mês.
##
## 1. Modo `off`: mercado, banco central, mídia, executivo NPC e judiciário
##    rodam com a contingência do motor e nenhum estado de IA é criado.
## 2. Determinismo: duas execuções idênticas produzem o mesmo hash.
## 3. Decisão preparada e validada chega ao estado só pelo override do applier.
## 4. O motor recusa o incoerente: veto sem projeto, caso inexistente.
## 5. G4: cliente que falha produz estado final idêntico ao modo `off`.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_fase4.gd

const Fixture := preload("res://test/world_fixture.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const AiRuntime := preload("res://scripts/ai/ai_runtime.gd")
const FakeClient := preload("res://test/fake_ai_client.gd")
const Broker := preload("res://scripts/ai/decision_broker.gd")
const MarketSystem := preload("res://scripts/sim/market_system.gd")
const CentralBankSystem := preload("res://scripts/sim/central_bank.gd")
const MediaSystem := preload("res://scripts/sim/media_system.gd")
const ExecutiveNPC := preload("res://scripts/sim/executive_npc.gd")
const JudiciarySystem := preload("res://scripts/sim/judiciary_system.gd")

const MONTHS := 6

var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[ai-fase4] " + message)

func _run() -> void:
	_test_off_runs_actors()
	_test_determinism()
	_test_market_decision()
	_test_central_bank_decision()
	_test_media_frame()
	_test_executive_veto_needs_bill()
	_test_court_needs_case()
	_test_failed_ai_matches_off()
	_finish()

func _finish() -> void:
	print("")
	print("=== Fase 4: %d checks, %d falhas ===" % [checks, failures.size()])
	for message in failures:
		print("FAIL  ", message)
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		print("FALHOU")
		quit(1)

# ----------------------------------------------------------------- helpers

func _config() -> Dictionary:
	return {
		"mode": "preferred",
		"active_model": "fake-ai",
		"budget": {"max_calls_per_month": 40},
		"parallel": {"max_parallel": 2},
		"training_export": {"enabled": false, "only_validated": true},
	}

func _plan(st: Dictionary, key: String, decision: Dictionary) -> void:
	var raw: Variant = st.get("ai_plan", {})
	var plan: Dictionary = raw if raw is Dictionary else {}
	plan[key] = {
		"decision": decision.duplicate(true),
		"source": "ia",
		"model": "fake-ai",
		"request_hash": "",
		"input": "{}",
		"output": "{}",
	}
	st["ai_plan"] = plan

func _profile(st: Dictionary, country: String) -> Dictionary:
	var raw: Variant = st.get("international_state", {})
	if not (raw is Dictionary):
		return {}
	var profiles: Variant = (raw as Dictionary).get("profiles", {})
	if not (profiles is Dictionary):
		return {}
	var row: Variant = (profiles as Dictionary).get(country, {})
	return row if row is Dictionary else {}

func _project(st: Dictionary) -> String:
	return Broker.hash_context({
		"world": st.get("world", {}),
		"international_state": st.get("international_state", {}),
		"market": st.get("market", {}),
		"central_bank": st.get("central_bank", {}),
		"judiciary": st.get("judiciary", {}),
		"executive": st.get("executive", {}),
		"media": st.get("media", {}),
	})

func _run_months(st: Dictionary, months: int, runtime: Object) -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	for i in months:
		Fixture.set_date(st, 2027 + int(i / 12), int(i % 12) + 1)
		WorldSim.monthly(st, countries, economy, runtime)

func _log_has(st: Dictionary, contract: String) -> bool:
	var log: Variant = st.get("ai_decision_log", [])
	if not (log is Array):
		return false
	for raw in log:
		if raw is Dictionary and str((raw as Dictionary).get("contract", "")) == contract:
			return true
	return false

# ------------------------------------------------------------------ testes

func _test_off_runs_actors() -> void:
	var st := Fixture.build_state()
	var fake := FakeClient.new()
	var runtime := AiRuntime.new({"mode": "off"}, fake)
	Fixture.set_date(st, 2027, 1)
	WorldSim.monthly(st, Fixture.countries(), Fixture.economy(), runtime)
	var country := Fixture.sample_country(st)
	var market := MarketSystem.summary(st, country)
	_check(not market.is_empty(), "mercado deve registrar o mês mesmo em modo off")
	_check(str(market.get("source", "")) == "contingencia", "modo off: mercado usa contingência")
	_check(float(market.get("risk_premium_bp", 0.0)) > 0.0, "modo off: prêmio de risco deve ser calculado")
	var bank := CentralBankSystem.summary(st, country)
	_check(not bank.is_empty(), "banco central deve registrar o mês mesmo em modo off")
	_check(float(bank.get("rate", 0.0)) > 0.0, "modo off: taxa básica deve existir")
	var media := MediaSystem.summary(st, country)
	_check(not media.is_empty(), "mídia deve registrar o mês mesmo em modo off")
	_check(bool(media.get("applied", false)), "mídia deve fechar o mês com o efeito aplicado")
	var executive := ExecutiveNPC.summary(st, country)
	_check(not (executive.get("last_action", {}) as Dictionary).is_empty(), "executivo NPC deve agir todo mês")
	_check(fake.calls.is_empty(), "modo off não deve chamar o cliente de IA")
	_check(not st.has("ai_plan"), "modo off não deve guardar plano dos atores")

func _test_determinism() -> void:
	var a := Fixture.build_state()
	var b := Fixture.build_state()
	_run_months(a, MONTHS, AiRuntime.new({"mode": "off"}))
	_run_months(b, MONTHS, AiRuntime.new({"mode": "off"}))
	_check(_project(a) == _project(b), "dois mundos idênticos devem produzir o mesmo hash")

func _test_market_decision() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var off := st.duplicate(true)
	var runtime := AiRuntime.new(_config(), FakeClient.new())
	var country := Fixture.sample_country(st)
	Fixture.set_date(st, 2027, 1)
	Fixture.set_date(off, 2027, 1)
	_plan(st, "market_mood|market:%s|2027-01" % country, {
		"sentiment": -0.8,
		"risk_premium_bp": 320,
		"fx_pressure_pct": 6.0,
		"capital_flow": "saida",
		"business": {"invest": "reduzir", "layoffs": "muitas"},
		"reason": "dólar e dívida",
	})
	WorldSim.monthly(st, countries, economy, runtime)
	WorldSim.monthly(off, countries, economy)
	var row := MarketSystem.summary(st, country)
	_check(is_equal_approx(float(row.get("risk_premium_bp", 0.0)), 320.0), "prêmio decidido pela IA deve chegar ao estado")
	_check(str(row.get("source", "")) == "ia", "mercado deve registrar a origem IA")
	var growth_ai := float(_profile(st, country).get("growth", 0.0))
	var growth_off := float(_profile(off, country).get("growth", 0.0))
	_check(growth_ai < growth_off, "prêmio maior deve reduzir o crescimento contra o modo off")
	_check(_log_has(st, "market_mood"), "decisão de mercado deve ser registrada no save")

func _test_central_bank_decision() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var runtime := AiRuntime.new(_config(), FakeClient.new())
	var country := Fixture.sample_country(st)
	Fixture.set_date(st, 2027, 1)
	_plan(st, "central_bank|central_bank:%s|2027-01" % country, {
		"rate_move_bp": 150,
		"stance": "hawkish",
		"statement": "Inflação fora da meta.",
		"reason": "inflação acima da meta",
	})
	WorldSim.monthly(st, countries, economy, runtime)
	var bank := CentralBankSystem.summary(st, country)
	_check(is_equal_approx(float(bank.get("rate", 0.0)), 8.0), "alta de 150 p.b. deve levar a taxa de 6,5%% para 8,0%%")
	_check(str(bank.get("stance", "")) == "hawkish", "postura hawkish deve ser registrada")
	_check(str(bank.get("source", "")) == "ia", "banco central deve registrar a origem IA")
	# Efeito do motor medido no próprio módulo: taxa acima da neutra desacelera
	# atividade e preços no mês, sem depender da reação política do país.
	var unit_ai := {}
	var unit_off := {}
	var base := {"potential_growth": 2.0, "inflation_anchor": 3.0, "natural_unemployment": 7.0, "initial_debt": 60.0}
	var wc_unit := {"id": country, "approval": 50.0, "stability": 60.0}
	var ai_profile := {"growth": 2.0, "inflation": 3.0, "debt": 60.0}
	var off_profile := {"growth": 2.0, "inflation": 3.0, "debt": 60.0}
	CentralBankSystem.monthly(unit_ai, wc_unit, ai_profile, base, 2027, 1, {"rate_move_bp": 150, "stance": "hawkish", "statement": "x", "reason": "inflação acima da meta"})
	CentralBankSystem.monthly(unit_off, wc_unit, off_profile, base, 2027, 1, {})
	_check(float(ai_profile["growth"]) < float(off_profile["growth"]), "juro acima da neutra deve reduzir o crescimento")
	_check(float(ai_profile["inflation"]) < float(off_profile["inflation"]), "juro acima da neutra deve reduzir a inflação")
	_check(_log_has(st, "central_bank"), "decisão do banco central deve ser registrada no save")

func _test_media_frame() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var off := st.duplicate(true)
	var runtime := AiRuntime.new(_config(), FakeClient.new())
	var country := Fixture.sample_country(st)
	Fixture.set_date(st, 2027, 1)
	Fixture.set_date(off, 2027, 1)
	_plan(st, "media_coverage|media:%s|2027-01" % country, {
		"frame": "escandalo",
		"bias": -0.9,
		"reason": "cobertura negativa",
	})
	WorldSim.monthly(st, countries, economy, runtime)
	WorldSim.monthly(off, countries, economy)
	var media := MediaSystem.summary(st, country)
	_check(str(media.get("frame", "")) == "escandalo", "enquadramento decidido deve chegar ao estado")
	_check(str(media.get("source", "")) == "ia", "mídia deve registrar a origem IA")
	var wc_ai: Dictionary = (st.get("world", {}) as Dictionary).get("countries", {}).get(country, {})
	var wc_off: Dictionary = (off.get("world", {}) as Dictionary).get("countries", {}).get(country, {})
	_check(float(wc_ai.get("approval", 0.0)) < float(wc_off.get("approval", 0.0)), "viés negativo deve custar aprovação")

func _test_executive_veto_needs_bill() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var runtime := AiRuntime.new(_config(), FakeClient.new())
	var country := Fixture.sample_country(st)
	Fixture.set_date(st, 2027, 1)
	# Sem projeto aprovado no mês, o veto é incoerente e não pode ser aplicado.
	_plan(st, "executive_action|exec:%s|2027-01" % country, {
		"action": "vetar",
		"target_id": "b_inexistente",
		"stance": "firme",
		"reason": "veto sem projeto",
	})
	WorldSim.monthly(st, countries, economy, runtime)
	var executive := ExecutiveNPC.summary(st, country)
	var last: Dictionary = executive.get("last_action", {}) if executive.get("last_action") is Dictionary else {}
	_check(str(last.get("action", "")) != "vetar", "veto sem projeto aprovado deve ser recusado pelo motor")
	var wc: Dictionary = (st.get("world", {}) as Dictionary).get("countries", {}).get(country, {})
	_check(not (wc.get("vetoed_bills", []) is Array) or (wc.get("vetoed_bills", []) as Array).is_empty(), "nenhum projeto pode ser vetado sem ter passado")

func _test_court_needs_case() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var runtime := AiRuntime.new(_config(), FakeClient.new())
	var country := Fixture.sample_country(st)
	Fixture.set_date(st, 2027, 1)
	_plan(st, "court_ruling|court:%s|2027-01" % country, {
		"case_id": "c_999",
		"ruling": "suspender",
		"vote_split": [9, 6],
		"reason": "caso que não existe",
	})
	WorldSim.monthly(st, countries, economy, runtime)
	var judiciary := JudiciarySystem.summary(st, country)
	_check(not judiciary.is_empty(), "judiciário deve registrar o mês")
	_check((judiciary.get("last_ruling", {}) as Dictionary).is_empty(), "tribunal só julga caso existente")

func _test_failed_ai_matches_off() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var reference := Fixture.build_state()
	_run_months(reference, MONTHS, AiRuntime.new({"mode": "off"}))
	var expected := _project(reference)
	for mode in ["invalid", "empty", "offline"]:
		var fake := FakeClient.new()
		fake.mode = mode
		var st := Fixture.build_state()
		_run_months(st, MONTHS, AiRuntime.new(_config(), fake))
		_check(_project(st) == expected, "G4: cliente %s deve produzir o mesmo estado do modo off" % mode)
