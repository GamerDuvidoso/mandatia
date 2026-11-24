extends RefCounted
## Sistema B2: grupos sociais e reações a políticas.
##
## Duas camadas independentes (ocupação e renda). Cada camada soma 1,0 e uma
## pessoa pode aparecer nas duas; o índice eleitoral usa SÓ a camada ocupacional
## para não contar ninguém duas vezes. As participações são modelo declarado,
## não estatística oficial.

const DATA_PATH := "res://config/social_groups.json"
const LEGACY := ["Jovens", "Trabalhadores", "Empreendedores", "Aposentados", "Rurais"]
## Ponto de partida da condição econômica por grupo; o mês ajusta pelo ciclo.
const ECONOMIC_BASE := {
	"industrial_workers": 46.0, "service_workers": 48.0, "public_sector": 56.0,
	"entrepreneurs": 68.0, "farmers": 49.0, "students": 38.0, "retirees": 45.0,
	"unemployed": 24.0, "informal": 33.0, "low_income": 28.0,
	"middle_income": 52.0, "high_income": 78.0,
}

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func definitions() -> Array:
	return config().get("groups", [])

static func definition(group_id: String) -> Dictionary:
	for entry in definitions():
		if str(entry.get("id", "")) == group_id:
			return entry
	return {}

static func layers() -> Dictionary:
	return config().get("layers", {})

static func policy_def(policy_id: String) -> Dictionary:
	var policies: Dictionary = config().get("policies", {})
	return policies.get(policy_id, {}) if policies.get(policy_id) is Dictionary else {}

static func _economic_condition(entry: Dictionary, st: Dictionary) -> float:
	var base := float(ECONOMIC_BASE.get(str(entry.get("id", "")), 50.0))
	var worker := str(entry.get("id", "")) in ["industrial_workers", "service_workers", "unemployed", "informal"]
	base += (float(st.get("economy", 2.4)) - 2.5) * 5.0
	base -= (float(st.get("unemployment", 8.2)) - 7.0) * (3.2 if worker else 1.0)
	base -= maxf(0.0, float(st.get("inflation", 4.8)) - 4.0) * 1.2
	return clampf(base, 5.0, 95.0)

static func _macro_pressure(entry: Dictionary, st: Dictionary) -> float:
	var id := str(entry.get("id", ""))
	var worker := id in ["industrial_workers", "service_workers", "unemployed", "informal", "public_sector"]
	var retired := id == "retirees"
	var business := id in ["entrepreneurs", "high_income"]
	var value := (float(st.get("economy", 2.4)) - 2.5) * 2.4
	value -= maxf(0.0, float(st.get("inflation", 4.8)) - 4.0) * (1.6 if not business else 0.5)
	value -= (float(st.get("unemployment", 8.2)) - 7.0) * (1.4 if worker else 0.35 if retired else 0.2)
	if business:
		value += maxf(0.0, 60.0 - float(st.get("debt", 60.0))) * 0.03
	return clampf(value, -18.0, 18.0)

static func init_state(st: Dictionary) -> void:
	var gov := Vector2(float(st.get("ideology_position", {}).get("economic", 0.0)), float(st.get("ideology_position", {}).get("social", 0.0)))
	var approval := float(st.get("approval", 42.0))
	var groups := {}
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var pref := Vector2(float(entry.get("economic", 0.0)), float(entry.get("social", 0.0)))
		var distance := pref.distance_to(gov) / 282.8427
		var satisfaction := clampf(48.0 + (approval - 45.0) * 0.25 - distance * 16.0 + _macro_pressure(entry, st), 5.0, 95.0)
		groups[id] = {
			"label": str(entry.get("label", id)),
			"layer": str(entry.get("layer", "occupation")),
			"share": float(entry.get("share", 0.0)),
			"satisfaction": satisfaction,
			"approval": satisfaction,
			"economic": _economic_condition(entry, st),
			"preferences": {"economic": pref.x, "social": pref.y},
			"concerns": entry.get("concerns", []),
			"history": [satisfaction],
			"last_policy": "",
		}
	st["social_groups"] = groups
	st["social_support"] = support_index(st)
	st["demographics"] = legacy_demographics(st)
	st["income_support"] = income_support(st)

