# Nova versão do GNOME

**Status:** a preencher na Fase 6 (quando a extensão `nexo-focus` existir).

Roteiro previsto:

1. `gnome-shell --version` na nova versão.
2. Ler o guia de portabilidade da versão em <https://gjs.guide/extensions/upgrading/>.
3. Testar a extensão numa sessão aninhada (`dbus-run-session gnome-shell --devkit`).
4. Adicionar a versão em `shell-version` do `metadata.json` somente após testar.
5. Atualizar esta página com o que mudou e o [troubleshooting](../04-operacao/troubleshooting.md).
