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

A documentação detalhada de projeto (arquitetura, registros de decisão, roteiros) é mantida de forma
privada pelo mantenedor e não faz parte deste repositório.

## Descobertas no logiops 0.3.5

Construir o Nexo exigiu testar a fundo como o logid trata a configuração: o próprio código de
decodificação do logid roda num teste diferencial contra o parser do Nexo, e cada comportamento
arriscado foi reproduzido em hardware real (MX Master 3S via Bluetooth). Os achados críticos:

| Configuração | O que acontece de verdade |
|---|---|
| `interval: 0` num gesto `OnInterval` | **o logid cai** (SIGFPE) no primeiro movimento |
| `dpi: []`, mais DPIs que sensores, ou o erro de digitação `dpi: 1600L;` | **o logid desiste do dispositivo** — nenhuma configuração é aplicada, só `Device timed out` no log |
| Qualquer ação `CycleDPI` | **Nunca muda o DPI** (bug conhecido, correção ainda não integrada) |
| Nome de eixo inválido num gesto `Axis` | Comportamento indefinido no aviso do logid (imprime memória aleatória) |

O validador do Nexo bloqueia todos esses casos. Relatório completo (em inglês), com passos para
reproduzir, causas e textos prontos para reportar ao projeto original:
[`reports/logiops-0.3.5-findings.md`](reports/logiops-0.3.5-findings.md).

## Roadmap

1. **v1.0** — Módulo Logitech no Linux (logiops).
2. **v1.1** — Camada genérica de Bluetooth/áudio no Linux (BlueZ, UPower, PipeWire).
3. **v2** — Adapter para Samsung Galaxy Buds.
4. **v3** — Port para Windows.
5. **v4+** — Adapters da comunidade (HeadsetControl, OpenRGB…).

## Licença

[GPL-3.0](LICENSE). O Nexo é um projeto independente, sem afiliação ou endosso da Logitech, Samsung ou
de qualquer outro fabricante. Todas as marcas pertencem aos seus respectivos donos.
