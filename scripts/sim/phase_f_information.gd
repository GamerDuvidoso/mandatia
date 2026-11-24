extends RefCounted
## Fase F — camada derivada de informação política.
##
## Este módulo não simula uma segunda política. Ele indexa fatos já produzidos por
## `state`, `world.history`, `causal_log` e `scandals`, gerando apresentação,
## estimativas e análises explicitamente rotuladas.

const VERSION := 1
const MAX_ARTICLES := 180
const MAX_ARCHIVE := 600
const MAX_POLLS := 120
const MAX_REPORTS := 60
const CausalLog := preload("res://scripts/sim/causal_log.gd")

const OUTLETS := [
	{"id": "agencia_publica", "name": "Agência Cívica", "kind": "pública", "line": "institucional", "independence": 0.72},
	{"id": "diario_nacional", "name": "Diário Nacional", "kind": "privado", "line": "governista", "independence": 0.48},
	{"id": "observador", "name": "O Observador", "kind": "privado", "line": "fiscalizador", "independence": 0.78},
	{"id": "economia_em_foco", "name": "Economia em Foco", "kind": "especializado", "line": "mercado", "independence": 0.66},
]

static func ensure(st: Dictionary) -> void:
	var info: Variant = st.get("phase_f", {})
	if not (info is Dictionary):
		info = {}
	var data: Dictionary = info
	data["version"] = VERSION
	if not (data.get("articles") is Array): data["articles"] = []
	if not (data.get("archive") is Array): data["archive"] = []
	if not (data.get("polls") is Array): data["polls"] = []
	if not (data.get("reports") is Array): data["reports"] = []
	if not (data.get("biographies") is Dictionary): data["biographies"] = {}
	if not (data.get("encyclopedia") is Dictionary): data["encyclopedia"] = {}
	if not (data.get("last_tick", "") is String): data["last_tick"] = ""
	st["phase_f"] = data

static func outlets() -> Array:
	return OUTLETS.duplicate(true)

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]

static func _bounded_append(rows: Array, item: Dictionary, limit: int) -> void:
	rows.push_front(item)
	if rows.size() > limit: rows.resize(limit)

static func _article_id(source_id: String, outlet_id: String) -> String:
	return source_id + "@" + outlet_id

static func _frame(event: Dictionary, outlet: Dictionary) -> String:
	var category := str(event.get("category", "política"))
	var line := str(outlet.get("line", "institucional"))
	if line == "mercado" and category == "economia": return "ênfase em custos, riscos e indicadores"
	if line == "governista": return "ênfase em anúncio, execução e resposta do governo"
	if line == "fiscalizador": return "ênfase em cobrança, evidência e consequências"
	return "ênfase em procedimento, fontes e contexto institucional"

static func _make_article(event: Dictionary, outlet: Dictionary) -> Dictionary:
	var source_id := str(event.get("id", ""))
	var title := str(event.get("headline", event.get("description", "Fato registrado")))
	var certainty := str(event.get("certainty", event.get("status", "confirmado")))
	return {
		"id": _article_id(source_id, str(outlet.get("id", ""))),
		"source_type": "simulation_event",
		"source_id": source_id,
		"date": str(event.get("date", "")),
		"country": str(event.get("country", "")),
		"category": str(event.get("category", "")),
		"outlet_id": str(outlet.get("id", "")),
		"outlet_name": str(outlet.get("name", "")),
		"headline": title,
		"factual_basis": str(event.get("description", title)),
		"certainty": certainty,
		"status": certainty,
		"frame": _frame(event, outlet),
		"actors": event.get("actors", []),
		"consequences": event.get("consequences", []),
		"related_indicators": event.get("related_indicators", []),
		"causal_evidence": event.get("causal_evidence", []),
	}

static func _editorial_event(st: Dictionary, event: Dictionary) -> Dictionary:
	var enriched := event.duplicate(true)
	var evidence: Array = []
	var event_date := str(event.get("date", _stamp(st)))
	var category := str(event.get("category", ""))
	var title := str(event.get("headline", event.get("description", ""))).to_lower()
	var search_title := title.split(" · ")[0]
	for entry in CausalLog.recent(st, "", 40):
		if not (entry is Dictionary) or str(entry.get("month", "")) != event_date:
			continue
		var domain := str(entry.get("domain", ""))
		var cause := str(entry.get("cause", ""))
		var explanation := str(entry.get("explanation", ""))
		var relevant := false
		if category in ["escandalo", "investigacao"]:
			relevant = domain == "escandalo" and (search_title == "" or cause.to_lower().contains(search_title) or explanation.to_lower().contains(search_title))
		else:
			relevant = cause.to_lower().contains(title) or explanation.to_lower().contains(title)
		if relevant:
			evidence.append({"month": str(entry.get("month", "")), "domain": domain, "cause": cause, "effects": entry.get("effects", {}), "explanation": explanation})
			if evidence.size() >= 3:
				break
	if not evidence.is_empty():
		enriched["causal_evidence"] = evidence
	return enriched

