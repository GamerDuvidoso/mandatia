extends RefCounted
## Sistema B3: organizações de interesse e conflito distributivo.
##
## Organizações têm agenda, influência, relação e capacidade de organização.
## Uma greve não é um modificador instantâneo: ela persiste, reduz produção,
## pressiona inflação/contas públicas, desgasta a coalizão e pode ser encerrada
## por negociação. Os efeitos alimentam os mesmos indicadores que o resto do
## simulador já lê.

const DATA_PATH := "res://config/interest_groups.json"
const NEGOTIATION_COST := 800.0
const STRIKE_NEGOTIATION_COST := 1400.0
const STRIKE_COOLDOWN := 4
const CausalLog := preload("res://scripts/sim/causal_log.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func definitions() -> Array:
	return config().get("groups", [])

static func definition(id: String) -> Dictionary:
	for entry in definitions():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func _alignment_score(entry: Dictionary, position: Vector2) -> float:
	var pref := Vector2(float(entry.get("economic", 0.0)), float(entry.get("social", 0.0)))
	return clampf(100.0 - pref.distance_to(position) / 282.8427 * 100.0, 0.0, 100.0)

static func _empty_strike() -> Dictionary:
	return {"active": false, "months": 0, "intensity": 0.0, "demand": "", "lost_output": 0.0}

static func init_state(st: Dictionary) -> void:
	var player := Vector2(float(st.get("ideology_position", {}).get("economic", 0.0)), float(st.get("ideology_position", {}).get("social", 0.0)))
	var groups := {}
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var alignment := _alignment_score(entry, player)
		var relation := clampf(float(entry.get("base_relation", 0.0)) + (alignment - 50.0) * 0.5, -60.0, 80.0)
		groups[id] = {
			"name": str(entry.get("name", id)), "kind": str(entry.get("kind", "organização")),
			"influence": float(entry.get("influence", 40.0)),
			"represented_share": float(entry.get("represented_share", 0.0)),
			"objectives": entry.get("objectives", []),
			"alignment": {"economic": float(entry.get("economic", 0.0)), "social": float(entry.get("social", 0.0))},
			"relationship": relation, "negotiation": float(entry.get("negotiation", 5.0)),
			"activity": clampf(45.0 + (100.0 - alignment) * 0.25, 10.0, 95.0),
			"grievance": clampf(18.0 + (100.0 - alignment) * 0.18, 0.0, 100.0),
			"last_strike": -99, "last_action_month": "", "endorsed_month": "",
			"stance": "neutra", "strike": _empty_strike(),
		}
	st["interest_groups"] = groups
	st["strike_impact"] = 0.0

static func ensure(st: Dictionary) -> void:
	if not (st.get("interest_groups") is Dictionary) or (st.interest_groups as Dictionary).is_empty():
		init_state(st)
		return
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var groups: Dictionary = st.interest_groups
		if not groups.has(id):
			continue
		var org: Dictionary = groups[id]
		if not (org.get("strike") is Dictionary):
			org["strike"] = _empty_strike()
		if not org.has("grievance"):
			org["grievance"] = 18.0
	if not st.has("strike_impact"):
		st["strike_impact"] = 0.0

static func _linked_group(entry: Dictionary) -> String:
	return str(entry.get("linked_group", ""))

static func _social(st: Dictionary, group_id: String) -> Dictionary:
	var social: Dictionary = st.get("social_groups", {}) if st.get("social_groups") is Dictionary else {}
	return social.get(group_id, {}) if social.get(group_id) is Dictionary else {}

## Pressão vinda do histórico recente de políticas: uma reforma que retira
## direitos aumenta a queixa por vários meses, não apenas no mês da votação.
static func _policy_pressure(st: Dictionary, id: String) -> float:
	var all_stances: Dictionary = config().get("policy_stance", {}) if config().get("policy_stance", {}) is Dictionary else {}
	var log: Array = st.get("policy_log", []) if st.get("policy_log") is Array else []
	var pressure := 0.0
	for item in log.slice(0, mini(8, log.size())):
		var policy_id := str(item.get("policy", ""))
		var policy_map: Dictionary = all_stances.get(policy_id, {}) if all_stances.get(policy_id) is Dictionary else {}
		var value := float(policy_map.get(id, 0.0))
		if value < 0.0:
			pressure += absf(value) * 0.18
	return pressure

static func _strike_effects(st: Dictionary, org: Dictionary, entry: Dictionary) -> Dictionary:
	var intensity := clampf(float(org.strike.intensity), 0.05, 1.0)
	var influence := float(org.influence)
	var lost := (0.06 + intensity * 0.12) * (influence / 70.0)
	var public_sector := str(entry.get("id", "")) == "public_union"
	var effects := {
		"economy": -lost,
		"gdp": -lost * 2.2,
		"inflation": 0.03 + intensity * 0.03,
		"unemployment": 0.01 + intensity * 0.02,
		"debt": 0.015 + intensity * 0.02,
		"approval": -(0.5 + intensity * 0.9),
		"coalition_cohesion": -intensity * 1.1,
		"funds": -(55.0 * intensity) if public_sector else 0.0,
	}
	st["economy"] = clampf(float(st.get("economy", 2.4)) + float(effects.economy), -2.0, 6.0)
	st["gdp"] = maxf(20.0, float(st.get("gdp", 100.0)) + float(effects.gdp))
	st["inflation"] = clampf(float(st.get("inflation", 4.8)) + float(effects.inflation), 1.5, 15.0)
	st["unemployment"] = clampf(float(st.get("unemployment", 8.2)) + float(effects.unemployment), 3.5, 18.0)
	st["debt"] = clampf(float(st.get("debt", 60.0)) + float(effects.debt), 20.0, 120.0)
	st["approval"] = clampf(float(st.get("approval", 45.0)) + float(effects.approval), 0.0, 100.0)
	st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) + float(effects.coalition_cohesion), 10.0, 100.0)
	if public_sector:
		st["funds"] = maxf(0.0, float(st.get("funds", 0.0)) + float(effects.funds))
	var linked := _linked_group(entry)
	var social := _social(st, linked)
	if not social.is_empty():
		social.satisfaction = clampf(float(social.get("satisfaction", 50.0)) - (0.8 + intensity), 5.0, 95.0)
		social.approval = float(social.satisfaction)
	return effects

