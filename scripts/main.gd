extends Control

const BOARD_SCRIPT := preload("res://scripts/aurora_board.gd")
const Election := preload("res://scripts/sim/election.gd")
const Events := preload("res://scripts/sim/events.gd")
const Coalition := preload("res://scripts/sim/coalition.gd")
const Legislature := preload("res://scripts/sim/legislature.gd")
const Ideology := preload("res://scripts/sim/ideology_system.gd")
const SocialGroups := preload("res://scripts/sim/social_groups.gd")
const InterestGroups := preload("res://scripts/sim/interest_groups.gd")
const PoliticalRelations := preload("res://scripts/sim/political_relations.gd")
const Scandals := preload("res://scripts/sim/scandal_system.gd")
const CausalLog := preload("res://scripts/sim/causal_log.gd")
const CampaignSystem := preload("res://scripts/sim/campaign_system.gd")
const Government := preload("res://scripts/sim/government.gd")
const BudgetSystem := preload("res://scripts/sim/budget_system.gd")
const Taxation := preload("res://scripts/sim/taxation_system.gd")
const Ministries := preload("res://scripts/sim/ministry_system.gd")
const Projects := preload("res://scripts/sim/public_project_system.gd")
const Debt := preload("res://scripts/sim/debt_system.gd")
const PublicServices := preload("res://scripts/sim/public_services_system.gd")
const International := preload("res://scripts/sim/international_system.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const Military := preload("res://scripts/sim/military_system.gd")
const Conflict := preload("res://scripts/sim/conflict_system.gd")
const GlobalShock := preload("res://scripts/sim/global_shock_system.gd")
const Resources := preload("res://scripts/sim/strategic_resources.gd")
const E2GeopoliticsContract := preload("res://scripts/sim/e2_geopolitics_contract.gd")
const E2ForcedFlowsContract := preload("res://scripts/sim/e2_forced_flows_contract.gd")
const PhaseFInformation := preload("res://scripts/sim/phase_f_information.gd")
const Demography := preload("res://scripts/sim/demography_system.gd")
const PhaseGContract := preload("res://scripts/sim/phase_g_contract.gd")
const MacroLedgerContract := preload("res://scripts/sim/macro_ledger_contract.gd")
const IdeologyChart := preload("res://scripts/ui/ideology_chart.gd")
const AIClient := preload("res://scripts/ai/ollama_client.gd")
const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const COUNTRY_DATA_PATH := "res://config/countries.json"
const ECONOMY_DATA_PATH := "res://config/economy.json"
const ECONOMY_FIELDS := ["gdp_growth", "inflation", "unemployment", "debt"]
const TABULAR_FONT := "res://assets/template/fonts/ui_medium.tres"
## Onboarding: um cartão por tela, mostrado uma única vez (ver tutorial_seen).
const TUTORIAL_STEPS := [
	{"nav": "Visão geral", "title": "SEU QUARTEL-GENERAL", "message": "Aqui ficam as decisões do mês, a agenda e os sinais que movem a próxima eleição. Comece lendo a Agenda antes de avançar."},
	{"nav": "Meu partido", "title": "PARTIDO E BASE", "message": "Reconhecimento, coesão e membros definem seu alcance. Forme voluntários para crescer sem gastar caixa."},
	{"nav": "Eleições", "title": "CAMPANHA", "message": "Cada mês permite três ações de campanha. A pesquisa nacional vira cadeiras por D'Hondt; no presidencialismo há segundo turno."},
	{"nav": "Governo", "title": "COALIZÃO", "message": "Sem maioria própria, negocie parceiros. A coesão da coalizão cai todo mês e um parceiro pode abandonar o governo."},
	{"nav": "Congresso", "title": "PLENÁRIO", "message": "O voto é por bancada: ideologia, coalizão e custo político decidem. Leis constitucionais exigem 3/5 da câmara."},
	{"nav": "Governo", "title": "GABINETE E PROGRAMAS", "message": "Ministérios e programas executivos custam caixa e manutenção mensal, mas movem indicadores e grupos sociais."},
	{"nav": "Economia", "title": "INDICADORES", "message": "Crescimento, inflação, desemprego e dívida reagem às suas decisões. Cada país começa com um perfil econômico próprio e fonte declarada."},
	{"nav": "Visão geral", "title": "AVANÇAR O MÊS", "message": "O botão AVANÇAR fecha o mês, aplica a conjuntura e abre o relatório com o que mudou. A eleição é obrigatória quando o prazo chega a zero."},
]
const SAVE_PATH := "user://mandatia_save.json"
const SAVE_TMP := "user://mandatia_save.tmp"
const SAVE_BACKUP := "user://mandatia_save.bak"
const LEGACY_SAVE_PATH := "user://mandato_save.json"
const SAVE_VERSION := 6
const MINISTRIES := {
	"Finanças": {"cost": 600, "now": {"credibility": 2.0, "debt": -0.2}, "groups": {"Empreendedores": 2.0}, "desc": "credibilidade +2, dívida -0,2"},
	"Educação": {"cost": 600, "now": {"economy": 0.1}, "groups": {"Jovens": 3.0}, "desc": "crescimento +0,1, jovens +3"},
	"Saúde": {"cost": 600, "now": {"approval": 1.5}, "groups": {"Aposentados": 3.0}, "desc": "aprovação +1,5, aposentados +3"},
	"Infraestrutura": {"cost": 600, "now": {"economy": 0.15}, "groups": {}, "region": 0.6, "desc": "crescimento +0,15, apoio regional +0,6"},
}
const EFFECT_KEYS := ["economy", "approval", "debt", "unemployment", "inflation", "credibility", "cohesion", "popularity", "recognition"]
const PROGRAMS := {
	"jobs": {"label": "Pacto de empregos", "cost": 2000, "upkeep": 80, "now": {"unemployment": -0.5, "approval": 2.0}, "groups": {"Trabalhadores": 3.0}, "monthly": {"unemployment": -0.04}, "desc": "desemprego -0,5 p.p. agora e -0,04 por mês"},
	"schools": {"label": "Rede de escolas técnicas", "cost": 3200, "upkeep": 120, "now": {"economy": 0.4, "approval": 1.0}, "groups": {"Jovens": 3.0}, "monthly": {"economy": 0.02}, "desc": "crescimento +0,4 agora e +0,02 por mês"},
	"infra": {"label": "Fundo de infraestrutura", "cost": 4500, "upkeep": 160, "now": {"approval": 2.0, "debt": 0.8}, "groups": {}, "region": 0.4, "monthly": {"economy": 0.03}, "desc": "apoio regional +0,4 e crescimento +0,03 por mês"},
	"health": {"label": "Saúde da família", "cost": 3000, "upkeep": 110, "now": {"approval": 2.0}, "groups": {"Aposentados": 3.0}, "monthly": {"approval": 0.08}, "desc": "aprovação +0,08 por mês"},
	"rural": {"label": "Crédito rural", "cost": 2500, "upkeep": 90, "now": {"approval": 1.0}, "groups": {"Rurais": 4.0}, "monthly": {"inflation": -0.02}, "desc": "inflação -0,02 por mês"},
}
const TERM_MONTHS := 48
const FIRST_CAMPAIGN_MONTHS := 12
const CAMPAIGN_ACTIONS_PER_MONTH := 3
const OPPOSITION_ACTION_COST := 600
const CENSURE_COST := 3000
const CENSURE_CREDIBILITY := 10.0
const SAVE_REQUIRED_KEYS := ["party", "date_year", "date_month", "country_id", "region_support"]

const UI := preload("res://scripts/ui/mandato_theme.gd")
const FlagPainter := preload("res://scripts/ui/flag_painter.gd")
const GlobeView := preload("res://scripts/ui/globe_view.gd")
const NavIcon := preload("res://scripts/ui/nav_icon.gd")

## Itens administrativos: ficam ao pé da faixa contextual, fora da lista do grupo.
const ADMIN_ITEMS := ["Configurações"]

## Camada de cenário (B.8 / Etapa 5): globo desenhado atrás de todo o conteúdo.
## Desligar remove o cenário por completo, sem tocar no resto da interface.
const SHOW_GLOBE := true

## Macro-regiões de `config/countries.json` na ordem usada pelo marcador do globo.
const COUNTRY_REGIONS := ["América do Norte", "América Central", "Caribe", "América do Sul"]

## Largura da coluna de conteúdo da Visão geral (B.9, classe WIDE). Com 727 px o
## globo ficava 85,8% coberto pelos painéis; em 560 px a esfera expõe ~41% do disco
## na faixa entre os painéis e o rail, sem descer abaixo do mínimo real dos blocos
## (436 px em 1280). É a menor largura que devolve o globo à composição.
const DASHBOARD_WIDTH := 560

const BG := UI.BG
const SURFACE := UI.SURFACE
const SURFACE_RAISED := UI.SURFACE_RAISED
const SURFACE_HOVER := UI.SURFACE_HOVER
const PANEL := UI.PANEL
const PANEL_2 := UI.PANEL_2
const LINE := UI.LINE
const TEXT := UI.TEXT
const MUTED := UI.MUTED
const SUBTLE := UI.SUBTLE
const AMBER := UI.AMBER
const GREEN := UI.GREEN
const RED := UI.RED

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
var header_panel: Control
var header_leader: Control
var header_pills: Control
var header_capsules: Array = []
var month_button: Button
var month_report_panel: Control
var month_report_continue: Button
var report_blocked: Array = []
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
var economy_catalog: Dictionary = {}
var tutorial_callout: Control = null
var selected_country_id := "BR"
var world_region_filter := "Todas"
var world_region_options: Array = []
var news_outlet_filter := "Todos"
var news_category_filter := "Todas"
var news_status_filter := "Todos"
var news_query := ""
var news_outlet_select: OptionButton
var news_category_select: OptionButton
var news_status_select: OptionButton
var news_search: LineEdit
var file_dialog: FileDialog
var root_stack: Control
var globe_layer: Control
var globe_view
var sidebar: HBoxContainer
var sidebar_context: PanelContainer
var main_column: VBoxContainer
var right_column: VBoxContainer
var main_margin: MarginContainer
var sidebar_plate: PanelContainer
var header_stats: Array = []
var promise_checks: Array = []
var promise_options: Array = []
var promise_confirm: Button
var campaign_region_select: OptionButton
var campaign_group_select: OptionButton
var ai: Node
var ai_wait_panel: PanelContainer
var ai_wait_ops: Array = []
var _month_in_progress := false
var _bill_in_progress := false
var _election_in_progress := false
var _event_due := false
var _international_due := false
var _month_stamp_pending := ""
var _month_event_needed := false
var _month_event_done := true
var _month_intl_needed := false
var _month_intl_done := true
var _month_event_op := ""
var _month_intl_op := ""
## Indicadores no início do mês, para o relatório honesto de variação.
var _month_snapshot: Dictionary = {}

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
	_load_economy_catalog()
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

func _load_economy_catalog() -> void:
	economy_catalog = {}
	if not FileAccess.file_exists(ECONOMY_DATA_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_DATA_PATH))
	if parsed is Dictionary:
		economy_catalog = parsed.get("countries", {}) if parsed.get("countries") is Dictionary else {}

func _economy_profile(country_id: String) -> Dictionary:
	var profile: Variant = economy_catalog.get(country_id, {})
	return (profile as Dictionary).duplicate(true) if profile is Dictionary else {}

## O perfil histórico inicializa o país; a partir daí a simulação evolui sozinha.
func _apply_country_economy(country_id: String, reset_history := true) -> void:
	var profile := _economy_profile(country_id)
	if profile.is_empty():
		return
	state["economic_profile"] = profile
	for key in ECONOMY_FIELDS:
		var entry: Variant = profile.get(key, {})
		if not (entry is Dictionary):
			continue
		var value: Variant = entry.get("simulation_value", entry.get("value", null))
		if value != null:
			# O perfil usa o nome do indicador do WDI; o estado usa "economy".
			state["economy" if key == "gdp_growth" else key] = float(value)
	if reset_history:
		state["economy_history"] = [_economy_point()]

## B1-B6: inicializa os sistemas políticos novos para uma campanha nova.
func _init_political_state(country: Dictionary) -> void:
	Ideology.player_position(state)
	var positions := Ideology.positions(state, country)
	SocialGroups.init_state(state)
	InterestGroups.init_state(state)
	PoliticalRelations.init_state(state, positions)
	CampaignSystem.init_state(state)
	Scandals.ensure(state)
	CausalLog.ensure(state)
	Government.init_state(state)
	International.init_state(state, countries, economy_catalog)
	WorldSim.ensure(state, countries, economy_catalog)
	Military.ensure(state, countries, economy_catalog)
	Resources.ensure(state, str(state.get("country_id", "BR")))
	Conflict.ensure(state, countries)
	E2GeopoliticsContract.ensure(state)
	E2ForcedFlowsContract.ensure(state)
	GlobalShock.ensure(state)
	Demography.init_state(state, economy_catalog)
	PhaseGContract.ensure(state)
	PhaseFInformation.ensure(state)
	MacroLedgerContract.ensure(state)
	state["coalition_terms"] = []
	state["coalition_assignments"] = {}
	state["coalition_compliance"] = {}
	state["coalition_started"] = 0
	state["leadership_challenge"] = false

## Migração idempotente: saves v5 ganham os sistemas sem perder indicadores.
func _ensure_political_state() -> void:
	var country := _country_by_id(str(state.get("country_id", "BR")))
	Ideology.player_position(state)
	var positions := Ideology.positions(state, country)
	SocialGroups.ensure(state)
	InterestGroups.ensure(state)
	PoliticalRelations.ensure(state, positions)
	CampaignSystem.ensure(state)
	Scandals.ensure(state)
	CausalLog.ensure(state)
	Government.ensure(state)
	International.ensure(state, countries, economy_catalog)
	WorldSim.ensure(state, countries, economy_catalog)
	Military.ensure(state, countries, economy_catalog)
	Resources.ensure(state, str(state.get("country_id", "BR")))
	Conflict.ensure(state, countries)
	E2GeopoliticsContract.ensure(state)
	E2ForcedFlowsContract.ensure(state)
	GlobalShock.ensure(state)
	Demography.ensure(state, economy_catalog)
	PhaseGContract.ensure(state)
	PhaseFInformation.ensure(state)
	MacroLedgerContract.ensure(state)
	if not (state.get("coalition_assignments") is Dictionary):
		state["coalition_assignments"] = {}
	if not (state.get("coalition_compliance") is Dictionary):
		state["coalition_compliance"] = {}
	if not state.has("coalition_started"):
		state["coalition_started"] = int(state.get("date_year", 0)) * 12 + int(state.get("date_month", 1))
	if not (state.get("coalition_terms") is Array):
		state["coalition_terms"] = []
	if not (state.get("policy_log") is Array):
		state["policy_log"] = []

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
	_apply_country_economy("BR", true)

func _default_state() -> Dictionary:
	return {
		"started": false, "date_year": 2027, "date_month": 1, "party": "Partido do Jogador", "abbr": "PJ", "leader": "Líder do Partido", "ideology": "social-democrata", "scenario": "Novo movimento", "start_mode": "Partido criado do zero", "country_id": "BR", "country_name": "Brasil", "legislature": {}, "funds": 12400.0, "members": 0, "recognition": 2.0, "popularity": 4.0, "credibility": 31.0, "cohesion": 78.0, "approval": 42.0, "economy": 2.4, "inflation": 4.8, "unemployment": 8.2, "debt": 61.0, "gdp": 100.0, "congress": 0, "senate_seats": 0, "lower_house_seats": 0, "government": false, "coalition": 0, "campaign": 0, "minister_index": 0, "history": [], "news": ["A campanha começa sem país pré-definido: escolha uma democracia e construa sua força política."], "chamber_name": "", "chamber_seats": 0, "majority": 1, "seat_map": {}, "last_election": {}, 		"coalition_partners": [], "coalition_seats": 0, "coalition_cohesion": 60.0, "bills": [], "economy_history": [], "months_to_election": 0, "term_index": 0, "term_months_served": 0, "campaign_actions": 0, "opposition_actions": 0, "action_month": "", 		"promises": [], "last_result": {}, "event_effects_applied": false, "region_support": [4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0], "demographics": {"Jovens": 4.0, "Trabalhadores": 4.0, "Empreendedores": 4.0, "Aposentados": 4.0, "Rurais": 4.0}, "policies": [], "event": "", "event_id": "", "event_options": [], "event_recent": [], "ministers": [], 		"economic_profile": {}, "month_factors": [], "tutorial_seen": [], "tutorial_done": false,
		"ideology_position": {}, "social_groups": {}, "interest_groups": {}, "party_relations": {},
		"relation_history": [], "factions": [], "coalition_terms": [], "policy_log": [],
		"scandals": [], "scandal_history": [], "scandal_penalty": 0.0, "leadership_challenge": false,
		"causal_log": [], "strike_impact": 0.0, "coalition_stability": 60.0,
		"coalition_assignments": {}, "coalition_compliance": {}, "coalition_started": 0, "integrity_scar": 0,
		"campaign_finance": {}, "campaign_log": [], "campaign_penalty": 0.0,
		"social_support": 50.0, "income_support": 50.0,
		"treasury": 0.0, "budget": {}, "taxes": {}, "tax_revenue": {}, "tax_revenue_share": 0.0,
		"ministry_admin": {}, "projects": [], "project_opex": {}, "services": {},
			"service_index": 50.0, "debt_book": [], "debt_stats": {}, "debt_history": [], "international_state": {}, "world": {}, "demography": {}, "phase_g": {}, "macro_ledger": {},
		"admin_capacity": 50.0, "admin_performance": 50.0, "fiscal": {}, "fiscal_history": []}

func _build_shell() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Cenário: globo atrás de tudo, entre o fundo e o conteúdo. Vive no shell (não em
	# root_stack), então persiste entre telas e nunca entra na ordem de foco.
	globe_layer = Control.new()
	globe_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_layer.visible = false
	add_child(globe_layer)
	globe_view = GlobeView.new()
	globe_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe_view.background = true
	globe_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	globe_layer.add_child(globe_view)
	root_stack = Control.new()
	root_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_stack)

func _clear_root() -> void:
	month_report_panel = null
	month_report_continue = null
	tutorial_callout = null
	_release_focus_trap()
	for child in root_stack.get_children():
		child.queue_free()
	_refresh_globe()

## Opacidade do globo por tela (B.8.2): protagonista onde é cenário, atenuado onde
## há painel analítico, ausente onde o gráfico é o elemento principal da tela.
func _globe_opacity() -> float:
	if not SHOW_GLOBE:
		return 0.0
	if screen == "menu":
		return 0.35
	if screen != "game":
		return 0.0
	match selected_nav:
		"Visão geral", "Regiões", "Internacional":
			return 1.0
		"Economia", "População":
			return 0.35
	return 0.0

## Macro-região do país (0..3) apenas para posicionar o marcador do globo: o único
## dado geográfico do catálogo é `region`, e a posição no disco é constante visual.
func _country_region_index() -> int:
	var country := _country_by_id(str(state.get("country_id", "BR")))
	var index := COUNTRY_REGIONS.find(str(country.get("region", "")))
	return index if index >= 0 else 3

func _refresh_globe() -> void:
	if not is_instance_valid(globe_layer) or not is_instance_valid(globe_view):
		return
	var value := _globe_opacity()
	globe_layer.visible = value > 0.001
	if not globe_layer.visible:
		return
	globe_view.country_region = _country_region_index()
	globe_view.opacity = value

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
	var continue_button := _button("CONTINUAR CAMPANHA", SUBTLE)
	continue_button.disabled = not _has_save()
	continue_button.pressed.connect(_continue_game)
	box.add_child(continue_button)
	var hint := _label("Jogo desktop  ·  salvamento local  ·  português brasileiro", 13, MUTED)
	box.add_child(_spacer(22))
	box.add_child(hint)
	new_button.grab_focus()

func _show_new_game() -> void:
	screen = "new_game"
	_clear_root()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	root_stack.add_child(margin)
	# Em 1280×720 o formulário passa da altura: rolar acompanhando o foco evita
	# que INICIAR CAMPANHA fique abaixo da tela (beco sem saída para o teclado).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
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
	start.grab_focus()

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
	_apply_country_economy(str(state.country_id), true)
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
	_init_political_state(country)
	if not official_mode and state.scenario == "Oposição estabelecida":
		state.funds = 22000.0; state.recognition = 34.0; state.popularity = 34.0; state.members = 2400
	elif not official_mode and state.scenario == "Veterano político":
		state.funds = 31000.0; state.recognition = 48.0; state.popularity = 41.0; state.credibility = 50.0; state.members = 4800
	elif not official_mode and state.scenario == "Incumbente":
		state.funds = 18000.0; state.recognition = 62.0; state.popularity = 52.0; state.government = true; state.lower_house_seats = int(state.majority); state.congress = int(state.majority); state.members = 7400
	if not official_mode and bool(state.government):
		_install_incumbent_chamber(country)
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
	selected_group = _group_of(selected_nav)
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
	# AUTO e não DISABLED: com DISABLED o ScrollContainer propaga a largura mínima
	# do conteúdo e empurra o rail para fora da janela de 1280.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Foco precisa rolar para dentro da vista: com follow_focus desligado, setas
	# levavam o foco a botões abaixo da dobra que ficavam invisíveis.
	scroll.follow_focus = true
	scroll.add_child(main_margin)
	body.add_child(scroll)
	right_column = VBoxContainer.new()
	right_column.custom_minimum_size.x = UI.RAIL_WIDTH
	right_column.add_theme_constant_override("separation", 12)
	body.add_child(right_column)
	shell.add_child(_build_status_bar())
	_ensure_chamber_state()
	_ensure_political_state()
	_apply_responsive()
	match selected_nav:
		"Visão geral": _show_dashboard()
		"Meu partido": _show_party()
		"Eleições": _show_elections()
		"Congresso": _show_congress()
		"Governo": _show_government()
		"Ministérios": _show_ministries()
		"Crises": _show_crises()
		"Defesa": _show_defense()
		"Economia": _show_economy()
		"Orçamento": _show_budget()
		"Receitas": _show_revenue()
		"Projetos": _show_projects()
		"Dívida": _show_debt()
		"Serviços": _show_services()
		"Relatório do governo": _show_government_report()
		"População": _show_population()
		"Sociedade": _show_society()
		"Regiões": _show_regions()
		"Internacional": _show_international()
		"Mundo": _show_world()
		"Notícias": _show_news()
		"História": _show_history()
		"Inteligência": _show_intelligence()
		"Enciclopédia": _show_encyclopedia()
		"Configurações": _show_settings()
	# Foco inicial: teclado e gamepad navegam a tela sem depender do mouse.
	# Botão de mês desabilitado (eleição obrigatória) não aceita foco: cai para
	# o primeiro controle focável da faixa de navegação.
	if is_instance_valid(month_button) and not month_button.disabled:
		month_button.grab_focus()
	elif is_instance_valid(sidebar):
		var fallback := _first_focusable(sidebar)
		if fallback != null:
			fallback.grab_focus()
	_maybe_show_tutorial.call_deferred()

## Onboarding progressivo: um cartão por tela, uma única vez. O jogador pode
## fechar no Enter ou pular o restante; a escolha fica no save.
func _maybe_show_tutorial() -> void:
	if screen != "game" or not bool(state.get("started", false)):
		return
	if bool(state.get("tutorial_done", false)) or is_instance_valid(tutorial_callout):
		return
	if is_instance_valid(month_report_panel) or _month_in_progress:
		return
	for index in TUTORIAL_STEPS.size():
		var step: Dictionary = TUTORIAL_STEPS[index]
		if str(step.get("nav", "")) != selected_nav or _tutorial_step_seen(index):
			continue
		_mark_tutorial_seen(index)
		_save_game()
		var tutorial_script: Script = load("res://scripts/ui/tutorial_callout.gd") as Script
		if tutorial_script != null:
			tutorial_callout = tutorial_script.new()
		if tutorial_callout == null:
			# Headless/import fallback: state still tracks onboarding without a visual card.
			tutorial_callout = Control.new()
		tutorial_callout.name = "TutorialCallout"
		root_stack.add_child(tutorial_callout)
		if tutorial_callout.has_signal("continued"):
			tutorial_callout.continued.connect(_hide_tutorial_callout)
		if tutorial_callout.has_signal("skipped"):
			tutorial_callout.skipped.connect(_skip_tutorial)
		if tutorial_callout.has_method("show_callout"):
			var hint := "Uma vez por tela · Enter, Espaço ou clique para fechar."
			tutorial_callout.show_callout(str(step.get("title", "GUIA")), str(step.get("message", "")), hint, _tutorial_anchor())
		return

func _tutorial_step_seen(index: int) -> bool:
	var seen: Array = state.get("tutorial_seen", []) if state.get("tutorial_seen") is Array else []
	return seen.has(index) or seen.has(str(index))

func _mark_tutorial_seen(index: int) -> void:
	var seen: Array = state.get("tutorial_seen", []) if state.get("tutorial_seen") is Array else []
	if not seen.has(index):
		seen.append(index)
	state["tutorial_seen"] = seen
	if seen.size() >= TUTORIAL_STEPS.size():
		state["tutorial_done"] = true

func _tutorial_anchor() -> Vector2:
	var target: Control = null
	if selected_nav == "Visão geral" and is_instance_valid(month_button):
		target = month_button
	elif is_instance_valid(sidebar_context):
		target = sidebar_context
	elif is_instance_valid(main_column):
		target = main_column
	if target == null:
		return size * 0.5
	return target.get_global_rect().get_center()

func _hide_tutorial_callout() -> void:
	if is_instance_valid(tutorial_callout):
		tutorial_callout.queue_free()
	tutorial_callout = null

func _skip_tutorial() -> void:
	for index in TUTORIAL_STEPS.size():
		_mark_tutorial_seen(index)
	state["tutorial_done"] = true
	_hide_tutorial_callout()
	_save_game()
	_show_toast("Guia concluído. Você pode reabri-lo em Configurações.")

func _restart_tutorial() -> void:
	state["tutorial_seen"] = []
	state["tutorial_done"] = false
	_hide_tutorial_callout()
	_save_game()
	selected_nav = "Visão geral"
	_show_game()

## Primeiro controle visível e focável abaixo de um nó (para foco de emergência).
func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not control.is_visible_in_tree():
				continue
			if control is BaseButton:
				var button := control as BaseButton
				if not button.disabled and control.focus_mode == Control.FOCUS_ALL:
					return control
		var nested := _first_focusable(child)
		if nested != null:
			return nested
	return null

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = UI.HEADER_HEIGHT
	var header_style := _style(SURFACE, LINE, 0, 1)
	header_style.content_margin_left = 10
	header_style.content_margin_right = 10
	header_style.content_margin_top = 3
	header_style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", header_style)
	header_panel = panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	# Zona esquerda: bandeira + país + forma de governo (texto real de `structure`).
	var flag := FlagPainter.new()
	flag.country_id = str(state.get("country_id", "BR"))
	flag.custom_minimum_size = Vector2(26, 17)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flag.tooltip_text = str(state.get("country_name", ""))
	row.add_child(flag)
	var country_col := VBoxContainer.new()
	country_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	country_col.add_theme_constant_override("separation", 0)
	country_col.add_child(_label(_shorten(str(state.get("country_name", "País")).to_upper(), 20), 13, TEXT))
	var form := _country_form()
	if form != "":
		country_col.add_child(_label(_shorten(form, 30), 9, SUBTLE))
	row.add_child(country_col)
	# Bloco do jogador: sem retrato no projeto, iniciais no selo.
	header_leader = _header_leader_block()
	row.add_child(header_leader)
	# Pílulas de ação do topo (ícone + tooltip), como os controles compactos da referência.
	header_pills = HBoxContainer.new()
	header_pills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_pills.add_theme_constant_override("separation", 4)
	header_pills.add_child(_header_pill("news", "Notícias", _on_header_news))
	header_pills.add_child(_header_pill("save", "Salvar campanha", _manual_save))
	row.add_child(header_pills)
	# Faixa de KPIs em linha única: economia | política, sem caixa.
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	header_capsules.clear()
	for cap in [
		["CAIXA", "M$ %s" % _fmt_int(state.funds), AMBER, 1],
		["DÍVIDA/PIB", "%.0f%%" % state.debt, AMBER, 1],
		["CRESC.", "%+.1f%%" % state.economy, GREEN, 2],
		["INFLAÇÃO", "%.1f%%" % state.inflation, RED, 1],
		["DESEMPREGO", "%.1f%%" % state.unemployment, RED if float(state.unemployment) >= 10.0 else AMBER, 2],
	]:
		center.add_child(_header_capsule(str(cap[0]), str(cap[1]), cap[2], int(cap[3])))
	center.add_child(_vrule(20))
	for cap in [
		["APROVAÇÃO", "%.0f%%" % state.approval, TEXT, 1],
		["POPULARIDADE", "%.0f%%" % state.popularity, AMBER, 1],
		["ESTABILIDADE", "%d/100" % int(_stability()), AMBER, 2],
	]:
		center.add_child(_header_capsule(str(cap[0]), str(cap[1]), cap[2], int(cap[3])))
	row.add_child(center)
	# Zona direita em linha: data + avançar (o mesmo Button que foco/testes usam).
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 8)
	header_date = _label("", 11, MUTED)
	header_date.custom_minimum_size.x = 104
	header_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_child(header_date)
	month_button = _button("AVANÇAR ›", AMBER)
	month_button.pressed.connect(_advance_month)
	month_button.custom_minimum_size = Vector2(0, 32)
	month_button.add_theme_font_size_override("font_size", 12)
	right.add_child(month_button)
	row.add_child(right)
	_update_header()
	return panel

## Forma de governo classificada a partir do texto de `structure` do país.
## Nada é inventado: só traduzimos o que o dado já diz em um rótulo curto.
func _country_form() -> String:
	var country := _country_by_id(str(state.get("country_id", "")))
	if country.is_empty():
		return ""
	var structure := str(country.get("structure", "")).to_lower()
	var parts: Array[String] = []
	if structure.contains("bicameral"):
		parts.append("BICAMERAL")
	elif structure.contains("unicameral"):
		parts.append("UNICAMERAL")
	# Sistema: a mesma classificação que o motor eleitoral já usa.
	parts.append("PARLAMENTAR" if Election.is_parliamentary(country) else "PRESIDENCIAL")
	return " · ".join(parts)

## Corta um rótulo longo com reticências, para o topo nunca esticar a faixa.
func _shorten(text: String, max_chars: int) -> String:
	if max_chars <= 1 or text.length() <= max_chars:
		return text
	return text.substr(0, max_chars - 1).strip_edges() + "…"

