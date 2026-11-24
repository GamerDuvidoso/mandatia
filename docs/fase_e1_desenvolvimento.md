# Fase E1 — Simulação Mundial Autônoma

Relatório técnico da fase E1 de Mandatia. Todos os números de teste abaixo são
de execuções headless reais nesta máquina; as mudanças permanecem **não
commitadas**, preservando o trabalho anterior.

## 1. Resultado

O mundo deixou de ser um pano de fundo reativo. A cada mês, os 33 países
simuláveis (o país do jogador e o Haiti ficam fora) passam por:

1. decisão de prioridade do governo;
2. evolução macroeconômica própria;
3. reação de aprovação, estabilidade e partidos;
4. pauta e votação legislativa;
5. política externa bilateral;
6. calendário eleitoral, eleição e formação de governo;
7. registro histórico e notícia derivada do fato.

Em uma execução de 20 anos (janeiro de 2027 a dezembro de 2046), o motor
produziu **153 eleições, 41 trocas de governo, 3.544 votações (749 derrotas) e
390 acordos** entre países. Nenhum país recebeu trajetória idêntica; nenhum
valor saiu dos limites; o mesmo estado inicial reproduziu o mesmo resultado.

A aceitação final foi feita **no jogo real**, não só no sandbox: uma campanha
nova foi iniciada em 2027/1 e o laço mensal do jogo avançou **240 ciclos por
país** (2058/1 no calendário do jogador, porque 11 eleições automáticas de
oposição antecipam o ano). Sem escolher políticas nem usar IA, o mundo terminou
com **10/33 governos, 32/33 partidos, 30 coalizões, 33/34 economias e 34/34
relações bilaterais diferentes** do inicial, além de **152 eleições, 38 trocas
de governo, 3.536 votações (764 derrotas) e 417 acordos**. O save foi recarregado
em uma segunda instância e preservou governos, economias e contadores.

## 2. Auditoria inicial e dependências

| Item | Situação encontrada | Uso na E1 |
|---|---|---|
| Catálogo de países | 35 países; 34 com partidos; Haiti sem partidos/câmara ocupada | 33 simulados (jogador + Haiti fora); Cuba entra como sistema de partido único |
| Sistemas | 14 países com `head_of_government`, mas Haiti não tem dados | 13 parlamentares simuláveis; 20 presidenciais |
| Câmaras | `chambers[]` com `statutory_seats`/`occupied_seats` | `Election.chamber_seats`; sem distritos |
| Partidos | `official_parties[]` com abbr, nome, ideologia, liderança, cadeiras | apoio inicial = participação na câmara |
| Economia | `economy.json` WDI, `value` histórico e `simulation_value` | âncoras por país; `value` nunca é sobrescrito |
| Eleições | D'Hondt, dois turnos presidenciais, coalizão mínima | reutilizados em `foreign_election_system.gd` |
| Legislativo | catálogo e votação do jogador | modelo próprio, mais simples, para NPCs |
| Ciclo mensal | `Government.monthly` → `International.monthly` | `WorldSim.monthly` entra depois de International |
| Save | versão 6, migração aditiva por chaves | `world` é campo aditivo; versão não muda |
| Testes | suíte, layout e interação | ampliados; 418 + 0 problemas + 1961 checks |

Dependências preservadas: `countries.json`, `economy.json`, `election.gd`,
`coalition.gd`, `international_system.gd`, `legislature.gd`, temas escuro/âmbar
e Figtree. Nenhuma fonte de verdade foi duplicada: a macro continua em
`international_state.profiles`; a política nova fica em `state.world`.

## 3. Arquitetura e ordem mensal

```
_advance_month()
  Government.monthly(state)
  International.monthly(state, countries, economy)
  WorldSim.monthly(state, countries, economy)
      para cada país:
        AutonomousGovernment.monthly()   # prioridade + aprovação/estabilidade
        CountryEconomy.monthly()         # impulso da prioridade + choque
        AutonomousParty.monthly()        # apoio, estabilidade, liderança
        AutonomousLegislature.monthly()  # pauta, votação, efeitos
        _foreign_policy()                # acordo/parceria/financiamento
        calendário → ForeignElection.run()
        perfis sincronizados
  resumo e contadores
```

