# MANDATIA — Fase B: profundidade política e simulação social

Registro de implementação, regras, dados, testes e limitações. A Fase B foi
construída sobre o estado real da Fase A: economias dos 35 países, onboarding,
série histórica, coalizão, legislativo e eventos determinísticos já estavam
presentes. Nenhum sistema existente foi substituído.

## 1. Sistemas concluídos

### B1 — Ideologia em dois eixos

- Eixo econômico: −100 (intervencionista/coletivista) a +100 (mercado).
- Eixo social: −100 (progressista) a +100 (conservador).
- `config/ideologies.json` mapeia as 11 categorias existentes e aplica
  overrides por país/partido quando há classificação manual validada.
- A posição do jogador é persistida em `ideology_position` e usada em:
  compatibilidade, coalizões, relações, facções, grupos sociais e transferência
  de voto no segundo turno.
- O gráfico `scripts/ui/ideology_chart.gd` desenha todos os partidos do país,
  destaca o jogador em âmbar e mostra compatibilidade e relação com os três
  partidos mais próximos.
- As posições são **classificação analítica**, não dado oficial do partido.

### B2 — Grupos sociais e população

- 12 grupos em **duas camadas independentes**:
  - ocupacional (9): industriais, serviços, servidores, empresários, rurais,
    estudantes, aposentados, desempregados, informais;
  - renda (3): baixa, média, alta.
- Cada camada soma 1,0. Uma pessoa pode aparecer em uma categoria ocupacional e
  em uma faixa de renda, mas o índice eleitoral usa **somente a camada
  ocupacional**; as camadas nunca são somadas entre si.
- Cada grupo guarda participação, satisfação, aprovação, condição econômica,
  preferências, preocupações, sensibilidade a políticas e histórico de até 24
  meses.
- `config/social_groups.json` declara a incidência de cada política com uma
  explicação mecânica. Exemplo: salário mínimo eleva industriais/serviços/baixa
  renda e reduz empresários/alta renda; previdência reduz aposentados e eleva
  renda alta/empresários.
- O mês atualiza satisfação por conjuntura (crescimento, inflação, desemprego),
  alinhamento ideológico e aprovação. As cinco categorias legadas usadas pela
  eleição (`Jovens`, `Trabalhadores`, `Empreendedores`, `Aposentados`, `Rurais`)
  são recalculadas a partir dos grupos detalhados.

### B3 — Organizações de interesse

- Sete organizações: central sindical, confederação empresarial, federação
  agropecuária, conselho profissional, rede socioambiental, união estudantil e
  sindicato do serviço público.
- Cada uma tem influência, população representada (modelo), pauta, alinhamento
  em dois eixos, relação com o jogador, capacidade de negociação e atividade.
- A relação evolui mensalmente com aprovação, alinhamento, coesão da coalizão e
  políticas aprovadas. Reforma trabalhista afasta a central sindical; crédito
  rural aproxima a federação agropecuária.
- Ações do jogador na tela Sociedade:
  - **Negociar** (M$ 800): +14 de relação e +3 de satisfação no grupo ligado.
  - **Pedir apoio**: exige relação ≥ 20, gera campanha/popularidade e consome
    relação.
- Sindicatos em greve: a queixa acumula relação hostil, insatisfação do grupo
  ligado, inflação, políticas recentes contrárias e coalizão fraca. Ao cruzar o
  limiar (55; 50 no serviço público), com cooldown de quatro meses, a greve
  começa e persiste. Durante a greve, a organização não endossa o governo;
  negociar custa M$ 1.400 e encerra o conflito com acordo. A greve custa
  aprovação, produção/PIB, inflação, desemprego, dívida e coesão — não é um
  modificador aleatório.

### B4 — Relações partidárias, coalizões e facções

- Matriz `party_relations` com chave canônica `A|B`, faixa −100..+100.
- A relação nasce da distância em dois eixos, mas evolui com votação
  parlamentar, coalizão, renegociação, reforço da base, rompimento e crises.
- A coalizão usa posição 2D + relação acumulada. Cada parceiro apresenta:
  cadeiras, número de pastas, exigência programática (uma proposição concreta),
  relação e estabilidade. Texto que contraria a pauta retira votos do aliado e
  reduz coesão/relação; violação persistente pode romper o acordo. As pastas são
  distribuídas ao nomear ministros e cobradas após três meses.
- O jogador pode **renegociar termos** (M$ 350): −15% de custo, +6 de coesão,
  +4 de relação com cada parceiro; a ala ideológica perde satisfação.
