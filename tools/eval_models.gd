extends SceneTree
## Avaliação comparativa de modelos Ollama nos 4 contratos do Mandatia.
## Mede sucesso, latência, uso de fallback e cobertura do legislativo em blocos.
##
## Uso:
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/eval_models.gd
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/eval_models.gd -- --models m1,m2
##   ... -- --rounds 3 --json res://eval_report.json
##
## Requer Ollama em 127.0.0.1:11434 com os modelos instalados.

const Contracts := preload("res://scripts/ai/ai_contracts.gd")
const AIClient := preload("res://scripts/ai/ollama_client.gd")

var models: PackedStringArray = []
var rounds := 1
var json_out := ""

func _initialize() -> void:
	call_deferred("_run")

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := str(args[i])
		if a == "--models" and i + 1 < args.size():
			for m in str(args[i + 1]).split(",", false):
				var t := m.strip_edges()
				if t != "":
					models.append(t)
			i += 2
			continue
		if a == "--rounds" and i + 1 < args.size():
			rounds = maxi(1, int(args[i + 1]))
			i += 2
			continue
		if a == "--json" and i + 1 < args.size():
			json_out = str(args[i + 1])
			i += 2
			continue
		i += 1
	if models.is_empty():
		models = PackedStringArray(["huihui_ai/qwen2.5-abliterate:3b"])

func _probe_tags() -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var err := http.request("http://127.0.0.1:11434/api/tags", [], HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "request err " + str(err)}
	var result = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {"ok": false, "error": "http " + str(result[1])}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if parsed is Dictionary:
		return {"ok": true, "data": parsed}
	return {"ok": false, "error": "json inválido"}

