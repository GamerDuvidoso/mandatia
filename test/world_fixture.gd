extends RefCounted
## Estado de mundo mínimo, determinístico e sem cena.
##
## Usado por `test/test_ai_wiring.gd` e por `tools/ai_proof.gd` para rodar o
## `WorldSim.monthly` real sem instanciar o jogo inteiro (que exige UI, autoloads
## e vários frames). Carrega os catálogos reais (`config/countries.json` e
## `config/economy.json`), então o mundo tem os mesmos 34 países NPC do jogo.

const International := preload("res://scripts/sim/international_system.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")

const COUNTRIES_PATH := "res://config/countries.json"
const ECONOMY_PATH := "res://config/economy.json"

static func countries() -> Array:
	if not FileAccess.file_exists(COUNTRIES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COUNTRIES_PATH))
	if not (parsed is Dictionary):
		return []
	var raw: Variant = (parsed as Dictionary).get("countries", [])
	return (raw as Array).duplicate(true) if raw is Array else []

static func economy() -> Dictionary:
	if not FileAccess.file_exists(ECONOMY_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_PATH))
	if not (parsed is Dictionary):
		return {}
	var raw: Variant = (parsed as Dictionary).get("countries", {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

## Estado com o mínimo que `International` e `WorldSim` leem, já inicializado.
static func build_state(country_id: String = "BR") -> Dictionary:
	var st := {
		"country_id": country_id,
		"date_year": 2027,
		"date_month": 1,
		"gdp": 2100.0,
		"funds": 1200,
		"treasury": 1200.0,
		"government": true,
		"approval": 50.0,
		"popularity": 50.0,
		"inflation": 4.5,
		"unemployment": 7.0,
		"economy": 2.0,
		"debt": 60.0,
		"service_index": 50.0,
		"international_state": {},
		"world": {},
		"geopolitics": {},
		"demography": {},
		"tutorial_done": true,
	}
	var catalog := countries()
	var economy_catalog := economy()
	International.init_state(st, catalog, economy_catalog)
	WorldSim.ensure(st, catalog, economy_catalog)
	return st

## Avança a data do estado (o chamador do mês faz isso no jogo).
static func set_date(st: Dictionary, year: int, month: int) -> void:
	st["date_year"] = year
	st["date_month"] = month

## País NPC usado nos testes (o país do jogador fica fora do mundo autônomo).
static func sample_country(st: Dictionary) -> String:
	var countries_map: Dictionary = (st.get("world", {}) as Dictionary).get("countries", {})
	var ids: Array = countries_map.keys()
	ids.sort()
	return str(ids[0]) if not ids.is_empty() else ""
