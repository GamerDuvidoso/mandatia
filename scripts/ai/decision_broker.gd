extends RefCounted
## Fase 1 — broker de decisões.
##
## Uma camada só entre os sistemas do jogo e o cliente do Ollama. O sistema
## enfileira a decisão com prioridade; o broker controla orçamento mensal,
## paralelismo, ordem de atendimento, hash de contexto e pré-cálculo do mês
## seguinte. Ele NÃO fala HTTP: depende de um cliente com
## `request(contract, prompt_ctx, data, meta, callback)`, `pending_count()` e
## `cancel(op_id)` — o `OllamaClient` em produção e o `FakeAIClient` nos testes.
##
## Nesta fase o broker ainda não está ligado ao `main.gd`: o jogo continua
## idêntico. A ligação entra na fase do ator correspondente.

const Catalog := preload("res://scripts/ai/decision_catalog.gd")
const Validator := preload("res://scripts/ai/decision_validator.gd")

const DEFAULT_MAX_CALLS := 40
const DEFAULT_MAX_PARALLEL := 2

var client: Object = null
var config: Dictionary = {}

var _queue: Array = []
var _month := ""
var _calls := 0
var _dropped := 0
var _dispatched := 0
var _precalc: Dictionary = {}

func _init(ai_client: Object = null, ai_config: Dictionary = {}) -> void:
	configure(ai_client, ai_config)

func configure(ai_client: Object, ai_config: Dictionary) -> void:
	client = ai_client
	config = ai_config.duplicate(true)

func set_month(year: int, month: int) -> void:
	var key := "%d-%02d" % [year, month]
	if key == _month:
		return
	_month = key
	_calls = 0
	_queue.clear()
	_precalc = {}

func month() -> String:
	return _month

func budget() -> Dictionary:
	var raw: Variant = config.get("budget", {})
	return raw if raw is Dictionary else {}

func max_calls_per_month() -> int:
	return int(budget().get("max_calls_per_month", DEFAULT_MAX_CALLS))

func max_parallel() -> int:
	var raw: Variant = config.get("parallel", {})
	var parallel: Dictionary = raw if raw is Dictionary else {}
	return maxi(1, int(parallel.get("max_parallel", DEFAULT_MAX_PARALLEL)))

func calls_this_month() -> int:
	return _calls

func can_call() -> bool:
	return _calls < max_calls_per_month()

## Enfileira uma decisão. Devolve ok=false quando o contrato é desconhecido ou
## o orçamento do mês acabou — nesse caso o chamador usa a contingência.
func submit(contract: String, prompt_ctx: Dictionary, data: Dictionary, meta: Dictionary, callback: Callable) -> Dictionary:
	if not Catalog.has(contract):
		_dropped += 1
		return {"ok": false, "request_id": "", "reason": "contrato desconhecido: " + contract, "queued": _queue.size()}
	if not can_call():
		_dropped += 1
		return {"ok": false, "request_id": "", "reason": "orçamento mensal esgotado", "queued": _queue.size()}
	var entry := {
		"contract": contract,
		"priority": int(meta.get("priority", Catalog.priority(contract))),
		"tier": int(meta.get("tier", Catalog.tier(contract))),
		"prompt_ctx": prompt_ctx,
		"data": data,
		"meta": meta,
		"callback": callback,
		"request_id": "",
	}
	_queue.append(entry)
	return {"ok": true, "request_id": "", "reason": "enfileirado", "queued": _queue.size()}

## Despacha a fila em ordem de prioridade, respeitando orçamento e paralelismo.
## Devolve quantas decisões foram enviadas ao cliente.
func flush(parallel_limit: int = -1) -> int:
	if client == null:
		return 0
	var limit := parallel_limit
	if limit <= 0:
		limit = max_parallel()
	_queue.sort_custom(func(a, b):
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return int(a["tier"]) < int(b["tier"])
	)
	var dispatched := 0
	while not _queue.is_empty() and can_call():
		var busy := 0
		if client.has_method("pending_count"):
			busy = int(client.call("pending_count"))
		if busy >= limit:
			break
		var entry: Dictionary = _queue.pop_front()
		_calls += 1
		var request_id := str(client.call("request", entry["contract"], entry["prompt_ctx"], entry["data"], entry["meta"], entry["callback"]))
		entry["request_id"] = request_id
		_dispatched += 1
		dispatched += 1
	return dispatched

func pending() -> int:
	return _queue.size()

## Descarta o que ainda não foi despachado. Quem já saiu para o cliente é
## cancelado pelo próprio cliente (é ele que conhece o `op_id`).
func cancel_all() -> void:
	_queue.clear()

func stats() -> Dictionary:
	return {
		"month": _month,
		"queued": _queue.size(),
		"calls": _calls,
		"max_calls": max_calls_per_month(),
		"dropped": _dropped,
		"dispatched": _dispatched,
		"budget_left": maxi(0, max_calls_per_month() - _calls),
	}

# ------------------------------------------------------- hash e pré-cálculo

## String estável (chaves ordenadas) para o hash de contexto.
static func stable_string(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var parts := PackedStringArray()
		for key in keys:
			parts.append("%s=%s" % [str(key), stable_string((value as Dictionary)[key])])
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var items := PackedStringArray()
		for item in value:
			items.append(stable_string(item))
		return "[" + ",".join(items) + "]"
	return str(value)

static func hash_context(snapshot: Dictionary) -> String:
	return str(stable_string(snapshot).hash())

## Guarda o contexto do mês seguinte. Antes de aplicar, o chamador compara o
## hash: se o estado mudou além do limiar, o pré-cálculo é descartado.
func precompute(snapshot: Dictionary) -> void:
	_precalc = {"hash": hash_context(snapshot), "month": _month, "snapshot": snapshot.duplicate(true)}

func is_precalc_fresh(snapshot: Dictionary) -> bool:
	if _precalc.is_empty():
		return false
	if str(_precalc.get("month", "")) != _month:
		return false
	return str(_precalc.get("hash", "")) == hash_context(snapshot)

func precalc_hash() -> String:
	return str(_precalc.get("hash", ""))

# --------------------------------------------------------------- validação

## Atalho: valida a resposta do cliente com o validador da fase.
func validate(contract: String, parsed: Variant, ctx: Dictionary = {}) -> Dictionary:
	return Validator.validate(contract, parsed, ctx)
