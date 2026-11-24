extends RefCounted
## E2 — crises financeiras e choques de energia/recursos.
##
## Um choque global não aplica o mesmo percentual a todos. A transmissão usa:
## - vulnerabilidade financeira: dívida externa, concentração de exportações,
##   exposição a remessas e turismo;
## - vulnerabilidade energética: importação de petróleo/gás, renováveis e
##   estoque estratégico;
## - choque de commodities: concentração exportadora e dependência de alimentos.
## Os choques têm duração, severidade e memória; não são desaparecem no mês
## seguinte. A resposta do governo (estoque, diversificação, subsídio) reduz a
## exposição, mas custa caixa e tem prazo.

const Resources := preload("res://scripts/sim/strategic_resources.gd")
const WorldHistory := preload("res://scripts/sim/world_history.gd")

const TYPES := {
	"recessao": {"label": "Recessão global", "duration": [8, 18], "base_growth": 0.55, "base_inflation": 0.10},
	"financeira": {"label": "Instabilidade financeira", "duration": [6, 14], "base_growth": 0.42, "base_inflation": 0.18},
	"divida": {"label": "Crise de dívida soberana", "duration": [10, 24], "base_growth": 0.50, "base_inflation": 0.26},
	"cambio": {"label": "Crise cambial", "duration": [5, 12], "base_growth": 0.32, "base_inflation": 0.42},
	"commodities": {"label": "Choque de commodities", "duration": [6, 16], "base_growth": 0.28, "base_inflation": 0.36},
	"energia": {"label": "Crise energética", "duration": [6, 18], "base_growth": 0.38, "base_inflation": 0.52},
}

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]

static func ensure(st: Dictionary) -> void:
	var g: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	if not (g.get("shocks") is Array):
		g["shocks"] = []
	if not (g.get("shock_seq") is int):
		g["shock_seq"] = 0
	if not (g.get("energy_policy") is Dictionary):
		g["energy_policy"] = {"stockpile": 0, "diversification": 0, "subsidy_months": 0}
	if not (g.get("stats") is Dictionary):
		g["stats"] = {}
	st["geopolitics"] = g

static func spawn(st: Dictionary, kind: String, severity := 0.6, source := "condições sistêmicas") -> Dictionary:
	if not TYPES.has(kind):
		return {"ok": false, "reason": "Tipo de choque desconhecido"}
	ensure(st)
	var g: Dictionary = st["geopolitics"]
	if (g.shocks as Array).size() >= 3:
		return {"ok": false, "reason": "Já há três choques globais ativos"}
	var spec: Dictionary = TYPES[kind]
	var duration: Array = spec.get("duration", [8, 12])
	var months := int(duration[0]) + int(_hash01(kind + _stamp(st)) * float(int(duration[1]) - int(duration[0]) + 1))
	g.shock_seq = int(g.get("shock_seq", 0)) + 1
	var shock := {
		"id": "G%03d" % int(g.shock_seq), "type": kind, "label": str(spec.get("label", kind)),
		"start": _stamp(st), "severity": clampf(severity, 0.2, 1.0), "months_left": months,
		"months_total": months, "source": source, "status": "ativo",
		"growth": float(spec.get("base_growth", 0.3)) * severity,
		"inflation": float(spec.get("base_inflation", 0.2)) * severity,
	}
	g.shocks.push_front(shock)
	g.stats["shocks"] = int(g.stats.get("shocks", 0)) + 1
	st["geopolitics"] = g
	_record(st, kind, shock)
	return {"ok": true, "id": shock.id, "label": shock.label}

static func _record(st: Dictionary, kind: String, shock: Dictionary) -> void:
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	if world.is_empty():
		return
	WorldHistory.push(world, {
		"year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1)),
		"country": "GLOBAL", "country_name": "Sistema internacional", "category": "economia_global",
		"description": "%s atinge a economia internacional: %s." % [str(shock.get("label", kind)), str(shock.get("source", ""))],
		"headline": "%s: choque global de severidade %.0f" % [str(shock.get("label", kind)), float(shock.get("severity", 0.0)) * 100.0],
		"trigger": str(shock.get("source", "")),
		"consequences": ["crescimento menor", "inflação e dívida sob pressão", "impacto assimétrico por exposição"],
		"actors": ["mercados", "governos"], "news": true,
	}, 2)
	st["world"] = world

static func _player_gdp(st: Dictionary) -> float:
	return maxf(1.0, float(st.get("gdp", 1.0)))

