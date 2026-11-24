# Fase G — auditoria inicial e mapa de dependências

## Escopo auditado

A auditoria foi feita sobre os arquivos existentes do projeto Mandatia/Godot 4.7, sem criar um novo projeto e sem executar a suíte completa. A Fase F permanece uma camada derivada de informação em `state.phase_f`; a Fase G deverá ser uma camada de simulação social persistente, integrada ao ciclo mensal existente.

## Estado real encontrado

### 1. População e demografia

Não foi encontrado um estado demográfico dedicado. O catálogo econômico contém `population` por país como observação histórica do World Bank, mas esse valor não é evoluído pelo motor. O estado principal possui `demographics` legado, porém ele é um dicionário de apoio eleitoral derivado dos grupos sociais, não uma estrutura populacional.

**Conclusão:** criar um sistema novo e único de demografia agregada, com coortes, população total, nascimentos, mortes, migração, urbanização, dependência e histórico mensal. O valor de catálogo deve permanecer como âncora/fonte, sem ser sobrescrito.

### 2. Grupos sociais

`social_groups.gd` e `config/social_groups.json` já possuem duas camadas explicitamente separadas: ocupação e renda. Cada camada soma 1,0; uma pessoa pode estar representada nas duas camadas. O sistema já documenta o risco de dupla contagem e mantém compatibilidade com as categorias legadas Jovens, Trabalhadores, Empreendedores, Aposentados e Rurais.

**Conclusão:** reutilizar grupos como dimensões analíticas sobre uma população-base única. Não somar shares de ocupação e renda. A Fase G deve adicionar atributos demográficos e socioeconômicos sem transformar cada grupo em população independente.

### 3. Serviços públicos

`public_services_system.gd` já simula cobertura, qualidade, capacidade, demanda, infraestrutura e eficiência. A atualização mensal considera orçamento, ministério e infraestrutura, mas ainda não calcula resultados de saúde, educação, habitação ou segurança a partir da composição demográfica e das diferenças regionais.

**Conclusão:** integrar a Fase G depois da atualização de serviços, consumindo capacidade/qualidade/demanda como entradas. Não substituir o índice de serviços nem tratar dotação como resultado automático.

### 4. Finanças, tributação e orçamento

`taxation_system.gd`, `budget_system.gd` e o catálogo `public_administration.json` já oferecem receita, carga tributária, conformidade, categorias orçamentárias, pisos/tetos e execução. O modelo usa um PIB-índice de jogo, com parâmetros declarados, e não pretende representar diretamente valores fiscais oficiais.

**Conclusão:** políticas sociais devem consumir envelopes orçamentários e capacidade administrativa existentes. A Fase G não deve criar um segundo tesouro nem inventar impactos fiscais fora dos sistemas de orçamento/projetos.

### 5. Ministérios e projetos

`public_project_system.gd` já possui proposta, viabilidade, aprovação, financiamento, obras, paralisação, operação, empregos, beneficiários e ganhos de serviço. Projetos podem ampliar capacidade e cobertura, mas os benefícios são agregados e não possuem resultados demográficos ou regionais detalhados.

**Conclusão:** usar projetos concluídos como entradas graduais para capacidade social; políticas da Fase G devem registrar beneficiários, regiões, instituição responsável, recursos, prazo, indicadores e riscos, sem aplicar o resultado integral no momento do anúncio.

### 6. Trabalho e emprego

O estado já possui desemprego agregado, inflação, crescimento e grupos ocupacionais. Não foi identificado no material auditado um sistema autônomo com força de trabalho, formalidade, salários reais, subemprego, produtividade, setores e incompatibilidade de competências.

**Conclusão:** criar um módulo agregado de trabalho/human capital dentro da Fase G, ancorado nos indicadores macro existentes. O módulo deverá preservar `state.unemployment` como compatibilidade, mas passar a derivá-lo de participação, emprego, informalidade e demanda setorial simulada.

### 7. Educação e saúde

Os serviços `educacao` e `saude`, os ministérios correspondentes e projetos como escolas técnicas, hospitais e centros de saúde já existem. Ainda não há coortes de matrícula, frequência, conclusão, qualificação, profissionais de saúde, leitos, espera, prevenção, mortalidade evitável ou expectativa de vida.

**Conclusão:** implementar resultados populacionais agregados, graduais e limitados pela capacidade instalada. Não criar prontuários individuais nem impactos imediatos iguais ao gasto.

### 8. Regiões

As oito regiões usadas pela interface e pelos projetos — Costa Norte, Serra Azul, Vale Central, Campos do Leste, Distrito Aurora, Planalto Sul, Lagos do Oeste e Fronteira Verde — são descritas como arquétipos de jogo em `main.gd`. Não há no catálogo de países uma divisão subnacional comparável entre todos os países suportados.

**Conclusão:** tratar essas regiões como regiões jogáveis estimadas/ficcionais, rotulando sua natureza no estado e na interface. Não apresentar as oito regiões como estatística oficial de cada país. A Fase G deve manter totais nacionais reconciliáveis e repartir indicadores por pesos modelados.

### 9. Mundo, migração internacional e humanitarismo

`world_sim.gd` simula países autônomos, economia, governos, partidos, eleições, acordos e histórico. A auditoria não encontrou, no material lido, um estoque demográfico internacional ou um registro unificado de migração comum e deslocamento forçado.

**Conclusão:** iniciar com migração ordinária interna e internacional agregada na Fase G, deixando um identificador de origem e destino. Antes de integrar deslocamento forçado da Fase E2, localizar o contrato específico dessa camada para evitar contar o mesmo fluxo duas vezes.

### 10. Histórico e persistência

