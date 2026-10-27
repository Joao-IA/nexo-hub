# Glossário

**Status:** vigente. Acrescente termos sempre que um novo conceito aparecer no projeto.

| Termo | Significado |
|---|---|
| **ADR** | *Architecture Decision Record*. Documento curto que registra uma decisão: contexto, decisão e consequências. Ficam em [`01-arquitetura/adr/`](01-arquitetura/adr/README.md). |
| **AOT** | *Ahead-of-time*. Compilação do Dart para um executável nativo (`dart compile exe`), sem precisar da VM Dart instalada. Usado no agent e no helper. |
| **AppIndicator / SNI** | *StatusNotifierItem*: protocolo D-Bus para ícones na bandeja. No Ubuntu, a extensão `ubuntu-appindicators` exibe esses ícones no painel do GNOME. |
| **Bento** | Estilo de layout em grade de cards de tamanhos variados (como uma marmita japonesa). Usado na tela inicial. |
| **BlueZ** | Pilha Bluetooth oficial do Linux; expõe dispositivos via D-Bus (`org.bluez`). |
| **CID** | *Control ID*. Número que o protocolo HID++ atribui a cada botão físico (ex.: `0xc3` = botão de gestos do MX Master 3S). É a chave dos botões no `logid.cfg`. |
| **Capacidade (capability)** | No Nexo, um recurso que um dispositivo oferece (botões remapeáveis, DPI, SmartShift, bateria, ANC…). A UI é montada a partir das capacidades. |
| **Adapter** | Módulo do Nexo que sabe falar com uma família de dispositivos (ex.: Logitech via logid). Traduz o dispositivo para capacidades. |
| **D-Bus** | Barramento de mensagens do Linux. Há o *barramento de sistema* (serviços root, ex.: logid, polkit) e o *de sessão* (apps do usuário). |
| **Easy-Switch** | Recurso dos periféricos Logitech para alternar entre até 3 computadores (canais/hosts). No logid é a ação `ChangeHost`. |
| **evdev** | Interface de eventos de entrada do kernel Linux. Teclas têm nomes como `KEY_LEFTCTRL`; é o que o logid usa nas ações `Keypress`. |
| **FVM** | *Flutter Version Management*. Fixa a versão do Flutter do projeto no arquivo `.fvmrc`. |
| **Gesto** | No logid, ação disparada ao segurar um botão e mover o mouse numa direção (Up/Down/Left/Right) ou sem mover (None). |
| **hidraw** | Dispositivo do kernel (`/dev/hidrawN`) que dá acesso cru a um dispositivo HID. O logid usa para falar HID++. Só root acessa por padrão. |
| **HID++** | Protocolo proprietário da Logitech sobre HID. A versão 2.0 é organizada em *features* (DPI, SmartShift, botões reprogramáveis…). |
| **Hires scroll** | Rolagem de alta resolução: a roda envia eventos mais finos que um "clique" de rolagem. |
| **libconfig** | Biblioteca e formato de arquivo de configuração usados pelo `logid.cfg`. |
| **libevdev** | Biblioteca que, entre outras coisas, converte nomes como `KEY_A` em códigos numéricos. O logid valida os nomes de tecla por ela. |
| **logid** | O daemon do projeto logiops. Roda como root, lê `/etc/logid.cfg` e configura os dispositivos. |
| **logind** | Componente do systemd que gerencia sessões de login. O helper usa para saber a qual sessão pertence quem chamou e quando ela termina. |
| **Palco** | Estilo da página de um dispositivo: ilustração grande no centro, com pontos clicáveis (*hotspots*). |
| **Perfil** | Conjunto completo de configurações de um dispositivo no logid (DPI, botões, gestos…). Um dispositivo pode ter vários; `default_profile` define o inicial. |
| **pkexec / polkit** | polkit decide se um usuário pode executar uma ação privilegiada (pedindo senha ou não). As ações ficam em arquivos `.policy`. |
| **PipeWire / WirePlumber** | Servidor de áudio do Linux moderno e seu gerenciador de sessão. Base da futura camada de áudio do hub. |
| **Rollback** | Voltar automaticamente ao arquivo anterior quando uma aplicação falha. |
| **SmartShift** | Recurso da roda do MX Master: alterna sozinha entre modo "catraca" e "livre" conforme a velocidade. `threshold` define a sensibilidade; `torque`, a força da catraca. |
| **Spike** | Experimento curto e descartável para responder uma dúvida técnica antes de construir. Ver [spikes.md](spikes.md). |
| **Thumbwheel** | Roda lateral (de polegar) do MX Master. |
| **uinput** | Interface do kernel para criar dispositivos de entrada virtuais. O logid a usa para "digitar" os atalhos das ações. |
| **UPower** | Serviço que informa bateria de dispositivos (inclusive mouses Bluetooth) via D-Bus, sem root. |
| **Wayland** | Protocolo gráfico moderno do Linux. Por segurança, apps não enxergam janelas de outros apps — por isso precisamos da extensão `nexo-focus`. |
| **Workspace (pub)** | Recurso do Dart para vários pacotes num repositório (monorepo) compartilharem dependências. |
