extends RefCounted
## Modelo eleitoral puro do MANDATO.
##
## Lê apenas o catálogo de países (res://config/countries.json) e o estado da
## campanha: não cria nós, não escreve arquivos e não usa aleatoriedade sem
## semente. Assim pode ser testado em headless pela cena de teste.
##
## Regras:
## - câmara baixa = primeira câmara cujo id termina em -LC01 (fallback: a primeira);
## - tamanho da câmara = statutory_seats, com fallback para occupied_seats;
## - maioria = metade + 1 das cadeiras da câmara;
## - votos partem das cadeiras reais do snapshot (fotografia legislativa);
## - cadeiras distribuídas por D'Hondt sobre a pesquisa, sem cláusula de barreira;
## - presidencial tem segundo turno quando ninguém passa de 50%.

const LOWER := "lower"
const UPPER := "upper"
const UNDECIDED := "Indecisos"
const PLAYER_FALLBACK := "Jogador"

## Remove acentos para comparar rótulos de ideologia sem depender da grafia do JSON.
static func fold(text: String) -> String:
	var out := text.to_lower()
	var accents := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var plain := "aaaaaeeeeiiiiooooouuuucn"
	for i in accents.length():
		out = out.replace(accents[i], plain[i])
	return out

static func _stat_seats(item: Dictionary) -> int:
	var seats := int(item.get("statutory_seats", 0))
	if seats <= 0:
		seats = int(item.get("occupied_seats", 0))
	return maxi(seats, 0)

## Câmara alta por nome/id: o catálogo não usa um padrão único de id
## ("senate", "lower-house", "-LC01", "congress"...), então classificamos por nome.
static func is_upper_chamber(item: Dictionary) -> bool:
	var text := fold(str(item.get("name", "")) + " " + str(item.get("id", "")))
	return text.contains("senad") or text.contains("senate") or text.contains("camara alta") or text.ends_with("-uc01")

static func is_lower_chamber(item: Dictionary) -> bool:
	if is_upper_chamber(item):
		return false
	var text := fold(str(item.get("name", "")) + " " + str(item.get("id", "")))
	return text.contains("diputad") or text.contains("deputad") or text.contains("representante") or text.contains("commons") or text.contains("camara baixa") or text.contains("lower") or text.ends_with("-lc01") or text.contains("congress") or text.contains("assembly") or text.contains("assembleia") or text.contains("deput") or text.contains("congreso") or text.contains("asamblea")

static func chamber(country: Dictionary, kind: String) -> Dictionary:
	var chambers: Array = country.get("chambers", [])
	if chambers.is_empty():
		return {}
	var want_lower := kind != UPPER
	var best_upper := {}
	for item in chambers:
		if is_upper_chamber(item):
			if best_upper.is_empty() or _stat_seats(item) > _stat_seats(best_upper):
				best_upper = item
			continue
		if want_lower:
			return item
	if want_lower:
		var best := {}
		for item in chambers:
			if best.is_empty() or _stat_seats(item) > _stat_seats(best):
				best = item
		return best
	return best_upper

static func chamber_seats(country: Dictionary, kind := LOWER) -> int:
	return _stat_seats(chamber(country, kind))

static func chamber_name(country: Dictionary, kind := LOWER) -> String:
	return str(chamber(country, kind).get("name", ""))

static func majority_of(seats: int) -> int:
	if seats <= 0:
		return 1
	return int(seats / 2.0) + 1

## Sistemas com chefe de governo próprio (primeiro-ministro) não elegem o chefe
## de Estado diretamente: quem forma governo é a maior bancada.
static func is_parliamentary(country: Dictionary) -> bool:
	return country.get("head_of_government", null) != null

## Converte o rótulo de ideologia (classificação, não dado oficial) num eixo
## -1 (esquerda) .. +1 (direita). Serve para transferência de votos e coalizões.
static func ideology_axis(label: String) -> float:
	var text := fold(label)
	for rule in [
		["centro-esquerda", -0.4], ["centro-direita", 0.45], ["centro conservador", 0.3],
		["centrao", 0.0],
		["fascis", 0.95], ["libertar", 0.85], ["direita", 0.7], ["conservador", 0.6],
		["democrata-crist", 0.15], ["social-crist", 0.2],
		["trabalh", -0.5], ["social-democra", -0.45],
		["socialis", -0.7], ["comunis", -0.9], ["esquerda", -0.6],
		["progressis", -0.3], ["ecolog", -0.35], ["sustentab", -0.25],
		["social-lib", 0.2], ["liberal", 0.35], ["centr", 0.0],
	]:
		if text.contains(rule[0]):
			return float(rule[1])
	return 0.0

