# Mandatia — Phase J
## Consolidação final, balanceamento, QA e prontidão para lançamento

**Escopo vigente:** consolidar o jogo realmente implementado. Não expandir indefinidamente G2–G7/H1–H5 nem tratar fases planejadas como funcionalidades existentes.

**Status atual:** não pronto para lançamento. O projeto tem uma base jogável e vários sistemas estruturais; parser/boot, progressão curta, eleições básicas, contratos eleitorais, governo legislativo, censura integrada, save/load e alguns testes de UI já possuem evidência headless nesta sessão. Ainda faltam simulações longas, suíte completa autorizada, migração legada independente, auditoria dos P1 restantes, build/instalação limpa e validação de release.

## Princípios de execução

- Trabalhar somente no projeto existente.
- Auditar antes de corrigir.
- Classificar cada recurso por evidência: implementado e testado; implementado sem teste suficiente; parcial; presentacional; protótipo; quebrado; ausente; obsoleto/não usado.
- Não transformar botão, tela, contrato ou documentação em prova de mecânica funcional.
- Preservar saves, dados, regras eleitorais e decisões de design já existentes.
- Não adicionar sistemas grandes enquanto o loop atual não passar por testes reais.
- Registrar todo bug com reprodução, severidade, causa, correção e regressão.
- Manter `official`, `estimated`, `model`, `pending` e `unreconciled` distintos.
- Não declarar lançamento sem evidência reproduzível.

## Auditoria inicial — classificação provisória baseada no código real

| Área | Classificação atual | Evidência necessária |
|---|---|---|
| Inicialização, seleção de país e criação de partido | Implementado estruturalmente, insuficientemente testado | iniciar jogo real em cada cenário suportado |
| Avanço mensal e relatório | Parcial | parser, progressão de meses, retry e relatório pós-fechamento |
| Campanha e limite de três ações | Implementado estruturalmente, insuficientemente testado | três ações, rejeição da quarta, reset mensal e save/load |
| Eleições, D’Hondt e segundo turno | Implementado com contratos direcionados; integração ampla ainda insuficiente | fixtures parlamentar/presidencial, empates, cadeiras e calendário |
| Governo, coalizões e parlamento | Implementado com contratos direcionados; integração ampla ainda insuficiente | formação, leis, votação, censura, estabilidade e consequências |
| Economia, orçamento, impostos e dívida | Implementado/parcial | reconciliação fiscal, estabilidade e simulações repetíveis |
| Ministérios, serviços e projetos | Implementado/parcial | execução, capacidade, atraso, opex e efeitos não duplicados |
| Demografia G1 | Implementado estruturalmente, insuficientemente testado | 20/240 meses, coortes, limites e save/load |
| Território G6 | Ausente como sistema autoritativo | não implementar antes de provar necessidade para o loop atual |
| Saúde, educação, trabalho, renda e políticas sociais G2–G7 | Ausentes ou apenas envelopes/genéricos | manter declarados como ausentes/parciais |
| Militar, conflitos e crises | Parcial | corrigir `threat`, `inflow`, progressão e idempotência |
| Internacional/diplomacia | Implementado/parcial | eventos, perfis, sanções e efeitos verificáveis |
| Jornalismo/Fase F | Parcial/derivado | IDs causais, proveniência e isolamento de campanha |
| H1–H5 | Ausentes/parciais | não implementar como pré-requisito do release sem decisão explícita |
| Saves e migrações | Parcial, não validado dinamicamente | round-trip, legado, corrupção, backup e rollback |
| UI/UX | Presente, não consolidada por matriz de resolução | walkthrough e testes em 1280×720, 1366×768, 1600×900 e 1920×1080 |
| IA | Opcional com fallback esperado | provar que o jogo essencial funciona sem IA |
| Performance | Não medida | baseline de startup, mês, eleição, save/load e histórico |

Esta tabela é provisória até o J0 completo; qualquer item pode ser rebaixado após teste.

## Matriz de prioridade

### P0 — crítico

