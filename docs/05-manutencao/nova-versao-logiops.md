# Nova versão do logiops

**Status:** vigente (checklist). Use quando o Ubuntu/upstream lançar um logiops diferente de 0.3.5.

O Nexo espelha o schema do logid em `nexohub_logid_config`. Uma versão nova pode adicionar/remover
opções ou mudar comportamentos — e o logid **descarta em silêncio** o que não entende.

## Checklist

1. **Versão e changelog**
   ```bash
   apt-cache policy logiops
   apt-get changelog logiops | head -40
   ```
   Leia também as *release notes* em <https://github.com/PixlOne/logiops/releases>.

2. **Diff do schema** (troque `NOVA` pela tag, ex. `v0.3.6`):
   ```bash
   curl -sL https://raw.githubusercontent.com/PixlOne/logiops/v0.3.5/src/logid/config/schema.h > /tmp/schema-old.h
   curl -sL https://raw.githubusercontent.com/PixlOne/logiops/NOVA/src/logid/config/schema.h   > /tmp/schema-new.h
   diff -u /tmp/schema-old.h /tmp/schema-new.h
   ```
   Repita para `config/types.h`, `config/group.h`, `Configuration.h` (valores padrão),
   `actions/*.cpp`, `actions/gesture/*.cpp`, `features/*.cpp` (validações e clamps).

3. **API D-Bus:** procure mudanças em `make_interface`, nomes de métodos e propriedades
   (`grep -rn "ipcgull::interface" src/logid`). Compare com
   [api-dbus-logid.md](../02-logiops/api-dbus-logid.md).

4. **Política D-Bus:** confira se `/usr/share/dbus-1/system.d/pizza.pixl.LogiOps.conf` mudou.

5. **Atualize o código:** modelo, parser, serializer e validador em `nexohub_logid_config`; novas ações
   no seletor da UI; novas capacidades no adapter.

6. **Atualize os testes:** novos casos no corpus diferencial; regenere goldens se a saída canônica mudar.

7. **Atualize a documentação:** crie `referencia-logid-<nova>.md` (copie a atual e ajuste os permalinks
   para o novo commit), atualize os links no [mapa](../README.md) e registre um ADR se houver decisão.

8. **Teste no hardware:** [checklist manual](../06-testes-manuais/mx-master-3s.md).

9. **Compatibilidade:** decida se o Nexo suporta as duas versões (detectando `logid --version`) ou só a
   nova; ajuste `Depends:` do `.deb`.
