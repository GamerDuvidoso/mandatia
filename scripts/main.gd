extends Control

const BOARD_SCRIPT := preload("res://scripts/aurora_board.gd")
const Election := preload("res://scripts/sim/election.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const Legislature := preload("res://scripts/sim/legislature.gd")
const AIClient := preload("res://scripts/ai/ollama_client.gd")
const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const COUNTRY_DATA_PATH := "res://config/countries.json"
const SAVE_PATH := "user://mandatia_save.json"
const SAVE_TMP := "user://mandatia_save.tmp"
const LEGACY_SAVE_PATH := "user://mandato_save.json"
const SAVE_VERSION := 5
const TERM_MONTHS := 48
const FIRST_CAMPAIGN_MONTHS := 12
const CAMPAIGN_ACTIONS_PER_MONTH := 3
const OPPOSITION_ACTION_COST := 600
const CENSURE_COST := 3000
const CENSURE_CREDIBILITY := 10.0
const SAVE_REQUIRED_KEYS := ["party", "date_year", "date_month", "country_id", "region_support"]

const UI := preload("res://scripts/ui/mandato_theme.gd")
const FlagPainter := preload("res://scripts/ui/flag_painter.gd")

const BG := UI.BG
const PANEL := UI.PANEL
const PANEL_2 := UI.PANEL_2
const LINE := UI.LINE
const TEXT := UI.TEXT
const MUTED := UI.MUTED
const AMBER := UI.AMBER
const CYAN := UI.CYAN
const RED := UI.RED
const GREEN := UI.GREEN

var state: Dictionary = {}
var screen := "menu"
var selected_region := 0
var selected_nav := "Visão geral"
var content: VBoxContainer
var board
var toast: Label
var decision_box: PanelContainer
var decision_text: Label
var decision_buttons: HBoxContainer
var month_button: Button
var header_date: Label
var header_party: Label
var header_funds: Label
var header_position: Label
var status_label: Label
var new_party_name: LineEdit
var new_party_abbr: LineEdit
var new_leader: LineEdit
var new_ideology: OptionButton
var new_scenario: OptionButton
var new_country: OptionButton
var new_start_mode: OptionButton
var new_official_party: OptionButton
var country_leader_label: Label
var official_party_row_label: Label
var new_party_name_label: Label
var new_party_abbr_label: Label
var new_leader_label: Label
var new_ideology_label: Label
var new_scenario_label: Label
var scenario_note: Label
var countries: Array = []
var selected_country_id := "BR"
var file_dialog: FileDialog
var root_stack: Control
var sidebar: VBoxContainer
var main_column: VBoxContainer
var right_column: VBoxContainer
var main_margin: MarginContainer
var sidebar_plate: PanelContainer
var header_stats: Array = []
var promise_checks: Array = []
var promise_options: Array = []
var promise_confirm: Button
var ai: Node
var ai_wait_panel: PanelContainer
var _month_in_progress := false
var _bill_in_progress := false
var _election_in_progress := false
var _event_due := false
var _international_due := false

var regions := [
	{"name":"Costa Norte", "kind":"Portos e pesca", "pop":1.9, "support":33.0, "income":58, "unemployment":7.8, "problem":"infraestrutura portuária"},
	{"name":"Serra Azul", "kind":"Mineração e energia", "pop":1.2, "support":27.0, "income":51, "unemployment":9.6, "problem":"transição industrial"},
	{"name":"Vale Central", "kind":"Serviços e governo", "pop":2.5, "support":41.0, "income":72, "unemployment":5.3, "problem":"custo de moradia"},
	{"name":"Campos do Leste", "kind":"Agricultura", "pop":1.5, "support":29.0, "income":46, "unemployment":10.4, "problem":"seca prolongada"},
	{"name":"Distrito Aurora", "kind":"Tecnologia e finanças", "pop":2.2, "support":36.0, "income":91, "unemployment":4.1, "problem":"desigualdade"},
	{"name":"Planalto Sul", "kind":"Indústria e logística", "pop":1.8, "support":31.0, "income":63, "unemployment":8.1, "problem":"qualificação"},
	{"name":"Lagos do Oeste", "kind":"Turismo e serviços", "pop":1.1, "support":25.0, "income":55, "unemployment":11.2, "problem":"emprego sazonal"},
	{"name":"Fronteira Verde", "kind":"Florestas e agro", "pop":0.9, "support":22.0, "income":43, "unemployment":12.0, "problem":"conectividade"}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_apply_responsive)
	_load_country_catalog()
	_build_state()
	_build_shell()
	_setup_ai()
	_show_menu()

func _setup_ai() -> void:
	ai = AIClient.new()
	ai.name = "AIClient"
	add_child(ai)
	ai.attach(self)

func _load_country_catalog() -> void:
	if not FileAccess.file_exists(COUNTRY_DATA_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COUNTRY_DATA_PATH))
	if parsed is Dictionary: countries = parsed.get("countries", [])

func _country_by_id(country_id: String) -> Dictionary:
	for country in countries:
		if str(country.get("id", "")) == country_id: return country
	return countries[0] if not countries.is_empty() else {}

func _selected_country() -> Dictionary:
	return _country_by_id(selected_country_id)

func _country_label(country: Dictionary) -> String:
	return "%s  [%s]" % [country.get("name", "País"), country.get("id", "??")]

func _build_state() -> void:
	state = _default_state()

func _default_state() -> Dictionary:
	return {
		"started": false, "date_year": 2027, "date_month": 1, "party": "Partido do Jogador", "abbr": "PJ", "leader": "Líder do Partido", "ideology": "social-democrata", "scenario": "Novo movimento", "start_mode": "Partido criado do zero", "country_id": "BR", "country_name": "Brasil", "legislature": {}, "funds": 12400.0, "members": 0, "recognition": 2.0, "popularity": 4.0, "credibility": 31.0, "cohesion": 78.0, "approval": 42.0, "economy": 2.4, "inflation": 4.8, "unemployment": 8.2, "debt": 61.0, "gdp": 100.0, "congress": 0, "senate_seats": 0, "lower_house_seats": 0, "government": false, "coalition": 0, "campaign": 0, "minister_index": 0, "history": [], "news": ["A campanha começa sem país pré-definido: escolha uma democracia e construa sua força política."], "chamber_name": "", "chamber_seats": 0, "majority": 1, "seat_map": {}, "last_election": {}, 		"coalition_partners": [], "coalition_seats": 0, "coalition_cohesion": 60.0, "bills": [], "economy_history": [], "months_to_election": 0, "term_index": 0, "term_months_served": 0, "campaign_actions": 0, "opposition_actions": 0, "action_month": "", 		"promises": [], "last_result": {}, "event_effects_applied": false, "region_support": [4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0], "demographics": {"Jovens": 4.0, "Trabalhadores": 4.0, "Empreendedores": 4.0, "Aposentados": 4.0, "Rurais": 4.0}, "policies": [], "event": ""}

func _build_shell() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root_stack = Control.new()
	root_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_stack)

func _clear_root() -> void:
	for child in root_stack.get_children():
		child.queue_free()

func _show_menu() -> void:
	screen = "menu"
	_clear_root()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_stack.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var eyebrow := _label("ESCOLHA SEU PAÍS  /  SIMULAÇÃO POLÍTICA", 13, AMBER)
	box.add_child(eyebrow)
	var title := _label("MANDATIA", 64, TEXT)
	box.add_child(title)
	var sub := _label("Poder não se herda. Constrói-se, mês a mês.", 22, MUTED)
	box.add_child(sub)
	box.add_child(_rule())
	var description := _label("Lidere um partido, dispute eleições e governe sob pressão.\nCada decisão muda apoio, economia e coalizões.", 18, TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	box.add_child(_spacer(18))
	var new_button := _button("FUNDAR NOVA CAMPANHA", AMBER)
	new_button.pressed.connect(_show_new_game)
	box.add_child(new_button)
	var continue_button := _button("CONTINUAR CAMPANHA", CYAN)
	continue_button.disabled = not _has_save()
	continue_button.pressed.connect(_continue_game)
	box.add_child(continue_button)
	var hint := _label("Jogo desktop  ·  salvamento local  ·  português brasileiro", 13, MUTED)
	box.add_child(_spacer(22))
	box.add_child(hint)

func _show_new_game() -> void:
	screen = "new_game"
	_clear_root()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 70)
	root_stack.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_label("NOVA CAMPANHA", 13, AMBER))
	box.add_child(_label("Fundar uma força política", 36, TEXT))
	box.add_child(_label("Escolha uma identidade. O país responde às suas escolhas, não ao seu rótulo.", 16, MUTED))
	box.add_child(_rule())
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 24)
	form.add_theme_constant_override("v_separation", 12)
	box.add_child(form)
	new_country = OptionButton.new()
	for index in countries.size():
		var country: Dictionary = countries[index]
		new_country.add_item(_country_label(country))
		if str(country.get("id", "")) == selected_country_id: new_country.select(index)
	new_country.custom_minimum_size.x = 310
	new_country.item_selected.connect(_on_country_selected)
	new_start_mode = OptionButton.new()
	new_start_mode.add_item("Partido criado do zero")
	new_start_mode.add_item("Partido oficial com cadeiras atuais")
	new_start_mode.custom_minimum_size.x = 310
	new_start_mode.item_selected.connect(_on_start_mode_changed)
	new_official_party = OptionButton.new()
	new_official_party.custom_minimum_size.x = 310
	_add_field(form, "País da campanha", new_country)
	country_leader_label = _label("", 13, MUTED)
	country_leader_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_field(form, "Governo do país", country_leader_label)
	_add_field(form, "Forma de começar", new_start_mode)
	official_party_row_label = _add_field(form, "Partido oficial", new_official_party)
	new_party_name = _line("Partido do Jogador")
	new_party_abbr = _line("PJ")
	new_leader = _line("Líder do Partido")
	new_ideology = OptionButton.new()
	for item in ["Comunista", "socialista democrático", "social-democrata", "trabalhista", "esquerda progressista", "Centro", "Centro-liberal", "democrata-cristão", "liberal", "conservador", "fascista"]:
		new_ideology.add_item(item)
	new_ideology.custom_minimum_size.x = 310
	new_scenario = OptionButton.new()
	for item in ["Novo movimento", "Oposição estabelecida", "Veterano político", "Incumbente"]:
		new_scenario.add_item(item)
	new_scenario.custom_minimum_size.x = 310
	new_party_name_label = _add_field(form, "Nome do partido", new_party_name)
	new_party_abbr_label = _add_field(form, "Sigla", new_party_abbr)
	new_leader_label = _add_field(form, "Líder", new_leader)
	new_ideology_label = _add_field(form, "Ideologia", new_ideology)
	new_scenario_label = _add_field(form, "Cenário", new_scenario)
	_refresh_party_options()
	box.add_child(_spacer(10))
	scenario_note = _label("Partido criado começa com zero cadeiras. Partido oficial usa a fotografia legislativa disponível para o país e a data do snapshot.", 14, MUTED)
	scenario_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(scenario_note)
	_apply_start_mode_ui()
	box.add_child(_spacer(12))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var back := _button("VOLTAR", MUTED)
	back.pressed.connect(_show_menu)
	actions.add_child(back)
	var start := _button("INICIAR CAMPANHA", AMBER)
	start.pressed.connect(_start_campaign)
	actions.add_child(start)

func _on_country_selected(index: int) -> void:
	if index >= 0 and index < countries.size():
		selected_country_id = str(countries[index].get("id", "BR"))
		_refresh_party_options()

func _on_start_mode_changed(_index: int) -> void:
	_apply_start_mode_ui()
	_refresh_party_options()

func _apply_start_mode_ui() -> void:
	var official_mode := is_instance_valid(new_start_mode) and new_start_mode.selected == 1
	var new_party_visible := not official_mode
	if is_instance_valid(official_party_row_label): official_party_row_label.visible = official_mode
	if is_instance_valid(new_official_party): new_official_party.visible = official_mode
	for pair in [
		[new_party_name_label, new_party_name],
		[new_party_abbr_label, new_party_abbr],
		[new_leader_label, new_leader],
		[new_ideology_label, new_ideology],
		[new_scenario_label, new_scenario],
	]:
		if pair[0] != null and is_instance_valid(pair[0]): pair[0].visible = new_party_visible
		if pair[1] != null and is_instance_valid(pair[1]): pair[1].visible = new_party_visible
	if is_instance_valid(scenario_note):
		if official_mode:
			scenario_note.visible = true
			scenario_note.text = "O partido oficial usa a fotografia legislativa disponível para o país e a data do snapshot. A campanha começa com essas cadeiras."
		else:
			scenario_note.visible = true
			scenario_note.text = "O partido criado começa com zero cadeiras. Escolha o cenário inicial da campanha."

func _refresh_party_options() -> void:
	if not is_instance_valid(new_official_party): return
	new_official_party.clear()
	var country := _selected_country()
	var official_parties: Array = country.get("official_parties", [])
	if official_parties.is_empty():
		new_official_party.add_item("Nenhum snapshot partidário disponível ainda")
		new_official_party.disabled = true
	else:
		new_official_party.disabled = false
		for party in official_parties:
			new_official_party.add_item("%s — %s · %s" % [party.get("name", "Partido"), _party_seat_label(party), party.get("ideology", "ideologia não informada")])
	if is_instance_valid(country_leader_label):
		country_leader_label.text = _country_leader_summary(country)

