# Testes

**Status:** planejado; vira vigente na Fase 1 (primeiros pacotes com testes).

## Camadas

| Camada | Ferramenta | Onde | Quando roda |
|---|---|---|---|
| Unidade (Dart puro) | `dart test` | `packages/*/test/` | CI em todo PR |
| Propriedade (round-trip modelo → texto → modelo) | `dart test` + gerador aleatório com semente fixa | `packages/nexohub_logid_config/test/` | CI |
| **Diferencial com libconfig++** | `tool/libconfig_check` (C++) | `tool/libconfig_check/` | CI |
| Widgets e goldens | `flutter test` | `apps/nexo/test/` | CI |
| Integração (UI + fakes do helper/plataforma) | `flutter test integration_test` | `apps/nexo/integration_test/` | CI (com `xvfb`) |
| Helper (caminhos injetados, systemd falso) | `dart test` | `bin/helper/test/` | CI |
| Manual no hardware | checklist | [06-testes-manuais/mx-master-3s.md](../06-testes-manuais/mx-master-3s.md) | antes de cada release |

## Teste diferencial (por que existe)

O logid usa a biblioteca **libconfig** para ler o arquivo. Nosso parser/serializer é escrito em Dart.
Para garantir que eles concordam, uma pequena ferramenta C++ (`tool/libconfig_check`) usa o libconfig++
real para:
1. ler **toda** saída do nosso serializer (incluindo milhares de configs aleatórias) — nenhuma pode falhar;
2. ler um corpus de entradas válidas e inválidas — nosso parser deve aceitar/rejeitar exatamente as mesmas.

## Como rodar (a partir da Fase 1)

```bash
dart test                                  # todos os pacotes do workspace
dart test packages/nexohub_logid_config    # um pacote
tool/libconfig_check/run.sh                # diferencial
```

## Fixtures

`fixtures/logid/` guarda configs reais usadas como entrada de testes:
- `user-original-2026-10-27.cfg` — sua configuração antes do Nexo;
- `logid.example.cfg` — exemplo oficial do logiops (todas as linhas comentadas).
