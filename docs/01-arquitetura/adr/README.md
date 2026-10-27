# Registros de Decisão de Arquitetura (ADRs)

Cada ADR registra **uma** decisão importante: o contexto que a motivou, o que foi decidido e as
consequências (boas e ruins). ADRs não são apagados: se uma decisão mudar, crie um novo ADR que
**substitui** o antigo e marque o antigo como `Substituído por ADR-XXXX`.

| Nº | Título | Status |
|---|---|---|
| [0001](0001-flutter-para-a-interface.md) | Flutter para a interface | Aceito |
| [0002](0002-aplicar-por-arquivo.md) | Aplicar configurações por arquivo + reinício seguro | Aceito |
| [0003](0003-helper-dbus-polkit-cache-por-sessao.md) | Helper root como serviço D-Bus, polkit por método e senha por sessão | Aceito |
| [0004](0004-agent-separado-da-ui.md) | Agent leve separado da UI Flutter | Aceito |
| [0005](0005-nome-e-identificadores.md) | Nome "Nexo" e identificadores técnicos | Aceito |
| [0006](0006-licenca-gpl3.md) | Licença GPL-3.0 | Aceito |
| [0007](0007-idioma-da-documentacao-e-do-codigo.md) | Idioma da documentação e do código | Aceito |
| [0008](0008-versao-do-flutter-fixada-em-fvmrc.md) | Versão do Flutter fixada em `.fvmrc` sem exigir FVM | Aceito |

## Modelo

```markdown
# ADR-XXXX — Título

- **Status:** Proposto | Aceito | Substituído por ADR-YYYY
- **Data:** AAAA-MM-DD

## Contexto
O problema e as forças em jogo.

## Decisão
O que foi decidido, de forma afirmativa.

## Alternativas consideradas
O que mais foi avaliado e por que não.

## Consequências
O que fica mais fácil, o que fica mais difícil, riscos assumidos.
```
