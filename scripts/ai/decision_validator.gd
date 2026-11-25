extends RefCounted
## Fase 1 — validador de decisões.
##
## Recebe o JSON cru do modelo e devolve uma decisão normalizada, com os valores
## fora de faixa recortados e registrados em `clamped`. Enum inválido, chave
## desconhecida, ID inexistente e tipo errado viram erro específico para nova
## tentativa (nunca viram estado).
##
## Os quatro contratos antigos delegam para `ai_contracts.gd`; a normalização
## aqui só padroniza o envelope de resposta.

const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const Catalog := preload("res://scripts/ai/decision_catalog.gd")

const LEGACY := ["legislative", "electoral", "events", "international"]

const KIND_NUMBER := "number"
const KIND_BOOL := "bool"
const KIND_STRING := "string"
const KIND_ENUM := "enum"
const KIND_ID := "id"
const KIND_DICT := "dict"
const KIND_ARRAY := "array"

const MAX_ID_LENGTH := 48
const MAX_REASON_LENGTH := 200
const MAX_TEXT_LENGTH := 480
const MAX_HEADLINE_LENGTH := 160

const GROUP_NAMES := ["Jovens", "Trabalhadores", "Empreendedores", "Aposentados", "Rurais"]

## Especificação das chaves por contrato novo (seção 12 do prompt).
const SPECS := {
	"gov_priority": {
		"required": {"action": KIND_ENUM, "intensity": KIND_NUMBER},
		"optional": {"reason": KIND_STRING},
		"enums": {"action": ["estabilizacao", "empregos", "investimento", "austeridade", "negociacao"]},
		"ranges": {"intensity": [0.0, 1.0]},
	},
	"executive_action": {
		"required": {"action": KIND_ENUM},
		"optional": {"target_id": KIND_ID, "stance": KIND_ENUM, "reason": KIND_STRING},
		"enums": {
			"action": ["sancionar", "vetar", "decretar", "nomear", "demitir", "convocar_coalizao", "discursar", "negociar_oposicao"],
			"stance": ["firme", "moderado", "conciliador"],
		},
		"ranges": {},
	},
	"party_leadership": {
		"required": {"change_leader": KIND_BOOL, "stance": KIND_ENUM},
		"optional": {"reason": KIND_STRING},
		"enums": {"stance": ["mais_moderado", "mais_combativo", "manter"]},
		"ranges": {},
	},
	"legislative_agenda": {
		"required": {"agenda_id": KIND_ID},
		"optional": {"rebels": KIND_ARRAY, "reason": KIND_STRING},
		"enums": {},
		"ranges": {},
	},
	"chamber_leadership": {
		"required": {"agenda_id": KIND_ID},
		"optional": {"obstruct": KIND_ARRAY, "open_inquiry": KIND_BOOL, "reason": KIND_STRING},
		"enums": {},
		"ranges": {},
	},
	"court_ruling": {
		"required": {"case_id": KIND_ID, "ruling": KIND_ENUM},
		"optional": {"vote_split": KIND_ARRAY, "reason": KIND_STRING},
		"enums": {"ruling": ["procedente", "improcedente", "suspender", "arquivar", "avancar_investigacao"]},
		"ranges": {},
	},
	"market_mood": {
		"required": {"sentiment": KIND_NUMBER, "risk_premium_bp": KIND_NUMBER, "fx_pressure_pct": KIND_NUMBER, "capital_flow": KIND_ENUM},
		"optional": {"business": KIND_DICT, "reason": KIND_STRING},
		"enums": {"capital_flow": ["entrada", "saida", "neutro"]},
		"ranges": {"sentiment": [-1.0, 1.0], "risk_premium_bp": [0.0, 400.0], "fx_pressure_pct": [-10.0, 10.0]},
	},
	"central_bank": {
		"required": {"rate_move_bp": KIND_NUMBER, "stance": KIND_ENUM},
		"optional": {"statement": KIND_STRING, "reason": KIND_STRING},
		"enums": {"stance": ["hawkish", "neutro", "dovish"]},
		"ranges": {"rate_move_bp": [-200.0, 200.0]},
	},
	"public_mood": {
		"required": {"mood": KIND_NUMBER, "mobilization": KIND_ENUM},
		"optional": {"groups": KIND_DICT, "trust_institutions": KIND_NUMBER, "reason": KIND_STRING},
		"enums": {"mobilization": ["nenhuma", "protesto_pequeno", "protesto_medio", "protesto_grande", "greve"]},
		"ranges": {"mood": [-1.0, 1.0], "trust_institutions": [-5.0, 5.0]},
	},
	"media_coverage": {
		"required": {"frame": KIND_ENUM},
		"optional": {"bias": KIND_NUMBER, "focus_id": KIND_ID, "reason": KIND_STRING},
		"enums": {"frame": ["crise_economica", "escandalo", "entrega_governo", "seguranca", "eleicao", "rotina"]},
		"ranges": {"bias": [-1.0, 1.0]},
	},
	"global_event": {
		"required": {"shock": KIND_ENUM, "severity": KIND_NUMBER, "duration_months": KIND_NUMBER},
		"optional": {"reason": KIND_STRING},
		"enums": {"shock": ["recessao", "financeira", "divida", "cambio", "commodities", "energia"]},
		"ranges": {"severity": [0.0, 1.0], "duration_months": [1.0, 36.0]},
	},
	"diplomacy_action": {
		"required": {"actions": KIND_ARRAY},
		"optional": {"reason": KIND_STRING},
		"enums": {},
		"ranges": {},
	},
	"organization_action": {
		"required": {"organization": KIND_ID, "action": KIND_ENUM},
		"optional": {"target_country": KIND_ID, "reason": KIND_STRING},
		"enums": {"action": ["votar", "condicionar_emprestimo", "sancionar_coletivamente", "suspender", "admitir"]},
		"ranges": {},
	},
	"conflict_action": {
		"required": {"conflict_id": KIND_ID, "action": KIND_ENUM},
		"optional": {"reason": KIND_STRING},
		"enums": {"action": ["manter", "escalar", "desescalar", "negociar_cessar_fogo", "aceitar_paz", "pedir_ajuda_humanitaria"]},
		"ranges": {},
	},
	"scandal_seed": {
		"required": {"seed": KIND_BOOL, "type_id": KIND_ID, "target_role": KIND_ID},
		"optional": {"coverage": KIND_ENUM, "reason": KIND_STRING},
		"enums": {"coverage": ["baixa", "media", "alta"]},
		"ranges": {},
	},
	"group_demand": {
		"required": {"group_id": KIND_ID, "stance": KIND_ENUM},
		"optional": {"demand_id": KIND_ID, "escalate": KIND_BOOL, "reason": KIND_STRING},
		"enums": {"stance": ["negociar", "manter", "escalar", "recuar"]},
		"ranges": {},
	},
	"coalition_response": {
		"required": {"accept": KIND_BOOL},
		"optional": {"price": KIND_DICT, "reason": KIND_STRING},
		"enums": {},
		"ranges": {},
	},
	"news_text": {
		"required": {"headline": KIND_STRING, "body": KIND_STRING, "tone": KIND_ENUM},
		"optional": {},
		"enums": {"tone": ["neutro", "critico", "favoravel", "alarmante"]},
		"ranges": {},
	},
	"rival_campaign": {
		"required": {"rival_id": KIND_ID, "action": KIND_ENUM},
		"optional": {"target": KIND_ID, "intensity": KIND_NUMBER, "reason": KIND_STRING},
		"enums": {"action": ["ataque_programa", "ataque_pessoal", "alianca", "recuo", "mobilizacao"]},
		"ranges": {"intensity": [0.0, 1.0]},
	},
	"foreign_election_swing": {
		"required": {"parties": KIND_DICT},
		"optional": {"reason": KIND_STRING},
		"enums": {},
		"ranges": {},
	},
	"armed_forces_stance": {
		"required": {"stance": KIND_ENUM},
		"optional": {"reason": KIND_STRING},
		"enums": {"stance": ["legalista", "cauteloso", "politizado", "intervencionista"]},
		"ranges": {},
	},
}

