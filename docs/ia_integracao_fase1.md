# Integração da IA local — Fase 1 e Fase 2

Referência: `prompt_integracao_ia_local_v2.txt` (seções 5, 6, 8, 12, 13 e 15).
Base verificada: branch `melhorias-mecanicas`, commit `d77f356`.

## O que foi entregue

**Fase 1 — infraestrutura, sem mudar comportamento.**
Camada única entre os sistemas do jogo e o cliente do Ollama. Nenhum sistema
fala HTTP; nenhum módulo novo está ligado ao `main.gd` ainda, então o jogo roda
exatamente como antes.

**Fase 2 — catálogo como fonte dos quatro contratos antigos.**
`config/ai_catalog.json` passa a declarar `max_tokens` por contrato e o
`ollama_client.gd` lê esse valor. O texto de prompt dos contratos antigos não
mudou; a equivalência é provada por fixture (abaixo).

## Arquivos criados

| Arquivo | Papel |
| --- | --- |
| `config/ai_config.json` | modo, endpoint, modelo ativo, orçamento, paralelismo, replay, log, export de treino |
| `config/ai_models.json` | perfis por modelo (contexto, JSON mode, temperatura, seed, raciocínio desligado) |
| `config/ai_catalog.json` | 26 contratos: 4 antigos + os atores das ondas 1–5 |
| `config/ai_personas.json` | personas de governo, oposição, banco central, mídia e mercado |
| `scripts/ai/decision_catalog.gd` | leitura do catálogo; padrões iguais aos antigos se o JSON faltar |
| `scripts/ai/context_builder.gd` | contexto compacto (~600 tokens), arredondamento, faixas, `month_facts`, corte |
| `scripts/ai/decision_validator.gd` | schema, enum, ID, faixa com clamp registrado, coerência entre atores, `event_v2`, regra de placeholders |
| `scripts/ai/decision_applier.gd` | traduz decisão validada em plano de chamadas; diff; registro da seção 6.3 |
| `scripts/ai/ai_memory.gd` | memória curta por ator em `state.ai_memory` (persiste no save) |
| `scripts/ai/training_export.gd` | log no save + coleta `user://ai_dataset/<contrato>.jsonl` (seção 8.1) |
| `scripts/ai/decision_broker.gd` | fila por prioridade, orçamento mensal, paralelismo, hash e pré-cálculo do mês |
| `test/fake_ai_client.gd` | cliente falso determinístico (`valid`, `invalid`, `empty`, `timeout`, `offline`) |
| `test/test_ai_layer.gd` | teste headless da camada (107 checks) |
| `test/fixtures/ai_prompt_cases.json` | prompts congelados dos 4 contratos antigos |
| `tools/ai_prompt_snapshot.gd` | regenera o fixture acima |

## Arquivo alterado

`scripts/ai/ollama_client.gd`: `_max_tokens()` passa a delegar para
`decision_catalog.max_tokens()`. Os valores do catálogo são idênticos aos que
estavam no `match` anterior (legislative 720, electoral 400, international 480,
padrão 220), então o comportamento não muda.

## Testes executados

```
# camada nova
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_layer.gd
=== camada de IA: 107 checks, 0 falhas ===
PASS

# regressão do jogo
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://test/test_suite.tscn
[game-generic-tests] PASS: 418 checks
```

O `test_ai_layer.gd` cobre: catálogo e equivalência de tokens; prompt dos 4
contratos contra o fixture; contexto compacto, faixas, sanitização e corte por
orçamento; validador (enum, clamp registrado, chave inesperada, campo ausente,
delegação do legislativo, `event_v2` com 3 opções/dominância/custo, notícia com
placeholder e com número literal, coerência de banco central e mercado);
aplicador (plano, destino, diff, registro); memória (dedupe, teto, persona,
persistência); registro (dataset só com decisão válida, log com contingência);
broker (fila por prioridade, orçamento, renovação por mês, paralelismo com
cliente assíncrono, hash estável, pré-cálculo descartado quando o estado muda);
cliente falso (fixture, timeout, offline).

## Limitações declaradas

- O broker **não está ligado** ao `main.gd`. Isso é intencional na Fase 1: a
  ligação acontece no ator correspondente (Onda 1 em diante).
- Os atores novos estão **declarados** no catálogo, mas os módulos
  (`executive_npc.gd`, `market_system.gd`, `central_bank.gd`,
  `judiciary_system.gd`, `media_system.gd`) ainda não existem. O aplicador já
  aponta o destino de cada contrato.
- A prova mínima (gates G1–G7, seção 9) **não foi medida**: exige Ollama com o
  modelo instalado e hardware do dono. Nenhum contrato novo entra em produção
  antes disso.
- O fixture de prompt guarda o contexto com as chaves ordenadas (o parser JSON
  do Godot reordena). É um retrato fiel do conteúdo do prompt, não da ordem de
  inserção usada em tempo de execução — que continua intocada.
- Os logs de RID/ObjectDB no fim da suíte são ruído de encerramento do motor,
  já presentes antes desta mudança.

## Pendências e perguntas ao dono (seção 10)

1. **P1** — quando o jogador está na oposição, o governo do país dele vira NPC
   do mundo (A) ou continua no motor com decisões da IA (B)? Muda
   `world_sim.gd` e o `executive_npc`.
2. **P2** — orçamento aceitável de espera por mês (`player_blocking_ms`).
3. **P3** — versão do Ollama, GPU, VRAM e RAM (define paralelismo e se o
   raciocínio pode ficar desligado).
4. **P4** — modo padrão `preferred` (atual) ou `required`.
5. **P5** — forças armadas entram na Onda 5 ou ficam fora?

## Próxima fase recomendada

**Fase 3 — Onda 1**: ligar `gov_priority` ao `world_sim.monthly` pelo broker,
atrás do modo `off` (contingência = `autonomous_government.choose_priority`),
com `tools/ai_proof.gd` medindo G1–G7 em 200 chamadas por contrato. Sem Ollama,
o teste roda em `off` e prova G4 (fallback idêntico ao motor).
