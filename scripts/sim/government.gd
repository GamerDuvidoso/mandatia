extends RefCounted
## C7 — Fachada da administração pública.
##
## Orquestra os módulos na ordem em que o dinheiro realmente se move:
## arrecadação -> orçamento -> custeio de projetos -> capacidade ministerial ->
## serviços -> dívida. A fachada também traduz o resultado fiscal em efeitos
## sobre crescimento, aprovação, grupos sociais e relação com organizações,
## sempre a partir de variáveis mensuráveis. `main.gd` só chama esta fachada e
## desenha o resultado.

const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const Taxation := preload("res://scripts/sim/taxation_system.gd")
const Ministries := preload("res://scripts/sim/ministry_system.gd")
const PublicServices := preload("res://scripts/sim/public_services_system.gd")
const Projects := preload("res://scripts/sim/public_project_system.gd")
const Debt := preload("res://scripts/sim/debt_system.gd")
const PoliticalRelations := preload("res://scripts/sim/political_relations.gd")
const CausalLog := preload("res://scripts/sim/causal_log.gd")

static func init_state(st: Dictionary) -> void:
	BudgetSystem.init_state(st)
	Taxation.init_state(st)
	Ministries.init_state(st)
	PublicServices.init_state(st)
	Projects.init_state(st)
	Debt.init_state(st)
	st["fiscal"] = _empty_fiscal()
	# Receita de posse: sem isso, o primeiro orçamento era votado contra 0% de
	# receita e caía mesmo quando o plano era viável.
	var estimate := Taxation.estimate(st)
	st["tax_revenue"] = estimate
	st["tax_revenue_share"] = float(estimate.get("share", 0.0))
	st["tax_burden_effect"] = Taxation.growth_effect(st)

static func ensure(st: Dictionary) -> void:
	BudgetSystem.ensure(st)
	Taxation.ensure(st)
	Ministries.ensure(st)
	PublicServices.ensure(st)
	Projects.ensure(st)
	Debt.ensure(st)
	if not (st.get("fiscal") is Dictionary):
		st["fiscal"] = _empty_fiscal()

static func _empty_fiscal() -> Dictionary:
	return {
		"revenue": 0.0, "spending": 0.0, "primary": 0.0, "overall": 0.0,
		"interest": 0.0, "capital": 0.0, "opex": 0.0, "ratio": 0.0,
		"service_index": 50.0, "capacity": 50.0, "tax_share": 0.0,
	}

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var revenue := Taxation.monthly(st)
	var budget := BudgetSystem.monthly(st)
	var projects := Projects.monthly(st)
	var opex := BudgetSystem.record_opex(st, projects.get("opex_by_category", {}) if projects.get("opex_by_category") is Dictionary else {})
	var b: Dictionary = st.budget
	b["opex_month"] = opex
	var ministries := Ministries.monthly(st)
	var services := PublicServices.monthly(st)
	var non_interest := float(budget.get("total", 0.0)) + opex
	var debt := Debt.monthly(st, float(revenue.get("total", 0.0)), non_interest)

	var tax_share := float(revenue.get("share", 0.0))
	var service_index := float(services.get("index", 50.0))
	var capacity := float(ministries.get("capacity", 50.0))
	var ratio := float(debt.get("ratio", 0.0))
	var primary := float(debt.get("primary", 0.0))
	var annual := BudgetSystem.annual_gdp(st)

	# C7: o resultado fiscal e a entrega de serviços alteram a economia, a
	# aprovação e a coalizão. Não há bônus solto: cada efeito tem origem no
	# fluxo que o produziu.
	var tax_effect := float(st.get("tax_burden_effect", 0.0))
	var investment_impulse := float(projects.get("capital", 0.0)) / annual * 0.30
	st["economy"] = clampf(float(st.get("economy", 2.4)) + tax_effect + investment_impulse, -2.0, 6.0)
	var service_effect := (service_index - 50.0) * 0.015
	var capacity_effect := (capacity - 50.0) * 0.010
	var debt_effect := -maxf(0.0, ratio - 90.0) * 0.010
	var tax_pressure := -maxf(0.0, tax_share - 30.0) * 0.020
	st["approval"] = clampf(float(st.get("approval", 45.0)) + service_effect + capacity_effect + debt_effect + tax_pressure, 0.0, 100.0)
	st["credibility"] = clampf(float(st.get("credibility", 31.0)) + clampf(primary / annual * 12.0 * 100.0, -1.0, 1.0) * 0.12 - maxf(0.0, ratio - 80.0) * 0.006, 0.0, 100.0)
	st["coalition_stability"] = PoliticalRelations.stability(st)

	# Grupos sociais sentem cobertura e qualidade, não o número do orçamento.
	var social: Dictionary = st.get("social_groups", {}) if st.get("social_groups") is Dictionary else {}
	for entry in PublicServices.definitions():
		var service_id := str(entry.get("id", ""))
		var service: Dictionary = PublicServices.service(st, service_id)
		var delta := (float(service.get("quality", 50.0)) - 50.0) * 0.010 + (float(service.get("coverage", 50.0)) - 55.0) * 0.004
		for group_id in entry.get("linked_groups", []):
			if social.has(str(group_id)):
				var group: Dictionary = social[str(group_id)]
				group.satisfaction = clampf(float(group.get("satisfaction", 50.0)) + delta, 5.0, 95.0)
				group.approval = float(group.satisfaction)

	# Organizações: carga tributária pesa sobre empresas; entrega social melhora
	# a relação com trabalhadores. Ambas são consequências do mesmo orçamento.
	var groups: Dictionary = st.get("interest_groups", {}) if st.get("interest_groups") is Dictionary else {}
	if groups.has("business_association"):
		var business: Dictionary = groups.business_association
		if tax_share > 27.0:
			business.relationship = clampf(float(business.get("relationship", 0.0)) - (tax_share - 27.0) * 0.10, -100.0, 100.0)
	if groups.has("labor_federation"):
		var labor: Dictionary = groups.labor_federation
		if service_index > 52.0:
			labor.relationship = clampf(float(labor.get("relationship", 0.0)) + (service_index - 52.0) * 0.04, -100.0, 100.0)

	var fiscal := {
		"revenue": float(revenue.get("total", 0.0)), "spending": float(debt.get("spending", 0.0)),
		"primary": primary, "overall": float(debt.get("overall", 0.0)), "interest": float(debt.get("interest", 0.0)),
		"capital": float(projects.get("capital", 0.0)), "opex": opex, "ratio": ratio,
		"service_index": service_index, "capacity": capacity, "tax_share": tax_share,
		"borrowing": float(debt.get("borrowing", 0.0)), "amortization": float(debt.get("amortization", 0.0)),
		"budget_status": str(b.get("status", "approved")), "projects_active": int(Projects.active_count(st)),
		"projects_completed": int(projects.get("completed", 0)), "projects_delayed": int(projects.get("delayed", 0)),
	}
	st["fiscal"] = fiscal
	CausalLog.record(st, "orcamento", "fechamento fiscal do mês",
		{"revenue": fiscal.revenue, "spending": fiscal.spending, "primary": primary, "debt": float(debt.get("ratio", ratio))},
		"Receita M$ %s, despesa M$ %s, resultado primário M$ %s; capacidade %.0f, serviços %.0f, dívida %.1f%% do PIB." % [
			str(int(fiscal.revenue)), str(int(fiscal.spending)), str(int(primary)), capacity, service_index, ratio])
	return fiscal

