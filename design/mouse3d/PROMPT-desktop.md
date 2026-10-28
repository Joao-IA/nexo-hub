# Prompt — modelo 3D realista do MX Master 3S para o Nexo (Claude Code no Windows 11)

> **Como usar:** abra o Claude Code no desktop (Windows 11, RTX 4060 8 GB, 32 GB de RAM), numa pasta onde
> você queira o repositório, e cole este arquivo inteiro como primeira mensagem. Tudo o que está aqui foi
> escrito e testado no Blender 5.2.3 do notebook; os scripts de Windows foram verificados com o PowerShell
> e o instalador baixou e conferiu o zip oficial de verdade.

---

## 0. Sua missão

Você vai transformar o **modelo 3D provisório** do mouse Logitech **MX Master 3S (cor Grafite)** que já existe
no repositório `nexo-hub` num modelo **o mais fiel e realista possível**, usando as fotos que o dono do mouse
vai tirar, e depois gerar os arquivos finais (renders, máscaras e pontos clicáveis) que o app **Nexo** (Flutter)
mostra no "palco" do dispositivo.

Você **não** começa do zero: o pipeline completo já funciona (cena, materiais, luzes, câmeras, máscaras,
`hotspots.json`, comparação de silhueta com as fotos e verificações automáticas). Seu trabalho é **refinar a
forma, os detalhes e a aparência** até passar em todos os critérios de aceite (G0–G5, seção 13), sempre
mostrando o resultado ao dono e pedindo a aprovação dele.

Fale com o dono em **português do Brasil**.

## 1. Regras inegociáveis

1. **Modelo original.** Nada de logotipos, textos, marcas ("logi", "MX"…), arquivos CAD, texturas, renders ou
   imagens oficiais da Logitech. Não decalque imagens oficiais. As fotos do dono servem **só de referência** e
   **nunca** são publicadas (a pasta `design/mouse3d/reference/` está no `.gitignore`). Se a foto mostrar
   logotipo, o modelo fica **liso** naquele lugar.
2. **Tudo por código.** Toda mudança vai em `design/mouse3d/` (`nexo3d/params.py`, `nexo3d/model.py`,
   `nexo3d/materials.py`, …) e é gerada pelo `build.py`. Nunca edite um `.blend` à mão e não automatize a
   interface gráfica do Blender. O `.blend` (opção `--save-blend`) é só para inspeção.
3. **O contrato de saída não muda** (o app Flutter depende dele): nomes e tamanhos dos arquivos, os ids e CIDs
   de `params.PARTS`, o formato do `hotspots.json` e a câmera do app (vista 3/4 da lateral **esquerda**, com a
   **frente do mouse à esquerda** da imagem). Ajustes pequenos de enquadramento são aceitáveis; qualquer
   mudança maior, pergunte ao dono antes.
4. **Decisões do dono que você mantém:** cor Grafite; **as duas rodas (principal e lateral) prateadas**, mesmo
   que a foto mostre outro tom; estilo "foto de produto" realista; fundo transparente com sombra de contato nas
   imagens do app.
5. **Blender exatamente 5.2.3 LTS** (o `check-env` recusa outra versão).
6. **Git:** trabalhe no branch `feat/mouse-3d`. **Commit e push só quando o dono pedir.** Nunca faça commit de
   `reference/`, `out/` ou `.blend`.
7. Só mexa fora de `design/mouse3d/` se o dono pedir.

## 2. O que já existe (leia antes de mudar qualquer coisa)

Leia `design/mouse3d/README.md` e os módulos de `design/mouse3d/nexo3d/`. Resumo:

| Arquivo | Papel |
|---|---|
| `build.py` | Ponto de entrada. Tarefas: `check-env`, `selftest`, `checks`, `preview`, `fit`, `final`, `export` |
| `run.ps1` / `run.sh` | Chamam o `build.py` com o Blender fixado (use sempre um deles) |
| `install-blender.ps1` | Instala o Blender 5.2.3 portátil no Windows conferindo o SHA-256 |
| `nexo3d/params.py` | **Todos os números**: medidas, seções da carcaça, posição e tamanho das peças, cores, materiais, luzes, câmeras, qualidade, metas |
| `nexo3d/model.py` | Carcaça (loft de seções com 14 pontos de controle semânticos + subdivisão, reescalada para 124,9 × 84,3 × 51 mm) e peças (booleanos exatos com folga real de 0,45 mm) |
| `nexo3d/geometry.py` | Construtores de malha, booleanos, bevel, suavização, ray casts |
| `nexo3d/materials.py` | Plástico soft-touch grafite com microtextura, aço usinado anisotrópico, interior escuro das folgas, LED |
| `nexo3d/lights.py` | Estúdio claro e escuro, ambiente em degradê, shadow catcher, ciclorama da cena de capa |
| `nexo3d/cameras.py` | Câmeras com enquadramento automático, vistas ortográficas, raio por pixel |
| `nexo3d/export.py` | Renders, máscaras por peça, `hotspots.json`, imagem de conferência, métricas de exposição |
| `nexo3d/fit.py` | Silhueta das fotos × do modelo: IoU e imagem de diferenças |
| `nexo3d/checks.py` | Dimensões, malhas fechadas, peças que se atravessam |
| `nexo3d/selftest.py` | Testes unitários que rodam dentro do Blender |

Coordenadas: milímetros no `params.py`, metros na cena (escala real). **+X = frente do mouse, +Y = lado
esquerdo (polegar), +Z = para cima**, origem no centro da base. Azimute da câmera medido de +X para +Y.

Peças interativas (não renomeie): `left_button` 0x50, `right_button` 0x51, `wheel` 0x52, `back` 0x53,
`forward` 0x56, `gesture` 0xc3, `smartshift` 0xc4, `thumbwheel`. Peças só de aparência: `body`, `base`, `led`.

O modelo atual é **provisório**: proporções estimadas, sem calibração. Ele passa em G0, G1 e G5, mas não foi
comparado com fotos (G2), não teve aprovação visual (G3) e a exposição (G4) foi ajustada só para ele.

## 3. Preparar o Windows

Rode tudo **a partir da raiz do repositório**.

1. **Clonar e criar o branch**
   ```powershell
   git clone https://github.com/Joao-IA/nexo-hub.git
   cd nexo-hub
   git switch -c feat/mouse-3d
   ```
   Confira se `design/mouse3d/build.py` existe. Se não existir, **pare** e peça ao dono para dar push do
   notebook.