static func axes(state: Dictionary, country: Dictionary) -> Dictionary:
	var result := {}
	for party in country.get("official_parties", []):
		result[str(party.get("abbr", ""))] = ideology_axis(str(party.get("ideology", "")))
	result[str(state.get("abbr", PLAYER_FALLBACK))] = ideology_axis(str(state.get("ideology", "")))
	return result

## Fotografia legislativa convertida em percentuais de voto.
## Blocos sem cadeira publicada entram com peso mínimo para continuarem visíveis.
static func baseline_shares(country: Dictionary, kind := LOWER) -> Dictionary:
	var shares := {}
	var total := 0.0
	for party in country.get("official_parties", []):
		var key := str(party.get("abbr", party.get("name", ""))).strip_edges()
		if key == "":
			continue
		var field := "lower_house_seats" if kind == LOWER else "senate_seats"
		var raw: Variant = party.get(field, null)
		var value := float(raw) if raw != null else 0.5
		if value < 0.0:
			value = 0.0
		shares[key] = float(shares.get(key, 0.0)) + value
	for key in shares.keys():
		total += float(shares[key])
	if total <= 0.0:
		return {}
	for key in shares.keys():
		shares[key] = float(shares[key]) / total * 100.0
	return shares

const GROUP_WEIGHTS := {"Jovens": 0.22, "Trabalhadores": 0.34, "Empreendedores": 0.12, "Aposentados": 0.16, "Rurais": 0.16}

## Apoio ponderado dos cinco grupos sociais; sem dados, cai na popularidade.
static func demographic_support(state: Dictionary) -> float:
	var popularity := float(state.get("popularity", 4.0))
	var groups: Variant = state.get("demographics", {})
	if not (groups is Dictionary) or (groups as Dictionary).is_empty():
		return popularity
	var total := 0.0
	for key in GROUP_WEIGHTS.keys():
		total += float(GROUP_WEIGHTS[key]) * float((groups as Dictionary).get(key, popularity))
	return total

## Média do apoio nas regiões; sem dados, cai na popularidade.
static func regional_support(state: Dictionary) -> float:
	var support: Variant = state.get("region_support", [])
	if not (support is Array) or (support as Array).is_empty():
		return float(state.get("popularity", 4.0))
	var sum := 0.0
	for value in support:
		sum += float(value)
	return sum / float((support as Array).size())

## Voto do partido do jogador: popularidade, grupos sociais e regiões, mais o
## voto retrospectivo. No governo, aprovação alta ajuda e inflação/desemprego
## cobram a conta; na oposição o sinal inverte (governo impopular favorece).
static func player_share(state: Dictionary) -> float:
	var base := float(state.get("popularity", 4.0)) * 0.55 + demographic_support(state) * 0.25 + regional_support(state) * 0.20
	base *= 0.8
	base += float(state.get("campaign", 0.0)) * 0.3
	base += float(state.get("recognition", 0.0)) * 0.05
	# B2/B6: apoio dos grupos detalhados e custo eleitoral de crises ativas.
	base += (float(state.get("social_support", 50.0)) - 50.0) * 0.04
	base -= maxf(0.0, float(state.get("campaign_penalty", 0.0))) * 0.35
	var approval_gap := float(state.get("approval", 45.0)) - 45.0
	var inflation_gap := maxf(0.0, float(state.get("inflation", 4.8)) - 4.0)
	var jobless_gap := maxf(0.0, float(state.get("unemployment", 8.2)) - 8.0)
	if bool(state.get("government", false)):
		base += clampf(approval_gap * 0.12, -4.0, 4.0) - inflation_gap * 0.6 - jobless_gap * 0.3
	else:
		base += clampf(-approval_gap * 0.10, -3.0, 3.0) + minf(inflation_gap * 0.25, 2.5) + minf(jobless_gap * 0.15, 2.0)
	return clampf(base, 0.5, 65.0)