func _country_leader_summary(country: Dictionary) -> String:
	var head: Dictionary = country.get("head_of_state", {})
	var government: Variant = country.get("head_of_government", null)
	var lines: Array = []
	if str(head.get("office", "")) != "":
		lines.append("%s — %s (%s)" % [head.get("name", "Vago"), head.get("office", ""), head.get("party", "")])
	else:
		lines.append("%s" % head.get("office", "Lider do país não informado"))
	if government is Dictionary and str(government.get("name", "")) != "":
		lines.append("Chefe de Governo: %s — %s" % [government.get("name", ""), government.get("office", "")])
	return "\n".join(lines)

func _party_seat_label(party: Dictionary) -> String:
	var lower: Variant = party.get("lower_house_seats", null)
	var senate: Variant = party.get("senate_seats", null)
	if lower != null and senate != null: return "%d deputados · %d senadores" % [int(lower), int(senate)]
	if lower != null: return "%d deputados" % int(lower)
	if senate != null: return "%d senadores" % int(senate)
	return "cadeiras não informadas"

func _selected_official_party() -> Dictionary:
	var country := _selected_country()
	var parties: Array = country.get("official_parties", [])
	if parties.is_empty() or not is_instance_valid(new_official_party): return {}
	var index := new_official_party.selected
	return parties[index] if index >= 0 and index < parties.size() else {}

func _start_campaign() -> void:
	var country := _selected_country()
	var official_mode := new_start_mode.selected == 1
	var official_party := _selected_official_party()
	if official_mode and official_party.is_empty():
		_show_toast("Este país já está selecionável, mas o snapshot de partidos oficiais ainda está em preparação.", "warning")
		return
	state.country_id = str(country.get("id", "BR"))
	state.country_name = str(country.get("name", "País"))
	state.legislature = country
	state.chamber_name = Election.chamber_name(country)
	state.chamber_seats = Election.chamber_seats(country)
	state.majority = Election.majority_of(int(state.chamber_seats))
	state.last_election = {}
	state.coalition_partners = []
	state.coalition_seats = 0
	state.bills = []
	state.economy_history = [_economy_point()]
	state.start_mode = "Partido oficial" if official_mode else "Partido criado do zero"
	if official_mode:
		state.party = str(official_party.get("name", "Partido oficial"))
		state.abbr = str(official_party.get("abbr", "OF"))
		state.leader = str(official_party.get("leader", "Líder não informado"))
		state.ideology = str(official_party.get("ideology", "não informada oficialmente"))
		state.scenario = "Partido oficial"
		state.lower_house_seats = int(official_party.get("lower_house_seats", 0)) if official_party.get("lower_house_seats", null) != null else 0
		state.senate_seats = int(official_party.get("senate_seats", 0)) if official_party.get("senate_seats", null) != null else 0
		state.congress = state.lower_house_seats + state.senate_seats
		state.members = state.congress
		state.recognition = 32.0
		state.popularity = 26.0
	else:
		state.party = new_party_name.text.strip_edges() if new_party_name.text.strip_edges() != "" else "Partido do Jogador"
		state.abbr = new_party_abbr.text.strip_edges().to_upper() if new_party_abbr.text.strip_edges() != "" else "PJ"
		state.leader = new_leader.text.strip_edges() if new_leader.text.strip_edges() != "" else "Líder do Partido"
		state.ideology = new_ideology.get_item_text(new_ideology.selected)
		state.scenario = new_scenario.get_item_text(new_scenario.selected) if is_instance_valid(new_scenario) else "Novo movimento"
		state.lower_house_seats = 0
		state.senate_seats = 0
		state.congress = 0
		state.members = 0
	state.seat_map = _starting_seat_map(country)
	if not official_mode and state.scenario == "Oposição estabelecida":
		state.funds = 22000.0; state.recognition = 34.0; state.popularity = 34.0; state.members = 2400
	elif not official_mode and state.scenario == "Veterano político":
		state.funds = 31000.0; state.recognition = 48.0; state.popularity = 41.0; state.credibility = 50.0; state.members = 4800
	elif not official_mode and state.scenario == "Incumbente":
		state.funds = 18000.0; state.recognition = 62.0; state.popularity = 52.0; state.government = true; state.lower_house_seats = int(state.majority); state.congress = int(state.majority); state.members = 7400
	if not official_mode and bool(state.government):
		state.seat_map[str(state.abbr)] = int(state.lower_house_seats)
	state.started = true
	state.months_to_election = TERM_MONTHS if bool(state.government) else FIRST_CAMPAIGN_MONTHS
	state.term_index = 1
	state.term_months_served = 0
	state.campaign_actions = 0
	state.opposition_actions = 0
	state.action_month = "%d-%02d" % [int(state.date_year), int(state.date_month)]
	state.promises = []
	state.last_result = {}
	_save_game()
	_show_promises()

func _continue_game() -> void:
	_load_game()
	if state.get("started", false): _show_game()
	else: _show_menu()