static func monthly(st: Dictionary) -> Array:
	ensure(st)
	var events: Array = []
	var player := Vector2(float(st.get("ideology_position", {}).get("economic", 0.0)), float(st.get("ideology_position", {}).get("social", 0.0)))
	var approval := float(st.get("approval", 45.0))
	var month_index := int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))
	var total_strike_impact := 0.0
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var org: Dictionary = st.interest_groups[id]
		var linked := _linked_group(entry)
		var social := _social(st, linked)
		var satisfaction := float(social.get("satisfaction", 50.0))
		var target := (approval - 45.0) * 0.5 + (_alignment_score(entry, player) - 50.0) * 0.6
		if bool(st.get("government", false)):
			target += (float(st.get("coalition_cohesion", 60.0)) - 60.0) * 0.15
		if bool(org.strike.active):
			target -= 8.0 * float(org.strike.intensity)
		org.relationship = clampf(float(org.relationship) + (target - float(org.relationship)) * 0.06, -100.0, 100.0)
		var hostile := maxf(0.0, 20.0 - float(org.relationship))
		org.activity = clampf(float(org.activity) + (hostile * 0.4 - (float(org.activity) - 40.0) * 0.05), 5.0, 100.0)
		if float(org.relationship) > 22.0:
			org.stance = "aliada"
		elif float(org.relationship) < -22.0:
			org.stance = "opositora"
		else:
			org.stance = "neutra"
		# Queixa é estoque: relação ruim, satisfação baixa, inflação e políticas
		# recentes acumulam; relação boa e renda real a reduzem.
		var wage_pressure := maxf(0.0, float(st.get("inflation", 4.8)) - 4.0) * 1.8
		var grievance := float(org.get("grievance", 0.0))
		grievance += maxf(0.0, 18.0 - float(org.relationship)) * 0.16
		grievance += maxf(0.0, 45.0 - satisfaction) * 0.12
		grievance += wage_pressure + _policy_pressure(st, id)
		if float(st.get("coalition_cohesion", 60.0)) < 40.0 and bool(st.get("government", false)):
			grievance += 0.8
		if float(org.relationship) > 35.0 and satisfaction > 50.0:
			grievance -= 1.6
		org["grievance"] = clampf(grievance, 0.0, 100.0)
		var threshold := float(entry.get("strike_threshold", 60.0))
		if str(entry.get("kind", "")) == "sindicato" and bool(st.get("government", false)) and not bool(org.strike.active):
			if float(org.grievance) >= threshold and month_index - int(org.get("last_strike", -99)) >= STRIKE_COOLDOWN:
				org.strike = {
					"active": true, "months": 0,
					"intensity": clampf(0.35 + float(org.influence) / 220.0 + maxf(0.0, float(org.grievance) - threshold) / 100.0, 0.3, 0.9),
					"demand": str((entry.get("objectives", [""]) as Array)[0]) if not (entry.get("objectives", []) as Array).is_empty() else "reajuste",
					"lost_output": 0.0,
				}
				org["last_strike"] = month_index
				org.activity = minf(100.0, float(org.activity) + 18.0)
				events.append({"group": id, "type": "greve_inicio", "text": "%s entra em greve por %s (queixa %.0f/100)." % [str(org.name), str(org.strike.demand), float(org.grievance)]})
		if bool(org.strike.active):
			org.strike.months = int(org.strike.get("months", 0)) + 1
			# Conflito longo endurece a posição, mas a exaustão reduz a adesão.
			var drift := 0.04 if float(org.relationship) < -25.0 else -0.02
			org.strike.intensity = clampf(float(org.strike.intensity) + drift, 0.2, 1.0)
			var effects := _strike_effects(st, org, entry)
			org.strike.lost_output = float(org.strike.get("lost_output", 0.0)) + absf(float(effects.economy))
			total_strike_impact += absf(float(effects.economy))
			events.append({"group": id, "type": "greve", "text": "%s: %dº mês de greve; produção -%.2f, inflação +%.2f p.p., aprovação %.1f." % [str(org.name), int(org.strike.months), absf(float(effects.economy)), float(effects.inflation), float(effects.approval)]})
			CausalLog.record(st, "greve", "%s em greve por %s" % [str(org.name), str(org.strike.demand)], effects, "Greve ativa há %d mês(es): perda de produção reduz crescimento, pressiona preços e desgasta o governo." % int(org.strike.months))
			if int(org.strike.months) >= 6 and float(org.relationship) > -18.0:
				_end_strike(st, id, false, 0.0)
				events.append({"group": id, "type": "greve_fim", "text": "%s encerra a greve por exaustão, sem acordo formal." % str(org.name)})
		elif float(org.relationship) > 35.0 and float(org.activity) > 55.0:
			events.append({"group": id, "type": "apoio", "text": "%s manifesta apoio ao governo." % str(org.name)})
	st["strike_impact"] = total_strike_impact
	return events

