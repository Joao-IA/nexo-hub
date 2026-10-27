# Atualizar Flutter, Dart e dependências

**Status:** vigente para o Flutter; seção de pacotes cresce a partir da Fase 1.

## Flutter

1. Veja a versão estável atual:
   ```bash
   curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
     | python3 -c "import json,sys; d=json.load(sys.stdin); h=d['current_release']['stable']; \
       print([r['version'] for r in d['releases'] if r['hash']==h][0])"
   ```
2. Leia as *breaking changes*: <https://docs.flutter.dev/release/breaking-changes>.
3. Instale a nova versão seguindo [ambiente.md §2](../03-desenvolvimento/ambiente.md) (substitua a pasta
   `~/development/flutter`).
4. Atualize **`.fvmrc`** com a nova versão.
5. Rode `tool/check_flutter_version.sh`, `dart format`, `flutter analyze`, todos os testes e o checklist
   manual resumido.
6. Commit: `build: bump Flutter to X.Y.Z` + entrada no `CHANGELOG.md`.

## Pacotes Dart/Flutter

```bash
dart pub outdated          # o que está desatualizado
dart pub upgrade           # dentro das faixas do pubspec
dart pub upgrade --major-versions   # com cuidado: pode quebrar API
```

Antes de adicionar ou atualizar um pacote, confira a **licença** (precisa ser compatível com GPL-3.0 —
[ADR-0006](../01-arquitetura/adr/0006-licenca-gpl3.md)) e registre na tabela abaixo.

| Pacote | Licença | Usado em | Por quê |
|---|---|---|---|
| *(preenchido conforme os pacotes forem adicionados)* | | | |