func _show_game() -> void:
	screen = "game"
	_clear_root()
	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	root_stack.add_child(shell)
	var header := _build_header()
	shell.add_child(header)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	shell.add_child(body)
	sidebar = _build_sidebar()
	body.add_child(sidebar)
	main_column = VBoxContainer.new()
	main_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_column.add_theme_constant_override("separation", 12)
	main_margin = MarginContainer.new()
	main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_margin.add_theme_constant_override("margin_left", 22)
	main_margin.add_theme_constant_override("margin_right", 22)
	main_margin.add_theme_constant_override("margin_top", 16)
	main_margin.add_theme_constant_override("margin_bottom", 16)
	main_margin.add_child(main_column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_child(main_margin)
	body.add_child(scroll)
	right_column = VBoxContainer.new()
	right_column.custom_minimum_size.x = UI.RAIL_WIDTH
	right_column.add_theme_constant_override("separation", 12)
	body.add_child(right_column)
	shell.add_child(_build_status_bar())
	_ensure_chamber_state()
	_apply_responsive()
	match selected_nav:
		"Visão geral": _show_dashboard()
		"Meu partido": _show_party()
		"Eleições": _show_elections()
		"Congresso": _show_congress()
		"Governo": _show_government()
		"Economia": _show_economy()
		"População": _show_population()
		"Regiões": _show_regions()
		"Internacional": _show_international()
		"Notícias": _show_news()
		"História": _show_history()
		"Configurações": _show_settings()

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 72
	panel.add_theme_stylebox_override("panel", _style(PANEL, LINE, 0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var flag := FlagPainter.new()
	flag.country_id = str(state.get("country_id", "BR"))
	flag.custom_minimum_size = Vector2(56, 36)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flag.tooltip_text = str(state.get("country_name", ""))
	row.add_child(flag)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 200
	brand.add_child(_label("MANDATIA", 18, AMBER))
	header_party = _label("", 12, MUTED)
	brand.add_child(header_party)
	row.add_child(brand)
	header_date = _label("", 18, TEXT)
	header_date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(header_date)
	header_position = _label("", 13, CYAN)
	row.add_child(header_position)
	header_funds = _label("", 16, AMBER)
	row.add_child(header_funds)
	header_stats = [
		_header_stat("DÍVIDA/PIB", "%.0f%%" % state.debt, AMBER),
		_header_stat("INFLAÇÃO", "%.1f%%" % state.inflation, RED),
	]
	for stat in header_stats:
		row.add_child(stat)
	month_button = _button("AVANÇAR MÊS  ›", AMBER)
	month_button.pressed.connect(_advance_month)
	row.add_child(month_button)
	return panel

func _build_sidebar() -> VBoxContainer:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = UI.SIDEBAR_WIDE
	nav.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var plate := PanelContainer.new()
	plate.custom_minimum_size.x = UI.SIDEBAR_WIDE
	plate.add_theme_stylebox_override("panel", _style(Color("0b1727"), LINE, 0, 0))
	sidebar_plate = plate
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	plate.add_child(inner)
	scroll.add_child(plate)
	for group in [
		["PAÍS", ["Visão geral", "Meu partido"]],
		["PODER", ["Eleições", "Congresso", "Governo"]],
		["ECONOMIA", ["Economia", "População", "Regiões"]],
		["MUNDO", ["Internacional"]],
		["REGISTRO", ["Notícias", "História", "Configurações"]],
	]:
		var caption := _label(str(group[0]), 9, MUTED)
		caption.custom_minimum_size.y = 18
		inner.add_child(caption)
		for item in group[1]:
			var b := _button(str(item), TEXT if item == selected_nav else MUTED, false)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 32
			b.pressed.connect(_select_nav.bind(str(item)))
			inner.add_child(b)
	var footer := VBoxContainer.new()
	footer.add_spacer(false)
	var save := _button("SALVAR CAMPANHA", CYAN, false)
	save.pressed.connect(_manual_save)
	footer.add_child(save)
	var menu := _button("MENU PRINCIPAL", MUTED, false)
	menu.pressed.connect(_show_menu)
	footer.add_child(menu)
	nav.add_child(scroll)
	nav.add_child(footer)
	return nav

func _select_nav(item: String) -> void:
	selected_nav = item
	_show_game()

func _show_dashboard() -> void:
	_update_header()
	_clear_column(main_column)
	_clear_column(right_column)
	main_column.add_child(_section_title("Visão geral", "Decisões deste mês e sinais que movem o próximo ciclo eleitoral."))
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	for metric in [["POPULARIDADE", state.popularity, CYAN], ["APROVAÇÃO", state.approval, GREEN], ["RECONHECIMENTO", state.recognition, AMBER], ["COESÃO", state.cohesion, Color("b39ddb")]]:
		metrics.add_child(_metric_card(metric[0], "%.0f%%" % metric[1], metric[2]))
	main_column.add_child(metrics)
	main_column.add_child(_month_action_panel())
	board = BOARD_SCRIPT.new()
	board.custom_minimum_size = Vector2(0, 340)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.set_data(state, regions)
	main_column.add_child(board)
	var brief := _panel_box()
	var bcol := VBoxContainer.new()
	bcol.add_child(_label("BRIEFING", 12, AMBER))
	bcol.add_child(_label("Fatores que mudaram", 17, TEXT))
	bcol.add_child(_rule())
	bcol.add_child(_label("+ reconhecimento", 14, GREEN))
	var growth_note := _label("A presença regional cresceu após o último giro de base.", 13, MUTED)
	growth_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bcol.add_child(growth_note)
	bcol.add_child(_spacer(8))
	bcol.add_child(_label("− inflação", 14, RED))
	var cost_note := _label("Custo de vida reduz confiança entre trabalhadores urbanos.", 13, MUTED)
	cost_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bcol.add_child(cost_note)
	bcol.add_child(_spacer(8))
	bcol.add_child(_label("Próximo marco", 12, AMBER))
	bcol.add_child(_label(_next_election_label(), 18, TEXT))
	brief.add_child(bcol)
	main_column.add_child(brief)
	_build_right_rail()

func _build_right_rail() -> void:
	var decision := _panel_box()
	var dcol := VBoxContainer.new()
	dcol.add_child(_label("DECISÃO PENDENTE", 12, AMBER))
	decision_text = _label("", 15, TEXT)
	decision_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dcol.add_child(decision_text)
	decision_buttons = HBoxContainer.new()
	decision_buttons.add_theme_constant_override("separation", 6)
	dcol.add_child(decision_buttons)
	decision.add_child(dcol)
	right_column.add_child(decision)
	decision_box = decision
	_set_event_if_needed()
	var news := _panel_box()
	var ncol := VBoxContainer.new()
	ncol.add_child(_label("RADAR NACIONAL", 12, CYAN))
	ncol.add_child(_label("Últimas manchetes", 18, TEXT))
	for item in state.news.slice(0, 4):
		var l := _label("• " + str(item), 13, MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ncol.add_child(l)
	news.add_child(ncol)
	right_column.add_child(news)
	var mandate := _panel_box()
	var mcol := VBoxContainer.new()
	mcol.add_child(_label("PARTIDO", 12, AMBER))
	mcol.add_child(_label("%s  ·  %s" % [state.party, state.ideology], 14, TEXT))
	mcol.add_child(_label("Membros  %s" % _fmt_int(state.members), 13, MUTED))
	mcol.add_child(_label("Caixa  M$ %s" % _fmt_int(state.funds), 13, MUTED))
	mandate.add_child(mcol)
	right_column.add_child(mandate)

func _set_event_if_needed() -> void:
	for child in decision_buttons.get_children(): child.queue_free()
	var event: String = state.event
	if event == "":
		decision_text.text = "Nenhuma crise aberta. Avance o mês para atualizar o ambiente político."
		var b := _button("VER NOTÍCIAS", MUTED, false)
		b.pressed.connect(_select_nav.bind("Notícias"))
		decision_buttons.add_child(b)
		return
	decision_text.text = event
	for option in ["Investir agora", "Negociar", "Não intervir"]:
		var b := _button(option, CYAN if option != "Não intervir" else MUTED, false)
		b.pressed.connect(_resolve_event.bind(option))
		decision_buttons.add_child(b)

func _resolve_event(option: String) -> void:
	# Evento da IA: a conjuntura já foi contabilizada uma única vez no avanço do
	# mês. A escolha do jogador define apenas o custo político da resposta.
	if bool(state.get("event_effects_applied", false)):
		match option:
			"Investir agora":
				state.credibility += 1
				state.news.push_front("O partido anunciou uma resposta de investimento; os efeitos da crise já estavam contabilizados.")
			"Negociar":
				state.cohesion += 1
				state.news.push_front("A liderança abriu negociação com setores produtivos; os efeitos da crise já estavam contabilizados.")
			_:
				state.credibility -= 1
				state.news.push_front("A crise seguiu sem intervenção direta; os efeitos da conjuntura já estavam contabilizados.")
	else:
		if option == "Investir agora":
			state.funds -= 1400; state.approval += 3; state.popularity += 2; state.news.push_front("O partido anunciou uma resposta de investimento e ganhou espaço na imprensa.")
		elif option == "Negociar":
			state.credibility += 4; state.cohesion += 2; state.news.push_front("A liderança abriu negociação com setores produtivos.")
		else:
			state.funds += 500; state.approval -= 2; state.news.push_front("A crise seguiu sem intervenção direta do partido.")
	state.event = ""
	state["event_effects_applied"] = false
	_clamp_state()
	_save_game()
	_show_game()

func _show_section(title: String, subtitle: String) -> void:
	_update_header()
	_clear_column(main_column)
	_clear_column(right_column)
	main_column.add_child(_section_title(title, subtitle))

func _show_party() -> void:
	_show_section("Meu partido", "Uma organização forte transforma identidade em votos.")
	var grid := HBoxContainer.new()
	for metric in [["Membros", _fmt_int(state.members), AMBER], ["Credibilidade", "%.0f%%" % state.credibility, CYAN], ["Coesão interna", "%.0f%%" % state.cohesion, GREEN], ["Caixa", "M$ %s" % _fmt_int(state.funds), AMBER]]:
		grid.add_child(_metric_card(metric[0], metric[1], metric[2]))
	main_column.add_child(grid)
	var panel := _panel_box()
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 18)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label("IDENTIDADE", 12, AMBER))
	col.add_child(_label(state.party + "  /  " + state.abbr, 24, TEXT))
	col.add_child(_label("Liderança: %s" % state.leader, 15, MUTED))
	col.add_child(_label("Ideologia: %s" % state.ideology, 15, MUTED))
	col.add_child(_label("Cenário: %s" % state.scenario, 15, MUTED))
	col.add_child(_rule())
	col.add_child(_label("Ações organizacionais", 17, TEXT))
	var actions := HBoxContainer.new()
	for pair in [["Giro regional", "Aumenta apoio em regiões frágeis", "regional"], ["Formar voluntários", "Mais membros e coesão", "volunteers"], ["Publicar programa", "Credibilidade e reconhecimento", "program"]]:
		var b := _button(pair[0], CYAN, false)
		b.tooltip_text = pair[1]
		b.pressed.connect(_party_action.bind(pair[2]))
		actions.add_child(b)
	col.add_child(actions)
	var medals := HBoxContainer.new()
	medals.add_theme_constant_override("separation", 10)
	medals.add_child(_badge(str(state.abbr), "SIGLA", 104, AMBER))
	medals.add_child(_badge(_initials(str(state.leader)), "LIDERANÇA", 104, CYAN))
	identity_row.add_child(col)
	identity_row.add_child(medals)
	panel.add_child(identity_row)
	main_column.add_child(panel)
	_build_right_rail()

func _party_action(action: String) -> void:
	if action == "regional":
		state.funds -= 900; state.recognition += 3; state.popularity += 2
		for i in state.region_support.size(): state.region_support[i] += 1.2
		state.news.push_front("O partido concluiu um giro regional com foco em regiões competitivas.")
	elif action == "volunteers":
		state.funds -= 650; state.members += 420; state.cohesion += 2; state.popularity += 1
		state.news.push_front("A rede de voluntários ganhou novos núcleos locais.")
	else:
		state.funds -= 1100; state.credibility += 4; state.recognition += 2
		state.news.push_front("O novo programa partidário foi publicado e passou a orientar as alianças.")
	_clamp_state(); _save_game(); _show_game()

func _show_elections() -> void:
	_show_section("Eleições", "Pesquisas são sinais. Campanha converte sinais em organização.")
	var country := _country_by_id(str(state.country_id))
	var seats := Election.chamber_seats(country)
	var shares := Election.poll_shares(state, country)
	var projection := Election.allocate_dhondt(shares, seats)
	var majority := Election.majority_of(seats)
	var player_key := str(state.abbr)
	var top := HBoxContainer.new()
	top.add_child(_metric_card("PRÓXIMA ELEIÇÃO", "%d meses" % max(0, 12 - int(state.date_month)), AMBER))
	top.add_child(_metric_card("INTENÇÃO DE VOTO", "%.1f%%" % float(shares.get(player_key, 0.0)), CYAN))
	top.add_child(_metric_card("CADEIRAS PROJETADAS", ("%d de %d" % [int(projection.get(player_key, 0)), seats]) if seats > 0 else "câmara não informada", AMBER))
	main_column.add_child(top)
	var poll := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("PESQUISA NACIONAL  ·  %s  ·  margem ±3,2 p.p." % str(country.get("name", "País")), 12, CYAN))
	col.add_child(_label("Intenção de voto para %s" % (Election.chamber_name(country) if seats > 0 else "o parlamento"), 20, TEXT))
	var shown := 0
	for pair in Election.sorted_pairs(shares):
		if shown >= 8:
			break
		shown += 1
		var key := str(pair[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(key, 14, AMBER if key == player_key else (MUTED if key == Election.UNDECIDED else TEXT))
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		var fill := ProgressBar.new()
		fill.value = float(pair[1])
		fill.show_percentage = false
		fill.custom_minimum_size = Vector2(230, 15)
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fill)
		row.add_child(_label("%.1f%%" % float(pair[1]), 14, AMBER if key == player_key else MUTED))
		if key != Election.UNDECIDED and seats > 0:
			var seat_label := _label("%d cadeiras" % int(projection.get(key, 0)), 13, MUTED)
			seat_label.custom_minimum_size.x = 104
			row.add_child(seat_label)
		col.add_child(row)
	col.add_child(_rule())
	col.add_child(_label("Maioria na câmara: %d de %d cadeiras  ·  projeção por D'Hondt sobre a pesquisa" % [majority, seats], 13, MUTED))
	poll.add_child(col)
	main_column.add_child(poll)
	var campaign := _panel_box()
	var ccol := VBoxContainer.new()
	ccol.add_child(_label("SALA DE CAMPANHA", 12, AMBER))
	ccol.add_child(_label("Escolha onde gastar capital político. A eleição distribui as cadeiras da câmara pela pesquisa nacional (D'Hondt).", 15, MUTED))
	var acts := HBoxContainer.new()
	for pair in [["Debate nacional", 2400, 5], ["Foco regional", 1800, 4], ["Coalizão", 1200, 3]]:
		var b := _button(pair[0], AMBER, false)
		b.tooltip_text = "M$ %d  ·  +%d p.p. de intenção" % [pair[1], pair[2]]
		b.pressed.connect(_campaign_action.bind(pair[1], pair[2], pair[0]))
		acts.add_child(b)
	var free_action := _button("Militância de base", MUTED, false)
	free_action.tooltip_text = "Sem custo  ·  +0,5 de popularidade e +0,2 de reconhecimento"
	free_action.pressed.connect(_free_campaign_action)
	acts.add_child(free_action)
	ccol.add_child(acts)
	_sync_action_month()
	ccol.add_child(_label("Ações de campanha neste mês: %d de %d" % [int(state.campaign_actions), CAMPAIGN_ACTIONS_PER_MONTH], 12, MUTED))
	if int(state.months_to_election) <= 0:
		var election := _button("REALIZAR ELEIÇÃO", GREEN)
		election.pressed.connect(_run_election)
		ccol.add_child(election)
		ccol.add_child(_label("Mandato encerrado: o pleito é obrigatório para abrir o próximo ciclo.", 13, AMBER))
	campaign.add_child(ccol)
	main_column.add_child(campaign)
	_build_right_rail()

func _campaign_action(cost: int, gain: int, label: String) -> void:
	_sync_action_month()
	if int(state.campaign_actions) >= CAMPAIGN_ACTIONS_PER_MONTH:
		_show_toast("Limite de %d ações de campanha neste mês" % CAMPAIGN_ACTIONS_PER_MONTH, "warning")
		return
	if state.funds < cost:
		_show_toast("Caixa insuficiente para " + label.to_lower(), "error")
		return
	state.campaign_actions = int(state.campaign_actions) + 1
	state.funds -= cost; state.popularity += gain; state.recognition += 1.5; state.campaign += gain
	state.news.push_front("A campanha investiu em %s e ganhou presença nacional." % label.to_lower())
	_clamp_state(); _save_game(); _show_game()

func _run_election() -> void:
	if int(state.months_to_election) > 0:
		_show_toast("O mandato ainda tem %d meses" % int(state.months_to_election), "warning")
		return
	var country := _country_by_id(str(state.country_id))
	var seats := Election.chamber_seats(country)
	if seats <= 0:
		_show_toast("Este país ainda não tem câmara catalogada", "error")
		return
	if _election_in_progress:
		return
	if ai != null and ai.pending_count() > 0:
		_show_toast("Aguarde a decisão da IA em andamento", "warning")
		return
	_election_in_progress = true
	var base := Election.poll_shares(state, country)
	var prompt_ctx := {
		"pais": str(state.country_name),
		"partido": str(state.party),
		"popularidade": float(state.popularity),
		"aprovacao": float(state.approval),
		"pesquisa": _poll_lines(base),
		"ids_permitidos": Array(base.keys()),
	}
	var meta := {"month": int(state.date_month), "year": int(state.date_year), "country": str(state.country_id)}
	var data := {"base_shares": base, "entities": base.keys()}
	var op_id: String = ai.request(Contracts.ELECTORAL, prompt_ctx, data, meta, _on_election_shares.bind(country))
	if ai.is_pending(op_id):
		_show_ai_wait("As urnas estão sendo apuradas...", op_id)

func _poll_lines(shares: Dictionary) -> Array:
	var lines: Array = []
	for pair in Election.sorted_pairs(shares):
		lines.append("%s: %.1f%%" % [str(pair[0]), float(pair[1])])
	return lines

## A IA ajusta a intenção de voto em ±3 p.p.; D'Hondt continua no motor.
func _on_election_shares(result: Dictionary, country: Dictionary) -> void:
	if not _election_in_progress:
		return
	_election_in_progress = false
	_hide_ai_wait()
	var base := Election.poll_shares(state, country)
	var value: Dictionary = result.get("value", {})
	var shares: Dictionary = value.get("shares", {}) if value.get("shares") is Dictionary else {}
	if shares.is_empty():
		shares = base
	var seats := Election.chamber_seats(country)
	var election_year := int(state.date_year)
	var seat_map := Election.allocate_dhondt(shares, seats)
	var majority := Election.majority_of(seats)
	var rng := RandomNumberGenerator.new()
	rng.seed = election_year * 1200 + int(state.date_month) * 31 + seats
	var presidential_race := Election.presidential(shares, Election.axes(state, country), rng)
	var player_key := str(state.abbr)
	var player_seats := int(seat_map.get(player_key, 0))
	var parliamentary := Election.is_parliamentary(country)
	var won := false
	if parliamentary:
		won = player_seats >= majority or (player_seats > 0 and Election.largest_party(seat_map) == player_key)
	else:
		won = str(presidential_race.get("winner", "")) == player_key
	state.seat_map = seat_map
	state.lower_house_seats = player_seats
	state.congress = player_seats + int(state.senate_seats)
	state.chamber_name = Election.chamber_name(country)
	state.chamber_seats = seats
	state.majority = majority
	state.government = won
	state.coalition_partners = []
	state.coalition_seats = player_seats if won else 0
	state.coalition_cohesion = float(state.cohesion)
	state.last_election = {
		"year": election_year, "seats": seat_map, "majority": majority,
		"player_seats": player_seats, "winner": str(presidential_race.get("winner", "")),
		"round1": presidential_race.get("round1", []), "round2": presidential_race.get("round2", []),
		"second_round": bool(presidential_race.get("second_round", false)), "parliamentary": parliamentary,
	}
	var months_served := int(state.term_months_served)
	state.date_month = 1
	state.date_year += 1
	state.campaign = 0
	state.event = ""
	state.approval = 56.0 if won else 38.0
	var promise_result := _evaluate_promises()
	state.term_index = int(state.term_index) + 1
	state.term_months_served = 0
	state.months_to_election = TERM_MONTHS
	state.campaign_actions = 0
	state.opposition_actions = 0
	state.action_month = "%d-%02d" % [int(state.date_year), int(state.date_month)]
	var laws := 0
	for item in state.bills:
		if bool(item.get("approved", false)):
			laws += 1
	state.last_result = {
		"won": won, "year": election_year, "seats": seats, "majority": majority,
		"player_seats": player_seats, "approval": float(state.approval), "debt": float(state.debt),
		"laws": laws, "promises": promise_result.get("details", []), "term_months": months_served,
		"fulfilled": int(promise_result.get("fulfilled", 0)), "promise_total": int(promise_result.get("total", 0)),
		"parliamentary": parliamentary,
	}
	state.history.push_front("Eleição %d: %s — %d de %d cadeiras (maioria %d)" % [election_year, "vitória" if won else "derrota", player_seats, seats, majority])
	state.history.push_front("Mandato encerrado: %d de %d promessas cumpridas, %d leis aprovadas." % [int(state.last_result.fulfilled), int(state.last_result.promise_total), laws])
	if won:
		state.news.push_front("Vitória eleitoral: o partido chega a %d de %d cadeiras e assume o governo." % [player_seats, seats])
	else:
		state.news.push_front("Derrota eleitoral: %d de %d cadeiras na %s; a organização segue na oposição." % [player_seats, seats, Election.chamber_name(country)])
	_clamp_state(); _save_game(); _show_result()

func _show_congress() -> void:
	_show_section("Congresso", "Nenhuma lei passa sem aritmética, concessões e confiança.")
	var country := _country_by_id(str(state.country_id))
	var seats := int(state.chamber_seats)
	var majority := int(state.majority)
	var player_seats := int(state.lower_house_seats)
	var player_key := str(state.abbr)
	var has_majority := majority > 1 and player_seats >= majority
	var top := HBoxContainer.new()
	top.add_child(_metric_card("CADEIRAS DO PARTIDO", "%d de %d" % [player_seats, seats], CYAN))
	top.add_child(_metric_card("MAIORIA", str(majority), AMBER))
	top.add_child(_metric_card("SITUAÇÃO", "maioria" if has_majority else "minoria", GREEN if has_majority else RED))
	main_column.add_child(top)
	var seat_map: Dictionary = {}
	if state.get("seat_map") is Dictionary:
		seat_map = state.seat_map
	var chart := BOARD_SCRIPT.new()
	chart.custom_minimum_size = Vector2(0, 300)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_hemicycle(seat_map, Election.axes(state, country), majority, seats, int(state.get("coalition_seats", 0)))
	main_column.add_child(chart)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("BANCADAS  ·  %s" % str(state.chamber_name), 12, CYAN))
	if seat_map.is_empty():
		col.add_child(_label("Sem fotografia legislativa para este país. Realize uma eleição para gerar a distribuição.", 15, MUTED))
	else:
		var chamber_total := maxf(1.0, float(seats))
		for pair in Election.sorted_pairs(seat_map):
			var key := str(pair[0])
			var count := int(pair[1])
			if count <= 0:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var chip := _label(key, 12, UI.axis_color(Election.ideology_axis(_party_ideology(key))))
			chip.custom_minimum_size.x = 84
			row.add_child(chip)
			var name_label := _label(_party_name(key), 14, TEXT)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.clip_text = true
			row.add_child(name_label)
			if size.x >= UI.PAD_BREAKPOINT:
				row.add_child(_label(_party_role(key), 11, MUTED))
			var seats_label := _label("%d cadeiras" % count, 13, MUTED)
			seats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			seats_label.custom_minimum_size.x = 86
			row.add_child(seats_label)
			var share_label := _label("%d%%" % int(round(float(count) / chamber_total * 100.0)), 13, MUTED)
			share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			share_label.custom_minimum_size.x = 40
			row.add_child(share_label)
			col.add_child(row)
		col.add_child(_label("Sigla colorida pelo eixo ideológico; cadeiras e participação no total da câmara.", 12, MUTED))
	panel.add_child(col)
	main_column.add_child(panel)
	var bills := _panel_box()
	var bcol := VBoxContainer.new()
	bcol.add_child(_label("PROPOSIÇÕES", 12, AMBER))
	bcol.add_child(_label("O plenário vota por bancada: proximidade ideológica e disciplina da coalizão.", 13, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	for bill in Legislature.BILLS:
		if bool(bill.get("requires_government", false)) and not bool(state.government):
			continue
		var b := _button(str(bill.get("title", "Proposição")), CYAN, false)
		b.tooltip_text = "%s  ·  custo M$ %s  ·  eixo %.2f" % [str(bill.get("summary", "")), _fmt_int(float(bill.get("cost", 0))), float(bill.get("axis", 0.0))]
		b.pressed.connect(_propose_bill.bind(str(bill.get("id", ""))))
		actions.add_child(b)
	if not bool(state.government):
		bcol.add_child(_label("Três proposições de governo ficam disponíveis ao assumir o poder; como bancada, restam as três de iniciativa parlamentar.", 12, MUTED))
	bcol.add_child(actions)
	bills.add_child(bcol)
	main_column.add_child(bills)
	var agenda: Array = []
	if state.get("bills") is Array:
		agenda = state.bills
	if not agenda.is_empty():
		var history := _panel_box()
		var hcol := VBoxContainer.new()
		hcol.add_child(_label("AGENDA RECENTE", 12, CYAN))
		for item in agenda.slice(0, 6):
			var approved := bool(item.get("approved", false))
			hcol.add_child(_label("%02d/%d  ·  %s  ·  %s  ·  %d a %d" % [int(item.get("month", 1)), int(item.get("year", 0)), str(item.get("title", "")), "aprovada" if approved else "rejeitada", int(item.get("ayes", 0)), int(item.get("nayes", 0))], 14, GREEN if approved else RED))
		history.add_child(hcol)
		main_column.add_child(history)
	_build_right_rail()

## O modelo local trava com JSON longo: cada bloco de bancadas é uma decisão.
const BILL_BANKS_PER_REQUEST := 5

func _propose_bill(bill_id: String) -> void:
	var bill := Legislature.bill(bill_id)
	if bill.is_empty():
		return
	if bool(bill.get("requires_government", false)) and not bool(state.government):
		_show_toast("Essa proposição é exclusiva do governo", "warning")
		return
	var cost := int(bill.get("cost", 0))
	if state.funds < cost:
		_show_toast("Caixa insuficiente para " + str(bill.get("title", "a proposição")), "error")
		return
	var country := _country_by_id(str(state.country_id))
	var seat_map: Dictionary = {}
	if state.get("seat_map") is Dictionary:
		seat_map = state.seat_map
	if seat_map.is_empty():
		_show_toast("Sem bancada registrada para votar", "warning")
		return
	var partners: Array = []
	if state.get("coalition_partners") is Array:
		partners = state.coalition_partners
	if _bill_in_progress:
		_show_toast("A votação anterior ainda está em curso", "warning")
		return
	if ai != null and ai.pending_count() > 0:
		_show_toast("Aguarde a decisão da IA em andamento", "warning")
		return
	_bill_in_progress = true
	var axes := Election.axes(state, country)
	var banks: Array = []
	for key in seat_map.keys():
		if int(seat_map[key]) > 0:
			banks.append(str(key))
	banks.sort()
	var chunks: Array = []
	var cursor := 0
	while cursor < banks.size():
		chunks.append(banks.slice(cursor, cursor + BILL_BANKS_PER_REQUEST))
		cursor += BILL_BANKS_PER_REQUEST
	if chunks.is_empty():
		_bill_in_progress = false
		_show_toast("Sem bancada registrada para votar", "warning")
		return
	var meta := {"month": int(state.date_month), "year": int(state.date_year), "country": str(state.country_id)}
	var resolution_key := Contracts.cache_key(Contracts.LEGISLATIVE, meta, seat_map.keys())
	_request_bill_chunk(bill, seat_map, axes, partners, chunks, 0, {}, meta, resolution_key)

## O modelo local não entrega 13 bancadas numa resposta só: o plenário é
## consultado em blocos e o resultado é agregado antes da apuração.
func _request_bill_chunk(bill: Dictionary, seat_map: Dictionary, axes: Dictionary, partners: Array, chunks: Array, index: int, collected: Dictionary, meta: Dictionary, resolution_key: String) -> void:
	if index >= chunks.size():
		_on_bill_votes({"key": resolution_key, "value": {"votes": collected}}, bill, seat_map)
		return
	var chunk: Array = chunks[index]
	var chunk_map := {}
	for party in chunk:
		chunk_map[str(party)] = int(seat_map.get(str(party), 0))
	var prompt_ctx := {
		"proposicao": str(bill.get("title", "")),
		"eixo": float(bill.get("axis", 0.0)),
		"coesao": float(state.cohesion),
		"bancadas": _bill_party_lines(chunk_map, axes, partners),
		"ids_permitidos": chunk,
	}
	var data := {"bill": bill, "seat_map": chunk_map, "axes": axes, "partners": partners, "cohesion": float(state.cohesion), "entities": chunk}
	var op_id: String = ai.request(Contracts.LEGISLATIVE, prompt_ctx, data, meta, _on_bill_chunk.bind(bill, seat_map, axes, partners, chunks, index, collected, meta, resolution_key))
	if ai.is_pending(op_id):
		_show_ai_wait("O plenário está votando a proposição...", op_id)

func _on_bill_chunk(result: Dictionary, bill: Dictionary, seat_map: Dictionary, axes: Dictionary, partners: Array, chunks: Array, index: int, collected: Dictionary, meta: Dictionary, resolution_key: String) -> void:
	_hide_ai_wait()
	var value: Dictionary = result.get("value", {}) if result.get("value") is Dictionary else {}
	var votes: Variant = value.get("votes", {})
	if votes is Dictionary:
		for party in (votes as Dictionary).keys():
			collected[str(party)] = (votes as Dictionary)[party]
	# "Resolver sem IA" corta a votação aqui: o que veio fica e o resto é motor.
	if str(result.get("source", "")) == "cancelled":
		_on_bill_votes({"key": resolution_key, "value": {"votes": collected}}, bill, seat_map)
		return
	_request_bill_chunk(bill, seat_map, axes, partners, chunks, index + 1, collected, meta, resolution_key)

func _bill_party_lines(seat_map: Dictionary, axes: Dictionary, partners: Array) -> Array:
	var lines: Array = []
	for key in seat_map.keys():
		var seats := int(seat_map[key])
		if seats <= 0:
			continue
		lines.append("%s: %d cadeiras, eixo %.2f, %s" % [
			str(key), seats, float(axes.get(str(key), 0.0)),
			"aliado" if partners.has(str(key)) else "oposição",
		])
	return lines

## Resultado da votação: aplicado uma única vez, venha da IA, do cache ou do fallback.
func _on_bill_votes(result: Dictionary, bill: Dictionary, seat_map: Dictionary) -> void:
	_bill_in_progress = false
	_hide_ai_wait()
	var resolution_key := str(result.get("key", ""))
	if resolution_key != "" and str(state.get("bill_resolution", "")) == resolution_key:
		return
	if resolution_key != "":
		state["bill_resolution"] = resolution_key
	var cost := int(bill.get("cost", 0))
	var value: Dictionary = result.get("value", {})
	var votes: Dictionary = value.get("votes", {}) if value.get("votes") is Dictionary else {}
	# Bancada sem resposta da IA (bloco que caiu no fallback) é votada pelo
	# motor determinístico, para a apuração nunca sair incompleta.
	var country_vote := _country_by_id(str(state.country_id))
	var engine_vote := Contracts.fallback_legislative(
		bill, seat_map, Election.axes(state, country_vote),
		state.get("coalition_partners", []) if state.get("coalition_partners") is Array else [],
		float(state.cohesion)
	)
	var engine_votes: Dictionary = engine_vote.get("votes", {}) if engine_vote.get("votes") is Dictionary else {}
	for party in seat_map.keys():
		if int(seat_map[party]) > 0 and not votes.has(str(party)) and engine_votes.has(str(party)):
			votes[str(party)] = engine_votes[str(party)]
	var outcome := Contracts.votes_to_outcome(votes, seat_map)
	var approved := bool(outcome.get("approved", false))
	state.bills.push_front({
		"id": str(bill.get("id", "")), "title": str(bill.get("title", "")),
		"year": int(state.date_year), "month": int(state.date_month),
		"ayes": int(outcome.get("ayes", 0)), "nayes": int(outcome.get("nayes", 0)),
		"abstain": int(outcome.get("abstain", 0)), "approved": approved,
	})
	state.bills = state.bills.slice(0, 12)
	if approved:
		state.funds -= cost
		_apply_effects(bill.get("effects", {}))
		if not bool(state.government):
			state.credibility += 2
		state.news.push_front("%s aprovada: %s." % [str(bill.get("title", "Proposição")), Legislature.summary(outcome)])
	else:
		state.credibility += 1
		state.news.push_front("%s rejeitada no plenário: %s." % [str(bill.get("title", "Proposição")), Legislature.summary(outcome)])
	_clamp_state(); _save_game(); _show_game()
	_show_toast("Proposição aprovada" if approved else "Proposição rejeitada", "success" if approved else "error")

func _apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		match str(key):
			"economy": state.economy += float(effects[key])
			"approval": state.approval += float(effects[key])
			"debt": state.debt += float(effects[key])
			"unemployment": state.unemployment += float(effects[key])

func _formation_deal() -> Dictionary:
	var country := _country_by_id(str(state.country_id))
	var seat_map: Dictionary = {}
	if state.get("seat_map") is Dictionary:
		seat_map = state.seat_map
	if seat_map.is_empty():
		return {}
	return Coalition.minimum_winning(seat_map, Election.axes(state, country), str(state.abbr), int(state.majority))

func _formation_panel() -> PanelContainer:
	var deal := _formation_deal()
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("FORMAÇÃO DE GOVERNO", 12, AMBER))
	col.add_child(_label("Sua bancada tem %d de %d cadeiras; a maioria é %d." % [int(state.lower_house_seats), int(state.chamber_seats), int(state.majority)], 16, TEXT))
	if deal.is_empty():
		col.add_child(_label("Nenhuma coalizão mínima vencedora é possível com as bancadas atuais.", 14, MUTED))
	else:
		var partners := PackedStringArray(deal.get("partners", []))
		col.add_child(_label("Coalizão mínima: %s — %d de %d cadeiras." % [", ".join(partners), int(deal.get("seats", 0)), int(state.chamber_seats)], 15, TEXT))
		col.add_child(_label("Custo de negociação: M$ %s  ·  coesão esperada %.0f%%" % [_fmt_int(float(deal.get("cost", 0))), float(deal.get("cohesion", 0.0))], 13, MUTED))
		var accept := _button("FECHAR COALIZÃO", GREEN)
		accept.disabled = state.funds < float(deal.get("cost", 0))
		accept.pressed.connect(_accept_coalition)
		col.add_child(accept)
	panel.add_child(col)
	return panel

func _coalition_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("BASE DE GOVERNO", 12, CYAN))
	var partners: Array = []
	if state.get("coalition_partners") is Array:
		partners = state.coalition_partners
	var base_seats := int(state.get("coalition_seats", 0))
	if base_seats <= 0:
		base_seats = int(state.lower_house_seats)
	var partners_text := "bancada própria" if partners.is_empty() else ", ".join(PackedStringArray(partners))
	col.add_child(_label("%d de %d cadeiras  ·  %s" % [base_seats, int(state.chamber_seats), partners_text], 15, TEXT))
	col.add_child(_label("Coesão da base: %.0f%%" % float(state.get("coalition_cohesion", 60.0)), 13, MUTED))
	panel.add_child(col)
	return panel

func _accept_coalition() -> void:
	var deal := _formation_deal()
	if deal.is_empty():
		_show_toast("Sem coalizão viável", "warning")
		return
	var cost := int(deal.get("cost", 0))
	if state.funds < cost:
		_show_toast("Caixa insuficiente para a coalizão", "error")
		return
	state.funds -= cost
	state.government = true
	state.coalition_partners = deal.get("partners", [])
	state.coalition_seats = int(deal.get("seats", 0))
	state.coalition_cohesion = float(deal.get("cohesion", 60.0))
	state.news.push_front("Coalizão fechada com %s: %d de %d cadeiras." % [", ".join(PackedStringArray(deal.get("partners", []))), int(deal.get("seats", 0)), int(state.chamber_seats)])
	_clamp_state(); _save_game(); _show_game()
	_show_toast("Governo formado por coalizão", "success")

func _show_government() -> void:
	_show_section("Governo", "Governar é transformar promessas em capacidade de execução.")
	var country := _country_by_id(str(state.country_id))
	if not state.government:
		var empty := _panel_box()
		var col := VBoxContainer.new()
		col.add_child(_label("OPOSIÇÃO", 13, CYAN))
		col.add_child(_label("O governo ainda não é seu. A organização pode crescer na oposição e disputar o próximo ciclo.", 18, TEXT))
		col.add_child(_label("No presidencialismo é preciso vencer a eleição; no parlamentarismo, a bancada pode formar coalizão.", 14, MUTED))
		empty.add_child(col)
		main_column.add_child(empty)
		if Election.is_parliamentary(country) and int(state.lower_house_seats) > 0:
			main_column.add_child(_formation_panel())
			main_column.add_child(_censure_panel())
		_build_right_rail(); return
	var top := HBoxContainer.new()
	top.add_child(_metric_card("APROVAÇÃO", "%.0f%%" % state.approval, GREEN))
	top.add_child(_metric_card("DÍVIDA / PIB", "%.0f%%" % state.debt, AMBER))
	top.add_child(_metric_card("CAPACIDADE", "%.0f%%" % ((state.credibility + state.cohesion) / 2.0), CYAN))
	main_column.add_child(top)
	var cabinet := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("GABINETE", 12, AMBER))
	for ministry in ["Finanças", "Educação", "Saúde", "Infraestrutura"]:
		var row := HBoxContainer.new()
		row.add_child(_label(ministry, 15, TEXT))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(spacer)
		var b := _button("NOMEAR", CYAN, false)
		b.pressed.connect(_appoint_minister.bind(ministry))
		row.add_child(b)
		col.add_child(row)
	cabinet.add_child(col)
	main_column.add_child(cabinet)
	main_column.add_child(_coalition_panel())
	var policy := _panel_box()
	var pcol := VBoxContainer.new()
	pcol.add_child(_label("PROGRAMAS EXECUTIVOS", 12, CYAN))
	for pair in [["Pacto de empregos", "M$ 2.000  ·  desemprego -0,5 p.p.", "jobs"], ["Rede de escolas técnicas", "M$ 3.200  ·  produtividade +0,4", "schools"], ["Fundo de infraestrutura", "M$ 4.500  ·  apoio regional +3", "infra"]]:
		var b := _button(pair[0], TEXT, false)
		b.tooltip_text = pair[1]
		b.pressed.connect(_policy_action.bind(pair[2]))
		pcol.add_child(b)
	policy.add_child(pcol)
	main_column.add_child(policy)
	_build_right_rail()