static func _end_strike(st: Dictionary, id: String, conceded: bool, cost: float, paid := -1.0) -> Dictionary:
	var groups: Dictionary = st.get("interest_groups", {})
	if not groups.has(id):
		return {"ok": false, "reason": "Organização desconhecida"}
	var org: Dictionary = groups[id]
	if not bool(org.get("strike", {}).get("active", false)):
		return {"ok": false, "reason": "Não há greve ativa"}
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente para o acordo"}
	st["funds"] = float(st.funds) - cost
	var entry := definition(id)
	org.strike.active = false
	org.strike.months = 0
	org.strike.intensity = 0.0
	org.last_strike = int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))
	org["grievance"] = clampf(float(org.get("grievance", 50.0)) - (32.0 if conceded else 16.0), 0.0, 100.0)
	org.relationship = clampf(float(org.relationship) + (10.0 if conceded else 4.0), -100.0, 100.0)
	var linked := _linked_group(entry)
	var social := _social(st, linked)
	if not social.is_empty():
		social.satisfaction = clampf(float(social.get("satisfaction", 50.0)) + (4.0 if conceded else 1.5), 5.0, 95.0)
		social.approval = float(social.satisfaction)
	if conceded:
		st["debt"] = clampf(float(st.get("debt", 60.0)) + 0.15, 20.0, 120.0)
	st["strike_impact"] = maxf(0.0, float(st.get("strike_impact", 0.0)) - 0.05)
	var spent := paid if paid >= 0.0 else cost
	var effects := {"funds": -spent, "relationship": 10.0 if conceded else 4.0, "grievance": -32.0 if conceded else -16.0, "debt": 0.15 if conceded else 0.0}
	CausalLog.record(st, "greve", "acordo com %s" % str(org.name), effects, "Greve encerrada por %s; a relação e a satisfação sobem, mas o acordo tem custo fiscal." % ("concessão" if conceded else "mediação"))
	return {"ok": true, "reason": "%s encerra a greve." % str(org.name), "conceded": conceded, "effects": effects}

