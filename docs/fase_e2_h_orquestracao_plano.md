# Plano orquestrado superior — E2 até a última tarefa H

**Status geral:** E2, F, G e H permanecem parciais; nenhuma dessas frentes deve ser declarada concluída sem validação dinâmica, migração, proveniência, integração mensal e testes de horizonte quando aplicável.

## Síntese executiva

A auditoria paralela confirmou implementação real de partes de E2, F, G1 e da base eleitoral/campanha, mas também encontrou lacunas e defeitos de integração. A prioridade segura é estabilizar contratos e o fechamento mensal antes de ampliar os módulos sociais e partidários.

O primeiro defeito funcional é o fluxo de `conflict_system.gd` que deixa o tick de guerra inalcançável após a transição para hostilidades. Também existem `threat=0.0` na chamada militar, manutenção pós-entrega não cobrada, ausência de contrato versionado próprio para E2 e inexistência de testes específicos E2.

A migração forçada/humanitária E2 permanece bloqueada para integração demográfica: o código possui `displaced`, `hosted` e ajuda, mas não há contrato com classificação, origem, destino, `flow_id`, reconciliação e deduplicação. `state.demography` continua sendo a única população-base.

A Fase F possui uma camada editorial derivada robusta, mas ainda precisa de proveniência uniforme, histórico jurídico por etapa, IDs causais, retenção e teste explícito de isolamento entre campanha paga e jornalismo independente.

A Fase G possui G1 e o envelope `phase_g`, mas G6 e G2–G7 continuam pendentes. O fechamento atual calcula relatório e grava `month_completed` antes de terminar G1, G e Fase F; isso deve ser corrigido antes da integração social.

A Fase H possui limite de três ações, D’Hondt, segundo turno, modelos presidencial/parlamentar e coalizões. Ainda existem divergência entre mandato documentado de 60 meses no parlamentarismo e `TERM_MONTHS=48`, avanço anual fixo após eleição, validação insuficiente de shares de IA e ausência de contratos executáveis H1–H5.

## Ordem de implementação

1. Corrigir o fluxo de `_war_tick` e criar regressão E2 de múltiplos meses.
2. Criar contrato versionado persistente para `state.geopolitics`/E2, com migração aditiva e `last_tick`.
3. Definir o contrato E2/E de fluxos forçados; manter sua integração demográfica bloqueada até origem, destino, categoria e deduplicação existirem.
4. Corrigir o fechamento mensal: relatório e `month_completed` somente depois de todos os sistemas; falha intermediária não pode aparentar fechamento concluído.
5. Reforçar migração G1/`phase_g`, normalizar proveniência e testar save/load.
6. Implementar G6 territorial: oito IDs estáveis, pesos normalizados, população regional derivada e reconciliação nacional.
7. Implementar G2 saúde e G3 educação com capacidade, demanda, coortes, regiões e defasagem.
8. Implementar G4 trabalho/capital humano, definindo a autoridade de `state.unemployment`.
9. Implementar G5 renda/desigualdade/mobilidade e G7 políticas sociais com beneficiários reconciliados.
10. Endurecer a compatibilidade eleitoral H existente: mandatos, calendário, shares de IA, D’Hondt, segundo turno e coalizões.
11. Implementar H1 organização partidária, H2 candidatos, H3 ledger financeiro/conformidade, H4 comunicação separada e H5 mobilização/turnout.
12. Executar testes direcionados, save/load, migração e horizontes de 240 meses relevantes.

## Ordem mensal corrigida

1. Macro, governo, orçamento, tributação, dívida, ministérios, projetos e serviços.
2. Mundo e migrações ordinárias autorizadas.
3. Militar E2 e cálculo de ameaça.
4. Conflitos, sanções, ajuda e reconstrução E2.
5. Choques globais.
6. Demografia G1.
7. G6 territorial.
8. G2 saúde e G3 educação.
9. G4 trabalho/capital humano.
10. G5 renda/mobilidade e G7 políticas sociais.
11. Grupos, campanha e demais consumidores dos resultados estabilizados.
12. Causalidade e proveniência.
13. Relatório final do mês.
14. Fase F editorial.
15. Atualização de `last_tick`, `month_completed` por último e save atômico.