## Selo circular com iniciais: substitui o retrato, que não existe no projeto.
func _initial_badge(text: String, diameter := 26, color := AMBER) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := _style(SURFACE_RAISED, color, int(diameter * 0.5), 1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", style)
	var letter := _label(text, 10, color)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(letter)
	return badge

func _header_leader_block() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 7)
	box.add_child(_vrule(24))
	box.add_child(_initial_badge(_initials(str(state.get("leader", "")))))
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	col.add_child(_label(_shorten(str(state.get("leader", "Líder")), 16), 12, TEXT))
	col.add_child(_label(_government_role() if bool(state.get("government", false)) else "LÍDER DA OPOSIÇÃO", 9, SUBTLE))
	box.add_child(col)
	return box

func _vrule(height: int) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(1, height)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rule

## Pílula 26x24 do topo: ícone desenhado, nome acessível no tooltip, foco real.
func _header_pill(icon_kind: String, tip: String, action: Callable) -> Button:
	var pill := _button("", MUTED, false)
	pill.custom_minimum_size = Vector2(26, 24)
	pill.tooltip_text = tip
	pill.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0))
	var hover := _style(SURFACE_HOVER, LINE, 4, 1)
	pill.add_theme_stylebox_override("hover", hover)
	pill.add_theme_stylebox_override("pressed", hover)
	var focus := _style(Color.TRANSPARENT, AMBER, 6, 1)
	focus.set_expand_margin_all(2.0)
	pill.add_theme_stylebox_override("focus", focus)
	pill.pressed.connect(action)
	var icon := NavIcon.new(icon_kind, MUTED, 14)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -7
	icon.offset_right = 7
	icon.offset_top = -7
	icon.offset_bottom = 7
	pill.add_child(icon)
	return pill

func _on_header_news() -> void:
	_select_nav("Notícias")

## Grupo selecionado atualmente (para a faixa contextual).
var selected_group: String = ""

## Estrutura de navegação única (B.5/B.6): [rótulo curto, nome do grupo, itens].
const NAV_GROUPS := [
	["PAÍS", "PAÍS", ["Visão geral", "Meu partido"]],
	["PODER", "PODER", ["Eleições", "Congresso", "Governo", "Ministérios", "Crises"]],
	["ECON", "ECONOMIA", ["Economia", "Orçamento", "Receitas", "Projetos", "Dívida", "Serviços", "População", "Sociedade", "Regiões"]],
	["MUNDO", "MUNDO", ["Internacional", "Mundo", "Defesa"]],
		["REGIS", "REGISTRO", ["Notícias", "História", "Inteligência", "Enciclopédia", "Relatório do governo", "Configurações"]],
]

func _group_of(nav_item: String) -> String:
	for group in NAV_GROUPS:
		if nav_item in group[2]:
			return str(group[1])
	return str(NAV_GROUPS[0][1])

func _items_of(group_name: String) -> Array:
	for group in NAV_GROUPS:
		if str(group[1]) == group_name:
			return group[2]
	return []

## O rail de 290 px é opcional por tela (matriz D.4): telas de leitura ampla
## dispensam decisão pendente, radar e resumo do partido para ganhar largura.
func _rail_enabled() -> bool:
	return selected_nav in ["Visão geral", "Meu partido", "Eleições", "Internacional", "Notícias", "História", "Crises"]

## Navegação em duas faixas (B.5/B.6): faixa principal de 64 px com os cinco
## grupos e faixa contextual de 120 px com os itens do grupo ativo.
func _build_sidebar() -> HBoxContainer:
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 0)
	# --- Trilho de ícones: 64 px ---
	var main_band := PanelContainer.new()
	main_band.custom_minimum_size.x = UI.NAV_MAIN_HEIGHT
	main_band.add_theme_stylebox_override("panel", _style(SURFACE, LINE, 0, 0))
	sidebar_plate = main_band
	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 2)
	main_band.add_child(main_col)
	nav.add_child(main_band)
	for group in NAV_GROUPS:
		var group_name := str(group[1])
		main_col.add_child(_rail_button(str(group[0]), group_name, _nav_icon_kind(group_name), group_name == selected_group, _select_group.bind(group_name)))
	main_col.add_spacer(false)
	main_col.add_child(_rule())
	main_col.add_child(_rail_button("SALVAR", "Salvar campanha", "save", false, _manual_save))
	main_col.add_child(_rail_button("MENU", "Voltar ao menu", "menu", false, _show_menu))
	# --- Faixa contextual: 132 px com o grupo ativo ---
	var context := PanelContainer.new()
	context.custom_minimum_size.x = UI.NAV_CONTEXT_WIDTH
	context.add_theme_stylebox_override("panel", _style(SURFACE_RAISED, LINE, 0, 0))
	sidebar_context = context
	var ctx_col := VBoxContainer.new()
	ctx_col.add_theme_constant_override("separation", 1)
	context.add_child(ctx_col)
	nav.add_child(context)
	var caption := _label(selected_group, 9, SUBTLE)
	caption.custom_minimum_size.y = 28
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctx_col.add_child(caption)
	for item in _items_of(selected_group):
		if str(item) in ADMIN_ITEMS:
			continue
		ctx_col.add_child(_context_item(str(item), str(item) == selected_nav))
	ctx_col.add_spacer(false)
	ctx_col.add_child(_rule())
	var admin := _label("ADMINISTRAÇÃO", 8, SUBTLE)
	admin.custom_minimum_size.y = 22
	admin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctx_col.add_child(admin)
	for item in ADMIN_ITEMS:
		ctx_col.add_child(_context_item(str(item), str(item) == selected_nav))
	return nav

func _nav_icon_kind(group_name: String) -> String:
	match group_name:
		"PAÍS":
			return "country"
		"PODER":
			return "power"
		"ECONOMIA":
			return "economy"
		"MUNDO":
			return "world"
		_:
			return "registry"

## Botão do trilho: ícone 18 px no topo, rótulo 8 px embaixo. O texto continua
## sendo o nome acessível; o ícone é filho inerte (não recebe foco nem clique).
func _rail_button(short_label: String, accessible_name: String, icon_kind: String, active: bool, action: Callable) -> Button:
	var rail := _button(short_label, AMBER if active else SUBTLE, false)
	rail.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.custom_minimum_size = Vector2(0, 52)
	rail.add_theme_font_size_override("font_size", 8)
	rail.tooltip_text = accessible_name
	var flat := _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	flat.content_margin_top = 24
	flat.content_margin_bottom = 4
	var active_style := _style(SURFACE_HOVER, Color.TRANSPARENT, 0, 0)
	active_style.content_margin_top = 24
	active_style.content_margin_bottom = 4
	active_style.border_width_left = 2
	active_style.border_color = AMBER
	var hover_style := _style(SURFACE_HOVER, LINE, 0, 0)
	hover_style.content_margin_top = 24
	hover_style.content_margin_bottom = 4
	rail.add_theme_stylebox_override("normal", active_style if active else flat)
	rail.add_theme_stylebox_override("hover", hover_style if not active else active_style)
	rail.add_theme_stylebox_override("pressed", active_style)
	rail.pressed.connect(action)
	var icon := NavIcon.new(icon_kind, AMBER if active else SUBTLE, 18)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.offset_left = -9
	icon.offset_right = 9
	icon.offset_top = 7
	icon.offset_bottom = 25
	rail.add_child(icon)
	return rail

## Item da faixa contextual: ativo em âmbar com fundo e chevron à direita.
func _context_item(item: String, active: bool) -> Button:
	var entry := _button(item, AMBER if active else MUTED, false)
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.custom_minimum_size = Vector2(0, 30)
	entry.add_theme_font_size_override("font_size", 12)
	entry.pressed.connect(_select_nav.bind(item))
	var flat := _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	flat.content_margin_left = 10
	flat.content_margin_right = 18
	var active_style := _style(SURFACE_HOVER, Color.TRANSPARENT, 0, 0)
	active_style.content_margin_left = 10
	active_style.content_margin_right = 18
	active_style.border_width_left = 2
	active_style.border_color = AMBER
	var hover_style := _style(SURFACE_HOVER, LINE, 0, 0)
	hover_style.content_margin_left = 10
	hover_style.content_margin_right = 18
	entry.add_theme_stylebox_override("normal", active_style if active else flat)
	entry.add_theme_stylebox_override("hover", hover_style if not active else active_style)
	entry.add_theme_stylebox_override("pressed", active_style)
	if active:
		var chevron := _label("›", 13, AMBER)
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chevron.anchor_left = 1.0
		chevron.anchor_right = 1.0
		chevron.anchor_top = 0.5
		chevron.anchor_bottom = 0.5
		chevron.offset_left = -16
		chevron.offset_right = -5
		chevron.offset_top = -9
		chevron.offset_bottom = 9
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_child(chevron)
	return entry

## Troca de grupo: mantém a tela atual se ela pertencer ao grupo; senão abre o primeiro item.
func _select_group(group_name: String) -> void:
	_hide_tutorial_callout()
	selected_group = group_name
	var items := _items_of(group_name)
	if not selected_nav in items and not items.is_empty():
		selected_nav = str(items[0])
	_show_game()

func _select_nav(item: String) -> void:
	_hide_tutorial_callout()
	selected_nav = item
	_show_game()

func _show_dashboard() -> void:
	_update_header()
	_clear_column(main_column)
	_clear_column(right_column)
	# A coluna não ocupa a área de conteúdo inteira: o vão à direita é onde o globo
	# (SHOW_GLOBE) aparece. SHRINK_BEGIN mantém os blocos à esquerda com a largura
	# declarada em vez de esticar até o rail.
	var dash := VBoxContainer.new()
	dash.custom_minimum_size.x = DASHBOARD_WIDTH
	dash.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dash.add_theme_constant_override("separation", 12)
	main_column.add_child(dash)
	dash.add_child(_section_title("Visão geral", "Decisões deste mês e sinais que movem o próximo ciclo eleitoral."))
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	for metric in [["POPULARIDADE", state.popularity, TEXT], ["APROVAÇÃO", state.approval, GREEN], ["RECONHECIMENTO", state.recognition, AMBER], ["COESÃO", state.cohesion, TEXT]]:
		metrics.add_child(_metric_card(metric[0], "%.0f%%" % metric[1], metric[2]))
	dash.add_child(metrics)
	dash.add_child(_agenda_panel())
	dash.add_child(_month_action_panel())
	board = BOARD_SCRIPT.new()
	board.custom_minimum_size = Vector2(0, 340)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.set_data(state, regions)
	dash.add_child(board)
	var brief := _panel_box()
	var bcol := VBoxContainer.new()
	bcol.add_child(_label("BRIEFING", 12, AMBER))
	bcol.add_child(_label("Fatores que mudaram", 17, TEXT))
	bcol.add_child(_rule())
	var report: Array = state.get("month_report", []) if state.get("month_report") is Array else []
	if report.is_empty():
		bcol.add_child(_label("Avance o mês para ver o que realmente mudou.", 13, MUTED))
	else:
		for entry in report:
			var row: Dictionary = entry if entry is Dictionary else {}
			var delta := float(row.get("delta", 0.0))
			var good := bool(row.get("good", true))
			bcol.add_child(_label("%s  %+.1f" % [str(row.get("label", "")), delta], 14, GREEN if good else RED))
	var factors: Array = state.get("month_factors", []) if state.get("month_factors") is Array else []
	if not factors.is_empty():
		bcol.add_child(_spacer(8))
		bcol.add_child(_label("FATORES CONTRIBUINTES", 12, AMBER))
		for factor in factors.slice(0, 2):
			var factor_label := _label("• " + str(factor), 12, MUTED)
			factor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bcol.add_child(factor_label)
	bcol.add_child(_spacer(8))
	bcol.add_child(_label("Próximo marco", 12, AMBER))
	bcol.add_child(_label(_next_election_label(), 18, TEXT))
	brief.add_child(bcol)
	dash.add_child(brief)
	_build_right_rail()

## Agenda (prazos, problemas e o que merece atenção): o resumo que o jogador
## precisa ler antes de avançar o mês. Cada item tem tom: "bad", "warn" ou "info".
func _agenda_items() -> Array:
	var items: Array = []
	if str(state.event) != "":
		items.append({"text": "Decisão pendente: %s" % str(state.event), "tone": "warn"})
	var months := int(state.months_to_election)
	if months <= 0:
		items.append({"text": "Eleição aberta: o pleito é obrigatório.", "tone": "bad"})
	elif months <= 6:
		items.append({"text": "Eleição em %d meses: hora de campanha e alianças." % months, "tone": "warn"})
	else:
		items.append({"text": "Eleição em %d meses." % months, "tone": "info"})
	if float(state.inflation) >= 8.0:
		items.append({"text": "Inflação em %.1f%%: salários e aprovação sob pressão." % float(state.inflation), "tone": "bad"})
	if float(state.unemployment) >= 11.0:
		items.append({"text": "Desemprego em %.1f%%: greves e protestos prováveis." % float(state.unemployment), "tone": "bad"})
	if float(state.debt) >= 85.0:
		items.append({"text": "Dívida em %.0f%% do PIB: risco de rebaixamento." % float(state.debt), "tone": "bad"})
	if float(state.cohesion) < 45.0:
		items.append({"text": "Coesão em %.0f%%: a bancada pode rachar." % float(state.cohesion), "tone": "warn"})
	if float(state.funds) < 1000.0:
		items.append({"text": "Caixa quase vazio: receita do mês M$ %s." % _fmt_int(_monthly_income()), "tone": "warn"})
	if not bool(state.government) and int(state.opposition_actions) < 1 and float(state.funds) >= OPPOSITION_ACTION_COST:
		items.append({"text": "Ação de oposição disponível neste mês.", "tone": "info"})
	return items

## Objetivos do mandato: situação atual, prioridades e promessas em aberto.
## Nada aqui impõe ideologia ou estratégia — só mede o que o jogador prometeu.
func _mandate_objectives() -> Array:
	var items: Array = []
	var months := maxi(0, int(state.months_to_election))
	if not bool(state.government):
		items.append({"text": "Objetivo: conquistar o governo na eleição em %d meses." % months, "tone": "info"})
		if float(state.recognition) < 35.0:
			items.append({"text": "Prioridade: reconhecimento em %.0f%% (meta 35%%)." % float(state.recognition), "tone": "warn"})
		if int(state.lower_house_seats) <= 0:
			items.append({"text": "Prioridade: eleger as primeiras cadeiras para influenciar o plenário.", "tone": "warn"})
	else:
		var approval := float(state.approval)
		items.append({"text": "Objetivo: sustentar aprovação ≥ 45%% (atual %.0f%%)." % approval, "tone": "info" if approval >= 45.0 else "warn"})
		if not (state.promises as Array).is_empty():
			var fulfilled := 0
			for promise in state.promises:
				var metric := str(promise.get("metric", ""))
				var target := float(promise.get("target", 0.0))
				var value := float(state.get(metric, 0.0))
				var ok := value <= target if str(promise.get("mode", "min")) == "max" else value >= target
				if ok:
					fulfilled += 1
			var total := (state.promises as Array).size()
			items.append({"text": "Promessas no rumo: %d de %d até o fim do mandato." % [fulfilled, total], "tone": "info" if fulfilled == total else "warn"})
			var pending := 0
			for promise in state.promises:
				var metric := str(promise.get("metric", ""))
				var target := float(promise.get("target", 0.0))
				var value := float(state.get(metric, 0.0))
				var ok := value <= target if str(promise.get("mode", "min")) == "max" else value >= target
				if not ok and pending < 2:
					pending += 1
					items.append({"text": "Promessa em aberto: %s" % str(promise.get("text", "")), "tone": "warn"})
		var base_seats := int(state.get("coalition_seats", 0))
		if base_seats <= 0:
			base_seats = int(state.get("lower_house_seats", 0))
		if Election.is_parliamentary(_country_by_id(str(state.country_id))) and base_seats < int(state.majority):
			items.append({"text": "Risco institucional: sem maioria, o governo pode cair por censura.", "tone": "bad"})
	return items.slice(0, 5)

func _agenda_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("AGENDA", 12, AMBER))
	col.add_child(_label("Prazos e problemas", 17, TEXT))
	col.add_child(_label("%s  ·  %d de %d cadeiras  ·  eleição em %d meses" % ["GOVERNO" if bool(state.government) else "OPOSIÇÃO", int(state.lower_house_seats), int(state.chamber_seats), maxi(0, int(state.months_to_election))], 11, MUTED))
	col.add_child(_rule())
	for item in _agenda_items() + _mandate_objectives():
		var tone := str(item.tone)
		var l := _label("•  " + str(item.text), 13, RED if tone == "bad" else AMBER if tone == "warn" else MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	panel.add_child(col)
	return panel

func _build_right_rail() -> void:
	if not _rail_enabled():
		return
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
	ncol.add_child(_label("RADAR NACIONAL", 12, SUBTLE))
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
	if not is_instance_valid(decision_buttons):
		return
	for child in decision_buttons.get_children(): child.queue_free()
	var event: String = state.event
	if event == "":
		decision_text.text = "Nenhuma crise aberta. Avance o mês para atualizar o ambiente político."
		var b := _button("VER NOTÍCIAS", MUTED, false)
		b.pressed.connect(_select_nav.bind("Notícias"))
		decision_buttons.add_child(b)
		return
	decision_text.text = event
	var options: Array = state.get("event_options", []) if state.get("event_options") is Array else []
	if not options.is_empty():
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_theme_constant_override("separation", 6)
		decision_buttons.add_child(stack)
		for i in options.size():
			var option: Dictionary = options[i]
			var b := _button(str(option.get("label", "")), TEXT, i == 0)
			var cost := Events.cost_of(option)
			b.tooltip_text = "%s%s" % [str(option.get("hint", "")), "  ·  custo M$ %s" % _fmt_int(cost) if cost > 0.0 else ""]
			b.disabled = cost > float(state.funds)
			b.pressed.connect(_resolve_event_option.bind(i))
			stack.add_child(b)
			var hint := _label("%s%s" % [str(option.get("hint", "")), "  ·  M$ %s" % _fmt_int(cost) if cost > 0.0 else ""], 12, MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(hint)
		return
	for option in ["Investir agora", "Negociar", "Não intervir"]:
		var b := _button(option, SUBTLE if option != "Não intervir" else MUTED, false)
		b.pressed.connect(_resolve_event.bind(option))
		decision_buttons.add_child(b)

## Resposta a um evento do motor determinístico: aplica o efeito da opção uma vez.
func _resolve_event_option(index: int) -> void:
	var options: Array = state.get("event_options", []) if state.get("event_options") is Array else []
	if index < 0 or index >= options.size():
		return
	var option: Dictionary = options[index]
	if Events.cost_of(option) > float(state.funds):
		_show_toast("Caixa insuficiente para esta resposta", "error")
		return
	var summary := Events.apply(state, option, bool(state.government))
	_push_news("%s: %s%s" % [str(state.event), str(option.get("label", "")), " (%s)" % summary if summary != "" else ""])
	state.event = ""
	state.event_id = ""
	state.event_options = []
	state["event_effects_applied"] = false
	_clamp_state()
	_save_game()
	_show_game()

## Manchete sem duplicata consecutiva: o radar não repete a mesma linha.
func _push_news(text: String) -> void:
	if state.news.size() > 0 and str(state.news[0]) == text:
		return
	state.news.push_front(text)

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
	for metric in [["Membros", _fmt_int(state.members), AMBER], ["Credibilidade", "%.0f%%" % state.credibility, TEXT], ["Coesão interna", "%.0f%%" % state.cohesion, GREEN], ["Caixa", "M$ %s" % _fmt_int(state.funds), AMBER]]:
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
		var b := _button(pair[0], SUBTLE, false)
		b.tooltip_text = pair[1]
		b.pressed.connect(_party_action.bind(pair[2]))
		actions.add_child(b)
	col.add_child(actions)
	var medals := HBoxContainer.new()
	medals.add_theme_constant_override("separation", 10)
	medals.add_child(_badge(str(state.abbr), "SIGLA", 104, AMBER))
	medals.add_child(_badge(_initials(str(state.leader)), "LIDERANÇA", 104, TEXT))
	identity_row.add_child(col)
	identity_row.add_child(medals)
	panel.add_child(identity_row)
	main_column.add_child(panel)
	main_column.add_child(_ideology_panel())
	main_column.add_child(_factions_panel())
	_build_right_rail()

func _ideology_panel() -> PanelContainer:
	var country := _country_by_id(str(state.country_id))
	var positions := Ideology.positions(state, country)
	var labels := {}
	for party in country.get("official_parties", []):
		labels[str(party.get("abbr", ""))] = str(party.get("name", party.get("abbr", "")))
	labels[str(state.abbr)] = str(state.party)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("POSIÇÃO IDEOLÓGICA  ·  DOIS EIXOS", 12, AMBER))
	var position := Ideology.player_position(state)
	col.add_child(_label("%s  ·  econômico %+.0f  ·  social %+.0f  ·  %s" % [state.party, position.x, position.y, Ideology.nearest_category(position)], 16, TEXT))
	var chart := IdeologyChart.new()
	chart.set_data(positions, str(state.abbr), labels)
	col.add_child(chart)
	col.add_child(_label("Horizontal: -100 intervencionista / +100 mercado. Vertical: -100 progressista / +100 conservador. Posições são classificação analítica, não dado oficial.", 11, SUBTLE))
	var player_key := str(state.abbr)
	var rivals: Array = []
	for key in positions.keys():
		if str(key) == player_key:
			continue
		var rel := PoliticalRelations.relation(state, player_key, str(key))
		rivals.append([str(key), Ideology.compatibility(position, positions[key]), rel])
	rivals.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	for row in rivals.slice(0, 3):
		col.add_child(_label("%s: compatibilidade %.0f%%, relação %+.0f" % [str(row[0]), float(row[1]), float(row[2])], 12, MUTED))
	panel.add_child(col)
	return panel

func _factions_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("FACÇÕES INTERNAS", 12, AMBER))
	col.add_child(_label("A liderança não é um bloco: cada ala cobra coerência, espaço e resultado.", 13, MUTED))
	for faction in PoliticalRelations.faction_summary(state):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(str(faction.name), 14, TEXT)
		name_label.custom_minimum_size.x = 132
		row.add_child(name_label)
		row.add_child(_bar(float(faction.strength) * 100.0, 100.0, SUBTLE, 8.0))
		row.add_child(_label("peso %.0f%%" % (float(faction.strength) * 100.0), 11, MUTED))
		row.add_child(_bar(float(faction.satisfaction), 100.0, GREEN if float(faction.satisfaction) >= 45.0 else RED, 10.0))
		row.add_child(_label("satisfação %.0f%%" % float(faction.satisfaction), 12, GREEN if float(faction.satisfaction) >= 45.0 else RED))
		col.add_child(row)
	if bool(state.get("leadership_challenge", false)):
		col.add_child(_label("Uma ala articula desafio à liderança. Conceder espaço interno reduz o risco e reforça a coesão.", 13, RED))
		var b := _button("CONCEDER ESPAÇO INTERNO  ·  M$ 600", AMBER, false)
		b.pressed.connect(_resolve_leadership_challenge)
		col.add_child(b)
	panel.add_child(col)
	return panel

func _resolve_leadership_challenge() -> void:
	if not bool(state.get("leadership_challenge", false)) or float(state.funds) < 600.0:
		return
	state.funds -= 600.0
	state["leadership_challenge"] = false
	state.cohesion = clampf(float(state.cohesion) + 5.0, 10.0, 100.0)
	for faction in state.factions:
		if str(faction.get("id", "")) in ["ideological", "base"]:
			faction.satisfaction = clampf(float(faction.satisfaction) + 8.0, 0.0, 100.0)
	_push_news("A liderança cedeu espaço às alas internas e superou o desafio.")
	_clamp_state(); _save_game(); _show_game()

func _party_action(action: String) -> void:
	var cost := 900
	if action == "volunteers": cost = 650
	elif action == "program": cost = 1100
	if float(state.funds) < float(cost):
		_show_toast("Caixa insuficiente para esta ação", "error")
		return
	if action == "regional":
		state.funds -= 900; state.recognition += 3; state.popularity += 2
		var target := clampi(selected_region, 0, state.region_support.size() - 1)
		for i in state.region_support.size(): state.region_support[i] += 4.0 if i == target else 0.5
		state.news.push_front("O partido concluiu um giro regional com foco em %s." % str(regions[target].name))
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
	top.add_child(_metric_card("PRÓXIMA ELEIÇÃO", "%d meses" % max(0, int(state.months_to_election)), AMBER))
	top.add_child(_metric_card("INTENÇÃO DE VOTO", "%.1f%%" % float(shares.get(player_key, 0.0)), AMBER))
	top.add_child(_metric_card("CADEIRAS PROJETADAS", ("%d de %d" % [int(projection.get(player_key, 0)), seats]) if seats > 0 else "câmara não informada", AMBER))
	main_column.add_child(top)
	var poll := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("PESQUISA NACIONAL  ·  %s  ·  margem ±3,2 p.p." % str(country.get("name", "País")), 12, SUBTLE))
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
		row.add_child(_bar(float(pair[1]), 100.0, AMBER if key == player_key else SUBTLE, 12.0))
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
	main_column.add_child(_campaign_panel_b())
	main_column.add_child(_regional_campaign_panel())
	_build_right_rail()

func _campaign_panel_b() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("SALA DE CAMPANHA  ·  B6", 12, AMBER))
	col.add_child(_label("Três ações por mês. Cada ação declara alcance, custo e grupo; a eleição converte apoio em cadeiras por D'Hondt.", 14, MUTED))
	var selectors := HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 10)
	campaign_region_select = OptionButton.new()
	for i in regions.size():
		campaign_region_select.add_item(str(regions[i].name))
	campaign_region_select.select(clampi(selected_region, 0, regions.size() - 1))
	campaign_region_select.custom_minimum_size.x = 190
	selectors.add_child(_label("Região-alvo", 12, SUBTLE))
	selectors.add_child(campaign_region_select)
	campaign_group_select = OptionButton.new()
	campaign_group_select.add_item("Sem grupo específico")
	for group in SocialGroups.definitions():
		campaign_group_select.add_item(str(group.get("label", group.get("id", ""))))
		campaign_group_select.set_item_metadata(campaign_group_select.item_count - 1, str(group.get("id", "")))
	campaign_group_select.custom_minimum_size.x = 210
	selectors.add_child(_label("Grupo-alvo", 12, SUBTLE))
	selectors.add_child(campaign_group_select)
	col.add_child(selectors)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 8)
	for entry in CampaignSystem.actions():
		var id := str(entry.get("id", ""))
		var cost := float(entry.get("cost", 0))
		var b := _button("%s%s" % [str(entry.get("label", id)), "  ·  M$ %s" % _fmt_int(cost) if cost > 0.0 else ""], AMBER if cost > 0.0 else MUTED, false)
		b.tooltip_text = "%s  ·  alcance nacional %.1f, reconhecimento +%.1f" % [str(entry.get("hint", "")), float(entry.get("campaign", 0.0)), float(entry.get("recognition", 0.0))]
		b.disabled = int(state.campaign_actions) >= CAMPAIGN_ACTIONS_PER_MONTH or float(state.funds) < cost
		b.pressed.connect(_campaign_run.bind(id))
		acts.add_child(b)
	var free_action := _button("Militância de base", MUTED, false)
	free_action.tooltip_text = "Sem custo  ·  +0,5 de popularidade e +0,2 de reconhecimento"
	free_action.pressed.connect(_free_campaign_action)
	acts.add_child(free_action)
	col.add_child(acts)
	_sync_action_month()
	col.add_child(_label("Ações neste mês: %d de %d  ·  penalidade eleitoral de crise: %.1f p.p." % [int(state.campaign_actions), CAMPAIGN_ACTIONS_PER_MONTH, float(state.get("campaign_penalty", 0.0))], 12, MUTED))
	var finance: Dictionary = state.get("campaign_finance", {}) if state.get("campaign_finance") is Dictionary else {}
	col.add_child(_rule())
	col.add_child(_label("FINANCIAMENTO  ·  privado M$ %s / %s  ·  público M$ %s / %s  ·  risco %d" % [_fmt_int(float(finance.get("private_raised", 0.0))), _fmt_int(float(CampaignSystem.finance_rules().get("private_cap", 6000))), _fmt_int(float(finance.get("public_raised", 0.0))), _fmt_int(float(CampaignSystem.finance_rules().get("public_cap", 2400))), int(finance.get("risk", 0.0))], 12, MUTED))
	var funding := HBoxContainer.new()
	var private_btn := _button("CAPTAR RECURSOS PRIVADOS", AMBER, false)
	private_btn.tooltip_text = "M$ 2.500 por mês, até o teto; aumenta o risco de apuração."
	private_btn.pressed.connect(_raise_campaign.bind("private"))
	funding.add_child(private_btn)
	var public_btn := _button("FUNDO PÚBLICO", SUBTLE, false)
	public_btn.tooltip_text = "M$ 1.200 por mês, até M$ 2.400; sem risco jurídico."
	public_btn.pressed.connect(_raise_campaign.bind("public"))
	funding.add_child(public_btn)
	col.add_child(funding)
	if int(state.months_to_election) <= 0:
		var election := _button("REALIZAR ELEIÇÃO", GREEN)
		election.pressed.connect(_run_election)
		col.add_child(election)
		col.add_child(_label("Mandato encerrado: o pleito é obrigatório para abrir o próximo ciclo.", 13, AMBER))
	panel.add_child(col)
	return panel

func _campaign_run(id: String) -> void:
	var region_index := campaign_region_select.selected if is_instance_valid(campaign_region_select) else selected_region
	var focus := ""
	if is_instance_valid(campaign_group_select) and campaign_group_select.selected > 0:
		focus = str(campaign_group_select.get_item_metadata(campaign_group_select.selected))
	var result := CampaignSystem.perform(state, id, region_index, regions, focus)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Ação indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_game()
	_show_toast(str(result.get("reason", "Ação concluída")), "success")

func _raise_campaign(source: String) -> void:
	var result := CampaignSystem.raise_funds(state, source)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Captação indisponível")), "warning")
		return
	_push_news(str(result.get("reason", "Captação de campanha")))
	_clamp_state(); _save_game(); _show_game()
	_show_toast(str(result.get("reason", "Captação concluída")), "success")

func _regional_campaign_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("LEITURA REGIONAL DA CAMPANHA", 12, AMBER))
	col.add_child(_label("Regiões com menor apoio e maior alcance relativo modelado oferecem o melhor retorno marginal. O contexto local é o problema real cadastrado; isso não representa peso eleitoral oficial.", 13, MUTED))
	for row in CampaignSystem.regional_analysis(state, regions):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var name_label := _label(str(row.name), 13, TEXT)
		name_label.custom_minimum_size.x = 140
		line.add_child(name_label)
		line.add_child(_bar(float(row.support), 100.0, AMBER, 9.0))
		line.add_child(_label("apoio %.0f%%  ·  alcance relativo %.1f%%  ·  oportunidade %.0f" % [float(row.support), float(row.weight), float(row.opportunity)], 12, MUTED))
		var context := _label(str(row.context), 11, SUBTLE)
		context.custom_minimum_size.x = 130
		line.add_child(context)
		col.add_child(line)
	panel.add_child(col)
	return panel

