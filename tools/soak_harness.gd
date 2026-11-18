extends SceneTree
## Harness de soak/autoplay headless: exercita campanhas em todos os países
## do catálogo por N ciclos eleitorais, com IA em fallback determinístico.
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/soak_harness.gd

const ELECTION_CYCLES := 2
const MAX_STEPS := 220

var failures := PackedStringArray()
var checks := 0
var countries_tested := 0
var runs := 0

func _initialize() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error("[soak] " + msg)

func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		_fail(msg)

func _is_finite_number(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		return not is_nan(v) and not is_inf(v)
	return false

func _assert_state(game: Node, label: String) -> void:
	var s: Dictionary = game.get("state")
	_check(s is Dictionary and not s.is_empty(), label + ": estado vazio")
	if s.is_empty():
		return
	for key in ["popularity", "approval", "recognition", "credibility", "cohesion", "funds", "debt", "gdp", "inflation", "unemployment", "economy"]:
		var v: Variant = s.get(key, NAN)
		_check(_is_finite_number(v), label + ": " + key + " não é número finito")
	_check(float(s.get("funds", -1.0)) >= -0.001, label + ": caixa negativa")
	_check(float(s.get("popularity", 0.0)) >= 0.0 and float(s.get("popularity", 0.0)) <= 100.0, label + ": popularidade fora de [0,100]")
	_check(float(s.get("approval", 0.0)) >= 0.0 and float(s.get("approval", 0.0)) <= 100.0, label + ": aprovação fora de [0,100]")
	_check(float(s.get("recognition", 0.0)) >= 0.0 and float(s.get("recognition", 0.0)) <= 100.0, label + ": reconhecimento fora de [0,100]")
	_check(float(s.get("credibility", 0.0)) >= 0.0 and float(s.get("credibility", 0.0)) <= 100.0, label + ": credibilidade fora de [0,100]")
	_check(float(s.get("cohesion", 0.0)) >= 0.0 and float(s.get("cohesion", 0.0)) <= 100.0, label + ": coesão fora de [0,100]")
	_check(int(s.get("date_month", 0)) >= 1 and int(s.get("date_month", 0)) <= 12, label + ": mês inválido")
	_check(int(s.get("date_year", 0)) >= 2000, label + ": ano inválido")
	_check(int(s.get("months_to_election", -1)) >= 0, label + ": meses para eleição negativos")
	_check(int(s.get("lower_house_seats", -1)) >= 0, label + ": cadeiras negativas")
	var chamber := int(s.get("chamber_seats", 0))
	_check(chamber >= 0, label + ": câmara negativa")
	var seat_map: Variant = s.get("seat_map", {})
	if seat_map is Dictionary and chamber > 0 and not (seat_map as Dictionary).is_empty():
		var total := 0
		for k in (seat_map as Dictionary).keys():
			var seats := int((seat_map as Dictionary)[k])
			_check(seats >= 0, label + ": bancada negativa " + str(k))
			total += seats
		_check(total == chamber, label + ": soma das bancadas %d != câmara %d" % [total, chamber])
	for i in (s.get("region_support", []) as Array).size():
		var rv: float = float(s.region_support[i])
		_check(not is_nan(rv) and not is_inf(rv) and rv >= 0.0 and rv <= 100.0, label + ": apoio regional inválido em %d" % i)

func _disable_ai(game: Node) -> void:
	var ai: Node = game.get("ai")
	if ai == null:
		return
	# Evita probe assíncrono sobrescrever o estado durante o soak.
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

func _resolve_pending_event(game: Node) -> void:
	var s: Dictionary = game.get("state")
	if str(s.get("event", "")) != "":
		game.call("_resolve_event", "Negociar")

func _play_cycle(game: Node, label: String) -> void:
	var steps := 0
	while int(game.get("state").get("months_to_election", 0)) > 0 and steps < MAX_STEPS:
		# Garante fallback mesmo se algo reativar a IA.
		_disable_ai(game)
		game.call("_advance_month")
		_resolve_pending_event(game)
		_assert_state(game, label + " step=" + str(steps))
		steps += 1
	_check(int(game.get("state").get("months_to_election", 1)) == 0, label + ": eleição não abriu no prazo")
	if int(game.get("state").get("months_to_election", 1)) != 0:
		return
	_disable_ai(game)
	game.call("_run_election")
	_assert_state(game, label + " pós-eleição")
	_check(str(game.get("screen")) == "result", label + ": tela de resultado esperada, obtida " + str(game.get("screen")))
	# Próximo ciclo: novo programa.
	game.call("_show_promises")
	game.call("_auto_pick_promises")
	_assert_state(game, label + " pós-promessas")
	_check(str(game.get("screen")) == "game", label + ": deveria voltar ao jogo após programa")

func _run_country(game: Node, country_index: int, country: Dictionary) -> void:
	var cid := str(country.get("id", "?"))
	var cname := str(country.get("name", cid))
	countries_tested += 1

	# --- Partido criado do zero ---
	runs += 1
	game.call("_show_new_game")
	await process_frame
	var nc = game.get("new_country")
	if nc == null:
		_fail("new_country ausente para " + cid)
		return
	nc.select(country_index)
	game.call("_on_country_selected", country_index)
	var nsm = game.get("new_start_mode")
	nsm.select(0)
	game.call("_on_start_mode_changed", 0)
	game.get("new_party_name").text = "Frente Teste"
	game.get("new_party_abbr").text = "FT"
	game.get("new_leader").text = "Líder Teste"
	var nideo = game.get("new_ideology")
	if nideo != null and nideo.item_count > 5:
		nideo.select(5)
	game.call("_start_campaign")
	_assert_state(game, cid + "/criado/início")
	_check(str(game.get("screen")) == "promises", cid + "/criado: deveria abrir promessas")
	game.call("_auto_pick_promises")
	_assert_state(game, cid + "/criado/promessas")
	for cycle in range(ELECTION_CYCLES):
		_play_cycle(game, "%s/criado/c%d" % [cid, cycle + 1])
	print("[soak] ok criado: %s (%s)" % [cid, cname])

	# --- Partido oficial (primeiro disponível) ---
	var officials: Array = country.get("official_parties", [])
	if officials.is_empty():
		return
	runs += 1
	game.call("_show_new_game")
	await process_frame
	nc = game.get("new_country")
	nc.select(country_index)
	game.call("_on_country_selected", country_index)
	nsm = game.get("new_start_mode")
	nsm.select(1)
	game.call("_on_start_mode_changed", 1)
	await process_frame
	var nop = game.get("new_official_party")
	if nop != null and nop.item_count > 0 and not nop.disabled:
		nop.select(0)
		game.call("_start_campaign")
		_assert_state(game, cid + "/oficial/início")
		var sc := str(game.get("screen"))
		if sc == "promises":
			game.call("_auto_pick_promises")
			_assert_state(game, cid + "/oficial/promessas")
			for cycle in range(ELECTION_CYCLES):
				_play_cycle(game, "%s/oficial/c%d" % [cid, cycle + 1])
			print("[soak] ok oficial: %s (%s)" % [cid, cname])
		else:
			# País com snapshot incompleto: início pode ser recusado com toast.
			print("[soak] skip oficial (screen=%s): %s" % [sc, cid])
	else:
		print("[soak] skip oficial (indisponível): %s" % cid)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("cena principal não carregou")
		_finish()
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	_disable_ai(game)

	var countries: Array = game.get("countries")
	_check(not countries.is_empty(), "catálogo de países vazio")
	for i in range(countries.size()):
		var country: Dictionary = countries[i]
		await _run_country(game, i, country)
		# Pequena pausa cooperativa para evitar acúmulo excessivo.
		if i % 5 == 4:
			await process_frame

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[soak] PASS: %d checks, %d países, %d campanhas" % [checks, countries_tested, runs])
		quit(0)
	else:
		print("[soak] FAIL: %d falhas em %d checks (%d países, %d campanhas)" % [failures.size(), checks, countries_tested, runs])
		for f in failures:
			print("  - " + f)
		quit(1)
