extends RefCounted
## Fase 4 (A5) — judiciário.
##
## Decide constitucionalidade de lei aprovada, avanço de investigação, disputa
## eleitoral e legalidade de greve. LIMITE DO PROMPT: o tribunal nunca altera
## contagem de votos, cadeiras ou D'Hondt; só efeitos procedimentais (suspender
## lei, arquivar, avançar investigação).
##
## O caso nasce do fato do mês (lei aprovada e contestada). Sem caso aberto não
## há julgamento — e o override da IA só é aceito para o caso que existe.
##
## Estado em `state.judiciary` (aditivo).

const CONFIG_PATH := "res://config/judiciary.json"
const VERSION := 1
const AutonomousLegislature := preload("res://scripts/sim/autonomous_legislature.gd")

const RULINGS := ["procedente", "improcedente", "suspender", "arquivar", "avancar_investigacao"]

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	_config = {
		"justices": 15,
		"challenge_chance": 0.35,
		"close_split_seats": 4,
		"max_cases": 8,
		"max_history": 12,
		"effects": {
			"suspender_revert": 0.5,
			"suspended_stability": -0.2,
			"procedente_stability": 0.3,
			"improcedente_stability": -0.1,
			"investigation_approval": -0.3,
			"investigation_stability": -0.2,
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

static func _bill(bill_id: String) -> Dictionary:
	for row in AutonomousLegislature.AGENDA:
		if str((row as Dictionary).get("id", "")) == bill_id:
			return row
	return {}

static func ensure(st: Dictionary) -> Dictionary:
	var raw: Variant = st.get("judiciary", {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if int(state.get("version", 0)) < VERSION:
		state["migration"] = {"from": int(state.get("version", 0)), "to": VERSION}
	if not (state.get("countries", {}) is Dictionary):
		state["countries"] = {}
	if not (state.get("seq") is int) and not (state.get("seq") is float):
		state["seq"] = 0
	state["version"] = VERSION
	st["judiciary"] = state
	return state

static func _country_row(state: Dictionary, country: String) -> Dictionary:
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	# `row.get(chave, {})` já devolve o tipo padrão: testar só o tipo deixaria
	# a linha vazia e o resumo sem caso nenhum.
	if not row.has("cases") or not (row["cases"] is Dictionary):
		row["cases"] = {}
	if not row.has("history") or not (row["history"] is Array):
		row["history"] = []
	if not row.has("last_ruling") or not (row["last_ruling"] is Dictionary):
		row["last_ruling"] = {}
	return row

## Abre caso a partir da lei aprovada no próprio mês. Determinístico: o hash do
## país + mês decide se o projeto é contestado.
static func _open_case(state: Dictionary, row: Dictionary, wc: Dictionary, country: String, stamp: String) -> void:
	var raw_vote: Variant = wc.get("last_vote", {})
	if not (raw_vote is Dictionary):
		return
	var vote: Dictionary = raw_vote
	if str(vote.get("month", "")) != stamp or not bool(vote.get("passed", false)):
		return
	var bill_id := str(vote.get("bill", ""))
	if bill_id == "":
		return
	var cfg := config()
	if _hash01(country + "|court|" + stamp) > _num(cfg, "challenge_chance", 0.35):
		return
	var cases: Dictionary = row.get("cases", {})
	for key in cases.keys():
		var existing: Variant = cases[key]
		if existing is Dictionary and str((existing as Dictionary).get("bill", "")) == bill_id:
			return
	var seq := int(state.get("seq", 0)) + 1
	state["seq"] = seq
	var case_id := "c_%d" % seq
	cases[case_id] = {
		"id": case_id, "bill": bill_id, "type": "lei", "opened": stamp,
		"status": "pendente", "ayes": int(vote.get("ayes", 0)), "nayes": int(vote.get("nayes", 0)),
	}
	# Casos antigos caem: o tribunal não acumula pauta infinita.
	if cases.size() > int(_num(cfg, "max_cases", 8.0)):
		var ids: Array = cases.keys()
		ids.sort()
		while ids.size() > int(_num(cfg, "max_cases", 8.0)):
			cases.erase(ids.pop_front())
	row["cases"] = cases

static func _pending(row: Dictionary) -> Dictionary:
	var cases: Dictionary = row.get("cases", {})
	var ids: Array = cases.keys()
	ids.sort()
	for key in ids:
		var raw: Variant = cases[key]
		if raw is Dictionary and str((raw as Dictionary).get("status", "")) == "pendente":
			return raw
	return {}

## Contingência: maioria estreita derruba a lei; maioria folgada a confirma.
## A divisão do plenário é derivada do caso, não sorteada.
static func minimum_rule(case: Dictionary) -> Dictionary:
	var cfg := config()
	var justices := int(_num(cfg, "justices", 15.0))
	var thin := maxi(0, int(case.get("ayes", 0)) - int(case.get("nayes", 0))) <= int(_num(cfg, "close_split_seats", 4.0))
	var ruling := "suspender" if thin else "procedente"
	var ayes := int(float(justices) / 2.0) + 1
	if _hash01(str(case.get("id", "")) + "|split") < 0.5:
		ayes += 1
	ayes = clampi(ayes, 1, justices - 1)
	return {
		"ruling": ruling,
		"vote_split": [ayes, justices - ayes],
		"reason": "aprovação %s no legislativo" % ("por margem estreita" if thin else "com margem estável"),
	}

## Normaliza a decisão validada: sem estado, sem alterar votos ou cadeiras.
static func apply_ruling(args: Dictionary) -> Dictionary:
	if args.is_empty():
		return {}
	var case_id := str(args.get("case_id", ""))
	var ruling := str(args.get("ruling", ""))
	if case_id == "" or not RULINGS.has(ruling):
		return {}
	var split: Array = []
	var raw_split: Variant = args.get("vote_split", [])
	if raw_split is Array:
		for item in raw_split:
			if typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT:
				split.append(clampi(int(item), 0, int(_num(config(), "justices", 15.0))))
	return {
		"case_id": case_id,
		"ruling": ruling,
		"vote_split": split,
		"reason": str(args.get("reason", "")),
	}

static func monthly(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	var state := ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var stamp := "%d-%02d" % [year, month]
	var row := _country_row(state, country)
	_open_case(state, row, wc, country, stamp)
	var case := _pending(row)
	if case.is_empty():
		_save(state, country, row)
		return {}
	var decision := apply_ruling(override)
	var source := "ia"
	if decision.is_empty() or str(decision.get("case_id", "")) != str(case.get("id", "")):
		# Caso inexistente no plano: o motor julga pelo próprio critério.
		decision = minimum_rule(case)
		source = "contingencia"
	var ruling := str(decision.get("ruling", "arquivar"))
	var event := _apply(wc, profile, case, ruling, str(case.get("id", "")) + "|" + stamp)
	var cases: Dictionary = row.get("cases", {})
	var closed: Dictionary = cases.get(str(case.get("id", "")), {})
	closed["status"] = "julgado"
	closed["ruling"] = ruling
	closed["decided"] = stamp
	closed["source"] = source
	cases[str(case.get("id", ""))] = closed
	row["cases"] = cases
	row["last_ruling"] = {
		"case_id": str(case.get("id", "")), "ruling": ruling, "month": stamp,
		"vote_split": decision.get("vote_split", []), "reason": str(decision.get("reason", "")),
		"source": source,
	}
	var history: Array = row.get("history", [])
	history.push_front({"month": stamp, "case_id": str(case.get("id", "")), "ruling": ruling, "source": source})
	if history.size() > int(_num(config(), "max_history", 12.0)):
		history.resize(int(_num(config(), "max_history", 12.0)))
	row["history"] = history
	if not event.is_empty():
		row["event"] = event
	else:
		row.erase("event")
	_save(state, country, row)
	return row

static func _save(state: Dictionary, country: String, row: Dictionary) -> void:
	var rows: Dictionary = state.get("countries", {})
	rows[country] = row
	state["countries"] = rows
	state["version"] = VERSION

## Efeitos procedimentais com clamp. `suspender` devolve metade do impulso da
## lei ao macro (a lei para de produzir efeito; não há retroatividade total).
static func _apply(wc: Dictionary, profile: Dictionary, case: Dictionary, ruling: String, seed: String) -> Dictionary:
	var effects := _sub(config(), "effects")
	var name := str(wc.get("name", wc.get("id", "")))
	match ruling:
		"suspender":
			var bill := _bill(str(case.get("bill", "")))
			var bill_effects: Dictionary = bill.get("effects", {}) if bill.get("effects") is Dictionary else {}
			var revert := _num(effects, "suspender_revert", 0.5)
			profile["growth"] = clampf(_num(profile, "growth", 2.0) - _num(bill_effects, "growth", 0.0) * revert, -8.0, 10.0)
			profile["inflation"] = clampf(_num(profile, "inflation", 4.5) - _num(bill_effects, "inflation", 0.0) * revert, 0.5, 40.0)
			profile["unemployment"] = clampf(_num(profile, "unemployment", 7.0) - _num(bill_effects, "unemployment", 0.0) * revert, 2.0, 30.0)
			profile["debt"] = clampf(_num(profile, "debt", 60.0) - _num(bill_effects, "debt", 0.0) * revert, 0.0, 200.0)
			wc["stability"] = clampf(_num(wc, "stability", 60.0) + _num(effects, "suspended_stability", -0.2), 5.0, 98.0)
			_remember_suspended(wc, str(case.get("bill", "")))
			if _hash01(seed + "|fact") > 0.5:
				return {
					"category": "judiciario",
					"description": "Tribunal de %s suspende a lei %s por inconstitucionalidade." % [name, str(bill.get("title", str(case.get("bill", ""))))],
					"headline": "%s: lei %s suspensa pelo tribunal" % [name, str(bill.get("title", "projeto"))],
					"trigger": "contestação no mês da aprovação",
					"consequences": ["metade do efeito da lei revertida", "estabilidade -0,2"],
					"actors": [],
					"news": true,
				}
		"procedente":
			wc["stability"] = clampf(_num(wc, "stability", 60.0) + _num(effects, "procedente_stability", 0.3), 5.0, 98.0)
		"improcedente":
			wc["stability"] = clampf(_num(wc, "stability", 60.0) + _num(effects, "improcedente_stability", -0.1), 5.0, 98.0)
		"avancar_investigacao":
			wc["approval"] = clampf(_num(wc, "approval", 50.0) + _num(effects, "investigation_approval", -0.3), 3.0, 92.0)
			wc["stability"] = clampf(_num(wc, "stability", 60.0) + _num(effects, "investigation_stability", -0.2), 5.0, 98.0)
	return {}

static func _remember_suspended(wc: Dictionary, bill_id: String) -> void:
	if bill_id == "":
		return
	var list: Array = wc.get("suspended_bills", []) if wc.get("suspended_bills") is Array else []
	if list.has(bill_id):
		return
	list.push_front(bill_id)
	if list.size() > 6:
		list.resize(6)
	wc["suspended_bills"] = list

static func summary(st: Dictionary, country: String) -> Dictionary:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
