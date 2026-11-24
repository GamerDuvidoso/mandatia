extends Control

signal region_clicked(index: int)

const THEME := preload("res://scripts/ui/mandato_theme.gd")

const BG := THEME.SURFACE
const LINE := THEME.LINE
const TEXT := THEME.TEXT
const MUTED := THEME.MUTED
const AMBER := THEME.AMBER
const CYAN := THEME.SUBTLE
const GREEN := THEME.GREEN

var data: Dictionary = {}
var regions: Array = []
var mode := "dashboard"
var selected := -1
var chart_mode := false
var hemicycle_seats: Dictionary = {}
var hemicycle_axes: Dictionary = {}
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func set_data(new_data: Dictionary, new_regions: Array) -> void:
	data = new_data; regions = new_regions; mode = "dashboard"; chart_mode = false; queue_redraw()

func set_map(new_data: Dictionary, new_regions: Array) -> void:
	data = new_data; regions = new_regions; mode = "map"; chart_mode = false; queue_redraw()

func set_chart(new_data: Dictionary) -> void:
	data = new_data; mode = "chart"; chart_mode = true; queue_redraw()

func set_economy(new_data: Dictionary) -> void:
	data = new_data; mode = "economy"; chart_mode = true; queue_redraw()

func set_hemicycle(seat_map: Dictionary, axes: Dictionary, majority: int, chamber_seats := 0, coalition_seats := 0) -> void:
	hemicycle_seats = seat_map
	hemicycle_axes = axes
	data = {"majority": majority, "chamber_seats": chamber_seats, "coalition_seats": coalition_seats}
	mode = "hemicycle"
	chart_mode = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if mode != "map" or not (event is InputEventMouseButton) or not event.pressed: return
	var pos: Vector2 = event.position
	var rect := Rect2(Vector2(22, 68), Vector2(max(140.0, size.x - 44.0), max(200.0, size.y - 92.0)))
	var cols := 4
	var cell := Vector2(rect.size.x / cols - 8, rect.size.y / 2.0 - 8)
	for i in 8:
		var x := i % cols
		var y := i / cols
		var r := Rect2(rect.position + Vector2(x * (cell.x + 8), y * (cell.y + 16)), cell)
		if r.has_point(pos): selected = i; region_clicked.emit(i); queue_redraw(); return

func _draw() -> void:
	draw_style_box(_panel_style(BG, LINE), Rect2(Vector2.ZERO, size))
	if mode == "map": _draw_map()
	elif mode == "chart": _draw_chart()
	elif mode == "economy": _draw_economy()
	elif mode == "hemicycle": _draw_hemicycle()
	else: _draw_dashboard()

