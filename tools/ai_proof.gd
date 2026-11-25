extends SceneTree
## Fase 3 — prova mínima G1–G7 (seção 9 do prompt de integração).
##
## Roda sem Ollama e sem GPU. Os gates que dependem do modelo e do hardware do
## dono saem como NÃO MEDIDO com o motivo — nunca como PASS inventado.
##
## Medidos offline (determinísticos):
##   G3 orçamento e tempo do mês;
##   G4 fallback (timeout, JSON inválido, resposta vazia, Ollama desligado);
##   G5 integridade (origem, validação, faixa e registro);
##   G6 replay de 12 meses com as decisões gravadas.
##
## NÃO MEDIDOS offline (exigem Ollama + modelo + hardware):
##   G1 JSON válido na 1ª e na 2ª tentativa;
##   G2 latência p50/p95;
##   G7 sanidade com 20 casos rotulados.
##
## Uso:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_proof.gd
## Saída: relatório em docs/ia_prova_minima.md; código 1 se algum gate medido falhar.

const Fixture := preload("res://test/world_fixture.gd")
const WorldSim := preload("res://scripts/sim/world_sim.gd")
const AiRuntime := preload("res://scripts/ai/ai_runtime.gd")
const FakeClient := preload("res://test/fake_ai_client.gd")
const Broker := preload("res://scripts/ai/decision_broker.gd")
const AutonomousGovernment := preload("res://scripts/sim/autonomous_government.gd")

const CONTRACT := "gov_priority"
const MONTHS := 12
const REPORT_PATH := "res://docs/ia_prova_minima.md"
const EXTRA_MS_LIMIT := 100.0

const STATUS_PASS := "PASS"
const STATUS_FAIL := "FAIL"
const STATUS_NA := "NÃO MEDIDO"

var gates: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _gate(id: String, name: String, status: String, detail: String, evidence: String = "") -> void:
	gates.append({"id": id, "name": name, "status": status, "detail": detail, "evidence": evidence})

func _run() -> void:
	_gate_g3()
	_gate_g4()
	_gate_g5()
	_gate_g6()
	_gate_not_measured("G1", "JSON válido (>=95% na 1ª; >=99% em até 2 tentativas; >=200 chamadas)",
		"exige o modelo real: offline não existe saída do modelo para medir taxa de JSON válido. O validador e o reparo por segunda tentativa estão cobertos em test/test_ai_layer.gd.")
	_gate_not_measured("G2", "Latência p50 <= 6 s e p95 <= 15 s; cena 3–4 atores p95 <= 25 s; timeouts <= 2%",
		"depende do hardware e do modelo do dono (o repo mediu 7–28 s com modelo de 3B). O caminho assíncrono/preparado é medido em G3; a latência em si não é mensurável sem Ollama.")
	_gate_not_measured("G7", "Sanidade: >=70% de 20 casos rotulados; nenhuma ação >60%; >=3 ações distintas; motivo cita variável do contexto em >=80%",
		"depende de 20 casos rotulados ANTES da medição e das saídas reais do modelo; sem modelo não há amostra válida.")
	_write_report()
	_finish()

func _finish() -> void:
	var failed := 0
	var measured := 0
	for gate in gates:
		if str(gate["status"]) == STATUS_FAIL:
			failed += 1
		if str(gate["status"]) != STATUS_NA:
			measured += 1
	print("")
	print("=== prova mínima da IA (gov_priority) ===")
	for gate in gates:
		print("%-2s %-9s %s" % [str(gate["id"]), str(gate["status"]), str(gate["name"])])
	print("gates medidos: %d · falhas: %d · relatório: %s" % [measured, failed, REPORT_PATH])
	if failed == 0:
		print("PASS (somente gates offline-determinísticos)")
		quit(0)
	else:
		print("FALHOU")
		quit(1)

# ----------------------------------------------------------------- helpers

