extends RefCounted
## Tokens e construtores visuais únicos do MANDATO.
##
## Toda cor, raio, espaçamento e estilo de componente sai daqui. As telas
## chamam estes helpers em vez de recriar StyleBoxFlat/Label/Button cada uma.

## Tokens de cor — paleta grafite institucional + âmbar (revisão 2, seção B.1).
## Cores do eixo político (AXIS_*) são exclusivas de assento de hemiciclo, chip de sigla
## e marcador de eixo. Nunca aparecem em botão, cabeçalho, borda de painel ou série de gráfico.
const BG := Color("090A0C")           # Fundo global, espaço do globo, área sem conteúdo
const SURFACE := Color("17191C")      # Faixas de navegação, painéis padrão
const SURFACE_RAISED := Color("202226") # Cards, blocos elevados, cabeçalho de seção
const SURFACE_HOVER := Color("292C31")  # Hover, item ativo discreto
const LINE := Color("34373D")         # Bordas, separadores, grade de gráfico
const TEXT := Color("E7E7E7")         # Texto principal
const MUTED := Color("A0A2A6")        # Texto secundário, legendas
const SUBTLE := Color("70747A")       # Metadados, unidades, itens inativos
const AMBER := Color("DDAA4D")        # Ação primária, seleção, destaque institucional
const GREEN := Color("79B88A")        # Estado positivo (crescimento, aprovação saudável)
const RED := Color("D87575")          # Estado crítico (risco, déficit, reprovação)
const AXIS_LEFT := Color("E97878")    # Exclusivo: eixo ideológico à esquerda
const AXIS_CENTER := Color("E8B45B")  # Exclusivo: eixo ideológico de centro
const AXIS_RIGHT := Color("5FA9AC")   # Exclusivo: eixo ideológico à direita (CYAN dessaturado)
const GLOBE_LAND := Color("2A3038")   # Massa continental do globo (tom, não cor)
const GLOBE_OCEAN := Color("0C1216")  # Oceano/base do globo

## Cores de transição mantidas para compatibilidade com telas ainda não migradas.
## Deprecated: usar SURFACE/SURFACE_RAISED/LINE/TEXT/AMBER/RED/GREEN/AXIS_* acima.
const PANEL := Color("101d2e")
const PANEL_2 := Color("14263a")
const PANEL_3 := Color("0b1727")
const CYAN := Color("62c7c9")          # Apenas para transição; não novo uso

## Tokens de espaçamento (item 9) — escala declarada, aplicada em todos os componentes.
const RADIUS := 8
const RADIUS_SMALL := 5
const RADIUS_LARGE := 12
const PAD_X := 14
const PAD_Y := 12
const PAD_SMALL := 8
const PAD_LARGE := 20
const GAP := 12
const GAP_SMALL := 6
const GAP_LARGE := 24

## Margens padrão da área de conteúdo (1280 lógicos: 1280 − 64 − 120 − 2*16 = 1064 útil)
const MARGIN_SIDE := 16
const MARGIN_TOP := 16
const MARGIN_BOTTOM := 16

## Larguras de faixa (seção B.5 / B.6)
const NAV_MAIN_HEIGHT := 64
const NAV_CONTEXT_WIDTH := 132
const HEADER_HEIGHT := 48
const FOOTER_HEIGHT := 32

## Classes de largura de painel (seção B.9 / matriz D.4)
const PANEL_NARROW_MIN := 280
const PANEL_NARROW_MAX := 320
const PANEL_MEDIUM_MIN := 380
const PANEL_MEDIUM_MAX := 520
const PANEL_WIDE_MIN := 540
const PANEL_WIDE_MAX := 760
const PANEL_FULL_MIN := 800
const PANEL_FULL_MAX := 1064

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
	# Frases longas quebram em vez de forçar a largura mínima da coluna e
	# empurrar o rail/faixas para fora da janela de 1280.
	if text.length() > 70:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, color: Color, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_pressed_color", AMBER)
	b.add_theme_stylebox_override("normal", panel_style(SURFACE_RAISED if primary else SURFACE, LINE, RADIUS_SMALL))
	b.add_theme_stylebox_override("hover", panel_style(SURFACE_HOVER, AMBER, RADIUS_SMALL))
	b.add_theme_stylebox_override("pressed", panel_style(SURFACE_HOVER, AMBER, RADIUS_SMALL))
	var focus := panel_style(Color.TRANSPARENT, AMBER, RADIUS_SMALL + 2)
	focus.set_expand_margin_all(2.0)
	b.add_theme_stylebox_override("focus", focus)
	return b

static func line(value: String) -> LineEdit:
	var l := LineEdit.new()
	l.text = value
	l.custom_minimum_size = Vector2(310, 42)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_stylebox_override("normal", panel_style(SURFACE, LINE, RADIUS_SMALL))
	l.add_theme_stylebox_override("focus", panel_style(SURFACE_RAISED, AMBER, RADIUS_SMALL))
	return l

## Cor de um partido pelo eixo ideológico (-1 esquerda .. +1 direita).
## Retorna AXIS_LEFT/AXIS_CENTER/AXIS_RIGHT — cores exclusivas do eixo político.
static func axis_color(axis: float) -> Color:
	if axis < -0.15:
		return AXIS_LEFT
	if axis > 0.15:
		return AXIS_RIGHT
	return AXIS_CENTER

static func panel(bg := SURFACE, border := LINE) -> PanelContainer:
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