func _appoint_minister(ministry: String) -> void:
	state.funds -= 350; state.credibility += 1; state.approval += 1; state.minister_index += 1
	state.news.push_front("%s nomeou um ministro com mandato de execução para %s." % [state.leader, ministry])
	_clamp_state(); _save_game(); _show_game()

func _policy_action(policy: String) -> void:
	var cost := 2000
	if policy == "schools": cost = 3200
	elif policy == "infra": cost = 4500
	if state.funds < cost:
		_show_toast("Orçamento insuficiente", "error")
		return
	state.funds -= cost
	if policy == "jobs": state.unemployment -= 0.5; state.approval += 2; state.demographics["Trabalhadores"] += 3
	elif policy == "schools": state.economy += 0.4; state.approval += 1; state.demographics["Jovens"] += 3
	else:
		for i in state.region_support.size(): state.region_support[i] += 0.4
		state.approval += 2; state.debt += 0.8
	state.policies.append(policy)
	state.news.push_front("O governo iniciou um programa com efeitos graduais e custo fiscal explícito.")
	_clamp_state(); _save_game(); _show_game()

func _show_economy() -> void:
	_show_section("Economia", "O que o país produz, quanto custa viver e como o emprego reage às suas decisões.")
	var growth := float(state.economy)
	var card := _panel_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var left := VBoxContainer.new()
	left.add_child(_label("CONJUNTURA  ·  %02d/%d" % [int(state.date_month), int(state.date_year)], 11, MUTED))
	left.add_child(_label("%+.1f%%" % growth, 44, GREEN if growth >= 2.0 else (AMBER if growth >= 0.0 else RED)))
	left.add_child(_label(_growth_label(growth), 16, TEXT))
	row.add_child(left)
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(_label("Inflação  %.1f%%     Desemprego  %.1f%%" % [state.inflation, state.unemployment], 14, MUTED))
	facts.add_child(_label("Dívida/PIB  %.0f%%     PIB (índice)  %.1f     Caixa  M$ %s" % [state.debt, state.gdp, _fmt_int(state.funds)], 14, MUTED))
	var reading_label := _label(_cycle_reading(), 14, TEXT)
	reading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_child(reading_label)
	row.add_child(facts)
	card.add_child(row)
	main_column.add_child(card)
	var chart := BOARD_SCRIPT.new()
	chart.custom_minimum_size = Vector2(0, 260)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_economy(state)
	main_column.add_child(chart)
	var leitura := _panel_box()
	var lcol := VBoxContainer.new()
	lcol.add_child(_label("COMO LER", 12, AMBER))
	var how_label := _label("Crescimento melhora caixa e apoio, mas programas públicos pressionam a dívida antes de gerar produtividade. A inflação reage à dívida e ao ritmo da economia; o desemprego segue o crescimento com defasagem.", 14, MUTED)
	how_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lcol.add_child(how_label)
	leitura.add_child(lcol)
	main_column.add_child(leitura)
	if bool(state.government):
		var policy := _panel_box()
		var pcol := VBoxContainer.new()
		pcol.add_child(_label("PROGRAMAS EXECUTIVOS", 12, CYAN))
		for pair in [["Pacto de empregos", "M$ 2.000  ·  desemprego -0,5 p.p.", "jobs"], ["Rede de escolas técnicas", "M$ 3.200  ·  produtividade +0,4", "schools"], ["Fundo de infraestrutura", "M$ 4.500  ·  apoio regional +3", "infra"]]:
			var b := _button(pair[0], TEXT, false)
			b.tooltip_text = pair[1]
			b.pressed.connect(_policy_action.bind(pair[2]))
			pcol.add_child(b)
		policy.add_child(pcol)
		main_column.add_child(policy)
	else:
		var note := _panel_box()
		var ncol := VBoxContainer.new()
		ncol.add_child(_label("SEM GOVERNO", 12, AMBER))
		var opposition_note := _label("Programas executivos ficam disponíveis ao assumir o governo; na oposição resta influenciar o debate e o orçamento pelo Congresso.", 14, MUTED)
		opposition_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ncol.add_child(opposition_note)
		note.add_child(ncol)
		main_column.add_child(note)
	_build_right_rail()

