extends Control
## Gráfico B1: plano econômico × social. Desenha os partidos reais e destaca o
## jogador em âmbar. Sem imagens e sem eixos decorativos: cada ponto é uma
## posição analítica carregada do estado.

const UI := preload("res://scripts/ui/mandato_theme.gd")

var positions: Dictionary = {}
var player_key := ""
var labels: Dictionary = {}
var _hovered := ""

func _ready() -> void:
	custom_minimum_size = Vector2(0, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): _hovered = ""; queue_redraw())
	tooltip_text = "Eixo horizontal: econômico (-100 intervencionista / +100 mercado). Vertical: social (-100 progressista / +100 conservador)."

func set_data(value: Dictionary, player: String, name_lookup: Dictionary = {}) -> void:
	positions = value
	player_key = player
	labels = name_lookup
	queue_redraw()

func _plot_rect() -> Rect2:
	return Rect2(Vector2(54, 22), size - Vector2(78, 54))

func _point(pos: Vector2) -> Vector2:
	var r := _plot_rect()
	return Vector2(r.position.x + (pos.x + 100.0) / 200.0 * r.size.x, r.position.y + (100.0 - pos.y) / 200.0 * r.size.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var closest := ""
		var best := 14.0
		for key in positions.keys():
			var distance := (event as InputEventMouseMotion).position.distance_to(_point(positions[key]))
			if distance < best:
				best = distance
				closest = str(key)
		if closest != _hovered:
			_hovered = closest
			queue_redraw()

func _draw() -> void:
	var r := _plot_rect()
	draw_rect(r, Color(0.05, 0.055, 0.06, 0.85), true)
	var grid := UI.LINE
	for i in range(1, 4):
		var x := r.position.x + r.size.x * i / 4.0
		var y := r.position.y + r.size.y * i / 4.0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(grid.r, grid.g, grid.b, 0.55), 1.0)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(grid.r, grid.g, grid.b, 0.55), 1.0)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.8), 1.2)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.8), 1.2)
	var font := ThemeDB.fallback_font
	var small := 10
	draw_string(font, Vector2(r.position.x + 4, r.end.y - 6), "INTERVENCIONISTA", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UI.SUBTLE)
	draw_string(font, Vector2(r.end.x - 90, r.end.y - 6), "MERCADO", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UI.SUBTLE)
	draw_string(font, Vector2(r.position.x + 4, r.position.y + 12), "CONSERVADOR", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UI.SUBTLE)
	draw_string(font, Vector2(r.position.x + 4, r.end.y - 22), "PROGRESSISTA", HORIZONTAL_ALIGNMENT_LEFT, -1, small, UI.SUBTLE)
	# Partidos reais primeiro; jogador por cima.
	var keys: Array = positions.keys()
	keys.sort_custom(func(a, b): return str(a) == player_key)
	for key in keys:
		var id := str(key)
		var pos: Vector2 = positions[key]
		var at := _point(pos)
		var color := UI.axis_color(clampf(pos.x / 100.0, -1.0, 1.0))
		if id == player_key:
			draw_circle(at, 10.0, Color(UI.AMBER.r, UI.AMBER.g, UI.AMBER.b, 0.22))
			draw_arc(at, 8.0, 0, TAU, 24, UI.AMBER, 2.0)
			draw_circle(at, 4.0, UI.AMBER)
		else:
			draw_circle(at, 4.0, color)
			if id == _hovered:
				draw_arc(at, 8.0, 0, TAU, 20, UI.TEXT, 1.2)
		if id == player_key or id == _hovered:
			draw_string(font, at + Vector2(8, -8), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.AMBER if id == player_key else UI.TEXT)
	if positions.is_empty():
		draw_string(font, r.position + Vector2(12, r.size.y / 2.0), "Posições indisponíveis", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