O governo decide **antes** da economia para que a prioridade tenha efeito no
mesmo mês. Partidos e legislativo reagem ao resultado já atualizado. A simulação
é idempotente por `world.last_tick`: chamar duas vezes no mesmo mês não duplica
nada. Não há `RNG` persistido; a variação vem de hash FNV-1a estável de
`país + mês`.

## 4. Governo autônomo (E1.1)

Prioridade escolhida por condições reais, nesta ordem:

| Condição | Prioridade |
|---|---|
| inflação ≥ 8% | estabilização |
| desemprego ≥ natural + 2 p.p. | emprego e atividade |
| dívida ≥ 95% do PIB | ajuste fiscal |
| crescimento ≤ 0,3% | investimento, se dívida < 85; senão estabilização |
| aprovação ≤ 34 ou coesão ≤ 32 | negociação parlamentar |
| eixo ideológico ≤ −0,3 | emprego se desemprego > natural + 0,5; senão investimento |
| eixo ideológico ≥ 0,35 | ajuste se dívida ≥ 70; senão investimento |
| demais casos | investimento |

Histerese: uma prioridade nova precisa se sustentar **dois meses consecutivos**.
Isso evita governo flip-flop e fatos repetidos. A troca gera evento com gatilho
numérico e consequência declarada.

Aprovação:

```
A' = clamp(A + 0,20(g − g*) − 0,10·max(0, π − 4,5)
         − 0,05·max(0, u − u*) + aprovação_da_prioridade
         − 0,03 + 0,015(50 − A), 3, 92)
```

Estabilidade:

```
S' = clamp(S + 0,06(A' − S) + 0,01(coesão − 60), 5, 98)
```

O termo `−0,03` é desgaste de incumbência. Os impulsos de aprovação por
prioridade são: estabilização −0,12; empregos +0,16; investimento +0,05;
austeridade −0,22; negociação +0,08.

## 5. Partidos autônomos (E1.2)

Apoio inicial = cadeiras / total de cadeiras × 100. A cada mês:

```
swing = 0,015(A − 50)
      + 0,10[0,20(g − g*) − 0,10·max(0, π − 4,5)
             − 0,06·max(0, u − u*)]

Δgoverno = swing − 0,02 + 0,01(estrutural − apoio)
Δoposição = −swing/(n − 1) + 0,01(estrutural − apoio)
```

O apoio é limitado a 0,3–75 e normalizado para somar 100. A estabilidade interna
sobe 0,8 quando o apoio cresce > 0,15, cai 1,0 quando cai > 0,15 e, nos demais
meses, reverte 2% para 60. Liderança muda quando estabilidade < 32, apoio < 25%
e o hash mensal < 5%; a causa e a data ficam no evento. Não há troca arbitrária
de ideologia nem fusão de partidos.

## 6. Eleições estrangeiras (E1.3)

### Calendário

Mandato: **48 meses** no presidencialismo e **60 meses** no parlamentarismo
(aproximação documentada; o catálogo não traz a regra constitucional de cada
país). O primeiro pleito é derivado de `head_of_state.since` /
`head_of_government.since` + mandato quando a data é plausível; caso contrário,
hash do país distribui o calendário. Eleições antecipadas são permitidas no
parlamentarismo após derrota em base minoritária.

### Votação

```
voto_i = 0,70·apoio_i + 0,30·participação_em_cadeiras_i
       + bônus_do_governo − 2,2·max(0, mandatos_consecutivos − 1)
       + 2,0·(η_i − 0,5)
```

```
bônus_do_governo = 0,30(A − 50) + 0,50(g − 2)
                 − 0,35·max(0, π − 5) − 0,40·max(0, u − 7)
```

A votação é normalizada para 100 e convertida em cadeiras por **D'Hondt**
nacional. O catálogo não tem votos por distrito; essa é a simplificação central
da fase.

- **Presidencialismo:** `Election.presidential_2d` com dois turnos e
  transferência ideológica; o vencedor forma o Executivo e não precisa de
  coalizão para tomar posse.
- **Parlamentarismo:** o maior partido tenta a menor coalizão vencedora
  (`Coalition.minimum_winning`); sem acordo, governa em minoria.

### Transição

