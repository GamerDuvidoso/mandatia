# Fase F — auditoria e status incremental

## Escopo desta entrega

Esta entrega implementa a fundação incremental da Fase F. Ela não declara a Fase F completa. O objetivo foi criar uma única camada derivada de informação, preservando as fontes de verdade existentes e evitando uma segunda simulação política.

## Fontes de verdade reutilizadas

| Recurso | Fonte existente | Uso na camada Fase F |
|---|---|---|
| Fatos internacionais | `state.world.history`, produzido por `world_sim.gd` e `world_history.gd` | Arquivo histórico e artigos |
| Conjuntura nacional | `state.event`, `event_id`, `month_factors` | Artigo local rastreável ao mês e ao evento |
| Causalidade | `state.causal_log`, `causal_log.gd` | Evidências compatíveis são anexadas a artigos e relatórios sem recalcular efeitos |
| Alegações e investigações | `state.scandals`, `scandal_history`, `scandal_system.gd` | Cada etapa do caso é indexada editorialmente, com categoria e status jurídico separados |
| Indicadores econômicos | `state.economy`, `inflation`, `unemployment`, `debt` e `economic_profile` | Fatos observados dos relatórios |
| Governo e coalizão | `state.government`, `coalition_*`, `Government`, `PoliticalRelations` | Biografia atual e relatório de estabilidade |
| Líderes e ministros | `state.leader`, `state.party`, `state.ministers` / `ministry_admin` | Perfis políticos marcados como “simulação” |
| Atores autônomos | `state.world.countries.*.parties`, `world.history` | Líderes partidários autônomos com cargo atual e trajetória derivada de eleições, governos e liderança |
| Persistência | `_save_game`, `_migrate_state`, saves versionados | `phase_f` é adicionado por `ensure`, sem invalidar saves antigos |

## Contrato introduzido

Arquivo: `scripts/sim/phase_f_information.gd`

O bloco persistente `state.phase_f` contém:

- `articles`: artigos com `source_id`, `source_type`, veículo, enquadramento, base factual, atores, consequências e status de certeza.
- `archive`: registros históricos deduplicados por `source_id`.
- `biographies`: perfis derivados do líder e do gabinete, identificados como `kind: simulação`.
- `encyclopedia`: entradas atuais de país, partido e governo, sempre derivadas do estado.
- `polls`: estimativas simuladas com organização identificável, amostra, método, pergunta, margem de erro, indecisos e data de campo/publicação.
- `reports`: boletins com fatos observados, estimativas, interpretações, projeção condicional, confiança, premissas, limitações e nível de acesso.
- `last_tick`: carimbo mensal de atualização.

Os artigos de diferentes veículos compartilham o mesmo `source_id` e a mesma base factual, mas variam apenas em `frame`. Nenhum artigo é criado sem evento de simulação.

## Regras implementadas

1. Quatro veículos simulados têm características identificáveis; nenhum veículo real é usado com reputação inventada.
2. Artigos são derivados de `world.history` ou do evento nacional armazenado no estado.
3. O arquivo histórico tem limites de tamanho e deduplicação.
4. Enquetes são determinísticas para país/mês, têm incerteza amostral e não expõem o valor subjacente exato.
5. Relatórios distinguem fatos, estimativas e projeções condicionais.
6. A atualização é mensal e idempotente; abrir uma tela não recalcula a simulação.
7. `PhaseFInformation.ensure(state)` é chamado na criação, migração e carregamento lógico do estado.
8. A atualização da Fase F ocorre antes do salvamento do mês concluído.
9. Ollama não é dependência da camada nova.
10. Alegações, investigações, desfechos e casos sem conclusão geram eventos editoriais rastreáveis por caso, mês e estágio.
11. Artigos e relatórios preservam registros compatíveis do `causal_log`, incluindo causa, efeitos e explicação.
12. Biografias autônomas são derivadas de líderes partidários, situação no governo, mudanças de liderança e eventos históricos com o partido como ator.
13. Biografias ministeriais registram nomeação, permanência, saída do gabinete e retorno, preservando strings legadas.
14. A enciclopédia deriva países, partidos autônomos, leis, organizações, tratados e conceitos econômicos com fonte identificada.
15. Pesquisas preservam série curta, média móvel e segmentos geográficos mutuamente exclusivos cuja soma é a amostra total.
16. O detalhe editorial oferece navegação para evento, ator, partido, país, indicadores, causalidade, história e enciclopédia.

## Arquivos modificados ou criados

- `scripts/sim/phase_f_information.gd` — camada derivada, indexação editorial de escândalos e investigações e evidência causal.
- `scripts/main.gd` — preload, inicialização/migração, atualização mensal, newsroom com filtros/busca/detalhe e exibição do arquivo na tela História.
- `test/test_phase_f_information.gd` — teste curto isolado, sem a suíte longa.
- `test/test_phase_f_scenarios.gd` — cenários curtos de eleição, liderança e investigação.
- `docs/fase_f_auditoria_status.md` — este registro.

## Validação

- Suíte completa: **não executada**, conforme solicitação do usuário.
- Teste curto da Fase F: criado, mas a execução headless foi bloqueada pelo ambiente local com `terminal: config home unavailable`.
- A verificação realizada nesta sessão foi leitura estrutural dos arquivos escritos e dos pontos de integração.

### Tarefas incrementais

| Tarefa | Escopo | Status |
|---|---|---|
| 2 | Escândalos, alegações e investigações | Implementada; cobertura por estágio e status jurídico separado |
| 3 | `causal_log` | Implementada; evidência em artigos, arquivo e relatórios |
| 4 | Biografias | Implementada; atores autônomos e nomeação/saída ministerial |
| 5 | Enciclopédia | Implementada; tela e entradas derivadas ampliadas |
| 6 | Pesquisas | Implementada; média móvel, série e segmentos sem dupla contagem |
| 7 | Navegação contextual | Implementada; newsroom, perfis, país, história, indicadores e enciclopédia |
| 8 | Testes direcionados | Implementada; teste contratual e cenário curto separado |
| 9 | Auditoria incremental | Implementada; este documento atualizado sem declarar conclusão total |

## Limitações atuais

Ainda não estão completas nesta entrega: biografias de chefes de Estado fora dos partidos catalogados, segmentação demográfica mais detalhada além dos três segmentos geográficos, controle refinado de acesso de inteligência, correspondência causal para eventos sem registro compatível e validação headless efetiva.

## Próxima etapa recomendada

Expandir a enciclopédia e depois cobrir casos de eleição, reforma, troca de ministro, investigação sem desfecho, crise internacional e mudança de liderança com testes curtos independentes.
