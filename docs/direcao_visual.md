# Mandatia — Direção Visual e Arquitetura de Interface (revisão 2)

**Referência estética:** Geoplanetical / simuladores geopolíticos de gestão nacional
**Plataforma prioritária:** Windows
**Idioma da interface:** Português do Brasil (PT-BR)
**Resoluções suportadas:** 1280 × 720 (base), 1600 × 900, 1920 × 1080
**Etapa:** direção visual revisada e aprovada para implementação — **nenhum arquivo de código foi alterado**

> Este documento responde ao prompt `docs/direção visual/Mandatia_Direcao_Visual/PROMPT_MANDATIA_DIRECAO_VISUAL.md`
> e incorpora a revisão pedida: globo como cenário dominante, painéis adaptáveis por tela,
> suporte a três resoluções, verificação da identidade política no código e preservação funcional integral.

---

## Sumário

| Seção | Conteúdo |
|---|---|
| A | Diagnóstico do visual atual (revisado com evidências) |
| B | Sistema visual: tokens, tipografia, componentes, **globo**, **painéis adaptáveis** |
| C | Wireframes atualizados em 1280 × 720 (7 composições) |
| D | Plano técnico definitivo, por etapas, com verificação em cada etapa |
| E | Riscos, limitações reais e decisões pendentes |
| F | Checklist de aprovação |

### O que mudou em relação à versão 1

| # | Revisão pedida | Como foi resolvida |
|---|---|---|
| 1 | Globo como cenário, não mapa 2D | Seção **B.8**: globo esférico em 2D (shader de projeção + malha de graticula), três camadas, sem mundo 3D interativo. Inclui o status real dos assets. |
| 2 | Painéis com larguras diferentes por tela | Seção **B.9** + matriz de larguras + seção **D.4**: três classes de largura, coluna direita opcional e faixa de contexto. |
| 3 | 1280 × 720, 1600 × 900, 1920 × 1080 | Seção **B.10** e **D.7**: escala uniforme por `canvas_items/expand`, critérios de teste objetivos por resolução. |
| 4 | Identidade política conferida no código | Seção **D.1**: auditoria linha a linha de `axis_color` e `ideology_axis`; correspondência preservada. |
| 5 | Preservação funcional | Seção **D.2**: inventário de invariantes (dados, cálculos, ações, save, IA, testes). |
| 6 | Ordem gradual com verificação | Seção **D.9**: 7 etapas, cada uma com gate de verificação e critério de rollback. |

### Correções factuais da versão 1

1. **Pirâmide etária:** a versão 1 propunha uma pirâmide para a tela População. **Não existe contagem etária nos dados.** `state.demographics` contém 5 grupos (*Jovens, Trabalhadores, Empreendedores, Aposentados, Rurais*) com percentual de apoio, não população por idade. A tela passa a usar barras horizontais desses 5 grupos — dado real, sem inventar estrutura etária.
2. **Assets geográficos:** `assets/aurora/aurora-map.png`, `leadership-portraits.png` e `party-symbols.png` **não estão no disco**. Existem apenas os `.import`; os PNGs estão no `.gitignore` e listados em `assets.lock.json` (fontes com hash). Portanto **nada pode depender deles hoje**. O globo foi especificado para funcionar sem nenhum asset novo e sem esses arquivos (B.8.4).
3. **Overflow em 1280 × 720:** as capturas atuais (`docs/shots/congresso-hemiciclo.png`, `docs/shots/economia.png`) mostram texto da coluna direita e o botão "AVANÇAR MÊS ›" **cortados na borda**. O layout atual estoura a largura de 1280. Isso deixa de ser risco teórico e passa a ser requisito de correção na Etapa 4.
4. **Não existe globo 3D nem geodados:** `config/countries.json` não tem latitude, longitude nem polígonos. O único dado geográfico é o campo `region` do país e o mapa `regions` (4 macro-regiões: América do Norte, América Central, Caribe, América do Sul). O globo é, portanto, **cenário** — não um mapa interativo de territórios.

---

## A. Diagnóstico do visual atual

### A.1 O que já está alinhado com a direção

| Item | Situação | Evidência |
|---|---|---|
| Base escura | Fundo já é quase preto, não azul-marinho saturado | `project.godot` clear color `#08111f`; `mandato_theme.BG` |
| Âmbar como destaque | Já é cor de ação primária e de métrica destacada | `AMBER #e8b45b` em botões, badges e métricas |
| Hierarquia tipográfica | Existe separação entre display e corpo | Sora em `display/generic_*`, Figtree em `ui_*` |
| Densidade informacional | Painéis, métricas e listas já são compactos | `_metric_card`, `_panel_box`, `_section_title` |
| Hemiciclo funcional | Desenhado com dados reais de cadeiras, maioria e coalizão | `aurora_board.set_hemicycle`, `_draw_hemicycle` |
| Malha de 8 regiões | Existe, clicável, com detalhe por região | `aurora_board.set_map`, `_gui_input`, `_show_regions` |
| Taxonomia de navegação | Os 5 grupos e 12 itens já são os corretos | `_build_sidebar` |

### A.2 O que conflita com a direção

1. **Duas paletas concorrentes.** `mandato_theme.gd` (azul institucional + ciano) e `screen_factory.gd` (`INK #0b0e13`, `ACCENT #2f6fe4`, `CYAN #70b7ff`, `CORAL #ff9b8e`) convivem.
2. **Estética sci-fi no kit de UI.** `screen_factory` traz `plate()` com `skew = 0.18`, `holo_panel()` com shader de varredura, cantos em L, `modal_backdrop()` com blur e `add_press_juice()` com squash.
3. **Sidebar larga e de uma camada.** 210 px (`SIDEBAR_WIDE`) com grupos e itens na mesma lista; a referência pede faixa estreita + faixa contextual.
4. **Barra superior pesada.** 72 px com bandeira 56 × 36, marca + partido, data 18 px, cargo 13 px, fundos, 2 estatísticas e botão — e mesmo assim **corta o botão em 1280**.
5. **Sem cenário geográfico.** O jogo principal é uma página opaca: header + sidebar + coluna com scroll + rail. O único mapa é a grade de 8 cartões dentro de um card.
6. **Estouro horizontal em 1280.** Rail fixo de 290 px + conteúdo com largura mínima excede a viewport (evidência nas capturas).
7. **Raios e sombras excessivos.** Card raio 8, botão 5, kit sci-fi 12/20 com sombras de 28–40 px.
8. **Escalas tipográficas misturadas.** `main.gd` usa 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 24, 25, 30, 36, 44, 64 px sem escala declarada.
9. **Menu com título de 64 px** e caixa fixa de 620 px, sem relação com o resto do sistema.
10. **CIANO com dois papéis.** É cor de séries e de cabeçalhos (`_draw_economy`, `_draw_hemicycle`, `RADAR NACIONAL`) **e** é a cor do eixo de direita em `axis_color`. O mesmo tom significa "destaque de interface" e "direita política" — ambiguidade que precisa ser resolvida por reserva de uso (D.1).

### A.3 Estilos duplicados ou competindo

| Conceito | `mandato_theme` | `screen_factory` | Conflito |
|---|---|---|---|
| Painel | `panel()` raio 8, borda 1 px | raio 20, sombra 28 px | Raio e sombra |
| Botão | 40 px, raio 5 | 46–52 px, placa inclinada | Forma e altura |
| Primário | Texto âmbar sobre painel | Fundo azul `#2f6fe4` | Cor de ação |
| Destaque | `AMBER #e8b45b` | `CYAN #70b7ff` | Cor de destaque |
| Fundo | `#08111f` | `INK #0b0e13` | Quase iguais, mas distintos |
| Fonte | fallback do projeto | `FONT_*` explícito | Aplicação inconsistente |

