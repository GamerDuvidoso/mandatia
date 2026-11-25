extends RefCounted
## Fase 1 — cliente de IA falso.
##
## Mesma interface do `OllamaClient` (`request`, `is_pending`, `pending_count`,
## `cancel`), mas sem rede e sem tempo: entrega fixtures determinísticas na
## hora. A suíte, o soak e os testes de contrato rodam sem Ollama.
##
## Modos:
##   valid      entrega a fixture da fila (ou o fallback, se não houver);
##   invalid    entrega um dicionário inválido para forçar o validador;
##   empty      entrega vazio (simula resposta truncada);
##   timeout    não entrega nada; o teste decide quando soltar;
##   offline    entrega contingência na hora, como o cliente real sem Ollama.

const Contracts := preload("res://scripts/ai/ai_contracts.gd")

var model := "fake-ai"
var available := true
var mode := "valid"
var calls: Array = []

var _fixtures: Dictionary = {}
var _pending: Dictionary = {}
var _seq := 0

func queue(contract: String, value: Dictionary) -> void:
	var list: Array = []
	if _fixtures.has(contract) and _fixtures[contract] is Array:
		list = _fixtures[contract]
	list.append(value.duplicate(true))
	_fixtures[contract] = list

func queue_many(contract: String, values: Array) -> void:
	for value in values:
		if value is Dictionary:
			queue(contract, value)

func reset() -> void:
	calls.clear()
	_fixtures.clear()
	_pending.clear()
	_seq = 0
	mode = "valid"
	available = true

func request(contract: String, prompt_ctx: Dictionary, data: Dictionary, meta: Dictionary, callback: Callable) -> String:
	_seq += 1
	var op_id := "fake_%d" % _seq
	calls.append({"id": op_id, "contract": contract, "ctx": prompt_ctx.duplicate(true), "meta": meta.duplicate(true)})
	if mode == "timeout":
		_pending[op_id] = {"callback": callback, "contract": contract, "data": data, "meta": meta}
		return op_id
	if mode == "offline" or not available:
		_deliver(callback, {
			"ok": true,
			"value": fallback(contract, data),
			"source": "contingencia",
			"contract": contract,
			"fallback_used": true,
			"reason": "cliente falso offline",
		})
		return op_id
	if mode == "invalid":
		_deliver(callback, {
			"ok": true,
			"value": {"invalid": true},
			"source": "ia",
			"contract": contract,
			"fallback_used": false,
			"reason": "",
		})
		return op_id
	if mode == "empty":
		_deliver(callback, {
			"ok": true,
			"value": {},
			"source": "ia",
			"contract": contract,
			"fallback_used": false,
			"reason": "resposta vazia",
		})
		return op_id
	var value := _pop_fixture(contract)
	var source := "ia"
	if value.is_empty():
		value = fallback(contract, data)
		source = "contingencia"
	_deliver(callback, {
		"ok": true,
		"value": value,
		"source": source,
		"contract": contract,
		"fallback_used": source == "contingencia",
		"reason": "",
	})
	return op_id

func _pop_fixture(contract: String) -> Dictionary:
	if not _fixtures.has(contract):
		return {}
	var list: Array = _fixtures[contract]
	if list.is_empty():
		return {}
	var value: Variant = list.pop_front()
	_fixtures[contract] = list
	return (value as Dictionary) if value is Dictionary else {}

func _deliver(callback: Callable, payload: Dictionary) -> void:
	if callback.is_valid():
		callback.call(payload)

## Solta as respostas pendentes do modo `timeout` (uma ou todas).
func release_pending(limit: int = -1) -> int:
	var released := 0
	for op_id in _pending.keys():
		if limit >= 0 and released >= limit:
			break
		var op: Dictionary = _pending[op_id]
		_pending.erase(op_id)
		_deliver(op["callback"], {
			"ok": true,
			"value": fallback(str(op["contract"]), op["data"]),
			"source": "contingencia",
			"contract": str(op["contract"]),
			"fallback_used": true,
			"reason": "timeout simulado",
		})
		released += 1
	return released

func is_pending(op_id: String) -> bool:
	return _pending.has(op_id)

func pending_count() -> int:
	return _pending.size()

func cancel(op_id: String) -> void:
	if not _pending.has(op_id):
		return
	var op: Dictionary = _pending[op_id]
	_pending.erase(op_id)
	_deliver(op["callback"], {
		"ok": true,
		"value": fallback(str(op["contract"]), op["data"]),
		"source": "cancelled",
		"contract": str(op["contract"]),
		"fallback_used": true,
		"reason": "cancelado pelo jogador",
	})

## Contingência determinística: delega para os fallbacks reais do contrato.
static func fallback(contract: String, data: Dictionary) -> Dictionary:
	match contract:
		Contracts.LEGISLATIVE:
			return Contracts.fallback_legislative(
				data.get("bill", {}),
				data.get("seat_map", {}),
				data.get("axes", {}),
				data.get("partners", []),
				float(data.get("cohesion", 60.0))
			)
		Contracts.ELECTORAL:
			return Contracts.fallback_electoral(data.get("base_shares", {}))
		Contracts.EVENTS:
			return Contracts.fallback_event()
		Contracts.INTERNATIONAL:
			return Contracts.fallback_international()
	return {}