func _economy_point(source: Dictionary = {}) -> Dictionary:
	var data := state if source.is_empty() else source
	return {
		"year": int(data.get("date_year", 2027)),
		"month": int(data.get("date_month", 1)),
		"economy": float(data.get("economy", 0.0)),
		"inflation": float(data.get("inflation", 0.0)),
		"unemployment": float(data.get("unemployment", 0.0)),
	}

func _growth_label(growth: float) -> String:
	if growth >= 3.0:
		return "Crescimento forte"
	if growth >= 1.5:
		return "Crescimento moderado"
	if growth >= 0.0:
		return "Estagnação"
	return "Contração"

func _cycle_reading() -> String:
	var inflation_note := "inflação sob controle" if float(state.inflation) <= 4.5 else "inflação pressionando o custo de vida"
	var jobs_note := "emprego estável" if float(state.unemployment) <= 8.5 else "desemprego elevado"
	var debt_note := "dívida confortável" if float(state.debt) <= 65.0 else "dívida exigindo ajuste"
	return "%s com %s, %s e %s." % [_growth_label(float(state.economy)), inflation_note, jobs_note, debt_note]

func _show_population() -> void:
	_show_section("População", "A população não vota como um bloco único.")
	var panel := _panel_box(); var col := VBoxContainer.new()
	col.add_child(_label("GRUPOS DEMOGRÁFICOS  ·  apoio ao partido", 12, CYAN))
	for key in state.demographics.keys():
		var row := HBoxContainer.new(); row.add_child(_label(str(key), 15, TEXT)); var fill := ProgressBar.new(); fill.value = state.demographics[key]; fill.show_percentage = false; fill.custom_minimum_size = Vector2(280, 15); fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(fill); row.add_child(_label("%.0f%%" % state.demographics[key], 14, AMBER)); col.add_child(row)
	panel.add_child(col); main_column.add_child(panel)
	var social := _panel_box(); var scol := VBoxContainer.new(); scol.add_child(_label("INDICADORES SOCIAIS", 12, AMBER)); scol.add_child(_label("Pobreza  18,4%     Acesso à saúde  76%     Escolaridade  8,2 anos", 16, TEXT)); scol.add_child(_label("Mudanças são lentas: políticas precisam de financiamento e execução.", 14, MUTED)); social.add_child(scol); main_column.add_child(social)
	_build_right_rail()

func _show_regions() -> void:
	_show_section("Regiões", "Clique numa região para ver economia, problemas e apoio.")
	var split := HBoxContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map := BOARD_SCRIPT.new(); map.custom_minimum_size = Vector2(0, 430); map.size_flags_horizontal = Control.SIZE_EXPAND_FILL; map.set_map(state, regions); map.region_clicked.connect(_select_region); split.add_child(map)
	var detail := _panel_box(); detail.custom_minimum_size.x = 260; var col := VBoxContainer.new(); var r: Dictionary = regions[selected_region]
	col.add_child(_label("REGIÃO %02d" % (selected_region + 1), 12, AMBER)); col.add_child(_label(r.name, 24, TEXT)); col.add_child(_label(r.kind, 14, CYAN)); col.add_child(_rule()); col.add_child(_label("População  %.1f mi" % r.pop, 14, MUTED)); col.add_child(_label("Renda média  %d" % r.income, 14, MUTED)); col.add_child(_label("Desemprego  %.1f%%" % r.unemployment, 14, MUTED)); col.add_child(_label("Apoio  %.0f%%" % state.region_support[selected_region], 18, AMBER)); col.add_child(_label("Problema central", 12, AMBER)); col.add_child(_label(r.problem, 15, TEXT)); detail.add_child(col); split.add_child(detail); main_column.add_child(split)
	_build_right_rail()

func _select_region(index: int) -> void:
	selected_region = index
	_show_regions()