### A.4 O que será reaproveitado

- `mandato_theme.gd` como única fonte de tokens; `axis_color` mantido.
- A taxonomia de `_build_sidebar` (5 grupos, 12 itens) — muda só a apresentação.
- `_metric_card`, `_panel_box`, `_badge`, `_section_title`, `_rule`, `_status_chip`.
- `aurora_board.gd`: modos `dashboard`, `map`, `chart`, `economy`, `hemicycle`, mais o novo modo `globe` (B.8).
- `flag_painter.gd` (bandeiras desenhadas por código) — reutilizável como marcador no globo.
- Fontes `ui_regular/ui_medium/ui_bold` (Figtree) e `display/generic_*` (Sora).
- `tools/capture_fase1.gd` como ferramenta de verificação visual (extensão para 3 resoluções, D.7).

---

## B. Sistema visual proposto

### B.1 Tokens de cor

| Token | Hex | Aplicação |
|---|---|---|
| `BG` | `#090A0C` | Fundo global, espaço do globo, área sem conteúdo |
| `SURFACE` | `#17191C` | Faixas de navegação, painéis padrão |
| `SURFACE_RAISED` | `#202226` | Cards, blocos elevados, cabeçalho de seção |
| `SURFACE_HOVER` | `#292C31` | Hover, item ativo discreto |
| `LINE` | `#34373D` | Bordas, separadores, grade de gráfico |
| `TEXT` | `#E7E7E7` | Texto principal |
| `MUTED` | `#A0A2A6` | Texto secundário, legendas |
| `SUBTLE` | `#70747A` | Metadados, unidades, itens inativos |
| `AMBER` | `#DDAA4D` | Ação primária, seleção, destaque institucional |
| `GREEN` | `#79B88A` | Estado positivo (crescimento, aprovação saudável) |
| `RED` | `#D87575` | Estado crítico (risco, déficit, reprovação) |
| `AXIS_LEFT` | `#E97878` | **Exclusivo** eixo ideológico à esquerda |
| `AXIS_CENTER` | `#E8B45B` | **Exclusivo** eixo ideológico de centro |
| `AXIS_RIGHT` | `#5FA9AC` | **Exclusivo** eixo ideológico à direita (dessaturação do `CYAN` atual, ver D.1) |
| `GLOBE_LAND` | `#2A3038` | Massa continental do globo (tom, não cor) |
| `GLOBE_OCEAN` | `#0C1216` | Oceano/base do globo |

**Regras**
- Âmbar é o único destaque de navegação e ação. Ciano/azul deixa de ser cor de tema.
- Vermelho e verde só comunicam estado e sempre acompanhados de sinal, texto ou ícone.
- `AXIS_LEFT/CENTER/RIGHT` aparecem **apenas** em assento do hemiciclo, chip de sigla e marcador de eixo. Nunca em botão, cabeçalho, borda de painel ou série de gráfico.
- Séries de gráfico usam somente `GREEN` (crescimento), `RED` (inflação), `AMBER` (desemprego) e `MUTED` (referência) — exatamente as que `_draw_economy` já usa.
- Nenhuma cor saturada em área grande; o globo é o único elemento com área extensa e usa tons neutros.

### B.2 Escala tipográfica

| Nível | Tam. | Peso/fonte | Uso |
|---|---:|---|---|
| Micro | 10 px | Figtree regular | Unidades, datas, rodapé de card, legenda de eixo |
| Legenda | 11 px | Figtree regular | Notas, legenda do hemiciclo |
| Corpo | 12–13 px | Figtree regular | Listas, tabelas, descrições |
| Corpo forte | 13 px | Figtree medium | Nome de partido, rótulo de indicador |
| Título de bloco | 14 px | Figtree bold | Cabeçalho de card |
| Título de seção | 17 px | Sora heading | Cabeçalho de painel |
| Título de tela | 22 px | Sora heading | Título da área de conteúdo |
| Métrica | 24–28 px | Sora heading | Valor de destaque, total de cadeiras |
| Métrica grande | 40–44 px | Sora heading | Conjuntura econômica (mantém os 44 px atuais) |
| Marca (só menu) | 40 px | Sora title | "MANDATIA" |

Nenhum texto essencial abaixo de 10 px lógicos. Sora fica em títulos e números grandes; Figtree carrega leitura.

### B.3 Barra superior (44 px)

Linha única `SURFACE` com borda inferior `LINE`, três zonas:

- **Esquerda (até 340 px):** bandeira 26 × 17 (via `flag_painter`), nome do país 13 px bold + regime/partido 10 px `SUBTLE`; retrato 22 px + líder/cargo quando houver.
- **Centro (flexível):** cápsulas de indicador — rótulo 9 px `SUBTLE` caixa alta sobre valor 12 px bold. Ordem de prioridade: **Caixa, Dívida/PIB, Inflação, Aprovação, Popularidade, Estabilidade, Crescimento**. Em 1280 cabem **7** cápsulas; as demais migram para a barra de rodapé ou tooltip.
- **Direita (fixa, 220–240 px):** mês/ano 12 px, controles de ritmo (pausa/avançar) e botão "AVANÇAR MÊS ›" com 32 px de altura.

Regra de ouro: **nada é cortado em 1280**. Se a soma exceder a largura, a zona central reduz cápsulas por prioridade (nunca por overflow de container).

### B.4 Barra de rodapé (32 px)

`SURFACE` com borda superior `LINE`; absorve os indicadores que não cabem na barra superior, sempre com rótulo micro + valor: **Aprovação · Estabilidade · Tensão constitucional**, mais o estado do save (`salvo automaticamente · 09/2027`). É a barra de status atual (46 px) compactada, sem perder nenhum dos três indicadores.

### B.5 Navegação principal (64 px)

Faixa `SURFACE`, ícone 18 px + rótulo 9 px caixa alta. Grupo ativo: marcador âmbar 3 × 18 px na borda esquerda, ícone e rótulo em `TEXT`; inativos em `SUBTLE`. Separador 1 px `LINE` entre os 5 grupos. Rodapé da faixa: salvar (ícone) e menu principal.

### B.6 Navegação contextual (120 px)

Segunda faixa, um tom acima do BG, com o nome do grupo em 9 px `SUBTLE` e os itens em 12 px. Item ativo: fundo `SURFACE_HOVER` + marcador âmbar 2 × 12 px. Quando a altura não comporta 3 itens + título, a faixa rola internamente (o `ScrollContainer` atual é reaproveitado).

| Grupo | Itens (inalterados) |
|---|---|
| PAÍS | Visão geral, Meu partido |
| PODER | Eleições, Congresso, Governo |
| ECONOMIA | Economia, População, Regiões |
| MUNDO | Internacional |
| REGISTRO | Notícias, História, Configurações |

### B.7 Componentes

