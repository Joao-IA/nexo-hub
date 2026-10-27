# Checklist manual — MX Master 3S

**Status:** rascunho; finalizado na Fase 7. Executar antes de cada release, anotando data, versão do
Nexo, versão do logid e resultado de cada item.

## Preparação
- [ ] Anotar versões: `nexo --version`, `logid --version`, `gnome-shell --version`, `uname -r`.
- [ ] Backup manual de `/etc/logid.cfg`.

## Botões e gestos
- [ ] Cada botão remapeável executa a ação configurada (`0x52`, `0x53`, `0x56`, `0xc3`, `0xc4`).
- [ ] Botão de gestos: None, Up, Down, Left, Right disparam a ação certa.
- [ ] Modos `OnRelease`, `OnThreshold`, `OnInterval`, `Axis` se comportam como descrito na referência.
- [ ] Atalho com tecla Super capturado/selecionado corretamente.

## Rolagem e roda lateral
- [ ] SmartShift on/off, threshold e torque (se suportado) mudam o comportamento.
- [ ] Hires on/off; invert on/off.
- [ ] Thumbwheel left/right com `OnInterval`; invert.

## DPI
- [ ] DPI fixo aplicado; CycleDPI percorre a lista; ChangeDPI soma/subtrai.

## Perfis
- [ ] Troca por botão (`ChangeProfile`).
- [ ] Troca automática por app (ex.: VS Code ↔ navegador) sem pedir senha.
- [ ] Perfil reaplicado após: restart do logid, BT off/on, suspensão, Easy-Switch ida e volta.

## Easy-Switch
- [ ] `ChangeHost` next / prev / canal específico.

## Segurança e robustez
- [ ] Senha pedida só na primeira aplicação da sessão; após logout/login, pedida de novo.
- [ ] Config corrompida forçada → rollback automático, mouse continua configurado.
- [ ] Edição externa de `/etc/logid.cfg` com a UI aberta → conflito detectado.
- [ ] Reboot: configuração ativa após login.
- [ ] Desinstalar `.deb` deixa o sistema limpo; `/etc/logid.cfg` preservado.
