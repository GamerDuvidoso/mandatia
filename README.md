# Mandatia — Poder e Política

Simulação política por turnos em Godot 4.7. Você lidera um partido real de um dos
35 países catalogados ou funda o seu, disputa eleições e, se chegar ao poder,
governa um mandato de 48 meses com promessas a cumprir.

## Como jogar

- **Campanha**: partido fora do poder começa a 12 meses da primeira eleição.
  Cada mês permite até três ações de campanha, uma delas gratuita.
- **Eleição**: pesquisa nacional convertida em cadeiras por D'Hondt; no
  presidencialismo há segundo turno. A câmara sempre fecha no tamanho do país.
- **Mandato**: 48 meses. Leis, programas executivos, coalizão e economia.
  Promessas escolhidas no início do mandato são cobradas no fim.
- **Resultado**: ao fim de cada mandato, a tela mostra cadeiras, leis aprovadas,
  aprovação, dívida e promessas. Perder leva à oposição — o ciclo seguinte
  continua com a popularidade acumulada.
- **Oposição**: ação mensal de oposição, proposições de bancada e, em sistemas
  parlamentaristas, moção de censura quando o governo está impopular.
- **Fase B**: ideologia em dois eixos, 12 grupos sociais em duas camadas, sete
  organizações de interesse, relações partidárias dinâmicas, facções, coalizões
  com termos, escândalos em estágios e campanha com financiamento e alvo
  regional. Telas novas: **Sociedade** e **Crises**; gráfico de dois eixos em
  **Meu partido**, matriz de relações no **Congresso** e leitura regional em
  **Eleições**. A revisão B7 conecta greves persistentes a produção, inflação,
  aprovação e coalizão; cumprimento/violação de pauta afeta votos e pastas; e
  escândalos têm cobertura, procedimento e registro causal observável.

## Dados

`config/countries.json` é a única fonte de países, partidos, cadeiras e líderes.
Nada é estimado: lacunas de fonte ficam registradas em `notes` e aparecem na UI
como "X registradas · câmara Y". Para conferir:

```bash
python3 tools/audit_countries.py        # falha em erro estrutural
python3 tools/audit_countries.py --strict
```

`config/ideologies.json` classifica as posições em dois eixos (análise, não dado
oficial). `config/social_groups.json` declara as duas camadas populacionais e a
incidência de cada política; `config/interest_groups.json` define as sete
organizações; `config/scandals.json` define categorias, estágios e respostas;
`config/campaign_actions.json` define as ações, custos e tetos de financiamento.
Todas as participações sociais são **modelo de simulação**, identificadas na UI.

`config/economy.json` traz o perfil econômico individual dos 35 países. Cada
indicador guarda valor, unidade, ano de referência, classificação
(`official`/`estimated`), fonte e metodologia quando estimado. A base oficial é
o World Bank WDI. Para regerar e auditar:

```bash
python3 tools/build_economy_profiles.py   # baixa do World Bank e grava
python3 tools/audit_economy.py            # falha em dado inválido ou sem fonte
```

## Rodar e testar

O Godot 4.7 fica em `.tools/` (não versionado).

```bash
# abrir o jogo
./.tools/Godot_v4.7-stable_win64_console.exe --path .

# suíte de testes (headless)
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . res://test/test_suite.tscn

# capturas de tela em docs/shots/ (opcional: --res 1366x768 --out fase-b-1366x768)
./.tools/Godot_v4.7-stable_win64_console.exe --path . --script tools/capture_fase1.gd

# walkthrough de UI ponta a ponta (sai com 1 em falha)
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/walkthrough.gd

# soak: 35 países e 69 campanhas (demorado)
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/soak_harness.gd

# sonda da IA local no jogo (plenário, evento e cenário internacional)
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/probe_ai_end_to_end.gd

# conteudo do build exportado
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" builds/Mandatia.exe
python3 tools/verify_pack.py
```

O build exportado nao executa `--script res://tools/...` (tools/* fica fora do
pack), por isso a conferencia do pack le o proprio `.pck` em
`tools/verify_pack.py`.

## IA local (planejada)

Decisões que não são do jogador (voto fracionário por bancada, eventos, política
internacional, reações de partidos e narrativa eleitoral) serão opcionalmente
decididas por um modelo local via Ollama, com fallback determinístico quando o
modelo falta ou falha. Indicadores exatos — dinheiro, dívida, PIB, inflação,
desemprego, contagem de votos e conversão de cadeiras — permanecem no motor.

## Estrutura

- `scripts/main.gd` — telas, calendário de mandato, campanha, governo, economia,
  onboarding e objetivos do mandato.
- `scripts/sim/` — eleição (D'Hondt, presidencial 2D), coalizão, legislativo e
  eventos determinísticos puros; módulos B1–B7: ideologia, grupos sociais,
  organizações de interesse, relações/facções, escândalos, campanha e registro
  causal.
- `scripts/ui/` — tema único, bandeiras procedurais, globo, painel de dados,
  tutorial e gráfico ideológico de dois eixos.
- `config/economy.json` — perfis econômicos com proveniência.
- `test/test_suite.gd` — suíte headless cobrindo simulação, telas e dados.
- `docs/fase_a_desenvolvimento.md` — registro da Fase A e limitações.
- `docs/fase_b_desenvolvimento.md` — regras, dados, testes e limitações da Fase B.
