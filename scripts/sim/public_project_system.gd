extends RefCounted
## C4 — Projetos públicos e infraestrutura.
##
## Ciclo completo: proposta, viabilidade, aprovação orçamentária, financiamento,
## obras, operação e avaliação. Prazo, custo e resultado dependem da capacidade
## do ministério responsável, da dotação da categoria e do risco de execução.
## O projeto não é um evento pronto: cada mês de obra consome dotação e pode
## atrasar, encarecer ou paralisar por falta de verba.

const DATA_PATH := "res://config/public_administration.json"
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const Ministries := preload("res://scripts/sim/ministry_system.gd")
const CausalLog := preload("res://scripts/sim/causal_log.gd")

const FUNDING_LABELS := {
	"tesouro": "Tesouro / dotação",
	"titulos": "Títulos públicos",
	"ppp": "Parceria público-privada",
	"externo": "Financiamento externo",
}

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func catalog() -> Array:
	var value: Variant = config().get("projects", [])
	return value if value is Array else []

static func definition(key: String) -> Dictionary:
	for entry in catalog():
		if str(entry.get("id", "")) == key:
			return entry
	return {}

static func init_state(st: Dictionary) -> void:
	st["projects"] = []
	st["project_seq"] = 0
	st["project_opex"] = {}
	st["project_history"] = []

static func ensure(st: Dictionary) -> void:
	if not (st.get("projects") is Array):
		st["projects"] = []
	if not st.has("project_seq"):
		st["project_seq"] = (st.projects as Array).size()
	if not (st.get("project_opex") is Dictionary):
		st["project_opex"] = {}
	if not (st.get("project_history") is Array):
		st["project_history"] = []

static func _month_index(st: Dictionary) -> int:
	return int(st.get("date_year", 0)) * 12 + int(st.get("date_month", 1))

static func _project(st: Dictionary, id: String) -> Dictionary:
	for project in st.projects:
		if str(project.get("id", "")) == id:
			return project
	return {}

static func active_count(st: Dictionary) -> int:
	ensure(st)
	var count := 0
	for project in st.projects:
		if str(project.get("status", "")) in ["obras", "paralisada"]:
			count += 1
	return count

static func operational_count(st: Dictionary) -> int:
	ensure(st)
	var count := 0
	for project in st.projects:
		if str(project.get("status", "")) == "operacional":
			count += 1
	return count

