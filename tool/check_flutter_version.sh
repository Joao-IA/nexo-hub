#!/usr/bin/env bash
# Fails when the Flutter SDK on PATH differs from the version pinned in .fvmrc.
# See docs/01-arquitetura/adr/0008-versao-do-flutter-fixada-em-fvmrc.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/.fvmrc")"

if [[ -z "$expected" ]]; then
  echo "error: could not read the Flutter version from .fvmrc" >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found in PATH (see docs/03-desenvolvimento/ambiente.md)" >&2
  exit 1
fi

actual="$(flutter --version --machine 2>/dev/null \
  | sed -n 's/.*"frameworkVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

if [[ "$actual" != "$expected" ]]; then
  echo "error: Flutter $actual installed, but .fvmrc pins $expected" >&2
  exit 1
fi
echo "ok: Flutter $actual matches .fvmrc"
