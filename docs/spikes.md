# Spikes da Fase 0

**Status:** em andamento. Spikes são experimentos curtos para eliminar incertezas **antes** de construir.
O código dos spikes fica em `spikes/` e é descartável; o que importa é o **resultado** registrado aqui.

| ID | Pergunta | Por que importa | Resultado |
|---|---|---|---|
| S1 | A forma com `profiles`/`default_profile` + ação `ChangeProfile` funciona no logid 0.3.5 com o seu 3S? | Perfis múltiplos e por app dependem disso | ✅ **confirmado** (27/10/2026) |
| S2 | O helper (root) consegue ler do D-Bus do logid: árvore de objetos, `GetProfiles`, `SetProfile`, `Buttons.Enumerate`, `GetDPIs`, `TorqueSupport`? | Probe de capacidades e troca de perfil ao vivo | ✅ **confirmado** (27/10/2026) — ver registro |
| S3 | A captura de teclas do Flutter no Wayland dá o código evdev correto (inclusive Super e teclas de mídia)? | Editor de atalhos | ✅ **confirmado** (27/10/2026) — mídia/Print não chegam ao app (esperado) |
| S4 | Uma extensão mínima no GNOME 50 consegue emitir o app em foco via D-Bus? | Perfis por aplicativo | pendente |
| S5 | Quanto tempo o logid leva para reiniciar e reaplicar? O que acontece no Easy-Switch (ida e volta)? `prev` no canal 1 funciona? `up`/`down` do scroll exigem `target: true`? | Health-check, timeouts, reaplicação de perfil, avisos na UI | ✅ **concluído** (27/10/2026) — com 1 problema em aberto (ChangeHost pouco confiável) |

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

