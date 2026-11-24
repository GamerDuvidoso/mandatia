extends RefCounted
## E2 — capacidades militares, orçamento de defesa, aquisições e mobilização.
##
## Fontes: as faixas de pessoal/equipamento/tecnologia vêm de estimativas
## qualitativas baseadas em população, PIB e gasto militar histórico (SIPRI
## milex, faixas 2023-2024), nunca de inventários operacionais. O arquivo
## `config/geopolitics.json` declara a incerteza (`certainty`).
##
## Poder militar NÃO é um número único: a fórmula soma equipamento, pessoal,
## logística, prontidão, treinamento, tecnologia, indústria, marinha e aviação.
## Um país menor pode compensar quantidade com prontidão, defesa no território e
## apoio externo (aplicado pelo simulador de conflito).

const DATA_PATH := "res://config/geopolitics.json"
const WorldHistory := preload("res://scripts/sim/world_history.gd")
const ITEMS := {
	"equipamento": {"label": "Equipamento e blindados", "cost_pct": 0.45, "months": 12, "equipment": 7.0, "logistics": 1.5, "maintenance": 0.12},
	"tecnologia": {"label": "Pesquisa e tecnologia", "cost_pct": 0.35, "months": 18, "tech": 8.0, "industry": 3.0, "maintenance": 0.08},
	"infraestrutura": {"label": "Infraestrutura militar", "cost_pct": 0.30, "months": 24, "logistics": 7.0, "readiness": 3.0, "maintenance": 0.05},
	"manutencao": {"label": "Manutenção e prontidão", "cost_pct": 0.12, "months": 6, "readiness": 7.0, "maintenance": 0.03},
	"defesa_industrial": {"label": "Base industrial de defesa", "cost_pct": 0.55, "months": 30, "industry": 9.0, "tech": 4.0, "maintenance": 0.10},
}

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _population(st: Dictionary, id: String, economy: Dictionary) -> float:
	var row: Variant = economy.get(id, {})
	if row is Dictionary and (row as Dictionary).get("population") is Dictionary:
		return float(((row as Dictionary).population as Dictionary).get("value", 0.0))
	if id == str(st.get("country_id", "")):
		var ep: Variant = st.get("economic_profile", {})
		if ep is Dictionary and (ep as Dictionary).get("population") is Dictionary:
			return float(((ep as Dictionary).population as Dictionary).get("value", 0.0))
	var profile: Variant = st.get("international_state", {}).get("profiles", {}).get(id, {})
	if profile is Dictionary:
		return float((profile as Dictionary).get("population", 0.0))
	return 1.0

static func _gdp(st: Dictionary, id: String, economy: Dictionary) -> float:
	if id == str(st.get("country_id", "")):
		return maxf(1.0, float(st.get("gdp", 1.0)))
	var profile: Variant = st.get("international_state", {}).get("profiles", {}).get(id, {})
	if profile is Dictionary:
		return maxf(1.0, float((profile as Dictionary).get("gdp", 1.0)))
	var row: Variant = economy.get(id, {})
	if row is Dictionary and (row as Dictionary).get("gdp") is Dictionary:
		return maxf(1.0, float(((row as Dictionary).gdp as Dictionary).get("value", 1.0)))
	return 1.0

static func _name(st: Dictionary, id: String, countries: Array) -> String:
	for row in countries:
		if str((row as Dictionary).get("id", "")) == id:
			return str((row as Dictionary).get("name", id))
	return str(st.get("international_state", {}).get("profiles", {}).get(id, {}).get("name", id))

