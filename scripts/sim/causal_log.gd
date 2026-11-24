extends RefCounted
## Registro de causalidade: cada evento relevante guarda causa, efeitos
## numéricos e explicação. É a camada de observabilidade do simulador; não
## altera o estado por conta própria.

const MAX_ENTRIES := 40

static func ensure(st: Dictionary) -> void:
	if not (st.get("causal_log") is Array):
		st["causal_log"] = []

static func record(st: Dictionary, domain: String, cause: String, effects: Dictionary, explanation: String) -> Dictionary:
	ensure(st)
	var entry := {
		"month": "%d-%02d" % [int(st.get("date_year", 0)), int(st.get("date_month", 1))],
		"domain": domain,
		"cause": cause,
		"effects": effects.duplicate(true),
		"explanation": explanation,
	}
	var log: Array = st.causal_log
	log.push_front(entry)
	if log.size() > MAX_ENTRIES:
		log = log.slice(0, MAX_ENTRIES)
	st["causal_log"] = log
	return entry

static func recent(st: Dictionary, domain := "", limit := 8) -> Array:
	ensure(st)
	var rows: Array = []
	for entry in st.causal_log:
		if domain != "" and str(entry.get("domain", "")) != domain:
			continue
		rows.append(entry)
		if rows.size() >= limit:
			break
	return rows

static func label(domain: String) -> String:
	var labels := {
		"greve": "GREVE",
		"coalizao": "COALIZÃO",
		"escandalo": "ESCÂNDALO",
		"politica": "POLÍTICA",
		"campanha": "CAMPANHA",
		"ministerio": "GABINETE",
	}
	return str(labels.get(domain, domain.to_upper()))
