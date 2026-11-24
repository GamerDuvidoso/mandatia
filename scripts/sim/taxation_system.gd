extends RefCounted
## C2 — Tributação e receita.
##
## Cada tributo tem base econômica, alíquota, conformidade e elasticidade.
## Alíquota maior não gera receita proporcional: a base reage, a conformidade
## cai e a administração tributária limita a coleta. A receita resultante
## alimenta o tesouro e o cálculo do resultado fiscal.

const DATA_PATH := "res://config/public_administration.json"
const CausalLog := preload("res://scripts/sim/causal_log.gd")
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func definitions() -> Array:
	var value: Variant = config().get("taxes", [])
	return value if value is Array else []

static func definition(id: String) -> Dictionary:
	for entry in definitions():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func _avg_capacity(st: Dictionary) -> float:
	var data: Dictionary = st.get("ministry_admin", {}) if st.get("ministry_admin") is Dictionary else {}
	if data.is_empty():
		return 50.0
	var total := 0.0
	for entry in data.values():
		total += float((entry as Dictionary).get("capacity", 50.0))
	return total / float(data.size())

static func init_state(st: Dictionary) -> void:
	var taxes := {}
	for entry in definitions():
		taxes[str(entry.get("id", ""))] = {
			"rate": float(entry.get("rate", 0.0)),
			"compliance": float(entry.get("compliance", 0.75)),
		}
	st["taxes"] = taxes
	st["tax_revenue"] = {"total": 0.0, "share": 0.0, "by_tax": {}}
	st["tax_revenue_share"] = 0.0
	st["tax_burden_effect"] = 0.0

static func ensure(st: Dictionary) -> void:
	if not (st.get("taxes") is Dictionary):
		init_state(st)
		return
	for entry in definitions():
		var id := str(entry.get("id", ""))
		if not (st.taxes as Dictionary).has(id):
			st.taxes[id] = {"rate": float(entry.get("rate", 0.0)), "compliance": float(entry.get("compliance", 0.75))}
		var tax: Dictionary = st.taxes[id]
		for key in ["rate", "compliance"]:
			if not tax.has(key):
				tax[key] = float(entry.get(key, 0.0))
		tax["rate"] = clampf(float(tax.rate), float(entry.get("min_rate", 0.0)), float(entry.get("max_rate", 60.0)))
		tax["compliance"] = clampf(float(tax.compliance), 0.35, 0.98)
	if not (st.get("tax_revenue") is Dictionary):
		st["tax_revenue"] = {"total": 0.0, "share": 0.0, "by_tax": {}}
	if not st.has("tax_revenue_share"):
		st["tax_revenue_share"] = 0.0
	if not st.has("tax_burden_effect"):
		st["tax_burden_effect"] = 0.0

static func rate(st: Dictionary, id: String) -> float:
	ensure(st)
	return float((st.taxes as Dictionary).get(id, {}).get("rate", definition(id).get("rate", 0.0)))

static func _behavior(entry: Dictionary, current: float) -> float:
	var neutral := maxf(1.0, float(entry.get("neutral_rate", current)))
	var elasticity := float(entry.get("elasticity", 0.3))
	var excess := maxf(0.0, current - neutral)
	var below := maxf(0.0, neutral - current)
	var value := 1.0 - elasticity * (excess / neutral) * 0.8
	value += elasticity * 0.22 * (below / neutral)
	return clampf(value, 0.55, 1.10)

static func _activity(entry: Dictionary, st: Dictionary) -> float:
	var kind := str(entry.get("activity", "labor"))
	var growth := float(st.get("economy", 2.4)) - 2.5
	var unemployment := float(st.get("unemployment", 8.2)) - 7.0
	var inflation := maxf(0.0, float(st.get("inflation", 4.8)) - 4.0)
	match kind:
		"labor":
			return 1.0 + growth * 0.008 - unemployment * 0.004
		"capital":
			return 1.0 + growth * 0.012 - inflation * 0.001
		"consumption":
			return 1.0 + growth * 0.006 - inflation * 0.002
		"trade":
			return 1.0 + growth * 0.010
	return 1.0

## Calcula a receita sem mover tesouro, orçamento ou conformidade. Usado na
## posse para que o primeiro orçamento já seja negociado com a receita real.
static func estimate(st: Dictionary) -> Dictionary:
	ensure(st)
	return _revenue(st, false)