func _campaign_action(cost: int, gain: int, label: String) -> void:
	_sync_action_month()
	if int(state.campaign_actions) >= CAMPAIGN_ACTIONS_PER_MONTH:
		_show_toast("Limite de %d ações de campanha neste mês" % CAMPAIGN_ACTIONS_PER_MONTH, "warning")
		return
	if state.funds < cost:
		_show_toast("Caixa insuficiente para " + label.to_lower(), "error")
		return
	state.campaign_actions = int(state.campaign_actions) + 1
	# Retorno decrescente: quem já é popular ganha menos por cada ação.
	var effective := float(gain) * clampf(1.0 - float(state.popularity) / 80.0, 0.25, 1.0)
	state.funds -= cost; state.popularity += effective; state.recognition += 1.5; state.campaign += effective
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
	var presidential_race := Election.presidential_2d(shares, Ideology.positions(state, country), rng)
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
	state.coalition_terms = []
	state.leadership_challenge = false
	CampaignSystem.init_state(state)
	PoliticalRelations.ensure(state, Ideology.positions(state, country))
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
	state.event_id = ""
	state.event_options = []
	state.ministers = []
	state["bill_month"] = ""
	if not won:
		state.policies = []
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
	top.add_child(_metric_card("CADEIRAS DO PARTIDO", "%d de %d" % [player_seats, seats], AMBER))
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
	col.add_child(_label("BANCADAS  ·  %s" % str(state.chamber_name), 12, SUBTLE))
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
	main_column.add_child(_relations_panel())
	var bills := _panel_box()
	var bcol := VBoxContainer.new()
	bcol.add_child(_label("PROPOSIÇÕES", 12, AMBER))
	bcol.add_child(_label("O plenário vota por bancada: proximidade ideológica e disciplina da coalizão.", 13, MUTED))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	for bill in Legislature.BILLS:
		if bool(bill.get("requires_government", false)) and not bool(state.government):
			continue
		var b := _button(str(bill.get("title", "Proposição")), SUBTLE, false)
		b.tooltip_text = "%s  ·  custo M$ %s  ·  eixo %.2f%s" % [str(bill.get("summary", "")), _fmt_int(float(bill.get("cost", 0))), float(bill.get("axis", 0.0)), "  ·  constitucional (3/5)" if str(bill.get("kind", "")) == "constitutional" else ""]
		b.pressed.connect(_propose_bill.bind(str(bill.get("id", ""))))
		actions.add_child(b)
	if not bool(state.government):
		bcol.add_child(_label("Proposições de governo ficam disponíveis ao assumir o poder; como bancada, restam as de iniciativa parlamentar. Uma votação por mês.", 12, MUTED))
	bcol.add_child(actions)
	bills.add_child(bcol)
	main_column.add_child(bills)
	var agenda: Array = []
	if state.get("bills") is Array:
		agenda = state.bills
	if not agenda.is_empty():
		var history := _panel_box()
		var hcol := VBoxContainer.new()
		hcol.add_child(_label("AGENDA RECENTE", 12, SUBTLE))
		for item in agenda.slice(0, 6):
			var approved := bool(item.get("approved", false))
			hcol.add_child(_label("%02d/%d  ·  %s  ·  %s  ·  %d a %d" % [int(item.get("month", 1)), int(item.get("year", 0)), str(item.get("title", "")), "aprovada" if approved else "rejeitada", int(item.get("ayes", 0)), int(item.get("nayes", 0))], 14, GREEN if approved else RED))
		history.add_child(hcol)
		main_column.add_child(history)
	_build_right_rail()

## O modelo local trava com JSON longo: cada bloco de bancadas é uma decisão.
const BILL_BANKS_PER_REQUEST := Contracts.LEGISLATIVE_CHUNK

func _relations_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("MATRIZ DE RELAÇÕES  ·  B4", 12, AMBER))
	col.add_child(_label("Relação -100..+100. Ela parte da distância em dois eixos, mas muda com votos, coalizão, renegociação e crises. Não é um multiplicador fixo.", 12, MUTED))
	var seat_map: Dictionary = state.get("seat_map", {}) if state.get("seat_map") is Dictionary else {}
	var ranked: Array = []
	for key in seat_map.keys():
		if int(seat_map[key]) > 0:
			ranked.append([str(key), int(seat_map[key])])
	ranked.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var parties: Array = [str(state.abbr)]
	for item in ranked:
		if parties.size() >= 6:
			break
		if not parties.has(str(item[0])):
			parties.append(str(item[0]))
	var header := HBoxContainer.new()
	header.add_child(_table_head("PARTIDO", 76))
	for party in parties:
		header.add_child(_table_head(str(party), 74))
	col.add_child(header)
	for a in parties:
		var row := HBoxContainer.new()
		row.add_child(_table_cell(str(a), 76, AMBER if str(a) == str(state.abbr) else TEXT))
		for b in parties:
			if str(a) == str(b):
				row.add_child(_table_cell("—", 74, SUBTLE))
			else:
				var value := PoliticalRelations.relation(state, str(a), str(b))
				row.add_child(_table_cell("%+.0f" % value, 74, GREEN if value > 10.0 else RED if value < -10.0 else MUTED, true))
		col.add_child(row)
	panel.add_child(col)
	return panel

func _propose_bill(bill_id: String) -> void:
	var bill := Legislature.bill(bill_id)
	if bill.is_empty():
		return
	if bool(bill.get("requires_government", false)) and not bool(state.government):
		_show_toast("Essa proposição é exclusiva do governo", "warning")
		return
	if str(state.get("bill_month", "")) == _month_stamp():
		_show_toast("Uma proposição por mês: o plenário já votou neste mês", "warning")
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
	# B4/B5: relação, facção e crise deslocam uma fração limitada das cadeiras.
	var relations: Dictionary = state.get("party_relations", {}) if state.get("party_relations") is Dictionary else {}
	votes = Legislature.adjust_votes(votes, seat_map, Election.axes(state, country_vote), bill, relations, str(state.abbr), PoliticalRelations.faction_penalty(state), float(state.get("scandal_penalty", 0.0)), state.get("coalition_terms", []) if state.get("coalition_terms") is Array else [])
	var outcome := Contracts.votes_to_outcome(votes, seat_map)
	var approved := Legislature.passes(bill, outcome, int(state.chamber_seats))
	state["bill_month"] = _month_stamp()
	state.bills.push_front({
		"id": str(bill.get("id", "")), "title": str(bill.get("title", "")),
		"year": int(state.date_year), "month": int(state.date_month),
		"ayes": int(outcome.get("ayes", 0)), "nayes": int(outcome.get("nayes", 0)),
		"abstain": int(outcome.get("abstain", 0)), "approved": approved,
	})
	state.bills = state.bills.slice(0, 12)
	PoliticalRelations.bill_update(state, votes, str(state.abbr), state.get("coalition_partners", []) if state.get("coalition_partners") is Array else [])
	var coalition_result := PoliticalRelations.apply_bill_result(state, bill, approved, str(state.abbr))
	for coalition_event in coalition_result.get("events", []):
		_push_news(str(coalition_event))
	if not (coalition_result.get("left", []) as Array).is_empty():
		if bool(state.government) and Election.is_parliamentary(country_vote) and int(state.get("coalition_seats", 0)) < int(state.get("majority", 1)):
			state.government = false
			state.months_to_election = 0
			_push_news("A coalizão perdeu a maioria após a violação do acordo: eleição antecipada.")
	if approved:
		state.funds -= cost
		_apply_effects(bill.get("effects", {}))
		var bill_groups: Dictionary = bill.get("groups", {})
		var detailed_policy: Array = SocialGroups.apply_policy(state, str(bill.get("id", "")))
		if detailed_policy.is_empty() and not bill_groups.is_empty():
			SocialGroups.apply_legacy(state, bill_groups)
		for pressure in InterestGroups.apply_policy(state, str(bill.get("id", ""))):
			_push_news("%s reage à %s (%+.0f de relação)." % [_interest_name(str(pressure.get("group", ""))), str(bill.get("title", "proposição")), float(pressure.get("delta", 0.0))])
		CausalLog.record(state, "politica", str(bill.get("title", "proposição")), bill.get("effects", {}) if bill.get("effects") is Dictionary else {}, "A proposição foi aprovada e seus efeitos macro passam a operar; grupos e organizações reagem conforme a incidência declarada.")
		if not bool(state.government):
			state.credibility += 2
		state.news.push_front("%s aprovada: %s." % [str(bill.get("title", "Proposição")), Legislature.summary(outcome)])
	else:
		state.credibility += -2.0 if bool(state.government) else 1.0
		state.news.push_front("%s rejeitada no plenário: %s." % [str(bill.get("title", "Proposição")), Legislature.summary(outcome)])
	_clamp_state(); _save_game(); _show_game()
	_show_toast("Proposição aprovada" if approved else "Proposição rejeitada", "success" if approved else "error")

func _interest_name(id: String) -> String:
	var groups: Dictionary = state.get("interest_groups", {}) if state.get("interest_groups") is Dictionary else {}
	var org: Dictionary = groups.get(id, {}) if groups.get(id) is Dictionary else {}
	return str(org.get("name", id))

func _apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		if EFFECT_KEYS.has(str(key)):
			state[key] = float(state.get(key, 0.0)) + float(effects[key])

func _formation_deal() -> Dictionary:
	var country := _country_by_id(str(state.country_id))
	var seat_map: Dictionary = {}
	if state.get("seat_map") is Dictionary:
		seat_map = state.seat_map
	if seat_map.is_empty():
		return {}
	var positions := Ideology.positions(state, country)
	var deal := PoliticalRelations.coalition_terms(state, seat_map, positions, str(state.abbr), int(state.majority))
	if deal.is_empty():
		return Coalition.minimum_winning(seat_map, Election.axes(state, country), str(state.abbr), int(state.majority))
	if bool(state.get("coalition_negotiated", false)):
		deal["cost"] = int(round(float(deal.get("cost", 0)) * 0.85))
		deal["cohesion"] = minf(95.0, float(deal.get("cohesion", 60.0)) + 6.0)
		deal["negotiated"] = true
	return deal

## Renegociar termos: custa caixa e capital ideológico, mas reduz o preço e
## melhora a relação com cada parceiro.
func _renegotiate_formation() -> void:
	if bool(state.get("coalition_negotiated", false)):
		_show_toast("Os termos já foram renegociados nesta formação", "warning")
		return
	if float(state.funds) < 350.0:
		_show_toast("Caixa insuficiente para renegociar", "error")
		return
	var deal := _formation_deal()
	if deal.is_empty():
		return
	state.funds -= 350.0
	for party in deal.get("partners", []):
		PoliticalRelations.shift(state, str(state.abbr), str(party), 4.0, "renegociação de coalizão")
	state["coalition_negotiated"] = true
	for faction in state.factions:
		if str(faction.get("id", "")) == "ideological":
			faction.satisfaction = clampf(float(faction.satisfaction) - 4.0, 0.0, 100.0)
	_push_news("A liderança renegociou os termos da coalizão: custo menor, concessão maior.")
	_clamp_state(); _save_game(); _show_game()

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
		col.add_child(_label("Custo de negociação: M$ %s  ·  coesão esperada %.0f%%  ·  estabilidade %.0f%%" % [_fmt_int(float(deal.get("cost", 0))), float(deal.get("cohesion", 0.0)), float(deal.get("stability", 50.0))], 13, MUTED))
		for term in deal.get("terms", []):
			col.add_child(_label("%s: %d cadeiras, %d pasta(s), exige %s (relação %+.0f)." % [str(term.get("party", "")), int(term.get("seats", 0)), int(term.get("ministries", 1)), str(term.get("demand", "compromisso")), float(term.get("relation", 0.0))], 13, TEXT))
		if not bool(state.get("coalition_negotiated", false)):
			var negotiate := _button("RENEGOCIAR TERMOS  ·  M$ 350", AMBER, false)
			negotiate.tooltip_text = "Reduz 15% do custo, +6 de coesão e +4 de relação com cada parceiro; a ala ideológica perde satisfação."
			negotiate.pressed.connect(_renegotiate_formation)
			col.add_child(negotiate)
		var accept := _button("FECHAR COALIZÃO", GREEN)
		accept.disabled = state.funds < float(deal.get("cost", 0))
		accept.pressed.connect(_accept_coalition)
		col.add_child(accept)
	panel.add_child(col)
	return panel

func _coalition_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("BASE DE GOVERNO", 12, SUBTLE))
	var partners: Array = []
	if state.get("coalition_partners") is Array:
		partners = state.coalition_partners
	var base_seats := int(state.get("coalition_seats", 0))
	if base_seats <= 0:
		base_seats = int(state.lower_house_seats)
	var partners_text := "bancada própria" if partners.is_empty() else ", ".join(PackedStringArray(partners))
	col.add_child(_label("%d de %d cadeiras  ·  %s" % [base_seats, int(state.chamber_seats), partners_text], 15, TEXT))
	col.add_child(_label("Coesão da base: %.0f%%  ·  estabilidade: %.0f%%" % [float(state.get("coalition_cohesion", 60.0)), PoliticalRelations.stability(state)], 13, MUTED))
	if not partners.is_empty():
		var terms: Array = state.get("coalition_terms", []) if state.get("coalition_terms") is Array else []
		var assignments: Dictionary = state.get("coalition_assignments", {}) if state.get("coalition_assignments") is Dictionary else {}
		for term in terms:
			var party := str(term.get("party", ""))
			col.add_child(_label("%s: %s  ·  pastas %d/%d" % [party, str(term.get("demand", "acordo")), int(assignments.get(party, 0)), int(term.get("ministries", 0))], 12, MUTED))
	if not partners.is_empty():
		var renew := _button("REFORÇAR BASE  ·  M$ 600", SUBTLE, false)
		renew.tooltip_text = "Coesão da base +15. Abaixo de 30, um parceiro deixa a coalizão."
		renew.pressed.connect(_renew_coalition)
		col.add_child(renew)
	panel.add_child(col)
	return panel

func _coalition_ministries(deal: Dictionary) -> int:
	var total := 0
	for term in deal.get("terms", []):
		total += int(term.get("ministries", 0))
	return total

func _accept_coalition() -> void:
	var was_government := bool(state.government)
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
	state["coalition_terms"] = deal.get("terms", [])
	state["coalition_assignments"] = {}
	state["coalition_compliance"] = {}
	state["coalition_started"] = int(state.get("date_year", 0)) * 12 + int(state.get("date_month", 1))
	state["coalition_stability"] = float(deal.get("stability", 55.0))
	for party in state.coalition_partners:
		PoliticalRelations.shift(state, str(state.abbr), str(party), 12.0, "coalizão fechada")
	for faction in state.factions:
		if str(faction.get("id", "")) == "ideological":
			faction.satisfaction = clampf(float(faction.satisfaction) - 3.0, 0.0, 100.0)
		elif str(faction.get("id", "")) == "pragmatic":
			faction.satisfaction = clampf(float(faction.satisfaction) + 4.0, 0.0, 100.0)
	state["coalition_negotiated"] = false
	state.news.push_front(("Base de governo fechada com %s" if was_government else "Coalizão fechada com %s") % ", ".join(PackedStringArray(deal.get("partners", []))) + ": %d de %d cadeiras; %d pasta(s) distribuídas." % [int(deal.get("seats", 0)), int(state.chamber_seats), _coalition_ministries(deal)])
	_clamp_state(); _save_game(); _show_game()
	_show_toast("Base de governo fechada" if was_government else "Governo formado por coalizão", "success")

func _show_government() -> void:
	_show_section("Governo", "Governar é transformar promessas em capacidade de execução.")
	var country := _country_by_id(str(state.country_id))
	if not state.government:
		var empty := _panel_box()
		var col := VBoxContainer.new()
		col.add_child(_label("OPOSIÇÃO", 13, SUBTLE))
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
	top.add_child(_metric_card("CAPACIDADE", "%.0f%%" % ((state.credibility + state.cohesion) / 2.0), SUBTLE))
	main_column.add_child(top)
	main_column.add_child(_public_admin_panel())
	var cabinet := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("GABINETE", 12, AMBER))
	for ministry in MINISTRIES.keys():
		var def: Dictionary = MINISTRIES[ministry]
		var named: bool = state.ministers.has(ministry)
		var row := HBoxContainer.new()
		row.add_child(_label(ministry, 15, TEXT))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(spacer)
		var b := _button("NOMEADO" if named else "NOMEAR  ·  M$ %d" % int(def.cost), MUTED if named else AMBER, false)
		b.tooltip_text = str(def.desc)
		b.disabled = named
		b.pressed.connect(_appoint_minister.bind(ministry))
		row.add_child(b)
		col.add_child(row)
	cabinet.add_child(col)
	main_column.add_child(cabinet)
	main_column.add_child(_coalition_panel())
	var governing_base := int(state.get("coalition_seats", 0))
	if governing_base <= 0:
		governing_base = int(state.lower_house_seats)
	if int(state.chamber_seats) > 0 and governing_base < int(state.majority):
		main_column.add_child(_formation_panel())
	main_column.add_child(_crisis_summary_panel())
	if Election.is_parliamentary(country):
		main_column.add_child(_early_election_panel())
	var policy := _panel_box()
	var pcol := VBoxContainer.new()
	pcol.add_child(_label("PROGRAMAS EXECUTIVOS", 12, SUBTLE))
	pcol.add_child(_label("Receita líquida mensal: M$ %s  ·  manutenção dos programas: M$ %s" % [_fmt_int(_monthly_income()), _fmt_int(_program_upkeep())], 13, MUTED))
	for id in PROGRAMS.keys():
		var def: Dictionary = PROGRAMS[id]
		var active: bool = state.policies.has(id)
		var b := _button("%s%s" % [def.label, "  ·  ATIVO" if active else "  ·  M$ %s" % _fmt_int(def.cost)], TEXT, false)
		b.tooltip_text = "%s  ·  manutenção M$ %d/mês" % [def.desc, int(def.upkeep)]
		b.disabled = active
		b.pressed.connect(_policy_action.bind(id))
		pcol.add_child(b)
	policy.add_child(pcol)
	main_column.add_child(policy)
	_build_right_rail()

func _appoint_minister(ministry: String) -> void:
	if not MINISTRIES.has(ministry) or state.ministers.has(ministry):
		return
	var def: Dictionary = MINISTRIES[ministry]
	if float(state.funds) < float(def.cost):
		_show_toast("Caixa insuficiente para o ministério", "error")
		return
	state.funds -= float(def.cost)
	_apply_effects(def.now)
	SocialGroups.apply_policy(state, ministry)
	InterestGroups.apply_policy(state, ministry)
	if def.has("region"):
		for i in state.region_support.size(): state.region_support[i] += float(def.region)
	state.ministers.append(ministry)
	state.minister_index += 1
	var allocation := PoliticalRelations.assign_ministry(state, str(state.abbr))
	var owner := str(allocation.get("party", ""))
	if owner != "":
		_push_news("A pasta de %s foi atribuída a %s (%d/%d da cota)." % [ministry, owner, int(allocation.get("assigned", 0)), int(allocation.get("promised", 0))])
	_push_news("%s nomeou o ministro de %s: %s." % [state.leader, ministry, def.desc])
	_clamp_state(); _save_game(); _show_game()

func _policy_action(policy: String) -> void:
	if not PROGRAMS.has(policy) or state.policies.has(policy):
		return
	var def: Dictionary = PROGRAMS[policy]
	if state.funds < float(def.cost):
		_show_toast("Orçamento insuficiente", "error")
		return
	state.funds -= float(def.cost)
	for key in def.now.keys():
		state[key] = float(state.get(key, 0.0)) + float(def.now[key])
	SocialGroups.apply_policy(state, policy)
	InterestGroups.apply_policy(state, policy)
	if def.has("region"):
		for i in state.region_support.size(): state.region_support[i] += float(def.region)
	state.policies.append(policy)
	_push_news("O governo lançou \"%s\": %s. Custa M$ %d por mês de manutenção." % [def.label, def.desc, int(def.upkeep)])
	_clamp_state(); _save_game(); _show_game()

## Programas ativos custam manutenção e rendem pequenos efeitos todo mês.
func _program_upkeep() -> float:
	var total := 0.0
	for id in state.policies:
		if PROGRAMS.has(id):
			total += float(PROGRAMS[id].upkeep)
	return total

func _apply_program_monthly() -> void:
	for id in state.policies:
		if not PROGRAMS.has(id):
			continue
		for key in PROGRAMS[id].monthly.keys():
			state[key] = float(state.get(key, 0.0)) + float(PROGRAMS[id].monthly[key])

## Receita do mês: contribuições e doações do partido; no governo, parte da
## arrecadação cresce com o PIB e com a aprovação. Menos a manutenção.
func _monthly_income() -> float:
	var income := 300.0 + float(state.members) * 0.35 + float(state.popularity) * 18.0
	if bool(state.government):
		income += 1200.0 + (float(state.gdp) - 100.0) * 6.0 + float(state.approval) * 12.0 - maxf(0.0, float(state.debt) - 60.0) * 8.0
		income -= _program_upkeep()
	return maxf(0.0, income)

func _show_economy() -> void:
	_show_section("Economia", "O que o país produz, quanto custa viver e como o emprego reage às suas decisões.")
	var growth := float(state.economy)
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	for item in [
		["CRESCIMENTO", "%+.1f%%" % growth, GREEN if growth >= 2.0 else (AMBER if growth >= 0.0 else RED), "economy"],
		["INFLAÇÃO", "%.1f%%" % state.inflation, RED if float(state.inflation) >= 6.0 else AMBER, "inflation"],
		["DESEMPREGO", "%.1f%%" % state.unemployment, RED if float(state.unemployment) >= 10.0 else AMBER, "unemployment"],
		["DÍVIDA/PIB", "%.0f%%" % state.debt, RED if float(state.debt) >= 80.0 else AMBER, "debt"],
	]:
		kpis.add_child(_kpi_card(str(item[0]), str(item[1]), item[2], _econ_delta(str(item[3]))))
	main_column.add_child(kpis)
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
	main_column.add_child(_economy_history_panel())
	var leitura := _panel_box()
	var lcol := VBoxContainer.new()
	lcol.add_child(_label("COMO LER", 12, AMBER))
	var how_label := _label("Crescimento melhora caixa e apoio, mas programas públicos pressionam a dívida antes de gerar produtividade. A inflação reage à dívida e ao ritmo da economia; o desemprego segue o crescimento com defasagem.", 14, MUTED)
	how_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lcol.add_child(how_label)
	leitura.add_child(lcol)
	main_column.add_child(leitura)
	main_column.add_child(_economy_sources_panel())
	if bool(state.government):
		var policy := _panel_box()
		var pcol := VBoxContainer.new()
		pcol.add_child(_label("PROGRAMAS EXECUTIVOS", 12, SUBTLE))
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
		"debt": float(data.get("debt", 0.0)),
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

## Série real do mandato: início, mês anterior, mês atual, variação absoluta e
## percentual, com a direção desejável de cada indicador.
func _profile_simulation(key: String) -> float:
	var profile: Dictionary = state.get("economic_profile", {}) if state.get("economic_profile") is Dictionary else {}
	var profile_key := "gdp_growth" if key == "economy" else key
	var entry: Variant = profile.get(profile_key, {})
	if not (entry is Dictionary):
		return 0.0
	return float((entry as Dictionary).get("simulation_value", (entry as Dictionary).get("value", 0.0)))

func _economy_history_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("DESEMPENHO NO MANDATO", 12, AMBER))
	col.add_child(_label("Série registrada mês a mês · comparação desde o início", 14, MUTED))
	col.add_child(_rule())
	var history: Array = state.get("economy_history", []) if state.get("economy_history") is Array else []
	if history.is_empty():
		col.add_child(_label("Sem série registrada nesta campanha.", 13, MUTED))
		panel.add_child(col)
		return panel
	var first: Dictionary = history[0] if history[0] is Dictionary else {}
	var current: Dictionary = history[history.size() - 1] if history[history.size() - 1] is Dictionary else {}
	var previous: Dictionary = history[history.size() - 2] if history.size() >= 2 and history[history.size() - 2] is Dictionary else current
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	for pair in [["INDICADOR", 150], ["INÍCIO", 78], ["MÊS", 78], ["MANDATO", 92], ["%", 62], ["DIREÇÃO", 60]]:
		header.add_child(_table_head(str(pair[0]), int(pair[1])))
	col.add_child(header)
	for spec in [["economy", "Crescimento", true, "%"], ["inflation", "Inflação", false, "%"], ["unemployment", "Desemprego", false, "%"], ["debt", "Dívida/PIB", false, "%"]]:
		var key := str(spec[0])
		var up_good := bool(spec[2])
		var now := float(current.get(key, 0.0))
		# Saves v5 antigos não tinham dívida na série: usa o perfil inicial.
		var start := float(first.get(key, _profile_simulation(key)))
		var prev := float(previous.get(key, now))
		var month_delta := now - prev
		var total_delta := now - start
		var pct := (total_delta / absf(start) * 100.0) if absf(start) > 0.001 else 0.0
		var direction := "→" if absf(total_delta) < 0.05 else ("↑" if total_delta > 0.0 else "↓")
		var tone := GREEN if (total_delta > 0.0) == up_good else (RED if absf(total_delta) >= 0.05 else MUTED)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_table_cell(str(spec[1]), 150, TEXT))
		row.add_child(_table_cell("%.1f%%" % start, 78, MUTED, true))
		row.add_child(_table_cell("%.1f%%" % now, 78, TEXT, true))
		row.add_child(_table_cell("%+.2f p.p." % total_delta, 92, tone, true))
		row.add_child(_table_cell("%+.1f%%" % pct, 62, tone, true))
		row.add_child(_table_cell("%s  mês %+.2f" % [direction, month_delta], 60, tone, true))
		col.add_child(row)
	col.add_child(_label("↑/↓ mostram a direção; verde/vermelho comparam com a direção desejável, não com a sua ideologia.", 11, MUTED))
	panel.add_child(col)
	return panel

func _table_head(text: String, width: int) -> Label:
	var label := _label(text, 10, SUBTLE)
	label.custom_minimum_size.x = width
	return label

func _table_cell(text: String, width: int, color: Color, tabular := false) -> Label:
	var label := _label(text, 13, color)
	label.custom_minimum_size.x = width
	if tabular:
		_tabular(label)
	return label

## Origem e status do dado de cada indicador, com ano de referência.
func _economy_sources_panel() -> PanelContainer:
	var profile: Dictionary = state.get("economic_profile", {}) if state.get("economic_profile") is Dictionary else {}
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("PAÍS E DADOS ECONÔMICOS", 12, AMBER))
	col.add_child(_label("Perfil inicial de %s · a simulação evolui a partir desta fotografia" % str(profile.get("name", state.get("country_name", "País"))), 14, MUTED))
	col.add_child(_rule())
	if profile.is_empty():
		col.add_child(_label("Perfil econômico indisponível para este save; os indicadores salvos foram preservados.", 13, MUTED))
		panel.add_child(col)
		return panel
	var labels := {"gdp_growth": "Crescimento", "inflation": "Inflação", "unemployment": "Desemprego", "debt": "Dívida/PIB", "gdp": "PIB nominal", "gdp_per_capita": "PIB per capita", "population": "População", "revenue": "Receita do governo", "expense": "Despesa do governo"}
	for key in ["gdp_growth", "inflation", "unemployment", "debt"]:
		var entry: Dictionary = profile.get(key, {}) if profile.get(key) is Dictionary else {}
		if entry.is_empty():
			continue
		var status := str(entry.get("status", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_table_cell(str(labels.get(key, key)), 150, TEXT))
		row.add_child(_table_cell(_format_indicator(key, float(entry.get("value", 0.0))) + "  " + str(entry.get("unit", "")), 200, TEXT, true))
		var badge := _label("OFICIAL" if status == "official" else "ESTIMATIVA", 10, GREEN if status == "official" else AMBER)
		badge.custom_minimum_size.x = 92
		row.add_child(badge)
		row.add_child(_table_cell("ref. %d" % int(entry.get("year", 0)), 72, MUTED, true))
		col.add_child(row)
		var source := str(entry.get("methodology", "")) if status == "estimated" else str(entry.get("source", ""))
		if source != "":
			var source_label := _label(source, 11, MUTED)
			source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(source_label)
	var context: Array = []
	for key in ["gdp", "gdp_per_capita", "population", "revenue", "expense"]:
		var entry: Dictionary = profile.get(key, {}) if profile.get(key) is Dictionary else {}
		if entry.is_empty():
			continue
		context.append("%s %s (%d)" % [str(labels.get(key, key)), _format_indicator(key, float(entry.get("value", 0.0))), int(entry.get("year", 0))])
	if not context.is_empty():
		col.add_child(_rule())
		var context_label := _label("Contexto: " + "  ·  ".join(PackedStringArray(context)), 11, MUTED)
		context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(context_label)
	col.add_child(_label("Fonte oficial: World Bank, World Development Indicators. Estimativas são marcadas e trazem metodologia; dados históricos só inicializam o país.", 11, SUBTLE))
	panel.add_child(col)
	return panel

func _format_indicator(key: String, value: float) -> String:
	match key:
		"gdp", "gdp_per_capita":
			return _fmt_usd(value)
		"population":
			return _fmt_people(value)
		"revenue", "expense":
			return "%.1f%% do PIB" % value
		_:
			return "%.2f%%" % value

func _fmt_usd(value: float) -> String:
	if absf(value) >= 1.0e12:
		return "US$ %.2f tri" % (value / 1.0e12)
	if absf(value) >= 1.0e9:
		return "US$ %.1f bi" % (value / 1.0e9)
	if absf(value) >= 1.0e6:
		return "US$ %.0f mi" % (value / 1.0e6)
	return "US$ %.0f" % value

func _fmt_people(value: float) -> String:
	if value >= 1.0e6:
		return "%.1f mi" % (value / 1.0e6)
	if value >= 1.0e3:
		return "%.0f mil" % (value / 1.0e3)
	return "%d" % int(value)

func _show_population() -> void:
	_show_section("População", "A população não vota como um bloco único: cada grupo pesa e reage de forma própria.")
	var demographics: Dictionary = state.demographics
	var strongest := ""
	var weakest := ""
	var best_value := -1.0
	var worst_value := 999.0
	var total := 0.0
	for key in demographics.keys():
		var value := float(demographics[key])
		total += value
		if value > best_value:
			best_value = value
			strongest = str(key)
		if value < worst_value:
			worst_value = value
			weakest = str(key)
	var average := total / maxf(1.0, float(demographics.size()))
	var tied := absf(best_value - worst_value) < 0.05
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_kpi_card("APOIO MÉDIO", "%.0f%%" % average, AMBER))
	kpis.add_child(_kpi_card("MAIOR APOIO", "—" if tied else "%s  %.0f%%" % [strongest, best_value], GREEN))
	kpis.add_child(_kpi_card("MENOR APOIO", "—" if tied else "%s  %.0f%%" % [weakest, worst_value], RED))
	kpis.add_child(_kpi_card("GRUPOS MONITORADOS", str(demographics.size()), TEXT))
	main_column.add_child(kpis)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("APOIO POR GRUPO DEMOGRÁFICO", 10, SUBTLE))
	for key in demographics.keys():
		var value := float(demographics[key])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(str(key), 14, TEXT)
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		row.add_child(_bar(value, 100.0, GREEN if value >= average else AMBER, 12.0))
		var pct := _label("%.0f%%" % value, 13, GREEN if value >= average else AMBER)
		pct.custom_minimum_size.x = 46
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		var delta := value - average
		var trend := _label("%+.1f p.p. vs média" % delta, 12, SUBTLE)
		trend.custom_minimum_size.x = 120
		trend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(trend)
		col.add_child(row)
	col.add_child(_rule())
	col.add_child(_label("O apoio abaixo da média indica onde a próxima ação de base rende mais.", 12, SUBTLE))
	panel.add_child(col)
	main_column.add_child(panel)
	# Envelope regional modelado: não é uma fonte demográfica nem altera a população canônica.
	var total_envelope := 0.0
	for region in regions:
		total_envelope += float(region.pop)
	var weight_panel := _panel_box()
	var wcol := VBoxContainer.new()
	wcol.add_child(_label("ENVELOPE REGIONAL MODELADO", 10, SUBTLE))
	wcol.add_child(_label("Leitura analítica estática — não é população canônica nem peso eleitoral (total do envelope: %.1f u.)" % total_envelope, 12, MUTED))
	for region in regions:
		var share := float(region.pop) / maxf(0.01, total_envelope) * 100.0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(str(region.name), 13, TEXT)
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		row.add_child(_bar(share, 25.0, AMBER, 9.0))
		var share_label := _label("%.1f%% do envelope  ·  %.1f u." % [share, float(region.pop)], 12, MUTED)
		share_label.custom_minimum_size.x = 110
		share_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(share_label)
		wcol.add_child(row)
	weight_panel.add_child(wcol)
	main_column.add_child(weight_panel)
	var social := _panel_box()
	var scol := VBoxContainer.new()
	scol.add_child(_label("INDICADORES SOCIAIS", 10, SUBTLE))
	var social_grid := HBoxContainer.new()
	social_grid.add_theme_constant_override("separation", 8)
	for item in [["POBREZA", "18,4%", RED], ["ACESSO À SAÚDE", "76%", GREEN], ["ESCOLARIDADE", "8,2 anos", AMBER]]:
		social_grid.add_child(_kpi_card(str(item[0]), str(item[1]), item[2]))
	scol.add_child(social_grid)
	scol.add_child(_label("Mudanças são lentas: políticas precisam de financiamento e execução para mover estes números.", 12, MUTED))
	social.add_child(scol)
	main_column.add_child(social)
	_build_right_rail()