Enquanto os módulos ainda não existem, registrar o estado como pendente em vez de simular resultados.

## Fontes únicas de verdade

- População e coortes: `state.demography.population` e `state.demography.cohorts`.
- Militar: `Military` para capacidade, aquisições, mobilização e custos.
- Conflitos e sanções: `Conflict`/`state.geopolitics`, com contrato E2 próprio.
- Macroeconomia e fiscal: sistemas existentes de governo, orçamento, tributação, dívida, serviços e projetos.
- Território: `state.phase_g.regions` após G6; os arquétipos de `main.gd` não são dados oficiais.
- Causalidade: `causal_log` registra efeitos já aplicados.
- Jornalismo: `PhaseFInformation` deriva fatos; publicidade paga não edita artigos.
- Eleições: `Election` é autoridade de D’Hondt, maioria e segundo turno; `CampaignSystem` fornece ações intermediárias.

## Invariantes globais

- Uma única população-base; coortes reconciliadas.
- Migração ordinária e deslocamento forçado separados por categoria, origem, destino e chave idempotente.
- Oito regiões com pesos não negativos somando 1 e reconciliação nacional.
- `last_tick` impede reaplicação mensal.
- `month_completed` só é persistido no fim do fechamento.
- `official`, `estimated` e `model` permanecem distinguíveis.
- Efeitos graduais respeitam capacidade, demanda, execução, operação e defasagem.
- Fase F não produz nem reaplica efeitos.
- Campanha paga não altera `factual_basis`, `source_id`, status ou enquadramento editorial independente.
- Limite de três ações mensais, D’Hondt e segundo turno permanecem preservados.

## Tarefa 1 atual — estabilização E2

Implementar somente:

- correção do controle de fluxo que impede `_war_tick` após hostilidades;
- teste direcionado de regressão de múltiplos meses;
- contrato persistente inicial E2/geopolítico com versão, `last_tick`, proveniência e migração aditiva;
- integração de `ensure` do contrato sem aplicar fluxos humanitários à demografia.

Não implementar nesta tarefa: integração de refugiados/deslocados em `state.demography`, G2–G7, H1–H5, mudanças eleitorais ou execução da suíte completa.

## Resultado da Tarefa 1

Implementados:

- correção da estrutura de controle em `conflict_system.gd`, permitindo que conflitos com status `hostilidades`, `escalada` ou `impasse` chamem `_war_tick` em meses consecutivos;
- contrato inicial `scripts/sim/e2_geopolitics_contract.gd`, com `schema_version`, `last_tick`, histórico limitado, proveniência, referência a `state.geopolitics`, módulos E2 e bloqueio explícito do contrato humanitário;
- integração de `E2GeopoliticsContract.ensure` na criação/migração lógica do estado;
- registro mensal do contrato depois de `Conflict.monthly`, sem aplicar deslocados à demografia;
- teste direcionado `test/test_phase_e2_conflict.gd` para progressão de meses, baixas e `months` após hostilidades.

Correção incremental posterior: o caminho explícito de `_migrate_state()` também chama
`E2GeopoliticsContract.ensure(result)`, tornando a migração de saves legados aditiva e
idempotente mesmo quando o save não contém o envelope `e2`.

**Status:** implementada estruturalmente, ainda não validada dinamicamente. O teste não foi executado porque Godot/headless continua sem execução válida nesta sessão.

**Não implementado:** cálculo de `threat`, manutenção pós-entrega, contrato de fluxos forçados/humanitários, integração com `state.demography`, G2–G7 e H1–H5.

## Bloqueios

O executável Godot/headless ainda não foi validado nesta sessão. A auditoria foi estrutural; testes criados nesta tarefa devem permanecer marcados como não executados até o ambiente funcionar.

## Tarefa 2 — contrato E2/E de fluxos forçados e humanitários

