extends RefCounted
## FUND-03 — contrato comum de unidades e ledger macrofiscal/populacional.
##
## Este módulo observa valores já produzidos por outros sistemas. Ele não é uma
## segunda fonte de verdade: não calcula PIB, população, dívida ou arrecadação.
## Cada valor carrega unidade e status de proveniência (official/estimated/model).

const VERSION := 1
const MAX_HISTORY := 240
const STATUS_VALUES := ["official", "estimated", "model"]

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))]

static func _status(value: Variant, fallback := "model") -> String:
	var candidate := str(value)
	return candidate if candidate in STATUS_VALUES else fallback

static func _source_status(st: Dictionary, key: String, fallback := "model") -> String:
	var profile: Variant = st.get("economic_profile", {})
	if profile is Dictionary:
		var entry: Variant = (profile as Dictionary).get(key, {})
		if entry is Dictionary:
			return _status((entry as Dictionary).get("source_status", (entry as Dictionary).get("status", fallback)), fallback)
	return fallback

static func _new_contract(existing: Dictionary = {}) -> Dictionary:
	var result := existing.duplicate(true)
	result["schema_version"] = VERSION
	result["unit_system"] = "SI + moeda interna M$ + índices declarados"
	if not (result.get("history") is Array): result["history"] = []
	if not result.has("last_tick"): result["last_tick"] = ""
	if not (result.get("provenance") is Dictionary): result["provenance"] = {}
	if not (result.get("reconciliation") is Dictionary): result["reconciliation"] = {}
	return result

static func ensure(st: Dictionary) -> void:
	var raw: Variant = st.get("macro_ledger", {})
	var data: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	st["macro_ledger"] = _new_contract(data)

static func _population_reconciliation(st: Dictionary) -> Dictionary:
	var demo: Variant = st.get("demography", {})
	if not demo is Dictionary:
		return {"status": "unreconciled", "reason": "demography_missing"}
	var cohorts: Variant = (demo as Dictionary).get("cohorts", {})
	if not cohorts is Dictionary:
		return {"status": "unreconciled", "reason": "cohorts_missing"}
	var cohort_total := 0.0
	for value in (cohorts as Dictionary).values(): cohort_total += maxf(0.0, float(value))
	var population := maxf(0.0, float((demo as Dictionary).get("population", 0.0)))
	var delta := absf(cohort_total - population)
	return {
		"status": "reconciled" if delta <= 0.5 else "unreconciled",
		"population": population,
		"cohort_total": cohort_total,
		"delta": delta,
		"tolerance": 0.5,
	}

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var data: Dictionary = st.macro_ledger
	var tick := _stamp(st)
	if str(data.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}

	var population := float(((st.get("demography", {}) as Dictionary).get("population", 0.0))) if st.get("demography") is Dictionary else 0.0
	var fiscal: Variant = st.get("fiscal", {})
	var revenue_share := float((fiscal as Dictionary).get("tax_share", st.get("tax_revenue_share", 0.0))) if fiscal is Dictionary else float(st.get("tax_revenue_share", 0.0))
	var entry := {
		"date": tick,
		"country_id": str(st.get("country_id", "")),
		"values": {
			"population": {"value": population, "unit": "persons", "status": "model", "source": "state.demography.population"},
			"gdp_index": {"value": float(st.get("gdp", 0.0)), "unit": "index_100", "status": "model", "source": "state.gdp"},
			"growth_rate": {"value": float(st.get("economy", 0.0)), "unit": "percent_per_year", "status": _source_status(st, "gdp_growth"), "source": "state.economy"},
			"inflation_rate": {"value": float(st.get("inflation", 0.0)), "unit": "percent_per_year", "status": _source_status(st, "inflation"), "source": "state.inflation"},
			"unemployment_rate": {"value": float(st.get("unemployment", 0.0)), "unit": "percent_labor_force", "status": _source_status(st, "unemployment"), "source": "state.unemployment"},
			"debt_ratio": {"value": float(st.get("debt", 0.0)), "unit": "percent_gdp", "status": _source_status(st, "debt"), "source": "state.debt"},
			"tax_revenue_share": {"value": revenue_share, "unit": "percent_gdp", "status": "model", "source": "state.fiscal/tax_revenue_share"},
		},
		"reconciliation": {"population": _population_reconciliation(st)},
	}
	var history: Array = data.get("history", [])
	history.push_front(entry)
	if history.size() > MAX_HISTORY: history.resize(MAX_HISTORY)
	data["history"] = history
	data["last_tick"] = tick
	data["reconciliation"] = entry.reconciliation
	data["provenance"] = {"population": "state.demography.population", "macro": "state + economic_profile", "policy": "observational_only"}
	st["macro_ledger"] = data
	return entry

static func summary(st: Dictionary) -> Dictionary:
	var data: Variant = st.get("macro_ledger", {})
	return data.duplicate(true) if data is Dictionary else {}
