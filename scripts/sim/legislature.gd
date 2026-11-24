extends RefCounted
## Tramitação e votação de proposições por bancada.
##
## O voto de cada partido depende da distância entre o eixo ideológico do partido
## e o eixo da proposição, mais a disciplina da coalizão de governo. A bancada não
## vota em bloco: as cadeiras se dividem entre sim, abstenção e não conforme a
## distância, então um partido de centro pode aprovar "75% da lei" e ainda assim
## registrar dissidência. Nenhum número de cadeiras é inventado: tudo vem do mapa
## de bancadas da eleição.

const BILLS := [
	{
		"id": "investment",
		"title": "Lei de investimento regional",
		"axis": -0.2,
		"cost": 2400,
		"requires_government": false,
		"summary": "Aporte direto em infraestrutura regional.",
		"effects": {"economy": 0.3, "approval": 2.0, "debt": 0.4},
	},
	{
		"id": "austerity",
		"title": "Reforma fiscal de ajuste",
		"axis": 0.5,
		"cost": 0,
		"requires_government": false,
		"summary": "Corta despesa e reduz a dívida com custo político.",
		"effects": {"debt": -1.4, "approval": -2.0, "economy": -0.2},
	},
	{
		"id": "welfare",
		"title": "Piso social emergencial",
		"axis": -0.5,
		"cost": 3200,
		"requires_government": false,
		"summary": "Transferência imediata para famílias de baixa renda.",
		"effects": {"approval": 3.0, "debt": 0.9, "unemployment": -0.2},
		"groups": {"Trabalhadores": 3.0, "Aposentados": 2.0},
	},
	{
		"id": "minimum_wage",
		"title": "Salário mínimo real",
		"axis": -0.6,
		"cost": 2200,
		"requires_government": true,
		"summary": "Reajuste acima da inflação, com impacto fiscal.",
		"effects": {"approval": 2.0, "debt": 0.6, "economy": 0.1},
		"groups": {"Trabalhadores": 4.0, "Empreendedores": -2.0},
	},
	{
		"id": "public_salary",
		"title": "Reajuste do funcionalismo",
		"axis": -0.4,
		"cost": 2600,
		"requires_government": true,
		"summary": "Aumento real para servidores; melhora a máquina e pressiona o caixa.",
		"effects": {"approval": 1.0, "debt": 0.7, "credibility": 1.0},
		"groups": {"Trabalhadores": 3.0},
	},
	{
		"id": "deregulation",
		"title": "Desregulamentação econômica",
		"axis": 0.7,
		"cost": 900,
		"requires_government": true,
		"summary": "Simplifica licenças e reduz o custo de operação.",
		"effects": {"economy": 0.4, "debt": -0.3, "approval": -1.0},
		"groups": {"Empreendedores": 4.0, "Trabalhadores": -2.0},
	},
	{
		"id": "transition",
		"title": "Transição energética",
		"axis": -0.3,
		"cost": 3600,
		"requires_government": true,
		"summary": "Investimento em matriz limpa e requalificação.",
		"effects": {"economy": 0.2, "debt": 0.5, "approval": 1.0, "unemployment": -0.1},
	},
	{
		"id": "pension",
		"title": "Reforma da previdência",
		"axis": 0.4,
		"cost": 1500,
		"kind": "constitutional",
		"requires_government": true,
		"summary": "Idade mínima maior e menos déficit; aposentados pagam o preço. Exige 3/5 da câmara.",
		"effects": {"debt": -1.0, "approval": -3.0, "economy": 0.1, "credibility": 2.0},
		"groups": {"Aposentados": -6.0, "Empreendedores": 2.0},
	},
	{
		"id": "labor",
		"title": "Reforma trabalhista",
		"axis": 0.55,
		"cost": 800,
		"requires_government": true,
		"summary": "Flexibiliza contratos: mais vagas, menos proteção.",
		"effects": {"economy": 0.3, "unemployment": -0.3, "approval": -2.0},
		"groups": {"Trabalhadores": -5.0, "Empreendedores": 4.0},
	},
	{
		"id": "education",
		"title": "Pacto nacional pela educação",
		"axis": -0.35,
		"cost": 2800,
		"requires_government": true,
		"summary": "Verba vinculada e piso docente; colhe resultado no longo prazo.",
		"effects": {"economy": 0.2, "approval": 1.0, "debt": 0.4},
		"groups": {"Jovens": 4.0},
	},
	{
		"id": "tax",
		"title": "Reforma tributária",
		"axis": 0.1,
		"cost": 1800,
		"kind": "constitutional",
		"requires_government": true,
		"summary": "Simplifica impostos e amplia a base. Exige 3/5 da câmara.",
		"effects": {"economy": 0.3, "debt": -0.5, "approval": -1.0, "credibility": 2.0},
		"groups": {"Empreendedores": 3.0, "Rurais": -2.0},
	},
	{
		"id": "transparency",
		"title": "Pacote de transparência",
		"axis": 0.0,
		"cost": 900,
		"requires_government": false,
		"summary": "Divulgação de contratos e controle externo; credibilidade contra redes de favorecimento.",
		"effects": {"credibility": 4.0, "approval": -1.0},
	},
	{
		"id": "electoral",
		"title": "Reforma eleitoral",
		"axis": 0.0,
		"cost": 600,
		"kind": "constitutional",
		"requires_government": false,
		"summary": "Regras de financiamento e transparência; rende credibilidade, racha a bancada. Exige 3/5 da câmara.",
		"effects": {"credibility": 4.0, "cohesion": -3.0},
	},
]

