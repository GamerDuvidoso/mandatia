extends RefCounted
## E1 — simulação autônoma do mundo.
##
## Um único ponto de entrada, chamado uma vez por mês no ciclo existente:
## `WorldSim.monthly(state, countries, economy)`.
##
## Ordem do mês por país (seção 7 do prompt de integração): mercado → banco
## central → mídia (enquadramento) → executivo → governo → economia → partidos
## → legislativo → mídia (consequência) → judiciário → política externa →
## calendário eleitoral. Cada ator novo usa contingência determinística quando a
## camada de IA está desligada.
##
## Fonte de verdade:
## - macro (PIB, crescimento, inflação, desemprego, dívida) fica em
##   `state.international_state.profiles`, reutilizada pela diplomacia;
## - política (governo, partidos, cadeiras, aprovação, calendário) fica em
##   `state.world`;
## - nenhum valor de catálogo (`value`) é sobrescrito: a simulação lê
##   `simulation_value` e grava apenas o estado simulado.
##
## Determinismo: nenhum RNG guardado. Variação mensal vem de hash estável do
## país + mês; a mesma entrada produz o mesmo mês. A simulação é idempotente por
## `last_tick`.

const VERSION := 1
const Election := preload("res://scripts/sim/election.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const International := preload("res://scripts/sim/international_system.gd")
const WorldHistory := preload("res://scripts/sim/world_history.gd")
const CountryEconomy := preload("res://scripts/sim/country_economy_simulation.gd")
const AutonomousGovernment := preload("res://scripts/sim/autonomous_government.gd")
const AutonomousParty := preload("res://scripts/sim/autonomous_party_system.gd")
const AutonomousLegislature := preload("res://scripts/sim/autonomous_legislature.gd")
const ForeignElection := preload("res://scripts/sim/foreign_election_system.gd")
## Fase 4: atores das ondas 2 e 3 (mercado, banco central, mídia, executivo e
## judiciário). Todos rodam sempre com a contingência do motor; a IA só troca a
## decisão, pelo override validado.
const MarketSystem := preload("res://scripts/sim/market_system.gd")
const CentralBankSystem := preload("res://scripts/sim/central_bank.gd")
const MediaSystem := preload("res://scripts/sim/media_system.gd")
const ExecutiveNPC := preload("res://scripts/sim/executive_npc.gd")
const JudiciarySystem := preload("res://scripts/sim/judiciary_system.gd")
## Fase 3: camada de decisão. Com o modo padrão "off" ela devolve {} e o mês
## sai exatamente como antes; o broker só age quando o modo é ligado.
const AiRuntime := preload("res://scripts/ai/ai_runtime.gd")

static var _default_runtime: Object = null

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _month_index(year: int, month: int) -> int:
	return year * 12 + month

static func ensure(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	var intl: Variant = st.get("international_state", {})
	if not (intl is Dictionary) or (intl as Dictionary).get("profiles", {}).is_empty():
		International.init_state(st, countries, economy)
	# Catálogo vazio/inválido não pode criar mundo sem perfis: sem esta guarda,
	# International.init_state voltaria ao ensure em recursão.
	intl = st.get("international_state", {})
	if not (intl is Dictionary) or (intl as Dictionary).get("profiles", {}).is_empty():
		return
	var world: Variant = st.get("world", {})
	if not (world is Dictionary) or int(world.get("version", 0)) != VERSION or (world.get("countries", {}) as Dictionary).is_empty():
		_init(st, countries, economy)
		return
	var known: Dictionary = world.countries
	for row in countries:
		var id := str(row.get("id", ""))
		if id == "" or id == str(st.get("country_id", "")):
			continue
		if not known.has(id):
			var built := _build_country(st, row, economy)
			if not built.is_empty():
				known[id] = built
	world["countries"] = known
	WorldHistory.ensure(world)
	st["world"] = world

static func _init(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	var world := {"version": VERSION, "countries": {}, "history": [], "news": [], "stats": {}, "last_tick": ""}
	for row in countries:
		var wc := _build_country(st, row, economy)
		if not wc.is_empty():
			world.countries[wc.id] = wc
	WorldHistory.ensure(world)
	st["world"] = world
	st["world_summary"] = summary(st)

static func _resolve_government_party(row: Dictionary, official: Array, system: String) -> String:
	var holder: Variant = row.get("head_of_government") if system == "parlamentar" else row.get("head_of_state")
	var label := ""
	if holder is Dictionary:
		label = str((holder as Dictionary).get("party", ""))
	var norm := label.to_lower().strip_edges()
	var largest := ""
	var largest_seats := -1
	for party in official:
		var abbr := str(party.get("abbr", "")).strip_edges()
		var pname := str(party.get("name", "")).strip_edges()
		var seats := int(party.get("lower_house_seats", 0)) if party.get("lower_house_seats", null) != null else 0
		if seats > largest_seats:
			largest_seats = seats
			largest = abbr
		if norm == "" or abbr == "":
			continue
		if norm == abbr.to_lower():
			return abbr
		if pname != "" and (norm.contains(pname.to_lower()) or pname.to_lower().contains(norm)):
			return abbr
		if norm.contains("(" + abbr.to_lower() + ")"):
			return abbr
	if largest == "" and not official.is_empty():
		largest = str(official[0].get("abbr", ""))
	return largest

static func _initial_months(row: Dictionary, system: String, term: int, st: Dictionary) -> int:
	var holder: Variant = row.get("head_of_government") if system == "parlamentar" else row.get("head_of_state")
	var since := ""
	if holder is Dictionary:
		since = str((holder as Dictionary).get("since", ""))
	var parts := since.split("-")
	if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var end_year := int(parts[0]) + int(term / 12)
		var months := (end_year - int(st.get("date_year", 2027))) * 12 + (int(parts[1]) - int(st.get("date_month", 1)))
		if months >= 1 and months <= term:
			return months
	var id := str(row.get("id", ""))
	return 1 + int(_hash01(id + "|calendar") * float(term - 1))

static func _build_country(st: Dictionary, row: Dictionary, economy: Dictionary) -> Dictionary:
	var id := str(row.get("id", ""))
	if id == "" or id == str(st.get("country_id", "")):
		return {}
	var chamber := Election.chamber_seats(row)
	var official: Array = row.get("official_parties", []) if row.get("official_parties") is Array else []
	if chamber <= 0 or official.is_empty():
		return {}
	var system := "parlamentar" if Election.is_parliamentary(row) else "presidencial"
	var term := 60 if system == "parlamentar" else 48
	var gov_party := _resolve_government_party(row, official, system)
	var parties := AutonomousParty.init_parties(official, gov_party)
	if parties.is_empty():
		return {}
	var chamber_seats := 0
	var seat_map := {}
	var axes := {}
	for key in parties.keys():
		var party: Dictionary = parties[key]
		chamber_seats += int(party.get("seats", 0))
		seat_map[key] = int(party.get("seats", 0))
		axes[key] = Election.ideology_axis(str(party.get("ideology", "")))
	if seat_map.is_empty():
		return {}
	var majority := int(chamber / 2) + 1
	var partners: Array = []
	var coalition_seats := int(seat_map.get(gov_party, 0))
	var cohesion := 62.0
	if system == "parlamentar" and coalition_seats < majority:
		var deal := Coalition.minimum_winning(seat_map, axes, gov_party, majority)
		if not deal.is_empty():
			partners = deal.get("partners", [])
			coalition_seats = int(deal.get("seats", coalition_seats))
			cohesion = float(deal.get("cohesion", 55.0))
		else:
			cohesion = 40.0
	for key in partners:
		if parties.has(str(key)):
			parties[str(key)]["in_coalition"] = true
	var profile: Dictionary = st.get("international_state", {}).get("profiles", {}).get(id, {})
	if profile.is_empty():
		return {}
	var base := CountryEconomy.base_from(economy.get(id, {}) if economy.get(id, {}) is Dictionary else {})
	var inflation := float(profile.get("inflation", 4.5))
	var unemployment := float(profile.get("unemployment", 7.0))
	var growth := float(profile.get("growth", 2.0))
	var approval := clampf(50.0 - maxf(0.0, inflation - 4.5) * 1.1 - maxf(0.0, unemployment - 7.0) * 0.8 + growth * 1.5 + (_hash01(id + "|approval") - 0.5) * 8.0, 24.0, 72.0)
	var stability := clampf(58.0 + (approval - 50.0) * 0.3 - maxf(0.0, inflation - 6.0) * 1.0, 20.0, 92.0)
	var gov_axis := float(axes.get(gov_party, 0.0))
	profile["approval"] = approval
	profile["stability"] = stability
	profile["government_party"] = gov_party
	profile["government"] = str(parties.get(gov_party, {}).get("name", gov_party))
	profile["orientation"] = str(parties.get(gov_party, {}).get("ideology", ""))
	profile["system"] = system
	profile["policy_priority"] = "investimento"
	return {
		"id": id, "name": str(row.get("name", id)), "region": str(row.get("region", "não informado")),
		"system": system, "term_months": term,
		"chamber_seats": chamber, "chamber_total": chamber_seats,
		"parties": parties, "government_party": gov_party, "government_axis": gov_axis,
		"coalition_partners": partners, "coalition_seats": coalition_seats, "coalition_cohesion": cohesion,
		"approval": approval, "stability": stability,
		"months_to_election": _initial_months(row, system, term, st),
		"economy_base": base, "policy_priority": "investimento", "last_priority": "",
		"last_vote": {}, "last_election": {}, "turn": 0, "consecutive_terms": 1,
		"trade_links": 0, "last_agreement_month": -999, "strategic_partner": "",
	}

static func _foreign_policy(world: Dictionary, st: Dictionary, wc: Dictionary, profile: Dictionary, year: int, month: int) -> void:
	var tick := "%d-%02d" % [year, month]
	var stamp := _month_index(year, month)
	if _hash01(str(wc.get("id", "")) + "|fp|" + tick) > 0.06:
		return
	if stamp - int(wc.get("last_agreement_month", -999)) < 6:
		return
	var peers := []
	for other in (world.get("countries", {}) as Dictionary).keys():
		if str(other) == str(wc.get("id", "")):
			continue
		var row: Dictionary = world.countries[other]
		if str(row.get("region", "")) == str(wc.get("region", "")):
			peers.append(str(other))
	if peers.is_empty():
		return
	peers.sort()
	var peer_id := str(peers[int(_hash01(str(wc.get("id", "")) + "|peer|" + tick) * peers.size()) % peers.size()])
	if not (world.countries as Dictionary).has(peer_id):
		return
	var peer: Dictionary = world.countries[peer_id]
	var peer_profile: Dictionary = st.get("international_state", {}).get("profiles", {}).get(peer_id, {})
	if peer_profile.is_empty():
		return
	WorldHistory.bump(world, "agreements")
	var action_roll := _hash01(str(wc.get("id", "")) + "|fpa|" + tick)
	var action := "comercial"
	var debt := float(profile.get("debt", 60.0))
	var growth := float(profile.get("growth", 2.0))
	# Financiamento de desenvolvimento quando a dívida aperta e o crescimento trava.
	if debt >= 80.0 and growth < 2.0:
		action = "financiamento"
	# Parceria estratégica depois de repetidos acordos comerciais.
	elif int(wc.get("trade_links", 0)) >= 3 and action_roll < 0.40:
		action = "parceria"
	wc["trade_links"] = int(wc.get("trade_links", 0)) + 1
	wc["last_agreement_month"] = stamp
	peer["trade_links"] = int(peer.get("trade_links", 0)) + 1
	world.countries[peer_id] = peer
	var a := str(wc.get("name", wc.get("id", "")))
	var b := str(peer.get("name", peer_id))
	var description := ""
	var headline := ""
	var consequences: Array = []
	if action == "financiamento":
		profile["debt"] = clampf(debt - 0.6, 0.0, 200.0)
		profile["growth"] = clampf(growth + 0.06, -8.0, 10.0)
		peer_profile["growth"] = clampf(float(peer_profile.get("growth", 2.0)) + 0.02, -8.0, 10.0)
		description = "%s obtém financiamento de desenvolvimento de %s." % [a, b]
		headline = "%s obtém financiamento de desenvolvimento (%d)" % [a, year]
		consequences = ["dívida -0,6 p.p.", "crescimento +0,06 p.p.", "credor regional ganha influência"]
	elif action == "parceria":
		profile["growth"] = clampf(growth + 0.05, -8.0, 10.0)
		peer_profile["growth"] = clampf(float(peer_profile.get("growth", 2.0)) + 0.05, -8.0, 10.0)
		wc["strategic_partner"] = peer_id
		description = "%s e %s elevam o acordo comercial a parceria estratégica." % [a, b]
		headline = "%s e %s firmam parceria estratégica (%d)" % [a, b, year]
		consequences = ["coordenação econômica", "crescimento +0,05 p.p. no mês para ambos"]
	else:
		profile["growth"] = clampf(growth + 0.03, -8.0, 10.0)
		peer_profile["growth"] = clampf(float(peer_profile.get("growth", 2.0)) + 0.03, -8.0, 10.0)
		description = "%s e %s firmam acordo comercial e de investimento." % [a, b]
		headline = "%s e %s ampliam acordo comercial (%d)" % [a, b, year]
		consequences = ["intercâmbio comercial maior", "crescimento +0,03 p.p. no mês para ambos"]
	WorldHistory.push(world, {
		"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": a,
		"category": "diplomacia",
		"description": description,
		"headline": headline,
		"trigger": "interesse econômico regional e prioridade do governo",
		"consequences": consequences,
		"actors": [str(wc.get("government_party", "")), str(peer.get("government_party", ""))],
		"status": "confirmado", "news": _hash01(str(wc.get("id", "")) + "|fpn|" + tick) < 0.6,
	}, 12)

## Runtime usado quando o chamador não passa um (jogo e testes antigos).
## Criado uma vez por processo e lido do `config/ai_config.json`.
static func _resolve_runtime(runtime: Object) -> Object:
	if runtime != null:
		return runtime
	if _default_runtime == null:
		_default_runtime = AiRuntime.new()
	return _default_runtime

## Publica no `causal_log` do mundo o fato que o módulo do ator marcou como
## notável. Módulos não conhecem o histórico; quem escreve é este ponto.
static func _push_module_event(world: Dictionary, wc: Dictionary, country: String, row: Dictionary, year: int, month: int) -> void:
	var raw: Variant = row.get("event", {})
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return
	var event: Dictionary = (raw as Dictionary).duplicate(true)
	event["year"] = year
	event["month"] = month
	event["country"] = country
	event["country_name"] = str(wc.get("name", country))
	if not (event.get("actors", []) is Array) or (event.get("actors", []) as Array).is_empty():
		event["actors"] = [str(wc.get("government_party", ""))]
	WorldHistory.push(world, event, 6)

static func monthly(st: Dictionary, countries: Array, economy: Dictionary, runtime: Object = null) -> Dictionary:
	ensure(st, countries, economy)
	var world: Dictionary = st["world"]
	var year := int(st.get("date_year", 2027))
	var month := int(st.get("date_month", 1))
	var tick := "%d-%02d" % [year, month]
	if str(world.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}
	var intl: Dictionary = st.get("international_state", {})
	var profiles: Dictionary = intl.get("profiles", {})
	var events_before := (world.get("history", []) as Array).size()
	var ai := _resolve_runtime(runtime)
	for id in (world.get("countries", {}) as Dictionary).keys():
		var wc: Dictionary = world.countries[id]
		var country := str(id)
		var profile: Variant = profiles.get(country, {})
		if not (profile is Dictionary) or (profile as Dictionary).is_empty():
			continue
		var typed_profile: Dictionary = profile
		var base: Dictionary = wc.get("economy_base", {})
		# Choque externo determinístico de ±0,6 p.p. anualizado: cria trajetórias
		# distintas sem RNG guardado e sem dominar a âncora de cada país.
		var shock := (_hash01(country + "|" + tick) * 2.0 - 1.0) * 0.6
		# 2. mercado e banco central (A6, A7): o custo de capital e a taxa do mês
		# entram no macro antes de qualquer decisão política.
		var market_decision: Dictionary = {}
		var bank_decision: Dictionary = {}
		var media_decision: Dictionary = {}
		var executive_decision: Dictionary = {}
		var court_decision: Dictionary = {}
		if ai != null and ai.has_method("decide_actor"):
			market_decision = ai.decide_actor("market_mood", "market:" + country, st, wc, typed_profile, base, year, month)
			bank_decision = ai.decide_actor("central_bank", "central_bank:" + country, st, wc, typed_profile, base, year, month)
			media_decision = ai.decide_actor("media_coverage", "media:" + country, st, wc, typed_profile, base, year, month)
			executive_decision = ai.decide_actor("executive_action", "exec:" + country, st, wc, typed_profile, base, year, month)
		_push_module_event(world, wc, country, MarketSystem.monthly(st, wc, typed_profile, base, year, month, market_decision), year, month)
		_push_module_event(world, wc, country, CentralBankSystem.monthly(st, wc, typed_profile, base, year, month, bank_decision), year, month)
		# 3. povo e mídia (A8, A9): a mídia fixa o enquadramento do mês aqui; a
		# consequência sobre aprovação fecha depois do bloco político.
		_push_module_event(world, wc, country, MediaSystem.monthly(st, wc, typed_profile, base, year, month, media_decision), year, month)
		# 4. executivo (A2) e governo (A1).
		_push_module_event(world, wc, country, ExecutiveNPC.monthly(st, wc, typed_profile, base, year, month, executive_decision), year, month)
		# A prioridade passa pela camada de decisão: em modo "off" ela devolve {}
		# e a regra do motor decide, como antes do fio.
		var ai_priority: Dictionary = {}
		if ai != null:
			ai_priority = ai.decide_gov_priority(st, wc, typed_profile, base, year, month)
		var government := AutonomousGovernment.monthly(world, wc, typed_profile, base, year, month, ai_priority)
		var priority := str(government.get("priority", wc.get("policy_priority", "investimento")))
		CountryEconomy.monthly(typed_profile, base, priority, shock)
		# 5. partidos (A3) e câmara (A4).
		AutonomousParty.monthly(world, wc, typed_profile, base, year, month)
		AutonomousLegislature.monthly(world, wc, typed_profile, base, year, month)
		MediaSystem.close_month(st, wc)
		# 6. judiciário (A5): julga o caso aberto do mês, só com efeito
		# procedimental — nunca votos ou cadeiras.
		if ai != null and ai.has_method("decide_actor"):
			court_decision = ai.decide_actor("court_ruling", "court:" + country, st, wc, typed_profile, base, year, month)
		_push_module_event(world, wc, country, JudiciarySystem.monthly(st, wc, typed_profile, base, year, month, court_decision), year, month)
		# 7. diplomacia e calendário eleitoral.
		_foreign_policy(world, st, wc, typed_profile, year, month)
		wc["months_to_election"] = int(wc.get("months_to_election", 1)) - 1
		if int(wc.months_to_election) <= 0:
			ForeignElection.run(world, st, wc, typed_profile, year, month)
		wc["turn"] = int(wc.get("turn", 0)) + 1
		typed_profile["approval"] = wc.get("approval", 50.0)
		typed_profile["stability"] = wc.get("stability", 60.0)
		typed_profile["policy_priority"] = str(wc.get("policy_priority", ""))
		world.countries[id] = wc
	world["last_tick"] = tick
	st["world"] = world
	st["world_summary"] = summary(st)
	return {
		"tick": tick,
		"countries": (world.get("countries", {}) as Dictionary).size(),
		"events": (world.get("history", []) as Array).size() - events_before,
	}

static func summary(st: Dictionary) -> Dictionary:
	var world: Variant = st.get("world", {})
	if not (world is Dictionary):
		return {}
	var countries: Dictionary = (world as Dictionary).get("countries", {})
	var count := 0
	var growth_sum := 0.0
	var approval_sum := 0.0
	var stability_sum := 0.0
	var next_election := 999
	for id in countries.keys():
		var wc: Dictionary = countries[id]
		count += 1
		var profile: Dictionary = st.get("international_state", {}).get("profiles", {}).get(id, {})
		growth_sum += float(profile.get("growth", 0.0))
		approval_sum += float(wc.get("approval", 50.0))
		stability_sum += float(wc.get("stability", 60.0))
		next_election = mini(next_election, int(wc.get("months_to_election", 999)))
	var history: Array = (world as Dictionary).get("history", [])
	var recent: Array = history.slice(0, 8)
	return {
		"countries": count,
		"avg_growth": growth_sum / maxf(1.0, float(count)),
		"avg_approval": approval_sum / maxf(1.0, float(count)),
		"avg_stability": stability_sum / maxf(1.0, float(count)),
		"next_election_months": 0 if next_election == 999 else next_election,
		"elections_12m": WorldHistory.count_since(world, "eleicao", int(st.get("date_year", 0)), int(st.get("date_month", 1)), 12),
		"stats": (world as Dictionary).get("stats", {}),
		"news": WorldHistory.news(world, 6),
		"recent": recent,
	}

static func country_view(st: Dictionary, id: String) -> Dictionary:
	var world: Variant = st.get("world", {})
	if not (world is Dictionary):
		return {}
	var wc: Dictionary = (world as Dictionary).get("countries", {}).get(id, {})
	if wc.is_empty():
		return {}
	var view := wc.duplicate(true)
	view["profile"] = st.get("international_state", {}).get("profiles", {}).get(id, {}).duplicate(true)
	view["history"] = WorldHistory.country_history(world, id, 10)
	view["relation"] = International.profile(st, id).get("relation", {})
	return view
