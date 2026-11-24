# Fase H — Auditoria inicial e avaliação de dependências

**Tarefa:** Fase H — Tarefa 1  
**Status:** auditoria concluída; nenhuma mudança de código da Fase H aplicada nesta tarefa.  
**Projeto:** Mandatia, projeto Godot 4.7 existente.  
**Escopo auditado:** campanhas eleitorais avançadas, comunicação política, mobilização territorial e financiamento de campanha.

## 1. Objetivo da auditoria

A Fase H não deve substituir o motor eleitoral existente por um modificador genérico de popularidade. A auditoria foi realizada para identificar o que já funciona, o que pode ser reutilizado e quais estruturas persistentes precisam ser criadas antes de implementar novas mecânicas.

A decisão desta tarefa é evoluir o sistema atual por camadas, preservando saves, regras eleitorais e o limite de ações já existente. A campanha deverá produzir efeitos separados — organização, reconhecimento, familiaridade, saliência, credibilidade, mobilização e comparecimento — que serão consumidos pelos sistemas apropriados. Nenhuma ação nova deve converter diretamente todo esse conjunto em votos.

## 2. Sistemas existentes confirmados

### 2.1 `campaign_system.gd`

O sistema atual já fornece uma base funcional de campanha:

- limite preservado de **três ações por mês**;
- catálogo de ações carregado de `config/campaign_actions.json`;
- custos explícitos em recursos da campanha;
- efeitos sobre campanha, reconhecimento, regiões e grupos sociais;
- ações nacionais e regionais;
- captação privada e financiamento público básicos;
- risco financeiro/jurídico simplificado;
- registro causal de efeitos;
- análise regional de desempenho.

Essa camada deve continuar sendo o ponto de execução das ações mensais. H1 não deve criar uma segunda fila concorrente de ações nem remover `campaign_actions`.

### 2.2 `election.gd`

O motor eleitoral existente deve ser tratado como autoridade para a conversão institucional dos resultados de campanha:

- regras eleitorais por câmara;
- modelos parlamentar e presidencial;
- distribuição proporcional por **D’Hondt**;
- segundo turno presidencial;
- apoio por grupos e regiões;
- pesquisas eleitorais e leitura do apoio acumulado.

A Fase H deverá alimentar esse motor com variáveis intermediárias mais ricas, mas não substituir D’Hondt, o segundo turno ou as regras específicas de cada câmara.

### 2.3 Ideologia, mídia e pesquisas

`ideology_system.gd` já representa posições em dois eixos e compatibilidade ideológica. `phase_f_information.gd` fornece mídia simulada, pesquisas, relatórios, rastreabilidade e distinção entre informação observada e modelada. Esses sistemas são dependências de H4/H5, especialmente para credibilidade, saliência, cobertura jornalística e interpretação das mensagens.

A Fase H deve preservar a separação entre:

- **comunicação paga de campanha**, que consome orçamento de campanha e produz alcance, familiaridade ou mobilização conforme o canal;
- **jornalismo independente**, que pode cobrir, investigar, comparar ou contestar a campanha sem ser tratado como publicidade controlável pelo candidato.

### 2.4 Demografia e regiões

A Fase G1 já criou estado demográfico persistente e indicadores territoriais. O apoio regional existente e os dados de regiões em `main.gd` são dependências diretas para organização territorial, voluntários, filiais, alcance de eventos e mobilização.

A campanha não deve duplicar população ou território. Quando uma mecânica precisar de denominador populacional, densidade, urbanização ou composição regional, deverá consultar `state.demography` e os dados territoriais existentes.

## 3. Catálogo atual e limites observados

`config/campaign_actions.json` declara custos, alcance, mecanismos, grupos afetados, risco e dicas de uso. O catálogo já diferencia, entre outras ações, debate, comício regional, entrevista, anúncio de política, publicidade, mobilização comunitária, campanha segmentada, endosso e resposta a crise.

O catálogo, entretanto, ainda é uma representação compacta. Ele não descreve de forma independente:

- canal de comunicação;
- audiência primária e secundária;
- capacidade organizacional necessária;
- saturação e frequência;
- origem e categoria do recurso gasto;
- efeito sobre awareness, familiaridade, saliência, credibilidade, mobilização e comparecimento;
- obrigações de prestação de contas;
- vínculo com candidato, partido, filial ou comitê regional.

Essas lacunas serão tratadas progressivamente. Não será feita uma reescrita indiscriminada do catálogo antes de existir o estado persistente que irá consumi-lo.

## 4. Dependências e lacunas da Fase H

### H1 — Organização partidária

**Dependências:** `main.gd`, regiões, apoio regional, recursos existentes da campanha e migração de saves.  
**Lacunas:** não há uma estrutura completa para organização partidária persistente.

H1 deverá criar um estado versionado para representar, no mínimo:

- presença e força organizacional por região;
- filiais e núcleos territoriais;
- voluntários e equipe profissional;
- capacidade mensal de execução;
- manutenção e desgaste organizacional;
- cobertura de regiões e capacidade de mobilização;
- relação entre organização e as ações atuais, sem substituí-las.

O sistema deverá ser idempotente e compatível com saves antigos por meio de `ensure()` e valores padrão conservadores.

### H2 — Candidatos estruturados

**Dependências:** líder atual, partidos oficiais, ideologia, eleições e governos.  
**Lacunas:** candidatos ainda não formam um sistema independente com identidade, carreira e atributos persistentes.

H2 deverá separar partido, candidato, titular, desafiante e eventual lista parlamentar. Também deverá permitir seleção e carreira sem quebrar o líder atual nem presumir que toda eleição presidencial e parlamentar usa a mesma estrutura.

