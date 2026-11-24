extends SceneTree
## Teste headless de layout (padrão da skill godot-ui-control).
## Abre a cena principal nas três resoluções-alvo e falha quando um Control
## visível fica fora dos limites da tela. Filhos de ScrollContainer são
## ignorados de propósito: eles podem se estender além do viewport.
## Uso: godot --headless --path . --script test/test_ui_layout.gd

const SIZES := [Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1920, 1080)]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	for size in SIZES:
		var viewport := SubViewport.new()
		viewport.size = size
		root.add_child(viewport)
		var game: Control = load("res://scenes/main.tscn").instantiate()
		viewport.add_child(game)
		# Cartões de onboarding não entram na checagem geométrica do layout.
		game.get("state")["tutorial_done"] = true
		for _i in 24:
			await process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		if viewport.gui_get_focus_owner() == null:
			failures += 1
			push_error("[ui-layout] menu sem foco inicial em %s" % size)
		for node in game.find_children("*", "Control", true, false):
			var control := node as Control
			if not control.is_visible_in_tree():
				continue
			if _inside_scroll(control):
				continue
			var rect := control.get_global_rect()
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			if not screen.encloses(rect):
				failures += 1
				push_error("[ui-layout] %s fora da tela em %s: %s" % [game.get_path_to(control), size, rect])
		# Nova campanha: foco visível e dentro da tela (formulário rola com o foco).
		game.call("_show_new_game")
		for _i in 8:
			await process_frame
		var new_focus := viewport.gui_get_focus_owner()
		if new_focus == null or not screen.has_point(new_focus.get_global_rect().get_center()):
			failures += 1
			push_error("[ui-layout] nova campanha sem foco visível em %s" % size)
		# Tela de jogo: o foco precisa existir para teclado/gamepad operarem.
		game.call("_auto_pick_promises")
		for _i in 8:
			await process_frame
		if viewport.gui_get_focus_owner() == null:
			failures += 1
			push_error("[ui-layout] tela de jogo sem foco inicial em %s" % size)
		# Recorte: nada no topo nem na lateral pode passar do próprio retângulo.
		failures += _check_inside(game.get("header_panel") as Control, "cabeçalho", size)
		failures += _check_inside(game.get("sidebar") as Control, "lateral", size)
		# B7: telas com as novas cadeias causais, conflito e procedimentos.
		for nav_item in ["Sociedade", "Crises", "Governo"]:
			game.call("_select_nav", nav_item)
			for _i in 6:
				await process_frame
			failures += _check_inside(game.get("header_panel") as Control, "cabeçalho/%s" % nav_item, size)
			failures += _check_inside(game.get("sidebar") as Control, "lateral/%s" % nav_item, size)
		game.call("_select_nav", "Visão geral")
		for _i in 6:
			await process_frame
		# Relatório do mês: abre como tela com foco visível dentro da área.
		game.get("state")["month_report"] = [{"label": "Aprovação", "delta": 0.2, "good": true}]
		game.call("_show_month_report")
		for _i in 6:
			await process_frame
		var report_focus := viewport.gui_get_focus_owner()
		if report_focus == null or not screen.has_point(report_focus.get_global_rect().get_center()):
			failures += 1
			push_error("[ui-layout] relatório do mês sem foco visível em %s" % size)
		game.call("_dismiss_month_report")
		for _i in 3:
			await process_frame
		# Eleição obrigatória desabilita o botão de mês: o foco não pode morrer.
		game.get("state")["months_to_election"] = 0
		game.call("_show_game")
		for _i in 8:
			await process_frame
		if viewport.gui_get_focus_owner() == null:
			failures += 1
			push_error("[ui-layout] jogo sem foco com mês desabilitado em %s" % size)
		# Modais precisam abrir já focadas.
		for modal in ["_show_promises", "_show_result"]:
			game.call(modal)
			for _i in 5:
				await process_frame
			if viewport.gui_get_focus_owner() == null:
				failures += 1
				push_error("[ui-layout] %s sem foco em %s" % [modal, size])
		viewport.queue_free()
		await process_frame
	print("[ui-layout] %d problema(s) em %d tamanhos" % [failures, SIZES.size()])
	quit(1 if failures > 0 else 0)

## Nenhum filho visível pode sair do retângulo do pai (topo e lateral).
func _check_inside(parent: Control, label: String, size: Vector2i) -> int:
	if parent == null:
		push_error("[ui-layout] %s ausente em %s" % [label, size])
		return 1
	var problems := 0
	var bounds := parent.get_global_rect().grow(1.0)
	for node in parent.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if not bounds.encloses(rect):
			problems += 1
			push_error("[ui-layout] %s: %s passa do retângulo em %s: %s" % [label, control.name, size, rect])
	return problems

func _inside_scroll(control: Control) -> bool:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false
