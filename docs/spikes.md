# Spikes da Fase 0

**Status:** em andamento. Spikes são experimentos curtos para eliminar incertezas **antes** de construir.
O código dos spikes fica em `spikes/` e é descartável; o que importa é o **resultado** registrado aqui.

| ID | Pergunta | Por que importa | Resultado |
|---|---|---|---|
| S1 | A forma com `profiles`/`default_profile` + ação `ChangeProfile` funciona no logid 0.3.5 com o seu 3S? | Perfis múltiplos e por app dependem disso | pendente |
| S2 | O helper (root) consegue ler do D-Bus do logid: árvore de objetos, `GetProfiles`, `SetProfile`, `Buttons.Enumerate`, `GetDPIs`, `TorqueSupport`? | Probe de capacidades e troca de perfil ao vivo | pendente |
| S3 | A captura de teclas do Flutter no Wayland dá o código evdev correto (inclusive Super e teclas de mídia)? | Editor de atalhos | pendente |
| S4 | Uma extensão mínima no GNOME 50 consegue emitir o app em foco via D-Bus? | Perfis por aplicativo | pendente |
| S5 | Quanto tempo o logid leva para reiniciar e reaplicar? O que acontece no Easy-Switch (ida e volta)? `prev` no canal 1 funciona? `up`/`down` do scroll exigem `target: true`? | Health-check, timeouts, reaplicação de perfil, avisos na UI | pendente |

## Procedimentos

### S1 — Perfis no logid (exige sudo; não altera `/etc/logid.cfg`)

```bash
sudo systemctl stop logid
sudo logid -v -c spikes/s1/s1-profiles.cfg
# 1) Confirme no log "Device found: MX Master 3S" e o perfil ativo.
# 2) Aperte o botão atrás da roda (0xc4): deve alternar entre os perfis (DPI muda visivelmente).
# 3) Ctrl+C para encerrar.
sudo systemctl start logid
```

### S2 — D-Bus do logid como root

Com o logid rodando (serviço normal ou o processo do S1):

```bash
sudo busctl --system tree pizza.pixl.LogiOps
sudo busctl --system introspect pizza.pixl.LogiOps <caminho-do-dispositivo>
sudo busctl --system call pizza.pixl.LogiOps <caminho> pizza.pixl.LogiOps.Device GetProfiles
sudo busctl --system call pizza.pixl.LogiOps <caminho> pizza.pixl.LogiOps.DPI GetDPIs y 0
sudo busctl --system get-property pizza.pixl.LogiOps <caminho> pizza.pixl.LogiOps.SmartShift TorqueSupport
```

(Os comandos exatos serão ajustados com o resultado do `tree`.)

### S4 — Extensão de foco no GNOME 50 (sem sudo)

Código: [`spikes/s4/nexo-focus-spike@joao-ia.github.io/`](../spikes/s4/nexo-focus-spike@joao-ia.github.io/extension.js).
Instala só no seu usuário; desfaz com os dois últimos comandos.

```bash
mkdir -p ~/.local/share/gnome-shell/extensions
ln -s "$HOME/Documentos/VSCode/Git/logiOpsPlus/spikes/s4/nexo-focus-spike@joao-ia.github.io" \
      ~/.local/share/gnome-shell/extensions/
# No Wayland o Shell só enxerga extensões novas após sair e entrar na sessão (logout/login).
gnome-extensions enable nexo-focus-spike@joao-ia.github.io
gnome-extensions info nexo-focus-spike@joao-ia.github.io          # State: ACTIVE?

# Observe os sinais enquanto troca de janela (Alt+Tab):
gdbus monitor --session --dest io.github.joao_ia.NexoHub.Focus
# Consulta pontual:
gdbus call --session --dest io.github.joao_ia.NexoHub.Focus \
     --object-path /io/github/joao_ia/NexoHub/Focus \
     --method io.github.joao_ia.NexoHub.Focus.GetFocused

# Desfazer:
gnome-extensions disable nexo-focus-spike@joao-ia.github.io
rm ~/.local/share/gnome-shell/extensions/nexo-focus-spike@joao-ia.github.io
```

Esperado: a cada troca de janela, um `FocusChanged ('code.desktop', 'Code')` (ou equivalente).

### S5 — Tempo de reinício, Easy-Switch e scroll com `target` (exige sudo)

Configs: [`spikes/s5/`](../spikes/s5/). Nenhuma altera `/etc/logid.cfg`.

**S5.1 — Tempo de reinício** (com o serviço normal):

```bash
sudo systemctl restart logid
journalctl -u logid -n 4 -o short-precise --no-pager
# Diferença entre "Started logid.service" e "Device found" = tempo até o mouse estar configurado.
```

**S5.2 — ChangeHost e scroll com target ligado** (⚠ a roda passa a mudar o **volume**):

```bash
sudo systemctl stop logid
sudo logid -v -c spikes/s5/s5a-host-scroll-target-on.cfg
# a) Role a roda: o volume muda? (up/down disparam com target: true)
# b) Botão AVANÇAR (0x56, "next"): o mouse vai para o canal 2 (LED do canal pisca).
#    Volte ao canal 1 pelo botão Easy-Switch embaixo do mouse. Anote o que o log mostra na volta
#    (desconexão, "Device found"?).
# c) Estando no canal 1, botão VOLTAR (0x53, "prev"): nada acontece (bug previsto) ou vai p/ canal 3?
#    Se for para o canal 3, volte pelo botão Easy-Switch.
# Ctrl+C para encerrar.
```

**S5.3 — Scroll com target desligado:**

```bash
sudo logid -v -c spikes/s5/s5b-scroll-target-off.cfg
# Role a roda: rola normalmente (hipótese) ou muda o volume?
# Ctrl+C e depois:
sudo systemctl start logid
```

### S3 — Captura de teclas no Flutter/Wayland (sem sudo, exige dependências de build)

**Conceito-chave:** o logid emite **códigos físicos** evdev (`KEY_SEMICOLON` = a tecla na posição do
`;` de um teclado americano). O GNOME traduz pelo layout ativo — no seu **ABNT2**, essa mesma posição
é a tecla `Ç`. Portanto o Nexo deve **guardar o código físico** e **mostrar o rótulo do seu layout**.

No Flutter, cada `KeyEvent` traz `physicalKey.usbHidUsage` (posição física, independe do layout) e
`logicalKey.keyLabel` (o que o layout produz). O spike verifica se a conversão
USB-HID → evdev que vamos usar dá o código certo.

App mínimo: `spikes/s3/` (criado após instalar as dependências). Procedimento:

```bash
cd spikes/s3 && flutter run -d linux
```

Pressione e anote (código físico mostrado × esperado): letras, números, `Ç`, `´`, `~`, `/` (ABNT2),
`AltGr`, `Super`, `Ctrl`/`Shift`/`Alt` esquerdos e direitos, `F1`–`F12`, setas, `Print`, teclas de
mídia (volume, play/pause). Registre também quais teclas o GNOME **intercepta** (não chegam ao app).

## Registro de resultados

*(preencher: data, comando, saída relevante, conclusão, impacto no plano)*
