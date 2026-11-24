extends RefCounted
## C1 — Orçamento público.
##
## O orçamento é um plano anual em % do PIB, aprovado pelo parlamento e
## executado mês a mês. O que foi aprovado e o que foi efetivamente gasto são
## variáveis distintas: capacidade administrativa baixa executa menos, e a
## diferença aparece no relatório do governo. Nenhum valor é aplicado como
## bônus solto; a execução alimenta o tesouro, a dívida e os serviços.

const DATA_PATH := "res://config/public_administration.json"
const CausalLog := preload("res://scripts/sim/causal_log.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func fiscal() -> Dictionary:
	var value: Variant = config().get("fiscal", {})
	return value if value is Dictionary else {}

static func categories() -> Array:
	var value: Variant = config().get("budget_categories", [])
	return value if value is Array else []

static func category(id: String) -> Dictionary:
	for entry in categories():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func annual_gdp(st: Dictionary) -> float:
	return maxf(20.0, float(st.get("gdp", 100.0))) * float(fiscal().get("gdp_unit_millions", 1000.0))

static func monthly_gdp(st: Dictionary) -> float:
	return annual_gdp(st) / 12.0

static func _default_allocations() -> Dictionary:
	var alloc := {}
	for entry in categories():
		alloc[str(entry.get("id", ""))] = float(entry.get("base_share", 0.0))
	return alloc

static func init_state(st: Dictionary) -> void:
	var alloc := _default_allocations()
	st["budget"] = {
		"year": int(st.get("date_year", 2027)),
		"status": "approved",
		"allocations": alloc.duplicate(true),
		"approved_allocations": alloc.duplicate(true),
		"executed": {},
		"revenue": 0.0,
		"capital": 0.0,
		"submitted_month": "",
		"last_vote": {},
		"expenditure_month": 0.0,
	}
	st["treasury"] = annual_gdp(st) * float(fiscal().get("treasury_buffer_pct_gdp", 0.5)) / 100.0
	st["fiscal_history"] = []
	st["tax_revenue_share"] = 0.0

## Migração idempotente. Saves anteriores à fase C recebem um orçamento base
## aprovado, sem sobrescrever indicadores já salvos.
static func ensure(st: Dictionary) -> void:
	if not (st.get("treasury") is float) and not (st.get("treasury") is int):
		st["treasury"] = annual_gdp(st) * float(fiscal().get("treasury_buffer_pct_gdp", 0.5)) / 100.0
	if not (st.get("fiscal_history") is Array):
		st["fiscal_history"] = []
	if not (st.get("budget") is Dictionary):
		var alloc := _default_allocations()
		st["budget"] = {
			"year": int(st.get("date_year", 2027)), "status": "approved",
			"allocations": alloc.duplicate(true), "approved_allocations": alloc.duplicate(true),
			"executed": {}, "revenue": 0.0, "capital": 0.0,
			"submitted_month": "", "last_vote": {}, "expenditure_month": 0.0,
		}
	var b: Dictionary = st.budget
	if not b.has("year"):
		b["year"] = int(st.get("date_year", 2027))
	if not (str(b.get("status", "")) in ["approved", "draft", "rejected"]):
		b["status"] = "approved"
	if not (b.get("allocations") is Dictionary):
		b["allocations"] = _default_allocations()
	if not (b.get("approved_allocations") is Dictionary):
		b["approved_allocations"] = _default_allocations()
	if not (b.get("executed") is Dictionary):
		b["executed"] = {}
	if not (b.get("last_vote") is Dictionary):
		b["last_vote"] = {}
	for key in ["revenue", "capital", "expenditure_month"]:
		if not b.has(key):
			b[key] = 0.0
	for entry in categories():
		var id := str(entry.get("id", ""))
		if not (b.allocations as Dictionary).has(id):
			b.allocations[id] = float(entry.get("base_share", 0.0))
		if not (b.approved_allocations as Dictionary).has(id):
			b.approved_allocations[id] = float(entry.get("base_share", 0.0))

static func allocations(st: Dictionary) -> Dictionary:
	ensure(st)
	var b: Dictionary = st.budget
	return b.approved_allocations if b.get("status", "approved") == "approved" else b.allocations

static func planned_share(st: Dictionary, id: String) -> float:
	return float(allocations(st).get(id, 0.0))

static func total_planned(st: Dictionary) -> float:
	var total := 0.0
	for entry in categories():
		total += planned_share(st, str(entry.get("id", "")))
	return total

static func expense_share(st: Dictionary) -> float:
	var total := 0.0
	var b: Dictionary = st.get("budget", {})
	var executed: Dictionary = b.get("executed", {}) if b.get("executed") is Dictionary else {}
	for value in executed.values():
		total += float(value)
	return total / annual_gdp(st) * 12.0 * 100.0

## Abre a revisão do plano: o texto aprovado continua em vigor até a votação.
static func open_draft(st: Dictionary) -> void:
	ensure(st)
	var b: Dictionary = st.budget
	b["status"] = "draft"
	b["allocations"] = (b.get("approved_allocations", {}) as Dictionary).duplicate(true)

static func adjust(st: Dictionary, id: String, delta: float) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo prepara o orçamento"}
	var entry := category(id)
	if entry.is_empty():
		return {"ok": false, "reason": "Categoria desconhecida"}
	ensure(st)
	var b: Dictionary = st.budget
	if b.get("status", "approved") != "draft":
		open_draft(st)
	var current := float((b.allocations as Dictionary).get(id, float(entry.get("base_share", 0.0))))
	var lo := float(entry.get("floor_share", 0.0))
	var hi := float(entry.get("cap_share", current + 1.0))
	var target := clampf(current + delta, lo, hi)
	if absf(target - current) < 0.001:
		return {"ok": false, "reason": "Limite da categoria atingido"}
	b.allocations[id] = target
	# O ajuste é uma decisão interna, mas afeta a negociação: o jogador vê o
	# impacto no resultado antes de submeter o texto ao parlamento.
	return {"ok": true, "share": target, "delta": target - current, "total": total_planned(st)}

static func _support_score(st: Dictionary) -> float:
	var chamber := maxi(1, int(st.get("chamber_seats", 0)))
	# `coalition_seats` é o total da base (própria bancada + parceiros), como em
	# `_accept_coalition`; somar `lower_house_seats` contava a bancada duas vezes.
	var gov_seats := int(st.get("coalition_seats", 0))
	if gov_seats <= 0:
		gov_seats = int(st.get("lower_house_seats", 0))
	gov_seats = mini(gov_seats, chamber)
	var share := clampf(float(gov_seats) / float(chamber), 0.0, 1.0)
	var revenue := float(st.get("tax_revenue_share", 25.0))
	# Antes do primeiro mês fechado a arrecadação ainda é 0; sem estimativa, o
	# primeiro orçamento era sempre rejeitado por "receita zero".
	if revenue <= 0.0:
		revenue = 25.0
	var spend := total_planned(st)
	var deficit := spend - revenue
	# Uma maioria simples precisa conseguir aprovar o próprio plano; sem isso o
	# mandato trava no primeiro orçamento. O déficit, a impopularidade e a
	# instabilidade continuam derrubando o texto (ver penalidades abaixo).
	var support := 0.20 + share * 0.62
	support += (float(st.get("approval", 45.0)) - 45.0) * 0.004
	support += (float(st.get("coalition_stability", 60.0)) - 50.0) * 0.002
	support -= maxf(0.0, deficit) * 0.012
	support -= maxf(0.0, revenue - 28.0) * 0.004
	support -= maxf(0.0, float(st.get("scandal_penalty", 0.0))) * 0.004
	var investment := 0.0
	for entry in categories():
		if str(entry.get("type", "")) == "investment":
			investment += planned_share(st, str(entry.get("id", "")))
	support += minf(0.04, maxf(0.0, investment - 4.5) * 0.01)
	# Relação média com os aliados pesa na disciplina, não substitui os votos.
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	if not partners.is_empty():
		var relation_sum := 0.0
		var relations: Dictionary = st.get("party_relations", {}) if st.get("party_relations") is Dictionary else {}
		for party in partners:
			var pair := [str(st.get("abbr", "")), str(party)]
			pair.sort()
			relation_sum += float(relations.get("%s|%s" % [str(pair[0]), str(pair[1])], 0.0))
		support += relation_sum / float(partners.size()) * 0.0006
	# Variação de ±1% (±5 cadeiras), não de ±3%: a aritmética do plenário não
	# pode derrubar sozinha um plano que fecha a maioria.
	var wobble := float(hash("%d-%d-orcamento" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]) % 20) / 1000.0 - 0.01
	return clampf(support + wobble, 0.05, 0.93)