# Descobre o caminho do dispositivo automaticamente (não use marcadores <...>: o zsh os
# interpreta como redirecionamento e aborta o bloco inteiro).
CAMINHO=$(sudo busctl --system tree --list pizza.pixl.LogiOps | grep -E '/devices/[^/]+$' | head -1); echo "CAMINHO=$CAMINHO"
sudo busctl --system introspect pizza.pixl.LogiOps "$CAMINHO"
sudo busctl --system call pizza.pixl.LogiOps "$CAMINHO" pizza.pixl.LogiOps.Device GetProfiles
sudo busctl --system get-property pizza.pixl.LogiOps "$CAMINHO" pizza.pixl.LogiOps.Device ActiveProfile
sudo busctl --system call pizza.pixl.LogiOps "$CAMINHO" pizza.pixl.LogiOps.Device SetProfile s "s1-test"
sudo busctl --system call pizza.pixl.LogiOps "$CAMINHO" pizza.pixl.LogiOps.DPI GetDPIs y 0
sudo busctl --system get-property pizza.pixl.LogiOps "$CAMINHO" pizza.pixl.LogiOps.SmartShift TorqueSupport
sudo busctl --system tree --list pizza.pixl.LogiOps | grep buttons
```

Esperado: depois do `SetProfile`, o ponteiro fica lento (400 DPI) na hora, sem reiniciar o logid.

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

### S1 — 27/10/2026 ✅

`sudo logid -v -c spikes/s1/s1-profiles.cfg` com o serviço parado.

- O logid aceitou a forma com `profiles` + `default_profile` e iniciou no perfil `default` (1600 DPI).
- O botão atrás da roda (`0xc4`, ação `ChangeProfile`) alternou entre `default` e `s1-test` (400 DPI)
  a cada aperto — observado pelo usuário.

**Impacto:** perfis múltiplos e troca por botão funcionam como planejado; nenhum fallback necessário.

### S3 — 27/10/2026 ✅

App [`spikes/s3/`](../spikes/s3/README.md) (Flutter 3.47.8, GNOME 50 Wayland, teclado ABNT2 do IdeaPad).
Mapa testado: a tabela do próprio Flutter `kLinuxToPhysicalKey` (XKB → tecla física, a mesma usada pelo
embedder GTK), invertida, com `evdev = XKB − 8`; nomes de `/usr/include/linux/input-event-codes.h`
(são os nomes que o libevdev/logid aceitam). O app registrou cada tecla num log lido automaticamente.

```
physical=Key A          evdev=30  KEY_A          label="A"
physical=Digit 1        evdev=2   KEY_1          label="1"
physical=Meta Left      evdev=125 KEY_LEFTMETA   label="Super"        ← Super chega ao app
physical=Semicolon      evdev=39  KEY_SEMICOLON  label="Ç" char="ç"   ← posição física ABNT2
physical=Bracket Left   evdev=26  KEY_LEFTBRACE  label="[" char=""    ← acento agudo (tecla morta)
physical=Alt Right      evdev=100 KEY_RIGHTALT   label="Alt Graph"
physical=Control Left   evdev=29  KEY_LEFTCTRL   …  Shift L/R 42/54, Alt 56
physical=F1/F5/F12      evdev=59/63/88
physical=Home/End/PgUp/PgDn evdev=102/107/104/109                     ← via Fn+setas
```

**Conclusões e impacto no plano:**

1. **22/22 teclas com código evdev correto**, inclusive `Super`, `AltGr` e as teclas ABNT2. A conversão
   usa a mesma tabela do embedder, então é correta por construção; o pacote `nexohub_input_keys`
   (Fase 1) será **gerado** a partir de `kLinuxToPhysicalKey` + `input-event-codes.h`, com testes
   cobrindo todas as teclas.
2. O Nexo grava o **código físico** e mostra o **rótulo do layout** (`logicalKey.keyLabel`). Exceção:
   teclas mortas (`´`, `~`) trazem o rótulo do layout americano (`[`) → a UI precisa de um rótulo
   alternativo para elas (Fase 5).
3. `Fn` não é uma tecla para o sistema (tratada pelo firmware). Teclas de **mídia** e **Print Screen**
   são capturadas pelo GNOME antes do app → o **seletor pesquisável** de teclas é obrigatório (já
   previsto). O logid as emite normalmente (S5 confirmou `KEY_VOLUMEUP`).
4. Não testadas na sessão (cobertas pelos testes da Fase 1): setas, Tab, Esc, Ctrl direito, `~`, `/`, `\`.

### S5 — 27/10/2026 ✅ (com problema em aberto)

Executado via `pkexec` com scripts equivalentes aos procedimentos acima. Na 2ª rodada, o serviço foi
mascarado em tempo de execução (`systemctl mask --runtime`) para a regra udev de reconexão não subir um
segundo logid durante o teste; as etapas avançaram por confirmação no chat (a 1ª tentativa dependia de
notificações na tela, que não apareceram para o usuário).

| Teste | Resultado |
|---|---|
| Tempo de reinício | `Started logid.service` → `Device found` em **~0,41 s** (0,51 s medidos a partir do comando `restart`) |
| Scroll com `target: true` + `up`/`down` | ✅ gestos disparam (a roda mudou o volume) |
| Scroll com `target: false` + `up`/`down` | ✅ gestos **não** disparam (a roda rola normalmente) |
| `ChangeHost "next"` (Avançar) | ⚠ funciona, mas exige **muitos** apertos |
| `ChangeHost "prev"` (Voltar) | ⚠ funciona, mas exige **2–3** apertos |
| Reconexão após voltar de outro canal | ✅ o próprio processo do logid redetectou o mouse (`disconnected` → `Device found`) 4 vezes, **sem** a regra udev |
| Erros no log | nenhum `WARN`/`ERROR` durante os testes |

Leitura do código (`ChangeHost::setHost`, [hidpp20/features/ChangeHost.cpp L41‑L56](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/backend/hidpp20/features/ChangeHost.cpp#L41-L56)):
`"prev"` no canal 1 calcula `-1`, que vira `255` em `uint8_t`, e `setHost` lança `InvalidArgument` —
nenhuma troca acontece. Como o "Voltar" funcionou e nenhum erro foi registrado, o PC do usuário
provavelmente **não** está no canal 1 (a confirmar).

**Conclusões e impacto no plano:**

1. Health-check do helper: timeout de 5 s é folgado (restart real ≈ 0,4 s). Manter 5 s.
2. Validador/UI: avisar que `up`/`down` do scroll só funcionam com `target: true` e que, com isso, a
   roda deixa de rolar normalmente (a menos que a ação seja de rolagem).
3. **Problema em aberto — ChangeHost pouco confiável via Bluetooth.** Hipótese principal: o desvio
   temporário (`TemporaryDiverted`) do botão se perde quando o mouse economiza energia, e os primeiros
   apertos chegam ao sistema como Voltar/Avançar comuns. Investigar antes da Fase 5 (capturar eventos
   com `libinput debug-events` + `logid -v` ao mesmo tempo). Até lá, a UI deve marcar as ações de
   Easy-Switch como **experimentais** e recomendar o botão físico.
4. A regra udev de reconexão não é necessária para trocas de canal — o logid redetecta sozinho. Ela
   continua útil para o caso de **boot** (`Failed to add device … after 5 tries`). Reavaliar o escopo do
   `InstallReconnectRule` na Fase 3.
5. Do log de inicialização: a thumbwheel do 3S suporta **toque, proximidade, toque simples (tap) e
   timestamp**; resolução nativa 18, desviada 120 → `tap`/`touch`/`proxy` podem ser oferecidos na UI.

### S2 — 27/10/2026 ✅

Executado com o logid de teste do S1 rodando, via `pkexec` de um script único (uma senha só) —
script equivalente aos comandos acima. Saída relevante:

```
tree:          /pizza/pixl/logiops/devices/0 , /pizza/pixl/logiops/devices/0/buttons/{0..7}
interfaces:    Buttons, DPI, Device, HiresScroll, SmartShift (TorqueSupport=false), ThumbWheel
GetProfiles:   as 2 "default" "s1-test"
ActiveProfile: s "default"
GetSensors:    y 1
GetDPIs(0):    aqqb 2 200 8000 50 true      → faixa 200–8000, passo 50
GetDPI(0):     q 1600
SmartShift:    yyy 2 20 0                   → on(2), threshold 20, torque 0
HiresScroll:   bbb false false false
ThumbWheel:    bb false false
botões (ControlID / Remappable / GestureSupport):
  0x50 (80)  false false   0x51 (81)  false false   0x52 (82)  true true
  0x53 (83)  true  true    0x56 (86)  true  true    0xc3 (195) true true
  0xc4 (196) true  true    0xd7 (215) true  true
SetProfile "s1-test"  → ponteiro ficou lento na hora (observado pelo usuário)
SetProfile "nao-existe" → GetProfiles: "default" "nao-existe" "s1-test"; ActiveProfile "nao-existe"
SetProfile "default"  → restaurado
```

**Conclusões e impacto no plano:**

1. Troca de perfil ao vivo via D-Bus funciona → perfis por aplicativo viáveis como planejado.
2. **Armadilha confirmada:** `SetProfile` com nome desconhecido cria e ativa um perfil vazio. O helper
   **deve** validar com `GetProfiles` antes (já previsto no ADR-0003).
3. O probe real dá tudo que a UI precisa (botões remapeáveis, suporte a gestos, faixa/passo de DPI,
   torque). O `device_db` fica só com o que o logid não informa (nomes amigáveis, ilustração).
4. MX Master 3S **não suporta torque** no logid 0.3.5 → UI esconde o controle.
5. **Todos os 6 botões remapeáveis aceitam gestos** (não só `0xc3`) → UI permite gestos em qualquer um.
6. `SmartShift.GetConfig` devolve a **config** (0 = ausente, 1 = off, 2 = on), não o estado do aparelho.
7. A política D-Bus só-root funciona como esperado: sem root, `Access denied`.
