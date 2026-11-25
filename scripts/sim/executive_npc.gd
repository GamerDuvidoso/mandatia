extends RefCounted
## Fase 4 (A2) — executivo NPC (presidente / primeiro-ministro).
##
## Decide sancionar, vetar, decretar, nomear, demitir, convocar coalizão,
## discursar e negociar com a oposição. O motor impõe a coerência: só se sanciona
## ou veta o projeto que passou NESTE mês, e o veto devolve metade do impulso da
## lei (a lei não vigora). Nomear e demitir custam estabilidade; nada disso
## mexe em cadeiras, votos ou D'Hondt.
##
## Estado em `state.executive` (aditivo).

const CONFIG_PATH := "res://config/executive.json"
const VERSION := 1
const AutonomousLegislature := preload("res://scripts/sim/autonomous_legislature.gd")

const ACTIONS := ["sancionar", "vetar", "decretar", "nomear", "demitir", "convocar_coalizao", "discursar", "negociar_oposicao"]
const BILL_ACTIONS := ["sancionar", "vetar"]

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	_config = {
		"veto_chance": 0.22,
		"low_stability": 42.0,
		"max_history": 12,
		"effects": {
			"sancionar": {"stability": 0.2, "approval": 0.1},
			"vetar": {"stability": -0.6, "approval": -0.4, "revert": 0.5},
			"decretar": {"stability": 0.3, "debt": 0.03},
			"nomear": {"stability": 0.4},
			"demitir": {"stability": -0.4},
			"convocar_coalizao": {"cohesion": 0.8},
			"discursar": {"approval": 0.3},
			"negociar_oposicao": {"cohesion": 0.5, "stability": 0.2},
		},
	}
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config = (parsed as Dictionary).duplicate(true)
	return _config