func _installed_models(tags: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for item in (tags.get("models", []) as Array):
		if item is Dictionary:
			var name := str((item as Dictionary).get("name", ""))
			if name != "":
				out.append(name)
	return out

func _request_once(ai: Node, contract: String, ctx: Dictionary, data: Dictionary, meta: Dictionary, timeout_ms: int = 70000) -> Dictionary:
	var box: Array = []
	var start := Time.get_ticks_msec()
	ai.request(contract, ctx, data, meta, func(payload: Dictionary) -> void: box.append(payload))
	while box.is_empty() and Time.get_ticks_msec() - start < timeout_ms:
		await create_timer(0.2).timeout
	var elapsed := Time.get_ticks_msec() - start
	if box.is_empty():
		return {"ok": false, "source": "timeout", "reason": "timeout local", "ms": elapsed, "value": {}}
	var payload: Dictionary = box[0]
	return {
		"ok": str(payload.get("source", "")) == "ollama",
		"source": str(payload.get("source", "")),
		"reason": str(payload.get("reason", "")),
		"fallback_used": bool(payload.get("fallback_used", true)),
		"ms": elapsed,
		"value": payload.get("value", {}),
	}

# Mesmo formato de prompt que o jogo envia em _request_bill_chunk: sem as
# linhas de bancada o 3B responde JSON inválido e cai no fallback.
const EVAL_AXES := {"PT": -0.55, "PL": 0.6, "UNIAO": 0.3, "PP": 0.45, "PSD": 0.2, "MDB": 0.05, "REPUBLICANOS": 0.5, "PSDB": -0.1, "PDT": -0.4, "PSB": -0.5, "PODE": 0.1, "PSOL": -0.8, "CIDADANIA": -0.2}

func _eval_legislative(ai: Node, meta_base: Dictionary) -> Dictionary:
	var seat_map := {"PT": 67, "PL": 92, "UNIAO": 59, "PP": 47, "PSD": 46, "MDB": 44, "REPUBLICANOS": 41, "PSDB": 13, "PDT": 17, "PSB": 14, "PODE": 14, "PSOL": 13, "CIDADANIA": 5}
	var banks := seat_map.keys()
	var covered := 0
	var batches := 0
	var ok_batches := 0
	var total_ms := 0
	var cursor := 0
	var chunk := Contracts.LEGISLATIVE_CHUNK
	while cursor < banks.size():
		var batch: Array = banks.slice(cursor, mini(cursor + chunk, banks.size()))
		batches += 1
		var chunk_map := {}
		var lines: Array = []
		for party in batch:
			chunk_map[str(party)] = int(seat_map[str(party)])
			lines.append("%s: %d cadeiras, eixo %.2f, %s" % [
				str(party), int(chunk_map[str(party)]), float(EVAL_AXES.get(str(party), 0.0)),
				"aliado" if str(party) == "PT" else "oposição",
			])
		var ctx := {
			"proposicao": "Lei de investimento regional",
			"eixo": -0.2,
			"coesao": 60.0,
			"bancadas": lines,
			"ids_permitidos": batch,
		}
		var data := {"seat_map": chunk_map, "bill": {"id": "investment", "title": "Lei de investimento regional", "axis": -0.2}, "axes": EVAL_AXES, "partners": ["PT"], "cohesion": 60.0, "entities": batch}
		var meta := meta_base.duplicate()
		meta["bill"] = "investment:%d" % cursor
		var r: Dictionary = await _request_once(ai, Contracts.LEGISLATIVE, ctx, data, meta)
		total_ms += int(r.get("ms", 0))
		var votes: Dictionary = (r.get("value", {}) as Dictionary).get("votes", {})
		covered += votes.size()
		if str(r.get("source", "")) == "ollama":
			ok_batches += 1
		cursor += chunk
	return {"contract": "legislative", "ok": ok_batches == batches and covered == banks.size(), "covered_banks": covered, "total_banks": banks.size(), "ok_batches": ok_batches, "batches": batches, "ms": total_ms}

func _eval_model(model: String) -> Dictionary:
	print("[eval] modelo: " + model)
	var ai: Node = AIClient.new()
	ai.model = model
	root.add_child(ai)
	ai.set("ai_available", false)
	ai.set("availability_checked", false)
	ai.attach(null)
	var wait_start := Time.get_ticks_msec()
	while not bool(ai.get("availability_checked")) and Time.get_ticks_msec() - wait_start < 15000:
		await create_timer(0.25).timeout
	while ai.get("_warm") != null and is_instance_valid(ai.get("_warm")) and Time.get_ticks_msec() - wait_start < 300000:
		await create_timer(0.25).timeout
	var available := bool(ai.get("ai_available"))
	var out := {"model": model, "available": available, "rounds": [], "summary": {}}
	if not available:
		print("[eval]   indisponível: " + str(ai.get("last_error")))
		ai.queue_free()
		return out
	for r in range(rounds):
		var meta_base := {"month": 1 + r, "year": 2027, "country": "BR", "eval": r}
		var round_out := {"round": r + 1, "contracts": []}
		round_out.contracts.append(await _eval_legislative(ai, meta_base))
		var e := await _request_once(ai, Contracts.ELECTORAL,
			{"pais": "Brasil", "partido": "FT", "popularidade": 30.0, "aprovacao": 35.0, "pesquisa": ["PL: 25.0%", "PT: 21.0%", "FT: 8.0%"], "ids_permitidos": ["PL", "PT", "FT", "OUTROS"]},
			{"base_shares": {"PL": 25.0, "PT": 21.0, "FT": 8.0, "OUTROS": 46.0}, "entities": ["PL", "PT", "FT"]},
			meta_base)
		e["contract"] = "electoral"
		round_out.contracts.append(e)
		var ev := await _request_once(ai, Contracts.EVENTS,
			{"pais": "Brasil", "governo": "governo", "aprovacao": 41.0, "popularidade": 38.0, "mes": 3, "ano": 2027},
			{"entities": ["evento", "BR"]}, meta_base)
		ev["contract"] = "events"
		round_out.contracts.append(ev)
		var it := await _request_once(ai, Contracts.INTERNATIONAL,
			{"pais": "Brasil", "mes": 12, "ano": 2027, "bancadas": ["PL", "PT", "UNIAO"], "ids_permitidos": ["PL", "PT", "UNIAO"]},
			{"party_ids": ["PL", "PT", "UNIAO"], "entities": ["PL", "PT", "UNIAO"]}, meta_base)
		it["contract"] = "international"
		round_out.contracts.append(it)
		for c in round_out.contracts:
			var extra := ""
			if c.has("covered_banks"):
				extra = " bancadas=%d/%d lotes=%d/%d" % [int(c.get("covered_banks", 0)), int(c.get("total_banks", 0)), int(c.get("ok_batches", 0)), int(c.get("batches", 0))]
			print("[eval]   r%d %-13s source=%s ms=%s ok=%s%s" % [r + 1, str(c.get("contract", "")), str(c.get("source", "")), str(c.get("ms", "")), str(c.get("ok", false)), extra])
		out.rounds.append(round_out)
	var by_contract := {}
	for round_out in out.rounds:
		for c in round_out.contracts:
			var name := str(c.get("contract", ""))
			if not by_contract.has(name):
				by_contract[name] = {"ok": 0, "total": 0, "ms_sum": 0}
			by_contract[name].total += 1
			by_contract[name].ms_sum += int(c.get("ms", 0))
			if bool(c.get("ok", false)) or str(c.get("source", "")) == "ollama":
				by_contract[name].ok += 1
	out.summary = by_contract
	ai.queue_free()
	return out

func _run() -> void:
	_parse_args()
	var tags_r: Dictionary = await _probe_tags()
	if not bool(tags_r.get("ok", false)):
		print("[eval] Ollama indisponível: " + str(tags_r.get("error", "")))
		quit(1)
		return
	var installed := _installed_models(tags_r.get("data", {}))
	print("[eval] modelos instalados: " + ", ".join(installed))
	print("[eval] modelos a avaliar: " + ", ".join(models))
	print("[eval] rounds: %d" % rounds)
	var report := {"installed": Array(installed), "results": []}
	for m in models:
		report.results.append(await _eval_model(str(m)))
	print("\n[eval] RESUMO")
	for res in report.results:
		print("- %s (disponível=%s)" % [str(res.get("model", "")), str(res.get("available", false))])
		var summary: Dictionary = res.get("summary", {})
		for cname in summary.keys():
			var s: Dictionary = summary[cname]
			var avg := 0
			if int(s.total) > 0:
				avg = int(s.ms_sum / s.total)
			print("  %-13s %d/%d ok  ~%dms" % [cname, int(s.ok), int(s.total), avg])
	if json_out != "":
		var path := json_out
		if path.begins_with("res://"):
			path = ProjectSettings.globalize_path(path)
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "  "))
			f.close()
			print("[eval] relatório salvo em: " + path)
		else:
			print("[eval] falha ao salvar relatório em: " + path)
	quit(0)