- Falha de inicialização ou parser.
- Corrupção/perda de save ou publicação indevida de `month_completed`.
- Progressão mensal que não pode avançar ou reaplica efeitos.
- Eleição com cadeiras inválidas, calendário impossível ou resultado inconsistente.
- Inconsistência grave entre estado salvo e valores exibidos.
- Fluxo humanitário quebrado por uso de variável antes da declaração.

### P1 — alto

- `threat=0.0` deixando o sistema militar inerte.
- Falta de manutenção pós-entrega se aquisições já forem expostas como funcionais.
- Escritores concorrentes de desemprego, dívida, fundos ou outros indicadores.
- Governo, coalizão, orçamento ou projetos com efeitos duplicados.
- Falhas de navegação ou decisões sem feedback de custo/consequência.
- Crescimento econômico, dívida, inflação ou popularidade sem limites plausíveis.

### P2 — médio

- Relatórios incompletos.
- Proveniência inconsistente.
- Feedback insuficiente em decisões.
- Histórico e notícias pouco auditáveis.
- Inconsistências de layout e densidade de informação.

### P3 — baixo

- Polimento visual, animações e refinamentos cosméticos sem impacto na confiabilidade.

## Estágios controlados

### J0 — auditoria completa

Inventariar arquitetura, bancos de países/partidos, eleição, campanha, governo, parlamento, economia, finanças, ministérios, projetos, grupos, demografia, internacional, conflitos, notícias, IA, UI, saves, testes e ferramentas.

Entregáveis: matriz de status, lista P0–P3, mapa de fontes de verdade, mapa de mutações e baseline de testes. Nenhuma expansão de sistema nesta etapa.

### J1 — integridade crítica

Corrigir apenas P0 e bloqueadores do loop atual: parser/runtime, inicialização, avanço mensal, save/backup, ordem de fechamento, `inflow`, ameaça, cadeiras e referências de estado. Cada correção precisa de reprodução e regressão direcionada.

### J2 — balanceamento medido

Executar simulações repetíveis do jogo realmente implementado, não de sistemas futuros. Medir economia, fiscal, política, eleições e internacional nos marcos de 12, 60, 120 e 240 meses quando o ambiente funcionar.

Nenhuma fórmula será alterada por intuição isolada. Cada ajuste deve registrar hipótese, métrica antes/depois, impacto e risco para saves.

### J3 — performance

Medir startup, novo jogo, mês, eleição, save/load, carregamento de catálogos, memória e crescimento de históricos. Otimizar somente gargalos medidos; não fazer reescritas especulativas.

### J4 — consolidação UI/UX

Preservar estética escura, âmbar, Figtree e sala de situação. Corrigir navegação, hierarquia, estados desabilitados, feedback de custo/consequência, textos, tabelas e clipping nas resoluções suportadas. Não redesenhar tudo.

### J5 — confiabilidade e saves

Validar novo jogo, save imediato, load, avanço de mês, eleição, governo, políticas, vários anos, novo save e continuidade. Testar save corrompido, campos ausentes, campos inválidos, backup, falha de escrita e migração repetida.

### J6 — acessibilidade/localização

Auditar legibilidade, contraste, uso de cor, foco, tooltips, escalabilidade, textos hard-coded e cobertura de idioma. Declarar lacunas; não afirmar localização completa sem revisar todas as superfícies.

### J7 — onboarding e documentação

Documentar somente regras implementadas: início, campanha, eleição, governo, orçamento, projetos, indicadores, save/load e limitações. Atualizar ajuda contextual sem prometer sistemas ausentes.

### J8 — QA completo controlado

Executar testes unitários e de integração existentes, walkthrough de gameplay, save regression, progressão eleitoral/governamental e simulações longas. A suíte completa só será executada quando o usuário autorizar e o ambiente estiver funcional.

### J9 — preparação de release

Validar build, instalação limpa, primeiro início, save/load, ausência de dependência essencial de IA, documentação de compatibilidade e known issues. O resultado pode ser “não pronto” ou “pronto com limitações”.

## Ordem de execução imediata

