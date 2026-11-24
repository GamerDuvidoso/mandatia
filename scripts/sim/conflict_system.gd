extends RefCounted
## E2 — crises diplomáticas, conflitos estratégicos, sanções, refugiados, paz e
## reconstrução.
##
## Nada começa "do nada": conflitos exigem tensão bilateral acumulada, disputa
## declarada, competição por recursos ou escalada de uma crise. O resultado
## militar é abstrato e depende de equipamento, pessoal, logística, prontidão,
## treinamento, tecnologia, indústria, terreno, apoio externo, sanções,
## exaustão e estabilidade política — não de um único número.
##
## Fórmulas (valores 0-100, exceto indicado):
##   poder = 0.20 equip + 0.12 pessoal + 0.15 logística + 0.15 prontidão
##         + 0.10 treino + 0.13 tecnologia + 0.08 indústria + 0.04 marinha
##         + 0.03 aviação
##   frente += (poder_a + apoio_a + terreno_a - sanção_a - exaustão_a)
##           - (poder_b + apoio_b + terreno_b - sanção_b - exaustão_b)
##   baixas_mês ≈ intensidade × (0.45 + poder_defensor/100) × 250–700
##   deslocados += baixas × 2.2 + intensidade × 30
##   custo_mês = PIB_M$ × (0.0008 + intensidade × 0.00001)
## A frente é limitada a [-100,100]; não há conquista total automática. Paz exige
## pressão interna, custo fiscal e/ou mediação; cessar-fogo pode congelar e
## retomar se a causa persistir.

const WorldHistory := preload("res://scripts/sim/world_history.gd")
const Resources := preload("res://scripts/sim/strategic_resources.gd")
const Military := preload("res://scripts/sim/military_system.gd")

const MAX_ACTIVE_CONFLICTS := 7
const CEASEFIRE_MONTHS := 6
const FROZEN_MONTHS := 18
const SANCTION_MONTHS := 18
const MAX_CRISES := 4

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _month_index(st: Dictionary) -> int:
	return int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]

static func _pair_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)

static func _name(st: Dictionary, id: String) -> String:
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	if (world.get("countries", {}) as Dictionary).has(id):
		return str(world.countries[id].get("name", id))
	for row in (st.get("geopolitics", {}).get("military", {}) as Dictionary).values():
		if str((row as Dictionary).get("id", "")) == id:
			return str((row as Dictionary).get("name", id))
	return id

static func _profile(st: Dictionary, id: String) -> Dictionary:
	if id == str(st.get("country_id", "")):
		return {}
	return st.get("international_state", {}).get("profiles", {}).get(id, {}) if st.get("international_state") is Dictionary else {}

static func _military(st: Dictionary, id: String) -> Dictionary:
	return st.get("geopolitics", {}).get("military", {}).get(id, {}) if st.get("geopolitics") is Dictionary else {}

static func _gdp(st: Dictionary, id: String) -> float:
	if id == str(st.get("country_id", "")):
		return maxf(1.0, float(st.get("gdp", 1.0)))
	return maxf(1.0, float(_profile(st, id).get("gdp", 1.0)))

static func _debt(st: Dictionary, id: String) -> float:
	if id == str(st.get("country_id", "")):
		return float(st.get("debt", 60.0))
	return float(_profile(st, id).get("debt", 60.0))

static func _capability(st: Dictionary, id: String) -> float:
	var m := _military(st, id)
	return MilitaryCapability.power(m)

## Pequeno adaptador para evitar preload circular: a fórmula é idêntica à do
## MilitarySystem.capability e é testada separadamente.
class MilitaryCapability:
	static func power(m: Dictionary) -> float:
		return clampf(
			float(m.get("equipment", 30.0)) * 0.20 +
			float(m.get("personnel_index", 20.0)) * 0.12 +
			float(m.get("logistics", 30.0)) * 0.15 +
			float(m.get("readiness", 50.0)) * 0.15 +
			float(m.get("training", 40.0)) * 0.10 +
			float(m.get("tech", 30.0)) * 0.13 +
			float(m.get("industry", 25.0)) * 0.08 +
			float(m.get("navy", 20.0)) * 0.04 +
			float(m.get("air", 25.0)) * 0.03,
			0.0, 100.0)

static func ensure(st: Dictionary, countries: Array) -> void:
	var g: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	for key in ["conflicts", "crises", "sanctions", "humanitarian", "humanitarian_events", "reconstruction", "bilateral"]:
		if not g.has(key):
			g[key] = {} if key in ["humanitarian", "reconstruction", "bilateral"] else []
	if not (g.get("conflict_seq") is int):
		g["conflict_seq"] = 0
	if not (g.get("crisis_seq") is int):
		g["crisis_seq"] = 0
	if not (g.get("stats") is Dictionary):
		g["stats"] = {}
	var military: Dictionary = g.get("military", {}) if g.get("military") is Dictionary else {}
	var ids: Array = military.keys()
	ids.sort()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := str(ids[i])
			var b := str(ids[j])
			if a == str(st.get("country_id", "")) or b == str(st.get("country_id", "")):
				continue
			var key := _pair_key(a, b)
			if (g.bilateral as Dictionary).has(key):
				continue
			var wa: Dictionary = st.get("world", {}).get("countries", {}).get(a, {})
			var wb: Dictionary = st.get("world", {}).get("countries", {}).get(b, {})
			if wa.is_empty() or wb.is_empty():
				continue
			var same_region := str(wa.get("region", "")) == str(wb.get("region", ""))
			var dispute := Resources.dispute(a, b)
			if not same_region and dispute.is_empty():
				continue
			var axis_diff := absf(float(wa.get("government_axis", 0.0)) - float(wb.get("government_axis", 0.0)))
			var competition := (Resources.vulnerability(a, "energia") + Resources.vulnerability(b, "energia")) * 3.0
			var tension := clampf(7.0 + axis_diff * 16.0 + competition + float(dispute.get("weight", 0.0)), 2.0, 72.0)
			g.bilateral[key] = {
				"a": a, "b": b, "tension": tension, "trust": clampf(60.0 - tension * 0.55, 5.0, 80.0),
				"cause": str(dispute.get("cause", "competição regional e diferenças políticas")),
				"dispute": not dispute.is_empty(), "last_conflict": -999,
			}
	st["geopolitics"] = g
	if not st.has("geopolitics_summary"):
		st["geopolitics_summary"] = summary(st)

