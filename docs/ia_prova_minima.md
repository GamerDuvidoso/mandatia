# Prova mínima da IA local — `gov_priority`

Gerado por `tools/ai_proof.gd` (Fase 3). Reproduza com:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_proof.gd
```

- Data: 2026-11-24T21:28:32
- Godot: 4.7.2-stable (official)
- Sistema: Windows
- Contrato: `gov_priority` no `WorldSim.monthly`, via broker
- Modo do jogo: `off` (`config/ai_config.json`); a prova liga os modos explicitamente
- Cliente da prova: `FakeAIClient` (sem Ollama, sem GPU)

## Resultado por gate

| Gate | Status | O que mede |
| --- | --- | --- |
| G3 | **PASS** | Orçamento e tempo: nenhuma chamada bloqueante; orçamento mensal respeitado; sem espera ao avançar o mês |
| G4 | **PASS** | Fallback: 100% dos meses completam e o estado final é idêntico ao modo off |
| G5 | **PASS** | Integridade: decisão com origem, modelo, mês, validação e aplicação; nada fora de faixa no estado |
| G6 | **PASS** | Replay: meses gravados e reproduzidos produzem o mesmo hash final |
| G1 | **NÃO MEDIDO** | JSON válido (>=95% na 1ª; >=99% em até 2 tentativas; >=200 chamadas) |
| G2 | **NÃO MEDIDO** | Latência p50 <= 6 s e p95 <= 15 s; cena 3–4 atores p95 <= 25 s; timeouts <= 2% |
| G7 | **NÃO MEDIDO** | Sanidade: >=70% de 20 casos rotulados; nenhuma ação >60%; >=3 ações distintas; motivo cita variável do contexto em >=80% |

`PASS`/`FAIL` só aparecem para o que foi medido de verdade. Os gates que
dependem do modelo e do hardware do dono saem como `NÃO MEDIDO` com motivo.

## Evidências

### G3 — PASS

chamadas no último mês: 40 (teto 40) · meses concluídos: 12/12 (off) e 12/12 (IA) · custo do mês: 23.7 ms (off) vs 86.3 ms (IA), extra 62.7 ms/mês (teto 100)

_chamadas bloqueantes: 0 — a prioridade do mês é decidida em segundo plano e aplicada no mês seguinte_

### G4 — PASS

timeout: 12/12 meses, estado idêntico; invalid: 12/12 meses, estado idêntico; empty: 12/12 meses, estado idêntico; offline: 12/12 meses, estado idêntico

_hash de referência (modo off): 93507850_

### G5 — PASS

decisões registradas: 41 · com todos os campos: 41 · aplicadas pelo applier: 41 · clamps dentro da faixa: 41 · prioridades válidas no mundo: sim

_nenhum sistema escreve prioridade fora de autonomous_government.monthly: a decisão só entra pelo plano do applier_

### G6 — PASS

decisões gravadas: 42 · hash original: 173553865 · hash reproduzido: 173553865

### G1 — NÃO MEDIDO

exige o modelo real: offline não existe saída do modelo para medir taxa de JSON válido. O validador e o reparo por segunda tentativa estão cobertos em test/test_ai_layer.gd.

### G2 — NÃO MEDIDO

depende do hardware e do modelo do dono (o repo mediu 7–28 s com modelo de 3B). O caminho assíncrono/preparado é medido em G3; a latência em si não é mensurável sem Ollama.

### G7 — NÃO MEDIDO

depende de 20 casos rotulados ANTES da medição e das saídas reais do modelo; sem modelo não há amostra válida.

## Limitações desta prova

- G1, G2 e G7 exigem Ollama com o modelo `mandatia-qwen35-local:latest` e o hardware do dono; nenhum número foi inventado.
- A prova usa o cliente falso: ela mede o encanamento (broker, validador, applier, fallback, replay), não a qualidade do modelo.
- `G3` mede o custo do mês com cliente instantâneo. Com o Ollama real o pedido é assíncrono e o mês continua sem esperar; a latência por chamada é o objeto de G2.
- `G5` verifica estrutura e faixa do que passa pelo applier; não prova ausência de escrita em outros módulos por análise estática.

## Pendências para o dono (não respondidas por esta prova)

1. **P1** — quem governa o país do jogador na oposição: NPC do mundo (A) ou motor com IA (B)?
2. **P2** — espera aceitável por mês (`player_blocking_ms`).
3. **P3** — versão do Ollama, GPU, VRAM e RAM.
4. **P4** — modo padrão `preferred` ou `required` (hoje `off` até a prova com modelo).
5. **P5** — forças armadas entram na Onda 5 ou ficam fora?

## Próximo passo

Ligar `mode: "preferred"` no `config/ai_config.json` com o Ollama do dono,
rodar este mesmo script para medir G1/G2/G7 e só então promover a Onda 1.
