extends SceneTree
## E1 — aceitação de 20 anos NO JOGO.
##
## Instancia a cena real, inicia uma campanha, avança 240 meses pelo
## `_advance_month` verdadeiro e resolve automaticamente apenas as eleições
## obrigatórias do jogador (sem escolher políticas, sem IA). Ao final compara o
## mundo inicial com o final e recarrega o save em uma segunda instância.
##
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script test/test_world_20y.gd

const MONTHS := 240
const MAX_FRAMES := 6

var failures: Array = []
var checks := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("[world-20y] " + message)

func _frames(count := 1) -> void:
	for _i in count:
		await process_frame

func _disable_ai(node: Node) -> void:
	var ai: Node = node.get("ai")
	if ai == null:
		return
	ai.set("availability_checked", true)
	ai.set("ai_available", false)
	if ai.has_method("stop"):
		ai.call("stop")
	var probe = ai.get("_probe")
	if probe != null and is_instance_valid(probe):
		probe.queue_free()
		ai.set("_probe", null)
	var warm = ai.get("_warm")
	if warm != null and is_instance_valid(warm):
		warm.queue_free()
		ai.set("_warm", null)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "cena principal deve carregar")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	game.get("state")["tutorial_done"] = true
	await _frames(3)
	_disable_ai(game)
	game.call("_show_new_game")
	await _frames(2)
	var countries: Array = game.get("countries")
	var br_index := -1
	for i in countries.size():
		if str((countries[i] as Dictionary).get("id", "")) == "BR":
			br_index = i
			break
	_check(br_index >= 0, "Brasil deve estar no catálogo")
	if br_index < 0:
		_finish()
		return
	game.get("new_country").select(br_index)
	game.call("_on_country_selected", br_index)
	game.get("new_start_mode").select(0)
	game.call("_on_start_mode_changed", 0)
	game.get("new_party_name").text = "Frente E1"
	game.get("new_party_abbr").text = "FE1"
	game.get("new_leader").text = "Teste E1"
	game.call("_start_campaign")
	await _frames(2)
	if str(game.get("screen")) == "promises":
		game.call("_auto_pick_promises")
		await _frames(2)
	_check(str(game.get("screen")) == "game", "campanha deve começar no jogo")
	var initial := _snapshot(game)
	_check(not (initial.get("countries", {}) as Dictionary).is_empty(), "mundo inicial deve existir")
	if (initial.get("countries", {}) as Dictionary).is_empty():
		_finish()
		return
	_check((initial.countries as Dictionary).size() == 33, "mundo deve começar com 33 países simuláveis")
	print("[world-20y] início: %d países, %d/%d" % [(initial.countries as Dictionary).size(), int(initial.date.year), int(initial.date.month)])
	# 240 meses reais de simulação. A eleição do jogador não reinicializa o mundo;
	# ela apenas abre o resultado e o próximo programa.
	var started_usec := Time.get_ticks_usec()
	var advanced := 0
	var elections_resolved := 0
	var guard := 0
	while advanced < MONTHS and guard < MONTHS + 20:
		guard += 1
		var st: Dictionary = game.get("state")
		if int(st.get("months_to_election", 1)) <= 0:
			game.call("_run_election")
			await _frames(2)
			_check(str(game.get("screen")) == "result", "eleição do jogador deve abrir resultado")
			game.call("_show_promises")
			game.call("_auto_pick_promises")
			await _frames(2)
			elections_resolved += 1
			_check(str(game.get("screen")) == "game", "novo mandato deve voltar ao jogo")
			continue
		game.set("_month_in_progress", false)
		game.call("_advance_month")
		advanced += 1
		# Nenhuma escolha do jogador: eventos ficam pendentes; o mundo não lê
		# `event` para evoluir. Só a eleição obrigatória é resolvida.
		if advanced % 24 == 0:
			print("[world-20y] %d/%d meses · %d/%d" % [advanced, MONTHS, int(st.get("date_year", 0)), int(st.get("date_month", 0))])
	var elapsed_ms := (Time.get_ticks_usec() - started_usec) / 1000
	_check(advanced == MONTHS, "harness deve avançar 240 meses")
	_check(elections_resolved >= 4, "deve haver pelo menos quatro eleições do jogador no período")
	var final := _snapshot(game)
	print("[world-20y] 240 avanços em %d ms · %d eleições do jogador" % [elapsed_ms, elections_resolved])
	_report(initial, final)
	_check_save(initial, final)
	_finish()

