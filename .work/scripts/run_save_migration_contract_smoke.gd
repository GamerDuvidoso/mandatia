extends SceneTree
## Contrato direcionado da Tarefa 9. Não substitui QA de saves, corrupção ou suíte completa.

var failures: Array[String] = []
var checks := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "cena principal deveria carregar")
	if packed == null:
		_finish()
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var base: Dictionary = game.call("_default_state")
	base["future_unknown_field"] = {"preserve": true, "value": 17}
	base["save_version"] = 1
	base.erase("economic_profile")
	var migrated: Dictionary = game.call("_migrate_state", base)
	_check(not migrated.is_empty(), "save compatível deveria migrar")
	_check(migrated.get("future_unknown_field", {}).get("value", -1) == 17, "campo desconhecido deveria ser preservado")
	_check(int(migrated.get("save_version", 0)) == 6, "versão migrada deveria ser a versão atual")
	var migrated_again: Dictionary = game.call("_migrate_state", migrated)
	_check(not migrated_again.is_empty(), "migração repetida deveria continuar válida")
	_check(migrated_again.get("future_unknown_field", {}).get("preserve", false) == true, "campo desconhecido deveria sobreviver à segunda migração")
	_check(JSON.stringify(migrated_again.get("demography", {})) == JSON.stringify(migrated.get("demography", {})), "migração repetida não deveria recriar demografia diferente")
	_check(int(migrated.get("date_month", 0)) >= 1 and int(migrated.get("date_month", 0)) <= 12, "mês migrado deveria permanecer no intervalo válido")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SAVE_MIGRATION_CONTRACT_PASS checks=%d" % checks)
		quit(0)
	else:
		print("SAVE_MIGRATION_CONTRACT_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