**Objetivo:** registrar deslocamentos derivados de conflitos com identidade, origem, destino, categoria, quantidade, proveniência, reconciliação e deduplicação, sem alterar a população-base.

**Auditoria:** `conflict_system.gd` mantinha apenas contadores agregados (`displaced` e `hosted`) e não possuía eventos persistentes com identidade. A origem e o destino não podem ser inferidos quando o sistema não encontra país anfitrião.

**Implementação:** criado `scripts/sim/e2_forced_flows_contract.gd`; criado o ledger `state.geopolitics.humanitarian_events` com `event_id` determinístico por conflito/mês; integrados `ensure` e `monthly` na criação, carregamento, migração e fechamento; criado teste direcionado de reconciliação, `last_tick`, deduplicação e isolamento demográfico.

**Invariantes:** `flow_id` deriva do evento-fonte; eventos repetidos são ignorados; origem/destino ausentes tornam o fluxo `unreconciled` com valor `unresolved`, sem preenchimento inventado; `demography_applied` permanece falso; `state.demography.population` não é modificado.

**Testes:** teste criado, não executado; validação dinâmica continua bloqueada pela ausência de Godot/headless funcional.

**Status:** parcial — contrato e integração estrutural implementados; validação dinâmica, reconciliação operacional completa e integração demográfica continuam pendentes.

**Próxima tarefa:** Tarefa 3 — corrigir o fechamento mensal para gerar relatório e gravar `month_completed` somente após todas as etapas.

## Tarefa FUND-01 — fechamento mensal transacional e save observável

**Objetivo:** impedir fechamento parcial, executar sistemas globais uma vez por mês, gerar relatório sobre o estado final e publicar `month_completed` somente antes de um save validado.

**Auditoria:** `month_completed` e o relatório eram gravados antes de Demography, PhaseG e PhaseF. Além disso, `Conflict.monthly`, os contratos E2 e `GlobalShock.monthly` estavam dentro do laço de países militares, e duas atribuições macro tinham indentação inválida. O save não retornava sucesso/falha e não validava o arquivo publicado.

**Implementação:** movidos os sistemas globais para fora do laço militar; corrigida a indentação macro; reordenado `_complete_month()` para executar G1, G e Fase F antes do relatório e de `month_completed`; `_save_game()` agora retorna `bool`, valida o temporário e o arquivo final, preserva o backup e a UI distingue sucesso de falha.

**Invariantes:** um único tick global por mês; relatório calculado após as etapas produtoras; `month_completed` só é definido antes do commit; falha de save restaura o marcador anterior em memória e não anuncia o mês como persistido; saves existentes e backups permanecem compatíveis.

**Testes:** inspeção estrutural e verificação de indentação executadas; parser Godot, teste de falha de I/O, recuperação e integração mensal não executados porque o Godot/headless permanece indisponível. A suíte completa continua não executada.

**Status:** parcial — correção estrutural implementada, ainda sem validação dinâmica de execução, crash-recovery ou atomicidade real no Windows.

**Próxima tarefa:** FUND-02 — reforçar migração de envelopes e preservar dados de saves antigos antes de ampliar G2–H.

## Tarefa FUND-02 — migrações idempotentes e envelopes sistêmicos

**Objetivo:** garantir que saves legados recebam os contratos atuais sem perder indicadores, históricos ou campos desconhecidos.

**Entradas/dependências:** `_migrate_state()`, `SAVE_VERSION := 6`, catálogos de países/economia e os `ensure()` de International, WorldSim, Military, Resources, Conflict, GlobalShock, E2, Demography, PhaseG e PhaseF.

**Auditoria:** a migração chamava contratos políticos e E2, mas não normalizava explicitamente todos os envelopes mundo/militar/recursos/conflitos. Também havia indentação excedente em `Scandals`, `PhaseGContract` e `PhaseFInformation`, o que poderia impedir o parse do script.

