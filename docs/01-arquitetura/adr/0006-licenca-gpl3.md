# ADR-0006 — Licença GPL-3.0

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O projeto é público (portfólio) e, no roadmap do hub, pode portar código de protocolos de projetos como
logiops, GalaxyBudsClient e HeadsetControl — todos GPL-3.0.

## Decisão
O Nexo é licenciado sob **GPL-3.0** (texto em [`LICENSE`](../../../LICENSE)).

## Consequências
- ✅ Compatível com portar/derivar código dos projetos de referência.
- ✅ Garante que derivados continuem abertos.
- ⚠ Dependências precisam ter licenças compatíveis (MIT, BSD, Apache-2.0, LGPL, GPL-3.0). Verificar a
  licença de cada pacote adicionado (registrar em [atualizar-dependencias.md](../../05-manutencao/atualizar-dependencias.md)).
- ⚠ Não usar logos, renders ou textos oficiais das marcas (ilustrações próprias).
