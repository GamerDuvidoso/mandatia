extends RefCounted
## E1 — eleições e formação de governo em outros países.
##
## Premissas:
## - A votação parte do apoio corrente dos partidos (autonomous_party_system) e
##   da fotografia de cadeiras do catálogo. O partido do governo recebe o ônus ou
##   o bônus de aprovação, crescimento, inflação e desemprego.
## - A alocação de cadeiras usa D'Hondt sobre a votação nacional porque o
##   catálogo não traz votos por distrito. É uma simplificação documentada.
## - Presidencialismo: dois turnos entre os partidos, com transferência por
##   distância ideológica (reutiliza Election.presidential_2d). O vencedor forma
##   o Executivo; não precisa de coalizão para tomar posse.
## - Parlamentarismo: o maior partido tenta a menor coalizão vencedora
##   (Coalition.minimum_winning); sem coalizão, governa em minoria.
## - O novo governo herda PIB, inflação, desemprego, dívida e serviços: a
##   eleição troca a política, não reseta a economia.

const Election := preload("res://scripts/sim/election.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const WorldHistory := preload("res://scripts/sim/world_history.gd")

static func _hash_int(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return h

static func _hash01(text: String) -> float:
	return float(_hash_int(text) % 10000) / 10000.0

static func _shares(wc: Dictionary, profile: Dictionary, year: int, month: int) -> Dictionary:
	var parties: Dictionary = wc.get("parties", {})
	var chamber := maxi(1, int(wc.get("chamber_seats", 1)))
	var stamp := "%d-%02d" % [year, month]
	var growth := float(profile.get("growth", 2.0))
	var inflation := float(profile.get("inflation", 4.5))
	var unemployment := float(profile.get("unemployment", 7.0))
	var approval := float(wc.get("approval", 50.0))
	var gov_party := str(wc.get("government_party", ""))
	var shares := {}
	var total := 0.0
	for key in parties.keys():
		var party: Dictionary = parties[key]
		var seat_share := float(party.get("seats", 0)) / float(chamber) * 100.0
		var base := float(party.get("support", 0.0)) * 0.70 + seat_share * 0.30
		if str(key) == gov_party:
			base += (approval - 50.0) * 0.30 + (growth - 2.0) * 0.50 - maxf(0.0, inflation - 5.0) * 0.35 - maxf(0.0, unemployment - 7.0) * 0.40
			# Desgaste de incumbência: cada mandato consecutivo corrói a votação.
			# Premissa documentada, não regra eleitoral do país.
			base -= maxf(0.0, float(int(wc.get("consecutive_terms", 1)) - 1)) * 2.2
		base += (_hash01(str(wc.get("id", "")) + "|" + str(key) + "|" + stamp) - 0.5) * 4.0
		base = maxf(0.4, base)
		shares[key] = base
		total += base
	if total <= 0.0:
		return {}
	for key in shares.keys():
		shares[key] = float(shares[key]) / total * 100.0
	return shares

static func _axes(parties: Dictionary) -> Dictionary:
	var axes := {}
	for key in parties.keys():
		axes[key] = Election.ideology_axis(str(parties[key].get("ideology", "")))
	return axes

static func run(world: Dictionary, st: Dictionary, wc: Dictionary, profile: Dictionary, year: int, month: int) -> Dictionary:
	var chamber := int(wc.get("chamber_seats", 0))
	var parties: Dictionary = wc.get("parties", {})
	if chamber <= 0 or parties.is_empty():
		wc["months_to_election"] = int(wc.get("term_months", 48))
		return {"ok": false, "reason": "dados insuficientes"}
	var shares := _shares(wc, profile, year, month)
	if shares.is_empty():
		wc["months_to_election"] = int(wc.get("term_months", 48))
		return {"ok": false, "reason": "votação inválida"}
	var axes := _axes(parties)
	var seat_map := Election.allocate_dhondt(shares, chamber)
	var old_gov := str(wc.get("government_party", ""))
	var old_approval := float(wc.get("approval", 50.0))
	var winner := ""
	var partners: Array = []
	var coalition_seats := 0
	var cohesion := 60.0
	var second_round := false
	if str(wc.get("system", "presidencial")) == "parlamentar":
		winner = Election.largest_party(seat_map)
		var majority := int(chamber / 2) + 1
		coalition_seats = int(seat_map.get(winner, 0))
		if coalition_seats < majority:
			var deal := Coalition.minimum_winning(seat_map, axes, winner, majority)
			if not deal.is_empty():
				partners = deal.get("partners", [])
				coalition_seats = int(deal.get("seats", coalition_seats))
				cohesion = float(deal.get("cohesion", 55.0))
			else:
				cohesion = 38.0
		else:
			cohesion = 74.0
	else:
		var positions := {}
		for key in parties.keys():
			positions[key] = Vector2(float(axes.get(key, 0.0)), 0.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _hash_int(str(wc.get("id", "")) + "|pres|" + "%d-%02d" % [year, month])
		var race := Election.presidential_2d(shares, positions, rng)
		winner = str(race.get("winner", ""))
		second_round = bool(race.get("second_round", false))
		partners = []
		coalition_seats = int(seat_map.get(winner, 0))
		cohesion = 60.0
	if winner == "":
		wc["months_to_election"] = int(wc.get("term_months", 48))
		return {"ok": false, "reason": "sem vencedor"}
	for key in parties.keys():
		var party: Dictionary = parties[key]
		party["seats"] = int(seat_map.get(key, 0))
		party["in_gov"] = str(key) == winner
		party["in_coalition"] = str(key) == winner or (partners as Array).has(str(key))
		party["support"] = float(shares.get(key, party.get("support", 0.0)))
		party["last_support"] = party.support
		parties[key] = party
	wc["parties"] = parties
	wc["government_party"] = winner
	wc["government_axis"] = float(axes.get(winner, 0.0))
	wc["coalition_partners"] = partners
	wc["coalition_seats"] = coalition_seats
	wc["coalition_cohesion"] = cohesion
	wc["stability"] = clampf(52.0 + cohesion * 0.25 - maxf(0.0, float(profile.get("inflation", 4.5)) - 6.0) * 1.2, 25.0, 92.0)
	var changed := winner != old_gov
	var honeymoon := 46.0 + _hash01(str(wc.get("id", "")) + "|" + winner + "|" + "%d-%02d" % [year, month]) * 12.0
	wc["approval"] = honeymoon if changed else clampf(old_approval + 2.0, 5.0, 85.0)
	wc["months_to_election"] = int(wc.get("term_months", 48))
	wc["consecutive_terms"] = 1 if changed else int(wc.get("consecutive_terms", 1)) + 1
	WorldHistory.bump(world, "elections")
	if changed:
		WorldHistory.bump(world, "government_changes")
	wc["last_election"] = {
		"year": year, "month": month, "shares": shares, "seats": seat_map,
		"winner": winner, "coalition_seats": coalition_seats, "partners": partners,
		"second_round": second_round, "changed_government": changed,
	}
	profile["government_party"] = winner
	profile["government"] = str(parties.get(winner, {}).get("name", winner))
	profile["orientation"] = str(parties.get(winner, {}).get("ideology", ""))
	profile["approval"] = wc.approval
	profile["stability"] = wc.stability
	var name := str(wc.get("name", wc.get("id", "")))
	var winner_name := str(parties.get(winner, {}).get("name", winner))
	var seat_line := "%d de %d cadeiras" % [int(seat_map.get(winner, 0)), chamber]
	var govs := "presidencial" if str(wc.get("system", "")) == "presidencial" else "parlamentar"
	WorldHistory.push(world, {
		"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
		"category": "eleicao",
		"description": "Eleição %s em %s: %s vence com %s%s." % [govs, name, winner_name, seat_line, " em dois turnos" if second_round else ""],
		"headline": "%s: %s vence a eleição de %d" % [name, winner_name, year],
		"trigger": "fim do mandato; votação calculada por apoio, aprovação e economia",
		"consequences": ["novo mandato de %d meses" % int(wc.get("term_months", 48))],
		"actors": [winner, old_gov], "status": "oficial", "news": true,
	}, 1)
	if changed:
		WorldHistory.push(world, {
			"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
			"category": "governo",
			"description": "%s passa do governo de %s para %s." % [name, old_gov, winner_name],
			"headline": "%s troca de governo: %s assume em %d" % [name, winner_name, year],
			"trigger": "resultado eleitoral",
			"consequences": ["nova orientação ideológica %.2f" % float(wc.get("government_axis", 0.0)), "política externa reavaliada"],
			"actors": [old_gov, winner], "status": "oficial", "news": true,
		}, 1)
		_shift_player_relation(st, wc, float(wc.get("government_axis", 0.0)))
	if not partners.is_empty():
		WorldHistory.push(world, {
			"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
			"category": "coalizao",
			"description": "%s forma coalizão com %s (%d de %d cadeiras)." % [winner, ", ".join(PackedStringArray(partners)), coalition_seats, chamber],
			"headline": "%s: coalizão de %s fecha %d cadeiras (%d)" % [name, winner, coalition_seats, year],
			"trigger": "maior partido sem maioria absoluta",
			"consequences": ["base de governo com coesão %.0f%%" % cohesion],
			"actors": [winner] + partners, "status": "confirmado", "news": true,
		}, 1)
	return {"ok": true, "winner": winner, "changed": changed, "seats": seat_map, "partners": partners}

## Uma troca de governo move a relação com o jogador conforme a distância
## ideológica, mas de forma limitada: compromissos e dependência continuam
## pesando nos meses seguintes (International.monthly).
static func _shift_player_relation(st: Dictionary, wc: Dictionary, new_axis: float) -> void:
	var intl: Variant = st.get("international_state", {})
	if not (intl is Dictionary):
		return
	var player := str(st.get("country_id", "BR"))
	var key := "%s:%s" % [player, str(wc.get("id", ""))]
	var relations: Dictionary = (intl as Dictionary).get("relations", {})
	if not relations.has(key):
		return
	var rel: Dictionary = relations[key]
	var player_axis := Election.ideology_axis(str(st.get("ideology", "")))
	var distance := absf(player_axis - new_axis)
	var delta := 3.0 if distance <= 0.35 else (-3.0 if distance >= 0.9 else 0.0)
	rel["cooperation"] = clampf(float(rel.get("cooperation", 40.0)) + delta, 0.0, 100.0)
	rel["political_alignment"] = clampf(float(rel.get("political_alignment", 38.0)) + delta, 0.0, 100.0)
	rel["tension"] = clampf(float(rel.get("tension", 10.0)) + maxf(0.0, -delta) * 0.5, 0.0, 100.0)
	rel["last_action"] = "troca de governo"
	relations[key] = rel
	(intl as Dictionary)["relations"] = relations