## Apoio estimado, exibido antes da votação: não é promessa de resultado.
static func support_preview(st: Dictionary) -> Dictionary:
	var score := _support_score(st)
	var chamber := maxi(1, int(st.get("chamber_seats", 0)))
	var ayes := int(round(float(chamber) * score))
	return {"score": score, "ayes": ayes, "chamber": chamber, "majority": int(st.get("majority", int(chamber / 2) + 1))}

static func submit(st: Dictionary, _country: Dictionary = {}) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo submete orçamento"}
	ensure(st)
	var b: Dictionary = st.budget
	var preview := support_preview(st)
	var ayes := int(preview.ayes)
	var chamber := int(preview.chamber)
	var abstain := int(round(float(chamber - ayes) * 0.22))
	var nayes := maxi(0, chamber - ayes - abstain)
	var approved := ayes >= int(preview.majority)
	var month := "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
	var effects := {}
	if approved:
		b["status"] = "approved"
		b["approved_allocations"] = (b.allocations as Dictionary).duplicate(true)
		effects = {"approval": 0.8, "coalition_cohesion": 0.5}
		st["approval"] = clampf(float(st.get("approval", 45.0)) + 0.8, 0.0, 100.0)
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) + 0.5, 10.0, 100.0)
	else:
		b["status"] = "rejected"
		effects = {"approval": -1.2, "coalition_cohesion": -2.0}
		st["approval"] = clampf(float(st.get("approval", 45.0)) - 1.2, 0.0, 100.0)
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - 2.0, 10.0, 100.0)
	b["submitted_month"] = month
	b["last_vote"] = {"month": month, "ayes": ayes, "nayes": nayes, "abstain": abstain, "approved": approved, "support": preview.score}
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("Orçamento %s: %d a favor, %d contra, %d abstenções (despesa %.1f%% do PIB)." % [
		"aprovado" if approved else "rejeitado", ayes, nayes, abstain, total_planned(st)])
	st["news"] = news
	CausalLog.record(st, "orcamento", "orçamento %s no parlamento" % ("aprovado" if approved else "rejeitado"), effects,
		"Apoio estimado %.0f%% com %d de %d cadeiras; a execução do plano aprovado começa no mês seguinte." % [preview.score * 100.0, ayes, chamber])
	return {"ok": true, "approved": approved, "vote": b.last_vote, "reason": "Orçamento aprovado" if approved else "Orçamento rejeitado; o plano anterior continua em execução"}

