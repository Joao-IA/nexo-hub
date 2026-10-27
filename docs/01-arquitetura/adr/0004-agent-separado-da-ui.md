# ADR-0004 — Agent leve separado da UI Flutter

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
A v1 precisa de ícone na bandeja com bateria, notificações de bateria baixa e **perfis por aplicativo**
— tudo funcionando durante a sessão inteira, mesmo com a janela fechada. Manter o Flutter aberto e
escondido custaria ~100 MB de RAM o tempo todo.

## Decisão
Criar o `nexo-agent`: executável Dart AOT (~15 MB de RAM) que inicia com o login (serviço systemd de
usuário) e é responsável por:
- ícone na bandeja implementando **StatusNotifierItem + DBusMenu** diretamente via D-Bus (sem GTK);
- notificações (`org.freedesktop.Notifications`);
- motor de regras "aplicativo → perfil" (ouve a extensão `nexo-focus`, chama `helper.SetProfile`);
- API no barramento de sessão para a UI.

A UI Flutter é aberta sob demanda (pelo menu do app ou pelo ícone na bandeja) e fecha de verdade.

## Alternativas consideradas
- **Flutter residente com `tray_manager`:** menos código, mas consumo alto de memória e perfis por app
  dependeriam da janela/engine estar viva.
- **Agent em Python/C:** leve, mas quebraria a regra de "uma linguagem" e duplicaria lógica.

## Consequências
- ✅ Baixo consumo em segundo plano; perfis por app independem da UI.
- ✅ No Windows, o mesmo papel será cumprido por um agent equivalente (bandeja Win32).
- ⚠ Implementar SNI/DBusMenu à mão (especificações públicas e estáveis) — coberto por testes.
- ⚠ Mais um processo para monitorar: logs em `journalctl --user -u nexo-agent`.
