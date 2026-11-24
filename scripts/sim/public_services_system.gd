extends RefCounted
## C6 — Serviços públicos e capacidade do Estado.
##
## Gastar não é entregar. Cobertura, qualidade, capacidade, demanda e eficiência
## são estoques distintos. A dotação move a capacidade com defasagem; a
## capacidade instalada, o efetivo ministerial e a infraestrutura concluída
## determinam o que chega à população.

const DATA_PATH := "res://config/public_administration.json"
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const Ministries := preload("res://scripts/sim/ministry_system.gd")

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func definitions() -> Array:
	var value: Variant = config().get("services", [])
	return value if value is Array else []

static func definition(id: String) -> Dictionary:
	for entry in definitions():
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func init_state(st: Dictionary) -> void:
	var services := {}
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var coverage := float(entry.get("coverage", 50.0))
		var quality := float(entry.get("quality", 50.0))
		var capacity := float(entry.get("capacity", 50.0))
		var demand := float(entry.get("demand", 70.0))
		services[id] = {
			"coverage": coverage, "quality": quality, "capacity": capacity,
			"demand": demand, "infrastructure": 50.0,
			"efficiency": clampf(quality * 0.45 + coverage * 0.25 + capacity * 0.2 - demand * 0.15, 0.0, 100.0),
			"history": [coverage],
		}
	st["services"] = services
	st["service_index"] = _index(services)

static func ensure(st: Dictionary) -> void:
	if not (st.get("services") is Dictionary):
		init_state(st)
		return
	for entry in definitions():
		var id := str(entry.get("id", ""))
		if not (st.services as Dictionary).has(id):
			st.services[id] = {
				"coverage": float(entry.get("coverage", 50.0)), "quality": float(entry.get("quality", 50.0)),
				"capacity": float(entry.get("capacity", 50.0)), "demand": float(entry.get("demand", 70.0)),
				"infrastructure": 50.0, "efficiency": 50.0, "history": [],
			}
		var service: Dictionary = st.services[id]
		for key in ["coverage", "quality", "capacity", "demand", "infrastructure", "efficiency"]:
			if not service.has(key):
				service[key] = 50.0
		if not (service.get("history") is Array):
			service["history"] = []
	if not st.has("service_index"):
		st["service_index"] = _index(st.services)

static func _index(services: Dictionary) -> float:
	if services.is_empty():
		return 50.0
	var total := 0.0
	for service in services.values():
		total += float((service as Dictionary).get("coverage", 50.0)) * 0.40
		total += float((service as Dictionary).get("quality", 50.0)) * 0.40
		total += float((service as Dictionary).get("capacity", 50.0)) * 0.20
	return clampf(total / float(services.size()), 0.0, 100.0)

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var weakest := ""
	var worst := 101.0
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var service: Dictionary = st.services[id]
		var ministry_id := str(entry.get("ministry", ""))
		var ministry := Ministries.ministry_data(st, ministry_id)
		var ministry_capacity := float(ministry.get("capacity", 50.0))
		var category := str(entry.get("category", ""))
		var category_def := BudgetSystem.category(category)
		var adequacy := 1.0
		if not category_def.is_empty():
			adequacy = BudgetSystem.planned_share(st, category) / maxf(0.01, float(category_def.get("base_share", 1.0)))
		var infrastructure := float(service.get("infrastructure", 50.0))
		var target_capacity := 26.0 + adequacy * 26.0 + ministry_capacity * 0.30 + infrastructure * 0.22
		service["capacity"] = clampf(float(service.get("capacity", 50.0)) + (clampf(target_capacity, 5.0, 96.0) - float(service.get("capacity", 50.0))) * 0.08, 0.0, 100.0)
		var demand_target := float(entry.get("demand", 70.0))
		demand_target += maxf(0.0, 72.0 - float(service.get("coverage", 50.0))) * 0.08
		demand_target += (float(st.get("unemployment", 8.2)) - 7.0) * 0.25
		demand_target -= (float(st.get("economy", 2.4)) - 2.5) * 0.20
		service["demand"] = clampf(float(service.get("demand", 70.0)) + (clampf(demand_target, 5.0, 98.0) - float(service.get("demand", 70.0))) * 0.05, 0.0, 100.0)
		var served := minf(float(service.demand), float(service.capacity) * 1.02)
		service["coverage"] = clampf(float(service.get("coverage", 50.0)) + (served - float(service.get("coverage", 50.0))) * 0.06, 0.0, 100.0)
		var target_quality := float(service.capacity) * 0.62 + ministry_capacity * 0.22 + (adequacy - 1.0) * 18.0 + infrastructure * 0.10
		service["quality"] = clampf(float(service.get("quality", 50.0)) + (clampf(target_quality, 5.0, 96.0) - float(service.get("quality", 50.0))) * 0.07, 0.0, 100.0)
		service["efficiency"] = clampf(float(service.quality) * 0.45 + float(service.coverage) * 0.25 + float(service.capacity) * 0.20 - float(service.demand) * 0.15, 0.0, 100.0)
		var history: Array = service.get("history", [])
		history.append(float(service.coverage))
		if history.size() > 24:
			history = history.slice(history.size() - 24, history.size())
		service["history"] = history
		if float(service.quality) < worst:
			worst = float(service.quality)
			weakest = str(entry.get("label", id))
	st["service_index"] = _index(st.services)
	return {"index": float(st.service_index), "weakest": weakest}

static func index(st: Dictionary) -> float:
	ensure(st)
	return float(st.get("service_index", 50.0))

static func service(st: Dictionary, id: String) -> Dictionary:
	ensure(st)
	return (st.services as Dictionary).get(id, {})

static func summary(st: Dictionary) -> Dictionary:
	ensure(st)
	var rows: Array = []
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var service: Dictionary = st.services[id]
		rows.append({
			"id": id, "label": str(entry.get("label", id)), "ministry": str(entry.get("ministry", "")),
			"coverage": float(service.get("coverage", 0.0)), "quality": float(service.get("quality", 0.0)),
			"capacity": float(service.get("capacity", 0.0)), "demand": float(service.get("demand", 0.0)),
			"efficiency": float(service.get("efficiency", 0.0)), "infrastructure": float(service.get("infrastructure", 0.0)),
			"linked_groups": entry.get("linked_groups", [])})
	return {"rows": rows, "index": index(st)}