func _show_society() -> void:
	_show_section("Sociedade", "Grupos sociais e organizações não são a mesma coisa: um mede a população, o outro organiza interesse.")
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("APOIO SOCIAL", "%.0f%%" % float(state.get("social_support", 50.0)), AMBER))
	kpis.add_child(_metric_card("RENDA MÉDIA", "%.0f%%" % float(state.get("income_support", 50.0)), TEXT))
	kpis.add_child(_metric_card("GREVES ATIVAS", str(InterestGroups.active_strikes(state).size()), RED if not InterestGroups.active_strikes(state).is_empty() else SUBTLE))
	kpis.add_child(_metric_card("ORGANIZAÇÕES", str(InterestGroups.definitions().size()), SUBTLE))
	main_column.add_child(kpis)
	main_column.add_child(_social_layer_panel("occupation", "CAMADA OCUPACIONAL  ·  base do índice eleitoral"))
	main_column.add_child(_social_layer_panel("income", "CAMADA DE RENDA  ·  análise separada, sem dupla contagem"))
	main_column.add_child(_interest_panel())
	main_column.add_child(_causal_panel())
	_build_right_rail()

func _social_layer_panel(layer: String, title: String) -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label(title, 12, AMBER))
	col.add_child(_label("Participações são modelo declarado; cada camada soma %.0f%% e uma pessoa pode aparecer nas duas sem ser contada duas vezes no voto." % (SocialGroups.layer_share(state, layer) * 100.0), 11, MUTED))
	var header := HBoxContainer.new()
	header.add_child(_table_head("GRUPO", 190))
	header.add_child(_table_head("PESO", 54))
	header.add_child(_table_head("APOIO", 210))
	header.add_child(_table_head("CONDIÇÃO", 76))
	header.add_child(_table_head("PRINCIPAIS PREOCUPAÇÕES", 300))
	col.add_child(header)
	for row in SocialGroups.sorted_groups(state, layer):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(_table_cell(str(row.label), 190, TEXT))
		line.add_child(_table_cell("%.0f%%" % (float(row.share) * 100.0), 54, MUTED, true))
		var bar := _bar(float(row.approval), 100.0, GREEN if float(row.approval) >= 45.0 else RED, 10.0)
		bar.custom_minimum_size.x = 120
		line.add_child(bar)
		line.add_child(_table_cell("%.0f%%" % float(row.approval), 60, GREEN if float(row.approval) >= 45.0 else RED, true))
		line.add_child(_table_cell("%.0f" % float(row.economic), 76, MUTED, true))
		var concerns: Array = row.get("concerns", [])
		line.add_child(_table_cell(", ".join(PackedStringArray(concerns)), 300, SUBTLE))
		col.add_child(line)
	panel.add_child(col)
	return panel

func _interest_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("ORGANIZAÇÕES DE INTERESSE  ·  B3", 12, AMBER))
	col.add_child(_label("Influência é capacidade de pressão; relação é histórico com o seu partido. Negociar custa M$ 800; pedir apoio consome a relação.", 12, MUTED))
	for row in InterestGroups.sorted_groups(state):
		var block := VBoxContainer.new()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(_label(str(row.name), 15, TEXT))
		head.add_child(_label("%s  ·  influência %.0f  ·  representa %.0f%%" % [str(row.kind), float(row.influence), float(row.represented_share) * 100.0], 11, SUBTLE))
		var relation := float(row.relationship)
		head.add_child(_label("relação %+.0f  ·  %s  ·  atividade %.0f" % [relation, str(row.stance), float(row.activity)], 12, GREEN if relation > 20.0 else RED if relation < -20.0 else MUTED))
		block.add_child(head)
		var strike: Dictionary = row.get("strike", {}) if row.get("strike") is Dictionary else {}
		var on_strike := bool(strike.get("active", false))
		block.add_child(_label("Pauta: %s  ·  queixa %.0f/100%s" % [", ".join(PackedStringArray(row.get("objectives", []))), float(row.get("grievance", 0.0)), "  ·  GREVE ATIVA HÁ %d MÊS(ES): %s" % [int(strike.get("months", 0)), str(strike.get("demand", ""))] if on_strike else ""], 12, RED if on_strike else MUTED))
		var actions := HBoxContainer.new()
		var negotiate := _button("NEGOCIAR GREVE  ·  M$ 1.400" if on_strike else "NEGOCIAR  ·  M$ 800", RED if on_strike else SUBTLE, false)
		negotiate.disabled = float(state.funds) < (1400.0 if on_strike else 800.0)
		negotiate.pressed.connect(_negotiate_interest.bind(str(row.id)))
		actions.add_child(negotiate)
		var endorse := _button("PEDIR APOIO", AMBER if relation >= 20.0 else MUTED, false)
		endorse.disabled = relation < 20.0 or on_strike
		endorse.pressed.connect(_endorse_interest.bind(str(row.id)))
		actions.add_child(endorse)
		block.add_child(actions)
		col.add_child(block)
		col.add_child(_rule())
	panel.add_child(col)
	return panel

func _negotiate_interest(id: String) -> void:
	var result := InterestGroups.negotiate(state, id)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Negociação indisponível")), "warning")
		return
	_push_news(str(result.get("reason", "Negociação concluída")))
	_clamp_state(); _save_game(); _show_game()
	_show_toast(str(result.get("reason", "Negociação concluída")), "success")

func _endorse_interest(id: String) -> void:
	var result := InterestGroups.endorse(state, id)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Endosso indisponível")), "warning")
		return
	_push_news(str(result.get("reason", "Endosso recebido")))
	_clamp_state(); _save_game(); _show_game()
	_show_toast(str(result.get("reason", "Endosso recebido")), "success")

func _causal_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("CADEIAS CAUSAIS  ·  O QUE PRODUZIU O QUÊ", 12, AMBER))
	col.add_child(_label("Cada registro liga uma decisão ou choque aos indicadores que ele moveu. Os efeitos continuam no mês seguinte enquanto a causa persistir.", 12, MUTED))
	var entries := CausalLog.recent(state, "", 8)
	if entries.is_empty():
		col.add_child(_label("Nenhuma cadeia registrada ainda. Greves, coalizões, escândalos e políticas aparecem aqui quando mudam o estado.", 13, MUTED))
	for entry in entries:
		var row := VBoxContainer.new()
		row.add_child(_label("%s  ·  %s  ·  %s" % [str(entry.get("month", "")), CausalLog.label(str(entry.get("domain", ""))), str(entry.get("cause", ""))], 12, AMBER))
		var text := _label(str(entry.get("explanation", "")), 12, TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var effect_text := _format_causal_effects(entry.get("effects", {}) if entry.get("effects") is Dictionary else {})
		if effect_text != "":
			row.add_child(_label(effect_text, 11, MUTED))
		col.add_child(row)
	panel.add_child(col)
	return panel

func _format_causal_effects(effects: Dictionary) -> String:
	var parts: Array = []
	var labels := {"economy": "crescimento", "gdp": "PIB", "inflation": "inflação", "unemployment": "desemprego", "debt": "dívida", "approval": "aprovação", "popularity": "popularidade", "credibility": "credibilidade", "cohesion": "coesão", "coalition_cohesion": "coesão da coalizão", "relationship": "relação", "media": "cobertura", "campaign": "campanha", "campaign_penalty": "penalidade eleitoral", "funds": "caixa", "evidence": "evidência"}
	for key in effects.keys():
		var value := float(effects[key]) if str(effects[key]).is_valid_float() else 0.0
		if absf(value) < 0.01:
			continue
		parts.append("%s %s%.1f" % [str(labels.get(str(key), key)), "+" if value > 0.0 else "", value])
	return "  ·  ".join(PackedStringArray(parts))

func _crisis_summary_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	var cases := Scandals.active(state)
	col.add_child(_label("INTEGRIDADE E CRISES", 12, AMBER))
	col.add_child(_label("Casos abertos: %d  ·  penalidade ativa: %.1f p.p.  ·  risco mensal: %.1f%%" % [cases.size(), float(state.get("scandal_penalty", 0.0)), Scandals.risk(state) * 100.0], 14, RED if not cases.is_empty() else MUTED))
	if cases.is_empty():
		col.add_child(_label("Nenhuma apuração em curso. Transparência preventiva reduz o risco estrutural.", 12, MUTED))
	else:
		var case: Dictionary = cases[0]
		col.add_child(_label("%s  ·  %s  ·  %s  ·  cobertura %.0f" % [str(case.get("title", "")), Scandals.stage_label(str(case.get("stage", "alegacao"))), Scandals.legal_label(str(case.get("legal", "unproven"))), float(case.get("media", 20.0))], 13, TEXT))
	var b := _button("VER TIMELINE E RESPONDER", AMBER, false)
	b.pressed.connect(_select_nav.bind("Crises"))
	col.add_child(b)
	panel.add_child(col)
	return panel

func _show_crises() -> void:
	_show_section("Crises", "Alegação não é condenação. Cada caso tem estágio, status jurídico e consequências próprias.")
	_append_geopolitical_crises()
	var cases := Scandals.active(state)
	var counts := Scandals.status_counts(state)
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("CASOS ABERTOS", str(cases.size()), RED if not cases.is_empty() else GREEN))
	kpis.add_child(_metric_card("PENALIDADE", "%.1f p.p." % float(state.get("scandal_penalty", 0.0)), RED if float(state.get("scandal_penalty", 0.0)) > 0.0 else GREEN))
	kpis.add_child(_metric_card("RISCO MENSAL", "%.1f%%" % (Scandals.risk(state) * 100.0), AMBER))
	kpis.add_child(_metric_card("CONFIRMADOS", str(counts.get("confirmed", 0)), RED if int(counts.get("confirmed", 0)) > 0 else MUTED))
	main_column.add_child(kpis)
	if cases.is_empty():
		var empty := _panel_box()
		var ecol := VBoxContainer.new()
		ecol.add_child(_label("NENHUMA APURAÇÃO ABERTA", 12, SUBTLE))
		ecol.add_child(_label("O risco sobe com credibilidade baixa, coalizão frágil e financiamento privado de campanha. Abrir uma auditoria preventiva custa M$ 700 e reduz a exposição.", 14, MUTED))
		var audit := _button("ABRIR AUDITORIA PREVENTIVA  ·  M$ 700", SUBTLE, false)
		audit.disabled = float(state.funds) < 700.0
		audit.pressed.connect(_preventive_audit)
		ecol.add_child(audit)
		empty.add_child(ecol)
		main_column.add_child(empty)
	for case in cases:
		main_column.add_child(_scandal_case_panel(case))
	if not (state.get("scandal_history", []) as Array).is_empty():
		var history := _panel_box()
		var hcol := VBoxContainer.new()
		hcol.add_child(_label("CASOS ENCERRADOS", 12, SUBTLE))
		for closed in (state.scandal_history as Array).slice(0, mini(4, (state.scandal_history as Array).size())):
			hcol.add_child(_label("%s  ·  %s" % [str(closed.get("title", "")), Scandals.legal_label(str(closed.get("legal", "unresolved")))], 13, MUTED))
		history.add_child(hcol)
		main_column.add_child(history)
	_build_right_rail()

func _scandal_case_panel(case: Dictionary) -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	var stage_index := int(case.get("stage_index", 0))
	col.add_child(_label("%s  ·  %s" % [str(case.get("category_label", "CASO")), str(case.get("opened", ""))], 10, SUBTLE))
	col.add_child(_label(str(case.get("title", "Caso")), 20, TEXT))
	col.add_child(_label("Estágio: %s  ·  status jurídico: %s  ·  resposta: %s" % [Scandals.stage_label(str(case.get("stage", "alegacao"))), Scandals.legal_label(str(case.get("legal", "unproven"))), str(case.get("response", "nenhuma"))], 13, AMBER if stage_index < 4 else RED))
	col.add_child(_label("Procedimento: %s  ·  cobertura %.0f/100  ·  evidência %d/5  ·  cooperação %d" % [Scandals.procedure_label(str(case.get("procedure", "alegacao"))), float(case.get("media", 20.0)), int(case.get("evidence", 0)), int(case.get("cooperation", 0))], 12, MUTED))
	var stages: Array = Scandals.config().get("stages", [])
	var timeline := HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 4)
	for i in stages.size():
		var mark := "OK" if i < stage_index else "AGORA" if i == stage_index else "..."
		var color := AMBER if i == stage_index else TEXT if i < stage_index else SUBTLE
		timeline.add_child(_label("%s %s" % [mark, Scandals.stage_label(str(stages[i]))], 10, color))
	col.add_child(timeline)
	var case_history: Array = case.get("history", []) if case.get("history") is Array else []
	for entry in case_history.slice(maxi(0, case_history.size() - 3), case_history.size()):
		col.add_child(_label("%s  ·  %s" % [str(entry.get("month", "")), str(entry.get("note", ""))], 12, MUTED))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	for action in ["cooperate", "investigate", "replace", "defend", "transparency"]:
		var response: Dictionary = Scandals.config().get("responses", {}).get(action, {})
		var b := _button(str(response.get("label", action)), SUBTLE, false)
		b.tooltip_text = str(response.get("hint", ""))
		b.disabled = float(state.funds) < float(response.get("cost", 0))
		b.pressed.connect(_scandal_response.bind(str(case.get("id", "")), action))
		actions.add_child(b)
	col.add_child(actions)
	panel.add_child(col)
	return panel

func _scandal_response(case_id: String, action: String) -> void:
	var result := Scandals.respond(state, case_id, action)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Resposta indisponível")), "warning")
		return
	_push_news(str(result.get("reason", "Resposta ao caso")))
	state["scandal_penalty"] = Scandals.penalty(state)
	_clamp_state(); _save_game(); _show_game()
	_show_toast(str(result.get("reason", "Resposta registrada")), "success")

func _preventive_audit() -> void:
	if float(state.funds) < 700.0:
		return
	state.funds -= 700.0
	var finance: Dictionary = state.get("campaign_finance", {}) if state.get("campaign_finance") is Dictionary else {}
	finance["risk"] = maxf(0.0, float(finance.get("risk", 0.0)) - 12.0)
	state["campaign_finance"] = finance
	state.credibility = clampf(float(state.credibility) + 2.0, 0.0, 100.0)
	_push_news("Auditoria preventiva aberta: risco de crise reduzido, credibilidade +2.")
	_clamp_state(); _save_game(); _show_game()

func _append_geopolitical_crises() -> void:
	Conflict.ensure(state, countries)
	GlobalShock.ensure(state)
	var g: Dictionary = state.get("geopolitics", {})
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("SEGURANÇA INTERNACIONAL · FASE E2", 12, AMBER))
	col.add_child(_label("Conflitos e choques são consequências rastreáveis de tensão, capacidades, dependências e decisões — não modificadores isolados de popularidade.", 12, MUTED))
	var conflicts: Array = g.get("conflicts", []) if g.get("conflicts") is Array else []
	var active := 0
	for conflict in conflicts:
		if str(conflict.get("status", "")) in ["tensao", "confronto", "hostilidades", "escalada", "impasse", "negociacao", "cessar_fogo", "congelado"]:
			active += 1
	col.add_child(_label("Conflitos ativos: %d  ·  crises diplomáticas: %d  ·  choques globais: %d" % [active, (g.get("crises", []) as Array).size(), (g.get("shocks", []) as Array).size()], 13, TEXT))
	for conflict in conflicts.slice(0, 4):
		var status := str(conflict.get("status", ""))
		var row := HBoxContainer.new()
		var label := _label("%s × %s · %s · frente %+.0f · pressão %.0f" % [str(conflict.get("a_name", conflict.get("a", ""))), str(conflict.get("b_name", conflict.get("b", ""))), status, float(conflict.get("front", 0.0)), float(conflict.get("peace_pressure", 0.0))], 12, RED if status in ["hostilidades", "escalada"] else AMBER)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var id := str(conflict.get("id", ""))
		for action in ["negociar", "mediar", "cessar_fogo", "retirada"]:
			var button := _button(action.to_upper(), SUBTLE, false)
			button.disabled = str(conflict.get("a", "")) != str(state.get("country_id", "")) and str(conflict.get("b", "")) != str(state.get("country_id", ""))
			button.pressed.connect(_e2_conflict_action.bind(id, action))
			row.add_child(button)
		col.add_child(row)
	for shock in (g.get("shocks", []) as Array).slice(0, 3):
		if str(shock.get("status", "")) == "ativo":
			col.add_child(_label("Choque global: %s · severidade %.0f · %d mês(es) restantes" % [str(shock.get("label", "choque")), float(shock.get("severity", 0.0)) * 100.0, int(shock.get("months_left", 0))], 12, RED))
	if active == 0 and (g.get("shocks", []) as Array).is_empty():
		col.add_child(_label("Nenhum conflito ou choque E2 ativo neste momento.", 13, GREEN))
	panel.add_child(col)
	main_column.add_child(panel)

func _e2_conflict_action(conflict_id: String, action: String) -> void:
	var result := Conflict.player_conflict_action(state, conflict_id, action)
	_show_toast(str(result.get("reason", "Ação registrada")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		_save_game()
		_show_crises()

func _show_defense() -> void:
	_show_section("Defesa", "Capacidades estratégicas, prontidão, aquisições e mobilização com custos fiscais reais.")
	Military.ensure(state, countries, economy_catalog)
	var id := str(state.get("country_id", "BR"))
	var summary := Military.summary(state, id)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("CAPACIDADE NACIONAL · %s" % str(summary.get("name", id)), 12, AMBER))
	col.add_child(_label("Capacidade composta %.1f/100 · pessoal %.1f · equipamento %.0f · logística %.0f · tecnologia %.0f · indústria %.0f" % [float(summary.get("capability", 0.0)), float(summary.get("personnel", 0.0)), float(summary.get("equipment", 0.0)), float(summary.get("logistics", 0.0)), float(summary.get("tech", 0.0)), float(summary.get("industry", 0.0))], 14, TEXT))
	col.add_child(_label("Defesa %.2f%% do PIB · orçamento M$ %.2f · prontidão %.0f · mobilização: %s" % [float(summary.get("defense_share", 0.0)), float(summary.get("budget_billions", 0.0)), float(summary.get("readiness", 0.0)), str(summary.get("mobilization", "nenhuma"))], 13, MUTED))
	var actions := HFlowContainer.new()
	for level in ["parcial", "geral", "desmobilizar"]:
		var button := _button("MOBILIZAÇÃO %s" % level.to_upper(), AMBER if level != "desmobilizar" else SUBTLE, false)
		button.pressed.connect(_e2_mobilize.bind(level))
		actions.add_child(button)
	for item in ["equipamento", "tecnologia", "infraestrutura", "manutencao", "defesa_industrial"]:
		var button := _button("ADQUIRIR %s" % item.to_upper(), SUBTLE, false)
		button.pressed.connect(_e2_procure.bind(item))
		actions.add_child(button)
	col.add_child(actions)
	var queue: Array = summary.get("procurement", []) if summary.get("procurement") is Array else []
	for program in queue:
		col.add_child(_label("Aquisição: %s · %d mês(es) restantes · %s" % [str(program.get("label", "")), int(program.get("months_left", 0)), str(program.get("status", ""))], 12, GREEN))
	panel.add_child(col)
	main_column.add_child(panel)
	_build_right_rail()

func _e2_mobilize(level: String) -> void:
	var result := Military.mobilize(state, str(state.get("country_id", "BR")), level)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		_clamp_state()
		_save_game()
		_show_defense()

func _e2_procure(item: String) -> void:
	var result := Military.start_procurement(state, str(state.get("country_id", "BR")), item, true)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		_save_game()
		_show_defense()

func _show_regions() -> void:
	_show_section("Regiões", "Clique numa região no mapa para ver economia, problemas e apoio.")
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", UI.GAP)
	# O globo desta tela é o cenário de fundo (SHOW_GLOBE); a malha é o dado.
	var map := BOARD_SCRIPT.new()
	map.custom_minimum_size = Vector2(0, 400)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.set_map(state, regions)
	map.region_clicked.connect(_select_region)
	split.add_child(map)
	var detail := _panel_box()
	detail.custom_minimum_size.x = 262
	var col := VBoxContainer.new()
	var r: Dictionary = regions[selected_region]
	col.add_child(_label("REGIÃO %02d  ·  %s" % [selected_region + 1, str(r.kind)], 10, SUBTLE))
	col.add_child(_label(str(r.name), 24, TEXT))
	col.add_child(_rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for pair in [
		["Envelope regional modelado", "%.1f u." % float(r.pop)],
		["Renda média", "%d" % int(r.income)],
		["Desemprego", "%.1f%%" % float(r.unemployment)],
		["Apoio ao partido", "%.0f%%" % float(state.region_support[selected_region])],
	]:
		grid.add_child(_label(str(pair[0]), 12, SUBTLE))
		var value := _label(str(pair[1]), 16, AMBER if str(pair[0]) == "Apoio ao partido" else TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
	col.add_child(grid)
	col.add_child(_label("O envelope regional é modelado e não representa população canônica nem peso eleitoral.", 11, MUTED))
	col.add_child(_spacer(6))
	col.add_child(_bar(float(state.region_support[selected_region]), 100.0, AMBER, 10.0))
	col.add_child(_spacer(10))
	col.add_child(_label("PROBLEMA CENTRAL", 10, SUBTLE))
	var problem := _label(str(r.problem), 15, TEXT)
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(problem)
	detail.add_child(col)
	split.add_child(detail)
	main_column.add_child(split)
	# Ranking de apoio: comparação direta entre os oito territórios.
	var ranking := _panel_box()
	var rcol := VBoxContainer.new()
	rcol.add_child(_label("APOIO POR REGIÃO", 10, SUBTLE))
	for i in regions.size():
		var region: Dictionary = regions[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(str(region.name), 13, TEXT if i == selected_region else MUTED)
		name_label.custom_minimum_size.x = 130
		row.add_child(name_label)
		var support := float(state.region_support[i])
		row.add_child(_bar(support, 100.0, AMBER if i == selected_region else SUBTLE, 9.0))
		var pct := _label("%.0f%%" % support, 12, AMBER if i == selected_region else MUTED)
		pct.custom_minimum_size.x = 42
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		rcol.add_child(row)
	ranking.add_child(rcol)
	main_column.add_child(ranking)
	_build_right_rail()

func _select_region(index: int) -> void:
	selected_region = index
	_show_regions()

## Esta tela apenas exibe a decisão internacional já gerada na simulação.
## Nenhuma chamada de IA acontece ao abrir a aba.
func _show_international() -> void:
	_show_section("Internacional", "Sala de situação: relações, comércio, riscos e decisões com efeitos internos.")
	International.ensure(state, countries, economy_catalog)
	var intl: Dictionary = state.get("international_state", {})
	var overview := _panel_box()
	var ocol := VBoxContainer.new()
	ocol.add_child(_label("DOUTRINA EXTERNA  ·  %s" % str(intl.get("policy_label", "")), 16, AMBER))
	ocol.add_child(_label("Credibilidade %.0f/100  ·  valores históricos têm referência; efeitos depois do início são simulados." % float(intl.get("policy_credibility", 50.0)), 13, MUTED))
	var policy_row := HFlowContainer.new()
	for policy in International.POLICIES:
		var pb := _button(str(International.POLICY_LABELS.get(policy, policy)), AMBER if str(intl.get("policy", "")) == policy else SUBTLE, false)
		pb.pressed.connect(_intl_policy.bind(policy))
		policy_row.add_child(pb)
	ocol.add_child(policy_row)
	overview.add_child(ocol)
	main_column.add_child(overview)
	var offers_panel := _panel_box()
	var offcol := VBoxContainer.new()
	offcol.add_child(_label("MESA DE NEGOCIAÇÃO  ·  OFERTAS PENDENTES", 12, AMBER))
	var offers: Array = intl.get("offers", [])
	for offer_index in offers.size():
		var offer: Dictionary = offers[offer_index]
		if str(offer.get("status", "")) != "pending": continue
		var offer_row := HBoxContainer.new()
		var offer_lbl := _label("%s · %s · responde em %d mes(es)" % [str(offer.get("label", "")), str(offer.get("country", "")), int(offer.get("expires_in", 0))], 13, TEXT)
		offer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer_row.add_child(offer_lbl)
		var accept := _button("ACEITAR", AMBER, false)
		accept.pressed.connect(_intl_offer.bind(offer_index, true))
		offer_row.add_child(accept)
		var refuse := _button("RECUSAR", SUBTLE, false)
		refuse.pressed.connect(_intl_offer.bind(offer_index, false))
		offer_row.add_child(refuse)
		offcol.add_child(offer_row)
	if offcol.get_child_count() == 1:
		offcol.add_child(_label("Nenhuma oferta pendente: parceiros propõem quando a relação amadurece ou a tensão sobe.", 13, MUTED))
	offers_panel.add_child(offcol)
	main_column.add_child(offers_panel)
	var profile_panel := _panel_box()
	var pcol := VBoxContainer.new()
	pcol.add_child(_label("PAÍSES E RELAÇÕES MULTIDIMENSIONAIS", 12, AMBER))
	pcol.add_child(_label("Cooperação, alinhamento político, parceria econômica, interdependência comercial, confiança, segurança e tensão não são a mesma variável.", 12, MUTED))
	var profiles: Dictionary = intl.get("profiles", {})
	for id in profiles.keys():
		var profile: Dictionary = profiles[id]
		var rel: Dictionary = International.profile(state, str(id)).get("relation", {})
		var row := HBoxContainer.new()
		row.add_child(_label("%s [%s]" % [str(profile.get("name", id)), str(id)], 13, TEXT))
		var metrics := _label("coop %.0f · comércio %.0f · confiança %.0f · tensão %.0f · %s" % [float(rel.get("cooperation", 0.0)), float(rel.get("economic_partnership", 0.0)), float(rel.get("strategic_trust", 0.0)), float(rel.get("tension", 0.0)), str(International.stance(rel))], 11, MUTED)
		metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(metrics)
		for action in ["meeting", "protest", "trade", "sanction", "investment"]:
			var label: String = str({"meeting":"REUNIÃO", "protest":"PROTESTO", "trade":"ACORDO", "sanction":"SANÇÃO", "investment":"INVESTIR"}.get(action, action))
			var b := _button(str(label), SUBTLE, false)
			b.pressed.connect(_intl_action.bind(str(id), action))
			row.add_child(b)
		pcol.add_child(row)
	profile_panel.add_child(pcol)
	main_column.add_child(profile_panel)
	var events_panel := _panel_box()
	var ecol := VBoxContainer.new()
	ecol.add_child(_label("EVENTOS E COMPROMISSOS", 12, AMBER))
	for event in (intl.get("events", []) as Array).slice(0, 5):
		ecol.add_child(_label("• %s" % str(event.get("headline", "")), 13, TEXT))
	for treaty in (intl.get("treaties", []) as Array).slice(0, 5):
		ecol.add_child(_label("Tratado %s: %s · %s" % [str(treaty.get("kind", "")), str(treaty.get("country", "")), str(treaty.get("status", ""))], 13, GREEN))
	if ecol.get_child_count() == 1:
		ecol.add_child(_label("Nenhum evento ou tratado registrado.", 13, MUTED))
	events_panel.add_child(ecol)
	main_column.add_child(events_panel)
	var governance := _panel_box()
	var gcol := VBoxContainer.new()
	gcol.add_child(_label("INSTITUIÇÕES E FINANCIAMENTO", 12, AMBER))
	var treaties: Array = intl.get("treaties", [])
	for treaty_index in treaties.size():
		var treaty: Dictionary = treaties[treaty_index]
		var treaty_row := HBoxContainer.new()
		var treaty_status := str(treaty.get("status", ""))
		if treaty_status == "active":
			treaty_status = "ativo · expira em %d mes(es)" % int(treaty.get("expires_in", 0))
		elif treaty_status == "pending_ratification":
			treaty_status = "aguarda ratificação · %d mes(es) restantes" % maxi(0, int(International.TREATY_PENDING_MONTHS) - int(treaty.get("months_pending", 0)))
		var treaty_lbl := _label("Tratado %s · %s · %s" % [str(treaty.get("kind", "")), str(treaty.get("country", "")), treaty_status], 13, TEXT)
		treaty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		treaty_row.add_child(treaty_lbl)
		if str(treaty.get("status", "")) == "pending_ratification":
			var ratify := _button("RATIFICAR", AMBER, false)
			ratify.pressed.connect(_intl_ratify.bind(treaty_index))
			treaty_row.add_child(ratify)
		gcol.add_child(treaty_row)
	for org_id in (intl.get("organizations", {}) as Dictionary).keys():
		var org: Dictionary = intl.organizations[org_id]
		var org_row := HBoxContainer.new()
		var org_lbl := _label("%s · compromisso %.0f%% · %s" % [str(org_id), float(org.get("commitment", 0.0)) * 100.0, str(org.get("rule", ""))], 12, MUTED)
		org_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		org_row.add_child(org_lbl)
		if bool(org.get("member", false)):
			var vote := _button("VOTAR", SUBTLE, false)
			vote.pressed.connect(_intl_vote.bind(str(org_id)))
			org_row.add_child(vote)
		else:
			org_row.add_child(_label("NÃO MEMBRO", 11, MUTED))
		gcol.add_child(org_row)
	for bloc_id in (intl.get("blocs", {}) as Dictionary).keys():
		var bloc: Dictionary = intl.blocs[bloc_id]
		var bloc_row := HBoxContainer.new()
		var bloc_lbl := _label("Bloco %s · %s · membros %d" % [str(bloc.get("label", bloc_id)), str(bloc.get("status", "")), (bloc.get("members", []) as Array).size()], 12, MUTED)
		bloc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc_row.add_child(bloc_lbl)
		var join := _button("ADERIR", SUBTLE, false)
		join.pressed.connect(_intl_bloc.bind(str(bloc_id)))
		bloc_row.add_child(join)
		var loan := _button("EMPRÉSTIMO 1% PIB", SUBTLE, false)
		loan.pressed.connect(_intl_loan.bind(str(intl.get("profiles", {}).keys()[0]) if not (intl.get("profiles", {}) as Dictionary).is_empty() else ""))
		bloc_row.add_child(loan)
		gcol.add_child(bloc_row)
	governance.add_child(gcol)
	main_column.add_child(governance)
	var crisis_panel := _panel_box()
	var ccol := VBoxContainer.new()
	ccol.add_child(_label("CRISES EM ESTÁGIOS", 12, AMBER))
	for crisis_index in (intl.get("crises", []) as Array).size():
		var crisis: Dictionary = intl.crises[crisis_index]
		var crisis_row := HBoxContainer.new()
		var crisis_lbl := _label("%s · estágio %d/%d · %s" % [str(crisis.get("headline", "")), int(crisis.get("stage", 1)), int(crisis.get("stages", 3)), str(crisis.get("status", ""))], 12, RED if str(crisis.get("status", "")) == "open" else GREEN)
		crisis_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crisis_row.add_child(crisis_lbl)
		if str(crisis.get("status", "")) == "open":
			for response in ["negociar", "diversificar", "isolar"]:
				var rb := _button(response.to_upper(), SUBTLE, false)
				rb.pressed.connect(_intl_crisis.bind(crisis_index, response))
				crisis_row.add_child(rb)
		ccol.add_child(crisis_row)
	if ccol.get_child_count() == 1:
		ccol.add_child(_label("Nenhuma crise multietapa ativa.", 13, MUTED))
	crisis_panel.add_child(ccol)
	main_column.add_child(crisis_panel)
	_build_right_rail()

func _intl_policy(policy: String) -> void:
	var result := International.set_policy(state, policy)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		_clamp_state(); _save_game(); _show_international()

func _intl_action(id: String, action: String) -> void:
	var result: Dictionary
	if action == "trade": result = International.trade_agreement(state, id)
	elif action == "sanction": result = International.sanction(state, id)
	elif action == "investment": result = International.investment(state, id)
	else: result = International.diplomatic_action(state, id, action)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		International.refresh(state); _clamp_state(); _save_game(); _show_international()

func _intl_offer(index: int, accept: bool) -> void:
	var result := International.respond_offer(state, index, accept)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		International.refresh(state); _clamp_state(); _save_game(); _show_international()

func _intl_ratify(index: int) -> void:
	var result := International.ratify_treaty(state, index)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)): International.refresh(state); _save_game(); _show_international()

func _intl_vote(org_id: String) -> void:
	var result := International.organization_vote(state, org_id, "cooperação e desenvolvimento", true)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)): International.refresh(state); _save_game(); _show_international()

