extends Node

const Election := preload("res://scripts/sim/election.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const Legislature := preload("res://scripts/sim/legislature.gd")
const Flags := preload("res://scripts/ui/flag_painter.gd")
const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const AIClient := preload("res://scripts/ai/ollama_client.gd")

var failures := PackedStringArray()
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "cena principal deve carregar")
	if packed == null:
		_finish()
		return
	var game: Node = packed.instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	_check(game.get("screen") == "menu", "jogo deve iniciar no menu")
	var initial_state: Dictionary = game.get("state")
	_check(initial_state.has("country_id"), "estado deve ter país")
	_check(initial_state.has("region_support") and initial_state.region_support.size() == 8, "estado deve preservar oito regiões simuladas")
	game.call("_show_new_game")
	await get_tree().process_frame
	_check(game.get("new_country") != null, "nova campanha deve expor seleção de país")
	_check(game.get("new_start_mode") != null, "nova campanha deve expor modo de início")
	_check(game.get("new_ideology").item_count == 11, "criação deve oferecer 11 ideologias")
	_check(game.get("new_ideology").get_item_text(0) == "Comunista" and game.get("new_ideology").get_item_text(5) == "Centro" and game.get("new_ideology").get_item_text(10) == "fascista", "ideologias devem manter ordem política")
	game.get("new_country").select(2)
	game.call("_on_country_selected", 2)
	game.get("new_party_name").text = "Frente do Brasil"
	game.get("new_party_abbr").text = "FB"
	game.get("new_leader").text = "Iara Luz"
	game.call("_start_campaign")
	await get_tree().process_frame
	var started_state: Dictionary = game.get("state")
	_check(bool(started_state.get("started", false)), "campanha deve iniciar")
	_check(started_state.get("country_id") == "BR", "campanha deve guardar Brasil")
	_check(int(started_state.get("lower_house_seats", -1)) == 0, "partido criado deve começar com zero cadeiras")
	_check(game.get("screen") == "promises", "campanha deve abrir a escolha de promessas")
	game.call("_auto_pick_promises")
	await get_tree().process_frame
	_check((game.get("state").get("promises", []) as Array).size() == 3, "programa deve registrar três promessas")
	_check(game.get("screen") == "game", "programa deve abrir o centro de comando")
	for month in 12:
		game.call("_advance_month")
	await get_tree().process_frame
	var after_year: Dictionary = game.get("state")
	_check(int(after_year.get("date_month", 0)) == 1, "avanço mensal deve virar o ano")
	_check((after_year.get("economy_history", []) as Array).size() == 13, "série econômica deve registrar um ponto por mês")
	_check(int(after_year.get("months_to_election", -1)) == 0, "doze meses devem abrir a primeira eleição")
	_check(FileAccess.file_exists("user://mandatia_save.json"), "campanha deve salvar automaticamente")
	game.call("_show_new_game")
	await get_tree().process_frame
	game.get("new_country").select(0)
	game.call("_on_country_selected", 0)
	game.get("new_start_mode").select(1)
	game.call("_on_start_mode_changed", 1)
	var justicialista_index: int = -1
	for i in range(game.get("new_official_party").item_count):
		if game.get("new_official_party").get_item_text(i).begins_with("Justicialista"):
			justicialista_index = i
			break
	_check(justicialista_index >= 0, "catálogo argentino deve conter bloco Justicialista")
	game.get("new_official_party").select(justicialista_index)
	game.call("_start_campaign")
	await get_tree().process_frame
	game.call("_auto_pick_promises")
	await get_tree().process_frame
	var argentina_state: Dictionary = game.get("state")
	_check(argentina_state.get("country_id") == "AR", "partido oficial deve iniciar na Argentina")
	_check(int(argentina_state.get("senate_seats", 0)) == 22, "Justicialista deve carregar 22 senadores oficiais")
	_check(Election.majority_of(513) == 257, "maioria deve ser metade+1 da câmara")
	_check(int(argentina_state.get("majority", 0)) == Election.majority_of(int(argentina_state.get("chamber_seats", 0))), "maioria deve seguir a câmara do país")
	var country_data: Dictionary = argentina_state.get("legislature", {})
	_check(Election.chamber_seats(country_data) == 257, "câmara baixa deve vir do catálogo")
	var d_hondt: Dictionary = Election.allocate_dhondt({"A": 50.0, "B": 30.0, "C": 20.0}, 10)
	var d_total := 0
	for value in d_hondt.values():
		d_total += int(value)
	_check(d_total == 10, "D'Hondt deve distribuir exatamente as cadeiras")
	_check(int(d_hondt.get("A", 0)) >= int(d_hondt.get("B", 0)) and int(d_hondt.get("B", 0)) >= int(d_hondt.get("C", 0)), "D'Hondt deve respeitar a ordem da votação")
	var shares: Dictionary = Election.poll_shares(argentina_state, country_data)
	var shares_total := 0.0
	for value in shares.values():
		shares_total += float(value)
	_check(absf(shares_total - 100.0) < 0.5, "pesquisa deve somar 100%")
	var election_state: Dictionary = game.get("state")
	election_state["months_to_election"] = 0
	game.call("_run_election")
	await get_tree().process_frame
	_check(game.get("screen") == "result", "eleição deve mostrar o resultado do mandato")
	var elected: Dictionary = game.get("state")
	_check(int((elected.get("last_result", {}) as Dictionary).get("promise_total", 0)) == 3, "resultado deve cobrar as três promessas")
	game.call("_show_game")
	await get_tree().process_frame
	var seat_map: Dictionary = elected.get("seat_map", {})
	var seat_total := 0
	for value in seat_map.values():
		seat_total += int(value)
	_check(seat_total == int(elected.get("chamber_seats", -1)), "eleição deve preencher a câmara inteira")
	_check(not (elected.get("last_election", {}) as Dictionary).is_empty(), "eleição deve registrar o pleito")
	game.call("_save_game")
	var save_file := FileAccess.open("user://mandatia_save.json", FileAccess.READ)
	_check(save_file != null, "save deve existir após gravar")
	if save_file != null:
		var payload: Variant = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		_check(payload is Dictionary and int((payload as Dictionary).get("save_version", 0)) == 5 and (payload as Dictionary).has("state"), "save deve ser versionado")
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("mandatia_save.json"):
		dir.remove("mandatia_save.json")
	# Sem remover o backup, o carregamento legado encontraria o .bak antes do save antigo.
	if dir != null and dir.file_exists("mandatia_save.bak"):
		dir.remove("mandatia_save.bak")
	var legacy_file := FileAccess.open("user://mandato_save.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"party": "Partido Legado", "date_year": 2028, "date_month": 3, "country_id": "BR", "region_support": [1, 2, 3, 4, 5, 6, 7, 8]}))
	legacy_file.close()
	game.call("_load_game")
	var migrated: Dictionary = game.get("state")
	_check(str(migrated.get("party", "")) == "Partido Legado", "save sem versão deve migrar")
	_check(int(migrated.get("save_version", 0)) == 5, "migração deve marcar a versão do save")
	_check((migrated.get("economy_history", null) is Array), "save migrado deve ter série econômica")
	var coalition: Dictionary = Coalition.minimum_winning({"PJ": 100, "A": 90, "B": 60}, {"PJ": -0.5, "A": -0.3, "B": 0.8}, "PJ", 130)
	_check(not coalition.is_empty(), "coalizão mínima deve existir")
	_check(int(coalition.get("seats", 0)) >= 130, "coalizão deve fechar maioria")
	_check((coalition.get("partners", []) as Array) == ["A"], "coalizão deve somar o partido mais próximo")
	var bill := Legislature.bill("investment")
	var vote := Legislature.vote(bill, {"PJ": 40, "ESQ": 10, "DIR": 50}, {"PJ": -0.3, "ESQ": -0.8, "DIR": 0.9}, ["ESQ"], 70.0)
	_check(int(vote.get("ayes", 0)) > 0 and int(vote.get("nayes", 0)) > 0, "votação deve somar bancadas dos dois lados")
	_check(bool(vote.get("approved", false)) == (int(vote.get("ayes", 0)) > int(vote.get("nayes", 0))), "resultado deve seguir a maioria dos votos")
	_check(int(vote.get("abstain", 0)) > 0 and int(vote.get("ayes", 0)) > 0, "bancadas devem se dividir entre sim, abstenção e não")
	_check(Legislature.BILLS.size() == 6, "catálogo deve ter seis proposições")
	var government_bills := 0
	for item in Legislature.BILLS:
		if bool(item.get("requires_government", false)):
			government_bills += 1
	_check(government_bills == 3, "três proposições devem ser exclusivas do governo")
	var flag_specs: Dictionary = Flags.FLAGS
	for country in game.get("countries"):
		_check(flag_specs.has(str(country.get("id", ""))), "bandeira desenhada para " + str(country.get("id", "")))
	var sections := ["Visão geral", "Meu partido", "Eleições", "Congresso", "Governo", "Economia", "População", "Regiões", "Internacional", "Notícias", "História", "Configurações"]
	for section in sections:
		game.call("_select_nav", section)
		await get_tree().process_frame
		var column: VBoxContainer = game.get("main_column")
		_check(is_instance_valid(column) and column.get_child_count() > 0, "tela deve montar conteúdo: " + section)
	game.call("_apply_responsive")
	_check(is_instance_valid(game.get("main_margin")), "layout responsivo deve manter a margem do conteúdo")
	game.call("_show_toast", "teste", "error")
	_check(is_instance_valid(game.get("toast")), "toast tipado deve ser criado")
	game.size = Vector2(1000, 700)
	game.call("_apply_responsive")
	_check(not bool((game.get("right_column") as CanvasItem).visible), "coluna lateral deve sumir em tela estreita")
	game.size = Vector2(1280, 720)
	game.call("_apply_responsive")
	_check(bool((game.get("right_column") as CanvasItem).visible), "coluna lateral deve voltar em tela larga")
	# ---------------------------------------------------------------- IA (Q22-Q37)
	_check(int(AIClient.MAX_ATTEMPTS) == 2, "contrato exige duas tentativas")
	_check(int(AIClient.TIMEOUT_MS) == 20000, "contrato exige timeout de 20 s")
	var seat_map_ai := {"PJ": 40, "ESQ": 60, "DIR": 100}
	_check(not bool(Contracts.validate_legislative("lixo", seat_map_ai).get("ok", true)), "JSON inválido deve ser rejeitado")
	_check(not bool(Contracts.validate_legislative({"votes": {"PJ": {"sim": 50, "abstencao": 20, "nao": 20}}}, seat_map_ai).get("ok", true)), "soma diferente de 100 deve ser rejeitada")
	_check(not bool(Contracts.validate_legislative({"votes": {"ZZZ": {"sim": 100, "abstencao": 0, "nao": 0}}}, seat_map_ai).get("ok", true)), "partido inexistente deve ser rejeitado")
	var votes_ok := {"PJ": {"sim": 75.0, "abstencao": 15.0, "nao": 10.0}, "ESQ": {"sim": 10.0, "abstencao": 20.0, "nao": 70.0}, "DIR": {"sim": 0.0, "abstencao": 10.0, "nao": 90.0}}
	var validated := Contracts.validate_legislative({"votes": votes_ok}, seat_map_ai)
	_check(bool(validated.get("ok", false)), "votos válidos devem passar")
	var compact := Contracts.validate_legislative({"votes": {"PJ": [75, 15, 10], "ESQ": [10, 20, 70], "DIR": [0, 10, 90]}}, seat_map_ai)
	_check(bool(compact.get("ok", false)), "voto em lista [sim, abstencao, nao] deve ser aceito")
	_check(not bool(Contracts.validate_legislative({"votes": {"PJ": [75, 20, 10]}}, seat_map_ai).get("ok", true)), "lista que não soma 100 deve ser rejeitada")
	var typo := Contracts.validate_legislative({"votes": {"PJS": [75, 15, 10], "ESQ": [10, 20, 70], "DIR": [0, 10, 90]}}, seat_map_ai)
	_check(bool(typo.get("ok", false)) and (typo.get("votes", {}) as Dictionary).has("PJ"), "sigla com uma letra errada deve voltar ao ID real quando não for ambígua")
	var partial := Contracts.validate_legislative({"votes": {"PJ": [75, 15, 10]}}, seat_map_ai)
	_check(bool(partial.get("ok", false)) and (partial.get("missing", []) as Array).size() == 2, "bloco incompleto deve voltar com as bancadas que faltaram")
	var ai_outcome := Contracts.votes_to_outcome(validated.get("votes", {}), seat_map_ai)
	_check(int(ai_outcome.get("ayes", 0)) + int(ai_outcome.get("nayes", 0)) + int(ai_outcome.get("abstain", 0)) == 200, "conversão de votos deve preservar todas as cadeiras")
	_check(int(ai_outcome.get("ayes", 0)) == 36, "75% de 40 cadeiras deve virar 30 + 6")
	var fallback_votes := Contracts.fallback_legislative(Legislature.bill("investment"), seat_map_ai, {"PJ": -0.3, "ESQ": -0.8, "DIR": 0.9}, ["ESQ"], 70.0)
	var fallback_total_ok := true
	for party in (fallback_votes.get("votes", {}) as Dictionary).keys():
		var split: Dictionary = fallback_votes.votes[party]
		if absf(float(split.get("sim", 0.0)) + float(split.get("abstencao", 0.0)) + float(split.get("nao", 0.0)) - 100.0) > 0.01:
			fallback_total_ok = false
	_check(fallback_total_ok, "fallback legislativo deve somar 100 por bancada")
	var base_shares := {"A": 40.0, "B": 35.0, "C": 25.0}
	var extreme := {"parties": {"A": {"delta_pp": 50.0, "reason": "x"}, "B": {"delta_pp": -50.0, "reason": "y"}, "C": {"delta_pp": 0.0, "reason": "z"}}}
	var electoral := Contracts.normalize_electoral(extreme, base_shares)
	_check(bool(electoral.get("ok", false)), "eleitoral deve aceitar deltas e normalizar")
	var electoral_total := 0.0
	var inside_band := true
	for key in (electoral.get("shares", {}) as Dictionary).keys():
		electoral_total += float(electoral.shares[key])
		if absf(float(electoral.shares[key]) - float(base_shares[key])) > 3.001:
			inside_band = false
	_check(absf(electoral_total - 100.0) < 0.5, "pesquisa da IA deve somar 100")
	_check(inside_band, "cada partido deve ficar dentro de ±3 p.p. da pesquisa")
	var event_ok := Contracts.validate_event({"headline": "Teste", "effects": {"approval": 99, "popularity": -50, "funds": 5000, "debt": -9}})
	_check(bool(event_ok.get("ok", false)), "evento válido deve passar")
	_check(is_equal_approx(float(event_ok.effects.approval), 6.0), "aprovação deve ser limitada a ±6")
	_check(is_equal_approx(float(event_ok.effects.popularity), -4.0), "popularidade deve ser limitada a ±4")
	_check(is_equal_approx(float(event_ok.effects.funds), 800.0), "caixa deve ser limitado a ±800")
	_check(is_equal_approx(float(event_ok.effects.debt), -1.0), "dívida deve ser limitada a ±1 p.p.")
	_check(not bool(Contracts.validate_event({"headline": "Sem efeito", "effects": {"approval": 0}}).get("ok", true)), "evento sem efeito deve ser rejeitado")
	var international_ok := Contracts.validate_international({"reactions": {"PJ": {"support_change": 50, "cohesion_change": -50, "reason": "x"}}, "international": {"event": "Crise", "impact": "Pressão"}}, ["PJ", "ESQ"])
	_check(bool(international_ok.get("ok", false)), "internacional válido deve passar")
	_check(is_equal_approx(float(international_ok.reactions.PJ.support_change), 10.0), "reação deve ser limitada a ±10")
	_check(not bool(Contracts.validate_international({"reactions": {"ZZZ": {"support_change": 1, "cohesion_change": 1}}, "international": {"event": "x", "impact": "y"}}, ["PJ"]).get("ok", true)), "reação de partido inexistente deve ser rejeitada")
	var truncated := Contracts.validate_international({"reactions": {"L": {"support_change": 2, "cohesion_change": 1, "reason": "x"}}, "international": {"event": "x", "impact": "y"}}, ["LLA", "PRO"])
	_check(bool(truncated.get("ok", false)) and (truncated.get("reactions", {}) as Dictionary).has("LLA"), "sigla truncada deve voltar ao ID real quando for prefixo único")
	var key_a := Contracts.cache_key(Contracts.EVENTS, {"month": 1, "year": 2027, "country": "BR"}, ["a", "b"])
	var key_b := Contracts.cache_key(Contracts.EVENTS, {"month": 1, "year": 2027, "country": "BR"}, ["b", "a"])
	var key_c := Contracts.cache_key(Contracts.EVENTS, {"month": 2, "year": 2027, "country": "BR"}, ["a", "b"])
	_check(key_a == key_b, "chave de cache deve ignorar a ordem das entidades")
	_check(key_a != key_c, "chave de cache deve mudar com o mês")

	# Cliente sem servidor: fallback imediato, callback único, cancelamento e cache.
	var ai_client: Node = AIClient.new()
	add_child(ai_client)
	ai_client.game = game
	ai_client.ai_available = false
	var delivered: Array = []
	var fallback_op: String = ai_client.request(Contracts.EVENTS, {"pais": "Brasil"}, {"entities": ["x"]}, {"month": 1, "year": 2027, "country": "BR"}, func(payload: Dictionary) -> void: delivered.append(payload))
	_check(delivered.size() == 1, "sem Ollama o fallback deve responder uma vez")
	_check(str((delivered[0] as Dictionary).get("source", "")) == "fallback", "origem deve ser fallback")
	_check(not ai_client.is_pending(fallback_op), "operação concluída não deve ficar pendente")
	ai_client.call("_on_response", 0, 200, PackedStringArray(), JSON.stringify({"response": "{\"headline\": \"atrasada\", \"effects\": {\"approval\": 3}}"}).to_utf8_buffer(), fallback_op, 1)
	_check(delivered.size() == 1, "resposta atrasada após fallback deve ser ignorada")
	var cancelled: Array = []
	ai_client.ai_available = true
	var pending_op: String = ai_client.request(Contracts.EVENTS, {"pais": "Brasil"}, {"entities": ["y"]}, {"month": 4, "year": 2027, "country": "BR"}, func(payload: Dictionary) -> void: cancelled.append(payload))
	ai_client.cancel(pending_op)
	ai_client.cancel(pending_op)
	_check(cancelled.size() == 1, "cancelar duas vezes deve entregar um único fallback")
	var timeout_box: Array = []
	var timeout_op: String = ai_client.request(Contracts.EVENTS, {"pais": "Brasil"}, {"entities": ["prazo"]}, {"month": 9, "year": 2027, "country": "BR"}, func(payload: Dictionary) -> void: timeout_box.append(payload))
	var ops: Dictionary = ai_client.get("_ops")
	if ops.has(timeout_op):
		var timeout_entry: Dictionary = ops[timeout_op]
		timeout_entry["attempt"] = 2
		timeout_entry["deadline_ms"] = 1
		ops[timeout_op] = timeout_entry
	ai_client.call("_process", 0.016)
	_check(timeout_box.size() == 1 and str((timeout_box[0] as Dictionary).get("source", "")) == "fallback", "vigia deve cortar a decisão no prazo e entregar o fallback")
	_check(not ai_client.is_pending(timeout_op), "operação fora do prazo não deve ficar pendente")
	ai_client.ai_available = false
	_check(str((cancelled[0] as Dictionary).get("source", "")) == "cancelled", "cancelamento deve sinalizar a origem")
	ai_client.call("_write_cache", "cache_teste|v1", {"ok": true, "value": {"headline": "cache"}})
	game.call("_save_game")
	game.get("state")["ai_decisions"] = {}
	game.call("_load_game")
	var cache_after_load: Dictionary = game.get("state").get("ai_decisions", {})
	_check(cache_after_load.has("cache_teste|v1"), "cache de IA deve persistir no save/load")

	# Backup do save: dois salvamentos geram .bak e um arquivo corrompido cai nele.
	game.call("_save_game")
	game.call("_save_game")
	_check(FileAccess.file_exists("user://mandatia_save.bak"), "salvamentos devem manter um backup do save anterior")
	var corrupt := FileAccess.open("user://mandatia_save.json", FileAccess.WRITE)
	corrupt.store_string("{ isto nao e json")
	corrupt.close()
	var expected_party := str(game.get("state").get("party", ""))
	game.get("state")["party"] = "Partido Perdido"
	game.call("_load_game")
	_check(str(game.get("state").get("party", "")) == expected_party, "save corrompido deve recuperar do backup")

	# Segurança assíncrona no motor: mês idempotente, evento aplicado uma vez,
	# internacional só exibe o estado salvo.
	game.get("state")["date_month"] = 3
	var month_before := int(game.get("state")["date_month"])
	game.set("_month_in_progress", true)
	game.call("_advance_month")
	_check(int(game.get("state")["date_month"]) == month_before, "avanço de mês duplicado deve ser bloqueado")
	game.set("_month_in_progress", false)
	var stamp := "%d-%02d" % [int(game.get("state")["date_year"]), int(game.get("state")["date_month"])]
	game.get("state")["month_completed"] = stamp
	var approval_before := float(game.get("state")["approval"])
	game.call("_on_month_event", {"value": {"headline": "Evento repetido", "effects": {"approval": 5.0, "popularity": 0.0, "funds": 0.0, "debt": 0.0}}}, stamp)
	_check(is_equal_approx(float(game.get("state")["approval"]), approval_before), "evento não deve aplicar efeito duas vezes")
	game.get("state")["event"] = "Crise em curso"
	game.get("state")["event_effects_applied"] = true
	var approval_response := float(game.get("state")["approval"])
	var funds_response := float(game.get("state")["funds"])
	game.call("_resolve_event", "Investir agora")
	_check(is_equal_approx(float(game.get("state")["approval"]), approval_response) and is_equal_approx(float(game.get("state")["funds"]), funds_response), "resposta ao evento não deve reaplicar efeitos já contabilizados")
	_check(not bool(game.get("state")["event_effects_applied"]), "marca de efeito aplicado deve ser limpa ao resolver")
	game.get("state")["international"] = {"year": 2027, "month": 3, "event": "Cúpula regional", "impact": "Abertura de mercado", "reactions": {}, "source": "fallback"}
	var game_ai: Node = game.get("ai")
	var pending_before := int(game_ai.pending_count()) if game_ai != null else 0
	game.call("_show_international")
	var pending_after := int(game_ai.pending_count()) if game_ai != null else 0
	_check(pending_after == pending_before, "abrir Internacional não deve chamar a IA")
	game.get("state")["funds"] = 50000.0
	game.get("state")["seat_map"] = {"PJ": 100, "OPO": 150}
	game.get("state")["chamber_seats"] = 250
	game.get("state")["majority"] = 126
	game.get("state")["bills"] = []
	# Caminho sem IA: com Ollama no ar a votação ficaria pendente e o teste
	# deixaria de medir o fallback determinístico.
	game_ai.ai_available = false
	game.call("_propose_bill", "investment")
	var bills_after: Array = game.get("state").get("bills", [])
	_check(not bills_after.is_empty(), "proposição deve ser resolvida mesmo sem Ollama")
	if not bills_after.is_empty():
		var bill_row: Dictionary = bills_after[0]
		_check(int(bill_row.get("ayes", 0)) + int(bill_row.get("nayes", 0)) + int(bill_row.get("abstain", 0)) == 250, "votação por bancada deve somar todas as cadeiras")
	game.get("state")["bills"] = []
	game.call("_on_bill_votes", {"key": "voto_parcial", "value": {"votes": {"PJ": {"sim": 100.0, "abstencao": 0.0, "nao": 0.0}}}}, Legislature.bill("investment"), {"PJ": 100, "OPO": 150})
	var partial_row: Dictionary = game.get("state").get("bills", [{}])[0]
	_check(int(partial_row.get("ayes", 0)) + int(partial_row.get("nayes", 0)) + int(partial_row.get("abstain", 0)) == 250, "bancadas sem voto da IA devem ser completadas pelo motor")
	ai_client.queue_free()
	game.queue_free()
	_finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("[game-generic-tests] PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[game-generic-tests] " + failure)
		print("[game-generic-tests] FAIL: %d failures across %d checks" % [failures.size(), checks])
		get_tree().quit(1)
