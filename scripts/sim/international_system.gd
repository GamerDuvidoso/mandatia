extends RefCounted
## Fase D — relações internacionais determinísticas.
## Valores históricos vêm dos catálogos existentes; efeitos abaixo são simulados.
##
## Ciclo mensal, nesta ordem: deriva de perfis/posturas → tratados (ratificação,
## vigência e caducidade) → sanções (vigência e retaliação) → crises (agravamento
## por inação) → ofertas de parceiros (prazo e resposta) → organizações (adesão
## derivada por regra) → efeitos econômicos. Não há IA nem sorteio persistente:
## a mesma entrada produz sempre o mesmo mês.

const VERSION := 1
const Debt := preload("res://scripts/sim/debt_system.gd")
const POLICIES := [
	"diplomacia_economica", "integracao_regional", "autonomia_estrategica",
	"cooperacao_internacional", "nao_alinhamento", "cooperacao_seguranca",
	"parcerias_tecnologicas", "diplomacia_ambiental", "multilateralismo"
]
const POLICY_LABELS := {
	"diplomacia_economica": "Diplomacia econômica", "integracao_regional": "Integração regional",
	"autonomia_estrategica": "Autonomia estratégica", "cooperacao_internacional": "Cooperação internacional",
	"nao_alinhamento": "Não alinhamento", "cooperacao_seguranca": "Cooperação de segurança",
	"parcerias_tecnologicas": "Parcerias tecnológicas", "diplomacia_ambiental": "Diplomacia ambiental",
	"multilateralismo": "Multilateralismo"
}
const ORGANIZATIONS := {
	"ONU": {"rule": "resoluções exigem voto e compromisso; não gera dinheiro", "membership": "catalogada", "commitment": 0.04},
	"OMC": {"rule": "acesso comercial depende de conformidade e negociação", "membership": "não inferida", "commitment": 0.02},
	"BANCO_DESENVOLVIMENTO": {"rule": "financiamento exige projeto elegível e capacidade de pagamento", "membership": "disponível", "commitment": 0.03}
}
const BLOCS := {
	"integracao_sul": {"label": "Integração sul-americana", "condition": "mesma região e tratado regional", "status": "informal"},
	"cooperacao_atlantica": {"label": "Cooperação atlântica", "condition": "alinhamento estratégico e acordo de segurança", "status": "informal"},
	"coalizao_autonomia": {"label": "Coalizão de autonomia", "condition": "doutrina de autonomia ou não alinhamento", "status": "informal"}
}
const TREATY_KINDS := {
	"comércio": {"cost": 180.0, "duration": 36, "benefit": "maior acesso; dependência cresce"},
	"segurança": {"cost": 220.0, "duration": 24, "benefit": "consulta e cooperação de segurança"},
	"regional": {"cost": 200.0, "duration": 48, "benefit": "coordenação regional e acesso preferencial"}
}
const OFFER_KINDS := {
	"acordo_comercial": {"cost": 180.0, "expires_in": 4, "label": "Proposta de acordo comercial"},
	"consulta_seguranca": {"cost": 220.0, "expires_in": 3, "label": "Consulta de segurança"},
	"ajuda_humanitaria": {"cost": 200.0, "expires_in": 3, "label": "Pedido de ajuda humanitária"},
	"demanda": {"cost": 0.0, "expires_in": 3, "label": "Demanda diplomática"}
}
const OFFER_LIMIT := 4
const TREATY_PENDING_MONTHS := 6
const SANCTION_MONTHS := 12

static func _clamp(v: float, lo := 0.0, hi := 100.0) -> float:
	return clampf(v, lo, hi)

static func _key(a: String, b: String) -> String:
	return a + ":" + b

