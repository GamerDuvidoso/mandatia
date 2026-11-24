extends RefCounted
## E1 — partidos autônomos.
##
## O apoio eleitoral de cada partido reage ao desempenho do governo (aprovação e
## economia) e reverte lentamente à sua base estrutural (participação na última
## eleição). O partido do governo absorve o bônus/ônus; a oposição recebe o sinal
## contrário proporcionalmente. Nada muda sem causa registrada.
##
## Lideranças mudam quando a estabilidade interna cai abaixo de 32 por vários
## meses; o evento declara a causa. Não há troca de ideologia nem fusão arbitrária.

const WorldHistory := preload("res://scripts/sim/world_history.gd")

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func init_parties(official: Array, government_party: String) -> Dictionary:
	var parties := {}
	var total := 0
	for row in official:
		var abbr := str(row.get("abbr", "")).strip_edges()
		if abbr == "":
			continue
		var seats := int(row.get("lower_house_seats", 0)) if row.get("lower_house_seats", null) != null else 0
		parties[abbr] = {
			"id": abbr, "name": str(row.get("name", abbr)), "ideology": str(row.get("ideology", "")),
			"leader": str(row.get("leader", "")), "seats": maxi(0, seats), "support": float(maxi(0, seats)),
			"stability": 62.0, "in_gov": abbr == government_party,
			"in_coalition": false, "leadership_since": "", "last_support": float(maxi(0, seats)),
		}
		total += maxi(0, seats)
	if total > 0:
		for key in parties.keys():
			parties[key]["support"] = float(parties[key].seats) / float(total) * 100.0
			parties[key]["last_support"] = parties[key].support
	return parties

static func _normalize(parties: Dictionary) -> void:
	var total := 0.0
	for key in parties.keys():
		total += maxf(0.0, float(parties[key].get("support", 0.0)))
	if total <= 0.0:
		return
	for key in parties.keys():
		parties[key]["support"] = maxf(0.0, float(parties[key].support)) / total * 100.0

static func monthly(world: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int) -> void:
	var parties: Dictionary = wc.get("parties", {})
	if parties.is_empty():
		return
	var approval := float(wc.get("approval", 50.0))
	var potential := float(base.get("potential_growth", 2.0))
	var natural := float(base.get("natural_unemployment", 7.0))
	var growth := float(profile.get("growth", potential))
	var inflation := float(profile.get("inflation", 4.5))
	var unemployment := float(profile.get("unemployment", natural))
	var economy := (growth - potential) * 0.20 - maxf(0.0, inflation - 4.5) * 0.10 - maxf(0.0, unemployment - natural) * 0.06
	var swing := (approval - 50.0) * 0.015 + economy * 0.10
	var gov_party := str(wc.get("government_party", ""))
	var n := maxi(1, parties.size() - 1)
	for key in parties.keys():
		var party: Dictionary = parties[key]
		var support := float(party.get("support", 0.0))
		var structural := float(party.get("seats", 0)) / maxf(1.0, float(wc.get("chamber_seats", 1))) * 100.0
		var delta := swing if str(key) == gov_party else -swing / float(n)
		# Custo de governar: o partido do governo perde um pouco de apoio todo mês,
		# mesmo com boa conjuntura; a oposição se beneficia da normalização.
		if str(key) == gov_party:
			delta -= 0.02
		delta += (structural - support) * 0.010
		support = clampf(support + delta, 0.3, 75.0)
		var last := float(party.get("last_support", support))
		var stability := float(party.get("stability", 62.0))
		if support > last + 0.15:
			stability += 0.8
		elif support < last - 0.15:
			stability -= 1.0
		else:
			stability += (60.0 - stability) * 0.02
		party["support"] = support
		party["last_support"] = support
		party["stability"] = clampf(stability, 0.0, 100.0)
		parties[key] = party
	_normalize(parties)
	wc["parties"] = parties
	for key in parties.keys():
		var party: Dictionary = parties[key]
		if float(party.get("stability", 60.0)) < 32.0 and float(party.get("support", 0.0)) < 25.0:
			if _hash01(str(key) + "|" + str(year) + "|" + str(month)) < 0.05:
				party["stability"] = 45.0
				party["leader"] = "Liderança interina"
				party["leadership_since"] = "%d-%02d" % [year, month]
				parties[key] = party
				wc["parties"] = parties
				WorldHistory.bump(world, "leadership_changes")
				var name := str(wc.get("name", wc.get("id", "")))
				WorldHistory.push(world, {
					"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
					"category": "lideranca",
					"description": "%s troca a liderança após queda de estabilidade interna." % str(party.get("name", key)),
					"headline": "%s: %s muda de liderança (%d)" % [name, str(party.get("name", key)), year],
					"trigger": "estabilidade interna abaixo de 32 e apoio abaixo de 25%",
					"consequences": ["nova liderança interina assume o partido"],
					"actors": [str(key)],
					"status": "confirmado", "news": true,
				}, 12)