static func _num(source: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = source.get(key, null)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback

static func _sub(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func ensure(st: Dictionary) -> Dictionary:
	var raw: Variant = st.get("executive", {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if int(state.get("version", 0)) < VERSION:
		state["migration"] = {"from": int(state.get("version", 0)), "to": VERSION}
	if not (state.get("countries", {}) is Dictionary):
		state["countries"] = {}
	state["version"] = VERSION
	st["executive"] = state
	return state

static func _country_row(state: Dictionary, country: String) -> Dictionary:
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	if not row.has("history") or not (row["history"] is Array):
		row["history"] = []
	if not row.has("last_action") or not (row["last_action"] is Dictionary):
		row["last_action"] = {}
	return row

## Projeto que passou neste mês, ou {} — é o único alvo válido de sanção/veto.
static func _current_bill(wc: Dictionary, stamp: String) -> Dictionary:
	var raw: Variant = wc.get("last_vote", {})
	if not (raw is Dictionary):
		return {}
	var vote: Dictionary = raw
	if str(vote.get("month", "")) != stamp or not bool(vote.get("passed", false)):
		return {}
	if str(vote.get("bill", "")) == "":
		return {}
	return vote

static func _bill_title(bill_id: String) -> String:
	for row in AutonomousLegislature.AGENDA:
		if str((row as Dictionary).get("id", "")) == bill_id:
			return str((row as Dictionary).get("title", bill_id))
	return bill_id

## Contingência mínima da seção 4: veto só se o projeto passou; sem projeto, o
## chefe de governo reage ao próprio desgaste.
static func minimum_rule(wc: Dictionary, bill: Dictionary, stamp: String) -> Dictionary:
	var cfg := config()
	var country := str(wc.get("id", ""))
	var roll := _hash01(country + "|exec|" + stamp)
	if not bill.is_empty():
		if roll < _num(cfg, "veto_chance", 0.22):
			return {
				"action": "vetar",
				"target_id": "b_" + str(bill.get("bill", "")),
				"stance": "firme",
				"reason": "projeto aprovado fora da agenda do governo",
			}
		return {
			"action": "sancionar",
			"target_id": "b_" + str(bill.get("bill", "")),
			"stance": "moderado",
			"reason": "projeto aprovado pelo legislativo",
		}
	if _num(wc, "stability", 60.0) < _num(cfg, "low_stability", 42.0):
		return {"action": "negociar_oposicao", "target_id": "", "stance": "conciliador", "reason": "estabilidade abaixo de 42"}
	if roll < 0.10:
		return {"action": "discursar", "target_id": "", "stance": "moderado", "reason": "agenda do mês"}
	return {"action": "decretar", "target_id": "", "stance": "moderado", "reason": "agenda do mês"}

## Normaliza a decisão validada. Não escreve estado.
static func apply_action(args: Dictionary) -> Dictionary:
	if args.is_empty():
		return {}
	var action := str(args.get("action", ""))
	if not ACTIONS.has(action):
		return {}
	var stance := str(args.get("stance", "moderado"))
	if not ["firme", "moderado", "conciliador"].has(stance):
		stance = "moderado"
	return {
		"action": action,
		"target_id": str(args.get("target_id", "")),
		"stance": stance,
		"reason": str(args.get("reason", "")),
	}

static func monthly(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	var state := ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var stamp := "%d-%02d" % [year, month]
	var bill := _current_bill(wc, stamp)
	var decision := apply_action(override)
	var source := "ia"
	var action := str(decision.get("action", ""))
	if decision.is_empty() or not _coherent(action, str(decision.get("target_id", "")), bill):
		decision = minimum_rule(wc, bill, stamp)
		action = str(decision.get("action", ""))
		source = "contingencia"
	var event := _apply(wc, profile, action, decision, bill, country + "|" + stamp)
	var row := _country_row(state, country)
	row["last_action"] = {
		"action": action,
		"target_id": str(decision.get("target_id", "")),
		"stance": str(decision.get("stance", "moderado")),
		"reason": str(decision.get("reason", "")),
		"month": stamp,
		"source": source,
	}
	var history: Array = row.get("history", [])
	history.push_front({"month": stamp, "action": action, "target_id": str(decision.get("target_id", "")), "source": source})
	if history.size() > int(_num(config(), "max_history", 12.0)):
		history.resize(int(_num(config(), "max_history", 12.0)))
	row["history"] = history
	if event.is_empty():
		row.erase("event")
	else:
		row["event"] = event
	var rows: Dictionary = state.get("countries", {})
	rows[country] = row
	state["countries"] = rows
	state["version"] = VERSION
	return row

## Coerência do motor: sanção e veto exigem o projeto do mês como alvo.
static func _coherent(action: String, target_id: String, bill: Dictionary) -> bool:
	if not BILL_ACTIONS.has(action):
		return true
	if bill.is_empty():
		return false
	return target_id == "b_" + str(bill.get("bill", ""))

static func _apply(wc: Dictionary, profile: Dictionary, action: String, decision: Dictionary, bill: Dictionary, seed: String) -> Dictionary:
	var table := _sub(config(), "effects")
	var row := _sub(table, action)
	wc["stability"] = clampf(_num(wc, "stability", 60.0) + _num(row, "stability", 0.0), 5.0, 98.0)
	wc["approval"] = clampf(_num(wc, "approval", 50.0) + _num(row, "approval", 0.0), 3.0, 92.0)
	wc["coalition_cohesion"] = clampf(_num(wc, "coalition_cohesion", 60.0) + _num(row, "cohesion", 0.0), 0.0, 100.0)
	profile["debt"] = clampf(_num(profile, "debt", 60.0) + _num(row, "debt", 0.0), 0.0, 200.0)
	var revert := _num(row, "revert", 0.0)
	if revert > 0.0 and not bill.is_empty():
		_revert_bill(profile, str(bill.get("bill", "")), revert)
		var list: Array = wc.get("vetoed_bills", []) if wc.get("vetoed_bills") is Array else []
		var bill_id := str(bill.get("bill", ""))
		if not list.has(bill_id):
			list.push_front(bill_id)
			if list.size() > 6:
				list.resize(6)
			wc["vetoed_bills"] = list
	if not BILL_ACTIONS.has(action):
		return {}
	if _hash01(seed + "|fact") > 0.55:
		return {}
	var name := str(wc.get("name", wc.get("id", "")))
	var title := _bill_title(str(bill.get("bill", "")))
	var description := "Executivo de %s %s o projeto %s." % [name, "veta" if action == "vetar" else "sanciona", title]
	return {
		"category": "executivo",
		"description": description,
		"headline": "%s: %s %s" % [name, "veto ao" if action == "vetar" else "sanção do", title],
		"trigger": str(decision.get("reason", "")),
		"consequences": ["metade do efeito da lei revertida" if action == "vetar" else "lei em vigor"],
		"actors": [str(wc.get("government_party", ""))],
		"news": true,
	}

static func _revert_bill(profile: Dictionary, bill_id: String, revert: float) -> void:
	for raw in AutonomousLegislature.AGENDA:
		var bill: Dictionary = raw
		if str(bill.get("id", "")) != bill_id:
			continue
		var effects: Dictionary = bill.get("effects", {}) if bill.get("effects") is Dictionary else {}
		profile["growth"] = clampf(_num(profile, "growth", 2.0) - _num(effects, "growth", 0.0) * revert, -8.0, 10.0)
		profile["inflation"] = clampf(_num(profile, "inflation", 4.5) - _num(effects, "inflation", 0.0) * revert, 0.5, 40.0)
		profile["unemployment"] = clampf(_num(profile, "unemployment", 7.0) - _num(effects, "unemployment", 0.0) * revert, 2.0, 30.0)
		profile["debt"] = clampf(_num(profile, "debt", 60.0) - _num(effects, "debt", 0.0) * revert, 0.0, 200.0)
		return

static func summary(st: Dictionary, country: String) -> Dictionary:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
