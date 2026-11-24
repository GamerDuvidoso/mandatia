extends RefCounted
## C3 — Ministérios e ministros.
##
## Cada pasta tem ministro, competência técnica, lealdade política, experiência,
## credibilidade e capacidade administrativa. Competência e lealdade são eixos
## distintos: um aliado pode estabilizar a coalizão e ao mesmo tempo reduzir a
## execução. A capacidade não nasce de evento aleatório: depende do ministro,
## da dotação orçamentária e do desempenho do serviço.

const DATA_PATH := "res://config/public_administration.json"
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const PoliticalRelations := preload("res://scripts/sim/political_relations.gd")
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

static func definitions() -> Array:
	var value: Variant = config().get("ministries", [])
	return value if value is Array else []

static func definition(id: String) -> Dictionary:
	for entry in definitions():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func init_state(st: Dictionary) -> void:
	var data := {}
	for entry in definitions():
		var id := str(entry.get("id", ""))
		data[id] = {
			"minister": "", "party": "", "kind": "", "competence": 50.0, "loyalty": 50.0,
			"experience": 45.0, "credibility": 50.0, "leadership": 45.0,
			"capacity": float(entry.get("base_capacity", 52.0)), "performance": 50.0,
			"months": 0, "appointed": "",
		}
	st["ministry_admin"] = data
	st["admin_capacity"] = _average(data, "capacity")
	st["admin_performance"] = _average(data, "performance")

static func ensure(st: Dictionary) -> void:
	if not (st.get("ministry_admin") is Dictionary):
		init_state(st)
		return
	for entry in definitions():
		var id := str(entry.get("id", ""))
		if not (st.ministry_admin as Dictionary).has(id):
			st.ministry_admin[id] = {
				"minister": "", "party": "", "kind": "", "competence": 50.0, "loyalty": 50.0,
				"experience": 45.0, "credibility": 50.0, "leadership": 45.0,
				"capacity": float(entry.get("base_capacity", 52.0)), "performance": 50.0,
				"months": 0, "appointed": "",
			}
		var data: Dictionary = st.ministry_admin[id]
		for key in ["competence", "loyalty", "experience", "credibility", "leadership", "capacity", "performance"]:
			if not data.has(key):
				data[key] = 50.0
		if not data.has("minister"):
			data["minister"] = ""

static func _average(data: Dictionary, key: String) -> float:
	if data.is_empty():
		return 50.0
	var total := 0.0
	for entry in data.values():
		total += float((entry as Dictionary).get(key, 50.0))
	return total / float(data.size())

static func average_capacity(st: Dictionary) -> float:
	ensure(st)
	return _average(st.ministry_admin, "capacity")

static func average_performance(st: Dictionary) -> float:
	ensure(st)
	return _average(st.ministry_admin, "performance")

