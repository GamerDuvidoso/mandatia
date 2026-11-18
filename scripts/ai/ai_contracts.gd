extends RefCounted
## Contratos JSON estritos da camada de IA local (Ollama, huihui_ai/qwen2.5-abliterate:3b).
##
## Script puro: não abre rede, não escreve arquivo e não toca em nós.
## Assim a validação de cada contrato pode ser testada em headless.
##
## Contratos:
##  A. legislativo   {"votes": {PARTY_ID: {"sim": 75, "abstencao": 15, "nao": 10}}}
##  B. eleitoral     {"parties": {PARTY_ID: {"delta_pp": 2.1, "reason": "..."}}}
##  C. eventos       {"headline": "...", "effects": {"approval": 3, "popularity": -2,
##                     "funds": 400, "debt": 0.5}}
##  D. internacional {"reactions": {PARTY_ID: {"support_change": -5,
##                     "cohesion_change": 2, "reason": "..."}},
##                     "international": {"event": "...", "impact": "..."}}
##
## A IA nunca define absolutos: dinheiro, dívida, PIB, inflação, desemprego,
## contagem de votos e conversão de cadeiras continuam no motor.

const Legislature := preload("res://scripts/sim/legislature.gd")

const LEGISLATIVE := "legislative"
const ELECTORAL := "electoral"
const EVENTS := "events"
const INTERNATIONAL := "international"
const CONTRACTS := [LEGISLATIVE, ELECTORAL, EVENTS, INTERNATIONAL]

const VOTE_TOLERANCE := 0.5
## Bancadas por pedido de voto. Com muitas bancadas numa resposta só o modelo
## de 3B corta a lista no meio; blocos menores voltam completos.
const LEGISLATIVE_CHUNK := 4
const ELECTORAL_MAX_DELTA := 3.0
const EFFECT_LIMITS := {"approval": 6.0, "popularity": 4.0, "funds": 800.0, "debt": 1.0}
const REACTION_LIMIT := 10.0
const MAX_HEADLINE := 160

const SCHEMA_BY_CONTRACT := {
	LEGISLATIVE: "{\"votes\": {\"PARTIDO\": [75, 15, 10]}}",
	ELECTORAL: "{\"parties\": {\"PARTIDO\": {\"delta_pp\": 2.1, \"reason\": \"motivo curto\"}}}",
	EVENTS: "{\"headline\": \"manchete\", \"effects\": {\"approval\": 3, \"popularity\": -2, \"funds\": 400, \"debt\": 0.5}}",
	INTERNATIONAL: "{\"reactions\": {\"PARTIDO\": {\"support_change\": -5, \"cohesion_change\": 2, \"reason\": \"motivo\"}}, \"international\": {\"event\": \"evento\", \"impact\": \"impacto\"}}",
}

## Regras curtas de propósito: com prompt longo o modelo de 3B entra em
## repetição e o Ollama aborta com "token repeat limit reached".
const RULES := {
	LEGISLATIVE: "Para cada bancada, [sim, abstencao, nao] em porcentagem somando 100.",
	ELECTORAL: "delta_pp entre -3 e 3 por partido.",
	EVENTS: "Manchete até 160 caracteres; approval ±6, popularity ±4, funds ±800, debt ±1.",
	INTERNATIONAL: "Inclua reactions e international; support_change e cohesion_change entre -10 e 10.",
}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _finite(value: Variant, fallback := 0.0) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var number := float(value)
		if is_finite(number):
			return number
	return fallback

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT

## Chave de cache: type|month|year|country|entities_hash|v1|model
static func cache_key(contract: String, meta: Dictionary, entity_ids: Array) -> String:
	var sorted := Array(entity_ids)
	sorted.sort()
	var joined := ""
	for item in sorted:
		joined += str(item) + ","
	return "%s|%d|%d|%s|%s|v1|%s" % [
		contract,
		int(meta.get("month", 0)),
		int(meta.get("year", 0)),
		str(meta.get("country", "")),
		str(joined.hash()),
		str(meta.get("model", "huihui_ai/qwen2.5-abliterate:3b")),
	]