const EVENT_EFFECT_LIMITS := {
	"approval": [-6.0, 6.0],
	"popularity": [-4.0, 4.0],
	"funds": [-2000.0, 800.0],
	"debt": [-1.0, 1.0],
	"inflation": [-0.5, 0.5],
	"economy": [-0.5, 0.5],
	"unemployment": [-0.5, 0.5],
	"credibility": [-5.0, 5.0],
	"cohesion": [-4.0, 4.0],
}

const EVENT_GROUPS_LIMIT := 6.0

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT

static func _finite(value: Variant) -> float:
	if _is_number(value):
		var number := float(value)
		if is_finite(number):
			return number
	return NAN

static func _result(ok: bool, contract: String) -> Dictionary:
	return {
		"ok": ok,
		"contract": contract,
		"decision": {},
		"clamped": [],
		"errors": [] if ok else [""],
	}

## Ponto de entrada. `ctx` traz os dados que a validação precisa
## (`seat_map`, `base_shares`, `party_ids`) e o `data` do cliente.
static func validate(contract: String, parsed: Variant, ctx: Dictionary = {}) -> Dictionary:
	if LEGACY.has(contract):
		return validate_legacy(contract, parsed, ctx)
	if contract == "event_v2":
		return validate_event_v2(parsed)
	if SPECS.has(contract):
		return _validate_spec(contract, parsed)
	return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": ["contrato desconhecido: " + contract]}