static func ministry_data(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	return (st.ministry_admin as Dictionary).get(id, {})

## Candidatos determinísticos: o mesmo mês e a mesma pasta produzem o mesmo
## quadro. Arquétipos separam competência técnica de lealdade política.
static func candidates(st: Dictionary, id: String, count := 3) -> Array:
	var names: Array = (config().get("minister_names", []) as Array).duplicate()
	var archetypes: Array = config().get("minister_archetypes", [])
	if names.is_empty() or archetypes.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + int(st.get("date_year", 0)) * 131 + int(st.get("date_month", 1)) * 17
	for index in range(names.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var tmp = names[index]
		names[index] = names[swap]
		names[swap] = tmp
	var partners: Array = st.get("coalition_partners", []) if st.get("coalition_partners") is Array else []
	var player := str(st.get("abbr", "PJ"))
	var result: Array = []
	for index in count:
		var arch: Dictionary = archetypes[index % archetypes.size()]
		var party := player
		if str(arch.get("id", "")) == "aliado" and not partners.is_empty():
			party = str(partners[index % partners.size()])
		elif str(arch.get("id", "")) == "tecnico":
			party = "independente"
		var competence := clampf(45.0 + float(arch.get("competence", 0.0)) + rng.randi_range(-8, 8), 12.0, 96.0)
		var loyalty := clampf(45.0 + float(arch.get("loyalty", 0.0)) + rng.randi_range(-8, 8), 10.0, 98.0)
		var experience := clampf(40.0 + float(arch.get("experience", 0.0)) + rng.randi_range(-10, 10), 8.0, 96.0)
		var credibility := clampf(48.0 + float(arch.get("credibility", 0.0)) + rng.randi_range(-8, 8), 10.0, 96.0)
		var leadership := clampf(45.0 + float(arch.get("leadership", 0.0)) + rng.randi_range(-8, 8), 10.0, 96.0)
		var cost := int(fiscal().get("default_minister_cost", 260)) + int(maxf(0.0, competence - 55.0) * 3.0)
		result.append({
			"name": str(names[index % names.size()]),
			"kind": str(arch.get("label", arch.get("id", "quadro"))),
			"party": party,
			"competence": competence, "loyalty": loyalty, "experience": experience,
			"credibility": credibility, "leadership": leadership,
			"cost": cost,
			"description": "%s · competência %.0f · lealdade %.0f · experiência %.0f" % [str(arch.get("label", "")), competence, loyalty, experience],
		})
	return result

static func appoint(st: Dictionary, id: String, candidate: Dictionary) -> Dictionary:
	if not bool(st.get("government", false)):
		return {"ok": false, "reason": "Apenas o governo nomeia ministros"}
	var entry := definition(id)
	if entry.is_empty() or candidate.is_empty():
		return {"ok": false, "reason": "Pasta ou candidato inválido"}
	ensure(st)
	var data: Dictionary = st.ministry_admin[id]
	var replacing := str(data.get("minister", "")) != ""
	var cost := int(fiscal().get("replace_minister_cost", 320)) if replacing else int(fiscal().get("default_minister_cost", 260))
	cost += int(maxf(0.0, float(candidate.get("competence", 50.0)) - 55.0) * 3.0)
	if float(st.get("funds", 0.0)) < float(cost):
		return {"ok": false, "reason": "Caixa partidário insuficiente (M$ %d)" % cost}
	st["funds"] = float(st.funds) - cost
	var previous_party := str(data.get("party", ""))
	if replacing and previous_party != "" and previous_party != "independente" and previous_party != str(st.get("abbr", "")):
		# Tirar uma pasta de um aliado tem custo de coalizão.
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - 1.5, 10.0, 100.0)
		PoliticalRelations.shift(st, str(st.get("abbr", "")), previous_party, -2.0, "pasta retirada do aliado")
	data["minister"] = str(candidate.get("name", "Ministro"))
	data["party"] = str(candidate.get("party", "independente"))
	data["kind"] = str(candidate.get("kind", "quadro"))
	for key in ["competence", "loyalty", "experience", "credibility", "leadership"]:
		data[key] = float(candidate.get(key, 50.0))
	data["months"] = 0
	data["appointed"] = "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))]
	# Capacidade inicial: o ministro recém-chegado não entrega tudo no primeiro dia.
	var target := 22.0 + float(data.competence) * 0.35 + float(data.experience) * 0.18 + float(data.leadership) * 0.10
	data["capacity"] = clampf((float(data.get("capacity", 50.0)) + target) * 0.5, 15.0, 92.0)
	var effects := {"capacity": float(data.capacity) - 50.0}
	if str(data.party) == "independente":
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) - 2.0, 10.0, 100.0)
		st["credibility"] = clampf(float(st.get("credibility", 31.0)) + 1.0, 0.0, 100.0)
		effects["coalition_cohesion"] = -2.0
		effects["credibility"] = 1.0
	elif str(data.party) != str(st.get("abbr", "")):
		var assignments: Dictionary = st.get("coalition_assignments", {}) if st.get("coalition_assignments") is Dictionary else {}
		assignments[str(data.party)] = int(assignments.get(str(data.party), 0)) + 1
		st["coalition_assignments"] = assignments
		st["coalition_cohesion"] = clampf(float(st.get("coalition_cohesion", 60.0)) + 1.0, 10.0, 100.0)
		PoliticalRelations.shift(st, str(st.get("abbr", "")), str(data.party), 1.5, "pasta entregue ao aliado")
		effects["coalition_cohesion"] = 1.0
		effects["relationship"] = 1.5
	st["admin_capacity"] = average_capacity(st)
	var news: Array = st.get("news", []) if st.get("news") is Array else []
	news.push_front("%s assume %s (%s, competência %.0f, lealdade %.0f)." % [str(data.minister), str(entry.get("label", id)), str(data.kind), float(data.competence), float(data.loyalty)])
	st["news"] = news
	CausalLog.record(st, "ministerio", "%s em %s" % [str(data.minister), str(entry.get("label", id))], effects,
		"A nomeação combina competência técnica e lealdade política; a capacidade inicial ainda é parcial e evolui com dotação e experiência.")
	return {"ok": true, "reason": "%s nomeado para %s" % [str(data.minister), str(entry.get("label", id))], "cost": cost}

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var weak: Array = []
	var strongest := ""
	var best := -1.0
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var data: Dictionary = st.ministry_admin[id]
		var base_capacity := float(entry.get("base_capacity", 52.0))
		var service_id := str(entry.get("service", ""))
		var service_quality := 50.0
		var service_map: Dictionary = st.get("services", {}) if st.get("services") is Dictionary else {}
		if service_id != "" and service_map.has(service_id):
			service_quality = float((service_map[service_id] as Dictionary).get("quality", 50.0))
		if str(data.get("minister", "")) == "":
			data["capacity"] = clampf(float(data.capacity) + (base_capacity - float(data.capacity)) * 0.02 - 0.25, 10.0, 95.0)
			data["performance"] = clampf(float(data.capacity) * 0.55 + service_quality * 0.25, 0.0, 100.0)
			weak.append(str(entry.get("label", id)))
			continue
		data["months"] = int(data.get("months", 0)) + 1
		var adequacy := 1.0
		var category := str(entry.get("category", ""))
		var category_def := BudgetSystem.category(category)
		if not category_def.is_empty():
			var base_share := maxf(0.01, float(category_def.get("base_share", 1.0)))
			adequacy = BudgetSystem.planned_share(st, category) / base_share
		var target := 20.0 + float(data.competence) * 0.38 + float(data.experience) * 0.18 + float(data.leadership) * 0.10
		target += (adequacy - 1.0) * 22.0
		target += (float(data.loyalty) - 50.0) * 0.02
		target += (float(data.credibility) - 50.0) * 0.04
		target += (service_quality - 50.0) * 0.10
		data["capacity"] = clampf(float(data.capacity) + (clampf(target, 10.0, 96.0) - float(data.capacity)) * 0.10, 10.0, 96.0)
		data["performance"] = clampf(float(data.capacity) * 0.60 + service_quality * 0.30 + float(data.credibility) * 0.10, 0.0, 100.0)
		if float(data.capacity) < 42.0:
			weak.append(str(entry.get("label", id)))
		if float(data.performance) > best:
			best = float(data.performance)
			strongest = str(entry.get("label", id))
	st["admin_capacity"] = average_capacity(st)
	st["admin_performance"] = average_performance(st)
	return {"capacity": float(st.admin_capacity), "performance": float(st.admin_performance), "weak": weak, "strongest": strongest}

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var rows: Array = []
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var data: Dictionary = st.ministry_admin[id]
		rows.append({
			"id": id, "label": str(entry.get("label", id)), "category": str(entry.get("category", "")),
			"service": str(entry.get("service", "")), "responsibilities": entry.get("responsibilities", []),
			"minister": str(data.get("minister", "")), "party": str(data.get("party", "")),
			"kind": str(data.get("kind", "")), "competence": float(data.get("competence", 0.0)),
			"loyalty": float(data.get("loyalty", 0.0)), "experience": float(data.get("experience", 0.0)),
			"capacity": float(data.get("capacity", 0.0)), "performance": float(data.get("performance", 0.0)),
			"months": int(data.get("months", 0)),
		})
	return {"rows": rows, "capacity": float(st.get("admin_capacity", 50.0)), "performance": float(st.get("admin_performance", 50.0))}