static func _record(st: Dictionary, country: String, category: String, description: String, trigger: String, consequences: Array, headline := "", news := true) -> void:
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	if world.is_empty():
		return
	WorldHistory.push(world, {
		"year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1)),
		"country": country, "country_name": _name(st, country), "category": category,
		"description": description, "headline": headline if headline != "" else description,
		"trigger": trigger, "consequences": consequences, "actors": [], "news": news,
	}, 2)
	st["world"] = world

static func start_conflict(st: Dictionary, a: String, b: String, cause: String, category := "interestatal") -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {})
	var active := 0
	for c in g.get("conflicts", []):
		if str((c as Dictionary).get("status", "")) in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao", "cessar_fogo", "congelado"]:
			active += 1
		if _pair_key(str(c.get("a", "")), str(c.get("b", ""))) == _pair_key(a, b):
			return {"ok": false, "reason": "Já existe conflito ativo neste par"}
	if active >= MAX_ACTIVE_CONFLICTS:
		return {"ok": false, "reason": "Limite de conflitos ativos atingido"}
	var ma := _military(st, a)
	var mb := _military(st, b)
	if ma.is_empty() or mb.is_empty():
		return {"ok": false, "reason": "País sem capacidade militar simulada"}
	g["conflict_seq"] = int(g.get("conflict_seq", 0)) + 1
	var conflict := {
		"id": "C%03d" % int(g.conflict_seq), "category": category, "a": a, "b": b,
		"a_name": _name(st, a), "b_name": _name(st, b),
		"start": _stamp(st), "cause": cause, "objectives": "conter ameaça, preservar território e obter vantagem negociadora",
		"status": "tensao", "stage": 1, "front": 0.0, "intensity": 18.0,
		"months": 0, "casualties": {a: 0, b: 0}, "displaced": 0,
		"cost": {a: 0.0, b: 0.0}, "support": {a: 0.0, b: 0.0},
		"peace_pressure": 0.0, "ceasefire_months": 0, "frozen_months": 0,
		"last_update": _stamp(st), "history": [{"month": _stamp(st), "status": "tensao", "note": cause}],
	}
	g.conflicts.push_front(conflict)
	var key := _pair_key(a, b)
	if (g.bilateral as Dictionary).has(key):
		var pair: Dictionary = g.bilateral[key]
		pair["last_conflict"] = _month_index(st)
		pair["tension"] = clampf(float(pair.get("tension", 60.0)) + 8.0, 0.0, 100.0)
		g.bilateral[key] = pair
	g.stats["conflicts_started"] = int(g.stats.get("conflicts_started", 0)) + 1
	st["geopolitics"] = g
	_record(st, a, "conflito", "%s e %s entram em confronto: %s." % [_name(st, a), _name(st, b), cause], "tensão bilateral e objetivos incompatíveis", ["mobilização", "risco econômico", "pressão humanitária"], "%s e %s entram em confronto" % [_name(st, a), _name(st, b)])
	return {"ok": true, "id": conflict.id}

static func _spawn_crisis(st: Dictionary, id: String, severity: float, cause: String, scope := "player") -> bool:
	var g: Dictionary = st.get("geopolitics", {})
	for crisis in g.get("crises", []):
		if str((crisis as Dictionary).get("country", "")) == id and str((crisis as Dictionary).get("status", "")) in ["aberta", "escalando"]:
			return false
	if (g.get("crises", []) as Array).size() >= MAX_CRISES:
		return false
	g["crisis_seq"] = int(g.get("crisis_seq", 0)) + 1
	var crisis := {
		"id": "X%03d" % int(g.crisis_seq), "country": id, "country_name": _name(st, id),
		"scope": scope, "start": _stamp(st), "cause": cause, "severity": clampf(severity, 5.0, 95.0),
		"status": "aberta", "stage": 1, "idle": 0, "escalation": 0,
		"history": [{"month": _stamp(st), "note": cause}],
		"economic_exposure": Resources.vulnerability(id, "comercio"),
		"options": ["negociar", "protestar", "mediar", "sancionar", "conceder", "prontidao"],
	}
	g.crises.push_front(crisis)
	g.stats["crises_started"] = int(g.stats.get("crises_started", 0)) + 1
	st["geopolitics"] = g
	_record(st, id, "crise", "Crise diplomática com %s: %s." % [_name(st, id), cause], "tensão acima do limiar e incidente Diplomático", ["severidade %.0f" % severity, "exposição econômica", "possibilidade de escalada"], "Crise diplomática entre %s e %s" % [_name(st, str(st.get("country_id", "BR"))), _name(st, id)])
	return true

static func _crisis_index(g: Dictionary, id: String) -> int:
	for i in (g.get("crises", []) as Array).size():
		if str(g.crises[i].get("id", "")) == id:
			return i
	return -1

static func respond_crisis(st: Dictionary, crisis_id: String, option: String) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {})
	var index := _crisis_index(g, crisis_id)
	if index < 0:
		return {"ok": false, "reason": "Crise inexistente"}
	var crisis: Dictionary = g.crises[index]
	if str(crisis.get("status", "")) != "aberta" and str(crisis.get("status", "")) != "escalando":
		return {"ok": false, "reason": "Crise já encerrada"}
	var target := str(crisis.get("country", ""))
	var cost := 120.0
	if option in ["mediar", "conceder"]:
		cost = 180.0
	if option == "sancionar":
		var applied := impose_sanction(st, target, "comércio")
		if not bool(applied.get("ok", false)):
			return applied
		crisis["severity"] = clampf(float(crisis.severity) + 8.0, 0.0, 100.0)
		crisis["status"] = "escalando"
	elif option == "prontidao":
		var mob := Military.mobilize(st, str(st.get("country_id", "BR")), "parcial")
		if not bool(mob.get("ok", false)):
			return mob
		crisis["severity"] = clampf(float(crisis.severity) + 5.0, 0.0, 100.0)
		crisis["status"] = "escalando"
	elif option in ["negociar", "mediar", "conceder", "protestar"]:
		if float(st.get("funds", 0.0)) < cost:
			return {"ok": false, "reason": "Caixa insuficiente para a resposta (M$ %d)" % int(cost)}
		st["funds"] = float(st.funds) - cost
		if option == "negociar":
			crisis["severity"] = clampf(float(crisis.severity) - 18.0, 0.0, 100.0)
			st["credibility"] = clampf(float(st.get("credibility", 30.0)) + 1.0, 0.0, 100.0)
		elif option == "mediar":
			crisis["severity"] = clampf(float(crisis.severity) - 26.0, 0.0, 100.0)
			st["credibility"] = clampf(float(st.get("credibility", 30.0)) + 2.0, 0.0, 100.0)
		elif option == "conceder":
			crisis["severity"] = clampf(float(crisis.severity) - 34.0, 0.0, 100.0)
			st["approval"] = clampf(float(st.get("approval", 45.0)) - 2.0, 0.0, 100.0)
		else:
			crisis["severity"] = clampf(float(crisis.severity) + 12.0, 0.0, 100.0)
			st["approval"] = clampf(float(st.get("approval", 45.0)) + 1.0, 0.0, 100.0)
		var rel: Dictionary = _relation(st, target)
		if not rel.is_empty():
			var cut := 10.0 if option in ["negociar", "mediar"] else (16.0 if option == "conceder" else 4.0)
			rel["tension"] = clampf(float(rel.get("tension", 0.0)) - cut, 0.0, 100.0)
			rel["cooperation"] = clampf(float(rel.get("cooperation", 40.0)) + (8.0 if option in ["negociar", "mediar"] else -3.0), 0.0, 100.0)
			_set_relation(st, target, rel)
	else:
		return {"ok": false, "reason": "Resposta desconhecida"}
	crisis["idle"] = 0
	crisis["history"].append({"month": _stamp(st), "note": "resposta: " + option})
	if float(crisis.severity) <= 20.0:
		crisis["status"] = "resolvida"
		g.stats["crises_resolved"] = int(g.stats.get("crises_resolved", 0)) + 1
		_record(st, target, "crise", "Crise com %s desescalou após %s." % [_name(st, target), option], "resposta diplomática", ["tensão menor", "credibilidade alterada"], "Crise com %s é desescalada" % _name(st, target))
	g.crises[index] = crisis
	st["geopolitics"] = g
	return {"ok": true, "reason": "Resposta '%s' aplicada; severidade %.0f" % [option, float(crisis.severity)]}

