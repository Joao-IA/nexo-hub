# Executar em desenvolvimento

**Status:** a preencher. Cada componente ganha sua seção na fase em que for criado:

| Componente | Fase | Seção prevista |
|---|---|---|
| Pacotes `nexohub_*` | 1 | `dart test` por pacote; exemplos de uso via `dart run` |
| `nexo-helper` | 3 | Rodar no **barramento de sessão** com caminhos de teste (`--dev`), sem root; instalar a política polkit de desenvolvimento |
| `nexo` (UI) | 4 | `flutter run -d linux` com `FakeHelper`/`FakePlatform` ou com o helper real |
| `nexo-agent` | 6 | `dart run bin/agent/main.dart --verbose` |
| `nexo-focus` | 6 | Link simbólico em `~/.local/share/gnome-shell/extensions/` + sessão aninhada `dbus-run-session gnome-shell --devkit` |