- **Card de indicador:** `SURFACE_RAISED`, borda `LINE`, raio 4, padding 10–12. Rótulo 10 px `SUBTLE`; valor 20–24 px bold; variação com sinal (`+1,2 p.p.` / `−0,8 p.p.`) **e** cor.
- **Tabela/lista:** cabeçalho 10 px `SUBTLE` caixa alta; linhas 12–13 px; separador 1 px `LINE`; números alinhados à direita com largura fixa; hover `SURFACE_HOVER`.
- **Gráfico:** fundo `BG`, grade 1 px `LINE` a 45% de opacidade, linha 1,5–2 px, sem preenchimento, legenda 11 px com unidade explícita.
- **Botões:** 30–34 px, raio 4. Primário: fundo `AMBER`, texto `#15110A`. Secundário: `SURFACE_RAISED` + borda `LINE`, texto `TEXT`. Terciário: texto `MUTED` até hover. Foco: contorno 1 px `AMBER`.
- **Abas:** sublinhado âmbar 2 px na ativa, texto 12 px; sem pílulas.
- **Alertas:** faixa de 3 px na borda esquerda + ícone + texto (`RED` crítico, `AMBER` prazo, `GREEN` conclusão).
- **Chips de bancada:** sigla 11 px na cor do eixo + fundo `SURFACE_RAISED` + borda `LINE`. A cor nunca é o único sinal — a sigla está escrita.
- **Retratos:** 40 px (lista) / 64 px (detalhe). **Só entram quando `leadership-portraits.png` for restaurado e o enquadramento por pessoa estiver mapeado**; até lá usa-se a sigla em `_badge`, como hoje.
- **Bandeiras:** `flag_painter.gd` (código), 26 × 17 na barra e 40 px no globo.

### B.8 Cenário geográfico: globo

O jogo passa a ter **um globo como cenário permanente**, não um mapa plano. A composição é 2D — nenhuma cena 3D, nenhuma navegação orbital, nenhum clique em território.

#### B.8.1 Conceito

Três camadas empilhadas, sempre nesta ordem:

1. **Espaço** — retângulo `BG` com vinheta radial sutil (escurece ~8% nas bordas). Sem estrelas, sem nebulosa: isso puxaria para sci-fi.
2. **Globo** — esfera desenhada com projeção esférica de uma textura equirretangular (ou, sem textura, com malha de graticula), escurecida no limbo, com terminador suave e brilho de borda de 1 px.
3. **Interface** — faixas de navegação, painéis e cards por cima. Os painéis são opacos (`SURFACE` a 96%); o globo aparece nos vazios, nunca atrás de texto corrido.

O globo ocupa de **45% a 60% da área de conteúdo** e é posicionado à direita, com o centro fora do centro da tela (deslocado ~8% para a direita), de modo que os painéis da esquerda cortem o disco — o recorte é o que cria a profundidade da referência.

#### B.8.2 Onde o globo aparece

| Tela | Papel do globo |
|---|---|
| Visão geral | **Protagonista**, atrás dos painéis, com marcador da macro-região do país |
| Economia | Fundo atenuado (35% de opacidade) — o painel analítico domina |
| População | Fundo atenuado (35%) |
| Regiões | **Protagonista**: o mapa de 8 regiões continua à frente, sobre o globo (a malha é o dado; o globo é o cenário) |
| Internacional | **Protagonista**, com o marcador do país e a leitura externa ao lado |
| Congresso | Sem globo. O hemiciclo é o elemento gráfico da tela; fundo liso |
| Eleições, Governo, Notícias, História, Configurações, Resultado | Sem globo (fundo liso), para não competir com tabelas |

>`Internacional` hoje só exibe `state.international` quando existe; o globo não adiciona dado algum, só presença visual.

#### B.8.3 Especificação técnica

- **Novo controle** `scripts/ui/globe_view.gd` (`extends Control`), independente de `aurora_board.gd`. Motivo: `aurora_board` é o painel de dados (regiões, hemiciclo, séries) e já tem 5 modos; o globo é cenário, com ciclo de vida próprio (fica atrás do conteúdo, não dentro de um card).
- **Textura + shader (caminho preferido):** `shaders/globe_sphere.gdshader` recebe a textura equirretangular e calcula:
  ```glsl
  // posição normalizada no quad -1..1
  vec2 p = UV * 2.0 - 1.0;
  float r2 = dot(p, p);
  if (r2 > 1.0) { discard; }                       // recorta o disco
  vec3 n = vec3(p.x, -p.y, sqrt(1.0 - r2));        // normal da esfera
  // rotação em torno do eixo Y (ângulo fixo por tela)
  n.xz = mat2(cos(a), -sin(a), sin(a), cos(a)) * n.xz;
  vec2 uv = vec2(atan(n.x, n.z) / TAU + 0.5, acos(n.y) / PI);
  vec3 col = texture(TEXTURE, uv).rgb;
  float limb = pow(clamp(n.z, 0.0, 1.0), 0.55);    // escurece o limbo
  col *= mix(0.35, 1.0, limb);
  ```
  Custo: um único quad com shader, compatível com `gl_compatibility` (o projeto usa esse renderer). Nenhum `SubViewport`, nenhuma renderização 3D.
- **Malha de graticula (sempre presente):** meridianos a cada 30° e paralelos a cada 30°, desenhados em `_draw()` com `draw_arc`, projetados pela mesma matemática (elipses com achatamento `cos(lat)` e recorte no limbo), em `LINE` a 18% de opacidade. Serve de estrutura visível, garante o efeito de esfera mesmo sem textura e é o que dá o aspecto institucional.
- **Terminador:** elipse escura cobrindo ~22% do disco no lado oposto ao marcador, com borda suave (3 anéis de alpha decrescente). Sem brilho especular.
- **Marcador do país:** usa `state.country_id` → `country.region` (dado real, 4 valores) para escolher um ponto fixo da macro-região, desenhado como bandeira 22 px (`flag_painter`) sobre um anel `AMBER` de 1 px. A tabela região → posição é **constante de posicionamento visual**, documentada no código como tal, não como dado simulado.
- **Estático.** Sem rotação automática, sem parallax, sem animação — o prompt proíbe animação decorativa. Arrastar para girar fica como **sugestão futura**.
- **Fallback obrigatório:** se a textura não carregar (asset ausente, import quebrado), o controle desenha apenas disco + graticula + marcador, sem erro e sem quad preto. Esse é o modo que funciona **hoje**, porque os PNGs não estão no disco.

#### B.8.4 Assets: situação real e decisão

| Asset | Estado no disco | Uso previsto | Se faltar |
|---|---|---|---|
| `assets/aurora/aurora-map.png` (3,79 MB no lock) | **Ausente** (só `.import`) | Textura equirretangular do globo | Globo com graticula + tons de continente procedurais |
| `assets/aurora/leadership-portraits.png` | **Ausente** | Retratos padronizados | `_badge` com iniciais (como hoje) |
| `assets/aurora/party-symbols.png` | **Ausente** | Símbolo partidário opcional | Cor do eixo + sigla textual |

**Decisão:** o globo **não depende** desses arquivos. Dois níveis, na ordem:

- **Nível A (implementável hoje, sem asset novo):** disco + graticula + terminador + marcador, com massas continentais **abstratas** (blobs tonais em `GLOBE_LAND` gerados por ruído determinístico semeado por `country.region`) apenas como textura de superfície — sem contorno de países, sem alegar geografia real.
- **Nível B (quando `aurora-map.png` for restaurado):** a mesma geometria, trocando a superfície procedural pela textura. Exige conferir se a imagem é equirretangular; se for um mapa estilizado plano, aplica-se a mesma máscara circular com distorção de curvatura e vinheta de limbo (efeito "globo" sem projeção matemática).

Restaurar os assets é tarefa de pipeline (`assets.lock.json`), **não desta reforma visual**. Se o usuário autorizar, o plano é: restaurar → conferir proporção e conteúdo → ligar o Nível B.

### B.9 Painéis adaptáveis (larguras por tela)

Nada de uma única estrutura repetida. A área de conteúdo útil é de **1096 px lógicos**: 1280 − 64 (faixa principal) − 120 (faixa contextual). Com margens de 16 px, sobram **1064 px**.

