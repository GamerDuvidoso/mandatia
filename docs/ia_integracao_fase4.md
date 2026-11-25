# Integração da IA local — Fase 4 (ondas 2 e 3: os cinco atores novos)

Data: 2026-11-25 · Godot 4.7.2 · branch `melhorias-mecanicas` · modo padrão `off`

## Escopo entregue

A Fase 4 do plano por fases (`prompt_integracao_ia_local_v2.txt`, seção 15) cria os
módulos que não existiam no código: mercado, banco central, judiciário, executivo
NPC e mídia. Cada um segue o padrão de ator do projeto (`ensure` / `monthly` /
`summary`), com config JSON próprio, contrato no catálogo e contingência
determinística do motor.

**A IA decide o quê; o motor calcula quanto e valida.** Nenhum módulo novo
escreve estado a partir da decisão: as funções `apply_*` apenas normalizam a
decisão validada e devolvem um override; quem converte em número é o `monthly` do
próprio módulo, com clamps.

## Ordem causal do mês (seção 7)

`WorldSim.monthly`, por país NPC:

1. choques globais — `global_shock_system` já roda fora deste laço (onda 3 futura)
2. **mercado** (`market_system`) e **banco central** (`central_bank`)
3. **mídia** (`media_system`) — fixa o enquadramento do mês
4. **executivo NPC** (`executive_npc`) e governo (`autonomous_government`)
5. economia do país, partidos e legislativo
6. **mídia** fecha o mês (consequência sobre aprovação e estabilidade)
7. **judiciário** (`judiciary_system`)
8. política externa e calendário eleitoral

O fato notável de cada ator é publicado pelo `world_sim` (os módulos não conhecem
o histórico do mundo), o que mantém a trilha causal no `causal_log`.

## Arquivos

### Criados

| Arquivo | Papel |
| --- | --- |
| `scripts/sim/market_system.gd` | A6 — sentimento, prêmio de risco, câmbio, fluxo de capital, decisão das empresas |
| `scripts/sim/central_bank.gd` | A7 — movimento da taxa e postura; o motor aplica a taxa |
| `scripts/sim/judiciary_system.gd` | A5 — julga lei contestada; só efeito procedimental, nunca votos ou cadeiras |
| `scripts/sim/executive_npc.gd` | A2 — sancionar, vetar, decretar, nomear, demitir, coalizão, discurso, oposição |
| `scripts/sim/media_system.gd` | A9 — enquadramento e viés; publica o multiplicador de exposição |
| `config/market.json`, `central_bank.json`, `judiciary.json`, `executive.json`, `media.json` | parâmetros de cada ator |
| `test/test_ai_fase4.gd` | prova da fase (31 checks) |

### Alterados

| Arquivo | Mudança |
| --- | --- |
| `scripts/sim/world_sim.gd` | ordem causal com os cinco atores; publicação do fato do módulo |
| `scripts/ai/ai_runtime.gd` | `decide_actor` genérico (plano do mês seguinte, validação, applier, whitelist) + cota por contrato |
| `config/ai_config.json` | `budget.per_contract`: 14 `gov_priority`, 6 mercado, 6 banco central, 6 executivo, 4 mídia, 4 judiciário (soma 40) |
| `test/test_ai_wiring.gd` | oráculo congelado passa a ser o laço da Fase 4 sem IA |

`decision_applier.gd`, `decision_validator.gd` e `ai_catalog.json` já tinham os
cinco contratos desde a Fase 1 — não precisaram mudar.

## Contratos e contingência

| Contrato | Contingência (motor) | Efeito no estado |
| --- | --- | --- |
| `market_mood` | humor por dívida, inflação, atividade e hash país+mês; prêmio e câmbio saem daí | prêmio → crescimento; câmbio → inflação; prêmio alto → dívida |
| `central_bank` | reação determinística ao hiato de inflação e atividade, com banda morta de 25 p.b. | taxa acima da neutra reduz crescimento e inflação |
| `executive_action` | veto só se o projeto passou, com 22% de chance determinística; senão sanção, discurso ou decreto | sanção/veto, estabilidade, coesão; veto devolve metade do impulso da lei |
| `court_ruling` | maioria estreita suspende a lei; maioria estável confirma | suspensão devolve metade do impulso da lei; investigação custa aprovação |
| `media_coverage` | enquadramento deduzido dos números (crise, segurança, eleição, entrega, rotina) | viés pressiona aprovação e estabilidade |