static func _player_impact(st: Dictionary, kind: String, severity: float) -> void:
	var g: Dictionary = st.get("geopolitics", {})
	var resources: Dictionary = Resources.ensure(st, str(st.get("country_id", "BR")))
	var fin := Resources.vulnerability(str(st.get("country_id", "BR")), "financeiro")
	var energy := Resources.vulnerability(str(st.get("country_id", "BR")), "energia")
	var trade := Resources.vulnerability(str(st.get("country_id", "BR")), "comercio")
	var policy: Dictionary = g.get("energy_policy", {})
	var mitigation := 0.0
	if kind == "energia":
		mitigation += minf(0.30, float(policy.get("stockpile", 0)) * 0.04)
		mitigation += minf(0.25, float(policy.get("diversification", 0)) * 0.05)
		if int(policy.get("subsidy_months", 0)) > 0:
			mitigation += 0.15
	var factor := 1.0 - clampf(mitigation, 0.0, 0.55)
	var growth_hit := 0.0
	var inflation_hit := 0.0
	match kind:
		"recessao":
			growth_hit = severity * (0.35 + trade * 0.55) * factor
		"financeira":
			growth_hit = severity * (0.30 + fin * 0.55) * factor
			inflation_hit = severity * 0.10
		"divida":
			growth_hit = severity * (0.28 + float(st.get("debt", 60.0)) / 220.0) * factor
			inflation_hit = severity * 0.22
		"cambio":
			growth_hit = severity * (0.25 + fin * 0.35) * factor
			inflation_hit = severity * (0.35 + fin * 0.45)
		"commodities":
			growth_hit = severity * (0.20 + trade * 0.35) * factor
			inflation_hit = severity * (0.28 + float(resources.get("food_dependency", 0.2)) * 0.35)
		"energia":
			growth_hit = severity * (0.22 + energy * 0.65) * factor
			inflation_hit = severity * (0.30 + energy * 0.75) * factor
	st["economy"] = clampf(float(st.get("economy", 2.0)) - growth_hit * 0.35, -8.0, 8.0)
	st["inflation"] = clampf(float(st.get("inflation", 4.5)) + inflation_hit * 0.45, 1.5, 30.0)
	st["unemployment"] = clampf(float(st.get("unemployment", 8.0)) + growth_hit * 0.08, 2.0, 30.0)
	st["approval"] = clampf(float(st.get("approval", 45.0)) - inflation_hit * 0.9, 0.0, 100.0)
	var fiscal := _player_gdp(st) / 1000000.0 * (0.00015 + severity * 0.00012) * (1.0 + energy + trade)
	st["treasury"] = maxf(0.0, float(st.get("treasury", 0.0)) - fiscal)
	if st.get("social_groups") is Dictionary:
		for id in ["low_income", "industrial_workers", "farmers", "service_workers"]:
			if st.social_groups.has(id):
				var group: Dictionary = st.social_groups[id]
				group["satisfaction"] = clampf(float(group.get("satisfaction", 50.0)) - inflation_hit * 0.8, 5.0, 95.0)
	if int(policy.get("subsidy_months", 0)) > 0:
		policy["subsidy_months"] = int(policy.subsidy_months) - 1
		g.energy_policy = policy
		st["geopolitics"] = g

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var g: Dictionary = st["geopolitics"]
	var tick := _stamp(st)
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	var conflicts: Array = g.get("conflicts", []) if g.get("conflicts") is Array else []
	var active_conflicts := 0
	for c in conflicts:
		if str((c as Dictionary).get("status", "")) in ["hostilidades", "escalada", "impasse", "negociacao"]:
			active_conflicts += 1
	var profiles: Dictionary = st.get("international_state", {}).get("profiles", {}) if st.get("international_state") is Dictionary else {}
	var avg_debt := 0.0
	var count := 0
	for p in profiles.values():
		avg_debt += float((p as Dictionary).get("debt", 60.0))
		count += 1
	avg_debt = avg_debt / maxf(1.0, float(count))
	var last_shock := -999
	for s in g.shocks:
		if str((s as Dictionary).get("status", "")) == "ativo":
			last_shock = maxi(last_shock, int(s.get("months_total", 0)) - int(s.get("months_left", 0)))
	# Probabilidades derivadas de condições, não de um sorteio decorativo.
	if (g.shocks as Array).size() < 2 and active_conflicts < 5:
		var financial_pressure := clampf((avg_debt - 60.0) / 80.0, 0.0, 1.0)
		if _hash01("fin|" + tick) < 0.012 + financial_pressure * 0.035:
			spawn(st, "financeira" if financial_pressure > 0.35 else "recessao", clampf(0.35 + financial_pressure * 0.55, 0.3, 0.95), "dívida média %.0f%% do PIB e tensão financeira" % avg_debt)
		elif _hash01("energy|" + tick) < 0.010 + float(active_conflicts) * 0.007:
			spawn(st, "energia", clampf(0.4 + float(active_conflicts) * 0.08, 0.3, 0.9), "interrupção de rotas e conflitos em regiões produtoras")
		elif _hash01("comm|" + tick) < 0.008:
			spawn(st, "commodities", 0.45, "estoques baixos e concentração exportadora")
	# Aplica os choques ativos a cada país.
	var total_growth := 0.0
	var total_inflation := 0.0
	for i in (g.shocks as Array).size():
		var s: Dictionary = g.shocks[i]
		if str(s.get("status", "")) != "ativo":
			continue
		s["months_left"] = int(s.get("months_left", 1)) - 1
		var sev := float(s.get("severity", 0.5))
		var kind := str(s.get("type", ""))
		for id in profiles.keys():
			var p: Dictionary = profiles[id]
			var fin := Resources.vulnerability(str(id), "financeiro")
			var energy := Resources.vulnerability(str(id), "energia")
			var trade := Resources.vulnerability(str(id), "comercio")
			var hit := 0.0
			var inf := 0.0
			match kind:
				"recessao": hit = sev * (0.22 + trade * 0.42)
				"financeira": hit = sev * (0.20 + fin * 0.45); inf = sev * 0.08
				"divida": hit = sev * (0.18 + fin * 0.30 + float(p.get("debt", 60.0)) / 300.0); inf = sev * 0.18
				"cambio": hit = sev * (0.16 + fin * 0.32); inf = sev * (0.26 + fin * 0.40)
				"commodities": hit = sev * (0.14 + trade * 0.28); inf = sev * (0.22 + float(Resources.profile(str(id)).get("food_dependency", 0.2)) * 0.25)
				"energia": hit = sev * (0.16 + energy * 0.48); inf = sev * (0.26 + energy * 0.55)
			p["growth"] = clampf(float(p.get("growth", 2.0)) - hit, -15.0, 10.0)
			p["inflation"] = clampf(float(p.get("inflation", 4.0)) + inf, 0.5, 45.0)
			p["debt"] = clampf(float(p.get("debt", 60.0)) + hit * 0.10, 0.0, 240.0)
			profiles[id] = p
			total_growth -= hit
			total_inflation += inf
		_player_impact(st, kind, sev)
		if int(s.months_left) <= 0:
			s["status"] = "encerrado"
			s["months_left"] = 0
			_record_end(st, s)
		g.shocks[i] = s
	st["international_state"]["profiles"] = profiles
	if (g.shocks as Array).size() > 0:
		_record_effects(st, total_growth, total_inflation)
	st["geopolitics"] = g
	return {"active": (g.shocks as Array).size(), "growth": total_growth, "inflation": total_inflation}