static func _ingest_event(data: Dictionary, event: Dictionary) -> void:
	var source_id := str(event.get("id", ""))
	if source_id == "": return
	var articles: Array = data.get("articles", [])
	for outlet in OUTLETS:
		var article := _make_article(event, outlet)
		var exists := false
		for old in articles:
			if str(old.get("id", "")) == str(article.get("id", "")):
				if old.get("causal_evidence", []) is Array and (old.get("causal_evidence", []) as Array).is_empty() and not (article.get("causal_evidence", []) as Array).is_empty():
					old["causal_evidence"] = article.get("causal_evidence", [])
				exists = true
				break
		if not exists: _bounded_append(articles, article, MAX_ARTICLES)
	var archive: Array = data.get("archive", [])
	var archived := false
	for old in archive:
		if str(old.get("source_id", "")) == source_id:
			if old.get("causal_evidence", []) is Array and (old.get("causal_evidence", []) as Array).is_empty() and not (event.get("causal_evidence", []) as Array).is_empty():
				old["causal_evidence"] = event.get("causal_evidence", [])
			archived = true
			break
	if not archived:
		var record := event.duplicate(true)
		record["source_type"] = "simulation_event"
		record["source_id"] = source_id
		_bounded_append(archive, record, MAX_ARCHIVE)
	data["articles"] = articles
	data["archive"] = archive

static func _world_events(st: Dictionary) -> Array:
	var world: Variant = st.get("world", {})
	if world is Dictionary and world.get("history") is Array:
		return world.get("history", [])
	return []

static func _state_event(st: Dictionary) -> Dictionary:
	var headline := str(st.get("event", ""))
	if headline == "": return {}
	var stamp := _stamp(st)
	return {
		"id": "local:%s:%s" % [stamp, str(st.get("event_id", "conjuntura"))],
		"date": stamp, "year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1)),
		"country": str(st.get("country_id", "")), "category": "politica", "description": headline,
		"headline": headline, "status": "confirmado", "certainty": "confirmado",
		"actors": [str(st.get("party", ""))], "consequences": st.get("month_factors", []),
	}

static func _scandal_status(stage: String, legal: String) -> String:
	if legal == "confirmed": return "confirmado"
	if legal == "acquitted": return "absolvido"
	if legal == "unresolved": return "sem_desfecho"
	if stage == "investigacao": return "investigacao"
	if stage == "alegacao": return "alegacao"
	return "em_apuracao"

static func _scandal_events(st: Dictionary) -> Array:
	var events: Array = []
	var seen_cases: Dictionary = {}
	var cases: Array = []
	for source_key in ["scandals", "scandal_history"]:
		var source: Variant = st.get(source_key, [])
		if not (source is Array):
			continue
		for raw_case in source:
			if not (raw_case is Dictionary):
				continue
			var case: Dictionary = raw_case
			var case_id := str(case.get("id", ""))
			if case_id == "" or seen_cases.has(case_id):
				continue
			seen_cases[case_id] = true
			cases.append(case)
	for case in cases:
		var history: Variant = case.get("history", [])
		if not (history is Array):
			continue
		for raw_step in history:
			if not (raw_step is Dictionary):
				continue
			var step: Dictionary = raw_step
			var stage := str(step.get("stage", case.get("stage", "alegacao")))
			var month := str(step.get("month", case.get("opened", "")))
			var note := str(step.get("note", ""))
			var legal := str(case.get("legal", "unproven"))
			var status := _scandal_status(stage, legal)
			var label := stage
			if stage == "alegacao": label = "Alegação pública"
			elif stage == "midia": label = "Cobertura midiática"
			elif stage == "reacao": label = "Reação pública"
			elif stage == "investigacao": label = "Investigação formal"
			elif stage == "consequencias": label = "Fase de consequências"
			elif stage == "resolucao": label = "Resolução"
			var indicator_list: Array = ["cobertura midiática", "aprovação"]
			if stage == "investigacao": indicator_list.append("evidência; status jurídico não concluído")
			if legal in ["confirmed", "acquitted", "unresolved"]: indicator_list.append("desfecho jurídico")
			events.append({
				"id": "scandal:%s:%s:%s" % [str(case.get("id", "caso")), month, stage],
				"date": month,
				"country": str(st.get("country_id", "")),
				"category": "investigacao" if stage == "investigacao" else "escandalo",
				"headline": "%s · %s" % [str(case.get("title", "Caso político")), label],
				"description": note if note != "" else "Etapa registrada no histórico do caso.",
				"status": status,
				"certainty": status,
				"actors": [str(case.get("actor", ""))],
				"consequences": [note] if note != "" else [],
				"related_indicators": indicator_list,
				"source_type": "scandal_case",
				"source_case_id": str(case.get("id", "")),
			})
	return events