A eleição **não** altera PIB, inflação, desemprego, dívida ou serviços. Muda
governo, coalizão, aprovação (lua de mel 46–58 se trocou), mandatos consecutivos
e orientação. A relação com o jogador se desloca no máximo ±3 pontos conforme a
distância ideológica; compromissos e dependência continuam pesando nos meses
seguintes. O evento registra eleição, troca de governo e coalizão.

## 7. Legislativo autônomo (E1.4)

A pauta nasce da prioridade do governo (emprego, estabilização, investimento,
austeridade, negociação). Há votação em ~45% dos meses. Cada bancada divide seus
assentos:

```
sim_i = clamp(0,40 + 0,55·max(0, 0,70 − |eixo_i − eixo_projeto|)
              + 0,15 se governo/coalizão, −0,12 se oposição
              + 0,25(η_i − 0,5), 0,02, 0,98)
```

5% dos assentos se abstêm; o restante divide entre sim e não. O projeto passa se
`sim > não`. Aprovado, aplica efeitos macro e de aprovação; rejeitado, custa
aprovação e estabilidade. Em parlamentarismo, base minoritária + derrota +
estabilidade < 45 antecipa a eleição em até 2 meses. O governo, portanto, não
aprova tudo — 749 derrotas em 3.544 votações na execução de 20 anos.

## 8. Economia por país (E1.5)

Âncoras do país (WDI `simulation_value`): `g*` em [−3, 6], `π*` em [1,5, 12],
`u*` em [3, 16], dívida inicial em [5, 180].

```
g' = g + 0,12(g* − g) + impulso_g + 0,6ε
π' = π + 0,10(π* − π) + impulso_π + 0,06(g' − g*) + 0,25ε
u' = u − 0,06(g' − g*) + 0,05(u* − u) + impulso_u
D' = D + 0,10 + 0,12·max(0, g* − g') + impulso_D − 0,02·max(0, g')
PIB' = max(1, PIB·(1 + g'/1200))
```

`ε ∈ [−0,6, +0,6]` é o choque externo determinístico do país/mês. Impulsos:

| Prioridade | g | π | u | dívida |
|---|---:|---:|---:|---:|
| estabilização | −0,10 | −0,22 | +0,05 | −0,06 |
| empregos | +0,16 | +0,10 | −0,14 | +0,12 |
| investimento | +0,11 | +0,03 | −0,06 | +0,10 |
| austeridade | −0,12 | −0,06 | +0,08 | −0,20 |
| negociação | +0,01 | 0 | 0 | +0,02 |

Limites: g [−8, 10], π [0,5, 40], u [2, 30], dívida [0, 200], PIB > 1. A
reversão às âncoras impede crescimento ou colapso infinito. O modelo é
reduzido (sem estoques setoriais, consumo e investimento detalhados); receita e
despesa por país não são simuladas — o jogador continua usando o sistema
orçamentário da Fase C.

## 9. Desenvolvimentos domésticos e política externa (E1.6/E1.7)

Além de prioridade, aprovação, apoio e votação, o mundo registra troca de
liderança partidária, coalizões, derrotas e eleições antecipadas. Escândalos,
investigações e reshuffles ministeriais de NPCs **não** foram implementados
(ver limitações).

Política externa: a cada mês, 6% de chance por país, com intervalo mínimo de 6
meses, escolhendo um par da mesma região:

| Ação | Condição | Efeito |
|---|---|---|
| financiamento de desenvolvimento | dívida ≥ 80 e crescimento < 2 | dívida −0,6; crescimento +0,06; parceiro +0,02 |
| parceria estratégica | ≥ 3 acordos anteriores e rolagem < 0,40 | crescimento +0,05 nos dois; parceiro registrado |
| acordo comercial e investimento | demais casos | crescimento +0,03 nos dois |

A mudança de governo de um parceiro desloca a relação com o jogador, mas não
reescreve tratados nem dependência comercial de uma vez. Membros de organizações
internacionais e financiamento multilateral de NPCs ainda não são simulados; a
diplomacia do jogador continua centralizada em `international_system.gd`.

## 10. História e notícias (E1.8)

Cada evento guarda: data, país, categoria, descrição, gatilho, consequências,
atores, status e certeza. Categorias: `eleicao`, `governo`, `coalizao`,
`legislativo`, `politica`, `lideranca`, `diplomacia`.

