# Mandatia — Fase D: relações internacionais, diplomacia e geopolítica

## Auditoria D0

As fases A, B e C já estavam integradas: `countries.json`, `economy.json`,
tela Internacional, avanço mensal, saves versionados e suítes headless. A tela
Internacional anterior apenas exibia uma cena anual gerada por IA/fallback. Não
existiam relações bilaterais persistentes, comércio, tratados, sanções,
investimentos, organizações, blocos ou eventos internacionais causais.

O catálogo existente tem 35 países e snapshots com `data_as_of` 2026-11-14.
`economy.json` preserva dados históricos do World Bank WDI, marca valores
oficiais/estimados e separa `value` de `simulation_value`. Esses catálogos foram
reutilizados; nenhum líder, partido ou estatística foi inventado.

## Núcleo determinístico (`scripts/sim/international_system.gd`)

- **Perfis (D1)**: governo/orientação, estabilidade, PIB, crescimento, inflação,
  desemprego, dívida, população e data de referência, derivados dos catálogos.
- **Relações multidimensionais (D2)**: cooperação, alinhamento político,
  parceria econômica, interdependência comercial, confiança estratégica,
  cooperação de segurança, tensão e reconhecimento — variáveis distintas que
  evoluem por regras, não por um único número de amizade.
- **Política externa (D3)**: nove doutrinas; trocar custa caixa e credibilidade.
- **Comércio bilateral (D4)**: exportações/importações/balanço dependentes de
  acesso e interdependência; não soma fluxo comercial novamente ao PIB.
- **Tratados (D5)**: acordos comerciais com objetivo, duração, custo, benefício e
  `pending_ratification`; `ratify_treaty` exige Executivo e maioria parlamentar.
- **Organizações (D5)**: ONU, OMC e Banco de Desenvolvimento com regra,
  compromisso e votos; o voto não altera leis domésticas automaticamente.
- **Sanções (D6)**: exigem tensão mínima; aplicam custo de crescimento/inflação,
  retaliação e risco humanitário registrado; também afetam o jogador.
- **Investimento e financiamento (D9)**: investimento privado registrado fora da
  receita pública; `foreign_loan` usa `Debt.issue_bond`, entra no livro de dívida
  e exige juros/amortização (não é dinheiro grátis).
- **Blocos (D10)**: integração regional, cooperação atlântica e coalizão de
  autonomia; adesão formal limita escolhas e registra compromissos.
- **Eventos e crises (D8)**: instabilidade externa + dependência comercial gera
  evento e crise multietapa com respostas (negociar/diversificar/isolar).
- **Interconexão (D12)**: `International.monthly` altera economia, inflação,
  desemprego e aprovação; sanções e dependência comercial modulam o crescimento.

## Ciclo diplomático mensal

O ciclo é determinístico e acontece dentro de `International.monthly`, sempre na
mesma ordem. Nenhuma chamada de IA é necessária.

1. **Deriva**: estabilidade dos perfis, cooperação/confiança e comércio evoluem
   por regra. `stance()` lê a relação e classifica o parceiro em cooperativo,
   pragmático, assertivo ou hostil — postura não é variável independente.
2. **Tratados**: `pending_ratification` conta meses e caduca em 6 sem
   ratificação; `active` conta a vigência e expira no prazo declarado, com perda
   de cooperação e confiança. Tratados de comércio, segurança e regional têm
   custo, duração e efeitos próprios.
3. **Sanções**: prazo de 12 meses, sem duplicata contra o mesmo país; o custo de
   crescimento/inflação e a retaliação são cobrados todo mês e a tensão sobe
   enquanto durar. Ao expirar, o custo mensal termina.
4. **Crises**: inação não congela o problema — a cada dois meses sem resposta o
   estágio avança, com custo econômico e mais tensão. A resposta final recompõe
   a relação (negociar corta mais tensão que isolar).
5. **Ofertas de parceiros**: países cooperativos propõem acordo comercial ou
   consulta de segurança; países assertivos/hostis enviam demandas; parceiros
   instáveis pedem ajuda. Cada oferta tem prazo (3–4 meses) e expira sem
   resposta, com perda de confiança. Aceitar/recusar é uma decisão com efeito
   (caixa, tratado pendente, concessão ou firmeza).
6. **Organizações**: adesão é derivada de regra, não declarada. ONU é membro;
   OMC exige tratado comercial/regional ativo; Banco de Desenvolvimento exige
   dívida ≤ 90% do PIB. Sem adesão, o voto é recusado com o motivo.
7. **Blocos**: `join_bloc` verifica a condição antes de cobrar: integração sul
   exige país sul-americano e tratado com vizinho; cooperação atlântica exige
   doutrina de segurança/autonomia e acordo de segurança ativo; coalizão de
   autonomia exige doutrina de autonomia ou não alinhamento. Adesão repetida é
   recusada.

Regras de consistência aplicadas junto: ação diplomática desconhecida não gasta
caixa; investimento e empréstimo externo exigem relação compatível; ações do
jogador chamam `International.refresh` (recalcula o resumo) em vez de simular um
mês extra a cada clique.

