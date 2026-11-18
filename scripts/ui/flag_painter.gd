extends Control
## Bandeira estilizada desenhada por primitivas, sem imagens.
##
## As faixas e cores seguem as bandeiras oficiais dos países do catálogo;
## brasões, estrelas e folhas aparecem como formas simples. É identificação
## visual rápida, não reprodução heráldica.

var country_id := "BR":
	set(value):
		country_id = value
		queue_redraw()

const FLAGS := {
	"AR": {"bands": [["74acdf", 1], ["ffffff", 1], ["74acdf", 1]]},
	"BO": {"bands": [["d52b1e", 1], ["f9e300", 1], ["007934", 1]]},
	"BR": {"field": "009c3b", "shapes": [
		{"shape": "diamond", "color": "ffd700"},
		{"shape": "circle", "color": "002776"},
	]},
	"CL": {"field": "ffffff", "shapes": [
		{"shape": "rect_bottom", "color": "d52b1e", "fraction": 0.5},
		{"shape": "canton", "color": "0039a6"},
	]},
	"CO": {"bands": [["fcd116", 2], ["003893", 1], ["ce1126", 1]]},
	"CR": {"bands": [["002b7f", 1], ["ffffff", 1], ["ce1126", 2], ["ffffff", 1], ["002b7f", 1]]},
	"CU": {"bands": [["002a8f", 1], ["ffffff", 1], ["002a8f", 1], ["ffffff", 1], ["002a8f", 1]], "shapes": [
		{"shape": "triangle_left", "color": "cf142b"},
	]},
	"EC": {"bands": [["ffd100", 2], ["034ea2", 1], ["ed1c24", 1]]},
	"SV": {"bands": [["0f47af", 1], ["ffffff", 1], ["0f47af", 1]]},
	"GT": {"bands": [["4997d0", 1], ["ffffff", 1], ["4997d0", 1]], "vertical": true},
	"HT": {"bands": [["00209f", 1], ["d21034", 1]]},
	"HN": {"bands": [["0073cf", 1], ["ffffff", 1], ["0073cf", 1]]},
	"MX": {"bands": [["006847", 1], ["ffffff", 1], ["ce1126", 1]], "vertical": true},
	"NI": {"bands": [["0067c6", 1], ["ffffff", 1], ["0067c6", 1]]},
	"PA": {"shapes": [{"shape": "quarters", "colors": ["ffffff", "ce1126", "0038a8", "ffffff"]}]},
	"PY": {"bands": [["d52b1e", 1], ["ffffff", 1], ["0038a8", 1]]},
	"PE": {"bands": [["d91023", 1], ["ffffff", 1], ["d91023", 1]], "vertical": true},
	"DO": {"shapes": [
		{"shape": "quarters", "colors": ["002d62", "ce1126", "ce1126", "002d62"]},
		{"shape": "cross", "color": "ffffff"},
	]},
	"UY": {"bands": [["ffffff", 1], ["0038a8", 1], ["ffffff", 1], ["0038a8", 1], ["ffffff", 1], ["0038a8", 1], ["ffffff", 1], ["0038a8", 1], ["ffffff", 1]], "shapes": [
		{"shape": "canton", "color": "ffffff"},
	]},
	"VE": {"bands": [["ffd700", 1], ["00247d", 1], ["cf142b", 1]]},
	"BZ": {"bands": [["ce1126", 1], ["003f87", 3], ["ce1126", 1]], "shapes": [
		{"shape": "circle", "color": "ffffff"},
	]},
	"CA": {"bands": [["ff0000", 1], ["ffffff", 2], ["ff0000", 1]], "vertical": true},
	"US": {"bands": [["b22234", 1], ["ffffff", 1], ["b22234", 1], ["ffffff", 1], ["b22234", 1], ["ffffff", 1], ["b22234", 1], ["ffffff", 1], ["b22234", 1], ["ffffff", 1], ["b22234", 1], ["ffffff", 1], ["b22234", 1]], "shapes": [
		{"shape": "canton", "color": "3c3b6e"},
	]},
	"JM": {"field": "009b3a", "shapes": [{"shape": "saltire", "color": "fed100"}]},
	"TT": {"field": "da1a35", "shapes": [{"shape": "diag_band", "color": "000000"}]},
	"BB": {"bands": [["00267f", 1], ["ffc72c", 1], ["00267f", 1]], "vertical": true},
	"BS": {"bands": [["00778b", 1], ["ffc72c", 2], ["00778b", 1]], "shapes": [
		{"shape": "triangle_left", "color": "000000"},
	]},
	"GD": {"shapes": [
		{"shape": "quarters", "colors": ["007a5e", "fcd116", "fcd116", "007a5e"]},
		{"shape": "border", "color": "ce1126"},
	]},
	"DM": {"field": "006b3f", "shapes": [{"shape": "cross", "color": "fcd116"}]},
	"AG": {"field": "ce1126", "shapes": [
		{"shape": "triangle_left", "color": "000000"},
		{"shape": "rect_bottom", "color": "0072c6", "fraction": 0.22},
	]},
	"KN": {"bands": [["009e49", 1], ["ce1126", 1]], "vertical": true, "shapes": [
		{"shape": "diag_band", "color": "000000"},
	]},
	"LC": {"field": "66ccff", "shapes": [{"shape": "triangle_left", "color": "000000"}]},
	"VC": {"bands": [["002674", 1], ["007b5f", 1], ["fcd116", 1]], "vertical": true},
	"SR": {"bands": [["377e3f", 1], ["ffffff", 1], ["b40a2d", 2], ["ffffff", 1], ["377e3f", 1]], "shapes": [
		{"shape": "circle", "color": "ecc81d"},
	]},
	"GY": {"field": "009e49", "shapes": [
		{"shape": "triangle_left", "color": "fcd116"},
		{"shape": "triangle_small", "color": "ce1126"},
	]},
}

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	draw_rect(rect, Color("0f1b29"))
	var spec: Dictionary = FLAGS.get(country_id, {})
	if spec.is_empty():
		draw_rect(rect.grow(-1.0), Color("1d3850"))
		return
	var bands: Array = spec.get("bands", [])
	if bands.is_empty():
		draw_rect(rect, _color(spec.get("field", "333333")))
	else:
		var total := 0.0
		for band in bands:
			total += float(band[1])
		var offset := 0.0
		var vertical := bool(spec.get("vertical", false))
		for band in bands:
			var extent := float(band[1]) / total
			var band_rect := rect
			if vertical:
				band_rect.position.x = rect.position.x + rect.size.x * offset
				band_rect.size.x = rect.size.x * extent
			else:
				band_rect.position.y = rect.position.y + rect.size.y * offset
				band_rect.size.y = rect.size.y * extent
			draw_rect(band_rect, _color(band[0]))
			offset += extent
	for shape in spec.get("shapes", []):
		_draw_shape(shape, rect)

