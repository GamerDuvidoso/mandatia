extends Node

const Election := preload("res://scripts/sim/election.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const Legislature := preload("res://scripts/sim/legislature.gd")
const Flags := preload("res://scripts/ui/flag_painter.gd")
const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const Events := preload("res://scripts/sim/events.gd")
const AIClient := preload("res://scripts/ai/ollama_client.gd")
const Ideology := preload("res://scripts/sim/ideology_system.gd")
const SocialGroups := preload("res://scripts/sim/social_groups.gd")
const InterestGroups := preload("res://scripts/sim/interest_groups.gd")
const PoliticalRelations := preload("res://scripts/sim/political_relations.gd")
const Scandals := preload("res://scripts/sim/scandal_system.gd")
const CampaignSystem := preload("res://scripts/sim/campaign_system.gd")
const CausalLog := preload("res://scripts/sim/causal_log.gd")
const International := preload("res://scripts/sim/international_system.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const WorldHistory := preload("res://scripts/sim/world_history.gd")
const ForeignElection := preload("res://scripts/sim/foreign_election_system.gd")
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const Projects := preload("res://scripts/sim/public_project_system.gd")
const Ministries := preload("res://scripts/sim/ministry_system.gd")

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
	# O onboarding é exercitado no fim; durante o fluxo ele não deve roubar foco.
	game.get("state")["tutorial_done"] = true
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
		_check(payload is Dictionary and int((payload as Dictionary).get("save_version", 0)) == 6 and (payload as Dictionary).has("state"), "save deve ser versionado")
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
	_check(int(migrated.get("save_version", 0)) == 6, "migração deve marcar a versão do save")
	_check((migrated.get("social_groups", {}) as Dictionary).size() == 12, "save migrado deve receber os grupos sociais")
	_check((migrated.get("party_relations", {}) as Dictionary).size() > 0, "save migrado deve receber a matriz de relações")
	_check((migrated.get("economy_history", null) is Array), "save migrado deve ter série econômica")
	_check(not (migrated.get("economic_profile", {}) as Dictionary).is_empty(), "save legado deve receber o perfil econômico para exibição")
	var coalition: Dictionary = Coalition.minimum_winning({"PJ": 100, "A": 90, "B": 60}, {"PJ": -0.5, "A": -0.3, "B": 0.8}, "PJ", 130)
	_check(not coalition.is_empty(), "coalizão mínima deve existir")
	_check(int(coalition.get("seats", 0)) >= 130, "coalizão deve fechar maioria")
	_check((coalition.get("partners", []) as Array) == ["A"], "coalizão deve somar o partido mais próximo")
	var bill := Legislature.bill("investment")
	var vote := Legislature.vote(bill, {"PJ": 40, "ESQ": 10, "DIR": 50}, {"PJ": -0.3, "ESQ": -0.8, "DIR": 0.9}, ["ESQ"], 70.0)
	_check(int(vote.get("ayes", 0)) > 0 and int(vote.get("nayes", 0)) > 0, "votação deve somar bancadas dos dois lados")
	_check(bool(vote.get("approved", false)) == (int(vote.get("ayes", 0)) > int(vote.get("nayes", 0))), "resultado deve seguir a maioria dos votos")
	_check(int(vote.get("abstain", 0)) > 0 and int(vote.get("ayes", 0)) > 0, "bancadas devem se dividir entre sim, abstenção e não")
	_check(Legislature.BILLS.size() == 13, "catálogo deve ter treze proposições")
	var government_bills := 0
	for item in Legislature.BILLS:
		if bool(item.get("requires_government", false)):
			government_bills += 1
	_check(government_bills == 8, "oito proposições devem ser exclusivas do governo")
	var flag_specs: Dictionary = Flags.FLAGS
	for country in game.get("countries"):
		_check(flag_specs.has(str(country.get("id", ""))), "bandeira desenhada para " + str(country.get("id", "")))
	var sections := ["Visão geral", "Meu partido", "Eleições", "Congresso", "Governo", "Crises", "Economia", "População", "Sociedade", "Regiões", "Internacional", "Mundo", "Notícias", "História", "Configurações"]
	for section in sections:
		game.call("_select_nav", section)
		await get_tree().process_frame
		var column: VBoxContainer = game.get("main_column")
		_check(is_instance_valid(column) and column.get_child_count() > 0, "tela deve montar conteúdo: " + section)
	# O rail é opcional por tela: a verificação de largura usa uma tela que o exibe.
	game.call("_select_nav", "Visão geral")
	await get_tree().process_frame
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
	var intl_state: Dictionary = game.get("state").get("international_state", {})
	_check(intl_state.get("profiles", {}).size() >= 10, "Fase D deve criar perfis internacionais dos países catalogados")
	_check(intl_state.get("relations", {}).size() >= 10, "Fase D deve criar relações bilaterais")
	var first_id := str((intl_state.get("profiles", {}) as Dictionary).keys()[0])
	var relation_before: Dictionary = International.profile(game.get("state"), first_id).get("relation", {})
	var meeting: Dictionary = International.diplomatic_action(game.get("state"), first_id, "meeting")
	_check(bool(meeting.get("ok", false)), "reunião diplomática deve ter condição e efeito")
	var relation_after: Dictionary = International.profile(game.get("state"), first_id).get("relation", {})
	_check(float(relation_after.get("cooperation", 0.0)) > float(relation_before.get("cooperation", 0.0)), "reunião deve elevar cooperação")
	var treaty: Dictionary = International.trade_agreement(game.get("state"), first_id)
	_check(bool(treaty.get("ok", false)), "acordo comercial deve registrar tratado")
	_check((game.get("state").get("international_state", {}).get("treaties", []) as Array).size() >= 1, "tratado deve persistir no estado")
	var investment: Dictionary = International.investment(game.get("state"), first_id)
	_check(bool(investment.get("ok", false)), "investimento estrangeiro deve ser registrável")
	_check(float(game.get("state").get("funds", 0.0)) > 0.0, "investimento privado não deve virar receita pública")
	# --- Fase D: ciclo diplomático determinístico (sem IA) ---
	var world: Array = game.get("countries")
	var world_economy: Dictionary = game.get("economy_catalog")
	var cycle: Dictionary = {
		"country_id": "BR", "date_year": 2027, "date_month": 3, "funds": 60000.0,
		"news": [], "credibility": 30.0, "approval": 45.0, "government": true,
		"gdp": 2000.0, "economy": 2.0, "inflation": 4.5, "unemployment": 7.0,
		"debt": 60.0, "lower_house_seats": 200, "coalition_seats": 50, "majority": 126,
		"treasury": 1000.0, "debt_book": [], "debt_history": []
	}
	International.init_state(cycle, world, world_economy)
	var cycle_intl: Dictionary = cycle.international_state
	_check((cycle_intl.get("profiles", {}) as Dictionary).size() >= 10, "ciclo D deve partir do catálogo de países")
	var partner := str((cycle_intl.profiles as Dictionary).keys()[0])
	var run_a: Dictionary = cycle.duplicate(true)
	var run_b: Dictionary = cycle.duplicate(true)
	run_a.date_month = 4
	run_b.date_month = 4
	International.monthly(run_a, world, world_economy)
	International.monthly(run_b, world, world_economy)
	_check(JSON.stringify(run_a.international_state) == JSON.stringify(run_b.international_state), "mês internacional deve ser determinístico")
	# Sem ação do jogador, o mundo propõe: a oferta nasce da relação, não da UI.
	var world_offers := 0
	for month in 12:
		var probe: Dictionary = cycle.duplicate(true)
		probe.date_month = month
		International.monthly(probe, world, world_economy)
		for offer in ((probe.international_state as Dictionary).get("offers", []) as Array):
			if str(offer.get("status", "")) == "pending":
				world_offers += 1
		if world_offers > 0:
			break
	_check(world_offers > 0, "mundo deve gerar ofertas sem ação do jogador")
	# Instabilidade do parceiro + dependência comercial abre crise sem evento manual.
	var unstable: Dictionary = cycle.duplicate(true)
	var unstable_intl: Dictionary = unstable.international_state
	var unstable_id := str((unstable_intl.profiles as Dictionary).keys()[0])
	unstable_intl.profiles[unstable_id]["stability"] = 20.0
	unstable_intl.trade["BR:" + unstable_id]["dependency"] = 40.0
	unstable.date_month = 5
	International.monthly(unstable, world, world_economy)
	var generated_crisis := false
	for crisis in (unstable_intl.get("crises", []) as Array):
		if str(crisis.get("country", "")) == unstable_id:
			generated_crisis = true
	_check(generated_crisis, "instabilidade do parceiro deve abrir crise sem gatilho manual")
	var cycle_funds := float(cycle.funds)
	var bogus_action: Dictionary = International.diplomatic_action(cycle, partner, "inventada")
	_check(not bool(bogus_action.get("ok", true)) and is_equal_approx(float(cycle.funds), cycle_funds), "ação desconhecida não pode gastar caixa")
	var economy_refresh := float(cycle.economy)
	International.refresh(cycle)
	_check(is_equal_approx(float(cycle.economy), economy_refresh), "refresh não deve simular outro mês")
	# Oferta: demanda aceita reduz tensão; recusada eleva tensão.
	var tension_before := float(International.profile(cycle, partner).relation.tension)
	cycle_intl.offers.push_front({"country": partner, "kind": "demanda", "label": "Demanda diplomática", "status": "pending", "expires_in": 3, "cost": 0.0})
	var accepted_demand: Dictionary = International.respond_offer(cycle, 0, true)
	_check(bool(accepted_demand.get("ok", false)) and float(cycle_intl.relations["BR:" + partner].tension) < tension_before, "aceitar demanda deve reduzir tensão")
	var tension_refuse := float(cycle_intl.relations["BR:" + partner].tension)
	cycle_intl.offers.push_front({"country": partner, "kind": "demanda", "label": "Demanda diplomática", "status": "pending", "expires_in": 3, "cost": 0.0})
	var refused_demand: Dictionary = International.respond_offer(cycle, 0, false)
	_check(bool(refused_demand.get("ok", false)) and float(cycle_intl.relations["BR:" + partner].tension) > tension_refuse, "recusar demanda deve elevar tensão")
	# Oferta comercial aceita abre tratado que ainda depende do parlamento.
	var treaties_before_offer := int((cycle_intl.treaties as Array).size())
	cycle_intl.offers.push_front({"country": partner, "kind": "acordo_comercial", "label": "Proposta de acordo comercial", "status": "pending", "expires_in": 4, "cost": 90.0})
	var accepted_trade: Dictionary = International.respond_offer(cycle, 0, true)
	_check(bool(accepted_trade.get("ok", false)) and int((cycle_intl.treaties as Array).size()) == treaties_before_offer + 1, "aceitar oferta comercial deve abrir tratado")
	_check(str((cycle_intl.treaties as Array)[0].get("status", "")) == "pending_ratification", "oferta aceita deve aguardar ratificação")
	cycle_intl.offers.push_front({"country": partner, "kind": "demanda", "label": "Demanda diplomática", "status": "pending", "expires_in": 0, "cost": 0.0})
	var expired_offer: Dictionary = International.respond_offer(cycle, 0, true)
	_check(not bool(expired_offer.get("ok", true)) and str((cycle_intl.offers as Array)[0].get("status", "")) == "expirada", "oferta vencida não pode ser aceita")
	# Tratado ativo expira; tratado sem ratificação caduca.
	cycle_intl.treaties.push_front({"country": partner, "kind": "comércio", "status": "active", "duration": 36, "expires_in": 1, "months_active": 0, "months_pending": 0, "cost": 180.0})
	International.monthly(cycle, world, world_economy)
	_check(str((cycle_intl.treaties as Array)[0].get("status", "")) == "expirado", "tratado vencido deve expirar")
	cycle_intl.treaties.push_front({"country": partner, "kind": "segurança", "status": "pending_ratification", "duration": 24, "expires_in": 24, "months_active": 0, "months_pending": 5, "cost": 220.0})
	International.monthly(cycle, world, world_economy)
	_check(str((cycle_intl.treaties as Array)[0].get("status", "")) == "caducado", "tratado sem ratificação deve caducar")
	# Sanção: sem duplicata, com prazo e expiração.
	cycle_intl.relations["BR:" + partner].tension = 60.0
	var sanction_one: Dictionary = International.sanction(cycle, partner)
	var sanction_two: Dictionary = International.sanction(cycle, partner)
	_check(bool(sanction_one.get("ok", false)) and not bool(sanction_two.get("ok", true)), "sanção duplicada deve ser recusada")
	var sanction_left := int((cycle_intl.sanctions as Array)[0].get("months_left", 0))
	International.monthly(cycle, world, world_economy)
	_check(int((cycle_intl.sanctions as Array)[0].get("months_left", -1)) == sanction_left - 1, "sanção deve contar o prazo")
	var sanction_row: Dictionary = (cycle_intl.sanctions as Array)[0]
	sanction_row["months_left"] = 1
	International.monthly(cycle, world, world_economy)
	_check(str((cycle_intl.sanctions as Array)[0].get("status", "")) == "expirado", "sanção deve expirar no fim do prazo")
	# Crise ignorada avança; resolvida, recompõe a relação.
	cycle_intl.crises.push_front({"country": partner, "headline": "Teste de crise", "stage": 1, "stages": 3, "idle": 1, "status": "open", "history": [], "month": 3, "year": 2027, "options": ["negociar", "diversificar", "isolar"]})
	International.monthly(cycle, world, world_economy)
	_check(int((cycle_intl.crises as Array)[0].get("stage", 0)) == 2, "inação deve agravar a crise")
	var tension_crisis := float(cycle_intl.relations["BR:" + partner].tension)
	var crisis_resolved: Dictionary = International.crisis_response(cycle, 0, "negociar")
	_check(bool(crisis_resolved.get("ok", false)), "crise deve aceitar resposta no estágio final")
	_check(str((cycle_intl.crises as Array)[0].get("status", "")) == "resolved" and float(cycle_intl.relations["BR:" + partner].tension) < tension_crisis, "resolver crise deve recompor a relação")
	_check(not bool(International.crisis_response(cycle, 0, "negociar").get("ok", true)), "crise resolvida não deve aceitar nova resposta")
	# Organizações: voto exige adesão derivada por regra.
	var omc_denied: Dictionary = International.organization_vote(cycle, "OMC", "teste", true)
	_check(not bool(omc_denied.get("ok", true)), "voto deve exigir adesão à organização")
	var omc_partner := ""
	for id in (cycle_intl.profiles as Dictionary).keys():
		if str(cycle_intl.profiles[id].get("region", "")) != "América do Sul":
			omc_partner = str(id)
			break
	if omc_partner == "":
		omc_partner = partner
	cycle_intl.treaties.push_front({"country": omc_partner, "kind": "comércio", "status": "active", "duration": 36, "expires_in": 36, "months_active": 0, "months_pending": 0, "cost": 0.0})
	International.monthly(cycle, world, world_economy)
	_check(bool((cycle_intl.organizations as Dictionary).get("OMC", {}).get("member", false)), "tratado ativo deve abrir adesão à OMC")
	var omc_allowed: Dictionary = International.organization_vote(cycle, "OMC", "teste", true)
	_check(bool(omc_allowed.get("ok", false)), "membro deve poder votar")
	# Blocos: condição verificada, não apenas registrada.
	var autonomy_denied: Dictionary = International.join_bloc(cycle, "coalizao_autonomia")
	_check(not bool(autonomy_denied.get("ok", true)), "bloco deve exigir a doutrina declarada")
	cycle_intl.policy = "nao_alinhamento"
	var autonomy_allowed: Dictionary = International.join_bloc(cycle, "coalizao_autonomia")
	_check(bool(autonomy_allowed.get("ok", false)), "doutrina compatível deve permitir adesão")
	_check(not bool(International.join_bloc(cycle, "coalizao_autonomia").get("ok", true)), "adesão não pode ser repetida")
	var south_denied: Dictionary = International.join_bloc(cycle, "integracao_sul")
	_check(not bool(south_denied.get("ok", true)), "integração sul deve exigir tratado com vizinho")
	var south_id := ""
	for id in (cycle_intl.profiles as Dictionary).keys():
		if str(cycle_intl.profiles[id].get("region", "")) == "América do Sul":
			south_id = str(id)
			break
	if south_id != "":
		cycle_intl.treaties.push_front({"country": south_id, "kind": "regional", "status": "active", "duration": 48, "expires_in": 48, "months_active": 0, "months_pending": 0, "cost": 0.0})
		_check(bool(International.join_bloc(cycle, "integracao_sul").get("ok", false)), "tratado regional com vizinho deve permitir adesão sul-americana")
	# Investimento e empréstimo exigem relação compatível.
	cycle_intl.relations["BR:" + partner].tension = 80.0
	_check(not bool(International.investment(cycle, partner).get("ok", true)), "tensão deve bloquear investimento")
	cycle_intl.relations["BR:" + partner].cooperation = 10.0
	_check(not bool(International.foreign_loan(cycle, partner, 1.0).get("ok", true)), "parceiro sem confiança não deve financiar")
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
	# Motor de eventos determinístico (sem IA).
	var ev_state := {"inflation": 8.0, "unemployment": 7.0, "debt": 60.0, "economy": 2.0, "months_to_election": 20, "event_recent": []}
	_check(Events.pick(ev_state, 0.5).options.size() == 3, "evento deve oferecer três respostas")
	var seen := {}
	for i in 40:
		var picked := Events.pick(ev_state, float(i) / 40.0)
		seen[picked.id] = true
		_check(Events.weight_for(picked, ev_state) > 0.0, "evento sorteado deve ser elegível: " + str(picked.id))
	_check(seen.size() >= 5, "sorteio deve variar entre eventos")
	_check(Events.weight_for({"when": {"debt_min": 85.0}}, ev_state) == 0.0, "dívida baixa não deve habilitar evento de rebaixamento")
	var recent_state := ev_state.duplicate(true)
	for entry in Events.CATALOG:
		recent_state["event_recent"] = [entry.id]
		_check(Events.pick(recent_state, 0.3).id != entry.id, "evento recente não deve repetir: " + str(entry.id))
	for entry in Events.CATALOG:
		_check((entry.options as Array).size() == 3, "todo evento deve ter três opções: " + str(entry.id))
	var apply_state := {"approval": 40.0, "funds": 5000.0, "inflation": 4.0, "economy": 2.0, "unemployment": 8.0, "debt": 60.0, "demographics": {"Trabalhadores": 10.0}}
	var strike_option: Dictionary = Events.CATALOG[0].options[0]
	Events.apply(apply_state, strike_option, true)
	_check(is_equal_approx(float(apply_state.funds), 4100.0) and float(apply_state.approval) > 40.0, "opção deve aplicar custo e efeito no governo")
	_check(float(apply_state.demographics.Trabalhadores) > 10.0, "opção deve mover grupos sociais")
	var opp_state := {"approval": 40.0, "funds": 5000.0, "inflation": 4.0, "economy": 2.0, "unemployment": 8.0, "debt": 60.0, "demographics": {}}
	Events.apply(opp_state, strike_option, false)
	_check(is_equal_approx(float(opp_state.inflation), 4.0), "oposição não deve mover a macroeconomia")
	game.get("state")["government"] = true
	game.get("state")["funds"] = 9000.0
	game.get("state")["event"] = ""
	game.call("_apply_month_event", {})
	var live_state: Dictionary = game.get("state")
	_check((live_state.event_options as Array).size() == 3 and str(live_state.event_id) != "", "evento sem IA deve registrar opções")
	var funds_before := float(live_state.funds)
	game.call("_resolve_event_option", 0)
	await get_tree().process_frame
	_check(str(game.get("state").event) == "" and (game.get("state").event_options as Array).is_empty(), "resposta deve encerrar o evento")
	_check(float(game.get("state").funds) <= funds_before, "resposta não deve gerar caixa a partir do nada")
	game.call("_push_news", "teste")
	game.call("_push_news", "teste")
	var teste_count := 0
	for line in game.get("state").news:
		if str(line) == "teste": teste_count += 1
	_check(teste_count == 1, "radar não deve repetir manchete consecutiva")
	# Receita mensal, programas e Agenda.
	var econ: Dictionary = game.get("state")
	econ["government"] = false
	econ["members"] = 1000
	econ["popularity"] = 10.0
	_check(float(game.call("_monthly_income")) > 300.0, "partido deve ter receita mensal")
	var funds_start := float(econ.funds)
	econ["government"] = true
	econ["policies"] = []
	econ["funds"] = 9000.0
	var income_no_programs := float(game.call("_monthly_income"))
	game.call("_policy_action", "jobs")
	_check((econ.policies as Array).has("jobs") and float(econ.funds) == 7000.0, "programa deve custar o valor declarado")
	game.call("_policy_action", "jobs")
	_check((econ.policies as Array).size() == 1 and float(econ.funds) == 7000.0, "programa não pode ser comprado duas vezes")
	_check(float(game.call("_monthly_income")) < income_no_programs, "programa ativo deve custar manutenção mensal")
	var unemployment_before := float(econ.unemployment)
	game.call("_apply_program_monthly")
	_check(float(econ.unemployment) < unemployment_before, "programa ativo deve render efeito mensal")
	econ["funds"] = 100.0
	econ["inflation"] = 9.0
	var agenda: Array = game.call("_agenda_items")
	_check(agenda.size() >= 3, "agenda deve listar prazos e problemas")
	var tones := ""
	for entry in agenda: tones += str(entry.tone) + ","
	_check(tones.contains("bad") and tones.contains("warn"), "agenda deve sinalizar inflação alta e caixa baixo")
	econ["policies"] = []
	econ["funds"] = funds_start
	# Revisão de mecânicas: voto retrospectivo, leis constitucionais, gabinete, coalizão.
	var gov_state := {"popularity": 20.0, "approval": 70.0, "inflation": 4.0, "unemployment": 8.0, "government": true}
	var opp_state2 := gov_state.duplicate(true)
	opp_state2["government"] = false
	_check(Election.player_share(gov_state) > Election.player_share(opp_state2), "aprovação alta deve ajudar o governo mais que a oposição")
	opp_state2["approval"] = 25.0
	gov_state["approval"] = 25.0
	_check(Election.player_share(opp_state2) > Election.player_share(gov_state), "governo impopular deve favorecer a oposição")
	var demo_low := {"popularity": 20.0, "demographics": {"Jovens": 5.0, "Trabalhadores": 5.0, "Empreendedores": 5.0, "Aposentados": 5.0, "Rurais": 5.0}}
	var demo_high := {"popularity": 20.0, "demographics": {"Jovens": 40.0, "Trabalhadores": 40.0, "Empreendedores": 40.0, "Aposentados": 40.0, "Rurais": 40.0}}
	_check(Election.player_share(demo_high) > Election.player_share(demo_low), "grupos sociais devem pesar no voto")
	var region_low := {"popularity": 20.0, "region_support": [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]}
	var region_high := {"popularity": 20.0, "region_support": [40.0, 40.0, 40.0, 40.0, 40.0, 40.0, 40.0, 40.0]}
	_check(Election.player_share(region_high) > Election.player_share(region_low), "apoio regional deve pesar no voto")
	var constitutional: Dictionary = Legislature.bill("pension")
	_check(not Legislature.passes(constitutional, {"ayes": 250, "nayes": 100}, 513), "projeto constitucional exige 3/5 das cadeiras")
	_check(Legislature.passes(constitutional, {"ayes": 320, "nayes": 100}, 513), "projeto constitucional passa com 3/5")
	_check(Legislature.passes(Legislature.bill("investment"), {"ayes": 120, "nayes": 100}, 513), "projeto ordinário passa por maioria simples dos votos")
	var rev: Dictionary = game.get("state")
	rev["government"] = true
	rev["funds"] = 9000.0
	rev["ministers"] = []
	game.call("_appoint_minister", "Saúde")
	game.call("_appoint_minister", "Saúde")
	_check((rev.ministers as Array).size() == 1 and float(rev.funds) == 8400.0, "ministério só pode ser nomeado uma vez")
	rev["bill_month"] = ""
	rev["coalition_partners"] = ["AAA", "BBB"]
	rev["coalition_cohesion"] = 30.3
	rev["coalition_seats"] = 300
	rev["majority"] = 257
	rev["seat_map"] = {"AAA": 30, "BBB": 40}
	game.call("_coalition_tick")
	_check((rev.coalition_partners as Array).size() == 1 and int(rev.coalition_seats) == 260, "coalizão desgastada deve perder um parceiro")
	var inflation_track := 12.0
	rev["inflation"] = inflation_track
	rev["economy"] = 2.4
	rev["debt"] = 60.0
	for i in 60:
		rev["inflation"] = clampf(float(rev.inflation) + (float(rev.economy) - 2.4) * 0.05 + (float(rev.debt) - 60.0) * 0.006 + (4.5 - float(rev.inflation)) * 0.04, 1.5, 15.0)
	_check(float(rev.inflation) < inflation_track - 3.0, "inflação deve convergir à âncora de expectativas")
	# ---------------------------------------------------------------- PERFIS ECONÔMICOS (Fase A)
	var economy_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/economy.json"))
	_check(economy_doc is Dictionary, "config/economy.json deve carregar")
	if economy_doc is Dictionary:
		var profiles: Dictionary = (economy_doc as Dictionary).get("countries", {})
		_check(profiles.size() == 35, "perfis econômicos devem cobrir os 35 países")
		var official_count := 0
		var estimated_ok := true
		var official_ok := true
		for cid in profiles.keys():
			var profile: Dictionary = profiles[cid]
			for key in ["gdp_growth", "inflation", "unemployment", "debt"]:
				var entry: Dictionary = profile.get(key, {})
				var sim := float(entry.get("simulation_value", 999.0))
				var value := float(entry.get("value", 999.0))
				var bounds: Array = ((economy_doc as Dictionary).get("indicators", {}).get(key, {}) as Dictionary).get("simulation_bounds", [0.0, 0.0])
				if sim < float(bounds[0]) or sim > float(bounds[1]) or (absf(sim - value) > 1e-9 and str(entry.get("calibration", "")) == ""):
					estimated_ok = false
				if str(entry.get("status", "")) == "official":
					official_count += 1
					if str(entry.get("source", "")) == "" or int(entry.get("year", 0)) < 2000:
						official_ok = false
				elif str(entry.get("methodology", "")) == "":
					estimated_ok = false
		_check(official_count >= 100, "maioria dos indicadores deve vir de fonte oficial (%d)" % official_count)
		_check(official_ok, "todo dado oficial deve ter fonte e ano de referência")
		_check(estimated_ok, "estimativas devem ter metodologia e respeitar os limites da simulação")
	game.call("_apply_country_economy", "BR", true)
	var br_economy := [float(game.get("state").economy), float(game.get("state").inflation), float(game.get("state").unemployment), float(game.get("state").debt)]
	game.call("_apply_country_economy", "US", true)
	var us_economy := [float(game.get("state").economy), float(game.get("state").inflation), float(game.get("state").unemployment), float(game.get("state").debt)]
	_check(br_economy != us_economy, "Brasil e Estados Unidos devem começar com economias diferentes")
	game.call("_apply_country_economy", "BR", true)
	_check(not (game.get("state").get("economic_profile", {}) as Dictionary).is_empty(), "campanha deve guardar o perfil econômico do país")
	var first_point: Dictionary = (game.get("state").get("economy_history", [{}]) as Array)[0]
	_check(absf(float(first_point.get("debt", 0.0)) - 81.86) < 0.01 and absf(float(first_point.get("economy", 0.0)) - 3.42) < 0.01, "primeiro ponto da série deve trazer crescimento e dívida iniciais: %s" % str(first_point))
	var objectives: Array = game.call("_mandate_objectives")
	_check(not objectives.is_empty(), "agenda deve ter objetivos contextuais do mandato")
	var factors: Array = game.call("_contributing_factors")
	_check(factors.size() >= 2 and str(factors[-1]).contains("correla"), "relatório deve listar fatores contribuintes sem alegar causalidade exata")
	var history_panel: PanelContainer = game.call("_economy_history_panel")
	_check(history_panel != null and history_panel.get_child_count() > 0, "painel de desempenho deve montar a série do mandato")
	var tutorial_steps: Array = game.get_script().get_script_constant_map().get("TUTORIAL_STEPS", [])
	_check(tutorial_steps.size() == 8, "onboarding deve cobrir os oito temas do mandato")
	game.get("state")["started"] = true
	game.call("_restart_tutorial")
	game.call("_maybe_show_tutorial")
	await get_tree().process_frame
	_check(is_instance_valid(game.get("tutorial_callout")), "guia deve abrir um cartão no primeiro acesso")
	game.call("_skip_tutorial")
	_check(bool(game.get("state").get("tutorial_done", false)), "pular o guia deve concluir o onboarding")
	# ---------------------------------------------------------------- FASE B
	var b_state: Dictionary = game.get("state").duplicate(true)
	b_state["funds"] = 20000.0
	b_state["credibility"] = 8.0
	b_state["coalition_cohesion"] = 20.0
	b_state["approval"] = 44.0
	b_state["date_year"] = 2028
	b_state["date_month"] = 5
	Ideology.player_position(b_state)
	var communist := Ideology.category_position("comunista")
	var liberal := Ideology.category_position("liberal")
	_check(communist.x < -50.0 and liberal.x > 40.0, "B1: eixo econômico deve separar comunista e liberal")
	_check(communist.y < 0.0 and Ideology.category_position("conservador").y > 40.0, "B1: eixo social deve separar progressista e conservador")
	_check(Ideology.compatibility(Vector2.ZERO, Vector2.ZERO) > 99.0, "B1: posições iguais devem ser compatíveis")
	var b_country: Dictionary = game.call("_country_by_id", str(b_state.get("country_id", "BR")))
	var b_positions := Ideology.positions(b_state, b_country)
	_check(b_positions.size() >= 2 and b_positions.has(str(b_state.abbr)), "B1: mapa deve incluir partidos e jogador")
	SocialGroups.init_state(b_state)
	_check(int((b_state.get("social_groups", {}) as Dictionary).size()) == 12, "B2: doze grupos sociais devem ser inicializados")
	_check(absf(SocialGroups.layer_share(b_state, "occupation") - 1.0) < 0.001, "B2: camada ocupacional deve somar 100%")
	_check(absf(SocialGroups.layer_share(b_state, "income") - 1.0) < 0.001, "B2: camada de renda deve somar 100%")
	var worker_before := float(SocialGroups.group(b_state, "industrial_workers").get("satisfaction", 0.0))
	var business_before := float(SocialGroups.group(b_state, "entrepreneurs").get("satisfaction", 0.0))
	SocialGroups.apply_policy(b_state, "minimum_wage")
	_check(float(SocialGroups.group(b_state, "industrial_workers").satisfaction) > worker_before, "B2: salário mínimo deve elevar trabalhadores")
	_check(float(SocialGroups.group(b_state, "entrepreneurs").satisfaction) < business_before, "B2: salário mínimo deve custar aos empresários")
	_check((b_state.get("demographics", {}) as Dictionary).size() == 5, "B2: legado deve manter cinco categorias para a eleição")
	InterestGroups.init_state(b_state)
	_check((b_state.get("interest_groups", {}) as Dictionary).size() == 7, "B3: sete organizações devem ser inicializadas")
	var labor_relation := InterestGroups.relation(b_state, "labor_federation")
	var negotiated := InterestGroups.negotiate(b_state, "labor_federation")
	_check(bool(negotiated.get("ok", false)) and InterestGroups.relation(b_state, "labor_federation") > labor_relation, "B3: negociar deve melhorar a relação")
	var labor_after := InterestGroups.relation(b_state, "labor_federation")
	InterestGroups.apply_policy(b_state, "labor")
	_check(InterestGroups.relation(b_state, "labor_federation") < labor_after, "B3: reforma trabalhista deve afastar o sindicato")
	PoliticalRelations.init_state(b_state, b_positions)
	_check((b_state.get("party_relations", {}) as Dictionary).size() > 0, "B4: matriz de relações deve iniciar")
	var first_key: String = (b_state.party_relations as Dictionary).keys()[0]
	var before_relation := float(b_state.party_relations[first_key])
	var parts := first_key.split("|")
	PoliticalRelations.shift(b_state, str(parts[0]), str(parts[1]), 10.0, "teste")
	_check(float(b_state.party_relations[first_key]) > before_relation, "B4: evento deve mover a relação")
	var sample_positions := {"PJ": Vector2(-40, -30), "A": Vector2(-30, -20), "B": Vector2(60, 50), "C": Vector2(10, 0)}
	var sample_seats := {"PJ": 100, "A": 70, "B": 60, "C": 20}
	var deal := PoliticalRelations.coalition_terms(b_state, sample_seats, sample_positions, "PJ", 130)
	_check(not deal.is_empty() and int(deal.get("seats", 0)) >= 130, "B4: coalizão deve fechar maioria")
	_check(not (deal.get("terms", []) as Array).is_empty(), "B4: coalizão deve ter termos e pastas")
	_check((b_state.get("factions", []) as Array).size() == 3, "B4: partido deve ter três facções")
	_check(PoliticalRelations.faction_penalty(b_state) >= 0.0, "B4: penalidade de facção deve ser finita")
	Scandals.ensure(b_state)
	b_state["government"] = true
	b_state["campaign_finance"] = {"risk": 100.0}
	var scandal_rng := RandomNumberGenerator.new()
	scandal_rng.seed = 424242
	var spawned_case := {}
	for _i in 30:
		spawned_case = Scandals.maybe_spawn(b_state, scandal_rng)
		if not spawned_case.is_empty():
			break
	_check(not spawned_case.is_empty(), "B5: risco alto deve gerar um caso")
	if not spawned_case.is_empty():
		var response := Scandals.respond(b_state, str(spawned_case.id), "cooperate")
		_check(bool(response.get("ok", false)), "B5: jogador deve poder cooperar com a apuração")
		for _i in 6:
			Scandals.advance(b_state, scandal_rng)
		_check(Scandals.legal_label(str(spawned_case.get("legal", ""))) != "", "B5: caso deve ter status jurídico explícito")
	_check(Scandals.legal_label("confirmed") == "MISCONDUTA CONFIRMADA", "B5: alegação e condenação devem ser distintas")
	CampaignSystem.init_state(b_state)
	b_state["funds"] = 20000.0
	b_state["campaign_actions"] = 0
	var region_before := float(b_state.region_support[0])
	var rally := CampaignSystem.perform(b_state, "rally", 0, [{"name": "Norte", "pop": 1.0, "problem": "teste"}], "")
	_check(bool(rally.get("ok", false)) and int(b_state.campaign_actions) == 1, "B6: ação de campanha deve consumir a economia de três ações")
	_check(float(b_state.region_support[0]) > region_before, "B6: comício deve elevar a região-alvo")
	var funds_before_raise := float(b_state.funds)
	var raised := CampaignSystem.raise_funds(b_state, "private")
	_check(bool(raised.get("ok", false)) and float(b_state.funds) > funds_before_raise, "B6: captação privada deve financiar a campanha")
	_check(float(b_state.campaign_finance.get("risk", 0.0)) > 0.0, "B6: dinheiro privado deve elevar o risco")

	# ------------------------------------------------- EFEITOS ENCADEADOS B7
	var strike_state: Dictionary = b_state.duplicate(true)
	strike_state["government"] = true
	strike_state["date_year"] = 2028
	strike_state["date_month"] = 9
	strike_state["economy"] = 2.4
	strike_state["funds"] = 20000.0
	strike_state["coalition_cohesion"] = 70.0
	InterestGroups.ensure(strike_state)
	strike_state.interest_groups.labor_federation.relationship = -60.0
	strike_state.interest_groups.labor_federation.grievance = 100.0
	strike_state.interest_groups.labor_federation.last_strike = -99
	strike_state.interest_groups.public_union.grievance = 0.0
	strike_state.social_groups.industrial_workers.satisfaction = 20.0
	strike_state.social_groups.industrial_workers.approval = 20.0
	var economy_before_strike := float(strike_state.economy)
	var strike_events: Array = InterestGroups.monthly(strike_state)
	_check(InterestGroups.active_strikes(strike_state).size() >= 1, "B7: queixa alta deve abrir greve persistente")
	_check(float(strike_state.economy) < economy_before_strike, "B7: greve deve reduzir a produção no mesmo mês")
	var strike_month := 0
	for event in strike_events:
		if str(event.get("type", "")) == "greve":
			strike_month = 1
	_check(strike_month == 1, "B7: greve deve gerar evento causal com efeitos numéricos")
	var strike_relation := InterestGroups.relation(strike_state, "labor_federation")
	var settled := InterestGroups.negotiate(strike_state, "labor_federation")
	_check(bool(settled.get("ok", false)) and InterestGroups.active_strikes(strike_state).is_empty(), "B7: negociar deve encerrar a greve")
	_check(InterestGroups.relation(strike_state, "labor_federation") > strike_relation, "B7: acordo deve melhorar a relação")
	_check(CausalLog.recent(strike_state, "greve").size() > 0, "B7: greve deve registrar a cadeia causal")
	var pressure_base: Dictionary = b_state.duplicate(true)
	pressure_base["government"] = false
	pressure_base["policy_log"] = []
	pressure_base["inflation"] = 4.0
	pressure_base["date_year"] = 2028
	pressure_base["date_month"] = 10
	InterestGroups.ensure(pressure_base)
	pressure_base.interest_groups.labor_federation.relationship = 0.0
	pressure_base.interest_groups.labor_federation.grievance = 10.0
	pressure_base.social_groups.industrial_workers.satisfaction = 55.0
	var pressure_with: Dictionary = pressure_base.duplicate(true)
	pressure_with["policy_log"] = [{"policy": "labor", "label": "Reforma trabalhista"}]
	InterestGroups.monthly(pressure_base)
	InterestGroups.monthly(pressure_with)
	_check(float(pressure_with.interest_groups.labor_federation.grievance) > float(pressure_base.interest_groups.labor_federation.grievance), "B7: política recente contrária deve elevar a queixa sindical")

	var coalition_state: Dictionary = b_state.duplicate(true)
	coalition_state["government"] = true
	coalition_state["coalition_cohesion"] = 70.0
	var coalition_deal := PoliticalRelations.coalition_terms(coalition_state, sample_seats, sample_positions, "PJ", 130)
	var coalition_terms: Array = coalition_deal.get("terms", []) if coalition_deal.get("terms") is Array else []
	coalition_state["coalition_partners"] = coalition_deal.get("partners", [])
	coalition_state["coalition_seats"] = int(coalition_deal.get("seats", 0))
	coalition_state["coalition_terms"] = coalition_terms
	coalition_state["coalition_assignments"] = {}
	coalition_state["coalition_compliance"] = {}
	coalition_state["coalition_started"] = int(coalition_state.date_year) * 12 + int(coalition_state.date_month)
	if not (coalition_terms as Array).is_empty():
		var first_term: Dictionary = coalition_terms[0]
		var compliant_bill := Legislature.bill(str(first_term.get("demand_policy", "investment")))
		var cohesion_before := float(coalition_state.coalition_cohesion)
		var compliant_result := PoliticalRelations.apply_bill_result(coalition_state, compliant_bill, true, "PJ")
		_check((compliant_result.get("events", []) as Array).size() > 0 and float(coalition_state.coalition_cohesion) > cohesion_before, "B7: proposta que cumpre a pauta deve estabilizar a coalizão")
		var violating := {"title": "Texto fora do acordo", "axis": 0.95 if float(first_term.get("demand_axis", 0.0)) < 0.0 else -0.95, "requires_government": true}
		var cohesion_pre_violation := float(coalition_state.coalition_cohesion)
		var violation_result := PoliticalRelations.apply_bill_result(coalition_state, violating, true, "PJ")
		_check(float(coalition_state.coalition_cohesion) < cohesion_pre_violation or not (violation_result.get("left", []) as Array).is_empty(), "B7: violar pauta deve reduzir coesão ou romper a coalizão")
		var allocation := PoliticalRelations.assign_ministry(coalition_state, "PJ")
		_check(str(allocation.get("party", "")) != "" and int((coalition_state.coalition_assignments as Dictionary).get(str(allocation.party), 0)) == 1, "B7: nomeação deve consumir uma cota de pasta da coalizão")
		first_term["ministries"] = 2
		coalition_state["date_month"] = int(coalition_state.get("date_month", 1)) + 3
		if int(coalition_state.date_month) > 12:
			coalition_state["date_month"] = int(coalition_state.date_month) - 12
			coalition_state["date_year"] = int(coalition_state.get("date_year", 2028)) + 1
		var pressure_before := float(coalition_state.coalition_cohesion)
		var pressure_events := PoliticalRelations.ministry_pressure(coalition_state, "PJ")
		_check((pressure_events as Array).size() > 0 and float(coalition_state.coalition_cohesion) < pressure_before, "B7: pasta prometida e não entregue deve gerar cobrança mensal")
		var term_for_vote: Dictionary = first_term
		var vote_bill := {"axis": 0.95 if float(term_for_vote.get("demand_axis", 0.0)) < 0.0 else -0.95, "requires_government": true}
		var vote_axes := {"PJ": 0.0, "A": float(term_for_vote.get("demand_axis", 0.0)), "B": 0.0}
		var vote_seats := {"PJ": 100, "A": 70, "B": 60}
		var raw_vote := Legislature.vote(vote_bill, vote_seats, vote_axes, ["A"], 70.0)
		var defected_vote := Legislature.adjust_votes(raw_vote, vote_seats, vote_axes, vote_bill, {}, "PJ", 0.0, 0.0, [term_for_vote])
		_check(int(defected_vote.get("ayes", 0)) <= int(raw_vote.get("ayes", 0)), "B7: aliado deve retirar apoio de texto contrário ao acordo")

	var scandal_state: Dictionary = b_state.duplicate(true)
	scandal_state["scandals"] = []
	scandal_state["scandal_history"] = []
	scandal_state["scandal_penalty"] = 0.0
	scandal_state["government"] = true
	scandal_state["credibility"] = 12.0
	scandal_state["coalition_cohesion"] = 70.0
	scandal_state["campaign_finance"] = {"risk": 100.0}
	Scandals.ensure(scandal_state)
	var media_rng := RandomNumberGenerator.new()
	media_rng.seed = 777
	var media_case := {}
	for _i in 40:
		media_case = Scandals.maybe_spawn(scandal_state, media_rng)
		if not media_case.is_empty():
			break
	_check(not media_case.is_empty(), "B7: risco alto deve abrir caso para testar cobertura")
	if not media_case.is_empty():
		_check(float(media_case.get("media", 0.0)) > 0.0 and str(media_case.get("procedure", "")) == "alegacao", "B7: caso deve nascer como alegação com cobertura")
		var media_before := float(media_case.get("media", 0.0))
		Scandals.respond(scandal_state, str(media_case.id), "cooperate")
		_check(float(media_case.get("media", 0.0)) < media_before, "B7: cooperação deve reduzir cobertura sem mudar o status jurídico")
		_check(str(media_case.get("legal", "")) == "unproven", "B7: resposta política não pode converter alegação em condenação")
		for _i in 4:
			Scandals.advance(scandal_state, media_rng)
		_check(str(media_case.get("procedure", "")) != "alegacao", "B7: caso deve atravessar procedimento institucional")
		_check(CausalLog.recent(scandal_state, "escandalo").size() > 0, "B7: escândalo deve registrar efeitos encadeados")
	_check(Scandals.penalty(scandal_state) >= 0.0, "B7: penalidade deve continuar finita")

	# Estresse: país com crescimento negativo e macro no limite superior.
	var stress: Dictionary = game.get("state")
	stress["economy"] = -4.18
	stress["inflation"] = 15.0
	stress["unemployment"] = 18.0
	stress["debt"] = 120.0
	stress["months_to_election"] = 12
	stress["event"] = ""
	stress["event_options"] = []
	stress["policies"] = []
	stress["government"] = false
	stress["funds"] = 5000.0
	game.set("_month_in_progress", false)
	for _i in 6:
		game.call("_advance_month")
		await get_tree().process_frame
		game.set("_month_in_progress", false)
	_check(is_finite(float(stress.economy)) and float(stress.economy) >= -2.0 and float(stress.economy) <= 6.0, "crescimento negativo deve convergir sem valores impossíveis")
	_check(is_finite(float(stress.inflation)) and float(stress.inflation) >= 1.5 and float(stress.inflation) <= 15.0, "inflação no teto deve permanecer na faixa")
	_check(is_finite(float(stress.debt)) and float(stress.debt) >= 20.0 and float(stress.debt) <= 120.0, "dívida no teto deve permanecer na faixa")

	game.queue_free()
	await get_tree().process_frame
	await _run_world_simulation()
	await _run_mandate()
	ai_client.queue_free()
	_finish()

## Integração: um mandato inteiro, da posse à execução e à eleição seguinte.
func _run_mandate() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var mandate: Node = packed.instantiate()
	get_tree().root.add_child(mandate)
	mandate.get("state")["tutorial_done"] = true
	await get_tree().process_frame
	mandate.call("_show_new_game")
	await get_tree().process_frame
	mandate.get("new_country").select(2)
	mandate.call("_on_country_selected", 2)
	mandate.get("new_party_name").text = "Frente de Teste"
	mandate.get("new_party_abbr").text = "FT"
	mandate.get("new_leader").text = "Teste"
	mandate.get("new_scenario").select(3)
	mandate.call("_start_campaign")
	await get_tree().process_frame
	mandate.call("_auto_pick_promises")
	await get_tree().process_frame
	var st: Dictionary = mandate.get("state")
	mandate.get("ai").ai_available = false
	_check(bool(st.government), "mandato deve começar com governo formado")
	_check(int(st.lower_house_seats) == int(st.majority), "incumbente deve começar com maioria")
	_check(int(st.months_to_election) == 48, "mandato deve ter 48 meses")
	var seat_total := 0
	for value in (st.seat_map as Dictionary).values():
		seat_total += int(value)
	_check(seat_total == int(st.chamber_seats), "plenário não pode ter mais cadeiras do que a câmara")
	_check(int(st.coalition_seats) == int(st.lower_house_seats), "base do governo deve contar a bancada uma única vez")
	# Gabinete: nomear pastas eleva a capacidade administrativa.
	var capacity_before := float(Ministries.summary(st).get("capacity", 0.0))
	mandate.call("_appoint_minister", "Saúde")
	mandate.call("_appoint_minister", "Educação")
	_check((st.ministers as Array).size() == 2, "governo deve poder nomear ministros")
	_check(float(Ministries.summary(st).get("capacity", 0.0)) >= capacity_before, "nomear ministros não deve reduzir a capacidade")
	# Projeto público: proposta, viabilidade e obra com dotação do orçamento.
	var catalog: Array = Projects.catalog()
	_check(not catalog.is_empty(), "catálogo de projetos deve existir")
	if not catalog.is_empty():
		var proposed: Dictionary = Projects.propose(st, str(catalog[0].get("id", "")), 0)
		_check(bool(proposed.get("ok", false)), "governo deve poder propor projeto")
		if bool(proposed.get("ok", false)):
			var project_id := str(proposed.get("id", ""))
			_check(bool(Projects.feasibility(st, project_id).get("ok", false)), "projeto deve concluir viabilidade")
			_check(bool(Projects.approve(st, project_id, "tesouro").get("ok", false)), "projeto viável deve entrar em obras")
	# Conflito parlamentar: a lei só passa com a aritmética do plenário.
	mandate.call("_propose_bill", "investment")
	var bills: Array = st.get("bills", [])
	_check(not bills.is_empty(), "governo deve conseguir propor lei")
	if not bills.is_empty():
		var bill_row: Dictionary = bills[0]
		_check(int(bill_row.ayes) + int(bill_row.nayes) + int(bill_row.abstain) == int(st.chamber_seats), "votação deve somar exatamente a câmara")
		_check(bool(bill_row.approved), "maioria deve aprovar a lei de investimento")
	# Restrição orçamentária: o plano padrão tem déficit e cai; austeridade aprova.
	mandate.call("_budget_review")
	mandate.call("_submit_budget")
	var rejected: Dictionary = st.get("budget", {}).get("last_vote", {})
	_check(not bool(rejected.get("approved", true)), "orçamento em déficit deve ser rejeitado")
	for entry in BudgetSystem.categories():
		for _i in 40:
			if not bool(BudgetSystem.adjust(st, str(entry.get("id", "")), -0.5).get("ok", false)):
				break
	mandate.call("_submit_budget")
	var approved: Dictionary = st.get("budget", {}).get("last_vote", {})
	_check(bool(approved.get("approved", false)), "orçamento ajustado deve ser aprovado")
	_check(int(approved.ayes) + int(approved.nayes) + int(approved.abstain) == int(st.chamber_seats), "votação orçamentária deve somar a câmara")
	# Execução do mandato: 48 meses com consequências sociais registradas.
	var approval_before := float(st.approval)
	var social_before := float(st.get("social_support", 50.0))
	var groups_before: Dictionary = (st.get("demographics", {}) as Dictionary).duplicate(true)
	var advanced := 0
	for _i in 48:
		mandate.call("_advance_month")
		advanced += 1
	_check(advanced == 48, "mandato deve avançar 48 meses")
	_check(int(st.months_to_election) == 0 and int(st.term_months_served) >= 48, "mandato deve terminar após 48 meses")
	_check(Projects.operational_count(st) > 0, "projeto aprovado deve entrar em operação dentro do mandato")
	_check(not is_equal_approx(float(st.approval), approval_before), "decisões do mandato devem mover a aprovação")
	_check(not is_equal_approx(float(st.get("social_support", 50.0)), social_before), "políticas devem mover o apoio social")
	var groups_changed := false
	for key in groups_before.keys():
		if not is_equal_approx(float((st.get("demographics", {}) as Dictionary).get(key, 0.0)), float(groups_before[key])):
			groups_changed = true
	_check(groups_changed, "grupos sociais devem reagir ao mandato")
	_check(FileAccess.file_exists("user://mandatia_save.json"), "mandato deve continuar salvando")
	# Fim do ciclo: a eleição seguinte abre um novo mandato.
	mandate.call("_run_election")
	await get_tree().process_frame
	_check(str(mandate.get("screen")) == "result", "fim do mandato deve abrir o resultado eleitoral")
	_check(not (st.get("last_result", {}) as Dictionary).is_empty(), "eleição deve registrar o resultado do mandato")
	_check(int(st.months_to_election) == 48, "novo ciclo deve abrir 48 meses")
	# Formação de governo minoritário: fechar a base destrava a governabilidade.
	var abbr := str(st.get("abbr", ""))
	var elected_map: Dictionary = st.get("seat_map", {})
	var others: Array = []
	for key in elected_map.keys():
		if str(key) != abbr and int(elected_map[key]) > 0:
			others.append(str(key))
	others.sort_custom(func(a, b): return int(elected_map[a]) > int(elected_map[b]))
	var formation_map := {abbr: 40}
	if others.size() >= 2:
		formation_map[others[0]] = 200
		formation_map[others[1]] = 273
	else:
		formation_map["Não atribuídas"] = 473
	st.seat_map = formation_map
	st.lower_house_seats = 40
	st.coalition_seats = 40
	st.coalition_partners = []
	st.chamber_seats = 513
	st.majority = 257
	st.government = true
	st.funds = 60000.0
	var deal: Dictionary = mandate.call("_formation_deal")
	_check(not deal.is_empty() and int(deal.get("seats", 0)) >= 257, "governo minoritário deve encontrar coalizão vencedora")
	mandate.call("_accept_coalition")
	_check(bool(st.government) and int(st.coalition_seats) >= 257, "fechar a base deve dar maioria ao governo")
	_check((st.coalition_partners as Array).size() > 0, "coalizão deve registrar parceiros")
	mandate.queue_free()
	await get_tree().process_frame

## E1.K — mundo autônomo: 12 meses, 5 anos e 20 anos no mesmo fluxo do jogo
## (International.monthly → WorldSim.monthly), com determinismo, limites,
## eleições, transições, notícias e desempenho.
func _run_world_simulation() -> void:
	var countries_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/countries.json"))
	var list: Array = (countries_parsed as Dictionary).get("countries", []) if countries_parsed is Dictionary else (countries_parsed if countries_parsed is Array else [])
	var econ_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/economy.json"))
	var econ: Dictionary = (econ_parsed as Dictionary).get("countries", {}) if econ_parsed is Dictionary else {}
	_check(not list.is_empty() and not econ.is_empty(), "E1: catálogos de países e economia devem carregar")
	var st := _world_sandbox()
	WorldSim.ensure(st, list, econ)
	var world: Dictionary = st.world
	var countries_map: Dictionary = world.get("countries", {})
	_check(countries_map.size() == list.size() - 2, "E1: todos os países exceto o jogador devem ser simulados (Haiti sem dados fica fora)")
	_check(not countries_map.has("HT"), "E1: Haiti sem partidos/câmara deve ficar fora da simulação política")
	var zero_party := 0
	var bad_support := 0
	var bad_seats := 0
	var parliamentary := 0
	for id in countries_map.keys():
		var wc: Dictionary = countries_map[id]
		var parties: Dictionary = wc.get("parties", {})
		if parties.is_empty():
			zero_party += 1
		var support := 0.0
		var seats := 0
		for key in parties.keys():
			support += float(parties[key].get("support", 0.0))
			seats += int(parties[key].get("seats", 0))
		if absf(support - 100.0) > 0.5:
			bad_support += 1
		if seats != int(wc.get("chamber_total", 0)):
			bad_seats += 1
		if str(wc.get("system", "")) == "parlamentar":
			parliamentary += 1
	_check(zero_party == 0, "E1: todo país simulado deve ter partidos")
	_check(bad_support == 0, "E1: apoio inicial dos partidos deve somar 100%%")
	_check(bad_seats == 0, "E1: cadeiras iniciais devem somar a câmara do catálogo")
	_check(parliamentary == 13, "E1: treze sistemas parlamentares simuláveis devem ser reconhecidos (Haiti sem dados fica fora)")
	# Transição de governo não pode resetar a economia: a eleição troca política,
	# não PIB, inflação, desemprego ou dívida.
	var transition_wc: Dictionary = countries_map["AR"]
	var transition_profile: Dictionary = st.international_state.profiles["AR"]
	var gdp_before := float(transition_profile.get("gdp", 0.0))
	var inflation_before := float(transition_profile.get("inflation", 0.0))
	var debt_before := float(transition_profile.get("debt", 0.0))
	ForeignElection.run(world, st, transition_wc, transition_profile, 2027, 1)
	_check(not (transition_wc.get("last_election", {}) as Dictionary).is_empty(), "E1: eleição deve registrar resultado")
	_check(is_equal_approx(float(transition_profile.get("gdp", 0.0)), gdp_before), "E1: eleição não pode resetar o PIB")
	_check(is_equal_approx(float(transition_profile.get("inflation", 0.0)), inflation_before), "E1: eleição não pode resetar a inflação")
	_check(is_equal_approx(float(transition_profile.get("debt", 0.0)), debt_before), "E1: eleição não pode resetar a dívida")
	var seat_sum := 0
	for value in (transition_wc.get("parties", {}) as Dictionary).values():
		seat_sum += int(value.get("seats", 0))
	_check(seat_sum == int(transition_wc.get("chamber_seats", -1)), "E1: eleição deve preencher exatamente a câmara")
	# Simulação longa, no mesmo fluxo do jogo.
	var start_usec := Time.get_ticks_usec()
	var snapshot_12 := {}
	var snapshot_60 := {}
	var snapshot_240 := {}
	for month_index in 240:
		st.date_month = int(st.date_month) + 1
		if int(st.date_month) > 12:
			st.date_month = 1
			st.date_year = int(st.date_year) + 1
		International.monthly(st, list, econ)
		WorldSim.monthly(st, list, econ)
		if month_index == 11:
			snapshot_12 = _world_averages(st)
		elif month_index == 59:
			snapshot_60 = _world_averages(st)
		elif month_index == 239:
			snapshot_240 = _world_averages(st)
	var elapsed_ms := (Time.get_ticks_usec() - start_usec) / 1000
	var sim_stats: Dictionary = st.world.get("stats", {})
	print("[world-sim] 240 meses em %d ms · %d países · %d fatos · %d eleições · %d trocas de governo · %d votações (%d derrotas) · %d acordos" % [elapsed_ms, (st.world.countries as Dictionary).size(), (st.world.history as Array).size(), int(sim_stats.get("elections", 0)), int(sim_stats.get("government_changes", 0)), int(sim_stats.get("votes", 0)), int(sim_stats.get("defeats", 0)), int(sim_stats.get("agreements", 0))])
	_check(elapsed_ms < 20000, "E1: 20 anos devem simular em menos de 20 s")
	for snapshot in [snapshot_12, snapshot_60, snapshot_240]:
		_check(not snapshot.is_empty(), "E1: marcos de 12, 60 e 240 meses devem ser medidos")
		_check(is_finite(float(snapshot.get("growth", INF))) and float(snapshot.get("growth", INF)) >= -8.0 and float(snapshot.get("growth", INF)) <= 10.0, "E1: crescimento deve ficar nos limites")
		_check(is_finite(float(snapshot.get("inflation", INF))) and float(snapshot.get("inflation", INF)) >= 0.5 and float(snapshot.get("inflation", INF)) <= 40.0, "E1: inflação deve ficar nos limites")
		_check(is_finite(float(snapshot.get("approval", INF))) and float(snapshot.get("approval", INF)) >= 3.0 and float(snapshot.get("approval", INF)) <= 92.0, "E1: aprovação deve ficar nos limites")
	var bounds_ok := true
	var unique_growth := {}
	var bad_party_sums := 0
	for id in (st.world.countries as Dictionary).keys():
		var wc: Dictionary = st.world.countries[id]
		var profile: Dictionary = st.international_state.profiles[id]
		var growth := float(profile.get("growth", 0.0))
		var inflation := float(profile.get("inflation", 0.0))
		var unemployment := float(profile.get("unemployment", 0.0))
		var debt := float(profile.get("debt", 0.0))
		var gdp := float(profile.get("gdp", 0.0))
		var approval := float(wc.get("approval", 0.0))
		var stability := float(wc.get("stability", 0.0))
		if not (is_finite(growth) and growth >= -8.0 and growth <= 10.0 and is_finite(inflation) and inflation >= 0.5 and inflation <= 40.0 and is_finite(unemployment) and unemployment >= 2.0 and unemployment <= 30.0 and is_finite(debt) and debt >= 0.0 and debt <= 200.0 and is_finite(gdp) and gdp > 0.0 and is_finite(approval) and approval >= 3.0 and approval <= 92.0 and is_finite(stability) and stability >= 5.0 and stability <= 98.0):
			bounds_ok = false
		unique_growth[snappedf(growth, 0.01)] = true
		var support := 0.0
		var seats := 0
		var parties: Dictionary = wc.get("parties", {})
		for key in parties.keys():
			support += float(parties[key].get("support", 0.0))
			seats += int(parties[key].get("seats", 0))
		if absf(support - 100.0) > 0.5 or seats != int(wc.get("chamber_seats", -1)):
			bad_party_sums += 1
		if int(wc.get("months_to_election", -1)) < 0 or int(wc.get("months_to_election", 999)) > int(wc.get("term_months", 999)):
			bounds_ok = false
	_check(bounds_ok, "E1: vinte anos não podem produzir valores impossíveis nem calendário inválido")
	_check(unique_growth.size() >= 10, "E1: países devem ter trajetórias econômicas distintas")
	_check(bad_party_sums == 0, "E1: apoio deve somar 100%% e cadeiras preencher a câmara depois de 20 anos")
	var stats: Dictionary = st.world.get("stats", {})
	_check(int(stats.get("elections", 0)) >= 30, "E1: vinte anos devem produzir eleições em todos os países")
	_check(int(stats.get("government_changes", 0)) > 0, "E1: o mundo deve trocar governos ao longo de vinte anos")
	_check(int(stats.get("defeats", 0)) > 0, "E1: legislativos devem rejeitar propostas do governo")
	_check(int(stats.get("votes", 0)) > 0 and int(stats.get("agreements", 0)) > 0, "E1: deve haver votações e acordos registrados")
	var history: Array = st.world.history
	var elections := 0
	var government_changes := 0
	var legislative := 0
	var diplomacy := 0
	var duplicates := 0
	var seen := {}
	for event in history:
		match str(event.get("category", "")):
			"eleicao": elections += 1
			"governo": government_changes += 1
			"legislativo": legislative += 1
			"diplomacia": diplomacy += 1
		var country := str(event.get("country", ""))
		var description := str(event.get("description", ""))
		var stamp := int(event.get("year", 0)) * 12 + int(event.get("month", 1))
		var key := country + "|" + description
		# A história é reverse-cronológica: guarda o registro mais novo e mede a
		# distância absoluta, não a subtração negativa.
		if seen.has(key):
			if absi(stamp - int(seen[key])) <= 2:
				duplicates += 1
		else:
			seen[key] = stamp
	_check(elections > 0, "E1: outros países devem realizar eleições")
	_check(government_changes > 0, "E1: eleições devem produzir trocas de governo")
	_check(legislative > 0, "E1: legislativos devem votar propostas")
	_check(diplomacy > 0, "E1: países devem firmar acordos autônomos")
	_check(duplicates == 0, "E1: o mesmo fato não pode se repetir em meses consecutivos")
	var news: Array = st.world.news
	var bad_news := 0
	var valid_status := ["confirmado", "oficial", "alegacao", "investigacao", "projecao"]
	for i in news.size():
		if str(news[i].get("headline", "")) == "" or not valid_status.has(str(news[i].get("status", ""))):
			bad_news += 1
		if i > 0 and str(news[i].get("headline", "")) == str(news[i - 1].get("headline", "")):
			bad_news += 1
	_check(not news.is_empty() and bad_news == 0, "E1: notícias devem existir, ter status e não repetir a manchete anterior")
	# Determinismo: duas simulações idênticas de 5 anos devem coincidir.
	var st_a := _world_sandbox()
	var st_b := _world_sandbox()
	WorldSim.ensure(st_a, list, econ)
	WorldSim.ensure(st_b, list, econ)
	for _i in 60:
		for st_run in [st_a, st_b]:
			st_run.date_month = int(st_run.date_month) + 1
			if int(st_run.date_month) > 12:
				st_run.date_month = 1
				st_run.date_year = int(st_run.date_year) + 1
			International.monthly(st_run, list, econ)
			WorldSim.monthly(st_run, list, econ)
	var deterministic := true
	for id in (st_a.world.countries as Dictionary).keys():
		var a: Dictionary = st_a.world.countries[id]
		var b: Dictionary = st_b.world.countries[id]
		if str(a.get("government_party", "")) != str(b.get("government_party", "")) or absf(float(a.get("approval", 0.0)) - float(b.get("approval", 0.0))) > 0.0001 or absf(float(st_a.international_state.profiles[id].get("growth", 0.0)) - float(st_b.international_state.profiles[id].get("growth", 0.0))) > 0.000001:
			deterministic = false
			break
	_check(deterministic, "E1: a simulação deve ser determinística por país e mês")
	# Compatibilidade: save antigo sem mundo recebe a fotografia atual; mundo
	# serializado sobrevive ao JSON e repõe país faltante.
	var legacy := _world_sandbox()
	legacy.erase("world")
	WorldSim.ensure(legacy, list, econ)
	_check((legacy.get("world", {}).get("countries", {}) as Dictionary).size() == list.size() - 2, "E1: save sem mundo deve receber os países simulados")
	var encoded := JSON.stringify({"save_version": 6, "state": st})
	var decoded: Variant = JSON.parse_string(encoded)
	_check(decoded is Dictionary and ((decoded as Dictionary).get("state", {}) as Dictionary).get("world", {}).get("countries", {}).size() == list.size() - 2, "E1: mundo deve sobreviver à serialização do save")
	st.world.countries.erase("AR")
	WorldSim.ensure(st, list, econ)
	_check((st.world.countries as Dictionary).has("AR"), "E1: ensure deve repor país ausente em save parcial")

func _world_sandbox() -> Dictionary:
	return {
		"country_id": "BR", "country_name": "Brasil", "ideology": "social-democrata",
		"date_year": 2027, "date_month": 1, "gdp": 100.0, "economy": 2.4,
		"inflation": 4.8, "unemployment": 8.2, "debt": 61.0, "approval": 42.0,
		"funds": 12400.0, "months_to_election": 48, "region_support": [4, 4, 4, 4, 4, 4, 4, 4],
		"international_state": {}, "world": {}, "news": [], "history": [],
	}

func _world_averages(st: Dictionary) -> Dictionary:
	var count := 0
	var growth := 0.0
	var inflation := 0.0
	var approval := 0.0
	for id in (st.world.countries as Dictionary).keys():
		count += 1
		growth += float(st.international_state.profiles[id].get("growth", 0.0))
		inflation += float(st.international_state.profiles[id].get("inflation", 0.0))
		approval += float(st.world.countries[id].get("approval", 0.0))
	return {"growth": growth / maxf(1.0, float(count)), "inflation": inflation / maxf(1.0, float(count)), "approval": approval / maxf(1.0, float(count))}

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
