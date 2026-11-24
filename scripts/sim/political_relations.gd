extends RefCounted
## Sistema B4: relações partidárias dinâmicas, coalizões e facções.
##
## A relação não é só distância ideológica: ela guarda histórico de cooperação,
## disputa e compromissos. Coalizões têm termos, pastas e estabilidade. Facções
## do partido do jogador podem criticar, rebelar-se ou desafiar a liderança.

const MAX_DISTANCE := 282.8427
const PROGRAM_PATH := "res://config/coalition_program.json"
const CausalLog := preload("res://scripts/sim/causal_log.gd")

static var _program: Dictionary = {}

static func program() -> Dictionary:
	if _program.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRAM_PATH))
		_program = parsed if parsed is Dictionary else {}
	return _program

static func pair_key(a: String, b: String) -> String:
	var parts := [a, b]
	parts.sort()
	return "%s|%s" % [str(parts[0]), str(parts[1])]

static func init_state(st: Dictionary, positions: Dictionary) -> void:
	var relations := {}
	for a in positions.keys():
		for b in positions.keys():
			if str(a) >= str(b):
				continue
			var distance := (positions[a] as Vector2).distance_to(positions[b] as Vector2) / MAX_DISTANCE
			relations[pair_key(str(a), str(b))] = clampf(28.0 - distance * 62.0, -80.0, 80.0)
	st["party_relations"] = relations
	st["relation_history"] = []
	st["coalition_assignments"] = {}
	st["coalition_compliance"] = {}
	st["coalition_started"] = int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))
	init_factions(st)

static func ensure(st: Dictionary, positions: Dictionary) -> void:
	if not (st.get("party_relations") is Dictionary) or (st.party_relations as Dictionary).is_empty():
		init_state(st, positions)
	if not (st.get("factions") is Array) or (st.factions as Array).is_empty():
		init_factions(st)
	if not (st.get("coalition_assignments") is Dictionary):
		st["coalition_assignments"] = {}
	if not (st.get("coalition_compliance") is Dictionary):
		st["coalition_compliance"] = {}
	if not st.has("coalition_started"):
		st["coalition_started"] = int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))

static func relation(st: Dictionary, a: String, b: String) -> float:
	var relations: Dictionary = st.get("party_relations", {}) if st.get("party_relations") is Dictionary else {}
	return float(relations.get(pair_key(a, b), 0.0))

static func shift(st: Dictionary, a: String, b: String, delta: float, reason: String) -> void:
	if a == "" or b == "" or a == b:
		return
	var relations: Dictionary = st.get("party_relations", {}) if st.get("party_relations") is Dictionary else {}
	var key := pair_key(a, b)
	relations[key] = clampf(float(relations.get(key, 0.0)) + delta, -100.0, 100.0)
	st["party_relations"] = relations
	var history: Array = st.get("relation_history", []) if st.get("relation_history") is Array else []
	history.push_front({"month": str(st.get("date_year", 0)) + "-%02d" % int(st.get("date_month", 1)), "pair": key, "delta": delta, "value": relations[key], "reason": reason})
	if history.size() > 40:
		history = history.slice(0, 40)
	st["relation_history"] = history

static func tick(st: Dictionary, positions: Dictionary) -> void:
	var relations: Dictionary = st.get("party_relations", {}) if st.get("party_relations") is Dictionary else {}
	var keys: Array = relations.keys()
	for key in keys:
		var parts := str(key).split("|")
		if parts.size() != 2 or not positions.has(parts[0]) or not positions.has(parts[1]):
			continue
		var distance := (positions[parts[0]] as Vector2).distance_to(positions[parts[1]] as Vector2) / MAX_DISTANCE
		var target := 25.0 - distance * 55.0
		if st.get("coalition_partners") is Array and (st.coalition_partners as Array).has(parts[0]) and parts[1] == str(st.get("abbr", "")):
			target += 25.0
		if st.get("coalition_partners") is Array and (st.coalition_partners as Array).has(parts[1]) and parts[0] == str(st.get("abbr", "")):
			target += 25.0
		relations[key] = clampf(float(relations[key]) + (target - float(relations[key])) * 0.02, -100.0, 100.0)
	st["party_relations"] = relations

