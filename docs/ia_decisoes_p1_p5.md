# Decisões pendentes P1–P5 — respostas e integração

Data: 2026-11-25 · Godot 4.7.2 · branch `melhorias-mecanicas`

Norma aplicada em todas as respostas (seção 1 do
`prompt_integracao_ia_local_v2.txt`): **a IA decide o que acontece; o motor
calcula quanto e valida; o motor aplica.** Nenhuma resposta abaixo move
aritmética (D'Hondt, livro-caixa, dívida como estoque, população, datas,
clamps, IDs, save, seeds) para o modelo.

## P1 — Quem governa o país do jogador na oposição?

**Resposta: Opção A — o governo vira NPC decidido pela IA.** O país do jogador
deixa de ser um ponto inerte do mundo quando o jogador perde a eleição. A
prioridade de governo (A1, `gov_priority`) e a ação do chefe do executivo (A2,
`executive_action`) passam pelo runtime de IA com a mesma regra dos 34 países
NPC: plano do mês seguinte, validação e aplicação por whitelist; sem decisão
pronta, a contingência do motor governa.

**Salvaguarda de contabilidade:** o país do jogador **não** entra em
`world.countries` e não ganha uma segunda cópia de PIB, inflação, desemprego ou
dívida. O NPC usa o estado do jogador como fonte macro e devolve ao save apenas
o que o jogador compartilha com o governo: **aprovação do governo** (que move a
popularidade da oposição) e **dívida** (custo do decreto, com clamp do motor).
O resumo do mês fica em `state.opposition_government` (campo aditivo; saves
antigos ganham a chave na primeira execução).

Integração:

- `WorldSim.player_opposition_month(st, countries, economy, runtime)` em
  `scripts/sim/world_sim.gd`;
- chamada em `main.gd::_advance_month` logo depois do `WorldSim.monthly`;
- idempotência por `last_tick`; nada roda quando `state.government == true`;
- desligável em `config/ai_config.json` → `player_opposition.npc_government`.

## P2 — Espera aceitável do jogador por mês?

**Resposta: 0 ms extra ao avançar o mês; 25 s só em decisão bloqueante
disparada por ação do jogador.**

- O turno do mundo é pré-calculado em segundo plano (1 mês à frente). O mês
  nunca espera a rede: `player_blocking_ms` (25 000) vale para o que o jogador
  pediu naquele instante — eleição, votação, evento.
- `OllamaClient.pending_blocking_count()` separa as operações de fundo
  (`meta.background = true`, marcadas pelo runtime) das bloqueantes; o botão de
  avançar mês só espera as bloqueantes.
- Requisito G3 preservado: 0 s extra ao concluir o mês.

## P3 — Ollama e hardware?

**Resposta: baseline já medida no repositório, sem inventar hardware.** O
`docs/eval_report.json` registra o modelo de 3B com 7,2 s a 28 s por chamada.
Mantidos `mandatia-qwen35-local:latest`, `timeout_ms` de 20 s, `max_parallel: 2`,
`think: false` e `echo` desligado (`strip_tags: ["think"]`). A medição de G1,
G2 e G7 depende da GPU/VRAM/RAM do dono e continua como **NÃO MEDIDO**; o
comando é `tools/ai_proof.gd` com o Ollama no ar. Nenhum número de hardware foi
inventado.

## P4 — Modo padrão?

**Resposta: `preferred`.** A IA decide sempre que o modelo responde; quando
não responde (timeout, JSON inválido, Ollama desligado), a contingência do
motor assume e o mês completa idêntico ao modo `off` (G4). `required` foi
rejeitado: quebraria o jogo sem Ollama e contrariaria a regra de confiabilidade
da seção 2(c). Testes e provas continuam passando runtime `off` explícito
quando precisam do comportamento determinístico.

Integração: `config/ai_config.json` → `"mode": "preferred"`; o runtime do mundo
é criado em `main.gd` com o mesmo cliente Ollama do jogo
(`AiRuntime.new(AiRuntime.default_config(), ai)`), e o cliente passou a atender
os contratos do catálogo (prompt curto com schema/regra, validação pelo
`decision_validator`, contingência devolvida vazia para o runtime ignorar).

## P5 — Forças armadas?

**Resposta: entram na Onda 5, opcional e depois de todas as ondas 1–4
passarem.** A seção 2 diz que atores são ordenados, não cortados; o contrato
`armed_forces_stance` já existe no catálogo (`tier: 5`, `optional: true`) e no
validador/applier. Nenhum módulo de forças armadas foi criado nesta entrega:
ele só entra com estágios e gatilhos explícitos, sem narrativa gráfica, e
depende da prova das ondas anteriores.

## Arquivos alterados nesta integração

| Arquivo | Mudança |
| --- | --- |
| `config/ai_config.json` | `mode: preferred`; bloco `player_opposition.npc_government` |
| `config/ai_catalog.json` | `schema` e `rules` dos seis contratos ligados (governo, executivo, judiciário, mercado, banco central, mídia) |
| `scripts/sim/world_sim.gd` | `player_opposition_month` + resumo persistido |
| `scripts/ai/ai_runtime.gd` | meta `background: true` nas decisões de fundo |
| `scripts/ai/ollama_client.gd` | prompt/validação dos contratos do catálogo; `pending_blocking_count` |
| `scripts/main.gd` | runtime do mundo ligado ao Ollama; governo NPC na oposição; guarda do mês só com operações bloqueantes |
| `test/test_player_opposition.gd` | prova da P1 (11 checks) |

## Limitações

- A prova com modelo real (G1/G2/G7) continua dependendo do hardware do dono.
- O NPC da oposição governa prioridade e executivo; partidos e legislativo do
  país do jogador continuam sendo o fluxo do próprio jogo (não há segundo
  Congresso).
- Forças armadas seguem como contrato opcional sem módulo.
