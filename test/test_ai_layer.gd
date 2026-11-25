extends SceneTree
## Fase 1/2 — teste headless da camada de decisão.
##
## Não precisa de Ollama, de cena nem de rede. Verifica:
##   - catálogo carregado e igual aos valores congelados dos 4 contratos antigos;
##   - prompt dos contratos antigos idêntico ao fixture (regressão da Fase 2);
##   - contexto compacto, faixas e corte por orçamento;
##   - validador (enum, faixa com clamp, chave inesperada, event_v2, notícia);
##   - aplicador (plano e diff) sem escrever estado;
##   - memória curta por ator;
##   - registro no save e coleta de dataset;
##   - broker (fila por prioridade, orçamento, pré-cálculo);
##   - FakeAIClient (fixture, timeout, offline).
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_layer.gd

const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const Catalog := preload("res://scripts/ai/decision_catalog.gd")
const ContextBuilder := preload("res://scripts/ai/context_builder.gd")
const Validator := preload("res://scripts/ai/decision_validator.gd")
const Applier := preload("res://scripts/ai/decision_applier.gd")
const Memory := preload("res://scripts/ai/ai_memory.gd")
const Recorder := preload("res://scripts/ai/training_export.gd")
const Broker := preload("res://scripts/ai/decision_broker.gd")
const FakeClient := preload("res://test/fake_ai_client.gd")

const FIXTURE_PATH := "res://test/fixtures/ai_prompt_cases.json"
const EXAMPLES_PATH := "res://config/ai_examples.json"
const TEST_CONTRACT := "gov_priority_test"

var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[ai-layer] " + message)

func _run() -> void:
	_test_catalog()
	_test_prompt_regression()
	_test_context_builder()
	_test_validator()
	_test_applier()
	_test_memory()
	_test_recorder()
	_test_broker()
	_test_fake_client()
	_finish()

func _finish() -> void:
	print("")
	print("=== camada de IA: %d checks, %d falhas ===" % [checks, failures.size()])
	for message in failures:
		print("FAIL  ", message)
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		print("FALHOU")
		quit(1)

# ---------------------------------------------------------------- catálogo

func _test_catalog() -> void:
	for contract in ["legislative", "electoral", "events", "international"]:
		_check(Catalog.has(contract), "catálogo deve ter o contrato " + contract)
	_check(Catalog.count() >= 20, "catálogo deve registrar os contratos novos (tem %d)" % Catalog.count())
	_check(Catalog.max_tokens("legislative") == 720, "legislative deve manter 720 tokens")
	_check(Catalog.max_tokens("electoral") == 400, "electoral deve manter 400 tokens")
	_check(Catalog.max_tokens("international") == 480, "international deve manter 480 tokens")
	_check(Catalog.max_tokens("events") == 220, "events deve manter 220 tokens")
	_check(Catalog.max_tokens("desconhecido") == 220, "contrato fora do catálogo usa o padrão de 220")
	_check(Catalog.timeout_ms("legislative") == 20000, "legislative deve manter 20 s de prazo")
	_check(Catalog.max_attempts("legislative") == 2, "legislative deve manter 2 tentativas")
	_check(Catalog.tier("desconhecido") == 4, "tier padrão é 4")
	_check(Catalog.priority("desconhecido") == 50, "prioridade padrão é 50")
	_check(str(Catalog.fallback_rule("legislative")) != "", "legislative deve declarar contingência")
	var actions := Catalog.allowed_list("gov_priority", "actions")
	_check(actions.size() == 5, "gov_priority deve permitir 5 ações")
	_check(actions.has("empregos"), "gov_priority deve permitir empregos")
	_check(Catalog.allowed_list("global_event", "shocks").has("energia"), "global_event deve permitir energia")

