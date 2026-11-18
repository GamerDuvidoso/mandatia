extends SceneTree
## Walkthrough de interface: percorre o jogo pela UI real, da primeira tela até
## o fim de um mandato, com a IA desligada (fallback determinístico).
##
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/walkthrough.gd
##
## Sai com código 1 quando alguma checagem falha.

var game: Node = null
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("[walk] FALHA: " + message)

func _frames(count := 3) -> void:
	for i in count:
		await process_frame

var _backups: Dictionary = {}

func _save_paths() -> Array:
	return [
		"user://mandatia_save.json", "user://mandatia_save.bak", "user://mandato_save.json",
		"user://mandato_export.json",
		# Save da versão antiga do jogo (pasta anterior), também aceito pelo menu.
		OS.get_user_data_dir().get_base_dir().path_join("Mandato — Poder e Política").path_join("mandato_save.json"),
	]

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path

## Guarda o conteúdo dos saves existentes e limpa o disco, para o roteiro
## começar sem campanha e terminar com o estado do usuário intacto.
func _erase_saves() -> void:
	for path in _save_paths():
		if FileAccess.file_exists(str(path)):
			_backups[str(path)] = FileAccess.get_file_as_string(str(path))
			DirAccess.remove_absolute(_absolute(str(path)))

func _restore_saves() -> void:
	for path in _save_paths():
		if FileAccess.file_exists(str(path)):
			DirAccess.remove_absolute(_absolute(str(path)))
	for path in _backups.keys():
		var file := FileAccess.open(str(path), FileAccess.WRITE)
		if file != null:
			file.store_string(str(_backups[path]))
			file.close()

## --- helpers de UI -----------------------------------------------------------

func _collect_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)

func _buttons(include_disabled := false) -> Array:
	var out: Array = []
	_collect_buttons(root, out)
	if include_disabled:
		return out
	var visible: Array = []
	for item in out:
		var b: Button = item
		if b.is_visible_in_tree() and not b.disabled:
			visible.append(b)
	return visible

func _find_button(text: String, include_disabled := false) -> Button:
	var candidates := _buttons(include_disabled)
	for item in candidates:
		var b: Button = item
		if b.text.strip_edges() == text:
			return b
	for item in candidates:
		var b: Button = item
		if b.text.contains(text):
			return b
	return null

func _press(text: String, include_disabled := false) -> bool:
	var b := _find_button(text, include_disabled)
	if b == null:
		_check(false, "botão não encontrado: " + text)
		return false
	b.pressed.emit()
	await _frames()
	return true

func _nav(item: String) -> void:
	var b := _find_button(item)
	if b == null:
		_check(false, "navegação não encontrada: " + item)
		return
	b.pressed.emit()
	await _frames()

func _all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	if node is Button:
		out += (node as Button).text + "\n"
	for child in node.get_children():
		out += _all_text(child)
	return out

func _screen() -> String:
	return str(game.get("screen"))

func _state() -> Dictionary:
	return game.get("state")

func _main_text() -> String:
	var column = game.get("main_column")
	if column == null or not is_instance_valid(column):
		return ""
	return _all_text(column)

func _count_labels(node: Node) -> int:
	var count := 0
	if node is Label and (node as Label).text.strip_edges() != "":
		count += 1
	for child in node.get_children():
		count += _count_labels(child)
	return count

## --- roteiro -----------------------------------------------------------------