## Os quatro contratos antigos mantêm exatamente a validação de ai_contracts.gd.
static func validate_legacy(contract: String, parsed: Variant, ctx: Dictionary) -> Dictionary:
	var raw := {}
	match contract:
		"legislative":
			raw = Contracts.validate_legislative(parsed, ctx.get("seat_map", {}))
		"electoral":
			raw = Contracts.normalize_electoral(parsed, ctx.get("base_shares", {}))
		"events":
			raw = Contracts.validate_event(parsed)
		"international":
			raw = Contracts.validate_international(parsed, ctx.get("party_ids", []))
	var ok := bool(raw.get("ok", false))
	var out := {
		"ok": ok,
		"contract": contract,
		"decision": {},
		"clamped": [],
		"errors": [] if ok else [str(raw.get("error", "resposta inválida"))],
		"legacy": raw,
	}
	if raw.has("missing"):
		out["missing"] = raw.get("missing", [])
	return out

static func _validate_spec(contract: String, parsed: Variant) -> Dictionary:
	if not (parsed is Dictionary):
		return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": ["resposta não é um objeto JSON"]}
	var spec: Dictionary = SPECS[contract]
	var required: Dictionary = spec.get("required", {})
	var optional: Dictionary = spec.get("optional", {})
	var enums: Dictionary = spec.get("enums", {})
	var ranges: Dictionary = spec.get("ranges", {})
	var source: Dictionary = parsed
	var decision := {}
	var clamped: Array = []
	var errors: Array = []
	for key in source.keys():
		var name := str(key)
		if not required.has(name) and not optional.has(name):
			errors.append("chave inesperada: " + name)
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": errors}
	for key in required.keys():
		if not source.has(key):
			errors.append("campo ausente: " + str(key))
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": errors}
	for key in source.keys():
		var name := str(key)
		var kind := str(required.get(name, optional.get(name, KIND_STRING)))
		var value: Variant = source[key]
		var checked := _check_value(name, kind, value, enums, ranges, clamped, errors)
		if checked[0]:
			decision[name] = checked[1]
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": clamped, "errors": errors}
	var coherence := check_coherence(contract, decision, {})
	for message in coherence:
		errors.append(message)
	if contract == "news_text":
		for message in check_news_placeholders(decision):
			errors.append(message)
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": clamped, "errors": errors}
	return {"ok": true, "contract": contract, "decision": decision, "clamped": clamped, "errors": []}