func _test_prompt_regression() -> void:
	var examples := _load_examples()
	var fixture := _load_fixture()
	_check(not fixture.is_empty(), "fixture de prompts deve existir (rode tools/ai_prompt_snapshot.gd)")
	var cases: Array = fixture.get("cases", [])
	_check(cases.size() == 4, "fixture deve ter um caso por contrato antigo")
	for raw in cases:
		if not (raw is Dictionary):
			continue
		var case: Dictionary = raw
		var contract := str(case.get("contract", ""))
		var ctx: Dictionary = case.get("ctx", {})
		var expected := str(case.get("prompt", ""))
		var actual := Contracts.prompt(contract, ctx, examples)
		_check(actual == expected, "prompt de %s deve continuar idêntico ao fixture" % contract)
	# Fase 2: o catálogo carrega o mesmo texto congelado.
	_check(Catalog.schema("legislative") == str(Contracts.SCHEMA_BY_CONTRACT[Contracts.LEGISLATIVE]), "schema do catálogo deve igualar ai_contracts")
	_check(Catalog.rules("legislative") == str(Contracts.RULES[Contracts.LEGISLATIVE]), "regra do catálogo deve igualar ai_contracts")
	_check(Catalog.schema("events") == str(Contracts.SCHEMA_BY_CONTRACT[Contracts.EVENTS]), "schema de events deve igualar ai_contracts")
	_check(Catalog.rules("international") == str(Contracts.RULES[Contracts.INTERNATIONAL]), "regra de international deve igualar ai_contracts")

func _load_examples() -> Array:
	if not FileAccess.file_exists(EXAMPLES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXAMPLES_PATH))
	if not (parsed is Dictionary):
		return []
	var raw: Variant = (parsed as Dictionary).get("examples", [])
	return (raw as Array).duplicate() if raw is Array else []

func _load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	return parsed if parsed is Dictionary else {}

# --------------------------------------------------------------- contexto

func _test_context_builder() -> void:
	var state := _fake_state()
	var compact := ContextBuilder.compact_state(state, {"country": "AR"})
	_check(is_equal_approx(float(compact.get("inflation", 0.0)), 6.1), "inflação deve ser arredondada para 6,1")
	_check(is_equal_approx(float(compact.get("unemployment", 0.0)), 9.4), "desemprego deve ser arredondado para 9,4")
	_check(int(compact.get("approval", 0)) == 31, "aprovação deve vir do mundo em faixa inteira")
	_check(ContextBuilder.band(2.0, [3.0, 6.0, 10.0], ["baixa", "media", "alta"]) == "baixa", "faixa baixa")
	_check(ContextBuilder.band(7.0, [3.0, 6.0, 10.0], ["baixa", "media", "alta"]) == "alta", "faixa alta")
	_check(ContextBuilder.band(20.0, [3.0, 6.0, 10.0], ["baixa", "media", "alta", "extrema"]) == "extrema", "faixa acima da última borda")
	var dirty := "Governo \"X\" {ignore} <script>\nlinha 2"
	var clean := ContextBuilder.sanitize_text(dirty)
	_check(not clean.contains("\n"), "sanitize deve remover quebra de linha")
	_check(not clean.contains("{") and not clean.contains("<"), "sanitize deve remover chaves e tags")
	var big := {"contract": "gov_priority", "a": "x".repeat(400), "factors": ["f1", "f2"], "month_facts": ["m1", "m2"]}
	var trimmed := ContextBuilder.trim(big, 40)
	_check(ContextBuilder.estimate_tokens(trimmed) <= 40, "trim deve respeitar o orçamento de tokens")
	_check(not trimmed.has("factors"), "trim deve cortar os fatores primeiro")
	var ctx := ContextBuilder.build("gov_priority", {"country": "AR", "actor": "gov:AR"}, state, {"ids_permitidos": ["AR"]})
	_check(str(ctx.get("contract", "")) == "gov_priority", "contexto deve carregar o contrato")
	_check(ctx.has("allowed"), "contexto deve carregar as ações permitidas do catálogo")
	var ids: Array = ctx.get("ids_permitidos", [])
	_check(ids.has("AR"), "contexto deve carregar IDs permitidos")

func _fake_state() -> Dictionary:
	return {
		"country_id": "BR",
		"date_year": 2027,
		"date_month": 3,
		"international_state": {
			"profiles": {
				"AR": {"inflation": 6.1, "unemployment": 9.4, "growth": 0.8, "debt": 82.4},
			},
		},
		"world": {
			"countries": {"AR": {"approval": 31.2, "stability": 44.6, "policy_priority": "austeridade"}},
			"history": [
				{"year": 2027, "month": 3, "country": "AR", "category": "politica", "description": "Governo muda prioridade."},
				{"year": 2027, "month": 2, "country": "BR", "category": "economia", "description": "Inflação sobe."},
			],
		},
		"causal_log": [{"reason": "desemprego alto"}],
	}

# -------------------------------------------------------------- validador

