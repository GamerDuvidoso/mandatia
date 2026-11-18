extends SceneTree
## Sonda da resolução do mês com IA real (evento + cenário internacional).
## Mede a latência de um mês em que os dois contratos são devidos e confirma que
## o mês fecha uma única vez, sem duplicar efeitos. Os dois contratos são
## resolvidos em sequência porque o Ollama atende uma requisição por vez.
##
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/probe_month_parallel.gd

var game: Node = null

func _initialize() -> void:
	call_deferred("_run")

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		print("[parallel] cena principal não carregou")
		quit(1)
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var ai: Node = game.get("ai")
	if ai == null:
		print("[parallel] cliente de IA ausente")
		quit(1)
		return
	var waited := 0.0
	while not bool(ai.get("availability_checked")) and waited < 10.0:
		await _wait(0.25)
		waited += 0.25
	if not bool(ai.get("ai_available")):
		print("[parallel] Ollama indisponível: " + str(ai.get("last_error")))
		quit(1)
		return
	# Aguarda o aquecimento do modelo para não medir o carregamento do disco.
	waited = 0.0
	while ai.get("_warm") != null and is_instance_valid(ai.get("_warm")) and waited < 240.0:
		await _wait(0.5)
		waited += 0.5
	print("[parallel] modelo aquecido em %.1fs" % waited)

	# Campanha rápida em BR para ter bancadas no seat_map.
	game.call("_show_new_game")
	await process_frame
	var nc = game.get("new_country")
	nc.select(0)
	game.call("_on_country_selected", 0)
	var nsm = game.get("new_start_mode")
	nsm.select(0)
	game.call("_on_start_mode_changed", 0)
	game.get("new_party_name").text = "Frente Paralela"
	game.get("new_party_abbr").text = "FP"
	game.get("new_leader").text = "Líder Paralelo"
	game.call("_start_campaign")
	game.call("_auto_pick_promises")
	await process_frame

	var state: Dictionary = game.get("state")
	state["date_month"] = 12
	state["seat_map"] = {"PL": 92, "PT": 68, "FP": 40}
	state["chamber_seats"] = 200
	game.set("_event_due", true)
	game.set("_international_due", true)
	var stamp := "%d-12" % int(state.get("date_year", 2027))
	state["month_completed"] = ""

	var start := Time.get_ticks_msec()
	game.call("_resolve_month", stamp)
	var elapsed_until_close := -1
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		await _wait(0.2)
		if str((game.get("state") as Dictionary).get("month_completed", "")) == stamp:
			elapsed_until_close = Time.get_ticks_msec() - start
			break
	if elapsed_until_close < 0:
		print("[parallel] FALHA: mês não fechou em 90s")
		quit(1)
		return
	var final_state: Dictionary = game.get("state")
	var intl: Dictionary = final_state.get("international", {})
	var official := str(intl.get("source", ""))
	print("[parallel] mês fechado em %dms · internacional source=%s · evento=%s" % [
		elapsed_until_close, official, str((game.get("state") as Dictionary).get("event", "")).substr(0, 60),
	])
	# Idempotência: repetir o fechamento não muda aprovação.
	var approval_before := float((game.get("state") as Dictionary).get("approval", 0.0))
	game.call("_resolve_month", stamp)
	await _wait(0.5)
	var approval_after := float((game.get("state") as Dictionary).get("approval", 0.0))
	if absf(approval_after - approval_before) > 0.001:
		print("[parallel] FALHA: mês reaplicou efeitos (%.2f -> %.2f)" % [approval_before, approval_after])
		quit(1)
		return
	print("[parallel] PASS: fechamento idempotente e contratos do mês resolvidos")
	quit(0)
