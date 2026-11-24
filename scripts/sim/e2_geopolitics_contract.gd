extends RefCounted
## E2 — contrato persistente de defesa e geopolítica.
##
## Esta fundação normaliza o envelope e a proveniência sem substituir
## state.geopolitics nem aplicar deslocados à população. O contrato detalhado de
## fluxos fica em e2_forced_flows_contract.gd; a integração demográfica segue bloqueada.

const SCHEMA_VERSION := 1
const MAX_HISTORY := 120
const DATA_STATUS := ["official", "estimated", "model"]

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))]

static func _defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"last_tick": "",
		"history": [],
		"provenance": {
			"contract": {"source": "e2_geopolitics_contract.gd", "status": "model"},
			"military": {"source": "config/geopolitics.json", "status": "estimated"},
			"conflicts": {"source": "conflict_system.gd", "status": "model"},
		},
		"geopolitics_ref": "state.geopolitics",
		"humanitarian_flows": {
			"status": "partial",
			"reason": "Contrato E2/E registra fluxos; integração com state.demography permanece bloqueada",
			"flows": [],
		},
		"modules": {
			"military": {"status": "partial", "last_tick": ""},
			"conflicts": {"status": "partial", "last_tick": ""},
			"sanctions": {"status": "partial", "last_tick": ""},
			"humanitarian": {"status": "blocked", "last_tick": ""},
			"reconstruction": {"status": "partial", "last_tick": ""},
		},
		"migration": {"from_schema": 0, "to_schema": SCHEMA_VERSION},
	}

static func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_merge_missing(target[key], defaults[key])

static func ensure(st: Dictionary) -> void:
	var raw: Variant = st.get("e2", {})
	var contract: Dictionary = raw if raw is Dictionary else {}
	var version := int(contract.get("schema_version", 0))
	if version < SCHEMA_VERSION:
		contract["migration"] = {"from_schema": version, "to_schema": SCHEMA_VERSION}
	_merge_missing(contract, _defaults())
	contract["schema_version"] = SCHEMA_VERSION
	contract["history"] = contract.history if contract.get("history") is Array else []
	if contract.history.size() > MAX_HISTORY:
		contract.history = contract.history.slice(0, MAX_HISTORY)
	contract["provenance"] = contract.provenance if contract.get("provenance") is Dictionary else {}
	contract["modules"] = contract.modules if contract.get("modules") is Dictionary else {}
	for key in ["military", "conflicts", "sanctions", "humanitarian", "reconstruction"]:
		var module: Dictionary = contract.modules.get(key, {}) if contract.modules.get(key, {}) is Dictionary else {}
		_merge_missing(module, {"status": "partial", "last_tick": ""})
		contract.modules[key] = module
	st["e2"] = contract

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var contract: Dictionary = st.e2
	var tick := _stamp(st)
	if str(contract.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}
	var geopolitics: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	var row := {
		"date": tick,
		"military_countries": (geopolitics.get("military", {}) as Dictionary).size(),
		"active_conflicts": _active_conflicts(geopolitics),
		"humanitarian_status": "blocked",
		"source": "state.geopolitics",
	}
	var history: Array = contract.get("history", [])
	history.push_front(row)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	contract["history"] = history
	contract["last_tick"] = tick
	contract["provenance"]["last_tick"] = {"source": "e2_geopolitics_contract.monthly", "status": "model", "date": tick}
	st["e2"] = contract
	return row

static func _active_conflicts(geopolitics: Dictionary) -> int:
	var count := 0
	for raw in geopolitics.get("conflicts", []) if geopolitics.get("conflicts") is Array else []:
		if raw is Dictionary and str(raw.get("status", "")) in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao", "cessar_fogo"]:
			count += 1
	return count

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	return (st.e2 as Dictionary).duplicate(true)
