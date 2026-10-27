# Segurança

**Status:** planejado. Revisar e atualizar ao fim da Fase 3 (helper) e da Fase 6 (agent/extensão),
incluindo o resultado do `/security-review`.

## O que estamos protegendo

1. **Integridade da entrada do teclado/mouse.** O `logid.cfg` define ações `Keypress`: quem controla o
   arquivo pode fazer um botão "digitar" qualquer sequência de teclas. Foi exatamente isso que motivou a
   **CVE-2024-45752** (logiops ≤ 0.3.4: qualquer usuário local podia configurar macros pelo D-Bus).
2. **O sistema (root).** O `nexo-helper` roda como root; um bug nele pode virar escalada de privilégio.
3. **Privacidade.** A extensão vê qual app está em foco.

## Ameaças e mitigações

| Ameaça | Mitigação |
|---|---|
| Processo malicioso do usuário reescreve `logid.cfg` | `ApplyConfig` exige polkit `auth_admin` (senha) na primeira vez por sessão; política D-Bus do logid continua só-root |
| Processo de **outra** sessão/usuário usa a autorização em cache | Cache é por `(uid, sessão logind)`; sessões remotas/inativas não herdam |
| Abuso de `SetProfile` sem senha | Só troca entre perfis **já existentes** (definidos com senha); nomes desconhecidos são recusados |
| Escrita em caminho arbitrário / injeção de comando | Caminhos e comandos fixos no código; nenhum shell; nenhum argumento vira caminho |
| Payload gigante / malformado | Limite de 256 KB; parser com limites de profundidade; validação completa antes de gravar |
| Corrida entre leitura e gravação (edição externa) | `expectedSha256` comparado antes de gravar |
| Arquivo corrompido por queda de energia | temp + `fsync` + `rename` atômico; backup prévio |
| Config inválida derruba o logid | Validação + rollback automático |
| Extensão vaza dados de janelas | Publica só `appId`/`wmClass`; nunca título ou conteúdo |
| Unit do helper com privilégio demais | Unit systemd endurecida (`NoNewPrivileges`, `ProtectHome`, `PrivateTmp`, `RestrictAddressFamilies=AF_UNIX`, `SystemCallFilter=@system-service`…) — detalhes na Fase 3 |

## Ações polkit

| Ação | Padrão (sessão ativa) | Métodos |
|---|---|---|
| `io.github.joao_ia.NexoHub.apply-config` | `auth_admin` (+ cache por sessão no helper) | `ApplyConfig`, `RestoreBackup`, `InstallReconnectRule` |
| `io.github.joao_ia.NexoHub.switch-profile` | `yes` | `SetProfile` |
| `io.github.joao_ia.NexoHub.read` | `yes` | `ProbeDevices`, `GetServiceStatus`, `ListBackups` |

Sessões inativas ou remotas (`allow_any`, `allow_inactive`): `no` em todas.