1. Completar o inventário J0 sem adicionar sistemas.
2. Executar somente testes estruturais já disponíveis e registrar limites.
3. Quando Godot estiver disponível, validar parser e boot.
4. Corrigir P0 antes de qualquer balanceamento.
5. Rodar progressão curta real: novo jogo → meses → campanha → eleição → governo → política → save/load.
6. Corrigir regressões encontradas.
7. Só então executar balanceamento medido de 12/60/120/240 meses.
8. Medir performance e consolidar UI/UX.
9. Executar QA e só depois avaliar release.

## Invariantes de consolidação

- A população canônica permanece `state.demography.population`/coortes.
- D’Hondt, segundo turno, parlamentarismo/presidencialismo e limite de três ações permanecem.
- Campanha paga não altera jornalismo independente.
- Saves existentes são preservados e migrados explicitamente.
- A IA é opcional; fallback determinístico sustenta mecânicas essenciais.
- Dados oficiais, estimados e modelados permanecem separados.
- Não declarar G2–G7 ou H1–H5 implementados sem mecânica e testes correspondentes.
- `month_completed` somente é publicado após fechamento e save válidos.
- Toda alteração significativa possui teste ou fica marcada como não validada.

## Critérios de lançamento

Mandatia só pode ser classificado como pronto quando houver evidência de:

- inicialização e loop principal funcionando;
- progressão política real;
- eleições e cadeiras consistentes;
- governo, parlamento e políticas com consequências;
- economia e finanças numericamente estáveis;
- saves novos e legados confiáveis;
- simulações longas sem overflow, NaN, duplicação ou crescimento inexplicável;
- UI utilizável nas resoluções suportadas;
- IA não essencial;
- documentação coerente com o código;
- limitações conhecidas explicitamente registradas.

Sem essas evidências, a classificação correta é **não pronto para lançamento**.

## Decisão atual

A expansão planejada de novos sistemas fica congelada. A próxima tarefa deixa de ser INT-01 como implementação de contrato novo e passa a ser **J0 — auditoria completa da Phase J**, começando pelo inventário real e pela matriz P0–P3. A auditoria não deve esconder funcionalidades ausentes nem criar sistemas enormes para aparentar completude.

## Registro de evidências — Tarefa 2C/2D

As validações direcionadas seguintes foram executadas com Godot 4.7 headless, verificando também os marcadores de sucesso e a ausência de `Parse Error`, `SCRIPT ERROR` e `ERROR:` nos logs:

- `ELECTION_SMOKE_PASS checks=11`: D’Hondt preenche o número exato de cadeiras, maioria, distinção parlamentarismo/presidencialismo, segundo turno com RNG seedado e vitória direta com maioria inicial.
- `GOVERNMENT_SMOKE_PASS checks=8`: menor coalizão vencedora, parceiro ideologicamente mais próximo, conservação das cadeiras, aprovação de lei ordinária e requisito de 3/5 para lei constitucional.
- `CENSURE_SMOKE_PASS checks=5`: fluxo integrado da cena principal, cobrança de custo, cobrança de credibilidade, censura rejeitada quando a coalizão governista possui 75/100 cadeiras e preservação da coalizão.

Foi reproduzido e corrigido um P1 na composição da censura: `main.gd` subtraía apenas a bancada do maior partido e podia tratar parceiros governistas como oposição. A correção soma o partido governista e todos os `coalition_partners` existentes antes de calcular as cadeiras externas. O teste de censura executou com backup e restauração do diretório real de `user://`; o save local não é evidência de release e permanece sujeito à validação de migração/corrupção.

Limitações mantidas: esses contratos não substituem a suíte completa, as eleições integradas de todos os regimes, segundo turno com dados de catálogo, estabilidade mensal, migração legada, horizontes de 60/120/240 meses, soak, benchmarks, build EXE/PCK ou instalação limpa. O status continua **não pronto para lançamento**.

## Auditoria P1 restante — Tarefa 3

Auditoria estática realizada após a correção da censura, sem executar a suíte completa e sem alterar fórmulas por hipótese:

| Risco | Resultado | Evidência e decisão |
|---|---|---|
| `threat=0.0` no militar | **Confirmado** | `main.gd:3977` chama `Military.monthly(..., 0.0, ...)`. Não foi encontrado produtor de ameaça usado nessa chamada. A ameaça não influencia o alvo de gasto militar (`military_system.gd:193-199`). Criar teste/regra determinística antes de corrigir. |
| Manutenção pós-entrega militar | **Confirmado** | Aquisições guardam `maintenance` em cada programa (`military_system.gd:169-175`), mas `_deliver` só aplica atributos e estoque (`:182-185`); `monthly` não transforma manutenção acumulada em despesa, prontidão ou desgaste. Corrigir com custo mensurável e regressão. |
| Conservação de caixa no orçamento | **Contrato direcionado aprovado; horizontes longos pendentes** | O contrato valida `treasury`, `debt_book`, `project_debt` e execução nos três caminhos. `titulos/externo` agora emitem tranche real por capital mensal; `tesouro` não cria tranche nem registra dívida de projeto. |
| Dupla cobrança de projetos | **Não reproduzida no contrato** | `PROJECT_ACCOUNTING_SMOKE_PASS checks=17` confirmou que `tesouro` não debita capital duas vezes e que `titulos/externo` creditam o financiamento e criam a tranche correspondente. A estabilidade após vários meses ainda depende de simulação longa. |
| Escritores concorrentes de macro | **Risco de ordem, não prova de bug isolado** | `main.gd`, `Government`, `Military`, `Conflict`, `Events`, `GlobalShock`, `InterestGroups`, `International` e `Debt` escrevem subconjuntos dos indicadores. Há ordem explícita no fechamento, mas faltam testes de atribuição e invariantes por etapa. Não remover escritores sem simulação de regressão. |
| Painel de população | **Corrigido como envelope explícito** | A população canônica continua em `state.demography.population`/coortes. O painel regional agora se identifica como `ENVELOPE REGIONAL MODELADO`, sem chamá-lo de população ou peso eleitoral e sem alterar o estado demográfico. |
| `TERM_MONTHS=48` versus documentação | **Decisão: preservar 48** | `main.gd:71` é a regra canônica implementada e o README já documenta 48 meses. Referências restantes a 60 devem ser removidas ou marcadas como históricas; não alterar o calendário nem migrar saves por esse motivo. |

### Tarefa 4 — contratos militares de ameaça e manutenção

Implementação concluída no sistema existente, sem criar uma fonte paralela de estado:

- `Military.threat_for(state, id)` deriva a ameaça máxima de conflitos ativos relevantes e de crises abertas/escalando, limitada a `0..100`; `main.gd` usa esse valor no fechamento mensal em vez de `0.0` hardcoded.
- `_deliver()` soma `program.maintenance` em `m["maintenance_load"]`, com limite seguro `0..20`; a migração de `ensure()` inicializa o campo em saves antigos.
- `monthly()` inclui `maintenance_load` no alvo gradual de `defense_share` e retorna `maintenance_load` e `threat` junto com participação, prontidão e poder.
- Regressões executadas com Godot 4.7 headless: parser do sistema militar sem erro; `MILITARY_SMOKE_PASS checks=6`; carregamento da cena sem erro; `CORE_SMOKE_PASS checks=34` após a integração.

Limitações: o contrato cobre entrega, acumulação e ameaça determinística, mas ainda não substitui simulações de 60/120/240 meses, soak, reconciliação fiscal de projetos, migração legada ou QA completo de saves. O status permanece **não pronto para lançamento**.

### Tarefa 5 — contrato contábil de projetos

Auditoria e correção concluídas no fluxo existente de obras e dívida:

- `tesouro` continua dependendo da execução orçamentária e não cria dívida artificial.
- `titulos` e `externo` agora chamam `Debt.finance_project()`, que cria uma tranche real em `debt_book`, credita o caixa e registra `project_debt`.
- Corrigido um bug real de indentação em `PublicProjects.monthly()`: o avanço da obra, `cost_spent`, capital e financiamento estavam depois de `continue`, dentro do ramo de paralisação, e nunca eram executados.
- O contrato foi executado novamente no PowerShell normal após a correção: `PROJECT_ACCOUNTING_SMOKE_PASS checks=17`.

Limitações: o contrato cobre um mês de cada fonte e verifica o estoque/tranche imediatamente após o financiamento. Ainda faltam juros acumulados, vencimento/refinanciamento, execução de opex, múltiplos projetos e horizontes de 60/120/240 meses. O status permanece **não pronto para lançamento**.