static func propose(st: Dictionary, key: String, region_index: int) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo propõe projetos"}
	var entry := definition(key)
	if entry.is_empty():
		return {"ok": false, "reason": "Projeto desconhecido"}
	ensure(st)
	for project in st.projects:
		if str(project.get("key", "")) == key and int(project.get("region", -1)) == region_index and str(project.get("status", "")) != "cancelado":
			return {"ok": false, "reason": "Já existe um projeto desta obra nesta região"}
	var capex := float(entry.get("capex", 1000.0))
	var cost := capex * float(BudgetSystem.fiscal().get("project_feasibility_cost", 0.01))
	if float(st.get("treasury", 0.0)) < cost:
		return {"ok": false, "reason": "Tesouro insuficiente para o estudo de viabilidade (M$ %d)" % int(cost)}
	st["treasury"] = float(st.treasury) - cost
	st["project_seq"] = int(st.get("project_seq", 0)) + 1
	var id := "P%02d" % int(st.project_seq)
	var month := _month_index(st)
	var project := {
		"id": id, "key": key, "label": str(entry.get("label", key)),
		"category": str(entry.get("category", "")), "ministry": str(entry.get("ministry", "")),
		"service": str(entry.get("service", "")), "region": clampi(region_index, 0, 7),
		"status": "proposta", "stage_index": 0, "funding": "tesouro",
		"capex": capex, "cost_total": capex, "cost_spent": 0.0,
		"months_total": int(entry.get("months", 12)), "months_left": int(entry.get("months", 12)),
		"months_paused": 0, "progress": 0.0, "op_cost": float(entry.get("op_cost", 0.0)),
		"service_gain": float(entry.get("service_gain", 0.0)), "jobs": int(entry.get("jobs", 0)),
		"beneficiaries": int(entry.get("beneficiaries", 0)), "group": str(entry.get("group", "")),
		"risk": float(entry.get("risk", 20.0)), "overrun": 0.0,
		"feasibility": 0.0, "proposed_month": month, "started_month": 0,
		"completed_month": 0, "evaluated": false, "evaluation": {},
		"history": [{"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "proposta", "note": "Estudo de viabilidade iniciado."}],
	}
	st.projects.append(project)
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("Proposta de %s na região %d entra em análise de viabilidade (custo inicial M$ %s)." % [str(project.label), int(project.region) + 1, str(int(cost))])
	st["news"] = news
	CausalLog.record(st, "projeto", "%s proposto" % str(project.label), {"funds": -cost}, "Viabilidade técnica e orçamentária é o primeiro filtro; sem dotação e capacidade a obra não avança.")
	return {"ok": true, "id": id, "cost": cost, "reason": "Proposta criada"}

static func feasibility(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	var project := _project(st, id)
	if project.is_empty() or str(project.get("status", "")) != "proposta":
		return {"ok": false, "reason": "Projeto não está em proposta"}
	var cost := float(project.capex) * float(BudgetSystem.fiscal().get("project_feasibility_cost", 0.01))
	if float(st.get("treasury", 0.0)) < cost:
		return {"ok": false, "reason": "Tesouro insuficiente para concluir a viabilidade"}
	st["treasury"] = float(st.treasury) - cost
	var ministry := Ministries.ministry_data(st, str(project.ministry))
	var capacity := float(ministry.get("capacity", 50.0))
	var risk := clampf(float(project.risk) + (60.0 - capacity) * 0.45 - (capacity - 50.0) * 0.15, 5.0, 85.0)
	var months := int(project.months_total) + int(maxf(0.0, 55.0 - capacity) / 14.0)
	project["risk"] = risk
	project["months_total"] = months
	project["months_left"] = months
	project["feasibility"] = clampf(100.0 - risk, 0.0, 100.0)
	project["cost_total"] = float(project.capex) * (1.0 + risk / 500.0)
	project["status"] = "viabilidade"
	project["stage_index"] = 1
	project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "viabilidade", "note": "Risco %.0f, prazo estimado %d meses, custo provável M$ %s." % [risk, months, str(int(project.cost_total))]})
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("Viabilidade de %s: risco %.0f/100, prazo %d meses, custo provável M$ %s." % [str(project.label), risk, months, str(int(project.cost_total))])
	st["news"] = news
	return {"ok": true, "risk": risk, "months": months, "cost_total": float(project.cost_total), "reason": "Viabilidade concluída"}

static func approve(st: Dictionary, id: String, funding := "tesouro") -> Dictionary:
	ensure(st)
	var project := _project(st, id)
	if project.is_empty() or str(project.get("status", "")) != "viabilidade":
		return {"ok": false, "reason": "Projeto precisa de viabilidade concluída"}
	if not FUNDING_LABELS.has(funding):
		return {"ok": false, "reason": "Fonte de financiamento inválida"}
	var category := str(project.category)
	if funding in ["tesouro", "titulos"]:
		var payment := float(project.cost_total) / float(maxi(1, int(project.months_total)))
		var envelope := BudgetSystem.category_envelope(st, category)
		if envelope < payment * 0.8:
			return {"ok": false, "reason": "Dotação insuficiente em %s: a parcela mensal (M$ %s) não cabe no orçamento" % [str(BudgetSystem.category(category).get("label", category)), str(int(payment))]}
	if funding == "ppp":
		var fee := float(project.capex) * float(BudgetSystem.fiscal().get("ppp_contract_cost", 0.005))
		if float(st.get("treasury", 0.0)) < fee:
			return {"ok": false, "reason": "Tesouro insuficiente para o contrato de PPP"}
		st["treasury"] = float(st.treasury) - fee
	project["funding"] = funding
	project["status"] = "obras"
	project["stage_index"] = 3
	project["started_month"] = _month_index(st)
	project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "obras", "note": "Obra aprovada com financiamento %s." % str(FUNDING_LABELS[funding])})
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("%s entra em obras com %s (M$ %s em %d meses)." % [str(project.label), str(FUNDING_LABELS[funding]), str(int(project.cost_total)), int(project.months_total)])
	st["news"] = news
	CausalLog.record(st, "projeto", "%s aprovado" % str(project.label), {"spending": float(project.cost_total)}, "A obra passa a consumir dotação e capacidade administrativa; o resultado só aparece após a operação.")
	return {"ok": true, "reason": "Obra aprovada"}