static func report(st: Dictionary) -> Dictionary:
	ensure(st)
	var budget := BudgetSystem.summary(st)
	var taxes := Taxation.summary(st)
	var ministries := Ministries.summary(st)
	var services := PublicServices.summary(st)
	var projects := Projects.summary(st)
	var debt := Debt.summary(st)
	var fiscal: Dictionary = st.get("fiscal", {}) if st.get("fiscal") is Dictionary else _empty_fiscal()
	return {
		"budget": budget, "taxes": taxes, "ministries": ministries, "services": services,
		"projects": projects, "debt": debt, "fiscal": fiscal.duplicate(true),
		"balance": BudgetSystem.balance(st), "factors": factors(st),
	}

static func factors(st: Dictionary) -> Array:
	ensure(st)
	var rows: Array = []
	var fiscal: Dictionary = st.get("fiscal", {}) if st.get("fiscal") is Dictionary else {}
	var balance := BudgetSystem.balance(st)
	var revenue := float(balance.get("revenue", 0.0))
	var primary := float(balance.get("primary", 0.0))
	var overall := float(balance.get("overall", 0.0))
	rows.append("Receita efetiva M$ %s; despesa M$ %s; primário M$ %s; total M$ %s." % [
		str(int(revenue)), str(int(balance.get("spending", 0.0))), str(int(primary)), str(int(overall))])
	rows.append("Carga tributária %.1f%% do PIB; efeito estimado no crescimento %+.2f p.p. no mês." % [
		float(fiscal.get("tax_share", st.get("tax_revenue_share", 0.0))), float(st.get("tax_burden_effect", 0.0))])
	rows.append("Capacidade administrativa média %.0f/100; execução orçamentária depende dela e da dotação de cada pasta." % float(fiscal.get("capacity", 50.0)))
	rows.append("Índice de serviços %.0f/100; cobertura e qualidade seguem capacidade, efetivo e infraestrutura concluída." % float(fiscal.get("service_index", 50.0)))
	var active := Projects.active_count(st)
	var operational := Projects.operational_count(st)
	rows.append("Projetos: %d em obra/paralisados, %d em operação; capital do mês M$ %s." % [active, operational, str(int(fiscal.get("capital", 0.0)))])
	var debt_stats: Dictionary = st.get("debt_stats", {}) if st.get("debt_stats") is Dictionary else {}
	rows.append("Dívida %.1f%% do PIB; juros do mês M$ %s; taxa média %.1f%%; financiamento do déficit M$ %s." % [
		float(st.get("debt", 0.0)), str(int(debt_stats.get("interest", 0.0))), float(debt_stats.get("average_rate", 0.0)), str(int(debt_stats.get("borrowing", 0.0)))])
	var lows: Array = []
	for row in Ministries.summary(st).get("rows", []):
		if float(row.get("capacity", 50.0)) < 42.0:
			lows.append(str(row.get("label", "")))
	if not lows.is_empty():
		rows.append("Pastas com capacidade abaixo de 42/100: %s." % ", ".join(PackedStringArray(lows)))
	return rows
