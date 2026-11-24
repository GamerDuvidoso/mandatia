# Phase J — Matriz de QA e release

O projeto permanece **não pronto para lançamento** até que os itens abaixo tenham evidência reproduzível.

| Frente | Evidência exigida | Situação |
|---|---|---|
| Parser e boot | Godot 4.7 headless sem `Parse Error`, `SCRIPT ERROR` ou `ERROR:` | boot validado anteriormente; repetir após alterações |
| Progressão | novo jogo, meses, evento, eleição e relatório | parcial |
| Eleições | parlamentarismo/presidencialismo, segundo turno, cadeiras e empates | contratos direcionados; integração ampla pendente |
| Governo | coalizão, lei, censura, estabilidade e consequências | contratos direcionados; progressão pendente |
| Saves | novo save, round-trip, backup, corrupção, legado, campos ausentes/desconhecidos e repetição | smoke criado; execução pendente |
| Simulação | 12/60/120/240 meses, soak e limites acumulativos | não executado |
| IA ausente | jogo completo com Ollama indisponível e fallback | infraestrutura presente; prova dinâmica pendente |
| IA real isolada | probe de plenário, evento e internacional com modelo configurado | não executado |
| UI | walkthrough em 1280×720, 1366×768, 1600×900 e 1920×1080 | pendente |
| Build | export Windows, verificação do pack e execução em instalação limpa | pendente |
| Documentação | README e known issues coerentes com código | parcial; revisar após QA |

## Known issues já declarados

- Migração legada e corrupção de save ainda não têm validação dinâmica nesta Phase J.
- Os envelopes regionais são dados modelados de apresentação; não são população autoritativa nem peso eleitoral.
- Saúde, educação, trabalho, renda, território autoritativo e H1–H5 não devem ser tratados como implementados sem mecânica e testes próprios.
- IA local é opcional; o modelo configurado pode estar ausente e o fallback é o caminho obrigatório de continuidade.
- Simulações longas, soak, benchmarks, build e instalação limpa continuam pendentes.

## Regra de release

Nenhum contrato textual, tela, botão, documentação ou smoke isolado substitui QA de progressão real. O resultado final pode ser “não pronto” ou “pronto com limitações”, mas não será declarado lançamento sem todos os bloqueadores críticos resolvidos e evidências preservadas.
