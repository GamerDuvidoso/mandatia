extends RefCounted
## Sistema B5: escândalos e crises em estágios.
##
## Alegação, cobertura, reação, investigação, consequências e resolução são
## estados distintos. O sistema nunca trata alegação como culpa provada e não
## oferece "suprimir instituições": defender publicamente aumenta exposição.

const DATA_PATH := "res://config/scandals.json"
const MAX_ACTIVE := 2
const CausalLog := preload("res://scripts/sim/causal_log.gd")
const PoliticalRelations := preload("res://scripts/sim/political_relations.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func categories() -> Array:
	return config().get("categories", [])

static func ensure(st: Dictionary) -> void:
	if not (st.get("scandals") is Array):
		st["scandals"] = []
	if not (st.get("scandal_history") is Array):
		st["scandal_history"] = []
	if not st.has("scandal_penalty"):
		st["scandal_penalty"] = 0.0
	if not st.has("integrity_scar"):
		st["integrity_scar"] = 0
	for case in st.scandals:
		if not case.has("media"):
			case["media"] = 20.0
		if not case.has("procedure"):
			case["procedure"] = "alegacao"
		if not case.has("evidence"):
			case["evidence"] = 0
		if not case.has("cooperation"):
			case["cooperation"] = 0

static func risk(st: Dictionary) -> float:
	var value := 0.035
	value += maxf(0.0, 45.0 - float(st.get("credibility", 31.0))) * 0.0022
	value += maxf(0.0, 70.0 - float(st.get("coalition_cohesion", 60.0))) * 0.0007
	var finance: Dictionary = st.get("campaign_finance", {}) if st.get("campaign_finance") is Dictionary else {}
	value += float(finance.get("risk", 0.0)) / 500.0
	if bool(st.get("government", false)):
		value += 0.01
	return clampf(value, 0.02, 0.32)

static func _category_by_id(id: String) -> Dictionary:
	for entry in categories():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func _open_cases(st: Dictionary) -> Array:
	var rows: Array = []
	for case in (st.get("scandals", []) if st.get("scandals") is Array else []):
		if not bool(case.get("closed", false)):
			rows.append(case)
	return rows

static func maybe_spawn(st: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	ensure(st)
	if _open_cases(st).size() >= MAX_ACTIVE:
		return {}
	if rng.randf() > risk(st):
		return {}
	var pool: Array = []
	var total := 0.0
	for entry in categories():
		var weight := float(entry.get("weight", 1.0))
		if str(entry.get("id", "")) == "campaign" and not bool(st.get("in_campaign", false)):
			weight *= 0.4
		pool.append([entry, weight])
		total += weight
	var cursor := rng.randf() * total
	var picked: Dictionary = categories()[0]
	for pair in pool:
		cursor -= float(pair[1])
		if cursor <= 0.0:
			picked = pair[0]
			break
	var month := "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
	var case := {
		"id": "caso-%d-%d" % [int(st.get("date_year", 0)), rng.randi_range(1000, 9999)],
		"category": str(picked.get("id", "admin")), "category_label": str(picked.get("label", "Falha")),
		"title": str(picked.get("title", "Caso sob apuração")),
		"severity": float(picked.get("severity", 3)), "stage_index": 0,
		"stage": "alegacao", "status": "unproven", "legal": "unproven",
		"opened": month, "closed": false, "response": "", "evidence": 0,
		"media": clampf(18.0 + float(picked.get("severity", 3)) * 4.0 + maxf(0.0, 45.0 - float(st.get("credibility", 31.0))) * 0.35, 10.0, 95.0),
		"procedure": "alegacao", "cooperation": 0,
		"history": [{"month": month, "stage": "alegacao", "note": "Alegação publicada; nenhuma conclusão jurídica."}],
		"actor": "auxiliar do partido",
	}
	var scandals: Array = st.get("scandals", [])
	scandals.push_front(case)
	st["scandals"] = scandals
	st["scandal_penalty"] = penalty(st)
	st["news"].push_front("ALEGAÇÃO: " + str(case.title))
	return case

static func stage_label(stage: String) -> String:
	var labels: Dictionary = config().get("status_labels", {})
	return str(labels.get(stage, stage.to_upper()))

static func legal_label(status: String) -> String:
	var labels: Dictionary = config().get("legal_labels", {})
	return str(labels.get(status, status.to_upper()))

static func procedure_label(status: String) -> String:
	var labels := {
		"alegacao": "ALEGAÇÃO PÚBLICA", "midia": "COBERTURA MIDIÁTICA",
		"reacao": "REAÇÃO PÚBLICA", "inquerito": "INQUÉRITO FORMAL",
		"cooperacao": "COOPERAÇÃO", "judicial": "FASE JUDICIAL",
		"encerrado": "ENCERRADO",
	}
	return str(labels.get(status, status.to_upper()))

## Avança um estágio por mês. O desfecho depende das respostas do jogador,
## da evidência acumulada e do risco — nunca de um botão de "abafar".
static func advance(st: Dictionary, rng: RandomNumberGenerator) -> Array:
	ensure(st)
	var news: Array = []
	for case in st.scandals:
		if bool(case.get("closed", false)):
			continue
		var idx := int(case.get("stage_index", 0))
		idx = mini(idx + 1, 5)
		case["stage_index"] = idx
		var stages: Array = config().get("stages", []) if config().get("stages") is Array else []
		var stage := str(stages[idx]) if idx < stages.size() else "resolucao"
		case["stage"] = stage
		var month := "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
		var note := ""
		var media := float(case.get("media", 20.0))
		var effects := {}
		if stage == "midia":
			media = clampf(media + 10.0 + float(case.get("severity", 3)) * 1.5, 0.0, 100.0)
			st["approval"] = float(st.get("approval", 45.0)) - 0.8 - media * 0.012
			case["procedure"] = "midia"
			note = "Imprensa amplia o caso (cobertura %.0f); aprovação %.1f." % [media, float(st.get("approval", 45.0))]
			effects = {"approval": -0.8 - media * 0.012, "media": 10.0}
		elif stage == "reacao":
			media = clampf(media + 7.0, 0.0, 100.0)
			st["approval"] = float(st.get("approval", 45.0)) - 1.2 - media * 0.008
			st["popularity"] = float(st.get("popularity", 4.0)) - 0.5
			case["procedure"] = "reacao"
			note = "Reação pública pressiona o partido; cobertura %.0f, popularidade -0,5." % media
			effects = {"approval": -1.2 - media * 0.008, "popularity": -0.5, "media": 7.0}
		elif stage == "investigacao":
			case["status"] = "investigating"
			case["legal"] = "investigating"
			case["procedure"] = "inquerito"
			case["evidence"] = mini(5, int(case.get("evidence", 0)) + 1 + (1 if int(case.get("cooperation", 0)) > 0 else 0))
			media = clampf(media + 5.0, 0.0, 100.0)
			for party in (st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []):
				PoliticalRelations.shift(st, str(st.get("abbr", "")), str(party), -1.5, "caso sob apuração")
			note = "Apuração formal aberta; evidência %d/5, cobertura %.0f, sem conclusão jurídica." % [int(case.evidence), media]
			effects = {"evidence": int(case.evidence), "media": 5.0, "relation": -1.5}
		elif stage == "consequencias":
			var defense := str(case.get("response", "")) == "defend"
			var evidence := int(case.get("evidence", 0))
			var cooperation := int(case.get("cooperation", 0))
			var chance_confirm := 0.28 + float(case.get("severity", 3)) * 0.035 + evidence * 0.07 + media * 0.0018 + (0.10 if defense else 0.0) - cooperation * 0.025
			case["procedure"] = "judicial"
			if rng.randf() < clampf(chance_confirm, 0.1, 0.85):
				case["status"] = "confirmed"
				case["legal"] = "confirmed"
				var approval_cost := 3.0 + media * 0.035 + float(case.get("severity", 3)) * 0.35
				var coalition_cost := 5.0 + media * 0.045
				st["approval"] = clampf(float(st.get("approval", 45.0)) - approval_cost, 0.0, 100.0)
				st["credibility"] = float(st.get("credibility", 31.0)) - 4.0
				st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - coalition_cost, 10.0, 100.0)
				st["integrity_scar"] = int(st.get("integrity_scar", 0)) + 1
				var relation_cost := -3.0 - media * 0.03
				for party in (st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []):
					PoliticalRelations.shift(st, str(st.get("abbr", "")), str(party), relation_cost, "escândalo confirmado")
				note = "MISCONDUTA CONFIRMADA: aprovação -%.1f, credibilidade -4, coalizão -%.1f, relação com aliados %.1f (cobertura %.0f)." % [approval_cost, coalition_cost, relation_cost, media]
				effects = {"approval": -approval_cost, "credibility": -4.0, "coalition_cohesion": -coalition_cost, "relationship": relation_cost, "media": media}
			elif rng.randf() < 0.35:
				case["status"] = "acquitted"
				case["legal"] = "acquitted"
				media = maxf(0.0, media - 12.0)
				st["credibility"] = float(st.get("credibility", 31.0)) + 2.0
				note = "ABSOLVIÇÃO: sem culpa comprovada; credibilidade +2, cobertura recua para %.0f." % media
				effects = {"credibility": 2.0, "media": -12.0}
			else:
				case["status"] = "unresolved"
				case["legal"] = "unresolved"
				note = "Caso sem desfecho conclusivo; o tema permanece no noticiário (cobertura %.0f)." % media
				effects = {"media": media}
		elif stage == "resolucao":
			case["closed"] = true
			case["procedure"] = "encerrado"
			if case.get("status", "unproven") == "unproven":
				case["status"] = "unresolved"
				case["legal"] = "unresolved"
				note = "Caso encerrado com status: %s (sem condenação)." % legal_label(str(case.get("status", "unresolved")))
			else:
				note = "Caso encerrado: %s." % legal_label(str(case.get("status", "unresolved")))
			if not (st.get("scandal_history") is Array):
				st["scandal_history"] = []
			st.scandal_history.push_front(case.duplicate(true))
		case["media"] = clampf(media, 0.0, 100.0)
		if note != "":
			case.history.append({"month": month, "stage": stage, "note": note})
			news.append(note)
			CausalLog.record(st, "escandalo", "%s (%s)" % [str(case.get("title", "caso")), stage], effects, note)
		st["scandal_penalty"] = penalty(st)
	return news

static func penalty(st: Dictionary) -> float:
	var total := 0.0
	for case in _open_cases(st):
		var status := str(case.get("status", "unproven"))
		var media := float(case.get("media", 20.0))
		if status == "confirmed":
			total += (2.0 + float(case.get("severity", 3)) * 0.5) * (0.6 + media / 100.0)
		elif status == "unresolved":
			total += 0.8 * (0.7 + media / 150.0)
		elif status == "investigating":
			total += 0.4 + media * 0.004
	return clampf(total, 0.0, 8.0)

static func respond(st: Dictionary, case_id: String, action: String) -> Dictionary:
	ensure(st)
	var case: Dictionary = {}
	for item in st.scandals:
		if str(item.get("id", "")) == case_id and not bool(item.get("closed", false)):
			case = item
			break
	if case.is_empty():
		return {"ok": false, "reason": "Caso não encontrado ou já encerrado"}
	var response: Dictionary = config().get("responses", {}).get(action, {})
	if response.is_empty():
		return {"ok": false, "reason": "Resposta inválida"}
	var cost := float(response.get("cost", 0))
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente"}
	st["funds"] = float(st.funds) - cost
	case["response"] = action
	case["evidence"] = int(case.get("evidence", 0)) + (1 if action in ["investigate", "defend"] else 0)
	var media := float(case.get("media", 20.0))
	var effects := {}
	var result := ""
	match action:
		"cooperate":
			case["cooperation"] = int(case.get("cooperation", 0)) + 2
			case["procedure"] = "cooperacao"
			media = maxf(0.0, media - 9.0)
			st["credibility"] = float(st.get("credibility", 31.0)) + 3.0
			st["approval"] = float(st.get("approval", 45.0)) - 1.0
			result = "O partido coopera; cobertura -9, credibilidade +3, desgaste imediato -1."
			effects = {"media": -9.0, "credibility": 3.0, "approval": -1.0, "cooperation": 2}
		"investigate":
			case["procedure"] = "inquerito"
			media = minf(100.0, media + 6.0)
			st["credibility"] = float(st.get("credibility", 31.0)) + 2.0
			result = "Investigação interna aberta; cobertura +6, custo M$ 600 e mais evidência vem à tona."
			effects = {"media": 6.0, "credibility": 2.0, "evidence": 1}
		"replace":
			media = maxf(0.0, media - 5.0)
			st["cohesion"] = clampf(float(st.get("cohesion", 78.0)) - 3.0, 10.0, 100.0)
			st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - 2.0, 10.0, 100.0)
			st["approval"] = float(st.get("approval", 45.0)) + 2.0
			result = "Envolvido afastado; cobertura -5, aprovação +2, coesão -3 e coalizão -2."
			effects = {"media": -5.0, "cohesion": -3.0, "coalition_cohesion": -2.0, "approval": 2.0}
		"defend":
			media = minf(100.0, media + 11.0)
			st["credibility"] = float(st.get("credibility", 31.0)) - 3.0
			st["approval"] = float(st.get("approval", 45.0)) + 1.0
			result = "Defesa pública mobiliza a base, mas a cobertura sobe para %.0f e a credibilidade cai 3." % media
			effects = {"media": 11.0, "credibility": -3.0, "approval": 1.0}
		"transparency":
			media = maxf(0.0, media - 7.0)
			st["credibility"] = float(st.get("credibility", 31.0)) + 5.0
			st["approval"] = float(st.get("approval", 45.0)) - 2.0
			result = "Pacote de transparência: cobertura -7, credibilidade +5, custo político -2."
			effects = {"media": -7.0, "credibility": 5.0, "approval": -2.0, "evidence": 1}
	case["media"] = clampf(media, 0.0, 100.0)
	var month := "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
	case.history.append({"month": month, "stage": str(case.get("stage", "alegacao")), "note": result})
	st["scandal_penalty"] = penalty(st)
	CausalLog.record(st, "escandalo", "resposta ao caso: %s" % action, effects, result)
	return {"ok": true, "reason": result, "case": case}

static func active(st: Dictionary) -> Array:
	ensure(st)
	return _open_cases(st)

static func status_counts(st: Dictionary) -> Dictionary:
	ensure(st)
	var counts := {"confirmed": 0, "acquitted": 0, "unresolved": 0, "investigating": 0, "open": 0}
	for case in st.scandals:
		var status := str(case.get("status", "unproven"))
		if counts.has(status):
			counts[status] = int(counts[status]) + 1
		if not bool(case.get("closed", false)):
			counts["open"] = int(counts["open"]) + 1
	return counts
