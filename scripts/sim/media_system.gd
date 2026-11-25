extends RefCounted
## Fase 4 (A9) — mídia.
##
## Decide enquadramento e viés do mês. A consequência é de agenda-setting: o
## enquadramento é escolhido junto de povo e mídia (passo 3 da ordem causal) e a
## pressão sobre aprovação e estabilidade fecha o mês depois do bloco político.
## O multiplicador de exposição fica publicado em `state.media` para o
## `scandal_system` usar na onda 4.
##
## Estado em `state.media` (aditivo).

const CONFIG_PATH := "res://config/media.json"
const VERSION := 1
const MAX_HISTORY := 6

const FRAMES := ["crise_economica", "escandalo", "entrega_governo", "seguranca", "eleicao", "rotina"]

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	_config = {
		"max_history": 6,
		"pass_through": {"approval": 0.8, "stability": 0.4},
		"exposure_base": 1.0,
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
	var raw: Variant = st.get("media", {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if int(state.get("version", 0)) < VERSION:
		state["migration"] = {"from": int(state.get("version", 0)), "to": VERSION}
	if not (state.get("countries", {}) is Dictionary):
		state["countries"] = {}
	state["version"] = VERSION
	st["media"] = state
	return state

static func _country_row(state: Dictionary, country: String) -> Dictionary:
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	if not row.has("history") or not (row["history"] is Array):
		row["history"] = []
	return row

## Contingência: o enquadramento que qualquer redação deduziria dos números.
static func neutral_frame(wc: Dictionary, profile: Dictionary, base: Dictionary) -> Dictionary:
	var potential := _num(base, "potential_growth", 2.0)
	var inflation := _num(profile, "inflation", 4.5)
	var growth := _num(profile, "growth", potential)
	var approval := _num(wc, "approval", 50.0)
	var stability := _num(wc, "stability", 60.0)
	var frame := "rotina"
	if inflation > 7.0 or growth < 0.0:
		frame = "crise_economica"
	elif stability < 40.0:
		frame = "seguranca"
	elif int(wc.get("months_to_election", 99)) <= 3:
		frame = "eleicao"
	elif approval > 55.0 and growth >= potential:
		frame = "entrega_governo"
	var bias := clampf((growth - potential) * 0.06 - maxf(0.0, inflation - 4.5) * 0.04, -1.0, 1.0)
	return {
		"frame": frame,
		"bias": bias,
		"focus_id": "",
		"reason": "inflação %.1f%%, atividade %+.2f p.p., aprovação %.0f" % [inflation, growth - potential, approval],
	}

## Normaliza a decisão validada. Não escreve estado.
static func apply_frame(args: Dictionary) -> Dictionary:
	if args.is_empty():
		return {}
	var frame := str(args.get("frame", "rotina"))
	if not FRAMES.has(frame):
		frame = "rotina"
	return {
		"frame": frame,
		"bias": clampf(_num(args, "bias", 0.0), -1.0, 1.0),
		"focus_id": str(args.get("focus_id", "")),
		"reason": str(args.get("reason", "")),
	}

## Passo 3 da ordem causal: decide o enquadramento do mês e publica a exposição.
static func monthly(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	var state := ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var stamp := "%d-%02d" % [year, month]
	var decision := apply_frame(override)
	var source := "ia"
	if decision.is_empty():
		decision = neutral_frame(wc, profile, base)
		source = "contingencia"
	var row := _country_row(state, country)
	var bias := float(decision.get("bias", 0.0))
	row["frame"] = str(decision.get("frame", "rotina"))
	row["bias"] = snappedf(bias, 0.01)
	row["focus_id"] = str(decision.get("focus_id", ""))
	row["reason"] = str(decision.get("reason", ""))
	row["exposure"] = snappedf(_num(config(), "exposure_base", 1.0) + absf(bias), 0.01)
	row["source"] = source
	row["month"] = stamp
	row["applied"] = false
	var history: Array = row.get("history", [])
	history.push_front({"month": stamp, "frame": str(row["frame"]), "bias": row["bias"], "source": source})
	if history.size() > int(_num(config(), "max_history", 6.0)):
		history.resize(int(_num(config(), "max_history", 6.0)))
	row["history"] = history
	var rows: Dictionary = state.get("countries", {})
	rows[country] = row
	state["countries"] = rows
	state["version"] = VERSION
	return row

## Fecha o mês: a cobertura pressiona aprovação e estabilidade. Chamado depois
## do bloco político, para que a consequência não seja sobrescrita pelo governo.
static func close_month(st: Dictionary, wc: Dictionary) -> void:
	var state := ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	if not (raw is Dictionary):
		return
	var row: Dictionary = raw
	if bool(row.get("applied", false)):
		return
	var through := _sub(config(), "pass_through")
	var bias := _num(row, "bias", 0.0)
	wc["approval"] = clampf(_num(wc, "approval", 50.0) + bias * _num(through, "approval", 0.8), 3.0, 92.0)
	wc["stability"] = clampf(_num(wc, "stability", 60.0) + bias * _num(through, "stability", 0.4), 5.0, 98.0)
	row["applied"] = true
	rows[country] = row
	state["countries"] = rows

## Multiplicador de exposição que o `scandal_system` vai consultar na onda 4.
static func exposure(st: Dictionary, country: String) -> float:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	if not (raw is Dictionary):
		return _num(config(), "exposure_base", 1.0)
	return _num(raw, "exposure", _num(config(), "exposure_base", 1.0))

static func summary(st: Dictionary, country: String) -> Dictionary:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