## Esta tela apenas exibe a decisão internacional já gerada na simulação.
## Nenhuma chamada de IA acontece ao abrir a aba.
func _show_international() -> void:
	_show_section("Internacional", "A leitura externa do ciclo, decidida durante a simulação do mês.")
	var data: Dictionary = state.get("international", {}) if state.get("international") is Dictionary else {}
	if data.is_empty():
		var empty := _panel_box()
		var empty_col := VBoxContainer.new()
		empty_col.add_child(_label("SEM LEITURA INTERNACIONAL", 12, AMBER))
		empty_col.add_child(_label("Nenhuma cena internacional foi gerada neste ciclo. Ela é resolvida durante o avanço do mês, com a IA local ou pelo fallback determinístico.", 15, MUTED))
		empty.add_child(empty_col)
		main_column.add_child(empty)
		_build_right_rail()
		return
	var event_card := _panel_box()
	var event_col := VBoxContainer.new()
	event_col.add_child(_label("CENA EXTERNA  ·  %02d/%d" % [int(data.get("month", 0)), int(data.get("year", 0))], 12, CYAN))
	event_col.add_child(_label(str(data.get("event", "Sem evento")), 22, TEXT))
	var impact := _label(str(data.get("impact", "Sem impacto registrado.")), 14, MUTED)
	impact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_col.add_child(impact)
	event_col.add_child(_label("Origem da decisão: %s" % ("modelo local" if str(data.get("source", "")) == "ollama" else ("cache" if str(data.get("source", "")) == "cache" else "fallback determinístico")), 12, AMBER))
	event_card.add_child(event_col)
	main_column.add_child(event_card)
	var reactions: Dictionary = data.get("reactions", {}) if data.get("reactions") is Dictionary else {}
	if not reactions.is_empty():
		var panel := _panel_box()
		var col := VBoxContainer.new()
		col.add_child(_label("REAÇÕES DAS BANCADAS", 12, AMBER))
		for key in reactions.keys():
			var reaction: Dictionary = reactions[key]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var chip := _label(str(key), 12, UI.axis_color(Election.ideology_axis(_party_ideology(str(key)))))
			chip.custom_minimum_size.x = 88
			row.add_child(chip)
			var support := float(reaction.get("support_change", 0.0))
			var cohesion := float(reaction.get("cohesion_change", 0.0))
			var numbers := _label("apoio %+.1f  ·  coesão %+.1f" % [support, cohesion], 13, GREEN if support >= 0.0 else RED)
			numbers.custom_minimum_size.x = 190
			row.add_child(numbers)
			var reason := _label(str(reaction.get("reason", "")), 13, MUTED)
			reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(reason)
			col.add_child(row)
		panel.add_child(col)
		main_column.add_child(panel)
	_build_right_rail()

func _diplomacy(country: String) -> void:
	state.funds -= 300; state.credibility += 1; state.news.push_front("Aurora abriu um canal diplomático com %s." % country); _clamp_state(); _save_game(); _show_game()

func _show_news() -> void:
	_show_section("Notícias", "O mundo reage às suas políticas. Leia antes de avançar o mês.")
	for item in state.news:
		var card := _panel_box(); var col := VBoxContainer.new(); col.add_child(_label("%02d  ·  %d/%02d/%d" % [state.news.find(item) + 1, 1, state.date_month, state.date_year], 12, AMBER)); col.add_child(_label(str(item), 16, TEXT)); card.add_child(col); main_column.add_child(card)
	_build_right_rail()

func _show_history() -> void:
	_show_section("História política", "O placar é o rastro de decisões, não só o resultado final.")
	var panel := _panel_box(); var col := VBoxContainer.new(); col.add_child(_label("LINHA DO TEMPO", 12, CYAN))
	if state.history.is_empty(): col.add_child(_label("Ainda não há eleições registradas. %s." % _next_election_label(), 16, MUTED))
	for item in state.history: col.add_child(_label("• " + str(item), 15, TEXT))
	panel.add_child(col); main_column.add_child(panel)
	_build_right_rail()

func _show_settings() -> void:
	_show_section("Configurações", "Salvamento local e recuperação da campanha.")
	var panel := _panel_box(); var col := VBoxContainer.new(); col.add_child(_label("DADOS DA CAMPANHA", 12, AMBER)); col.add_child(_label("Salvamento automático após decisões e avanço de mês.", 15, TEXT))
	var actions := HBoxContainer.new(); var save := _button("SALVAR AGORA", CYAN, false); save.pressed.connect(_manual_save); actions.add_child(save); var export_b := _button("EXPORTAR JSON", AMBER, false); export_b.pressed.connect(_export_data); actions.add_child(export_b); var import_b := _button("IMPORTAR JSON", TEXT, false); import_b.pressed.connect(_import_data); actions.add_child(import_b); col.add_child(actions); 	status_label = _label("Arquivo local: user://mandatia_save.json", 13, MUTED); col.add_child(status_label); panel.add_child(col); main_column.add_child(panel)
	var ai_panel := _panel_box()
	var ai_col := VBoxContainer.new()
	ai_col.add_child(_label("IA LOCAL", 12, AMBER))
	var available := ai != null and bool(ai.ai_available)
	ai_col.add_child(_label("Ollama em 127.0.0.1:11434  ·  modelo huihui_ai/qwen2.5-abliterate:3b", 14, TEXT))
	ai_col.add_child(_label("Estado: %s" % ("disponível" if available else "indisponível — o jogo usa o fallback determinístico"), 14, GREEN if available else MUTED))
	ai_col.add_child(_label("Sem IA o jogo continua 100%% funcional: votações, eleições e eventos seguem a regra do motor.", 13, MUTED))
	if ai != null:
		ai_col.add_child(_label("Log da sessão: %s" % str(ai.log_path()), 12, MUTED))
	ai_panel.add_child(ai_col)
	main_column.add_child(ai_panel)
	_build_right_rail()

func _advance_month() -> void:
	_sync_action_month()
	if _month_in_progress:
		_show_toast("O mês anterior ainda está sendo resolvido", "warning")
		return
	if int(state.months_to_election) <= 0:
		_show_toast("Eleição obrigatória: realize o pleito em Eleições", "warning")
		return
	if ai != null and ai.pending_count() > 0:
		_show_toast("Aguarde a decisão da IA em andamento", "warning")
		return
	_month_in_progress = true
	state.date_month += 1
	if state.date_month > 12: state.date_month = 1; state.date_year += 1
	state.months_to_election = maxi(0, int(state.months_to_election) - 1)
	state.term_months_served = int(state.term_months_served) + 1
	state.campaign_actions = 0
	state.opposition_actions = 0
	state.action_month = "%d-%02d" % [int(state.date_year), int(state.date_month)]
	state.popularity += _seat_bonus()
	if int(state.months_to_election) == 0:
		state.news.push_front("Mandato encerrado: a eleição está aberta e o pleito é obrigatório.")
	state.gdp += state.economy * 0.08
	var potential := 2.6 - maxf(0.0, float(state.debt) - 60.0) * 0.03 - maxf(0.0, float(state.inflation) - 4.0) * 0.12
	state.economy = clampf(float(state.economy) + (potential - float(state.economy)) * 0.12, -2.0, 6.0)
	state.inflation = clampf(state.inflation + (state.debt - 60.0) * 0.015 - (state.economy - 2.0) * 0.08, 1.5, 15.0)
	state.unemployment = clampf(state.unemployment - (state.economy - 2.0) * 0.05, 3.5, 18.0)
	var debt_delta := 0.1 if state.government and state.policies.size() > 0 else -0.1
	state.debt = clampf(state.debt + debt_delta, 20.0, 120.0)
	state.approval += (state.economy - 2.5) * 0.15 - (state.inflation - 4.0) * 0.12
	state.popularity += (state.approval - 45.0) * 0.025 + (state.credibility - 30.0) * 0.01
	state.recognition += 0.15
	for i in state.region_support.size(): state.region_support[i] += (state.popularity - state.region_support[i]) * 0.012
	_event_due = int(state.date_month) % 3 == 0
	_international_due = int(state.date_month) % 12 == 0
	state.economy_history.append(_economy_point())
	if state.economy_history.size() > 60:
		state.economy_history = state.economy_history.slice(state.economy_history.size() - 60, state.economy_history.size())
	if state.date_month == 6: state.news.push_front("Pesquisas apontam disputa aberta: regiões metropolitanas e rurais podem decidir a próxima eleição.")
	if state.date_month == 12: state.news.push_front("Ano eleitoral: urnas abertas em 8 regiões. Campanhas entram na reta final.")
	_resolve_month(_month_stamp())

func _month_stamp() -> String:
	return "%d-%02d" % [int(state.date_year), int(state.date_month)]

## O mês só é concluído uma vez: evento e cena internacional passam pela IA,
## com fallback determinístico, e o fechamento é idempotente pelo carimbo.
func _resolve_month(stamp: String) -> void:
	if _event_due:
		var prompt_ctx := {
			"pais": str(state.country_name),
			"governo": "governo" if bool(state.government) else "oposição",
			"aprovacao": float(state.approval),
			"popularidade": float(state.popularity),
			"mes": int(state.date_month),
			"ano": int(state.date_year),
		}
		var meta := {"month": int(state.date_month), "year": int(state.date_year), "country": str(state.country_id)}
		var data := {"entities": ["evento", str(state.country_id)]}
		var op_id: String = ai.request(Contracts.EVENTS, prompt_ctx, data, meta, _on_month_event.bind(stamp))
		if ai.is_pending(op_id):
			_show_ai_wait("A conjuntura do mês está sendo resolvida...", op_id)
		return
	_after_month_event(stamp)

func _on_month_event(result: Dictionary, stamp: String) -> void:
	if str(state.get("month_completed", "")) == stamp:
		return
	_hide_ai_wait()
	var value: Dictionary = result.get("value", {})
	_apply_month_event(value)
	_after_month_event(stamp)

func _apply_month_event(value: Dictionary) -> void:
	var headline := str(value.get("headline", "")).strip_edges()
	var effects: Variant = value.get("effects", {})
	if headline == "":
		headline = ["Uma greve nacional pede reajuste acima da inflação.", "Uma seca ameaça a produção agrícola do país.", "Uma empresa anuncia investimento bilionário e pede incentivos fiscais."][randi() % 3]
	state.event = headline
	state.news.push_front(headline)
	if effects is Dictionary and not (effects as Dictionary).is_empty():
		_apply_ai_effects(effects, "evento")
		state["event_effects_applied"] = true

func _apply_ai_effects(effects: Dictionary, source: String) -> void:
	state.approval += float(effects.get("approval", 0.0))
	state.popularity += float(effects.get("popularity", 0.0))
	state.funds += float(effects.get("funds", 0.0))
	state.debt += float(effects.get("debt", 0.0))
	state.news.push_front("Efeitos do %s aplicados uma única vez: aprovação %+.1f, popularidade %+.1f, caixa %+.0f, dívida %+.2f p.p." % [
		source, float(effects.get("approval", 0.0)), float(effects.get("popularity", 0.0)),
		float(effects.get("funds", 0.0)), float(effects.get("debt", 0.0)),
	])

func _after_month_event(stamp: String) -> void:
	if _international_due:
		_international_due = false
		var party_ids: Array = []
		var seat_map: Dictionary = state.get("seat_map", {}) if state.get("seat_map") is Dictionary else {}
		for key in seat_map.keys():
			if int(seat_map[key]) > 0:
				party_ids.append(str(key))
		if not party_ids.is_empty():
			var prompt_ctx := {
				"pais": str(state.country_name),
				"governo": "governo" if bool(state.government) else "oposição",
				"bancadas": party_ids,
				"ids_permitidos": party_ids,
				"mes": int(state.date_month),
				"ano": int(state.date_year),
			}
			var meta := {"month": int(state.date_month), "year": int(state.date_year), "country": str(state.country_id)}
			var data := {"party_ids": party_ids, "entities": party_ids}
			var op_id: String = ai.request(Contracts.INTERNATIONAL, prompt_ctx, data, meta, _on_month_international.bind(stamp))
			if ai.is_pending(op_id):
				_show_ai_wait("A cena internacional está sendo lida...", op_id)
			return
	_complete_month(stamp)

## A cena internacional é gerada na simulação e apenas exibida na tela.
func _on_month_international(result: Dictionary, stamp: String) -> void:
	if str(state.get("month_completed", "")) == stamp:
		return
	_hide_ai_wait()
	var value: Dictionary = result.get("value", {})
	var international: Dictionary = value.get("international", {}) if value.get("international") is Dictionary else {}
	var reactions: Dictionary = value.get("reactions", {}) if value.get("reactions") is Dictionary else {}
	state["international"] = {
		"year": int(state.date_year),
		"month": int(state.date_month),
		"event": str(international.get("event", "")),
		"impact": str(international.get("impact", "")),
		"reactions": reactions,
		"source": str(result.get("source", "")),
	}
	if str(international.get("event", "")) != "":
		state.news.push_front("Internacional: " + str(international.get("event", "")))
	_apply_international_reactions(reactions)
	_complete_month(stamp)

func _apply_international_reactions(reactions: Dictionary) -> void:
	if reactions.is_empty():
		return
	var partners: Array = state.get("coalition_partners", []) if state.get("coalition_partners") is Array else []
	for key in reactions.keys():
		var reaction: Dictionary = reactions[key]
		var support := float(reaction.get("support_change", 0.0))
		var cohesion := float(reaction.get("cohesion_change", 0.0))
		if partners.has(str(key)):
			state.coalition_cohesion = clampf(float(state.get("coalition_cohesion", 60.0)) + support * 0.5, 10.0, 100.0)
		state.cohesion = clampf(float(state.cohesion) + cohesion * 0.2, 10.0, 100.0)

func _complete_month(stamp: String) -> void:
	if str(state.get("month_completed", "")) == stamp:
		_month_in_progress = false
		return
	state["month_completed"] = stamp
	_month_in_progress = false
	_clamp_state(); _save_game(); _show_game()

