# Componentes

**Status:** planejado (design aprovado na Fase 0). Cada seção vira `vigente` quando o componente for
implementado; mantenha a tabela "Arquivos que toca" sempre exata — ela é a base de qualquer depuração.

Identificadores: ver [ADR-0005](adr/0005-nome-e-identificadores.md). Prefixo D-Bus abaixo:
`io.github.joao_ia.NexoHub` (abreviado como `…NexoHub`).

---

## `nexo` — interface (Flutter)

| Item | Valor |
|---|---|
| Fase | 2 (design), 4–5 (implementação) |
| Roda como | usuário, sob demanda (menu de aplicativos ou ícone na bandeja) |
| Processo | `/usr/lib/nexo/nexo` (bundle Flutter), atalho `/usr/bin/nexo` |
| Fala com | `nexo-agent` (D-Bus de sessão), `nexo-helper` (D-Bus de sistema), UPower/BlueZ (D-Bus de sistema, leitura) |
| Logs | `~/.local/state/nexo/nexo.log` (rotação 5 × 1 MB) |

**Responsabilidades:** mostrar dispositivos (home Bento), editar configurações (página Palco), validar em
tempo real, mostrar diff, pedir aplicação ao helper, listar/restaurar backups, tela de Diagnóstico.

**Não faz:** não grava em `/etc`, não fala com o logid diretamente, não guarda regras de perfil por app
(isso é do agent).

| Arquivos que toca | Modo |
|---|---|
| `/etc/logid.cfg` | leitura (o arquivo é `0644`) + observação de mudanças |
| `~/.config/nexo/settings.json` | leitura/escrita (preferências da UI) |
| `~/.local/state/nexo/nexo.log` | escrita |

---

## `nexo-agent` — processo de sessão (Dart AOT)

| Item | Valor |
|---|---|
| Fase | 6 |
| Roda como | usuário; serviço systemd de usuário `nexo-agent.service` (habilitado pelo autostart do app) |
| Barramento | publica `…NexoHub.Agent` no D-Bus de **sessão** |
| Fala com | `nexo-focus` (sinais), `nexo-helper` (`SetProfile`), UPower (bateria), `org.freedesktop.Notifications`, `org.kde.StatusNotifierWatcher` (bandeja) |
| Logs | `journalctl --user -u nexo-agent` |

**Responsabilidades:** ícone na bandeja (SNI + DBusMenu) com bateria e atalhos; notificação de bateria
baixa; motor de regras "app → perfil" com debounce de ~150 ms; reaplicar o perfil correto quando o logid
reinicia, o mouse reconecta ou volta de outro computador (Easy-Switch).

| Arquivos que toca | Modo |
|---|---|
| `~/.config/nexo/rules.json` | leitura (regras app → perfil, por dispositivo) |
| `~/.config/systemd/user/nexo-agent.service` | instalado pelo `.deb` em `/usr/lib/systemd/user/` |

---

## `nexo-helper` — serviço privilegiado (Dart AOT)

| Item | Valor |
|---|---|
| Fase | 3 |
| Roda como | **root**, ativado sob demanda pelo D-Bus/systemd (`nexo-helper.service`, `Type=dbus`) |
| Barramento | publica `…NexoHub.Helper` no D-Bus de **sistema** |
| Autorização | polkit, uma ação por grupo de métodos — ver [ADR-0003](adr/0003-helper-dbus-polkit-cache-por-sessao.md) |
| Fala com | polkit, logind (sessões), systemd (`RestartUnit`), journald, logid (D-Bus como root) |
| Logs | `journalctl -u nexo-helper` |

**Métodos (contrato completo em `packages/nexohub_ipc/dbus/` a partir da Fase 3):**

| Método | Ação polkit | O que faz |
|---|---|---|
| `ApplyConfig(text, expectedSha256)` | apply-config | Valida, faz backup, grava atomicamente, reinicia o logid, verifica e faz rollback se falhar |
| `ListBackups()` | read | Lista backups com data e hash |
| `RestoreBackup(id)` | apply-config | Restaura um backup pelo mesmo fluxo do `ApplyConfig` |
| `GetServiceStatus()` | read | Estado do logid e trechos recentes do journal |
| `ProbeDevices()` | read | Lê do logid (D-Bus root) botões, DPI, torque, perfis, perfil ativo |
| `SetProfile(device, profile)` | switch-profile | Confere `GetProfiles` e troca o perfil ao vivo |
| `InstallReconnectRule(pids)` | apply-config | Cria/atualiza a regra udev de reconexão |
| sinais `LogidRestarted`, `DeviceStatusChanged` | — | Repassa eventos do logid para o agent |

| Arquivos que toca | Modo |
|---|---|
| `/etc/logid.cfg` | escrita atômica (temp no mesmo diretório + `fsync` + `rename`), dono root, `0644` |
| `/var/lib/nexo/backups/` | escrita (20 últimos + `original-*.cfg` que nunca é apagado) |
| `/etc/udev/rules.d/99-nexo-logid-reconnect.rules` | escrita (só via `InstallReconnectRule`) |

**Proteções:** caminhos e comandos fixos no código; nenhum shell; payload ≤ 256 KB; revalidação com o
mesmo validador da UI; comparação de hash para detectar edição externa entre leitura e gravação.

---

## `nexo-focus` — extensão GNOME Shell (JavaScript ESM)

| Item | Valor |
|---|---|
| Fase | 6 |
| Roda como | dentro do processo `gnome-shell` |
| UUID | `nexo-focus@joao-ia.github.io` |
| Barramento | publica `…NexoHub.Focus` no D-Bus de sessão; sinal `FocusChanged(appId, wmClass)` e método `GetFocused()` |
| Logs | `journalctl --user -b /usr/bin/gnome-shell \| grep nexo-focus` |

**Por que existe:** no Wayland nenhum aplicativo pode descobrir qual janela está em foco; apenas o
GNOME Shell sabe. A extensão publica **somente** o identificador do app (`.desktop`) e a classe da
janela — nunca título ou conteúdo.

**Atenção:** extensão recém-instalada só carrega após logout/login no Wayland.

---

## `logid` — daemon do logiops (externo)

Não faz parte do Nexo, mas é a peça que efetivamente configura o mouse. Referência completa:
[02-logiops/referencia-logid-0.3.5.md](../02-logiops/referencia-logid-0.3.5.md).

| Item | Valor |
|---|---|
| Pacote | `logiops` (apt), versão testada 0.3.5 |
| Serviço | `logid.service` (root) |
| Config | `/etc/logid.cfg` |
| Logs | `journalctl -u logid` |

---

## Garantia de config válida (defesa em camadas)

1. **Modelo tipado** (`sealed class` espelhando os `std::variant` do logid): estados inválidos não podem
   ser construídos.
2. **Serializer canônico:** emite só um subconjunto conservador de libconfig; preserva chaves
   desconhecidas; grava cabeçalho "gerenciado pelo Nexo".
3. **Parser completo:** aceita toda a gramática libconfig para importar configs escritas à mão.
4. **Validador semântico:** tipos, faixas, CIDs que existem/são remapeáveis no aparelho, nomes de tecla
   libevdev válidos, `interval` em `OnInterval`, perfis referenciados existentes, DPI dentro da faixa.
5. **Testes diferenciais:** toda saída do serializer é lida pelo libconfig++ real (o mesmo do logid).
6. **Rollback em produção:** se mesmo assim o logid não subir, o arquivo anterior volta sozinho.
