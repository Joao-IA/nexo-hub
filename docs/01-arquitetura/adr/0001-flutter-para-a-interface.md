# ADR-0001 — Flutter para a interface

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O objetivo é uma interface com identidade visual própria, inspirada no Logi Options+ (Windows/macOS), e
que no futuro rode também no Windows e no macOS como um hub de periféricos.

## Decisão
A interface (`nexo`) é escrita em **Flutter**. Os processos sem interface (`nexo-agent`, `nexo-helper`)
são escritos em **Dart** e compilados AOT, compartilhando pacotes com a UI.

## Alternativas consideradas
- **Python + GTK4/libadwaita:** dependências já instaladas e visual nativo do GNOME, mas pouca liberdade
  visual e sem caminho bom para Windows.
- **Rust + gtk4-rs/Relm4:** tipagem forte, mesma limitação visual/multiplataforma do GTK.
- **C++ + Qt6/QML:** multiplataforma, porém build mais complexo e menos produtivo.
- **Tauri (web):** liberdade visual, mas mais pesado e com cara de página web.

## Consequências
- ✅ Liberdade visual total e um único código de UI para Linux/Windows/macOS.
- ✅ Uma linguagem (Dart) para UI, agent, helper e lógica de configuração — o validador é o mesmo em
  todos.
- ⚠ No Linux o Flutter usa GTK3 por baixo; o app não terá aparência "libadwaita" (intencional).
- ⚠ O motor do Flutter consome ~100 MB de RAM: por isso a UI não fica residente (ver ADR-0004).
- ⚠ Integrações de sistema (D-Bus, polkit) dependem de pacotes Dart (`dbus`) e de código próprio.