func _test_validator() -> void:
	var ok := Validator.validate("gov_priority", {"action": "empregos", "intensity": 0.6, "reason": "desemprego alto"})
	_check(bool(ok.get("ok", false)), "gov_priority válido deve passar")
	_check(str((ok.get("decision", {}) as Dictionary).get("action", "")) == "empregos", "ação deve ser preservada")
	var clamped := Validator.validate("gov_priority", {"action": "empregos", "intensity": 3.5})
	_check(bool(clamped.get("ok", false)), "valor fora de faixa deve ser recortado, não rejeitado")
	_check(is_equal_approx(float((clamped.get("decision", {}) as Dictionary).get("intensity", 0.0)), 1.0), "intensidade deve ser recortada para 1")
	_check((clamped.get("clamped", []) as Array).size() == 1, "o recorte deve ser registrado")
	var bad_enum := Validator.validate("gov_priority", {"action": "guerra", "intensity": 0.5})
	_check(not bool(bad_enum.get("ok", false)), "enum fora da lista deve ser rejeitado")
	_check(str((bad_enum.get("errors", [""]) as Array)[0]).contains("fora da lista"), "erro deve citar a lista")
	var extra := Validator.validate("gov_priority", {"action": "empregos", "intensity": 0.5, "missil": 3})
	_check(not bool(extra.get("ok", false)), "chave inesperada deve ser rejeitada")
	var missing := Validator.validate("gov_priority", {"intensity": 0.5})
	_check(not bool(missing.get("ok", false)), "campo ausente deve ser rejeitado")
	var legacy := Validator.validate_legacy("legislative", {"votes": {"PL": [70, 20, 10], "PT": [10, 10, 80]}}, {"seat_map": {"PL": 10, "PT": 5}})
	_check(bool(legacy.get("ok", false)), "legislativo antigo deve continuar validando")
	_check((legacy.get("missing", []) as Array).is_empty(), "legislativo antigo não deve ter bancada faltando")
	# event_v2
	var event := {
		"headline": "Greve pressiona governo",
		"category": "economia",
		"options": [
			{"label": "Negociar", "hint": "acordo rápido", "effects": {"approval": 3, "funds": -900}, "groups": {"Trabalhadores": 3}},
			{"label": "Ignorar", "hint": "sem custo", "effects": {"credibility": 2, "approval": -1}, "groups": {}},
			{"label": "Endurecer", "hint": "discurso duro", "effects": {"popularity": -1, "approval": 1}, "groups": {}},
		],
	}
	var event_ok := Validator.validate_event_v2(event)
	_check(bool(event_ok.get("ok", false)), "event_v2 válido deve passar")
	var two_options := event.duplicate(true)
	two_options["options"] = (two_options["options"] as Array).slice(0, 2)
	_check(not bool(Validator.validate_event_v2(two_options).get("ok", false)), "event_v2 com 2 opções deve falhar")
	var dominant := {
		"headline": "Escolha falsa",
		"category": "politica",
		"options": [
			{"label": "A", "hint": "", "effects": {"approval": 1, "funds": -100}, "groups": {}},
			{"label": "B", "hint": "", "effects": {"approval": 1}, "groups": {}},
			{"label": "C", "hint": "", "effects": {"approval": -1}, "groups": {}},
		],
	}
	_check(not bool(Validator.validate_event_v2(dominant).get("ok", false)), "opção dominante deve ser rejeitada")
	# notícia com placeholder
	var news := Validator.validate("news_text", {"headline": "Inflação preocupa em {{country}}", "body": "Índice chegou a {{inflation}}% no mês.", "tone": "neutro"})
	_check(bool(news.get("ok", false)), "notícia com placeholders deve passar")
	var literal := Validator.validate("news_text", {"headline": "Inflação de 6,1% preocupa", "body": "Índice subiu.", "tone": "neutro"})
	_check(not bool(literal.get("ok", false)), "notícia com número literal deve ser rejeitada")
	# coerência
	var hawk := Validator.validate("central_bank", {"rate_move_bp": 50, "stance": "dovish", "reason": "inflação"})
	_check(not bool(hawk.get("ok", false)), "banco central dovish com alta deve ser incoerente")
	var euphoria := Validator.validate("market_mood", {"sentiment": 0.8, "risk_premium_bp": 10, "fx_pressure_pct": 1.0, "capital_flow": "saida"})
	_check(not bool(euphoria.get("ok", false)), "euforia com saída de capital deve ser incoerente")
	# contrato desconhecido
	var unknown := Validator.validate("nao_existe", {})
	_check(not bool(unknown.get("ok", false)), "contrato desconhecido deve falhar")