## Prompt curto: com instruções longas o modelo de 3B entra em repetição e o
## Ollama aborta a geração. Cada linha aqui é necessária e nada mais.
static func prompt(contract: String, ctx: Dictionary, examples: Array) -> String:
	# O modelo copia o placeholder literal do schema: trocar "PARTIDO" por um
	# ID real evita respostas com chave inventada.
	var schema := str(SCHEMA_BY_CONTRACT.get(contract, "{}"))
	var allowed: Array = ctx.get("ids_permitidos", []) if ctx.get("ids_permitidos") is Array else []
	if contract == LEGISLATIVE and not allowed.is_empty():
		# O modelo de 3B só devolve todas as bancadas quando o formato já as
		# enumera; por isso o voto vai em blocos pequenos, um schema por bloco.
		var parts := PackedStringArray()
		for item in allowed:
			parts.append("\"%s\": [70, 20, 10]" % str(item))
		schema = "{\"votes\": {%s}}" % ", ".join(parts)
	elif not allowed.is_empty():
		schema = schema.replace("PARTIDO", str(allowed[0]))
	# No legislativo o schema já enumera as bancadas; um exemplo extra com
	# outra estrutura de arrays fazia o modelo repetir até o Ollama abortar.
	var example_text := ""
	if contract != LEGISLATIVE:
		for item in examples:
			if item is Dictionary and str(item.get("contract", contract)) == contract:
				example_text = "Exemplo: %s\n" % str(item.get("completion", ""))
				break
	var context_parts := PackedStringArray()
	for key in ctx.keys():
		if key == "entities" or key == "meta" or key == "ids_permitidos":
			continue
		var value: Variant = ctx[key]
		if value is Array:
			context_parts.append("%s: %s" % [str(key), "; ".join(PackedStringArray(value))])
		else:
			context_parts.append("%s: %s" % [str(key), str(value)])
	var ids_line := ""
	if not allowed.is_empty():
		ids_line = "IDs (use todos, sem inventar): %s\n" % ", ".join(PackedStringArray(allowed))
	return "Analista político do jogo Mandatia. Responda apenas JSON, sem markdown, em português do Brasil.\nFormato: %s\nRegra: %s\n%sContexto: %s\n%s" % [
		schema,
		str(RULES.get(contract, "")),
		ids_line,
		" | ".join(context_parts),
		example_text,
	]

# ---------------------------------------------------------------- legislativo

## O modelo às vezes erra uma letra na sigla ("CIDANHIA" para CIDADANIA).
## Só normaliza quando a sigla não existe e há um único candidato parecido.
static func _resolve_party(key: String, known: Array) -> String:
	var raw := key.strip_edges()
	if raw == "":
		return raw
	var upper := raw.to_upper()
	for item in known:
		if str(item).to_upper() == upper:
			return str(item)
	# Sigla cortada ("L" para LLA) só vale quando é prefixo de uma única sigla.
	var prefix_hits: Array = []
	for item in known:
		if str(item).to_upper().begins_with(upper):
			prefix_hits.append(str(item))
	if prefix_hits.size() == 1:
		return str(prefix_hits[0])
	# Sigla com letra sobrando ("PJS" para PJ): a sigla real é prefixo do texto.
	var longer_hits: Array = []
	for item in known:
		if upper.begins_with(str(item).to_upper()) and str(item).length() >= 2:
			longer_hits.append(str(item))
	if longer_hits.size() == 1:
		return str(longer_hits[0])
	var best := ""
	var best_distance := 99
	var tie := false
	for item in known:
		var candidate := str(item)
		if candidate.length() < 4 or raw.length() < 4:
			continue
		var distance := _edit_distance(upper, candidate.to_upper())
		if distance < best_distance:
			best_distance = distance
			best = candidate
			tie = false
		elif distance == best_distance:
			tie = true
	if best != "" and best_distance <= 2 and not tie:
		return best
	return raw