**Implementação:** corrigida a indentação; adicionados os `ensure()` idempotentes de International, WorldSim, Military, Resources, Conflict e GlobalShock ao caminho de `_migrate_state()`. Os dados brutos continuam sendo copiados primeiro para o estado derivado de `_default_state()`, preservando chaves adicionais do save.

**Invariantes:** migração aditiva; nenhum histórico é substituído deliberadamente; `state.demography.population` continua sendo a referência populacional; contratos de fluxos continuam sem aplicação demográfica; versões antigas continuam passando pelo caminho de migração antes de `save_version` ser atualizado.

**Testes:** `test/test_fund01_structure.ps1` executado com sucesso; ele verifica ordem estrutural de Demography/PhaseG/PhaseF, relatório, marcador mensal, save booleano e ticks globais. Parser Godot, round-trip de saves e testes de compatibilidade ainda não foram executados.

**Status:** parcial — migração reforçada estruturalmente, sem validação dinâmica no Godot e sem teste destrutivo de corrupção/recuperação.

**Próxima tarefa:** FUND-03 — contrato de unidades macrofiscais/populacionais e ledger reconciliável, antes de MIL-04.

## Tarefa FUND-03 — unidades macrofiscais/populacionais e ledger reconciliável

**Objetivo:** estabelecer um envelope observacional comum para unidades, proveniência e reconciliação, sem criar uma segunda fonte de verdade para população, PIB, dívida ou arrecadação.

**Auditoria:** o estado possuía `economy_history`, `debt_history` e `fiscal_history` separados, além de indicadores macro diretamente no estado. Não havia um ledger comum que explicitasse unidades, status `official`/`estimated`/`model`, referência populacional e reconciliação das coortes.

**Implementação:** criado `scripts/sim/macro_ledger_contract.gd`. O contrato mantém `schema_version`, `unit_system`, `last_tick`, histórico limitado a 240 entradas, valores com unidade/status/fonte, proveniência e reconciliação populacional. Foi integrado à criação, migração e fechamento mensal depois de Demography, PhaseG e PhaseF e antes do relatório.

**Invariantes:** `state.demography.population` permanece a população canônica; o ledger somente observa dados já calculados; GDP, dívida, desemprego e arrecadação não são recalculados; uma entrada por mês via `last_tick`; soma das coortes é comparada à população com tolerância explícita; dados oficiais, estimados e modelados continuam distinguíveis.

**Testes:** `test/test_fund03_macro_ledger_structure.ps1` executado com sucesso. Ele verifica contrato, unidades, proveniência, guarda idempotente, reconciliação e integração. Parser Godot, execução mensal, round-trip de save e horizonte de 240 meses ainda não foram executados.

**Status:** parcial — contrato e integração estrutural implementados; sem validação dinâmica no Godot.

**Próxima tarefa:** MIL-04 — conectar ameaça aos conflitos e corrigir o fluxo militar sem alterar a população ou os sistemas eleitorais.

## Síntese orquestrada global — próximas tarefas E2 até H

Esta síntese foi produzida por dez auditorias independentes e uma redução consolidada sobre o código real. Nenhuma frente alterou arquivos durante a auditoria.

### Estado global

O projeto permanece **parcial/bloqueado para validação dinâmica**. A base estrutural de E2, G1, contratos PhaseG, campanha, eleições, Fase F e `MacroLedgerContract` existe, mas o parser/runtime Godot, save/load, retry, migrações semânticas e o horizonte integrado de 240 meses ainda não foram validados.

O bloqueio técnico imediato é confirmar o parser de `main.gd`, especialmente os trechos de migração e fechamento mensal que receberam patches recentes. A inspeção textual e os testes PowerShell são evidência estrutural, não evidência de execução Godot.

### Mapa de dependências

