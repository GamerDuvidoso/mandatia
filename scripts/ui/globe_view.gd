extends Control
## Globo cenário — Nível A (sem asset): disco + massas continentais procedurais +
## graticula + terminador + marcador. Nenhuma dependência de aurora-map.png.
##
## Dois modos de uso:
## - card (padrão): disco centrado no próprio rect, usado quando o globo é conteúdo.
## - camada de fundo (`background = true`): disco maior, deslocado ~8% para a direita,
##   desenhado atrás do conteúdo da tela (ver `SHOW_GLOBE` em `scripts/main.gd`).
##
## country_region: índice da macro-região do país (0..3). Usado apenas para posicionar
## o marcador — constante de posicionamento visual, não dado geográfico simulado.
## As massas continentais são abstratas e determinísticas por região: não representam
## fronteiras nem territórios reais.

signal region_selected(region_id: int)

const GRATICULA_OPACITY := 0.30
const LAND_OPACITY := 0.85
const MARKER_RADIUS := 8.0
const MARKER_RING := 12.0
## Raio do disco que corresponde ao tamanho 1.0 do marcador.
const MARKER_BASE_RADIUS := 160.0

## Cores do tema (via ScreenFactory para manter uma única fonte de tokens).
const _THEME := preload("res://scripts/ui/screen_factory.gd")

var country_region: int = 0:
	set(value):
		country_region = clampi(value, 0, 3)
		queue_redraw()
var show_graticula: bool = true
var show_terminator: bool = true
var show_marker: bool = true
var background: bool = false:
	set(value):
		background = value
		# Cenário nunca captura ponteiro: só conteúdo (pílulas, painéis) é clicável.
		mouse_filter = Control.MOUSE_FILTER_IGNORE if background else Control.MOUSE_FILTER_STOP
		queue_redraw()
var opacity: float = 1.0:
	set(value):
		opacity = clampf(value, 0.0, 1.0)
		modulate.a = opacity
		visible = opacity > 0.001

func _ready() -> void:
	# O globo é estático (sem rotação nem animação): só redesenha quando o rect muda.
	resized.connect(queue_redraw)
	if background:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rect: Rect2 = get_rect()
	var center: Vector2
	var radius: float
	if background:
		radius = minf(rect.size.y * 0.50, rect.size.x * 0.30)
		center = Vector2(rect.size.x * 0.68, rect.size.y * 0.50)
	else:
		center = rect.size / 2.0
		radius = minf(rect.size.x, rect.size.y) * 0.46
	if radius <= 1.0:
		return

	# Limbo: anel sutil que separa o globo do fundo
	draw_circle(center, radius + 1.5, Color(_THEME.LINE.r, _THEME.LINE.g, _THEME.LINE.b, 0.55))
	# Disco oceano
	draw_circle(center, radius, _THEME.GLOBE_OCEAN)
	# Massas continentais (tom, sem fronteiras)
	_draw_land(center, radius)

	if show_graticula:
		_draw_graticula(center, radius)

	if show_terminator:
		_draw_terminator(center, radius)

	if show_marker:
		_draw_country_marker(center, radius)

## Blobs tonais determinísticos semeados pela macro-região: manchas de "continente"
## que dão leitura de esfera sem alegar geografia. Clipadas no disco pelo limbo.
func _draw_land(center: Vector2, radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1187 + country_region * 131
	var land := Color(_THEME.GLOBE_LAND.r, _THEME.GLOBE_LAND.g, _THEME.GLOBE_LAND.b, LAND_OPACITY)
	for i in 6:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(0.10, 0.52) * radius
		var blob_center := center + Vector2(cos(angle), sin(angle)) * distance
		var base := rng.randf_range(0.16, 0.34) * radius
		var phase := rng.randf_range(0.0, TAU)
		var points := PackedVector2Array()
		var steps := 18
		for s in steps:
			var t := float(s) / float(steps) * TAU
			var wobble := 1.0 + 0.28 * sin(t * 3.0 + phase) + 0.16 * sin(t * 5.0 - phase * 0.7)
			var point := blob_center + Vector2(cos(t), sin(t) * 0.78) * base * wobble
			var offset := point - center
			if offset.length() > radius * 0.97:
				point = center + offset.normalized() * radius * 0.97
			points.append(point)
		draw_colored_polygon(points, land)

func _draw_graticula(center: Vector2, radius: float) -> void:
	var color := Color(_THEME.MUTED.r, _THEME.MUTED.g, _THEME.MUTED.b, GRATICULA_OPACITY)
	var width := maxf(1.0, radius / 240.0)

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
				width,
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
		draw_polyline(points, color, width, true)

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
	# No cenário o disco é cortado pela coluna de conteúdo à esquerda: comprimir o
	# deslocamento horizontal mantém o marcador na faixa descoberta (Visão geral em
	# 1280: x 799..990), preservando a distinção entre macro-regiões pelo eixo vertical.
	if background:
		pos.x *= 0.35
	var marker_pos: Vector2 = center + pos * radius
	var marker_scale := clampf(radius / MARKER_BASE_RADIUS, 0.7, 3.2)
	var dot := MARKER_RADIUS * marker_scale
	var ring := MARKER_RING * marker_scale
	# No cenário o marcador é detalhe do globo: mesma forma, menos brilho, para não
	# parecer um controle da interface quando cai num vão entre painéis.
	var strength := 0.55 if background else 1.0
	var ring_color := Color(_THEME.AMBER.r, _THEME.AMBER.g, _THEME.AMBER.b, strength)

	# Halo suave, anel neutro e ponto central (cor não comunica eixo político)
	draw_circle(marker_pos, ring + 5.0 * marker_scale, Color(_THEME.AMBER.r, _THEME.AMBER.g, _THEME.AMBER.b, 0.09 * strength))
	draw_arc(marker_pos, ring, 0.0, TAU, 48, ring_color, maxf(1.5, 1.5 * marker_scale), true)
	draw_circle(marker_pos, dot * 0.45, Color(_THEME.TEXT.r, _THEME.TEXT.g, _THEME.TEXT.b, strength))

func _gui_input(event: InputEvent) -> void:
	if background:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		region_selected.emit(country_region)