`world_history.gd` mantém eventos com data, país, categoria, atores, consequências e status, com limites e deduplicação. `main.gd` possui estado central, save versionado, migração idempotente e chamadas `ensure` para sistemas existentes. `PhaseFInformation.ensure` já é chamado na criação e na migração.

**Conclusão:** a Fase G deverá usar `ensure`, versão própria, histórico limitado e `last_tick`, além de ser incluída na criação, migração e fechamento mensal antes do salvamento.

## Mapa de dependências proposto

```text
config/economy.json + config/countries.json
        │
        ├── âncoras nacionais: população, PIB per capita, região e fonte
        └── calibração declarada, sem sobrescrever observações

state principal
        │
        ├── DemographySystem: coortes, população, nascimentos, mortes, migração
        ├── SocialGroups: dimensões ocupacionais e de renda sem soma cruzada
        ├── PublicServices + Ministries + Projects: capacidade e entrega defasada
        ├── Budget + Taxation: recursos, restrições e custo de políticas
        ├── World/International: economia externa e migração internacional futura
        └── PhaseGInformation: relatórios, histórico e rastreabilidade social
```

## Ordem mensal recomendada

1. Sistemas macro, fiscal, ministérios, projetos e serviços existentes.
2. Atualização demográfica: envelhecimento, nascimentos, mortes e migração.
3. Atualização de saúde, educação, trabalho, renda, moradia e desigualdade da Fase G.
4. Atualização dos grupos sociais a partir dos resultados, sem duplicar população.
5. Registro de política, causalidade, eventos e indicadores derivados.
6. Fase F editorial/analítica, para noticiar fatos já produzidos.
7. Persistência do estado.

A ordem exata deverá ser confirmada no ponto real de fechamento mensal antes da integração.

## Lacunas e reparos necessários

- Criar contrato de estado para `state.phase_g` com migração segura.
- Criar dados demográficos por país ou uma camada de âncoras com `status: official/estimated/model`.
- Separar explicitamente população-base de dimensões sobrepostas.
- Criar oito regiões jogáveis com pesos e status `estimated`, sem alegar divisão oficial.
- Adicionar testes curtos de invariantes: população não negativa, coortes somando população, fluxos reconciliados, shares de grupos sem dupla contagem e efeitos graduais.
- Localizar o ponto de fechamento mensal e o contrato de migração humanitária antes de integrar migração internacional forçada.

## Decisão de implementação

A Fase G será implementada em módulos pequenos, começando por **G1 — Demografia e estrutura populacional**, depois saúde, educação, trabalho, renda/inequality, regiões, políticas e interface. Nenhum impacto numérico será atribuído apenas por existir gasto; todos os efeitos dependerão de capacidade, cobertura, tempo e restrições documentadas.

## Marco atual — G1

G1 foi implementada em `scripts/sim/demography_system.gd` e integrada a `main.gd`.

- População nacional ancorada no catálogo econômico, preservando o dado de origem.
- Coortes agregadas: crianças, adolescentes, jovens adultos, adultos em idade ativa e idosos.
- Nascimentos, mortes, envelhecimento, imigração, emigração e migração interna mensal.
- População urbana/rural, domicílios e razão de dependência.
- Fluxos limitados e graduais, condicionados por desemprego, serviços e habitação.
- Histórico mensal limitado e `last_tick` idempotente.
- Migração segura para saves que ainda não têm demografia.

G1 ainda não declara a Fase G completa: saúde, educação, trabalho detalhado, distribuição de renda, regiões, políticas sociais e interface permanecem pendentes. A validação headless continua pendente devido à limitação ambiental registrada na auditoria da Fase F.

O teste curto de invariantes foi criado em `test/test_phase_g_demography.gd`. Ele verifica população positiva, coortes reconciliadas com o total, nascimentos positivos e idempotência no mesmo mês. Não foi executado por causa da indisponibilidade do terminal Godot no ambiente (`terminal: config home unavailable`).

## Validação de horizonte longo

Como educação, demografia, saúde e mobilidade social produzem efeitos acumulados, cada módulo da Fase G deverá ser validado em uma trajetória de pelo menos 20 anos/240 meses, além dos testes unitários curtos. O teste deve procurar especificamente:

- crescimento ou contração populacional implausível;
- transições etárias instantâneas ou coortes que deixem de somar a população;
- urbanização, dependência ou migração fora dos limites documentados;
- efeitos de saúde, educação e mobilidade social grandes demais nos primeiros meses;
- inflação de indicadores causada por dupla contagem entre grupos, regiões e população-base;
- perda de rastreabilidade entre dado oficial, estimativa e variável puramente modelada.

O primeiro teste de horizonte longo foi criado em `test/test_phase_g_long_horizon.gd`. Ele percorre 240 meses de G1, controla limites de população, coortes, urbanização, dependência e preservação da âncora de dados. Ainda não foi executado por causa da indisponibilidade do terminal Godot.

## Política de dados da Fase G

Os dados devem manter a convenção já usada pelo projeto:

1. `official`: observação publicada por fonte oficial, com ano, indicador, código e URL quando disponíveis.
2. `estimated`: valor derivado por metodologia declarada quando não houver observação adequada; deve manter a fonte da referência e explicar o método.
3. `model`: parâmetro ou trajetória criada pelo simulador; nunca deve ser apresentada como estatística observada.

O estado simulado deve guardar a proveniência junto ao indicador. Valores oficiais de população, PIB, saúde ou educação servem como âncoras e não devem ser sobrescritos. Distribuições etárias, cobertura regional e indicadores ausentes podem começar como estimativas, mas precisam ser rotulados e submetidos a análise de sensibilidade no horizonte longo.
