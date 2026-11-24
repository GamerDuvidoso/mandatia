extends RefCounted
## Fase G — contrato comum v1.
##
## Esta camada define o envelope persistente dos módulos sociais. Ela não produz
## saúde, educação, trabalho, renda ou políticas sociais; apenas mantém contrato,
## proveniência, referências e idempotência para que esses módulos compartilhem
## a população única de state.demography.

const SCHEMA_VERSION := 1
const MAX_HISTORY := 120
const MODULE_KEYS := ["territory", "health", "education", "labor", "income", "social_policy"]
const DATA_STATUS := ["official", "estimated", "model"]

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))]

static func _module_skeleton() -> Dictionary:
	return {
		"status": "pending",
		"last_tick": "",
		"history": [],
		"provenance": {},
	}

static func _initial_state() -> Dictionary:
	var modules := {}
	for key in MODULE_KEYS:
		modules[key] = _module_skeleton()
	return {
		"schema_version": SCHEMA_VERSION,
		"last_tick": "",
		"population_ref": {
			"path": "state.demography.population",
			"source": "demography",
			"status": "model",
		},
		"regions": {
			"status": "pending",
			"ids": [],
			"weights": {},
			"reconciled": false,
		},
		"modules": modules,
		"history": [],
		"provenance": {
			"contract": {"source": "phase_g_contract.gd", "status": "model"},
			"population": {"source": "state.demography", "status": "model"},
		},
		"migration": {"from_schema": 0, "to_schema": SCHEMA_VERSION},
	}

static func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_merge_missing(target[key], defaults[key])

static func _ensure_history(value: Variant) -> Array:
	return value if value is Array else []

static func ensure(st: Dictionary) -> void:
	var raw: Variant = st.get("phase_g", {})
	var phase: Dictionary = raw if raw is Dictionary else {}
	var version := int(phase.get("schema_version", 0))
	var defaults := _initial_state()
	# Migração somente aditiva: campos desconhecidos e dados já produzidos são preservados.
	if version < SCHEMA_VERSION:
		phase["migration"] = {"from_schema": version, "to_schema": SCHEMA_VERSION}
	_merge_missing(phase, defaults)
	phase["schema_version"] = SCHEMA_VERSION
	phase["history"] = _ensure_history(phase.get("history", []))
	if phase.history.size() > MAX_HISTORY:
		phase.history = phase.history.slice(0, MAX_HISTORY)
	phase["provenance"] = phase.provenance if phase.get("provenance") is Dictionary else {}
	phase["modules"] = phase.modules if phase.get("modules") is Dictionary else {}
	for key in MODULE_KEYS:
		var module_value: Variant = phase.modules.get(key, {})
		var module: Dictionary = module_value if module_value is Dictionary else {}
		_merge_missing(module, _module_skeleton())
		module["history"] = _ensure_history(module.get("history", []))
		if module.history.size() > MAX_HISTORY:
			module.history = module.history.slice(0, MAX_HISTORY)
		phase.modules[key] = module
	st["phase_g"] = phase

static func population_reference(st: Dictionary) -> Dictionary:
	ensure(st)
	var demography: Dictionary = st.get("demography", {}) if st.get("demography") is Dictionary else {}
	var status := str(demography.get("source_status", "model"))
	if status not in DATA_STATUS:
		status = "model"
	var phase: Dictionary = st.phase_g
	var reference: Dictionary = phase.get("population_ref", {}) if phase.get("population_ref") is Dictionary else {}
	reference["path"] = "state.demography.population"
	reference["source"] = "demography"
	reference["status"] = status
	reference["value"] = float(demography.get("population", 0.0))
	phase["population_ref"] = reference
	phase["provenance"]["population"] = {"source": "state.demography", "status": status, "path": "state.demography.population"}
	st["phase_g"] = phase
	return reference.duplicate(true)

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var phase: Dictionary = st.phase_g
	var tick := _stamp(st)
	if str(phase.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}
	var population := population_reference(st)
	phase = st.phase_g
	var row := {
		"date": tick,
		"population": float(population.get("value", 0.0)),
		"population_source": str(population.get("status", "model")),
		"regions_reconciled": bool((phase.get("regions", {}) as Dictionary).get("reconciled", false)),
	}
	var history: Array = phase.get("history", [])
	history.push_front(row)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	phase["history"] = history
	phase["last_tick"] = tick
	phase["provenance"]["last_tick"] = {"source": "phase_g_contract.monthly", "status": "model", "date": tick}
	st["phase_g"] = phase
	return row

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	return (st.phase_g as Dictionary).duplicate(true)