### Tarefa 6 — contrato da ordem dos escritores macro

Contrato executado com a cena real e campanha sem IA, registrando snapshots antes e depois de cada etapa do fechamento:

- ordem verificada: `antes` → `governo` → `internacional` → `mundo` → `militar` → `conflitos` → `choques`;
- campos críticos verificados em cada etapa: economia, inflação, desemprego, dívida, aprovação e tesouro;
- faixas de segurança e valores não finitos verificados sem falhas;
- `Government.monthly()` confirmou a publicação do fiscal antes dos escritores seguintes;
- evidência: `MACRO_WRITER_ORDER_SMOKE_PASS checks=53 stages=7`.

O contrato não prova que a atribuição econômica de cada efeito é ideal nem substitui simulações longas; ele confirma a ordem executada e a estabilidade básica dos campos observados. O status permanece **não pronto para lançamento**.

### Síntese orquestrada — sequência restante da Phase J

Escopo mantido no projeto existente, sem expansão G2–G7/H1–H5 e sem caça geral a bugs nesta etapa. A fonte única permanece: população em `state.demography`, calendário em `TERM_MONTHS := 48`, finanças em `treasury`/`budget`/`debt_book`, e IA como camada opcional.

| Unidade | Dependências | Implementação planejada | Critério de conclusão |
|---|---|---|---|
| Tarefa 7 — painel regional | `demography_system`, `phase_g_contract`, UI | Apenas apresentação; envelope estático claramente rotulado | Nenhum texto afirma população canônica ou peso eleitoral |
| Tarefa 8 — calendário 48 meses | `main.gd`, README e docs | Preservar 48 e alinhar documentação | Regra e textos coerentes; regressão posterior |
| Tarefa 9 — saves/migração | `SAVE_VERSION`, `ensure`, backup/load | Auditoria e correções aditivas/idempotentes | Campos desconhecidos preservados; migração repetível |
| Tarefa 10 — IA local isolada | `ai_contracts`, `ollama_client` | Manter `preferred`, schema, retry e fallback; sem integração nova | Contrato real isolado, sem IA essencial |
| Tarefa 11 — validação acumulativa | tarefas 7–10 concluídas | Planejar 12/60/120/240, soak e benchmarks | Executar somente com autorização explícita |
| Tarefa 12 — QA/release | validações anteriores | saves, build, instalação limpa e known issues | Nunca declarar lançamento sem evidências |

Durante a orquestração, validações direcionadas mínimas podem ser usadas para evitar integrar sintaxe quebrada; a rodada ampla de caça a bugs, suíte completa e simulações longas fica deliberadamente reservada para depois das tarefas estruturais.

### Próxima sequência de validação P1

1. Corrigir o painel regional para exibir a fonte canônica ou declarar explicitamente os dados regionais como envelope estático não demográfico.
2. Resolver a divergência 48/60 documentando a decisão e adicionando regressão do calendário.

Nenhuma dessas frentes autoriza declaração de lançamento; permanecem pendentes os horizontes longos, soak, migração legada, benchmarks, build e instalação limpa.

### Tarefa 7 — painel regional

Objetivo: impedir que o envelope regional estático seja confundido com a população canônica ou com peso eleitoral.

Entradas e dependências: `scripts/main.gd`, `scripts/sim/demography_system.gd`, `scripts/sim/phase_g_contract.gd` e `state.region_support`.

Auditoria: a UI já usava `ENVELOPE REGIONAL MODELADO` em parte do painel, mas a tela `Regiões` ainda rotulava `r.pop` como “População”. A demografia autoritativa continua em `state.demography.population`/coortes; `r.pop` é somente um valor estático de apresentação.

Implementação: o rótulo foi alterado para “Envelope regional modelado”, a unidade foi removida de “mi” para “u.” e uma nota explícita informa que o valor não é população canônica nem peso eleitoral. A tela de campanha também passou a chamar sua proporção derivada de `r.pop` de “alcance relativo modelado”, sem alterar a fórmula ou o comportamento da campanha. `state.region_support` permaneceu separado e inalterado. Nenhuma reconciliação territorial foi criada.

