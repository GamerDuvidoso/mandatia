# Integração da IA local — Fase 3

Referência: `prompt_integracao_ia_local_v2.txt` (seções 2, 5, 7, 9, 13 e 15).
Base: Fases 1 e 2 (ver `docs/ia_integracao_fase1.md`).

## O que mudou

`gov_priority` deixou de ser só uma entrada de catálogo: o `WorldSim.monthly`
agora pede a prioridade de cada país NPC à camada de decisão em todo tick. O
caminho é único — motor, contingência e IA passam pelo mesmo ponto:

```
WorldSim.monthly(st, countries, economy, runtime = null)
   └─ AiRuntime.decide_gov_priority(...)
        ├─ modo "off"  → devolve {}  (regra do motor, comportamento anterior)
        └─ modo com IA → decide...
             ├─ plano do mês já preparado?
             │    ├─ decision_validator.valida (enum, faixa, coerência)
             │    ├─ decision_applier monta o plano de chamada
             │    ├─ AutonomousGovernment.priority_override executa
             │    └─ training_export registra no save (origem, modelo, mês, validação)
             └─ sem plano → broker.submit + flush pede a decisão do PRÓXIMO mês
                            e usa a contingência neste (nunca espera a rede)
```

O modo padrão é `off` em `config/ai_config.json`. O jogo (main.gd) não passa
runtime, então usa o runtime padrão criado uma vez por processo: `off`, sem
broker, sem cliente, sem tocar em `state`.

## Arquivos criados

| Arquivo | Papel |
| --- | --- |
| `scripts/ai/ai_runtime.gd` | runtime: modo, broker, plano do mês seguinte, validação, aplicação e registro |
| `test/world_fixture.gd` | estado de mundo mínimo e determinístico (34 países NPC) para testes e prova |
| `test/test_ai_wiring.gd` | prova `off` == comportamento anterior + via da IA (24 checks) |
| `tools/ai_proof.gd` | gates G1–G7, relatório em `docs/ia_prova_minima.md` |
| `docs/ia_prova_minima.md` | relatório gerado pela prova |

## Arquivos alterados

| Arquivo | Mudança |
| --- | --- |
| `scripts/sim/world_sim.gd` | `monthly(..., runtime = null)`; resolve o runtime e passa o override ao governo |
| `scripts/sim/autonomous_government.gd` | `monthly(..., override = {})` com ação/intensidade forçadas e `priority_override()` |
| `scripts/ai/decision_applier.gd` | destino de `gov_priority` passou a `autonomous_government.priority_override` |
| `config/ai_config.json` | `mode` de `preferred` para `off` (Onda 1 desligada até a prova com modelo) |

## Prova de que `off` é idêntico ao anterior

`test/test_ai_wiring.gd` guarda um **oráculo congelado**: a cópia exata do laço
de `WorldSim.monthly` do commit `d77f356` (antes do fio). Dois estados idênticos
avançam 12 meses — um pelo oráculo, outro pelo `monthly` real com runtime em
`off` — e são comparados recursivamente (tipo, chaves, ordem das chaves, listas
e valores). O teste falha na primeira divergência e imprime o caminho da chave
(ex.: `state.world.countries.AR.approval: 43.1 != 43.2`).

Também verifica que, em `off`, o cliente de IA não é chamado e o estado não
ganha `ai_priority_plan`, `ai_decision_log` nem `ai_memory`.

## Prova de que a IA age (e não escreve direto)

Com `mode: "preferred"` e cliente falso:

- mês 1: 34 pedidos ao broker, dentro do orçamento; respostas viram plano;
- mês 2: cada plano passa por validador + applier; o país fica com a prioridade
  decidida (`austeridade`, que o motor quase nunca escolhe) — e o número de
  países nessa prioridade é maior que no mesmo mês em `off`;
- plano envenenado (`action: "guerra_total"`) é rejeitado: nada chega ao estado
  e a rejeição fica registrada no log.

## Prova mínima (`tools/ai_proof.gd`)

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_proof.gd
```

Resultado desta execução (2026-11-24, Godot 4.7.2, Windows, sem Ollama):

| Gate | Status | Evidência |
| --- | --- | --- |
| G3 orçamento/tempo | **PASS** | 33 chamadas no último mês (teto 40); 12/12 meses; 8,8 ms (off) vs 16,0 ms (IA) → +7,3 ms/mês (teto 100) |
| G4 fallback | **PASS** | timeout, JSON inválido, resposta vazia e Ollama desligado: 12/12 meses e hash final igual ao `off` |
| G5 integridade | **PASS** | todas as decisões com origem, modelo, mês, validação e aplicação; nada fora de faixa no mundo |
| G6 replay | **PASS** | plano gravado reproduzido com cliente offline → mesmo hash final |
| G1 JSON válido | **NÃO MEDIDO** | exige modelo real e 200 chamadas |
| G2 latência | **NÃO MEDIDO** | depende do hardware/modelo do dono |
| G7 sanidade | **NÃO MEDIDO** | exige 20 casos rotulados com saídas do modelo |

Os gates não medidos nunca saem como PASS: o relatório grava o motivo.

## Testes executados

```
--script test/test_ai_wiring.gd     → 24 checks, 0 falhas, PASS
--script test/test_ai_layer.gd      → 107 checks, 0 falhas, PASS
res://test/test_suite.tscn          → 418 checks, PASS
--script tools/ai_proof.gd          → G3/G4/G5/G6 PASS; G1/G2/G7 NÃO MEDIDO
```

## Limitações declaradas

- A prova usa `FakeAIClient`: mede o encanamento (broker, validador, applier,
  fallback, replay), não a qualidade do modelo.
- `intensity` do `gov_priority` escala apenas o efeito de aprovação; o impulso
  fiscal continua sendo o da prioridade escolhida. Refinar isso é trabalho de
  balanceamento da Onda 1, não deste fio.
- O broker faz um pedido por país NPC (até 34/mês). O catálogo já declara
  `batch.by = "region", size = 4`; usar lotes de região é otimização de G3/G2,
  deliberadamente fora desta fase.
- `main.gd` continua sem passar runtime: com `mode: "off"` nada muda; ao ligar
  o modo, o jogo passa a usar o runtime padrão automaticamente.

## Pendências para o dono (P1–P5, não respondidas aqui)

1. **P1** — jogador na oposição: governo do país dele vira NPC do mundo (A) ou
   continua no motor com decisões da IA (B)? Muda `world_sim.gd` e o `executive_npc`.
2. **P2** — espera aceitável por mês (`player_blocking_ms`; hoje 25 s).
3. **P3** — versão do Ollama, GPU, VRAM e RAM.
4. **P4** — modo padrão `preferred` ou `required` (hoje `off`).
5. **P5** — forças armadas entram na Onda 5 ou ficam fora?

Nenhum módulo da Onda 1 (`executive_npc`, `market_system`, `central_bank`,
`judiciary_system`, `media_system`) foi criado nesta fase.
