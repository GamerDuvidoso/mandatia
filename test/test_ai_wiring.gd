extends SceneTree
## Fase 3 — prova do fio `gov_priority` no `WorldSim.monthly`.
##
## 1. Modo `off` (padrão) contra o comportamento ANTERIOR ao fio: um oráculo
##    congelado neste arquivo replica o laço do `monthly` do commit `d77f356`,
##    sem camada de IA. Os dois estados são comparados mês a mês e o teste falha
##    na primeira divergência, mostrando o caminho da chave.
## 2. Modo `off` não chama o cliente nem cria bookkeeping de IA no estado.
## 3. Modo `preferred` pede a decisão pelo broker, guarda para o mês seguinte,
##    valida e aplica pelo applier (a prioridade muda de verdade).
## 4. Decisão inválida é rejeitada pelo validador e não chega ao estado.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_wiring.gd

const Fixture := preload("res://test/world_fixture.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const AiRuntime := preload("res://scripts/ai/ai_runtime.gd")
const FakeClient := preload("res://test/fake_ai_client.gd")
const AutonomousGovernment := preload("res://scripts/sim/autonomous_government.gd")
const CountryEconomy := preload("res://scripts/sim/country_economy_simulation.gd")
const AutonomousParty := preload("res://scripts/sim/autonomous_party_system.gd")
const AutonomousLegislature := preload("res://scripts/sim/autonomous_legislature.gd")
const ForeignElection := preload("res://scripts/sim/foreign_election_system.gd")

const MONTHS := 12

var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[ai-wiring] " + message)

func _run() -> void:
	_test_off_matches_legacy()
	_test_off_untouched()
	_test_ai_path_applies()
	_test_invalid_decision_rejected()
	_finish()

func _finish() -> void:
	print("")
	print("=== fio da IA: %d checks, %d falhas ===" % [checks, failures.size()])
	for message in failures:
		print("FAIL  ", message)
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		print("FALHOU")
		quit(1)

# ------------------------------------------------------- oráculo congelado

## Cópia do laço de `WorldSim.monthly` anterior ao fio (commit d77f356).
## Não deve ser atualizada junto com o produção: ela é a referência.
func _legacy_month(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	WorldSim.ensure(st, countries, economy)
	var world: Dictionary = st["world"]
	var year := int(st.get("date_year", 2027))
	var month := int(st.get("date_month", 1))
	var tick := "%d-%02d" % [year, month]
	if str(world.get("last_tick", "")) == tick:
		return
	var intl: Dictionary = st.get("international_state", {})
	var profiles: Dictionary = intl.get("profiles", {})
	for id in (world.get("countries", {}) as Dictionary).keys():
		var wc: Dictionary = world.countries[id]
		var profile: Variant = profiles.get(str(id), {})
		if not (profile is Dictionary) or (profile as Dictionary).is_empty():
			continue
		var base: Dictionary = wc.get("economy_base", {})
		var shock := (WorldSim._hash01(str(id) + "|" + tick) * 2.0 - 1.0) * 0.6
		var government := AutonomousGovernment.monthly(world, wc, profile, base, year, month)
		var priority := str(government.get("priority", wc.get("policy_priority", "investimento")))
		CountryEconomy.monthly(profile, base, priority, shock)
		AutonomousParty.monthly(world, wc, profile, base, year, month)
		AutonomousLegislature.monthly(world, wc, profile, base, year, month)
		WorldSim._foreign_policy(world, st, wc, profile, year, month)
		wc["months_to_election"] = int(wc.get("months_to_election", 1)) - 1
		if int(wc.months_to_election) <= 0:
			ForeignElection.run(world, st, wc, profile, year, month)
		wc["turn"] = int(wc.get("turn", 0)) + 1
		profile["approval"] = wc.get("approval", 50.0)
		profile["stability"] = wc.get("stability", 60.0)
		profile["policy_priority"] = str(wc.get("policy_priority", ""))
		world.countries[id] = wc
	world["last_tick"] = tick
	st["world"] = world
	st["world_summary"] = WorldSim.summary(st)

# ------------------------------------------------------------- comparação

func _first_diff(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		return "%s: tipo %d != %d" % [path, typeof(a), typeof(b)]
	if a is Dictionary:
		var ka: Array = (a as Dictionary).keys()
		var kb: Array = (b as Dictionary).keys()
		if ka.size() != kb.size():
			return "%s: %d chaves != %d" % [path, ka.size(), kb.size()]
		for i in ka.size():
			if str(ka[i]) != str(kb[i]):
				return "%s: ordem das chaves difere em %d (%s != %s)" % [path, i, str(ka[i]), str(kb[i])]
		for key in ka:
			var diff := _first_diff((a as Dictionary)[key], (b as Dictionary)[key], path + "." + str(key))
			if diff != "":
				return diff
		return ""
	if a is Array:
		var la: Array = a
		var lb: Array = b
		if la.size() != lb.size():
			return "%s: lista %d != %d" % [path, la.size(), lb.size()]
		for i in la.size():
			var diff := _first_diff(la[i], lb[i], "%s[%d]" % [path, i])
			if diff != "":
				return diff
		return ""
	if a is float or b is float:
		if float(a) != float(b):
			return "%s: %s != %s" % [path, str(a), str(b)]
		return ""
	if str(a) != str(b):
		return "%s: %s != %s" % [path, str(a), str(b)]
	return ""

# ------------------------------------------------------------------ testes

func _test_off_matches_legacy() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var baseline := Fixture.build_state()
	var wired := baseline.duplicate(true)
	var diverged := ""
	for i in MONTHS:
		var year := 2027 + int(i / 12)
		var month := int(i % 12) + 1
		Fixture.set_date(baseline, year, month)
		Fixture.set_date(wired, year, month)
		_legacy_month(baseline, countries, economy)
		WorldSim.monthly(wired, countries, economy)
		diverged = _first_diff(baseline, wired, "state")
		if diverged != "":
			break
	_check(diverged == "", "modo off deve reproduzir o comportamento anterior (%s)" % diverged)
	_check(int((wired.get("world", {}) as Dictionary).get("countries", {}).size()) > 0, "mundo deve ter países NPC")
	_check(str((wired.get("world", {}) as Dictionary).get("last_tick", "")) == "2027-12", "doze meses devem avançar o tick")

func _test_off_untouched() -> void:
	var st := Fixture.build_state()
	var fake := FakeClient.new()
	var runtime := AiRuntime.new({"mode": "off"}, fake)
	Fixture.set_date(st, 2027, 1)
	WorldSim.monthly(st, Fixture.countries(), Fixture.economy(), runtime)
	_check(fake.calls.is_empty(), "modo off não deve chamar o cliente de IA")
	_check(not st.has("ai_priority_plan"), "modo off não deve guardar plano de IA")
	_check(not st.has("ai_decision_log"), "modo off não deve criar log de decisões")
	_check(not st.has("ai_memory"), "modo off não deve criar memória de IA")
	_check(not runtime.is_active(), "runtime deve estar inativo em modo off")

func _test_ai_path_applies() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st_off := Fixture.build_state()
	var st_ai := st_off.duplicate(true)
	Fixture.set_date(st_off, 2027, 1)
	WorldSim.monthly(st_off, countries, economy)
	Fixture.set_date(st_off, 2027, 2)
	WorldSim.monthly(st_off, countries, economy)

	var fake := FakeClient.new()
	for i in 40:
		fake.queue("gov_priority", {"action": "austeridade", "intensity": 0.7, "reason": "dívida alta"})
	var runtime := AiRuntime.new({
		"mode": "preferred",
		"active_model": "fake-ai",
		"budget": {"max_calls_per_month": 40},
		"parallel": {"max_parallel": 2},
		"training_export": {"enabled": false, "only_validated": true},
	}, fake)
	var countries_count := int((st_ai.get("world", {}) as Dictionary).get("countries", {}).size())
	Fixture.set_date(st_ai, 2027, 1)
	WorldSim.monthly(st_ai, countries, economy, runtime)
	_check(not fake.calls.is_empty(), "modo preferred deve pedir a prioridade ao broker")
	_check(fake.calls.size() <= 40, "pedidos do mês devem caber no orçamento (%d)" % fake.calls.size())
	_check(fake.calls.size() <= countries_count + 1, "no máximo um pedido por país NPC")
	var plan: Dictionary = st_ai.get("ai_priority_plan", {})
	_check(not plan.is_empty(), "resposta da IA deve virar plano para o mês seguinte")

	Fixture.set_date(st_ai, 2027, 2)
	WorldSim.monthly(st_ai, countries, economy, runtime)
	var forced := _count_priority(st_ai, "austeridade")
	var natural := _count_priority(st_off, "austeridade")
	_check(forced >= 1, "a prioridade decidida pela IA deve chegar ao estado")
	_check(forced > natural, "modo IA deve divergir do motor quando a decisão manda (%d > %d)" % [forced, natural])
	var log: Array = st_ai.get("ai_decision_log", [])
	_check(log.size() >= 1, "decisão aplicada deve ser registrada no save")
	var first: Dictionary = log[0] if not log.is_empty() else {}
	_check(str(first.get("contract", "")) == "gov_priority", "registro deve citar o contrato")
	_check(str(first.get("source", "")) == "ia", "origem deve ser a IA")
	_check(str((first.get("applied", {}) as Dictionary).get("system", "")) == "autonomous_government", "aplicação deve passar pelo applier")
	_check(bool((first.get("validation", {}) as Dictionary).get("ok", false)), "só decisão validada deve ser aplicada")
	_check(str(first.get("stamp", "")) == "2027-02", "registro deve carregar o mês aplicado")
	_check(st_ai.has("ai_memory"), "memória curta deve persistir no save")

func _test_invalid_decision_rejected() -> void:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var st := Fixture.build_state()
	var fake := FakeClient.new()
	var runtime := AiRuntime.new({
		"mode": "preferred",
		"active_model": "fake-ai",
		"budget": {"max_calls_per_month": 40},
		"parallel": {"max_parallel": 2},
		"training_export": {"enabled": false, "only_validated": true},
	}, fake)
	# Plano envenenado: ação fora do enum permitido.
	var poisoned := {}
	for id in (st.get("world", {}) as Dictionary).countries.keys():
		poisoned["%s|2027-01" % str(id)] = {"decision": {"action": "guerra_total", "intensity": 5.0}, "source": "ia"}
	st["ai_priority_plan"] = poisoned
	Fixture.set_date(st, 2027, 1)
	WorldSim.monthly(st, countries, economy, runtime)
	_check(_count_priority(st, "guerra_total") == 0, "ação fora do enum não deve chegar ao estado")
	var log: Array = st.get("ai_decision_log", [])
	_check(log.size() >= 1, "rejeição deve ficar registrada")
	var rejected := false
	for entry in log:
		if entry is Dictionary and not bool((entry.get("validation", {}) as Dictionary).get("ok", true)):
			rejected = true
	_check(rejected, "validador deve registrar a rejeição")

func _count_priority(st: Dictionary, action: String) -> int:
	var total := 0
	var countries_map: Dictionary = (st.get("world", {}) as Dictionary).get("countries", {})
	for id in countries_map.keys():
		if str((countries_map[id] as Dictionary).get("policy_priority", "")) == action:
			total += 1
	return total
