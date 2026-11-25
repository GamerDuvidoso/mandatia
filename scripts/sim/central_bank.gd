extends RefCounted
## Fase 4 (A7) — banco central.
##
## A IA escolhe o movimento da taxa (p.b.) e a postura (hawkish / neutro /
## dovish); a validação exige motivo quando o movimento é diferente de zero. O
## motor aplica a taxa e calcula o efeito sobre atividade e inflação — a IA não
## define inflação, crescimento nem nível de crédito.
##
## Contingência: regra determinística de reação (hiato de inflação e de
## atividade, com banda morta). Sem IA o banco central continua reagindo, como
## reagiria um comitê que só olha os números.
##
## Estado em `state.central_bank` (aditivo).

const CONFIG_PATH := "res://config/central_bank.json"
const VERSION := 1
const MAX_HISTORY := 12

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	_config = {
		"target_inflation": 3.0,
		"neutral_rate": 6.5,
		"deadband_bp": 25.0,
		"step_bp": 5.0,
		"min_rate": 1.0,
		"max_rate": 40.0,
		"notable_move_bp": 50.0,
		"weights": {"inflation": 60.0, "activity": -40.0},
		"pass_through": {"growth": 0.015, "inflation": 0.05},
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
	var raw: Variant = st.get("central_bank", {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if int(state.get("version", 0)) < VERSION:
		state["migration"] = {"from": int(state.get("version", 0)), "to": VERSION}
	if not (state.get("countries", {}) is Dictionary):
		state["countries"] = {}
	state["version"] = VERSION
	st["central_bank"] = state
	return state

static func _country_row(state: Dictionary, country: String) -> Dictionary:
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	if not row.has("rate"):
		row["rate"] = _num(config(), "neutral_rate", 6.5)
	if not (row.get("history", []) is Array):
		row["history"] = []
	return row

static func rate(st: Dictionary, country: String) -> float:
	var state := ensure(st)
	return _num(_country_row(state, country), "rate", _num(config(), "neutral_rate", 6.5))

## Contingência: reação determinística ao hiato de inflação e de atividade.
static func minimum_rule(wc: Dictionary, profile: Dictionary, base: Dictionary, current: float) -> Dictionary:
	var cfg := config()
	var target := _num(cfg, "target_inflation", 3.0)
	var potential := _num(base, "potential_growth", 2.0)
	var weights := _sub(cfg, "weights")
	var inflation := _num(profile, "inflation", 4.5)
	var growth := _num(profile, "growth", potential)
	var raw := (inflation - target) * _num(weights, "inflation", 60.0) + (growth - potential) * _num(weights, "activity", -40.0)
	var step := maxf(1.0, _num(cfg, "step_bp", 5.0))
	var move := roundf(raw / step) * step
	if absf(move) < _num(cfg, "deadband_bp", 25.0):
		move = 0.0
	move = clampf(move, -200.0, 200.0)
	var stance := "neutro"
	if move > 0.0:
		stance = "hawkish"
	elif move < 0.0:
		stance = "dovish"
	var reason := "inflação %.1f%% contra meta %.1f%% e atividade %+.2f p.p." % [inflation, target, growth - potential]
	return {
		"rate_move_bp": move,
		"stance": stance,
		"statement": "Taxa %s para %.2f%% ao ano." % ["mantida em" if move == 0.0 else ("elevada" if move > 0.0 else "reduzida"), clampf(current + move / 100.0, _num(cfg, "min_rate", 1.0), _num(cfg, "max_rate", 40.0))],
		"reason": reason,
	}

## Normaliza a decisão validada: só números e enums, sem escrever estado.
static func apply_rate_move(args: Dictionary) -> Dictionary:
	if args.is_empty():
		return {}
	var stance := str(args.get("stance", "neutro"))
	if not ["hawkish", "neutro", "dovish"].has(stance):
		stance = "neutro"
	return {
		"rate_move_bp": clampf(_num(args, "rate_move_bp", 0.0), -200.0, 200.0),
		"stance": stance,
		"statement": str(args.get("statement", "")),
		"reason": str(args.get("reason", "")),
	}

static func monthly(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	var state := ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var stamp := "%d-%02d" % [year, month]
	var cfg := config()
	var row := _country_row(state, country)
	var current := _num(row, "rate", _num(cfg, "neutral_rate", 6.5))
	var decision := apply_rate_move(override)
	var source := "ia"
	if decision.is_empty():
		decision = minimum_rule(wc, profile, base, current)
		source = "contingencia"
	var move := float(decision.get("rate_move_bp", 0.0))
	var rate_now := clampf(current + move / 100.0, _num(cfg, "min_rate", 1.0), _num(cfg, "max_rate", 40.0))
	# Motor: a taxa real menos a neutra é o impulso monetário do mês. A conta é
	# do motor; a decisão só diz para onde mover e com que postura.
	var impulse := rate_now - _num(cfg, "neutral_rate", 6.5)
	var through := _sub(cfg, "pass_through")
	profile["growth"] = clampf(_num(profile, "growth", 2.0) - impulse * _num(through, "growth", 0.015), -8.0, 10.0)
	profile["inflation"] = clampf(_num(profile, "inflation", 4.5) - impulse * _num(through, "inflation", 0.05), 0.5, 40.0)
	row["rate"] = snappedf(rate_now, 0.01)
	row["last_move_bp"] = move
	row["stance"] = str(decision.get("stance", "neutro"))
	row["statement"] = str(decision.get("statement", ""))
	row["reason"] = str(decision.get("reason", ""))
	row["source"] = source
	row["month"] = stamp
	var history: Array = row.get("history", [])
	history.push_front({"month": stamp, "rate": row["rate"], "move_bp": move, "stance": row["stance"], "source": source})
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	row["history"] = history
	var event := _event_for(cfg, wc, row, move, country + "|" + stamp)
	if event.is_empty():
		row.erase("event")
	else:
		row["event"] = event
	var rows: Dictionary = state.get("countries", {})
	rows[country] = row
	state["countries"] = rows
	st["central_bank"] = state
	return row

static func _event_for(cfg: Dictionary, wc: Dictionary, row: Dictionary, move: float, seed: String) -> Dictionary:
	if absf(move) < _num(cfg, "notable_move_bp", 50.0):
		return {}
	if _hash01(seed + "|fact") > 0.6:
		return {}
	var name := str(wc.get("name", wc.get("id", "")))
	var direction := "eleva" if move > 0.0 else "reduz"
	var description := "Banco central de %s %s a taxa básica em %d p.b., para %.2f%% ao ano." % [name, direction, int(round(absf(move))), _num(row, "rate", 6.5)]
	return {
		"category": "juros",
		"description": description,
		"headline": "%s: juros a %.2f%% (%s)" % [name, _num(row, "rate", 6.5), str(row.get("stance", "neutro"))],
		"trigger": str(row.get("reason", "")),
		"consequences": ["crédito", "crescimento e inflação do mês"],
		"actors": [],
		"news": true,
	}

static func summary(st: Dictionary, country: String) -> Dictionary:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
