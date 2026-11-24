extends RefCounted
## E2/E — contrato persistente de fluxos forçados e humanitários.
##
## Este contrato registra eventos produzidos por conflitos sem converter
## deslocados em população demográfica. Origem e destino desconhecidos não são
## inferidos: o fluxo é preservado como não reconciliado.

const SCHEMA_VERSION := 1
const MAX_HISTORY := 120
const MAX_FLOWS := 240
const MAX_SEEN_EVENTS := 480
const UNRESOLVED := "unresolved"

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))]

static func _defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"last_tick": "",
		"flows": [],
		"history": [],
		"seen_event_ids": [],
		"source_ref": "state.geopolitics.humanitarian_events",
		"status": "partial",
		"demography_integration": "blocked",
		"provenance": {
			"contract": {"source": "e2_forced_flows_contract.gd", "status": "model"},
			"events": {"source": "conflict_system.gd", "status": "model"},
		},
		"reconciliation": {
			"events_seen": 0,
			"flows_recorded": 0,
			"duplicates_ignored": 0,
			"unreconciled": 0,
			"quantity_recorded": 0.0,
		},
	}

static func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_merge_missing(target[key], defaults[key])

static func ensure(st: Dictionary) -> void:
	var raw_e2: Variant = st.get("e2", {})
	var e2: Dictionary = raw_e2 if raw_e2 is Dictionary else {}
	var raw: Variant = e2.get("humanitarian_flows", {})
	var contract: Dictionary = raw if raw is Dictionary else {}
	var version := int(contract.get("schema_version", 0))
	if version < SCHEMA_VERSION:
		contract["migration"] = {"from_schema": version, "to_schema": SCHEMA_VERSION}
	_merge_missing(contract, _defaults())
	contract["schema_version"] = SCHEMA_VERSION
	for key in ["flows", "history", "seen_event_ids"]:
		if not (contract.get(key) is Array):
			contract[key] = []
	for key in ["provenance", "reconciliation"]:
		if not (contract.get(key) is Dictionary):
			contract[key] = {}
	if contract.flows.size() > MAX_FLOWS:
		contract.flows.resize(MAX_FLOWS)
	if contract.history.size() > MAX_HISTORY:
		contract.history.resize(MAX_HISTORY)
	if contract.seen_event_ids.size() > MAX_SEEN_EVENTS:
		contract.seen_event_ids.resize(MAX_SEEN_EVENTS)
	contract["status"] = "partial"
	contract["demography_integration"] = "blocked"
	e2["humanitarian_flows"] = contract
	st["e2"] = e2

static func _valid_event(event: Dictionary) -> bool:
	return str(event.get("event_id", "")) != "" and float(event.get("quantity", 0.0)) > 0.0

static func _flow_from_event(event: Dictionary, tick: String) -> Dictionary:
	var origin := str(event.get("origin", ""))
	var destination := str(event.get("destination", ""))
	var reconciled := origin != "" and destination != ""
	return {
		"flow_id": str(event.get("event_id", "")),
		"origin": origin if origin != "" else UNRESOLVED,
		"destination": destination if destination != "" else UNRESOLVED,
		"category": str(event.get("category", "deslocamento_forcado")),
		"quantity": maxf(0.0, float(event.get("quantity", 0.0))),
		"status": "reconciled" if reconciled else "unreconciled",
		"date": str(event.get("date", tick)),
		"source_event_id": str(event.get("event_id", "")),
		"source_conflict_id": str(event.get("source_conflict_id", "")),
		"provenance": event.get("provenance", {"source": "conflict_system.gd", "status": "model"}),
		"demography_applied": false,
	}

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var e2: Dictionary = st.e2
	var contract: Dictionary = e2.humanitarian_flows
	var tick := _stamp(st)
	if str(contract.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}
	var geopolitics: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	var events: Array = geopolitics.get("humanitarian_events", []) if geopolitics.get("humanitarian_events") is Array else []
	var seen: Array = contract.get("seen_event_ids", [])
	var flows: Array = contract.get("flows", [])
	var recorded := 0
	var duplicates := 0
	var unreconciled := 0
	var quantity := 0.0
	for raw in events:
		if not (raw is Dictionary):
			continue
		var event: Dictionary = raw
		var event_id := str(event.get("event_id", ""))
		if event_id == "":
			continue
		if seen.has(event_id):
			duplicates += 1
			continue
		seen.push_front(event_id)
		if not _valid_event(event):
			unreconciled += 1
			continue
		var flow := _flow_from_event(event, tick)
		flows.push_front(flow)
		recorded += 1
		quantity += float(flow.get("quantity", 0.0))
		if str(flow.get("status", "")) != "reconciled":
			unreconciled += 1
	if seen.size() > MAX_SEEN_EVENTS:
		seen.resize(MAX_SEEN_EVENTS)
	if flows.size() > MAX_FLOWS:
		flows.resize(MAX_FLOWS)
	var row := {
		"date": tick,
		"events_seen": events.size(),
		"flows_recorded": recorded,
		"duplicates_ignored": duplicates,
		"unreconciled": unreconciled,
		"quantity_recorded": quantity,
		"status": "partial",
	}
	var history: Array = contract.get("history", [])
	history.push_front(row)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	var reconciliation: Dictionary = contract.get("reconciliation", {})
	reconciliation["events_seen"] = int(reconciliation.get("events_seen", 0)) + events.size()
	reconciliation["flows_recorded"] = int(reconciliation.get("flows_recorded", 0)) + recorded
	reconciliation["duplicates_ignored"] = int(reconciliation.get("duplicates_ignored", 0)) + duplicates
	reconciliation["unreconciled"] = int(reconciliation.get("unreconciled", 0)) + unreconciled
	reconciliation["quantity_recorded"] = float(reconciliation.get("quantity_recorded", 0.0)) + quantity
	contract["flows"] = flows
	contract["history"] = history
	contract["seen_event_ids"] = seen
	contract["reconciliation"] = reconciliation
	contract["last_tick"] = tick
	contract["status"] = "partial"
	contract["provenance"]["last_tick"] = {"source": "e2_forced_flows_contract.monthly", "status": "model", "date": tick}
	e2["humanitarian_flows"] = contract
	st["e2"] = e2
	return row

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	return (st.e2.humanitarian_flows as Dictionary).duplicate(true)