A ideologia do candidato deverá reutilizar os dois eixos existentes. Biografias e reputação poderão aproveitar a Fase F, mas não devem transformar rótulos editoriais em fatos observados.

### H3 — Financiamento e conformidade

**Dependências:** recursos de campanha existentes, orçamento público quando aplicável, ações atuais e causal log.  
**Lacunas:** o financiamento atual tem limites e risco básicos, mas não possui contabilidade detalhada por categoria, origem, transferência e prestação de contas.

H3 deverá introduzir, de maneira auditável:

- saldo de caixa da campanha;
- receitas por categoria e origem;
- despesas por categoria e região;
- transferências entre partido, comitê, candidato e filial sem dupla contagem;
- compromissos futuros;
- prestação de contas;
- conformidade e risco jurídico;
- trilha causal das decisões financeiras.

As regras legais reais só deverão ser usadas quando houver dados oficiais aplicáveis ao país e ao modelo da eleição. Onde os dados faltarem, o jogo utilizará um **modelo simplificado**, explicitamente identificado como modelado. Não serão inventados limites legais reais para preencher lacunas.

### H4 — Comunicação e mídia

**Dependências:** `phase_f_information.gd`, pesquisas, grupos sociais, ideologia e catálogo de ações.  
**Lacunas:** publicidade, mensagens, debates e cobertura jornalística ainda não formam sistemas separados.

H4 deverá distinguir mensagem, canal, audiência, alcance, frequência, custo, risco e credibilidade. Publicidade paga não deverá editar notícias independentes. Debates poderão afetar familiaridade, saliência e credibilidade; sua repercussão deverá passar pela camada de informação e por consequências rastreáveis, não por um bônus universal de votos.

### H5 — Mobilização e comparecimento

**Dependências:** H1, regiões, demografia, pesquisas e motor eleitoral.  
**Lacunas:** mobilização territorial é parcialmente representada por apoio regional, mas não há capacidade organizacional, cobertura, esforço de comparecimento e turnout separados.

H5 deverá modelar a cadeia organização → contato/mobilização → probabilidade de comparecimento → resultado eleitoral. O apoio regional continuará sendo uma entrada do motor eleitoral, não será substituído por um novo placar incompatível.

## 5. Decisões de preservação obrigatória

As seguintes regras são invariantes da Fase H:

1. O limite de **três ações de campanha por mês** permanece vigente.
2. `campaign_actions.json` e `campaign_system.gd` continuam sendo utilizados; novas camadas devem integrar-se a eles.
3. **D’Hondt** permanece no cálculo proporcional das câmaras que o utilizam.
4. O **segundo turno presidencial** permanece ativo quando previsto pelas regras do país.
5. Os modelos **parlamentar e presidencial** continuam distintos.
6. A campanha não será implementada como um único modificador de popularidade.
7. Comunicação paga e jornalismo independente permanecem separados.
8. Recursos reais — caixa, orçamento, equipe, voluntários e capacidade regional — devem limitar as ações.
9. Saves antigos devem ser migrados sem apagar estado válido nem aplicar efeitos retroativos não justificados.
10. Nenhuma Fase H será declarada concluída sem testes direcionados e, quando possível, simulações de horizonte longo.

## 6. Política de dados

A Fase H seguirá a política já usada no projeto:

- **Oficial:** regras eleitorais, câmaras, partidos e autoridades quando provenientes de fonte oficial identificada.
- **Estimado:** valores derivados de fontes incompletas ou aproximações documentadas; devem ser marcados como estimados.
- **Modelado:** variáveis criadas pela simulação, como capacidade organizacional, alcance de uma mensagem, desgaste, risco simplificado e efeito de mobilização; não devem ser apresentados como estatísticas observadas.

Configurações e relatórios deverão carregar metadados ou rótulos suficientes para que o jogador diferencie dado institucional, estimativa e variável do modelo.

## 7. Plano de implementação decidido

A ordem aprovada para a próxima etapa é:

1. **H1:** criar o estado persistente de organização partidária e sua migração, com integração mínima às ações existentes.
2. **H2:** criar candidatos estruturados, seleção e carreira, reutilizando partidos, ideologia e regras eleitorais já existentes.
3. **H3:** ampliar financiamento com categorias, saldos, transferências, prestação de contas e riscos, evitando dupla contagem.
4. **H4:** separar comunicação, mensagens, publicidade, debates e cobertura de mídia.
5. **H5:** conectar organização e comunicação à mobilização regional e ao comparecimento sem conversão universal direta em votos.
6. Criar testes curtos por camada e testes de horizonte longo para verificar estabilidade, limites, migrações e ausência de crescimento explosivo.

A próxima tarefa de implementação será **Fase H — Tarefa 2: H1, estado persistente de organização partidária**. Esta auditoria não altera o código e não inaugura ainda essa implementação.

## 8. Validação e limitações ambientais

A auditoria foi estática e baseada nos arquivos existentes. A tentativa anterior de executar o teste demográfico de 20 anos não chegou a iniciar o Godot por falha ambiental `terminal: config home unavailable`. Portanto, não há nesta tarefa um resultado novo de execução headless nem uma declaração de estabilidade dinâmica.

A limitação deve permanecer registrada até que testes direcionados possam ser executados com sucesso. A suíte completa não deve ser executada sem autorização explícita.

## 9. Resultado da tarefa

A **Fase H — Tarefa 1** está concluída em nível documental: o estado atual, as dependências, as lacunas, as invariantes e a ordem de implementação foram registrados. Nenhuma mudança de código da Fase H foi aplicada, preservando integralmente o comportamento atual enquanto H1 não é iniciado.