func _intl_bloc(bloc_id: String) -> void:
	var result := International.join_bloc(state, bloc_id)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)): International.refresh(state); _save_game(); _show_international()

func _intl_loan(id: String) -> void:
	var result := International.foreign_loan(state, id, 1.0)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)): _save_game(); _show_international()

func _intl_crisis(index: int, response: String) -> void:
	var result := International.crisis_response(state, index, response)
	_show_toast(str(result.get("reason", "")), "success" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)): International.refresh(state); _save_game(); _show_international()

## E1.J — visão do mundo autônomo. A tela lê o estado já simulado no mês;
## nenhuma decisão de país acontece ao abrir a aba. Filtro por região e detalhe
## por país usam a mesma fonte de verdade de WorldSim.
func _show_world() -> void:
	_show_section("Mundo", "Enquanto você governa, outros países elegem governos, votam leis e mudam de trajetória econômica.")
	WorldSim.ensure(state, countries, economy_catalog)
	var world: Dictionary = state.get("world", {}) if state.get("world") is Dictionary else {}
	var summary := WorldSim.summary(state)
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_kpi_card("PAÍSES ATIVOS", str(int(summary.get("countries", 0))), TEXT))
	kpis.add_child(_kpi_card("ELEIÇÕES · 12 MESES", str(int(summary.get("elections_12m", 0))), AMBER))
	kpis.add_child(_kpi_card("CRESCIMENTO MÉDIO", "%.1f%%" % float(summary.get("avg_growth", 0.0)), GREEN if float(summary.get("avg_growth", 0.0)) >= 0.0 else RED))
	kpis.add_child(_kpi_card("ESTABILIDADE MÉDIA", "%.0f/100" % float(summary.get("avg_stability", 0.0)), AMBER))
	main_column.add_child(kpis)
	var countries_map: Dictionary = world.get("countries", {}) if world.get("countries") is Dictionary else {}
	var regions := []
	for id in countries_map.keys():
		var region := str((countries_map[id] as Dictionary).get("region", ""))
		if region != "" and not regions.has(region):
			regions.append(region)
	regions.sort()
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	filters.add_child(_label("REGIÃO", 10, SUBTLE))
	var region_select := OptionButton.new()
	world_region_options = ["Todas"] + regions
	for option in world_region_options:
		region_select.add_item(str(option))
	var selected := world_region_options.find(world_region_filter)
	region_select.select(selected if selected >= 0 else 0)
	region_select.item_selected.connect(_world_region_changed)
	filters.add_child(region_select)
	filters.add_child(_label("%d países com partidos e câmaras simuláveis; Haiti fica de fora por falta de dados partidários." % int(summary.get("countries", 0)), 11, MUTED))
	main_column.add_child(filters)
	var stats: Dictionary = world.get("stats", {}) if world.get("stats") is Dictionary else {}
	main_column.add_child(_label("DESDE O INÍCIO  ·  %d eleições  ·  %d trocas de governo  ·  %d votações (%d derrotas)  ·  %d acordos" % [int(stats.get("elections", 0)), int(stats.get("government_changes", 0)), int(stats.get("votes", 0)), int(stats.get("defeats", 0)), int(stats.get("agreements", 0))], 11, MUTED))
	var table_panel := _panel_box()
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 3)
	tcol.add_child(_label("PAÍSES · GOVERNO, ECONOMIA E PRÓXIMA ELEIÇÃO", 12, AMBER))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	for spec in [["PAÍS", 160], ["SIST.", 66], ["GOV.", 62], ["APROV.", 58], ["CRESC.", 56], ["INFLA.", 56], ["DÍVIDA", 56], ["ESTAB.", 56], ["ELEIÇÃO", 66], ["", 40]]:
		head.add_child(_world_cell(str(spec[0]), int(spec[1]), SUBTLE, 10))
	tcol.add_child(head)
	tcol.add_child(_rule())
	var ids := countries_map.keys()
	ids.sort_custom(func(a, b): return str(countries_map[a].get("name", a)) < str(countries_map[b].get("name", b)))
	var shown := 0
	for raw_id in ids:
		var id := str(raw_id)
		var wc: Dictionary = countries_map[id]
		if world_region_filter != "Todas" and str(wc.get("region", "")) != world_region_filter:
			continue
		var profile: Dictionary = state.get("international_state", {}).get("profiles", {}).get(id, {}) if state.get("international_state") is Dictionary else {}
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_world_cell(str(wc.get("name", id)), 160, TEXT))
		row.add_child(_world_cell("PARL." if str(wc.get("system", "")) == "parlamentar" else "PRES.", 66, MUTED, 11))
		row.add_child(_world_cell(str(wc.get("government_party", "")), 62, AMBER, 11))
		row.add_child(_world_cell("%.0f%%" % float(wc.get("approval", 0.0)), 58, TEXT, 11))
		row.add_child(_world_cell("%+.1f%%" % float(profile.get("growth", 0.0)), 56, GREEN if float(profile.get("growth", 0.0)) >= 0.0 else RED, 11))
		row.add_child(_world_cell("%.1f%%" % float(profile.get("inflation", 0.0)), 56, TEXT, 11))
		row.add_child(_world_cell("%.0f%%" % float(profile.get("debt", 0.0)), 56, TEXT, 11))
		row.add_child(_world_cell("%.0f" % float(wc.get("stability", 0.0)), 56, AMBER if float(wc.get("stability", 0.0)) < 45.0 else TEXT, 11))
		row.add_child(_world_cell(_world_next_election(int(wc.get("months_to_election", 0))), 66, MUTED, 11))
		var view_button := _button("VER", SUBTLE, false)
		view_button.custom_minimum_size.x = 40
		view_button.add_theme_font_size_override("font_size", 9)
		view_button.pressed.connect(_show_world_country.bind(id))
		row.add_child(view_button)
		tcol.add_child(row)
		shown += 1
	if shown == 0:
		tcol.add_child(_label("Nenhum país nesta região.", 13, MUTED))
	table_panel.add_child(tcol)
	main_column.add_child(table_panel)
	var news_panel := _panel_box()
	var ncol := VBoxContainer.new()
	ncol.add_child(_label("GIRO DO MUNDO · NOTÍCIAS DERIVADAS DE FATOS", 12, AMBER))
	for item in (summary.get("news", []) as Array):
		var news_row := HBoxContainer.new()
		news_row.add_theme_constant_override("separation", 10)
		news_row.add_child(_world_cell(str(item.get("date", "")), 64, MUTED, 11))
		news_row.add_child(_world_cell(str(item.get("country", "")), 60, AMBER, 11))
		var headline := _label(str(item.get("headline", "")), 13, TEXT)
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		news_row.add_child(headline)
		news_row.add_child(_world_cell(_world_status(str(item.get("status", "confirmado"))), 84, _world_status_color(str(item.get("status", "confirmado"))), 10))
		ncol.add_child(news_row)
	if (summary.get("news", []) as Array).is_empty():
		ncol.add_child(_label("Sem notícias ainda. Avance o mês para o mundo começar a gerar história.", 13, MUTED))
	news_panel.add_child(ncol)
	main_column.add_child(news_panel)
	var history_panel := _panel_box()
	var hcol := VBoxContainer.new()
	hcol.add_child(_label("ÚLTIMOS FATOS REGISTRADOS", 12, AMBER))
	for event in (summary.get("recent", []) as Array):
		var event_row := HBoxContainer.new()
		event_row.add_theme_constant_override("separation", 10)
		event_row.add_child(_world_cell(str(event.get("date", "")), 64, MUTED, 11))
		event_row.add_child(_world_cell(str(event.get("country_name", event.get("country", ""))), 120, TEXT, 10))
		event_row.add_child(_world_cell(_world_category(str(event.get("category", ""))), 86, AMBER, 10))
		var description := _label(str(event.get("description", "")), 13, TEXT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_row.add_child(description)
		hcol.add_child(event_row)
	if (summary.get("recent", []) as Array).is_empty():
		hcol.add_child(_label("O mundo ainda não registrou fatos nesta campanha.", 13, MUTED))
	history_panel.add_child(hcol)
	main_column.add_child(history_panel)

func _world_region_changed(index: int) -> void:
	if index >= 0 and index < world_region_options.size():
		world_region_filter = str(world_region_options[index])
	_show_world()

func _world_cell(text: String, width: int, color: Color, font_size := 13) -> Label:
	var label := _label(text, font_size, color)
	label.custom_minimum_size.x = width
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _world_next_election(months: int) -> String:
	if months <= 0:
		return "agora"
	return "em %d m" % months

func _world_category(category: String) -> String:
	return str({"eleicao": "ELEIÇÃO", "governo": "GOVERNO", "coalizao": "COALIZÃO", "legislativo": "CONGRESSO", "politica": "POLÍTICA", "lideranca": "LIDERANÇA", "diplomacia": "DIPLOMACIA", "economia": "ECONOMIA", "escandalo": "ESCÂNDALO", "investigacao": "INVESTIGAÇÃO"}.get(category, category.to_upper()))

func _world_status(status: String) -> String:
	return str({"confirmado": "CONFIRMADO", "oficial": "OFICIAL", "alegacao": "ALEGAÇÃO", "investigacao": "INVESTIGAÇÃO", "em_apuracao": "EM APURAÇÃO", "sem_desfecho": "SEM DESFECHO", "absolvido": "ABSOLVIDO", "projecao": "PROJEÇÃO"}.get(status, status.to_upper()))

func _world_status_color(status: String) -> Color:
	if status in ["alegacao", "investigacao", "em_apuracao", "sem_desfecho"]:
		return AMBER
	if status == "projecao":
		return MUTED
	return GREEN

## Detalhe de um país: governo, partidos, macro e história recente, tudo lido do
## estado simulado. Não há globo 3D nem chamada de IA.
func _show_world_country(id: String) -> void:
	var view := WorldSim.country_view(state, id)
	if view.is_empty():
		_show_toast("País sem dados simuláveis", "warning")
		_show_world()
		return
	var profile: Dictionary = view.get("profile", {}) if view.get("profile") is Dictionary else {}
	_show_section(str(view.get("name", id)), "Governo, partidos, economia e história recente de %s [%s]." % [str(view.get("name", id)), id])
	var back := _button("‹ VOLTAR AO MUNDO", SUBTLE, false)
	back.pressed.connect(_show_world)
	main_column.add_child(back)
	var gov_kpis := HBoxContainer.new()
	gov_kpis.add_theme_constant_override("separation", 8)
	gov_kpis.add_child(_kpi_card("GOVERNO", str(view.get("government_party", "")), AMBER, str(profile.get("government", ""))))
	gov_kpis.add_child(_kpi_card("APROVAÇÃO", "%.0f%%" % float(view.get("approval", 0.0)), TEXT))
	gov_kpis.add_child(_kpi_card("ESTABILIDADE", "%.0f/100" % float(view.get("stability", 0.0)), AMBER))
	gov_kpis.add_child(_kpi_card("PRÓXIMA ELEIÇÃO", _world_next_election(int(view.get("months_to_election", 0))), TEXT))
	main_column.add_child(gov_kpis)
	var macro_kpis := HBoxContainer.new()
	macro_kpis.add_theme_constant_override("separation", 8)
	macro_kpis.add_child(_kpi_card("CRESCIMENTO", "%+.1f%%" % float(profile.get("growth", 0.0)), GREEN if float(profile.get("growth", 0.0)) >= 0.0 else RED))
	macro_kpis.add_child(_kpi_card("INFLAÇÃO", "%.1f%%" % float(profile.get("inflation", 0.0)), RED if float(profile.get("inflation", 0.0)) >= 8.0 else TEXT))
	macro_kpis.add_child(_kpi_card("DESEMPREGO", "%.1f%%" % float(profile.get("unemployment", 0.0)), RED if float(profile.get("unemployment", 0.0)) >= 12.0 else TEXT))
	macro_kpis.add_child(_kpi_card("DÍVIDA/PIB", "%.0f%%" % float(profile.get("debt", 0.0)), AMBER))
	main_column.add_child(macro_kpis)
	var government := _panel_box()
	var gcol := VBoxContainer.new()
	gcol.add_child(_label("FORMA DE GOVERNO", 12, AMBER))
	gcol.add_child(_label("Sistema %s · mandato de %d meses · prioridade atual: %s" % ["parlamentar" if str(view.get("system", "")) == "parlamentar" else "presidencial", int(view.get("term_months", 0)), str(view.get("policy_priority", ""))], 14, TEXT))
	var partners: Array = view.get("coalition_partners", []) if view.get("coalition_partners") is Array else []
	gcol.add_child(_label("Base: %s · %d de %d cadeiras · coesão %.0f/100" % ["governo de maioria" if partners.is_empty() else "coalizão com " + ", ".join(PackedStringArray(partners)), int(view.get("coalition_seats", 0)), int(view.get("chamber_seats", 0)), float(view.get("coalition_cohesion", 0.0))], 14, TEXT))
	var relation: Dictionary = view.get("relation", {}) if view.get("relation") is Dictionary else {}
	if relation.is_empty():
		gcol.add_child(_label("Relação com o seu país: sem registro.", 13, MUTED))
	else:
		gcol.add_child(_label("Relação com o seu país: cooperação %.0f · confiança %.0f · tensão %.0f" % [float(relation.get("cooperation", 0.0)), float(relation.get("strategic_trust", 0.0)), float(relation.get("tension", 0.0))], 13, MUTED))
	if view.get("last_election") is Dictionary and not (view.last_election as Dictionary).is_empty():
		var election: Dictionary = view.last_election
		gcol.add_child(_label("Última eleição: %02d/%d · vencedor %s · %s" % [int(election.get("month", 0)), int(election.get("year", 0)), str(election.get("winner", "")), "governo trocou" if bool(election.get("changed_government", false)) else "governo reeleito"], 13, MUTED))
	government.add_child(gcol)
	main_column.add_child(government)
	var parties_panel := _panel_box()
	var pcol := VBoxContainer.new()
	pcol.add_child(_label("PARTIDOS E BANCADAS", 12, AMBER))
	var phead := HBoxContainer.new()
	phead.add_theme_constant_override("separation", 4)
	for spec in [["PARTIDO", 170], ["CADEIRAS", 60], ["APOIO", 55], ["PAPEL", 80], ["ESTAB.", 55], ["LIDERANÇA", 150]]:
		phead.add_child(_world_cell(str(spec[0]), int(spec[1]), SUBTLE, 10))
	pcol.add_child(phead)
	pcol.add_child(_rule())
	var parties: Dictionary = view.get("parties", {}) if view.get("parties") is Dictionary else {}
	var party_list := []
	for key in parties.keys():
		party_list.append(parties[key])
	party_list.sort_custom(func(a, b): return int(a.get("seats", 0)) > int(b.get("seats", 0)))
	for party in party_list:
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 4)
		prow.add_child(_world_cell("%s · %s" % [str(party.get("abbr", "")), str(party.get("name", ""))], 170, TEXT, 12))
		prow.add_child(_world_cell(str(int(party.get("seats", 0))), 60, TEXT, 12))
		prow.add_child(_world_cell("%.1f%%" % float(party.get("support", 0.0)), 55, AMBER, 12))
		var role := "GOVERNO" if bool(party.get("in_gov", false)) else ("APOIO" if bool(party.get("in_coalition", false)) else "OPOSIÇÃO")
		prow.add_child(_world_cell(role, 80, AMBER if role != "OPOSIÇÃO" else MUTED, 10))
		prow.add_child(_world_cell("%.0f" % float(party.get("stability", 0.0)), 55, TEXT, 12))
		prow.add_child(_world_cell(str(party.get("leader", "—")), 150, MUTED, 11))
		pcol.add_child(prow)
	if party_list.is_empty():
		pcol.add_child(_label("Sem partidos registrados.", 13, MUTED))
	parties_panel.add_child(pcol)
	main_column.add_child(parties_panel)
	var history_panel := _panel_box()
	var hcol := VBoxContainer.new()
	hcol.add_child(_label("HISTÓRIA RECENTE", 12, AMBER))
	for event in (view.get("history", []) as Array):
		var event_row := HBoxContainer.new()
		event_row.add_theme_constant_override("separation", 10)
		event_row.add_child(_world_cell(str(event.get("date", "")), 64, MUTED, 11))
		event_row.add_child(_world_cell(_world_category(str(event.get("category", ""))), 90, AMBER, 10))
		event_row.add_child(_world_cell(_world_status(str(event.get("status", "confirmado"))), 96, _world_status_color(str(event.get("status", "confirmado"))), 10))
		var description := _label(str(event.get("description", "")), 13, TEXT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_row.add_child(description)
		hcol.add_child(event_row)
	if (view.get("history", []) as Array).is_empty():
		hcol.add_child(_label("Sem eventos registrados para este país.", 13, MUTED))
	history_panel.add_child(hcol)
	main_column.add_child(history_panel)

func _show_news() -> void:
	_show_section("Notícias", "Newsroom simulada: fatos comuns, enquadramentos diferentes e rastreabilidade até o evento original.")
	PhaseFInformation.ensure(state)
	var articles: Array = PhaseFInformation.articles(state, 180)
	var outlets := ["Todos"]
	var categories := ["Todas"]
	var statuses := ["Todos"]
	for article in articles:
		var outlet := str(article.get("outlet_name", ""))
		var category := str(article.get("category", ""))
		var status := str(article.get("status", "confirmado"))
		if outlet != "" and not outlets.has(outlet): outlets.append(outlet)
		if category != "" and not categories.has(category): categories.append(category)
		if status != "" and not statuses.has(status): statuses.append(status)
	var filters := _panel_box()
	var fcol := VBoxContainer.new()
	fcol.add_child(_label("FILTROS DA NEWSROOM", 12, AMBER))
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	news_search = _line(news_query)
	news_search.placeholder_text = "Buscar manchete, fato ou fonte"
	news_search.custom_minimum_size.x = 250
	news_search.text_changed.connect(_news_search_changed)
	filter_row.add_child(news_search)
	var search_button := _button("BUSCAR", AMBER, false)
	search_button.pressed.connect(_show_news)
	filter_row.add_child(search_button)
	news_outlet_select = _news_option(outlets, news_outlet_filter)
	news_outlet_select.item_selected.connect(_news_outlet_changed)
	filter_row.add_child(news_outlet_select)
	news_category_select = _news_option(categories, news_category_filter)
	news_category_select.item_selected.connect(_news_category_changed)
	filter_row.add_child(news_category_select)
	news_status_select = _news_option(statuses, news_status_filter)
	news_status_select.item_selected.connect(_news_status_changed)
	filter_row.add_child(news_status_select)
	fcol.add_child(filter_row)
	fcol.add_child(_label("O mesmo evento pode aparecer em vários veículos; o filtro não altera os fatos arquivados.", 11, MUTED))
	filters.add_child(fcol)
	main_column.add_child(filters)
	var shown := 0
	for article in articles:
		if not _news_matches(article): continue
		var article_card := _panel_box()
		var article_col := VBoxContainer.new()
		article_col.add_child(_label("%s  ·  %s  ·  %s" % [str(article.get("outlet_name", "Veículo")), str(article.get("date", "")), _world_status(str(article.get("status", "confirmado")))], 11, AMBER))
		var headline := _label(str(article.get("headline", "")), 16, TEXT)
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		article_col.add_child(headline)
		var basis := _label("FATO-BASE: " + str(article.get("factual_basis", "")), 12, MUTED)
		basis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		article_col.add_child(basis)
		var detail := _button("ABRIR ARTIGO", SUBTLE, false)
		detail.pressed.connect(_show_article_detail.bind(article))
		article_col.add_child(detail)
		article_card.add_child(article_col)
		main_column.add_child(article_card)
		shown += 1
	if shown == 0:
		main_column.add_child(_label("Nenhum artigo corresponde aos filtros atuais.", 14, MUTED))
	_build_right_rail()

func _news_option(values: Array, selected: String) -> OptionButton:
	var option := OptionButton.new()
	for value in values:
		option.add_item(str(value))
	var index := values.find(selected)
	option.select(index if index >= 0 else 0)
	option.custom_minimum_size.x = 150
	return option

func _news_matches(article: Dictionary) -> bool:
	if news_outlet_filter != "Todos" and str(article.get("outlet_name", "")) != news_outlet_filter: return false
	if news_category_filter != "Todas" and str(article.get("category", "")) != news_category_filter: return false
	if news_status_filter != "Todos" and str(article.get("status", "")) != news_status_filter: return false
	if news_query.strip_edges() == "": return true
	var haystack := (str(article.get("headline", "")) + " " + str(article.get("factual_basis", "")) + " " + str(article.get("source_id", ""))).to_lower()
	return haystack.contains(news_query.strip_edges().to_lower())

func _news_search_changed(value: String) -> void:
	news_query = value

func _news_outlet_changed(index: int) -> void:
	news_outlet_filter = news_outlet_select.get_item_text(index)
	_show_news()

func _news_category_changed(index: int) -> void:
	news_category_filter = news_category_select.get_item_text(index)
	_show_news()

func _news_status_changed(index: int) -> void:
	news_status_filter = news_status_select.get_item_text(index)
	_show_news()

func _show_article_detail(article: Dictionary) -> void:
	_show_section(str(article.get("headline", "Artigo")), "Detalhe editorial e rastreabilidade do evento original.")
	var back := _button("‹ VOLTAR À NEWSROOM", SUBTLE, false)
	back.pressed.connect(_show_news)
	main_column.add_child(back)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("%s  ·  %s" % [str(article.get("outlet_name", "Veículo")), str(article.get("date", ""))], 12, AMBER))
	col.add_child(_label("STATUS: %s  ·  TIPO: %s" % [_world_status(str(article.get("status", "confirmado"))), str(article.get("source_type", "simulation_event"))], 12, MUTED))
	col.add_child(_rule())
	col.add_child(_label("FATO-BASE", 11, SUBTLE))
	var fact := _label(str(article.get("factual_basis", "")), 16, TEXT)
	fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(fact)
	col.add_child(_label("ENQUADRAMENTO EDITORIAL", 11, SUBTLE))
	col.add_child(_label(str(article.get("frame", "")), 14, TEXT))
	col.add_child(_label("EVENTO ORIGINAL: " + str(article.get("source_id", "")), 12, AMBER))
	var causal_evidence: Array = article.get("causal_evidence", []) if article.get("causal_evidence") is Array else []
	var causal_panel := _panel_box()
	var causal_col := VBoxContainer.new()
	causal_col.add_child(_label("CADEIA CAUSAL REGISTRADA", 11, AMBER))
	if causal_evidence.is_empty():
		causal_col.add_child(_label("Nenhum registro causal compatível foi encontrado para este evento; a ausência não implica ausência de causa na simulação.", 12, MUTED))
	else:
		for evidence in causal_evidence:
			if not (evidence is Dictionary):
				continue
			causal_col.add_child(_label("[%s] %s" % [str(evidence.get("month", "")), str(evidence.get("cause", ""))], 13, TEXT))
			causal_col.add_child(_label("Efeito registrado: %s" % str(evidence.get("effects", {})), 12, MUTED))
			causal_col.add_child(_label("Explicação: %s" % str(evidence.get("explanation", "")), 12, MUTED))
	causal_panel.add_child(causal_col)
	col.add_child(causal_panel)
	var context := _panel_box()
	var context_col := VBoxContainer.new()
	context_col.add_child(_label("NAVEGAÇÃO CONTEXTUAL", 11, AMBER))
	var context_row := HFlowContainer.new()
	var event_button := _button("EVENTO ORIGINAL", SUBTLE, false)
	event_button.pressed.connect(_show_history)
	context_row.add_child(event_button)
	var party_button := _button("PARTIDO", SUBTLE, false)
	party_button.pressed.connect(_show_party)
	context_row.add_child(party_button)
	var country_id := str(article.get("country", ""))
	var country_button := _button("PAÍS " + (country_id if country_id != "" else "DE ORIGEM"), SUBTLE, false)
	country_button.pressed.connect(_show_article_country.bind(country_id))
	context_row.add_child(country_button)
	var indicator_button := _button("INDICADORES", SUBTLE, false)
	indicator_button.pressed.connect(_show_economy)
	context_row.add_child(indicator_button)
	context_col.add_child(context_row)
	var actors: Array = article.get("actors", []) if article.get("actors") is Array else []
	if not actors.is_empty():
		context_col.add_child(_label("ATORES", 11, SUBTLE))
		var actor_row := HFlowContainer.new()
		for actor in actors:
			var actor_button := _button(str(actor), SUBTLE, false)
			actor_button.pressed.connect(_show_article_actor.bind(str(actor)))
			actor_row.add_child(actor_button)
		context_col.add_child(actor_row)
	else:
		context_col.add_child(_label("ATORES: sem identificadores no evento original.", 12, MUTED))
	context.add_child(context_col)
	col.add_child(context)
	col.add_child(_label("CONSEQUÊNCIAS REGISTRADAS: " + ", ".join(PackedStringArray(article.get("consequences", []) as Array)), 12, MUTED))
	panel.add_child(col)
	main_column.add_child(panel)
	_build_right_rail()

func _show_article_country(country_id: String) -> void:
	if country_id == "" or country_id == str(state.get("country_id", "")):
		_show_economy()
		return
	var view := WorldSim.country_view(state, country_id)
	if view.is_empty():
		_show_toast("País sem perfil navegável neste registro", "warning")
		_show_history()
		return
	_show_world_country(country_id)

