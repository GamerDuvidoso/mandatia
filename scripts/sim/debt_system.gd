extends RefCounted
## C5 — Dívida pública e financiamento.
##
## O estoque é mantido em M$ e convertido para % do PIB. Juros incidem sobre
## cada tranche; o resultado primário e o resultado total são calculados a
## partir das mesmas receitas e despesas que o tesouro já movimentou, sem
## contar o mesmo fluxo duas vezes. Emitir dívida financia o caixa; amortizar
## consome caixa. O endividamento não é tratado como bom ou ruim por si só:
## depende do custo, do prazo e do que ele financia.

const DATA_PATH := "res://config/public_administration.json"
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
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

static func init_state(st: Dictionary) -> void:
	var annual := BudgetSystem.annual_gdp(st)
	var stock := maxf(0.0, float(st.get("debt", 60.0)) / 100.0 * annual)
	st["debt_stock"] = stock
	st["debt_book"] = [{"id": "legado", "amount": stock, "rate": float(fiscal().get("interest_base_rate", 6.5)), "months_left": 60, "source": "estoque inicial"}]
	st["debt_stats"] = {}
	st["debt_history"] = []
	st["project_debt"] = 0.0

static func ensure(st: Dictionary) -> void:
	if not (st.get("debt_stock") is float) and not (st.get("debt_stock") is int):
		init_state(st)
		return
	if not (st.get("debt_book") is Array) or (st.debt_book as Array).is_empty():
		st["debt_book"] = [{"id": "legado", "amount": float(st.get("debt_stock", 0.0)), "rate": float(fiscal().get("interest_base_rate", 6.5)), "months_left": 60, "source": "estoque inicial"}]
	if not (st.get("debt_history") is Array):
		st["debt_history"] = []
	if not (st.get("debt_stats") is Dictionary):
		st["debt_stats"] = {}
	if not st.has("project_debt"):
		st["project_debt"] = 0.0

static func _stock_from_book(st: Dictionary) -> float:
	ensure(st)
	var total := 0.0
	for tranche in st.debt_book:
		total += float((tranche as Dictionary).get("amount", 0.0))
	return total

static func rate_for(st: Dictionary, ratio: float) -> float:
	var base := float(fiscal().get("interest_base_rate", 6.5))
	var risk := maxf(0.0, ratio - 60.0) * 0.06
	risk += maxf(0.0, 50.0 - float(st.get("credibility", 31.0))) * 0.04
	risk += maxf(0.0, 30.0 - float(st.get("approval", 45.0))) * 0.02
	return clampf(base + risk, 3.0, 22.0)

static func _issue(st: Dictionary, amount: float, source: String) -> Dictionary:
	if amount <= 0.0:
		return {}
	var annual := BudgetSystem.annual_gdp(st)
	var ratio := float(st.get("debt_stock", 0.0)) / annual * 100.0
	var tranche := {
		"id": "T%d" % int((st.get("debt_book", []) as Array).size() + 1),
		"amount": amount, "rate": rate_for(st, ratio),
		"months_left": 60, "source": source,
	}
	st.debt_book.append(tranche)
	st["debt_stock"] = _stock_from_book(st)
	return tranche

static func issue_bond(st: Dictionary, pct_gdp: float) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo emite dívida"}
	ensure(st)
	var amount := BudgetSystem.annual_gdp(st) * pct_gdp / 100.0
	if amount <= 0.0:
		return {"ok": false, "reason": "Valor inválido"}
	var tranche := _issue(st, amount, "emissão voluntária")
	st["treasury"] = float(st.get("treasury", 0.0)) + amount
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("Tesouro emite M$ %s em títulos a %.1f%% ao ano; o caixa sobe e a dívida também." % [str(int(amount)), float(tranche.get("rate", 0.0))])
	st["news"] = news
	CausalLog.record(st, "divida", "emissão de M$ %s" % str(int(amount)), {"treasury": amount, "debt": amount},
		"A emissão financia o caixa hoje e cria serviço de juros futuro; o custo depende da taxa, do prazo da tranche.")
	return {"ok": true, "reason": "Emissão concluída", "amount": amount, "rate": float(tranche.rate)}

static func finance_project(st: Dictionary, amount: float, source: String) -> Dictionary:
	if amount <= 0.0 or source not in ["titulos", "externo"]:
		return {"ok": false, "amount": 0.0}
	ensure(st)
	var tranche := _issue(st, amount, "projeto:%s" % source)
	st["treasury"] = float(st.get("treasury", 0.0)) + amount
	st["project_debt"] = float(st.get("project_debt", 0.0)) + amount
	return {"ok": true, "amount": amount, "tranche": tranche}

