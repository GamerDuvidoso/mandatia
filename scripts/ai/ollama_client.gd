extends Node
## Ponte local com Ollama (mandatia-qwen35-local:latest) para as decisões que não são do jogador.
##
## Contratos em scripts/ai/ai_contracts.gd:
##  legislativo, eleitoral, eventos, internacional.
##
## Garantias:
##  - cada pedido é uma operação com ID único (pending/done/cancelled);
##  - no máximo 2 tentativas de 20 s por operação, com fallback determinístico;
##  - resposta atrasada depois de timeout/fallback/cancelamento é ignorada;
##  - callback é chamado exatamente uma vez;
##  - cache em state.ai_decisions (persiste no save) e log NDJSON em user://ai_log;
##  - sem Ollama (ai_available = false) o jogo responde pelo fallback na hora.

signal availability_changed(available: bool)

const Contracts := preload("res://scripts/ai/ai_contracts.gd")
## Fase 2: o catálogo (config/ai_catalog.json) passa a ser a fonte dos limites
## por contrato. Os valores são idênticos aos antigos e a equivalência é
## verificada por test/test_ai_layer.gd; sem o JSON, o catálogo devolve os
## mesmos padrões de antes.
const DecisionCatalog := preload("res://scripts/ai/decision_catalog.gd")

## 127.0.0.1 e não "localhost": no Windows o Godot resolve localhost para
## ::1 e o Ollama só escuta em IPv4, o que derrubava toda chamada no fallback.
const BASE_URL := "http://127.0.0.1:11434"
const TAGS_URL := BASE_URL + "/api/tags"
const SHOW_URL := BASE_URL + "/api/show"
const GENERATE_URL := BASE_URL + "/api/generate"
const MODEL := "mandatia-qwen35-local:latest"
const TIMEOUT_MS := 20000
## Carregar o modelo do disco leva dezenas de segundos; o aquecimento na
## inicialização paga esse custo fora do prazo de 20 s de cada decisão.
const WARM_TIMEOUT_MS := 240000
## Tolerância do vigia de prazo: garante o corte mesmo se o HTTPRequest
## continuar recebendo bytes e não disparar o próprio timeout.
const DEADLINE_GRACE_MS := 250
const KEEP_ALIVE := "30m"
const MAX_ATTEMPTS := 2
const PROBE_TIMEOUT_MS := 3000
const EXAMPLES_PATH := "res://config/ai_examples.json"
const LOG_DIR := "user://ai_log"
const CACHE_VERSION := "v1"

var game: Node = null
var ai_available := false
var availability_checked := false
var model := MODEL
var examples: Array = []
var last_error := ""
## Structured output (JSON mode) do Ollama. Mantido desativado por padrão:
## com gramática forçada alguns modelos/versões omitem o motivo do erro em
## abortos; o parsing robusto (_extract_json) já lida com JSON sem formato.
var use_json_format := false

var _ops: Dictionary = {}
var _seq := 0
var _log_file: FileAccess = null
var _log_path := ""
var _probe: HTTPRequest = null
var _probe_stage := "tags"
var _warm: HTTPRequest = null

func _ready() -> void:
	_load_examples()
	_open_log()

func attach(game_node: Node) -> void:
	game = game_node
	if _log_file == null:
		_open_log()
	check_startup()

func stop() -> void:
	for op_id in _ops.keys():
		cancel(str(op_id))
	# Sondagem pendente também precisa ser cortada: a resposta atrasada chamava
	# _probe.request num nó já liberado e escrevia erro no console ao sair.
	if _probe != null and is_instance_valid(_probe):
		_probe.cancel_request()
		_probe.queue_free()
	_probe = null
	if _warm != null and is_instance_valid(_warm):
		_warm.cancel_request()
		_warm.queue_free()
		_warm = null

# --------------------------------------------------------------- startup

## GET /api/tags + POST /api/show: só considera a IA disponível se o modelo existe.
func check_startup() -> void:
	availability_checked = false
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	_probe = HTTPRequest.new()
	add_child(_probe)
	_probe.request_completed.connect(_on_probe_completed)
	_probe_stage = "tags"
	var err := _probe.request(TAGS_URL, [], HTTPClient.METHOD_GET)
	if err != OK:
		_set_available(false, "tags: erro " + str(err))
		return
	get_tree().create_timer(PROBE_TIMEOUT_MS / 1000.0).timeout.connect(_on_probe_timeout)

