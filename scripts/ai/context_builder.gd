extends RefCounted
## Fase 1 — contexto compacto de uma decisão.
##
## O modelo local é pequeno: prompt longo faz o Ollama abortar por repetição.
## Por isso o contexto enviado ao modelo é curto e sem números absolutos
## desnecessários: valores arredondados, faixas, IDs permitidos e os fatores
## mais recentes do `causal_log`.
##
## Script puro e determinístico: mesma entrada, mesma saída. Não escreve estado.

const Catalog := preload("res://scripts/ai/decision_catalog.gd")

const MAX_TOKENS := 600
const MONTH_FACTS_TOKENS := 300
const DEFAULT_MAX_FACTS := 6

## Campos macro que sempre entram no contexto de um ator de país.
const MACRO_KEYS := ["inflation", "unemployment", "growth", "debt", "approval", "stability"]

static func round_to(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return snappedf(value, step)

## Faixa textual: devolve o rótulo da primeira borda >= valor.
static func band(value: float, edges: Array, labels: Array = []) -> String:
	for i in edges.size():
		if value <= float(edges[i]):
			if i < labels.size():
				return str(labels[i])
			return "faixa_%d" % i
	if labels.size() > edges.size():
		return str(labels[edges.size()])
	return "faixa_%d" % edges.size()

## Remove do texto o que não deve chegar ao modelo como instrução: quebras,
## chaves, setas de tag e markdown básico. Preserva `{{placeholder}}`.
static func sanitize_text(text: String) -> String:
	var out := text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	out = out.replace("{", " ").replace("}", " ")
	out = out.replace("<", " ").replace(">", " ")
	out = out.replace("`", " ").replace("#", " ")
	out = out.replace("\"", " ").replace("'", " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()

## Números macro do país do escopo, arredondados para o prompt.
static func compact_state(state: Dictionary, scope: Dictionary = {}) -> Dictionary:
	var country := str(scope.get("country", state.get("country_id", "")))
	var profile := _profile(state, country)
	var world_row := _world_row(state, country)
	var out := {}
	for key in MACRO_KEYS:
		if profile.has(key):
			out[key] = _round_key(key, float(profile[key]))
	if world_row.has("approval"):
		out["approval"] = round_to(float(world_row["approval"]), 0.1)
	if world_row.has("stability"):
		out["stability"] = round_to(float(world_row["stability"]), 0.1)
	if world_row.has("policy_priority"):
		out["priority"] = str(world_row["policy_priority"])
	return out

static func _round_key(key: String, value: float) -> float:
	match key:
		"inflation", "unemployment", "growth":
			return round_to(value, 0.1)
		"debt", "approval", "stability":
			return round_to(value, 1.0)
	return round_to(value, 0.1)

static func _profile(state: Dictionary, country: String) -> Dictionary:
	var intl: Variant = state.get("international_state", {})
	if not (intl is Dictionary):
		return {}
	var profiles: Variant = (intl as Dictionary).get("profiles", {})
	if not (profiles is Dictionary):
		return {}
	var row: Variant = (profiles as Dictionary).get(country, {})
	return (row as Dictionary).duplicate(true) if row is Dictionary else {}

static func _world_row(state: Dictionary, country: String) -> Dictionary:
	var world: Variant = state.get("world", {})
	if not (world is Dictionary):
		return {}
	var countries: Variant = (world as Dictionary).get("countries", {})
	if not (countries is Dictionary):
		return {}
	var row: Variant = (countries as Dictionary).get(country, {})
	return (row as Dictionary).duplicate(true) if row is Dictionary else {}

## Fatos já decididos no mês (`month_facts`), no máximo ~300 tokens.
## `categories` vazio significa "qualquer categoria".
static func month_facts(state: Dictionary, categories: Array = [], limit: int = DEFAULT_MAX_FACTS) -> Array:
	var world: Variant = state.get("world", {})
	if not (world is Dictionary):
		return []
	var history: Variant = (world as Dictionary).get("history", [])
	if not (history is Array):
		return []
	var out: Array = []
	for raw in history:
		if out.size() >= limit:
			break
		if not (raw is Dictionary):
			continue
		var fact: Dictionary = raw
		var category := str(fact.get("category", ""))
		if not categories.is_empty() and not categories.has(category):
			continue
		var line := "%s/%d %s: %s" % [
			str(fact.get("year", "")), int(fact.get("month", 0)),
			str(fact.get("country", "")), sanitize_text(str(fact.get("description", ""))),
		]
		out.append(line.substr(0, 140))
	return out

## Fatores do `causal_log` (se existir). Só os mais recentes.
static func top_factors(state: Dictionary, limit: int = 3) -> Array:
	var log: Variant = state.get("causal_log", [])
	if not (log is Array):
		return []
	var out: Array = []
	for i in range((log as Array).size() - 1, -1, -1):
		if out.size() >= limit:
			break
		var raw: Variant = (log as Array)[i]
		if not (raw is Dictionary):
			continue
		var text := str((raw as Dictionary).get("reason", (raw as Dictionary).get("text", "")))
		if text == "":
			continue
		out.append(sanitize_text(text).substr(0, 120))
	return out

## Monta o contexto final do contrato: macro + IDs permitidos + fatos.
static func build(contract: String, scope: Dictionary, state: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var ctx := {}
	ctx["contract"] = contract
	var allowed := Catalog.allowed(contract)
	if not allowed.is_empty():
		ctx["allowed"] = allowed
	if scope.has("country"):
		ctx["country"] = str(scope["country"])
		ctx["state"] = compact_state(state, scope)
	if scope.has("actor"):
		ctx["actor"] = str(scope["actor"])
	var ids: Variant = extra.get("ids_permitidos", [])
	if ids is Array and not (ids as Array).is_empty():
		ctx["ids_permitidos"] = (ids as Array).duplicate()
	var facts: Variant = extra.get("month_facts", null)
	if facts is Array and not (facts as Array).is_empty():
		ctx["month_facts"] = (facts as Array).duplicate()
	else:
		var categories: Array = extra.get("categories", []) if extra.get("categories") is Array else []
		var auto_facts := month_facts(state, categories)
		if not auto_facts.is_empty():
			ctx["month_facts"] = auto_facts
	var factors := top_factors(state)
	if not factors.is_empty():
		ctx["factors"] = factors
	for key in extra.keys():
		if key in ["ids_permitidos", "month_facts", "categories"]:
			continue
		ctx[key] = extra[key]
	return trim(ctx, MAX_TOKENS)

## Estimativa grosseira de tokens (4 caracteres por token).
static func estimate_tokens(ctx: Dictionary) -> int:
	return int(ceil(float(JSON.stringify(ctx).length()) / 4.0))

## Corta o contexto até o orçamento, na ordem menos importante primeiro.
static func trim(ctx: Dictionary, max_tokens: int = MAX_TOKENS) -> Dictionary:
	var out := ctx.duplicate(true)
	var order := ["factors", "month_facts", "history", "recent"]
	for key in order:
		if estimate_tokens(out) <= max_tokens:
			break
		if out.has(key):
			out.erase(key)
	if estimate_tokens(out) <= max_tokens:
		return out
	# Ainda grande: encurta listas longas e textos.
	for key in out.keys():
		var value: Variant = out[key]
		if value is Array:
			var list: Array = value
			while list.size() > 2 and estimate_tokens(out) > max_tokens:
				list.remove_at(list.size() - 1)
			out[key] = list
		elif value is String and (value as String).length() > 80:
			out[key] = (value as String).substr(0, 80)
	return out