func _show_ai_wait(message: String, op_id: String) -> void:
	_hide_ai_wait()
	if not is_instance_valid(root_stack):
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL_2, AMBER, 8, 2))
	panel.position = Vector2(28, 84)
	panel.custom_minimum_size.x = 420
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(_label("IA LOCAL  ·  huihui_ai/qwen2.5-abliterate:3b", 11, AMBER))
	col.add_child(_label(message, 15, TEXT))
	var row := HBoxContainer.new()
	var note := _label("2 tentativas · 20 s cada · fallback pronto", 11, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	var skip := _button("RESOLVER SEM IA", MUTED, false)
	skip.pressed.connect(func() -> void:
		if ai != null:
			ai.cancel(op_id)
		_hide_ai_wait())
	row.add_child(skip)
	col.add_child(row)
	panel.add_child(col)
	root_stack.add_child(panel)
	ai_wait_panel = panel

func _hide_ai_wait() -> void:
	if is_instance_valid(ai_wait_panel):
		ai_wait_panel.queue_free()
	ai_wait_panel = null

func _update_header() -> void:
	if not is_instance_valid(header_date): return
	header_date.text = "%s  ·  %02d/%d" % ["GOVERNO" if state.government else "OPOSIÇÃO", state.date_month, state.date_year]
	if is_instance_valid(month_button):
		var pending := int(state.months_to_election) <= 0
		month_button.disabled = pending
		month_button.text = "ELEIÇÃO OBRIGATÓRIA" if pending else "AVANÇAR MÊS  ›"
	header_party.text = "%s  ·  %s" % [state.country_name, state.abbr]
	header_position.text = _government_role() if state.government else "LÍDER DA OPOSIÇÃO"
	header_funds.text = "M$ %s" % _fmt_int(state.funds)

func _clamp_state() -> void:
	state.popularity = clampf(state.popularity, 5.0, 85.0); state.approval = clampf(state.approval, 5.0, 90.0); state.recognition = clampf(state.recognition, 5.0, 95.0); state.credibility = clampf(state.credibility, 5.0, 90.0); state.cohesion = clampf(state.cohesion, 10.0, 100.0); state.funds = maxf(0.0, state.funds)
	for i in state.region_support.size(): state.region_support[i] = clampf(state.region_support[i], 5.0, 90.0)
	for key in state.demographics.keys(): state.demographics[key] = clampf(state.demographics[key], 5.0, 90.0)

func _seat_bonus() -> float:
	if int(state.chamber_seats) <= 0:
		return 0.0
	var share := float(state.lower_house_seats) / float(state.chamber_seats) * 100.0
	return clampf((share - 5.0) * 0.02, 0.0, 0.6)

func _next_election_label() -> String:
	if int(state.months_to_election) <= 0:
		return "Eleição aberta · pleito obrigatório"
	return "Eleição em %d meses" % int(state.months_to_election)

func _sync_action_month() -> void:
	var stamp := "%d-%02d" % [int(state.date_year), int(state.date_month)]
	if str(state.get("action_month", "")) != stamp:
		state.action_month = stamp
		state.campaign_actions = 0
		state.opposition_actions = 0

func _month_action_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("AÇÃO DO MÊS", 12, CYAN))
	if bool(state.government):
		col.add_child(_label("Governo: programas executivos ficam em Governo; a conjuntura, em Economia.", 13, MUTED))
	else:
		_sync_action_month()
		col.add_child(_label("Oposição ativa: M$ %d por +1,5 de popularidade e +1 de reconhecimento, uma vez por mês." % OPPOSITION_ACTION_COST, 14, TEXT))
		var b := _button("FAZER OPOSIÇÃO ATIVA", AMBER)
		b.disabled = int(state.opposition_actions) >= 1 or float(state.funds) < OPPOSITION_ACTION_COST
		b.pressed.connect(_opposition_action)
		col.add_child(b)
	panel.add_child(col)
	return panel

func _free_campaign_action() -> void:
	_sync_action_month()
	if int(state.campaign_actions) >= CAMPAIGN_ACTIONS_PER_MONTH:
		_show_toast("Limite de %d ações de campanha neste mês" % CAMPAIGN_ACTIONS_PER_MONTH, "warning")
		return
	state.campaign_actions = int(state.campaign_actions) + 1
	state.popularity += 0.5
	state.recognition += 0.2
	state.campaign += 1
	state.news.push_front("Militância de base levou o partido às ruas sem custo de caixa.")
	_clamp_state(); _save_game(); _show_game()

func _opposition_action() -> void:
	_sync_action_month()
	if int(state.opposition_actions) >= 1:
		_show_toast("Você já fez a ação de oposição deste mês", "warning")
		return
	if float(state.funds) < OPPOSITION_ACTION_COST:
		_show_toast("Caixa insuficiente", "error")
		return
	state.funds -= OPPOSITION_ACTION_COST
	state.opposition_actions = 1
	state.popularity += 1.5
	state.recognition += 1.0
	state.news.push_front("A oposição levou o debate às ruas e ganhou espaço no noticiário.")
	_clamp_state(); _save_game(); _show_game()

func _promise_axis() -> String:
	var axis := Election.ideology_axis(str(state.get("ideology", "Centro")))
	if axis <= -0.35:
		return "left"
	if axis >= 0.35:
		return "right"
	return "center"

func _promise_pool() -> Array:
	var pools := {
		"left": [
			["unemployment", "max", -1.2, "Reduzir o desemprego para %.1f%%"],
			["approval", "min", 6.0, "Elevar a aprovação a %.0f%%"],
			["economy", "min", 0.6, "Fazer a economia crescer %.1f%%"],
			["debt", "max", 2.0, "Manter a dívida abaixo de %.0f%% do PIB"],
			["funds", "min", 4000.0, "Fechar o mandato com M$ %d em caixa"],
			["recognition", "min", 8.0, "Alcançar %.0f%% de reconhecimento"],
		],
		"center": [
			["unemployment", "max", -0.8, "Baixar o desemprego para %.1f%%"],
			["approval", "min", 5.0, "Sustentar aprovação de %.0f%%"],
			["economy", "min", 0.4, "Crescer %.1f%% ao ano"],
			["debt", "max", 0.0, "Não deixar a dívida passar de %.0f%% do PIB"],
			["funds", "min", 3000.0, "Entregar o mandato com M$ %d em caixa"],
			["recognition", "min", 6.0, "Chegar a %.0f%% de reconhecimento"],
		],
		"right": [
			["debt", "max", -1.0, "Reduzir a dívida para %.0f%% do PIB"],
			["economy", "min", 0.5, "Crescer %.1f%% com ajuste fiscal"],
			["approval", "min", 4.0, "Manter aprovação em %.0f%%"],
			["unemployment", "max", -0.6, "Reduzir o desemprego a %.1f%%"],
			["funds", "min", 5000.0, "Fechar o mandato com M$ %d em caixa"],
			["recognition", "min", 6.0, "Alcançar %.0f%% de reconhecimento"],
		],
	}
	return pools.get(_promise_axis(), pools["center"])

func _promise_text(metric: String, label: String, target: float) -> String:
	if metric == "funds":
		return label % int(target)
	return label % target

func _promise_choices() -> Array:
	var out: Array = []
	for spec in _promise_pool():
		var metric := str(spec[0])
		var mode := str(spec[1])
		var current := float(state.get(metric, 0.0))
		var target := current + float(spec[2])
		if metric != "funds" and metric != "economy":
			target = clampf(target, 0.0, 100.0)
		else:
			target = maxf(0.0, target)
		out.append({"metric": metric, "mode": mode, "target": target, "text": _promise_text(metric, str(spec[3]), target)})
	return out

func _show_promises() -> void:
	screen = "promises"
	state.promises = []
	_clear_root()
	promise_checks = []
	promise_options = _promise_choices()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_stack.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	box.add_child(_label("PROGRAMA DE GOVERNO  ·  %s" % str(state.abbr), 13, AMBER))
	box.add_child(_label("Escolha três compromissos", 34, TEXT))
	var intro := _label("O mandato será cobrado no fim: cada promessa cumprida rende aprovação; cada promessa esquecida cobra o preço.", 15, MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	box.add_child(_rule())
	var counter := _label("0 de 3 selecionadas", 13, MUTED)
	for choice in promise_options:
		var base_text := str(choice.get("text", ""))
		var check := _button("    " + base_text, TEXT, false)
		check.toggle_mode = true
		check.alignment = HORIZONTAL_ALIGNMENT_LEFT
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.custom_minimum_size = Vector2(700, 42)
		check.toggled.connect(func(pressed: bool) -> void:
			check.text = ("»  " if pressed else "    ") + base_text
			check.add_theme_color_override("font_color", AMBER if pressed else TEXT)
			_on_promise_toggled(check, pressed, counter))
		box.add_child(check)
		promise_checks.append(check)
	box.add_child(counter)
	promise_confirm = _button("CONFIRMAR PROGRAMA", GREEN)
	promise_confirm.disabled = true
	promise_confirm.pressed.connect(_confirm_promises)
	box.add_child(promise_confirm)

func _on_promise_toggled(check: CheckBox, pressed: bool, counter: Label) -> void:
	var selected := 0
	for item in promise_checks:
		if item.button_pressed:
			selected += 1
	if selected > 3:
		check.set_pressed_no_signal(false)
		selected = 3
		_show_toast("Escolha apenas três compromissos", "warning")
	counter.text = "%d de 3 selecionadas" % selected
	promise_confirm.disabled = selected != 3

func _confirm_promises() -> void:
	var chosen: Array = []
	for index in promise_checks.size():
		if promise_checks[index].button_pressed:
			chosen.append(promise_options[index])
	if chosen.size() != 3:
		_show_toast("Escolha exatamente três compromissos", "warning")
		return
	state.promises = chosen
	state.months_to_election = TERM_MONTHS if bool(state.government) else FIRST_CAMPAIGN_MONTHS
	_save_game()
	_show_game()

func _auto_pick_promises() -> void:
	state.promises = _promise_choices().slice(0, 3)
	state.months_to_election = TERM_MONTHS if bool(state.government) else FIRST_CAMPAIGN_MONTHS
	_save_game()
	_show_game()

func _evaluate_promises() -> Dictionary:
	var details: Array = []
	var fulfilled := 0
	for promise in state.promises:
		var metric := str(promise.get("metric", ""))
		var target := float(promise.get("target", 0.0))
		var value := float(state.get(metric, 0.0))
		var ok := value <= target if str(promise.get("mode", "min")) == "max" else value >= target
		if ok:
			fulfilled += 1
		details.append({"text": str(promise.get("text", "")), "fulfilled": ok, "value": value, "target": target})
	var total := details.size()
	if total > 0:
		state.approval += fulfilled * 3.0 - (total - fulfilled) * 2.0
	return {"fulfilled": fulfilled, "total": total, "details": details}

func _show_result() -> void:
	screen = "result"
	_clear_root()
	var result: Dictionary = state.get("last_result", {})
	var won := bool(result.get("won", false))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	root_stack.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_label("RESULTADO DO MANDATO  ·  %d" % int(result.get("year", state.date_year)), 13, AMBER))
	box.add_child(_label("Governo mantido" if won else "Derrota eleitoral", 40, GREEN if won else RED))
	var line := _label("%d de %d cadeiras na câmara  ·  maioria de %d  ·  %d meses de ciclo" % [int(result.get("player_seats", 0)), int(result.get("seats", 0)), int(result.get("majority", 0)), int(result.get("term_months", TERM_MONTHS))], 16, MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	metrics.add_child(_metric_card("APROVAÇÃO FINAL", "%.0f%%" % float(result.get("approval", 0.0)), GREEN))
	metrics.add_child(_metric_card("DÍVIDA / PIB", "%.0f%%" % float(result.get("debt", 0.0)), AMBER))
	metrics.add_child(_metric_card("LEIS APROVADAS", str(int(result.get("laws", 0))), CYAN))
	metrics.add_child(_metric_card("PROMESSAS", "%d de %d" % [int(result.get("fulfilled", 0)), int(result.get("promise_total", 0))], GREEN if int(result.get("fulfilled", 0)) > 0 else RED))
	box.add_child(metrics)
	box.add_child(_rule())
	box.add_child(_label("PROGRAMA DE GOVERNO", 12, CYAN))
	for detail in result.get("promises", []):
		var ok := bool(detail.get("fulfilled", false))
		var row := _label("%s  %s" % ["cumprida" if ok else "não cumprida", str(detail.get("text", ""))], 15, GREEN if ok else RED)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(row)
	if result.get("promises", []).is_empty():
		box.add_child(_label("Nenhum compromisso registrado neste mandato.", 14, MUTED))
	box.add_child(_spacer(12))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var next := _button("ESCOLHER NOVO PROGRAMA", GREEN)
	next.pressed.connect(_show_promises)
	actions.add_child(next)
	var menu := _button("MENU PRINCIPAL", MUTED, false)
	menu.pressed.connect(_show_menu)
	actions.add_child(menu)
	box.add_child(actions)

func _censure_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("MOÇÃO DE CENSURA", 12, RED))
	var reasons: Array = []
	if int(state.term_months_served) < 8:
		reasons.append("só a partir do 8º mês de mandato")
	if float(state.approval) > 30.0:
		reasons.append("exige aprovação do governo ≤ 30%")
	if float(state.funds) < CENSURE_COST:
		reasons.append("custa M$ %d" % CENSURE_COST)
	if float(state.credibility) < CENSURE_CREDIBILITY:
		reasons.append("exige %.0f de credibilidade" % CENSURE_CREDIBILITY)
	if int(state.lower_house_seats) <= 0:
		reasons.append("sem bancada para sustentar a moção")
	col.add_child(_label("A oposição pode derrubar o governo quando ele sangra. Errar a conta custa caro.", 14, MUTED))
	if reasons.is_empty():
		col.add_child(_label("Custo: M$ %d e %.0f de credibilidade. Passa se as bancadas fora do governo somarem maioria." % [CENSURE_COST, CENSURE_CREDIBILITY], 13, MUTED))
		var b := _button("APRESENTAR MOÇÃO", RED)
		b.pressed.connect(_motion_of_censure)
		col.add_child(b)
	else:
		col.add_child(_label("Indisponível: " + ", ".join(PackedStringArray(reasons)), 13, MUTED))
	panel.add_child(col)
	return panel