static func ensure(st: Dictionary) -> void:
	if not (st.get("social_groups") is Dictionary) or (st.social_groups as Dictionary).is_empty():
		init_state(st)

static func _gov_position(st: Dictionary) -> Vector2:
	var stored: Variant = st.get("ideology_position", {})
	if stored is Dictionary:
		return Vector2(float(stored.get("economic", 0.0)), float(stored.get("social", 0.0)))
	return Vector2.ZERO

static func monthly(st: Dictionary) -> Dictionary:
	ensure(st)
	var gov := _gov_position(st)
	var summary := {"changed": [], "strongest": "", "weakest": ""}
	var best := -1.0
	var worst := 101.0
	for entry in definitions():
		var id := str(entry.get("id", ""))
		var group: Dictionary = st.social_groups[id]
		var pref_data: Dictionary = group.get("preferences", {}) if group.get("preferences") is Dictionary else {}
		var pref := Vector2(float(pref_data.get("economic", 0.0)), float(pref_data.get("social", 0.0)))
		var alignment := 1.0 - clampf(pref.distance_to(gov) / 282.8427, 0.0, 1.0)
		var target := 46.0 + (float(st.get("approval", 45.0)) - 45.0) * 0.18 + _macro_pressure(entry, st) + (alignment - 0.5) * 16.0
		var before := float(group.satisfaction)
		var after := clampf(before + (clampf(target, 5.0, 95.0) - before) * 0.16, 5.0, 95.0)
		group.satisfaction = after
		group.approval = after
		group.economic = clampf(float(group.economic) + (_economic_condition(entry, st) - float(group.economic)) * 0.14, 5.0, 95.0)
		var history: Array = group.get("history", [])
		history.append(after)
		if history.size() > 24:
			history = history.slice(history.size() - 24, history.size())
		group["history"] = history
		if absf(after - before) >= 0.05:
			summary.changed.append({"group": id, "delta": after - before})
		if after > best:
			best = after
			summary.strongest = id
		if after < worst:
			worst = after
			summary.weakest = id
	st["social_support"] = support_index(st)
	st["income_support"] = income_support(st)
	st["demographics"] = legacy_demographics(st)
	return summary

