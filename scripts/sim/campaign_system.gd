extends RefCounted
## Sistema B6: campanha avançada, financiamento e alcance regional.
##
## Mantém a economia de três ações por mês. Cada ação altera organização,
## reconhecimento, regiões e grupos que o motor eleitoral já lê; nenhuma soma
## votos diretamente. Dinheiro privado compra alcance e aumenta risco jurídico.

const DATA_PATH := "res://config/campaign_actions.json"
const MAX_ACTIONS := 3
const InterestGroups := preload("res://scripts/sim/interest_groups.gd")
const Scandals := preload("res://scripts/sim/scandal_system.gd")
const CausalLog := preload("res://scripts/sim/causal_log.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func actions() -> Array:
	return config().get("actions", [])

static func action(id: String) -> Dictionary:
	for entry in actions():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func finance_rules() -> Dictionary:
	return config().get("finance", {})

static func init_state(st: Dictionary) -> void:
	st["campaign_finance"] = {
		"private_raised": 0.0, "public_raised": 0.0, "spent": 0.0,
		"risk": 0.0, "private_month": "", "public_month": "", "reports": [],
	}
	st["campaign_log"] = []
	st["campaign_penalty"] = 0.0

static func ensure(st: Dictionary) -> void:
	if not (st.get("campaign_finance") is Dictionary):
		init_state(st)

static func _month(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]

static func perform(st: Dictionary, id: String, region_index: int, regions: Array, focus_group: String) -> Dictionary:
	ensure(st)
	var entry := action(id)
	if entry.is_empty():
		return {"ok": false, "reason": "Ação desconhecida"}
	if int(st.get("campaign_actions", 0)) >= MAX_ACTIONS:
		return {"ok": false, "reason": "Limite de 3 ações de campanha neste mês"}
	var cost := float(entry.get("cost", 0))
	if id == "endorsement":
		var picked_id := ""
		var picked := ""
		var best := 20.0
		for group_key in st.get("interest_groups", {}).keys():
			var row: Dictionary = st.interest_groups[group_key]
			if bool(row.get("strike", {}).get("active", false)):
				continue
			if float(row.get("relationship", 0.0)) > best:
				best = float(row.relationship)
				picked = str(row.get("name", ""))
				picked_id = str(group_key)
		if picked_id == "":
			return {"ok": false, "reason": "Nenhuma organização com relação suficiente para endossar"}
		var endorsed := InterestGroups.endorse(st, picked_id)
		if not bool(endorsed.get("ok", false)):
			return {"ok": false, "reason": str(endorsed.get("reason", "Endosso indisponível"))}
		st["campaign_actions"] = int(st.get("campaign_actions", 0)) + 1
		_log(st, id, "Endosso de %s" % picked, 0)
		CausalLog.record(st, "campanha", "endosso de %s" % picked, {"campaign": 1.5, "popularity": 1.0, "relationship": -4.0}, "O endosso move a campanha porque a organização cobra relação e expõe sua base; não é um bônus isolado de popularidade.")
		return {"ok": true, "reason": "%s endossa a campanha." % picked}
	if float(st.get("funds", 0.0)) < cost:
		return {"ok": false, "reason": "Caixa insuficiente para " + str(entry.get("label", id))}
	var diminishing := clampf(1.0 - float(st.get("popularity", 4.0)) / 85.0, 0.25, 1.0)
	st["funds"] = float(st.funds) - cost
	st["campaign_actions"] = int(st.get("campaign_actions", 0)) + 1
	st["campaign"] = float(st.get("campaign", 0.0)) + float(entry.get("campaign", 0.0)) * diminishing
	st["recognition"] = float(st.get("recognition", 2.0)) + float(entry.get("recognition", 0.0))
	var region_delta := float(entry.get("region", 0.0))
	if region_delta > 0.0 and not regions.is_empty():
		var idx := clampi(region_index, 0, st.region_support.size() - 1)
		st.region_support[idx] = float(st.region_support[idx]) + region_delta
		for i in st.region_support.size():
			if i != idx:
				st.region_support[i] = float(st.region_support[i]) + region_delta * 0.12
	var group_ids: Array = (entry.get("groups", []) as Array).duplicate()
	if focus_group != "":
		group_ids.append(focus_group)
	var social: Dictionary = st.get("social_groups", {})
	for group_id in group_ids:
		if social.has(str(group_id)):
			social[str(group_id)].satisfaction = clampf(float(social[str(group_id)].satisfaction) + 1.4, 5.0, 95.0)
			social[str(group_id)].approval = float(social[str(group_id)].satisfaction)
	var finance: Dictionary = st.campaign_finance
	finance.spent = float(finance.get("spent", 0.0)) + cost
	finance.risk = clampf(float(finance.get("risk", 0.0)) + float(entry.get("finance_risk", 0.0)), 0.0, 100.0)
	if id == "crisis":
		var target := {}
		var worst := -1.0
		for case in (st.get("scandals", []) if st.get("scandals") is Array else []):
			if bool(case.get("closed", false)):
				continue
			var weight := float(case.get("media", 20.0)) * float(case.get("severity", 3))
			if weight > worst:
				worst = weight
				target = case
		if not target.is_empty():
			target["media"] = maxf(0.0, float(target.get("media", 20.0)) - 10.0)
			CausalLog.record(st, "campanha", "resposta eleitoral a %s" % str(target.get("title", "crise")), {"media": -10.0, "campaign_penalty": -2.5}, "A campanha responde à crise e reduz a cobertura, mas o status jurídico do caso não muda: responder não absolve.")
		st["campaign_penalty"] = maxf(0.0, float(st.get("campaign_penalty", 0.0)) - 2.5)
		st["scandal_penalty"] = Scandals.penalty(st)
	_log(st, id, str(entry.get("label", id)), cost)
	st["news"].push_front("Campanha: %s em %s." % [str(entry.get("label", id)), str(regions[clampi(region_index, 0, regions.size() - 1)].get("name", "região")) if not regions.is_empty() else "todo o país"])
	return {"ok": true, "reason": "%s concluída." % str(entry.get("label", id))}

static func _log(st: Dictionary, id: String, label: String, cost: float) -> void:
	var log: Array = st.get("campaign_log", []) if st.get("campaign_log") is Array else []
	log.push_front({"month": _month(st), "action": id, "label": label, "cost": cost})
	if log.size() > 30:
		log = log.slice(0, 30)
	st["campaign_log"] = log

static func raise_funds(st: Dictionary, source: String) -> Dictionary:
	ensure(st)
	var finance: Dictionary = st.campaign_finance
	var rules := finance_rules()
	if source == "private":
		if str(finance.get("private_month", "")) == _month(st):
			return {"ok": false, "reason": "Captação privada já feita neste mês"}
		var amount := float(rules.get("private_amount", 2500))
		var cap := float(rules.get("private_cap", 6000))
		if float(finance.get("private_raised", 0.0)) >= cap:
			return {"ok": false, "reason": "Teto privado da campanha atingido"}
		amount = minf(amount, cap - float(finance.private_raised))
		finance.private_raised = float(finance.private_raised) + amount
		finance.private_month = _month(st)
		finance.risk = clampf(float(finance.risk) + float(rules.get("risk_per_private", 9.0)), 0.0, 100.0)
		st["funds"] = float(st.funds) + amount
		return {"ok": true, "reason": "Captação privada: M$ %s. Risco de apuração +%d." % [_fmt(amount), int(rules.get("risk_per_private", 9))]}
	if source == "public":
		if str(finance.get("public_month", "")) == _month(st):
			return {"ok": false, "reason": "Financiamento público já usado neste mês"}
		var cap := float(rules.get("public_cap", 2400))
		if float(finance.get("public_raised", 0.0)) >= cap:
			return {"ok": false, "reason": "Teto público da campanha atingido"}
		var amount := minf(float(rules.get("public_amount", 1200)), cap - float(finance.public_raised))
		finance.public_raised = float(finance.get("public_raised", 0.0)) + amount
		finance.public_month = _month(st)
		st["funds"] = float(st.funds) + amount
		return {"ok": true, "reason": "Fundo público de campanha: M$ %s." % _fmt(amount)}
	return {"ok": false, "reason": "Fonte desconhecida"}

static func monthly(st: Dictionary) -> void:
	ensure(st)
	var finance: Dictionary = st.campaign_finance
	finance.risk = maxf(0.0, float(finance.get("risk", 0.0)) - 3.0)
	var reports: Array = finance.get("reports", [])
	reports.push_front({"month": _month(st), "spent": float(finance.get("spent", 0.0)), "private": float(finance.get("private_raised", 0.0)), "public": float(finance.get("public_raised", 0.0)), "risk": float(finance.get("risk", 0.0))})
	if reports.size() > 12:
		reports = reports.slice(0, 12)
	finance["reports"] = reports
	st["campaign_finance"] = finance
	st["campaign_penalty"] = maxf(0.0, float(st.get("scandal_penalty", 0.0)) * 0.8 - 0.5)

static func regional_analysis(st: Dictionary, regions: Array) -> Array:
	var rows: Array = []
	var total_pop := 0.0
	for region in regions:
		total_pop += float(region.get("pop", 0.0))
	for i in regions.size():
		var support_values: Array = st.get("region_support", []) if st.get("region_support") is Array else []
		var support := float(support_values[i]) if i < support_values.size() else float(st.get("popularity", 4.0))
		var region: Dictionary = regions[i]
		var gap := maxf(0.0, 60.0 - support)
		rows.append({
			"name": str(region.get("name", "Região")), "support": support,
			"weight": float(region.get("pop", 0.0)) / maxf(0.01, total_pop) * 100.0,
			"opportunity": gap, "context": str(region.get("problem", "")),
		})
	rows.sort_custom(func(a, b): return float(a.support) < float(b.support))
	return rows

static func _fmt(value: float) -> String:
	return "%d" % int(round(value))