## A política aprovada move a relação conforme a pauta declarada e reduz a
## queixa quando atende a organização. Não encerra greve automaticamente.
static func apply_policy(st: Dictionary, policy_id: String) -> Array:
	ensure(st)
	var stance: Dictionary = config().get("policy_stance", {}).get(policy_id, {})
	var changed: Array = []
	for id in stance.keys():
		if not (st.interest_groups as Dictionary).has(str(id)):
			continue
		var org: Dictionary = st.interest_groups[str(id)]
		var delta := float(stance[id])
		org.relationship = clampf(float(org.relationship) + delta, -100.0, 100.0)
		org.activity = clampf(float(org.activity) + absf(delta) * 0.6, 5.0, 100.0)
		org["grievance"] = clampf(float(org.get("grievance", 0.0)) - delta * 1.4, 0.0, 100.0)
		if bool(org.get("strike", {}).get("active", false)) and delta > 0.0:
			org.strike.intensity = maxf(0.2, float(org.strike.intensity) - delta * 0.02)
		changed.append({"group": str(id), "delta": delta})
	return changed

static func negotiate(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	if not (st.interest_groups as Dictionary).has(id):
		return {"ok": false, "reason": "Organização desconhecida"}
	var org: Dictionary = st.interest_groups[id]
	var on_strike := bool(org.get("strike", {}).get("active", false))
	var cost := STRIKE_NEGOTIATION_COST if on_strike else NEGOTIATION_COST
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente"}
	st["funds"] = float(st.funds) - cost
	org.relationship = clampf(float(org.relationship) + (14.0 if not on_strike else 8.0), -100.0, 100.0)
	org.activity = clampf(float(org.activity) - 3.0, 5.0, 100.0)
	org["grievance"] = clampf(float(org.get("grievance", 0.0)) - (18.0 if on_strike else 8.0), 0.0, 100.0)
	var linked := _linked_group(definition(id))
	var social := _social(st, linked)
	if not social.is_empty():
		social.satisfaction = clampf(float(social.satisfaction) + (4.0 if on_strike else 3.0), 5.0, 95.0)
		social.approval = float(social.satisfaction)
	st["social_support"] = float(st.get("social_support", 50.0)) + 0.2
	if on_strike:
		return _end_strike(st, id, true, 0.0, cost)
	return {"ok": true, "reason": "%s aceita negociar." % str(org.name), "relationship": float(org.relationship), "cost": cost}

static func endorse(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	if not (st.interest_groups as Dictionary).has(id):
		return {"ok": false, "reason": "Organização desconhecida"}
	var org: Dictionary = st.interest_groups[id]
	if bool(org.get("strike", {}).get("active", false)):
		return {"ok": false, "reason": "Organização em greve não endossa o governo"}
	var month := "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
	if str(org.get("endorsed_month", "")) == month:
		return {"ok": false, "reason": "Endosso já usado neste mês"}
	if float(org.relationship) < 20.0:
		return {"ok": false, "reason": "Relação insuficiente para endosso"}
	org["endorsed_month"] = month
	org.relationship = clampf(float(org.relationship) - 4.0, -100.0, 100.0)
	st["campaign"] = float(st.get("campaign", 0.0)) + 1.5
	st["popularity"] = float(st.get("popularity", 4.0)) + 1.0
	return {"ok": true, "reason": "%s endossa a campanha." % str(org.name), "group": id, "relationship": float(org.relationship)}

static func relation(st: Dictionary, id: String) -> float:
	var groups: Dictionary = st.get("interest_groups", {}) if st.get("interest_groups") is Dictionary else {}
	var org: Dictionary = groups.get(id, {}) if groups.get(id) is Dictionary else {}
	return float(org.get("relationship", 0.0))

static func active_strikes(st: Dictionary) -> Array:
	ensure(st)
	var rows: Array = []
	for id in (st.interest_groups as Dictionary).keys():
		var org: Dictionary = st.interest_groups[id]
		if bool(org.get("strike", {}).get("active", false)):
			rows.append({"id": str(id), "name": str(org.get("name", id)), "months": int(org.strike.get("months", 0)), "intensity": float(org.strike.get("intensity", 0.0)), "demand": str(org.strike.get("demand", "")), "lost_output": float(org.strike.get("lost_output", 0.0))})
	return rows

static func sorted_groups(st: Dictionary) -> Array:
	ensure(st)
	var rows: Array = []
	for id in (st.interest_groups as Dictionary).keys():
		var org: Dictionary = st.interest_groups[id]
		rows.append({"id": str(id), "name": str(org.name), "kind": str(org.kind), "influence": float(org.influence), "relationship": float(org.relationship), "activity": float(org.activity), "stance": str(org.stance), "objectives": org.objectives, "represented_share": float(org.represented_share), "grievance": float(org.get("grievance", 0.0)), "strike": org.get("strike", _empty_strike())})
	rows.sort_custom(func(a, b): return float(a.influence) > float(b.influence))
	return rows