## Aplica a incidência declarada de uma política. Os efeitos macro continuam
## sendo aplicados pelo sistema que aprovou a política; aqui só muda a
## satisfação dos grupos, com explicação explícita.
static func apply_policy(st: Dictionary, policy_id: String) -> Array:
	ensure(st)
	var policy := policy_def(policy_id)
	if policy.is_empty():
		return []
	var changes: Array = []
	var groups: Dictionary = policy.get("groups", {})
	for id in groups.keys():
		if not (st.social_groups as Dictionary).has(str(id)):
			continue
		var group: Dictionary = st.social_groups[str(id)]
		var delta := float(groups[id])
		group.satisfaction = clampf(float(group.satisfaction) + delta, 5.0, 95.0)
		group.approval = float(group.satisfaction)
		group["last_policy"] = policy_id
		changes.append({"group": str(id), "delta": delta})
	var log: Array = st.get("policy_log", []) if st.get("policy_log") is Array else []
	log.push_front({"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 0))], "policy": policy_id, "label": str(policy.get("label", policy_id)), "explanation": str(policy.get("explanation", "")), "groups": changes})
	if log.size() > 30:
		log = log.slice(0, 30)
	st["policy_log"] = log
	st["social_support"] = support_index(st)
	st["income_support"] = income_support(st)
	st["demographics"] = legacy_demographics(st)
	return changes

## Eventos antigos falam em Jovens/Trabalhadores/etc. Converte o delta para os
## grupos detalhados sem duplicar o valor entre as camadas.
static func apply_legacy(st: Dictionary, legacy: Dictionary) -> void:
	ensure(st)
	var mapping := {
		"Jovens": {"students": 0.7, "unemployed": 0.3},
		"Trabalhadores": {"industrial_workers": 0.35, "service_workers": 0.35, "unemployed": 0.15, "informal": 0.15},
		"Empreendedores": {"entrepreneurs": 0.7, "high_income": 0.3},
		"Aposentados": {"retirees": 0.8, "public_sector": 0.2},
		"Rurais": {"farmers": 0.8, "informal": 0.2},
	}
	for key in legacy.keys():
		if not mapping.has(str(key)):
			continue
		for group_id in mapping[str(key)].keys():
			if (st.social_groups as Dictionary).has(group_id):
				var group: Dictionary = st.social_groups[group_id]
				group.satisfaction = clampf(float(group.satisfaction) + float(legacy[key]) * float(mapping[str(key)][group_id]), 5.0, 95.0)
				group.approval = float(group.satisfaction)
	st["social_support"] = support_index(st)
	st["income_support"] = income_support(st)
	st["demographics"] = legacy_demographics(st)

static func layer_share(st: Dictionary, layer: String) -> float:
	var total := 0.0
	for entry in definitions():
		if str(entry.get("layer", "")) == layer:
			total += float((st.get("social_groups", {}) as Dictionary).get(str(entry.get("id", "")), {}).get("share", entry.get("share", 0.0)))
	return total

## Índice eleitoral: apenas a camada ocupacional, ponderada pela participação.
static func support_index(st: Dictionary) -> float:
	if not (st.get("social_groups") is Dictionary) or (st.social_groups as Dictionary).is_empty():
		init_state(st)
	var total := 0.0
	var weight := 0.0
	for entry in definitions():
		if str(entry.get("layer", "")) != "occupation":
			continue
		var group: Dictionary = st.social_groups.get(str(entry.get("id", "")), {})
		var share := float(group.get("share", entry.get("share", 0.0)))
		total += float(group.get("approval", 45.0)) * share
		weight += share
	return clampf(total / maxf(0.001, weight), 0.0, 100.0)

static func income_support(st: Dictionary) -> float:
	var total := 0.0
	var weight := 0.0
	for entry in definitions():
		if str(entry.get("layer", "")) != "income":
			continue
		var group: Dictionary = st.social_groups.get(str(entry.get("id", "")), {})
		total += float(group.get("approval", 45.0)) * float(group.get("share", entry.get("share", 0.0)))
		weight += float(group.get("share", entry.get("share", 0.0)))
	return clampf(total / maxf(0.001, weight), 0.0, 100.0)

## Compatibilidade com a eleição e os eventos existentes: cinco categorias
## legadas calculadas a partir dos grupos detalhados, nunca somadas em dobro.
static func legacy_demographics(st: Dictionary) -> Dictionary:
	var groups: Dictionary = st.get("social_groups", {})
	var map := {
		"Jovens": {"students": 0.7, "unemployed": 0.3},
		"Trabalhadores": {"industrial_workers": 0.35, "service_workers": 0.35, "unemployed": 0.15, "informal": 0.15},
		"Empreendedores": {"entrepreneurs": 0.7, "high_income": 0.3},
		"Aposentados": {"retirees": 0.8, "public_sector": 0.2},
		"Rurais": {"farmers": 0.8, "informal": 0.2},
	}
	var result := {}
	for key in map.keys():
		var total := 0.0
		var mapping: Dictionary = map[key]
		for id in mapping.keys():
			total += float(groups.get(id, {}).get("approval", 45.0)) * float(mapping[id])
		result[key] = clampf(total, 0.0, 100.0)
	return result

static func group(st: Dictionary, id: String) -> Dictionary:
	return (st.get("social_groups", {}) as Dictionary).get(id, {}) if st.get("social_groups") is Dictionary else {}

static func sorted_groups(st: Dictionary, layer := "occupation") -> Array:
	var rows: Array = []
	for entry in definitions():
		if str(entry.get("layer", "")) != layer:
			continue
		var id := str(entry.get("id", ""))
		var group_data := group(st, id)
		rows.append({
			"id": id, "label": str(group_data.get("label", entry.get("label", id))),
			"share": float(group_data.get("share", entry.get("share", 0.0))),
			"approval": float(group_data.get("approval", 45.0)),
			"economic": float(group_data.get("economic", 50.0)),
			"concerns": group_data.get("concerns", entry.get("concerns", [])),
			"history": group_data.get("history", []),
		})
	rows.sort_custom(func(a, b): return float(a.approval) > float(b.approval))
	return rows

static func explanation(policy_id: String) -> String:
	return str(policy_def(policy_id).get("explanation", ""))