func _run() -> void:
	_erase_saves()
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	await _frames(4)
	# IA desligada: todo contrato cai no fallback síncrono do motor.
	var ai: Node = game.get("ai")
	if ai != null:
		ai.stop()
		ai.set("ai_available", false)
		ai.set("availability_checked", true)
		ai.set("_probe", null)
		ai.set("_warm", null)

	await _phase_menu()
	await _phase_new_game_countries()
	await _phase_campaign_zero("BR")
	await _phase_campaign_official("CA")
	_restore_saves()
	print("[walk] %s: %d checks, %d falhas" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _phase_menu() -> void:
	_check(_screen() == "menu", "primeira tela deve ser o menu")
	var menu_text := _all_text(root)
	_check(menu_text.contains("MANDATIA"), "menu deve exibir o título MANDATIA")
	_check(_find_button("FUNDAR NOVA CAMPANHA") != null, "menu deve ter nova campanha")
	var continue_button := _find_button("CONTINUAR CAMPANHA", true)
	_check(continue_button != null, "menu deve ter continuar campanha")
	_check(continue_button != null and continue_button.disabled, "continuar deve estar desabilitado sem save")
	await _press("FUNDAR NOVA CAMPANHA")
	_check(_screen() == "new_game", "nova campanha deve abrir a criação")

func _phase_new_game_countries() -> void:
	var countries: Array = game.get("countries")
	_check(countries.size() == 35, "catálogo deve ter 35 países (tem %d)" % countries.size())
	var with_official := 0
	var official_mode_country := -1
	for index in countries.size():
		var country: Dictionary = countries[index]
		game.get("new_country").select(index)
		game.call("_on_country_selected", index)
		await process_frame
		var party_option: OptionButton = game.get("new_official_party")
		var leader_label: Label = game.get("country_leader_label")
		_check(party_option.item_count > 0, "%s: lista de partidos oficiais vazia" % country.get("id", "?"))
		_check(leader_label.text.strip_edges() != "", "%s: resumo do governo vazio" % country.get("id", "?"))
		var parties: Array = country.get("official_parties", [])
		if parties.is_empty():
			_check(party_option.disabled, "%s: sem partidos, seletor oficial deve ficar desabilitado" % country.get("id", "?"))
		else:
			with_official += 1
			_check(not party_option.disabled, "%s: seletor oficial deveria estar ativo" % country.get("id", "?"))
			if official_mode_country < 0 and str(country.get("id", "")) == "CA":
				official_mode_country = index
	_check(with_official == 34, "34 países devem ter partidos oficiais (tem %d)" % with_official)

	# Modo oficial esconde os campos de partido novo; modo criado mostra.
	game.get("new_start_mode").select(1)
	game.call("_on_start_mode_changed", 1)
	await process_frame
	_check(not (game.get("new_party_name") as LineEdit).visible, "modo oficial deve esconder o nome do partido")
	_check((game.get("new_official_party") as OptionButton).visible, "modo oficial deve mostrar o partido oficial")
	game.get("new_start_mode").select(0)
	game.call("_on_start_mode_changed", 0)
	await process_frame
	_check((game.get("new_party_name") as LineEdit).visible, "modo criado deve mostrar o nome do partido")

	# HT não tem partidos: iniciar em modo oficial deve avisar e não avançar.
	for index in countries.size():
		if str(countries[index].get("id", "")) == "HT":
			game.get("new_country").select(index)
			game.call("_on_country_selected", index)
	game.get("new_start_mode").select(1)
	game.call("_on_start_mode_changed", 1)
	await process_frame
	await _press("INICIAR CAMPANHA")
	_check(_screen() == "new_game", "HT sem partidos oficiais não deve iniciar campanha oficial")
	game.get("new_start_mode").select(0)
	game.call("_on_start_mode_changed", 0)



func _phase_campaign_zero(country_id: String) -> void:
	print("[walk] campanha criada do zero: " + country_id)
	game.call("_show_menu")
	await _frames()
	await _press("FUNDAR NOVA CAMPANHA")
	var countries: Array = game.get("countries")
	for index in countries.size():
		if str(countries[index].get("id", "")) == country_id:
			game.get("new_country").select(index)
			game.call("_on_country_selected", index)
	game.get("new_start_mode").select(0)
	game.call("_on_start_mode_changed", 0)
	await _frames()
	game.get("new_party_name").text = "Frente Aurora"
	game.get("new_party_abbr").text = "FA"
	game.get("new_leader").text = "Marina Duarte"
	game.get("new_ideology").select(2)
	game.get("new_scenario").select(0)
	await _press("INICIAR CAMPANHA")
	_check(_screen() == "promises", "iniciar campanha deve abrir o programa de governo")
	_check(str(_state().get("abbr", "")) == "FA", "sigla informada deve ser aplicada")
	_check(str(_state().get("party", "")) == "Frente Aurora", "nome informado deve ser aplicado")
	_check(str(_state().get("start_mode", "")) == "Partido criado do zero", "modo de início deve ser registrado")

	# Toggle de promessas: 3 aceitas, a quarta é recusada.
	var promise_buttons: Array = game.get("promise_checks")
	_check(promise_buttons.size() == 6, "programa deve oferecer 6 compromissos (tem %d)" % promise_buttons.size())
	for i in mini(4, promise_buttons.size()):
		var b: Button = promise_buttons[i]
		b.button_pressed = not b.button_pressed
		await process_frame
	var selected := 0
	for b in promise_buttons:
		if (b as Button).button_pressed:
			selected += 1
	_check(selected == 3, "quarta promessa deve ser recusada (selecionadas %d)" % selected)
	_check(not (game.get("promise_confirm") as Button).disabled, "confirmar deve liberar com três promessas")
	await _press("CONFIRMAR PROGRAMA")
	_check(_screen() == "game", "confirmar programa deve abrir o jogo")
	_check(int(_state().get("months_to_election", 0)) > 0, "campanha deve ter prazo até a eleição")

	await _tour_screens()
	await _opposition_actions()
	await _congress_actions()
	await _advance_months_and_international()
	await _settings_roundtrip()
	await _election_and_result()
	await _back_to_menu_and_continue()

func _tour_screens() -> void:
	for item in ["Visão geral", "Meu partido", "Eleições", "Congresso", "Governo", "Economia", "População", "Regiões", "Internacional", "Notícias", "História", "Configurações"]:
		await _nav(item)
		_check(_screen() == "game", "navegar para %s deve manter a tela de jogo" % item)
		_check(_count_labels(game.get("main_column")) >= 3, "%s deve renderizar conteúdo" % item)
		_check((game.get("right_column") as Node).get_child_count() >= 2, "%s deve renderizar a coluna lateral" % item)
		_check(not _main_text().contains("null"), "%s não deve exibir texto nulo" % item)

func _opposition_actions() -> void:
	await _nav("Visão geral")
	var popularity_before := float(_state().get("popularity", 0.0))
	var funds_before := float(_state().get("funds", 0.0))
	await _press("FAZER OPOSIÇÃO ATIVA")
	_check(float(_state().get("popularity", 0.0)) > popularity_before, "oposição ativa deve aumentar popularidade")
	_check(float(_state().get("funds", 0.0)) < funds_before, "oposição ativa deve custar caixa")
	_check(_find_button("FAZER OPOSIÇÃO ATIVA", true).disabled, "oposição ativa deve ficar indisponível no mesmo mês")

	await _nav("Meu partido")
	var members_before := int(_state().get("members", 0))
	await _press("Formar voluntários")
	_check(int(_state().get("members", 0)) > members_before, "formar voluntários deve aumentar membros")

	await _nav("Eleições")
	var campaign_actions := int(_state().get("campaign_actions", 0))
	for i in 4:
		if _find_button("Militância de base") != null:
			await _press("Militância de base")
	_check(int(_state().get("campaign_actions", 0)) == campaign_actions + 3, "limite de 3 ações de campanha por mês")
	_check(_main_text().contains("PRÓXIMA ELEIÇÃO"), "tela de eleições deve mostrar a próxima eleição")
	var months_label := "%d meses" % int(_state().get("months_to_election", 0))
	_check(_main_text().contains(months_label), "contagem regressiva deve usar meses_to_election (%s)" % months_label)

func _congress_actions() -> void:
	await _nav("Congresso")
	var funds_before := float(_state().get("funds", 0.0))
	var bill_button: Button = null
	for item in _buttons():
		var b: Button = item
		if b.tooltip_text.contains("custo M$"):
			bill_button = b
			break
	_check(bill_button != null, "congresso deve oferecer proposições")
	if bill_button == null:
		return
	bill_button.pressed.emit()
	await _frames(6)
	_check((_state().get("bills", []) as Array).size() == 1, "votação deve registrar a proposição na agenda")
	_check(not bool(game.get("_bill_in_progress")), "votação deve concluir sem IA")
	_check(float(_state().get("funds", 0.0)) <= funds_before, "proposição aprovada pode consumir caixa")

func _advance_months_and_international() -> void:
	await _nav("Visão geral")
	var year_before := int(_state().get("date_year", 0))
	var month_before := int(_state().get("date_month", 0))
	await _press("AVANÇAR MÊS")
	var month_after := int(_state().get("date_month", 1))
	var year_after := int(_state().get("date_year", 0))
	_check(year_after > year_before or month_after == month_before + 1, "avançar mês deve mover a data")
	_check(not bool(game.get("_month_in_progress")), "mês deve fechar com fallback")
	_check(str(_state().get("month_completed", "")) == "%d-%02d" % [year_after, month_after], "mês fechado deve ficar carimbado")

	# Dezembro: a cena internacional precisa existir depois do avanço.
	_state()["date_month"] = 11
	_state()["months_to_election"] = 3
	game.call("_show_game")
	await _frames()
	await _press("AVANÇAR MÊS")
	var intl: Dictionary = _state().get("international", {}) if _state().get("international") is Dictionary else {}
	_check(not intl.is_empty(), "dezembro deve gerar cena internacional")
	_check(str(intl.get("event", "")) != "", "cena internacional deve ter evento")
	await _nav("Internacional")
	_check(_main_text().contains("CENA EXTERNA"), "tela internacional deve mostrar a cena gerada")
	_check(_main_text().contains("Origem da decisão"), "tela internacional deve informar a origem")
	await _nav("Notícias")
	_check(_main_text().contains("01"), "notícias devem ser numeradas")

func _settings_roundtrip() -> void:
	await _nav("Configurações")
	_check(_main_text().contains("IA LOCAL"), "configurações devem mostrar o estado da IA")
	await _press("SALVAR AGORA")
	_check(FileAccess.file_exists("user://mandatia_save.json"), "salvar agora deve gravar o save")
	await _press("EXPORTAR JSON")
	_check(FileAccess.file_exists("user://mandato_export.json"), "exportar deve gravar o JSON")
	var party := str(_state().get("party", ""))
	await _press("IMPORTAR JSON")
	_check(str(_state().get("party", "")) == party, "importar deve restaurar a campanha exportada")
	_check(_screen() == "game", "importar deve voltar ao jogo")

func _election_and_result() -> void:
	_state()["months_to_election"] = 0
	await _nav("Eleições")
	_check(_find_button("REALIZAR ELEIÇÃO") != null, "pleito deve ficar disponível ao fim do prazo")
	await _press("REALIZAR ELEIÇÃO")
	_check(_screen() == "result", "eleição deve abrir o resultado")
	var last: Dictionary = _state().get("last_result", {})
	_check(not last.is_empty(), "resultado deve registrar o pleito")
	_check(int(last.get("seats", 0)) > 0, "resultado deve ter cadeiras da câmara")
	var seat_total := 0
	for value in (_state().get("seat_map", {}) as Dictionary).values():
		seat_total += int(value)
	_check(seat_total == int(last.get("seats", -1)), "bancadas devem somar as cadeiras da câmara (%d)" % seat_total)
	_check(_all_text(root).contains("PROGRAMA DE GOVERNO"), "resultado deve listar o programa")
	await _press("ESCOLHER NOVO PROGRAMA")
	_check(_screen() == "promises", "resultado deve abrir o novo programa")
	game.call("_auto_pick_promises")
	await _frames()
	_check(_screen() == "game", "novo programa deve voltar ao jogo")
	var expected_months := 48 if bool(_state().get("government", false)) else 12
	_check(int(_state().get("months_to_election", 0)) == expected_months, "novo ciclo deve ter %d meses" % expected_months)

func _back_to_menu_and_continue() -> void:
	await _press("MENU PRINCIPAL")
	_check(_screen() == "menu", "menu principal deve voltar à primeira tela")
	var continue_button := _find_button("CONTINUAR CAMPANHA", true)
	_check(continue_button != null and not continue_button.disabled, "continuar deve ficar disponível com save")
	await _press("CONTINUAR CAMPANHA")
	_check(_screen() == "game", "continuar deve carregar a campanha")

func _phase_campaign_official(country_id: String) -> void:
	print("[walk] campanha com partido oficial: " + country_id)
	game.call("_show_menu")
	await _frames()
	await _press("FUNDAR NOVA CAMPANHA")
	var countries: Array = game.get("countries")
	for index in countries.size():
		if str(countries[index].get("id", "")) == country_id:
			game.get("new_country").select(index)
			game.call("_on_country_selected", index)
	game.get("new_start_mode").select(1)
	game.call("_on_start_mode_changed", 1)
	await _frames()
	await _press("INICIAR CAMPANHA")
	_check(_screen() == "promises", "campanha oficial deve abrir o programa")
	_check(str(_state().get("start_mode", "")) == "Partido oficial", "modo oficial deve ser registrado")
	_check(int(_state().get("lower_house_seats", 0)) > 0, "partido oficial deve começar com cadeiras")
	game.call("_auto_pick_promises")
	await _frames()
	_check(_screen() == "game", "programa oficial deve abrir o jogo")

	await _nav("Governo")
	var text := _main_text()
	_check(text.contains("FORMAÇÃO DE GOVERNO") or text.contains("GABINETE"), "governo deve oferecer formação ou gabinete")
	if _find_button("FECHAR COALIZÃO") != null:
		await _press("FECHAR COALIZÃO")
		_check(bool(_state().get("government", false)), "coalizão deve formar governo")
		await _nav("Governo")
		_check(_main_text().contains("GABINETE"), "governo formado deve mostrar gabinete")
		var credibility_before := float(_state().get("credibility", 0.0))
		await _press("NOMEAR")
		_check(float(_state().get("credibility", 0.0)) >= credibility_before, "nomear ministro deve atualizar o gabinete")
		if _find_button("Pacto de empregos") != null:
			var unemployment_before := float(_state().get("unemployment", 0.0))
			await _press("Pacto de empregos")
			_check(float(_state().get("unemployment", 0.0)) < unemployment_before, "programa de empregos deve reduzir desemprego")
		await _nav("Congresso")
		var bills := 0
		for item in _buttons():
			var b: Button = item
			if b.tooltip_text.contains("custo M$"):
				bills += 1
		_check(bills >= 6, "governo deve ver as seis proposições (tem %d)" % bills)

	# Moção de censura: oposição com condições políticas no parlamento.
	_state()["government"] = false
	_state()["term_months_served"] = 10
	_state()["approval"] = 20.0
	_state()["funds"] = 9000.0
	_state()["credibility"] = 60.0
	if int(_state().get("lower_house_seats", 0)) <= 0:
		_state()["lower_house_seats"] = 5
	game.set("selected_nav", "Governo")
	game.call("_show_game")
	await _frames()
	if _find_button("APRESENTAR MOÇÃO") != null:
		var funds_before := float(_state().get("funds", 0.0))
		await _press("APRESENTAR MOÇÃO")
		_check(float(_state().get("funds", 0.0)) < funds_before, "moção de censura deve consumir caixa")
	else:
		_check(_main_text().contains("MOÇÃO DE CENSURA"), "governo em oposição deve mostrar o painel de censura")