1. `state.demography.population` e `state.demography.cohorts` são a única população-base.
2. G6 depende de G1 e precisa fornecer oito IDs, pesos normalizados e populações regionais derivadas.
3. G2 saúde, G3 educação e G4 trabalho dependem de G6, coortes e capacidade fiscal/administrativa.
4. G5 renda/mobilidade e G7 políticas sociais dependem de G2–G4, fiscalidade e ledger de beneficiários.
5. MIL-04 depende de E2/geopolítica para ameaça; MIL-05 depende também de unidades fiscais e de um ledger de ativos/manutenção.
6. E2-06 depende da correção do produtor humanitário e permanece separado da demografia.
7. F-10 depende de IDs causais e de produtores estáveis; Fase F continua somente leitura.
8. H-10 depende da definição formal de mandato/calendário; H1–H5 dependem de Election, CampaignSystem, finanças, comunicação e turnout.
9. INT-12/VAL-13 depende de todos os produtores anteriores, parser, migração e fechamento transacional.

### Ordem recomendada de implementação

#### Tarefa 0 — desbloqueio técnico e parser

Confirmar o caminho de Godot/headless e validar `main.gd`, preloads e cena principal. Corrigir qualquer erro de indentação ou tipo encontrado, sem ampliar escopo funcional. Até esta tarefa passar, todas as demais ficam `parcial_bloqueado` para execução dinâmica.

#### Tarefa INT-01 — contrato transversal de tick

Formalizar o stamp único ano-mês, produtores, observadores e consumidores; garantir `last_tick` por módulo, contadores de chamadas e retry idempotente. Nenhum sistema global pode executar dentro do laço de países quando deve executar uma vez por mês.

#### Tarefa FUND-04 — persistência e migração semântica

Completar a migração aditiva por envelope, validação semântica do temporário, round-trip save/load, backup/rollback e falhas de escrita/rename. Preservar chaves desconhecidas, históricos permitidos, `last_tick` e `month_completed` sem reaplicar efeitos.

#### Tarefa G-06 — território

Criar oito IDs regionais estáveis em `state.phase_g.regions`, pesos finitos e não negativos somando 1, populações derivadas da população nacional e reconciliação dentro de tolerância. Migrar `region_support` por ID e retirar `regions[*].pop` de `main.gd` como autoridade populacional.

#### Tarefa E2-06 — fluxos forçados/humanitários

Corrigir o uso de `inflow` antes da declaração; definir `quantity`, unidade, origem, destino, categoria, `event_id`, `flow_id`, `source_conflict_id`, proveniência e estado `unresolved`. Manter `demography_applied=false` e não alterar população/coortes.

#### Tarefa MIL-04 — ameaça e conflitos

Substituir `threat=0.0` por ameaça determinística, limitada e proveniente. Testar guerras multi-mês, transições, sanções, ajuda, reconstrução e a ordem de um tick militar por país seguido de um tick global de conflito.

#### Tarefa MIL-05 — aquisições, manutenção e mobilização

Criar contrato de ativos entregues, manutenção, unidades, `last_tick` e ledger causal. Cobrar manutenção uma vez por país/mês, separar custo inicial de recorrência, tornar mobilização idempotente e impedir dupla contagem com Government, dívida, tesouro e MacroLedger.

#### Tarefa H-10 — compatibilidade eleitoral

Aprovar e implementar a duração por regime, oposição e eleição antecipada; não forçar janeiro sem regra explícita. Validar shares da IA antes de D’Hondt/segundo turno, definir desempate determinístico e preservar parlamentarismo, presidencialismo, segundo turno e limite de três ações.

#### Tarefa G-08 — saúde, educação e trabalho

Implementar contratos versionados de G2, G3 e G4 após G6. Separar capacidade, demanda, execução, operação, cobertura, coortes, regiões e defasagem. G4 deve ser a única autoridade final de `state.unemployment`; obras, macro e relações devem fornecer inputs/choques, não escritas concorrentes.

#### Tarefa G-09 — renda, mobilidade e políticas sociais

Implementar renda, quantis, desigualdade, pobreza e mobilidade; criar catálogo de programas sociais com elegibilidade, take-up, capacidade, orçamento, gasto, atendidos, recusados e fila. Reconciliar beneficiários e impedir dupla contagem entre serviços, transferências, tributos, emprego e projetos.

#### Tarefa F-10 — causalidade, editorial e proveniência