- Três facções do partido do jogador: base militante, ala ideológica e ala
  pragmática. Cada uma tem peso, posição, lealdade, satisfação e pauta.
  - Satisfação baixa gera crítica pública e perda de coesão.
  - Abaixo de 18 surge desafio à liderança; o jogador pode conceder espaço
    interno (M$ 600), recuperando coesão e satisfação.
- Votos já apurados recebem um deslocamento limitado por relação hostil,
  disciplina de facção e escândalo ativo. O voto ideológico continua dominante.

### B5 — Escândalos, investigações e crises

- Sete categorias: corrupção, irregularidade financeira, financiamento de
  campanha, abuso de autoridade, conflito de interesses, falha administrativa e
  favorecimento político.
- Seis estágios: alegação → cobertura → reação pública → investigação →
  consequências → resolução.
- Status jurídicos distintos: não comprovado, em apuração, misconduta
  confirmada, absolvição e caso sem desfecho.
- O risco mensal sobe com credibilidade baixa, coalizão frágil, financiamento
  privado e governo. Casos novos usam RNG com semente derivada de ano/mês/câmara.
- Respostas: cooperar, abrir investigação interna, afastar envolvido, defender
  publicamente e pacote de transparência. Cada uma tem custo/trade-off.
- **Não existe botão de suprimir instituições.** Defender publicamente aumenta a
  exposição; cooperar e investigar aumentam a chance de absolvição, mas expõem o
  caso.
- Consequências: aprovação, credibilidade, coesão, penalidade eleitoral,
  relações partidárias, coalizão e grupos. Casos confirmados permanecem no
  histórico. A cobertura midiática (`media`) amplia o custo; o procedimento vai
  de alegação a inquérito, cooperação, fase judicial e encerramento. Cooperar
  reduz cobertura, mas não converte alegação em culpa.

### B6 — Campanha avançada

- A economia de **três ações por mês** foi preservada.
- Nove ações declaradas em `config/campaign_actions.json`: debate, comício,
  mídia, anúncio de política, publicidade, mobilização comunitária, campanha
  segmentada, endosso e resposta a crise.
- Região-alvo e grupo-alvo são escolhidos na tela. Comício e campanha
  segmentada elevam `region_support`; grupos recebem satisfação; reconhecimento
  e campanha sobem com retorno decrescente.
- Financiamento:
  - privado: M$ 2.500/mês até M$ 6.000, +9 de risco por captação;
  - público: M$ 1.200/mês até M$ 2.400, sem risco;
  - relatório mensal e teto por campanha.
- A eleição lê apoio social detalhado, regiões, campanha, reconhecimento,
  retrospecto e penalidade de crise. D'Hondt, segundo turno (agora 2D), regras
  eleitorais e dados oficiais dos partidos continuam intactos.

### B7 — Causalidade e efeitos encadeados

A revisão B7 substituiu efeitos soltos por mecanismos persistentes. O objetivo
é que o jogador consiga responder "por que isto aconteceu?" olhando o estado.

- **Greve é processo, não evento instantâneo.** A queixa de cada organização é
  um estoque que sobe com relação hostil, satisfação baixa do grupo ligado,
  inflação, políticas recentes contra a pauta e coalizão fraca. Ao cruzar o
  limiar, o sindicato entra em greve por vários meses. A greve ativa reduz
  produção/PIB, eleva inflação e desemprego, pressiona dívida e aprovação,
  reduz a coesão da coalizão, custa caixa no serviço público e derruba a
  satisfação do grupo ligado. Negociar encerra o conflito com custo fiscal e
  melhora relação/satisfação; o acordo registra a cadeia causal.
- **Coalizão tem programa e cota de pastas.** Cada termo aponta para uma
  proposição concreta (`welfare`, `deregulation`, `pension`, `transparency` ou
  `investment`) e seu eixo. Texto que cumpre a pauta eleva relação/coesão;
  texto contrário retira votos do aliado no plenário, reduz coesão e pode
  romper a coalizão. As pastas prometidas são distribuídas automaticamente
  quando o jogador nomeia ministros; três meses sem entrega geram cobrança,
  perda de relação e risco de queda. A relação alterada alimenta a próxima
  negociação.
- **Escândalo tem cobertura e procedimento.** Cada caso carrega `media`
  (0–100), `procedure` (alegação, cobertura, reação, inquérito, cooperação,
  judicial, encerrado) e evidência 0–5. Cooperar reduz cobertura e aumenta
  cooperação; defender aumenta exposição; afastar o envolvido custa coesão e
  coalizão. A fase judicial usa evidência/cobertura para decidir entre
  condenação, absolvição e caso sem desfecho, com consequências proporcionais.
  A alegação nunca vira condenação por resposta política.