## Devolve [aceito, valor_normalizado].
static func _check_value(name: String, kind: String, value: Variant, enums: Dictionary, ranges: Dictionary, clamped: Array, errors: Array) -> Array:
	match kind:
		KIND_NUMBER:
			var number := _finite(value)
			if is_nan(number):
				errors.append("campo não numérico: " + name)
				return [false, 0.0]
			if ranges.has(name):
				var bounds: Array = ranges[name]
				var low := float(bounds[0])
				var high := float(bounds[1])
				if number < low or number > high:
					var fixed := clampf(number, low, high)
					clamped.append({"key": name, "from": number, "to": fixed})
					number = fixed
			return [true, number]
		KIND_BOOL:
			if typeof(value) != TYPE_BOOL:
				errors.append("campo não booleano: " + name)
				return [false, false]
			return [true, value]
		KIND_STRING:
			if not (value is String):
				errors.append("campo não textual: " + name)
				return [false, ""]
			var text := str(value).strip_edges()
			if text.length() > MAX_REASON_LENGTH and name == "reason":
				text = text.substr(0, MAX_REASON_LENGTH)
			if text.length() > MAX_TEXT_LENGTH:
				errors.append("texto longo demais: " + name)
				return [false, ""]
			return [true, text]
		KIND_ENUM:
			if not (value is String):
				errors.append("campo não textual: " + name)
				return [false, ""]
			var choice := str(value).strip_edges()
			var allowed: Array = enums.get(name, [])
			if not allowed.is_empty() and not allowed.has(choice):
				errors.append("valor fora da lista em %s: %s" % [name, choice])
				return [false, ""]
			return [true, choice]
		KIND_ID:
			if not (value is String):
				errors.append("campo não textual: " + name)
				return [false, ""]
			var id := str(value).strip_edges()
			if id == "" or id.length() > MAX_ID_LENGTH:
				errors.append("ID inválido em " + name)
				return [false, ""]
			for forbidden in [" ", "\n", "\t", "{", "}", "\"", "<", ">"]:
				if id.contains(forbidden):
					errors.append("ID com caractere inválido em " + name)
					return [false, ""]
			return [true, id]
		KIND_DICT:
			if not (value is Dictionary):
				errors.append("campo não é objeto: " + name)
				return [false, {}]
			return [true, (value as Dictionary).duplicate(true)]
		KIND_ARRAY:
			if not (value is Array):
				errors.append("campo não é lista: " + name)
				return [false, []]
			return [true, _clean_array(value, name, errors)]
	return [false, null]

## Listas só podem carregar IDs ou textos curtos; strings com chaves ou
## quebras são rejeitadas para não virarem instrução no passo seguinte.
static func _clean_array(value: Array, name: String, errors: Array) -> Array:
	var out: Array = []
	for item in value:
		if item is String:
			var text := str(item).strip_edges()
			if text == "" or text.length() > MAX_ID_LENGTH:
				errors.append("item inválido em " + name)
				return out
			for forbidden in ["\n", "\t", "{", "}", "\"", "<", ">"]:
				if text.contains(forbidden):
					errors.append("item com caractere inválido em " + name)
					return out
			out.append(text)
		elif item is Dictionary:
			var entry := {}
			for key in (item as Dictionary).keys():
				entry[str(key)] = (item as Dictionary)[key]
			out.append(entry)
		else:
			errors.append("item de tipo não suportado em " + name)
			return out
	return out

