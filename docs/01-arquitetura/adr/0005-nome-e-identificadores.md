# ADR-0005 — Nome "Nexo" e identificadores técnicos

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O projeto deixou de ser só "uma GUI do logiops" e virou um hub de periféricos, então precisa de um nome
amplo. O nome escolhido foi **Nexo** ("ligação", "conexão" em português). Verificação feita em
27/10/2026: os pacotes `nexo` e `nexo_core` já existem no pub.dev; "Nexo" também é marca de uma empresa
de cripto e de um jornal brasileiro (áreas diferentes, mas com risco de colisão de busca).

## Decisão
- **Nome de exibição:** Nexo.
- **Repositório:** `nexo-hub` (GitHub `Joao-IA/nexo-hub`).
- **App ID / nomes D-Bus:** `io.github.joao_ia.NexoHub` (hífen do usuário vira `_`, convenção do Flathub
  e exigência de nomes D-Bus). Ex.: `io.github.joao_ia.NexoHub.Helper`, `io.github.joao_ia.NexoHub.Agent`.
- **Pacotes Dart:** prefixo `nexohub_` (ex.: `nexohub_core`, `nexohub_logid_config`).
- **Executáveis:** `nexo`, `nexo-agent`, `nexo-helper`; extensão `nexo-focus@joao-ia.github.io`.

## Consequências
- ✅ Sem colisão técnica de nomes; marca curta para o usuário.
- ⚠ Se o projeto for publicado em lojas, reavaliar a marca (busca de registro no INPI/USPTO).