func _snapshot(node: Node) -> Dictionary:
	var st: Dictionary = node.get("state")
	var world: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	var snap := {
		"date": {"year": int(st.get("date_year", 0)), "month": int(st.get("date_month", 1))},
		"countries": {}, "profiles": {}, "relations": {},
		"stats": (world.get("stats", {}) if world.get("stats") is Dictionary else {}).duplicate(true),
	}
	var countries: Dictionary = world.get("countries", {}) if world.get("countries") is Dictionary else {}
	for id in countries.keys():
		var wc: Dictionary = countries[id]
		var parties := {}
		for key in (wc.get("parties", {}) as Dictionary).keys():
			var party: Dictionary = wc.parties[key]
			parties[str(key)] = {"seats": int(party.get("seats", 0)), "support": float(party.get("support", 0.0))}
		snap.countries[str(id)] = {
			"government_party": str(wc.get("government_party", "")),
			"coalition_partners": (wc.get("coalition_partners", []) as Array).duplicate(),
			"coalition_seats": int(wc.get("coalition_seats", 0)),
			"turn": int(wc.get("turn", 0)),
			"parties": parties,
		}
	var profiles: Dictionary = st.get("international_state", {}).get("profiles", {}) if st.get("international_state") is Dictionary else {}
	for id in profiles.keys():
		var profile: Dictionary = profiles[id]
		snap.profiles[str(id)] = {
			"gdp": float(profile.get("gdp", 0.0)), "growth": float(profile.get("growth", 0.0)),
			"inflation": float(profile.get("inflation", 0.0)), "unemployment": float(profile.get("unemployment", 0.0)),
			"debt": float(profile.get("debt", 0.0)), "government_party": str(profile.get("government_party", "")),
		}
	var relations: Dictionary = st.get("international_state", {}).get("relations", {}) if st.get("international_state") is Dictionary else {}
	var prefix := str(st.get("country_id", "BR")) + ":"
	for key in relations.keys():
		if not str(key).begins_with(prefix):
			continue
		var rel: Dictionary = relations[key]
		snap.relations[str(key)] = {
			"cooperation": float(rel.get("cooperation", 0.0)),
			"alignment": float(rel.get("political_alignment", 0.0)),
			"tension": float(rel.get("tension", 0.0)),
		}
	return snap

func _report(initial: Dictionary, final: Dictionary) -> void:
	var initial_countries: Dictionary = initial.countries
	var final_countries: Dictionary = final.countries
	_check(initial_countries.size() == final_countries.size(), "nenhum país pode sumir do mundo em 20 anos")
	var gov_changed := 0
	var party_changed := 0
	var coalition_changed := 0
	var gov_examples: Array = []
	var party_examples: Array = []
	for id in initial_countries.keys():
		if not final_countries.has(id):
			continue
		var a: Dictionary = initial_countries[id]
		var b: Dictionary = final_countries[id]
		if str(a.government_party) != str(b.government_party):
			gov_changed += 1
			if gov_examples.size() < 5:
				gov_examples.append("%s %s→%s" % [id, a.government_party, b.government_party])
		var seats_changed := false
		var support_changed := false
		for key in (a.parties as Dictionary).keys():
			if not (b.parties as Dictionary).has(key):
				seats_changed = true
				continue
			if int(a.parties[key].seats) != int(b.parties[key].seats):
				seats_changed = true
			if absf(float(a.parties[key].support) - float(b.parties[key].support)) > 1.0:
				support_changed = true
		if seats_changed or support_changed:
			party_changed += 1
			if party_examples.size() < 3:
				party_examples.append(str(id))
		if str(a.get("coalition_partners", [])) != str(b.get("coalition_partners", [])) or int(a.coalition_seats) != int(b.coalition_seats):
			coalition_changed += 1
	var econ_changed := 0
	var gdp_changed := 0
	var econ_examples: Array = []
	for id in (initial.profiles as Dictionary).keys():
		if not (final.profiles as Dictionary).has(id):
			continue
		var a: Dictionary = initial.profiles[id]
		var b: Dictionary = final.profiles[id]
		if absf(float(a.gdp) - float(b.gdp)) > 0.01:
			gdp_changed += 1
		var delta := absf(float(a.growth) - float(b.growth)) + absf(float(a.inflation) - float(b.inflation)) + absf(float(a.unemployment) - float(b.unemployment)) + absf(float(a.debt) - float(b.debt))
		if delta > 0.5:
			econ_changed += 1
			if econ_examples.size() < 5:
				econ_examples.append("%s cresc %.1f→%.1f, infl %.1f→%.1f" % [id, a.growth, b.growth, a.inflation, b.inflation])
	var min_turn := 999999
	var max_turn := 0
	for id in final_countries.keys():
		min_turn = mini(min_turn, int((final_countries[id] as Dictionary).get("turn", 0)))
		max_turn = maxi(max_turn, int((final_countries[id] as Dictionary).get("turn", 0)))
	var relation_changed := 0
	var relation_examples: Array = []
	for key in (initial.relations as Dictionary).keys():
		if not (final.relations as Dictionary).has(key):
			continue
		var a: Dictionary = initial.relations[key]
		var b: Dictionary = final.relations[key]
		var delta := absf(float(a.cooperation) - float(b.cooperation)) + absf(float(a.alignment) - float(b.alignment)) + absf(float(a.tension) - float(b.tension))
		if delta > 1.0:
			relation_changed += 1
			if relation_examples.size() < 5:
				relation_examples.append("%s coop %.0f→%.0f, alinh %.0f→%.0f" % [key, a.cooperation, b.cooperation, a.alignment, b.alignment])
	var stats: Dictionary = final.stats
	print("[world-20y] fim: %d/%d · ciclos mensais por país %d–%d" % [int(final.date.year), int(final.date.month), min_turn, max_turn])
	print("[world-20y] governos %d/%d · partidos %d · coalizões %d · economias %d/%d (PIB %d)" % [gov_changed, initial_countries.size(), party_changed, coalition_changed, econ_changed, (initial.profiles as Dictionary).size(), gdp_changed])
	print("[world-20y] relações %d/%d · eleições %d · trocas %d · votações %d (%d derrotas) · acordos %d" % [relation_changed, (initial.relations as Dictionary).size(), int(stats.get("elections", 0)), int(stats.get("government_changes", 0)), int(stats.get("votes", 0)), int(stats.get("defeats", 0)), int(stats.get("agreements", 0))])
	for line in gov_examples:
		print("[world-20y] governo: " + str(line))
	for line in econ_examples:
		print("[world-20y] economia: " + str(line))
	for line in relation_examples:
		print("[world-20y] relação: " + str(line))
	_check(min_turn >= MONTHS, "cada país deve ter ao menos 240 ciclos mensais de simulação")
	_check(max_turn >= MONTHS, "o mundo não pode parar de simular antes de 240 ciclos")
	_check(gov_changed > 0, "deve haver governo diferente do inicial após 20 anos")
	_check(party_changed > 0, "partidos devem ganhar/perder cadeiras ou apoio")
	_check(coalition_changed > 0, "coalizões devem mudar em 20 anos")
	_check(econ_changed >= 25, "economias devem divergir da fotografia inicial")
	_check(gdp_changed >= 30, "PIB deve evoluir em quase todos os países")
	_check(relation_changed > 0, "relações políticas com o jogador devem mudar")
	_check(int(stats.get("elections", 0)) >= 30, "deve haver eleições estrangeiras suficientes")
	_check(int(stats.get("government_changes", 0)) > 0, "eleições devem trocar governos")
	_check(int(stats.get("votes", 0)) > 0 and int(stats.get("defeats", 0)) > 0, "legislativos devem votar e rejeitar")
	_check(int(stats.get("agreements", 0)) > 0, "política externa deve produzir acordos")
	var elapsed_months := (int(final.date.year) * 12 + int(final.date.month)) - (int(initial.date.year) * 12 + int(initial.date.month))
	_check(elapsed_months >= 228, "calendário do jogo deve avançar pelo menos 19 anos")
	var categories := {}
	for event in (game.get("state").get("world", {}).get("history", []) as Array):
		categories[str(event.get("category", ""))] = true
	for category in ["eleicao", "governo", "legislativo", "diplomacia", "politica"]:
		_check(categories.has(category), "história deve conter categoria " + category)