## Hash estável (FNV-1a reduzido) para variar o mês sem guardar RNG no save.
static func _hash01(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h = int((h ^ text.unicode_at(i)) * 16777619) % 2147483647
	return float(h % 10000) / 10000.0

static func _month_stamp(st: Dictionary) -> String:
	return "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 0))]

static func _push_event(intl: Dictionary, st: Dictionary, headline: String, cause: String, countries: Array) -> void:
	var events: Array = intl.get("events", [])
	for row in events:
		if str(row.get("headline", "")) == headline:
			return
	events.push_front({"month": int(st.date_month), "year": int(st.date_year), "headline": headline, "cause": cause, "countries": countries, "status": "em acompanhamento"})
	intl["events"] = events.slice(0, 12)

static func _catalog_profile(id: String, countries: Array, economy: Dictionary) -> Dictionary:
	var country: Dictionary = {}
	for row in countries:
		if str(row.get("id", "")) == id:
			country = row
			break
	var econ: Dictionary = economy.get(id, {}) if economy.get(id, {}) is Dictionary else {}
	var growth: float = float((econ.get("gdp_growth", {}) as Dictionary).get("simulation_value", 2.0)) if econ.get("gdp_growth", {}) is Dictionary else 2.0
	var inflation: float = float((econ.get("inflation", {}) as Dictionary).get("simulation_value", 4.5)) if econ.get("inflation", {}) is Dictionary else 4.5
	var unemployment: float = float((econ.get("unemployment", {}) as Dictionary).get("simulation_value", 7.0)) if econ.get("unemployment", {}) is Dictionary else 7.0
	var debt: float = float((econ.get("debt", {}) as Dictionary).get("simulation_value", 60.0)) if econ.get("debt", {}) is Dictionary else 60.0
	var gdp: float = float((econ.get("gdp", {}) as Dictionary).get("value", 0.0)) if econ.get("gdp", {}) is Dictionary else 0.0
	var population: float = float((econ.get("population", {}) as Dictionary).get("value", 0.0)) if econ.get("population", {}) is Dictionary else 0.0
	var party: String = str(country.get("head_of_state", {}).get("party", "governo nacional")) if country.get("head_of_state", {}) is Dictionary else "governo nacional"
	return {
		"id": id, "name": str(country.get("name", id)), "region": str(country.get("region", "não informado")),
		"government": party, "orientation": party, "stability": _clamp(62.0 - absf(growth) * 1.2 - maxf(0.0, inflation - 6.0) * 0.8),
		"gdp": gdp, "growth": growth, "inflation": inflation, "unemployment": unemployment,
		"debt": debt, "population": population, "data_as_of": str(country.get("data_as_of", "")),
		"data_status": "histórico/oficial quando disponível; evolução posterior simulada"
	}

static func _organization_member(org_id: String, intl: Dictionary, st: Dictionary) -> bool:
	if org_id == "ONU":
		return true
	if org_id == "OMC":
		for treaty in intl.get("treaties", []):
			if str(treaty.get("status", "")) == "active" and str(treaty.get("kind", "")) in ["comércio", "regional"]:
				return true
		return false
	if org_id == "BANCO_DESENVOLVIMENTO":
		return float(st.get("debt", 60.0)) <= 90.0
	return false

static func _organization_reason(org_id: String, member: bool) -> String:
	if member:
		return "membro"
	if org_id == "OMC":
		return "não membro: exige tratado comercial ou regional ativo"
	if org_id == "BANCO_DESENVOLVIMENTO":
		return "não membro: dívida acima de 90% do PIB compromete a capacidade de pagamento"
	return "não membro"

static func init_state(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	var player := str(st.get("country_id", "BR"))
	var player_region := "não informado"
	for row in countries:
		if str(row.get("id", "")) == player:
			player_region = str(row.get("region", "não informado"))
			break
	var profiles := {}
	for row in countries:
		var id := str(row.get("id", ""))
		if id != "" and id != player:
			profiles[id] = _catalog_profile(id, countries, economy)
	var relations := {}
	var trade := {}
	for id in profiles.keys():
		var p: Dictionary = profiles[id]
		var regional := 18.0 if str(p.get("region", "")) == "América do Sul" else 0.0
		relations[_key(player, str(id))] = {"cooperation": 42.0 + regional, "political_alignment": 38.0, "economic_partnership": 35.0 + regional, "trade_interdependence": 18.0 + regional * 0.4, "strategic_trust": 40.0, "security_cooperation": 25.0, "tension": 12.0, "recognized": true, "last_action": "relação inicial"}
		trade[_key(player, str(id))] = {"exports": 0.0, "imports": 0.0, "balance": 0.0, "dependency": 4.0 + regional * 0.2, "sector": "bens e serviços", "status": "potencial"}
	var organizations := {}
	for org_id in ORGANIZATIONS.keys():
		organizations[org_id] = {"name": org_id, "rule": str(ORGANIZATIONS[org_id].get("rule", "")), "membership": str(ORGANIZATIONS[org_id].get("membership", "")), "member": org_id == "ONU", "commitment": 0.0, "votes": [], "programs": []}
	var blocs := {}
	for bloc_id in BLOCS.keys():
		blocs[bloc_id] = {"id": bloc_id, "label": str(BLOCS[bloc_id].get("label", bloc_id)), "condition": str(BLOCS[bloc_id].get("condition", "")), "status": str(BLOCS[bloc_id].get("status", "informal")), "members": [], "commitments": [], "negotiating_power": 0.0}
	st["international_state"] = {"version": VERSION, "player_region": player_region, "policy": "diplomacia_economica", "policy_credibility": 50.0, "profiles": profiles, "relations": relations, "trade": trade, "treaties": [], "sanctions": [], "investments": [], "offers": [], "events": [], "crises": [], "organizations": organizations, "blocs": blocs}
	monthly(st, countries, economy)

static func ensure(st: Dictionary, countries: Array, economy: Dictionary) -> void:
	var intl: Variant = st.get("international_state", {})
	if not (intl is Dictionary) or (intl as Dictionary).get("version", 0) != VERSION or (intl as Dictionary).get("profiles", {}).is_empty():
		init_state(st, countries, economy)
		return
	if not (intl as Dictionary).has("events"): intl["events"] = []
	if not (intl as Dictionary).has("treaties"): intl["treaties"] = []
	if not (intl as Dictionary).has("sanctions"): intl["sanctions"] = []
	if not (intl as Dictionary).has("investments"): intl["investments"] = []
	if not (intl as Dictionary).has("offers"): intl["offers"] = []
	if not (intl as Dictionary).has("crises"): intl["crises"] = []
	if not (intl as Dictionary).has("organizations"): intl["organizations"] = {}
	if not (intl as Dictionary).has("blocs"): intl["blocs"] = {}
	if not (intl as Dictionary).has("player_region"):
		var region := "não informado"
		for row in countries:
			if str(row.get("id", "")) == str(st.get("country_id", "BR")):
				region = str(row.get("region", "não informado"))
				break
		intl["player_region"] = region
	for org_id in ORGANIZATIONS.keys():
		if not (intl.organizations as Dictionary).has(org_id):
			intl.organizations[org_id] = {"name": org_id, "rule": str(ORGANIZATIONS[org_id].get("rule", "")), "membership": str(ORGANIZATIONS[org_id].get("membership", "")), "member": org_id == "ONU", "commitment": 0.0, "votes": [], "programs": []}
	for bloc_id in BLOCS.keys():
		if not (intl.blocs as Dictionary).has(bloc_id):
			intl.blocs[bloc_id] = {"id": bloc_id, "label": str(BLOCS[bloc_id].get("label", bloc_id)), "condition": str(BLOCS[bloc_id].get("condition", "")), "status": str(BLOCS[bloc_id].get("status", "informal")), "members": [], "commitments": [], "negotiating_power": 0.0}
	# Saves anteriores ao ciclo não tinham prazo; o prazo é derivado da duração
	# declarada, não inventado por save.
	for i in (intl.get("treaties", []) as Array).size():
		var treaty: Dictionary = intl.treaties[i]
		if not treaty.has("expires_in"):
			treaty["expires_in"] = int(treaty.get("duration", int(TREATY_KINDS.get(str(treaty.get("kind", "")), {}).get("duration", 36))))
		if not treaty.has("months_pending"):
			treaty["months_pending"] = 0
		intl.treaties[i] = treaty
	for i in (intl.get("sanctions", []) as Array).size():
		var entry: Dictionary = intl.sanctions[i]
		if not entry.has("months_left"):
			entry["months_left"] = SANCTION_MONTHS
		intl.sanctions[i] = entry
	for i in (intl.get("crises", []) as Array).size():
		var crisis: Dictionary = intl.crises[i]
		if not crisis.has("idle"):
			crisis["idle"] = 0
		intl.crises[i] = crisis

static func _relation(st: Dictionary, id: String) -> Dictionary:
	var intl: Dictionary = st.get("international_state", {})
	var key := _key(str(st.get("country_id", "BR")), id)
	return intl.get("relations", {}).get(key, {}) if intl.get("relations", {}).get(key, {}) is Dictionary else {}

static func _set_relation(st: Dictionary, id: String, relation: Dictionary) -> void:
	var intl: Dictionary = st["international_state"]
	var relations: Dictionary = intl.get("relations", {})
	relations[_key(str(st.get("country_id", "BR")), id)] = relation
	intl["relations"] = relations

## Postura é leitura da relação, não uma variável independente: um país não fica
## hostil só porque o mês virou.
static func stance(rel: Dictionary) -> String:
	var tension := float(rel.get("tension", 0.0))
	var cooperation := float(rel.get("cooperation", 0.0))
	if tension >= 55.0: return "hostil"
	if tension >= 30.0: return "assertivo"
	if cooperation >= 55.0 and tension <= 20.0: return "cooperativo"
	# Parceria econômica forte também sustenta cooperação: sem isso, a fricção
	# mensal derrubaria a cooperação para sempre abaixo do limiar e nenhum
	# parceiro proporia acordo.
	if cooperation >= 50.0 and float(rel.get("economic_partnership", 0.0)) >= 50.0 and tension <= 25.0: return "cooperativo"
	return "pragmático"

static func _has_treaty(intl: Dictionary, id: String, kind: String, status := "active") -> bool:
	for treaty in intl.get("treaties", []):
		if str(treaty.get("country", "")) == id and str(treaty.get("kind", "")) == kind and str(treaty.get("status", "")) == status:
			return true
	return false

static func _pending_offers(intl: Dictionary) -> int:
	var count := 0
	for offer in intl.get("offers", []):
		if str(offer.get("status", "")) == "pending":
			count += 1
	return count

static func _make_offer(st: Dictionary, intl: Dictionary, id: String, kind: String, cause: String) -> void:
	if not OFFER_KINDS.has(kind): return
	if _row_exists_with_status(intl.get("offers", []), id, kind):
		return
	var offers: Array = intl.get("offers", [])
	offers.push_front({
		"country": id, "kind": kind, "label": str(OFFER_KINDS[kind].get("label", kind)),
		"status": "pending", "expires_in": int(OFFER_KINDS[kind].get("expires_in", 3)),
		"cost": float(OFFER_KINDS[kind].get("cost", 0.0)), "cause": cause,
		"month": _month_stamp(st)
	})
	intl["offers"] = offers.slice(0, 10)

static func _row_exists_with_status(rows: Array, id: String, kind: String) -> bool:
	for row in rows:
		if str(row.get("country", "")) == id and str(row.get("kind", "")) == kind and str(row.get("status", "")) == "pending":
			return true
	return false

## Avança um mês do sistema internacional. Devolve os efeitos aplicados ao
## jogador para que o chamador possa testá-los sem reabrir o estado.
static func monthly(st: Dictionary, countries: Array, economy: Dictionary) -> Dictionary:
	ensure(st, countries, economy)
	var intl: Dictionary = st["international_state"]
	var player := str(st.get("country_id", "BR"))
	var effects := {"growth": 0.0, "inflation": 0.0, "unemployment": 0.0, "approval": 0.0, "treasury": 0.0}
	var events: Array = intl.get("events", [])
	# 1. Perfis, posturas, relações e comércio.
	for id in (intl.get("profiles", {}) as Dictionary).keys():
		var profile: Dictionary = intl.profiles[id]
		profile["stability"] = _clamp(float(profile.get("stability", 60.0)) + (55.0 - float(profile.get("stability", 60.0))) * 0.015 + float(profile.get("growth", 2.0)) * 0.02)
		intl.profiles[id] = profile
		var rel := _relation(st, str(id))
		if rel.is_empty(): continue
		var treaty_bonus := 0.0
		for treaty in intl.treaties:
			if str(treaty.get("country", "")) == str(id) and str(treaty.get("status", "")) == "active": treaty_bonus += 0.15
		rel["cooperation"] = _clamp(float(rel.get("cooperation", 40.0)) + treaty_bonus - float(rel.get("tension", 10.0)) * 0.002)
		rel["strategic_trust"] = _clamp(float(rel.get("strategic_trust", 40.0)) + (float(rel.cooperation) - 50.0) * 0.006)
		_set_relation(st, str(id), rel)
		profile["stance"] = stance(rel)
		profile["cooperation"] = float(rel.get("cooperation", 0.0))
		profile["tension"] = float(rel.get("tension", 0.0))
		intl.profiles[id] = profile
		var trade_row: Dictionary = intl.trade.get(_key(player, str(id)), {})
		var base := maxf(1.0, float(st.get("gdp", 100.0)) * 0.02)
		var access := float(rel.get("economic_partnership", 35.0)) / 100.0
		trade_row["exports"] = maxf(0.0, float(trade_row.get("exports", base * access)) * 0.98 + base * access * 0.02)
		trade_row["imports"] = maxf(0.0, float(trade_row.get("imports", base * 0.8 * access)) * 0.98 + base * 0.8 * access * 0.02)
		trade_row["balance"] = float(trade_row.exports) - float(trade_row.imports)
		trade_row["dependency"] = _clamp(float(trade_row.get("dependency", 5.0)) + (float(rel.get("trade_interdependence", 20.0)) - 20.0) * 0.003, 0.0, 80.0)
		intl.trade[_key(player, str(id))] = trade_row
		if float(profile.get("stability", 60.0)) < 35.0 and float(trade_row.dependency) > 20.0:
			var headline := "%s enfrenta instabilidade; dependências comerciais elevam o risco externo." % str(profile.get("name", id))
			if events.is_empty() or str(events[0].get("headline", "")) != headline:
				events.push_front({"month": int(st.date_month), "year": int(st.date_year), "headline": headline, "cause": "estabilidade do parceiro abaixo de 35 e dependência acima de 20", "countries": [str(id)], "status": "em acompanhamento"})
			var crises: Array = intl.get("crises", [])
			if crises.is_empty() or str(crises[0].get("headline", "")) != headline:
				crises.push_front({"month": int(st.date_month), "year": int(st.date_year), "headline": headline, "cause": "instabilidade externa + dependência comercial", "country": str(id), "stage": 1, "stages": 3, "idle": 0, "status": "open", "options": ["negociar", "diversificar", "isolar"], "history": []})
				intl["crises"] = crises.slice(0, 6)
			effects.growth -= 0.04 * float(trade_row.dependency) / 20.0
			effects.inflation += 0.03 * float(trade_row.dependency) / 20.0
	intl["events"] = events
	# 2. Tratados: vigência conta; ratificação parada caduca.
	var treaties: Array = intl.get("treaties", [])
	for i in treaties.size():
		var treaty: Dictionary = treaties[i]
		var status := str(treaty.get("status", ""))
		var id := str(treaty.get("country", ""))
		if status == "active":
			treaty["expires_in"] = int(treaty.get("expires_in", 36)) - 1
			treaty["months_active"] = int(treaty.get("months_active", 0)) + 1
			if int(treaty.expires_in) <= 0:
				treaty["status"] = "expirado"
				treaty["expires_in"] = 0
				var rel := _relation(st, id)
				if not rel.is_empty():
					rel["cooperation"] = _clamp(float(rel.get("cooperation", 40.0)) - 3.0)
					rel["strategic_trust"] = _clamp(float(rel.get("strategic_trust", 40.0)) - 2.0)
					_set_relation(st, id, rel)
				_push_event(intl, st, "Tratado de %s com %s expirou; a cooperação recua." % [str(treaty.get("kind", "")), id], "prazo de vigência encerrado", [id])
		elif status == "pending_ratification":
			treaty["months_pending"] = int(treaty.get("months_pending", 0)) + 1
			if int(treaty.months_pending) >= TREATY_PENDING_MONTHS:
				treaty["status"] = "caducado"
				var rel := _relation(st, id)
				if not rel.is_empty():
					rel["strategic_trust"] = _clamp(float(rel.get("strategic_trust", 40.0)) - 2.0)
					_set_relation(st, id, rel)
				_push_event(intl, st, "Tratado de %s com %s caducou sem ratificação." % [str(treaty.get("kind", "")), id], "parlamento não ratificou em %d meses" % TREATY_PENDING_MONTHS, [id])
		treaties[i] = treaty
	intl["treaties"] = treaties
	# 3. Sanções: prazo finito, retaliação cobrada todo mês e tensão persistente.
	var sanctions: Array = intl.get("sanctions", [])
	for i in sanctions.size():
		var entry: Dictionary = sanctions[i]
		if str(entry.get("status", "")) != "implemented":
			continue
		entry["months_left"] = int(entry.get("months_left", SANCTION_MONTHS)) - 1
		effects.growth -= float(entry.get("growth_cost", 0.0))
		effects.inflation += float(entry.get("inflation_cost", 0.0))
		effects.approval -= float(entry.get("retaliation", 0.0))
		var rel := _relation(st, str(entry.get("country", "")))
		if not rel.is_empty():
			rel["tension"] = _clamp(float(rel.get("tension", 0.0)) + 0.5)
			_set_relation(st, str(entry.get("country", "")), rel)
		if int(entry.months_left) <= 0:
			entry["status"] = "expirado"
			entry["months_left"] = 0
			_push_event(intl, st, "Sanção contra %s expirou; o custo mensal termina." % str(entry.get("country", "")), "prazo de %d meses encerrado" % SANCTION_MONTHS, [str(entry.get("country", ""))])
		sanctions[i] = entry
	intl["sanctions"] = sanctions
	# 4. Crises: inação não congela o problema; a cada dois meses o estágio avança.
	var crises: Array = intl.get("crises", [])
	for i in crises.size():
		var crisis: Dictionary = crises[i]
		if str(crisis.get("status", "")) != "open":
			continue
		crisis["idle"] = int(crisis.get("idle", 0)) + 1
		if int(crisis.idle) % 2 == 0 and int(crisis.get("stage", 1)) < int(crisis.get("stages", 3)):
			crisis["stage"] = int(crisis.get("stage", 1)) + 1
			effects.growth -= 0.03
			effects.inflation += 0.02
			var rel := _relation(st, str(crisis.get("country", "")))
			if not rel.is_empty():
				rel["tension"] = _clamp(float(rel.get("tension", 0.0)) + 3.0)
				rel["cooperation"] = _clamp(float(rel.get("cooperation", 40.0)) - 2.0)
				_set_relation(st, str(crisis.get("country", "")), rel)
			_push_event(intl, st, "Crise com %s avançou por inação para o estágio %d." % [str(crisis.get("country", "")), int(crisis.stage)], "nenhuma resposta diplomática há %d meses" % int(crisis.idle), [str(crisis.get("country", ""))])
		crises[i] = crisis
	intl["crises"] = crises
	# 5. Ofertas de parceiros: prazo, expiração e novas propostas por postura.
	var offers: Array = intl.get("offers", [])
	for i in offers.size():
		var offer: Dictionary = offers[i]
		if str(offer.get("status", "")) != "pending":
			continue
		offer["expires_in"] = int(offer.get("expires_in", 3)) - 1
		if int(offer.expires_in) <= 0:
			offer["status"] = "expirada"
			offer["expires_in"] = 0
			var rel := _relation(st, str(offer.get("country", "")))
			if not rel.is_empty():
				rel["cooperation"] = _clamp(float(rel.get("cooperation", 40.0)) - 2.0)
				rel["strategic_trust"] = _clamp(float(rel.get("strategic_trust", 40.0)) - 2.0)
				_set_relation(st, str(offer.get("country", "")), rel)
			_push_event(intl, st, "%s arquivou a proposta de %s sem resposta." % [str(offer.get("country", "")), str(offer.get("label", ""))], "prazo de resposta vencido", [str(offer.get("country", ""))])
		offers[i] = offer
	intl["offers"] = offers
	if _pending_offers(intl) < OFFER_LIMIT:
		var stamp := _month_stamp(st)
		for id in (intl.get("profiles", {}) as Dictionary).keys():
			if _pending_offers(intl) >= OFFER_LIMIT:
				break
			var profile: Dictionary = intl.profiles[id]
			var rel := _relation(st, str(id))
			if rel.is_empty(): continue
			var current := stance(rel)
			var roll := _hash01(str(id) + "|" + stamp)
			if current == "cooperativo" and roll < 0.14 and not _has_treaty(intl, str(id), "comércio", "pending_ratification") and not _has_treaty(intl, str(id), "comércio", "active"):
				_make_offer(st, intl, str(id), "acordo_comercial", "postura cooperativa e cooperação acima de 55")
			elif current == "cooperativo" and roll < 0.08 and not _has_treaty(intl, str(id), "segurança", "active") and not _has_treaty(intl, str(id), "segurança", "pending_ratification"):
				_make_offer(st, intl, str(id), "consulta_seguranca", "postura cooperativa e cooperação de segurança baixa")
			elif current in ["assertivo", "hostil"] and roll < 0.12:
				_make_offer(st, intl, str(id), "demanda", "postura %s e tensão em %.0f" % [current, float(rel.get("tension", 0.0))])
			elif float(profile.get("stability", 60.0)) < 40.0 and float(rel.get("cooperation", 0.0)) >= 50.0 and roll < 0.15:
				_make_offer(st, intl, str(id), "ajuda_humanitaria", "estabilidade do parceiro abaixo de 40")
	# 6. Organizações: adesão derivada de regra, não declarada à mão.
	for org_id in (intl.get("organizations", {}) as Dictionary).keys():
		var org: Dictionary = intl.organizations[org_id]
		var member := _organization_member(str(org_id), intl, st)
		org["member"] = member
		org["membership"] = _organization_reason(str(org_id), member)
		intl.organizations[org_id] = org
	# 7. Efeitos no jogador (fecham o mês, uma única vez).
	st.economy = clampf(float(st.get("economy", 0.0)) + effects.growth, -6.0, 8.0)
	st.inflation = clampf(float(st.get("inflation", 4.5)) + effects.inflation, 1.5, 15.0)
	st.unemployment = clampf(float(st.get("unemployment", 7.0)) - effects.growth * 0.08, 3.5, 18.0)
	st.approval = _clamp(float(st.get("approval", 45.0)) + effects.approval - effects.inflation * 0.08)
	intl["events"] = (intl.get("events", []) as Array).slice(0, 12)
	st["international"] = summary(st)
	return effects

## Recalcula apenas o resumo exibido, sem simular outro mês. Usado depois de uma
## ação do jogador para não acumular deriva a cada clique.
static func refresh(st: Dictionary) -> void:
	st["international"] = summary(st)

static func set_policy(st: Dictionary, policy: String) -> Dictionary:
	if not POLICIES.has(policy): return {"ok": false, "reason": "Doutrina desconhecida"}
	var intl: Dictionary = st["international_state"]
	if str(intl.get("policy", "")) == policy: return {"ok": false, "reason": "Doutrina já ativa"}
	var cost := 250.0
	if float(st.get("funds", 0.0)) < cost: return {"ok": false, "reason": "Caixa insuficiente"}
	st.funds = float(st.funds) - cost
	intl["policy"] = policy
	intl["policy_credibility"] = _clamp(float(intl.get("policy_credibility", 50.0)) - 4.0)
	st.news.push_front("Política externa alterada para %s; a mudança custa credibilidade e M$ 250." % str(POLICY_LABELS.get(policy, policy)))
	return {"ok": true, "reason": "Política alterada"}

static func diplomatic_action(st: Dictionary, id: String, action: String) -> Dictionary:
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País não encontrado"}
	# Custo só existe para ação válida: ação desconhecida não pode drenar caixa.
	var cost := 0.0
	match action:
		"meeting": cost = 80.0
		"protest": cost = 40.0
		_: return {"ok": false, "reason": "Ação desconhecida"}
	if float(st.get("funds", 0.0)) < cost: return {"ok": false, "reason": "Caixa insuficiente"}
	st.funds = float(st.funds) - cost
	if action == "meeting":
		rel.cooperation = _clamp(float(rel.cooperation) + 6.0); rel.strategic_trust = _clamp(float(rel.strategic_trust) + 3.0); rel.tension = _clamp(float(rel.tension) - 2.0)
	else:
		rel.tension = _clamp(float(rel.tension) + 8.0); rel.cooperation = _clamp(float(rel.cooperation) - 2.0)
	rel.last_action = action
	rel.last_action_month = _month_stamp(st)
	_set_relation(st, id, rel)
	return {"ok": true, "reason": "Ação diplomática aplicada"}

## Cria um tratado negociado pelo jogador. Separado de `agreement` para que a
## aceitação de uma oferta use exatamente as mesmas regras.
static func _create_treaty(st: Dictionary, id: String, kind: String) -> Dictionary:
	var spec: Dictionary = TREATY_KINDS.get(kind, {})
	if spec.is_empty(): return {"ok": false, "reason": "Tipo de tratado desconhecido"}
	var intl: Dictionary = st["international_state"]
	if _has_treaty(intl, id, kind, "active") or _has_treaty(intl, id, kind, "pending_ratification"):
		return {"ok": false, "reason": "Tratado de %s já ativo ou em ratificação" % kind}
	var cost := float(spec.get("cost", 180.0))
	if float(st.get("funds", 0.0)) < cost: return {"ok": false, "reason": "Caixa insuficiente para negociar"}
	st.funds = float(st.funds) - cost
	var rel := _relation(st, id)
	if kind == "comércio":
		rel.economic_partnership = _clamp(float(rel.get("economic_partnership", 35.0)) + 12.0)
		rel.trade_interdependence = _clamp(float(rel.get("trade_interdependence", 20.0)) + 10.0)
		rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) + 4.0)
	elif kind == "segurança":
		rel.security_cooperation = _clamp(float(rel.get("security_cooperation", 25.0)) + 14.0)
		rel.strategic_trust = _clamp(float(rel.get("strategic_trust", 40.0)) + 8.0)
		rel.tension = _clamp(float(rel.get("tension", 0.0)) - 4.0)
	else:
		rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) + 10.0)
		rel.economic_partnership = _clamp(float(rel.get("economic_partnership", 35.0)) + 6.0)
		rel.trade_interdependence = _clamp(float(rel.get("trade_interdependence", 20.0)) + 6.0)
	_set_relation(st, id, rel)
	intl.treaties.push_front({"country": id, "kind": kind, "objective": "acesso recíproco", "status": "pending_ratification", "ratification": "câmara legislativa pendente", "duration": int(spec.get("duration", 36)), "expires_in": int(spec.get("duration", 36)), "months_pending": 0, "months_active": 0, "cost": cost, "benefit": str(spec.get("benefit", ""))})
	return {"ok": true, "reason": "Tratado de %s negociado; ratificação parlamentar pendente" % kind}

