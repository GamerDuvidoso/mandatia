extends RefCounted
## E2 — dependências de recursos estratégicos.
##
## O perfil é um modelo declarado: importação de petróleo/gás, alimentos,
## minerais, concentração de exportações, renováveis, estoque estratégico e
## exposição a turismo/remessas. Não é um balanço energético oficial. Países
## exportadores têm dependência de importação menor; a vulnerabilidade a um
## choque é calculada pela exposição, não aplicada igualmente a todos.

const DATA_PATH := "res://config/geopolitics.json"

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func ensure(st: Dictionary, id: String) -> Dictionary:
	var g: Dictionary = st.get("geopolitics", {}) if st.get("geopolitics") is Dictionary else {}
	var resources: Dictionary = g.get("resources", {}) if g.get("resources") is Dictionary else {}
	if not resources.has(id):
		resources[id] = profile(id)
	g["resources"] = resources
	st["geopolitics"] = g
	return resources[id]

static func profile(id: String) -> Dictionary:
	var cfg := config()
	var p: Dictionary = (cfg.get("resource_defaults", {}) as Dictionary).duplicate(true)
	var overrides: Dictionary = cfg.get("resource_overrides", {}) if cfg.get("resource_overrides") is Dictionary else {}
	if overrides.get(id) is Dictionary:
		for key in (overrides[id] as Dictionary).keys():
			p[key] = overrides[id][key]
	p["id"] = id
	# Vulnerabilidade energética: petróleo e gás ponderados; exportador reduz.
	var energy := float(p.get("oil_import", 0.5)) * 0.62 + float(p.get("gas_import", 0.3)) * 0.38
	if bool(p.get("oil_exporter", false)) or bool(p.get("gas_exporter", false)):
		energy *= 0.35
	p["energy_dependency"] = clampf(energy, 0.0, 1.0)
	p["food_dependency"] = clampf(float(p.get("food_import", 0.25)), 0.0, 1.0)
	p["mineral_dependency"] = clampf(float(p.get("minerals_import", 0.2)), 0.0, 1.0)
	p["stock_cover_months"] = clampf(float(p.get("strategic_stock_days", 28)) / 30.0, 0.2, 6.0)
	return p

static func vulnerability(id: String, kind: String) -> float:
	var p := profile(id)
	match kind:
		"energia":
			return clampf(float(p.energy_dependency) * (1.0 - minf(0.55, float(p.renewables) * 0.8)) / maxf(0.6, float(p.stock_cover_months) / 2.5), 0.0, 1.6)
		"alimentos":
			return clampf(float(p.food_dependency) * (1.0 - minf(0.4, float(p.renewables) * 0.3)), 0.0, 1.0)
		"comercio":
			return clampf(float(p.export_concentration) * 1.15 + float(p.tourism_exposure) * 0.35 + float(p.remittance_exposure) * 0.25, 0.0, 1.4)
		"financeiro":
			return clampf(0.45 + float(p.remittance_exposure) * 0.35 + float(p.export_concentration) * 0.25, 0.0, 1.2)
	return 0.5

static func dispute(a: String, b: String) -> Dictionary:
	for row in (config().get("disputes", []) as Array):
		var x := str((row as Dictionary).get("a", ""))
		var y := str((row as Dictionary).get("b", ""))
		if (x == a and y == b) or (x == b and y == a):
			return row
	return {}

static func shared_region(st: Dictionary, a: String, b: String) -> bool:
	var profiles: Dictionary = st.get("international_state", {}).get("profiles", {}) if st.get("international_state") is Dictionary else {}
	var ra := str(profiles.get(a, {}).get("region", ""))
	var rb := str(profiles.get(b, {}).get("region", ""))
	return ra != "" and ra == rb

static func summary(st: Dictionary, id: String) -> Dictionary:
	var p := ensure(st, id)
	return {
		"energy_dependency": float(p.energy_dependency), "food_dependency": float(p.food_dependency),
		"mineral_dependency": float(p.mineral_dependency), "export_concentration": float(p.export_concentration),
		"renewables": float(p.renewables), "stock_cover_months": float(p.stock_cover_months),
		"oil_exporter": bool(p.get("oil_exporter", false)), "gas_exporter": bool(p.get("gas_exporter", false)),
	}
