# ADR-0007 — Idioma da documentação e do código

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O mantenedor é brasileiro e precisa entender cada parte para depurar e manter. O projeto também é
portfólio público.

## Decisão
- `docs/`, ADRs, `CHANGELOG.md`: **português (PT-BR)**.
- Código, identificadores, comentários `///` e mensagens de commit: **inglês** (convenção da comunidade).
- `README.md` em inglês + `README.pt-BR.md`.
- Interface do app: PT-BR e EN (arquivos ARB).

## Consequências
- ✅ Documentação acessível para o mantenedor; código legível para a comunidade.
- ⚠ Termos técnicos aparecem nos dois idiomas — mantidos consistentes pelo [glossário](../../glossario.md).