static func _revenue(st: Dictionary, mutate_compliance: bool) -> Dictionary:
	var annual := BudgetSystem.annual_gdp(st)
	var admin := _avg_capacity(st)
	var by_tax := {}
	var total := 0.0
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var tax: Dictionary = st.taxes[id]
		var current := float(tax.rate)
		var neutral := maxf(1.0, float(entry.get("neutral_rate", current)))
		var excess := maxf(0.0, current - neutral)
		if mutate_compliance:
			var target_compliance := float(entry.get("compliance", 0.75)) + (admin - 50.0) * 0.0025 - (excess / neutral) * 0.05
			tax["compliance"] = clampf(float(tax.compliance) + (clampf(target_compliance, 0.35, 0.96) - float(tax.compliance)) * 0.06, 0.35, 0.96)
		var base_m := float(entry.get("base_share", 0.0)) / 100.0 * annual / 12.0
		var revenue := base_m * current / 100.0 * float(tax.compliance) * _behavior(entry, current) * _activity(entry, st)
		by_tax[id] = revenue
		total += revenue
	return {"total": total, "share": total / annual * 12.0 * 100.0, "by_tax": by_tax}

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var computed := _revenue(st, true)
	st["tax_revenue"] = computed
	st["tax_revenue_share"] = float(computed.share)
	st["tax_burden_effect"] = growth_effect(st)
	var b: Dictionary = st.get("budget", {}) if st.get("budget") is Dictionary else {}
	if not b.is_empty():
		b["revenue"] = float(b.get("revenue", 0.0)) + float(computed.total)
	st["treasury"] = float(st.get("treasury", 0.0)) + float(computed.total)
	return st.tax_revenue

## Efeito da carga e da composição tributária sobre o crescimento do mês.
static func growth_effect(st: Dictionary) -> float:
	var burden := float(st.get("tax_revenue_share", 25.0))
	var effect := 0.0
	if burden > 27.0:
		effect -= (burden - 27.0) * 0.03
	elif burden < 20.0:
		effect += (20.0 - burden) * 0.012
	var corporate := definition("empresas")
	if not corporate.is_empty():
		var excess := maxf(0.0, rate(st, "empresas") - float(corporate.get("neutral_rate", 25.0)))
		effect -= excess * 0.004
	return clampf(effect, -0.35, 0.15)

static func adjust(st: Dictionary, id: String, delta: float) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo altera tributos"}
	var entry := definition(id)
	if entry.is_empty():
		return {"ok": false, "reason": "Tributo desconhecido"}
	ensure(st)
	var tax: Dictionary = st.taxes[id]
	var before := float(tax.rate)
	var after := clampf(before + delta, float(entry.get("min_rate", 0.0)), float(entry.get("max_rate", 60.0)))
	if absf(after - before) < 0.001:
		return {"ok": false, "reason": "Limite da alíquota atingido"}
	tax["rate"] = after
	var change := after - before
	var effects := {}
	var approval := -change * 0.18
	if change < 0.0:
		approval = absf(change) * 0.08
	st["approval"] = clampf(float(st.get("approval", 45.0)) + approval, 0.0, 100.0)
	if approval != 0.0:
		effects["approval"] = approval
	# Grupos organizados reagem à alíquota que incide sobre sua base.
	var groups: Dictionary = st.get("interest_groups", {}) if st.get("interest_groups") is Dictionary else {}
	var hit := "business_association" if str(entry.get("kind", "")) in ["corporate", "property", "wealth", "trade"] else "labor_federation"
	if groups.has(hit):
		var org: Dictionary = groups[hit]
		var relation := -change * 0.55 if hit == "business_association" else change * 0.15
		org.relationship = clampf(float(org.get("relationship", 0.0)) + relation, -100.0, 100.0)
		effects["relationship"] = relation
	var social: Dictionary = st.get("social_groups", {}) if st.get("social_groups") is Dictionary else {}
	for group_id in ["entrepreneurs", "high_income"]:
		if social.has(group_id):
			var group: Dictionary = social[group_id]
			var hit_value := -change * 0.25
			group.satisfaction = clampf(float(group.get("satisfaction", 50.0)) + hit_value, 5.0, 95.0)
			effects["satisfaction_" + group_id] = hit_value
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("%s: alíquota %+.1f p.p., de %.1f%% para %.1f%%. A base tributária e a conformidade reagem ao novo patamar." % [
		str(entry.get("label", id)), change, before, after])
	st["news"] = news
	CausalLog.record(st, "tributos", "%s %+.1f p.p." % [str(entry.get("label", id)), change], effects,
		"Alíquota alterada de %.1f%% para %.1f%%; a receita efetiva depende da base, da conformidade e da resposta econômica." % [before, after])
	return {"ok": true, "rate": after, "delta": change, "reason": "%s ajustado para %.1f%%" % [str(entry.get("label", id)), after]}

static func total_revenue(st: Dictionary) -> float:
	ensure(st)
	return float((st.get("tax_revenue", {}) as Dictionary).get("total", 0.0))

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	return {"total": total_revenue(st), "share": float(st.get("tax_revenue_share", 0.0)), "by_tax": (st.get("tax_revenue", {}) as Dictionary).get("by_tax", {}).duplicate(true), "burden_effect": float(st.get("tax_burden_effect", 0.0))}