static func bill_update(st: Dictionary, by_party: Dictionary, player: String, partners: Array) -> void:
	for key in by_party.keys():
		var party := str(key)
		if party == player:
			continue
		var votes: Dictionary = by_party[key] if by_party[key] is Dictionary else {}
		var ayes := int(votes.get("sim", 0))
		var nayes := int(votes.get("nao", 0))
		if ayes + nayes <= 0:
			continue
		var delta := 2.5 if ayes > nayes else -2.5
		if partners.has(party) and ayes > nayes:
			delta += 1.5
		shift(st, player, party, delta, "votação parlamentar")

## Menor coalizão vencedora usando posição em dois eixos + relação acumulada.
static func coalition_terms(st: Dictionary, seat_map: Dictionary, positions: Dictionary, player_key: String, majority: int) -> Dictionary:
	var player_seats := int(seat_map.get(player_key, 0))
	if player_seats <= 0 or majority <= 1:
		return {}
	var player_pos: Vector2 = positions.get(player_key, Vector2.ZERO)
	var candidates: Array = []
	for key in seat_map.keys():
		var party := str(key)
		var seats := int(seat_map[party])
		if seats <= 0 or party == player_key:
			continue
		var distance := (positions.get(party, Vector2.ZERO) as Vector2).distance_to(player_pos) / MAX_DISTANCE
		var rel := relation(st, player_key, party)
		# Relação boa pode compensar distância; ideologia não decide sozinha.
		var score := distance - rel / 260.0
		candidates.append([party, seats, distance, rel, score])
	candidates.sort_custom(func(a, b): return float(a[4]) < float(b[4]))
	var picked: Array = []
	var total := player_seats
	for item in candidates:
		if total >= majority:
			break
		picked.append(item)
		total += int(item[1])
	if total < majority:
		return {}
	var partner_seats := 0
	var max_distance := 0.0
	var cost := 450.0
	var terms: Array = []
	var partner_names: Array = []
	for item in picked:
		partner_seats += int(item[1])
		max_distance = maxf(max_distance, float(item[2]))
		var party := str(item[0])
		var seats := int(item[1])
		var rel := float(item[3])
		var ministries := clampi(1 + int(round(float(seats) / maxf(1.0, float(majority)) * 3.0)), 1, 4)
		var demand_data := demand_for(positions.get(party, Vector2.ZERO))
		cost += float(seats) * 28.0 + maxf(0.0, 35.0 - rel) * 10.0
		terms.append({"party": party, "seats": seats, "ministries": ministries, "demand": str(demand_data.get("label", "compromisso")), "demand_policy": str(demand_data.get("policy", "investment")), "demand_axis": float(demand_data.get("axis", 0.0)), "relation": rel})
		partner_names.append(party)
	var cohesion := clampf(52.0 + (float(partner_seats) / maxf(1.0, float(majority))) * 12.0 - max_distance * 24.0, 20.0, 92.0)
	var relation_total := 0.0
	var relation_count := 0
	for item in picked:
		relation_total += float(item[3])
		relation_count += 1
	var avg_relation := relation_total / maxf(1.0, float(relation_count))
	var stability := clampf(45.0 + avg_relation * 0.35, 15.0, 95.0)
	return {
		"partners": partner_names, "partner_seats": partner_seats, "seats": total,
		"majority": majority, "cost": int(round(cost)), "spread": max_distance,
		"cohesion": cohesion, "stability": stability, "terms": terms,
		"negotiated": false,
	}

## Pauta programática: cada família ideológica exige uma proposição concreta.
## O eixo da proposição é usado para medir cumprimento e defeição no voto.
static func demand_for(pos: Vector2) -> Dictionary:
	var demands: Dictionary = program().get("demands", {})
	var key := "center"
	if pos.x >= 35.0:
		key = "right"
	elif pos.x <= -35.0:
		key = "left"
	elif pos.y >= 35.0:
		key = "conservative"
	elif pos.y <= -35.0:
		key = "progressive"
	return demands.get(key, {}) if demands.get(key) is Dictionary else {}

