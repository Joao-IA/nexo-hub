# ADR-0003 — Helper root como serviço D-Bus, polkit por método e senha por sessão

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
Gravar `/etc/logid.cfg` e reiniciar o `logid` exigem root. O usuário quer digitar a senha **uma vez e
ela valer até a sessão de login terminar**. Perfis por aplicativo trocam de perfil a cada mudança de
janela — isso **não pode** pedir senha.

O polkit, sozinho, só "lembra" uma autenticação por cerca de 5 minutos (`auth_admin_keep`), e a decisão
vale para a ação inteira, não por método.

## Decisão
`nexo-helper` é um **serviço D-Bus de sistema** (root), ativado sob demanda pelo systemd
(`Type=dbus`), com unit endurecida. Cada método exige uma **ação polkit própria**:

| Ação polkit | Métodos | Padrão |
|---|---|---|
| `…apply-config` | `ApplyConfig`, `RestoreBackup`, `InstallReconnectRule` | `auth_admin` + **cache por sessão** |
| `…switch-profile` | `SetProfile` | `allow_active: yes` (sem senha) |
| `…read` | `ProbeDevices`, `GetServiceStatus`, `ListBackups` | `allow_active: yes` |

**Cache por sessão:** após uma autenticação bem-sucedida, o helper descobre a sessão logind de quem
chamou (PID da conexão D-Bus → `GetSessionByPID`) e guarda `(uid, sessão)` como autorizados. O cache é
apagado quando o logind emite `SessionRemoved` (logout) ou quando o helper reinicia. Enquanto houver
sessões no cache, o helper não encerra por inatividade.

## Alternativas consideradas
- **`pkexec` + processo filho vivo enquanto o app roda:** mais simples, mas a autorização é "tudo ou
  nada" (não dá para liberar só `SetProfile` sem senha) e morre se a UI fechar.
- **`auth_admin_keep`:** só 5 minutos.
- **Regra polkit liberando tudo para o usuário ativo:** sem senha nenhuma, porém qualquer processo do
  usuário poderia reescrever o `logid.cfg` (macros de teclado) — exatamente o risco da CVE.

## Consequências
- ✅ Senha 1x por login; troca de perfil sem senha; menor privilégio por operação.
- ✅ Padrão "correto" do Linux, bom para portfólio.
- ⚠ Lógica de autorização própria (cache) é código sensível: exige testes e revisão de segurança
  (`/security-review`) — ver [seguranca.md](../seguranca.md).
- ⚠ Mais arquivos de sistema para instalar (política D-Bus, `.service` de ativação, unit systemd,
  `.policy` do polkit) — cobertos pelo pacote `.deb`.
