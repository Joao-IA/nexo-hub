# Convenções

**Status:** vigente.

## Código

- Estilo: `dart format` (largura padrão de 80 colunas). O CI falha se houver arquivo não formatado.
- Análise estática estrita (`analysis_options.yaml` na raiz): `strict-casts`, `strict-inference`,
  `strict-raw-types` e lints adicionais. **Nenhum aviso** é aceito no CI.
- Identificadores, comentários e mensagens de log em **inglês**; documentação em `docs/` em **PT-BR**
  ([ADR-0007](../01-arquitetura/adr/0007-idioma-da-documentacao-e-do-codigo.md)).
- Toda API pública tem `///`. Comentários explicam o **porquê**; quando espelhamos um comportamento do
  logid, inclua o permalink da linha correspondente.
- Variantes do logid (ações, gestos) são `sealed class` + `switch` exaustivo — nunca `dynamic` ou
  `Map<String, dynamic>` no modelo.
- Erros esperados retornam tipos de resultado explícitos; exceções só para bugs/condições inesperadas.

## Antes de cada commit

Rode o mesmo que o CI roda (`.github/workflows/ci.yml`):

```bash
tool/check_flutter_version.sh            # Flutter local == .fvmrc
/usr/bin/python3 -I tool/check_docs_links.py   # links e âncoras de todos os .md
dart format --output=none --set-exit-if-changed .   # (quando houver pubspec.yaml na raiz)
dart analyze --fatal-infos
dart test                                # dentro de cada pacote com testes
```

| Script | O que verifica |
|---|---|
| `tool/check_flutter_version.sh` | Se o Flutter no PATH é a versão fixada em `.fvmrc` ([ADR-0008](../01-arquitetura/adr/0008-versao-do-flutter-fixada-em-fvmrc.md)) |
| `tool/check_docs_links.py` | Se todo link relativo em Markdown aponta para um arquivo existente e, quando há `#âncora`, para um título existente (mesmas regras de slug do GitHub). Ignora links externos e blocos de código |

## Commits — [Conventional Commits](https://www.conventionalcommits.org/pt-br/)

```
<tipo>(<escopo opcional>): <resumo no imperativo, em inglês>
```

Tipos: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`.
Escopos comuns: `logid-config`, `input-keys`, `helper`, `agent`, `ui`, `focus-ext`, `packaging`, `docs`.

Exemplos: `feat(logid-config): parse hex integers`, `docs: add recovery guide`.

## Branches e PRs

- `main` sempre verde (CI passando).
- Trabalho em `feat/<assunto>`, `fix/<assunto>`, `docs/<assunto>`.
- Cada PR: descrição do quê/porquê, como testar, docs atualizadas, entrada no `CHANGELOG.md`.

## Versões — [SemVer](https://semver.org/lang/pt-BR/)

`MAIOR.MENOR.CORREÇÃO`. Antes da v1.0.0, versões `0.x` podem quebrar compatibilidade.
Processo de lançamento: [05-manutencao/release.md](../05-manutencao/release.md).