static func _relation(st: Dictionary, id: String) -> Dictionary:
	var intl: Dictionary = st.get("international_state", {}) if st.get("international_state") is Dictionary else {}
	var key := str(st.get("country_id", "BR")) + ":" + id
	return intl.get("relations", {}).get(key, {}) if intl.get("relations", {}) is Dictionary else {}

static func _set_relation(st: Dictionary, id: String, rel: Dictionary) -> void:
	var intl: Dictionary = st.get("international_state", {})
	var relations: Dictionary = intl.get("relations", {})
	relations[str(st.get("country_id", "BR")) + ":" + id] = rel
	intl["relations"] = relations

static func impose_sanction(st: Dictionary, target: String, scope := "comércio", imposer := "") -> Dictionary:
	if imposer == "":
		imposer = str(st.get("country_id", "BR"))
	if target == "" or target == imposer:
		return {"ok": false, "reason": "Alvo inválido"}
	var g: Dictionary = st.get("geopolitics", {})
	for row in g.get("sanctions", []):
		if str((row as Dictionary).get("target", "")) == target and str((row as Dictionary).get("imposer", "")) == imposer and str((row as Dictionary).get("status", "")) == "ativa":
			return {"ok": false, "reason": "Já existe sanção ativa deste emissor contra o alvo"}
	if imposer == str(st.get("country_id", "")):
		var rel := _relation(st, target)
		if rel.is_empty():
			return {"ok": false, "reason": "País não encontrado"}
		if float(rel.get("tension", 0.0)) < 25.0:
			return {"ok": false, "reason": "Tensão insuficiente para sanção"}
	var scope_effect: float = float({"comércio": 0.22, "financeiro": 0.30, "tecnologia": 0.26, "armas": 0.20, "recursos": 0.24}.get(scope, 0.22))
	g.sanctions.push_front({
		"id": "S%d" % (int(g.get("sanction_seq", 0)) + 1), "imposer": imposer, "target": target,
		"scope": scope, "justification": "pressão política e segurança", "status": "ativa",
		"months_left": SANCTION_MONTHS, "months_active": 0, "enforcement": 0.7,
		"exemptions": "alimentos e medicamentos", "adaptation": 0.0, "effect": scope_effect,
		"compliance": "parcial", "retaliation": 0.35 if scope in ["financeiro", "recursos"] else 0.18,
	})
	g["sanction_seq"] = int(g.get("sanction_seq", 0)) + 1
	g.stats["sanctions_imposed"] = int(g.stats.get("sanctions_imposed", 0)) + 1
	st["geopolitics"] = g
	if imposer == str(st.get("country_id", "")):
		var rel := _relation(st, target)
		if not rel.is_empty():
			rel["tension"] = clampf(float(rel.get("tension", 0.0)) + 14.0, 0.0, 100.0)
			rel["cooperation"] = clampf(float(rel.get("cooperation", 40.0)) - 8.0, 0.0, 100.0)
			_set_relation(st, target, rel)
	_record(st, target, "sancao", "%s impõe sanções de %s a %s." % [_name(st, imposer), scope, _name(st, target)], "pressão política e segurança", ["comércio restrito", "adaptação gradual", "risco de retaliação"], "%s sanciona %s" % [_name(st, imposer), _name(st, target)])
	return {"ok": true, "reason": "Sanção de %s ativa por %d meses" % [scope, SANCTION_MONTHS]}