## Segundo turno em dois eixos: a transferência usa a distância completa
## (econômica e social), não apenas o eixo esquerda-direita.
static func presidential_2d(shares: Dictionary, positions: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var round1 := []
	for key in shares.keys():
		if key == UNDECIDED:
			continue
		round1.append([str(key), maxf(float(shares[key]) + rng.randf_range(-1.2, 1.2), 0.1)])
	round1.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	if round1.is_empty():
		return {"winner": "", "round1": [], "round2": [], "second_round": false}
	if float(round1[0][1]) > 50.0 or round1.size() == 1:
		return {"winner": str(round1[0][0]), "round1": round1, "round2": [], "second_round": false}
	var left: Array = round1[0]
	var right: Array = round1[1]
	var left_pos: Vector2 = positions.get(str(left[0]), Vector2.ZERO)
	var right_pos: Vector2 = positions.get(str(right[0]), Vector2.ZERO)
	var left_score := float(left[1])
	var right_score := float(right[1])
	for i in range(2, round1.size()):
		var item: Array = round1[i]
		var weight := float(item[1])
		var pos: Vector2 = positions.get(str(item[0]), Vector2.ZERO)
		var left_distance := pos.distance_to(left_pos)
		var right_distance := pos.distance_to(right_pos)
		var total := left_distance + right_distance
		if total <= 0.001:
			left_score += weight * 0.5
			right_score += weight * 0.5
		else:
			left_score += weight * (right_distance / total)
			right_score += weight * (left_distance / total)
	var round2 := [[str(left[0]), left_score], [str(right[0]), right_score]]
	round2.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return {"winner": str(round2[0][0]), "round1": round1, "round2": round2, "second_round": true}

static func undecided_share(state: Dictionary) -> float:
	return clampf(14.0 - float(state.get("recognition", 2.0)) * 0.08, 4.0, 14.0)

## Pesquisa nacional completa (soma 100): partidos reais do país + partido do
## jogador + indecisos. O partido do jogador absorve o apoio calculado, então
## jogar com um partido oficial não duplica a linha.
static func poll_shares(state: Dictionary, country: Dictionary, kind := LOWER) -> Dictionary:
	var player_key := str(state.get("abbr", PLAYER_FALLBACK)).strip_edges()
	if player_key == "":
		player_key = PLAYER_FALLBACK
	var player := player_share(state)
	var undecided := undecided_share(state)
	var remaining := maxf(0.0, 100.0 - player - undecided)
	var base := baseline_shares(country, kind)
	base.erase(player_key)
	var base_total := 0.0
	for value in base.values():
		base_total += float(value)
	var result := {}
	if base_total > 0.0:
		var factor := remaining / base_total
		for key in base.keys():
			result[key] = float(base[key]) * factor
	result[player_key] = player
	result[UNDECIDED] = undecided
	return result

static func sorted_pairs(values: Dictionary) -> Array:
	var pairs := []
	for key in values.keys():
		pairs.append([str(key), float(values[key])])
	pairs.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return pairs

## D'Hondt puro: divisores sucessivos, sem cláusula de barreira.
static func allocate_dhondt(shares: Dictionary, seats: int) -> Dictionary:
	var result := {}
	if seats <= 0:
		return result
	var contested := {}
	for key in shares.keys():
		if key == UNDECIDED:
			continue
		var value := float(shares[key])
		if value <= 0.01:
			continue
		contested[key] = value
		result[key] = 0
	if contested.is_empty():
		return result
	var divisor := {}
	for key in contested.keys():
		divisor[key] = 1.0
	for _seat in range(seats):
		var best := ""
		var best_score := -1.0
		for key in contested.keys():
			var score := float(contested[key]) / float(divisor[key])
			if score > best_score:
				best_score = score
				best = key
		if best == "":
			break
		result[best] = int(result[best]) + 1
		divisor[best] = float(divisor[best]) + 1.0
	return result

static func largest_party(seat_map: Dictionary) -> String:
	var best := ""
	var best_seats := -1
	for key in seat_map.keys():
		var seats := int(seat_map[key])
		if seats > best_seats:
			best_seats = seats
			best = str(key)
	return best

## Primeiro turno e, se necessário, segundo turno com transferência por
## proximidade ideológica entre os partidos eliminados e os dois finalistas.
static func presidential(shares: Dictionary, axis_by_party: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var round1 := []
	for key in shares.keys():
		if key == UNDECIDED:
			continue
		var value := float(shares[key]) + rng.randf_range(-1.2, 1.2)
		round1.append([str(key), maxf(value, 0.1)])
	round1.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	if round1.is_empty():
		return {"winner": "", "round1": [], "round2": [], "second_round": false}
	var leader: Array = round1[0]
	if float(leader[1]) > 50.0 or round1.size() == 1:
		return {"winner": str(leader[0]), "round1": round1, "round2": [], "second_round": false}
	var left: Array = round1[0]
	var right: Array = round1[1]
	var left_score := float(left[1])
	var right_score := float(right[1])
	var left_axis := float(axis_by_party.get(str(left[0]), 0.0))
	var right_axis := float(axis_by_party.get(str(right[0]), 0.0))
	for i in range(2, round1.size()):
		var item: Array = round1[i]
		var weight := float(item[1])
		var axis := float(axis_by_party.get(str(item[0]), 0.0))
		var left_distance := absf(axis - left_axis)
		var right_distance := absf(axis - right_axis)
		var total := left_distance + right_distance
		if total <= 0.001:
			left_score += weight * 0.5
			right_score += weight * 0.5
		else:
			left_score += weight * (right_distance / total)
			right_score += weight * (left_distance / total)
	var round2 := [[str(left[0]), left_score], [str(right[0]), right_score]]
	round2.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return {"winner": str(round2[0][0]), "round1": round1, "round2": round2, "second_round": true}
