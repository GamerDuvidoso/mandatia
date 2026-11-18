extends RefCounted
## Tokens e construtores visuais únicos do MANDATO.
##
## Toda cor, raio, espaçamento e estilo de componente sai daqui. As telas
## chamam estes helpers em vez de recriar StyleBoxFlat/Label/Button cada uma.

const BG := Color("08111f")
const PANEL := Color("101d2e")
const PANEL_2 := Color("14263a")
const PANEL_3 := Color("0b1727")
const LINE := Color("29415a")
const TEXT := Color("e7edf5")
const MUTED := Color("8ea4ba")
const AMBER := Color("e8b45b")
const CYAN := Color("62c7c9")
const RED := Color("e97878")
const GREEN := Color("75c88b")

const RADIUS := 8
const RADIUS_SMALL := 5
const PAD_X := 14
const PAD_Y := 12
const GAP := 12

const SIDEBAR_WIDE := 210
const SIDEBAR_NARROW := 168
const RAIL_WIDTH := 290
const RAIL_BREAKPOINT := 1180
const PAD_BREAKPOINT := 1000
const SIDEBAR_BREAKPOINT := 1100

static func panel_style(bg: Color, border: Color, radius := RADIUS, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = PAD_X
	s.content_margin_right = PAD_X
	s.content_margin_top = PAD_Y
	s.content_margin_bottom = PAD_Y
	return s

static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return l

static func button(text: String, color: Color, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", panel_style(PANEL_2 if primary else PANEL_3, LINE, RADIUS_SMALL))
	b.add_theme_stylebox_override("hover", panel_style(Color("1d3850"), color, RADIUS_SMALL))
	return b

static func line(value: String) -> LineEdit:
	var l := LineEdit.new()
	l.text = value
	l.custom_minimum_size = Vector2(310, 42)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_stylebox_override("normal", panel_style(PANEL_3, LINE, 4))
	return l

## Cor de um partido pelo eixo ideológico (-1 esquerda .. +1 direita).
static func axis_color(axis: float) -> Color:
	if axis < -0.15:
		return RED
	if axis > 0.15:
		return CYAN
	return AMBER

static func panel(bg := PANEL, border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p

static func metric_card(caption: String, value: String, color: Color) -> PanelContainer:
	var p := panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_child(label(caption, 11, MUTED))
	col.add_child(label(value, 23, color))
	p.add_child(col)
	return p