static func agreement(st: Dictionary, id: String, kind := "comércio") -> Dictionary:
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País não encontrado"}
	if float(rel.get("tension", 0.0)) > 55.0: return {"ok": false, "reason": "Tensão diplomática alta"}
	if kind == "segurança" and float(rel.get("cooperation", 0.0)) < 50.0: return {"ok": false, "reason": "Cooperação insuficiente para acordo de segurança"}
	if kind == "regional" and str(_profile_region(st, id)) != str(st.get("international_state", {}).get("player_region", "")): return {"ok": false, "reason": "Acordo regional exige parceiro da mesma região"}
	return _create_treaty(st, id, kind)

static func trade_agreement(st: Dictionary, id: String) -> Dictionary:
	return agreement(st, id, "comércio")

static func _profile_region(st: Dictionary, id: String) -> String:
	var profile: Dictionary = st.get("international_state", {}).get("profiles", {}).get(id, {})
	return str(profile.get("region", "não informado"))

static func ratify_treaty(st: Dictionary, treaty_index: int) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var treaties: Array = intl.get("treaties", [])
	if treaty_index < 0 or treaty_index >= treaties.size(): return {"ok": false, "reason": "Tratado inexistente"}
	var treaty: Dictionary = treaties[treaty_index]
	if str(treaty.get("status", "")) != "pending_ratification": return {"ok": false, "reason": "Tratado não aguarda ratificação"}
	if not bool(st.get("government", false)): return {"ok": false, "reason": "O Executivo precisa estar no governo"}
	var seats := int(st.get("coalition_seats", 0))
	if seats <= 0:
		seats = int(st.get("lower_house_seats", 0))
	var majority := int(st.get("majority", 1))
	if seats < majority: return {"ok": false, "reason": "Sem maioria parlamentar para ratificar"}
	treaty["status"] = "active"
	treaty["ratification"] = "ratificado pela câmara"
	treaty["months_active"] = 0
	treaties[treaty_index] = treaty
	intl["treaties"] = treaties
	return {"ok": true, "reason": "Tratado ratificado pelo parlamento"}

