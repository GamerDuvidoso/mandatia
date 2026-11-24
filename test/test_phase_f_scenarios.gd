extends Node
## Cenários curtos da Fase F; não executa a suíte histórica.

const PhaseF := preload("res://scripts/sim/phase_f_information.gd")

func _ready() -> void:
	var state := {
		"date_year": 2027, "date_month": 3, "country_id": "BR", "country_name": "Brasil",
		"party": "Partido Teste", "abbr": "PT", "leader": "Líder Teste", "government": true,
		"approval": 48.0, "debt": 70.0, "coalition_stability": 58.0,
		"event": "Reforma aprovada", "event_id": "reforma",
		"world": {"history": [
			{"id": "election-1", "date": "2027-03", "country": "AR", "category": "eleicao", "headline": "Eleição autônoma", "description": "Eleição registrada", "status": "oficial", "certainty": "confirmado", "actors": ["P1"], "consequences": []},
			{"id": "leadership-1", "date": "2027-03", "country": "AR", "category": "lideranca", "headline": "Mudança de liderança", "description": "Partido troca liderança", "status": "confirmado", "certainty": "confirmado", "actors": ["P1"], "consequences": []}
		]},
		"scandals": [{"id": "case-1", "title": "Investigação teste", "legal": "unresolved", "actor": "P1", "history": [{"month": "2027-03", "stage": "investigacao", "note": "Investigação sem desfecho."}]}],
		"causal_log": []
	}
	PhaseF.monthly(state)
	var articles: Array = state.phase_f.articles
	var categories := {}
	for article in articles: categories[str(article.get("category", ""))] = true
	var ok := categories.has("eleicao") and categories.has("lideranca") and categories.has("investigacao")
	if not ok:
		push_error("Tarefa 8: cenários editoriais ausentes")
		print("PHASE_F_SCENARIOS_FAIL")
		get_tree().quit(1)
		return
	print("PHASE_F_SCENARIOS_OK")
	get_tree().quit(0)
