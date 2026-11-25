extends RefCounted
## Fase 1 — memória curta por ator.
##
## Cada ator guarda poucos fatos resumidos e uma persona. A memória vive em
## `state.ai_memory`, portanto persiste no save junto com o resto do estado e
## entra na migração aditiva (campo novo, valor padrão, nunca invalida save).
##
## Script puro: recebe o `state` e mexe apenas na chave `ai_memory`.

const VERSION := 1
const MAX_FACTS := 6
const MAX_TEXT := 160

static func _defaults() -> Dictionary:
	return {"version": VERSION, "actors": {}}

static func ensure(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get("ai_memory", {})
	var memory: Dictionary = raw if raw is Dictionary else {}
	var version := int(memory.get("version", 0))
	if version < VERSION:
		memory["migration"] = {"from": version, "to": VERSION}
	if not (memory.get("actors", {}) is Dictionary):
		memory["actors"] = {}
	memory["version"] = VERSION
	state["ai_memory"] = memory
	return memory

static func _actor(memory: Dictionary, actor_id: String) -> Dictionary:
	var actors: Dictionary = memory.get("actors", {})
	var raw: Variant = actors.get(actor_id, {})
	var actor: Dictionary = raw if raw is Dictionary else {}
	if not (actor.get("facts", []) is Array):
		actor["facts"] = []
	if not (actor.get("persona", "") is String):
		actor["persona"] = ""
	actors[actor_id] = actor
	memory["actors"] = actors
	return actor

## Guarda um fato curto. Fatos repetidos não duplicam; o mais antigo cai.
static func remember(state: Dictionary, actor_id: String, fact: String, stamp: String = "") -> void:
	var text := fact.strip_edges().replace("\n", " ").replace("\r", " ")
	if text == "":
		return
	if text.length() > MAX_TEXT:
		text = text.substr(0, MAX_TEXT)
	var key := "%s: %s" % [stamp, text] if stamp != "" else text
	var memory := ensure(state)
	var actor := _actor(memory, actor_id)
	var facts: Array = actor.get("facts", [])
	for existing in facts:
		if str((existing as Dictionary).get("text", "")) == text:
			return
	facts.push_front({"text": text, "stamp": stamp, "key": key})
	if facts.size() > MAX_FACTS:
		facts.resize(MAX_FACTS)
	actor["facts"] = facts
	state["ai_memory"] = memory

static func recall(state: Dictionary, actor_id: String, limit: int = MAX_FACTS) -> Array:
	var memory := ensure(state)
	var actors: Dictionary = memory.get("actors", {})
	var raw: Variant = actors.get(actor_id, {})
	if not (raw is Dictionary):
		return []
	var facts: Variant = (raw as Dictionary).get("facts", [])
	if not (facts is Array):
		return []
	var out: Array = []
	for item in facts:
		if out.size() >= limit:
			break
		if not (item is Dictionary):
			continue
		var stamp := str((item as Dictionary).get("stamp", ""))
		var text := str((item as Dictionary).get("text", ""))
		out.append("%s: %s" % [stamp, text] if stamp != "" else text)
	return out

static func set_persona(state: Dictionary, actor_id: String, persona: String) -> void:
	var memory := ensure(state)
	var actor := _actor(memory, actor_id)
	actor["persona"] = persona.strip_edges().substr(0, MAX_TEXT)
	state["ai_memory"] = memory

static func persona(state: Dictionary, actor_id: String, fallback: String = "") -> String:
	var memory := ensure(state)
	var actors: Dictionary = memory.get("actors", {})
	var raw: Variant = actors.get(actor_id, {})
	if not (raw is Dictionary):
		return fallback
	var value := str((raw as Dictionary).get("persona", ""))
	return value if value != "" else fallback

static func forget(state: Dictionary, actor_id: String) -> void:
	var memory := ensure(state)
	var actors: Dictionary = memory.get("actors", {})
	actors.erase(actor_id)
	memory["actors"] = actors
	state["ai_memory"] = memory

static func actor_count(state: Dictionary) -> int:
	var memory := ensure(state)
	return (memory.get("actors", {}) as Dictionary).size()