**Três classes de largura**

| Classe | Faixa | Uso |
|---|---|---|
| `NARROW` | 280–320 | Detalhe, coluna de contexto, cartões auxiliares |
| `MEDIUM` | 380–520 | Painel de leitura, lista de bancadas, coluna de análise |
| `WIDE` | 540–760 | Hemiciclo, gráfico de séries, mapa de regiões |
| `FULL` | 800–1064 | Faixa de conjuntura, tabela de proposições, feed |

**Coluna direita (rail) passa a ser opcional por tela.** `_build_right_rail()` continua sendo a única fonte dos três blocos (Decisão pendente, Radar nacional, Partido). Quando a tela desliga o rail, os três blocos são re-renderizados numa **faixa de contexto horizontal** de 96 px no rodapé do conteúdo (decisão + 3 botões inline, 1 manchete + link, sigla/caixa/membros). **Nenhum bloco é removido** — muda de posição.

**Matriz definitiva (1280 × 720 lógicos)**

| Tela | Rail | Estrutura | Larguras |
|---|---|---|---|
| Visão geral | Sim, 296 | Painel A (métricas + ação do mês + briefing) · Painel B (apoio regional) · globo ao fundo | 416 · 300 · globo 1064 |
| Meu partido | Sim, 296 | Painel de identidade · coluna de insígnias | 596 · 196 |
| Eleições | Sim, 296 | Coluna única: 3 métricas · pesquisa (8 linhas) · sala de campanha | 804 |
| Congresso | **Não** | Coluna A: hemiciclo + métricas · Coluna B: bancadas · proposições · agenda | 536 · 516 |
| Governo | Não | Gabinete · coalizão | 596 · 452 |
| Economia | **Não** | Faixa de conjuntura `FULL` · 3 séries (333 cada) · leitura + programas lado a lado | 1064 · 333×3 · 512 · 512 |
| População | **Não** | Grupos demográficos · indicadores sociais + leitura | 640 · 412 |
| Regiões | **Não** | Mapa (malha 8 regiões sobre o globo) · detalhe da região | 736 · 300 |
| Internacional | Sim, 296 | Evento + leitura externa | 804 |
| Notícias | Sim, 296 | Feed cronológico | 804 |
| História | Sim, 296 | Linha do tempo / lista de marcos | 804 |
| Configurações | **Não** | Painel de opções | 640 |
| Resultado | **Não** | Síntese do mandato | 1064 |

Regra de consistência: mesma barra superior, mesmas faixas, mesmos tokens e mesma tipografia em todas as telas. O que muda é a **grade interna** e o uso do rail.

### B.10 Movimento

Transições de 140–180 ms para troca de tela (fade simples de 1 quadro de opacidade no `root_stack`), 90 ms para hover. Sem escala, sem overshoot, sem brilho. `reduced_motion` respeitado (desliga até o fade). Nada de som.

---

## C. Wireframes atualizados (1280 × 720 lógicos)

Régua: 1280 px de largura; 44 (topo) + 644 (corpo) + 32 (rodapé) = 720.

### C.1 Visão geral — globo protagonista

```
0        64      184                                                         1280
┌────────────────────────────────────────────────────────────────────────────┐
│ BRASIL · República   CAIXA  DÍVIDA  INFLAÇÃO  APROV.  POPUL.  ESTAB.  CRESC.│ 44
│                     12400  60%      4,6%      41%     12%     62     2,5%  ▶ │
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ PAÍS   │                                            ······            │
│PAÍS│ Visão ●│        ┌──────────────────┐            ············          │
│ ▤  │ Partido│        │ VISÃO GERAL      │          ················        │
│PODER│────────│        │ Popularidade  Aprov.         ··················     │
│ ▥  │ PODER  │        │ 12%           41%             ·  GLOBO  ······      │
│ECON│ Eleições│       │ Reconhec.     Coesão          ··············        │
│ ▦  │ Congr. │        │ 6%            78%              ············         │
│MUNDO│ Governo│        │ ─────────────────────         ··········            │
│ ▧  │────────│        │ AÇÃO DO MÊS                        ┌───────────────┐ │
│REGIS│ ECONOMIA│       │ [ FAZER OPOSIÇÃO ATIVA ]          │ APOIO REGIONAL│ │
│ ▨  │ Economia│       │ ─────────────────────             │ Costa Norte 12│ │
│    │ Popul. │        │ BRIEFING (rolagem)                │ Serra Azul  11│ │
│    │ Regiões│        │ + reconhecimento …                │ Vale Central 9│ │
│ ⚙  │────────│        │ − inflação …                      │ (8 regiões)   │ │
│ 💾 │ MUNDO  │        └──────────────────┘                └───────────────┘ │
│    │ Intern.│         416 px                            300 px              │
│    │────────│                                                              │
│    │REGISTRO│   rail 296 → decisão pendente · radar · partido              │
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ APROVAÇÃO 41%   ESTABILIDADE 62/100   TENSÃO 27/100        salvo 09/2027   │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

Hierarquia: globo (contexto) → métricas → ação do mês → apoio regional → briefing. O globo nunca fica sob texto corrido: o painel A é opaco e cobre o flanco esquerdo do disco; a faixa central do globo fica livre entre A e B.

### C.2 Congresso — hemiciclo à esquerda, aritmética à direita

```
┌────────────────────────────────────────────────────────────────────────────┐
│ BRASIL · República   CAIXA  DÍVIDA  INFLAÇÃO  APROV.  …            ▶       │ 44
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ PODER  │ Congresso                                    (sem globo)      │
│PAÍS│ Eleições│ ┌───────┐┌───────┐┌───────┐                                  │
│ ▤  │ Congr.●│ │CADEIRAS││MAIORIA││SITUAÇÃO│                                 │
│PODER│ Governo│ │ 0/513  ││  257  ││ minoria│                                │
│ ▥  │        │ └───────┘└───────┘└───────┘        ┌────────────────────────┐ │
│ECON│        │ ┌──────────────────────────────┐   │ BANCADAS · Câmara 513  │ │
│ ▦  │        │ │ COMPOSIÇÃO DA CÂMARA         │   │ PL    Partido Liberal  │ │
│MUNDO│       │ │                              │   │        OPOSIÇÃO 98  19%│ │
│ ▧  │        │ │        ● ● ● ● ● ●           │   │ PT    Partido dos Trab.│ │
│REGIS│       │ │      ● ● ● ● ● ● ●           │   │        OPOSIÇÃO 67  13%│ │
│ ▨  │        │ │     ● ● ● ● ● ● ● ●          │   │ UNIÃO …                │ │
│    │        │ │    ● ● ● ● ● ● ● ● ●         │   ├────────────────────────┤ │
│    │        │ │          513                 │   │ PROPOSIÇÕES            │ │
│    │        │ │   Maioria 257 · Coalizão 0   │   │ [Lei de diretrizes]    │ │
│    │        │ │  ●PL 98 ●PT 67 ●UNIÃO 50     │   │ [Reforma tributária]   │ │
│    │        │ └──────────────────────────────┘   ├────────────────────────┤ │
│    │        │  536 px                            │ AGENDA RECENTE         │ │
│    │        │                                    │ 03/2028 · aprovada …   │ │
│    │        │                                    │ 516 px                 │ │
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ DECISÃO: empresa pede incentivos  [Investir][Negociar][Não intervir]       │ 96
│ RADAR: manchete principal →  |  PARTIDO  FA · M$ 12400 · 0 membros          │
├────────────────────────────────────────────────────────────────────────────┤
│ APROVAÇÃO 41%   ESTABILIDADE 59/100   TENSÃO 27/100        salvo 09/2027   │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

