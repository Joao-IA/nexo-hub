# Logitech MX Master 3S

**Status:** vigente. Valores confirmados no aparelho do mantenedor em 27/10/2026 (spike S2,
logid 0.3.5 via D-Bus) — ver [spikes.md](../spikes.md#s2--27102026-).

## Identificação no seu computador

| Item | Valor |
|---|---|
| Nome HID++ (usado em `name:`) | `MX Master 3S` |
| Conexão | Bluetooth (`HID_ID=0005:0000046D:0000B034`) |
| Vendor / Product ID | `046D` / `B034` (D-Bus `ProductID` = 45108) |
| MAC | `D5:C1:47:E4:17:05` |
| Dispositivo hidraw | `/dev/hidraw2` (pode mudar entre boots) |
| Objeto D-Bus do logid | `/pizza/pixl/logiops/devices/0` (o número é um apelido e pode mudar) |
| Bateria | UPower `battery_hidpp_battery_2` (driver `hid_logitech_hidpp`) |

## Botões (CIDs) — confirmados

| CID | Decimal | Botão físico | Remapeável | Gestos |
|---|---|---|---|---|
| `0x50` | 80 | Clique esquerdo | ❌ | ❌ |
| `0x51` | 81 | Clique direito | ❌ | ❌ |
| `0x52` | 82 | Clique do meio (roda) | ✅ | ✅ |
| `0x53` | 83 | Voltar (polegar, trás) | ✅ | ✅ |
| `0x56` | 86 | Avançar (polegar, frente) | ✅ | ✅ |
| `0xc3` | 195 | Botão de gestos (base do polegar) | ✅ | ✅ |
| `0xc4` | 196 | Botão atrás da roda (SmartShift) | ✅ | ✅ |
| `0xd7` | 215 | "Virtual gesture button" | ✅ | ✅ |

> Todos os botões remapeáveis aceitam gestos, não só o `0xc3`. O `0xd7` não é um botão físico
> separado; o significado prático dele será investigado na Fase 5 antes de exibi-lo na UI.

## Recursos — confirmados

| Recurso | Valor |
|---|---|
| Sensores de DPI | 1 |
| DPI | 200–8000, passo 50 |
| SmartShift | sim; **torque não suportado** (`TorqueSupport=false`) |
| Hires scroll | sim (interface `HiresScroll` presente); `up`/`down` exigem `target: true` (S5) |
| Thumbwheel | sim; suporta **toque, proximidade, tap e timestamp**; resolução nativa 18, desviada 120 (log do logid, S5) |
| Easy-Switch | 3 canais; ação `ChangeHost` via Bluetooth exige vários apertos (S5) — experimental |
| Tempo de reinício do logid | ~0,4 s até `Device found` (S5) |
| Reconexão (troca de canal) | o logid redetecta sozinho, sem precisar de restart (S5) |

## Sua configuração atual

Explicada linha a linha na [referência do logid §11](referencia-logid-0.3.5.md#11-exemplo-completo-comentado-a-sua-configuração-original).
