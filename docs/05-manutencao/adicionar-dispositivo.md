# Adicionar um dispositivo

**Status:** a preencher na Fase 4 (quando `device_db/` e o probe existirem).

Roteiro previsto:

1. Conectar o dispositivo e confirmar que o logid o detecta (`journalctl -u logid` → `Device found: <nome>`).
2. Rodar o probe (UI → Diagnóstico → "Probe", ou `ProbeDevices` via `busctl`) para obter CIDs,
   `Remappable`, `GestureSupport`, faixa/passo de DPI e suporte a torque.
3. Criar `device_db/<fabricante>-<modelo>.json` seguindo o JSON Schema (`device_db/schema.json`):
   nome HID++, PIDs (USB/Bluetooth/receptor), nomes amigáveis dos botões (PT-BR/EN), recursos.
4. Criar a ilustração SVG **original** (nunca renders oficiais) e mapear os *hotspots* de cada botão.
5. Rodar `dart test device_db` (valida schema e consistência com o probe salvo em `test/fixtures`).
6. Testar no hardware e registrar o dispositivo como "testado" ou "experimental".
