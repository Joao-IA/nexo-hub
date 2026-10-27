# Publicar uma versão

**Status:** a preencher na Fase 7 (quando o empacotamento `.deb` existir).

Roteiro previsto:

1. `main` verde no CI; checklist manual ([06-testes-manuais](../06-testes-manuais/mx-master-3s.md))
   executado e anexado.
2. Mover as entradas de `[Não lançado]` do `CHANGELOG.md` para `[X.Y.Z] - AAAA-MM-DD`.
3. Atualizar a versão em `apps/nexo/pubspec.yaml` e no `packaging/linux/debian/changelog`.
4. Commit `chore(release): vX.Y.Z` e tag anotada `git tag -a vX.Y.Z -m "vX.Y.Z"`.
5. `git push --follow-tags` → o CI gera o `.deb` e cria o GitHub Release com as notas do CHANGELOG.
6. Instalar o `.deb` publicado numa máquina limpa e repetir o smoke test.
