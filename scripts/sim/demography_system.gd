extends RefCounted
## Fase G1 — demografia agregada.
##
## A população é uma base única. Coortes, renda, ocupação e regiões são
## dimensões analíticas sobre essa base e nunca devem ser somadas entre si.
## Valores do catálogo são âncoras; a trajetória simulada fica no estado.

const VERSION := 1
const MAX_HISTORY := 120
const COHORT_KEYS := ["children", "adolescents", "young_adults", "working_age", "older_adults"]
const COHORT_LABELS := {
	"children": "Crianças (0–14)",
	"adolescents": "Adolescentes (15–24)",
	"young_adults": "Jovens adultos (25–34)",
	"working_age": "Adultos em idade ativa (35–64)",
	"older_adults": "Idosos (65+)",
}
const BASE_SHARES := {"children": 0.20, "adolescents": 0.13, "young_adults": 0.14, "working_age": 0.39, "older_adults": 0.14}
const TRANSITION_MONTHLY := {"children": 1.0 / (15.0 * 12.0), "adolescents": 1.0 / (10.0 * 12.0), "young_adults": 1.0 / (10.0 * 12.0), "working_age": 1.0 / (30.0 * 12.0)}

static func _stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 2027)), int(st.get("date_month", 1))]

static func _country_population(st: Dictionary, economy: Dictionary) -> float:
	var country_id := str(st.get("country_id", "BR"))
	var profile: Variant = economy.get(country_id, {}) if economy is Dictionary else {}
	if profile is Dictionary:
		var population: Variant = (profile as Dictionary).get("population", {})
		if population is Dictionary and float((population as Dictionary).get("value", 0.0)) > 0.0:
			return float((population as Dictionary).get("value", 0.0))
	return 1000000.0

static func _normalise_cohorts(cohorts: Dictionary, total: float) -> Dictionary:
	var result := {}
	var sum := 0.0
	for key in COHORT_KEYS:
		var value := maxf(0.0, float(cohorts.get(key, 0.0)))
		result[key] = value
		sum += value
	if sum <= 0.0:
		for key in COHORT_KEYS: result[key] = total * float(BASE_SHARES[key])
		return result
	var factor := total / sum
	for key in COHORT_KEYS: result[key] = float(result[key]) * factor
	return result

static func _service_index(st: Dictionary) -> float:
	return float(st.get("service_index", 50.0))

static func init_state(st: Dictionary, economy: Dictionary) -> void:
	var total := _country_population(st, economy)
	var cohorts := {}
	for key in COHORT_KEYS: cohorts[key] = total * float(BASE_SHARES[key])
	var urban_share := 0.78
	var country_id := str(st.get("country_id", ""))
	if country_id in ["AR", "CL", "UY"]: urban_share = 0.84
	elif country_id in ["BO", "PY"]: urban_share = 0.70
	st["demography"] = {
		"version": VERSION,
		"source_population": total,
		"source_status": "catalog_anchor",
		"population": total,
		"cohorts": cohorts,
		"birth_rate": 13.0,
		"fertility_rate": 1.8,
		"mortality_rate": 7.5,
		"life_expectancy": 75.0,
		"births_month": 0.0,
		"deaths_month": 0.0,
		"immigration_month": 0.0,
		"emigration_month": 0.0,
		"internal_migration_month": 0.0,
		"urban_population": total * urban_share,
		"rural_population": total * (1.0 - urban_share),
		"urban_share": urban_share,
		"households": total / 2.8,
		"dependency_ratio": 0.0,
		"history": [],
		"assumptions": ["coortes iniciais são modelo estimado quando o catálogo não fornece distribuição etária", "migração comum é agregada e não representa deslocamento forçado"],
		"last_tick": "",
	}
	_recalculate(st.demography)

static func ensure(st: Dictionary, economy: Dictionary) -> void:
	var data: Variant = st.get("demography", {})
	if not (data is Dictionary) or int((data as Dictionary).get("version", 0)) != VERSION:
		init_state(st, economy)
		return
	var demography: Dictionary = data
	if not (demography.get("cohorts") is Dictionary): demography["cohorts"] = {}
	if not (demography.get("history") is Array): demography["history"] = []
	for key in ["population", "urban_population", "rural_population"]:
		if not demography.has(key): demography[key] = _country_population(st, economy)
	_recalculate(demography)
	st["demography"] = demography

static func _recalculate(data: Dictionary) -> void:
	var total := 0.0
	var cohorts: Dictionary = data.get("cohorts", {}) if data.get("cohorts") is Dictionary else {}
	for key in COHORT_KEYS: total += maxf(0.0, float(cohorts.get(key, 0.0)))
	data["population"] = maxf(1.0, total)
	data["urban_population"] = clampf(float(data.get("urban_population", 0.0)), 0.0, data.population)
	data["rural_population"] = maxf(0.0, data.population - data.urban_population)
	data["urban_share"] = data.urban_population / data.population
	data["households"] = data.population / 2.8
	var dependents := float(cohorts.get("children", 0.0)) + float(cohorts.get("adolescents", 0.0)) + float(cohorts.get("older_adults", 0.0))
	var active := maxf(1.0, float(cohorts.get("young_adults", 0.0)) + float(cohorts.get("working_age", 0.0)))
	data["dependency_ratio"] = dependents / active * 100.0