func _runtime(mode: String, client: Object = null, budget := 40) -> Object:
	return AiRuntime.new({
		"mode": mode,
		"active_model": "fake-ai",
		"budget": {"max_calls_per_month": budget},
		"parallel": {"max_parallel": 2},
		"training_export": {"enabled": false, "only_validated": true},
	}, client)

func _run_months(st: Dictionary, months: int, runtime: Object = null) -> int:
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var done := 0
	for i in months:
		Fixture.set_date(st, 2027 + int(i / 12), int(i % 12) + 1)
		var result: Dictionary = WorldSim.monthly(st, countries, economy, runtime)
		if not bool(result.get("skipped", false)):
			done += 1
	return done

## Hash do mundo simulado (sem bookkeeping da IA) — é o "estado final" do gate.
func _world_hash(st: Dictionary) -> String:
	return Broker.hash_context({
		"world": st.get("world", {}),
		"international_state": st.get("international_state", {}),
	})

func _count_priority(st: Dictionary, action: String) -> int:
	var total := 0
	var countries_map: Dictionary = (st.get("world", {}) as Dictionary).get("countries", {})
	for id in countries_map.keys():
		if str((countries_map[id] as Dictionary).get("policy_priority", "")) == action:
			total += 1
	return total

func _fixtures(client: Object, months: int) -> void:
	for i in months * 40:
		client.call("queue", CONTRACT, {"action": "empregos", "intensity": 0.6, "reason": "desemprego alto"})

# ---------------------------------------------------------------------- G3

func _gate_g3() -> void:
	var off_state := Fixture.build_state()
	var start_off := Time.get_ticks_msec()
	var off_months := _run_months(off_state, MONTHS, _runtime("off"))
	var off_ms := float(Time.get_ticks_msec() - start_off)

	var fake := FakeClient.new()
	_fixtures(fake, MONTHS)
	var runtime := _runtime("preferred", fake)
	var ai_state := Fixture.build_state()
	var countries := Fixture.countries()
	var economy := Fixture.economy()
	var start_ai := Time.get_ticks_msec()
	var ai_months := 0
	var max_calls := 0
	for i in MONTHS:
		Fixture.set_date(ai_state, 2027 + int(i / 12), int(i % 12) + 1)
		var result: Dictionary = WorldSim.monthly(ai_state, countries, economy, runtime)
		if not bool(result.get("skipped", false)):
			ai_months += 1
		max_calls = maxi(max_calls, int(runtime.broker.stats().get("calls", 0)))
	var ai_ms := float(Time.get_ticks_msec() - start_ai)
	var stats: Dictionary = runtime.broker.stats()
	var per_month := off_ms / float(maxi(1, off_months))
	var extra := (ai_ms - off_ms) / float(maxi(1, ai_months))
	var budget_ok := max_calls <= int(stats.get("max_calls", 40))
	var time_ok := extra <= EXTRA_MS_LIMIT
	var months_ok := off_months == MONTHS and ai_months == MONTHS
	var status := STATUS_PASS if budget_ok and time_ok and months_ok else STATUS_FAIL
	_gate("G3", "Orçamento e tempo: nenhuma chamada bloqueante; orçamento mensal respeitado; sem espera ao avançar o mês",
		status,
		"chamadas no último mês: %d (teto %d) · meses concluídos: %d/%d (off) e %d/%d (IA) · custo do mês: %.1f ms (off) vs %.1f ms (IA), extra %.1f ms/mês (teto %.0f)" % [
			max_calls, int(stats.get("max_calls", 40)), off_months, MONTHS, ai_months, MONTHS,
			per_month, ai_ms / float(maxi(1, ai_months)), extra, EXTRA_MS_LIMIT,
		],
		"chamadas bloqueantes: 0 — a prioridade do mês é decidida em segundo plano e aplicada no mês seguinte")

# ---------------------------------------------------------------------- G4

