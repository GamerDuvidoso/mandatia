extends RefCounted
## E1 — registro histórico e notícias do mundo autônomo.
##
## Todo evento guarda data, país, categoria, descrição, gatilho, consequências,
## atores e status. A notícia é derivada do evento; não há manchete sem fato.
## A deduplicação evita repetir o mesmo acontecido em meses consecutivos.

const MAX_HISTORY := 1200
const MAX_NEWS := 60

static func ensure(world: Dictionary) -> void:
	if not (world.get("history") is Array):
		world["history"] = []
	if not (world.get("news") is Array):
		world["news"] = []
	if not (world.get("stats") is Dictionary):
		world["stats"] = {}

## Contadores persistentes: a história pode ser truncada, mas os totais de uma
## campanha de 20 anos não podem desaparecer com o corte da lista.
static func bump(world: Dictionary, key: String, amount := 1) -> void:
	var stats: Dictionary = world.get("stats", {}) if world.get("stats") is Dictionary else {}
	stats[key] = int(stats.get(key, 0)) + amount
	world["stats"] = stats

static func _month_index(year: int, month: int) -> int:
	return year * 12 + month

## Registra um evento. Devolve false quando é duplicata recente (mesmo país,
## categoria e descrição dentro da janela) ou quando falta descrição.
static func push(world: Dictionary, event: Dictionary, dedupe_months := 2) -> bool:
	ensure(world)
	var country := str(event.get("country", ""))
	var category := str(event.get("category", ""))
	var description := str(event.get("description", ""))
	if description == "":
		return false
	var year := int(event.get("year", 0))
	var month := int(event.get("month", 1))
	var stamp := _month_index(year, month)
	var history: Array = world.history
	# A história é reverse-cronológica: ao encontrar um registro mais antigo que
	# a janela, não há por que continuar varrendo. Isso mantém o custo proporcional
	# à janela (meses), não ao tamanho total do histórico.
	for row in history:
		var row_stamp := _month_index(int(row.get("year", 0)), int(row.get("month", 1)))
		if row_stamp < stamp - dedupe_months:
			break
		if str(row.get("country", "")) != country or str(row.get("category", "")) != category:
			continue
		if str(row.get("description", "")) != description:
			continue
		if absi(stamp - row_stamp) <= dedupe_months:
			return false
	var date := str(event.get("date", ""))
	if date == "":
		date = "%d-%02d" % [year, month]
	var row := {
		"id": "%s:%s:%s:%d" % [date, country, category, history.size()],
		"date": date, "year": year, "month": month,
		"country": country, "country_name": str(event.get("country_name", country)),
		"category": category, "description": description,
		"trigger": str(event.get("trigger", "")),
		"consequences": event.get("consequences", []),
		"actors": event.get("actors", []),
		"status": str(event.get("status", "confirmado")),
		"certainty": str(event.get("certainty", "confirmado")),
	}
	history.push_front(row)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	world["history"] = history
	if bool(event.get("news", false)):
		var headline := str(event.get("headline", description))
		var news: Array = world.get("news", [])
		var duplicate := false
		# Global: a mesma manchete não volta enquanto estiver no giro atual.
		# Eventos recorrentes legítimos (nova eleição, novo acordo) recebem ano
		# no título para não serem confundidos com o fato anterior.
		for item in news:
			if str(item.get("headline", "")) == headline:
				duplicate = true
				break
		if not duplicate:
			news.push_front({
				"date": date, "country": country, "headline": headline,
				"category": category, "status": row.status, "certainty": row.certainty,
			})
			if news.size() > MAX_NEWS:
				news.resize(MAX_NEWS)
			world["news"] = news
	return true

static func recent(world: Dictionary, limit := 12) -> Array:
	ensure(world)
	return (world.get("history", []) as Array).slice(0, limit)

static func news(world: Dictionary, limit := 12) -> Array:
	ensure(world)
	return (world.get("news", []) as Array).slice(0, limit)

static func country_history(world: Dictionary, country: String, limit := 10) -> Array:
	ensure(world)
	var rows := []
	for event in world.history:
		if str(event.get("country", "")) == country:
			rows.append(event)
			if rows.size() >= limit:
				break
	return rows

static func count_since(world: Dictionary, category: String, year: int, month: int, months: int) -> int:
	ensure(world)
	var cutoff := _month_index(year, month) - months
	var count := 0
	for event in world.history:
		if str(event.get("category", "")) != category:
			continue
		if _month_index(int(event.get("year", 0)), int(event.get("month", 1))) >= cutoff:
			count += 1
	return count