## Resposta a uma oferta de parceiro. Aceitar compromete caixa e/ou soberania;
## recusar custa confiança. A oferta sempre deixa de estar pendente.
static func respond_offer(st: Dictionary, offer_index: int, accept: bool) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var offers: Array = intl.get("offers", [])
	if offer_index < 0 or offer_index >= offers.size(): return {"ok": false, "reason": "Oferta inexistente"}
	var offer: Dictionary = offers[offer_index]
	if str(offer.get("status", "")) != "pending": return {"ok": false, "reason": "Oferta já encerrada"}
	if int(offer.get("expires_in", 0)) <= 0:
		offer["status"] = "expirada"
		offers[offer_index] = offer
		intl["offers"] = offers
		return {"ok": false, "reason": "Oferta expirada"}
	var id := str(offer.get("country", ""))
	var kind := str(offer.get("kind", ""))
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País não encontrado"}
	var reason := ""
	if accept:
		if kind == "demanda":
			rel.tension = _clamp(float(rel.get("tension", 0.0)) - 12.0)
			rel.economic_partnership = _clamp(float(rel.get("economic_partnership", 35.0)) - 5.0)
			st.approval = _clamp(float(st.get("approval", 45.0)) - 0.6)
			reason = "Demanda aceita: tensão cai, mas há concessão econômica"
		elif kind == "acordo_comercial" or kind == "consulta_seguranca":
			var treaty_kind := "comércio" if kind == "acordo_comercial" else "segurança"
			var created := _create_treaty(st, id, treaty_kind)
			if not bool(created.get("ok", false)): return created
			reason = "Oferta aceita; " + str(created.get("reason", ""))
		elif kind == "ajuda_humanitaria":
			if float(st.get("funds", 0.0)) < float(offer.get("cost", 200.0)): return {"ok": false, "reason": "Caixa insuficiente para a ajuda"}
			st.funds = float(st.funds) - float(offer.get("cost", 200.0))
			var target: Dictionary = intl.profiles.get(id, {})
			target["stability"] = _clamp(float(target.get("stability", 60.0)) + 4.0)
			intl.profiles[id] = target
			rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) + 5.0)
			rel.strategic_trust = _clamp(float(rel.get("strategic_trust", 40.0)) + 4.0)
			st.credibility = minf(100.0, float(st.get("credibility", 0.0)) + 1.0)
			reason = "Ajuda enviada: estabilidade do parceiro melhora"
		else:
			return {"ok": false, "reason": "Oferta desconhecida"}
	else:
		if kind == "demanda":
			rel.tension = _clamp(float(rel.get("tension", 0.0)) + 10.0)
			rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) - 6.0)
			st.approval = _clamp(float(st.get("approval", 45.0)) + 0.4)
			reason = "Demanda recusada: firmeza doméstica, tensão maior"
		else:
			rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) - 4.0)
			rel.strategic_trust = _clamp(float(rel.get("strategic_trust", 40.0)) - 3.0)
			reason = "Oferta recusada: confiança recua"
	rel.last_action = "offer_" + ("accepted" if accept else "rejected")
	rel.last_action_month = _month_stamp(st)
	_set_relation(st, id, rel)
	offer["status"] = "aceita" if accept else "recusada"
	offer["decided_month"] = _month_stamp(st)
	offers[offer_index] = offer
	intl["offers"] = offers
	return {"ok": true, "reason": reason}

