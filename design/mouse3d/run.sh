#!/usr/bin/env bash
# Runs build.py with the pinned Blender (Linux, or Git Bash on Windows).
#   design/mouse3d/run.sh <task> [options]        e.g. design/mouse3d/run.sh preview --views app
# Blender is looked up in $NEXO_BLENDER, then in the default install locations of the README.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
blender="${NEXO_BLENDER:-}"
if [[ -z "$blender" ]]; then
  candidates=("$HOME/.local/opt/blender-5.2.3/blender")
  if [[ -n "${LOCALAPPDATA:-}" ]] && command -v cygpath >/dev/null 2>&1; then
    candidates+=("$(cygpath -u "$LOCALAPPDATA")/Programs/blender-5.2.3-windows-x64/blender.exe")
  fi
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      blender="$candidate"
      break
    fi
  done
fi
if [[ -z "$blender" || ! -x "$blender" ]]; then
  echo "Blender 5.2.3 não encontrado. Instale conforme design/mouse3d/README.md ou defina NEXO_BLENDER." >&2
  exit 2
fi
exec "$blender" -b --factory-startup --python-exit-code 1 --python "$here/build.py" -- "$@"