static func _edit_distance(a: String, b: String) -> int:
	var previous := range(b.length() + 1)
	for i in range(1, a.length() + 1):
		var current := [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			current.append(mini(mini(int(current[j - 1]) + 1, int(previous[j]) + 1), int(previous[j - 1]) + cost))
		previous = current
	return int(previous[b.length()])

## Valida percentuais por bancada: IDs existentes, valores 0-100, soma 100.
## Bancada ausente não invalida o bloco: volta em "missing" para o motor
## completar (ou para o cliente pedir uma correção antes de aceitar).
static func validate_legislative(parsed: Variant, seat_map: Dictionary) -> Dictionary:
	if not (parsed is Dictionary):
		return _error("resposta não é um objeto JSON")
	var votes: Variant = (parsed as Dictionary).get("votes", null)
	if not (votes is Dictionary):
		return _error("campo votes ausente")
	var active: Array = []
	for key in seat_map.keys():
		if int(seat_map[key]) > 0:
			active.append(str(key))
	if active.is_empty():
		return _error("sem bancadas para votar")
	var clean := {}
	for key in (votes as Dictionary).keys():
		var party := _resolve_party(str(key), active)
		if not seat_map.has(party):
			return _error("partido inexistente: " + str(key))
		var entry: Variant = (votes as Dictionary)[key]
		var sim: Variant = null
		var abstain: Variant = null
		var nay: Variant = null
		if entry is Array:
			# Formato compacto pedido ao modelo: [sim, abstencao, nao].
			var triple: Array = entry
			if triple.size() != 3:
				return _error("voto de %s deve ter [sim, abstencao, nao]" % party)
			sim = triple[0]
			abstain = triple[1]
			nay = triple[2]
		elif entry is Dictionary:
			sim = (entry as Dictionary).get("sim", null)
			abstain = (entry as Dictionary).get("abstencao", null)
			nay = (entry as Dictionary).get("nao", null)
		else:
			return _error("voto de %s não é lista nem objeto" % party)
		if not (_is_number(sim) and _is_number(abstain) and _is_number(nay)):
			return _error("percentuais de %s não são numéricos" % party)
		var total := float(sim) + float(abstain) + float(nay)
		if absf(total - 100.0) > VOTE_TOLERANCE:
			return _error("percentuais de %s somam %.2f" % [party, total])
		if float(sim) < 0.0 or float(abstain) < 0.0 or float(nay) < 0.0 or float(sim) > 100.0 or float(abstain) > 100.0 or float(nay) > 100.0:
			return _error("percentual fora de 0-100 em " + party)
		clean[party] = {"sim": float(sim), "abstencao": float(abstain), "nao": float(nay)}
	var missing: Array = []
	for party in active:
		if not clean.has(str(party)):
			missing.append(str(party))
	return {"ok": true, "votes": clean, "missing": missing}

## Converte percentuais em cadeiras, preservando o total exato da bancada.
static func votes_to_outcome(votes: Dictionary, seat_map: Dictionary) -> Dictionary:
	var outcome := {"ayes": 0, "nayes": 0, "abstain": 0, "by_party": {}, "approved": false}
	for key in seat_map.keys():
		var party := str(key)
		var seats := int(seat_map[key])
		if seats <= 0:
			continue
		var entry: Dictionary = votes.get(party, {"sim": 0.0, "abstencao": 0.0, "nao": 100.0})
		var ayes := int(round(float(seats) * float(entry.get("sim", 0.0)) / 100.0))
		var abstain := int(round(float(seats) * float(entry.get("abstencao", 0.0)) / 100.0))
		var nayes := int(round(float(seats) * float(entry.get("nao", 0.0)) / 100.0))
		var drift := seats - (ayes + abstain + nayes)
		if drift != 0:
			var biggest := "sim"
			if abstain >= ayes and abstain >= nayes:
				biggest = "abstencao"
			elif nayes >= ayes and nayes >= abstain:
				biggest = "nao"
			match biggest:
				"sim": ayes = maxi(0, ayes + drift)
				"abstencao": abstain = maxi(0, abstain + drift)
				_: nayes = maxi(0, nayes + drift)
		ayes = clampi(ayes, 0, seats)
		abstain = clampi(abstain, 0, seats - ayes)
		nayes = seats - ayes - abstain
		outcome.by_party[party] = {"sim": ayes, "abstencao": abstain, "nao": nayes}
		outcome.ayes = int(outcome.ayes) + ayes
		outcome.abstain = int(outcome.abstain) + abstain
		outcome.nayes = int(outcome.nayes) + nayes
	outcome["approved"] = int(outcome.ayes) > int(outcome.nayes)
	return outcome

## Fallback determinístico: mesma matemática do motor, em formato de contrato.
static func fallback_legislative(bill: Dictionary, seat_map: Dictionary, axes: Dictionary, partners: Array, cohesion: float) -> Dictionary:
	var outcome := Legislature.vote(bill, seat_map, axes, partners, cohesion)
	var votes := {}
	var by_party: Dictionary = outcome.get("by_party", {})
	for key in by_party.keys():
		var party := str(key)
		var split: Dictionary = by_party[key]
		var seats := int(split.get("sim", 0)) + int(split.get("abstencao", 0)) + int(split.get("nao", 0))
		if seats <= 0:
			continue
		var sim: float = round(float(split.get("sim", 0)) / float(seats) * 100.0)
		var abstain: float = round(float(split.get("abstencao", 0)) / float(seats) * 100.0)
		var nay: float = 100.0 - sim - abstain
		if nay < 0.0:
			abstain = maxf(0.0, abstain + nay)
			nay = 0.0
		votes[party] = {"sim": sim, "abstencao": abstain, "nao": nay}
	return {"ok": true, "votes": votes, "source": "fallback"}

# ------------------------------------------------------------------ eleitoral

## Aplica deltas (clamp ±3 p.p.) e devolve pesquisa que ainda soma 100,
## mantendo cada partido dentro de [origem-3, origem+3].
static func normalize_electoral(parsed: Variant, base_shares: Dictionary) -> Dictionary:
	var parties: Dictionary = {}
	if parsed is Dictionary and (parsed as Dictionary).get("parties", null) is Dictionary:
		parties = (parsed as Dictionary).get("parties", {})
	var raw := {}
	var reasons := {}
	for key in parties.keys():
		var party := str(key)
		if not base_shares.has(party):
			return _error("partido inexistente na pesquisa: " + party)
		var entry: Variant = parties[key]
		if entry is Dictionary:
			var delta: Variant = (entry as Dictionary).get("delta_pp", 0.0)
			if not _is_number(delta):
				return _error("delta_pp de %s não é numérico" % party)
			raw[party] = clampf(_finite(delta), -ELECTORAL_MAX_DELTA, ELECTORAL_MAX_DELTA)
			reasons[party] = str((entry as Dictionary).get("reason", ""))
	var target := 0.0
	for value in base_shares.values():
		target += float(value)
	if target <= 0.0:
		return _error("pesquisa base vazia")
	var current := {}
	for key in base_shares.keys():
		var base := float(base_shares[key])
		current[str(key)] = base + float(raw.get(str(key), 0.0))
	current = rebalance(base_shares, current, target)
	var total := 0.0
	for value in current.values():
		total += float(value)
	if absf(total - target) > 0.5:
		return _error("não foi possível normalizar a pesquisa para 100%")
	for key in current.keys():
		var base := float(base_shares[key])
		if float(current[key]) < maxf(0.0, base - ELECTORAL_MAX_DELTA) - 0.01 or float(current[key]) > base + ELECTORAL_MAX_DELTA + 0.01:
			return _error("partido %s fora do limite de ±3 p.p." % str(key))
	return {"ok": true, "shares": current, "deltas": raw, "reasons": reasons}

## Redistribui o resíduo proporcionalmente à folga de cada partido, sem sair
## do intervalo permitido. Determinístico, então pode ser testado.
static func rebalance(base_shares: Dictionary, current: Dictionary, target: float) -> Dictionary:
	var result := {}
	var floors := {}
	var ceilings := {}
	for key in base_shares.keys():
		var party := str(key)
		var base := float(base_shares[key])
		floors[party] = maxf(0.0, base - ELECTORAL_MAX_DELTA)
		ceilings[party] = base + ELECTORAL_MAX_DELTA
		result[party] = clampf(float(current.get(party, base)), floors[party], ceilings[party])
	for _step in range(400):
		var total := 0.0
		for party in result.keys():
			total += float(result[party])
		var residual := target - total
		if absf(residual) < 0.0005:
			break
		var capacity := 0.0
		for party in result.keys():
			capacity += (ceilings[party] - float(result[party])) if residual > 0.0 else (float(result[party]) - floors[party])
		if capacity <= 0.0005:
			break
		for party in result.keys():
			var room: float = (float(ceilings[party]) - float(result[party])) if residual > 0.0 else (float(result[party]) - float(floors[party]))
			if room <= 0.0:
				continue
			result[party] = clampf(float(result[party]) + residual * room / capacity, floors[party], ceilings[party])
	return result

static func fallback_electoral(base_shares: Dictionary) -> Dictionary:
	var copy := {}
	for key in base_shares.keys():
		copy[str(key)] = float(base_shares[key])
	return {"ok": true, "shares": copy, "deltas": {}, "reasons": {}, "source": "fallback"}

# -------------------------------------------------------------------- eventos

## Efeitos nunca são absolutos: clamp fixo (Q37).
static func clamp_effects(raw: Dictionary) -> Dictionary:
	var effects := {}
	for key in EFFECT_LIMITS.keys():
		var value := _finite(raw.get(key, 0.0))
		effects[key] = clampf(value, -float(EFFECT_LIMITS[key]), float(EFFECT_LIMITS[key]))
	return effects

static func validate_event(parsed: Variant) -> Dictionary:
	if not (parsed is Dictionary):
		return _error("resposta não é um objeto JSON")
	var headline := str((parsed as Dictionary).get("headline", "")).strip_edges()
	if headline == "":
		return _error("manchete ausente")
	if headline.length() > MAX_HEADLINE:
		return _error("manchete longa demais")
	var raw_effects: Variant = (parsed as Dictionary).get("effects", null)
	if not (raw_effects is Dictionary):
		return _error("campo effects ausente")
	for key in (raw_effects as Dictionary).keys():
		if not EFFECT_LIMITS.has(str(key)):
			return _error("efeito desconhecido: " + str(key))
		if not _is_number((raw_effects as Dictionary)[key]):
			return _error("efeito não numérico: " + str(key))
	var effects := clamp_effects(raw_effects)
	var magnitude := 0.0
	for value in effects.values():
		magnitude += absf(float(value))
	if magnitude <= 0.0:
		return _error("evento sem efeito")
	return {"ok": true, "headline": headline, "effects": effects}

static func fallback_event() -> Dictionary:
	return {"ok": true, "headline": "", "effects": {"approval": 0.0, "popularity": 0.0, "funds": 0.0, "debt": 0.0}, "source": "fallback"}

# -------------------------------------------------------------- internacional

static func validate_international(parsed: Variant, party_ids: Array) -> Dictionary:
	if not (parsed is Dictionary):
		return _error("resposta não é um objeto JSON")
	var reactions_raw: Variant = (parsed as Dictionary).get("reactions", null)
	if not (reactions_raw is Dictionary):
		return _error("campo reactions ausente")
	var known := {}
	for item in party_ids:
		known[str(item)] = true
	var reactions := {}
	for key in (reactions_raw as Dictionary).keys():
		# Mesma tolerância do plenário: sigla truncada ou com uma letra errada
		# volta para o ID real quando não há ambiguidade.
		var party := _resolve_party(str(key), party_ids)
		if not known.has(party):
			return _error("partido inexistente: " + str(key))
		var entry: Variant = (reactions_raw as Dictionary)[key]
		if not (entry is Dictionary):
			return _error("reação de %s não é objeto" % party)
		var support: Variant = (entry as Dictionary).get("support_change", 0.0)
		var cohesion: Variant = (entry as Dictionary).get("cohesion_change", 0.0)
		if not (_is_number(support) and _is_number(cohesion)):
			return _error("reação de %s não é numérica" % party)
		reactions[party] = {
			"support_change": clampf(_finite(support), -REACTION_LIMIT, REACTION_LIMIT),
			"cohesion_change": clampf(_finite(cohesion), -REACTION_LIMIT, REACTION_LIMIT),
			"reason": str((entry as Dictionary).get("reason", "")),
		}
	var international_raw: Variant = (parsed as Dictionary).get("international", null)
	if not (international_raw is Dictionary):
		return _error("campo international ausente")
	var event := str((international_raw as Dictionary).get("event", "")).strip_edges()
	var impact := str((international_raw as Dictionary).get("impact", "")).strip_edges()
	if event == "" or impact == "":
		return _error("evento internacional incompleto")
	return {"ok": true, "reactions": reactions, "international": {"event": event, "impact": impact}}

static func fallback_international() -> Dictionary:
	return {
		"ok": true,
		"reactions": {},
		"international": {"event": "Sem sinal externo relevante neste ciclo.", "impact": "Nenhum efeito sobre a coalizão."},
		"source": "fallback",
	}