static func _record_end(st: Dictionary, shock: Dictionary) -> void:
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	if world.is_empty():
		return
	WorldHistory.push(world, {
		"year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1)),
		"country": "GLOBAL", "country_name": "Sistema internacional", "category": "economia_global",
		"description": "%s perde intensidade; a recuperação é gradual." % str(shock.get("label", "")),
		"headline": "%s: fim da fase aguda" % str(shock.get("label", "")),
		"trigger": "duração do choque encerrada", "consequences": ["recuperação lenta", "dívida residual"],
		"actors": ["governos", "empresas"], "news": true,
	}, 2)
	st["world"] = world

static func _record_effects(st: Dictionary, growth: float, inflation: float) -> void:
	if absf(growth) < 0.02 and absf(inflation) < 0.02:
		return
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	if world.is_empty():
		return
	WorldHistory.push(world, {
		"year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1)),
		"country": "GLOBAL", "country_name": "Sistema internacional", "category": "economia_global",
		"description": "Choques externos subtraem crescimento e pressionam preços de forma assimétrica.",
		"headline": "Custo global do mês: crescimento %+.2f, inflação %+.2f" % [growth, inflation],
		"trigger": "transmissão por comércio, dívida e energia",
		"consequences": ["países mais expostos sofrem mais", "respostas domésticas alteram o impacto"],
		"actors": ["mercados"], "news": false,
	}, 1)
	st["world"] = world

static func energy_measure(st: Dictionary, measure: String) -> Dictionary:
	ensure(st)
	var g: Dictionary = st["geopolitics"]
	var policy: Dictionary = g.energy_policy
	var cost := 250.0
	if measure == "estoque":
		cost = 350.0
	elif measure == "diversificar":
		cost = 500.0
	elif measure == "subsidio":
		cost = 400.0
	else:
		return {"ok": false, "reason": "Medida energética desconhecida"}
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente para a medida (M$ %d)" % int(cost)}
	st["funds"] = float(st.funds) - cost
	if measure == "estoque":
		policy["stockpile"] = int(policy.get("stockpile", 0)) + 1
	elif measure == "diversificar":
		policy["diversification"] = int(policy.get("diversification", 0)) + 1
	else:
		policy["subsidy_months"] = int(policy.get("subsidy_months", 0)) + 3
	g.energy_policy = policy
	st["geopolitics"] = g
	return {"ok": true, "reason": "Medida energética registrada; o efeito é gradual e custa caixa"}

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var g: Dictionary = st["geopolitics"]
	var active: Array = []
	for s in g.shocks:
		if str((s as Dictionary).get("status", "")) == "ativo":
			active.append(s)
	return {"active": active, "count": active.size(), "policy": g.energy_policy.duplicate(true)}
