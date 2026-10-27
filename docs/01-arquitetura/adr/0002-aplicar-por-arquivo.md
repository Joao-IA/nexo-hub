# ADR-0002 — Aplicar configurações por arquivo + reinício seguro

- **Status:** Aceito
- **Data:** 2026-10-27

## Contexto
O logid 0.3.5 oferece duas formas de mudar a configuração:
1. Editar `/etc/logid.cfg` e reiniciar o serviço.
2. API D-Bus ao vivo (`pizza.pixl.LogiOps`), inclusive `Config.Save`.

A API D-Bus foi restrita a root na 0.3.5 por causa da **CVE-2024-45752** (na 0.3.4 qualquer usuário
local podia configurar macros de teclado pelo D-Bus). Abrir essa API para usuários comuns reabriria
parte do problema. Além disso, um erro de sintaxe no arquivo impede o logid de iniciar.

## Decisão
O arquivo `/etc/logid.cfg` é a **fonte da verdade**. Para aplicar, o `nexo-helper` (root):
valida → faz backup → grava de forma atômica → reinicia o `logid` → verifica a saúde → faz **rollback
automático** se algo falhar. A política D-Bus do logid **não é alterada**.

O D-Bus do logid é usado apenas pelo helper (como root) para operações pontuais e seguras: descobrir
capacidades (`ProbeDevices`) e trocar perfil (`SetProfile`, após validar o nome).

## Alternativas consideradas
- **D-Bus ao vivo para tudo:** mudanças instantâneas, mas exige afrouxar a política (CVE), a API 0.3.5 é
  pouco testada e `Config.Save` reescreve o arquivo perdendo formatação.
- **Começar por arquivo e adicionar D-Bus ao vivo depois:** mantido como evolução possível (pré-visualização
  ao vivo via helper), sem compromisso na v1.

## Consequências
- ✅ Segurança da correção da CVE preservada; comportamento idêntico a editar o arquivo à mão.
- ✅ Funciona com qualquer versão do logid que leia o mesmo formato.
- ⚠ Ao aplicar, o logid reinicia: o mouse fica < 1 s sem as personalizações.
- ⚠ Exige um gerador de arquivo perfeito — ver "Garantia de config válida" em
  [componentes.md](../componentes.md) e os testes diferenciais em [testes.md](../../03-desenvolvimento/testes.md).