static func init_country(st: Dictionary, id: String, countries: Array, economy: Dictionary) -> Dictionary:
	var cfg: Dictionary = config()
	var base: Dictionary = (cfg.get("military_defaults", {}) as Dictionary).duplicate(true)
	var overrides: Dictionary = cfg.get("military_overrides", {}) if cfg.get("military_overrides") is Dictionary else {}
	if overrides.get(id) is Dictionary:
		for key in (overrides[id] as Dictionary).keys():
			base[key] = overrides[id][key]
	var population := _population(st, id, economy)
	var personnel := maxf(2.0, population / 1000.0 * float(base.get("personnel_per_1000", 2.2)) / 1000.0)
	var gdp := _gdp(st, id, economy)
	var share := float(base.get("defense_share", 1.2))
	return {
		"id": id, "name": _name(st, id, countries),
		"personnel": personnel, "personnel_index": clampf(personnel / 12.0, 4.0, 100.0),
		"equipment": clampf(float(base.get("equipment", 38.0)), 5.0, 100.0),
		"logistics": clampf(float(base.get("logistics", 40.0)), 5.0, 100.0),
		"training": clampf(float(base.get("training", 42.0)), 5.0, 100.0),
		"tech": clampf(float(base.get("tech", 36.0)), 5.0, 100.0),
		"industry": clampf(float(base.get("industry", 28.0)), 5.0, 100.0),
		"navy": clampf(float(base.get("navy", 24.0)), 5.0, 100.0),
		"air": clampf(float(base.get("air", 28.0)), 5.0, 100.0),
		"readiness": clampf(float(base.get("readiness", 55.0)), 5.0, 100.0),
		"defense_share": clampf(share, 0.3, 8.0),
			"base_share": clampf(share, 0.3, 8.0),
			"budget_billions": gdp * share / 100.0 / 1000000000.0,
			"procurement": [], "maintenance_load": 0.0, "mobilization": "nenhuma", "mobilized": 0.0,
			"stockpile_days": int(base.get("strategic_stock_days", base.get("reserves_months", 3) * 10)),
			"casualties": 0, "nuclear": bool(base.get("nuclear", false)),
		"source": "SIPRI milex (faixa) + população/PIB WDI; modelo abstrato",
		"certainty": str(base.get("certainty", "estimativa declarada")),
		"updated": "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))],
	}

static func ensure(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	var military: Dictionary = g.get("military", {}) if g.get("military") is Dictionary else {}
	var ids: Array = []
	ids.append(str(st.get("country_id", "BR")))
	for row in countries:
		var id := str((row as Dictionary).get("id", ""))
		if id != "" and id != str(st.get("country_id", "")) and id != "HT":
			ids.append(id)
	for id in ids:
		if not military.has(id):
			military[id] = init_country(st, str(id), countries, economy)
		else:
			var m: Dictionary = military[id]
			for key in ["procurement", "maintenance_load", "mobilization", "mobilized", "casualties"]:
				if not m.has(key):
					m[key] = [] if key == "procurement" else ("nenhuma" if key == "mobilization" else 0.0)
			military[id] = m
	g["military"] = military
	st["geopolitics"] = g

static func capability(m: Dictionary) -> float:
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

static func defense_budget_billions(st: Dictionary, id: String) -> float:
	var m: Dictionary = st.get("geopolitics", {}).get("military", {}).get(id, {})
	if m.is_empty():
		return 0.0
	if id == str(st.get("country_id", "")):
		var share := float(st.get("budget", {}).get("approved_allocations", {}).get("defesa", m.get("defense_share", 1.2)))
		return _gdp(st, id, {}) * share / 100.0 / 1000000000.0
	return float(m.get("budget_billions", 0.0))

static func threat_for(st: Dictionary, id: String) -> float:
	var threat := 0.0
	var geopolitics: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	for conflict in (geopolitics.get("conflicts", []) as Array):
		var status := str(conflict.get("status", ""))
		if status not in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao"]:
			continue
		if str(conflict.get("a", "")) == id or str(conflict.get("b", "")) == id:
			threat = maxf(threat, float(conflict.get("intensity", 0.0)))
	for crisis in (geopolitics.get("crises", []) as Array):
		if str(crisis.get("country", "")) != id or str(crisis.get("status", "")) not in ["aberta", "escalando"]:
			continue
		threat = maxf(threat, float(crisis.get("severity", 0.0)) * 0.6)
	return clampf(threat, 0.0, 100.0)

static func procurement_cost_m(st: Dictionary, id: String, item: String) -> float:
	var spec: Dictionary = ITEMS.get(item, {})
	if spec.is_empty():
		return 0.0
	return _gdp(st, id, {}) / 1000000.0 * float(spec.get("cost_pct", 0.2))

static func start_procurement(st: Dictionary, id: String, item: String, player := true) -> Dictionary:
	var spec: Dictionary = ITEMS.get(item, {})
	if spec.is_empty():
		return {"ok": false, "reason": "Programa de aquisição desconhecido"}
	var g: Dictionary = st.get("geopolitics", {})
	var military: Dictionary = g.get("military", {}) if g.get("military") is Dictionary else {}
	if not military.has(id):
		return {"ok": false, "reason": "País sem força militar simulada"}
	var m: Dictionary = military[id]
	var queue: Array = m.get("procurement", []) if m.get("procurement") is Array else []
	if queue.size() >= 2:
		return {"ok": false, "reason": "Já há dois programas de aquisição em andamento"}
	var cost := procurement_cost_m(st, id, item)
	if player:
		if not bool(st.get("government", false)):
			return {"ok": false, "reason": "Apenas o governo inicia aquisições"}
		if float(st.get("treasury", 0.0)) < cost:
			return {"ok": false, "reason": "Tesouro insuficiente para o programa (M$ %d)" % int(cost)}
		st["treasury"] = float(st.treasury) - cost
	queue.append({
		"id": "%s-%d" % [item, int(queue.size()) + int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))],
		"item": item, "label": str(spec.get("label", item)), "months_left": int(spec.get("months", 12)),
		"months_total": int(spec.get("months", 12)), "cost": cost,
		"effects": {"equipment": float(spec.get("equipment", 0.0)), "tech": float(spec.get("tech", 0.0)), "logistics": float(spec.get("logistics", 0.0)), "readiness": float(spec.get("readiness", 0.0)), "industry": float(spec.get("industry", 0.0))},
		"maintenance": float(spec.get("maintenance", 0.0)), "status": "em aquisição",
	})
	m["procurement"] = queue
	military[id] = m
	g["military"] = military
	st["geopolitics"] = g
	return {"ok": true, "reason": "%s iniciado; entrega em %d meses, sem capacidade imediata" % [str(spec.get("label", item)), int(spec.get("months", 12))], "cost": cost}