Hemiciclo com 536 px de largura: raio máximo sobe para ~247 px (contra ~193 em 420 px), assentos ficam distinguíveis e os 5 arcos respiram. A legenda fica em uma linha; se faltar espaço, quebra em duas.

### C.3 Economia — painel analítico, globo atenuado ao fundo

```
┌────────────────────────────────────────────────────────────────────────────┐
│ BRASIL · República   CAIXA  DÍVIDA  INFLAÇÃO  DESEMP.  PIB  …       ▶      │ 44
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ ECONOMIA│ Economia                (globo a 35% atrás do conteúdo)       │
│PAÍS│ Economia●│ ┌──────────────────────────────────────────────────────────┐│
│ ▤  │ População│ │ CONJUNTURA · 09/2027                                     ││
│PODER│ Regiões │ │ +2,5%          Inflação 4,6%   Desemprego 8,0%           ││
│ ▥  │────────│ │ Crescimento    Dívida 60%  PIB 101,6  Caixa M$ 12.400    ││
│ECON│ MUNDO  │ │ moderado       Crescimento moderado com inflação …       ││
│ ▦  │ Intern.│ └──────────────────────────────────────────────────────────┘│
│MUNDO│        │ ┌────────────────┐┌────────────────┐┌────────────────┐        │
│ ▧  │        │ │ INDICADORES ECONÔMICOS · série mensal registrada         │        │
│REGIS│       │ │ Crescimento    ││ Inflação       ││ Desemprego     │        │
│ ▨  │        │ │ 2,5%           ││ 4,6%           ││ 8,0%           │        │
│    │        │ │ +0,1 p.p.      ││ −0,2 p.p.      ││ −0,2 p.p.      │        │
│    │        │ │ ~~~~~~~~~~~~   ││ ~~~~~~~~~~~~   ││ ~~~~~~~~~~~~   │        │
│    │        │ │ mín 2,4 máx 2,5││ …              ││ …              │        │
│    │        │ └────────────────┘└────────────────┘└────────────────┘        │
│    │        │ ┌───────────────────────────┐┌───────────────────────────┐    │
│    │        │ │ COMO LER                  ││ PROGRAMAS EXECUTIVOS      │    │
│    │        │ │ (texto explicativo)        ││ [Pacto de empregos]       │    │
│    │        │ │                            ││ [Rede de escolas técnicas]│    │
│    │        │ └───────────────────────────┘└───────────────────────────┘    │
│    │        │   512 px                       512 px                         │
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ APROVAÇÃO 41%   ESTABILIDADE 59/100   TENSÃO 27/100        salvo 09/2027   │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

Três séries em 333 px cada: largura suficiente para ~12 pontos legíveis. A conjuntura mantém os 44 px de valor (é o único número que pode ser grande).

### C.4 População — grupos reais, sem pirâmide etária

```
┌────────────────────────────────────────────────────────────────────────────┐
│ …                                                                          │ 44
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ ECONOMIA│ População           (globo a 35% atrás do conteúdo)          │
│PAÍS│ Economia│ ┌────────────────────────────────────┐┌──────────────────────┐ │
│ ▤  │ População●│ │ GRUPOS DEMOGRÁFICOS · apoio      ││ INDICADORES SOCIAIS  │ │
│PODER│ Regiões│ │ Jovens         ▮▮▮▮▮▮     12%     ││ Pobreza        18,4% │ │
│ ▥  │        │ │ Trabalhadores  ▮▮▮▮        8%      ││ Saúde          76%   │ │
│ECON│        │ │ Empreendedores ▮▮▮▮▮      10%     ││ Escolaridade   8,2 a │ │
│ ▦  │        │ │ Aposentados    ▮▮          5%      ││ ───────────────────  │ │
│MUNDO│       │ │ Rurais         ▮▮▮         6%      ││ Mudanças são lentas: │ │
│ ▧  │        │ │                                    ││ políticas exigem     │ │
│REGIS│       │ │ 640 px                             ││ financiamento …      │ │
│ ▨  │        │ └────────────────────────────────────┘│ 412 px              │ │
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ APROVAÇÃO 41%   …                                                          │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

**Justificativa explícita:** os 5 grupos são os que `state.demographics` contém, com valores de apoio em %. Não há contagem por idade, migração nem população total no estado — logo, nada disso é exibido.

### C.5 Regiões — malha de 8 regiões sobre o globo

```
┌────────────────────────────────────────────────────────────────────────────┐
│ …                                                                          │ 44
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ ECONOMIA│ Regiões                                                      │
│PAÍS│ Economia│ ┌────────────────────────────────────────┐┌──────────────────┐  │
│ ▤  │ População│ │ MAPA POLÍTICO 2D                       ││ REGIÃO 03        │  │
│PODER│ Regiões●│ │  (globo ao fundo, malha por cima)      ││ Vale Central     │  │
│ ▥  │        │ │  ┌────┐┌────┐┌────┐┌────┐              ││ Interior         │  │
│ECON│        │ │  │01  ││02  ││03● ││04  │              ││ ──────────────── │  │
│ ▦  │        │ │  └────┘└────┘└────┘└────┘              ││ População 4,2 mi │  │
│MUNDO│       │ │  ┌────┐┌────┐┌────┐┌────┐              ││ Renda 2.140      │  │
│ ▧  │        │ │  │05  ││06  ││07  ││08  │              ││ Desemprego 9,1%  │  │
│REGIS│       │ │  └────┘└────┘└────┘└────┘              ││ Apoio 36%        │  │
│ ▨  │        │ │                                        ││ ──────────────── │  │
│    │        │ │ 736 px                                 ││ Problema central │  │
│    │        │ │                                        ││ 300 px           │  │
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ APROVAÇÃO 41%   …                                                          │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

O globo aqui é atmosfera: a malha de 8 cartões continua sendo o elemento interativo (`region_clicked`), com a mesma área clicável. Nenhuma região ganha coordenada geográfica.

### C.6 Eleições — pesquisa e sala de campanha

```
┌────────────────────────────────────────────────────────────────────────────┐
│ …                                                                          │ 44
├────┬────────┬──────────────────────────────────────────────────────────────┤
│ ▣  │ PODER  │ Eleições                                                     │
│PAÍS│ Eleições●│ ┌──────────┐┌──────────┐┌──────────────────┐                 │
│ ▤  │ Congr. │ │PRÓXIMA   ││INTENÇÃO  ││CADEIRAS PROJETADAS│                │
│PODER│ Governo│ │12 meses  ││ 8,4%     ││ 41 de 513         │                │
│ ▥  │        │ └──────────┘└──────────┘└──────────────────┘                 │
│ECON│        │ ┌──────────────────────────────────────────────────────────┐│
│ ▦  │        │ │ PESQUISA NACIONAL · margem ±3,2 p.p.                     ││
│MUNDO│       │ │ PL        ▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮     24,1%     122 cadeiras      ││
│ ▧  │        │ │ PT        ▮▮▮▮▮▮▮▮▮▮▮▮         17,3%      88 cadeiras      ││
│REGIS│       │ │ … 8 bancadas + indecisos                                 ││
│ ▨  │        │ │ Maioria 257 · projeção D'Hondt sobre a pesquisa          ││
│    │        │ ├──────────────────────────────────────────────────────────┤│
│    │        │ │ SALA DE CAMPANHA                                         ││
│    │        │ │ [Debate nacional][Foco regional][Coalizão][Militância]   ││
│    │        │ │ Ações deste mês: 1 de 2                                  ││
│    │        │ └──────────────────────────────────────────────────────────┘│
│    │        │  804 px                       rail 296 → decisão/radar/partido│
├────┴────────┴──────────────────────────────────────────────────────────────┤
│ …                                                                          │ 32
└────────────────────────────────────────────────────────────────────────────┘
```

### C.7 Menu e nova campanha — globo como pano de fundo

```
┌────────────────────────────────────────────────────────────────────────────┐
│                                                ··············              │
│   ESCOLHA SEU PAÍS / SIMULAÇÃO POLÍTICA      ··················            │
│                                              ··················           │
│   MANDATIA  (40 px, Sora title)              ····· GLOBO ······            │
│   Poder não se herda.                        ··················            │
│   Constrói-se, mês a mês.                    ················              │
│   ─────────────────────────────                                            │
│   Lidere um partido, dispute eleições e                                    │
│   governe sob pressão.                                                     │
│                                                                            │
│   [ FUNDAR NOVA CAMPANHA ]  (âmbar, 360 px)                                │
│   [ CONTINUAR CAMPANHA   ]  (secundário, 360 px)                           │
│   jogo desktop · salvamento local · português brasileiro                   │
└────────────────────────────────────────────────────────────────────────────┘
```

Nova campanha: margens 96/56 (eram 120/70), formulário em duas colunas de 280 px, `_label` 15 px, título 28 px. O globo entra só no menu e na visão geral — não nas telas de formulário.

---

## D. Plano técnico definitivo

### D.1 Identidade política — verificação no código

Auditoria feita em `scripts/ui/mandato_theme.gd` e `scripts/sim/election.gd`:

```gdscript
# mandato_theme.gd, linha 73
static func axis_color(axis: float) -> Color:
    if axis < -0.15:
        return RED        # esquerda  → vermelho
    if axis > 0.15:
        return CYAN       # direita   → ciano
    return AMBER          # centro    → âmbar