## Integração (`scripts/main.gd`)

- `Government.monthly()` seguido de `International.monthly()` no avanço mensal.
- `International.ensure()` migra saves antigos sem perder dados (idempotente).
- Tela Internacional reescrita como sala de situação compacta: doutrina e
  credibilidade; países com métricas multidimensionais e ações (reunião,
  protesto, acordo, sanção, investir); eventos; instituições (tratados com
  RATIFICAR, organizações com VOTAR, blocos com ADERIR e empréstimo externo);
  crises multietapa com respostas. Identidade escura/âmbar e Figtree mantidas.

## Correção de codificação (importante)

`scripts/main.gd` estava com dupla codificação (mojibake) armazenada como UTF-8
válido: acentos apareciam como `Ã£`/`Ã§` e parte do texto como `Ã—`/`Ã‡` (bytes
UTF-8 lidos como CP1252). Isso quebrava comparações de strings acentuadas na
navegação (`match selected_nav`), na barra lateral (`_rail_enabled`) e em chaves
como `"Saúde"`, fazendo 9 testes falharem e a UI exibir texto corrompido. O
arquivo foi reparado em duas passagens (latin-1 e depois CP1252) e agora é UTF-8
correto. Os demais arquivos do projeto já estavam corretos; só `main.gd` estava
afetado. Nenhuma alteração de comportamento além de corrigir texto e
comparações.

## Dados e metodologia

Valores históricos permanecem nos catálogos com fonte, unidade e ano. Após o
início da campanha, perfis evoluem por regras determinísticas. A relação inicial
usa região e condições econômicas como ponto de partida. Comércio é fluxo
bilateral simulado. Investimento privado não aumenta `funds` nem receita
tributária. Sanção afeta a economia por exposição e registra custos; não é bônus
de popularidade. Regiões vêm dos registros existentes; efeitos econômicos são
aproximações de gameplay, não previsões econométricas. Não há dependência de
Ollama: todo o núcleo é determinístico.

## Testes executados

```text
[game-generic-tests] PASS: 345 checks        (test/test_suite.gd)
[ui-layout] 0 problema(s) em 3 tamanhos       (test/test_ui_layout.gd, 1600x900 / 1366x768 / 1920x1080)
[interaction] PASS: 1957 checks               (test/test_interaction.gd)
```

Os 30 checks novos cobrem: determinismo do mês, geração autônoma de ofertas sem
ação do jogador, crise aberta por instabilidade do parceiro, ação desconhecida
sem custo, `refresh` sem simular mês, aceitar/recusar demanda, oferta comercial
aceita (pendente de ratificação), oferta vencida, expiração de tratado ativo,
caducidade de tratado sem ratificação, sanção duplicada/prazo/expiração,
agravamento de crise por inação, resolução de crise e recomposição da relação,
voto sem adesão, adesão à OMC por tratado ativo, condições dos blocos e
bloqueios de investimento/empréstimo. O teste de interação passou de 1945 para
1957 checks: os botões VOTAR de OMC/Banco (não membros) viraram rótulo "NÃO
MEMBRO" e a mesa de negociação acrescentou ACEITAR/RECUSAR focáveis.

Os rótulos longos dos painéis de instituições e crises expandem na horizontal
(antes colapsavam para ~1 px e esticavam os botões verticalmente).

QA visual anterior: `screenshots/internacional_1366x768.png`,
`internacional_1600x900.png` e `internacional_1920x1080.png` (jogo real). Essas
imagens são anteriores ao painel "Mesa de negociação"; o painel novo foi
verificado pelo teste de layout headless, não por captura atualizada.

## O que ainda não está completo

- A tela Internacional é uma sala única com painéis empilhados; não há abas
  separadas de Visão geral/Países/Comércio/Organizações/Eventos/Política.
- O comércio usa setores genéricos ("bens e serviços"); não há decomposição por
  setor nem concentração exportadora detalhada.
- Financiamento externo não está ligado ao ciclo completo de projetos públicos
  (apenas ao livro de dívida).
- Organizações têm adesão por regra e votos registrados, mas as resoluções
  continuam não vinculantes; não há fundos regionais nem campanha por voto.
- Blocos verificam condição de adesão, mas ainda não têm padrão comum,
  orçamento próprio nem sanção interna por descumprimento.
- Falta busca/filtro na lista de países (a lista é completa e rolável).

Esses pontos não foram mascarados como concluídos. A Fase E não foi iniciada:
primeiro o ciclo da Fase D precisava estar funcional e testado, como este
documento registra.

## Próxima etapa recomendada

Separar a tela em abas e adicionar busca de países, decompor comércio por setor
e ligar financiamento externo ao `public_project_system`. Só então avaliar a
Fase E, reutilizando as regras e os testes deste ciclo como contrato.

Cada incremento deve manter os testes headless passando e rodar o QA visual nas
três resoluções.