static func _migration(st: Dictionary, data: Dictionary) -> Dictionary:
	var unemployment := float(st.get("unemployment", 8.2))
	var service_gap := maxf(0.0, 65.0 - _service_index(st))
	var housing_gap := maxf(0.0, 60.0 - float((st.get("services", {}) as Dictionary).get("habitacao", {}).get("coverage", 50.0))) if st.get("services") is Dictionary else 10.0
	var annual_immigration_rate := clampf(0.0012 + maxf(0.0, 7.0 - unemployment) * 0.00008 - service_gap * 0.00001 - housing_gap * 0.00001, 0.0003, 0.0018)
	var annual_emigration_rate := clampf(0.0007 + maxf(0.0, unemployment - 7.0) * 0.00008 + service_gap * 0.00001, 0.0003, 0.0020)
	var immigration: float = float(data.population) * annual_immigration_rate / 12.0
	var emigration: float = float(data.population) * annual_emigration_rate / 12.0
	var internal: float = float(data.population) * clampf(0.0008 + maxf(0.0, 60.0 - _service_index(st)) * 0.00002, 0.0005, 0.0020) / 12.0
	return {"immigration": immigration, "emigration": emigration, "internal": internal}

static func monthly(st: Dictionary, economy: Dictionary) -> Dictionary:
	ensure(st, economy)
	var data: Dictionary = st.demography
	var tick := _stamp(st)
	if str(data.get("last_tick", "")) == tick:
		return {"skipped": true, "tick": tick}
	var cohorts: Dictionary = data.cohorts.duplicate(true)
	var total_before := float(data.population)
	var births := total_before * float(data.get("birth_rate", 13.0)) / 12000.0
	var deaths := total_before * float(data.get("mortality_rate", 7.5)) / 12000.0
	var migration := _migration(st, data)
	var aged := {}
	for key in COHORT_KEYS: aged[key] = 0.0
	for index in COHORT_KEYS.size():
		var key: String = str(COHORT_KEYS[index])
		var value := maxf(0.0, float(cohorts.get(key, 0.0)))
		var rate := float(TRANSITION_MONTHLY.get(key, 0.0))
		var leaving := value * rate
		aged[key] += value - leaving
		if index + 1 < COHORT_KEYS.size(): aged[COHORT_KEYS[index + 1]] += leaving
	var death_weights := {"children": 0.006, "adolescents": 0.004, "young_adults": 0.006, "working_age": 0.024, "older_adults": 0.960}
	for key in COHORT_KEYS: aged[key] = maxf(0.0, float(aged[key]) - deaths * float(death_weights[key]))
	aged["children"] += births
	var net_external := float(migration.immigration) - float(migration.emigration)
	aged["young_adults"] += maxf(0.0, net_external) * 0.55
	aged["working_age"] += maxf(0.0, net_external) * 0.45
	if net_external < 0.0:
		var loss := absf(net_external)
		aged["young_adults"] = maxf(0.0, float(aged["young_adults"]) - loss * 0.55)
		aged["working_age"] = maxf(0.0, float(aged["working_age"]) - loss * 0.45)
	data["cohorts"] = _normalise_cohorts(aged, maxf(1.0, total_before + births - deaths + net_external))
	data["births_month"] = births
	data["deaths_month"] = deaths
	data["immigration_month"] = float(migration.immigration)
	data["emigration_month"] = float(migration.emigration)
	data["internal_migration_month"] = float(migration.internal)
	var urbanisation := minf(float(migration.internal), float(data.rural_population))
	data["urban_population"] = float(data.urban_population) + urbanisation
	_recalculate(data)
	var row := {"date": tick, "population": data.population, "births": births, "deaths": deaths, "immigration": migration.immigration, "emigration": migration.emigration, "urban_share": data.urban_share, "dependency_ratio": data.dependency_ratio}
	var history: Array = data.get("history", [])
	history.push_front(row)
	if history.size() > MAX_HISTORY: history.resize(MAX_HISTORY)
	data["history"] = history
	data["last_tick"] = tick
	st["demography"] = data
	return row

static func summary(st: Dictionary) -> Dictionary:
	var data: Dictionary = st.get("demography", {}) if st.get("demography") is Dictionary else {}
	return data.duplicate(true)

static func cohort_rows(st: Dictionary) -> Array:
	var data: Dictionary = st.get("demography", {}) if st.get("demography") is Dictionary else {}
	var cohorts: Dictionary = data.get("cohorts", {}) if data.get("cohorts") is Dictionary else {}
	var rows: Array = []
	for key in COHORT_KEYS:
		var value := float(cohorts.get(key, 0.0))
		rows.append({"id": key, "label": COHORT_LABELS[key], "population": value, "share": value / maxf(1.0, float(data.get("population", 1.0)))})
	return rows