static func _refresh_biography(data: Dictionary, st: Dictionary) -> void:
	var biographies: Dictionary = data.get("biographies", {})
	var leader_id := "leader:" + str(st.get("leader", ""))
	var leader: Dictionary = biographies.get(leader_id, {}) if biographies.get(leader_id) is Dictionary else {}
	var leader_career: Array = leader.get("career", []) if leader.get("career") is Array else []
	var leader_date := str(leader_career[0].get("date", "")) if not leader_career.is_empty() and leader_career[0] is Dictionary else ""
	if leader_career.is_empty() or leader_date != _stamp(st):
		leader_career.push_front({"date": _stamp(st), "event": "posição atual registrada na simulação"})
	biographies[leader_id] = {"id": leader_id, "name": str(st.get("leader", "")), "kind": "simulação", "party": str(st.get("party", "")), "country": str(st.get("country_id", "")), "current_role": "governo" if bool(st.get("government", false)) else "oposição", "career": leader_career.slice(0, 48), "source": "state"}
	var ministers: Variant = st.get("ministers", [])
	var current_ministers: Dictionary = {}
	if ministers is Array:
		for minister in ministers:
			var name := str(minister.get("name", minister.get("id", ""))) if minister is Dictionary else str(minister)
			if name == "": continue
			current_ministers[name] = true
	for bio_id in biographies.keys():
		if not str(bio_id).begins_with("minister:"):
			continue
		var former: Dictionary = biographies[bio_id] if biographies[bio_id] is Dictionary else {}
		var former_name := str(former.get("name", ""))
		if former_name == "" or current_ministers.has(former_name) or str(former.get("current_role", "")).begins_with("ex-"):
			continue
		var former_career: Array = former.get("career", []) if former.get("career") is Array else []
		former_career.push_front({"date": _stamp(st), "event": "demissão ou saída do gabinete registrada na simulação"})
		former["current_role"] = "ex-ministro"
		former["career"] = former_career.slice(0, 48)
		biographies[bio_id] = former
	if ministers is Array:
		for minister in ministers:
			var minister_name := str(minister.get("name", minister.get("id", ""))) if minister is Dictionary else str(minister)
			if minister_name == "": continue
			var id := "minister:" + minister_name
			var old: Dictionary = biographies.get(id, {}) if biographies.get(id) is Dictionary else {}
			var career: Array = old.get("career", []) if old.get("career") is Array else []
			var career_date := str(career[0].get("date", "")) if not career.is_empty() and career[0] is Dictionary else ""
			if old.is_empty(): career.push_front({"date": _stamp(st), "event": "nomeação registrada na simulação"})
			elif str(old.get("current_role", "")) == "ex-ministro": career.push_front({"date": _stamp(st), "event": "retorno ao gabinete registrado na simulação"})
			elif career.is_empty() or career_date != _stamp(st): career.push_front({"date": _stamp(st), "event": "posição ministerial registrada na simulação"})
			var role := str(minister.get("portfolio", minister.get("role", "ministro"))) if minister is Dictionary else "ministro"
			biographies[id] = {"id": id, "name": minister_name, "kind": "simulação", "party": str(st.get("party", "")), "country": str(st.get("country_id", "")), "current_role": role, "career": career.slice(0, 48), "source": "state.ministers"}
	data["biographies"] = biographies