## Coerência entre atores (seção 7): o que não pode coexistir no mesmo mês.
static func check_coherence(contract: String, decision: Dictionary, month_facts: Dictionary = {}) -> Array:
	var errors: Array = []
	match contract:
		"central_bank":
			var move := float(decision.get("rate_move_bp", 0.0))
			var stance := str(decision.get("stance", "neutro"))
			if move > 0.0 and stance == "dovish":
				errors.append("postura dovish não combina com alta de juros")
			if move != 0.0 and str(decision.get("reason", "")).strip_edges() == "":
				errors.append("movimento de juros sem motivo registrado")
		"market_mood":
			var sentiment := float(decision.get("sentiment", 0.0))
			var flow := str(decision.get("capital_flow", "neutro"))
			if sentiment >= 0.6 and flow == "saida":
				errors.append("euforia com saída de capital é incoerente")
			if sentiment <= -0.6 and flow == "entrada":
				errors.append("pessimismo com entrada de capital é incoerente")
			if bool(month_facts.get("default", false)) and sentiment > 0.2:
				errors.append("mercado não pode estar otimista em mês de calote")
		"executive_action":
			if str(decision.get("action", "")) == "vetar" and str(decision.get("target_id", "")) == "":
				errors.append("veto exige target_id")
		"conflict_action":
			if str(decision.get("action", "")) == "escalar" and str(decision.get("conflict_id", "")) == "":
				errors.append("escalada exige conflito existente")
		"global_event":
			if float(decision.get("duration_months", 0.0)) <= 0.0:
				errors.append("choque sem duração")
		"coalition_response":
			if bool(decision.get("accept", false)) and not (decision.get("price", {}) is Dictionary):
				errors.append("aceite exige preço explícito")
	return errors

# ------------------------------------------------------------------- event_v2

## Evento do jogador: exatamente 3 opções, efeitos dentro de faixa, sem opção
## dominante e com pelo menos uma alternativa sem custo em caixa.
static func validate_event_v2(parsed: Variant) -> Dictionary:
	var contract := "event_v2"
	if not (parsed is Dictionary):
		return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": ["resposta não é um objeto JSON"]}
	var source: Dictionary = parsed
	var errors: Array = []
	var clamped: Array = []
	for key in source.keys():
		if not ["headline", "category", "options"].has(str(key)):
			errors.append("chave inesperada: " + str(key))
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": [], "errors": errors}
	var headline := str(source.get("headline", "")).strip_edges()
	if headline == "" or headline.length() > MAX_HEADLINE_LENGTH:
		errors.append("manchete ausente ou longa demais")
	var category := str(source.get("category", "politica")).strip_edges()
	if not ["economia", "politica", "social", "internacional", "seguranca"].has(category):
		errors.append("categoria desconhecida: " + category)
	var raw_options: Variant = source.get("options", null)
	if not (raw_options is Array) or (raw_options as Array).size() != 3:
		errors.append("evento exige exatamente 3 opções")
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": clamped, "errors": errors}
	var options: Array = []
	for index in 3:
		var raw: Variant = (raw_options as Array)[index]
		if not (raw is Dictionary):
			errors.append("opção %d não é objeto" % (index + 1))
			continue
		var option: Dictionary = raw
		var label := str(option.get("label", "")).strip_edges()
		if label == "" or label.length() > 40:
			errors.append("rótulo inválido na opção %d" % (index + 1))
		var hint := str(option.get("hint", "")).strip_edges()
		if hint.length() > 80:
			errors.append("dica longa demais na opção %d" % (index + 1))
		var effects := _clean_effects(option.get("effects", {}), index + 1, clamped, errors)
		var groups := _clean_groups(option.get("groups", {}), index + 1, clamped, errors)
		options.append({"label": label, "hint": hint, "effects": effects, "groups": groups})
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": clamped, "errors": errors}
	if _has_dominant_option(options):
		errors.append("opção dominante: uma alternativa é melhor em tudo")
	var free_option := false
	for option in options:
		var effects: Dictionary = (option as Dictionary).get("effects", {})
		if float(effects.get("funds", 0.0)) >= 0.0:
			free_option = true
	if not free_option:
		errors.append("nenhuma opção sem custo em caixa")
	if not errors.is_empty():
		return {"ok": false, "contract": contract, "decision": {}, "clamped": clamped, "errors": errors}
	return {
		"ok": true,
		"contract": contract,
		"decision": {"headline": headline, "category": category, "options": options},
		"clamped": clamped,
		"errors": [],
	}