static func _avg_capacity(st: Dictionary) -> float:
	var data: Dictionary = st.get("ministry_admin", {}) if st.get("ministry_admin") is Dictionary else {}
	if data.is_empty():
		return 50.0
	var total := 0.0
	for entry in data.values():
		total += float((entry as Dictionary).get("capacity", 50.0))
	return total / float(data.size())

static func execution_efficiency(st: Dictionary, entry: Dictionary) -> float:
	var capacity := _avg_capacity(st)
	var base := float(fiscal().get("execution_base", 0.86))
	var eff := base + (capacity - 50.0) * 0.004 + (float(st.get("approval", 45.0)) - 45.0) * 0.001
	var kind := str(entry.get("type", "operational"))
	if kind == "mandatory":
		eff = minf(1.02, eff + 0.08)
	elif kind == "investment":
		eff = eff - 0.04 - maxf(0.0, 55.0 - capacity) * 0.003
	elif kind == "discretionary":
		eff = eff - 0.02
	return clampf(eff, 0.40, 1.02)

static func category_envelope(st: Dictionary, id: String) -> float:
	var entry := category(id)
	if entry.is_empty():
		return 0.0
	return planned_share(st, id) / 100.0 * monthly_gdp(st) * execution_efficiency(st, entry)

static func rollover(st: Dictionary) -> void:
	ensure(st)
	var b: Dictionary = st.budget
	var year := int(st.get("date_year", 0))
	if int(b.get("year", year)) == year:
		return
	var history: Array = st.get("fiscal_history", []) if st.get("fiscal_history") is Array else []
	history.push_front({
		"year": int(b.get("year", year - 1)),
		"revenue": float(b.get("revenue", 0.0)),
		"expenditure": expense_share(st) if float(b.get("revenue", 0.0)) > 0.0 else 0.0,
		"status": str(b.get("status", "approved")),
	})
	if history.size() > 8:
		history = history.slice(0, 8)
	st["fiscal_history"] = history
	b["year"] = year
	b["status"] = "draft"
	b["allocations"] = (b.get("approved_allocations", _default_allocations()) as Dictionary).duplicate(true)
	b["executed"] = {}
	b["revenue"] = 0.0
	b["capital"] = 0.0

