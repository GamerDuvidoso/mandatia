extends RefCounted
## Catálogo de eventos do mês. Roda sem IA: a conjuntura do país decide quais
## eventos são elegíveis e cada um oferece três respostas com custo e efeito
## reais. Puro: recebe o estado (Dictionary) e devolve dados, sem tocar a UI.

const MACRO_KEYS := ["economy", "inflation", "unemployment", "debt"]
const GROUPS := ["Jovens", "Trabalhadores", "Empreendedores", "Aposentados", "Rurais"]
const RECENT_LIMIT := 5
const LABELS := {
	"approval": "aprovação", "popularity": "popularidade", "funds": "caixa",
	"debt": "dívida", "economy": "crescimento", "unemployment": "desemprego",
	"inflation": "inflação", "credibility": "credibilidade", "cohesion": "coesão",
}

## `when`: limites sobre o estado (<chave>_min / <chave>_max). `weight`: peso
## base; evento cuja condição vale pesa 3x (a conjuntura puxa o noticiário).
const CATALOG := [
	{"id": "greve", "weight": 1.0, "when": {"unemployment_min": 6.5},
	 "headline": "Sindicatos convocam greve nacional por reajuste acima da inflação.",
	 "options": [
		{"label": "Negociar o reajuste", "hint": "Custa caixa; acalma as ruas.", "effects": {"funds": -900, "approval": 2, "cohesion": 1, "inflation": 0.2}, "groups": {"Trabalhadores": 3}},
		{"label": "Mediar sem ceder", "hint": "Ganha credibilidade, perde apoio operário.", "effects": {"credibility": 2, "approval": -1}, "groups": {"Trabalhadores": -2}},
		{"label": "Endurecer", "hint": "Corta o custo, racha a base.", "effects": {"approval": -4, "cohesion": -2, "credibility": -1}, "groups": {"Trabalhadores": -4, "Empreendedores": 2}},
	]},
	{"id": "inflacao_alimentos", "weight": 1.0, "when": {"inflation_min": 6.0},
	 "headline": "Inflação de alimentos corrói salários e domina o noticiário.",
	 "options": [
		{"label": "Subsídio emergencial", "hint": "Alivia agora, pesa na dívida.", "effects": {"funds": -1200, "approval": 3, "debt": 0.4, "inflation": -0.2}},
		{"label": "Disciplina fiscal e juros", "hint": "Dói no curto prazo, ancora a inflação.", "effects": {"approval": -2, "credibility": 3, "inflation": -0.5, "economy": -0.2}},
		{"label": "Pedir paciência", "hint": "Sem custo, sem resposta.", "effects": {"approval": -3, "popularity": -1}},
	]},
	{"id": "demissoes", "weight": 1.0, "when": {"unemployment_min": 9.0},
	 "headline": "Fábricas demitem em massa e o desemprego vira o tema do país.",
	 "options": [
		{"label": "Frente de obras públicas", "hint": "Emprego rápido, custo fiscal.", "effects": {"funds": -1500, "unemployment": -0.4, "approval": 2, "debt": 0.3}, "groups": {"Trabalhadores": 3}},
		{"label": "Incentivo ao setor privado", "hint": "Mais lento, melhora a confiança.", "effects": {"funds": -800, "credibility": 2, "unemployment": -0.2, "economy": 0.1}, "groups": {"Empreendedores": 3}},
		{"label": "Culpar a conjuntura global", "hint": "Barato e pouco convincente.", "effects": {"approval": -2, "credibility": -2}},
	]},
	{"id": "rebaixamento", "weight": 1.0, "when": {"debt_min": 85.0},
	 "headline": "Agências de risco ameaçam rebaixar a nota de crédito do país.",
	 "options": [
		{"label": "Plano de ajuste fiscal", "hint": "Impopular, restaura confiança.", "effects": {"approval": -3, "debt": -1.0, "credibility": 4}, "groups": {"Empreendedores": 2}},
		{"label": "Renegociar prazos", "hint": "Compra tempo por um custo menor.", "effects": {"funds": -500, "debt": -0.3, "credibility": 1}},
		{"label": "Ignorar o alerta", "hint": "O mercado cobra a conta.", "effects": {"credibility": -4, "debt": 0.6, "inflation": 0.2}},
	]},
	{"id": "boom", "weight": 1.0, "when": {"economy_min": 3.5},
	 "headline": "Crescimento acima do esperado atrai capital e otimismo.",
	 "options": [
		{"label": "Reivindicar o resultado", "hint": "Colhe os louros agora.", "effects": {"approval": 3, "popularity": 1}},
		{"label": "Reforçar as reservas", "hint": "Prudência que paga depois.", "effects": {"debt": -0.6, "credibility": 2}},
		{"label": "Distribuir os ganhos", "hint": "Custa caixa, rende apoio.", "effects": {"funds": -1000, "approval": 4, "cohesion": 1}, "groups": {"Trabalhadores": 2, "Aposentados": 2}},
	]},
	{"id": "recessao", "weight": 1.0, "when": {"economy_max": 0.5},
	 "headline": "Indicadores apontam recessão técnica e a confiança despenca.",
	 "options": [
		{"label": "Estímulo anticíclico", "hint": "Segura a atividade, aumenta a dívida.", "effects": {"funds": -1800, "economy": 0.4, "debt": 0.8, "approval": 1}},
		{"label": "Reformas estruturais", "hint": "Aposta de longo prazo.", "effects": {"approval": -2, "credibility": 3, "economy": 0.1}, "groups": {"Empreendedores": 2}},
		{"label": "Esperar a reversão", "hint": "Nada muda no curto prazo.", "effects": {"approval": -3, "credibility": -1}},
	]},
	{"id": "seca", "weight": 1.0, "when": {},
	 "headline": "Uma seca ameaça a produção agrícola do país.",
	 "options": [
		{"label": "Crédito emergencial ao campo", "hint": "Protege o produtor rural.", "effects": {"funds": -1100, "approval": 2, "inflation": -0.1}, "groups": {"Rurais": 4}},
		{"label": "Importar alimentos", "hint": "Segura os preços, cede o campo.", "effects": {"funds": -700, "inflation": -0.2}, "groups": {"Rurais": -3}},
		{"label": "Não intervir", "hint": "Preço de alimento sobe.", "effects": {"approval": -2, "inflation": 0.3}, "groups": {"Rurais": -3}},
	]},
	{"id": "enchentes", "weight": 0.8, "when": {},
	 "headline": "Enchentes deixam milhares de desabrigados em várias regiões.",
	 "options": [
		{"label": "Ajuda federal imediata", "hint": "Caro e visível.", "effects": {"funds": -1800, "approval": 3, "debt": 0.3}},
		{"label": "Mutirão do partido", "hint": "Barato, une a militância.", "effects": {"funds": -400, "cohesion": 2, "popularity": 1}},
		{"label": "Aguardar os estados", "hint": "A cobrança política vem depois.", "effects": {"approval": -3, "credibility": -1}},
	]},
	{"id": "surto", "weight": 0.8, "when": {},
	 "headline": "Surto de gripe sobrecarrega hospitais e pronto-socorros.",
	 "options": [
		{"label": "Campanha de vacinação", "hint": "Contém o surto, rende confiança.", "effects": {"funds": -1300, "approval": 3}, "groups": {"Aposentados": 2}},
		{"label": "Reforçar leitos e equipes", "hint": "Resposta robusta e cara.", "effects": {"funds": -2000, "approval": 4, "debt": 0.3}, "groups": {"Aposentados": 3}},
		{"label": "Pedir cautela à população", "hint": "Pouca ação, crítica certa.", "effects": {"approval": -2, "credibility": -1}},
	]},
	{"id": "escandalo", "weight": 0.7, "when": {},
	 "headline": "Escândalo de corrupção atinge aliados do partido.",
	 "options": [
		{"label": "Afastar os envolvidos", "hint": "Dói na bancada, limpa a imagem.", "effects": {"cohesion": -3, "credibility": 4, "approval": -1}},
		{"label": "Blindar os aliados", "hint": "Preserva a unidade, queima a credibilidade.", "effects": {"credibility": -5, "cohesion": 2}},
		{"label": "Pedir apuração independente", "hint": "Meio-termo com custo.", "effects": {"funds": -300, "credibility": 2, "approval": -1}},
	]},
	{"id": "investimento", "weight": 1.0, "when": {},
	 "headline": "Empresa anuncia investimento bilionário e pede incentivos fiscais.",
	 "options": [
		{"label": "Conceder o incentivo", "hint": "Emprego hoje, caixa menor.", "effects": {"funds": -900, "economy": 0.2, "unemployment": -0.2}, "groups": {"Empreendedores": 2}},
		{"label": "Exigir contrapartidas", "hint": "Negocia e mantém a imagem.", "effects": {"credibility": 2, "economy": 0.1}},
		{"label": "Recusar", "hint": "Agrada a esquerda, assusta o mercado.", "effects": {"approval": 1, "credibility": -1}, "groups": {"Empreendedores": -2}},
	]},
	{"id": "estudantes", "weight": 0.9, "when": {},
	 "headline": "Estudantes ocupam as ruas por mais verba para a educação.",
	 "options": [
		{"label": "Abrir diálogo e verba", "hint": "Custa caixa, conquista os jovens.", "effects": {"funds": -800, "approval": 1}, "groups": {"Jovens": 4}},
		{"label": "Receber os líderes", "hint": "Gesto simbólico.", "effects": {"credibility": 1}, "groups": {"Jovens": 1}},
		{"label": "Ignorar os protestos", "hint": "Os jovens não esquecem.", "effects": {"approval": -2}, "groups": {"Jovens": -4}},
	]},
	{"id": "aposentados", "weight": 0.9, "when": {},
	 "headline": "Aposentados protestam contra a perda de poder de compra.",
	 "options": [
		{"label": "Reajuste extraordinário", "hint": "Conquista o grupo mais fiel.", "effects": {"funds": -1000, "approval": 2, "debt": 0.2}, "groups": {"Aposentados": 4}},
		{"label": "Manter a regra atual", "hint": "Fiscalmente seguro.", "effects": {"credibility": 1}, "groups": {"Aposentados": -3}},
		{"label": "Criar bônus pontual", "hint": "Meio-termo barato.", "effects": {"funds": -400, "approval": 1}, "groups": {"Aposentados": 1}},
	]},
	{"id": "petroleo", "weight": 0.8, "when": {},
	 "headline": "Choque nos preços do petróleo chega às bombas e ao frete.",
	 "options": [
		{"label": "Segurar o preço dos combustíveis", "hint": "Popular, vai para a dívida.", "effects": {"funds": -1400, "approval": 2, "debt": 0.5, "inflation": -0.2}},
		{"label": "Repassar ao consumidor", "hint": "Realismo de mercado.", "effects": {"approval": -3, "inflation": 0.4, "credibility": 1}},
		{"label": "Subsidiar só o transporte coletivo", "hint": "Foco em quem mais precisa.", "effects": {"funds": -700, "approval": 1, "inflation": 0.1}, "groups": {"Trabalhadores": 2}},
	]},
	{"id": "pre_campanha", "weight": 1.0, "when": {"months_to_election_max": 4},
	 "headline": "Pré-campanha aquece e aliados cobram posição sobre alianças.",
	 "options": [
		{"label": "Fechar aliança ampla", "hint": "Mais tempo de TV, menos identidade.", "effects": {"cohesion": -2, "popularity": 2, "funds": 600}},
		{"label": "Manter a identidade", "hint": "Base unida, menos alcance.", "effects": {"cohesion": 2, "popularity": -0.5, "credibility": 1}},
		{"label": "Apostar na mobilização", "hint": "Gasta caixa, ganha ruas.", "effects": {"funds": -700, "popularity": 1.5}},
	]},
]

