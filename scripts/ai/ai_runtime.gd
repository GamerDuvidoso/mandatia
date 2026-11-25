extends RefCounted
## Fase 3 — runtime da camada de decisão para o mundo autônomo.
##
## `WorldSim.monthly` pergunta a este objeto qual é a prioridade de governo de
## cada país. O runtime:
##
##   - em modo `off` (padrão no `config/ai_config.json`) devolve `{}` e não
##     toca em estado nenhum — o jogo roda exatamente como antes do fio;
##   - nos modos com IA pede a decisão ao broker (que respeita orçamento,
##     paralelismo e fila), guarda a resposta para o mês seguinte e, quando o
##     mês chega, valida no `decision_validator` e aplica pelo
##     `decision_applier`. Nada é escrito direto no estado.
##
## O mundo decide adiantado (1 mês) porque o jogador não pode esperar a rede:
## enquanto o mês M corre, o pedido do mês M+1 já saiu. Sem decisão pronta, a
## contingência é `AutonomousGovernment.choose_priority`, que é a regra do motor.

const Catalog := preload("res://scripts/ai/decision_catalog.gd")
const ContextBuilder := preload("res://scripts/ai/context_builder.gd")
const Validator := preload("res://scripts/ai/decision_validator.gd")
const Applier := preload("res://scripts/ai/decision_applier.gd")
const Memory := preload("res://scripts/ai/ai_memory.gd")
const Recorder := preload("res://scripts/ai/training_export.gd")
const Broker := preload("res://scripts/ai/decision_broker.gd")
const AutonomousGovernment := preload("res://scripts/sim/autonomous_government.gd")

const CONFIG_PATH := "res://config/ai_config.json"
const CONTRACT := "gov_priority"
## Decisões preparadas por país e por mês: "AR|2027-03".
const PLAN_KEY := "ai_priority_plan"

var config: Dictionary = {}
var client: Object = null
var broker: Object = null

var _seq := 0

static var _config_loaded := false
static var _config_cache: Dictionary = {}

## Lê `config/ai_config.json` uma vez por processo.
static func default_config() -> Dictionary:
	if _config_loaded:
		return _config_cache.duplicate(true)
	_config_loaded = true
	_config_cache = {}
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config_cache = (parsed as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)

## Só para testes: força a releitura do arquivo.
static func reload_config() -> void:
	_config_loaded = false

func _init(ai_config: Dictionary = {}, ai_client: Object = null) -> void:
	config = ai_config.duplicate(true) if not ai_config.is_empty() else default_config()
	client = ai_client
	if client != null:
		broker = Broker.new(client, config)

func mode() -> String:
	return str(config.get("mode", "off"))

func is_active() -> bool:
	return mode() != "off"

## Liga/desliga explicitamente (Configurações, prova e testes).
func set_mode(value: String) -> void:
	config["mode"] = value

func model() -> String:
	return str(config.get("active_model", ""))

## Ponto de entrada do `WorldSim.monthly`.
## Devolve o override aceito por `AutonomousGovernment.monthly` ou `{}`.
func decide_gov_priority(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int) -> Dictionary:
	if not is_active():
		return {}
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var actor := "gov:" + country
	var stamp := "%d-%02d" % [year, month]
	var prepared := _take_plan(st, country, stamp)
	if not prepared.is_empty():
		var applied := _apply_prepared(st, wc, country, actor, stamp, year, month, prepared)
		if not applied.is_empty():
			return applied
	_queue_next(st, country, actor, stamp, profile, base, year, month)
	return {}

# ------------------------------------------------------------- plano do mês

func _take_plan(st: Dictionary, country: String, stamp: String) -> Dictionary:
	var raw: Variant = st.get(PLAN_KEY, {})
	if not (raw is Dictionary):
		return {}
	var row: Variant = (raw as Dictionary).get("%s|%s" % [country, stamp], {})
	return (row as Dictionary).duplicate(true) if row is Dictionary else {}

func _apply_prepared(st: Dictionary, wc: Dictionary, country: String, actor: String, stamp: String, year: int, month: int, prepared: Dictionary) -> Dictionary:
	var source := str(prepared.get("source", "ia"))
	var validation := Validator.validate(CONTRACT, prepared.get("decision", {}), {})
	if not bool(validation.get("ok", false)):
		_record(st, wc, country, actor, stamp, year, month, {}, validation, {}, prepared, source)
		return {}
	var decision: Dictionary = validation.get("decision", {})
	var plan := Applier.plan(CONTRACT, decision, {"country": country, "actor": actor})
	if not bool(plan.get("ok", false)):
		return {}
	var override := _execute(plan)
	if override.is_empty():
		return {}
	_record(st, wc, country, actor, stamp, year, month, decision, validation, override, prepared, source)
	Memory.remember(st, actor, "priorizou %s (%s)" % [str(override.get("action", "")), source], stamp)
	return override