static func cancel(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	var project := _project(st, id)
	if project.is_empty() or str(project.get("status", "")) in ["operacional", "cancelado"]:
		return {"ok": false, "reason": "Projeto não pode ser cancelado"}
	var sunk := float(project.get("cost_spent", 0.0))
	project["status"] = "cancelado"
	project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "cancelado", "note": "Obra interrompida; custo afundado M$ %s." % str(int(sunk))})
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("%s é cancelado; M$ %s já gastos não retornam." % [str(project.label), str(int(sunk))])
	st["news"] = news
	CausalLog.record(st, "projeto", "%s cancelado" % str(project.label), {"approval": -0.5}, "Cancelar interrompe o cronograma e perde o custo afundado; não há devolução automática.")
	return {"ok": true, "reason": "Projeto cancelado"}

static func _roll(project: Dictionary, month: int) -> float:
	return float((hash(str(project.get("id", "")) + "-" + str(month)) % 1000)) / 1000.0

static func _complete(st: Dictionary, project: Dictionary) -> void:
	project["status"] = "operacional"
	project["stage_index"] = 6
	project["progress"] = 100.0
	project["months_left"] = 0.0
	project["completed_month"] = _month_index(st)
	project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "operacional", "note": "Obra concluída; entra em operação com custeio anual M$ %s." % str(int(project.get("op_cost", 0.0)))})
	var service_id := str(project.get("service", ""))
	if service_id != "" and st.get("services") is Dictionary and (st.services as Dictionary).has(service_id):
		var service: Dictionary = st.services[service_id]
		var gain := float(project.get("service_gain", 0.0))
		service["capacity"] = clampf(float(service.get("capacity", 50.0)) + gain * 0.55, 0.0, 100.0)
		service["coverage"] = clampf(float(service.get("coverage", 50.0)) + gain * 0.30, 0.0, 100.0)
		service["infrastructure"] = clampf(float(service.get("infrastructure", 50.0)) + gain, 0.0, 100.0)
	var jobs := int(project.get("jobs", 0))
	if jobs > 0:
		st["unemployment"] = clampf(float(st.get("unemployment", 8.2)) - minf(0.12, float(jobs) / 22000.0), 3.5, 18.0)
	var region := clampi(int(project.get("region", 0)), 0, 7)
	var support: Array = st.get("region_support", []) if st.get("region_support") is Array else []
	if region < support.size():
		support[region] = float(support[region]) + 1.8
		st["region_support"] = support
	var group_id := str(project.get("group", ""))
	if group_id != "" and st.get("social_groups") is Dictionary and (st.social_groups as Dictionary).has(group_id):
		var group: Dictionary = st.social_groups[group_id]
		group.satisfaction = clampf(float(group.get("satisfaction", 50.0)) + 2.0, 5.0, 95.0)
		group.approval = float(group.satisfaction)
	st["approval"] = clampf(float(st.get("approval", 45.0)) + 0.7, 0.0, 100.0)
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("%s entra em operação: %s beneficiários previstos, %d empregos de construção." % [str(project.label), str(_fmt_people(int(project.get("beneficiaries", 0)))), jobs])
	st["news"] = news
	CausalLog.record(st, "projeto", "%s concluído" % str(project.label),
		{"service": float(project.get("service_gain", 0.0)), "unemployment": -minf(0.12, float(jobs) / 22000.0), "approval": 0.7, "region": 1.8},
		"A obra concluída amplia a capacidade do serviço, cria emprego de construção e melhora o apoio regional; o custeio anual passa a pesar no orçamento.")