## Escolhe um evento elegível por sorteio ponderado. `roll` em [0, 1) deixa o
## sorteio testável. Ids recentes ficam de fora, a menos que sobrem só eles.
static func pick(st: Dictionary, roll: float) -> Dictionary:
	var recent: Array = st.get("event_recent", []) if st.get("event_recent") is Array else []
	var pool: Array = []
	var total := 0.0
	for entry in CATALOG:
		if recent.has(entry.id):
			continue
		var w := weight_for(entry, st)
		if w > 0.0:
			pool.append([entry, w])
			total += w
	if pool.is_empty():
		return CATALOG[0].duplicate(true)
	var cursor := clampf(roll, 0.0, 0.999999) * total
	for pair in pool:
		cursor -= float(pair[1])
		if cursor < 0.0:
			return (pair[0] as Dictionary).duplicate(true)
	return (pool[pool.size() - 1][0] as Dictionary).duplicate(true)

## Peso 0 quando a condição não vale; condição não vazia e válida pesa 3x.
static func weight_for(entry: Dictionary, st: Dictionary) -> float:
	var cond: Dictionary = entry.get("when", {})
	if not _conditions_hold(cond, st):
		return 0.0
	var base := float(entry.get("weight", 1.0))
	return base * 3.0 if not cond.is_empty() else base

