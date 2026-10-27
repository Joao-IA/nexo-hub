# Nexo

> 🇺🇸 [Read in English](README.md)

**Nexo** é um hub de periféricos open source para Linux (Windows/macOS planejados). O primeiro módulo é
uma interface gráfica completa para o [logiops](https://github.com/PixlOne/logiops) (`logid`), para
configurar mouses Logitech como o **MX Master 3S** sem nunca editar o `/etc/logid.cfg` à mão.

> **Status:** desenvolvimento inicial — Fase 0 (fundação). Ainda não há nada utilizável.

## Objetivos (v1.0 — módulo Logitech)

- Ilustração interativa do dispositivo: clique num botão e escolha a ação.
- Botões, gestos, roda de rolagem, SmartShift, roda lateral (thumbwheel), DPI e ações de Easy-Switch.
- Múltiplos perfis, trocados por um botão do mouse ou **automaticamente conforme o aplicativo em foco**.
- Configuração gerada **sempre válida**: modelo tipado, validador rigoroso e testes diferenciais contra
  o parser `libconfig` real usado pelo `logid`.
- Aplicação segura: backup → escrita atômica → reinício do `logid` → verificação de saúde →
  **rollback automático**.
- Pede a senha **uma vez por sessão de login**; trocar de perfil nunca pede.
- Ícone na bandeja com bateria e aviso de bateria baixa.
- Português (Brasil) e inglês.

## Arquitetura em resumo

| Componente    | Tecnologia            | Roda como               | Papel                                        |
|---------------|-----------------------|-------------------------|----------------------------------------------|
| `nexo`        | Flutter               | usuário, sob demanda    | A interface                                  |
| `nexo-agent`  | Dart (AOT)            | usuário, no login       | Bandeja, notificações, perfis por aplicativo |
| `nexo-helper` | Dart (AOT)            | root, serviço D-Bus     | Operações privilegiadas, protegidas por polkit |
| `nexo-focus`  | Extensão GNOME Shell  | dentro do Shell         | Informa o app em foco (exigência do Wayland) |

A documentação completa está em [`docs/`](docs/README.md).

## Roadmap

1. **v1.0** — Módulo Logitech no Linux (logiops).
2. **v1.1** — Camada genérica de Bluetooth/áudio no Linux (BlueZ, UPower, PipeWire).
3. **v2** — Adapter para Samsung Galaxy Buds.
4. **v3** — Port para Windows.
5. **v4+** — Adapters da comunidade (HeadsetControl, OpenRGB…).

## Licença

[GPL-3.0](LICENSE). O Nexo é um projeto independente, sem afiliação ou endosso da Logitech, Samsung ou
de qualquer outro fabricante. Todas as marcas pertencem aos seus respectivos donos.
