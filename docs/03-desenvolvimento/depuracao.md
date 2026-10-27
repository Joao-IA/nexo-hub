# Depuração

**Status:** vigente para ferramentas de sistema; seções do Nexo entram conforme os componentes surgem.

## D-Bus

```bash
busctl --system list | grep -i -E "logiops|nexohub"     # serviços no ar
sudo busctl --system tree pizza.pixl.LogiOps             # objetos do logid (root)
busctl --system introspect io.github.joao_ia.NexoHub.Helper /io/github/joao_ia/NexoHub/Helper
sudo busctl --system monitor io.github.joao_ia.NexoHub.Helper   # ver chamadas em tempo real
busctl --user monitor io.github.joao_ia.NexoHub.Agent            # idem, sessão
dbus-monitor --session "interface='io.github.joao_ia.NexoHub.Focus'"   # sinais da extensão
```

Detalhes da API do logid: [02-logiops/api-dbus-logid.md](../02-logiops/api-dbus-logid.md).

## logid em modo debug

```bash
sudo systemctl stop logid
sudo logid -v                    # ou: sudo logid -v -c /caminho/teste.cfg
# Ctrl+C ao terminar
sudo systemctl start logid
```

## polkit

```bash
pkaction --verbose --action-id io.github.joao_ia.NexoHub.apply-config   # política instalada?
journalctl -u polkit -f                                                 # decisões e erros
```

## Flutter (UI)

- `flutter run -d linux` → tecla `v` abre o **DevTools** (inspetor de widgets, performance, logs).
- `flutter run -d linux --profile` para medir desempenho real.

## Dart AOT (agent/helper) com depurador

Em desenvolvimento rode pela VM em vez do binário AOT:

```bash
dart run --observe bin/agent/main.dart --verbose
# a saída mostra a URL do VM service → abra no DevTools ou anexe pelo VS Code ("Dart: Attach to Process")
```

## Extensão GNOME Shell

- **Looking Glass:** `Alt+F2` → `lg` → aba *Extensions* (erros de carregamento).
- Logs: `journalctl --user -f /usr/bin/gnome-shell | grep nexo-focus`.
- Testar sem afetar a sessão: `dbus-run-session gnome-shell --devkit` (GNOME 49+).