static func _conditions_hold(cond: Dictionary, st: Dictionary) -> bool:
	for key in cond.keys():
		var name := str(key)
		if name.ends_with("_min"):
			if float(st.get(name.trim_suffix("_min"), 0.0)) < float(cond[key]):
				return false
		elif name.ends_with("_max"):
			if float(st.get(name.trim_suffix("_max"), 0.0)) > float(cond[key]):
				return false
	return true

static func remember(st: Dictionary, event_id: String) -> void:
	var recent: Array = st.get("event_recent", []) if st.get("event_recent") is Array else []
	recent.append(event_id)
	while recent.size() > RECENT_LIMIT:
		recent.pop_front()
	st["event_recent"] = recent

## Custo em caixa de uma opção (0 quando ela rende caixa).
static func cost_of(option: Dictionary) -> float:
	var effects: Dictionary = option.get("effects", {})
	return maxf(0.0, -float(effects.get("funds", 0.0)))

## Aplica a opção ao estado. Fora do governo o jogador não move a macroeconomia
## (economia, inflação, desemprego, dívida), só a imagem do partido.
## Devolve o resumo em texto para o radar.
static func apply(st: Dictionary, option: Dictionary, is_government: bool) -> String:
	var parts: PackedStringArray = []
	var effects: Dictionary = option.get("effects", {})
	for key in effects.keys():
		var name := str(key)
		if not is_government and MACRO_KEYS.has(name):
			continue
		var amount := float(effects[key])
		st[name] = float(st.get(name, 0.0)) + amount
		parts.append("%s %s" % [LABELS.get(name, name), _signed(name, amount)])
	var groups: Dictionary = option.get("groups", {})
	var demographics: Variant = st.get("demographics", {})
	if demographics is Dictionary:
		for group in groups.keys():
			if GROUPS.has(str(group)) and (demographics as Dictionary).has(group):
				demographics[group] = float(demographics[group]) + float(groups[group])
				parts.append("%s %+.0f" % [str(group).to_lower(), float(groups[group])])
	if is_government:
		st["economy"] = clampf(float(st.get("economy", 2.0)), -2.0, 6.0)
		st["inflation"] = clampf(float(st.get("inflation", 4.0)), 1.5, 15.0)
		st["unemployment"] = clampf(float(st.get("unemployment", 8.0)), 3.5, 18.0)
		st["debt"] = clampf(float(st.get("debt", 60.0)), 20.0, 120.0)
	return ", ".join(parts)

static func _signed(name: String, amount: float) -> String:
	if name == "funds":
		return "%+.0f" % amount
	return "%+.1f" % amount
