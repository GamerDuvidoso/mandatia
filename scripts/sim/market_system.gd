extends RefCounted
## Fase 4 (A6) — mercado financeiro e empresas.
##
## O ator tem um humor por país: sentimento, prêmio de risco, pressão cambial,
## fluxo de capital e decisão das empresas. A camada de IA escolhe esse humor;
## o `decision_applier` entrega o override e SÓ ESTE MÓDULO converte em macro.
## Sem decisão (modo "off", timeout, JSON inválido), a contingência abaixo é o
## comportamento do mês — determinística, sem RNG guardado.
##
## Estado em `state.market` (aditivo: save antigo recebe o padrão em `ensure`).

const CONFIG_PATH := "res://config/market.json"
const VERSION := 1
const MAX_HISTORY := 6

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	_config = {
		"target_inflation": 3.0,
		"premium": {"base_bp": 30.0, "debt_slope": 1.0, "pessimism_bp": 90.0, "min_bp": 0.0, "max_bp": 400.0},
		"fx": {"inflation_slope": 0.5, "pessimism_pct": 1.5, "min_pct": -10.0, "max_pct": 10.0},
		"pass_through": {"growth": 10000.0, "inflation": 0.02, "debt": 2200.0},
		"thresholds": {"exit_premium_bp": 120.0, "entry_premium_bp": 60.0, "notable_premium_bp": 120.0},
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
	var raw: Variant = st.get("market", {})
	var state: Dictionary = raw if raw is Dictionary else {}
	if int(state.get("version", 0)) < VERSION:
		state["migration"] = {"from": int(state.get("version", 0)), "to": VERSION}
	if not (state.get("countries", {}) is Dictionary):
		state["countries"] = {}
	state["version"] = VERSION
	st["market"] = state
	return state

static func _country_row(state: Dictionary, country: String) -> Dictionary:
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	var row: Dictionary = raw if raw is Dictionary else {}
	if not row.has("history") or not (row["history"] is Array):
		row["history"] = []
	if not row.has("business") or not (row["business"] is Dictionary):
		row["business"] = {}
	return row

## Contingência: o humor que o motor deduz sozinho quando a IA não decide.
## Números redondos, faixas fechadas e hash estável do país + mês.
static func neutral_mood(wc: Dictionary, profile: Dictionary, base: Dictionary, stamp: String) -> Dictionary:
	var cfg := config()
	var target := _num(cfg, "target_inflation", 3.0)
	var potential := _num(base, "potential_growth", 2.0)
	var inflation := _num(profile, "inflation", 4.5)
	var growth := _num(profile, "growth", potential)
	var debt := _num(profile, "debt", 60.0)
	var country := str(wc.get("id", ""))
	var premium_cfg := _sub(cfg, "premium")
	var fx_cfg := _sub(cfg, "fx")
	var activity_gap := growth - potential
	var debt_gap := maxf(0.0, debt - 60.0) / 60.0
	var noise := (_hash01(country + "|market|" + stamp) - 0.5) * 0.2
	var sentiment := clampf(0.55 * activity_gap - 0.35 * (inflation - target) - 0.5 * debt_gap + noise, -1.0, 1.0)
	var premium := _num(premium_cfg, "base_bp", 30.0) + _num(premium_cfg, "debt_slope", 1.0) * maxf(0.0, debt - 50.0) + _num(premium_cfg, "pessimism_bp", 90.0) * maxf(0.0, -sentiment)
	premium = clampf(premium, _num(premium_cfg, "min_bp", 0.0), _num(premium_cfg, "max_bp", 400.0))
	var fx := _num(fx_cfg, "inflation_slope", 0.5) * (inflation - target) + _num(fx_cfg, "pessimism_pct", 1.5) * maxf(0.0, -sentiment)
	fx = clampf(fx, _num(fx_cfg, "min_pct", -10.0), _num(fx_cfg, "max_pct", 10.0))
	var thresholds := _sub(cfg, "thresholds")
	var flow := "neutro"
	if premium >= _num(thresholds, "exit_premium_bp", 120.0) or sentiment <= -0.35:
		flow = "saida"
	elif sentiment >= 0.35 and premium <= _num(thresholds, "entry_premium_bp", 60.0):
		flow = "entrada"
	var invest := "manter"
	if sentiment < -0.2 or premium > 150.0:
		invest = "reduzir"
	elif sentiment > 0.3 and premium < 80.0:
		invest = "ampliar"
	var layoffs := "poucas"
	if growth < potential - 1.5:
		layoffs = "muitas"
	elif growth < potential - 0.3:
		layoffs = "alguma"
	return {
		"sentiment": sentiment,
		"risk_premium_bp": premium,
		"fx_pressure_pct": fx,
		"capital_flow": flow,
		"business": {"invest": invest, "layoffs": layoffs},
		"reason": "dívida %.0f%%, inflação %.1f%%, atividade %+.1f p.p." % [debt, inflation, activity_gap],
	}

## Normaliza a decisão validada. NÃO escreve estado: devolve o override do mês.
static func apply_mood(args: Dictionary) -> Dictionary:
	if args.is_empty():
		return {}
	var flow := str(args.get("capital_flow", "neutro"))
	if not ["entrada", "saida", "neutro"].has(flow):
		flow = "neutro"
	var business := {}
	var raw_business: Variant = args.get("business", {})
	if raw_business is Dictionary:
		for key in (raw_business as Dictionary).keys():
			if str(key) in ["invest", "layoffs"]:
				business[str(key)] = str((raw_business as Dictionary)[key])
	return {
		"sentiment": clampf(_num(args, "sentiment", 0.0), -1.0, 1.0),
		"risk_premium_bp": clampf(_num(args, "risk_premium_bp", 40.0), 0.0, 400.0),
		"fx_pressure_pct": clampf(_num(args, "fx_pressure_pct", 0.0), -10.0, 10.0),
		"capital_flow": flow,
		"business": business,
		"reason": str(args.get("reason", "")),
	}

## Um mês do ator. `override` é a decisão validada e aplicada pelo applier;
## vazio significa contingência. Devolve a linha do mês.
static func monthly(st: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	ensure(st)
	var country := str(wc.get("id", ""))
	if country == "":
		return {}
	var stamp := "%d-%02d" % [year, month]
	var cfg := config()
	var mood := apply_mood(override)
	var source := "ia"
	if mood.is_empty():
		mood = neutral_mood(wc, profile, base, stamp)
		source = "contingencia"
	var sentiment := float(mood.get("sentiment", 0.0))
	var premium := float(mood.get("risk_premium_bp", 40.0))
	var fx := float(mood.get("fx_pressure_pct", 0.0))
	var through := _sub(cfg, "pass_through")
	# Motor: prêmio vira custo de capital, câmbio vira preço, pessimismo vira
	# atividade. Tudo com clamp; nenhum valor absoluto vem da IA.
	profile["growth"] = clampf(_num(profile, "growth", 2.0) - premium / maxf(1.0, _num(through, "growth", 10000.0)) + sentiment * 0.02, -8.0, 10.0)
	profile["inflation"] = clampf(_num(profile, "inflation", 4.5) + fx * _num(through, "inflation", 0.02), 0.5, 40.0)
	profile["debt"] = clampf(_num(profile, "debt", 60.0) + maxf(0.0, premium - 60.0) / maxf(1.0, _num(through, "debt", 2200.0)), 0.0, 200.0)
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var row := _country_row(state, country)
	row["sentiment"] = snappedf(sentiment, 0.01)
	row["risk_premium_bp"] = premium
	row["fx_pressure_pct"] = snappedf(fx, 0.1)
	row["capital_flow"] = str(mood.get("capital_flow", "neutro"))
	row["business"] = (mood.get("business", {}) as Dictionary).duplicate(true) if mood.get("business") is Dictionary else {}
	row["reason"] = str(mood.get("reason", ""))
	row["source"] = source
	row["month"] = stamp
	var history: Array = row.get("history", [])
	history.push_front({"month": stamp, "sentiment": row["sentiment"], "premium_bp": premium, "flow": row["capital_flow"], "source": source})
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	row["history"] = history
	var event := _event_for(cfg, wc, row, premium, sentiment, country + "|" + stamp)
	if event.is_empty():
		row.erase("event")
	else:
		row["event"] = event
	rows[country] = row
	state["countries"] = rows
	st["market"] = state
	return row

## Fato do mês só quando o prêmio é alto e o hash do país + mês deixa passar:
## evita manchete de mercado todo mês em todos os países.
static func _event_for(cfg: Dictionary, wc: Dictionary, row: Dictionary, premium: float, sentiment: float, seed: String) -> Dictionary:
	var thresholds := _sub(cfg, "thresholds")
	if premium < _num(thresholds, "notable_premium_bp", 120.0):
		return {}
	if _hash01(seed + "|fact") > 0.45:
		return {}
	var name := str(wc.get("name", wc.get("id", "")))
	var direction := "sobe" if sentiment < 0.0 else "recua"
	var description := "Prêmio de risco de %s %s para %d p.b. com fluxo %s." % [name, direction, int(round(premium)), str(row.get("capital_flow", "neutro"))]
	return {
		"category": "mercado",
		"description": description,
		"headline": "%s: prêmio de risco em %d p.b." % [name, int(round(premium))],
		"trigger": "humor do mercado (%s) e dívida do país" % str(row.get("source", "")),
		"consequences": ["custo de capital do mês", "pressão cambial"],
		"actors": [],
		"news": true,
	}

static func summary(st: Dictionary, country: String) -> Dictionary:
	var state := ensure(st)
	var rows: Dictionary = state.get("countries", {})
	var raw: Variant = rows.get(country, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
