extends SceneTree
## Sonda ponta a ponta com IA real: plenário + mês completo (evento e cenário
## internacional) dentro do jogo, conferindo no log NDJSON o que veio do modelo.
##
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/probe_ai_end_to_end.gd

const Legislature := preload("res://scripts/sim/legislature.gd")

var game: Node = null
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _fail(message: String) -> void:
	failures.append(message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("[e2e] cena principal não carregou")
		quit(1)
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var ai: Node = game.get("ai")
	if ai == null:
		print("[e2e] cliente de IA ausente")
		quit(1)
		return
	var waited := 0.0
	while not bool(ai.get("availability_checked")) and waited < 15.0:
		await _wait(0.25)
		waited += 0.25
	if not bool(ai.get("ai_available")):
		print("[e2e] Ollama indisponível: " + str(ai.get("last_error")))
		quit(1)
		return
	waited = 0.0
	while ai.get("_warm") != null and is_instance_valid(ai.get("_warm")) and waited < 240.0:
		await _wait(0.5)
		waited += 0.5
	print("[e2e] modelo aquecido em %.1fs" % waited)

	# Campanha real em BR: o seat_map do país tem todas as bancadas.
	game.call("_show_new_game")
	await process_frame
	game.get("new_country").select(0)
	game.call("_on_country_selected", 0)
	game.get("new_start_mode").select(0)
	game.call("_on_start_mode_changed", 0)
	game.get("new_party_name").text = "Frente Sonda"
	game.get("new_party_abbr").text = "FS"
	game.get("new_leader").text = "Líder Sonda"
	game.call("_start_campaign")
	game.call("_auto_pick_promises")
	await process_frame
	var state: Dictionary = game.get("state")
	var seat_map: Dictionary = state.get("seat_map", {})
	var banks := 0
	for key in seat_map.keys():
		if int(seat_map[key]) > 0:
			banks += 1
	print("[e2e] país=%s câmara=%d bancadas=%d" % [str(state.get("country_id", "")), int(state.get("chamber_seats", 0)), banks])

	# Plenário: a proposição passa por todos os blocos consultados à IA.
	var bill_id := ""
	for bill in Legislature.BILLS:
		if not bool(bill.get("requires_government", false)):
			bill_id = str(bill.get("id", ""))
			break
	if bill_id == "":
		_fail("nenhuma proposição parlamentar disponível")
	else:
		print("[e2e] votando proposição %s" % bill_id)
		game.call("_propose_bill", bill_id)
		var deadline := Time.get_ticks_msec() + 180000
		while bool(game.get("_bill_in_progress")) and Time.get_ticks_msec() < deadline:
			await _wait(0.25)
		if bool(game.get("_bill_in_progress")):
			_fail("votação não terminou em 180s")
		var bills: Array = state.get("bills", [])
		if bills.is_empty():
			_fail("nenhuma votação registrada na agenda")
		else:
			var last: Dictionary = bills[0]
			var total := int(last.get("ayes", 0)) + int(last.get("nayes", 0)) + int(last.get("abstain", 0))
			print("[e2e] resultado: %s · %d a %d · %d registrados" % [
				"aprovada" if bool(last.get("approved", false)) else "rejeitada",
				int(last.get("ayes", 0)), int(last.get("nayes", 0)), total,
			])
			if total <= 0:
				_fail("apuração vazia na proposição")

	# Mês completo com evento e cenário internacional devidos.
	state["date_month"] = 12
	state["month_completed"] = ""
	game.set("_event_due", true)
	game.set("_international_due", true)
	var stamp := "%d-12" % int(state.get("date_year", 2027))
	var start := Time.get_ticks_msec()
	game.call("_resolve_month", stamp)
	var closed := -1
	var month_deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < month_deadline:
		await _wait(0.2)
		if str((game.get("state") as Dictionary).get("month_completed", "")) == stamp:
			closed = Time.get_ticks_msec() - start
			break
	if closed < 0:
		_fail("mês não fechou em 120s")
	else:
		var intl: Dictionary = (game.get("state") as Dictionary).get("international", {})
		print("[e2e] mês fechado em %dms · internacional source=%s · evento=%s" % [
			closed, str(intl.get("source", "?")), str((game.get("state") as Dictionary).get("event", "")).substr(0, 60),
		])

	# O que o modelo entregou de fato, lido do log NDJSON da IA.
	var counts := {}
	var partials := 0
	var log_text := FileAccess.get_file_as_string(str(ai.call("log_path")))
	for line in log_text.split("\n", false):
		var entry: Variant = JSON.parse_string(line)
		if not (entry is Dictionary):
			continue
		var contract := str((entry as Dictionary).get("contract", ""))
		var source := str((entry as Dictionary).get("source", ""))
		counts["%s:%s" % [contract, source]] = int(counts.get("%s:%s" % [contract, source], 0)) + 1
		if str((entry as Dictionary).get("validation_result", "")).begins_with("parcial"):
			partials += 1
	print("[e2e] log: %s · blocos parciais=%d" % [str(counts), partials])
	if int(counts.get("legislative:ollama", 0)) <= 0:
		_fail("nenhum bloco de plenário veio do modelo")
	if int(counts.get("events:ollama", 0)) <= 0:
		_fail("evento do mês não veio do modelo")
	if int(counts.get("international:ollama", 0)) <= 0:
		_fail("cenário internacional não veio do modelo")

	if failures.is_empty():
		print("[e2e] PASS: plenário, evento e internacional resolvidos pelo modelo local")
		quit(0)
		return
	for failure in failures:
		print("[e2e] FALHA: " + failure)
	quit(1)