static func organization_vote(st: Dictionary, organization: String, resolution: String, support := true) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var org: Dictionary = intl.get("organizations", {}).get(organization, {})
	if org.is_empty(): return {"ok": false, "reason": "Organização desconhecida"}
	if not bool(org.get("member", false)): return {"ok": false, "reason": "País não é membro: " + str(org.get("membership", ""))}
	var vote := {"month": _month_stamp(st), "resolution": resolution, "vote": "a favor" if support else "contra", "binding": false}
	org.votes.push_front(vote)
	org.commitment = clampf(float(org.get("commitment", 0.0)) + (0.03 if support else -0.01), 0.0, 1.0)
	if support: st.credibility = minf(100.0, float(st.credibility) + 0.4)
	else: st.credibility = maxf(0.0, float(st.credibility) - 0.2)
	intl.organizations[organization] = org
	return {"ok": true, "reason": "Voto registrado; resolução não altera leis domésticas automaticamente"}

static func foreign_loan(st: Dictionary, id: String, pct_gdp: float) -> Dictionary:
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País financiador inexistente"}
	if float(rel.get("cooperation", 0.0)) < 40.0: return {"ok": false, "reason": "Parceiro sem confiança suficiente para financiar"}
	if float(rel.get("tension", 0.0)) > 45.0: return {"ok": false, "reason": "Tensão alta impede financiamento"}
	if pct_gdp <= 0.0 or pct_gdp > 5.0: return {"ok": false, "reason": "Empréstimo fora do limite de 0 a 5% do PIB"}
	var issued: Dictionary = Debt.issue_bond(st, pct_gdp)
	if not bool(issued.get("ok", false)): return issued
	var intl: Dictionary = st["international_state"]
	var amount := float(issued.get("amount", 0.0))
	intl.investments.push_front({"country": id, "kind": "empréstimo soberano", "amount": amount, "ownership": "público", "government_revenue": 0.0, "repayment": amount, "interest": float(issued.get("rate", 0.0)), "dependency": 8.0, "status": "executado"})
	return {"ok": true, "reason": "Empréstimo externo emitido; entrou no livro de dívida e exige juros", "amount": amount}

