extends RefCounted
## Fase 1 — aplicador.
##
## A decisão validada nunca escreve estado. O aplicador a traduz em um plano de
## chamadas a funções que já existem (`{"calls": [...]}`); quem executa é o
## sistema dono do ator, no ponto causal do mês.
##
## Isso mantém a contabilidade do motor (D'Hondt, livro-caixa, dívida, datas,
## clamps) fora da IA: o modelo escolhe o quê, a função existente calcula quanto.

## Contrato → sistema/função de destino e argumentos levados adiante.
const TARGETS := {
	"gov_priority": {
		"system": "autonomous_government",
		"function": "priority_override",
		"args": ["action", "intensity"],
	},
	"executive_action": {
		"system": "executive_npc",
		"function": "apply_action",
		"args": ["action", "target_id", "stance", "reason"],
	},
	"party_leadership": {
		"system": "autonomous_party_system",
		"function": "apply_leadership",
		"args": ["change_leader", "stance", "reason"],
	},
	"legislative_agenda": {
		"system": "autonomous_legislature",
		"function": "apply_agenda",
		"args": ["agenda_id", "rebels", "reason"],
	},
	"chamber_leadership": {
		"system": "autonomous_legislature",
		"function": "apply_leadership",
		"args": ["agenda_id", "obstruct", "open_inquiry", "reason"],
	},
	"court_ruling": {
		"system": "judiciary_system",
		"function": "apply_ruling",
		"args": ["case_id", "ruling", "vote_split", "reason"],
	},
	"market_mood": {
		"system": "market_system",
		"function": "apply_mood",
		"args": ["sentiment", "risk_premium_bp", "fx_pressure_pct", "capital_flow", "business", "reason"],
	},
	"central_bank": {
		"system": "central_bank",
		"function": "apply_rate_move",
		"args": ["rate_move_bp", "stance", "statement", "reason"],
	},
	"public_mood": {
		"system": "social_groups",
		"function": "apply_mood",
		"args": ["mood", "groups", "mobilization", "trust_institutions", "reason"],
	},
	"media_coverage": {
		"system": "media_system",
		"function": "apply_frame",
		"args": ["frame", "bias", "focus_id", "reason"],
	},
	"global_event": {
		"system": "global_shock_system",
		"function": "apply_shock",
		"args": ["shock", "severity", "duration_months", "reason"],
	},
	"diplomacy_action": {
		"system": "international_system",
		"function": "apply_actions",
		"args": ["actions", "reason"],
	},
	"organization_action": {
		"system": "international_system",
		"function": "apply_organization_action",
		"args": ["organization", "action", "target_country", "reason"],
	},
	"conflict_action": {
		"system": "conflict_system",
		"function": "apply_action",
		"args": ["conflict_id", "action", "reason"],
	},
	"scandal_seed": {
		"system": "scandal_system",
		"function": "apply_seed",
		"args": ["seed", "type_id", "target_role", "coverage", "reason"],
	},
	"group_demand": {
		"system": "interest_groups",
		"function": "apply_demand",
		"args": ["group_id", "stance", "demand_id", "escalate", "reason"],
	},
	"coalition_response": {
		"system": "coalition",
		"function": "apply_response",
		"args": ["accept", "price", "reason"],
	},
	"news_text": {
		"system": "phase_f_information",
		"function": "apply_text",
		"args": ["headline", "body", "tone"],
	},
	"rival_campaign": {
		"system": "campaign_system",
		"function": "apply_rival_action",
		"args": ["rival_id", "action", "target", "intensity", "reason"],
	},
	"event_v2": {
		"system": "events",
		"function": "apply_event",
		"args": ["headline", "category", "options"],
	},
	"foreign_election_swing": {
		"system": "foreign_election_system",
		"function": "apply_swing",
		"args": ["parties", "reason"],
	},
	"armed_forces_stance": {
		"system": "military_system",
		"function": "apply_stance",
		"args": ["stance", "reason"],
	},
}

static func has_target(contract: String) -> bool:
	return TARGETS.has(contract)

## Plano de aplicação. `scope` identifica o ator (`country`, `actor`, `id`).
static func plan(contract: String, decision: Dictionary, scope: Dictionary = {}) -> Dictionary:
	if not TARGETS.has(contract):
		return {"ok": false, "error": "contrato sem destino de aplicação: " + contract, "calls": []}
	var target: Dictionary = TARGETS[contract]
	var args := {}
	for key in (target.get("args", []) as Array):
		if decision.has(str(key)):
			args[str(key)] = decision[str(key)]
	var call := {
		"system": str(target.get("system", "")),
		"function": str(target.get("function", "")),
		"args": args,
		"scope": scope.duplicate(true),
		"contract": contract,
	}
	return {"ok": true, "calls": [call]}

## Diff no formato do registro persistido (seção 6.3): [{key, from, to}].
static func diff(previous: Dictionary, decision: Dictionary) -> Array:
	var changes: Array = []
	var keys: Array = decision.keys()
	keys.sort()
	for key in keys:
		var name := str(key)
		var before: Variant = previous.get(name, null)
		var after: Variant = decision[key]
		if before == null:
			continue
		if str(before) != str(after):
			changes.append({"key": name, "from": before, "to": after})
	return changes

static func decision_id(index: int) -> String:
	return "d_%06d" % index

## Registro persistido de uma decisão (save + dataset). Não aplica nada.
static func record(contract: String, decision: Dictionary, meta: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var source := str(extra.get("source", "ia"))
	var payload := {
		"id": str(extra.get("id", decision_id(int(extra.get("index", 0))))),
		"contract": contract,
		"source": source,
		"model": str(meta.get("model", "")),
		"stamp": "%d-%02d" % [int(meta.get("year", 0)), int(meta.get("month", 0))],
		"request_hash": str(extra.get("request_hash", "")),
		"latency_ms": int(extra.get("latency_ms", 0)),
		"tokens": extra.get("tokens", {"prompt": 0, "output": 0, "thinking": 0}),
		"validation": {
			"ok": bool(extra.get("valid", true)),
			"clamped": extra.get("clamped", []),
			"errors": extra.get("errors", []),
		},
		"applied": {
			"system": str(extra.get("system", "")),
			"changes": extra.get("changes", []),
		},
		"rationale": str(decision.get("reason", extra.get("rationale", ""))),
	}
	return payload
