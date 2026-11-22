extends SceneTree
## Teste de interação ponta a ponta (skill godot-ui-control, padrão 4 estendido).
## Dirige a cena real com eventos sintéticos e prova três coisas por tela:
##  1. o foco existe e tem indicador visível (anel de foco desenhável e na tela);
##  2. as quatro direções nunca levam o foco a nada oculto/nulo;
##  3. ui_cancel devolve ao menu e reentrar restaura o foco.
## Uso: godot --headless --path . --script test/test_interaction.gd

const FOCUS_GUARD := 80
const MONTH_GUARD := 400
const DIRECTIONS := ["ui_up", "ui_down", "ui_left", "ui_right"]
const ACTION_KEYS := {
	"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT,
	"ui_accept": KEY_ENTER, "ui_cancel": KEY_ESCAPE,
}
const PAD_BUTTONS := {
	"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
	"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
	"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
}
const SECTIONS := [
	"Visão geral", "Meu partido", "Eleições", "Congresso", "Governo", "Economia",
	"População", "Regiões", "Internacional", "Notícias", "História", "Configurações",
]

var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _keyboard_flow()
	await _pointer_flow()
	await _gamepad_flow()
	await _report_flow()
	await _escape_flow()
	await _no_ai_month_flow()
	if failures.is_empty():
		print("[interaction] PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("[interaction] " + str(failure))
		print("[interaction] FAIL: %d falhas em %d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

# ------------------------------------------------------------------ jogador

## Instancia a cena real num SubViewport de 1280x720 e desliga a IA para que
## todo caminho use o fallback determinístico e nada dependa de rede.
func _make_game() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await _frames(12)
	var ai: Node = game.get("ai")
	if ai != null:
		ai.stop()
		ai.set("ai_available", false)
		ai.set("availability_checked", true)
	await _frames(2)
	return [viewport, game]

## Tecla física (é o que o jogador de teclado aperta).
func _press_key(viewport: SubViewport, action: String) -> void:
	var keycode: Key = ACTION_KEYS[action]
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		viewport.push_input(event, true)
	await _frames(1)

## Ação como o gamepad entrega à UI (A/B e D-pad mapeados em ui_*).
## Eventos físicos de joypad não chegam ao GUI headless; a camada de ação é
## exatamente o que o controle emite depois do InputMap.
func _press_pad(viewport: SubViewport, action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		viewport.push_input(event, true)
	await _frames(1)

func _click(viewport: SubViewport, control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = position
	down.global_position = position
	down.pressed = true
	viewport.push_input(down, true)
	await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.button_mask = 0
	up.position = position
	up.global_position = position
	up.pressed = false
	viewport.push_input(up, true)
	await _frames(1)

func _find_button(game: Node, needle: String) -> Button:
	for node in game.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and button.text.contains(needle):
			return button
	return null

func _wait_month(game: Node) -> void:
	for _i in MONTH_GUARD:
		await process_frame
		if not bool(game.get("_month_in_progress")):
			return

func _focus(viewport: SubViewport) -> Control:
	return viewport.gui_get_focus_owner()

func _screen(game: Node) -> String:
	return str(game.get("screen"))

# --------------------------------------------------- foco visível / travessia

## Um controle focado precisa: existir, estar visível, ter tamanho, estar
## dentro da tela e possuir um estilo de foco que pinte algo diferente do normal.
func _focus_ok(control: Control, viewport: SubViewport) -> bool:
	return _focus_reason(control, viewport) == ""

func _check_focus(viewport: SubViewport, label: String) -> void:
	var reason := _focus_reason(_focus(viewport), viewport)
	_check(reason == "", "%s (%s)" % [label, reason])

func _check_focus_control(control: Control, viewport: SubViewport, label: String) -> void:
	var reason := _focus_reason(control, viewport)
	_check(reason == "", "%s (%s)" % [label, reason])

func _focus_reason(control: Control, viewport: SubViewport) -> String:
	if control == null or not is_instance_valid(control):
		return "foco nulo"
	if not control.is_visible_in_tree():
		return "controle oculto (%s)" % control.name
	if control.size.x < 2.0 or control.size.y < 2.0:
		return "controle sem tamanho (%s)" % control.name
	var rect := control.get_global_rect()
	var screen_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	if not screen_rect.has_point(rect.get_center()):
		return "controle fora da tela (%s em %s)" % [control.name, rect]
	if not _has_focus_ring(control):
		return "sem indicador de foco visível (%s)" % control.name
	return ""

## O estilo de foco precisa desenhar borda ou fundo e diferir do estado normal.
func _has_focus_ring(control: Control) -> bool:
	var focus := control.get_theme_stylebox("focus")
	if focus == null:
		return false
	var normal := control.get_theme_stylebox("normal")
	if focus is StyleBoxFlat:
		var flat := focus as StyleBoxFlat
		var border := flat.border_width_left + flat.border_width_right + flat.border_width_top + flat.border_width_bottom
		var painted := border > 0 or flat.bg_color.a > 0.01
		if not painted:
			return false
		if normal is StyleBoxFlat:
			var base := normal as StyleBoxFlat
			var base_border := base.border_width_left + base.border_width_right + base.border_width_top + base.border_width_bottom
			var same_fill := flat.bg_color.is_equal_approx(base.bg_color)
			var same_border := flat.border_color.is_equal_approx(base.border_color) and border == base_border
			return not (same_fill and same_border)
		return true
	if focus is StyleBoxTexture:
		return true
	return focus.get_minimum_size() != Vector2.ZERO

func _focusables(root_node: Node) -> Array:
	var out: Array = []
	for node in root_node.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode != Control.FOCUS_ALL:
			continue
		if not control.is_visible_in_tree():
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		out.append(control)
	return out

## Exaustivo: cada controle focável da tela, cada uma das quatro direções.
## O foco resultante nunca pode ser nulo, oculto, fora da tela ou sem anel.
func _traverse_screen(viewport: SubViewport, game: Node, label: String) -> void:
	var controls := _focusables(game)
	_check(controls.size() > 0, "%s: existe controle focável" % label)
	var moves := 0
	for control in controls:
		if not is_instance_valid(control):
			continue
		control.grab_focus()
		await _frames(1)
		if _focus(viewport) != control:
			continue
		for direction in DIRECTIONS:
			await _press_key(viewport, direction)
			var owner := _focus(viewport)
			var reason := _focus_reason(owner, viewport)
			_check(reason == "", "%s: %s a partir de %s → %s" % [label, direction, control.name, reason])
			if owner != null and owner != control:
				moves += 1
	if controls.size() > 1:
		_check(moves > 0, "%s: setas realmente movem o foco" % label)

## Mesma travessia pelo D-pad (ações ui_*), para provar paridade com o teclado.
func _traverse_screen_pad(viewport: SubViewport, game: Node, label: String) -> void:
	var controls := _focusables(game)
	var moves := 0
	for control in controls:
		if not is_instance_valid(control):
			continue
		control.grab_focus()
		await _frames(1)
		if _focus(viewport) != control:
			continue
		for direction in DIRECTIONS:
			await _press_pad(viewport, direction)
			var owner := _focus(viewport)
			var reason := _focus_reason(owner, viewport)
			_check(reason == "", "%s: D-pad %s a partir de %s → %s" % [label, direction, control.name, reason])
			if owner != null and owner != control:
				moves += 1
	if controls.size() > 1:
		_check(moves > 0, "%s: D-pad realmente move o foco" % label)

# ------------------------------------------------------- fluxo por teclado

func _keyboard_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	_check(_screen(game) == "menu", "teclado: jogo abre no menu")
	_check_focus(viewport, "teclado: menu já nasce com foco visível")

	await _press_key(viewport, "ui_accept")
	_check(_screen(game) == "new_game", "teclado: ENTER abre nova campanha")
	_check_focus(viewport, "teclado: nova campanha recebe foco visível")

	await _press_key(viewport, "ui_accept")
	_check(_screen(game) == "promises", "teclado: ENTER inicia a campanha")
	_check(_focus(viewport) is BaseButton, "teclado: programa de governo foca uma opção")

	for _i in 3:
		await _press_key(viewport, "ui_accept")
		await _press_key(viewport, "ui_down")
	var confirm: Button = game.get("promise_confirm")
	_check(confirm != null and not confirm.disabled, "teclado: três promessas habilitam confirmar")

	var guard := 0
	while _focus(viewport) != confirm and guard < FOCUS_GUARD:
		await _press_key(viewport, "ui_down")
		guard += 1
	_check(_focus(viewport) == confirm, "teclado: setas alcançam CONFIRMAR PROGRAMA")
	await _press_key(viewport, "ui_accept")
	_check(_screen(game) == "game", "teclado: confirma e entra no jogo")

	var month_before := int(game.get("state")["date_month"])
	var year_before := int(game.get("state")["date_year"])
	_check(_focus(viewport) == game.get("month_button"), "teclado: jogo foca AVANÇAR MÊS")
	await _press_key(viewport, "ui_accept")
	await _wait_month(game)
	var month_after := int(game.get("state")["date_month"])
	var year_after := int(game.get("state")["date_year"])
	_check(month_after != month_before or year_after != year_before, "teclado: ENTER avança o mês")
	_check(not bool(game.get("_month_in_progress")), "teclado: mês fecha sem travar")
	var report: Array = game.get("state").get("month_report", []) if game.get("state").get("month_report") is Array else []
	_check(not report.is_empty(), "teclado: relatório do mês é gerado")
	_check(is_instance_valid(game.get("month_report_panel")), "teclado: relatório do mês abre como tela")
	var continue_button: Button = game.get("month_report_continue")
	_check(_focus(viewport) == continue_button, "teclado: relatório foca CONTINUAR")
	_check_focus_control(continue_button, viewport, "teclado: CONTINUAR tem foco visível")
	await _press_key(viewport, "ui_accept")
	_check(not is_instance_valid(game.get("month_report_panel")), "teclado: ENTER fecha o relatório")
	_check_focus(viewport, "teclado: foco volta ao painel após o relatório")

	game.get("state")["event"] = "Greve geral no transporte"
	game.call("_show_game")
	await _frames(6)
	var invest := _find_button(game, "Investir agora")
	_check(invest != null, "teclado: decisão pendente é renderizada")
	guard = 0
	while _focus(viewport) != invest and guard < FOCUS_GUARD:
		await _press_key(viewport, "ui_down")
		guard += 1
	if _focus(viewport) != invest:
		guard = 0
		while _focus(viewport) != invest and guard < FOCUS_GUARD:
			await _press_key(viewport, "ui_right")
			guard += 1
	_check(_focus(viewport) == invest, "teclado: direções alcançam a decisão pendente")
	await _press_key(viewport, "ui_accept")
	_check(str(game.get("state").get("event", "")) == "", "teclado: ENTER resolve a decisão")

	await _press_key(viewport, "ui_cancel")
	_check(_screen(game) == "menu", "teclado: ESCAPE volta ao menu sem prender")

	viewport.queue_free()
	await _frames(2)

# ------------------------------------------------------- fluxo por ponteiro

func _pointer_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	var new_campaign := _find_button(game, "FUNDAR NOVA CAMPANHA")
	_check(new_campaign != null, "mouse: botão de nova campanha existe")
	await _click(viewport, new_campaign)
	_check(_screen(game) == "new_game", "mouse: clique abre nova campanha")

	var start := _find_button(game, "INICIAR CAMPANHA")
	_check(start != null, "mouse: botão iniciar campanha existe")
	await _click(viewport, start)
	_check(_screen(game) == "promises", "mouse: clique inicia a campanha")

	var checks_array: Array = game.get("promise_checks")
	_check(checks_array.size() >= 3, "mouse: opções de promessa disponíveis")
	for index in 3:
		await _click(viewport, checks_array[index] as Control)
	var confirm: Button = game.get("promise_confirm")
	_check(confirm != null and not confirm.disabled, "mouse: três cliques habilitam confirmar")
	await _click(viewport, confirm)
	_check(_screen(game) == "game", "mouse: confirma e entra no jogo")

	var month_before := int(game.get("state")["date_month"])
	await _click(viewport, game.get("month_button") as Control)
	await _wait_month(game)
	_check(int(game.get("state")["date_month"]) != month_before, "mouse: clique avança o mês")
	_check(not bool(game.get("_month_in_progress")), "mouse: mês fecha sem travar")
	_check(is_instance_valid(game.get("month_report_panel")), "mouse: relatório do mês abre como tela")
	await _click(viewport, game.get("month_report_continue") as Control)
	_check(not is_instance_valid(game.get("month_report_panel")), "mouse: clique fecha o relatório")
	_check_focus(viewport, "mouse: foco volta ao painel após o relatório")

	game.get("state")["event"] = "Crise no abastecimento"
	game.call("_show_game")
	await _frames(6)
	var negotiate := _find_button(game, "Negociar")
	_check(negotiate != null, "mouse: decisão pendente é renderizada")
	await _click(viewport, negotiate)
	_check(str(game.get("state").get("event", "")) == "", "mouse: clique resolve a decisão")

	viewport.queue_free()
	await _frames(2)

# --------------------------------------------------------- fluxo por gamepad

func _gamepad_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	_check(_focus(viewport) != null, "gamepad: menu tem foco para o controle")
	await _press_pad(viewport, "ui_accept")
	_check(_screen(game) == "new_game", "gamepad: A abre nova campanha")
	_check_focus(viewport, "gamepad: foco visível em nova campanha")
	await _press_pad(viewport, "ui_cancel")
	_check(_screen(game) == "menu", "gamepad: B volta ao menu")
	await _press_pad(viewport, "ui_accept")
	await _press_pad(viewport, "ui_accept")
	_check(_screen(game) == "promises", "gamepad: A inicia a campanha")
	await _press_pad(viewport, "ui_down")
	_check_focus(viewport, "gamepad: D-pad move o foco com indicador")

	viewport.queue_free()
	await _frames(2)

# ------------------------------------------- relatório + painel (teclado/pad)

func _report_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	# Campanha rápida pelo teclado.
	await _press_key(viewport, "ui_accept")
	await _press_key(viewport, "ui_accept")
	for _i in 3:
		await _press_key(viewport, "ui_accept")
		await _press_key(viewport, "ui_down")
	var confirm: Button = game.get("promise_confirm")
	confirm.grab_focus()
	await _frames(1)
	await _press_key(viewport, "ui_accept")
	_check(_screen(game) == "game", "relatório: campanha inicia pelo teclado")

	# Mês 1 → relatório; percorrer as quatro direções e o D-pad nele.
	await _press_key(viewport, "ui_accept")
	await _wait_month(game)
	var continue_button: Button = game.get("month_report_continue")
	_check(is_instance_valid(game.get("month_report_panel")), "relatório: tela do mês abriu após o avanço")
	_check(_focus(viewport) == continue_button, "relatório: foco no CONTINUAR")
	_check_focus_control(continue_button, viewport, "relatório: CONTINUAR mostra anel de foco")
	for direction in DIRECTIONS:
		await _press_key(viewport, direction)
		_check(_focus(viewport) == continue_button and _focus_ok(continue_button, viewport), "relatório: %s mantém foco visível em CONTINUAR" % direction)
	for direction in DIRECTIONS:
		await _press_pad(viewport, direction)
		_check(_focus(viewport) == continue_button and _focus_ok(continue_button, viewport), "relatório: D-pad %s mantém foco visível" % direction)
	await _press_key(viewport, "ui_accept")
	_check(not is_instance_valid(game.get("month_report_panel")), "relatório: ui_accept fecha a tela do mês")
	_check(_focus(viewport) == game.get("month_button"), "relatório: foco volta para AVANÇAR MÊS")

	# Painel do mês: travessia exaustiva, teclado e D-pad.
	await _traverse_screen(viewport, game, "painel do mês")
	await _traverse_screen_pad(viewport, game, "painel do mês")

	# Segundo mês: fechar com ui_cancel em vez de ui_accept.
	(game.get("month_button") as Control).grab_focus()
	await _frames(1)
	await _press_key(viewport, "ui_accept")
	await _wait_month(game)
	_check(is_instance_valid(game.get("month_report_panel")), "relatório: segundo mês abre o relatório")
	await _press_key(viewport, "ui_cancel")
	_check(not is_instance_valid(game.get("month_report_panel")), "relatório: ui_cancel fecha a tela do mês")
	_check(_screen(game) == "game", "relatório: fechar não sai do jogo")
	_check_focus(viewport, "relatório: foco restaurado após ui_cancel")

	# Eleição obrigatória: AVANÇAR MÊS desabilitado não pode matar o foco.
	game.get("state")["months_to_election"] = 1
	(game.get("month_button") as Control).grab_focus()
	await _frames(1)
	await _press_key(viewport, "ui_accept")
	await _wait_month(game)
	if is_instance_valid(game.get("month_report_panel")):
		await _press_key(viewport, "ui_accept")
	await _frames(2)
	_check(bool((game.get("month_button") as Button).disabled), "eleição: AVANÇAR MÊS fica desabilitado")
	_check_focus(viewport, "eleição: foco sobrevive ao mês desabilitado")
	await _traverse_screen(viewport, game, "painel com eleição pendente")

	# Resultado do mandato: tela dirigida de verdade (eleição direta).
	game.call("_run_election")
	await _frames(6)
	_check(_screen(game) == "result", "resultado: eleição leva à tela de resultado")
	_check_focus(viewport, "resultado: aberto com foco visível")
	await _traverse_screen(viewport, game, "resultado")

	viewport.queue_free()
	await _frames(2)

# ------------------------------------------- saída por tela: ESC volta ao menu

func _escape_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	# Menu: ESC não prende nem apaga o foco.
	await _press_key(viewport, "ui_cancel")
	_check(_screen(game) == "menu", "esc: menu continua no menu")
	_check_focus(viewport, "esc: menu preserva foco visível")

	var screens := ["nova campanha", "programa", "resultado"]
	for name in screens:
		match name:
			"nova campanha": game.call("_show_new_game")
			"programa": game.call("_show_promises")
			"resultado": game.call("_show_result")
		await _frames(6)
		_check_focus(viewport, "esc: %s abre com foco visível" % name)
		await _press_key(viewport, "ui_cancel")
		_check(_screen(game) == "menu", "esc: %s volta ao menu" % name)
		_check_focus(viewport, "esc: menu reabre com foco visível após %s" % name)

	for section in SECTIONS:
		game.call("_select_nav", section)
		await _frames(6)
		_check(_screen(game) == "game", "esc: %s abre no jogo" % section)
		_check_focus(viewport, "esc: %s com foco visível" % section)
		await _traverse_screen(viewport, game, section)
		await _press_key(viewport, "ui_cancel")
		_check(_screen(game) == "menu", "esc: %s volta ao menu" % section)
		_check_focus(viewport, "esc: foco restaurado no menu após %s" % section)

	# Reentrar restaura foco: seção e resultado.
	game.call("_select_nav", "Visão geral")
	await _frames(6)
	_check_focus(viewport, "esc: reentrar no jogo restaura foco visível")
	game.call("_show_result")
	await _frames(6)
	_check(_focus(viewport) == _find_button(game, "ESCOLHER NOVO PROGRAMA"), "esc: resultado reabre com foco no próximo programa")

	viewport.queue_free()
	await _frames(2)

# --------------------------------------------------------- fluxo sem Ollama

func _no_ai_month_flow() -> void:
	var pair: Array = await _make_game()
	var viewport: SubViewport = pair[0]
	var game: Control = pair[1]

	await _click(viewport, _find_button(game, "FUNDAR NOVA CAMPANHA"))
	await _click(viewport, _find_button(game, "INICIAR CAMPANHA"))
	var checks_array: Array = game.get("promise_checks")
	for index in 3:
		await _click(viewport, checks_array[index] as Control)
	await _click(viewport, game.get("promise_confirm") as Control)
	_check(_screen(game) == "game", "sem IA: campanha inicia")

	# Dois avanços levam do mês 1 ao mês 3, quando o evento é devido.
	for _i in 2:
		await _click(viewport, game.get("month_button") as Control)
		await _wait_month(game)
		if is_instance_valid(game.get("month_report_panel")):
			await _click(viewport, game.get("month_report_continue") as Control)
	_check(not bool(game.get("_month_in_progress")), "sem IA: meses fecham sem travar")
	var event_text := str(game.get("state").get("event", ""))
	_check(event_text != "", "sem IA: evento do mês chega pelo fallback")
	var first_option: Dictionary = (game.get("state").get("event_options", []) as Array)[0] if not (game.get("state").get("event_options", []) as Array).is_empty() else {}
	var decision := _find_button(game, str(first_option.get("label", "Investir agora")))
	_check(decision != null and decision.is_visible_in_tree(), "sem IA: decisão fica visível na tela")
	_check(str(game.get("state").get("month_completed", "")) != "", "sem IA: mês registra conclusão")

	viewport.queue_free()
	await _frames(2)