static func bill(bill_id: String) -> Dictionary:
	for item in BILLS:
		if str(item.get("id", "")) == bill_id:
			return item
	return {}

## Fração de apoio de uma bancada antes da disciplina de coalizão.
static func support_share(gap: float) -> float:
	if gap <= 0.55:
		return 1.0 - (gap / 0.55) * 0.25
	if gap <= 0.9:
		return 0.5 - ((gap - 0.55) / 0.35) * 0.35
	return 0.05

## Voto fracionário por bancada: cada partido divide as cadeiras entre sim,
## abstenção e não. O resultado é determinístico para a mesma entrada.
static func vote(bill: Dictionary, seat_map: Dictionary, axes: Dictionary, partners: Array, cohesion: float) -> Dictionary:
	var result := {"ayes": 0, "nayes": 0, "abstain": 0, "by_party": {}, "approved": false}
	if bill.is_empty():
		return result
	var bill_axis := float(bill.get("axis", 0.0))
	var discipline := clampf(float(cohesion) / 100.0, 0.0, 1.0)
	for key in seat_map.keys():
		var seats := int(seat_map[key])
		if seats <= 0:
			continue
		var party := str(key)
		var gap := absf(float(axes.get(party, 0.0)) - bill_axis)
		var ally := partners.has(party)
		var support := support_share(gap)
		if ally:
			support = clampf(support + 0.2 * discipline, 0.0, 1.0)
		var ayes := int(round(float(seats) * support))
		var rest := seats - ayes
		var abstain := int(round(float(rest) * clampf(0.5 * (1.0 - support), 0.0, 0.5)))
		var nayes := rest - abstain
		result.by_party[party] = {"sim": ayes, "abstencao": abstain, "nao": nayes}
		result.ayes = int(result.ayes) + ayes
		result.nayes = int(result.nayes) + nayes
		result.abstain = int(result.abstain) + abstain
	result["approved"] = int(result.ayes) > int(result.nayes)
	return result

## B4/B5: relação partidária, facção e escândalo alteram o voto já apurado.
## Não substitui o voto ideológico: desloca uma fração limitada das cadeiras.
static func adjust_votes(votes: Dictionary, seat_map: Dictionary, axes: Dictionary, bill: Dictionary, relations: Dictionary, player: String, faction_penalty: float, scandal_penalty: float, coalition_terms: Array = []) -> Dictionary:
	var result := votes.duplicate(true)
	var bill_axis := float(bill.get("axis", 0.0))
	var term_by_party := {}
	for term in coalition_terms:
		term_by_party[str(term.get("party", ""))] = term
	for key in seat_map.keys():
		var party := str(key)
		if not result.has(party) or not (result[party] is Dictionary):
			continue
		var row: Dictionary = result[party]
		var seats := int(seat_map[party])
		if seats <= 0:
			continue
		var ayes := int(row.get("sim", 0))
		var abstain := int(row.get("abstencao", 0))
		var nayes := int(row.get("nao", 0))
		var shift_away := 0
		if party != player:
			var pair := [player, party]
			pair.sort()
			var relation := float(relations.get("%s|%s" % [str(pair[0]), str(pair[1])], 0.0))
			var gap := absf(float(axes.get(party, 0.0)) - bill_axis)
			if relation < -20.0 and gap > 0.2:
				shift_away = int(round(float(ayes) * clampf((-relation - 20.0) / 160.0, 0.0, 0.18)))
			# B4: acordo de coalizão é programa, não apenas relação. O aliado
			# retira apoio quando o texto contraria a pauta assinada.
			if term_by_party.has(party):
				var term: Dictionary = term_by_party[party]
				var distance := absf(bill_axis - float(term.get("demand_axis", 0.0)))
				if distance > 0.55:
					var defection := clampf((distance - 0.55) * 0.45 + (100.0 - float(term.get("relation", 0.0))) / 1200.0, 0.0, 0.22)
					shift_away += int(round(float(ayes) * defection))
				elif distance <= 0.25:
					# Aliado satisfeito converte abstenção em voto favorável.
					var shift_in := mini(abstain, int(round(float(ayes) * 0.08)))
					row["sim"] = int(row.get("sim", 0)) + shift_in
					row["abstencao"] = abstain - shift_in
					ayes = int(row.sim)
					abstain = int(row.abstencao)
		else:
			shift_away = int(round(float(ayes) * clampf(faction_penalty, 0.0, 0.25)))
		if bool(bill.get("requires_government", false)) and scandal_penalty > 2.0:
			shift_away += int(round(float(ayes) * clampf(scandal_penalty / 40.0, 0.0, 0.10)))
		shift_away = mini(shift_away, ayes)
		if shift_away <= 0:
			result[party] = row
			continue
		row["sim"] = ayes - shift_away
		row["abstencao"] = abstain + int(round(float(shift_away) * 0.5))
		row["nao"] = nayes + shift_away - int(round(float(shift_away) * 0.5))
		result[party] = row
	return result

static func summary(outcome: Dictionary) -> String:
	return "%d a favor · %d contra · %d abstenções" % [
		int(outcome.get("ayes", 0)), int(outcome.get("nayes", 0)), int(outcome.get("abstain", 0))
	]

## Projeto constitucional exige 3/5 das cadeiras da câmara; os demais, mais
## votos a favor do que contra. Abstenção não conta como voto contra.
static func passes(bill: Dictionary, outcome: Dictionary, total_seats: int) -> bool:
	var ayes := int(outcome.get("ayes", 0))
	var ok := ayes > int(outcome.get("nayes", 0))
	if str(bill.get("kind", "ordinary")) == "constitutional":
		ok = ok and ayes * 5 >= total_seats * 3
	return ok
