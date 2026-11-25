extends RefCounted
## Fase 1 — registro de decisões (seção 6.3) e coleta para treino (seção 8.1).
##
## Toda decisão validada entra no save (`state.ai_decision_log`, limitado) e,
## se o export estiver ligado, em `user://ai_dataset/<contrato>.jsonl` no
## formato {"input", "output", "contract", "validated", "source"}.
##
## Só decisão validada entra como exemplo de resposta da IA. Decisão de
## contingência continua no log (para auditoria) mas não vira exemplo de treino,
## porque não foi o modelo que a produziu.

const DEFAULT_PATH := "user://ai_dataset"
const MAX_SAVED := 240
const MAX_INPUT := 4000
const MAX_OUTPUT := 2000

static func _export_config(config: Dictionary) -> Dictionary:
	var raw: Variant = config.get("training_export", {})
	return raw if raw is Dictionary else {}

static func _dataset_dir(config: Dictionary) -> String:
	var export := _export_config(config)
	var path := str(export.get("path", DEFAULT_PATH))
	return path if path != "" else DEFAULT_PATH

static func dataset_path(config: Dictionary, contract: String) -> String:
	return "%s/%s.jsonl" % [_dataset_dir(config), contract]

static func _single_line(text: String, limit: int) -> String:
	var out := text.replace("\r", " ").replace("\n", " ")
	if out.length() > limit:
		out = out.substr(0, limit)
	return out

## `entry` no formato persistido da seção 6.3. Devolve true quando gravou no
## dataset (o log no save acontece sempre).
static func record(state: Dictionary, config: Dictionary, entry: Dictionary) -> bool:
	_append_to_state(state, entry)
	return append_dataset(config, entry)

static func _append_to_state(state: Dictionary, entry: Dictionary) -> void:
	var log: Array = []
	if state.get("ai_decision_log") is Array:
		log = state.ai_decision_log
	log.push_front(entry.duplicate(true))
	if log.size() > MAX_SAVED:
		log.resize(MAX_SAVED)
	state["ai_decision_log"] = log

static func append_dataset(config: Dictionary, entry: Dictionary) -> bool:
	var export := _export_config(config)
	if not bool(export.get("enabled", true)):
		return false
	var validation: Variant = entry.get("validation", {})
	var valid := bool((validation as Dictionary).get("ok", false)) if validation is Dictionary else false
	if bool(export.get("only_validated", true)) and not valid:
		return false
	var contract := str(entry.get("contract", ""))
	if contract == "":
		return false
	var prompt := _single_line(str(entry.get("input", entry.get("prompt", ""))), MAX_INPUT)
	var output := _single_line(str(entry.get("output", entry.get("raw", ""))), MAX_OUTPUT)
	if prompt == "" or output == "":
		return false
	var dir := _dataset_dir(config)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dataset_path(config, contract)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	var row := {
		"input": prompt,
		"output": output,
		"contract": contract,
		"validated": valid,
		"source": str(entry.get("source", "ia")),
		"stamp": str(entry.get("stamp", "")),
	}
	file.store_line(JSON.stringify(row))
	file.close()
	return true

static func count_lines(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var total := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() != "":
			total += 1
	file.close()
	return total

static func recent(state: Dictionary, limit: int = 10) -> Array:
	var log: Variant = state.get("ai_decision_log", [])
	if not (log is Array):
		return []
	return (log as Array).slice(0, limit)

static func by_source(state: Dictionary) -> Dictionary:
	var out := {}
	var log: Variant = state.get("ai_decision_log", [])
	if not (log is Array):
		return out
	for item in log:
		if not (item is Dictionary):
			continue
		var source := str((item as Dictionary).get("source", "desconhecido"))
		out[source] = int(out.get(source, 0)) + 1
	return out
