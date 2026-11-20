extends Control
## Glifos vetoriais da navegação (grupos), das pílulas do topo e do pé do trilho.
## Tudo desenhado em _draw(), como flag_painter.gd e globe_view.gd: nenhum asset novo.
##
## O nó é sempre filho de um Button real e por isso tem mouse_filter IGNORE e
## focus_mode NONE: o foco, o clique e o anel de foco continuam no Button.
##
## Uso: NavIcon.new("economy", UI.MUTED, 18)

const KINDS := ["country", "power", "economy", "world", "registry", "news", "save", "menu"]

var kind: String = "country":
	set(value):
		kind = value
		queue_redraw()
var color: Color = Color("A0A2A6"):
	set(value):
		color = value
		queue_redraw()

func _init(icon_kind := "country", icon_color := Color("A0A2A6"), icon_size := 18) -> void:
	kind = icon_kind
	color = icon_color
	custom_minimum_size = Vector2(icon_size, icon_size)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var half := minf(size.x, size.y) * 0.5
	if half <= 1.0:
		return
	var c := size * 0.5
	var width := maxf(1.2, half * 0.16)
	match kind:
		"country":
			# Bandeira/país: quadro com uma faixa interna.
			var box := half - 2.0
			draw_rect(Rect2(c - Vector2(box, box * 0.72), Vector2(box * 2.0, box * 1.44)), color, false, width, true)
			draw_line(c + Vector2(-box, -box * 0.12), c + Vector2(box, -box * 0.12), color, width, true)
		"power":
			# Poder: frontão + três colunas.
			draw_line(c + Vector2(-half + 2.0, -half + 2.0), c + Vector2(half - 2.0, -half + 2.0), color, width, true)
			draw_line(c + Vector2(-half + 2.0, half - 2.5), c + Vector2(half - 2.0, half - 2.5), color, width, true)
			for i in 3:
				var x: float = c.x + (float(i) - 1.0) * half * 0.55
				draw_line(Vector2(x, c.y - half + 4.0), Vector2(x, c.y + half - 4.0), color, width, true)
		"economy":
			# Economia: três barras crescentes.
			for i in 3:
				var height: float = (half - 2.5) * (0.7 + 0.45 * float(i))
				var x: float = c.x + (float(i) - 1.0) * half * 0.55
				draw_line(Vector2(x, c.y + half - 2.5), Vector2(x, c.y + half - 2.5 - height), color, width * 2.0, true)
		"world":
			# Mundo: globo com meridiano e equador.
			var radius := half - 2.0
			draw_arc(c, radius, 0.0, TAU, 32, color, width, true)
			draw_line(c + Vector2(-radius, 0.0), c + Vector2(radius, 0.0), color, width, true)
			draw_arc(c, radius * 0.5, -PI * 0.5, PI * 0.5, 16, color, width, true)
			draw_arc(c, radius * 0.5, PI * 0.5, PI * 1.5, 16, color, width, true)
		"registry":
			# Registro: documento com linhas.
			for i in 3:
				var y: float = c.y + (float(i) - 1.0) * half * 0.5
				var reach: float = half - 2.0 if i < 2 else (half - 2.0) * 0.55
				draw_line(Vector2(c.x - half + 2.0, y), Vector2(c.x - half + 2.0 + reach * 2.0, y), color, width, true)
		"news":
			# Notícias: marcador + linha em três manchetes.
			for i in 3:
				var y: float = c.y + (float(i) - 1.0) * half * 0.5
				draw_circle(Vector2(c.x - half + 2.5, y), width * 0.9, color)
				draw_line(Vector2(c.x - half + 6.0, y), Vector2(c.x + half - 2.0, y), color, width, true)
		"save":
			# Salvar: seta para dentro da bandeja.
			draw_line(c + Vector2(0.0, -half + 2.0), c + Vector2(0.0, half * 0.15), color, width, true)
			draw_line(c + Vector2(0.0, half * 0.15), c + Vector2(-half * 0.5, -half * 0.35), color, width, true)
			draw_line(c + Vector2(0.0, half * 0.15), c + Vector2(half * 0.5, -half * 0.35), color, width, true)
			draw_line(c + Vector2(-half + 2.5, half - 3.0), c + Vector2(half - 2.5, half - 3.0), color, width, true)
		_:
			# Menu: três linhas.
			for i in 3:
				var y: float = c.y + (float(i) - 1.0) * half * 0.5
				draw_line(Vector2(c.x - half + 2.0, y), Vector2(c.x + half - 2.0, y), color, width, true)
