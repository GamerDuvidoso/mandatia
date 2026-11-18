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
	},
	{
		"id": "minimum_wage",
		"title": "Salário mínimo real",
		"axis": -0.6,
		"cost": 2200,
		"requires_government": true,
		"summary": "Reajuste acima da inflação, com impacto fiscal.",
		"effects": {"approval": 2.0, "debt": 0.6, "economy": 0.1},
	},
	{
		"id": "deregulation",
		"title": "Desregulamentação econômica",
		"axis": 0.7,
		"cost": 900,
		"requires_government": true,
		"summary": "Simplifica licenças e reduz o custo de operação.",
		"effects": {"economy": 0.4, "debt": -0.3, "approval": -1.0},
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

static func summary(outcome: Dictionary) -> String:
	return "%d a favor · %d contra · %d abstenções" % [
		int(outcome.get("ayes", 0)), int(outcome.get("nayes", 0)), int(outcome.get("abstain", 0))
	]