# -------------------------------------------------------------- aplicador

func _test_applier() -> void:
	var plan := Applier.plan("gov_priority", {"action": "empregos", "intensity": 0.6}, {"country": "AR"})
	_check(bool(plan.get("ok", false)), "aplicador deve montar plano de gov_priority")
	var calls: Array = plan.get("calls", [])
	_check(calls.size() == 1, "plano deve ter uma chamada")
	var call: Dictionary = calls[0]
	_check(str(call.get("system", "")) == "autonomous_government", "destino deve ser autonomous_government")
	_check(is_equal_approx(float((call.get("args", {}) as Dictionary).get("intensity", 0.0)), 0.6), "argumento deve chegar ao destino")
	_check(not bool(Applier.plan("nao_existe", {}).get("ok", true)), "contrato sem destino deve falhar")
	var changes := Applier.diff({"action": "austeridade"}, {"action": "empregos"})
	_check(changes.size() == 1, "diff deve registrar a troca")
	_check(str((changes[0] as Dictionary).get("from", "")) == "austeridade", "diff deve guardar o valor anterior")
	var record := Applier.record("gov_priority", {"action": "empregos", "reason": "desemprego"}, {"model": "fake", "year": 2027, "month": 3}, {"source": "ia", "changes": changes})
	_check(str(record.get("stamp", "")) == "2027-03", "registro deve carregar o carimbo do mês")
	_check(str(record.get("rationale", "")) == "desemprego", "registro deve carregar o motivo")
	_check(str(record.get("source", "")) == "ia", "registro deve carregar a origem")

# ---------------------------------------------------------------- memória

func _test_memory() -> void:
	var state := {}
	var memory := Memory.ensure(state)
	_check(int(memory.get("version", 0)) == 1, "memória deve ter versão 1")
	Memory.remember(state, "gov:AR", "priorizou austeridade", "2027-01")
	Memory.remember(state, "gov:AR", "priorizou austeridade", "2027-01")
	Memory.remember(state, "gov:AR", "aprovação caiu 6", "2027-02")
	var facts := Memory.recall(state, "gov:AR")
	_check(facts.size() == 2, "fato repetido não deve duplicar")
	_check(str(facts[0]).contains("aprovação caiu"), "fato mais novo vem primeiro")
	Memory.set_persona(state, "gov:AR", "tecnocrata cauteloso")
	_check(Memory.persona(state, "gov:AR") == "tecnocrata cauteloso", "persona deve ser lida de volta")
	for i in 10:
		Memory.remember(state, "gov:AR", "fato %d" % i)
	_check(Memory.recall(state, "gov:AR").size() <= Memory.MAX_FACTS, "memória deve respeitar o teto de fatos")
	_check(state.has("ai_memory"), "memória deve persistir em state.ai_memory")

# --------------------------------------------------------------- registro