## Resultado de uma votação: acordo cumprido melhora relação/coesão; violação
## cobra o preço e pode levar um parceiro a deixar a coalizão. A decisão não é
## aleatória: depende do eixo real da proposição e do termo assinado.
static func apply_bill_result(st: Dictionary, bill: Dictionary, approved: bool, player_key: String) -> Dictionary:
	var outcome := {"events": [], "left": [], "cohesion": 0.0}
	if not approved or not bool(st.get("government", false)):
		return outcome
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	if partners.is_empty():
		return outcome
	var config_data := program()
	var tolerance := float(config_data.get("tolerance", 0.55))
	var bill_axis := float(bill.get("axis", 0.0))
	var terms: Array = st.get("coalition_terms", []) if st.get("coalition_terms") is Array else []
	var cohesion := float(st.get("coalition_cohesion", 60.0))
	var compliance: Dictionary = st.get("coalition_compliance", {}) if st.get("coalition_compliance") is Dictionary else {}
	for term in terms:
		var party := str(term.get("party", ""))
		if not partners.has(party):
			continue
		var distance := absf(bill_axis - float(term.get("demand_axis", 0.0)))
		if distance <= tolerance:
			shift(st, player_key, party, float(config_data.get("compliance_relation", 2.0)), "acordo de coalizão cumprido")
			cohesion += float(config_data.get("compliance_cohesion", 1.5))
			compliance[party] = int(compliance.get(party, 0)) + 1
			outcome.events.append("%s: pauta cumprida (%s); relação e coesão sobem." % [party, str(term.get("demand", "acordo"))])
			CausalLog.record(st, "coalizao", "%s aprovou %s" % [party, str(bill.get("title", "proposição"))], {"relation": float(config_data.get("compliance_relation", 2.0)), "cohesion": float(config_data.get("compliance_cohesion", 1.5))}, "O texto atende à pauta de %s; o aliado credita o compromisso e a base fica mais estável." % party)
		else:
			var penalty := float(config_data.get("violation_relation", -6.0))
			shift(st, player_key, party, penalty, "acordo de coalizão violado")
			cohesion += float(config_data.get("violation_cohesion", -4.0))
			compliance[party] = int(compliance.get(party, 0)) - 1
			outcome.events.append("%s: pauta contrariada (%s); relação %.0f e coesão %.0f." % [party, str(term.get("demand", "acordo")), penalty, float(config_data.get("violation_cohesion", -4.0))])
			CausalLog.record(st, "coalizao", "%s votou %s" % [party, str(bill.get("title", "proposição"))], {"relation": penalty, "cohesion": float(config_data.get("violation_cohesion", -4.0))}, "O texto contraria a pauta de %s; o aliado cobra o compromisso e a coalizão perde estabilidade." % party)
	st["coalition_cohesion"] = clampf(cohesion, 10.0, 100.0)
	st["coalition_compliance"] = compliance
	# Violação repetida ou relação destruída: o parceiro deixa a base.
	if float(st.coalition_cohesion) < 24.0:
		var weakest := ""
		var worst := 999.0
		for party in partners:
			var rel := relation(st, player_key, str(party))
			if rel < worst:
				worst = rel
				weakest = str(party)
		if weakest != "":
			remove_partner(st, weakest, player_key, "coesão abaixo de 24")
			outcome.left.append(weakest)
			outcome.events.append("%s deixa a coalizão após a violação do acordo." % weakest)
	outcome.cohesion = float(st.coalition_cohesion)
	st["coalition_stability"] = stability(st)
	return outcome

static func remove_partner(st: Dictionary, party: String, player_key: String, reason: String) -> void:
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	partners.erase(party)
	var seat_map: Dictionary = st.get("seat_map", {}) if st.get("seat_map") is Dictionary else {}
	st["coalition_partners"] = partners
	st["coalition_seats"] = maxi(0, int(st.get("coalition_seats", 0)) - int(seat_map.get(party, 0)))
	shift(st, player_key, party, -28.0, "saída da coalizão: " + reason)
	var kept: Array = []
	for term in (st.get("coalition_terms", []) if st.get("coalition_terms") is Array else []):
		if str(term.get("party", "")) != party:
			kept.append(term)
	st["coalition_terms"] = kept
	var assignments: Dictionary = st.get("coalition_assignments", {}) if st.get("coalition_assignments") is Dictionary else {}
	assignments.erase(party)
	st["coalition_assignments"] = assignments
	st["coalition_cohesion"] = 55.0