static func _tick_sanctions(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var sanctions: Array = g.get("sanctions", [])
	for i in sanctions.size():
		var row: Dictionary = sanctions[i]
		if str(row.get("status", "")) != "ativa":
			continue
		row["months_left"] = int(row.get("months_left", 1)) - 1
		row["months_active"] = int(row.get("months_active", 0)) + 1
		row["adaptation"] = clampf(float(row.get("adaptation", 0.0)) + 0.025, 0.0, 0.62)
		var target := str(row.get("target", ""))
		var effect := float(row.get("effect", 0.22)) * (1.0 - float(row.adaptation)) * float(row.get("enforcement", 0.7))
		var profile := _profile(st, target)
		if not profile.is_empty():
			profile["growth"] = clampf(float(profile.get("growth", 2.0)) - effect * 0.55, -12.0, 10.0)
			profile["inflation"] = clampf(float(profile.get("inflation", 4.0)) + effect * 0.30, 0.5, 40.0)
			profile["debt"] = clampf(float(profile.get("debt", 60.0)) + effect * 0.10, 0.0, 220.0)
			var intl_profiles: Dictionary = st.get("international_state", {}).get("profiles", {})
			intl_profiles[target] = profile
			st["international_state"]["profiles"] = intl_profiles
		if target == str(st.get("country_id", "")):
			st["economy"] = clampf(float(st.get("economy", 2.0)) - effect * 0.35, -8.0, 8.0)
			st["inflation"] = clampf(float(st.get("inflation", 4.5)) + effect * 0.22, 1.5, 30.0)
		if int(row.months_left) <= 0:
			row["status"] = "expirada"
			row["months_left"] = 0
			_record(st, target, "sancao", "Sanção de %s contra %s expirou." % [str(row.get("scope", "")), _name(st, target)], "prazo encerrado", ["pressão reduzida", "adaptação consolidada"], "Sanção contra %s expira" % _name(st, target))
		sanctions[i] = row
	g.sanctions = sanctions
	st["geopolitics"] = g

static func _host_for(st: Dictionary, conflict: Dictionary) -> String:
	var a := str(conflict.get("a", ""))
	var b := str(conflict.get("b", ""))
	var options: Array = []
	for id in (st.get("geopolitics", {}).get("military", {}) as Dictionary).keys():
		var key := str(id)
		if key == a or key == b or key == str(st.get("country_id", "")):
			continue
		if Resources.shared_region(st, a, key) or Resources.shared_region(st, b, key):
			options.append(key)
	options.sort()
	return "" if options.is_empty() else str(options[int(_hash01(a + b + _stamp(st)) * options.size()) % options.size()])

static func _humanitarian_tick(st: Dictionary, conflict: Dictionary, new_displaced: int) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var hosts: Dictionary = g.get("humanitarian", {})
	if hosts.is_empty():
		g["humanitarian"] = {}
		hosts = g.humanitarian
	var host := _host_for(st, conflict)
	var inflow := int(float(new_displaced) * 0.10)
	var event_id := "HF-%s-%s" % [str(conflict.get("id", "unknown")), _stamp(st)]
	var events: Array = g.get("humanitarian_events", []) if g.get("humanitarian_events") is Array else []
	var known := false
	for existing in events:
		if existing is Dictionary and str(existing.get("event_id", "")) == event_id:
			known = true
			break
	if not known:
		events.push_front({
			"event_id": event_id,
			"date": _stamp(st),
			"origin": str(conflict.get("a", "")),
			"origin_secondary": str(conflict.get("b", "")),
			"destination": host,
			"category": "deslocamento_forcado_beligerante",
			"quantity": inflow,
			"status": "unreconciled" if host == "" else "recorded",
			"source_conflict_id": str(conflict.get("id", "")),
			"provenance": {"source": "conflict_system.gd", "status": "model", "basis": "war_tick displaced delta"},
		})
		if events.size() > 240:
			events.resize(240)
	g["humanitarian_events"] = events
	st["geopolitics"] = g
	if host == "":
		return
	var h: Dictionary = hosts.get(host, {"hosted": 0, "needs": 0.0, "service_pressure": 0.0, "housing_pressure": 0.0, "social_tension": 0.0, "aid": 0.0, "months": 0})
	h["hosted"] = int(h.get("hosted", 0)) + inflow
	h["needs"] = clampf(float(h.get("needs", 0.0)) + float(inflow) / 10000.0, 0.0, 100.0)
	h["service_pressure"] = clampf(float(h.get("service_pressure", 0.0)) + float(inflow) / 12000.0, 0.0, 100.0)
	h["housing_pressure"] = clampf(float(h.get("housing_pressure", 0.0)) + float(inflow) / 9000.0, 0.0, 100.0)
	h["social_tension"] = clampf(float(h.get("social_tension", 0.0)) + float(inflow) / 15000.0, 0.0, 100.0)
	h["months"] = int(h.get("months", 0)) + 1
	hosts[host] = h
	g.humanitarian = hosts
	if host == str(st.get("country_id", "")):
		st["treasury"] = maxf(0.0, float(st.get("treasury", 0.0)) - float(inflow) * 0.00004)
		st["approval"] = clampf(float(st.get("approval", 45.0)) - 0.3, 0.0, 100.0)
	else:
		var p := _profile(st, host)
		if not p.is_empty():
			p["debt"] = clampf(float(p.get("debt", 60.0)) + float(inflow) / 900000.0, 0.0, 220.0)
			p["growth"] = clampf(float(p.get("growth", 2.0)) - float(inflow) / 2500000.0, -12.0, 10.0)
			var intl_profiles: Dictionary = st.get("international_state", {}).get("profiles", {})
			intl_profiles[host] = p
			st["international_state"]["profiles"] = intl_profiles
	if inflow > 0:
		_record(st, host, "humanitario", "%s recebe fluxo de deslocados de %s." % [_name(st, host), _name(st, str(conflict.get("a", "")))], "conflito e rotas de fuga", ["pressão sobre serviços", "necessidade de ajuda", "debate político"], "%s recebe deslocados do conflito" % _name(st, host))

static func _war_tick(st: Dictionary, conflict: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var a := str(conflict.get("a", ""))
	var b := str(conflict.get("b", ""))
	var ma := _military(st, a)
	var mb := _military(st, b)
	if ma.is_empty() or mb.is_empty():
		conflict["status"] = "congelado"
		return
	var cap_a := _capability(st, a)
	var cap_b := _capability(st, b)
	var terrain_a := (_hash01(a + b + "|terrain") * 10.0)
	var terrain_b := (_hash01(b + a + "|terrain") * 10.0)
	var support_a := float(conflict.get("support", {}).get(a, 0.0))
	var support_b := float(conflict.get("support", {}).get(b, 0.0))
	var sanction_a := 0.0
	var sanction_b := 0.0
	for row in g.get("sanctions", []):
		if str((row as Dictionary).get("status", "")) != "ativa":
			continue
		if str(row.get("target", "")) == a:
			sanction_a += float(row.get("effect", 0.2)) * 30.0
		if str(row.get("target", "")) == b:
			sanction_b += float(row.get("effect", 0.2)) * 30.0
	var exhaustion_a := float(conflict.get("casualties", {}).get(a, 0)) / maxf(1.0, float(ma.get("personnel", 100.0)) * 90.0) * 100.0 + maxf(0.0, _debt(st, a) - 90.0) * 0.08
	var exhaustion_b := float(conflict.get("casualties", {}).get(b, 0)) / maxf(1.0, float(mb.get("personnel", 100.0)) * 90.0) * 100.0 + maxf(0.0, _debt(st, b) - 90.0) * 0.08
	var noise := (_hash01(a + b + _stamp(st) + "|war") - 0.5) * 10.0
	var score_a := cap_a + float(ma.get("readiness", 50.0)) * 0.10 + terrain_a + support_a - sanction_a - exhaustion_a
	var score_b := cap_b + float(mb.get("readiness", 50.0)) * 0.10 + terrain_b + support_b - sanction_b - exhaustion_b
	var delta := score_a - score_b + noise
	var intensity := clampf(float(conflict.get("intensity", 22.0)) + absf(delta) * 0.18 + 2.0, 15.0, 100.0)
	conflict["front"] = clampf(float(conflict.get("front", 0.0)) + delta * 0.42, -100.0, 100.0)
	conflict["intensity"] = intensity
	var casualties_a := int(round(intensity * (0.45 + cap_b / 100.0) * (250.0 + _hash01(a + _stamp(st)) * 450.0)))
	var casualties_b := int(round(intensity * (0.45 + cap_a / 100.0) * (250.0 + _hash01(b + _stamp(st)) * 450.0)))
	var cas: Dictionary = conflict.get("casualties", {})
	cas[a] = int(cas.get(a, 0)) + casualties_a
	cas[b] = int(cas.get(b, 0)) + casualties_b
	conflict["casualties"] = cas
	var displaced := int(round(float(casualties_a + casualties_b) * 2.2 + intensity * 30.0))
	conflict["displaced"] = int(conflict.get("displaced", 0)) + displaced
	var gdp_a := _gdp(st, a) / 1000000.0
	var gdp_b := _gdp(st, b) / 1000000.0
	var cost_a := gdp_a * (0.0008 + intensity * 0.00001)
	var cost_b := gdp_b * (0.0008 + intensity * 0.00001)
	conflict["cost"][a] = float(conflict.cost.get(a, 0.0)) + cost_a
	conflict["cost"][b] = float(conflict.cost.get(b, 0.0)) + cost_b
	conflict["months"] = int(conflict.get("months", 0)) + 1
	# Efeitos econômicos e humanos nos beligerantes.
	for id in [a, b]:
		var p := _profile(st, id)
		if not p.is_empty():
			p["growth"] = clampf(float(p.get("growth", 2.0)) - intensity * 0.0022, -15.0, 10.0)
			p["inflation"] = clampf(float(p.get("inflation", 4.0)) + intensity * 0.0018, 0.5, 45.0)
			p["debt"] = clampf(float(p.get("debt", 60.0)) + (cost_a if id == a else cost_b) / maxf(1.0, float(p.get("gdp", 1.0)) / 1000000.0) * 100.0, 0.0, 260.0)
			p["unemployment"] = clampf(float(p.get("unemployment", 8.0)) + intensity * 0.0015, 2.0, 30.0)
			var intl_profiles: Dictionary = st.get("international_state", {}).get("profiles", {})
			intl_profiles[id] = p
			st["international_state"]["profiles"] = intl_profiles
	if a == str(st.get("country_id", "")) or b == str(st.get("country_id", "")):
		_apply_player_war(st, conflict, intensity, casualties_a if a == str(st.get("country_id", "")) else casualties_b, cost_a if a == str(st.get("country_id", "")) else cost_b)
	_humanitarian_tick(st, conflict, displaced)
	var pressure := clampf(float(conflict.get("peace_pressure", 0.0)) + float(casualties_a + casualties_b) / 9000.0 + intensity * 0.07 + (5.0 if conflict.get("front") == 0.0 else 0.0), 0.0, 100.0)
	conflict["peace_pressure"] = pressure
	if int(conflict.get("months", 0)) % 12 == 0 or pressure > 45.0:
		var status := str(conflict.get("status", ""))
		if pressure >= 70.0 and status in ["hostilidades", "escalada", "impasse"]:
			conflict["status"] = "negociacao"
			conflict["history"].append({"month": _stamp(st), "status": "negociacao", "note": "pressão de guerra e custo fiscal abrem negociação"})
			_record(st, a, "conflito", "Conflito entre %s e %s entra em negociação sob pressão de baixas e custos." % [_name(st, a), _name(st, b)], "exaustão militar e pressão humanitária", ["cessar-fogo possível", "reconstrução futura"], "Negociação aberta para o conflito %s" % str(conflict.get("id", "")))
	if absf(float(conflict.get("front", 0.0))) < 8.0 and int(conflict.get("months", 0)) > 8 and str(conflict.get("status", "")) in ["hostilidades", "escalada"]:
		conflict["status"] = "impasse"
		conflict["history"].append({"month": _stamp(st), "status": "impasse", "note": "frente estabilizada; nenhum lado obtém vantagem decisiva"})
	var ci := _conflict_index(g, str(conflict.get("id", "")))
	if ci >= 0:
		g.conflicts[ci] = conflict
	st["geopolitics"] = g

static func _apply_player_war(st: Dictionary, conflict: Dictionary, intensity: float, casualties: int, cost: float) -> void:
	var player := str(st.get("country_id", "BR"))
	st["treasury"] = maxf(0.0, float(st.get("treasury", 0.0)) - cost)
	st["economy"] = clampf(float(st.get("economy", 2.0)) - intensity * 0.0015, -8.0, 8.0)
	st["inflation"] = clampf(float(st.get("inflation", 4.5)) + intensity * 0.0012, 1.5, 30.0)
	st["approval"] = clampf(float(st.get("approval", 45.0)) - 0.25 - float(casualties) / 12000.0, 0.0, 100.0)
	if st.get("social_groups") is Dictionary:
		for id in ["industrial_workers", "low_income", "students"]:
			if st.social_groups.has(id):
				var group: Dictionary = st.social_groups[id]
				group["satisfaction"] = clampf(float(group.get("satisfaction", 50.0)) - 0.35, 5.0, 95.0)
	if float(st.get("treasury", 0.0)) <= 0.0:
		st["debt"] = clampf(float(st.get("debt", 60.0)) + 0.05, 0.0, 220.0)

static func _conflict_index(g: Dictionary, id: String) -> int:
	for i in (g.get("conflicts", []) as Array).size():
		if str(g.conflicts[i].get("id", "")) == id:
			return i
	return -1

static func player_conflict_action(st: Dictionary, conflict_id: String, action: String) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {})
	var index := _conflict_index(g, conflict_id)
	if index < 0:
		return {"ok": false, "reason": "Conflito inexistente"}
	var conflict: Dictionary = g.conflicts[index]
	var player := str(st.get("country_id", "BR"))
	if str(conflict.get("a", "")) != player and str(conflict.get("b", "")) != player:
		return {"ok": false, "reason": "O país não participa deste conflito"}
	var status := str(conflict.get("status", ""))
	if action in ["negociar", "mediar"]:
		if float(st.get("funds", 0.0)) < 150.0:
			return {"ok": false, "reason": "Caixa insuficiente para negociar"}
		st["funds"] = float(st.funds) - 150.0
		conflict["peace_pressure"] = clampf(float(conflict.get("peace_pressure", 0.0)) + (12.0 if action == "negociar" else 20.0), 0.0, 100.0)
		conflict["history"].append({"month": _stamp(st), "status": status, "note": action})
		if float(conflict.peace_pressure) >= 65.0:
			conflict["status"] = "negociacao"
		_record(st, player, "conflito", "O país abre %s no conflito %s." % ["negociação" if action == "negociar" else "mediação", conflict_id], "pressão de guerra", ["possibilidade de cessar-fogo", "custo diplomático"])
	elif action == "cessar_fogo":
		if float(conflict.get("peace_pressure", 0.0)) < 55.0:
			return {"ok": false, "reason": "Pressão insuficiente para um cessar-fogo crível"}
		if float(st.get("funds", 0.0)) < 250.0:
			return {"ok": false, "reason": "Caixa insuficiente para sustentar a trégua"}
		st["funds"] = float(st.funds) - 250.0
		conflict["status"] = "cessar_fogo"
		conflict["ceasefire_months"] = CEASEFIRE_MONTHS
		conflict["history"].append({"month": _stamp(st), "status": "cessar_fogo", "note": "trégua negociada"})
		_record(st, player, "conflito", "Cessar-fogo no conflito %s; a causa ainda precisa ser resolvida." % conflict_id, "exaustão e mediação", ["fim temporário dos combates", "monitoramento", "risco de retomada"], "Cessar-fogo no conflito %s" % conflict_id)
	elif action == "escalar":
		conflict["status"] = "escalada"
		conflict["intensity"] = clampf(float(conflict.get("intensity", 20.0)) + 12.0, 15.0, 100.0)
		st["approval"] = clampf(float(st.get("approval", 45.0)) - 1.0, 0.0, 100.0)
		conflict["history"].append({"month": _stamp(st), "status": "escalada", "note": "decisão de escalar"})
	elif action == "retirada":
		conflict["front"] = clampf(float(conflict.get("front", 0.0)) - 25.0, -100.0, 100.0)
		conflict["status"] = "negociacao"
		st["approval"] = clampf(float(st.get("approval", 45.0)) - 2.0, 0.0, 100.0)
		_record(st, player, "conflito", "Retirada unilateral em %s; o custo político é imediato." % conflict_id, "decisão de reduzir o esforço militar", ["perda de posição", "abertura de negociação"])
	else:
		return {"ok": false, "reason": "Ação de conflito desconhecida"}
	g.conflicts[index] = conflict
	st["geopolitics"] = g
	return {"ok": true, "reason": "Ação '%s' registrada" % action}

static func aid_humanitarian(st: Dictionary, target: String, amount := 300.0) -> Dictionary:
	if float(st.get("funds", 0.0)) < amount:
		return {"ok": false, "reason": "Caixa insuficiente para ajuda humanitária"}
	var g: Dictionary = st.get("geopolitics", {})
	var h: Dictionary = g.get("humanitarian", {}).get(target, {})
	if h.is_empty():
		return {"ok": false, "reason": "Não há emergência humanitária registrada neste país"}
	st["funds"] = float(st.funds) - amount
	h["aid"] = float(h.get("aid", 0.0)) + amount
	h["needs"] = clampf(float(h.get("needs", 50.0)) - amount / 50.0, 0.0, 100.0)
	h["service_pressure"] = clampf(float(h.get("service_pressure", 50.0)) - amount / 80.0, 0.0, 100.0)
	h["housing_pressure"] = clampf(float(h.get("housing_pressure", 50.0)) - amount / 100.0, 0.0, 100.0)
	h["social_tension"] = clampf(float(h.get("social_tension", 50.0)) - amount / 120.0, 0.0, 100.0)
	g.humanitarian[target] = h
	st["geopolitics"] = g
	var rel := _relation(st, target)
	if not rel.is_empty():
		rel["cooperation"] = clampf(float(rel.get("cooperation", 40.0)) + 4.0, 0.0, 100.0)
		rel["strategic_trust"] = clampf(float(rel.get("strategic_trust", 40.0)) + 3.0, 0.0, 100.0)
		_set_relation(st, target, rel)
	st["credibility"] = clampf(float(st.get("credibility", 30.0)) + 0.8, 0.0, 100.0)
	_record(st, target, "humanitario", "%s envia ajuda humanitária a %s." % [_name(st, str(st.get("country_id", "BR"))), _name(st, target)], "emergência humanitária", ["necessidades reduzidas", "serviços aliviados"], "Ajuda humanitária enviada a %s" % _name(st, target))
	return {"ok": true, "reason": "Ajuda humanitária registrada"}

static func fund_reconstruction(st: Dictionary, target: String, amount := 500.0) -> Dictionary:
	if float(st.get("treasury", 0.0)) < amount:
		return {"ok": false, "reason": "Tesouro insuficiente para reconstrução"}
	var g: Dictionary = st.get("geopolitics", {})
	var r: Dictionary = g.get("reconstruction", {}).get(target, {})
	if r.is_empty():
		return {"ok": false, "reason": "País sem programa de reconstrução"}
	st["treasury"] = float(st.treasury) - amount
	r["funded"] = float(r.get("funded", 0.0)) + amount
	g.reconstruction[target] = r
	st["geopolitics"] = g
	return {"ok": true, "reason": "Reconstrução financiada"}

static func _tick_reconstruction(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	for id in (g.get("reconstruction", {}) as Dictionary).keys():
		var r: Dictionary = g.reconstruction[id]
		if str(r.get("status", "")) != "ativa":
			continue
		var funded := float(r.get("funded", 0.0))
		var need := maxf(1.0, float(r.get("need", 100.0)))
		var progress := clampf(float(r.get("progress", 0.0)) + funded / need * 0.8, 0.0, 100.0)
		r["progress"] = progress
		r["months"] = int(r.get("months", 0)) + 1
		r["funded"] = maxf(0.0, funded * 0.92)
		var p := _profile(st, str(id))
		if not p.is_empty() and progress > 0.0:
			p["growth"] = clampf(float(p.get("growth", 2.0)) + 0.02 + progress / 100.0 * 0.04, -12.0, 10.0)
			p["unemployment"] = clampf(float(p.get("unemployment", 8.0)) - 0.02, 2.0, 30.0)
			var intl_profiles: Dictionary = st.get("international_state", {}).get("profiles", {})
			intl_profiles[id] = p
			st["international_state"]["profiles"] = intl_profiles
		if str(id) == str(st.get("country_id", "")):
			st["economy"] = clampf(float(st.get("economy", 2.0)) + 0.02, -8.0, 8.0)
			st["approval"] = clampf(float(st.get("approval", 45.0)) + 0.1, 0.0, 100.0)
		if progress >= 100.0:
			r["status"] = "concluida"
			g.stats["reconstructions_completed"] = int(g.stats.get("reconstructions_completed", 0)) + 1
			_record(st, str(id), "reconstrucao", "Reconstrução de %s concluída após %d meses." % [_name(st, str(id)), int(r.get("months", 0))], "financiamento e execução de obras", ["serviços restaurados", "emprego", "credibilidade"], "Reconstrução de %s concluída" % _name(st, str(id)))
		g.reconstruction[id] = r
	st["geopolitics"] = g

static func _start_reconstruction(st: Dictionary, id: String) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var r: Dictionary = g.get("reconstruction", {}).get(id, {})
	if not r.is_empty() and str(r.get("status", "")) == "ativa":
		return
	g.reconstruction[id] = {
		"id": id, "status": "ativa", "need": 100.0, "funded": 0.0, "progress": 0.0,
		"months": 0, "started": _stamp(st), "source": "orçamento nacional e cooperação",
	}
	st["geopolitics"] = g

static func _tick_crises(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var crises: Array = g.get("crises", [])
	for i in crises.size():
		var c: Dictionary = crises[i]
		if str(c.get("status", "")) not in ["aberta", "escalando"]:
			continue
		c["idle"] = int(c.get("idle", 0)) + 1
		if int(c.idle) % 2 == 0:
			c["severity"] = clampf(float(c.get("severity", 20.0)) + 4.0, 0.0, 100.0)
			if float(c.severity) >= 60.0:
				c["stage"] = 2
			if float(c.severity) >= 82.0 and str(c.get("scope", "")) == "player":
				c["status"] = "escalando"
				c["escalation"] = int(c.get("escalation", 0)) + 1
				if int(c.escalation) >= 2:
					var started := start_conflict(st, str(st.get("country_id", "BR")), str(c.get("country", "")), "escalada da crise: " + str(c.get("cause", "")), "crise")
					if bool(started.get("ok", false)):
						c["status"] = "convertida_em_conflito"
		if float(c.get("severity", 0.0)) <= 18.0:
			c["status"] = "resolvida"
		crises[i] = c
	g.crises = crises
	st["geopolitics"] = g

static func _tick_conflicts(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var conflicts: Array = g.get("conflicts", [])
	for i in conflicts.size():
		var c: Dictionary = conflicts[i]
		var status := str(c.get("status", ""))
		if status in ["tensao", "confronto"]:
			c["months"] = int(c.get("months", 0)) + 1
			if int(c.months) >= 2:
				var key := _pair_key(str(c.get("a", "")), str(c.get("b", "")))
				var pair: Dictionary = g.bilateral.get(key, {})
				var tension := float(pair.get("tension", 55.0))
				if tension >= 60.0 or int(c.months) >= 4:
					c["status"] = "hostilidades"
					c["history"].append({"month": _stamp(st), "status": "hostilidades", "note": "tensão não contida"})
					_record(st, str(c.a), "conflito", "Confronto entre %s e %s evolui para hostilidades." % [str(c.a_name), str(c.b_name)], "tensão bilateral e falha da mediação", ["combate ativo", "custos militares"], "Hostilidades começam entre %s e %s" % [str(c.a_name), str(c.b_name)])
				else:
					c["status"] = "congelado"
					c["frozen_months"] = 0
			elif status in ["hostilidades", "escalada", "impasse"]:
				_war_tick(st, c)
			var refreshed: Array = st.get("geopolitics", {}).get("conflicts", []) if st.get("geopolitics") is Dictionary else []
			var ri := _conflict_index({"conflicts": refreshed}, str(c.get("id", "")))
			if ri >= 0:
				c = refreshed[ri]
		elif status == "negociacao":
			c["peace_pressure"] = clampf(float(c.get("peace_pressure", 0.0)) + 2.0, 0.0, 100.0)
			if float(c.peace_pressure) >= 60.0 and int(c.get("months", 0)) >= 4:
				if _hash01(str(c.id) + _stamp(st)) < 0.28:
					c["status"] = "cessar_fogo"
					c["ceasefire_months"] = CEASEFIRE_MONTHS
					c["history"].append({"month": _stamp(st), "status": "cessar_fogo", "note": "acordo de trégua"})
					_record(st, str(c.a), "conflito", "Cessar-fogo assinado entre %s e %s." % [str(c.a_name), str(c.b_name)], "mediação e exaustão", ["fim temporário dos combates", "monitoramento"], "Cessar-fogo entre %s e %s" % [str(c.a_name), str(c.b_name)])
		elif status == "cessar_fogo":
			c["ceasefire_months"] = int(c.get("ceasefire_months", 1)) - 1
			var key := _pair_key(str(c.get("a", "")), str(c.get("b", "")))
			var pair: Dictionary = g.bilateral.get(key, {})
			if int(c.ceasefire_months) <= 0:
				if float(pair.get("tension", 55.0)) < 55.0:
					c["status"] = "acordo"
					c["resolution"] = "acordo negociado com monitoramento e reconstrução"
					c["history"].append({"month": _stamp(st), "status": "acordo", "note": c.resolution})
					_start_reconstruction(st, str(c.a))
					_start_reconstruction(st, str(c.b))
					g.stats["peace_agreements"] = int(g.stats.get("peace_agreements", 0)) + 1
					_record(st, str(c.a), "conflito", "Acordo de paz encerra o conflito entre %s e %s." % [str(c.a_name), str(c.b_name)], "cessar-fogo sustentado e causas reduzidas", ["reconstrução", "monitoramento", "sanções reavaliadas"], "Acordo de paz entre %s e %s" % [str(c.a_name), str(c.b_name)])
				else:
					c["status"] = "congelado"
					c["frozen_months"] = 0
					c["history"].append({"month": _stamp(st), "status": "congelado", "note": "causas não resolvidas"})
		elif status == "congelado":
			c["frozen_months"] = int(c.get("frozen_months", 0)) + 1
			var key := _pair_key(str(c.get("a", "")), str(c.get("b", "")))
			var pair: Dictionary = g.bilateral.get(key, {})
			if int(c.frozen_months) >= FROZEN_MONTHS and float(pair.get("tension", 55.0)) >= 60.0 and _hash01(str(c.id) + _stamp(st)) < 0.22:
				c["status"] = "hostilidades"
				c["history"].append({"month": _stamp(st), "status": "hostilidades", "note": "conflito congelado reacende"})
				_record(st, str(c.a), "conflito", "Conflito congelado entre %s e %s reacende." % [str(c.a_name), str(c.b_name)], "causas não resolvidas", ["retomada dos combates"], "Conflito entre %s e %s reacende" % [str(c.a_name), str(c.b_name)])
		conflicts[i] = c
	g.conflicts = conflicts
	st["geopolitics"] = g

static func monthly(st: Dictionary, countries: Array) -> Dictionary:
	ensure(st, countries)
	var g: Dictionary = st["geopolitics"]
	var tick := _stamp(st)
	if str(g.get("last_tick", "")) == tick:
		return {"skipped": true}
	var active := 0
	for c in g.conflicts:
		if str((c as Dictionary).get("status", "")) in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao", "cessar_fogo"]:
			active += 1
	# 1. Tensão bilateral dos NPCs (não substitui a relação do jogador).
	for key in (g.get("bilateral", {}) as Dictionary).keys():
		var pair: Dictionary = g.bilateral[key]
		var a := str(pair.get("a", ""))
		var b := str(pair.get("b", ""))
		var wa: Dictionary = st.get("world", {}).get("countries", {}).get(a, {})
		var wb: Dictionary = st.get("world", {}).get("countries", {}).get(b, {})
		var diff := absf(float(wa.get("government_axis", 0.0)) - float(wb.get("government_axis", 0.0)))
		var baseline := 6.0 + diff * 14.0 + float(Resources.dispute(a, b).get("weight", 0.0))
		var drift := (baseline - float(pair.get("tension", 20.0))) * 0.035 + (_hash01(a + b + tick) - 0.5) * 0.6
		pair["tension"] = clampf(float(pair.get("tension", 20.0)) + drift, 0.0, 100.0)
		pair["trust"] = clampf(70.0 - float(pair.tension) * 0.55, 0.0, 90.0)
		g.bilateral[key] = pair
	# 2. Crises do jogador: tensão alta + incidente; não é guerra automática.
	var player := str(st.get("country_id", "BR"))
	for id in (st.get("international_state", {}).get("profiles", {}) as Dictionary).keys():
		var rel := _relation(st, str(id))
		if rel.is_empty():
			continue
		var tension := float(rel.get("tension", 0.0))
		if tension < 45.0:
			continue
		var has_crisis := false
		for c in g.crises:
			if str((c as Dictionary).get("country", "")) == str(id) and str((c as Dictionary).get("status", "")) in ["aberta", "escalando"]:
				has_crisis = true
				break
		if has_crisis:
			continue
		if _hash01(str(id) + "|crisis|" + tick) < 0.055:
			var cause := "incidente de fronteira e tensão acumulada"
			var dispute := Resources.dispute(player, str(id))
			if not dispute.is_empty():
				cause = str(dispute.get("cause", cause))
			_spawn_crisis(st, str(id), tension + 15.0, cause)
	# 3. NPCs: pares com tensão alta viram crise/conflito com limite e cooldown.
	if active < MAX_ACTIVE_CONFLICTS:
		for key in (g.get("bilateral", {}) as Dictionary).keys():
			var pair: Dictionary = g.bilateral[key]
			if float(pair.get("tension", 0.0)) < 62.0:
				continue
			if int(g.get("conflict_seq", 0)) > 0 and int(pair.get("last_conflict", -999)) > _month_index(st) - 30:
				continue
			if _hash01(str(key) + "|war|" + tick) > 0.075:
				continue
			var started := start_conflict(st, str(pair.a), str(pair.b), str(pair.get("cause", "tensão regional")))
			if bool(started.get("ok", false)):
				active += 1
				pair["last_conflict"] = _month_index(st)
				g.bilateral[key] = pair
			if active >= MAX_ACTIVE_CONFLICTS:
				break
	# 4. Sanções NPC contra beligerantes (limitadas).
	if _hash01("sanction" + tick) < 0.15:
		for c in g.conflicts:
			if str((c as Dictionary).get("status", "")) not in ["hostilidades", "escalada"]:
				continue
			var target := str(c.get("a", ""))
			var imposer := str(c.get("b", ""))
			if imposer == player or target == player:
				continue
			if _hash01(str(c.id) + "|sanc|" + tick) < 0.35:
				impose_sanction(st, target, "comércio", imposer)
			break
	# 5. Ciclos.
	_tick_sanctions(st)
	_tick_crises(st)
	_tick_conflicts(st)
	_tick_humanitarian(st)
	_tick_reconstruction(st)
	g = st["geopolitics"]
	g["last_tick"] = tick
	g.stats["months_simulated"] = int(g.stats.get("months_simulated", 0)) + 1
	st["geopolitics"] = g
	st["geopolitics_summary"] = summary(st)
	return {"tick": tick, "active_conflicts": active, "crises": (g.crises as Array).size()}

static func _tick_humanitarian(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	for id in (g.get("humanitarian", {}) as Dictionary).keys():
		var h: Dictionary = g.humanitarian[id]
		h["needs"] = clampf(float(h.get("needs", 0.0)) + 0.6, 0.0, 100.0)
		h["service_pressure"] = clampf(float(h.get("service_pressure", 0.0)) + 0.35, 0.0, 100.0)
		h["housing_pressure"] = clampf(float(h.get("housing_pressure", 0.0)) + 0.30, 0.0, 100.0)
		h["social_tension"] = clampf(float(h.get("social_tension", 0.0)) + 0.20, 0.0, 100.0)
		h["hosted"] = int(maxf(0.0, float(h.get("hosted", 0)) * 0.995))
		h["aid"] = maxf(0.0, float(h.get("aid", 0.0)) * 0.9)
		g.humanitarian[id] = h
	st["geopolitics"] = g

static func summary(st: Dictionary) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	var conflicts: Array = g.get("conflicts", []) if g.get("conflicts") is Array else []
	var active: Array = []
	var history: Array = []
	for c in conflicts:
		if str((c as Dictionary).get("status", "")) in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao", "cessar_fogo", "congelado"]:
			active.append(c)
		else:
			history.append(c)
	var crises: Array = []
	for c in (g.get("crises", []) as Array):
		if str((c as Dictionary).get("status", "")) in ["aberta", "escalando"]:
			crises.append(c)
	var sanctions: Array = []
	for s in (g.get("sanctions", []) as Array):
		if str((s as Dictionary).get("status", "")) == "ativa":
			sanctions.append(s)
	return {
		"active_conflicts": active, "conflict_history": history, "crises": crises,
		"sanctions": sanctions, "humanitarian": g.get("humanitarian", {}).duplicate(true),
		"reconstruction": g.get("reconstruction", {}).duplicate(true),
		"stats": g.get("stats", {}).duplicate(true),
		"conflicts_count": active.size(), "crises_count": crises.size(),
		"sanctions_count": sanctions.size(),
	}