static func _clean_effects(raw: Variant, number: int, clamped: Array, errors: Array) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		errors.append("efeitos ausentes na opção %d" % number)
		return out
	for key in (raw as Dictionary).keys():
		var name := str(key)
		if not EVENT_EFFECT_LIMITS.has(name):
			errors.append("efeito desconhecido: " + name)
			continue
		var value := _finite((raw as Dictionary)[key])
		if is_nan(value):
			errors.append("efeito não numérico: " + name)
			continue
		var bounds: Array = EVENT_EFFECT_LIMITS[name]
		var low := float(bounds[0])
		var high := float(bounds[1])
		if value < low or value > high:
			var fixed := clampf(value, low, high)
			clamped.append({"key": name, "from": value, "to": fixed})
			value = fixed
		out[name] = value
	if out.is_empty():
		errors.append("opção %d sem efeito" % number)
	return out

static func _clean_groups(raw: Variant, _number: int, clamped: Array, errors: Array) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for key in (raw as Dictionary).keys():
		var name := str(key)
		if not GROUP_NAMES.has(name):
			errors.append("grupo desconhecido: " + name)
			continue
		var value := _finite((raw as Dictionary)[key])
		if is_nan(value):
			errors.append("grupo não numérico: " + name)
			continue
		if value < -EVENT_GROUPS_LIMIT or value > EVENT_GROUPS_LIMIT:
			var fixed := clampf(value, -EVENT_GROUPS_LIMIT, EVENT_GROUPS_LIMIT)
			clamped.append({"key": "groups." + name, "from": value, "to": fixed})
			value = fixed
		out[name] = value
	return out

## Uma opção domina outra quando é >= em todos os efeitos e grupos e > em pelo
## menos um. O evento é rejeitado porque a escolha deixa de existir.
static func _has_dominant_option(options: Array) -> bool:
	for i in options.size():
		var a: Dictionary = options[i]
		var effects_a: Dictionary = a.get("effects", {})
		var groups_a: Dictionary = a.get("groups", {})
		for j in options.size():
			if i == j:
				continue
			var b: Dictionary = options[j]
			var effects_b: Dictionary = b.get("effects", {})
			var groups_b: Dictionary = b.get("groups", {})
			if _dominates(effects_a, groups_a, effects_b, groups_b):
				return true
	return false

static func _dominates(effects_a: Dictionary, groups_a: Dictionary, effects_b: Dictionary, groups_b: Dictionary) -> bool:
	var keys: Array = []
	for key in effects_a.keys():
		if not keys.has(key):
			keys.append(key)
	for key in effects_b.keys():
		if not keys.has(key):
			keys.append(key)
	var better := false
	for key in keys:
		var a := float(effects_a.get(key, 0.0))
		var b := float(effects_b.get(key, 0.0))
		if a < b:
			return false
		if a > b:
			better = true
	if not better:
		var group_keys: Array = []
		for key in groups_a.keys():
			if not group_keys.has(key):
				group_keys.append(key)
		for key in groups_b.keys():
			if not group_keys.has(key):
				group_keys.append(key)
		for key in group_keys:
			var a := float(groups_a.get(key, 0.0))
			var b := float(groups_b.get(key, 0.0))
			if a < b:
				return false
			if a > b:
				better = true
	return better

# ------------------------------------------------------------------- news_text

## Texto de notícia usa apenas placeholders. Número literal é rejeitado porque
## o motor é quem calcula o valor (`{{inflation}}`), nunca o modelo.
static func has_literal_number(text: String) -> bool:
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "{":
			var close := text.find("}}", i)
			if close >= 0:
				i = close + 2
				continue
		if c >= "0" and c <= "9":
			return true
		i += 1
	return false

## Aplica a regra de placeholders ao texto já normalizado.
static func check_news_placeholders(decision: Dictionary) -> Array:
	var errors: Array = []
	for key in ["headline", "body"]:
		var text := str(decision.get(key, ""))
		if has_literal_number(text):
			errors.append("número literal em %s: use placeholders do motor" % key)
	return errors