static func _bloc_condition(st: Dictionary, bloc_id: String) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var policy := str(intl.get("policy", ""))
	if bloc_id == "integracao_sul":
		if str(intl.get("player_region", "")) != "América do Sul":
			return {"ok": false, "reason": "Adesão exige país sul-americano"}
		for id in (intl.get("profiles", {}) as Dictionary).keys():
			var profile: Dictionary = intl.profiles[id]
			if str(profile.get("region", "")) == "América do Sul" and (_has_treaty(intl, str(id), "regional", "active") or _has_treaty(intl, str(id), "comércio", "active")):
				return {"ok": true, "reason": "condição cumprida"}
		return {"ok": false, "reason": "Adesão exige tratado comercial ou regional ativo com um vizinho"}
	if bloc_id == "cooperacao_atlantica":
		if not (policy in ["cooperacao_seguranca", "autonomia_estrategica"]):
			return {"ok": false, "reason": "Adesão exige doutrina de segurança ou autonomia"}
		for id in (intl.get("profiles", {}) as Dictionary).keys():
			if _has_treaty(intl, str(id), "segurança", "active"):
				return {"ok": true, "reason": "condição cumprida"}
		return {"ok": false, "reason": "Adesão exige acordo de segurança ativo"}
	if bloc_id == "coalizao_autonomia":
		if not (policy in ["autonomia_estrategica", "nao_alinhamento"]):
			return {"ok": false, "reason": "Adesão exige doutrina de autonomia ou não alinhamento"}
		return {"ok": true, "reason": "condição cumprida"}
	return {"ok": false, "reason": "Bloco sem condição definida"}