static func _refresh_autonomous_biographies(data: Dictionary, st: Dictionary) -> void:
	var biographies: Dictionary = data.get("biographies", {})
	var world: Variant = st.get("world", {})
	if not (world is Dictionary):
		data["biographies"] = biographies
		return
	var country_map: Dictionary = world.get("countries", {}) if world.get("countries") is Dictionary else {}
	var history: Array = world.get("history", []) if world.get("history") is Array else []
	for country_key in country_map.keys():
		var country: Dictionary = country_map[country_key] if country_map[country_key] is Dictionary else {}
		var country_id := str(country.get("id", country_key))
		var country_name := str(country.get("name", country_id))
		var parties: Dictionary = country.get("parties", {}) if country.get("parties") is Dictionary else {}
		for party_key in parties.keys():
			var party: Dictionary = parties[party_key] if parties[party_key] is Dictionary else {}
			var party_id := str(party.get("id", party_key))
			var leader := str(party.get("leader", "")).strip_edges()
			if leader == "":
				continue
			var bio_id := "world:%s:leader:%s" % [country_id, party_id]
			var old: Dictionary = biographies.get(bio_id, {}) if biographies.get(bio_id) is Dictionary else {}
			var career: Array = old.get("career", []) if old.get("career") is Array else []
			var role := "governo" if bool(party.get("in_gov", false)) else "oposição"
			var leadership_since := str(party.get("leadership_since", ""))
			if leadership_since != "" and (career.is_empty() or str(career[0]) != leadership_since + " · mudança de liderança registrada"):
				career.push_front({"date": leadership_since, "event": "mudança de liderança registrada no partido"})
			for event in history:
				if not (event is Dictionary) or str(event.get("country", "")) != country_id:
					continue
				var actors: Array = event.get("actors", []) if event.get("actors") is Array else []
				if not actors.has(party_id):
					continue
				var event_date := str(event.get("date", "%d-%02d" % [int(event.get("year", 0)), int(event.get("month", 1))]))
				var event_text := str(event.get("headline", event.get("description", "evento registrado")))
				var exists := false
				for career_item in career:
					if career_item is Dictionary and str(career_item.get("date", "")) == event_date and str(career_item.get("event", "")) == event_text:
						exists = true
						break
				if not exists:
					career.append({"date": event_date, "event": event_text, "category": str(event.get("category", ""))})
			if career.size() >= 48:
				break
			biographies[bio_id] = {"id": bio_id, "name": leader, "kind": "ator autônomo", "party": str(party.get("name", party_id)), "party_id": party_id, "country": country_id, "country_name": country_name, "current_role": role, "career": career.slice(0, 48), "source": "world.countries.parties"}
	data["biographies"] = biographies