- Histórico máximo: **1.200 eventos**; notícias: **60**.
- Dedupe temporal por país/categoria/descrição: 12 meses para fatos rotineiros;
  1 mês para eleição/governo.
- A varredura para no primeiro evento mais antigo que a janela (histórico é
  reverse-cronológico), mantendo o custo proporcional à janela.
- Notícias são derivadas do evento; manchetes iguais não entram enquanto a
  anterior estiver no giro (dedupe global). Eventos recorrentes legítimos levam
  ano no título.
- Status: `confirmado`, `oficial`, `alegacao`, `investigacao`, `projecao`.
  Nesta fase, todos os fatos gerados são confirmados ou oficiais; alegação,
  investigação e projeção ficam disponíveis para a E2 e para sistemas futuros.
- Contadores persistentes (`world.stats`) sobrevivem ao corte do histórico.

Ollama não é usado. Se estiver disponível, pode narrar; a informação essencial
já é determinística.

## 11. Interface do mundo (E1.9)

`MUNDO → Mundo`, ao lado de Internacional, mantendo escuro + âmbar e Figtree.
Sem globo 3D.

- KPIs: países ativos, eleições nos últimos 12 meses, crescimento médio,
  estabilidade média.
- Linha acumulada: eleições, trocas de governo, votações, derrotas e acordos.
- Filtro por região.
- Tabela comparativa: país, sistema, partido do governo, aprovação, crescimento,
  inflação, dívida, estabilidade, próxima eleição e botão VER.
- Giro do mundo: notícias com data, país, manchete e status.
- Últimos fatos: data, país, categoria e descrição.
- Detalhe do país: governo, sistema, prioridade, base/coesão, relação com o
  jogador, última eleição, macro, partidos (cadeiras, apoio, papel, estabilidade,
  liderança) e história recente.

A tela lê o estado simulado; abrir a aba não executa decisões nem IA.

## 12. Desempenho (E1.10)

Execução headless, com `International.monthly` + `WorldSim.monthly`, 33 países,
240 meses:

```
[world-sim] 240 meses em 2636 ms · 33 países · 1200 fatos
           153 eleições · 41 trocas de governo
           3544 votações (749 derrotas) · 390 acordos
```

Média de ~11 ms por mês para todos os países, sem cálculo por frame. O custo é
mensal e independe da tela visível. O histórico é truncado em 1.200 eventos e a
notícia em 60, mantendo o save e a interface limitados.

## 13. Testes

| Suíte | Resultado |
|---|---|
| `test_suite.gd` | **418 checks PASS** |
| `test_world_20y.gd` | **51 checks PASS** · 240 avanços em 52.988 ms |
| `test_ui_layout.gd` | **0 problemas em 3 tamanhos** |
| `test_interaction.gd` | **1961 checks PASS** |

Cobertura E1 adicionada:

- catálogos e 33 países; Haiti fora; 13 parlamentares;
- apoio somando 100%, cadeiras somando a câmara;
- eleição de transição preservando PIB, inflação e dívida;
- marcos de **12, 60 e 240 meses** com limites macro, aprovação, estabilidade,
  PIB positivo e calendário válido;
- trajetórias distintas (≥ 10 crescimentos diferentes);
- eleições, trocas de governo, votações, derrotas e acordos acima de zero;
- nenhum fato repetido em até 2 meses; nenhuma manchete consecutiva repetida;
- determinismo: duas simulações independentes de 60 meses coincidem em governo,
  aprovação e crescimento;
- save sem `world` recebe o mundo; JSON preserva o mundo; país ausente é reposto.

`test/test_world_20y.gd` é a aceitação de 20 anos **no fluxo do jogo**:
instancia `main.tscn`, inicia uma campanha, chama `_advance_month` 240 vezes e
resolve só as eleições obrigatórias do jogador, sem propor leis, sem ações de
política externa e sem IA. Ele confere que cada país chegou a 240 ciclos
mensais, que governos/partidos/coalizões/economias/relações divergiram do
início, que a história contém as categorias esperadas e que o save recarregado
em outra instância mantém o mundo. A suíte de interação também cobre a tela
Mundo pela navegação existente.

## 14. Compatibilidade de save

- `SAVE_VERSION` continua **6**.
- `state.world` é campo aditivo; saves antigos não quebram.
- `WorldSim.ensure` reconstrói o mundo a partir dos catálogos quando `world`
  está ausente ou incompleto, e repõe país faltante.