func _on_probe_timeout() -> void:
	if not availability_checked:
		_set_available(false, "servidor local não respondeu")

func _on_probe_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _probe == null or not is_instance_valid(_probe):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_available(false, "tags: HTTP %d" % response_code)
		return
	if _probe_stage == "tags":
		_probe_stage = "show"
		var payload := JSON.stringify({"model": model})
		var err := _probe.request(SHOW_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
		if err != OK:
			_set_available(false, "show: erro " + str(err))
		return
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	var found := parsed is Dictionary
	_set_available(found, "" if found else "modelo %s ausente" % model)

func _set_available(value: bool, reason: String) -> void:
	availability_checked = true
	ai_available = value
	last_error = reason
	availability_changed.emit(value)
	if value:
		_warm_up()

## POST /api/generate com prompt vazio só para trazer o modelo à memória.
func _warm_up() -> void:
	if _warm != null and is_instance_valid(_warm):
		_warm.queue_free()
	_warm = HTTPRequest.new()
	_warm.timeout = WARM_TIMEOUT_MS / 1000.0
	add_child(_warm)
	_warm.request_completed.connect(_on_warm_completed)
	var body := {
		"model": model,
		"prompt": "",
		"stream": false,
		"think": false,
		"keep_alive": KEEP_ALIVE,
		"options": {"num_predict": 1},
	}
	var err := _warm.request(GENERATE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		last_error = "aquecimento: erro " + str(err)

func _on_warm_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _warm != null and is_instance_valid(_warm):
		_warm.queue_free()
		_warm = null

# --------------------------------------------------------------- pedidos

## Enfileira uma decisão. Devolve o ID da operação.
## prompt_ctx: campos que aparecem no prompt.
## data: dados usados na validação e no fallback (seat_map, axes, bill...).
func request(contract: String, prompt_ctx: Dictionary, data: Dictionary, meta: Dictionary, callback: Callable) -> String:
	_seq += 1
	var op_id := "ai_%d_%d" % [Time.get_ticks_msec(), _seq]
	var meta_full := meta.duplicate()
	meta_full["model"] = model
	var entities: Array = data.get("entities", [])
	var key := Contracts.cache_key(contract, meta_full, entities)
	var cached := _read_cache(key)
	if not cached.is_empty():
		var cached_value: Variant = cached.get("value", {})
		_deliver(callback, {"ok": true, "value": cached_value, "source": "cache", "contract": contract, "key": key})
		return op_id
	var op := {
		"id": op_id,
		"contract": contract,
		"prompt_ctx": prompt_ctx,
		"data": data,
		"meta": meta_full,
		"key": key,
		"callback": callback,
		"attempt": 0,
		"state": "pending",
		"http": null,
		"prompt": "",
		"raw": "",
		"validation": "",
		"retries": 0,
		"deadline_ms": 0,
	}
	_ops[op_id] = op
	if not ai_available:
		_finish(op_id, _fallback(contract, data), "fallback", "modelo indisponível")
		return op_id
	_attempt(op_id)
	return op_id

## Vigia de prazo: um único ponto de corte por tentativa. Sem ele, respostas
## que pingam bytes mantêm o HTTPRequest vivo e a decisão passava dos 20 s.
func _process(_delta: float) -> void:
	if _ops.is_empty():
		return
	var now := Time.get_ticks_msec()
	for op_id in _ops.keys():
		var op: Dictionary = _ops[op_id]
		if str(op.get("state", "")) != "pending":
			continue
		var deadline := int(op.get("deadline_ms", 0))
		if deadline <= 0 or now < deadline + DEADLINE_GRACE_MS:
			continue
		_abort_http(op)
		_retry_or_fallback(str(op_id), "timeout de %d s" % int(TIMEOUT_MS / 1000))

func is_pending(op_id: String) -> bool:
	var op: Dictionary = _ops.get(op_id, {})
	return str(op.get("state", "")) == "pending"

## "Resolver sem IA": aborta a chamada e entrega o fallback na hora.
func cancel(op_id: String) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	_abort_http(op)
	_finish(op_id, _fallback(str(op.get("contract", "")), op.get("data", {})), "cancelled", "cancelado pelo jogador")

func pending_count() -> int:
	var total := 0
	for op in _ops.values():
		if str((op as Dictionary).get("state", "")) == "pending":
			total += 1
	return total

func _attempt(op_id: String) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	var attempt := int(op.get("attempt", 0)) + 1
	op["attempt"] = attempt
	var contract := str(op.get("contract", ""))
	var prompt := Contracts.prompt(contract, op.get("prompt_ctx", {}), examples)
	var rejected := str(op.get("validation", ""))
	if int(op.get("retries", 0)) > 0 and rejected != "":
		prompt += "\nA tentativa anterior foi rejeitada: %s. Corrija exatamente esse ponto e responda apenas o JSON.\n" % rejected
	op["prompt"] = prompt
	op["deadline_ms"] = Time.get_ticks_msec() + TIMEOUT_MS
	_ops[op_id] = op
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_MS / 1000.0
	add_child(http)
	op["http"] = http
	_ops[op_id] = op
	http.request_completed.connect(_on_response.bind(op_id, attempt))
	# Structured output opcional: "format":"json" melhora conformidade, mas em
	# alguns casos pode omitir o motivo de aborto; desativado por padrão.
	var body := {
		"model": model,
		"prompt": prompt,
		"stream": false,
		"think": false,
		"keep_alive": KEEP_ALIVE,
		"options": {"temperature": 0.2, "num_predict": _max_tokens(contract), "seed": 7},
	}
	if use_json_format:
		body["format"] = "json"
	var err := http.request(GENERATE_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_retry_or_fallback(op_id, "erro de transporte " + str(err))
		return

## O voto bancada por bancada é o contrato mais longo: 13 partidos não cabem
## nos mesmos 320 tokens de uma manchete. O valor vem do catálogo.
func _max_tokens(contract: String) -> int:
	return DecisionCatalog.max_tokens(contract)

func _on_timeout(op_id: String, attempt: int) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	if int(op.get("attempt", 0)) != attempt:
		return
	_abort_http(op)
	_retry_or_fallback(op_id, "timeout de %d s" % int(TIMEOUT_MS / 1000))

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, op_id: String, attempt: int) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	if int(op.get("attempt", 0)) != attempt:
		return
	var http: HTTPRequest = op.get("http", null)
	if http != null and is_instance_valid(http):
		http.queue_free()
	op["http"] = null
	_ops[op_id] = op
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_retry_or_fallback(op_id, "HTTP %d" % response_code)
		return
	var text: String = body.get_string_from_utf8()
	op["raw"] = text
	_ops[op_id] = op
	var outer: Variant = JSON.parse_string(text)
	if not (outer is Dictionary):
		_retry_or_fallback(op_id, "envelope JSON inválido")
		return
	if (outer as Dictionary).has("error"):
		_retry_or_fallback(op_id, "modelo abortou: " + str((outer as Dictionary).get("error", "")))
		return
	var inner_text := _extract_json(str((outer as Dictionary).get("response", "")))
	if inner_text == "":
		_retry_or_fallback(op_id, "resposta vazia")
		return
	var parsed: Variant = JSON.parse_string(inner_text)
	var validation := _validate(str(op.get("contract", "")), parsed, op.get("data", {}))
	if bool(validation.get("ok", false)):
		# Bloco incompleto: uma correção pedindo as bancadas que faltaram. Se o
		# modelo repetir o corte, o que veio é aceito e o motor vota o resto.
		var missing: Array = validation.get("missing", []) if validation.get("missing") is Array else []
		if not missing.is_empty() and int(op.get("retries", 0)) == 0:
			_retry_or_fallback(op_id, "faltaram bancadas: " + ", ".join(PackedStringArray(missing)))
			return
		op["validation"] = "ok" if missing.is_empty() else "parcial: faltaram " + ", ".join(PackedStringArray(missing))
		_ops[op_id] = op
		_finish(op_id, validation, "ollama", "")
		return
	_retry_or_fallback(op_id, str(validation.get("error", "resposta incoerente")))

## Aceita JSON cercado por markdown ou por texto solto: pega do primeiro
## "{" ao último "}". O conteúdo continua validado pelo contrato.
func _extract_json(text: String) -> String:
	var clean := text.strip_edges()
	var start := clean.find("{")
	var end := clean.rfind("}")
	if start < 0 or end <= start:
		return ""
	return clean.substr(start, end - start + 1)

func _retry_or_fallback(op_id: String, reason: String) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	op["validation"] = reason
	op["retries"] = int(op.get("retries", 0)) + 1
	_ops[op_id] = op
	if int(op.get("attempt", 0)) < MAX_ATTEMPTS:
		_attempt(op_id)
		return
	_finish(op_id, _fallback(str(op.get("contract", "")), op.get("data", {})), "fallback", reason)

func _abort_http(op: Dictionary) -> void:
	var http: HTTPRequest = op.get("http", null)
	if http != null and is_instance_valid(http):
		http.cancel_request()
		http.queue_free()
	op["http"] = null

func _finish(op_id: String, value: Dictionary, source: String, reason: String) -> void:
	var op: Dictionary = _ops.get(op_id, {})
	if op.is_empty() or str(op.get("state", "")) != "pending":
		return
	_abort_http(op)
	op["state"] = "done" if source != "cancelled" else "cancelled"
	_ops[op_id] = op
	var contract := str(op.get("contract", ""))
	var key := str(op.get("key", ""))
	var fallback_used := source != "ollama" and source != "cache"
	if source == "ollama" or source == "cache":
		_write_cache(key, value)
	_log(op, value, source, reason)
	var payload := {
		"ok": true,
		"value": value,
		"source": source,
		"contract": contract,
		"key": key,
		"fallback_used": fallback_used,
		"reason": reason,
	}
	_deliver(op.get("callback", Callable()), payload)

func _deliver(callback: Callable, payload: Dictionary) -> void:
	if callback.is_valid():
		callback.call(payload)

# ------------------------------------------------------------ validação

func _validate(contract: String, parsed: Variant, data: Dictionary) -> Dictionary:
	match contract:
		Contracts.LEGISLATIVE:
			return Contracts.validate_legislative(parsed, data.get("seat_map", {}))
		Contracts.ELECTORAL:
			return Contracts.normalize_electoral(parsed, data.get("base_shares", {}))
		Contracts.EVENTS:
			return Contracts.validate_event(parsed)
		Contracts.INTERNATIONAL:
			return Contracts.validate_international(parsed, data.get("party_ids", []))
	return {"ok": false, "error": "contrato desconhecido: " + contract}

func _fallback(contract: String, data: Dictionary) -> Dictionary:
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

# ---------------------------------------------------------- cache e log

func _state() -> Dictionary:
	if game != null and is_instance_valid(game) and game.get("state") is Dictionary:
		return game.state
	return {}

func _read_cache(key: String) -> Dictionary:
	var state: Dictionary = _state()
	if not state.has("ai_decisions"):
		return {}
	var cache: Variant = state.get("ai_decisions")
	if not (cache is Dictionary):
		return {}
	var entry: Variant = (cache as Dictionary).get(key, {})
	if entry is Dictionary and (entry as Dictionary).has("value"):
		return entry
	return {}

func _write_cache(key: String, value: Dictionary) -> void:
	var state: Dictionary = _state()
	if state.is_empty():
		return
	var cache: Dictionary = {}
	if state.get("ai_decisions") is Dictionary:
		cache = state.ai_decisions
	cache[key] = {"value": value, "version": CACHE_VERSION, "model": model, "ts": Time.get_unix_time_from_system()}
	state["ai_decisions"] = cache

func _open_log() -> void:
	var abs_dir := ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	_log_path = "%s/ai_%d.jsonl" % [LOG_DIR, int(Time.get_unix_time_from_system())]
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	if _log_file == null:
		last_error = "log indisponível"

func _log(op: Dictionary, value: Dictionary, source: String, reason: String) -> void:
	if _log_file == null:
		return
	var entry := {
		"contract": op.get("contract", ""),
		"key": op.get("key", ""),
		"prompt": op.get("prompt", ""),
		"raw": op.get("raw", ""),
		"validated": value,
		"model": model,
		"validation_result": op.get("validation", ""),
		"retry_count": int(op.get("retries", 0)),
		"fallback_used": source != "ollama" and source != "cache",
		"source": source,
		"reason": reason,
		"timestamp": Time.get_unix_time_from_system(),
	}
	_log_file.store_line(JSON.stringify(entry))
	_log_file.flush()

func log_path() -> String:
	return _log_path

func _load_examples() -> void:
	examples = []
	if not FileAccess.file_exists(EXAMPLES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXAMPLES_PATH))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if data.get("examples") is Array:
		examples = data.get("examples", [])
	if str(data.get("model", "")) != "":
		model = str(data.get("model", MODEL))
	if data.has("use_json_format"):
		use_json_format = bool(data.get("use_json_format", false))
	elif data.has("json_format"):
		var jf: Variant = data.get("json_format")
		use_json_format = jf == true or str(jf) == "json"