static func _deliver(m: Dictionary, program: Dictionary) -> void:
	for key in (program.get("effects", {}) as Dictionary).keys():
		m[key] = clampf(float(m.get(key, 0.0)) + float(program.effects[key]), 0.0, 100.0)
	m["maintenance_load"] = clampf(float(m.get("maintenance_load", 0.0)) + float(program.get("maintenance", 0.0)), 0.0, 20.0)
	m["stockpile_days"] = mini(180, int(m.get("stockpile_days", 20)) + 3)

static func monthly(st: Dictionary, id: String, profile: Dictionary, at_war: bool, threat: float, year: int, month: int) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {})
	var military: Dictionary = g.get("military", {})
	var m: Dictionary = military.get(id, {})
	if m.is_empty():
		return {}
	var base_share := float(m.get("base_share", 1.2))
	var maintenance_load := maxf(0.0, float(m.get("maintenance_load", 0.0)))
	var target := base_share + threat * 0.02 + maintenance_load + (0.9 if at_war else 0.0)
	if str(m.get("mobilization", "nenhuma")) == "geral":
		target += 1.1
	elif str(m.get("mobilization", "nenhuma")) == "parcial":
		target += 0.45
	target = clampf(target, 0.4, 8.0)
	var share := float(m.get("defense_share", base_share))
	share += (target - share) * (0.18 if at_war else 0.06)
	m["defense_share"] = clampf(share, 0.3, 8.0)
	var gdp := _gdp(st, id, {})
	m["budget_billions"] = gdp * share / 100.0 / 1000000000.0
	# O custo fiscal é real: defesa acima da base pressiona dívida e reduz espaço
	# de crescimento; em guerra, o esforço é maior.
	var extra := maxf(0.0, share - base_share)
	var war_cost := 0.10 if at_war else 0.0
	if not profile.is_empty():
		profile["debt"] = clampf(float(profile.get("debt", 60.0)) + extra * 0.025 + war_cost, 0.0, 220.0)
		profile["growth"] = clampf(float(profile.get("growth", 2.0)) - extra * 0.012 - war_cost * 0.08, -12.0, 10.0)
		profile["inflation"] = clampf(float(profile.get("inflation", 4.0)) + extra * 0.008 + war_cost * 0.03, 0.0, 45.0)
	# Prontidão sobe com financiamento e cai com combate; não é gratuita.
	m["readiness"] = clampf(float(m.get("readiness", 50.0)) + (share - base_share) * 1.1 + (0.6 if at_war else 0.0) - (2.4 if at_war else 0.0) + (_hash01(id + "|ready|%d-%d" % [year, month]) - 0.5) * 1.2, 5.0, 100.0)
	var queue: Array = []
	for raw in (m.get("procurement", []) as Array):
		var program: Dictionary = raw
		program["months_left"] = int(program.get("months_left", 1)) - 1
		if int(program.months_left) <= 0:
			_deliver(m, program)
			program["status"] = "entregue"
			var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
			if not world.is_empty():
				WorldHistory.push(world, {
					"year": year, "month": month, "country": id, "country_name": str(m.get("name", id)),
					"category": "militar", "description": "Aquisição entregue: %s" % str(program.get("label", "")),
					"headline": "%s recebe %s após %d meses" % [str(m.get("name", id)), str(program.get("label", "")), int(program.get("months_total", 0))],
					"trigger": "programa de aquisição concluído",
					"consequences": ["capacidade material incorporada", "manutenção passa a pesar no orçamento"],
					"actors": ["indústria de defesa"], "news": true,
				}, 2)
				st["world"] = world
		else:
			queue.append(program)
	m["procurement"] = queue
	if str(m.get("mobilization", "nenhuma")) != "nenhuma" and not at_war:
		m["mobilization"] = "nenhuma"
		m["mobilized"] = 0.0
	m["updated"] = "%d-%02d" % [year, month]
	military[id] = m
	g["military"] = military
	st["geopolitics"] = g
	return {"share": share, "readiness": m.readiness, "power": capability(m), "maintenance_load": maintenance_load, "threat": clampf(threat, 0.0, 100.0)}