static func _refresh_encyclopedia(data: Dictionary, st: Dictionary) -> void:
	var entries: Dictionary = data.get("encyclopedia", {})
	var country_id := str(st.get("country_id", ""))
	entries["country:" + country_id] = {"id": "country:" + country_id, "kind": "país", "title": str(st.get("country_name", country_id)), "summary": "Perfil atual derivado dos sistemas político, econômico e internacional.", "source": "state"}
	entries["party:" + str(st.get("abbr", ""))] = {"id": "party:" + str(st.get("abbr", "")), "kind": "partido", "title": str(st.get("party", "")), "summary": "Partido do jogador; posição e força são atualizadas pela simulação.", "source": "state"}
	entries["government:" + country_id] = {"id": "government:" + country_id, "kind": "governo", "title": "Governo atual", "summary": "" + ("No governo" if bool(st.get("government", false)) else "Na oposição"), "source": "state"}
	var world: Variant = st.get("world", {})
	if world is Dictionary:
		for raw_id in (world.get("countries", {}) as Dictionary).keys():
			var country: Dictionary = world.countries[raw_id] if world.countries[raw_id] is Dictionary else {}
			var id := str(country.get("id", raw_id))
			entries["country:" + id] = {"id": "country:" + id, "kind": "país", "title": str(country.get("name", id)), "summary": "País autônomo; governo, eleições, partidos e trajetória econômica são simulados no mundo.", "region": str(country.get("region", "")), "source": "world.countries"}
			var parties: Dictionary = country.get("parties", {}) if country.get("parties") is Dictionary else {}
			for raw_party in parties.keys():
				var party: Dictionary = parties[raw_party] if parties[raw_party] is Dictionary else {}
				var party_id := str(party.get("id", raw_party))
				entries["party:%s:%s" % [id, party_id]] = {"id": "party:%s:%s" % [id, party_id], "kind": "partido", "title": str(party.get("name", party_id)), "summary": "Partido autônomo; líder, cadeiras, apoio e situação no governo vêm da simulação.", "country": id, "leader": str(party.get("leader", "")), "source": "world.countries.parties"}
	var bills: Array = st.get("bills", []) if st.get("bills") is Array else []
	for bill in bills:
		if bill is Dictionary:
			var bill_id := str(bill.get("id", bill.get("title", "lei")))
			entries["law:" + bill_id] = {"id": "law:" + bill_id, "kind": "lei", "title": str(bill.get("title", bill.get("name", bill_id))), "summary": str(bill.get("status", "proposição registrada na simulação")), "source": "state.bills"}
	var intl: Dictionary = st.get("international_state", {}) if st.get("international_state") is Dictionary else {}
	for key in ["organizations", "blocs"]:
		var collection: Dictionary = intl.get(key, {}) if intl.get(key) is Dictionary else {}
		for raw_org in collection.keys():
			var org: Dictionary = collection[raw_org] if collection[raw_org] is Dictionary else {}
			var org_id := str(raw_org)
			entries["organization:%s:%s" % [key, org_id]] = {"id": "organization:%s:%s" % [key, org_id], "kind": "organização", "title": str(org.get("label", org.get("name", org_id))), "summary": "Compromisso internacional e status derivados da simulação.", "status": str(org.get("status", "")), "source": "international_state"}
	var treaties: Array = intl.get("treaties", []) if intl.get("treaties") is Array else []
	for index in treaties.size():
		var treaty: Dictionary = treaties[index] if treaties[index] is Dictionary else {}
		entries["treaty:%d:%s" % [index, str(treaty.get("country", ""))]] = {"id": "treaty:%d:%s" % [index, str(treaty.get("country", ""))], "kind": "tratado", "title": "Tratado " + str(treaty.get("kind", "internacional")), "summary": str(treaty.get("status", "registrado")), "country": str(treaty.get("country", "")), "source": "international_state.treaties"}
	var profile: Dictionary = st.get("economic_profile", {}) if st.get("economic_profile") is Dictionary else {}
	var economic_labels := {"gdp_growth": "crescimento", "inflation": "inflação", "unemployment": "desemprego", "debt": "dívida pública", "gdp": "PIB", "gdp_per_capita": "PIB per capita", "revenue": "receita pública", "expense": "despesa pública"}
	for key in economic_labels.keys():
		var metric: Dictionary = profile.get(key, {}) if profile.get(key) is Dictionary else {}
		if not metric.is_empty():
			entries["concept:economia:%s" % key] = {"id": "concept:economia:%s" % key, "kind": "conceito econômico", "title": str(economic_labels[key]).capitalize(), "summary": "Indicador com perfil inicial, fonte e metodologia registrados no catálogo econômico.", "status": str(metric.get("status", "catalogado")), "source": "economic_profile"}
	data["encyclopedia"] = entries

static func _make_poll(data: Dictionary, st: Dictionary) -> void:
	var stamp := _stamp(st)
	var key := "approval|" + stamp
	for old in data.polls:
		if str(old.get("id", "")) == key: return
	var approval := float(st.get("approval", 42.0))
	var sample := 1000
	var uncertainty := 1.96 * sqrt(0.25 / float(sample)) * 100.0
	var noise := (_hash01(str(st.get("country_id", "")) + "|poll|" + stamp) - 0.5) * 3.0
	var estimate := clampf(approval + noise, 0.0, 100.0)
	var previous: Array = []
	for old in data.polls:
		if str(old.get("topic", "")) == "government_approval":
			previous.append(float(old.get("estimate", 0.0)))
			if previous.size() >= 2: break
	var moving_values: Array = [estimate]
	moving_values.append_array(previous)
	var moving_average := 0.0
	for value in moving_values: moving_average += float(value)
	moving_average /= float(moving_values.size())
	var segments := [
		{"id": "metropolitano", "label": "Metropolitano", "sample_size": 400, "estimate": clampf(estimate + (_hash01(str(st.get("country_id", "")) + "|metro|" + stamp) - 0.5) * 2.0, 0.0, 100.0)},
		{"id": "interior", "label": "Interior", "sample_size": 350, "estimate": clampf(estimate + (_hash01(str(st.get("country_id", "")) + "|interior|" + stamp) - 0.5) * 2.0, 0.0, 100.0)},
		{"id": "rural", "label": "Rural", "sample_size": 250, "estimate": clampf(estimate + (_hash01(str(st.get("country_id", "")) + "|rural|" + stamp) - 0.5) * 2.0, 0.0, 100.0)},
	]
	_bounded_append(data.polls, {"id": key, "topic": "government_approval", "fieldwork_date": stamp, "publication_date": stamp, "population": "eleitores adultos", "sample_size": sample, "method": "amostra simulada estratificada", "margin_of_error": uncertainty, "question": "Você aprova ou desaprova o desempenho do governo?", "undecided": 4.0, "organization": "Instituto Horizonte Simulado", "simulated": true, "estimate": estimate, "moving_average": moving_average, "series_window": moving_values.size(), "segments": segments, "segment_note": "Segmentos geográficos mutuamente exclusivos; suas amostras somam 1.000 e não devem ser somadas como novas entrevistas.", "underlying_state": "não publicado", "notes": "Estimativa; não é aprovação exata nem resultado eleitoral."}, MAX_POLLS)