- Saves antigos recebem o mundo **a partir da data atual**; não há história
  retroativa inventada.
- O mundo é JSON puro (dicionários/arrays/números/strings), sem objetos Deus.
- Teste de ida e volta JSON e de save legado sem `world` passou.

## 15. Limitações e o que é protótipo

**Completo nesta fase:** governo por condições, partidos, eleições e transições,
legislativo com derrotas, economia por país, história/notícias, tela Mundo,
política externa bilateral básica, contadores e testes longos.

**Parcial/protótipo:**

- Haiti fora por falta de partidos e câmara ocupada; Cuba é partido único.
- D'Hondt nacional, sem distritos ou diferenças regionais de voto.
- Mandatos fixos em 48/60 meses; datas constitucionais específicas não estão no
  catálogo.
- Coalizão é a menor vencedora; não há negociação multirodada, troca de parceiro
  no meio do mandato nem reshuffle ministerial de NPC.
- Sem escândalos, investigações ou campanha eleitoral de NPCs; aprovação e
  economia fazem o papel de conjuntura.
- Política externa limitada a acordos bilaterais regionais; organizações
  internacionais, financiamento multilateral, tratados de segurança e
  alinhamentos de bloco de NPCs não são simulados.
- Economia reduzida, sem setores, consumo/investimento estocados, receita e
  despesa por país.
- Nenhum sistema de guerra, mobilização, conquista, crise global, energia,
  refugiados ou emergência internacional — reservado à E2.
- Nenhum uso obrigatório de IA; narração Ollama é opcional e não foi integrada.

## 16. Requisitos e ganchos para a E2

A E1 deixa prontos:

- `state.world.countries[id]` com governo, partidos, cadeiras, aprovação,
  estabilidade, coalizão, prioridade, mandatos consecutivos e histórico;
- `international_state.profiles[id]` com PIB, crescimento, inflação, desemprego,
  dívida, aprovação, estabilidade, orientação e prioridade;
- relações jogador–país e comércio em `international_state`;
- eventos com categoria, status, atores e consequências;
- `world.stats` para totais de longo prazo;
- ponto único `WorldSim.monthly`, onde crises globais, guerras, mobilização,
  refugiados e choques energéticos podem ser inseridos **antes** da economia
  mensal, com efeitos explícitos nos mesmos perfis;
- separação UI/simulação e determinismo por país/mês.

A E2 ainda precisa definir: regras de conflito, cadeia de mobilização, efeitos
de guerra na economia e nos grupos, crises globais com estágios, refugiados,
energia, negociação de paz, e como o jogador e os NPCs respondem sem quebrar
tratados, dependência e save.

## 17. Arquivos

Novos:

- `scripts/sim/world_history.gd`
- `scripts/sim/country_economy_simulation.gd`
- `scripts/sim/autonomous_government.gd`
- `scripts/sim/autonomous_party_system.gd`
- `scripts/sim/foreign_election_system.gd`
- `scripts/sim/autonomous_legislature.gd`
- `scripts/sim/world_sim.gd`
- `docs/fase_e1_desenvolvimento.md`

Modificados:

- `scripts/main.gd` — preload, estado default, init/ensure, ciclo mensal,
  navegação MUNDO, tela Mundo e detalhe por país.
- `test/test_suite.gd` — preloads E1, navegação, testes de 12/60/240 meses,
  determinismo, save, eleições, estatísticas e desempenho.
- `test/test_world_20y.gd` — aceitação de 20 anos no jogo real, comparação
  inicial/final e recarga do save.

`project.godot` foi trocado temporariamente para a cena de teste e restaurado
para `res://scenes/main.tscn`. Nenhum commit ou push foi feito.

## 18. Como reproduzir

```bash
# suíte completa (troca a cena principal e restaura)
cp project.godot project.godot.bak
sed -i 's|run/main_scene="res://scenes/main.tscn"|run/main_scene="res://test/test_suite.tscn"|' project.godot
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path .
mv project.godot.bak project.godot

# aceitação de 20 anos no jogo real
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script test/test_world_20y.gd

# layout e interação
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script test/test_ui_layout.gd
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script test/test_interaction.gd
```