func _show_article_actor(actor_name: String) -> void:
	PhaseFInformation.ensure(state)
	var biographies: Dictionary = state.phase_f.get("biographies", {}) if state.phase_f.get("biographies") is Dictionary else {}
	var profile: Dictionary = {}
	for candidate in biographies.values():
		if candidate is Dictionary and str(candidate.get("name", "")) == actor_name:
			profile = candidate
			break
	if profile.is_empty():
		_show_toast("Ator sem biografia catalogada: " + actor_name, "warning")
		_show_news()
		return
	_show_section(str(profile.get("name", actor_name)), "Biografia política derivada de eventos e posições da simulação.")
	var back := _button("‹ VOLTAR À NEWSROOM", SUBTLE, false)
	back.pressed.connect(_show_news)
	main_column.add_child(back)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("PERFIL DE SIMULAÇÃO", 12, AMBER))
	col.add_child(_label("Nome: %s  ·  País: %s  ·  Partido: %s" % [str(profile.get("name", actor_name)), str(profile.get("country", "")), str(profile.get("party", ""))], 15, TEXT))
	col.add_child(_label("Cargo atual: %s  ·  Tipo: %s" % [str(profile.get("current_role", "não informado")), str(profile.get("kind", "simulação"))], 13, MUTED))
	col.add_child(_rule())
	col.add_child(_label("TRAJETÓRIA REGISTRADA", 11, SUBTLE))
	var career_history: Array = profile.get("career", []) if profile.get("career") is Array else []
	for career in career_history:
		if career is Dictionary:
			col.add_child(_label("• %s  ·  %s" % [str(career.get("date", "")), str(career.get("event", ""))], 13, TEXT))
		else:
			col.add_child(_label("• %s" % str(career), 13, TEXT))
	panel.add_child(col)
	main_column.add_child(panel)
	_build_right_rail()

func _show_history() -> void:
	_show_section("História política", "O placar é o rastro de decisões, não só o resultado final.")
	var panel := _panel_box(); var col := VBoxContainer.new(); col.add_child(_label("LINHA DO TEMPO", 12, SUBTLE))
	if state.history.is_empty(): col.add_child(_label("Ainda não há eleições registradas. %s." % _next_election_label(), 16, MUTED))
	for item in state.history: col.add_child(_label("• " + str(item), 15, TEXT))
	panel.add_child(col); main_column.add_child(panel)
	PhaseFInformation.ensure(state)
	var archive_panel := _panel_box()
	var archive_col := VBoxContainer.new()
	archive_col.add_child(_label("ARQUIVO HISTÓRICO PERSISTENTE", 12, AMBER))
	archive_col.add_child(_label("Registros derivados dos eventos da simulação; o identificador de origem evita duplicatas entre meses e saves.", 12, MUTED))
	var archive: Array = PhaseFInformation.archive(state, 24)
	if archive.is_empty():
		archive_col.add_child(_label("O arquivo será preenchido quando houver fatos registrados.", 14, MUTED))
	for event in archive:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_world_cell(str(event.get("date", "")), 70, MUTED, 11))
		row.add_child(_world_cell(_world_category(str(event.get("category", ""))), 100, AMBER, 10))
		row.add_child(_world_cell(_world_status(str(event.get("status", "confirmado"))), 100, _world_status_color(str(event.get("status", "confirmado"))), 10))
		var description := _label(str(event.get("description", event.get("headline", ""))), 13, TEXT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		archive_col.add_child(row)
	archive_panel.add_child(archive_col)
	main_column.add_child(archive_panel)
	var report := PhaseFInformation.latest_report(state)
	if not report.is_empty():
		var report_panel := _panel_box()
		var report_col := VBoxContainer.new()
		report_col.add_child(_label("LEITURA ANALÍTICA  ·  %s" % str(report.get("title", "Relatório")), 12, AMBER))
		report_col.add_child(_label(str(report.get("executive_summary", "")), 14, TEXT))
		report_col.add_child(_label("PROJEÇÃO CONDICIONAL: " + str(report.get("conditional_outlook", "")), 12, MUTED))
		report_col.add_child(_label("Confiança: %s  ·  Acesso: %s  ·  Não é previsão certa." % [str(report.get("confidence", "")), str(report.get("access", "público"))], 11, SUBTLE))
		report_panel.add_child(report_col)
		main_column.add_child(report_panel)
		_build_right_rail()

func _show_intelligence() -> void:
	_show_section("Análise e inteligência", "Relatórios derivados de fatos da simulação; estimativas, interpretações e projeções aparecem separadas.")
	PhaseFInformation.ensure(state)
	var reports: Array = state.phase_f.get("reports", []) if state.phase_f.get("reports") is Array else []
	var polls: Array = state.phase_f.get("polls", []) if state.phase_f.get("polls") is Array else []
	var intro := _panel_box()
	var intro_col := VBoxContainer.new()
	intro_col.add_child(_label("CENTRO DE ANÁLISE", 12, AMBER))
	intro_col.add_child(_label("Fatos vêm do estado e dos eventos registrados. Estimativas dependem de método. Interpretações e projeções são condicionais e não representam conhecimento onisciente.", 13, MUTED))
	intro_col.add_child(_label("Relatórios disponíveis: %d  ·  Pesquisas simuladas: %d  ·  Última atualização: %s" % [reports.size(), polls.size(), str(state.phase_f.get("last_tick", "não registrada"))], 12, SUBTLE))
	intro.add_child(intro_col)
	main_column.add_child(intro)
	if not polls.is_empty() and polls[0] is Dictionary:
		var poll: Dictionary = polls[0]
		var poll_panel := _panel_box()
		var poll_col := VBoxContainer.new()
		poll_col.add_child(_label("PESQUISA · %s" % str(poll.get("fieldwork_date", "")), 12, AMBER))
		poll_col.add_child(_label("Estimativa: %.1f%%  ·  média móvel (%d pontos): %.1f%%  ·  margem: ±%.1f p.p." % [float(poll.get("estimate", 0.0)), int(poll.get("series_window", 1)), float(poll.get("moving_average", poll.get("estimate", 0.0))), float(poll.get("margin_of_error", 0.0))], 14, TEXT))
		poll_col.add_child(_label(str(poll.get("segment_note", "")), 11, MUTED))
		for segment in poll.get("segments", []):
			if segment is Dictionary:
				poll_col.add_child(_label("• %s: %.1f%% · n=%d" % [str(segment.get("label", "segmento")), float(segment.get("estimate", 0.0)), int(segment.get("sample_size", 0))], 12, TEXT))
		poll_panel.add_child(poll_col)
		main_column.add_child(poll_panel)
	if reports.is_empty():
		var empty := _panel_box()
		empty.add_child(_label("Ainda não há relatório analítico. Avance um mês para registrar o primeiro boletim.", 14, MUTED))
		main_column.add_child(empty)
	else:
		for report in reports.slice(0, 12):
			if not (report is Dictionary):
				continue
			var item: Dictionary = report
			var panel := _panel_box()
			var col := VBoxContainer.new()
			col.add_child(_label("%s  ·  %s  ·  %s" % [str(item.get("title", "Relatório")), str(item.get("date", "")), str(item.get("area", "geral")).to_upper()], 14, AMBER))
			col.add_child(_label(str(item.get("executive_summary", "")), 14, TEXT))
			col.add_child(_rule())
			col.add_child(_label("FATOS OBSERVADOS", 11, GREEN))
			var facts: Array = item.get("facts", []) if item.get("facts") is Array else []
			if facts.is_empty():
				col.add_child(_label("Sem fatos estruturados neste relatório.", 12, MUTED))
			for fact in facts:
				if fact is Dictionary:
					col.add_child(_label("• %s: %s" % [str(fact.get("label", "indicador")), str(fact.get("value", ""))], 13, TEXT))
			col.add_child(_label("ESTIMATIVAS", 11, AMBER))
			var estimates: Array = item.get("estimates", []) if item.get("estimates") is Array else []
			for estimate in estimates:
				if estimate is Dictionary:
					col.add_child(_label("• %s: %s" % [str(estimate.get("label", "estimativa")), str(estimate.get("value", ""))], 13, TEXT))
			col.add_child(_label("INTERPRETAÇÕES", 11, AMBER))
			var interpretations: Array = item.get("interpretations", []) if item.get("interpretations") is Array else []
			if interpretations.is_empty():
				col.add_child(_label("Nenhuma interpretação adicional registrada.", 12, MUTED))
			for interpretation in interpretations:
				col.add_child(_label("• " + str(interpretation), 13, TEXT))
			col.add_child(_label("PROJEÇÃO CONDICIONAL", 11, SUBTLE))
			col.add_child(_label(str(item.get("conditional_outlook", "Sem projeção condicional.")), 13, MUTED))
			col.add_child(_label("Confiança: %s  ·  Acesso: %s  ·  Fonte: %s" % [str(item.get("confidence", "não informado")), str(item.get("access", "público")), str(item.get("source", "simulação"))], 11, SUBTLE))
			var assumptions: Array = item.get("assumptions", []) if item.get("assumptions") is Array else []
			var limitations: Array = item.get("limitations", []) if item.get("limitations") is Array else []
			col.add_child(_label("Premissas: %s" % ("; ".join(PackedStringArray(assumptions)) if not assumptions.is_empty() else "não informadas"), 11, MUTED))
			col.add_child(_label("Limitações: %s" % ("; ".join(PackedStringArray(limitations)) if not limitations.is_empty() else "não informadas"), 11, MUTED))
			var report_causal: Array = item.get("causal_evidence", []) if item.get("causal_evidence") is Array else []
			if not report_causal.is_empty():
				col.add_child(_label("EVIDÊNCIA CAUSAL RECENTE", 11, AMBER))
				for causal in report_causal.slice(0, 3):
					if causal is Dictionary:
						col.add_child(_label("• %s: %s → %s" % [str(causal.get("month", "")), str(causal.get("cause", "")), str(causal.get("effects", {}))], 11, MUTED))
			panel.add_child(col)
			main_column.add_child(panel)
	_build_right_rail()

func _show_encyclopedia() -> void:
	_show_section("Enciclopédia", "Países, partidos, instituições, leis, organizações e conceitos derivados dos dados da campanha.")
	PhaseFInformation.ensure(state)
	var entries: Dictionary = state.phase_f.get("encyclopedia", {}) if state.phase_f.get("encyclopedia") is Dictionary else {}
	var rows: Array = entries.values()
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return (str(a.get("kind", "")) + str(a.get("title", ""))) < (str(b.get("kind", "")) + str(b.get("title", ""))))
	var summary := _panel_box()
	var summary_col := VBoxContainer.new()
	summary_col.add_child(_label("CATÁLOGO DERIVADO", 12, AMBER))
	summary_col.add_child(_label("%d entradas persistentes · fonte de cada registro visível · sem fatos inventados fora da simulação." % rows.size(), 13, MUTED))
	summary.add_child(summary_col)
	main_column.add_child(summary)
	for raw_entry in rows.slice(0, 80):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var panel := _panel_box()
		var col := VBoxContainer.new()
		col.add_child(_label("%s  ·  %s" % [str(entry.get("kind", "registro")).to_upper(), str(entry.get("title", "Entrada"))], 14, AMBER))
		col.add_child(_label(str(entry.get("summary", "")), 13, TEXT))
		var meta := "Fonte: %s" % str(entry.get("source", "não informado"))
		if str(entry.get("country", "")) != "": meta += "  ·  País: " + str(entry.get("country", ""))
		if str(entry.get("leader", "")) != "": meta += "  ·  Líder: " + str(entry.get("leader", ""))
		col.add_child(_label(meta, 11, SUBTLE))
		panel.add_child(col)
		main_column.add_child(panel)
	_build_right_rail()

func _show_settings() -> void:
	_show_section("Configurações", "Salvamento local e recuperação da campanha.")
	var panel := _panel_box(); var col := VBoxContainer.new(); col.add_child(_label("DADOS DA CAMPANHA", 12, AMBER)); col.add_child(_label("Salvamento automático após decisões e avanço de mês.", 15, TEXT))
	var actions := HBoxContainer.new(); var save := _button("SALVAR AGORA", SUBTLE, false); save.pressed.connect(_manual_save); actions.add_child(save); var export_b := _button("EXPORTAR JSON", AMBER, false); export_b.pressed.connect(_export_data); actions.add_child(export_b); var import_b := _button("IMPORTAR JSON", TEXT, false); import_b.pressed.connect(_import_data); actions.add_child(import_b); col.add_child(actions); 	status_label = _label("Arquivo local: user://mandatia_save.json", 13, MUTED); col.add_child(status_label); panel.add_child(col); main_column.add_child(panel)
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
	var guide := _panel_box()
	var gcol := VBoxContainer.new()
	gcol.add_child(_label("GUIA DO JOGADOR", 12, AMBER))
	var seen: Array = state.get("tutorial_seen", []) if state.get("tutorial_seen") is Array else []
	gcol.add_child(_label("Cartões vistos: %d de %d  ·  %s" % [seen.size(), TUTORIAL_STEPS.size(), "concluído" if bool(state.get("tutorial_done", false)) else "em andamento"], 14, TEXT))
	gcol.add_child(_label("O guia explica partido, campanha, eleição, coalizão, plenário, governo, economia e o avanço mensal — um cartão por tela.", 13, MUTED))
	var guide_button := _button("REINICIAR GUIA", SUBTLE, false)
	guide_button.pressed.connect(_restart_tutorial)
	gcol.add_child(guide_button)
	guide.add_child(gcol)
	main_column.add_child(guide)
	_build_right_rail()

func _advance_month() -> void:
	_hide_tutorial_callout()
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
	_month_snapshot = _metric_snapshot()
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
	var gov := bool(state.government)
	var potential := 2.6 - maxf(0.0, float(state.debt) - 60.0) * 0.03 - maxf(0.0, float(state.inflation) - 4.0) * 0.12
	state.economy = clampf(float(state.economy) + (potential - float(state.economy)) * 0.12, -2.0, 6.0)
	# Inflação: demanda aquecida e dívida empurram para cima; a âncora de expectativas puxa de volta a 4,5%.
	state.inflation = clampf(float(state.inflation) + (float(state.economy) - 2.4) * 0.05 + (float(state.debt) - 60.0) * 0.006 + (4.5 - float(state.inflation)) * 0.04, 1.5, 15.0)
	# Desemprego: lei de Okun com reversão à taxa natural de 7%.
	state.unemployment = clampf(float(state.unemployment) - (float(state.economy) - 2.5) * 0.06 + (7.0 - float(state.unemployment)) * 0.02, 3.5, 18.0)
	# C1-C6: arrecadação, orçamento, ministérios, projetos, serviços e dívida
	# fecham o mês no mesmo fluxo de caixa. A fachada devolve o resultado e
	# aplica apenas os efeitos que decorrem dessas variáveis.
	Government.monthly(state)
	International.monthly(state, countries, economy_catalog)
	WorldSim.monthly(state, countries, economy_catalog)
	# E2: defesa e geopolítica avançada fecham o mês depois do mundo autônomo.
	# O país do jogador usa um perfil-ponte para que os custos militares alterem
	# dívida, crescimento e inflação sem criar uma segunda fonte macroeconômica.
	var military_ids: Array = (state.get("geopolitics", {}).get("military", {}) as Dictionary).keys()
	for raw_id in military_ids:
		var military_id := str(raw_id)
		var at_war := false
		for conflict in (state.get("geopolitics", {}).get("conflicts", []) as Array):
			if str(conflict.get("status", "")) in ["hostilidades", "escalada", "impasse"] and (str(conflict.get("a", "")) == military_id or str(conflict.get("b", "")) == military_id):
				at_war = true
				break
		var macro: Dictionary
		if military_id == str(state.get("country_id", "")):
			macro = {"debt": float(state.get("debt", 60.0)), "growth": float(state.get("economy", 2.0)), "inflation": float(state.get("inflation", 4.5))}
		else:
			macro = state.get("international_state", {}).get("profiles", {}).get(military_id, {})
		var military_result := Military.monthly(state, military_id, macro, at_war, Military.threat_for(state, military_id), int(state.date_year), int(state.date_month))
		if military_id == str(state.get("country_id", "")) and not macro.is_empty():
			state["debt"] = clampf(float(macro.get("debt", state.debt)), 0.0, 220.0)
			state["economy"] = clampf(float(macro.get("growth", state.economy)), -12.0, 10.0)
			state["inflation"] = clampf(float(macro.get("inflation", state.inflation)), 1.5, 45.0)
	# Conflitos, contratos E2 e choques são sistemas globais: um tick por mês,
	# fora do laço de países militares, para evitar duplicação de baixas, eventos
	# humanitários, sanções, histórico e efeitos macroeconômicos.
	Conflict.monthly(state, countries)
	E2GeopoliticsContract.monthly(state)
	E2ForcedFlowsContract.monthly(state)
	GlobalShock.monthly(state)
	state.debt = clampf(float(state.debt), 5.0, 180.0)
	state.approval += (state.economy - 2.5) * 0.15 - (state.inflation - 4.0) * 0.12 - (state.unemployment - 8.0) * 0.04 + (48.0 - state.approval) * 0.015
	# Popularidade do partido: no governo acompanha a aprovação; na oposição, o desgaste do governo ajuda.
	var drive: float = (state.approval - 45.0) * 0.025 if gov else (45.0 - state.approval) * 0.02
	state.popularity += drive + (state.credibility - 30.0) * 0.01 - maxf(0.0, state.popularity - 25.0) * 0.01
	state.recognition += 0.15
	state.funds += _monthly_income()
	state.members = maxi(0, int(state.members) + _member_drift())
	if gov:
		_apply_program_monthly()
	for i in state.region_support.size(): state.region_support[i] += (state.popularity - state.region_support[i]) * 0.012
	# B3: primeiro o conflito distributivo. Uma greve ativa altera economia,
	# inflação, contas e aprovação; os grupos sociais reagem a esse novo estado
	# no mesmo mês, em vez de receber um choque solto.
	var interest_news: Array = InterestGroups.monthly(state)
	for item in interest_news:
		_push_news(str(item.get("text", "")))
	# B2: grupos sociais reagem à conjuntura, ao conflito e ao alinhamento.
	var social_summary: Dictionary = SocialGroups.monthly(state)
	state.approval += (float(state.get("social_support", 50.0)) - 45.0) * 0.02
	# B4: relações partidárias e facções evoluem com o mês e os compromissos.
	var positions := Ideology.positions(state, _country_by_id(str(state.country_id)))
	PoliticalRelations.tick(state, positions)
	var faction_news: Array = PoliticalRelations.faction_tick(state, Ideology.player_position(state), not (state.get("coalition_partners", []) as Array).is_empty())
	for item in faction_news:
		_push_news(str(item.get("text", "")))
	# B5: casos avançam um estágio; novos casos dependem do risco real.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.date_year) * 1200 + int(state.date_month) * 31 + int(state.chamber_seats)
	state["in_campaign"] = int(state.months_to_election) <= 4
	var spawned: Dictionary = Scandals.maybe_spawn(state, rng)
	if not spawned.is_empty():
		_push_news("Nova alegação em apuração: %s" % str(spawned.get("title", "")))
	for note in Scandals.advance(state, rng):
		_push_news("Crise: " + str(note))
	state["scandal_penalty"] = Scandals.penalty(state)
	state["campaign_penalty"] = maxf(0.0, float(state.get("scandal_penalty", 0.0)) * 0.8 - 0.5)
	CampaignSystem.monthly(state)
	state.campaign = maxf(0.0, float(state.campaign) - 0.35)
	_coalition_tick()
	_event_due = int(state.date_month) % 3 == 0
	_international_due = false
	state.economy_history.append(_economy_point())
	if state.economy_history.size() > 60:
		state.economy_history = state.economy_history.slice(state.economy_history.size() - 60, state.economy_history.size())
	if state.date_month == 6: state.news.push_front("Pesquisas apontam disputa aberta: regiões metropolitanas e rurais podem decidir a próxima eleição.")
	if state.date_month == 12: state.news.push_front("Ano eleitoral: urnas abertas em 8 regiões. Campanhas entram na reta final.")
	_resolve_month(_month_stamp())

## Filiação cresce com a popularidade e encolhe quando o partido racha.
func _member_drift() -> int:
	return int(maxf(0.0, float(state.popularity) - 3.0) * 0.6) - (30 if float(state.cohesion) < 50.0 else 0)

## A coalizão desgasta todo mês. Abaixo de 30 de coesão o último parceiro sai;
## no parlamentarismo, sem maioria o governo cai e a eleição é antecipada.
func _coalition_tick() -> void:
	var partners: Array = state.coalition_partners if state.get("coalition_partners") is Array else []
	if not bool(state.government) or partners.is_empty():
		return
	state.coalition_cohesion = float(state.get("coalition_cohesion", 60.0)) - 0.6
	for pressure in PoliticalRelations.ministry_pressure(state, str(state.abbr)):
		_push_news(str(pressure))
	state["coalition_stability"] = PoliticalRelations.stability(state)
	if float(state.coalition_cohesion) >= 30.0:
		return
	var left := str(partners.pop_back())
	PoliticalRelations.remove_partner(state, left, str(state.abbr), "coesão abaixo de 30")
	state["coalition_stability"] = PoliticalRelations.stability(state)
	_push_news("%s rompe com o governo e deixa a coalizão." % left)
	if int(state.coalition_seats) >= int(state.majority) or not Election.is_parliamentary(_country_by_id(str(state.country_id))):
		return
	state.government = false
	state.months_to_election = 0
	state.coalition_seats = 0
	state.coalition_partners = []
	_push_news("O governo perdeu a maioria e caiu: eleição antecipada.")

## Reforça a base: custa caixa e devolve coesão à coalizão.
func _renew_coalition() -> void:
	var cost := 600.0
	if float(state.funds) < cost:
		_show_toast("Caixa insuficiente para renovar a coalizão", "error")
		return
	state.funds -= cost
	state.coalition_cohesion = minf(95.0, float(state.get("coalition_cohesion", 60.0)) + 15.0)
	for party in state.get("coalition_partners", []):
		PoliticalRelations.shift(state, str(state.abbr), str(party), 3.0, "reforço da base")
	_push_news("A base aliada foi reforçada com cargos e emendas.")
	_clamp_state(); _save_game(); _show_game()

## Primeiro-ministro popular pode antecipar a eleição para capitalizar.
func _call_early_election() -> void:
	if not _can_call_early_election():
		_show_toast("Condições para antecipar a eleição não atendidas", "warning")
		return
	state.funds -= 1500.0
	state.months_to_election = 0
	_push_news("Eleição antecipada convocada: o governo aposta na própria popularidade.")
	_clamp_state(); _save_game(); _show_game()

func _can_call_early_election() -> bool:
	return bool(state.government) and Election.is_parliamentary(_country_by_id(str(state.country_id))) and float(state.approval) >= 55.0 and int(state.months_to_election) > 3 and float(state.funds) >= 1500.0

