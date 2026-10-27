# API D-Bus do logid (v0.3.5)

**Status:** vigente para a parte lida no código; caminhos de objeto **a confirmar no spike S2**
(ver [spikes.md](../spikes.md)).

O logid publica o serviço `pizza.pixl.LogiOps` no **barramento de sistema**. Desde a v0.3.5 (correção da
CVE-2024-45752) a política em `/usr/share/dbus-1/system.d/pizza.pixl.LogiOps.conf` só permite que
**root** converse com ele. O Nexo **não altera** essa política: quem fala com o logid é o `nexo-helper`,
que roda como root e expõe só operações seguras e autorizadas por polkit.

## Interfaces usadas pelo Nexo

Fonte: `DeviceManager.cpp`, `Device.cpp` e `features/*.cpp` no commit
[`628ab93`](https://github.com/PixlOne/logiops/tree/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid).

| Interface | Membro | Assinatura (entrada → saída) | Uso no Nexo |
|---|---|---|---|
| `pizza.pixl.LogiOps.Devices` | `Enumerate` | → `devices` (lista de objetos) | Descobrir dispositivos ativos |
| | sinais `DeviceAdded`, `DeviceRemoved` | `device` | Reaplicar perfil após reconexão |
| `pizza.pixl.LogiOps.Device` | propriedades `Name`, `ProductID`, `Active`, `DefaultProfile`, `ActiveProfile` | — | Identificar e mostrar estado |
| | `GetProfiles` | → `profiles` (lista de strings) | Validar antes de trocar |
| | `SetProfile` | `profile` → | Troca de perfil ao vivo ⚠ ver abaixo |
| | `RemoveProfile`, `ClearProfile` | `profile` → | **Não usados** (alteram só a memória do logid) |
| | sinal `StatusChanged` | `active` (bool) | Dormiu/acordou (inclui Easy-Switch) |
| `pizza.pixl.LogiOps.Buttons` | `Enumerate` | → `buttons` | Listar botões |
| `pizza.pixl.LogiOps.Button` | propriedades `ControlID`, `TaskID`, `Remappable`, `GestureSupport` | — | Capacidades reais de cada botão |
| `pizza.pixl.LogiOps.DPI` | `GetSensors`, `GetDPIs(sensor)` → `dpis, dpiStep, range`, `GetDPI(sensor)`, `SetDPI(dpi, sensor)` | | Faixa e passo de DPI |
| `pizza.pixl.LogiOps.SmartShift` | `GetConfig` → `active, threshold, torque`; propriedade `TorqueSupport` | | Saber se `torque` é suportado |
| `pizza.pixl.LogiOps.HiresScroll` | `GetConfig` → `hires, invert, target` | | Diagnóstico |
| `pizza.pixl.LogiOps.ThumbWheel` | `GetConfig` → `divert, invert` | | Detectar presença de roda lateral |
| `pizza.pixl.LogiOps.Config` | `Save` | → | **Não usado** (ver abaixo) |

Árvore de objetos esperada (pelo código; confirmar no S2):

```
/…/devices/<apelido numérico>            Device, DPI, SmartShift, HiresScroll, ThumbWheel…
/…/devices/<apelido>/buttons/<índice>    Button
```

### Por que não usamos `SetProfile` diretamente sem checagem

`Device::setProfile` cria um perfil **vazio** quando o nome não existe e o ativa
([Device.cpp L240‑L250](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/Device.cpp#L240-L250)).
O helper sempre chama `GetProfiles` antes e recusa nomes desconhecidos.

### Por que não usamos `Config.Save`

`Save` reescreve o arquivo inteiro a partir da memória do logid (via libconfig `writeFile`), perde
comentários e grava os `type`/`mode` em minúsculas. A fonte da verdade do Nexo é o arquivo que ele
mesmo gera e valida — ver [ADR 0002](../01-arquitetura/adr/0002-aplicar-por-arquivo.md).

## Como inspecionar manualmente (exige sudo)

```bash
# serviço está no ar?
busctl --system list | grep -i logiops

# árvore de objetos
sudo busctl --system tree pizza.pixl.LogiOps

# interfaces/métodos de um objeto (troque o caminho pelo que o comando acima mostrar)
sudo busctl --system introspect pizza.pixl.LogiOps /pizza/pixl/logiops/devices/0

# exemplo: listar perfis e ver o ativo
sudo busctl --system call pizza.pixl.LogiOps /pizza/pixl/logiops/devices/0 \
     pizza.pixl.LogiOps.Device GetProfiles
sudo busctl --system get-property pizza.pixl.LogiOps /pizza/pixl/logiops/devices/0 \
     pizza.pixl.LogiOps.Device ActiveProfile

# acompanhar sinais (reconexões, troca de status)
sudo busctl --system monitor pizza.pixl.LogiOps
```

> Sem `sudo` estes comandos retornam `Access denied` — é o comportamento esperado.
