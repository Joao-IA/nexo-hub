# Pacotes Dart (monorepo)

**Status:** planejado. Cada pacote ganha sua seção completa (API pública, exemplos, onde é usado) quando
for criado. O repositório usa **pub workspaces**: um `pubspec.yaml` na raiz lista os membros e todos
compartilham um único `pubspec.lock`.

| Pacote | Fase | Depende de | Usado por | Propósito |
|---|---|---|---|---|
| `nexohub_logid_config` | 1 | — (Dart puro) | UI, helper | Ler, representar, validar e gerar o `logid.cfg` |
| `nexohub_input_keys` | 1 | — | UI, `nexohub_logid_config` | Tabela de teclas evdev (`KEY_*`) e conversão USB-HID → evdev para capturar atalhos |
| `nexohub_core` | 4 | — | todos | Tipos do hub: `Device`, `Capability` (sealed), `DeviceAdapter`, `PlatformServices` |
| `nexohub_ipc` | 3 | `dbus` | UI, agent, helper | Contratos D-Bus (XML de introspecção), DTOs versionados, códigos de erro |
| `nexohub_platform_linux` | 4 | `dbus`, `nexohub_core`, `nexohub_ipc` | UI, agent | UPower, BlueZ, sysfs hidraw, clientes do agent/helper |
| `nexohub_adapter_logitech_logid` | 4–5 | `nexohub_core`, `nexohub_logid_config` | UI, agent | Traduz logid ↔ capacidades do hub |

Aplicativos e executáveis:

| Caminho | Tipo | Depende de |
|---|---|---|
| `apps/nexo/` | Flutter (UI) | todos os pacotes acima |
| `bin/helper/` | Dart AOT (`nexo-helper`) | `nexohub_logid_config`, `nexohub_ipc` |
| `bin/agent/` | Dart AOT (`nexo-agent`) | `nexohub_core`, `nexohub_ipc`, `nexohub_platform_linux` |

## Regras de dependência

- Pacotes `nexohub_*` **não** dependem de Flutter (exceto se um dia houver um pacote de widgets
  compartilhados). Assim helper e agent continuam executáveis Dart puros.
- `nexohub_core` não conhece Linux, logid ou D-Bus — é o contrato que permite o port para Windows.
- Nada depende de `apps/nexo/`.
