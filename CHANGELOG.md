# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto adota
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Relatório público `reports/logiops-0.3.5-findings.md` (em inglês) com os 6 achados no logiops 0.3.5
  — causas, reprodução no hardware e textos prontos para reportar upstream — e seção correspondente nos
  READMEs.
- `nexohub_logid_config` — validador semântico: ~50 regras para o que o logid 0.3.5 aceita mas quebra,
  com gravidade (`error` bloqueia aplicar), caminho e parâmetros para a UI; `effectiveDpi` reproduz o
  arredondamento do logid. Sua config original: zero achados.
- Spike S6 no hardware: confirmado que `dpi: []`/`dpi: 1600L` fazem o logid abandonar o mouse,
  `interval: 0` derruba o logid (SIGFPE), `CycleDPI` não funciona e eixo inválido gera comportamento
  indefinido.
- `nexohub_logid_config` — modelo tipado do logid 0.3.5 (`LogidConfig`, perfis, ações, gestos) com
  decodificação fiel às regras do logid, avisos (`DecodeIssue`) do que ele ignora/descarta e escrita
  canônica; sua config original é reescrita sem nenhum aviso (teste golden).
- `tool/logid_config_check`: compila o código de configuração original do logid 0.3.5 para testes
  diferenciais do modelo; 0 divergências em 150 mil configs geradas.
- Pacote `nexohub_logid_config` — camada libconfig: lexer, parser e writer fiéis ao libconfig 1.7.3
  (o mesmo do logid), com árvore tipada que não permite estruturas inválidas.
- `tool/libconfig_check`: parser de referência em C++ usando o libconfig real, para testes
  diferenciais.
- 97 testes (unitários, ida e volta, golden, diferenciais e validação) + fuzz configurável; 0 divergências em 400 mil
  entradas geradas.
- CI compila o parser de referência e exige que os testes diferenciais rodem.
- Fundação do repositório: licença GPL-3.0, READMEs (EN/PT-BR), `.gitignore`, `.editorconfig`,
  recomendações de extensões do VS Code.
- Workspace Dart (pub workspaces) na raiz, com análise estática estrita compartilhada
  (`analysis_options.yaml`).
- Versão do Flutter fixada em `.fvmrc` (3.47.8) e `tool/check_flutter_version.sh` (ADR-0008).
- `tool/check_docs_links.py`: valida links e âncoras de toda a documentação.
- Estrutura completa de documentação em `docs/`: visão geral, componentes, fluxos (diagramas de
  sequência), pacotes, segurança, ADRs 0001–0008, referência do logid 0.3.5 com permalinks,
  API D-Bus do logid, MX Master 3S, ambiente, convenções, depuração, testes, logs, troubleshooting,
  recuperação manual, roteiros de manutenção, checklist manual e glossário.
- Fixtures de configuração: config original do usuário (27/10/2026) e exemplo oficial do logiops.
- Spikes da Fase 0: configs de perfis (S1), extensão de foco do GNOME 50 (S4) e configs de
  Easy-Switch/scroll (S5), com procedimentos em `docs/spikes.md`.
- Workflow de CI: links da documentação, versão do Flutter, format, analyze e testes Dart.
- Spike S3 (`spikes/s3/`): app Flutter mínimo de captura de teclas; mapeamento tecla física → evdev
  confirmado em 22/22 teclas (incl. Super, AltGr e ABNT2).
- Resultados dos spikes S1, S2 e S5 no hardware (MX Master 3S): perfis e troca ao vivo confirmados,
  armadilha do `SetProfile` com nome inexistente confirmada, CIDs/DPI/torque reais, tempo de
  reinício do logid (~0,4 s), semântica de `target` no scroll e problema de confiabilidade do
  `ChangeHost` via Bluetooth (em aberto).

### Alterado
- A documentação de projeto (`docs/`) passou a ser mantida de forma privada pelo mantenedor, fora do
  repositório público. READMEs e spikes não apontam mais para ela.

### Corrigido
- `docs/spikes.md`: comandos do S2 usavam marcadores `<...>`, que o zsh interpreta como
  redirecionamento; agora usam a variável `$CAMINHO`.
