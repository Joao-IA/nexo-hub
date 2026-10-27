# Ambiente de desenvolvimento

**Status:** vigente. Testado em Ubuntu 26.04 LTS (GNOME 50, Wayland) em 27/10/2026.

## 1. Pacotes do sistema

```bash
sudo apt install -y git curl xz-utils unzip clang cmake ninja-build pkg-config \
     libgtk-3-dev liblzma-dev libstdc++-15-dev libayatana-appindicator3-dev \
     libconfig++-dev logiops
```

| Pacote | Para quê |
|---|---|
| `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libstdc++-15-dev` | Compilar o app Flutter para Linux |
| `libayatana-appindicator3-dev` | Ícone na bandeja (testes de UI) |
| `libconfig++-dev` | Ferramenta de teste diferencial `tool/libconfig_check` (mesmo parser do logid) |
| `logiops` | O daemon que o Nexo configura |

## 2. Flutter (versão fixada)

A versão oficial do projeto está em [`.fvmrc`](../../.fvmrc) — ver
[ADR-0008](../01-arquitetura/adr/0008-versao-do-flutter-fixada-em-fvmrc.md).

```bash
VERSION=$(grep -oP '"flutter":\s*"\K[^"]+' .fvmrc)     # ex.: 3.47.8
mkdir -p ~/development && cd ~/development
curl -fLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"
tar -xJf "flutter_linux_${VERSION}-stable.tar.xz" && rm "flutter_linux_${VERSION}-stable.tar.xz"
```

Adicione ao `~/.zshrc` (ou `~/.bashrc`) e abra um novo terminal:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

Opcional — desativar telemetria do Flutter/Dart: `flutter --disable-analytics` e `dart --disable-analytics`.

> Alternativa: usar [FVM](https://fvm.app). Ele lê o mesmo `.fvmrc` (`fvm install && fvm flutter ...`).

> ⚠ Se você usa **pyenv**, o `python3` do PATH não tem PyGObject. Isso não afeta o Nexo (Flutter/Dart),
> mas scripts de sistema devem usar `/usr/bin/python3`.

## 3. Verificar

```bash
tool/check_flutter_version.sh     # confere se o Flutter instalado bate com o .fvmrc
flutter doctor -v                 # seção "Linux toolchain" deve estar ✓
```

## 4. Editor

VS Code com as extensões **Dart** e **Flutter** (`Dart-Code.dart-code`, `Dart-Code.flutter`) — já
recomendadas em `.vscode/extensions.json`.