Invariantes: a UI não atribui população ou cadeiras eleitorais a `r.pop`; a população oficial continua em `state.demography`; apoio regional continua em `state.region_support`.

Testes: validações direcionadas executadas pelo usuário passaram: `CORE_SMOKE_PASS checks=34` após o ajuste final, `MACRO_WRITER_ORDER_SMOKE_PASS checks=53 stages=7`, `MILITARY_SMOKE_PASS checks=6` e `PROJECT_ACCOUNTING_SMOKE_PASS checks=17`. A busca de referências confirmou `TERM_MONTHS := 48` e os rótulos do envelope regional; a tela de campanha tinha uma referência ambígua a “peso eleitoral”, corrigida nesta unidade. A suíte completa não foi executada.

Status: concluída estruturalmente, sem validação dinâmica nesta retomada.

Próxima tarefa: Tarefa 8 — calendário de 48 meses e alinhamento documental.

### Tarefa 8 — calendário de 48 meses

Objetivo: preservar o mandato implementado de 48 meses e eliminar ambiguidade documental sem migrar saves por uma mudança de calendário inexistente.

Entradas e dependências: `scripts/main.gd:TERM_MONTHS`, `README.md` e `project.godot`.

Auditoria: `TERM_MONTHS := 48`, o README e a descrição do projeto afirmam 48 meses. Não foi encontrada, nesta leitura dirigida, uma regra implementada de 60 meses. A busca global por referências históricas e a regressão dinâmica ficaram pendentes porque o terminal integrado retornou `terminal:config home unavailable`.

Implementação: nenhuma fórmula, calendário ou save foi alterado. O README permanece alinhado e a regressão de calendário foi definida como teste direcionado, sem executar a suíte completa.

Invariantes: um mandato continua com 48 meses; saves não são convertidos para 60; `months_to_election` e `term_months_served` continuam sendo estado da campanha, não uma segunda fonte de duração.

Testes: inspeção estática concluída; teste dinâmico e busca global executável pendentes do PowerShell normal.

Status: concluída documentalmente; validação dinâmica pendente.

Próxima tarefa: Tarefa 9 — saves e migração.

### Tarefa 9 — saves e migração

Objetivo: preservar saves atuais, tornar explícita a migração aditiva/idempotente e manter recuperação por backup.

Entradas e dependências: `SAVE_VERSION := 6`, `_migrate_state`, `_read_save_file`, `_load_game`, `_save_game`, save legado e módulos `ensure`.

Auditoria: a migração começa de `_default_state()` e copia todas as chaves do save, preservando campos desconhecidos; normaliza campos básicos, chama `ensure` dos módulos e grava a versão atual. O carregamento tenta principal, backup e legado. O save usa temporário, verifica JSON e mantém backup anterior. Ainda não há evidência dinâmica de save/load, corrupção, falha de escrita, legado independente ou repetição em runtime.

Implementação: criado `res://.work/scripts/run_save_migration_contract_smoke.gd` para verificar preservação de campo desconhecido, atualização de versão e idempotência. Nenhuma migração destrutiva ou remoção de campo foi feita. A rotação/rollback real permanece para QA controlado.

Invariantes: campos desconhecidos não são descartados; migrar duas vezes não duplica estruturas; save inválido não vira estado válido silenciosamente; `month_completed` só é publicado depois de `_save_game()` retornar sucesso.

Testes: smoke executado pelo usuário com Godot 4.7 no PowerShell normal: `SAVE_MIGRATION_CONTRACT_PASS checks=8`. Após uma correção de indentação no painel regional, também passaram `CORE_SMOKE_PASS checks=34`, `MACRO_WRITER_ORDER_SMOKE_PASS checks=53 stages=7`, `MILITARY_SMOKE_PASS checks=6` e `PROJECT_ACCOUNTING_SMOKE_PASS checks=17`. Suíte completa não executada.

Status: parcial — contrato preparado, evidência dinâmica pendente.

Próxima tarefa: Tarefa 10 — contrato isolado de IA local.

