extends RefCounted
## E1 — legislativo autônomo.
##
## A pauta nasce da prioridade do governo. Cada partido vota conforme distância
## ideológica ao projeto, pertencimento à coalizão e disciplina (determinística).
## O governo pode perder: não há aprovação automática.
##
## Efeitos aprovados entram nas variáveis macro do país e na aprovação. Em
## sistemas parlamentares, uma derrota com base minoritária pode antecipar a
## eleição — sem inventar crise: é o mecanismo institucional de confiança.

const Election := preload("res://scripts/sim/election.gd")
const WorldHistory := preload("res://scripts/sim/world_history.gd")
const CountryEconomy := preload("res://scripts/sim/country_economy_simulation.gd")

const AGENDA := [
	{"id": "employment", "title": "Plano de emprego", "axis": -0.45, "priority": "empregos", "effects": {"growth": 0.05, "unemployment": -0.08, "debt": 0.06}, "approval": 0.30},
	{"id": "stabilization", "title": "Programa de estabilização", "axis": 0.25, "priority": "estabilizacao", "effects": {"inflation": -0.12, "growth": -0.03}, "approval": -0.20},
	{"id": "investment", "title": "Pacote de investimento", "axis": -0.10, "priority": "investimento", "effects": {"growth": 0.06, "unemployment": -0.03, "debt": 0.07}, "approval": 0.15},
	{"id": "austerity", "title": "Revisão fiscal", "axis": 0.60, "priority": "austeridade", "effects": {"debt": -0.12, "growth": -0.04}, "approval": -0.35},
	{"id": "welfare", "title": "Ampliação social", "axis": -0.55, "priority": "negociacao", "effects": {"unemployment": -0.04, "debt": 0.06}, "approval": 0.40},
	{"id": "deregulation", "title": "Agenda de desregulamentação", "axis": 0.70, "priority": "investimento", "effects": {"growth": 0.07, "debt": -0.03}, "approval": -0.10},
]

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _bill_for(priority: String, stamp: String) -> Dictionary:
	var candidates := []
	for row in AGENDA:
		if str(row.get("priority", "")) == priority:
			candidates.append(row)
	if candidates.is_empty():
		return {}
	if candidates.size() == 1:
		return candidates[0]
	return candidates[int(_hash01(stamp + "|" + priority) * candidates.size()) % candidates.size()]

