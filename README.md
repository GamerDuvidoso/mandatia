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

## Dados

`config/countries.json` é a única fonte de países, partidos, cadeiras e líderes.
Nada é estimado: lacunas de fonte ficam registradas em `notes` e aparecem na UI
como "X registradas · câmara Y". Para conferir:

```bash
python3 tools/audit_countries.py        # falha em erro estrutural
python3 tools/audit_countries.py --strict
```

## Rodar e testar

O Godot 4.7 fica em `.tools/` (não versionado).

```bash
# abrir o jogo
./.tools/Godot_v4.7-stable_win64_console.exe --path .

# suíte de testes (headless)
./.tools/Godot_v4.7-stable_win64_console.exe --headless --path . res://test/test_suite.tscn

# capturas de tela em docs/shots/
./.tools/Godot_v4.7-stable_win64_console.exe --path . --script tools/capture_fase1.gd
```

## IA local (planejada)

Decisões que não são do jogador (voto fracionário por bancada, eventos, política
internacional, reações de partidos e narrativa eleitoral) serão opcionalmente
decididas por um modelo local via Ollama, com fallback determinístico quando o
modelo falta ou falha. Indicadores exatos — dinheiro, dívida, PIB, inflação,
desemprego, contagem de votos e conversão de cadeiras — permanecem no motor.

## Estrutura

- `scripts/main.gd` — telas, calendário de mandato, campanha, governo, economia.
- `scripts/sim/` — eleição (D'Hondt, presidencial), coalizão e legislativo puros.
- `scripts/ui/` — tema único, bandeiras procedurais e o painel de dados.
- `test/test_suite.gd` — suíte headless cobrindo simulação e telas.
