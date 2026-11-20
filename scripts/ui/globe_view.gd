extends Control
## Globo cenário — Nível A (sem asset): disco + graticula + terminador + marcador.
## Nenhuma dependência de aurora-map.png. Se a textura faltar, desenha apenas disco procedural.
##
## country_region: índice da macro-região do país (0..3). Usado apenas para posicionar
## o marcador — constante de posicionamento visual, não dado geográfico simulado.

signal region_selected(region_id: int)

const GRATICULA_OPACITY := 0.30
const MARKER_RADIUS := 8.0
const MARKER_RING := 12.0

## Cores do tema (via ScreenFactory para manter uma única fonte de tokens).
const _THEME := preload("res://scripts/ui/screen_factory.gd")

var country_region: int = 0:
	set(value):
		country_region = clampi(value, 0, 3)
		queue_redraw()
var show_graticula: bool = true
var show_terminator: bool = true

func _draw() -> void:
	var rect: Rect2 = get_rect()
	var center: Vector2 = rect.size / 2.0
	var radius: float = minf(rect.size.x, rect.size.y) * 0.46
	if radius <= 1.0:
		return

	# Limbo: anel sutil que separa o globo do fundo
	draw_circle(center, radius + 1.5, Color(_THEME.LINE.r, _THEME.LINE.g, _THEME.LINE.b, 0.55))
	# Disco oceano
	draw_circle(center, radius, _THEME.GLOBE_OCEAN)

	if show_graticula:
		_draw_graticula(center, radius)

	if show_terminator:
		_draw_terminator(center, radius)

	_draw_country_marker(center, radius)

func _draw_graticula(center: Vector2, radius: float) -> void:
	var color := Color(_THEME.MUTED.r, _THEME.MUTED.g, _THEME.MUTED.b, GRATICULA_OPACITY)

	# Paralelos (linhas horizontais achatadas pelo cos da latitude)
	for lat in range(-60, 61, 30):
		var lat_rad := deg_to_rad(lat)
		var y_offset := radius * sin(lat_rad)
		var half_width := radius * cos(lat_rad)
		if half_width > 1.0:
			draw_line(
				Vector2(center.x - half_width, center.y - y_offset),
				Vector2(center.x + half_width, center.y - y_offset),
				color,
				1.0,
				true,
			)

	# Meridianos: elipses verticais achatadas pelo cosseno da longitude
	for lon in range(0, 180, 30):
		var squash := absf(cos(deg_to_rad(lon)))
		if squash < 0.03:
			continue
		var points := PackedVector2Array()
		for i in 49:
			var t := float(i) / 48.0
			var angle := lerpf(-PI / 2.0, PI / 2.0, t)
			points.append(center + Vector2(cos(angle) * radius * squash, sin(angle) * radius))
		draw_polyline(points, color, 1.0, true)

func _draw_terminator(center: Vector2, radius: float) -> void:
	# Crescente de sombra no lado direito, inteiramente contido no disco.
	var points := PackedVector2Array()
	for i in 33:
		var a := lerpf(-PI / 2.0, PI / 2.0, float(i) / 32.0)
		points.append(center + Vector2(cos(a) * radius, sin(a) * radius))
	for i in 33:
		var a := lerpf(PI / 2.0, -PI / 2.0, float(i) / 32.0)
		points.append(center + Vector2(cos(a) * radius * 0.62, sin(a) * radius))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.38))

func _draw_country_marker(center: Vector2, radius: float) -> void:
	# Posições fixas por macro-região — posicionamento visual, não dado simulado.
	var positions := [
		Vector2(0.28, -0.22),  # Região 0
		Vector2(-0.30, 0.12),  # Região 1
		Vector2(0.10, 0.30),   # Região 2
		Vector2(-0.22, -0.32), # Região 3
	]
	var pos: Vector2 = positions[country_region]
	var marker_pos: Vector2 = center + pos * radius

	# Halo suave, anel neutro e ponto central (cor não comunica eixo político)
	draw_circle(marker_pos, MARKER_RING + 5.0, Color(_THEME.AMBER.r, _THEME.AMBER.g, _THEME.AMBER.b, 0.12))
	draw_arc(marker_pos, MARKER_RING, 0.0, TAU, 48, _THEME.AMBER, 1.5, true)
	draw_circle(marker_pos, MARKER_RADIUS * 0.45, _THEME.TEXT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		region_selected.emit(country_region)
