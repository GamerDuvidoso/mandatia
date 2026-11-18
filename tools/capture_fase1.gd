extends SceneTree
## Ferramenta de captura visual da Fase 1.
## Abre o jogo numa janela normal e salva PNGs em res://docs/shots/.
## Uso: Godot_v4.7-stable_win64.exe --path . --script tools/capture_fase1.gd

const SHOT_DIR := "res://docs/shots"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(Vector2i(1280, 720))
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
	_shot("cabecalho-e-painel")

	game.call("_select_nav", "Congresso")
	await _settle()
	_shot("congresso-hemiciclo")

	game.call("_select_nav", "Economia")
	await _settle()
	_shot("economia")

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