- **Registro causal observável.** `scripts/sim/causal_log.gd` guarda até 40
  entradas com mês, domínio, causa, efeitos numéricos e explicação. A tela
  Sociedade exibe as últimas oito em "CADEIAS CAUSAIS"; os eventos mensais e
  a tela Crises mostram os mesmos números.

## 2. Interconexões implementadas

1. Política aprovada → satisfação de grupos + relação de organizações.
2. Relação hostil → deslocamento de votos no plenário.
3. Facção insatisfeita → abstenção/rebelião e desafio de liderança.
4. Coalizão fechada → relação melhora, ala ideológica paga o compromisso.
5. Escândalo → aprovação, credibilidade, coalizão, penalidade eleitoral e risco.
6. Financiamento privado → risco de escândalo → campanha.
7. Crise regional/econômica → satisfação dos grupos → apoio eleitoral.
8. Ideologia 2D → coalizão, relações, facções e segundo turno.
9. Organização de interesse → endosso, greve, negociação e lobby.
10. Campanha regional → `region_support` → média eleitoral e leitura regional.
11. Greve → produção/PIB, inflação, desemprego, dívida, aprovação, satisfação,
    coesão da coalizão e votação (via disciplina) → negociação ou desgaste.
12. Coalizão → pauta programática → voto do aliado → coesão/relação → pastas e
    próximas negociações; violação pode derrubar o governo.
13. Escândalo → cobertura → procedimento → evidência → status jurídico →
    credibilidade, aprovação, relações partidárias, coalizão e eleição.
14. Nomeação de ministro → cota de coalizão → relação/coesão → estabilidade do
    governo; pasta prometida e não entregue gera cobrança mensal.
15. Política aprovada → efeitos macro + grupos + organizações + registro causal.

## 3. Arquivos

### Criados

- `config/ideologies.json`
- `config/social_groups.json`
- `config/interest_groups.json`
- `config/scandals.json`
- `config/campaign_actions.json`
- `config/coalition_program.json`
- `scripts/sim/causal_log.gd`
- `scripts/sim/ideology_system.gd`
- `scripts/sim/social_groups.gd`
- `scripts/sim/interest_groups.gd`
- `scripts/sim/political_relations.gd`
- `scripts/sim/scandal_system.gd`
- `scripts/sim/campaign_system.gd`
- `scripts/ui/ideology_chart.gd`
- `docs/fase_b_desenvolvimento.md`
- `docs/shots/fase-b-1600x900/` (18 PNGs)
- `docs/shots/fase-b-1366x768/` (18 PNGs)
- `docs/shots/fase-b-1920x1080/` (18 PNGs)
- `docs/shots/fase-b2-1600x900/` (19 PNGs da revisão causal)

### Modificados

- `scripts/main.gd` — estado, migração v6, mês, coalizão, eleição, voto,
  Sociedade, Crises, facções, campanha e integração.
- `scripts/sim/election.gd` — apoio social, penalidade de crise, segundo turno 2D.
- `scripts/sim/legislature.gd` — duas proposições novas e deslocamento por
  relação/facção/escândalo.
- `test/test_suite.gd` — 48 novos checks B1–B7 e versão 6.
- `tools/walkthrough.gd` — navegação e ações reais das telas novas.
- `tools/capture_fase1.gd` — capturas B1–B7, caso de crise gerado pelo motor
  e captura da cadeia causal.
- `README.md` — dados, telas e comandos.

## 4. Dados e premissas

- **Posições ideológicas**: classificação analítica manual; overrides por país
  para partidos conhecidos. Não são publicação oficial.
- **Participações sociais**: modelo de simulação declarado, não estatística
  demográfica real. A UI informa isso em cada camada.
- **Organizações**: influência, representação e relação são parâmetros de jogo.
- **Escândalos**: categorias e estágios são desenho de simulação; nenhum caso
  histórico real é atribuído a pessoa ou partido.
- **Financiamento**: tetos e valores são regras de balanceamento, não valores
  legais de um país específico.
- Economia continua vindo do World Bank WDI (`config/economy.json`); países,
  cadeiras e partidos continuam vindo de `config/countries.json`.

## 5. Testes

