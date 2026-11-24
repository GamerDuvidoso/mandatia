# Fase G — Plano de conclusão orquestrado

**Status:** auditoria orquestrada concluída; fundação `state.phase_g` v1 implementada; G2–G8 ainda não concluídas.  
**Base existente:** G1 demografia implementada; serviços públicos, ministérios, projetos, orçamento, tributação, grupos sociais, saves e Fase F fornecem entradas reutilizáveis.

## Resultado da orquestração

A Fase G permanece parcial. As frentes independentes foram auditadas em paralelo:

- G2 — saúde e resultados populacionais;
- G3 — educação, matrícula, conclusão e qualificação;
- G4 — trabalho, emprego, formalidade e produtividade;
- G5 — renda, desigualdade e mobilidade social;
- G6 — regiões estimadas e reconciliação territorial;
- G7 — políticas sociais, projetos e capacidade administrativa;
- G8 — interface, relatórios, rastreabilidade e migração.

Todas as frentes confirmaram que não devem criar uma população paralela. `state.demography` continua sendo a população-base única; grupos sociais, regiões, faixas de renda, domicílios e beneficiários são dimensões ou subconjuntos reconciliáveis.

## Ordem global decidida

1. Mapear o fechamento mensal real e o fluxo de `ensure`, migração, relatório e salvamento.
2. Criar o contrato comum `state.phase_g` v1, com `schema_version`, `last_tick`, proveniência, população-base referenciada, regiões, histórico limitado, causalidade e migração idempotente.
3. Fixar adaptadores e invariantes de G1 sem alterar `state.demography` nem o legado `state.demographics`.
4. Implementar G6 territorial mínimo: oito IDs estáveis, pesos declarados, status `estimated/model`, população derivada e reconciliação nacional.
5. Implementar G2 Saúde usando serviços, ministério, projetos e orçamento como entradas defasadas.
6. Implementar G3 Educação com matrícula, frequência, retenção, conclusão e qualificação graduais.
7. Implementar G4 Trabalho/Human Capital e tornar seu desemprego derivado a fonte compatível de `state.unemployment`.
8. Implementar G5 Renda, desigualdade e mobilidade sobre a população única.
9. Implementar G7 como camada de políticas sociais persistentes, com orçamento, capacidade, execução, beneficiários, região, prazo e risco.
10. Implementar G8 como normalizador de proveniência, causalidade, relatórios e interface.
11. Integrar o fechamento mensal, testes direcionados, migração de saves e teste de horizonte de 240 meses.

## Paralelismo permitido

Depois do contrato comum, G2, G3 e G4 podem desenvolver interfaces próprias em paralelo, desde que não mutem diretamente a população ou os serviços existentes. G6 pode avançar em paralelo com os esqueletos desses módulos, mas deve estar pronta antes de qualquer indicador regional ser consumido. G5 depende materialmente de G4; G7 pode preparar o contrato de políticas enquanto os módulos de resultado avançam; G8 pode preparar proveniência e migração, mas só deve exibir resultados estabilizados.

## Ordem mensal-alvo

1. Macro, tributação, orçamento, dívida, governo e capacidade ministerial.
2. Projetos e serviços: execução, obras, operação, capacidade, cobertura, qualidade e demanda.
3. Mundo e migrações autorizadas, com origem/destino e deduplicação.
4. Demografia G1: envelhecimento, nascimentos, mortes, migração e urbanização.
5. G6 territorial: derivação e reconciliação das oito regiões.
6. G2 Saúde e G3 Educação.
7. G4 Trabalho/Human Capital.
8. G5 Renda/Desigualdade/Mobilidade e G7 Políticas Sociais.
9. Grupos sociais como dimensões analíticas, sem soma cruzada.
10. Causalidade, proveniência, relatório e Fase F editorial.
11. `last_tick`, históricos limitados e salvamento atômico.

## Invariantes obrigatórias

- Uma única população-base; coortes somam população.
- Ocupação e renda são camadas sobrepostas e somam separadamente, nunca entre si.
- Pesos das oito regiões somam 1 e seus totais reconciliam ao nacional.
- `last_tick` torna cada atualização mensal idempotente.
- `official`, `estimated` e `model` permanecem identificáveis.
- Gasto, anúncio, cobertura nominal ou projeto em obra não geram resultado integral imediato.
- Migração forçada/humanitária permanece bloqueada até o contrato da E2 ser localizado.
- Nenhuma frente será declarada concluída sem teste curto, migração, proveniência e trajetória de 240 meses.

## Bloqueios registrados

O terminal Godot/headless ainda não forneceu resultado válido de execução; a limitação anterior foi `terminal: config home unavailable`. A validação dinâmica e o teste demográfico de 240 meses continuam pendentes até o ambiente permitir execução. O contrato da migração forçada da E2 também não foi localizado.

## Próxima tarefa

**Fase G — Tarefa de fundação:** mapear o fechamento mensal e implementar o contrato comum `state.phase_g` v1 com `ensure` e migração idempotente, sem ainda aplicar resultados de saúde, educação, trabalho, renda ou políticas sociais.

## Tarefa de fundação — resultado

Implementados `scripts/sim/phase_g_contract.gd` e a integração mínima em `main.gd`:

- contrato persistente versionado (`schema_version = 1`);
- migração aditiva e idempotente, preservando campos desconhecidos e saves antigos;
- `last_tick` e histórico limitado a 120 registros;
- referência única a `state.demography.population`;
- proveniência com status `official`, `estimated` ou `model`;
- esqueletos separados para território, saúde, educação, trabalho, renda e política social;
- integração após G1 no fechamento mensal, antes da camada editorial da Fase F;
- teste direcionado em `test/test_phase_g_contract.gd`.

Nenhum resultado de G2–G7 foi aplicado nesta tarefa. O projeto não possui `godot` disponível no PATH desta sessão, portanto o teste foi criado, mas ainda não foi declarado validado dinamicamente. A próxima tarefa é G6 territorial mínimo.
