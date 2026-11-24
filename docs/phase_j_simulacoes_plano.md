# Phase J — Plano de simulações acumulativas

Este documento prepara a Tarefa 11 sem executar a suíte completa, soak ou horizontes longos.

## Regras de execução

- Executar somente após autorização explícita do usuário.
- Usar fallback determinístico e seed registrada para a linha de base; IA real deve ser uma rodada separada.
- Cada processo deve ter horizonte, seed, início/fim, marcador de sucesso e limite de tempo registrados.
- Interromper ao detectar `NaN`, infinito, caixa negativa, cadeiras inválidas, mês inválido, população não finita, duplicação de `month_completed` ou crescimento de histórico sem limite.
- Não alterar fórmulas durante a medição; hipóteses e correções ficam em rodada posterior.

## Matriz mínima

| Horizonte | Objetivo | Métricas obrigatórias | Estado |
|---|---|---|---|
| 12 meses | progressão pré-eleitoral e fechamento mensal | calendário, caixa, macro, demografia, eventos, save | pendente |
| 60 meses | primeiro ciclo eleitoral e início de mandato | eleição, cadeiras, governo, dívida, projetos, `month_completed` | pendente |
| 120 meses | dois ciclos e efeitos acumulados | eleições, coalizão, fiscal, população/coortes, históricos | pendente |
| 240 meses | estabilidade de longo prazo | overflow/NaN, limites, população, dívida, caixa, memória e duplicação | pendente |

## Soak e benchmarks

O `tools/soak_harness.gd` existente percorre países e campanhas com fallback, mas não substitui os marcos acima. Deve ser executado separadamente e com timeout externo. Benchmarks devem medir startup, novo jogo, mês, eleição, save/load e crescimento dos históricos, sem misturar a rodada de correção.

## Critérios de aprovação

Uma rodada só pode ser marcada como aprovada se terminar com marcador explícito, zero falhas e log preservado. Ausência de saída, processo pendurado ou interrupção manual é “não validada”, nunca “passou”.
