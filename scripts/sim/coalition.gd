extends RefCounted
## Formação de governo por coalizão, a partir das bancadas reais.
##
## Sem nós e sem arquivos: recebe o mapa de cadeiras e os eixos ideológicos
## calculados por scripts/sim/election.gd.

static func distance(a: float, b: float) -> float:
	return absf(a - b)

static func axis_of(axes: Dictionary, key: String) -> float:
	return float(axes.get(key, 0.0))

## Menor coalizão vencedora que inclui a bancada do jogador, somando partidos
## em ordem de proximidade ideológica. Devolve {} quando nem todos os partidos
## disponíveis fecham maioria.
static func minimum_winning(seat_map: Dictionary, axes: Dictionary, player_key: String, majority: int) -> Dictionary:
	var player_seats := int(seat_map.get(player_key, 0))
	if player_seats <= 0 or majority <= 1:
		return {}
	var player_axis := axis_of(axes, player_key)
	var others := []
	for key in seat_map.keys():
		var seats := int(seat_map[key])
		var party := str(key)
		if seats <= 0 or party == player_key:
			continue
		others.append([party, seats, distance(axis_of(axes, party), player_axis)])
	others.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var picked := []
	var total := player_seats
	for item in others:
		if total >= majority:
			break
		picked.append(item)
		total += int(item[1])
	if total < majority:
		return {}
	var partner_seats := 0
	var spread := 0.0
	var names := PackedStringArray()
	for item in picked:
		partner_seats += int(item[1])
		spread = maxf(spread, float(item[2]))
		names.append(str(item[0]))
	return {
		"partners": Array(names),
		"partner_seats": partner_seats,
		"seats": total,
		"majority": majority,
		"cost": 600 + partner_seats * 40,
		"spread": spread,
		"cohesion": clampf(78.0 - spread * 40.0, 20.0, 95.0),
	}