func _check_save(initial: Dictionary, final: Dictionary) -> void:
	game.call("_save_game")
	var raw := FileAccess.get_file_as_string("user://mandatia_save.json")
	var payload: Variant = JSON.parse_string(raw)
	_check(payload is Dictionary, "save de 20 anos deve ser JSON válido")
	if not (payload is Dictionary):
		return
	var saved_world: Dictionary = (payload as Dictionary).get("state", {}).get("world", {}) if ((payload as Dictionary).get("state", {}) as Dictionary).get("world", {}) is Dictionary else {}
	_check((saved_world.get("countries", {}) as Dictionary).size() == (final.countries as Dictionary).size(), "save deve preservar todos os países")
	_check(int(saved_world.get("stats", {}).get("elections", 0)) == int(final.stats.get("elections", 0)), "save deve preservar os contadores do mundo")
	var packed: PackedScene = load("res://scenes/main.tscn")
	var reloaded: Node = packed.instantiate()
	root.add_child(reloaded)
	await _frames(3)
	_disable_ai(reloaded)
	reloaded.call("_continue_game")
	await _frames(3)
	var st: Dictionary = reloaded.get("state")
	_check(bool(st.get("started", false)), "save de 20 anos deve carregar uma campanha")
	var rworld: Dictionary = st.get("world", {}) if st.get("world") is Dictionary else {}
	_check((rworld.get("countries", {}) as Dictionary).size() == (final.countries as Dictionary).size(), "mundo recarregado deve manter os países")
	_check(int(rworld.get("stats", {}).get("elections", 0)) == int(final.stats.get("elections", 0)), "mundo recarregado deve manter os contadores")
	var sample := "AR"
	if (final.countries as Dictionary).has(sample) and (rworld.get("countries", {}) as Dictionary).has(sample):
		_check(str(rworld.countries[sample].get("government_party", "")) == str(final.countries[sample].government_party), "governo de AR deve sobreviver ao save")
		var profile: Dictionary = st.get("international_state", {}).get("profiles", {}).get(sample, {})
		_check(absf(float(profile.get("growth", 0.0)) - float(final.profiles[sample].growth)) < 0.001, "economia de AR deve sobreviver ao save")
	reloaded.queue_free()

func _finish() -> void:
	if failures.is_empty():
		print("[world-20y] PASS: %d checks" % checks)
		quit(0)
	else:
		print("[world-20y] FAIL: %d falhas em %d checks" % [failures.size(), checks])
		for failure in failures:
			print("  - " + str(failure))
		quit(1)