```

```gdscript
# election.gd, linha 87 — rótulo → eixo numérico
["fascis", 0.95] ["libertar", 0.85] ["direita", 0.7] ["conservador", 0.6]
["liberal", 0.35] ["social-lib", 0.2] ["democrata-crist", 0.15]
["centrao", 0.0] ["centr", 0.0] ["progressis", -0.3] ["ecolog", -0.35]
["trabalh", -0.5] ["social-democra", -0.45] ["esquerda", -0.6]
["socialis", -0.7] ["comunis", -0.9]
```

**Conclusão verificada:** a correspondência real é **esquerda = vermelho, centro = âmbar, direita = ciano**. Ela é coerente com a convenção política usual (esquerda vermelha, direita azulada) e é usada em `_draw_hemicycle` (assentos + legenda), no chip de bancada (`main.gd:948`) e na lista de bancadas do Congresso.

**Decisão:** a correspondência **não muda**. O que muda é a **reserva de uso**:

| Cor | Antes | Depois |
|---|---|---|
| `AXIS_LEFT #E97878` | eixo esquerda **e** alerta | só eixo esquerda |
| `AXIS_CENTER #E8B45B` | eixo centro **e** destaque de UI | só eixo centro (âmbar de UI passa a `#DDAA4D`) |
| `AXIS_RIGHT #5FA9AC` | eixo direita **e** cabeçalho/realce | só eixo direita |

O `AXIS_RIGHT` é o `CYAN #62C7C9` atual com saturação reduzida (~12%) para não competir com o âmbar e não evocar neon. **Se o usuário preferir, mantém-se `#62C7C9` exato**: é uma constante, reversível em uma linha.

**Usos de ciano que precisam migrar.** Hoje há **32 ocorrências em `main.gd`** e **4 em `aurora_board.gd`**; apenas as que codificam eixo político podem permanecer. Regra de migração por categoria:

| Categoria | Ocorrências (exemplos reais) | Hoje | Depois |
|---|---|---|---|
| Rótulo de contexto no header | `header_position` (`main.gd:485`) | `CYAN` | `MUTED` |
| Botão secundário de navegação/ação | "SALVAR CAMPANHA" (534), "CONTINUAR CAMPANHA" (186), ações organizacionais (686), "NOMEAR" (1240), proposições (978), opções de evento (629) | `CYAN` | `MUTED` (terciário) ou `TEXT` (secundário) |
| Cabeçalho de bloco/card | `RADAR NACIONAL` (601), `BANCADAS` (936), `AGENDA RECENTE` (993), `BASE DE GOVERNO` (1182), `OPOSIÇÃO` (1219), `PESQUISA NACIONAL` (735) | `CYAN` | `AMBER` (destaque) ou `SUBTLE` (rótulo) |
| Cabeçalho de gráfico | `_draw_economy`, `_draw_chart`, `_draw_hemicycle` — 4 ocorrências em `aurora_board.gd` | `CYAN` | `AMBER` |
| Série/indicador de dado | popularidade (555), credibilidade (669), intenção de voto (730), cadeiras do partido (922), capacidade (1231), barra de apoio > 30 (`_draw_dashboard`) | `CYAN` | `TEXT` (valor) ou `GREEN` (estado positivo) |
| Insígnia | `_badge` de liderança (694) | `CYAN` | `TEXT` |

Ganho: no fim, um ciano na tela significa **uma coisa só** — direita política. Verificação na Etapa 1: `grep -n "CYAN" scripts/main.gd scripts/aurora_board.gd` deve retornar apenas chips de bancada, assentos e legenda do hemiciclo.

### D.2 Preservação funcional — invariantes

Toda a reforma é visual. Estes invariantes são **não negociáveis** e cada um tem verificação:

