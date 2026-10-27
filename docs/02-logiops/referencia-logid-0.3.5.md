# Referência do `logid.cfg` — logiops v0.3.5

**Status:** vigente. Fonte da verdade: código do logiops na tag `v0.3.5`
(commit [`628ab93`](https://github.com/PixlOne/logiops/tree/628ab937a25724c1f21e7edf25c8e5aaff82c691)).
Todos os links abaixo apontam para esse commit — se o logiops for atualizado, siga
[05-manutencao/nova-versao-logiops.md](../05-manutencao/nova-versao-logiops.md).

O Nexo espelha estas regras no pacote `nexohub_logid_config` (modelo + validador). Quando mudar algo
aqui, mude lá também (e vice-versa).

[schema]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/config/schema.h
[types]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/config/types.h
[confcpp]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/Configuration.cpp
[confh]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/Configuration.h
[device]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/Device.cpp
[smartshift]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/features/SmartShift.cpp
[hires]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/features/HiresScroll.cpp
[changehost]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/ChangeHostAction.cpp
[interval]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/gesture/IntervalGesture.cpp

## 1. Como o logid lê o arquivo

- Caminho padrão: `/etc/logid.cfg`; outro arquivo com `logid -c <arquivo>`.
- Formato: [libconfig](https://hyperrealm.github.io/libconfig/libconfig_manual.html). `=` e `:` são
  equivalentes; `;` e `,` finais são opcionais; comentários `#`, `//` e `/* */`; inteiros decimais ou
  hexadecimais (`0xc3`); strings entre aspas duplas.
- ⚠ **Erro de sintaxe ⇒ o logid não inicia.** O construtor de `Configuration` relança a
  `ParseException` ([Configuration.cpp L33‑L42][confcpp]). Com o serviço parado, o mouse volta ao
  comportamento de fábrica.
- ⚠ **Erro de tipo em campo opcional ⇒ campo ignorado com log de erro** (`config_io<std::optional<T>>`,
  [types.h ~L392‑L406][types]). Ex.: `dpi: "1600"` (string) é descartado.
- ⚠ **Elemento inválido dentro de lista ⇒ descartado em silêncio** (`config_io<std::list<T>>`,
  [types.h ~L250‑L262][types]). Ex.: um gesto com `mode` desconhecido simplesmente desaparece, sem log.
  É por isso que o validador do Nexo é estrito: o logid não avisa.
- Uniões (`std::variant`) são resolvidas tentando cada alternativa na ordem declarada até uma funcionar.
- Os valores de `type` (ações) e `mode` (gestos) **não diferenciam maiúsculas/minúsculas**
  (`normalize_signature` em `config/group.h`); `direction` também não (`less_caseless`).
- Se o arquivo não existe, o logid roda com configuração vazia.

## 2. Estrutura de topo ([schema.h L320][schema])

```
devices: ( <dispositivo>, ... );   # lista de dispositivos (por nome)
ignore: [ 0xc52b, ... ];           # PIDs a ignorar
io_timeout: 500.0;                 # ms, padrão 500 (Configuration.h L31)
workers: 4;                        # threads de trabalho, padrão 4 (Configuration.h L32)
```

## 3. Dispositivo: forma plana × forma com perfis

Cada item de `devices` tem obrigatoriamente `name` (o nome HID++ exato do aparelho, ex. `"MX Master 3S"`)
e pode estar em duas formas ([schema.h L309‑L330][schema]):

**Forma plana** (a sua config atual): as opções do perfil ficam direto no dispositivo.

```
devices: ({ name: "MX Master 3S"; dpi: 1600; smartshift: { on: true; }; });
```

**Forma com perfis:**

```
devices: ({
    name: "MX Master 3S";
    default_profile: "default";
    profiles: (
        { name: "default"; dpi: 1600; },
        { name: "jogos";   dpi: 3200; }
    );
});
```

Como o logid normaliza ([Device.cpp L340‑L366][device]):

- Forma plana ⇒ vira **um perfil chamado `"default"`** com `default_profile = "default"`.
  Por isso o Nexo usa o nome interno `default` para o perfil importado (exibido como "Padrão").
- Forma com perfis sem nenhum perfil ⇒ cria `"default"` vazio.
- Ao conectar, ativa `default_profile`; se esse nome não existir, **cria um perfil vazio com esse nome**
  ([Device.cpp L146‑L149][device]).

## 4. Perfil ([schema.h L295][schema])

| Chave | Tipo | Observações |
|---|---|---|
| `dpi` | inteiro **ou** lista de inteiros | Lista = um valor por sensor (raro). Faixa e passo dependem do aparelho (consulte via D-Bus `GetDPIs`). |
| `smartshift` | grupo | `on` (bool), `threshold` (1‑255), `torque` (1‑100, só aparelhos com suporte). Valores fora da faixa são **ajustados** pelo logid: `threshold 0→1`, `torque 0→1`, `torque >100→100` ([SmartShift.cpp L40‑L54][smartshift]). |
| `hiresscroll` | bool **ou** grupo | Ver seção 7. |
| `thumbwheel` | grupo | Ver seção 8. |
| `buttons` | lista de `{ cid: <int>; action = <ação>; }` | `cid` em hex é o costume. Ver seção 5. |

## 5. Ações ([schema.h L60‑L240][schema])

Toda ação é um grupo com `type`. Os tipos e campos:

| `type` | Campos | Comportamento |
|---|---|---|
| `"None"` | — | Botão não faz nada. |
| `"Keypress"` | `keys`: string, inteiro ou lista misturando ambos | Nomes **libevdev** (`"KEY_LEFTCTRL"`, `"KEY_C"`, `"BTN_LEFT"`…). Pressiona na ordem e solta ao soltar o botão. |
| `"ToggleSmartShift"` | — | Alterna SmartShift. |
| `"ToggleHiresScroll"` | — | Alterna rolagem de alta resolução. |
| `"CycleDPI"` | `dpis`: lista de inteiros; `sensor` opcional | Avança para o próximo DPI da lista. |
| `"ChangeDPI"` | `inc`: inteiro (pode ser negativo); `sensor` opcional | Soma `inc` ao DPI atual. |
| `"ChangeHost"` | `host`: inteiro **1‑based** ou `"next"`/`"prev"`/`"previous"` (sem diferenciar maiúsculas) | Easy-Switch. Executa **ao soltar** o botão. Número vira `host - 1` e é tomado módulo o total de canais ([ChangeHostAction.cpp L84‑L107][changehost]). ⚠ Provável bug: `"prev"` estando no canal 1 calcula `-1 % N` (negativo em C++) — a confirmar no spike S5. |
| `"ChangeProfile"` | `profile`: string | Troca o perfil ativo. ⚠ Nome inexistente cria perfil **vazio** (ver seção 10). |
| `"Gestures"` | `gestures`: lista de `{ direction; mode; ... }` | Só em botões com suporte a gestos. Ver seção 6. |

`Gestures` só é aceito em `buttons`; dentro de um gesto, thumbwheel ou scroll só valem as ações
"básicas" (todas exceto `Gestures`).

## 6. Gestos ([schema.h L144‑L228][schema])

Cada gesto tem `direction` — `"Up"`, `"Down"`, `"Left"`, `"Right"` ou `"None"` (sem diferenciar
maiúsculas; `"None"` = apertar e soltar sem mover) — e `mode`:

| `mode` | Campos | Quando dispara |
|---|---|---|
| `"NoPress"` | `threshold` | Nunca (desativa a direção). |
| `"OnRelease"` | `threshold`, `action` | Ao soltar o botão, se o movimento passou do limiar. |
| `"OnThreshold"` | `threshold`, `action` | Assim que o movimento passa do limiar. |
| `"OnInterval"` | `threshold`, `action`, **`interval` (obrigatório)** | A cada `interval` unidades de movimento após o limiar. Sem `interval` não faz nada ([IntervalGesture.cpp `move()`][interval]). |
| `"OnFewPixels"` | igual a `OnInterval` | Variante de `OnInterval`. |
| `"Axis"` | `threshold`, `axis` (ex. `"REL_WHEEL"`, `"REL_HWHEEL"`), `axis_multiplier` (float) | Converte o movimento em eixo de rolagem. |

- `threshold` padrão: **50** ([Configuration.h L33][confh]).
- Na thumbwheel e no scroll (`left`/`right`/`up`/`down`) o "gesto" usa o mesmo esquema; o usual é
  `OnInterval` com `interval` pequeno (a sua config usa `interval: 3`).

## 7. `hiresscroll` ([HiresScroll.cpp `_makeConfig`][hires])

- Forma booleana `hiresscroll: true;` ⇒ altera **só** o modo hires; `invert`/`target` não são tocados.
- Forma de grupo: `hires`, `invert`, `target` (bool, cada um só é aplicado se presente) e `up`/`down`
  (gestos).
- `target: true` desvia os eventos da roda para o logid. Pelo código, `up`/`down` só recebem eventos com
  `target: true` — a confirmar no spike S5.

## 8. `thumbwheel` ([schema.h L276‑L293][schema])

| Chave | Tipo | Observação |
|---|---|---|
| `divert` | bool | Necessário para o logid receber os eventos da roda lateral (e as ações abaixo funcionarem). |
| `invert` | bool | Inverte o sentido. |
| `left`, `right` | gesto | Rotação para cada lado (normalmente `OnInterval`). |
| `tap` | ação básica | Toque na roda (aparelhos com sensor de toque). |
| `touch` | ação básica | Ao encostar o dedo. |
| `proxy` | ação básica | Proximidade do dedo. |

## 9. Valores padrão ([Configuration.h L30‑L34][confh])

| Item | Padrão |
|---|---|
| `io_timeout` | 500 ms |
| `workers` | 4 |
| `threshold` de gesto | 50 |

## 10. Armadilhas conhecidas (e como o Nexo se protege)

| Armadilha | Consequência | Proteção no Nexo |
|---|---|---|
| Erro de sintaxe | logid não inicia | Serializer canônico + validação + teste diferencial com libconfig++ + rollback automático |
| Elemento inválido em lista | Some em silêncio | Validador estrito (erro bloqueante) |
| `SetProfile`/`ChangeProfile` com nome inexistente | Cria perfil vazio e o ativa (mouse "perde" a config) ([Device.cpp L240‑L250][device]) | Helper confere `GetProfiles` antes; validador exige que `ChangeProfile` aponte para perfil existente |
| `default_profile` inexistente | Perfil vazio ativado no boot | Validador |
| Perfil ativo após restart/reconexão | Volta a `default_profile` | Agent reaplica o perfil da regra atual |
| `OnInterval` sem `interval` | Gesto nunca dispara | Validador exige |
| `prev` no canal 1 (ChangeHost) | Provavelmente não faz nada | A confirmar (S5); UI avisa |
| Gestos em botão sem suporte | Ação ignorada | Validador usa capacidades reais (`GestureSupport`) |

## 11. Exemplo completo comentado (a sua configuração original)

Arquivo: [`fixtures/logid/user-original-2026-10-27.cfg`](../../fixtures/logid/user-original-2026-10-27.cfg).

```
devices: (
{
    name: "MX Master 3S";                       # nome HID++ exato
    smartshift: { on: true; threshold: 20; };   # catraca solta com pouca velocidade
    hiresscroll: { hires: false; invert: false; target: false; };
    dpi: 1600;

    thumbwheel: {
        divert: true;                           # logid recebe a roda lateral
        invert: true;
        left:  { mode: "OnInterval"; interval: 3;
                 action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_LEFTSHIFT", "KEY_TAB"]; }; };  # aba anterior
        right: { mode: "OnInterval"; interval: 3;
                 action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_TAB"]; }; };                   # próxima aba
    };

    buttons: (
        { cid: 0xc3;                            # botão de gestos (polegar)
          action = { type: "Gestures"; gestures: (
              { direction: "None";  mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTMETA"]; }; },               # Visão geral
              { direction: "Up";    mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTMETA", "KEY_S"]; }; },      # Configurações rápidas
              { direction: "Down";  mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_C"]; }; },      # Copiar
              { direction: "Left";  mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_V"]; }; },      # Colar
              { direction: "Right"; mode: "OnRelease"; action = { type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_LEFTALT", "KEY_RIGHT"]; }; }  # Próximo workspace
          ); }; },
        { cid: 0xc4; action = { type: "ToggleSmartshift"; }; }   # botão atrás da roda
    );
}
);
```

> Observação: o arquivo original escreve `"ToggleSmartshift"` (com "s" minúsculo) e funciona, porque o
> logid converte para minúsculas tanto o valor lido quanto o esperado antes de comparar `type`/`mode`
> (`normalize_signature`, [group.h L144‑L196][group]). O Nexo aceita qualquer grafia ao importar, mas
> sempre grava a grafia canônica `"ToggleSmartShift"` do [schema.h L78‑L83][schema].

[group]: https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/config/group.h
