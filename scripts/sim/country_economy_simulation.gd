extends RefCounted
## E1 — evolução macroeconômica por país.
##
## Premissas documentadas:
## - O ponto de partida é sempre o `simulation_value` do catálogo WDI; valores
##   oficiais originais continuam apenas no catálogo (`value`), nunca são
##   sobrescritos.
## - Crescimento, inflação e desemprego fazem reversão parcial para a âncora
##   estrutural do país (média histórica do catálogo), não para uma média global.
## - A prioridade do governo entra como impulso fiscal/monetário pequeno; o
##   déficit eleva a dívida e a dívida alta reduz o espaço de crescimento.
## - O choque mensal é determinístico (hash do país + mês), entre -5% e +5% do
##   impulso, para variar trajetórias sem RNG guardado no save.
## - Todos os valores têm limites; não há crescimento, inflação ou desemprego
##   infinitos nem população/estoque negativo.

const POLICY_IMPULSE := {
	"estabilizacao": {"growth": -0.10, "inflation": -0.22, "unemployment": 0.05, "debt": -0.06},
	"empregos": {"growth": 0.16, "inflation": 0.10, "unemployment": -0.14, "debt": 0.12},
	"investimento": {"growth": 0.11, "inflation": 0.03, "unemployment": -0.06, "debt": 0.10},
	"austeridade": {"growth": -0.12, "inflation": -0.06, "unemployment": 0.08, "debt": -0.20},
	"negociacao": {"growth": 0.01, "inflation": 0.0, "unemployment": 0.0, "debt": 0.02},
}

static func base_from(row: Dictionary) -> Dictionary:
	var growth := 2.0
	var inflation := 4.5
	var unemployment := 7.0
	var debt := 60.0
	if row.get("gdp_growth") is Dictionary:
		growth = float((row.gdp_growth as Dictionary).get("simulation_value", growth))
	if row.get("inflation") is Dictionary:
		inflation = float((row.inflation as Dictionary).get("simulation_value", inflation))
	if row.get("unemployment") is Dictionary:
		unemployment = float((row.unemployment as Dictionary).get("simulation_value", unemployment))
	if row.get("debt") is Dictionary:
		debt = float((row.debt as Dictionary).get("simulation_value", debt))
	return {
		"potential_growth": clampf(growth, -3.0, 6.0),
		"inflation_anchor": clampf(inflation, 1.5, 12.0),
		"natural_unemployment": clampf(unemployment, 3.0, 16.0),
		"initial_debt": clampf(debt, 5.0, 180.0),
	}

static func monthly(profile: Dictionary, base: Dictionary, policy: String, shock: float) -> Dictionary:
	var potential := float(base.get("potential_growth", 2.0))
	var natural := float(base.get("natural_unemployment", 7.0))
	var anchor := float(base.get("inflation_anchor", 4.5))
	var growth := float(profile.get("growth", potential))
	var inflation := float(profile.get("inflation", anchor))
	var unemployment := float(profile.get("unemployment", natural))
	var debt := float(profile.get("debt", 60.0))
	var impulse: Dictionary = POLICY_IMPULSE.get(policy, POLICY_IMPULSE["investimento"])
	# Atividade: reversão à âncora + impulso da prioridade + choque externo.
	growth += (potential - growth) * 0.12 + float(impulse.get("growth", 0.0)) + shock * 0.6
	# Preços: âncora + hiato de atividade + impulso.
	inflation += (anchor - inflation) * 0.10 + float(impulse.get("inflation", 0.0)) + (growth - potential) * 0.06 + shock * 0.25
	# Desemprego: lei de Okun simplificada com reversão à taxa natural.
	unemployment += -(growth - potential) * 0.06 + (natural - unemployment) * 0.05 + float(impulse.get("unemployment", 0.0))
	# Dívida: déficit estrutural + gasto da prioridade - crescimento que arrecada.
	var deficit := 0.10 + maxf(0.0, potential - growth) * 0.12 + float(impulse.get("debt", 0.0))
	debt += deficit - maxf(0.0, growth) * 0.02
	growth = clampf(growth, -8.0, 10.0)
	inflation = clampf(inflation, 0.5, 40.0)
	unemployment = clampf(unemployment, 2.0, 30.0)
	debt = clampf(debt, 0.0, 200.0)
	profile["growth"] = growth
	profile["inflation"] = inflation
	profile["unemployment"] = unemployment
	profile["debt"] = debt
	profile["gdp"] = maxf(1.0, float(profile.get("gdp", 1.0)) * (1.0 + growth / 1200.0))
	return {"growth": growth, "inflation": inflation, "unemployment": unemployment, "debt": debt, "policy": policy}