func _draw_shape(shape: Dictionary, rect: Rect2) -> void:
	var kind := str(shape.get("shape", ""))
	if kind == "quarters":
		var colors: Array = shape.get("colors", [])
		var half := rect.size * 0.5
		for i in 4:
			if i >= colors.size():
				break
			var cell := Rect2(rect.position + Vector2(half.x * float(i % 2), half.y * float(i / 2)), half)
			draw_rect(cell, _color(colors[i]))
		return
	var col := _color(shape.get("color", "ffffff"))
	match kind:
		"diamond":
			draw_colored_polygon(PackedVector2Array([
				Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.2),
				Vector2(rect.position.x + rect.size.x * 0.85, rect.position.y + rect.size.y * 0.5),
				Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.8),
				Vector2(rect.position.x + rect.size.x * 0.15, rect.position.y + rect.size.y * 0.5),
			]), col)
		"circle":
			draw_circle(rect.position + rect.size * 0.5, minf(rect.size.x, rect.size.y) * 0.18, col)
		"canton":
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.42, rect.size.y * 0.5)), col)
		"rect_bottom":
			var fraction := float(shape.get("fraction", 0.5))
			draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * (1.0 - fraction)), Vector2(rect.size.x, rect.size.y * fraction)), col)
		"triangle_left":
			draw_colored_polygon(PackedVector2Array([
				rect.position,
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.position.x + rect.size.x * 0.45, rect.position.y + rect.size.y * 0.5),
			]), col)
		"triangle_small":
			draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(rect.size.x * 0.1, rect.size.y * 0.12),
				rect.position + Vector2(rect.size.x * 0.1, rect.size.y * 0.88),
				rect.position + Vector2(rect.size.x * 0.32, rect.size.y * 0.5),
			]), col)
		"cross":
			draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.42, 0), Vector2(rect.size.x * 0.16, rect.size.y)), col)
			draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.4), Vector2(rect.size.x, rect.size.y * 0.2)), col)
		"saltire":
			draw_line(rect.position, rect.end, col, maxf(rect.size.y * 0.13, 2.0))
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), col, maxf(rect.size.y * 0.13, 2.0))
		"diag_band":
			draw_line(rect.position, rect.end, col, maxf(rect.size.y * 0.22, 2.0))
		"border":
			draw_rect(rect.grow(-1.0), col, false, maxf(rect.size.y * 0.1, 2.0))

func _color(hex_value: Variant) -> Color:
	var text := str(hex_value).strip_edges().trim_prefix("#")
	if text.length() != 6:
		return Color("1d3850")
	return Color(text)