## Distribui uma pasta para o aliado com mais vagas prometidas ainda abertas.
## A nomeação passa a ser um ato de coalizão, não um botão isolado do gabinete.
static func assign_ministry(st: Dictionary, player_key: String) -> Dictionary:
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	if partners.is_empty():
		return {"party": "", "promised": 0, "assigned": 0}
	var terms: Array = st.get("coalition_terms", []) if st.get("coalition_terms") is Array else []
	var assignments: Dictionary = st.get("coalition_assignments", {}) if st.get("coalition_assignments") is Dictionary else {}
	var picked := ""
	var best_gap := -1
	var promised := 0
	for term in terms:
		var party := str(term.get("party", ""))
		if not partners.has(party):
			continue
		var want := int(term.get("ministries", 0))
		var gap := want - int(assignments.get(party, 0))
		if gap > best_gap:
			best_gap = gap
			picked = party
			promised = want
	if picked == "":
		# Coalizão formada por regra de emergência (sem termos detalhados):
		# ainda assim a primeira pasta dá crédito ao aliado.
		picked = str(partners[0])
		promised = 1
	assignments[picked] = int(assignments.get(picked, 0)) + 1
	st["coalition_assignments"] = assignments
	st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) + 1.0, 10.0, 100.0)
	st["coalition_stability"] = stability(st)
	shift(st, player_key, picked, 1.5, "pasta entregue ao aliado")
	CausalLog.record(st, "ministerio", "pasta atribuída a %s" % picked, {"cohesion": 1.0, "relation": 1.5}, "A nomeação cumpre parte do acordo de coalizão; o aliado ganha execução e a base ganha coesão.")
	return {"party": picked, "promised": promised, "assigned": int(assignments.get(picked, 0)), "gap": best_gap}

## Cobrança mensal das pastas prometidas. Três meses sem entrega geram
## desgaste verificável; cumprir o acordo estabiliza a relação.
static func ministry_pressure(st: Dictionary, player_key: String) -> Array:
	var events: Array = []
	if not bool(st.get("government", false)):
		return events
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	if partners.is_empty():
		return events
	var month := int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))
	var elapsed := month - int(st.get("coalition_started", month))
	if elapsed < 3:
		return events
	var terms: Array = st.get("coalition_terms", []) if st.get("coalition_terms") is Array else []
	var assignments: Dictionary = st.get("coalition_assignments", {}) if st.get("coalition_assignments") is Dictionary else {}
	var missing_total := 0
	for term in terms:
		var party := str(term.get("party", ""))
		if not partners.has(party):
			continue
		var missing := maxi(0, int(term.get("ministries", 0)) - int(assignments.get(party, 0)))
		missing_total += missing
		if missing <= 0:
			continue
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - float(missing) * 0.8, 10.0, 100.0)
		shift(st, player_key, party, -float(missing) * 0.8, "pasta prometida não entregue")
		if elapsed % 3 == 0:
			events.append("%s cobra %d pasta(s) prometida(s) e não entregue(s): coesão em %.0f." % [party, missing, float(st.get("coalition_cohesion", 60.0))])
	if missing_total == 0:
		for party in partners:
			shift(st, player_key, str(party), 0.4, "quotas de pastas cumpridas")
		if elapsed % 3 == 0:
			events.append("As quotas de pastas da coalizão estão cumpridas; a base permanece estabilizada.")
	return events

## Estabilidade combina coesão, relação média, desgaste de crise e greves.
static func stability(st: Dictionary) -> float:
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	var cohesion := float(st.get("coalition_cohesion", 60.0))
	var total := cohesion
	if not partners.is_empty():
		var sum := 0.0
		for party in partners:
			sum += relation(st, str(st.get("abbr", "")), str(party))
		total = cohesion * 0.7 + (sum / float(partners.size())) * 0.3
	total -= float(st.get("scandal_penalty", 0.0)) * 1.5
	total -= float(st.get("strike_impact", 0.0)) * 12.0
	return clampf(total, 0.0, 100.0)

## Renegociação: custa caixa, melhora relação e reduz o custo financeiro; a
## coesão esperada sobe, mas a ala ideológica do partido paga o compromisso.
static func renegotiate(st: Dictionary, deal: Dictionary, player_key: String) -> Dictionary:
	if deal.is_empty() or not (deal.get("partners") is Array):
		return {"ok": false, "reason": "Sem coalizão para renegociar"}
	var cost := 350.0
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente"}
	st["funds"] = float(st.funds) - cost
	var partners: Array = deal.partners
	for party in partners:
		shift(st, player_key, str(party), 4.0, "renegociação de coalizão")
	deal["cost"] = int(round(float(deal.get("cost", 0)) * 0.85))
	deal["cohesion"] = minf(95.0, float(deal.get("cohesion", 60.0)) + 6.0)
	deal["negotiated"] = true
	var factions: Array = st.get("factions", [])
	for faction in factions:
		if str(faction.get("id", "")) == "ideological":
			faction.satisfaction = clampf(float(faction.satisfaction) - 4.0, 0.0, 100.0)
	return {"ok": true, "reason": "Termos renegociados com as bancadas.", "deal": deal}

