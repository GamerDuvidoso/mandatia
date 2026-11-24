# Mandatia — Fase A: consolidação da fundação

Registro de desenvolvimento da Fase A. Cobre o patch de mecânicas já aplicado,
o walkthrough, os perfis econômicos dos 35 países, o onboarding, os objetivos de
mandato, os gráficos históricos, a explicabilidade e o refinamento visual.

## A1. Patch de mecânicas consolidado

- Branch `melhorias-mecanicas`, commit `22700ad` (eventos, receita, programas,
  coalizão e leis revisados). Nenhuma alteração não intencional foi descartada.
- Eventos determinísticos sem Ollama: `scripts/sim/events.gd` sorteia por peso,
  evita repetição recente, oferece três opções e aplica efeitos uma única vez.
  A suíte exercita 40 sorteios, elegibilidade e não repetição.
- Receita e consistência financeira: `_monthly_income()` soma contribuições,
  doações e, no governo, arrecadação ligada a PIB/aprovação, descontando a
  manutenção dos programas. A suíte confere custo de programa, manutenção
  mensal, efeito mensal e ausência de caixa negativo.
- Voto: `Election.player_share()` combina popularidade, os cinco grupos sociais
  (pesos 22/34/12/16/16), as oito regiões e o voto retrospectivo de aprovação.
  A suíte verifica aprovação, grupos sociais e apoio regional separadamente.

## A2. Walkthrough, testes e limpeza

Causa dos 36 erros: o walkthrough ainda procurava os antigos botões planos
(`Eleições`, `Congresso`, `Governo`...) enquanto a navegação passou a ter duas
faixas (rail de grupos + faixa contextual). Não era regressão de gameplay.

- `tools/walkthrough.gd` agora abre o grupo correto (`PAÍS`, `PODER`, `ECON`,
  `MUNDO`, `REGIS`) antes de clicar no item, aceita telas sem rail lateral e usa
  o botão `MENU` do rail.
- Recurso ausente encontrado: `Sora-VF.subset.woff2` era referenciado por quatro
  `.tres` de display e não existia no repositório. Restaurado do Google Fonts
  (Sora, OFL — licença já presente) e reimportado.
- Arquivos mortos do template removidos após confirmar que nenhuma cena, script
  ou preload os usava: `scripts/entities/runner.gd`, `scripts/entities/sentinel.gd`,
  `scripts/game/maze_world.gd`, `scripts/ui/title_art.gd`, `scripts/ui/menu_list.gd`
  (e respectivos `.uid`). Eles referenciavam texturas inexistentes.
- `scripts/game/stage_catalog.gd` foi mantido: ainda é referenciado pelo
  scaffolding de localização/score (`autoload/save_store.gd`,
  `scripts/score/run_score_service.gd`), que não é carregado pelo jogo.

## A3. Perfis econômicos dos 35 países

`config/economy.json` (schema 1) traz, para cada país, nove indicadores com
`value`, `unit`, `year`, `status` (`official`/`estimated`), `source`, e
`methodology` quando estimado. Os quatro indicadores simulados também têm
`simulation_value` e, quando o valor real sai da faixa que o jogo representa,
uma nota de `calibration` (o valor observado é preservado em `value`).

Fonte: **World Bank, World Development Indicators (WDI)**, API pública
(`api.worldbank.org`), janela 2019–2024 para inflação/desemprego/PIB e
2000–2024 para dívida (observação oficial mais recente disponível).

| Indicador | Oficial | Estimado | Cobertura |
|---|---:|---:|---|
| Crescimento do PIB | 35 | 0 | 100% oficial, 34 valores distintos |
| Inflação (IPC) | 33 | 2 | VE e CU estimados |
| Desemprego | 31 | 4 | AG, DM, GD, KN estimados |
| Dívida do governo central | 20 | 15 | 15 estimados por mediana regional |
| PIB nominal | 35 | 0 | contexto |
| PIB per capita | 35 | 0 | contexto |
| População | 35 | 0 | contexto |
| Receita do governo | 22 | 13 | contexto |
| Despesa do governo | 22 | 13 | contexto |

Totais nos quatro indicadores simulados: **119 observações oficiais e 21
estimativas**. Toda estimativa é marcada na UI e na auditoria, com metodologia
(mediana regional de observações oficiais; nunca um número inventado).

Referências antigas de dívida (oficiais, mas anteriores a 2023) aparecem para
BO (2001), CL (2000), PE (2021), BZ (2014), CR (2001), GT (2013), BB (2016),
JM (2020), KN (2014), LC (2010), VC (2009) e TT (2007); o ano é exibido na tela.

Calibrações de jogo (valor real preservado em `value`): inflação da AR (219,88%
→ 15%), HT (26,95% → 15%), SR (16,23% → 15%); dívida da BB (125,03% → 120%);
piso de 20% para dívida da CL/TT; pisos de desemprego em 3,5% e teto de 18%.

Ferramentas:
- `tools/build_economy_profiles.py` baixa os dados, aplica as regras e grava o
  arquivo. `--offline` revalida sem rede.
- `tools/audit_economy.py` falha em perfil ausente, campo inválido, valor
  impossível, estimativa sem metodologia, oficial sem fonte/ano, calibração sem
  nota e perfis idênticos entre países.

A simulação começa nos valores do perfil e evolui sozinha; o dado histórico não
é recalculado a cada mês.

## A4. Onboarding e objetivos de mandato

- `scripts/ui/tutorial_callout.gd` foi reativado e ganhou botão **PULAR GUIA** e
  sinal `skipped`; não depende mais de `I18n` (que não é autoload no projeto).