static func amortize(st: Dictionary, pct_gdp: float) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo amortiza dívida"}
	ensure(st)
	var amount := BudgetSystem.annual_gdp(st) * pct_gdp / 100.0
	var buffer := BudgetSystem.annual_gdp(st) * float(fiscal().get("treasury_buffer_pct_gdp", 0.5)) / 100.0
	if float(st.get("treasury", 0.0)) < amount + buffer:
		return {"ok": false, "reason": "Tesouro insuficiente para amortizar sem comprometer o caixa"}
	var left := amount
	var book: Array = []
	for tranche in st.debt_book:
		var row: Dictionary = tranche
		if left <= 0.0:
			book.append(row)
			continue
		var take: float = minf(left, float(row.get("amount", 0.0)))
		row["amount"] = float(row.get("amount", 0.0)) - take
		left -= take
		if float(row.amount) > 0.01:
			book.append(row)
	st["debt_book"] = book
	st["debt_stock"] = _stock_from_book(st)
	st["treasury"] = float(st.treasury) - amount
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("Tesouro amortiza M$ %s da dívida; o caixa cai e o serviço futuro diminui." % str(int(amount)))
	st["news"] = news
	CausalLog.record(st, "divida", "amortização de M$ %s" % str(int(amount)), {"treasury": -amount, "debt": -amount},
		"A amortização reduz o estoque e os juros futuros, mas consome caixa que deixaria de financiar políticas.")
	return {"ok": true, "reason": "Amortização concluída", "amount": amount}

static func monthly(st: Dictionary, revenue: float, non_interest_spending: float) -> Dictionary:
	ensure(st)
	var annual := BudgetSystem.annual_gdp(st)
	var interest := 0.0
	var book: Array = []
	var amortized := 0.0
	var buffer := annual * float(fiscal().get("treasury_buffer_pct_gdp", 0.5)) / 100.0
	for tranche in st.debt_book:
		var row: Dictionary = tranche
		interest += float(row.get("amount", 0.0)) * float(row.get("rate", 6.5)) / 100.0 / 12.0
		row["months_left"] = int(row.get("months_left", 60)) - 1
		if int(row.months_left) <= 0:
			var amount := float(row.get("amount", 0.0))
			if float(st.get("treasury", 0.0)) > buffer + amount * 0.25:
				st["treasury"] = float(st.treasury) - amount
				amortized += amount
				continue
			# Refinanciamento: o vencimento é rolado à taxa corrente.
			var ratio_now := float(st.get("debt_stock", 0.0)) / annual * 100.0
			row["rate"] = rate_for(st, ratio_now)
			row["months_left"] = 60
			row["source"] = "refinanciamento"
		book.append(row)
	st["debt_book"] = book
	st["treasury"] = float(st.get("treasury", 0.0)) - interest
	var b: Dictionary = st.get("budget", {}) if st.get("budget") is Dictionary else {}
	if not b.is_empty():
		var executed: Dictionary = b.get("executed", {}) if b.get("executed") is Dictionary else {}
		executed["divida"] = float(executed.get("divida", 0.0)) + interest
		b["executed"] = executed
	# O caixa abaixo do buffer é financiado por emissão automática. Isso fecha o
	# fluxo: receita - despesa - juros = variação do caixa; a dívida cobre o gap.
	var borrowing := 0.0
	if float(st.get("treasury", 0.0)) < buffer:
		borrowing = buffer - float(st.treasury)
		_issue(st, borrowing, "financiamento do déficit")
		st["treasury"] = float(st.treasury) + borrowing
	var stock := _stock_from_book(st)
	st["debt_stock"] = stock
	var ratio := stock / annual * 100.0
	st["debt"] = clampf(ratio, 5.0, 180.0)
	var primary := revenue - non_interest_spending
	var overall := primary - interest
	var average_rate := 0.0
	if stock > 0.0:
		for tranche in st.debt_book:
			average_rate += float((tranche as Dictionary).get("amount", 0.0)) * float((tranche as Dictionary).get("rate", 6.5)) / stock
	var stats := {
		"interest": interest, "primary": primary, "overall": overall,
		"revenue": revenue, "spending": non_interest_spending + interest,
		"non_interest_spending": non_interest_spending,
		"borrowing": borrowing, "amortization": amortized,
		"ratio": ratio, "stock": stock, "average_rate": average_rate,
		"project_financed": float(st.get("project_debt", 0.0)),
		"buffer": buffer,
	}
	st["debt_stats"] = stats
	var history: Array = st.get("debt_history", []) if st.get("debt_history") is Array else []
	history.append({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))], "ratio": ratio, "interest": interest, "primary": primary, "overall": overall})
	if history.size() > 60:
		history = history.slice(history.size() - 60, history.size())
	st["debt_history"] = history
	if absf(overall) / annual * 12.0 * 100.0 > 0.25 or borrowing > annual * 0.005:
		CausalLog.record(st, "divida", "financiamento do mês", {"debt": overall / annual * 100.0, "interest": interest, "primary": primary},
			"Resultado primário M$ %s, juros M$ %s, resultado total M$ %s; o caixa abaixo do buffer foi financiado por M$ %s." % [
				str(int(primary)), str(int(interest)), str(int(overall)), str(int(borrowing))])
	return stats

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var stats: Dictionary = st.get("debt_stats", {}) if st.get("debt_stats") is Dictionary else {}
	return {
		"ratio": float(st.get("debt", 0.0)), "stock": float(st.get("debt_stock", 0.0)),
		"book": (st.get("debt_book", []) as Array).duplicate(true), "stats": stats.duplicate(true),
		"history": (st.get("debt_history", []) as Array).duplicate(true),
	}
