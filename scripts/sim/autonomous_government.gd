extends RefCounted
## E1 — governo autônomo.
##
## O governo de cada país escolhe uma prioridade a partir das condições reais
## (inflação, desemprego, crescimento, dívida, aprovação, coesão e ideologia).
## A prioridade alimenta `country_economy_simulation`, que aplica o impulso
## fiscal; portanto a decisão tem consequência macro, não é só um texto.
##
## Aprovação e estabilidade também reagem ao resultado econômico. A troca de
## prioridade gera um evento histórico com gatilho explícito.

const WorldHistory := preload("res://scripts/sim/world_history.gd")

const POLICY_LABELS := {
	"estabilizacao": "estabilização de preços",
	"empregos": "emprego e atividade",
	"investimento": "investimento público",
	"austeridade": "ajuste fiscal",
	"negociacao": "negociação parlamentar",
}
const POLICY_APPROVAL := {
	"estabilizacao": -0.12,
	"empregos": 0.16,
	"investimento": 0.05,
	"austeridade": -0.22,
	"negociacao": 0.08,
}

## Fase 3: normaliza a decisão da camada de IA num override aceito por
## `monthly`. Só devolve valores; não escreve estado.
static func priority_override(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	if not POLICY_LABELS.has(action):
		return {}
	var intensity := clampf(float(args.get("intensity", 1.0)), 0.0, 1.0)
	return {"action": action, "intensity": intensity}

static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func choose_priority(wc: Dictionary, profile: Dictionary, base: Dictionary) -> String:
	var inflation := float(profile.get("inflation", 4.5))
	var unemployment := float(profile.get("unemployment", 7.0))
	var growth := float(profile.get("growth", 2.0))
	var debt := float(profile.get("debt", 60.0))
	var approval := float(wc.get("approval", 50.0))
	var cohesion := float(wc.get("coalition_cohesion", 60.0))
	var axis := float(wc.get("government_axis", 0.0))
	var natural := float(base.get("natural_unemployment", 7.0))
	if inflation >= 8.0:
		return "estabilizacao"
	if unemployment >= natural + 2.0:
		return "empregos"
	if debt >= 95.0:
		return "austeridade"
	if growth <= 0.3:
		return "investimento" if debt < 85.0 else "estabilizacao"
	if approval <= 34.0 or cohesion <= 32.0:
		return "negociacao"
	if axis <= -0.3:
		return "empregos" if unemployment > natural + 0.5 else "investimento"
	if axis >= 0.35:
		return "austeridade" if debt >= 70.0 else "investimento"
	return "investimento"

static func monthly(world: Dictionary, wc: Dictionary, profile: Dictionary, base: Dictionary, year: int, month: int, override: Dictionary = {}) -> Dictionary:
	var previous := str(wc.get("last_priority", ""))
	var priority := choose_priority(wc, profile, base)
	var intensity := 1.0
	var forced := priority_override(override)
	if not forced.is_empty():
		# Decisão da camada de IA: veio validada, então o ator decidiu e a
		# histerese não se aplica. A intensidade escala o efeito de aprovação.
		priority = str(forced.get("action", priority))
		intensity = float(forced.get("intensity", 1.0))
		wc["priority_streak"] = 0
	else:
		# Histerese: uma prioridade nova precisa se sustentar por dois meses. Sem
		# isso, condições próximas do limiar fazem o governo alternar de agenda todo
		# mês e geram fatos repetidos sem mudança real de situação.
		if previous != "" and priority != previous:
			var streak := int(wc.get("priority_streak", 0)) + 1
			if streak < 2:
				priority = previous
				wc["priority_streak"] = streak
			else:
				wc["priority_streak"] = 0
		else:
			wc["priority_streak"] = 0
	var potential := float(base.get("potential_growth", 2.0))
	var natural := float(base.get("natural_unemployment", 7.0))
	var growth := float(profile.get("growth", potential))
	var inflation := float(profile.get("inflation", 4.5))
	var unemployment := float(profile.get("unemployment", natural))
	var economy_score := (growth - potential) * 0.20 - maxf(0.0, inflation - 4.5) * 0.10 - maxf(0.0, unemployment - natural) * 0.05
	var approval := float(wc.get("approval", 50.0))
	# O desgaste de incumbência empurra a aprovação para baixo devagar; a
	# economia e a política precisam compensar para um governo se sustentar.
	approval = clampf(approval + economy_score + float(POLICY_APPROVAL.get(priority, 0.0)) * intensity - 0.03 + (50.0 - approval) * 0.015, 3.0, 92.0)
	var cohesion := float(wc.get("coalition_cohesion", 60.0))
	var stability := clampf(float(wc.get("stability", 60.0)) + (approval - float(wc.get("stability", 60.0))) * 0.06 + (cohesion - 60.0) * 0.01, 5.0, 98.0)
	wc["approval"] = approval
	wc["stability"] = stability
	wc["policy_priority"] = priority
	wc["last_priority"] = priority
	profile["approval"] = approval
	profile["stability"] = stability
	profile["policy_priority"] = priority
	var changed := priority != previous and previous != ""
	if changed:
		WorldHistory.bump(world, "priority_changes")
		var name := str(wc.get("name", wc.get("id", "")))
		var trigger := "inflação %.1f%%, desemprego %.1f%%, crescimento %.1f%%, dívida %.0f%% do PIB, aprovação %.0f%%" % [inflation, unemployment, growth, float(profile.get("debt", 60.0)), approval]
		WorldHistory.push(world, {
			"year": year, "month": month, "country": str(wc.get("id", "")), "country_name": name,
			"category": "politica",
			"description": "Governo de %s passa a priorizar %s." % [name, str(POLICY_LABELS.get(priority, priority))],
			"headline": "%s: governo muda prioridade para %s (%d)" % [name, str(POLICY_LABELS.get(priority, priority)), year],
			"trigger": trigger,
			"consequences": ["impulso fiscal/monetário de %s aplicado à economia" % priority],
			"actors": [str(wc.get("government_party", ""))],
			"status": "confirmado", "news": _hash01(str(wc.get("id", "")) + "|" + str(year) + "|" + str(month)) < 0.55,
		}, 12)
	return {"priority": priority, "changed": changed, "approval": approval, "stability": stability}