2. **Instalar o Blender 5.2.3** (portátil, sem administrador, ~370 MB, confere o SHA-256 oficial
   `723f08a4…c2fb` antes de extrair para `%LOCALAPPDATA%\Programs\blender-5.2.3-windows-x64\`):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File design\mouse3d\install-blender.ps1
   ```
   `-ExecutionPolicy Bypass` vale só para essa execução; não mude a política do sistema.
3. **Como rodar as tarefas** (os dois atalhos repassam o `--` corretamente para o Blender):
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File design\mouse3d\run.ps1 <tarefa> [opções]
   ```
   ```bash
   design/mouse3d/run.sh <tarefa> [opções]        # no Git Bash
   ```
   Se o Blender estiver em outro lugar, defina a variável `NEXO_BLENDER` com o caminho do `blender.exe`.
   Uma tarefa que falha termina com código 1 e uma linha `[nexo3d] FALHOU: …`. **Nas seções seguintes,
   `... run.ps1 <tarefa>` abrevia o comando de PowerShell acima** (no Git Bash, use `design/mouse3d/run.sh <tarefa>`).
4. **GPU:** rode `nvidia-smi`. O `check-env` precisa mostrar `dispositivo de render: OPTIX ['NVIDIA GeForce RTX 4060…']`.
   Se mostrar `CPU`, peça ao dono para atualizar o driver NVIDIA (Game Ready ou Studio recente), reinicie o
   terminal e rode de novo. **Não faça o export final na CPU.**

## 4. Portão G0 e primeira olhada

```powershell
... run.ps1 check-env
... run.ps1 selftest
... run.ps1 checks
... run.ps1 preview
```
Os dois primeiros têm de terminar com `check-env OK` e `selftest OK (20 testes)`; o `checks`, com `checks OK`.
O `preview` grava `design/mouse3d/out/preview/app-side-light.png`, `app-side-dark.png`, `hero-light.png` e
`hero-dark.png`. **Abra as imagens** (você consegue ler PNG) e mostre ao dono como ponto de partida.

## 5. Fotos de referência (peça ao dono e confira cada uma)

Passe este guia ao dono:

- Mouse sobre **papel branco fosco** (A3 ou duas A4), com outra folha em pé atrás como fundo.
- **Luz difusa** (perto de uma janela, sem sol direto e sem flash). Evite sombras fortes.
- Celular na **lente 2× ou 3×**, a **60–100 cm** do mouse, câmera **perpendicular** à face fotografada e na
  altura certa (para as laterais, a frente e a traseira, a lente fica na altura do meio do mouse, ~2,5 cm).
  Isso reduz a perspectiva, que distorce a silhueta.
- Formato **JPG** (no iPhone: Ajustes › Câmera › Formatos › "Mais compatível"). Não use a câmera frontal
  (ela espelha a imagem).
- Fotos (o nome do arquivo importa):

| Arquivo | Vista |
|---|---|
| `top.jpg` | de cima, mouse inteiro |
| `left.jpg` | lado esquerdo (polegar) |
| `right.jpg` | lado direito |
| `front.jpg` | frente (ponta dos botões) |
| `rear.jpg` | traseira |
| `bottom.jpg` | base (opcional) |
| `three-quarter.jpg` | vista 3/4 do lado esquerdo e da frente, ~30° acima: o mesmo ângulo do app |
| `closeup-wheel.jpg`, `closeup-smartshift.jpg`, `closeup-thumbwheel.jpg`, `closeup-side-buttons.jpg`, `closeup-gesture.jpg`, `closeup-front.jpg` | detalhes, **com uma régua em milímetros** encostada |

As fotos vão em `design/mouse3d/reference/`. Para cada foto, **abra e confira**: mouse inteiro no quadro,
fundo branco, foco nítido, sem objeto escuro encostado no mouse. As vistas `top/left/right/front/rear` **não
precisam de régua** (a escala vem das medidas oficiais); se houver uma no quadro, ela tem de estar a ≥ 3 cm do
mouse. Se alguma estiver ruim, explique o motivo e peça outra. Fotos giradas em 90° não
têm problema (o `fit` testa as quatro rotações); espelhadas, sim.

## 6. Calibrar a forma (G2): o trabalho principal

### 6.1 O ciclo

```powershell
... run.ps1 fit
```
Para cada vista com foto, o `fit` mostra o IoU (interseção ÷ união das silhuetas normalizadas pela caixa
oficial) e grava `out/fit/diff-<vista>.png`: **vermelho = só na foto (o modelo precisa crescer ali), azul = só
no modelo (precisa encolher), branco = os dois**. Metas: **top ≥ 0,96; left/right ≥ 0,95; front/rear ≥ 0,94**.

Ciclo: abra os diffs → identifique a região → mude **no máximo 3 parâmetros** → rode `fit` → compare. Registre
cada iteração em `design/mouse3d/out/fit/journal.md` (parâmetros alterados, IoU antes e depois). Ordem
recomendada: **top** (largura e contorno), depois **left/right** (perfil da crista), depois **front/rear**
(inclinação lateral e apoio do polegar). Rode `checks` a cada mudança relevante: o G1 tem de continuar verde.

### 6.2 Como a carcaça é descrita

`params.SECTIONS` tem seções-chave ao longo do comprimento (`s` = 0 traseira … 1 frente), interpoladas por uma
cúbica monótona (sem oscilação). Cada seção é gerada por `model.section_points()` com **14 pontos semânticos**:

| Ponto | Significado | Controlado por |
|---|---|---|
| 0 | centro da base | — |
| 1–2 | base e alargamento do lado direito | `wr` |
| 3–5 | flanco direito e ombro direito | `wr`, `zt`, `yc` |
| 6 | crista (ponto mais alto da seção) | `zt`, `yc` |
| 7–8 | ombro esquerdo e beiral sobre o polegar | `wl`, `zt` |
| 9 | canal do polegar (côncavo) | `ch`, `zw`, `wl` |
| 10–11 | topo e borda do apoio do polegar | `wing`, `zw` |
| 12–13 | base do lado esquerdo | `wl`, `wing` |

Efeito de cada parâmetro: **top** ← `wr`, `wl`, `wing`; **laterais** ← `zt` (perfil da crista), `zw`;
**frente/traseira** ← `yc` (inclinação), `ch`, `zw`, `wing`. `END_DOME_MM` arredonda as pontas; `STATIONS`,
`SAMPLES_PER_SEGMENT` e `SUBSURF_LEVELS` controlam a resolução.

A carcaça é **sempre reescalada** para 124,9 × 84,3 × 51 mm, então os valores das seções definem só a forma. Se
os 14 pontos não bastarem (por exemplo, a ponta dos botões projetada para a frente), acrescente **seções-chave**
onde a curvatura muda ou **pontos semânticos** novos. Todas as seções precisam ter o **mesmo número de pontos,
na mesma ordem**. Atualize a tabela da seção "Shell sections" do `README.md` e a docstring de
`section_points`.

Não persiga ruído: as bordas das fotos têm um pouco de perspectiva. Se o IoU travar perto da meta e o diff
mostrar só uma franja fina e uniforme, isso é a foto, não o modelo.

## 7. Detalhes do MX Master 3S

Confira **cada item nas fotos e nos closes com régua**; **quando a foto e este texto divergirem, a foto vence**.
Os valores atuais estão em `params.py`.

- **Roda principal** (`WHEEL`): roda de metal no canal entre os botões, com borda de estrias finas e paralelas
  ao eixo. Meça no `closeup-wheel.jpg` o diâmetro, a largura, quanto sobressai e a posição em X. A geometria das
  estrias é real (`ribs`, `rib_depth`).
- **Botão SmartShift** (`SMARTSHIFT`): botão pequeno logo atrás da roda, no mesmo canal.
- **Botões esquerdo e direito e emendas** (`TOP_BUTTONS`): posição da emenda traseira (`palm_seam_x`, curva
  `palm_seam_curve`), altura das emendas nas laterais (`seam_left`, `seam_right`, da emenda traseira até a
  frente) e largura do canal (`channel_half`).
- **Roda lateral** (`THUMBWHEEL`): acima de Voltar/Avançar, embutida na lateral, só a borda aparece. Meça
  diâmetro, largura, posição, inclinação e quanto sobressai.
- **Voltar e Avançar** (`SIDE_BUTTONS`): lado a lado abaixo da roda lateral, Avançar na frente e Voltar atrás.
  Meça comprimento, altura, espaçamento e altura em Z.
- **Botão de gestos** (`GESTURE`): a parte da frente do apoio do polegar. Reproduza o contorno que a foto mostra.
- **Apoio do polegar**: a "asa" larga na base esquerda (parâmetros `wing` e `zw` das seções).
- **Base** (`BASE_SLAB_MM`, `BASE_RING_MM`): placa escura de baixo e a emenda dela. A emenda é um sulco ao
  longo do contorno que termina contra o corpo (nunca uma fresta que atravessa o mouse).
- **USB-C** (`USB`): na frente, embaixo do canal da roda.
- **LED** (`LED`): se o mouse do dono **não** tiver LED visível nessa região, remova-o (`_mechanical_parts` e o
  bolso `pocket_led` em `model.py`). Ele não é peça interativa.
- **Texturas:** se as fotos mostrarem áreas com acabamento diferente (por exemplo, a região do polegar),
  crie um material próprio em `materials.py` (bump sutil, em metros) e aplique só ali.
- Arestas: tudo que é moldado tem raio (bevel). Nada de quinas vivas; isso é o que mais denuncia um render "de
  computador".

## 8. Aparência (G3 e G4)

- Materiais em `params.MATERIALS` e `params.COLORS` (cores em sRGB hex; o código converte para linear).
  Plástico soft-touch: rugosidade ~0,45–0,55, sheen baixo, microtextura de ~0,15 mm. Aço: metálico,
  rugosidade ~0,2, anisotrópico com tangente radial (as rodas são construídas no eixo Z local, não mude isso).
- Luzes em `params.THEMES`: potências **físicas e pequenas** (watts em escala real). Regra prática: E ≈ P/(π·d²);
  o grafite (albedo ≈ 0,04) aparece com ≈ 0,04·E/π. Não use exposure acima de ±0,5 para compensar luz errada.
  O tema escuro tem recorte (rim) mais forte para o mouse se separar do fundo escuro.
- Metal precisa de algo claro para refletir: o ambiente é `glossy_boost` vezes mais forte **só para raios de
  reflexo** (nó Light Path › Is Glossy Ray em `lights._world`). É isso que deixa as rodas prateadas sem
  clarear o plástico. Se as rodas ficarem cinza-chumbo, suba o `glossy_boost`, não a luz principal.
- Revisão de aparência:
  ```powershell
  ... run.ps1 final --views app
  ```
  Abra `out/final/app-side-light.png` e `app-side-dark.png` e a `reference/three-quarter.jpg`. Mostre ao dono,
  lado a lado, e **peça aprovação explícita (G3)**. Ajuste e repita até ele aprovar.
- O G4 é medido no `export`: média sRGB da carcaça entre **0,18 e 0,30** no tema claro e **< 0,5%** de pixels
  estourados.

## 9. Exportar (G5) e conferir

```powershell
... run.ps1 export
```
O `export` usa a qualidade final (768 amostras, máscaras com 32) e grava em
`design/mouse3d/export/mx-master-3s/`: `app-side-light.png`, `app-side-dark.png` (2048×1280),
`1x/app-side-*.png` (1024×640), `masks/<peça>.png` (8), `hotspots.json`, `hero-light.png` e `hero-dark.png`
(3840×2160). No fim, o log mostra `portões: G1=ok, G5=ok, G4=ok` e `export OK`.

Confira você mesmo:
1. `out/export/hotspots-overlay.png`: cada peça com a caixa e o ponto em ciano. O ponto tem de cair **em cima
   da peça certa**.
2. As 8 máscaras: cada uma deve mostrar só a parte **visível** da peça.
3. `hotspots.json`: 8 peças, âncoras dentro das caixas.
4. As cenas de capa (`hero-*.png`): bonitas o bastante para o README e o portfólio. Mostre ao dono.

## 10. Entregar

Mostre ao dono:
- a tabela final de IoU;
- os portões;
- as imagens finais;
- o diário de iterações.

Quando ele pedir o commit, use só `design/mouse3d/` (código e `export/`), com uma mensagem no padrão
Conventional Commits, por exemplo:

```
feat(mouse3d): detailed MX Master 3S model calibrated to reference photos
```

Depois faça o push do branch `feat/mouse-3d`, **só quando ele pedir**. Pelo notebook, o merge e a integração no
app Flutter são feitos depois.

## 11. Armadilhas verificadas no Blender 5.2.3 (não erre nestes pontos)

- Motor `CYCLES`. O antigo `BLENDER_EEVEE_NEXT` **não existe** mais; o EEVEE agora é `BLENDER_EEVEE`.
- Booleano: `solver` aceita `EXACT`, `MANIFOLD` e `FLOAT` (**`FAST` não existe**); `material_mode` aceita
  `INDEX` e `TRANSFER`. Os cortadores levam o material `interior`, e as faces cortadas herdam esse material
  (`TRANSFER`).
- `Mesh.use_auto_smooth` **não existe**. Use `geometry.shade()` (bmesh: faces lisas, arestas vivas acima de um
  ângulo) ou `bpy.ops.object.shade_smooth_by_angle`.
- Nó Mix: as entradas têm nomes repetidos. Acesse pelo **identificador** (`Factor_Float`, `A_Color`, `B_Color`,
  saída `Result_Color`), como em `lights._socket`.
- Principled BSDF: `Base Color`, `Metallic`, `Roughness`, `Specular IOR Level`, `Anisotropic`,
  `Anisotropic Rotation`, `Tangent`, `Coat Weight`, `Sheen Weight`, `Sheen Roughness`, `Emission Color`,
  `Emission Strength`. As cores das entradas são **lineares** (`units.hex_rgba` converte de sRGB).
- Depois de mover a câmera ou um objeto, chame `scene.update()` (`view_layer.update()`). Sem isso, o
  `world_to_camera_view` e os ray casts usam a posição **antiga** e devolvem coordenadas erradas **sem erro**.
- `world_to_camera_view` tem a origem **embaixo** à esquerda; o `hotspots.json` usa o **topo**: `v = 1 − y`.
  `Camera.view_frame()` já inclui o deslocamento de lente (shift).
- O denoiser `OPTIX` só aparece com driver NVIDIA. O pipeline usa `OPENIMAGEDENOISE` com
  `denoising_use_gpu = True`, que funciona na RTX e na CPU.
- Os dispositivos de GPU só aparecem depois de `refresh_devices()`. `get_devices_for_type()` pode incluir a
  CPU na lista; filtre por `device.type` (como `scene.setup_device` faz).
- Material novo já vem com árvore de nós e um Principled BSDF; não é preciso mexer em `use_nodes`.
- `Scene.ray_cast` devolve o objeto **original** (compare pelo nome).
- Rode o Blender com `--python-exit-code 1`, senão um erro de Python termina com código 0. Os atalhos
  `run.ps1`/`run.sh` já fazem isso e passam o caminho **absoluto** do `build.py`.
- PowerShell: o `--` vai entre aspas (`'--'`) para chegar ao Blender. O `run.ps1` já faz isso. Arquivos `.ps1`
  ficam só em ASCII (o Windows PowerShell 5.1 lê arquivos sem BOM como ANSI).

## 12. Se algo der errado

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `check-env` mostra `CPU` | driver NVIDIA antigo ou ausente | dono atualiza o driver; reabrir o terminal |
| `FALHOU: Blender (x, y, z)` | versão errada | usar o `install-blender.ps1` ou definir `NEXO_BLENDER` |
| `G1 interpenetração: {'body × X': n}` | peça mecânica encostando no corpo | aumentar a folga (`clearance`) ou o bolso daquela peça em `model._make_pockets` |
| `G1 arestas não-manifold` | cortador aberto ou booleano degenerado | cortadores precisam ser sólidos fechados; evitar faces coincidentes (folga ≥ 0,3 mm); não desloque a carcaça ao longo das normais (dobra nas pontas) |
| Linha clara atravessando o mouse num render ou foto sintética | folga que atravessa o mouse de um lado ao outro | toda folga precisa terminar contra o corpo maciço (por isso a base é um anel, `BASE_RING_MM`) |
| `G1 dimensões … FORA` | peça saindo da carcaça (roda, botão) | conferir `protrude`; a carcaça sozinha é sempre reescalada |
| `G5 …: ray through the anchor hits 'Y'` | o ponto da peça está escondido atrás de outra | conferir posição da peça; em último caso, ajustar levemente `CAMERAS["app"]` (avisar o dono) |
| `G5 …: not visible` | peça fora do quadro ou totalmente oculta | idem |
| `G4` fora da faixa | luz forte ou fraca demais | ajustar `THEMES`, não o exposure |
| IoU não sobe | foto com perspectiva, sombra ou objeto encostado | conferir `out/fit/model-<vista>.png` e o diff; pedir nova foto |
| `fit`: "no photo" | nome do arquivo | `reference/top.jpg`, `left.jpg`, `right.jpg`, `front.jpg`, `rear.jpg` |

## 13. Critérios de aceite

- **G0 ambiente:** `Blender 5.2.3 LTS`; `check-env` com OptiX na RTX 4060; `selftest` OK.
- **G1 geometria:** 124,9 × 84,3 × 51,0 mm (±0,3); nenhuma aresta não-manifold; nenhuma peça atravessando outra.
- **G2 silhueta × fotos:** IoU ≥ 0,96 (top), ≥ 0,95 (left/right), ≥ 0,94 (front/rear).
- **G3 aparência:** aprovação explícita do dono, comparando com `three-quarter.jpg` e os closes.
- **G4 exposição:** média sRGB da carcaça entre 0,18 e 0,30 no tema claro; < 0,5% de pixels estourados.
- **G5 saída:** arquivos e tamanhos do contrato, 8 peças visíveis com âncora sobre a peça certa, JSON válido,
  sem logotipos.

Trabalhe em etapas, mostre cada resultado ao dono e não declare nada pronto sem os portões passando.