func _early_election_panel() -> PanelContainer:
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("ELEIÇÃO ANTECIPADA", 12, SUBTLE))
	var note := _label("No parlamentarismo, um governo com aprovação ≥ 55% pode antecipar o pleito (custo M$ 1.500, mais de 3 meses para a eleição).", 13, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var b := _button("CONVOCAR ELEIÇÕES", AMBER, false)
	b.disabled = not _can_call_early_election()
	b.pressed.connect(_call_early_election)
	col.add_child(b)
	panel.add_child(col)
	return panel

func _month_stamp() -> String:
	return "%d-%02d" % [int(state.date_year), int(state.date_month)]

## Fotografia dos indicadores usada para medir a variação do mês.
func _metric_snapshot() -> Dictionary:
	return {
		"popularity": float(state.popularity), "approval": float(state.approval),
		"recognition": float(state.recognition), "credibility": float(state.credibility),
		"economy": float(state.economy), "inflation": float(state.inflation),
		"unemployment": float(state.unemployment), "debt": float(state.debt),
		"funds": float(state.funds), "treasury": float(state.get("treasury", 0.0)),
		"service_index": float(state.get("service_index", 50.0)),
	}

## Relatório do mês: até quatro indicadores que mais se moveram, com o sinal
## já traduzido para "melhorou/piorou" conforme a direção desejável de cada um.
## Fatores contribuintes do mês: só o que a mecânica realmente aplicou.
## O texto fala em correlação, nunca em causalidade exata.
func _contributing_factors() -> Array:
	var factors: Array = []
	factors.append("Convergência do crescimento ao potencial, ajustado por dívida e inflação.")
	for factor in Government.factors(state).slice(0, 4):
		factors.append(str(factor))
	if bool(state.government):
		factors.append("Receita do mês M$ %s; manutenção de programas M$ %s." % [_fmt_int(_monthly_income()), _fmt_int(_program_upkeep())])
	if not (state.policies as Array).is_empty():
		var labels: Array = []
		for id in state.policies:
			if PROGRAMS.has(id):
				labels.append(str(PROGRAMS[id].label))
		if not labels.is_empty():
			factors.append("Programas ativos: %s." % ", ".join(PackedStringArray(labels)))
	if float(state.debt) > 60.0:
		factors.append("Dívida acima de 60%% do PIB reduz o potencial de crescimento e pressiona a inflação.")
	if float(state.inflation) > 4.5:
		factors.append("Inflação acima da âncora de 4,5%% pressiona aprovação e salários.")
	if str(state.get("event", "")) != "":
		factors.append("Evento em aberto: %s." % str(state.event))
	for strike in InterestGroups.active_strikes(state):
		factors.append("Greve de %s há %d mês(es) por %s: produção e inflação sentem o conflito." % [str(strike.get("name", "")), int(strike.get("months", 0)), str(strike.get("demand", ""))])
	if bool(state.get("government", false)) and not (state.get("coalition_partners", []) as Array).is_empty() and float(state.get("coalition_stability", 60.0)) < 45.0:
		factors.append("Estabilidade da coalizão em %.0f/100: pastas e pauta pesam na disciplina dos aliados." % float(state.get("coalition_stability", 60.0)))
	for case in Scandals.active(state):
		factors.append("Caso \"%s\": cobertura %.0f, procedimento %s, status %s." % [str(case.get("title", "")), float(case.get("media", 20.0)), Scandals.procedure_label(str(case.get("procedure", "alegacao"))), Scandals.legal_label(str(case.get("legal", "unproven")))])
	factors.append("Relação de correlação: estes são os fatores mecânicos ativos, não uma atribuição causal exata.")
	return factors

func _build_month_report() -> Array:
	if _month_snapshot.is_empty():
		return []
	var current := _metric_snapshot()
	var definitions := [
		{"key": "approval", "label": "Aprovação", "up_good": true},
		{"key": "popularity", "label": "Popularidade", "up_good": true},
		{"key": "economy", "label": "Crescimento", "up_good": true},
		{"key": "inflation", "label": "Inflação", "up_good": false},
		{"key": "unemployment", "label": "Desemprego", "up_good": false},
		{"key": "debt", "label": "Dívida/PIB", "up_good": false},
		{"key": "service_index", "label": "Serviços públicos", "up_good": true},
		{"key": "treasury", "label": "Tesouro", "up_good": true},
		{"key": "recognition", "label": "Reconhecimento", "up_good": true},
		{"key": "credibility", "label": "Credibilidade", "up_good": true},
	]
	var entries: Array = []
	for definition in definitions:
		var key := str(definition.get("key", ""))
		var delta := float(current.get(key, 0.0)) - float(_month_snapshot.get(key, 0.0))
		if absf(delta) < 0.05:
			continue
		entries.append({
			"label": str(definition.get("label", key)),
			"delta": delta,
			"good": (delta > 0.0) == bool(definition.get("up_good", true)),
		})
	entries.sort_custom(func(a, b): return absf(float(a.delta)) > absf(float(b.delta)))
	return entries.slice(0, 4)

## O mês só é concluído uma vez: evento e cena internacional passam pela IA,
## com fallback determinístico, e o fechamento é idempotente pelo carimbo.
## Quando ambos são devidos, o evento vai primeiro e o cenário internacional
## começa quando ele termina: o Ollama atende uma requisição por vez e dois
## pedidos simultâneos estouravam o prazo de 20 s e caíam no fallback.
func _resolve_month(stamp: String) -> void:
	if str(state.get("month_completed", "")) == stamp:
		_month_in_progress = false
		return
	_month_stamp_pending = stamp
	_month_event_needed = bool(_event_due)
	_month_event_done = not _month_event_needed
	_month_intl_needed = false
	_month_intl_done = true
	_month_event_op = ""
	_month_intl_op = ""
	_event_due = false

	if _international_due:
		_international_due = false
		var party_ids: Array = _active_parties_for_international()
		_month_intl_needed = not party_ids.is_empty()
		_month_intl_done = not _month_intl_needed

	if not _month_event_needed and not _month_intl_needed:
		_complete_month(stamp)
		return

	var ops: Array = []
	var messages: Array = []

	var event_needed := _month_event_needed
	if _month_event_needed:
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
		_month_event_op = ai.request(Contracts.EVENTS, prompt_ctx, data, meta, _on_month_event.bind(stamp))
		if ai.is_pending(_month_event_op):
			ops.append(_month_event_op)
			messages.append("conjuntura")

	# Sem evento devido, o cenário internacional já sai agora; com evento, ele
	# espera a vez (ver _on_month_event) para não disputar o modelo.
	if _month_intl_needed and not event_needed:
		_start_month_international(stamp)
		if ai.is_pending(_month_intl_op):
			ops.append(_month_intl_op)
			messages.append("cenário internacional")

	# Em fallback síncrono os callbacks podem ter concluído o mês.
	if str(state.get("month_completed", "")) == stamp:
		return
	if not ops.is_empty():
		var msg := "Resolvendo a conjuntura do mês..." if messages.size() == 1 and messages[0] == "conjuntura" else "Lendo o cenário internacional..." if messages.size() == 1 else "Resolvendo conjuntura e cenário internacional..."
		_show_ai_wait(msg, ops)

func _start_month_international(stamp: String) -> void:
	if not _month_intl_needed or _month_intl_done:
		return
	var party_ids: Array = _active_parties_for_international()
	if party_ids.is_empty():
		_month_intl_done = true
		return
	var prompt_ctx_i := {
		"pais": str(state.country_name),
		"governo": "governo" if bool(state.government) else "oposição",
		"bancadas": party_ids,
		"ids_permitidos": party_ids,
		"mes": int(state.date_month),
		"ano": int(state.date_year),
	}
	var meta_i := {"month": int(state.date_month), "year": int(state.date_year), "country": str(state.country_id)}
	var data_i := {"party_ids": party_ids, "entities": party_ids}
	_month_intl_op = ai.request(Contracts.INTERNATIONAL, prompt_ctx_i, data_i, meta_i, _on_month_international.bind(stamp))

## O contrato internacional pede uma reação por bancada e o modelo de 3B não
## fecha uma câmara de 21 partidos dentro dos 20 s: o cenário é pedido para as
## bancadas que pesam (governo, coalizão e as maiores) e as demais ficam neutras.
const INTERNATIONAL_MAX_BANKS := 5

func _active_parties_for_international() -> Array:
	var seat_map: Dictionary = state.get("seat_map", {}) if state.get("seat_map") is Dictionary else {}
	var ranked: Array = []
	for key in seat_map.keys():
		if int(seat_map[key]) > 0:
			ranked.append([str(key), int(seat_map[key])])
	if ranked.is_empty():
		return []
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var picked: Array = []
	var priority: Array = [str(state.get("abbr", ""))]
	if state.get("coalition_partners") is Array:
		priority.append_array(state.coalition_partners)
	for key in priority:
		var party := str(key)
		if party != "" and picked.size() < INTERNATIONAL_MAX_BANKS and not picked.has(party) and int(seat_map.get(party, 0)) > 0:
			picked.append(party)
	for item in ranked:
		if picked.size() >= INTERNATIONAL_MAX_BANKS:
			break
		if not picked.has(str(item[0])):
			picked.append(str(item[0]))
	return picked

func _on_month_event(result: Dictionary, stamp: String) -> void:
	if stamp != _month_stamp_pending or str(state.get("month_completed", "")) == stamp:
		return
	if _month_event_done:
		return
	_month_event_done = true
	_month_event_op = ""
	var value: Dictionary = result.get("value", {})
	_apply_month_event(value)
	# Evento encerrado: agora o cenário internacional entra na vez do modelo.
	if _month_intl_needed and not _month_intl_done:
		_start_month_international(stamp)
		if ai.is_pending(_month_intl_op):
			_show_ai_wait("Lendo o cenário internacional...", [_month_intl_op])
			return
	_maybe_finish_month(stamp)

func _apply_month_event(value: Dictionary) -> void:
	var headline := str(value.get("headline", "")).strip_edges()
	var effects: Variant = value.get("effects", {})
	state.event_id = ""
	state.event_options = []
	if headline == "":
		# Sem IA (ou resposta vazia): o motor determinístico escolhe um evento
		# coerente com a conjuntura, com três respostas de efeito real.
		var picked := Events.pick(state, randf())
		headline = str(picked.headline)
		state.event_id = str(picked.id)
		state.event_options = picked.options
		Events.remember(state, state.event_id)
	state.event = headline
	_push_news(headline)
	if effects is Dictionary and not (effects as Dictionary).is_empty():
		_apply_ai_effects(effects, "evento")
		state["event_effects_applied"] = true

func _apply_ai_effects(effects: Dictionary, source: String) -> void:
	var approval := float(effects.get("approval", 0.0))
	var popularity := float(effects.get("popularity", 0.0))
	var funds := float(effects.get("funds", 0.0))
	var debt := float(effects.get("debt", 0.0))
	state.approval += approval
	state.popularity += popularity
	state.funds += funds
	state.debt += debt
	# Fallback do evento pode vir sem efeitos: uma linha "tudo zero" só polui o radar.
	if is_zero_approx(approval) and is_zero_approx(popularity) and is_zero_approx(funds) and is_zero_approx(debt):
		return
	state.news.push_front("Efeitos do %s aplicados uma única vez: aprovação %+.1f, popularidade %+.1f, caixa %+.0f, dívida %+.2f p.p." % [
		source, approval, popularity, funds, debt,
	])

## A cena internacional é gerada na simulação e apenas exibida na tela.
func _on_month_international(result: Dictionary, stamp: String) -> void:
	if stamp != _month_stamp_pending or str(state.get("month_completed", "")) == stamp:
		return
	if _month_intl_done:
		return
	_month_intl_done = true
	_month_intl_op = ""
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
	_maybe_finish_month(stamp)

func _maybe_finish_month(stamp: String) -> void:
	if str(state.get("month_completed", "")) == stamp:
		return
	if _month_event_done and _month_intl_done:
		_hide_ai_wait()
		_complete_month(stamp)
	else:
		_update_ai_wait_message()

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
		_month_stamp_pending = ""
		return
	var previous_completed := str(state.get("month_completed", ""))
	# Fase G1: população agregada, coortes e fluxos graduais. A Fase F apenas
	# noticia o resultado já produzido pelos sistemas de simulação.
	var demography_result := Demography.monthly(state, economy_catalog)
	# Fundação G: registra a referência única da população e a proveniência,
	# sem criar resultados sociais paralelos nem regiões ainda.
	var phase_g_result := PhaseGContract.monthly(state)
	# Fase F é uma camada derivada: indexa fatos que já foram resolvidos neste
	# mês, sem alterar aprovação, economia, eleições ou qualquer regra da simulação.
	PhaseFInformation.monthly(state)
	# FUND-03: observa unidades e reconciliações depois dos produtores, sem
	# substituir população, macroeconomia ou fiscal já calculados.
	var macro_ledger_result := MacroLedgerContract.monthly(state)
	# O relatório é construído somente depois das etapas que podem alterar seus
	# indicadores. Os resultados são mantidos para diagnóstico sem transformar
	# módulos pendentes em sucesso artificial.
	state["month_report"] = _build_month_report()
	state["month_factors"] = _contributing_factors()
	_clamp_state()
	# month_completed é o último marcador lógico antes do commit; uma falha de
	# save restaura o marcador anterior e não anuncia o mês como persistido.
	state["month_completed"] = stamp
	var committed := _save_game()
	if not committed:
		state["month_completed"] = previous_completed
		_month_in_progress = false
		_month_stamp_pending = ""
		_show_game()
		_show_toast("Falha ao salvar o fechamento do mês; o marcador não foi publicado.", "error")
		return
	_month_in_progress = false
	_month_stamp_pending = ""
	_month_event_needed = false
	_month_event_done = true
	_month_intl_needed = false
	_month_intl_done = true
	_month_event_op = ""
	_month_intl_op = ""
	_hide_ai_wait()
	_show_game()
	_show_month_report()

func _show_ai_wait(message: String, op_ids: Variant) -> void:
	_hide_ai_wait()
	if not is_instance_valid(root_stack):
		return
	var ids: Array = []
	if op_ids is Array:
		ids = op_ids
	elif op_ids is String and str(op_ids) != "":
		ids = [str(op_ids)]
	ai_wait_ops = ids
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL_2, AMBER, 8, 2))
	# Ao lado da barra lateral, para o painel não cobrir a navegação enquanto espera.
	var left := 22.0
	if is_instance_valid(sidebar):
		left += float(sidebar.custom_minimum_size.x)
	panel.position = Vector2(left, 84)
	panel.custom_minimum_size.x = 460
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 6)
	col.add_child(_label("IA LOCAL  ·  mandatia-qwen35-local:latest", 11, AMBER))
	var msg := _label(message, 15, TEXT)
	msg.name = "Msg"
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(msg)
	var row := HBoxContainer.new()
	var note := _label("2 tentativas · 20 s cada · fallback pronto", 11, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	var skip := _button("RESOLVER SEM IA", MUTED, false)
	skip.pressed.connect(func() -> void:
		if ai != null:
			for op_id in ai_wait_ops:
				ai.cancel(str(op_id))
		_hide_ai_wait())
	row.add_child(skip)
	col.add_child(row)
	panel.add_child(col)
	root_stack.add_child(panel)
	ai_wait_panel = panel

func _update_ai_wait_message() -> void:
	if not is_instance_valid(ai_wait_panel):
		return
	var parts: Array = []
	if _month_event_needed and not _month_event_done:
		parts.append("conjuntura")
	if _month_intl_needed and not _month_intl_done:
		parts.append("cenário internacional")
	if parts.is_empty():
		return
	var msg_node := ai_wait_panel.get_node_or_null("Col/Msg")
	if msg_node is Label:
		msg_node.text = "Aguardando IA: " + " e ".join(PackedStringArray(parts)) + "..."

func _hide_ai_wait() -> void:
	if is_instance_valid(ai_wait_panel):
		ai_wait_panel.queue_free()
	ai_wait_panel = null
	ai_wait_ops = []

func _update_header() -> void:
	if not is_instance_valid(header_date): return
	header_date.text = "%s · %02d/%d" % ["GOVERNO" if state.government else "OPOSIÇÃO", state.date_month, state.date_year]
	if is_instance_valid(month_button):
		var pending := int(state.months_to_election) <= 0
		month_button.disabled = pending
		month_button.text = "ELEIÇÃO" if pending else "AVANÇAR ›"
		month_button.tooltip_text = "Eleição obrigatória: abra Eleições para disputar o pleito" if pending else "Avançar um mês"

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
	col.add_child(_label("AÇÃO DO MÊS", 12, SUBTLE))
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
	# Foco na primeira opção: teclado/gamepad selecionam sem depender do mouse.
	if not promise_checks.is_empty():
		promise_checks[0].grab_focus()

func _on_promise_toggled(check: BaseButton, pressed: bool, counter: Label) -> void:
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
	metrics.add_child(_metric_card("LEIS APROVADAS", str(int(result.get("laws", 0))), SUBTLE))
	metrics.add_child(_metric_card("PROMESSAS", "%d de %d" % [int(result.get("fulfilled", 0)), int(result.get("promise_total", 0))], GREEN if int(result.get("fulfilled", 0)) > 0 else RED))
	box.add_child(metrics)
	box.add_child(_rule())
	box.add_child(_label("PROGRAMA DE GOVERNO", 12, SUBTLE))
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
	next.grab_focus()

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
	var government_party := Election.largest_party(seat_map)
	var government_seats := int(seat_map.get(government_party, 0))
	var coalition_partners: Array = state.get("coalition_partners", []) if state.get("coalition_partners") is Array else []
	for partner in coalition_partners:
		var partner_key := str(partner)
		if partner_key != government_party:
			government_seats += int(seat_map.get(partner_key, 0))
	var total_seats := 0
	for key in seat_map.keys():
		total_seats += int(seat_map[key])
	var outside := total_seats - government_seats
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

## Relatório do mês: tela própria, aberta ao fechar o mês, com foco no CONTINUAR.
## Só aparece quando há variação relevante — mês estável não interrompe o jogo.
func _show_month_report() -> void:
	_hide_tutorial_callout()
	var report: Array = state.get("month_report", []) if state.get("month_report") is Array else []
	if report.is_empty() or not is_instance_valid(root_stack):
		return
	var overlay := Control.new()
	overlay.name = "MonthReport"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_stack.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := _panel_box()
	card.custom_minimum_size.x = 520
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", 10)
	col.add_child(_label("RELATÓRIO DO MÊS  ·  %02d/%d" % [int(state.date_month), int(state.date_year)], 12, AMBER))
	col.add_child(_label("O que mudou desde o mês anterior", 24, TEXT))
	for entry in report:
		var delta := float(entry.get("delta", 0.0))
		var row := HBoxContainer.new()
		var name_label := _label(str(entry.get("label", "Indicador")), 15, TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label("%s%.2f" % ["+" if delta >= 0.0 else "", delta], 15, GREEN if bool(entry.get("good", true)) else RED))
		col.add_child(row)
	var factors: Array = state.get("month_factors", []) if state.get("month_factors") is Array else []
	if not factors.is_empty():
		col.add_child(_rule())
		col.add_child(_label("FATORES CONTRIBUINTES", 11, AMBER))
		for factor in factors.slice(0, 5):
			var factor_label := _label("• " + str(factor), 12, MUTED)
			factor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(factor_label)
	col.add_child(_rule())
	col.add_child(_label("ENTER, ESPAÇO ou ESC continuam o jogo.", 12, MUTED))
	month_report_continue = _button("CONTINUAR", AMBER)
	month_report_continue.pressed.connect(_dismiss_month_report)
	col.add_child(month_report_continue)
	card.add_child(col)
	center.add_child(card)
	month_report_panel = overlay
	_trap_focus(overlay)
	month_report_continue.grab_focus()

## Modal de verdade: enquanto o relatório está aberto, só ele recebe foco.
## Sem isso, setas/D-pad escapavam para botões atrás da cortina.
func _trap_focus(keep: Control) -> void:
	report_blocked.clear()
	for node in root_stack.find_children("*", "Control", true, false):
		var control := node as Control
		if control == keep or keep.is_ancestor_of(control):
			continue
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		report_blocked.append([control, control.focus_mode])
		control.focus_mode = Control.FOCUS_NONE

func _release_focus_trap() -> void:
	for entry in report_blocked:
		var control = entry[0]
		if is_instance_valid(control):
			control.focus_mode = entry[1]
	report_blocked.clear()

func _dismiss_month_report() -> void:
	if is_instance_valid(month_report_panel):
		month_report_panel.queue_free()
	month_report_panel = null
	month_report_continue = null
	_release_focus_trap()
	if is_instance_valid(month_button) and not month_button.disabled:
		month_button.grab_focus()
	elif is_instance_valid(sidebar):
		var fallback := _first_focusable(sidebar)
		if fallback != null:
			fallback.grab_focus()

## Escape / botão B: fecha o relatório ou sai de qualquer tela para o menu,
## sem prender o jogador. O salvamento é automático a cada decisão.
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(month_report_panel):
		var closes := event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			closes = true
		if closes:
			_dismiss_month_report()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if screen != "menu":
			_show_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if screen != "menu":
			_show_menu()
			get_viewport().set_input_as_handled()

func _show_toast(message: String, kind := "info") -> void:
	if is_instance_valid(toast): toast.queue_free()
	var color := SUBTLE
	if kind == "success":
		color = GREEN
	elif kind == "error":
		color = RED
	elif kind == "warning":
		color = AMBER
	toast = _label(message, 15, TEXT)
	toast.custom_minimum_size.x = 240
	toast.position = Vector2(28, size.y - 96)
	toast.add_theme_stylebox_override("normal", _style(PANEL_2, color, 6, 2))
	root_stack.add_child(toast)
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(toast): toast.queue_free())

func _apply_responsive() -> void:
	var width := size.x
	if is_instance_valid(right_column):
		right_column.visible = _rail_enabled() and width >= UI.RAIL_BREAKPOINT
	if is_instance_valid(sidebar):
		sidebar.custom_minimum_size.x = UI.NAV_MAIN_HEIGHT + UI.NAV_CONTEXT_WIDTH
	if is_instance_valid(sidebar_plate):
		sidebar_plate.custom_minimum_size.x = UI.NAV_MAIN_HEIGHT
	if is_instance_valid(sidebar_context):
		# Em janelas estreitas a faixa contextual recolhe e só o rail principal fica.
		sidebar_context.visible = width >= 1000
	if is_instance_valid(header_leader):
		header_leader.visible = width >= 1180
	if is_instance_valid(header_pills):
		header_pills.visible = width >= 1000
	for capsule in header_capsules:
		if not is_instance_valid(capsule):
			continue
		(capsule as Control).visible = width >= 1000 or int(capsule.get_meta("priority", 1)) == 1
	if is_instance_valid(month_button):
		if int(state.months_to_election) <= 0:
			month_button.text = "ELEIÇÃO"
			month_button.disabled = true
		else:
			month_button.text = "AVANÇAR ›" if width >= 900 else "›"
			month_button.disabled = false
	if is_instance_valid(main_margin):
		var pad := UI.MARGIN_SIDE if width >= UI.PAD_BREAKPOINT else 12
		var pad_y := UI.MARGIN_TOP if width >= UI.PAD_BREAKPOINT else 10
		main_margin.add_theme_constant_override("margin_left", pad)
		main_margin.add_theme_constant_override("margin_right", pad)
		main_margin.add_theme_constant_override("margin_top", pad_y)
		main_margin.add_theme_constant_override("margin_bottom", pad_y)

func _manual_save() -> void:
	if _save_game():
		_show_toast("Campanha salva em user://mandatia_save.json", "success")
	else:
		_show_toast("Falha ao salvar a campanha; o backup anterior foi preservado.", "error")

func _has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP) or FileAccess.file_exists(LEGACY_SAVE_PATH) or FileAccess.file_exists(_legacy_save_absolute_path())

func _legacy_save_absolute_path() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join("Mandato — Poder e Política").path_join("mandato_save.json")

func _save_game() -> bool:
	var user_dir := ProjectSettings.globalize_path("user://")
	if not DirAccess.dir_exists_absolute(user_dir):
		if DirAccess.make_dir_recursive_absolute(user_dir) != OK:
			return false
	var payload := {"save_version": SAVE_VERSION, "state": state}
	var file := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if file == null:
		return false
	var encoded := JSON.stringify(payload)
	file.store_string(encoded)
	if file.get_error() != OK:
		file.close()
		return false
	file.close()
	var verify_tmp := _read_save_file(SAVE_TMP)
	if verify_tmp.is_empty():
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	# Rotação: o save atual vira backup antes de ser substituído, para que um
	# arquivo corrompido possa ser recuperado no próximo carregamento.
	# Cópia via FileAccess: DirAccess.copy com caminho relativo ao root não abre
	# o arquivo no Windows.
	if dir.file_exists("mandatia_save.json"):
		var current := FileAccess.get_file_as_string(SAVE_PATH)
		if current != "":
			var bak := FileAccess.open(SAVE_BACKUP, FileAccess.WRITE)
			if bak == null:
				return false
			bak.store_string(current)
			if bak.get_error() != OK:
				bak.close()
				return false
			bak.close()
		dir.remove("mandatia_save.json")
	if dir.rename("mandatia_save.tmp", "mandatia_save.json") == OK:
		return not _read_save_file(SAVE_PATH).is_empty()
	var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if direct == null:
		return false
	direct.store_string(encoded)
	if direct.get_error() != OK:
		direct.close()
		return false
	direct.close()
	return not _read_save_file(SAVE_PATH).is_empty()

## Lê um arquivo de save e devolve o estado migrado, ou {} se estiver ilegível.
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	# JSON.new() em vez de JSON.parse_string(): um save corrompido é tratado
	# como ilegível (cai no backup) sem despejar erro do parser no console.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	if data.get("state") is Dictionary:
		data = data.get("state")
	return _migrate_state(data)

func _save_candidates() -> Array:
	var paths: Array = [SAVE_PATH]
	if FileAccess.file_exists(SAVE_BACKUP):
		paths.append(SAVE_BACKUP)
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		paths.append(LEGACY_SAVE_PATH)
	if FileAccess.file_exists(_legacy_save_absolute_path()):
		paths.append(_legacy_save_absolute_path())
	return paths

func _load_game() -> void:
	for path in _save_candidates():
		var migrated := _read_save_file(str(path))
		if migrated.is_empty():
			continue
		state = migrated
		if str(path) == SAVE_BACKUP:
			state.news.push_front("O arquivo de save principal estava corrompido: a campanha foi recuperada do backup.")
		_ensure_chamber_state()
		return

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
	# Saves v5 anteriores ao perfil econômico recebem o perfil apenas para
	# exibição/fonte: os indicadores salvos do jogador não são sobrescritos.
	if not (result.get("economic_profile") is Dictionary) or (result.economic_profile as Dictionary).is_empty():
		result["economic_profile"] = _economy_profile(str(result.get("country_id", "BR")))
	if not (result.get("month_factors") is Array):
		result["month_factors"] = []
	if not (result.get("tutorial_seen") is Array):
		result["tutorial_seen"] = []
	if not raw.has("months_to_election"):
		result["months_to_election"] = FIRST_CAMPAIGN_MONTHS
	# B1-B6: relações, grupos, interesses, facções e campanha são idempotentes.
	var country := _country_by_id(str(result.get("country_id", "BR")))
	Ideology.player_position(result)
	var positions := Ideology.positions(result, country)
	SocialGroups.ensure(result)
	InterestGroups.ensure(result)
	PoliticalRelations.ensure(result, positions)
	CampaignSystem.ensure(result)
	Scandals.ensure(result)
	CausalLog.ensure(result)
	Government.ensure(result)
	International.ensure(result, countries, economy_catalog)
	WorldSim.ensure(result, countries, economy_catalog)
	Military.ensure(result, countries, economy_catalog)
	Resources.ensure(result, str(result.get("country_id", "BR")))
	Conflict.ensure(result, countries)
	GlobalShock.ensure(result)
	E2GeopoliticsContract.ensure(result)
	E2ForcedFlowsContract.ensure(result)
	Demography.ensure(result, economy_catalog)
	PhaseGContract.ensure(result)
	PhaseFInformation.ensure(result)
	MacroLedgerContract.ensure(result)
	result["save_version"] = SAVE_VERSION
	return result

## Cenário Incumbente: a bancada do jogador já existe e precisa caber na câmara.
## Sem normalizar, as cadeiras do jogador eram somadas ao snapshot e o plenário
## passava a votar com mais cadeiras do que o país tem.
func _install_incumbent_chamber(country: Dictionary) -> void:
	var total := maxi(0, Election.chamber_seats(country))
	if total <= 0:
		state.seat_map[str(state.abbr)] = int(state.lower_house_seats)
		return
	var own := clampi(int(state.lower_house_seats), 0, total)
	var others := {}
	var other_total := 0
	for party in country.get("official_parties", []):
		var key := str(party.get("abbr", "")).strip_edges()
		if key == "" or key == str(state.abbr):
			continue
		var raw: Variant = party.get("lower_house_seats", null)
		var count := int(raw) if raw != null else 0
		if count <= 0:
			continue
		others[key] = int(others.get(key, 0)) + count
		other_total += count
	var map := {str(state.abbr): own}
	var remaining := total - own
	if remaining > 0 and other_total > 0:
		var assigned := 0
		var remainders: Array = []
		for key in others.keys():
			var exact := float(others[key]) * float(remaining) / float(other_total)
			var seats := int(floor(exact))
			map[key] = seats
			assigned += seats
			remainders.append([key, exact - float(seats)])
		remainders.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
		var leftover := remaining - assigned
		for i in leftover:
			if remainders.is_empty():
				break
			var key := str(remainders[i % remainders.size()][0])
			map[key] = int(map.get(key, 0)) + 1
	elif remaining > 0:
		map["Não atribuídas"] = remaining
	state.seat_map = map
	state.lower_house_seats = own
	state.coalition_seats = own
	state.coalition_cohesion = maxf(float(state.get("coalition_cohesion", 60.0)), float(state.get("cohesion", 60.0)))
	state["coalition_stability"] = PoliticalRelations.stability(state)
	state["coalition_started"] = int(state.get("date_year", 0)) * 12 + int(state.get("date_month", 1))

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
	if file == null:
		_show_toast("Não foi possível gravar o export", "error")
		return
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

## Cápsula do topo: rótulo 8 px sobre valor 13 px, sem caixa — o agrupamento
## vem do espaço e do filete entre economia e política. `priority` 1 nunca sai;
## 2 é dispensada abaixo de 1000 px.
func _header_capsule(caption: String, value: String, color: Color, priority := 1) -> PanelContainer:
	var box := PanelContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(_label(caption, 8, SUBTLE))
	var value_label := _label(value, 13, color)
	value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	col.add_child(value_label)
	box.add_child(col)
	box.set_meta("priority", priority)
	header_capsules.append(box)
	return box