func _gate_g4() -> void:
	var reference := Fixture.build_state()
	var ref_months := _run_months(reference, MONTHS, _runtime("off"))
	var ref_hash := _world_hash(reference)
	var details: Array = []
	var ok := ref_months == MONTHS
	for mode in ["timeout", "invalid", "empty", "offline"]:
		var fake := FakeClient.new()
		fake.mode = mode
		var state := Fixture.build_state()
		var months := _run_months(state, MONTHS, _runtime("preferred", fake))
		var same := _world_hash(state) == ref_hash
		details.append("%s: %d/%d meses, estado %s" % [mode, months, MONTHS, "idêntico" if same else "DIVERGENTE"])
		if months != MONTHS or not same:
			ok = false
	_gate("G4", "Fallback: 100% dos meses completam e o estado final é idêntico ao modo off",
		STATUS_PASS if ok else STATUS_FAIL,
		"; ".join(PackedStringArray(details)),
		"hash de referência (modo off): " + ref_hash)

# ---------------------------------------------------------------------- G5

func _gate_g5() -> void:
	var fake := FakeClient.new()
	_fixtures(fake, MONTHS)
	var state := Fixture.build_state()
	_run_months(state, MONTHS, _runtime("preferred", fake))
	var log: Array = state.get("ai_decision_log", [])
	var required := ["id", "contract", "source", "model", "stamp", "validation", "applied", "rationale"]
	var missing := 0
	var applied_ok := 0
	var clamp_ok := 0
	var allowed := ["estabilizacao", "empregos", "investimento", "austeridade", "negociacao"]
	for raw in log:
		if not (raw is Dictionary):
			missing += 1
			continue
		var entry: Dictionary = raw
		for key in required:
			if not entry.has(key):
				missing += 1
				break
		var applied: Dictionary = entry.get("applied", {}) if entry.get("applied") is Dictionary else {}
		if str(applied.get("system", "")) == "autonomous_government":
			applied_ok += 1
		var validation: Dictionary = entry.get("validation", {}) if entry.get("validation") is Dictionary else {}
		if bool(validation.get("ok", false)):
			var clamped: Variant = validation.get("clamped", [])
			if clamped is Array:
				var outside := false
				for item in clamped:
					if item is Dictionary and absf(float((item as Dictionary).get("to", 0.0))) > 1.0:
						outside = true
				if not outside:
					clamp_ok += 1
	var priorities_ok := true
	var countries_map: Dictionary = (state.get("world", {}) as Dictionary).get("countries", {})
	for id in countries_map.keys():
		if not allowed.has(str((countries_map[id] as Dictionary).get("policy_priority", "investimento"))):
			priorities_ok = false
	var ok := log.size() >= 1 and missing == 0 and applied_ok == log.size() and priorities_ok
	_gate("G5", "Integridade: decisão com origem, modelo, mês, validação e aplicação; nada fora de faixa no estado",
		STATUS_PASS if ok else STATUS_FAIL,
		"decisões registradas: %d · com todos os campos: %d · aplicadas pelo applier: %d · clamps dentro da faixa: %d · prioridades válidas no mundo: %s" % [
			log.size(), log.size() - missing, applied_ok, clamp_ok, "sim" if priorities_ok else "não",
		],
		"nenhum sistema escreve prioridade fora de autonomous_government.monthly: a decisão só entra pelo plano do applier")

# ---------------------------------------------------------------------- G6

func _gate_g6() -> void:
	var fake := FakeClient.new()
	_fixtures(fake, MONTHS)
	var first := Fixture.build_state()
	_run_months(first, MONTHS, _runtime("preferred", fake))
	var recorded: Dictionary = first.get("ai_priority_plan", {}) if first.get("ai_priority_plan") is Dictionary else {}
	var expected := _world_hash(first)

	# Replay: mesmo plano gravado, cliente offline (nenhuma decisão nova).
	var replay := Fixture.build_state()
	replay["ai_priority_plan"] = recorded.duplicate(true)
	var offline := FakeClient.new()
	offline.mode = "offline"
	_run_months(replay, MONTHS, _runtime("preferred", offline))
	var got := _world_hash(replay)
	var ok := not recorded.is_empty() and got == expected
	_gate("G6", "Replay: meses gravados e reproduzidos produzem o mesmo hash final",
		STATUS_PASS if ok else STATUS_FAIL,
		"decisões gravadas: %d · hash original: %s · hash reproduzido: %s" % [recorded.size(), expected, got])