Uniformizar `causal_id`, `event_id`, `source_id`, ator, ação, efeitos declarados/observados, status e versão. Tornar o histórico jurídico append-only lógico e substituir correlação textual por referências estáveis. Manter campanha paga, comunicação partidária e jornalismo editorial em ledgers separados.

#### Tarefa H-11 — partidos, candidatos, finanças, comunicação e turnout

Criar contratos H1–H5 para organização partidária, candidatos/chapa, ledger financeiro, comunicação paga e turnout. Consolidar `CampaignSystem.perform`, `_campaign_action` e `_free_campaign_action` em uma API idempotente, preservando três ações mensais. Election continua sendo a autoridade de cadeiras e segundo turno.

#### Tarefa INT-12 — integração mensal sequencial

Integrar a ordem única abaixo, com sentinelas e `last_tick` verificáveis. Módulos ainda pendentes devem registrar `pending`/`unreconciled`, nunca simular sucesso.

#### Tarefa VAL-13 — validação controlada

Executar parser, testes direcionados, round-trip, migração dupla, falhas de save e horizonte integrado de 240 meses somente quando Godot/headless estiver funcional. A suíte completa continua fora do escopo sem autorização explícita.

### Ordem mensal alvo

1. Abrir o stamp lógico e verificar se o mês já foi concluído.
2. Governo, orçamento, tributação, dívida, ministérios, projetos e serviços produzem inputs e capacidade.
3. Mundo, relações e migrações ordinárias autorizadas.
4. `Military.monthly` uma vez por país, depois da ameaça calculada.
5. `Conflict.monthly` uma vez globalmente, fora do laço militar.
6. Contratos E2 geopolítico e humanitário, uma vez, sem alterar demografia.
7. `GlobalShock.monthly` uma vez.
8. `Demography.monthly` como único produtor populacional.
9. G6 territorial e reconciliação nacional.
10. G2 saúde, G3 educação e G4 trabalho, com G4 consolidando desemprego uma vez.
11. G5 renda/mobilidade e G7 políticas sociais.
12. Consumidores políticos, grupos, campanha e eleições conforme calendário.
13. Causalidade uniforme e append-only lógico.
14. Fase F como derivação somente leitura.
15. Relatório e `MacroLedgerContract` observacionais.
16. Validação de invariantes, save temporário, leitura/validação, backup, commit e `month_completed` por último.

### Trilhos paralelos permitidos

Podem ser auditados em paralelo: G6; E2 humanitário; MIL-04/MIL-05; H-10; desenho de G2–G4; desenho de G5/G7; F-10; H1–H5; inventário de mutadores financeiros; fixtures e testes direcionados.

Devem permanecer sequenciais: parser antes de runtime; contrato de tick/migração antes da integração; G1 antes de G6; G6 antes de G2–G7; G2–G4 antes de G5/G7; causalidade antes de relatório/Fase F; definição de calendário antes de H-10; todos os produtores antes do horizonte integrado.

### Fontes únicas de verdade

- População: `state.demography.population` e `state.demography.cohorts`.
- Território: `state.phase_g.regions` após G6.
- Militar: `state.geopolitics.military`/`Military`.
- Conflitos e fluxos: `Conflict`, `state.geopolitics` e contratos E2.
- Desemprego: G4 após sua implementação.
- Eleições: `Election` para shares finais, D’Hondt, cadeiras, maioria e segundo turno.
- Finanças: ledgers versionados; `funds`, `treasury` e `spent` não podem ser autoridades concorrentes sem reconciliação.
- Jornalismo: `PhaseFInformation` como camada derivada de fatos; publicidade paga em ledger separado.
- `main.gd`: orquestrador, não fonte paralela de população regional, ativos, cadeiras, desemprego ou fatos editoriais.

### Invariantes que não podem ser alterados