func _draw_dashboard() -> void:
	var w := size.x
	var h := size.y
	draw_string(font, Vector2(20, 27), "SINAL POLÍTICO  /  APOIO REGIONAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(font, Vector2(20, 53), "Apoio atual por região", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, TEXT)
	var vals: Array = data.get("region_support", [33, 27, 41, 29, 36, 31, 25, 22])
	var wide := w >= 470.0
	var left := 20.0
	var top := 78.0
	var label_w := 104.0
	var bar_x := left + label_w
	var bars_span := w * 0.56 if wide else w - 40.0
	var bar_w := maxf(70.0, bars_span - label_w - 44.0)
	var row_h := clampf((h - 110.0) / maxf(1.0, float(vals.size())), 20.0, 34.0)
	for i in vals.size():
		var y := top + i * row_h
		var label: String = regions[i].name if i < regions.size() else "Região %d" % (i + 1)
		draw_string(font, Vector2(left, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, label_w - 4, 11, MUTED)
		draw_rect(Rect2(bar_x, y + 2, bar_w, 12), Color("292C31"))
		var value := float(vals[i])
		draw_rect(Rect2(bar_x, y + 2, maxf(2.0, bar_w * value / 80.0), 12), GREEN if value > 30 else AMBER)
		draw_string(font, Vector2(bar_x + bar_w + 6, y + 12), "%.0f%%" % value, HORIZONTAL_ALIGNMENT_LEFT, 40, 11, TEXT)
	if not wide:
		return
	var x0 := left + w * 0.56 + 34.0
	var panel_w := maxf(110.0, w - x0 - 20.0)
	draw_string(font, Vector2(x0, 78), "TRAJETÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AMBER)
	draw_string(font, Vector2(x0, 98), "Crescimento · série real", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	var line_rect := Rect2(x0, 110, panel_w, maxf(80.0, h - 224.0))
	for i in 5:
		var gy := line_rect.position.y + i * line_rect.size.y / 4.0
		draw_line(Vector2(line_rect.position.x, gy), Vector2(line_rect.end.x, gy), Color(LINE, 0.45), 1)
	var history: Array = data.get("economy_history", [])
	var values: Array = []
	for entry in history:
		values.append(float((entry as Dictionary).get("economy", 0.0)) if entry is Dictionary else 0.0)
	if values.is_empty():
		values.append(float(data.get("economy", 2.4)))
	var high: float = maxf(0.5, values.max())
	var low: float = minf(-0.5, values.min())
	var span := maxf(0.4, high - low)
	if low < 0.0 and high > 0.0:
		var zero_y := line_rect.end.y - (0.0 - low) / span * line_rect.size.y
		draw_line(Vector2(line_rect.position.x, zero_y), Vector2(line_rect.end.x, zero_y), Color(LINE, 0.9), 1)
	var points := PackedVector2Array()
	var last_index := maxf(1.0, float(values.size() - 1))
	for i in values.size():
		var px := line_rect.position.x + float(i) / last_index * line_rect.size.x
		var py := line_rect.end.y - (float(values[i]) - low) / span * line_rect.size.y
		points.append(Vector2(px, py))
	if points.size() > 1:
		draw_polyline(points, AMBER, 3, true)
	var current := float(values[values.size() - 1])
	var total_delta := current - float(values[0])
	draw_circle(points[-1], 4, AMBER)
	draw_string(font, Vector2(x0, line_rect.end.y + 32), "%+.1f%%" % current, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, GREEN if current >= 2.0 else (AMBER if current >= 0.0 else Color("e97878")))
	draw_string(font, Vector2(x0, line_rect.end.y + 52), "%+.1f p.p. no mandato  ·  %d meses" % [total_delta, maxi(1, history.size())], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

func _draw_map() -> void:
	draw_string(font, Vector2(22, 28), "MAPA POLÍTICO 2D", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)
	draw_string(font, Vector2(22, 52), "Selecione uma região", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEXT)
	var rect := Rect2(Vector2(22, 68), Vector2(max(140.0, size.x - 44.0), max(200.0, size.y - 92.0)))
	var cols := 4
	var cell := Vector2(rect.size.x / cols - 8, rect.size.y / 2.0 - 8)
	for i in 8:
		var x := i % cols; var y := i / cols
		var r := Rect2(rect.position + Vector2(x * (cell.x + 8), y * (cell.y + 16)), cell)
		var support := float(data.get("region_support", [33,27,41,29,36,31,25,22])[i])
		var col := Color("202226").lerp(Color("2E3A33"), support / 80.0)
		if i == selected: col = Color("3A3018")
		draw_style_box(_panel_style(col, AMBER if i == selected else LINE), r)
		draw_string(font, r.position + Vector2(10, 24), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1,1,1,0.55))
		draw_multiline_string(font, r.position + Vector2(10, 42), regions[i].name if i < regions.size() else "Região", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 12, 2, TEXT)
		draw_string(font, r.position + Vector2(10, 84), "%.0f%% apoio" % support, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER if i == selected else Color.WHITE)
		draw_string(font, r.position + Vector2(10, r.size.y - 12), regions[i].kind if i < regions.size() else "", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14, 9, Color(1,1,1,0.55))

func _draw_economy() -> void:
	draw_string(font, Vector2(20, 28), "INDICADORES ECONÔMICOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	draw_string(font, Vector2(20, 54), "Série mensal registrada", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, TEXT)
	var history: Array = data.get("economy_history", [])
	if history.size() < 2:
		draw_string(font, Vector2(20, 96), "Avance um mês para começar a série", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		return
	var series := [
		["Crescimento", "economy", GREEN],
		["Inflação", "inflation", Color("e97878")],
		["Desemprego", "unemployment", AMBER],
	]
	var panel_w := maxf(120.0, (size.x - 72.0) / 3.0)
	for i in series.size():
		var x := 24.0 + i * (panel_w + 12.0)
		var key := str(series[i][1])
		var color: Color = series[i][2]
		var values := []
		for entry in history:
			values.append(float(entry.get(key, 0.0)))
		var low: float = values[0]
		var high: float = values[0]
		for value in values:
			low = minf(low, value)
			high = maxf(high, value)
		var span := maxf(0.2, high - low)
		draw_string(font, Vector2(x, 92), str(series[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		draw_string(font, Vector2(x, 122), "%.1f%%" % values[values.size() - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
		var delta: float = values[values.size() - 1] - values[0]
		var month_delta: float = values[values.size() - 1] - values[values.size() - 2] if values.size() >= 2 else 0.0
		draw_string(font, Vector2(x, 142), "%+.1f p.p. no mandato  ·  %+.1f no mês" % [delta, month_delta], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		var rect := Rect2(x, 156, panel_w, maxf(60.0, size.y - 202.0))
		for g in 3:
			var gy := rect.position.y + g * rect.size.y / 2.0
			draw_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy), Color(LINE, 0.45), 1)
		var points := PackedVector2Array()
		var last_index := maxf(1.0, float(values.size() - 1))
		for j in values.size():
			var px := rect.position.x + float(j) / last_index * rect.size.x
			var py := rect.end.y - (float(values[j]) - low) / span * rect.size.y
			points.append(Vector2(px, py))
		draw_polyline(points, color, 2, true)
		draw_circle(points[points.size() - 1], 3.5, color)
		draw_string(font, Vector2(x, rect.end.y + 16), "mín %.1f  ·  máx %.1f" % [low, high], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)

func _draw_chart() -> void:
	draw_string(font, Vector2(20, 28), "INDICADORES ECONÔMICOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	draw_string(font, Vector2(20, 54), "Efeito acumulado das suas decisões", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, TEXT)
	var rect := Rect2(Vector2(30, 82), Vector2(max(220.0, size.x - 60), max(140.0, size.y - 128)))
	for i in 5:
		var y := rect.position.y + i * rect.size.y / 4.0
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(LINE, 0.65), 1)
	var econ := float(data.get("economy", 2.4)); var infl := float(data.get("inflation", 4.8)); var unem := float(data.get("unemployment", 8.2))
	var series := [[econ, GREEN, "crescimento"], [infl, Color("e97878"), "inflação"], [unem, AMBER, "desemprego"]]
	for s in series.size():
		var points := PackedVector2Array()
		for i in 10:
			var base := float(series[s][0]); var v := base + sin(i * 0.55 + s) * base * 0.08 - float(9 - i) * 0.02
			points.append(Vector2(rect.position.x + i * rect.size.x / 9.0, rect.end.y - v / 15.0 * rect.size.y))
		if points.size() > 1: draw_polyline(points, series[s][1], 3, true)
		draw_circle(points[-1], 4, series[s][1])
		draw_string(font, Vector2(rect.position.x + 10 + s * 125, rect.end.y + 30), str(series[s][2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, series[s][1])

func _draw_hemicycle() -> void:
	var total := 0
	for value in hemicycle_seats.values():
		total += int(value)
	var majority := int(data.get("majority", 0))
	var chamber_seats := int(data.get("chamber_seats", 0))
	var caption := "%d cadeiras" % total
	if chamber_seats > 0 and chamber_seats != total:
		caption = "%d cadeiras registradas  ·  câmara %d" % [total, chamber_seats]
	draw_string(font, Vector2(20, 28), "COMPOSIÇÃO DA CÂMARA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	draw_string(font, Vector2(20, 54), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, TEXT)
	draw_string(font, Vector2(20, 74), "Maioria absoluta: %d  ·  Coalizão: %d" % [majority, int(data.get("coalition_seats", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	if total <= 0:
		draw_string(font, Vector2(20, 88), "Sem bancada registrada", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		return
	var ordered := []
	for key in hemicycle_seats.keys():
		var seats := int(hemicycle_seats[key])
		if seats <= 0:
			continue
		ordered.append([str(key), float(hemicycle_axes.get(key, 0.0)), seats])
	ordered.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	var seat_colors := []
	for item in ordered:
		var col := _axis_color(float(item[1]))
		for _i in int(item[2]):
			seat_colors.append(col)
	var rows := 5
	var weights := 0.0
	for r in rows:
		weights += float(r + 1)
	var counts := []
	var assigned := 0
	for r in rows - 1:
		var row_seats := int(round(float(total) * float(r + 1) / weights))
		counts.append(row_seats)
		assigned += row_seats
	counts.append(total - assigned)
	var center := Vector2(size.x * 0.5, size.y - 74.0)
	var max_radius := minf(size.x * 0.46, size.y - 132.0)
	var dot := clampf(PI * max_radius * 0.6 / float(total) * 0.42, 1.4, 4.5)
	var index := 0
	for r in rows:
		var count := int(counts[r])
		if count <= 0:
			continue
		var radius := max_radius * (float(r + 1) / float(rows))
		for i in count:
			if index >= seat_colors.size():
				break
			var angle := PI + (float(i) + 0.5) / float(count) * PI
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			draw_circle(pos, dot, seat_colors[index])
			index += 1
	# Marca da maioria absoluta: tick no topo do hemiciclo.
	if majority > 0 and total > 0 and majority <= total:
		var maj_angle := PI + (float(majority) - 0.5) / float(total) * PI
		var maj_inner := center + Vector2(cos(maj_angle), sin(maj_angle)) * (max_radius + 8.0)
		var maj_outer := center + Vector2(cos(maj_angle), sin(maj_angle)) * (max_radius + 20.0)
		draw_line(maj_inner, maj_outer, AMBER, 2.0, true)
		draw_string(font, maj_outer + Vector2(-14.0, -4.0), "maioria", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AMBER)
	var legend_items := ordered.duplicate()
	legend_items.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	legend_items = legend_items.slice(0, 6)
	var legend_x := 20.0
	var legend_y := size.y - 18.0
	for item in legend_items:
		var text := "%s %d" % [str(item[0]), int(item[2])]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		if legend_x + 14.0 + text_size.x > size.x - 16.0:
			break
		draw_rect(Rect2(legend_x, legend_y - 9.0, 8.0, 8.0), _axis_color(float(item[1])))
		draw_string(font, Vector2(legend_x + 13.0, legend_y - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		legend_x += 14.0 + text_size.x + 14.0

func _axis_color(axis: float) -> Color:
	return THEME.axis_color(axis)

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(8); return s
