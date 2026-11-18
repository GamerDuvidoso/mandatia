extends SceneTree
## Sonda manual: exercita o Ollama real nos quatro contratos da IA.
## Uso: godot --headless --path . --script tools/probe_ollama.gd

class StubGame extends Node:
	var state: Dictionary = {}

var ai: Node = null

func _initialize() -> void:
	var game := StubGame.new()
	game.state = {"ai_decisions": {}}
	root.add_child(game)
	ai = preload("res://scripts/ai/ollama_client.gd").new()
	root.add_child(ai)
	# Em --script o root só entra na árvore no primeiro frame; sem isso o
	# HTTPRequest responde ERR_UNCONFIGURED.
	await process_frame
	ai.attach(game)
	var waited := 0.0
	while waited < 10.0 and not bool(ai.availability_checked):
		await create_timer(0.1).timeout
		waited += 0.1
	print("[probe] modelo=%s disponivel=%s erro=%s" % [ai.model, ai.ai_available, ai.last_error])
	if not bool(ai.ai_available):
		print("[probe] FALHA: modelo indisponivel")
		quit(2)
		return
	# Votação em blocos, como no jogo: o 3B não devolve as 13 bancadas de uma vez.
	var banks := ["PL", "PT", "UNIAO", "PP", "PSD", "MDB", "REPUBLICANOS", "PDT", "PSB", "PSOL", "PODE", "PV", "NOVO"]
	var seats := {"PL": 99, "PT": 67, "UNIAO": 59, "PP": 50, "PSD": 44, "MDB": 44, "REPUBLICANOS": 44, "PDT": 17, "PSB": 14, "PSOL": 12, "PODE": 12, "PV": 6, "NOVO": 3}
	var axes := {"PL": 0.4, "PT": -0.6, "UNIAO": 0.5, "PP": 0.3, "PSD": 0.2, "MDB": 0.0, "REPUBLICANOS": 0.35, "PDT": -0.4, "PSB": -0.35, "PSOL": -0.7, "PODE": 0.1, "PV": -0.45, "NOVO": 0.6}
	var partners := ["UNIAO", "PP", "PSD", "PDT", "PSB", "PODE", "PV"]
	var covered := 0
	var cursor := 0
	while cursor < banks.size():
		var chunk: Array = banks.slice(cursor, cursor + 5)
		var chunk_map := {}
		var lines: Array = []
		for party in chunk:
			chunk_map[str(party)] = int(seats[str(party)])
			lines.append("%s: %d cadeiras, eixo %.2f, %s" % [str(party), int(seats[str(party)]), float(axes[str(party)]), "aliado" if partners.has(str(party)) else "oposição"])
		var payload := await _run(
			"legislative",
			{"proposicao": "Reforma tributaria", "eixo": 0.2, "coesao": 62.0, "bancadas": lines, "ids_permitidos": chunk},
			{"bill": {"axis": 0.2}, "seat_map": chunk_map, "axes": axes, "partners": partners, "cohesion": 62.0, "entities": chunk},
			{"month": 3, "year": 2027, "country": "BR%d" % cursor}
		)
		var value: Dictionary = payload.get("value", {}) if payload.get("value") is Dictionary else {}
		var votes: Dictionary = value.get("votes", {}) if value.get("votes") is Dictionary else {}
		if str(payload.get("source", "")) == "ollama":
			covered += votes.size()
		cursor += 5
	print("[probe] legislative cobertura=%d/%d bancadas pelo modelo" % [covered, banks.size()])
	await _run(
		"electoral",
		{"pais": "Brasil", "mes": 8, "ano": 2027, "disputa": "governo", "pesquisa": ["PL: 25.0%", "PT: 21.0%", "UNIAO: 12.0%", "PSD: 9.0%", "MDB: 8.0%"], "ids_permitidos": ["PL", "PT", "UNIAO", "PSD", "MDB", "OUTROS"]},
		{"base_shares": {"PL": 25.0, "PT": 21.0, "UNIAO": 12.0, "PSD": 9.0, "MDB": 8.0, "OUTROS": 25.0}, "entities": ["PL", "PT", "UNIAO", "PSD", "MDB"]},
		{"month": 8, "year": 2027, "country": "BR"}
	)
	await _run(
		"events",
		{"pais": "Brasil", "governo": "governo", "aprovacao": 41.0, "popularidade": 38.0, "mes": 3, "ano": 2027},
		{"entities": ["evento", "BR"]},
		{"month": 3, "year": 2027, "country": "BR"}
	)
	await _run(
		"international",
		{"pais": "Brasil", "mes": 12, "ano": 2027, "bancadas": ["PL", "PT", "UNIAO", "PP", "MDB"], "ids_permitidos": ["PL", "PT", "UNIAO", "PP", "MDB"]},
		{"party_ids": ["PL", "PT", "UNIAO", "PP", "MDB"], "entities": ["PL", "PT", "UNIAO", "PP", "MDB"]},
		{"month": 12, "year": 2027, "country": "BR"}
	)
	print("[probe] log=%s" % ai.log_path())
	quit(0)

func _run(contract: String, ctx: Dictionary, data: Dictionary, meta: Dictionary) -> Dictionary:
	var box: Array = []
	var start := Time.get_ticks_msec()
	ai.request(contract, ctx, data, meta, func(payload: Dictionary) -> void: box.append(payload))
	while box.is_empty() and Time.get_ticks_msec() - start < 60000:
		await create_timer(0.2).timeout
	if box.is_empty():
		print("[probe] %s TIMEOUT" % contract)
		return {}
	var payload: Dictionary = box[0]
	print("[probe] %s source=%s reason=%s %dms value=%s" % [
		contract, str(payload.get("source", "")), str(payload.get("reason", "")),
		Time.get_ticks_msec() - start, JSON.stringify(payload.get("value", {})).substr(0, 320),
	])
	return payload