### Tarefa 10 — IA local isolada

Objetivo: manter a IA opcional, limitada por contrato e incapaz de definir diretamente os indicadores exatos do estado.

Entradas e dependências: `scripts/ai/ai_contracts.gd`, `scripts/ai/ollama_client.gd`, `tools/probe_ai_end_to_end.gd` e `config/ai_examples.json`.

Auditoria: há quatro contratos, validação antes da entrega, fallback determinístico, cache no estado, log NDJSON, aquecimento separado, duas tentativas e prazo de 20 s por tentativa. Eventos têm limites explícitos; eleitoral limita deltas; legislativo preserva a conversão de cadeiras no motor; internacional limita reações. A sonda E2E existe, mas exige Ollama/modelo real e não foi executada. O código ainda exibe o identificador configurado em `ai_examples.json`; não foi feita troca especulativa de modelo.

Implementação: README atualizado de “planejada” para “opcional”, sem integração nova ao mundo nem criação de sistemas D15–D23.

Invariantes: o jogo deve funcionar sem Ollama; respostas inválidas nunca entram diretamente no estado; extrapolações são registradas como rejeição/resultado validado, não como exemplos positivos automáticos de fine-tuning.

Testes: modelo GGUF `mandatia-qwen35-local:latest` registrado e acessível no Ollama; JSON mínimo inicial com `think=false` passou (`done_reason=stop`). Probe E2E real executado pelo usuário: `legislative:ollama=3`, `legislative:fallback=3`, `events:fallback=1`, `international:fallback=1`, com mês fechado em aproximadamente 80,6 s. O log registrou `HTTP 0` nos contratos de evento e internacional. Teste direto posterior retornou HTTP 500 após 19,3 s com `prediction aborted, token repeat limit reached`. Uma variante `mandatia-qwen35-event-test:latest`, criada a partir do GGUF com `repeat_last_n=128`, `repeat_penalty=1.15`, `temperature=0.15`, `top_k=30`, `top_p=0.85` e `min_p=0.05`, também não foi aprovada: respondeu `done=false`, resposta vazia e `model` vazio. Teste adicional via `/api/chat` confirmou que `format:"json"` causa erro do servidor (`Unexpected empty grammar stack after accepting piece: @`); removendo `format`, a chamada terminou com `done=true`, mas produziu somente `@` repetido até `done_reason=length`, sem JSON válido. Portanto, o modelo/runner não está aprovado para eventos nem para integração via chat; o fallback determinístico permanece o caminho seguro. Não foram aceitas respostas inválidas nem relaxados os limites.

Status: parcial/bloqueada — a infraestrutura de contrato e fallback atende ao desenho, mas o GGUF real só funciona de modo inconsistente em legislativo e falha nos testes estruturados de eventos; a IA permanece opcional e o fallback é obrigatório.

Próxima tarefa: Tarefa 11 — preparação de simulações acumulativas sem executar horizontes longos ainda.

### Tarefa 11 — simulações acumulativas

Objetivo: preparar uma matriz reproduzível para 12/60/120/240 meses, soak e benchmarks, sem executá-la sem autorização explícita.

Implementação planejada: `docs/phase_j_simulacoes_plano.md` define harnesses por horizonte, seed registrada, limite de tempo/processo, marcador de conclusão e métricas de overflow/NaN, dívida, caixa, população, eleições, histórico e memória. A execução fica bloqueada até autorização; o `tools/soak_harness.gd` existente não será duplicado.

Status: planejada, não executada.

Próxima tarefa: Tarefa 12 — QA/release.

### Tarefa 12 — QA e release

Objetivo: consolidar a matriz de QA, build, instalação limpa, saves e known issues sem declarar lançamento antecipado.

Implementação planejada: `docs/phase_j_qa_release_matrix.md` define a matriz de parser/boot, progressão, eleição, governo, saves novos/legados/corrompidos, IA ausente, resoluções e pacote exportado. Build e instalação limpa permanecem pendentes.

Status: planejada, não executada; o projeto continua **não pronto para lançamento**.

Próxima tarefa: concluir a validação dinâmica controlada das tarefas 8–10 antes de autorizar Tarefa 11.
