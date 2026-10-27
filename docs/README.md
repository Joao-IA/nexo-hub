# Documentação do Nexo

Este é o mapa da documentação. Procure pelo que você **quer fazer** e siga o link.

> Convenções: documentação em PT-BR; código e comentários `///` em inglês. Diagramas em
> [Mermaid](https://mermaid.js.org/) (o GitHub renderiza direto). Cada página informa seu **status**:
> `vigente` (descreve o que existe), `planejado` (descreve o design ainda não implementado) ou
> `a preencher` (esqueleto, será escrito na fase indicada).

## Quero entender o projeto

| Pergunta | Leia |
|---|---|
| O que é o Nexo e como as peças se encaixam? | [00-visao-geral.md](00-visao-geral.md) |
| O que cada componente faz, como roda e que arquivos toca? | [01-arquitetura/componentes.md](01-arquitetura/componentes.md) |
| Passo a passo do que acontece ao clicar em "Aplicar", trocar de app etc. | [01-arquitetura/fluxos.md](01-arquitetura/fluxos.md) |
| Para que serve cada pacote Dart? | [01-arquitetura/pacotes.md](01-arquitetura/pacotes.md) |
| Por que cada permissão existe e quais são os riscos? | [01-arquitetura/seguranca.md](01-arquitetura/seguranca.md) |
| Por que escolhemos X em vez de Y? | [01-arquitetura/adr/](01-arquitetura/adr/README.md) |
| O que significa HID++, CID, polkit, SNI…? | [glossario.md](glossario.md) |

## Quero entender o logiops (logid)

| Pergunta | Leia |
|---|---|
| Todas as opções do `logid.cfg`, valores padrão e armadilhas | [02-logiops/referencia-logid-0.3.5.md](02-logiops/referencia-logid-0.3.5.md) |
| Como conversar com o logid pelo D-Bus (e testar com `busctl`) | [02-logiops/api-dbus-logid.md](02-logiops/api-dbus-logid.md) |
| Botões (CIDs), DPI e particularidades do MX Master 3S | [02-logiops/mx-master-3s.md](02-logiops/mx-master-3s.md) |

## Quero desenvolver

| Tarefa | Leia |
|---|---|
| Preparar a máquina do zero | [03-desenvolvimento/ambiente.md](03-desenvolvimento/ambiente.md) |
| Rodar cada componente em modo desenvolvimento | [03-desenvolvimento/executar-em-dev.md](03-desenvolvimento/executar-em-dev.md) |
| Depurar (DevTools, D-Bus, journal, extensão GNOME) | [03-desenvolvimento/depuracao.md](03-desenvolvimento/depuracao.md) |
| Rodar e escrever testes | [03-desenvolvimento/testes.md](03-desenvolvimento/testes.md) |
| Padrões de código, commits e versões | [03-desenvolvimento/convencoes.md](03-desenvolvimento/convencoes.md) |
| Resultados dos experimentos da Fase 0 | [spikes.md](spikes.md) |

## Algo deu errado

| Situação | Leia |
|---|---|
| Onde estão os logs de cada parte? | [04-operacao/logs-e-diagnostico.md](04-operacao/logs-e-diagnostico.md) |
| Sintoma → causa → solução | [04-operacao/troubleshooting.md](04-operacao/troubleshooting.md) |
| Voltar a configuração do mouse manualmente / desinstalar limpo | [04-operacao/recuperacao.md](04-operacao/recuperacao.md) |

## Manutenção do dia a dia

| Tarefa | Leia |
|---|---|
| Adicionar suporte a um novo dispositivo | [05-manutencao/adicionar-dispositivo.md](05-manutencao/adicionar-dispositivo.md) |
| Saiu uma versão nova do logiops | [05-manutencao/nova-versao-logiops.md](05-manutencao/nova-versao-logiops.md) |
| Saiu uma versão nova do GNOME | [05-manutencao/nova-versao-gnome.md](05-manutencao/nova-versao-gnome.md) |
| Atualizar Flutter/Dart/dependências | [05-manutencao/atualizar-dependencias.md](05-manutencao/atualizar-dependencias.md) |
| Publicar uma versão | [05-manutencao/release.md](05-manutencao/release.md) |
| Testar no hardware antes de lançar | [06-testes-manuais/mx-master-3s.md](06-testes-manuais/mx-master-3s.md) |

## Regra de ouro

Toda mudança de código atualiza, **no mesmo commit/PR**, as páginas afetadas desta pasta, inclui uma
entrada no [troubleshooting](04-operacao/troubleshooting.md) para cada novo modo de falha e uma entrada
no [`CHANGELOG.md`](../CHANGELOG.md). Uma fase do projeto só é concluída com a documentação em dia.