Regras de coerência que o motor impõe mesmo com decisão válida da IA:

- veto ou sanção exigem o projeto aprovado **no mês**, como `target_id`;
- o tribunal só julga caso aberto (lei contestada no mês da aprovação);
- o banco central não sobe juros sem motivo registrado (validador);
- mercado não pode estar eufórico com saída de capital (validador).

## Cota mensal

Com 34 países e seis contratos, um orçamento único de 40 chamadas seria consumido
pelos primeiros atores da fila. `AiRuntime` aplica `budget.per_contract` e fixa o
mês do broker antes do primeiro submit — sem isso o `set_month` zerava o contador
no meio do laço e o mês estourava o orçamento (defeito encontrado e corrigido
nesta fase).

## Testes executados

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_fase4.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_wiring.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script test/test_ai_layer.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://test/test_suite.tscn
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/ai_proof.gd
```

| Comando | Resultado |
| --- | --- |
| `test_ai_fase4.gd` | **31 checks, 0 falhas** — modo off, determinismo, aplicação de mercado/banco central/mídia, veto sem projeto recusado, caso inexistente recusado, G4 com cliente inválido/vazio/offline |
| `test_ai_wiring.gd` | **24 checks, 0 falhas** — modo off idêntico ao laço do motor sem IA |
| `test_ai_layer.gd` | **107 checks, 0 falhas** |
| `test_suite.tscn` | **PASS: 418 checks** (inalterado); mundo de 240 meses em 5,6 s |
| `tools/ai_proof.gd` | G3, G4, G5, G6 **PASS**; G1, G2, G7 **NÃO MEDIDO** (exigem Ollama/modelo) |

`docs/ia_prova_minima.md` foi regenerado. G3 agora reporta 40 chamadas no mês
(teto 40), porque os seis contratos dividem o mesmo orçamento; o custo extra do
mês com cliente instantâneo foi de 62,7 ms (teto 100 ms).

## Limitações

- **Atores da onda 2/3 ainda em contingência**: `public_mood`, `party_leadership`,
  `chamber_leadership`, `legislative_agenda` e `global_event` não foram ligados
  nesta fase — dependem de `social_groups`, `interest_groups`,
  `autonomous_legislature` e `global_shock_system`, que já existiam e ficam para
  a próxima entrega. Os cinco módulos novos são exatamente os que não existiam.
- **País do jogador continua fora** do laço autônomo: o executivo NPC governa só
  os 34 países NPC. Quem governa o país do jogador na oposição é a pendência P1.
- **Mídia e escândalo**: o multiplicador de exposição está publicado em
  `media_system.exposure()`, mas o `scandal_system` só vai consumi-lo na onda 4.
- **Judiciário**: julga lei contestada. Disputa eleitoral e legalidade de greve
  entram na onda 4, quando `conflict_system` e `interest_groups` estiverem ligados.
- **UI**: o indicador "Mente do jogo" e a tela de Configurações seguem na Fase 7.
- **G1, G2 e G7 não foram medidos**: exigem o modelo real e o hardware do dono.
  Nenhum número foi inventado.
- As cotas por contrato não giram entre meses: os mesmos países tendem a receber
  decisão de IA. Rotação determinística fica para a Fase 6 (otimização).

## Pendências para o dono

P1–P5 foram respondidas e integradas em `docs/ia_decisoes_p1_p5.md`: o governo
do país do jogador na oposição virou NPC decidido pela IA (mantendo o livro-caixa
único), o mês não espera a rede, o modo padrão passou a `preferred` e as forças
armadas ficaram como contrato opcional da onda 5. O runtime do mundo agora é
ligado ao cliente Ollama no `main.gd`.