- Oito cartões, um por tela/tema: quartel-general, partido, campanha, coalizão,
  plenário, gabinete/programas, indicadores e avanço mensal. Cada cartão aparece
  uma vez (`tutorial_seen`), pode ser pulado e é reiniciável em Configurações.
- A Agenda ganhou objetivos contextuais: situação atual (governo/oposição,
  cadeiras, meses), meta de aprovação ou reconhecimento, promessas no rumo,
  promessas em aberto e risco institucional no parlamentarismo. Nenhuma
  ideologia ou estratégia é imposta.

## A5. Gráficos históricos e explicabilidade

- `economy_history` agora registra também a dívida, e a tela Economia mostra a
  série real (crescimento, inflação, desemprego) em vez de curvas sintéticas.
- A "Trajetória" do dashboard passou a plotar o crescimento real do mandato,
  com linha zero, mínimo/máximo, variação total e variação do mês.
- Nova tabela **Desempenho no mandato**: início, mês atual, variação absoluta e
  percentual, direção e cor semântica (verde/vermelho pela direção desejável).
- Relatório do mês agora inclui **Fatores contribuintes**: convergência ao
  potencial, receita/manutenção, programas ativos, dívida acima de 60%,
  inflação acima da âncora e evento em aberto. O texto declara explicitamente
  que é correlação, não atribuição causal exata.

## A6. Refinamento visual

- Identidade escura + âmbar preservada; nenhuma nova linguagem visual.
- Números econômicos em fonte com `tnum` (Figtree via `FontVariation`), para
  alinhamento de colunas.
- KPIs e tabelas com hierarquia mais clara; fonte secundária em 11–13 px.
- Navegação: grupo ativo com barra âmbar à esquerda e fundo elevado; hover com
  borda; item contextual ativo com a mesma barra âmbar.
- Capturas em `docs/shots/fase-a-1600x900/`, `fase-a-1366x768/` e
  `fase-a-1920x1080/` (menu, programa, onboarding, dashboard, congresso,
  economia, economia-dados, regiões, população, eleições, resultado).
  Comparar com `docs/shots/globo-1600/` e `docs/shots/baseline/`.

## Testes

| Verificação | Antes | Depois |
|---|---|---|
| `test_suite.tscn` | 238 checks | **257 checks, PASS** |
| `test_interaction.gd` | 1037 checks | **1041 checks, PASS** |
| `test_ui_layout.gd` | 0 problemas em 3 tamanhos (1280/1600/1920) | **0 problemas em 1600×900, 1366×768 e 1920×1080** |
| `tools/walkthrough.gd` | 228 checks, 36 falhas | **221 checks, 0 falhas** (execução isolada) |
| `tools/soak_harness.gd` | — | **PASS: 242.658 checks, 35 países, 69 campanhas** |
| `tools/audit_economy.py` | — | **OK** (35 países, schema validado) |

Novos testes cobrem: perfis dos 35 países, fonte/ano oficial, metodologia de
estimativa, calibração, diferença Brasil/EUA, primeiro ponto da série, apoio
regional no voto, objetivos, fatores contribuintes, painel histórico e
onboarding (cartão abre e pode ser pulado). O soak rodou após a integração dos
perfis; a correção final da inicialização do crescimento é coberta pelo teste
de estresse de seis meses com crescimento -4,18% e macro no teto.

## Compatibilidade de save

- Versão 5 preservada (`SAVE_VERSION = 5`).
- `_migrate_state` preenche `economic_profile`, `month_factors` e
  `tutorial_seen` quando ausentes, sem sobrescrever economia, dívida, eventos ou
  qualquer indicador já salvo.
- Teste de save legado continua passando e agora também confere que o perfil é
  anexado para exibição.

## Limitações conhecidas

- 15 países não têm dívida observada no WDI na janela 2000–2024; o valor é uma
  mediana regional marcada como estimativa (a UI mostra a metodologia).
- 12 países têm dívida oficial antiga (2000–2021); o ano aparece na tela, mas a
  fotografia é histórica, não contemporânea.
- Inflação de VE e CU e desemprego de AG, DM, GD e KN são estimativas regionais.
- A calibração limita valores reais extremos à faixa que a simulação consegue
  representar; o valor observado permanece no arquivo.
- O guia é textual e de uma vez por tela; não há setas de destaque sobre cada
  controle.
- `stage_catalog.gd` permanece até o scaffolding de localização/score ser
  removido ou migrado.
- A Fase A não introduz ideologia em dois eixos, grupos de interesse, escândalos
  avançados, diplomacia avançada nem novos personagens (Fase B/C).

## Arquitetura após a Fase A

- `scripts/main.gd` — telas, calendário, campanha, governo, economia, onboarding,
  objetivos e explicabilidade (ainda concentrado, mas sem reescrita).
- `scripts/sim/` — `election.gd`, `coalition.gd`, `legislature.gd`, `events.gd`
  (regras puras, testáveis).
- `scripts/ui/` — tema único, bandeiras, globo, navegação e tutorial.
- `config/` — `countries.json` (política) e `economy.json` (economia com
  proveniência).
- `tools/` — auditorias, geração de dados, walkthrough, soak e capturas.

## Recomendação para a Fase B

Antes de abrir a Fase B: manter `audit_economy.py` no fluxo de CI, decidir se a
dívida estimada será substituída por uma fonte oficial por país (IMF WEO ou
tesouros nacionais) e extrair de `main.gd` o bloco de economia/relatórios para
um módulo próprio. Só então introduzir os dois eixos ideológicos e grupos de
interesse, que dependem de dados e votos já estabilizados.
