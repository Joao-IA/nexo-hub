# Logitech MX Master 3S

**Status:** parcialmente vigente. Itens marcados com **(S2)** serão confirmados no spike S2 (probe via
D-Bus do logid) e esta página será atualizada com os valores reais.

## Identificação no seu computador

| Item | Valor |
|---|---|
| Nome HID++ (usado em `name:`) | `MX Master 3S` |
| Conexão | Bluetooth (`HID_ID=0005:0000046D:0000B034`) |
| Vendor / Product ID | `046D` / `B034` |
| MAC | `D5:C1:47:E4:17:05` |
| Dispositivo hidraw | `/dev/hidraw2` (pode mudar entre boots) |
| Bateria | UPower `battery_hidpp_battery_2` (driver `hid_logitech_hidpp`) |

## Botões (CIDs)

Valores conhecidos pela comunidade para a família MX Master 3/3S — **(S2)** confirmar `Remappable` e
`GestureSupport` de cada um no seu aparelho.

| CID | Botão físico | Observação |
|---|---|---|
| `0x50` | Clique esquerdo | Normalmente não remapeável |
| `0x51` | Clique direito | Normalmente não remapeável |
| `0x52` | Clique do meio (roda) | |
| `0x53` | Voltar (polegar, trás) | |
| `0x56` | Avançar (polegar, frente) | |
| `0xc3` | Botão de gestos (base do polegar) | Suporta gestos — usado na sua config |
| `0xc4` | Botão atrás da roda (SmartShift / modo) | Usado na sua config (ToggleSmartShift) |
| `0xd7` | "Virtual gesture button" | Pode aparecer na enumeração **(S2)** |

## Recursos

| Recurso | Valor | Fonte |
|---|---|---|
| DPI | 200–8000, passo 50 (especificação do fabricante) | **(S2)** confirmar com `GetDPIs` |
| SmartShift | sim; torque **(S2)** (`TorqueSupport`) | |
| Hires scroll | sim | |
| Thumbwheel | sim (sem sensor de toque conhecido — `tap`/`touch` **(S2)**) | |
| Easy-Switch | 3 canais | |

## Sua configuração atual

Explicada linha a linha na [referência do logid §11](referencia-logid-0.3.5.md#11-exemplo-completo-comentado-a-sua-configuração-original).