static func join_bloc(st: Dictionary, bloc_id: String) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var bloc: Dictionary = intl.get("blocs", {}).get(bloc_id, {})
	if bloc.is_empty(): return {"ok": false, "reason": "Bloco desconhecido"}
	var player := str(st.get("country_id", "BR"))
	if (bloc.get("members", []) as Array).has(player): return {"ok": false, "reason": "País já é membro do bloco"}
	var condition := _bloc_condition(st, bloc_id)
	if not bool(condition.get("ok", false)): return condition
	if float(st.get("funds", 0.0)) < 120.0: return {"ok": false, "reason": "Caixa insuficiente para adesão"}
	st.funds = float(st.funds) - 120.0
	bloc.members.append(player)
	bloc.status = "formal"
	bloc.commitments = [str(bloc.get("condition", "compromissos de coordenação")), "consulta diplomática prévia"]
	bloc.negotiating_power = float(bloc.members.size()) * 4.0
	intl.blocs[bloc_id] = bloc
	return {"ok": true, "reason": "Adesão formal registrada; coordenação passa a limitar escolhas"}

static func crisis_response(st: Dictionary, crisis_index: int, response: String) -> Dictionary:
	var intl: Dictionary = st["international_state"]
	var crises: Array = intl.get("crises", [])
	if crisis_index < 0 or crisis_index >= crises.size(): return {"ok": false, "reason": "Crise inexistente"}
	var crisis: Dictionary = crises[crisis_index]
	if str(crisis.get("status", "")) == "resolved": return {"ok": false, "reason": "Crise já resolvida"}
	var stage := int(crisis.get("stage", 1))
	if response == "negociar":
		st.funds = maxf(0.0, float(st.funds) - 150.0); st.approval = minf(100.0, float(st.approval) + 0.5); crisis["stage"] = stage + 1
	elif response == "diversificar":
		st.funds = maxf(0.0, float(st.funds) - 300.0); st.inflation = minf(15.0, float(st.inflation) + 0.1); crisis["stage"] = stage + 1
	elif response == "isolar":
		st.credibility = maxf(0.0, float(st.credibility) - 1.0); crisis["stage"] = stage + 1
	else: return {"ok": false, "reason": "Resposta desconhecida"}
	crisis["idle"] = 0
	var resolved := false
	if int(crisis.get("stage", 1)) >= int(crisis.get("stages", 3)):
		crisis["status"] = "resolved"
		resolved = true
		# Resolver a crise fecha o ciclo: a relação colhe o resultado da resposta.
		var id := str(crisis.get("country", ""))
		var rel := _relation(st, id)
		if not rel.is_empty():
			var tension_cut := 12.0 if response == "negociar" else 6.0
			rel.tension = _clamp(float(rel.get("tension", 0.0)) - tension_cut)
			rel.cooperation = _clamp(float(rel.get("cooperation", 40.0)) + (5.0 if response == "negociar" else 2.0))
			rel.strategic_trust = _clamp(float(rel.get("strategic_trust", 40.0)) + (3.0 if response == "negociar" else 1.0))
			_set_relation(st, id, rel)
		_push_event(intl, st, "Crise com %s encerrada após %s." % [id, response], "resposta concluiu os %d estágios" % int(crisis.get("stages", 3)), [id])
	crisis["last_response"] = response
	crisis["history"] = crisis.get("history", [])
	(crisis["history"] as Array).append({"stage": stage, "response": response})
	crises[crisis_index] = crisis
	intl["crises"] = crises
	return {"ok": true, "reason": ("Crise resolvida; relação recomposta" if resolved else "Resposta aplicada; crise avançou para estágio %d" % int(crisis.get("stage", 1)))}