static func monthly(world: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int) -> Dictionary:
	var stamp := "%d-%02d" % [year, month]
	if _hash01(str(wc.get("id", "")) + "|leg|" + stamp) > 0.45:
		return {}
	var bill := _bill_for(str(wc.get("policy_priority", "investimento")), stamp)
	if bill.is_empty():
		return {}
	var parties: Dictionary = wc.get("parties", {})
	var gov_party := str(wc.get("government_party", ""))
	var partners: Array = wc.get("coalition_partners", []) if wc.get("coalition_partners") is Array else []
	var axis_target := float(bill.get("axis", 0.0))
	var gov_axis := float(wc.get("government_axis", 0.0))
	var ayes := 0
	var nayes := 0
	var abstain := 0
	for key in parties.keys():
		var party: Dictionary = parties[key]
		var seats := int(party.get("seats", 0))
		if seats <= 0:
			continue
		var axis := Election.ideology_axis(str(party.get("ideology", "")))
		var distance := absf(axis - axis_target)
		# Base mais baixa e distância mais forte: o governo não passa tudo. Uma
		# bancada distante do projeto vota contra mesmo fora da oposição formal.
		var yes := 0.40 + maxf(0.0, 0.70 - distance) * 0.55
		var government_side := str(key) == gov_party or partners.has(str(key))
		if government_side:
			yes += 0.15
		else:
			yes -= 0.12
		yes += (_hash01(str(wc.get("id", "")) + "|" + str(key) + "|" + stamp) - 0.5) * 0.25
		yes = clampf(yes, 0.02, 0.98)
		var yes_seats := int(round(float(seats) * yes))
		var abstain_seats := int(round(float(seats) * 0.05))
		abstain_seats = mini(abstain_seats, seats - yes_seats)
		ayes += yes_seats
		abstain += abstain_seats
		nayes += maxi(0, seats - yes_seats - abstain_seats)
	var total := ayes + nayes + abstain
	if total <= 0:
		return {}
	var passed := ayes > nayes
	WorldHistory.bump(world, "votes")
	if not passed:
		WorldHistory.bump(world, "defeats")
	wc["last_vote"] = {"bill": str(bill.get("id", "")), "ayes": ayes, "nayes": nayes, "abstain": abstain, "passed": passed, "month": stamp}
	var name := str(wc.get("name", wc.get("id", "")))
	if passed:
		var effects: Dictionary = bill.get("effects", {})
		profile["growth"] = clampf(float(profile.get("growth", 2.0)) + float(effects.get("growth", 0.0)), -8.0, 10.0)
		profile["inflation"] = clampf(float(profile.get("inflation", 4.5)) + float(effects.get("inflation", 0.0)), 0.5, 40.0)
		profile["unemployment"] = clampf(float(profile.get("unemployment", 7.0)) + float(effects.get("unemployment", 0.0)), 2.0, 30.0)
		profile["debt"] = clampf(float(profile.get("debt", 60.0)) + float(effects.get("debt", 0.0)), 0.0, 200.0)
		wc["approval"] = clampf(float(wc.get("approval", 50.0)) + float(bill.get("approval", 0.0)), 3.0, 92.0)
		wc["stability"] = clampf(float(wc.get("stability", 60.0)) + 1.5, 5.0, 98.0)
		profile["approval"] = wc.approval
		profile["stability"] = wc.stability
	else:
		wc["approval"] = clampf(float(wc.get("approval", 50.0)) + float(bill.get("approval", 0.0)) * -0.5, 3.0, 92.0)
		wc["stability"] = clampf(float(wc.get("stability", 60.0)) - 3.0, 5.0, 98.0)
		profile["approval"] = wc.approval
		profile["stability"] = wc.stability
	var majority := int(wc.get("chamber_seats", 1) / 2) + 1
	var coalition := int(wc.get("coalition_seats", 0))
	if not passed and str(wc.get("system", "")) == "parlamentar" and coalition < majority and float(wc.get("stability", 60.0)) < 45.0:
		wc["months_to_election"] = mini(int(wc.get("months_to_election", 1)), 2)
		WorldHistory.push(world, {
			"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
			"category": "politica",
			"description": "Governo de %s perde a votação e antecipa a eleição." % name,
			"headline": "%s antecipa eleição após derrota no parlamento" % name,
			"trigger": "base minoritária, derrota legislativa e estabilidade abaixo de 45",
			"consequences": ["eleição antecipada em até 2 meses"],
			"actors": [gov_party], "status": "confirmado", "news": true,
		}, 6)
	WorldHistory.push(world, {
		"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
		"category": "legislativo",
		"description": "%s %s no parlamento de %s (%d a favor, %d contra, %d abstenções)." % [str(bill.get("title", "Projeto")), "aprovada" if passed else "rejeitada", name, ayes, nayes, abstain],
		"headline": "%s: %s %s (%d)" % [name, str(bill.get("title", "projeto")), "aprovado" if passed else "rejeitado", year],
		"trigger": "pauta prioritária: %s" % str(wc.get("policy_priority", "")),
		"consequences": ["efeitos macro aplicados" if passed else "governo perde estabilidade"],
		"actors": [gov_party], "status": "confirmado", "news": _hash01(str(wc.get("id", "")) + "|news|" + stamp) < 0.5,
	}, 12)
	return {"passed": passed, "ayes": ayes, "nayes": nayes, "abstain": abstain, "bill": str(bill.get("id", ""))}