static func _evaluate(st: Dictionary, project: Dictionary) -> void:
	var capacity: float = float(Ministries.ministry_data(st, str(project.get("ministry", ""))).get("capacity", 50.0))
	var factor := clampf(float(capacity) / 60.0 - float(project.get("risk", 20.0)) / 400.0, 0.35, 1.08)
	var expected := int(project.get("beneficiaries", 0))
	var actual := int(round(float(expected) * factor))
	project["evaluated"] = true
	project["evaluation"] = {
		"expected_beneficiaries": expected, "actual_beneficiaries": actual,
		"expected_service": float(project.get("service_gain", 0.0)),
		"actual_service": float(project.get("service_gain", 0.0)) * factor,
		"overrun_pct": float(project.get("overrun", 0.0)),
		"quality": factor * 100.0,
	}
	project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "avaliacao", "note": "Avaliação: %s de %s beneficiários previstos; qualidade %.0f/100." % [_fmt_people(actual), _fmt_people(expected), factor * 100.0]})

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var capital := 0.0
	var opex_by_category := {}
	var completed := 0
	var delayed := 0
	var month := _month_index(st)
	for project in st.projects:
		var status := str(project.get("status", ""))
		if status == "obras":
			var category := str(project.get("category", ""))
			var payment := float(project.get("cost_total", 0.0)) / float(maxi(1, int(project.get("months_total", 1))))
			var funding := str(project.get("funding", "tesouro"))
			var envelope := BudgetSystem.category_envelope(st, category)
			if funding in ["tesouro", "titulos"] and envelope < payment * 0.85:
				project["status"] = "paralisada"
				project["months_paused"] = 0
				project["overrun"] = float(project.get("overrun", 0.0)) + 0.01
				project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "paralisada", "note": "Dotação mensal insuficiente (M$ %s necessários)." % str(int(payment))})
				var news: Array = st.get("news", []) if st.get("news") is Array else []
				news.push_front("%s paralisa: a dotação de %s não cobre a parcela mensal." % [str(project.label), str(BudgetSystem.category(category).get("label", category))])
				st["news"] = news
				CausalLog.record(st, "projeto", "%s paralisado" % str(project.label), {"spending": 0.0}, "Sem dotação mensal a obra não avança; o prazo escorrega e o custo tende a subir.")
				continue
			var ministry := Ministries.ministry_data(st, str(project.get("ministry", "")))
			var capacity := float(ministry.get("capacity", 50.0))
			var speed := clampf(0.55 + capacity / 130.0 - float(project.get("risk", 20.0)) / 300.0, 0.35, 1.25)
			project["months_left"] = float(project.get("months_left", 1.0)) - speed
			project["progress"] = clampf(float(project.get("progress", 0.0)) + 100.0 / float(maxi(1, int(project.get("months_total", 1)))) * speed, 0.0, 100.0)
			project["cost_spent"] = float(project.get("cost_spent", 0.0)) + payment
			capital += payment
			if funding in ["titulos", "externo"]:
				st["project_debt"] = float(st.get("project_debt", 0.0)) + payment
			var roll := _roll(project, month)
			var disruption := float(project.get("risk", 20.0)) / 100.0 * 0.08
			if roll < disruption:
				var delay := 1 + int(month % 2)
				project["months_left"] = float(project.get("months_left", 0.0)) + delay
				project["overrun"] = float(project.get("overrun", 0.0)) + 0.03
				project["cost_total"] = float(project.get("cost_total", 0.0)) * 1.03
				delayed += 1
				project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "atraso", "note": "Problema de execução: +%d mês(es), custo +3%%." % delay})
				var dnews: Array = st.get("news", []) if st.get("news") is Array else []
				dnews.push_front("%s sofre atraso de %d mês(es) e estouro de 3%% no custo." % [str(project.label), delay])
				st["news"] = dnews
				CausalLog.record(st, "projeto", "%s atrasou" % str(project.label), {"cost": float(project.cost_total) * 0.03}, "Capacidade administrativa baixa e risco de execução produziram atraso e custo adicional.")
			if float(project.get("months_left", 0.0)) <= 0.0:
				_complete(st, project)
				completed += 1
		elif status == "paralisada":
			project["months_paused"] = int(project.get("months_paused", 0)) + 1
			var category := str(project.get("category", ""))
			var payment := float(project.get("cost_total", 0.0)) / float(maxi(1, int(project.get("months_total", 1))))
			if BudgetSystem.category_envelope(st, category) >= payment * 0.85:
				project["status"] = "obras"
				project["history"].append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "status": "obras", "note": "Dotação restabelecida; obra retomada."})
				var news: Array = st.get("news", []) if st.get("news") is Array else []
				news.push_front("%s retoma as obras após a dotação ser restabelecida." % str(project.label))
				st["news"] = news
		elif status == "operacional":
			var opex := float(project.get("op_cost", 0.0)) / 12.0
			if str(project.get("funding", "")) == "ppp":
				opex *= 1.35
			var category := str(project.get("category", ""))
			opex_by_category[category] = float(opex_by_category.get(category, 0.0)) + opex
			if not bool(project.get("evaluated", false)) and int(project.get("completed_month", 0)) > 0 and month - int(project.completed_month) >= 12:
				_evaluate(st, project)
	if not opex_by_category.is_empty():
		st["project_opex"] = opex_by_category
	var total_opex := 0.0
	for value in opex_by_category.values():
		total_opex += float(value)
	return {"capital": capital, "opex": total_opex, "opex_by_category": opex_by_category, "completed": completed, "delayed": delayed}

static func _fmt_people(value: int) -> String:
	if value >= 1000000:
		return "%.1f mi" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%d mil" % int(round(float(value) / 1000.0))
	return str(value)

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var rows: Array = []
	for project in st.projects:
		rows.append(project.duplicate(true))
	return {"rows": rows, "active": active_count(st), "operational": operational_count(st), "catalog": catalog()}
