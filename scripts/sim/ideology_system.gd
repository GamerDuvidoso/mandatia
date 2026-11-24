extends RefCounted
## Sistema B1: posição ideológica em dois eixos.
##
## Puro e determinístico. As posições são ANALÍTICAS, não dados oficiais: o
## catálogo parte do rótulo de ideologia de cada partido e aplica overrides
## manuais validados por país quando existem. Nunca inventa posição "oficial".

const DATA_PATH := "res://config/ideologies.json"
const MAX_DISTANCE := 282.8427

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_config = parsed if parsed is Dictionary else {}
	return _config

static func fold(text: String) -> String:
	var out := text.to_lower().strip_edges()
	var accents := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var plain := "aaaaaeeeeiiiiooooouuuucn"
	for i in accents.length():
		out = out.replace(accents[i], plain[i])
	return out

static func clamp_position(economic: float, social: float) -> Vector2:
	return Vector2(clampf(economic, -100.0, 100.0), clampf(social, -100.0, 100.0))

## Categoria mais específica vence: "social-democrata" antes de "democrata".
static func category_position(label: String) -> Vector2:
	var text := fold(label)
	var categories: Dictionary = config().get("categories", {})
	var best := ""
	for key in categories.keys():
		var rule := fold(str(key))
		if text.contains(rule) and rule.length() > best.length():
			best = rule
	if best == "":
		# Fallback conservador: rótulos desconhecidos ficam no centro.
		return Vector2.ZERO
	var entry: Dictionary = categories[best]
	return clamp_position(float(entry.get("economic", 0.0)), float(entry.get("social", 0.0)))

static func party_position(country_id: String, party: Dictionary) -> Vector2:
	var overrides: Dictionary = config().get("party_overrides", {})
	var country: Variant = overrides.get(country_id, {})
	var abbr := str(party.get("abbr", "")).strip_edges()
	var name := str(party.get("name", "")).strip_edges()
	if country is Dictionary:
		for key in (country as Dictionary).keys():
			var candidate := str(key)
			if candidate == abbr or fold(candidate) == fold(name):
				var value: Variant = (country as Dictionary)[key]
				if value is Array and (value as Array).size() >= 2:
					return clamp_position(float(value[0]), float(value[1]))
	var label := str(party.get("ideology", "centro"))
	return category_position(label)

## Mapa sigla -> Vector2 para todos os partidos oficiais do país + jogador.
static func positions(state: Dictionary, country: Dictionary) -> Dictionary:
	var result := {}
	for party in country.get("official_parties", []):
		var key := str(party.get("abbr", "")).strip_edges()
		if key != "":
			result[key] = party_position(str(country.get("id", "")), party)
	var player_key := str(state.get("abbr", "Jogador")).strip_edges()
	if player_key != "":
		result[player_key] = player_position(state)
	return result

static func player_position(state: Dictionary) -> Vector2:
	var stored: Variant = state.get("ideology_position", {})
	if stored is Dictionary and (stored as Dictionary).has("economic") and (stored as Dictionary).has("social"):
		return clamp_position(float(stored.economic), float(stored.social))
	var country = state.get("legislature", {})
	var party := {"abbr": str(state.get("abbr", "")), "name": str(state.get("party", "")), "ideology": str(state.get("ideology", "centro"))}
	var pos := party_position(str(state.get("country_id", "")), party) if country is Dictionary else category_position(str(state.get("ideology", "")))
	state["ideology_position"] = {"economic": pos.x, "social": pos.y}
	return pos

static func distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

static func normalized_distance(a: Vector2, b: Vector2) -> float:
	return clampf(distance(a, b) / MAX_DISTANCE, 0.0, 1.0)

static func compatibility(a: Vector2, b: Vector2) -> float:
	return clampf(100.0 - normalized_distance(a, b) * 100.0, 0.0, 100.0)

static func nearest_category(pos: Vector2) -> String:
	var economic := "centro"
	if pos.x <= -60: economic = "esquerda"
	elif pos.x <= -20: economic = "centro-esquerda"
	elif pos.x >= 60: economic = "direita"
	elif pos.x >= 20: economic = "centro-direita"
	var social := "moderado"
	if pos.y <= -60: social = "progressista"
	elif pos.y <= -20: social = "liberal"
	elif pos.y >= 60: social = "tradicionalista"
	elif pos.y >= 20: social = "conservador"
	return "%s · %s" % [economic, social]

## Eixo econômico normalizado (-1..1) para compatibilidade com o hemiciclo
## e com os contratos antigos que só conheciam um eixo.
static func legacy_axis(pos: Vector2) -> float:
	return clampf(pos.x / 100.0, -1.0, 1.0)

static func legacy_axes(state: Dictionary, country: Dictionary) -> Dictionary:
	var result := {}
	for key in positions(state, country).keys():
		result[str(key)] = legacy_axis(positions(state, country)[key])
	return result