func _test_recorder() -> void:
	var config := {"training_export": {"enabled": true, "path": "user://ai_dataset_test", "only_validated": true}}
	var path := Recorder.dataset_path(config, TEST_CONTRACT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var state := {}
	var entry := {
		"contract": TEST_CONTRACT,
		"input": "prompt curto",
		"output": "{\"action\": \"empregos\"}",
		"source": "ia",
		"stamp": "2027-03",
		"validation": {"ok": true, "clamped": [], "errors": []},
	}
	_check(Recorder.record(state, config, entry), "decisão válida deve ir para o dataset")
	_check(Recorder.count_lines(path) == 1, "dataset deve ter uma linha")
	_check(Recorder.recent(state, 5).size() == 1, "decisão deve entrar no log do save")
	var invalid := entry.duplicate(true)
	invalid["validation"] = {"ok": false, "clamped": [], "errors": ["enum inválido"]}
	invalid["source"] = "contingencia"
	_check(not Recorder.record(state, config, invalid), "decisão inválida não deve virar exemplo de treino")
	_check(Recorder.count_lines(path) == 1, "dataset não deve crescer com contingência")
	_check(Recorder.recent(state, 5).size() == 2, "contingência continua no log para auditoria")
	_check(int(Recorder.by_source(state).get("contingencia", 0)) == 1, "log deve separar por origem")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ----------------------------------------------------------------- broker

func _test_broker() -> void:
	var config := {"budget": {"max_calls_per_month": 40}, "parallel": {"max_parallel": 1}}
	var client := FakeClient.new()
	client.queue("gov_priority", {"action": "empregos", "intensity": 0.6})
	client.queue("conflict_action", {"conflict_id": "c_7", "action": "descalar"})
	var broker := Broker.new(client, config)
	broker.set_month(2027, 3)
	var unknown := broker.submit("nao_existe", {}, {}, {}, Callable())
	_check(not bool(unknown.get("ok", true)), "broker deve recusar contrato fora do catálogo")
	var low := broker.submit("conflict_action", {"a": 1}, {}, {"year": 2027, "month": 3}, Callable())
	var high := broker.submit("gov_priority", {"a": 1}, {}, {"year": 2027, "month": 3}, Callable())
	_check(bool(low.get("ok", false)) and bool(high.get("ok", false)), "broker deve enfileirar contratos do catálogo")
	_check(broker.pending() == 2, "fila deve ter duas decisões")
	broker.flush()
	_check(int(client.calls.size()) == 2, "cliente síncrono despacha a fila inteira no flush")
	_check(str((client.calls[0] as Dictionary).get("contract", "")) == "gov_priority", "prioridade menor deve sair primeiro")
	# Paralelismo só limita cliente assíncrono (resposta pendente).
	var slow := FakeClient.new()
	slow.mode = "timeout"
	var limited := Broker.new(slow, config)
	limited.set_month(2027, 3)
	limited.submit("gov_priority", {}, {}, {}, Callable())
	limited.submit("conflict_action", {}, {}, {}, Callable())
	_check(limited.flush() == 1, "paralelismo 1 deve despachar uma por vez")
	_check(limited.pending() == 1, "a segunda decisão deve continuar na fila")
	_check(limited.flush() == 0, "flush com cliente ocupado não deve despachar")
	_check(int(broker.stats().get("calls", 0)) == 2, "orçamento deve contar as chamadas")
	var tight := Broker.new(client, {"budget": {"max_calls_per_month": 1}, "parallel": {"max_parallel": 2}})
	tight.set_month(2027, 4)
	tight.submit("gov_priority", {}, {}, {}, Callable())
	_check(tight.flush() == 1, "orçamento de 1 deve despachar 1")
	_check(not bool(tight.submit("gov_priority", {}, {}, {}, Callable()).get("ok", true)), "orçamento esgotado deve recusar")
	tight.set_month(2027, 5)
	_check(bool(tight.submit("gov_priority", {}, {}, {}, Callable()).get("ok", false)), "novo mês renova o orçamento")
	broker.set_month(2027, 6)
	broker.precompute({"inflation": 6.1, "unemployment": 9.4})
	_check(broker.is_precalc_fresh({"unemployment": 9.4, "inflation": 6.1}), "pré-cálculo deve aceitar o mesmo contexto em outra ordem")
	_check(not broker.is_precalc_fresh({"inflation": 7.9}), "pré-cálculo deve ser descartado quando o estado muda")
	_check(Broker.hash_context({"a": 1, "b": 2}) == Broker.hash_context({"b": 2, "a": 1}), "hash de contexto deve ser estável")

# ------------------------------------------------------------ cliente falso

func _test_fake_client() -> void:
	var client := FakeClient.new()
	var received: Array = []
	client.queue("gov_priority", {"action": "investimento", "intensity": 0.4})
	client.request("gov_priority", {}, {}, {}, func(payload): received.append(payload))
	_check(received.size() == 1, "cliente falso deve entregar a fixture na hora")
	_check(str((received[0] as Dictionary).get("source", "")) == "ia", "fixture deve ter origem ia")
	_check(str(((received[0] as Dictionary).get("value", {}) as Dictionary).get("action", "")) == "investimento", "fixture deve chegar intacta")
	client.mode = "timeout"
	client.request("gov_priority", {}, {}, {}, func(payload): received.append(payload))
	_check(client.pending_count() == 1, "modo timeout deve deixar a decisão pendente")
	_check(client.is_pending("fake_2"), "op pendente deve ser reconhecida")
	client.release_pending()
	_check(client.pending_count() == 0, "release deve soltar a pendência")
	_check(str((received[1] as Dictionary).get("source", "")) == "contingencia", "timeout deve entregar contingência")
	client.mode = "offline"
	client.request("events", {}, {}, {}, func(payload): received.append(payload))
	_check(str((received[2] as Dictionary).get("source", "")) == "contingencia", "offline deve entregar contingência")
	_check(str((received[2] as Dictionary).get("value", {})).contains("headline"), "contingência de events deve vir do fallback real")