- Uma única população-base; nenhuma integração humanitária demográfica antes do contrato ser validado.
- Oito regiões com IDs estáveis, pesos normalizados e soma regional reconciliada.
- Dados `official`, `estimated`, `model`, `pending` e `unreconciled` permanecem distinguíveis.
- `last_tick`, `event_id`, `flow_id`, `asset_id`, `action_id`, `transaction_id` e `causal_id` impedem reaplicação.
- Aquisição cobra uma vez, entrega uma vez e gera manutenção rastreável.
- Threat não permanece literal zero; conflitos e choques globais executam uma vez por mês.
- G4 será o único escritor final de desemprego.
- D’Hondt, maioria, segundo turno, parlamentarismo/presidencialismo e três ações mensais permanecem preservados.
- Campanha paga não altera `factual_basis`, `source_id`, status ou enquadramento jornalístico independente.
- Migrações são aditivas/idempotentes e saves desconhecidos são preservados.
- `month_completed` só é publicado depois de relatório, validação e save válido.

### Critérios de conclusão global

A conclusão global exige: parser e cena carregáveis; ordem mensal observável; migração dupla idempotente; round-trip de save; recuperação de backup; testes E2/E, militar, G6, G2–G7, F e H; reconciliação populacional/fiscal/eleitoral; e horizonte integrado de 240 meses com valores finitos, sem duplicação e com retenção de histórico. Até que cada critério seja comprovado, o status permanece parcial ou bloqueado.

**Próxima execução:** Tarefa 0 — desbloqueio técnico e parser, seguida de INT-01 e FUND-04 antes das mudanças funcionais MIL/G.

## Tarefa 0 — desbloqueio técnico e parser

**Objetivo:** confirmar a disponibilidade do Godot/headless e eliminar dúvidas estruturais antes de implementar novas regras funcionais.

**Entradas/dependências:** `main.gd`, todos os `preload()` da cena principal, trechos de migração, fechamento mensal e `_complete_month()`.

**Auditoria:** `godot`, `godot4` e executáveis Godot 4.7 não foram encontrados no PATH nem nos locais comuns pesquisados. Todos os preloads referenciados por `main.gd` existem. A medição de caracteres confirmou indentação consistente nos blocos suspeitos de `_ensure_political_state()`, avanço mensal, `_complete_month()` e `_migrate_state()`.

**Implementação:** nenhum código de simulação foi alterado nesta tarefa. Foi criado `test/test_task0_parser_structure.ps1`, que verifica preloads existentes, indentação dos blocos críticos e registra explicitamente a indisponibilidade do Godot sem fingir validação do parser.

**Invariantes:** inspeção estrutural não é tratada como execução; nenhum módulo novo é promovido a concluído; a ausência do Godot permanece um bloqueio explícito; a suíte completa não foi executada.

**Testes:** `test_task0_parser_structure.ps1` executado com sucesso: `PASS; Godot/headless indisponível, parser não validado`. A busca do executável não encontrou `godot`, `godot4` ou binários Godot 4.7 comuns.

**Status:** parcial/bloqueada — preloads e indentação estrutural verificados, parser/runtime Godot ainda não validado.

**Próxima tarefa:** INT-01 — contrato transversal de tick, ordem de produtores/consumidores e retry idempotente, sem depender de execução Godot para a primeira camada estrutural.

## Mudança de escopo — consolidação Phase J

A partir desta decisão, a expansão de G2–G7 e H1–H5 fica congelada. O plano E2–H permanece como mapa de lacunas e dependências, não como autorização para criar sistemas enormes. A prioridade passa a ser J0–J9: auditoria real, correções P0/P1, balanceamento medido, performance, UI/UX, saves, QA, documentação e release.

A classificação de cada recurso deve usar evidência do código e de testes reais: implementado e testado; implementado sem teste suficiente; parcial; presentacional; protótipo; quebrado; ausente; ou obsoleto/não usado. Nenhuma tela, botão, contrato ou documentação será tratado como prova de implementação.

O plano detalhado da nova fase está em `docs/phase_j_consolidacao_plano.md`. A próxima tarefa efetiva é **J0 — auditoria completa da Phase J**, substituindo a implementação imediata de INT-01 como prioridade.
