extends RefCounted
## Fase 1 — catálogo único dos contratos de decisão (`config/ai_catalog.json`).
##
## Script puro: não abre rede, não cria nós e não escreve estado. Quem precisa
## saber o que um contrato permite, quanto tempo tem, quantos tokens pode gastar
## ou qual é a contingência consulta este catálogo em vez de repetir constantes.
##
## Compatibilidade (Fase 2): os quatro contratos antigos continuam com os mesmos
## limites de `scripts/ai/ai_contracts.gd` e `scripts/ai/ollama_client.gd`. A
## equivalência é verificada em `test/test_ai_layer.gd`. Se o JSON faltar, os
## padrões abaixo reproduzem exatamente o comportamento anterior.

const CATALOG_PATH := "res://config/ai_catalog.json"
const SCHEMA_VERSION := "3.0.0"

const DEFAULT_MAX_TOKENS := 220
const DEFAULT_TIMEOUT_MS := 20000
const DEFAULT_MAX_ATTEMPTS := 2
const DEFAULT_TIER := 4
const DEFAULT_PRIORITY := 50

## Valores congelados do cliente atual, usados se o catálogo não existir.
const LEGACY_TOKEN_DEFAULTS := {
	"legislative": 720,
	"electoral": 400,
	"international": 480,
	"events": 220,
}

static var _loaded := false
static var _contracts: Dictionary = {}

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_contracts = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (parsed is Dictionary):
		return
	var raw: Variant = (parsed as Dictionary).get("contracts", {})
	if not (raw is Dictionary):
		return
	for key in (raw as Dictionary).keys():
		var entry: Variant = (raw as Dictionary)[key]
		if entry is Dictionary:
			_contracts[str(key)] = (entry as Dictionary).duplicate(true)

## Recarrega do disco. Usado por testes e pelo editor ao trocar de catálogo.
static func reload() -> void:
	_loaded = false
	_ensure()

static func has(contract: String) -> bool:
	_ensure()
	return _contracts.has(contract)

static func ids() -> Array:
	_ensure()
	var out: Array = _contracts.keys()
	out.sort()
	return out

static func count() -> int:
	_ensure()
	return _contracts.size()

static func get_contract(contract: String) -> Dictionary:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

static func _int_field(contract: String, key: String, fallback: int) -> int:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if not (raw is Dictionary):
		return fallback
	var value: Variant = (raw as Dictionary).get(key, null)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return fallback

static func _str_field(contract: String, key: String, fallback: String) -> String:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if not (raw is Dictionary):
		return fallback
	var value: Variant = (raw as Dictionary).get(key, null)
	if value == null:
		return fallback
	return str(value)

static func _dict_field(contract: String, key: String) -> Dictionary:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if not (raw is Dictionary):
		return {}
	var value: Variant = (raw as Dictionary).get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func max_tokens(contract: String) -> int:
	var fallback := int(LEGACY_TOKEN_DEFAULTS.get(contract, DEFAULT_MAX_TOKENS))
	return _int_field(contract, "max_tokens", fallback)

static func timeout_ms(contract: String) -> int:
	return _int_field(contract, "timeout_ms", DEFAULT_TIMEOUT_MS)

static func max_attempts(contract: String) -> int:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if raw is Dictionary and (raw as Dictionary).has("retries"):
		var retries: Variant = (raw as Dictionary).get("retries", 0)
		if typeof(retries) == TYPE_FLOAT or typeof(retries) == TYPE_INT:
			return maxi(1, 1 + int(retries))
	return _int_field(contract, "max_attempts", DEFAULT_MAX_ATTEMPTS)

static func tier(contract: String) -> int:
	return _int_field(contract, "tier", DEFAULT_TIER)

static func priority(contract: String) -> int:
	return _int_field(contract, "priority", DEFAULT_PRIORITY)

static func cadence(contract: String) -> String:
	return _str_field(contract, "cadence", "monthly")

static func scope(contract: String) -> String:
	return _str_field(contract, "scope", "country")

static func batch(contract: String) -> Dictionary:
	return _dict_field(contract, "batch")

static func allowed(contract: String) -> Dictionary:
	return _dict_field(contract, "allowed")

static func allowed_list(contract: String, key: String) -> Array:
	var raw: Variant = allowed(contract).get(key, [])
	return (raw as Array).duplicate() if raw is Array else []

static func limits(contract: String) -> Dictionary:
	return _dict_field(contract, "limits")

static func fallback_rule(contract: String) -> String:
	return _str_field(contract, "fallback", "")

static func examples(contract: String) -> Array:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if not (raw is Dictionary):
		return []
	var value: Variant = (raw as Dictionary).get("examples", [])
	return (value as Array).duplicate() if value is Array else []

static func is_optional(contract: String) -> bool:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	return raw is Dictionary and bool((raw as Dictionary).get("optional", false))

## Texto de prompt congelado dos quatro contratos antigos (Fase 2).
## Contratos novos ainda não têm prompt no catálogo: a montagem entra quando o
## ator é ligado ao broker.
static func schema(contract: String) -> String:
	return _str_field(contract, "schema", "")

static func rules(contract: String) -> String:
	return _str_field(contract, "rules", "")

## Contratos agrupados por onda de prova (seção 9 do prompt de integração).
static func wave(contract: String) -> int:
	_ensure()
	var raw: Variant = _contracts.get(contract, {})
	if not (raw is Dictionary):
		return 0
	return int((raw as Dictionary).get("wave", tier(contract)))