| # | Invariante | Verificação |
|---|---|---|
| 1 | Save `user://mandatia_save.json` + `.tmp` + backup, `SAVE_VERSION`, migração e candidatos legados | `npm test` cobre load/save; conferir `_save_game`, `_read_save_file`, `_migrate_state` intactos |
| 2 | `state` com todas as chaves atuais (`region_support` de 8, `demographics` de 5, `seat_map`, `bills`, `promises`, `last_election`) | teste existente: "estado deve preservar oito regiões simuladas" |
| 3 | 11 ideologias na criação, na mesma ordem (Comunista → fascista) | teste existente de `item_count == 11` e ordem |
| 4 | Cálculo eleitoral (D'Hondt, maioria, presidencial, parlamentarismo) | `npm test` + `--headless` sem erro |
| 5 | Votação por blocos com IA e fallback determinístico (`_on_bill_chunk`, `fallback_legislative`) | teste de contratos (`tuning_bridge_contract`) + captura de votação |
| 6 | Fluxos de IA (eleição, votação, evento, internacional) com cache e "resolver sem IA" | `npm test`, `_show_ai_wait` visualmente |
| 7 | Todas as 12 rotas de navegação e todos os botões de ação existentes | captura por tela nas 3 resoluções |
| 8 | Hemiciclo: 5 fileiras, ordenação por eixo, dados reais, legenda das 6 maiores | captura + inspeção de `_draw_hemicycle` |
| 9 | Hover/seleção da malha de 8 regiões e `region_clicked` | interação manual na tela Regiões |
| 10 | Salvar manual, menu principal, continuar campanha, resultado do mandato, promessas | captura + teste |
| 11 | Fontes Figtree/Sora/Noto preservadas, sem família nova | conferir `.tres` |

**Proibido nesta reforma:** apagar tela, apagar ação, apagar indicador, mudar fórmula, mudar texto de dados, remover o rail sem re-alojar seus 3 blocos, "simplificar" removendo conteúdo.

### D.3 Arquivos e mudanças (por área)

| Arquivo | Mudança | Impacto |
|---|---|---|
| `scripts/ui/mandato_theme.gd` | Tokens da B.1; raios 4/6; espaçamentos 8/12/16; `axis_color` mantido com constantes `AXIS_*`; novos helpers `section`, `micro_label`, `row_separator` | Fonte única; tudo herda |
| `scripts/ui/screen_factory.gd` | Reduzir a fachada fina: reexportar `mandato_theme`; remover `plate`, `holo_panel`, `modal_backdrop`, `add_press_juice`, `radial_glow`, glossário sci-fi | Remove a segunda paleta |
| `shaders/holo_panel.gdshader`, `modal_backdrop.gdshader` | Deixam de ser referenciados (arquivos podem permanecer; propor remoção depois) | Sem shader sci-fi |
| `scripts/ui/globe_view.gd` (**novo**) | Controle do globo (C. B.8) | Cenário geográfico |
| `shaders/globe_sphere.gdshader` (**novo**) | Projeção equirretangular + limbo | Textura no globo |
| `scripts/aurora_board.gd` | Ajuste de raio/legenda do hemiciclo; cores de cabeçalho; `_panel_style` raio 6 | Consistência |
| `scripts/main.gd` — `_build_shell`, `_show_game` | Camada de fundo (globo) atrás do conteúdo | Estrutura de cenário |
| `scripts/main.gd` — `_build_header` | 72 → 44 px, cápsulas com prioridade, sem overflow | Requisito A.2.4 |
| `scripts/main.gd` — `_build_sidebar` | 210 → 64 + 120; estado com grupo + item | Mudança estrutural |
| `scripts/main.gd` — `_build_status_bar` | 46 → 32 px | Compactação |
| `scripts/main.gd` — `_build_right_rail` | Extrair 3 blocos; modo `rail` e modo `faixa de contexto` | Layout adaptável |
| `scripts/main.gd` — telas | Grades da matriz D.4 / B.9 | Larguras por tela |
| `scripts/main.gd` — `_apply_responsive` | Breakpoints por largura lógica + `rail` por tela | Sem estouro |
| `tools/capture_fase1.gd` | Loop de resoluções 1280×720, 1600×900, 1920×1080 com sufixo no nome do arquivo | Verificação visual |
| `project.godot` | `stretch/mode = "canvas_items"`, `aspect = "expand"`, `scale_mode = "fractional"` | Escala nas 3 resoluções |
| `scripts/main.gd` — `_ready` | `get_window().min_size = Vector2i(1280, 720)` | Impede layout abaixo da base |

Nada disso é executado nesta etapa.

### D.4 Navegação em duas faixas — desenho da mudança

Estado atual: `selected_nav: String` guarda só o item ("Congresso"), e `_select_nav(item)` reconstrói a tela inteira.

Proposta mínima e compatível:

```gdscript
var selected_nav := "Visão geral"        # mantido: item
var selected_group := "PAÍS"             # novo: grupo

const NAV := [
    ["PAÍS",     ["Visão geral", "Meu partido"]],
    ["PODER",    ["Eleições", "Congresso", "Governo"]],
    ...
]

func _select_group(group: String) -> void:
    selected_group = group
    if not NAV_ITEMS[group].has(selected_nav):
        selected_nav = NAV_ITEMS[group][0]   # abre o primeiro item do grupo
    _show_game()

func _select_nav(item: String) -> void:
    selected_nav = item
    selected_group = _group_of(item)         # sincroniza a faixa principal
    _show_game()
```

- `_select_nav` continua com a mesma assinatura → **nenhum `connect` existente quebra** (as 12 chamadas e os botões "VER NOTÍCIAS" seguem funcionando).
- A faixa contextual mostra só os itens do grupo ativo; clicar no grupo ativo alterna recolher/expandir (recolhida = 64 px de navegação e conteúdo ganha 120 px — útil em telas `FULL`).
- Item ativo destacado nas duas faixas; nenhuma tela deixa de ser alcançável.

### D.5 Globo — etapas internas

1. `globe_view.gd` com disco + graticula + terminador (sem textura). Verificação: capturas em 3 resoluções, sem quad preto, sem custo perceptível.
2. Integração como camada de fundo em `_show_game` (atrás de `root_stack`) e no menu. Verificação: nenhuma tela perde contraste; texto sobre painel opaco.
3. Marcador por `country.region` + bandeira. Verificação: trocar de país na criação de campanha muda o marcador.
4. Textura (Nível B), condicionada à restauração de `aurora-map.png`.
5. Polimento: limite de opacidade por tela (100% na Visão geral, 35% em Economia/População, 0% em Congresso).

### D.6 Hemiciclo — ajustes preservando a lógica

- Raio/assento recalculados para 536 px de largura (mantendo `max_radius = min(w×0.46, h−132)` e `dot` entre 1.4 e 4.5).
- Total de cadeiras em 26 px no centro do arco quando `chamber_seats == total`; caso contrário mantém-se a legenda atual ("N cadeiras registradas · câmara M"), que é informação real e não pode ser escondida.
- Mesa da presidência: retângulo 64 × 8 em `SURFACE_RAISED` com borda `AMBER`, acima do arco interno.
- Votação em curso: assentos da bancada em disputa com preenchimento `AMBER` a 70% — **só quando o dado de votação em curso existir** (`_bill_in_progress`); caso contrário, nada muda.
- Legenda: uma linha, quebra em duas se faltar espaço, sempre com quadrado 7 px + "SIGLA 123".
- Nenhuma mudança em ordenação, contagem, `hemicycle_seats`, `hemicycle_axes` ou `majority`.

### D.7 Resoluções — estratégia e critérios de teste

#### Estratégia

`project.godot`:

```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale_mode="fractional"
```

- **1280 × 720:** escala 1,000 → layout exatamente como nos wireframes.
- **1600 × 900:** escala 1,250 → mesma composição, 25% maior.
- **1920 × 1080:** escala 1,500 → mesma composição, 50% maior.

Consequência: as três resoluções são 16:9, então `expand` não adiciona área lógica e **a matriz de larguras de B.9 vale para todas**. Legibilidade e proporção são preservadas por construção, não por ajuste manual — 10 px lógicos viram 15 px físicos em 1080p.

Vantagens: um único layout para manter; nenhum breakpoint novo; texto e ícones escalam juntos.
Custo: em 1600×900 a escala é fracionária (1,25) e o texto pode ficar levemente suavizado; `scale_mode="fractional"` suaviza isso no Godot 4.7.

Alternativa rejeitada nesta etapa: layout nativo + fator de escala de tokens por resolução. Daria mais área útil em 1600/1920, mas triplica o custo de verificação e arrisca quebrar telas densas. Fica registrada como evolução futura ("modo denso").

Janela: `resizable = true`, `min_size = 1280 × 720` (definido em código). Em aspecto não 16:9 (ex.: 4:3), `expand` reduz a largura lógica abaixo de 1280 e os breakpoints de `_apply_responsive` continuam valendo como rede de segurança (rail oculto < 1180, faixa contextual recolhida < 1100, margens 12 < 1000).

#### Critérios objetivos por resolução

| # | Critério | Como medir |
|---|---|---|
| 1 | Nenhum texto cortado na borda direita (hoje falha) | captura: cabeçalho, rail, tabela de bancadas, botão "AVANÇAR MÊS" |
| 2 | Sem barra de rolagem horizontal em nenhuma tela | inspeção visual das 12 capturas |
| 3 | Menor texto renderizado ≥ 10 px lógicos (15 px em 1080p) | conferência na escala tipográfica |
| 4 | Sete indicadores na barra superior em 1280; nenhum é sobreposto | captura do cabeçalho |
| 5 | Hemiciclo com assentos distinguíveis e legenda completa | captura do Congresso |
| 6 | Colunas respeitam a largura mínima da classe (`NARROW` ≥ 280) | captura + checagem de `custom_minimum_size` |
| 7 | Globo visível entre 45% e 60% da área de conteúdo na Visão geral | captura com régua |
| 8 | Nenhum painel cobre mais de 55% do disco do globo | captura |
| 9 | Proporção idêntica entre as três resoluções (mesma composição) | comparação das capturas em 3 tamanhos |
| 10 | `npm test` verde nas três execuções | saída do teste |

**Ferramenta:** estender `tools/capture_fase1.gd` para aceitar resolução por argumento (`--res 1280x720`) e salvar com sufixo, gerando 12 capturas por rodada. Sem isso, a verificação de resolução é manual e não auditável.

### D.8 O que é sugestão futura (fora do escopo)

- Telas de **Defesa**, **Serviços públicos** e **Ciência/Energia** — não existem no projeto.
- **Globo arrastável** com rotação, zoom e seleção de país por clique — exigiria geodados de países.
- **Mapa real** com fronteiras e projeção por país — exigiria dados geoespaciais.
- **Pirâmide etária / migração** — exigiria dados demográficos que não existem.
- **Resultado orçamentário e reservas** isolados no cabeçalho — os dados não existem; usar `debt`, `funds`, `gdp`, `economy`, `inflation`, `unemployment`, `approval`, `popularity`, `recognition`, `cohesion`.
- **Modo denso** para 1600/1920 com mais colunas.
- **Sons de interface.**

### D.9 Ordem de implementação com verificação

Cada etapa termina com o mesmo gate: `npm test` verde + capturas nas 3 resoluções + inspeção visual + checklist de invariantes. Etapa só avança se o gate passar.

| Etapa | Escopo | Risco | Verificação específica | Rollback |
|---|---|---|---|---|
| **0. Baseline** | Nada de código de jogo. Estender `capture_fase1.gd` para 3 resoluções e capturar o estado atual | Nulo | 12 capturas em `docs/shots/baseline/`; `npm test` verde como referência | Não se aplica |
| **1. Tokens** | `mandato_theme` (paleta B.1, raios, helpers) + `screen_factory` como fachada | Baixo, efeito global | Contraste de cada token sobre `SURFACE`; `grep` de `#2f6fe4`, `#70b7ff`, `skew`, `holo`; capturas das 12 telas | Reverter o arquivo de tema (isolado) |
| **2. Barra superior e rodapé** | Header 44 px com cápsulas priorizadas; status 32 px | Baixo | Critério 1 e 4; captura do cabeçalho nas 3 resoluções | Reverter `_build_header`/`_build_status_bar` |
| **3. Navegação em duas faixas** | `selected_group`, faixas 64/120, recolhimento | Médio (estado) | Percorrer as 12 rotas; conferir que todo item é alcançável; `npm test` | Reverter estado + `_build_sidebar` |
| **4. Painéis adaptáveis + rail opcional + faixa de contexto** | Matriz B.9, sem overflow em 1280, 3 blocos do rail re-alojados | **Alto** (layout) | Critérios 2, 6, 8; conferir que decisão/radar/partido existem em todas as telas | Reverter para painel único de 800 e rail fixo |
| **5. Globo** | Camada de fundo, graticula, marcador, opacidade por tela | Médio (perf/contraste) | Critérios 7, 8; FPS estável; contraste do texto sobre painel; troca de país | Desligar a camada por flag (`SHOW_GLOBE`) |
| **6. Hemiciclo + telas restantes** | D.6 e acabamento de Congresso, Economia, População, Regiões, Eleições, Governo, menu | Médio | Capturas finais + 10 critérios de D.7 + `npm test` | Reverter por tela |

Dependências: 1 → 2 → 3 → 4 são sequenciais. 5 pode rodar em paralelo a 4 (arquivos distintos). 6 só depois de 4 (depende das larguras).

---

## E. Riscos e decisões pendentes

| # | Item | Detalhe | Encaminhamento |
|---|---|---|---|
| 1 | **Assets geográficos ausentes** | `aurora-map.png`, `leadership-portraits.png`, `party-symbols.png` não estão no disco (gitignored; listados em `assets.lock.json`) | Globo funciona sem eles (Nível A). Restaurar é tarefa de pipeline, com autorização |
| 2 | **Formato do mapa desconhecido** | Sem o arquivo, não é possível confirmar se é equirretangular | Ao restaurar, conferir; se for plano, usar máscara + curvatura (Nível B alternativo) |
| 3 | **Estouro atual em 1280** | Evidência nas capturas atuais | Corrigido na Etapa 4, com critério objetivo |
| 4 | **Rail opcional muda a estrutura** | Os 3 blocos precisam existir em todas as telas | Faixa de contexto de 96 px; verificação por tela |
| 5 | **`axis_color` e ciano** | Ciano é hoje cor de UI **e** de direita política | Reserva de uso (D.1); hex do `AXIS_RIGHT` sujeito a aprovação |
| 6 | **Escala fracionária em 1600×900** | Texto pode ficar levemente suavizado | `scale_mode="fractional"`; avaliar nas capturas |
| 7 | **Globo em GL Compatibility** | Projeto usa `gl_compatibility` | Shader simples, sem features de compute; testar em janela real |
| 8 | **Custo do globo por quadro** | `_draw` da graticula a cada frame | Desenhar só em `resize`/mudança de estado; cachear em `ImageTexture` se necessário |
| 9 | **Legibilidade de 10 px** | Limite inferior da escala | Usar só em metadados; corpo nunca abaixo de 12 px |
| 10 | **Contraste de `SUBTLE`** | `#70747A` sobre `SURFACE #17191C` ≈ 3:1 | Só em metadados não essenciais; texto informativo usa `MUTED` |
| 11 | **Retratos** | Sem `leadership-portraits.png`, não há como recortar por pessoa | Manter `_badge` com iniciais até restauração + mapeamento |
| 12 | **Nenhum dado novo é criado** | O globo não representa territórios reais; marcador é macro-região | Documentar no código que a posição é constante visual |

---

## F. Checklist de aprovação

- [ ] Interface de simulador institucional, não sci-fi
- [ ] **Globo como cenário dominante** na Visão geral, Internacionais e Regiões
- [ ] **Globo viável sem asset novo** (graticula + tons), com textura quando o mapa for restaurado
- [ ] **Painéis com larguras distintas por tela** (matriz B.9)
- [ ] **Rail opcional com faixa de contexto** preservando decisão, radar e partido
- [ ] Barra superior compacta (44 px) sem cortes em 1280
- [ ] Navegação principal estreita (64 px) + faixa contextual (120 px)
- [ ] **1280×720, 1600×900 e 1920×1080 com escala uniforme e critérios de teste**
- [ ] Grafite/preto predominante, âmbar como destaque
- [ ] Figtree, Sora e Noto Sans SC preservadas
- [ ] **Correspondência política preservada e conferida no código** (esquerda vermelho · centro âmbar · direita ciano)
- [ ] Ciano reservado ao eixo de direita
- [ ] Hemiciclo mantém 5 fileiras, ordenação por eixo, dados reais e legenda
- [ ] **Nenhuma funcionalidade, ação, dado ou cálculo removido** (D.2)
- [ ] Nenhuma tela, indicador ou dado inventado
- [ ] Ordem de implementação em 7 etapas com gate de verificação e rollback
- [ ] **Nenhum arquivo de código alterado nesta etapa**