func _motion_of_censure() -> void:
	if int(state.term_months_served) < 8 or float(state.approval) > 30.0:
		_show_toast("A moção ainda não tem condições políticas", "warning")
		return
	if float(state.funds) < CENSURE_COST or float(state.credibility) < CENSURE_CREDIBILITY:
		_show_toast("Caixa ou credibilidade insuficientes", "error")
		return
	state.funds -= CENSURE_COST
	state.credibility -= CENSURE_CREDIBILITY
	var seat_map: Dictionary = state.get("seat_map", {})
	var government_seats := int(seat_map.get(Election.largest_party(seat_map), 0))
	var outside := 0
	for key in seat_map.keys():
		outside += int(seat_map[key])
	outside -= government_seats
	if outside >= int(state.majority):
		state.government = true
		state.coalition_partners = []
		state.coalition_seats = outside
		state.coalition_cohesion = float(state.cohesion)
		state.approval = 50.0
		state.news.push_front("Moção de censura aprovada: a oposição assume o governo com %d de %d cadeiras." % [outside, int(state.chamber_seats)])
		_show_toast("Governo derrubado: você assume", "success")
	else:
		state.popularity -= 6.0
		state.approval += 3.0
		state.news.push_front("Moção de censura rejeitada: o governo ganha fôlego e a oposição paga o custo.")
		_show_toast("Moção rejeitada", "error")
	_clamp_state(); _save_game(); _show_game()

func _show_toast(message: String, kind := "info") -> void:
	if is_instance_valid(toast): toast.queue_free()
	var color := CYAN
	if kind == "success":
		color = GREEN
	elif kind == "error":
		color = RED
	elif kind == "warning":
		color = AMBER
	toast = _label(message, 15, TEXT)
	toast.custom_minimum_size.x = 240
	toast.position = Vector2(28, size.y - 58)
	toast.add_theme_stylebox_override("normal", _style(PANEL_2, color, 6, 2))
	root_stack.add_child(toast)
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(toast): toast.queue_free())

func _apply_responsive() -> void:
	var width := size.x
	if is_instance_valid(right_column):
		right_column.visible = width >= UI.RAIL_BREAKPOINT
	if is_instance_valid(sidebar):
		var sidebar_width := float(UI.SIDEBAR_WIDE if width >= UI.SIDEBAR_BREAKPOINT else UI.SIDEBAR_NARROW)
		sidebar.custom_minimum_size.x = sidebar_width
		if is_instance_valid(sidebar_plate):
			sidebar_plate.custom_minimum_size.x = sidebar_width
	if is_instance_valid(header_position):
		header_position.visible = width >= 900
	if is_instance_valid(month_button):
		if int(state.months_to_election) <= 0:
			month_button.text = "ELEIÇÃO OBRIGATÓRIA"
			month_button.disabled = true
		else:
			month_button.text = "AVANÇAR MÊS  ›" if width >= 900 else "AVANÇAR ›"
			month_button.disabled = false
	for stat in header_stats:
		if is_instance_valid(stat):
			stat.visible = width >= UI.PAD_BREAKPOINT
	if is_instance_valid(main_margin):
		var pad := 22 if width >= UI.PAD_BREAKPOINT else 12
		var pad_y := 16 if width >= UI.PAD_BREAKPOINT else 10
		main_margin.add_theme_constant_override("margin_left", pad)
		main_margin.add_theme_constant_override("margin_right", pad)
		main_margin.add_theme_constant_override("margin_top", pad_y)
		main_margin.add_theme_constant_override("margin_bottom", pad_y)

func _manual_save() -> void:
	_save_game(); _show_toast("Campanha salva em user://mandatia_save.json", "success")

func _has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH) or FileAccess.file_exists(_legacy_save_absolute_path())

func _legacy_save_absolute_path() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join("Mandato — Poder e Política").path_join("mandato_save.json")

func _save_game() -> void:
	var user_dir := ProjectSettings.globalize_path("user://")
	if not DirAccess.dir_exists_absolute(user_dir):
		DirAccess.make_dir_recursive_absolute(user_dir)
	var payload := {"save_version": SAVE_VERSION, "state": state}
	var file := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("mandatia_save.json"):
		dir.remove("mandatia_save.json")
	if dir.rename("mandatia_save.tmp", "mandatia_save.json") == OK:
		return
	var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if direct == null:
		return
	direct.store_string(JSON.stringify(payload))
	direct.close()

func _load_game() -> void:
	if not _has_save():
		return
	var path := SAVE_PATH
	if not FileAccess.file_exists(path) and FileAccess.file_exists(LEGACY_SAVE_PATH):
		path = LEGACY_SAVE_PATH
	elif not FileAccess.file_exists(path) and FileAccess.file_exists(_legacy_save_absolute_path()):
		path = _legacy_save_absolute_path()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if data.get("state") is Dictionary:
		data = data.get("state")
	var migrated := _migrate_state(data)
	if migrated.is_empty():
		return
	state = migrated
	_ensure_chamber_state()

func _migrate_state(raw: Dictionary) -> Dictionary:
	for key in SAVE_REQUIRED_KEYS:
		if not raw.has(key):
			return {}
	var result := _default_state()
	for key in raw.keys():
		result[key] = raw[key]
	result["started"] = bool(result.get("started", false))
	result["date_year"] = int(result.get("date_year", 2027))
	result["date_month"] = clampi(int(result.get("date_month", 1)), 1, 12)
	var support: Variant = result.get("region_support", [])
	if not (support is Array) or support.size() != 8:
		return {}
	if not (result.get("history") is Array):
		result["history"] = []
	if not (result.get("news") is Array):
		result["news"] = []
	if not (result.get("demographics") is Dictionary):
		result["demographics"] = _default_state()["demographics"]
	if not (result.get("seat_map") is Dictionary):
		result["seat_map"] = {}
	if not (result.get("last_election") is Dictionary):
		result["last_election"] = {}
	if not (result.get("coalition_partners") is Array):
		result["coalition_partners"] = []
	if not (result.get("bills") is Array):
		result["bills"] = []
	if not (result.get("economy_history") is Array):
		result["economy_history"] = [_economy_point(result)]
	if not raw.has("months_to_election"):
		result["months_to_election"] = FIRST_CAMPAIGN_MONTHS
	result["save_version"] = SAVE_VERSION
	return result

func _starting_seat_map(country: Dictionary) -> Dictionary:
	var map := {}
	var assigned := 0
	for party in country.get("official_parties", []):
		var key := str(party.get("abbr", "")).strip_edges()
		if key == "":
			continue
		var seats: Variant = party.get("lower_house_seats", null)
		var count := int(seats) if seats != null else 0
		map[key] = int(map.get(key, 0)) + count
		assigned += count
	if not map.has(str(state.abbr)):
		map[str(state.abbr)] = int(state.lower_house_seats)
		assigned += int(state.lower_house_seats)
	var total := Election.chamber_seats(country)
	if total > assigned:
		map["Não atribuídas"] = total - assigned
	return map

func _ensure_chamber_state() -> void:
	var country := _country_by_id(str(state.get("country_id", "BR")))
	var seat_map: Dictionary = {}
	if state.get("seat_map") is Dictionary:
		seat_map = state.seat_map
	if int(state.get("chamber_seats", 0)) <= 0:
		state.chamber_name = Election.chamber_name(country)
		state.chamber_seats = Election.chamber_seats(country)
		if int(state.chamber_seats) <= 0:
			var snapshot_total := 0
			for value in seat_map.values():
				snapshot_total += int(value)
			state.chamber_seats = snapshot_total
		if str(state.chamber_name) == "":
			state.chamber_name = "Câmara baixa"
		state.majority = Election.majority_of(int(state.chamber_seats))
	var assigned := 0
	for value in seat_map.values():
		assigned += int(value)
	if not seat_map.is_empty() and assigned >= int(state.chamber_seats):
		return
	state.seat_map = _starting_seat_map(country)

func _government_role() -> String:
	if Election.is_parliamentary(_country_by_id(str(state.country_id))):
		return "PRIMEIRO-MINISTRO"
	return "PRESIDENTE"

func _export_data() -> void:
	var file := FileAccess.open("user://mandato_export.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(state, "  ")); file.close(); _show_toast("Exportado em user://mandato_export.json", "success")

func _import_data() -> void:
	var file := FileAccess.open("user://mandato_export.json", FileAccess.READ)
	if not file: _show_toast("Nenhum export encontrado", "error"); return
	var parsed = JSON.parse_string(file.get_as_text()); file.close()
	if not (parsed is Dictionary):
		_show_toast("Arquivo de campanha inválido", "error")
		return
	var data: Dictionary = parsed
	if data.get("state") is Dictionary:
		data = data.get("state")
	var migrated := _migrate_state(data)
	if migrated.is_empty():
		_show_toast("Arquivo de campanha inválido", "error")
		return
	state = migrated
	_ensure_chamber_state()
	_save_game(); _show_game(); _show_toast("Campanha importada", "success")

func _clear_column(column: VBoxContainer) -> void:
	if not is_instance_valid(column): return
	for child in column.get_children(): child.queue_free()

func _section_title(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_child(_label(title, 30, TEXT)); box.add_child(_label(subtitle, 14, MUTED)); return box

func _header_stat(caption: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(caption, 9, MUTED))
	box.add_child(_label(value, 13, color))
	return box

func _stability() -> float:
	return clampf(float(state.cohesion) * 0.6 + float(state.credibility) * 0.4, 0.0, 100.0)

func _constitutional_tension() -> float:
	var approval_gap := absf(50.0 - float(state.approval)) * 0.8
	var opposition := 0.0 if bool(state.government) else 14.0
	return clampf(approval_gap + opposition + (100.0 - float(state.cohesion)) * 0.3, 0.0, 100.0)

func _build_status_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 46
	panel.add_theme_stylebox_override("panel", _style(PANEL, LINE, 0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	for cell_data in [
		["APROVAÇÃO", "%.0f%%" % state.approval, GREEN],
		["ESTABILIDADE", "%d/100" % int(_stability()), CYAN],
		["TENSÃO CONSTITUCIONAL", "%d/100" % int(_constitutional_tension()), AMBER],
	]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_label(str(cell_data[0]), 10, MUTED))
		cell.add_child(_label(str(cell_data[1]), 15, cell_data[2]))
		row.add_child(cell)
	panel.add_child(row)
	return panel

func _party_name(abbr: String) -> String:
	if abbr == str(state.abbr):
		return str(state.party)
	var country := _country_by_id(str(state.country_id))
	for party in country.get("official_parties", []):
		if str(party.get("abbr", "")) == abbr:
			return str(party.get("name", abbr))
	return abbr

func _party_ideology(abbr: String) -> String:
	if abbr == str(state.abbr):
		return str(state.ideology)
	var country := _country_by_id(str(state.country_id))
	for party in country.get("official_parties", []):
		if str(party.get("abbr", "")) == abbr:
			return str(party.get("ideology", ""))
	return ""

func _party_role(abbr: String) -> String:
	if abbr == str(state.abbr):
		return "VOCÊ"
	var partners: Array = []
	if state.get("coalition_partners") is Array:
		partners = state.coalition_partners
	if partners.has(abbr):
		return "APOIO"
	return "OPOSIÇÃO"

func _badge(value: String, caption: String, width: int, color: Color) -> PanelContainer:
	var p := _panel_box()
	p.custom_minimum_size.x = width
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var main_text := _label(value, 30, color)
	main_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var caption_text := _label(caption, 10, MUTED)
	caption_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(main_text)
	col.add_child(caption_text)
	p.add_child(col)
	return p

func _initials(name: String) -> String:
	var words := name.strip_edges().split(" ", false)
	var result := ""
	for word in words:
		if result.length() >= 2:
			break
		result += word.substr(0, 1).to_upper()
	return result if result != "" else "—"

func _metric_card(caption: String, value: String, color: Color) -> PanelContainer:
	return UI.metric_card(caption, value, color)

func _panel_box() -> PanelContainer:
	return UI.panel()

func _style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	return UI.panel_style(bg, border, radius, width)

func _label(text: String, font_size: int, color: Color) -> Label:
	return UI.label(text, font_size, color)

func _button(text: String, color: Color, primary := true) -> Button:
	return UI.button(text, color, primary)

func _line(value: String) -> LineEdit:
	return UI.line(value)

func _add_field(form: GridContainer, caption: String, control: Control) -> Label:
	var lbl := _label(caption, 15, MUTED)
	form.add_child(lbl)
	form.add_child(control)
	return lbl

func _rule() -> ColorRect:
	var r := ColorRect.new(); r.color = LINE; r.custom_minimum_size.y = 1; return r

func _spacer(height: int) -> Control:
	var s := Control.new(); s.custom_minimum_size.y = height; return s

func _fmt_int(value: float) -> String:
	return str(int(value))
