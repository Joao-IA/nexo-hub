# ADR-0008 — Versão do Flutter fixada em `.fvmrc` sem exigir FVM

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O plano previa usar o FVM para fixar a versão do Flutter. Instalar o FVM a partir de um Flutter já
instalado faria o FVM baixar **outra cópia** do SDK (~1,5 GB). O que importa é que todos (máquina local
e CI) usem exatamente a mesma versão.

## Decisão
- A versão fica registrada em **`.fvmrc`** (formato do FVM: `{"flutter": "3.47.8"}`).
- Localmente, o Flutter é instalado pelo tarball oficial em `~/development/flutter`.
- O script `tool/check_flutter_version.sh` compara a versão instalada com o `.fvmrc` e falha se divergir;
  o CI lê o `.fvmrc` para instalar a mesma versão.
- Quem preferir FVM pode usá-lo normalmente: ele lê o mesmo `.fvmrc`.

## Consequências
- ✅ Sem download duplicado; reprodutibilidade garantida pelo script e pelo CI.
- ⚠ Atualizar o Flutter = atualizar o SDK local **e** o `.fvmrc` (passo a passo em
  [atualizar-dependencias.md](../../05-manutencao/atualizar-dependencias.md)).