static func _make_report(data: Dictionary, st: Dictionary) -> void:
	var stamp := _stamp(st)
	var id := "government:" + stamp
	for old in data.reports:
		if str(old.get("id", "")) == id: return
	var approval := float(st.get("approval", 0.0))
	var debt := float(st.get("debt", 0.0))
	var stability := float(st.get("coalition_stability", st.get("coalition_cohesion", 60.0)))
	var risks: Array = []
	if approval < 35.0: risks.append("aprovação baixa")
	if debt > 80.0: risks.append("dívida elevada")
	if stability < 45.0: risks.append("coalizão instável")
	var causal_evidence: Array = []
	for entry in CausalLog.recent(st, "", 6):
		if entry is Dictionary:
			causal_evidence.append({"month": str(entry.get("month", "")), "domain": str(entry.get("domain", "")), "cause": str(entry.get("cause", "")), "effects": entry.get("effects", {}), "explanation": str(entry.get("explanation", ""))})
	_bounded_append(data.reports, {"id": id, "date": stamp, "area": "governo", "title": "Boletim de estabilidade governamental", "executive_summary": "O quadro combina indicadores observados e interpretação condicional.", "facts": [{"label": "aprovação observada", "value": approval}, {"label": "dívida/PIB observado", "value": debt}, {"label": "estabilidade observada", "value": stability}], "estimates": [{"label": "risco político", "value": "alto" if risks.size() >= 2 else "moderado"}], "interpretations": risks, "conditional_outlook": "Se a aprovação e a coesão continuarem caindo, a pressão parlamentar tende a aumentar; isto não é uma previsão certa.", "confidence": "moderada", "assumptions": ["os indicadores atuais permanecem comparáveis"], "limitations": ["o sistema não revela variáveis ocultas"], "access": "público", "source": "state"}, MAX_REPORTS)
	if not data.reports.is_empty() and data.reports[0] is Dictionary:
		data.reports[0]["causal_evidence"] = causal_evidence

static func monthly(st: Dictionary) -> void:
	ensure(st)
	var data: Dictionary = st.phase_f
	var world_events := _world_events(st)
	for event in world_events.slice(0, 30):
		if event is Dictionary: _ingest_event(data, _editorial_event(st, event))
	for event in _scandal_events(st):
		_ingest_event(data, _editorial_event(st, event))
	var local := _state_event(st)
	if not local.is_empty(): _ingest_event(data, _editorial_event(st, local))
	_refresh_biography(data, st)
	_refresh_autonomous_biographies(data, st)
	_refresh_encyclopedia(data, st)
	_make_poll(data, st)
	_make_report(data, st)
	data["last_tick"] = _stamp(st)
	st["phase_f"] = data

static func articles(st: Dictionary, limit := 20) -> Array:
	ensure(st)
	return (st.phase_f.articles as Array).slice(0, limit)

static func archive(st: Dictionary, limit := 20) -> Array:
	ensure(st)
	return (st.phase_f.archive as Array).slice(0, limit)

static func latest_report(st: Dictionary) -> Dictionary:
	ensure(st)
	var reports: Array = st.phase_f.reports
	return reports[0] if not reports.is_empty() else {}
