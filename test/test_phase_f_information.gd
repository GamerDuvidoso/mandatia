extends Node
## Teste curto da Fase F. Não substitui a suíte histórica e não executa cenários longos.

const PhaseF := preload("res://scripts/sim/phase_f_information.gd")

var failures := PackedStringArray()
var checks := 0

func _ready() -> void:
	var state := {
		"date_year": 2027, "date_month": 1, "country_id": "BR", "country_name": "Brasil",
		"party": "Frente de Teste", "abbr": "FT", "leader": "Lia Teste", "government": true,
		"approval": 55.0, "debt": 62.0, "coalition_stability": 68.0, "event": "Reforma aprovada",
		"event_id": "reforma", "world": {"countries": {"AR": {"id": "AR", "name": "Argentina", "parties": {"P1": {"id": "P1", "name": "Partido Um", "leader": "Líder Autônomo", "in_gov": true, "leadership_since": ""}}}}, "history": [{"id": "world-1", "date": "2027-01", "country": "AR", "category": "eleicao", "description": "Eleição registrada", "headline": "Eleição registrada", "status": "confirmado", "certainty": "confirmado", "actors": ["P1"], "consequences": []}]},
		"ministers": ["Finanças"],
		"causal_log": [{"month": "2027-01", "domain": "politica", "cause": "Reforma aprovada", "effects": {"approval": 2.0}, "explanation": "votação aprovada e efeitos registrados"}],
		"scandals": [{"id": "caso-teste", "title": "Contrato sob apuração", "stage": "investigacao", "legal": "investigating", "actor": "auxiliar do partido", "history": [{"month": "2027-01", "stage": "alegacao", "note": "Alegação publicada; nenhuma conclusão jurídica."}, {"month": "2027-02", "stage": "investigacao", "note": "Apuração formal aberta; sem conclusão jurídica."}]}]
	}
	PhaseF.ensure(state)
	_check(state.get("phase_f") is Dictionary, "ensure cria o bloco persistente")
	PhaseF.monthly(state)
	var info: Dictionary = state.phase_f
	_check((info.get("articles", []) as Array).size() >= 4, "um fato gera cobertura de outlets identificáveis")
	_check((info.get("archive", []) as Array).size() == 4, "arquivo conserva eventos mundial, local e duas etapas do caso")
	_check((info.get("polls", []) as Array).size() == 1, "poll mensal é deduplicado")
	var poll: Dictionary = (info.polls as Array)[0]
	_check(bool(poll.get("simulated", false)), "poll é explicitamente simulado")
	_check(float(poll.get("margin_of_error", 0.0)) > 0.0, "poll contém incerteza")
	_check(str(poll.get("underlying_state", "")) != str(poll.get("estimate", "")), "poll não revela o estado oculto")
	_check(float(poll.get("moving_average", 0.0)) >= 0.0, "poll contém média móvel")
	var segment_total := 0
	for segment in poll.get("segments", []): segment_total += int(segment.get("sample_size", 0))
	_check(segment_total == int(poll.get("sample_size", 0)), "segmentos somam a amostra sem dupla contagem")
	_check(not PhaseF.latest_report(state).is_empty(), "relatório analítico é gerado")
	var local_articles: Array = (info.get("articles", []) as Array).filter(func(article: Variant) -> bool: return str(article.get("source_id", "")).begins_with("local:"))
	_check(not local_articles.is_empty() and not (local_articles[0].get("causal_evidence", []) as Array).is_empty(), "artigo local referencia o causal_log")
	_check(not ((PhaseF.latest_report(state).get("causal_evidence", []) as Array).is_empty()), "relatório preserva evidência causal")
	var biographies: Dictionary = info.get("biographies", {})
	var autonomous: Dictionary = biographies.get("world:AR:leader:P1", {}) if biographies.get("world:AR:leader:P1") is Dictionary else {}
	_check(str(autonomous.get("name", "")) == "Líder Autônomo", "biografia de ator autônomo é criada")
	_check((autonomous.get("career", []) as Array).size() >= 1, "biografia autônoma preserva trajetória eleitoral")
	var encyclopedia: Dictionary = info.get("encyclopedia", {})
	_check(encyclopedia.has("country:AR") and encyclopedia.has("party:AR:P1"), "enciclopédia inclui país e partido autônomos")
	state["date_month"] = 2
	state["event"] = ""
	state["ministers"] = []
	PhaseF.monthly(state)
	var former_minister: Dictionary = info.biographies.get("minister:Finanças", {}) if info.biographies.get("minister:Finanças") is Dictionary else {}
	_check(str(former_minister.get("current_role", "")) == "ex-ministro", "saída do gabinete é registrada na biografia")
	_check((former_minister.get("career", []) as Array).size() >= 2, "biografia ministerial preserva nomeação e saída")
	var scandal_articles: Array = (info.get("articles", []) as Array).filter(func(article: Variant) -> bool: return str(article.get("source_type", "")) == "simulation_event" and str(article.get("category", "")) == "investigacao")
	_check(not scandal_articles.is_empty(), "investigação gera cobertura editorial própria")
	_check(str(scandal_articles[0].get("status", "")) == "investigacao", "investigação mantém status jurídico não conclusivo")
	PhaseF.monthly(state)
	_check((state.phase_f.archive as Array).size() == 4, "reprocessamento não duplica o arquivo")
	if failures.is_empty():
		print("PHASE_F_OK checks=%d" % checks)
	else:
		for failure in failures: push_error(str(failure))
		print("PHASE_F_FAIL checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
