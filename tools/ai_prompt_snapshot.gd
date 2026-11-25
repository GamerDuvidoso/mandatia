extends SceneTree
## Fase 2 — gera `test/fixtures/ai_prompt_cases.json`.
##
## O arquivo guarda a saída exata de `ai_contracts.prompt()` para um caso por
## contrato antigo. `test/test_ai_layer.gd` compara o prompt atual com esse
## fixture: se a migração para o catálogo mudar uma vírgula, o teste falha.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_prompt_snapshot.gd

const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const EXAMPLES_PATH := "res://config/ai_examples.json"
const OUT_DIR := "res://test/fixtures"
const OUT_PATH := "res://test/fixtures/ai_prompt_cases.json"

func _initialize() -> void:
	var examples := _load_examples()
	var cases: Array = [
		{
			"contract": "legislative",
			"ctx": {
				"proposicao": "Investimento regional",
				"eixo": -0.2,
				"coesao": 62.0,
				"bancadas": ["PL: 99 cadeiras, eixo 0.10, oposição", "PT: 68 cadeiras, eixo -0.40, aliado"],
				"ids_permitidos": ["PL", "PT"],
			},
		},
		{
			"contract": "electoral",
			"ctx": {
				"pais": "Brasil",
				"pesquisa": "PL 30, PT 28, UNIAO 18",
				"ids_permitidos": ["PL", "PT", "UNIAO"],
			},
		},
		{
			"contract": "events",
			"ctx": {"mes": "2027-03", "inflacao": 6.1, "desemprego": 9.4},
		},
		{
			"contract": "international",
			"ctx": {
				"evento": "Tarifas sobre aço e alumínio",
				"ids_permitidos": ["PL", "PT"],
			},
		},
	]
	for case in cases:
		# O JSON do Godot devolve as chaves ordenadas; o fixture precisa do mesmo
		# contexto que o teste vai carregar do disco, senão a ordem do prompt falso
		# diverge sem nenhuma mudança real de comportamento.
		case["ctx"] = JSON.parse_string(JSON.stringify(case["ctx"]))
		case["prompt"] = Contracts.prompt(str(case["contract"]), case["ctx"], examples)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("não foi possível escrever " + OUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify({"version": 1, "cases": cases}, "  "))
	file.close()
	print("fixture gravado: ", OUT_PATH, " (", cases.size(), " casos)")
	quit(0)

func _load_examples() -> Array:
	if not FileAccess.file_exists(EXAMPLES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXAMPLES_PATH))
	if not (parsed is Dictionary):
		return []
	var raw: Variant = (parsed as Dictionary).get("examples", [])
	return (raw as Array).duplicate() if raw is Array else []
