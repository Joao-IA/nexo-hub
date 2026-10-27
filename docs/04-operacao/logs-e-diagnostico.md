# Logs e diagnóstico

**Status:** vigente para o logid; planejado para os componentes do Nexo (atualizar quando cada um for
implementado).

## Onde cada parte registra

| Componente | Comando | Observações |
|---|---|---|
| `logid` | `journalctl -u logid -f` | Para nível debug: `sudo systemctl stop logid && sudo logid -v` (Ctrl+C e `sudo systemctl start logid` ao terminar) |
| `nexo-helper` | `journalctl -u nexo-helper -f` | Root; ativado sob demanda — pode não ter logs se nunca foi chamado |
| `nexo-agent` | `journalctl --user -u nexo-agent -f` | Serviço de usuário |
| `nexo` (UI) | `tail -f ~/.local/state/nexo/nexo.log` | Rotação: 5 arquivos de 1 MB |
| `nexo-focus` | `journalctl --user -f /usr/bin/gnome-shell \| grep nexo-focus` | Prefixo `[nexo-focus]` |
| polkit | `journalctl -u polkit -f` | Útil se a senha não for pedida/aceita |

## Nível de detalhe

Todos os componentes do Nexo aceitam `NEXO_LOG=debug` (variável de ambiente) ou `--verbose`.
Para serviços systemd:

```bash
sudo systemctl edit nexo-helper        # adicionar:  [Service]\nEnvironment=NEXO_LOG=debug
systemctl --user edit nexo-agent       # idem
```

## ID de correlação

Cada operação iniciada pela UI (ex.: "Aplicar") recebe um ID curto (ex.: `op=7f3a2c`) que é repassado
ao agent e ao helper e aparece em todas as linhas de log relacionadas:

```bash
journalctl -u nexo-helper -u logid --since "10 min ago" | grep 7f3a2c
grep 7f3a2c ~/.local/state/nexo/nexo.log
```

## Relatório de diagnóstico

Na UI: **Avançado → Diagnóstico → Exportar relatório**. Gera um `.txt` com versões (Nexo, logid,
GNOME, kernel), status dos serviços, estado da extensão, resultado do probe do dispositivo, perfil
ativo, config atual e as últimas linhas de log de cada componente. Revise antes de compartilhar.
