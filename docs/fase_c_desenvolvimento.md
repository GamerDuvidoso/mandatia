# Mandatia — Fase C: gestão governamental e administração pública

## Status

Fase C implementada sobre as fases A e B existentes. A lógica fiscal permanece separada da apresentação e não depende do Ollama.

## 1. Sistemas implementados

- `scripts/sim/budget_system.gd`: orçamento anual, dotações aprovadas, plano em revisão, execução mensal, categorias por tipo, tesouro e saldo fiscal.
- `scripts/sim/taxation_system.gd`: tributos com base, alíquota, conformidade, elasticidade, atividade econômica e resposta comportamental.
- `scripts/sim/ministry_system.gd`: ministérios, ministros, competência, lealdade, experiência, credibilidade, liderança, capacidade e desempenho.
- `scripts/sim/public_project_system.gd`: proposta, viabilidade, aprovação, financiamento, obras, paralisação, conclusão e avaliação.
- `scripts/sim/debt_system.gd`: estoque, tranches, juros, vencimento, refinanciamento, emissão, amortização, resultado primário e resultado total.
- `scripts/sim/public_services_system.gd`: cobertura, qualidade, capacidade, demanda, eficiência e infraestrutura.
- `scripts/sim/government.gd`: fachada de integração mensal, relatório e fatores contribuintes.
- `scripts/main.gd`: navegação, telas, ações do jogador, save/migração e integração com a simulação política.
- `config/public_administration.json`: categorias, tributos, ministérios, serviços, projetos, arquétipos e parâmetros fiscais.

## 2. Integração entre sistemas

A ordem mensal é:

1. arrecadação tributária;
2. execução do orçamento aprovado;
3. avanço e custeio dos projetos;
4. atualização da capacidade ministerial;
5. atualização dos serviços públicos;
6. juros, vencimentos, refinanciamento e financiamento do déficit;
7. atualização da economia, aprovação, credibilidade, coalizão e grupos sociais.

Um projeto não aplica bônus isolado. Ele exige tesouro, viabilidade, capacidade ministerial, dotação e financiamento. Seus efeitos aparecem com atraso e dependem da execução real.

## 3. Metodologia fiscal

- PIB anual simulado é convertido para unidade monetária interna por parâmetro declarado.
- Receita mensal usa base tributária, alíquota, conformidade, elasticidade e atividade econômica.
- Aumentar alíquota acima do nível neutro reduz base efetiva e conformidade.
- Despesa aprovada é distinta da despesa executada.
- Eficiência de execução depende da capacidade administrativa, aprovação e tipo de despesa.
- Juros são calculados sobre o estoque de cada tranche e ficam fora da despesa não financeira para evitar dupla contagem.
- Resultado primário = receita − despesa sem juros.
- Resultado total = resultado primário − juros.
- Dívida/PIB usa estoque consolidado dividido pelo PIB anual.

## 4. Fontes e premissas

Os perfis econômicos existentes usam `config/economy.json`, com proveniência e indicação de dado oficial ou estimado, conforme documentado na Fase A. A administração pública usa parâmetros de gameplay em `config/public_administration.json`. Onde não existe dado regional detalhado, o jogo usa as oito regiões já presentes no estado e marca os indicadores como simulação.

Não há pretensão de reproduzir estatísticas reais de execução administrativa. Os parâmetros foram escolhidos para tornar os trade-offs legíveis e determinísticos.

## 5. Modelo ministerial

Competência técnica e lealdade política são variáveis independentes. Candidatos determinísticos oferecem perfis técnico, aliado político, gestor público e quadro partidário. A capacidade evolui com competência, experiência, liderança, credibilidade, dotação orçamentária e qualidade do serviço. Pastas sem ministro perdem desempenho gradualmente.

## 6. Ciclo de projetos

Cada projeto percorre proposta, viabilidade, aprovação, financiamento, obras, operação e avaliação. O sistema registra prazo, custo previsto, custo executado, fonte de financiamento, risco, paralisações, estouros, beneficiários previstos, resultado efetivo e histórico causal.

As causas de falha são rastreáveis: falta de dotação, capacidade ministerial baixa, risco de execução, interrupção de financiamento ou atraso operacional.

## 7. Interface

A identidade escura com âmbar foi preservada. As telas integradas são:

- Orçamento;
- Receitas;
- Ministérios;
- Projetos;
- Dívida;
- Serviços;
- Relatório do governo.

As telas priorizam tabelas, indicadores compactos, execução planejada versus realizada e explicações textuais. A navegação existente das fases A e B foi mantida.

## 8. Testes e regressão

Suíte executada:

```text
[game-generic-tests] PASS: 307 checks
```

Também foram corrigidos durante a validação:

- inferência `Variant` tratada como erro em `public_project_system.gd`;
- conflito entre classe global e autoload do tutorial;
- fallback do tutorial em execução headless/import;
- versão do save alinhada ao contrato vigente (`SAVE_VERSION = 6`).

O encerramento headless ainda informa vazamentos de RIDs/ObjectDB do ambiente de teste. Eles não causam falha funcional nem alteram o resultado dos 307 checks.

## 9. Limitações conhecidas

- Não há dados geográficos detalhados além das oito regiões já existentes.
- Custos e indicadores administrativos são parâmetros de simulação, não estatísticas oficiais.
- O relatório explica fatores contribuintes, não causalidade econométrica.
- A execução completa em três resoluções deve continuar sendo feita no fluxo visual do projeto.
- Os avisos de recursos gráficos no encerramento headless permanecem para investigação posterior.

## 10. Recomendações para a Fase D

1. Extrair mais blocos de apresentação de `main.gd` para componentes de tela.
2. Adicionar gráficos históricos específicos para orçamento, dívida, serviços e projetos.
3. Criar testes de propriedade para conservação de caixa, estoque de dívida e soma de alocações.
4. Adicionar cenários de estresse fiscal e choques de financiamento.
5. Fazer uma rodada de QA visual em 1366×768, 1600×900 e 1920×1080.
6. Avaliar uma camada de auditoria de contratos públicos e compras, sem introduzir eventos arbitrários.

## 11. Mandato completo (verificação de integração)

O ciclo exigido — formar governo, executar políticas, enfrentar orçamento e
parlamento e sofrer consequências sociais — passou a ser verificado de ponta a
ponta em `test/test_suite.gd` (`_run_mandate`). O teste inicia um governo
Incumbente, confere a composição da câmara, nomeia ministros, propõe um projeto
(viabilidade e obra), aprova uma lei, vota o orçamento, avança 48 meses, realiza
a eleição seguinte e fecha uma coalizão de governo minoritário.

Correções necessárias encontradas pelo teste:

- **Composição da câmara**: o cenário Incumbente somava as cadeiras do jogador
  ao snapshot completo (770 cadeiras numa câmara de 513). Agora a bancada do
  jogador entra no total e os demais partidos são reescalados proporcionalmente.
- **Base de governo**: `coalition_seats` é o total da base (bancada própria +
  parceiros). O cálculo de apoio somava também `lower_house_seats` e contava a
  bancada duas vezes. O mesmo erro foi corrigido na ratificação de tratados e no
  alerta da agenda.
- **Apoio orçamentário**: a fórmula não deixava uma maioria simples aprovar o
  próprio plano. Passou a `0,20 + 0,62 × participação na câmara`, com oscilação
  de ±1% (±5 cadeiras), mantendo as penalidades por déficit, impopularidade e
  instabilidade.
- **Receita de posse**: `Taxation.estimate` calcula a receita real sem mover
  tesouro nem conformidade; sem isso o primeiro orçamento era votado contra 0%
  de receita e caía mesmo quando o plano era viável.
- **Formação de governo**: a formação de coalizão deixou de depender de o país
  ser parlamentar. Qualquer governo abaixo da maioria vê o painel e pode fechar
  uma base; um presidente minoritário passa a ter caminho para aprovar orçamento
  e leis.

O resultado medido no teste: o plano padrão (29% do PIB) é rejeitado com receita
de 20% do PIB; o plano ajustado até os pisos (22,25%) é aprovado por 262 de 513
cadeiras. As votações somam exatamente a câmara. Após 48 meses, aprovação e apoio
social se movem e os grupos sociais reagem; a eleição seguinte abre novo ciclo.

```text
[game-generic-tests] PASS: 375 checks        (30 novos de mandato)
[ui-layout] 0 problema(s) em 3 tamanhos
[interaction] PASS: 1957 checks
```