static func sanction(st: Dictionary, id: String) -> Dictionary:
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País não encontrado"}
	if float(rel.get("tension", 0.0)) < 25.0: return {"ok": false, "reason": "Não há tensão suficiente para sanção"}
	var intl: Dictionary = st["international_state"]
	for entry in intl.get("sanctions", []):
		if str(entry.get("country", "")) == id and str(entry.get("status", "")) == "implemented":
			return {"ok": false, "reason": "Sanção já em vigor contra este país"}
	intl.sanctions.push_front({"country": id, "status": "implemented", "months_left": SANCTION_MONTHS, "growth_cost": 0.08, "inflation_cost": 0.05, "retaliation": 0.04, "humanitarian_risk": 0.12})
	rel.tension = _clamp(float(rel.tension) + 18.0); rel.cooperation = _clamp(float(rel.cooperation) - 12.0)
	_set_relation(st, id, rel)
	st.inflation = clampf(float(st.inflation) + 0.05, 1.5, 15.0)
	return {"ok": true, "reason": "Sanção implementada; custos e retaliação registrados"}

static func investment(st: Dictionary, id: String, kind := "investimento direto") -> Dictionary:
	var rel := _relation(st, id)
	if rel.is_empty(): return {"ok": false, "reason": "País não encontrado"}
	if float(rel.get("cooperation", 0.0)) < 35.0: return {"ok": false, "reason": "Cooperação insuficiente para investimento"}
	if float(rel.get("tension", 0.0)) > 45.0: return {"ok": false, "reason": "Tensão alta afasta investimento"}
	var intl: Dictionary = st["international_state"]
	var amount := 500.0
	intl.investments.push_front({"country": id, "kind": kind, "amount": amount, "ownership": "privado", "government_revenue": 0.0, "repayment": 0.0, "dependency": 6.0, "status": "proposta"})
	rel.economic_partnership = _clamp(float(rel.economic_partnership) + 5.0)
	_set_relation(st, id, rel)
	st.economy = clampf(float(st.economy) + 0.06, -6.0, 8.0)
	return {"ok": true, "reason": "Investimento registrado fora da receita pública"}

static func summary(st: Dictionary) -> Dictionary:
	var intl: Dictionary = st.get("international_state", {})
	var relations: Dictionary = intl.get("relations", {})
	var ranked: Array = []
	for key in relations.keys():
		var rel: Dictionary = relations[key]
		ranked.append({"country": str(key).split(":")[-1], "cooperation": float(rel.get("cooperation", 0.0)), "tension": float(rel.get("tension", 0.0)), "trust": float(rel.get("strategic_trust", 0.0)), "stance": stance(rel)})
	ranked.sort_custom(func(a, b): return float(a.cooperation) > float(b.cooperation))
	var pending := 0
	for offer in intl.get("offers", []):
		if str(offer.get("status", "")) == "pending": pending += 1
	return {"policy": str(intl.get("policy", "")), "policy_label": str(POLICY_LABELS.get(str(intl.get("policy", "")), "")), "policy_credibility": float(intl.get("policy_credibility", 50.0)), "partners": ranked.slice(0, 5), "events": (intl.get("events", []) as Array).slice(0, 5), "treaties": (intl.get("treaties", []) as Array).slice(0, 8), "sanctions": (intl.get("sanctions", []) as Array).slice(0, 8), "investments": (intl.get("investments", []) as Array).slice(0, 8), "offers": (intl.get("offers", []) as Array).slice(0, 6), "pending_offers": pending, "trade": intl.get("trade", {}).duplicate(true)}

static func profile(st: Dictionary, id: String) -> Dictionary:
	var intl: Dictionary = st.get("international_state", {})
	var p: Dictionary = intl.get("profiles", {}).get(id, {})
	p = p.duplicate(true)
	var rel := _relation(st, id)
	p["relation"] = rel.duplicate(true)
	p["stance"] = stance(rel)
	p["trade"] = intl.get("trade", {}).get(_key(str(st.get("country_id", "BR")), id), {}).duplicate(true)
	return p
