# Troubleshooting

**Status:** vigente para itens do logid; itens do Nexo entram conforme cada componente é implementado.
**Regra:** todo novo modo de falha descoberto (em teste ou uso) ganha uma entrada aqui no mesmo PR.

Formato de cada entrada: **Sintoma → Causa provável → Como confirmar → Solução**.

## logid / mouse

### O mouse perdeu todas as personalizações
- **Causa provável:** o logid não está rodando (erro de sintaxe na config) ou não detectou o mouse.
- **Confirmar:** `systemctl status logid` e `journalctl -u logid -n 30`.
- **Solução:** [recuperacao.md §1–§2](recuperacao.md).

### `Parse error in /etc/logid.cfg, line N`
- **Causa:** sintaxe libconfig inválida (aspas, `;`, chaves/parênteses desbalanceados).
- **Confirmar:** abrir a linha N do arquivo.
- **Solução:** restaurar backup ([recuperacao.md §2](recuperacao.md)). Com o Nexo, isso é feito sozinho
  pelo rollback.

### Um botão/gesto específico não faz nada, sem erro no log
- **Causa provável:** elemento inválido dentro de uma lista é **descartado em silêncio** pelo logid
  (ver [referência §1](../02-logiops/referencia-logid-0.3.5.md#1-como-o-logid-lê-o-arquivo)); ou `OnInterval`
  sem `interval`; ou gesto num botão sem suporte.
- **Confirmar:** `sudo systemctl stop logid && sudo logid -v` (modo debug) e apertar o botão.
- **Solução:** corrigir o elemento. No Nexo, o validador impede isso.

### `Failed to add device /dev/hidrawN after 5 tries` no boot
- **Causa:** o logid inicia antes da conexão Bluetooth estabilizar.
- **Confirmar:** aparece logo após o boot e depois surge `Device found`.
- **Solução:** inofensivo se a regra udev de reconexão existir ([recuperacao.md §4](recuperacao.md)).

### Configuração some ao voltar de outro computador (Easy-Switch)
- **Causa:** ao reconectar, o logid reaplica o `default_profile`.
- **Confirmar:** `journalctl -u logid` mostra `Device found` na volta.
- **Solução:** com perfis por aplicativo, o `nexo-agent` reaplica o perfil certo. Sem o agent, o perfil
  padrão é o esperado.

## Nexo

*(Entradas serão adicionadas a partir da Fase 3. Itens já previstos:)*

- Senha pedida de novo na mesma sessão → cache do helper perdido (helper reiniciou?) — `journalctl -u nexo-helper`.
- Perfil por aplicativo não troca → extensão desativada / não carregada após instalação (requer
  logout/login) — `gnome-extensions info nexo-focus@joao-ia.github.io`.
- Ícone da bandeja não aparece → extensão `ubuntu-appindicators` desativada — `gnome-extensions list --enabled`.
- "Conflito: arquivo alterado fora do Nexo" → alguém editou `/etc/logid.cfg` depois que a UI o leu.