| Verificação | Resultado |
|---|---|
| `test_suite.tscn` | **307 checks, PASS** |
| `test_interaction.gd` | **1109 checks, PASS** |
| `walkthrough.gd` | **246 checks, 0 falhas** |
| `test_ui_layout.gd` | **0 problemas** em 1600×900, 1366×768 e 1920×1080 |
| `soak_harness.gd` | **PASS: 139.986 checks, 35 países, 69 campanhas** |
| `audit_countries.py` | **OK** (pendências documentadas) |
| `audit_economy.py` | **OK** |

Cobertura nova: separação dos eixos, overrides, camadas sem dupla contagem,
incidência de política, organização/negociação/greve, matriz e termos de
coalizão, facções, ciclo de escândalo com status jurídico, captação privada,
comício regional e migração de save. B7 acrescenta greve persistente com efeito
macroeconômico e acordo, defeição de aliado por pauta, cota de pastas, cobertura
midiática e procedimento do escândalo, e registro causal consultável.

## 6. Validação de jogo

- Walkthrough percorre as 14 telas, incluindo Sociedade e Crises.
- Verifica gráfico de dois eixos, três facções, negociação com organização,
  auditoria preventiva, termos de coalizão, renegociação, comício regional,
  captação privada e a presença da tela de cadeias causais.
- Capturas em três resoluções; crises usa um caso gerado pelo motor de risco e
  o estado é restaurado depois da captura. A revisão B7 tem capturas próprias em
  `docs/shots/fase-b2-1600x900/`, incluindo Sociedade, a tela de cadeias causais
  e Crises com procedimento, cobertura e evidência.
- O teste de layout navega Sociedade, Crises e Governo nas três resoluções,
  além do painel principal.

## 7. Balanceamento

- Coalizão: custo cresce com cadeiras e relação ruim; renegociar é vantajoso,
  mas desgasta a ala ideológica.
- Campanha: dinheiro privado acelera, mas eleva risco de escândalo; o teto evita
  compra direta de eleição.
- Escândalo: risco máximo de 32%/mês; penalidade máxima de 8 p.p. na eleição.
- Facções: penalidade máxima de 25% das cadeiras favoráveis; não anula o voto
  ideológico.
- Grupos: sensibilidades declaradas evitam bônus arbitrários; satisfação tem
  piso 5 e teto 95.
- Greve: perda de produção cresce com intensidade e influência; seis meses sem
  acordo encerram por exaustão se a relação já não estiver destruída. O custo do
  acordo é explícito (M$ 1.400) e o benefício é relação/satisfação, não um
  multiplicador eleitoral direto.
- Coalizão: uma violação custa 4 pontos de coesão e 6 de relação por aliado;
  abaixo de 24 de coesão o parceiro mais fraco sai. A cota de pastas é cobrada
  após três meses, com perda de 0,8 de coesão por pasta faltante.
- Escândalo: cobertura amplia a penalidade; cooperar reduz mídia mas não altera
  o status jurídico. A condenação depende de severidade, evidência, cobertura e
  cooperação, com chance limitada entre 10% e 85%.
- Limitação conhecida: em campanhas muito longas, a convergência de
  `region_support` para a popularidade reduz a diferença entre regiões; as ações
  regionais ainda produzem efeito marginal.

## 8. Limitações

- Não há dados demográficos oficiais por grupo para os 35 países; todas as
  participações são modelo declarado.
- Facções detalhadas existem apenas para o partido do jogador; partidos
  adversários usam relação e disciplina agregadas.
- A câmara alta não tem votação própria nesta fase.
- Organizações de interesse não financiam campanha diretamente; o endosso é a
  forma de apoio eleitoral.
- Greves são simuladas no nível da organização e do grupo ligado; não há
  modelagem firma a firma nem adesão individual.
- A pauta de coalizão é uma proposição principal por parceiro; não há emendas
  intermediárias nem verificação de cada cláusula do texto.
- O sistema judiciário é representado por procedimento, estágio e status; não
  há um ator independente com agenda e tempo processual próprios.
- Escândalos usam RNG semeado por mês; a sequência é determinística para o mesmo
  save, mas não há replay de eventos individuais.
- A IA local continua opcional; todos os sistemas B funcionam no fallback.

## 9. Recomendação para a Fase C

1. Câmara alta e comissões, com veto e emendas.
2. Facções e lideranças para todos os partidos, não só o jogador.
3. Judiciário e Ministério Público como atores com autonomia e tempo próprio.
4. Financiamento de campanha por organização e prestação de contas detalhada.
5. Demografia oficial onde existir, com fonte e ano, mantendo o modelo para os
   demais países.
6. Migrar `main.gd` para controladores de tela, agora que os sistemas puros já
   estão separados.