static func init_factions(st: Dictionary) -> void:
	var pos: Dictionary = st.get("ideology_position", {}) if st.get("ideology_position") is Dictionary else {}
	var economic := float(pos.get("economic", 0.0))
	var social := float(pos.get("social", 0.0))
	var toward_center := -signf(economic) * 22.0 if absf(economic) > 25.0 else 12.0
	var outward := signf(economic if absf(economic) > 1.0 else 1.0) * 20.0
	st["factions"] = [
		{"id": "base", "name": "Base militante", "strength": 0.50, "economic": economic, "social": social, "loyalty": 78.0, "satisfaction": 72.0, "concerns": ["unidade", "mobilização"]},
		{"id": "ideological", "name": "Ala ideológica", "strength": 0.30, "economic": clampf(economic + outward, -100.0, 100.0), "social": clampf(social + signf(social if absf(social) > 1.0 else 1.0) * 15.0, -100.0, 100.0), "loyalty": 56.0, "satisfaction": 66.0, "concerns": ["fidelidade programática", "coerência"]},
		{"id": "pragmatic", "name": "Ala pragmática", "strength": 0.20, "economic": clampf(economic + toward_center, -100.0, 100.0), "social": clampf(social * 0.6, -100.0, 100.0), "loyalty": 52.0, "satisfaction": 60.0, "concerns": ["governabilidade", "resultados"]},
	]

static func faction_tick(st: Dictionary, policy_position: Vector2, compromised: bool) -> Array:
	var factions: Array = st.get("factions", []) if st.get("factions") is Array else []
	var events: Array = []
	if factions.is_empty():
		init_factions(st)
		factions = st.factions
	for faction in factions:
		var pos := Vector2(float(faction.economic), float(faction.social))
		var alignment := 100.0 - pos.distance_to(policy_position) / MAX_DISTANCE * 100.0
		var target := 35.0 + alignment * 0.45 + float(faction.loyalty) * 0.2
		if compromised and str(faction.id) == "ideological":
			target -= 10.0
		if compromised and str(faction.id) == "pragmatic":
			target += 6.0
		faction.satisfaction = clampf(float(faction.satisfaction) + (clampf(target, 0.0, 100.0) - float(faction.satisfaction)) * 0.08, 0.0, 100.0)
		if float(faction.satisfaction) < 28.0 and int(st.get("date_month", 1)) % 3 == 0:
			events.append({"type": "critica", "text": "%s critica publicamente a liderança do partido." % str(faction.name)})
			st["cohesion"] = clampf(float(st.get("cohesion", 78.0)) - 1.2, 10.0, 100.0)
	if not factions.is_empty():
		var lowest := 101.0
		for faction in factions:
			lowest = minf(lowest, float(faction.satisfaction))
		if lowest < 18.0 and not bool(st.get("leadership_challenge", false)):
			st["leadership_challenge"] = true
			events.append({"type": "desafio", "text": "Uma ala do partido articula desafio à liderança."})
	return events

static func faction_penalty(st: Dictionary) -> float:
	var factions: Array = st.get("factions", []) if st.get("factions") is Array else []
	var lowest := 100.0
	for faction in factions:
		lowest = minf(lowest, float(faction.satisfaction))
	if lowest >= 35.0:
		return 0.0
	return clampf((35.0 - lowest) / 100.0, 0.0, 0.25)

static func faction_summary(st: Dictionary) -> Array:
	var rows: Array = []
	for faction in (st.get("factions", []) if st.get("factions") is Array else []):
		rows.append({"name": str(faction.name), "strength": float(faction.strength), "satisfaction": float(faction.satisfaction), "loyalty": float(faction.loyalty), "concerns": faction.concerns})
	return rows

static func matrix(st: Dictionary, parties: Array) -> Array:
	var rows: Array = []
	for a in parties:
		var row := {"party": str(a), "values": []}
		for b in parties:
			if str(a) == str(b):
				row.values.append(null)
			else:
				row.values.append(relation(st, str(a), str(b)))
		rows.append(row)
	return rows