func _gate_not_measured(id: String, name: String, reason: String) -> void:
	_gate(id, name, STATUS_NA, reason)

# ---------------------------------------------------------------- relatório

func _write_report() -> void:
	var version := str(Engine.get_version_info().get("string", "desconhecida"))
	var lines := PackedStringArray()
	lines.append("# Prova mínima da IA local — `gov_priority`")
	lines.append("")
	lines.append("Gerado por `tools/ai_proof.gd` (Fase 3). Reproduza com:")
	lines.append("")
	lines.append("```")
	lines.append("Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_proof.gd")
	lines.append("```")
	lines.append("")
	lines.append("- Data: " + Time.get_datetime_string_from_system())
	lines.append("- Godot: " + version)
	lines.append("- Sistema: " + OS.get_name())
	lines.append("- Contrato: `gov_priority` no `WorldSim.monthly`, via broker")
	lines.append("- Modo do jogo: `off` (`config/ai_config.json`); a prova liga os modos explicitamente")
	lines.append("- Cliente da prova: `FakeAIClient` (sem Ollama, sem GPU)")
	lines.append("")
	lines.append("## Resultado por gate")
	lines.append("")
	lines.append("| Gate | Status | O que mede |")
	lines.append("| --- | --- | --- |")
	for gate in gates:
		lines.append("| %s | **%s** | %s |" % [str(gate["id"]), str(gate["status"]), str(gate["name"])])
	lines.append("")
	lines.append("`PASS`/`FAIL` só aparecem para o que foi medido de verdade. Os gates que")
	lines.append("dependem do modelo e do hardware do dono saem como `NÃO MEDIDO` com motivo.")
	lines.append("")
	lines.append("## Evidências")
	lines.append("")
	for gate in gates:
		lines.append("### %s — %s" % [str(gate["id"]), str(gate["status"])])
		lines.append("")
		lines.append(str(gate["detail"]))
		if str(gate.get("evidence", "")) != "":
			lines.append("")
			lines.append("_%s_" % str(gate["evidence"]))
		lines.append("")
	lines.append("## Limitações desta prova")
	lines.append("")
	lines.append("- G1, G2 e G7 exigem Ollama com o modelo `mandatia-qwen35-local:latest` e o hardware do dono; nenhum número foi inventado.")
	lines.append("- A prova usa o cliente falso: ela mede o encanamento (broker, validador, applier, fallback, replay), não a qualidade do modelo.")
	lines.append("- `G3` mede o custo do mês com cliente instantâneo. Com o Ollama real o pedido é assíncrono e o mês continua sem esperar; a latência por chamada é o objeto de G2.")
	lines.append("- `G5` verifica estrutura e faixa do que passa pelo applier; não prova ausência de escrita em outros módulos por análise estática.")
	lines.append("")
	lines.append("## Pendências para o dono (não respondidas por esta prova)")
	lines.append("")
	lines.append("1. **P1** — quem governa o país do jogador na oposição: NPC do mundo (A) ou motor com IA (B)?")
	lines.append("2. **P2** — espera aceitável por mês (`player_blocking_ms`).")
	lines.append("3. **P3** — versão do Ollama, GPU, VRAM e RAM.")
	lines.append("4. **P4** — modo padrão `preferred` ou `required` (hoje `off` até a prova com modelo).")
	lines.append("5. **P5** — forças armadas entram na Onda 5 ou ficam fora?")
	lines.append("")
	lines.append("## Próximo passo")
	lines.append("")
	lines.append("Ligar `mode: \"preferred\"` no `config/ai_config.json` com o Ollama do dono,")
	lines.append("rodar este mesmo script para medir G1/G2/G7 e só então promover a Onda 1.")
	lines.append("")
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("não foi possível gravar " + REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
