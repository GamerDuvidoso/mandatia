extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _wait_month(game: Node) -> bool:
	for _i in 300:
		if not bool(game.get("_month_in_progress")):
			return true
		await process_frame
	return false

func _run() -> void:
	var game: Control = MainScene.instantiate()
	root.add_child(game)
	await _frames(12)
	var initial: Dictionary = game.get("state")
	initial["tutorial_done"] = true
	var ai: Node = game.get("ai")
	if ai != null:
		ai.stop()
		ai.set("ai_available", false)
		ai.set("availability_checked", true)
	await _frames(2)
	_check(str(game.get("screen")) == "menu", "jogo deveria iniciar no menu")

	game.call("_show_new_game")
	await _frames(2)
	var country_selector: OptionButton = game.get("new_country")
	_check(country_selector != null and country_selector.item_count > 0, "seleção de país deveria existir")
	var br_index := -1
	for i in country_selector.item_count:
		if country_selector.get_item_text(i).contains("BR"):
			br_index = i
			break
	_check(br_index >= 0, "Brasil deveria estar no catálogo selecionável")
	if br_index >= 0:
		country_selector.select(br_index)
		game.call("_on_country_selected", br_index)
	game.get("new_party_name").text = "Partido Smoke"
	game.get("new_party_abbr").text = "PSM"
	game.get("new_leader").text = "Líder Smoke"
	game.call("_start_campaign")
	await _frames(3)
	game.call("_auto_pick_promises")
	await _frames(3)
	var state: Dictionary = game.get("state")
	_check(bool(state.get("started", false)), "campanha deveria iniciar")
	_check(str(state.get("country_id", "")) == "BR", "campanha deveria guardar BR")
	_check((state.get("promises", []) as Array).size() == 3, "campanha deveria registrar três promessas")
	_check(str(game.get("screen")) == "game", "campanha deveria abrir a tela de jogo")

	var milestones := {1: false, 3: false, 12: false}
	for month in 12:
		game.call("_advance_month")
		var completed := await _wait_month(game)
		_check(completed, "mês %d deveria completar" % (month + 1))
		if month + 1 in milestones:
			milestones[month + 1] = true
			_check(int(state.get("date_month", 0)) >= 1 and int(state.get("date_year", 0)) >= 2027, "data válida no marco %d" % (month + 1))
	_check(bool(milestones[1]) and bool(milestones[3]) and bool(milestones[12]), "marcos 1/3/12 deveriam ser visitados")
	_check(int(state.get("months_to_election", -1)) == 0, "eleição deveria abrir após 12 meses")
	_check((state.get("economy_history", []) as Array).size() >= 13, "histórico econômico deveria registrar os meses")
	_check(FileAccess.file_exists("user://mandatia_save.json"), "fechamento mensal deveria persistir o save")

	game.call("_run_election")
	for _i in 300:
		if not bool(game.get("_election_in_progress")):
			break
		await process_frame
	state = game.get("state")
	_check(not bool(game.get("_election_in_progress")), "eleição deveria terminar")
	_check(not (state.get("last_election", {}) as Dictionary).is_empty(), "eleição deveria registrar o pleito")
	var seat_total := 0
	for value in (state.get("seat_map", {}) as Dictionary).values():
		seat_total += int(value)
	_check(seat_total == int(state.get("chamber_seats", 0)), "D'Hondt deveria preencher toda a câmara")
	_check(str(game.get("screen")) == "result", "eleição deveria abrir a tela de resultado")

	var saved := bool(game.call("_save_game"))
	_check(saved, "save explícito deveria retornar sucesso")
	game.call("_load_game")
	await _frames(3)
	var loaded: Dictionary = game.get("state")
	_check(bool(loaded.get("started", false)), "load deveria preservar campanha iniciada")
	_check(str(loaded.get("country_id", "")) == "BR", "load deveria preservar país")
	_check(int(loaded.get("save_version", 0)) == 6, "load deveria preservar versão do save")

	if failures.is_empty():
		print("CORE_SMOKE_PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("CORE_SMOKE: " + failure)
		print("CORE_SMOKE_FAIL failures=%d checks=%d" % [failures.size(), checks])
		quit(1)
