# Mandatia — Phase J
## Consolidação final, balanceamento, QA e prontidão para lançamento

**Escopo vigente:** consolidar o jogo realmente implementado. Não expandir indefinidamente G2–G7/H1–H5 nem tratar fases planejadas como funcionalidades existentes.

**Status atual:** não pronto para lançamento. O projeto tem uma base jogável e vários sistemas estruturais, mas a execução Godot/headless, progressão integrada, eleições, governo, save/load, balanceamento e simulações longas ainda não foram comprovados nesta sessão.

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
| Eleições, D’Hondt e segundo turno | Implementado estruturalmente, insuficientemente testado | fixtures parlamentar/presidencial, empates, cadeiras e calendário |
| Governo, coalizões e parlamento | Implementado estruturalmente, insuficientemente testado | formação, leis, votação, censura, estabilidade e consequências |
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