## Barra horizontal do tema: trilha SURFACE_HOVER + preenchimento colorido.
func _bar(value: float, max_value: float, color: Color, height: float = 12.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = clampf(value, 0.0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := _style(SURFACE_HOVER, LINE, 3, 1)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	var fill := _style(color, Color.TRANSPARENT, 3, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## Cartão de KPI: legenda 9 px + valor 22 px + variação opcional em 10 px.
func _kpi_card(caption: String, value: String, color: Color, delta: String = "") -> PanelContainer:
	var box := _panel_box()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(_label(caption, 9, SUBTLE))
	var value_label := _label(value, 22, color)
	_tabular(value_label)
	col.add_child(value_label)
	if delta != "":
		col.add_child(_label(delta, 10, SUBTLE))
	box.add_child(col)
	return box

## Números tabulares (largura fixa por dígito) para KPIs e tabelas econômicas.
func _tabular(label: Label) -> void:
	var base := load(TABULAR_FONT) as Font
	if base == null:
		return
	var variation := FontVariation.new()
	variation.base_font = base
	variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	label.add_theme_font_override("font", variation)

## Variação do último mês registrado para um indicador econômico.
func _econ_delta(key: String) -> String:
	var history: Array = state.get("economy_history", [])
	if history.size() < 2:
		return ""
	var last_point: Dictionary = history[history.size() - 1]
	var prev_point: Dictionary = history[history.size() - 2]
	if not last_point.has(key) or not prev_point.has(key):
		return ""
	var last := float(last_point.get(key, 0.0))
	var prev := float(prev_point.get(key, 0.0))
	var delta := last - prev
	if absf(delta) < 0.05:
		return "estável no mês"
	return "%+.1f p.p. no mês" % delta

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
	panel.custom_minimum_size.y = UI.FOOTER_HEIGHT
	var footer_style := _style(SURFACE, LINE, 0, 1)
	footer_style.content_margin_top = 2
	footer_style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", footer_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	for cell_data in [
		["DESEMPREGO", "%.1f%%" % state.unemployment, RED if float(state.unemployment) >= 10.0 else AMBER],
		["ESTABILIDADE", "%d/100" % int(_stability()), AMBER],
		["TENSÃO CONSTITUCIONAL", "%d/100" % int(_constitutional_tension()), AMBER],
	]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(_label(str(cell_data[0]), 9, SUBTLE))
		cell.add_child(_label(str(cell_data[1]), 12, cell_data[2]))
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

## ============================================================================
## FASE C — ADMINISTRAÇÃO PÚBLICA
## ============================================================================

var ministry_focus := ""
var project_region_select: OptionButton

func _type_label(kind: String) -> String:
	match kind:
		"mandatory": return "OBRIGATÓRIA"
		"discretionary": return "DISCRICIONÁRIA"
		"investment": return "INVESTIMENTO"
		"operational": return "CUSTEIO"
		"debt_service": return "DÍVIDA"
	return kind.to_upper()

func _fmt_money(value: float) -> String:
	var n := int(round(value))
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3, 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	return ("-" if n < 0 else "") + "M$ " + out

func _region_name(index: int) -> String:
	if index >= 0 and index < regions.size():
		return str((regions[index] as Dictionary).get("name", "Região %d" % (index + 1)))
	return "Região %d" % (index + 1)

func _project_status_label(status: String) -> String:
	match status:
		"proposta": return "PROPOSTA"
		"viabilidade": return "VIABILIDADE"
		"obras": return "EM OBRAS"
		"paralisada": return "PARALISADA"
		"operacional": return "EM OPERAÇÃO"
		"cancelado": return "CANCELADO"
	return status.to_upper()

func _project_status_color(status: String) -> Color:
	match status:
		"obras": return GREEN
		"operacional": return AMBER
		"paralisada": return RED
		"cancelado": return SUBTLE
	return MUTED

## Painel-resumo dentro de Governo: o jogador vê o estado fiscal e salta para
## a tela específica.
func _public_admin_panel() -> PanelContainer:
	var report := Government.report(state)
	var fiscal: Dictionary = report.get("fiscal", {}) if report.get("fiscal") is Dictionary else {}
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("ADMINISTRAÇÃO PÚBLICA  ·  FASE C", 12, AMBER))
	col.add_child(_label("Receita %.1f%% do PIB  ·  despesa planejada %.1f%%  ·  primário %s  ·  dívida %.1f%%  ·  serviços %.0f/100" % [
		float(fiscal.get("tax_share", 0.0)), BudgetSystem.total_planned(state),
		_fmt_money(float(fiscal.get("primary", 0.0))), float(state.debt), float(fiscal.get("service_index", 50.0))], 13, TEXT))
	col.add_child(_label("Orçamento aprovado só vira entrega quando a capacidade administrativa e a dotação de cada pasta acompanham a decisão.", 12, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	for item in [["ORÇAMENTO", "Orçamento"], ["MINISTÉRIOS", "Ministérios"], ["PROJETOS", "Projetos"], ["DÍVIDA", "Dívida"], ["SERVIÇOS", "Serviços"], ["RELATÓRIO", "Relatório do governo"]]:
		var b := _button(str(item[0]), SUBTLE, false)
		b.pressed.connect(_select_nav.bind(str(item[1])))
		actions.add_child(b)
	col.add_child(actions)
	panel.add_child(col)
	return panel

func _show_budget() -> void:
	_show_section("Orçamento", "O plano aprovado não é o gasto executado: dotação, capacidade administrativa e vínculos obrigatórios decidem o que chega ao fim do mês.")
	var b: Dictionary = state.get("budget", {}) if state.get("budget") is Dictionary else {}
	var status := str(b.get("status", "approved"))
	var fiscal: Dictionary = state.get("fiscal", {}) if state.get("fiscal") is Dictionary else {}
	var planned := BudgetSystem.total_planned(state)
	var revenue := float(state.get("tax_revenue_share", 0.0))
	var projected := revenue - planned
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("RECEITA / PIB", "%.1f%%" % revenue, GREEN if revenue >= 24.0 else AMBER))
	kpis.add_child(_metric_card("DESPESA PLANEJADA", "%.1f%%" % planned, RED if planned > revenue + 6.0 else TEXT))
	kpis.add_child(_metric_card("RESULTADO PROJETADO", "%+.1f p.p." % projected, GREEN if projected >= 0.0 else RED))
	kpis.add_child(_metric_card("TESOURO", _fmt_money(float(state.get("treasury", 0.0))), AMBER if float(state.get("treasury", 0.0)) >= 0.0 else RED))
	main_column.add_child(kpis)
	var head := _panel_box()
	var hcol := VBoxContainer.new()
	hcol.add_child(_label("PLANO ANUAL  ·  %d  ·  %s" % [int(b.get("year", state.date_year)), "EM REVISÃO" if status == "draft" else "APROVADO" if status == "approved" else "REJEITADO"], 12, AMBER))
	hcol.add_child(_label("Ajustes movem a dotação dentro dos limites de cada categoria. Obrigatórias têm piso; investimento tem teto de absorção. Submeter abre a votação no parlamento.", 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.add_child(_table_head("CATEGORIA", 190))
	header.add_child(_table_head("TIPO", 104))
	header.add_child(_table_head("PLANO", 72))
	header.add_child(_table_head("M$/MÊS", 96))
	header.add_child(_table_head("EXECUTADO NO ANO", 120))
	header.add_child(_table_head("EXECUÇÃO", 200))
	hcol.add_child(header)
	for entry in BudgetSystem.categories():
		var id := str(entry.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_table_cell(str(entry.get("label", id)), 190, TEXT))
		row.add_child(_table_cell(_type_label(str(entry.get("type", ""))), 104, MUTED))
		row.add_child(_table_cell("%.1f%%" % BudgetSystem.planned_share(state, id), 72, TEXT, true))
		row.add_child(_table_cell(str(int(BudgetSystem.category_envelope(state, id))), 96, MUTED, true))
		var executed := float((b.get("executed", {}) as Dictionary).get(id, 0.0)) if b.get("executed") is Dictionary else 0.0
		row.add_child(_table_cell(str(int(executed)), 120, MUTED, true))
		var plan_m := maxf(0.01, BudgetSystem.planned_share(state, id) / 100.0 * BudgetSystem.monthly_gdp(state))
		var rate := clampf(executed / maxf(1.0, plan_m * float(state.get("date_month", 1))), 0.0, 1.4)
		var bar := _bar(rate * 100.0, 100.0, GREEN if rate >= 0.75 else AMBER if rate >= 0.5 else RED, 10.0)
		bar.custom_minimum_size.x = 120
		row.add_child(bar)
		row.add_child(_table_cell("%.0f%%" % (rate * 100.0), 52, MUTED, true))
		if bool(state.get("government", false)):
			var minus := _button("-", SUBTLE, false)
			minus.custom_minimum_size.x = 34
			minus.pressed.connect(_budget_adjust.bind(id, -0.2))
			var plus := _button("+", AMBER, false)
			plus.custom_minimum_size.x = 34
			plus.pressed.connect(_budget_adjust.bind(id, 0.2))
			row.add_child(minus); row.add_child(plus)
		hcol.add_child(row)
	head.add_child(hcol)
	main_column.add_child(head)
	var actions := _panel_box()
	var acol := VBoxContainer.new()
	acol.add_child(_label("NEGOCIAÇÃO COM O PARLAMENTO", 12, AMBER))
	var preview := BudgetSystem.support_preview(state)
	acol.add_child(_label("Apoio estimado: %d de %d cadeiras (%.0f%%); maioria %d. O texto só é aprovado se a base e os aliados sustentarem o plano." % [
		int(preview.get("ayes", 0)), int(preview.get("chamber", 0)), float(preview.get("score", 0.0)) * 100.0, int(preview.get("majority", 0))], 13, TEXT))
	var last: Dictionary = b.get("last_vote", {}) if b.get("last_vote") is Dictionary else {}
	if not last.is_empty():
		acol.add_child(_label("Última votação: %s · %d a favor · %d contra · %d abstenções · %s" % [
			str(last.get("month", "")), int(last.get("ayes", 0)), int(last.get("nayes", 0)), int(last.get("abstain", 0)),
			"aprovado" if bool(last.get("approved", false)) else "rejeitado"], 12, MUTED))
	var buttons := HBoxContainer.new()
	var review := _button("REVISAR PLANO", SUBTLE, false)
	review.disabled = not bool(state.get("government", false))
	review.pressed.connect(_budget_review)
	buttons.add_child(review)
	var submit := _button("SUBMETER AO PARLAMENTO", AMBER)
	submit.disabled = not bool(state.get("government", false)) or status == "approved"
	submit.pressed.connect(_submit_budget)
	buttons.add_child(submit)
	acol.add_child(buttons)
	actions.add_child(acol)
	main_column.add_child(actions)

func _budget_adjust(id: String, delta: float) -> void:
	var result := BudgetSystem.adjust(state, id, delta)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Ajuste indisponível")), "warning")
		return
	_save_game(); _show_budget()

func _budget_review() -> void:
	BudgetSystem.open_draft(state)
	_save_game(); _show_budget()

func _submit_budget() -> void:
	var result := BudgetSystem.submit(state, _country_by_id(str(state.country_id)))
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Votação indisponível")), "warning")
		return
	_clamp_state(); _save_game()
	_show_toast(str(result.get("reason", "Orçamento votado")), "success" if bool(result.get("approved", false)) else "warning")
	_show_budget()

func _show_revenue() -> void:
	_show_section("Receitas", "Alíquota não é arrecadação: a base, a conformidade e a resposta econômica definem quanto entra no tesouro.")
	var revenue := float(state.get("tax_revenue_share", 0.0))
	var total := float((state.get("tax_revenue", {}) as Dictionary).get("total", 0.0))
	var compliance := 0.0
	for entry in Taxation.definitions():
		compliance += float((state.get("taxes", {}) as Dictionary).get(str(entry.get("id", "")), {}).get("compliance", 0.75))
	compliance = compliance / maxf(1.0, float(Taxation.definitions().size()))
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("RECEITA DO MÊS", _fmt_money(total), GREEN))
	kpis.add_child(_metric_card("CARGA / PIB", "%.1f%%" % revenue, AMBER if revenue < 28.0 else RED))
	kpis.add_child(_metric_card("CONFORMIDADE", "%.0f%%" % (compliance * 100.0), TEXT))
	kpis.add_child(_metric_card("EFEITO NO PIB", "%+.2f p.p." % float(state.get("tax_burden_effect", 0.0)), GREEN if float(state.get("tax_burden_effect", 0.0)) >= 0.0 else RED))
	main_column.add_child(kpis)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("ESTRUTURA TRIBUTÁRIA", 12, AMBER))
	col.add_child(_label("Cada linha tem base declarada em % do PIB anual. Receita = base × alíquota × conformidade × resposta comportamental. Aumentos acima do neutro reduzem a base e a conformidade.", 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	for item in [["TRIBUTO", 210], ["BASE / PIB", 92], ["ALÍQUOTA", 84], ["RECEITA DO MÊS", 130], ["CONFORMIDADE", 110]]:
		header.add_child(_table_head(str(item[0]), int(item[1])))
	col.add_child(header)
	for entry in Taxation.definitions():
		var id := str(entry.get("id", ""))
		var tax: Dictionary = (state.get("taxes", {}) as Dictionary).get(id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_table_cell(str(entry.get("label", id)), 210, TEXT))
		row.add_child(_table_cell("%.1f%%" % float(entry.get("base_share", 0.0)), 92, MUTED, true))
		row.add_child(_table_cell("%.1f%%" % float(tax.get("rate", 0.0)), 84, TEXT, true))
		row.add_child(_table_cell(str(int((state.get("tax_revenue", {}).get("by_tax", {}) as Dictionary).get(id, 0.0))), 130, MUTED, true))
		row.add_child(_table_cell("%.0f%%" % (float(tax.get("compliance", 0.0)) * 100.0), 110, MUTED, true))
		if bool(state.get("government", false)):
			var minus := _button("-", SUBTLE, false); minus.custom_minimum_size.x = 34
			minus.pressed.connect(_tax_adjust.bind(id, -1.0))
			var plus := _button("+", AMBER, false); plus.custom_minimum_size.x = 34
			plus.pressed.connect(_tax_adjust.bind(id, 1.0))
			row.add_child(minus); row.add_child(plus)
		col.add_child(row)
	col.add_child(_rule())
	col.add_child(_label("O imposto de renda e o consumo incidem sobre bases amplas; riqueza e propriedade têm conformidade menor. A administração tributária é a capacidade média das pastas.", 11, SUBTLE))
	panel.add_child(col)
	main_column.add_child(panel)

func _tax_adjust(id: String, delta: float) -> void:
	var result := Taxation.adjust(state, id, delta)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Ajuste indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_revenue()
	_show_toast(str(result.get("reason", "Alíquota ajustada")), "success")

func _show_ministries() -> void:
	if ministry_focus != "":
		_show_ministry_candidates(ministry_focus)
		return
	_show_section("Ministérios", "Competência técnica e lealdade política são eixos distintos. A capacidade de execução nasce da combinação entre ministro, dotação e serviço.")
	var summary := Ministries.summary(state)
	var rows: Array = summary.get("rows", [])
	var without := 0
	for row in rows:
		if str(row.get("minister", "")) == "":
			without += 1
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("CAPACIDADE MÉDIA", "%.0f/100" % float(summary.get("capacity", 50.0)), GREEN if float(summary.get("capacity", 50.0)) >= 55.0 else RED))
	kpis.add_child(_metric_card("DESEMPENHO", "%.0f/100" % float(summary.get("performance", 50.0)), TEXT))
	kpis.add_child(_metric_card("PASTAS SEM MINISTRO", str(without), RED if without > 0 else GREEN))
	kpis.add_child(_metric_card("CUSTO DE NOMEAÇÃO", "M$ %d" % int(BudgetSystem.fiscal().get("default_minister_cost", 260)), AMBER))
	main_column.add_child(kpis)
	for row in rows:
		var id := str(row.get("id", ""))
		var block := _panel_box()
		var col := VBoxContainer.new()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(_label(str(row.get("label", id)), 16, TEXT))
		head.add_child(_label("pasta de %s" % str(BudgetSystem.category(str(row.get("category", ""))).get("label", row.get("category", ""))), 11, SUBTLE))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(spacer)
		var appoint := _button("SUBSTITUIR" if str(row.get("minister", "")) != "" else "NOMEAR", AMBER, false)
		appoint.disabled = not bool(state.get("government", false))
		appoint.pressed.connect(_open_ministry.bind(id))
		head.add_child(appoint)
		col.add_child(head)
		var minister := str(row.get("minister", ""))
		if minister == "":
			col.add_child(_label("Sem titular. A pasta opera com capacidade residual e perde desempenho a cada mês.", 13, RED))
		else:
			col.add_child(_label("%s  ·  %s  ·  %s  ·  no cargo há %d mês(es)" % [minister, str(row.get("party", "")), str(row.get("kind", "")), int(row.get("months", 0))], 13, TEXT))
		var meters := HBoxContainer.new()
		meters.add_theme_constant_override("separation", 16)
		var capacity := float(row.get("capacity", 50.0))
		var bar := _bar(capacity, 100.0, GREEN if capacity >= 55.0 else AMBER if capacity >= 42.0 else RED, 12.0)
		bar.custom_minimum_size.x = 180
		meters.add_child(_label("CAPACIDADE", 10, SUBTLE)); meters.add_child(bar)
		meters.add_child(_label("%.0f" % capacity, 13, TEXT))
		meters.add_child(_label("COMPETÊNCIA %.0f  ·  LEALDADE %.0f  ·  EXPERIÊNCIA %.0f  ·  DESEMPENHO %.0f" % [
			float(row.get("competence", 0.0)), float(row.get("loyalty", 0.0)), float(row.get("experience", 0.0)), float(row.get("performance", 0.0))], 11, MUTED))
		col.add_child(meters)
		var responsibilities: Array = row.get("responsibilities", [])
		col.add_child(_label("Responsabilidades: %s" % ", ".join(PackedStringArray(responsibilities)), 11, SUBTLE))
		block.add_child(col)
		main_column.add_child(block)

func _open_ministry(id: String) -> void:
	ministry_focus = id
	_show_ministries()

func _show_ministry_candidates(id: String) -> void:
	var entry := Ministries.definition(id)
	_show_section("Ministérios", "Candidatos: o mesmo mês e a mesma pasta produzem o mesmo quadro. Escolha entre competência e lealdade.")
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("CANDIDATOS PARA %s" % str(entry.get("label", id)).to_upper(), 12, AMBER))
	col.add_child(_label("Nomear um aliado reforça a coalizão e pode consumir cota de pastas; um técnico independente eleva a capacidade e desagrada a base.", 12, MUTED))
	var candidates := Ministries.candidates(state, id, 3)
	for index in candidates.size():
		var candidate: Dictionary = candidates[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_label(str(candidate.get("name", "")), 15, TEXT))
		row.add_child(_label("%s · %s" % [str(candidate.get("kind", "")), str(candidate.get("party", ""))], 11, MUTED))
		row.add_child(_label("competência %.0f · lealdade %.0f · experiência %.0f" % [float(candidate.get("competence", 0.0)), float(candidate.get("loyalty", 0.0)), float(candidate.get("experience", 0.0))], 12, SUBTLE))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(spacer)
		var pick := _button("NOMEAR  ·  M$ %d" % int(candidate.get("cost", 0)), AMBER, false)
		pick.disabled = not bool(state.get("government", false))
		pick.pressed.connect(_appoint_ministry_candidate.bind(id, index))
		row.add_child(pick)
		col.add_child(row)
		col.add_child(_rule())
	var back := _button("VOLTAR", SUBTLE, false)
	back.pressed.connect(_close_ministry)
	col.add_child(back)
	panel.add_child(col)
	main_column.add_child(panel)

func _close_ministry() -> void:
	ministry_focus = ""
	_show_ministries()

func _appoint_ministry_candidate(id: String, index: int) -> void:
	var candidates := Ministries.candidates(state, id, 3)
	if index < 0 or index >= candidates.size():
		_show_toast("Candidato indisponível", "warning")
		return
	var result := Ministries.appoint(state, id, candidates[index])
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Nomeação indisponível")), "warning")
		return
	ministry_focus = ""
	_clamp_state(); _save_game(); _show_ministries()
	_show_toast(str(result.get("reason", "Ministro nomeado")), "success")

func _show_projects() -> void:
	_show_section("Projetos", "Cada obra percorre proposta, viabilidade, dotação, financiamento, execução e avaliação. Atraso e estouro têm causa: capacidade, verba e risco.")
	var active := Projects.active_count(state)
	var operational := Projects.operational_count(state)
	var fiscal: Dictionary = state.get("fiscal", {}) if state.get("fiscal") is Dictionary else {}
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("EM OBRA", str(active), AMBER if active > 0 else SUBTLE))
	kpis.add_child(_metric_card("EM OPERAÇÃO", str(operational), GREEN if operational > 0 else SUBTLE))
	kpis.add_child(_metric_card("CAPITAL DO MÊS", _fmt_money(float(fiscal.get("capital", 0.0))), TEXT))
	kpis.add_child(_metric_card("CUSTEIO ANUAL", _fmt_money(float(state.get("budget", {}).get("opex_month", 0.0)) * 12.0), MUTED))
	main_column.add_child(kpis)
	if bool(state.get("government", false)):
		var catalog_panel := _panel_box()
		var ccol := VBoxContainer.new()
		ccol.add_child(_label("CATÁLOGO DE PROJETOS  ·  PROPOSTA", 12, AMBER))
		var region_row := HBoxContainer.new()
		region_row.add_child(_label("Região de execução:", 12, MUTED))
		project_region_select = OptionButton.new()
		for i in regions.size():
			project_region_select.add_item(_region_name(i), i)
		project_region_select.selected = 0
		region_row.add_child(project_region_select)
		ccol.add_child(region_row)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		for entry in Projects.catalog():
			var b := _button("%s  ·  M$ %s  ·  %d meses" % [str(entry.get("label", "")), str(int(float(entry.get("capex", 0.0)))), int(entry.get("months", 12))], SUBTLE, false)
			b.tooltip_text = str(entry.get("description", ""))
			b.pressed.connect(_propose_project.bind(str(entry.get("id", ""))))
			grid.add_child(b)
		ccol.add_child(grid)
		catalog_panel.add_child(ccol)
		main_column.add_child(catalog_panel)
	var list := _panel_box()
	var lcol := VBoxContainer.new()
	lcol.add_child(_label("CARTEIRA DE PROJETOS", 12, AMBER))
	if (state.get("projects", []) as Array).is_empty():
		lcol.add_child(_label("Nenhum projeto proposto. A primeira etapa custa 1% do capital como estudo de viabilidade.", 13, MUTED))
	for item in state.get("projects", []):
		var project: Dictionary = item
		var status := str(project.get("status", ""))
		var block := VBoxContainer.new()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(_label(str(project.get("label", "")), 15, TEXT))
		head.add_child(_label("%s · %s" % [_region_name(int(project.get("region", 0))), _project_status_label(status)], 11, _project_status_color(status)))
		var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(spacer)
		head.add_child(_label("M$ %s de M$ %s" % [str(int(project.get("cost_spent", 0.0))), str(int(project.get("cost_total", 0.0)))], 12, MUTED))
		block.add_child(head)
		var progress := _bar(float(project.get("progress", 0.0)), 100.0, _project_status_color(status), 10.0)
		block.add_child(progress)
		var detail := "%s · %.0f%% · %d mês(es) restantes · risco %.0f · estouro %.0f%% · financiamento %s" % [
			str(project.get("label", "")), float(project.get("progress", 0.0)), int(ceil(float(project.get("months_left", 0.0)))),
			float(project.get("risk", 0.0)), float(project.get("overrun", 0.0)) * 100.0, str(Projects.FUNDING_LABELS.get(str(project.get("funding", "tesouro")), project.get("funding", "")))]
		block.add_child(_label(detail, 12, MUTED))
		var evaluation: Dictionary = project.get("evaluation", {}) if project.get("evaluation") is Dictionary else {}
		if not evaluation.is_empty():
			block.add_child(_label("Avaliação: %s de %s beneficiários previstos · serviço entregue %.1f de %.1f · qualidade %.0f/100" % [
				str(int(evaluation.get("actual_beneficiaries", 0))), str(int(evaluation.get("expected_beneficiaries", 0))),
				float(evaluation.get("actual_service", 0.0)), float(evaluation.get("expected_service", 0.0)), float(evaluation.get("quality", 0.0))], 12, AMBER))
		var actions := HBoxContainer.new()
		if status == "proposta":
			var feasibility := _button("CONCLUIR VIABILIDADE", AMBER, false)
			feasibility.pressed.connect(_project_feasibility.bind(str(project.get("id", ""))))
			actions.add_child(feasibility)
		elif status == "viabilidade":
			for funding in ["tesouro", "titulos", "ppp", "externo"]:
				var approve := _button("APROVAR · %s" % str(Projects.FUNDING_LABELS.get(funding, funding)).to_upper(), AMBER if funding == "tesouro" else SUBTLE, false)
				approve.pressed.connect(_project_approve.bind(str(project.get("id", "")), funding))
				actions.add_child(approve)
		elif status in ["obras", "paralisada"]:
			var cancel := _button("CANCELAR OBRA", RED, false)
			cancel.pressed.connect(_project_cancel.bind(str(project.get("id", ""))))
			actions.add_child(cancel)
		if actions.get_child_count() > 0:
			block.add_child(actions)
		lcol.add_child(block)
		lcol.add_child(_rule())
	list.add_child(lcol)
	main_column.add_child(list)

func _propose_project(key: String) -> void:
	var region := 0
	if is_instance_valid(project_region_select):
		region = project_region_select.selected
	var result := Projects.propose(state, key, region)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Proposta indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_projects()
	_show_toast(str(result.get("reason", "Proposta criada")), "success")

func _project_feasibility(id: String) -> void:
	var result := Projects.feasibility(state, id)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Viabilidade indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_projects()
	_show_toast("Viabilidade concluída: risco %.0f/100" % float(result.get("risk", 0.0)), "success")

func _project_approve(id: String, funding: String) -> void:
	var result := Projects.approve(state, id, funding)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Aprovação indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_projects()
	_show_toast(str(result.get("reason", "Obra aprovada")), "success")

func _project_cancel(id: String) -> void:
	var result := Projects.cancel(state, id)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Cancelamento indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_projects()
	_show_toast(str(result.get("reason", "Projeto cancelado")), "warning")

func _show_debt() -> void:
	_show_section("Dívida", "Emprestar financia investimento e cria serviço futuro; cortar despesa melhora o resultado e reduz capacidade. O custo depende da taxa, do prazo e do que a dívida financia.")
	var stats: Dictionary = state.get("debt_stats", {}) if state.get("debt_stats") is Dictionary else {}
	var book: Array = state.get("debt_book", []) if state.get("debt_book") is Array else []
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("DÍVIDA / PIB", "%.1f%%" % float(state.debt), RED if float(state.debt) >= 90.0 else AMBER if float(state.debt) >= 70.0 else GREEN))
	kpis.add_child(_metric_card("JUROS DO MÊS", _fmt_money(float(stats.get("interest", 0.0))), RED if float(stats.get("interest", 0.0)) > 0.0 else TEXT))
	kpis.add_child(_metric_card("RESULTADO PRIMÁRIO", _fmt_money(float(stats.get("primary", 0.0))), GREEN if float(stats.get("primary", 0.0)) >= 0.0 else RED))
	kpis.add_child(_metric_card("TAXA MÉDIA", "%.1f%%" % float(stats.get("average_rate", 0.0)), AMBER))
	main_column.add_child(kpis)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("ESTOQUE E FLUXOS", 12, AMBER))
	col.add_child(_label("Resultado total %s · financiamento do déficit %s · amortização %s · buffer de caixa %s · capital financiado por títulos %s" % [
		_fmt_money(float(stats.get("overall", 0.0))), _fmt_money(float(stats.get("borrowing", 0.0))),
		_fmt_money(float(stats.get("amortization", 0.0))), _fmt_money(float(stats.get("buffer", 0.0))),
		_fmt_money(float(stats.get("project_financed", 0.0)))], 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	for item in [["TRANCHE", 90], ["ORIGEM", 210], ["VALOR", 150], ["TAXA", 80], ["MESES", 70]]:
		header.add_child(_table_head(str(item[0]), int(item[1])))
	col.add_child(header)
	for tranche in book:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var t: Dictionary = tranche
		row.add_child(_table_cell(str(t.get("id", "")), 90, MUTED, true))
		row.add_child(_table_cell(str(t.get("source", "")), 210, TEXT))
		row.add_child(_table_cell(_fmt_money(float(t.get("amount", 0.0))), 150, TEXT, true))
		row.add_child(_table_cell("%.1f%%" % float(t.get("rate", 0.0)), 80, AMBER, true))
		row.add_child(_table_cell(str(int(t.get("months_left", 0))), 70, MUTED, true))
		col.add_child(row)
	col.add_child(_rule())
	var actions := HBoxContainer.new()
	for pct in [1, 2]:
		var issue := _button("EMITIR %d%% DO PIB" % pct, AMBER, false)
		issue.disabled = not bool(state.get("government", false))
		issue.pressed.connect(_debt_action.bind("issue", float(pct)))
		actions.add_child(issue)
		var amortize := _button("AMORTIZAR %d%% DO PIB" % pct, SUBTLE, false)
		amortize.disabled = not bool(state.get("government", false))
		amortize.pressed.connect(_debt_action.bind("amortize", float(pct)))
		actions.add_child(amortize)
	col.add_child(actions)
	col.add_child(_label("O caixa abaixo do buffer é financiado automaticamente por emissão. Emitir antes de gastar antecipa recursos, mas o estoque e os juros sobem no mesmo ato.", 11, SUBTLE))
	panel.add_child(col)
	main_column.add_child(panel)

func _debt_action(kind: String, pct: float) -> void:
	var result := Debt.issue_bond(state, pct) if kind == "issue" else Debt.amortize(state, pct)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "Operação indisponível")), "warning")
		return
	_clamp_state(); _save_game(); _show_debt()
	_show_toast(str(result.get("reason", "Operação concluída")), "success")

func _show_services() -> void:
	_show_section("Serviços", "Gastar não é entregar. Cobertura, qualidade, capacidade, demanda e eficiência são estoques distintos, movidos por dotação, efetivo e infraestrutura concluída.")
	var summary := PublicServices.summary(state)
	var rows: Array = summary.get("rows", [])
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("ÍNDICE DE SERVIÇOS", "%.0f/100" % float(summary.get("index", 50.0)), GREEN if float(summary.get("index", 50.0)) >= 55.0 else AMBER if float(summary.get("index", 50.0)) >= 45.0 else RED))
	kpis.add_child(_metric_card("SERVIÇOS MONITORADOS", str(rows.size()), SUBTLE))
	kpis.add_child(_metric_card("CAPACIDADE DO ESTADO", "%.0f/100" % float(state.get("admin_capacity", 50.0)), TEXT))
	kpis.add_child(_metric_card("PROJETOS EM OPERAÇÃO", str(Projects.operational_count(state)), AMBER))
	main_column.add_child(kpis)
	var panel := _panel_box()
	var col := VBoxContainer.new()
	col.add_child(_label("INDICADORES POR SERVIÇO", 12, AMBER))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	for item in [["SERVIÇO", 170], ["COBERTURA", 100], ["QUALIDADE", 100], ["CAPACIDADE", 100], ["DEMANDA", 90], ["EFICIÊNCIA", 100], ["INFRA", 90]]:
		header.add_child(_table_head(str(item[0]), int(item[1])))
	col.add_child(header)
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(_table_cell(str(row.get("label", "")), 170, TEXT))
		for key in ["coverage", "quality", "capacity", "demand", "efficiency", "infrastructure"]:
			var value := float(row.get(key, 0.0))
			var color := GREEN if value >= 60.0 else AMBER if value >= 45.0 else RED
			if key == "demand":
				color = MUTED
			line.add_child(_table_cell("%.0f" % value, 100 if key != "demand" and key != "infrastructure" else 90, color, true))
		col.add_child(line)
	col.add_child(_rule())
	col.add_child(_label("O índice combina cobertura (40%), qualidade (40%) e capacidade (20%). Um país pode gastar muito e entregar pouco se a capacidade administrativa e a infraestrutura não acompanham.", 11, SUBTLE))
	panel.add_child(col)
	main_column.add_child(panel)

func _show_government_report() -> void:
	_show_section("Relatório do governo", "Planejado e executado lado a lado, com os fatores que explicam a diferença. Nenhuma causalidade é afirmada sem mecanismo.")
	var report := Government.report(state)
	var fiscal: Dictionary = report.get("fiscal", {}) if report.get("fiscal") is Dictionary else {}
	var balance: Dictionary = report.get("balance", {}) if report.get("balance") is Dictionary else {}
	var kpis := HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	kpis.add_child(_metric_card("RECEITA", _fmt_money(float(balance.get("revenue", 0.0))), GREEN))
	kpis.add_child(_metric_card("DESPESA", _fmt_money(float(balance.get("spending", 0.0))), TEXT))
	kpis.add_child(_metric_card("RESULTADO TOTAL", _fmt_money(float(balance.get("overall", 0.0))), GREEN if float(balance.get("overall", 0.0)) >= 0.0 else RED))
	kpis.add_child(_metric_card("DÍVIDA / PIB", "%.1f%%" % float(state.debt), RED if float(state.debt) >= 90.0 else AMBER))
	main_column.add_child(kpis)
	var budget_summary: Dictionary = report.get("budget", {}) if report.get("budget") is Dictionary else {}
	var executed: Dictionary = budget_summary.get("executed", {}) if budget_summary.get("executed") is Dictionary else {}
	var budget_panel := _panel_box()
	var bcol := VBoxContainer.new()
	bcol.add_child(_label("ORÇAMENTO APROVADO × EXECUTADO NO ANO", 12, AMBER))
	bcol.add_child(_label("Status: %s · plano %.1f%% do PIB · tesouro %s" % [
		"aprovado" if str(budget_summary.get("status", "")) == "approved" else "em revisão", BudgetSystem.total_planned(state), _fmt_money(float(state.get("treasury", 0.0)))], 12, MUTED))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	for item in [["CATEGORIA", 200], ["PLANO ANUAL", 120], ["EXECUTADO", 120], ["EXECUÇÃO", 90], ["STATUS", 120]]:
		header.add_child(_table_head(str(item[0]), int(item[1])))
	bcol.add_child(header)
	for entry in BudgetSystem.categories():
		var id := str(entry.get("id", ""))
		var planned_m := BudgetSystem.planned_share(state, id) / 100.0 * BudgetSystem.annual_gdp(state)
		var actual := float(executed.get(id, 0.0))
		var rate := clampf(actual / maxf(1.0, planned_m), 0.0, 1.5)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_table_cell(str(entry.get("label", id)), 200, TEXT))
		row.add_child(_table_cell(_fmt_money(planned_m), 120, MUTED, true))
		row.add_child(_table_cell(_fmt_money(actual), 120, TEXT, true))
		row.add_child(_table_cell("%.0f%%" % (rate * 100.0), 90, GREEN if rate >= 0.8 else AMBER if rate >= 0.5 else RED, true))
		row.add_child(_table_cell("no prazo" if rate >= 0.8 else "abaixo do plano" if rate >= 0.5 else "execução baixa", 120, MUTED))
		bcol.add_child(row)
	budget_panel.add_child(bcol)
	main_column.add_child(budget_panel)
	var ministries: Dictionary = report.get("ministries", {}) if report.get("ministries") is Dictionary else {}
	var mp := _panel_box()
	var mcol := VBoxContainer.new()
	mcol.add_child(_label("DESEMPENHO DAS PASTAS", 12, AMBER))
	for row in ministries.get("rows", []):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(_table_cell(str(row.get("label", "")), 190, TEXT))
		line.add_child(_table_cell(str(row.get("minister", "sem titular")), 190, MUTED))
		var bar := _bar(float(row.get("capacity", 0.0)), 100.0, GREEN if float(row.get("capacity", 0.0)) >= 55.0 else RED, 10.0)
		bar.custom_minimum_size.x = 140
		line.add_child(bar)
		line.add_child(_table_cell("capacidade %.0f · desempenho %.0f" % [float(row.get("capacity", 0.0)), float(row.get("performance", 0.0))], 220, MUTED, true))
		mcol.add_child(line)
	mp.add_child(mcol)
	main_column.add_child(mp)
	var pp := _panel_box()
	var pcol := VBoxContainer.new()
	pcol.add_child(_label("EXECUÇÃO DE PROJETOS", 12, AMBER))
	var projects: Dictionary = report.get("projects", {}) if report.get("projects") is Dictionary else {}
	if (projects.get("rows", []) as Array).is_empty():
		pcol.add_child(_label("Nenhum projeto na carteira.", 12, MUTED))
	for item in projects.get("rows", []):
		var project: Dictionary = item
		pcol.add_child(_label("%s · %s · %s · %.0f%% · M$ %s de M$ %s" % [
			str(project.get("label", "")), _region_name(int(project.get("region", 0))), _project_status_label(str(project.get("status", ""))),
			float(project.get("progress", 0.0)), str(int(project.get("cost_spent", 0.0))), str(int(project.get("cost_total", 0.0)))], 12, TEXT))
	pp.add_child(pcol)
	main_column.add_child(pp)
	var services: Dictionary = report.get("services", {}) if report.get("services") is Dictionary else {}
	var sp := _panel_box()
	var scol := VBoxContainer.new()
	scol.add_child(_label("INDICADORES DE SERVIÇOS", 12, AMBER))
	for row in services.get("rows", []):
		scol.add_child(_label("%s · cobertura %.0f · qualidade %.0f · capacidade %.0f · demanda %.0f" % [
			str(row.get("label", "")), float(row.get("coverage", 0.0)), float(row.get("quality", 0.0)),
			float(row.get("capacity", 0.0)), float(row.get("demand", 0.0))], 12, TEXT))
	sp.add_child(scol)
	main_column.add_child(sp)
	var fp := _panel_box()
	var fcol := VBoxContainer.new()
	fcol.add_child(_label("FATORES QUE EXPLICAM O RESULTADO", 12, AMBER))
	for factor in report.get("factors", []):
		var label := _label("• " + str(factor), 12, MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fcol.add_child(label)
	fp.add_child(fcol)
	main_column.add_child(fp)
	main_column.add_child(_causal_panel())

