extends SceneTree
## Ferramenta de captura visual da Fase 1.
## Abre o jogo numa janela normal e salva PNGs em res://docs/shots/baseline/.
## Uso: Godot_v4.7-stable_win64_console.exe --path . --script tools/capture_fase1.gd --res 1280x720
## Resoluções: 1280x720 (base, padrão), 1600x900, 1920x1080
var SHOT_DIR := "res://docs/shots/baseline"

func _parse_out() -> void:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			SHOT_DIR = "res://docs/shots/" + args[i + 1].strip_edges().trim_prefix("/")
			return

func _parse_resolution() -> Vector2i:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--res" and i + 1 < args.size():
			var parts := args[i + 1].split("x")
			if parts.size() == 2:
				var w := int(parts[0])
				var h := int(parts[1])
				if w > 0 and h > 0:
					return Vector2i(w, h)
	print("[capture] resolução inválida ou ausente; usando 1280x720 padrão")
	return Vector2i(1280, 720)

func _initialize() -> void:
	_parse_out()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var res := _parse_resolution()
	DisplayServer.window_set_size(res)
	print("[capture] resolução: %dx%d  saida: %s" % [res.x, res.y, SHOT_DIR])
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await _settle()
	# Fallback determinístico: sem isso o avanço de mês fica bloqueado esperando
	# o modelo e as capturas saem com o painel de espera em cima da tela.
	var ai: Node = game.get("ai")
	if ai != null:
		ai.stop()
		ai.set("ai_available", false)
		ai.set("availability_checked", true)
	_shot("menu")

	game.call("_show_new_game")
	await _settle()
	game.get("new_party_name").text = "Frente Aurora"
	game.get("new_party_abbr").text = "FA"
	game.get("new_leader").text = "Ana Ribeiro"
	game.call("_start_campaign")
	await _settle()
	_shot("programa-de-governo")
	game.call("_auto_pick_promises")
	await _settle()
	for _month in 8:
		await _advance(game)
	await _settle()
	print("[report] ", game.get("state").get("month_report", []))
	_shot("cabecalho-e-painel")

	game.call("_select_nav", "Congresso")
	await _settle()
	_shot("congresso-hemiciclo")

	game.call("_select_nav", "Economia")
	await _settle()
	_shot("economia")

	game.call("_select_nav", "Regiões")
	await _settle()
	_shot("regioes")

	game.call("_select_nav", "População")
	await _settle()
	_shot("populacao")

	game.call("_select_nav", "Eleições")
	await _settle()
	_shot("eleicoes")

	game.get("state")["months_to_election"] = 0
	game.call("_select_nav", "Eleições")
	await _settle()
	game.call("_run_election")
	await _settle()
	print("[shot] tela após eleição: ", game.get("screen"))
	_shot("resultado-do-mandato")
	game.call("_auto_pick_promises")
	await _settle()
	game.call("_select_nav", "Visão geral")
	await _settle()

	DisplayServer.window_set_size(Vector2i(980, 700))
	await _settle()
	game.call("_apply_responsive")
	await _settle()
	_shot("janela-estreita")
	print("[shot] viewport: ", root.size, "  janela: ", DisplayServer.window_get_size())

	game.queue_free()
	await process_frame
	quit(0)

## Avança um mês e espera o mês fechar (fallback síncrono ou IA respondida).
func _advance(game: Node) -> void:
	game.call("_advance_month")
	# O relatório do mês é modal: fecha para fotografar o painel por baixo.
	if is_instance_valid(game.get("month_report_panel")):
		game.call("_dismiss_month_report")
	for _i in 200:
		await process_frame
		var current: Dictionary = game.get("state")
		var expected := "%d-%02d" % [int(current.get("date_year", 0)), int(current.get("date_month", 0))]
		if not bool(game.get("_month_in_progress")) or str(current.get("month_completed", "")) == expected:
			return

func _settle() -> void:
	for _i in 18:
		await process_frame
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		print("[shot] vazio: ", name)
		return
	var path := "%s/%s.png" % [SHOT_DIR, name]
	var error := image.save_png(path)
	print("[shot] %s  %dx%d  erro=%d" % [path, image.get_width(), image.get_height(), error])