## Executa o plano do applier por whitelist: só sistema/função declarados.
## A função chamada devolve o override; ela não escreve estado.
func _execute(plan: Dictionary) -> Dictionary:
	for raw in (plan.get("calls", []) as Array):
		if not (raw is Dictionary):
			continue
		var call: Dictionary = raw
		var system := str(call.get("system", ""))
		var function := str(call.get("function", ""))
		var args: Variant = call.get("args", {})
		if system != "autonomous_government" or function != "priority_override":
			continue
		if not (args is Dictionary):
			continue
		return AutonomousGovernment.priority_override(args)
	return {}

# ------------------------------------------------------- pedido para o mês seguinte

func _queue_next(st: Dictionary, country: String, actor: String, _stamp: String, profile: Dictionary, base: Dictionary, year: int, month: int) -> void:
	if broker == null:
		return
	broker.set_month(year, month)
	var ctx := ContextBuilder.build(CONTRACT, {"country": country, "actor": actor}, st, {
		"persona": Memory.persona(st, actor, str(config.get("default_persona", ""))),
		"memory": Memory.recall(st, actor, 3),
		"ids_permitidos": [],
	})
	var next_year := year
	var next_month := month + 1
	if next_month > 12:
		next_month = 1
		next_year += 1
	var next_stamp := "%d-%02d" % [next_year, next_month]
	var meta := {"year": next_year, "month": next_month, "country": country, "model": model()}
	var data := {"base": base, "profile": profile, "entities": [country]}
	var callback := func(payload: Dictionary) -> void:
		_on_decision(st, country, next_stamp, ctx, payload)
	var submitted: Dictionary = broker.submit(CONTRACT, ctx, data, meta, callback)
	if bool(submitted.get("ok", false)):
		broker.flush()

## Só decisão vinda da IA (ou do cache) vira plano. Contingência é a própria
## regra do motor: repeti-la no mês seguinte não acrescentaria nada.
func _on_decision(st: Dictionary, country: String, stamp: String, ctx: Dictionary, payload: Dictionary) -> void:
	var value: Variant = payload.get("value", {})
	if not (value is Dictionary) or (value as Dictionary).is_empty():
		return
	var source := str(payload.get("source", "ia"))
	if source == "contingencia" or source == "cancelled":
		return
	var plan: Dictionary = st.get(PLAN_KEY, {}) if st.get(PLAN_KEY) is Dictionary else {}
	plan["%s|%s" % [country, stamp]] = {
		"decision": (value as Dictionary).duplicate(true),
		"source": source,
		"model": str(payload.get("model", model())),
		"request_hash": Broker.hash_context(ctx),
		"input": JSON.stringify(ctx),
		"output": JSON.stringify(value),
	}
	st[PLAN_KEY] = plan

# --------------------------------------------------------------- registro

func _record(st: Dictionary, wc: Dictionary, country: String, actor: String, stamp: String, year: int, month: int, decision: Dictionary, validation: Dictionary, override: Dictionary, prepared: Dictionary, source: String) -> void:
	_seq += 1
	var changes := Applier.diff({"action": str(wc.get("last_priority", ""))}, override)
	var entry := Applier.record(CONTRACT, decision, {"model": str(prepared.get("model", model())), "year": year, "month": month}, {
		"id": Applier.decision_id(_seq),
		"source": source,
		"request_hash": str(prepared.get("request_hash", "")),
		"tokens": prepared.get("tokens", {"prompt": 0, "output": 0, "thinking": 0}),
		"valid": bool(validation.get("ok", false)),
		"clamped": validation.get("clamped", []),
		"errors": validation.get("errors", []),
		"system": "autonomous_government",
		"changes": changes,
		"input": str(prepared.get("input", "")),
		"output": str(prepared.get("output", "")),
	})
	entry["actor"] = actor
	entry["country"] = country
	entry["stamp"] = stamp
	Recorder.record(st, config, entry)

## Resumo para a UI de Configurações (indicador "Mente do jogo").
func summary(st: Dictionary) -> Dictionary:
	var plan: Variant = st.get(PLAN_KEY, {})
	return {
		"mode": mode(),
		"model": model(),
		"active": is_active(),
		"queued": int(broker.stats().get("queued", 0)) if broker != null else 0,
		"calls": int(broker.stats().get("calls", 0)) if broker != null else 0,
		"prepared": (plan as Dictionary).size() if plan is Dictionary else 0,
		"decisions": (st.get("ai_decision_log", []) as Array).size() if st.get("ai_decision_log") is Array else 0,
	}