## Executa o plano aprovado. O serviço da dívida fica de fora: os juros são
## lançados pelo sistema de dívida com o estoque real, sem dupla contagem.
static func monthly(st: Dictionary) -> Dictionary:
	rollover(st)
	ensure(st)
	var b: Dictionary = st.budget
	var total := 0.0
	var detail := {}
	var approved_total := 0.0
	for entry in categories():
		var id := str(entry.get("id", ""))
		var plan_m := planned_share(st, id) / 100.0 * monthly_gdp(st)
		approved_total += plan_m
		if str(entry.get("type", "")) == "debt_service":
			continue
		var actual := plan_m * execution_efficiency(st, entry)
		detail[id] = actual
		b.executed[id] = float((b.executed as Dictionary).get(id, 0.0)) + actual
		total += actual
	st["treasury"] = float(st.get("treasury", 0.0)) - total
	b["expenditure_month"] = total
	b["planned_month"] = approved_total
	return {"total": total, "planned": approved_total, "detail": detail}

## Despesa operacional de projetos concluídos entra no orçamento e no tesouro,
## mas não é capital: é custeio permanente do serviço.
static func record_opex(st: Dictionary, by_category: Dictionary) -> float:
	ensure(st)
	var b: Dictionary = st.budget
	var total := 0.0
	for id in by_category.keys():
		var amount := float(by_category[id])
		if amount <= 0.0:
			continue
		b.executed[id] = float((b.executed as Dictionary).get(id, 0.0)) + amount
		total += amount
	if total > 0.0:
		st["treasury"] = float(st.get("treasury", 0.0)) - total
	return total

static func balance(st: Dictionary) -> Dictionary:
	var revenue := float(st.get("tax_revenue", {}).get("total", 0.0))
	var interest := float(st.get("debt_stats", {}).get("interest", 0.0))
	var b: Dictionary = st.get("budget", {})
	var spend := float(b.get("expenditure_month", 0.0)) + float(b.get("opex_month", 0.0)) + interest
	return {
		"revenue": revenue, "spending": spend, "interest": interest,
		"primary": revenue - (spend - interest), "overall": revenue - spend,
	}

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var b: Dictionary = st.budget
	return {
		"status": str(b.get("status", "approved")),
		"year": int(b.get("year", 0)),
		"planned_share": total_planned(st),
		"treasury": float(st.get("treasury", 0.0)),
		"executed": b.get("executed", {}).duplicate(true),
		"last_vote": b.get("last_vote", {}).duplicate(true),
	}