static func mobilize(st: Dictionary, id: String, level: String) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {})
	var military: Dictionary = g.get("military", {}) if g.get("military") is Dictionary else {}
	if not military.has(id):
		return {"ok": false, "reason": "País sem força militar simulada"}
	if not (level in ["parcial", "geral", "desmobilizar"]):
		return {"ok": false, "reason": "Nível de mobilização inválido"}
	var m: Dictionary = military[id]
	if level == "desmobilizar":
		m["mobilization"] = "nenhuma"
		m["mobilized"] = 0.0
		m["readiness"] = clampf(float(m.get("readiness", 50.0)) - 4.0, 5.0, 100.0)
		military[id] = m
		g["military"] = military
		st["geopolitics"] = g
		return {"ok": true, "reason": "Mobilização encerrada; o custo de pessoal recua"}
	var cost := _gdp(st, id, {}) / 1000000.0 * (0.0035 if level == "parcial" else 0.010)
	if id == str(st.get("country_id", "")):
		if not bool(st.get("government", false)):
			return {"ok": false, "reason": "Apenas o governo mobiliza"}
		if float(st.get("treasury", 0.0)) < cost:
			return {"ok": false, "reason": "Tesouro insuficiente para mobilizar (M$ %d)" % int(cost)}
		st["treasury"] = float(st.treasury) - cost
		st["approval"] = clampf(float(st.get("approval", 45.0)) - (1.2 if level == "parcial" else 3.0), 0.0, 100.0)
		st["economy"] = clampf(float(st.get("economy", 2.0)) - (0.08 if level == "parcial" else 0.22), -8.0, 8.0)
		st["unemployment"] = clampf(float(st.get("unemployment", 8.0)) - (0.04 if level == "parcial" else 0.10), 2.0, 30.0)
		if st.get("social_groups") is Dictionary:
			for group_id in ["industrial_workers", "low_income"]:
				if st.social_groups.has(group_id):
					var group: Dictionary = st.social_groups[group_id]
					group["satisfaction"] = clampf(float(group.get("satisfaction", 50.0)) - 1.0, 5.0, 95.0)
	m["mobilization"] = level
	m["mobilized"] = (0.18 if level == "parcial" else 0.45) * float(m.get("personnel", 100.0))
	m["readiness"] = clampf(float(m.get("readiness", 50.0)) + (4.0 if level == "parcial" else 9.0), 5.0, 100.0)
	military[id] = m
	g["military"] = military
	st["geopolitics"] = g
	return {"ok": true, "reason": "Mobilização %s: prontidão maior, custo fiscal e menor disponibilidade civil" % level, "cost": cost}

static func summary(st: Dictionary, id: String) -> Dictionary:
	var m: Dictionary = st.get("geopolitics", {}).get("military", {}).get(id, {})
	if m.is_empty():
		return {}
	return {
		"id": id, "name": str(m.get("name", id)), "capability": capability(m),
		"personnel": float(m.get("personnel", 0.0)), "equipment": float(m.get("equipment", 0.0)),
		"logistics": float(m.get("logistics", 0.0)), "readiness": float(m.get("readiness", 0.0)),
		"tech": float(m.get("tech", 0.0)), "industry": float(m.get("industry", 0.0)),
		"defense_share": float(m.get("defense_share", 0.0)), "budget_billions": float(m.get("budget_billions", 0.0)),
		"mobilization": str(m.get("mobilization", "nenhuma")), "procurement": (m.get("procurement", []) as Array).duplicate(true),
		"casualties": int(m.get("casualties", 0)), "nuclear": bool(m.get("nuclear", false)),
		"source": str(m.get("source", "")), "certainty": str(m.get("certainty", "")),
	}
