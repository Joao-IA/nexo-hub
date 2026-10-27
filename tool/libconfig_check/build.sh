#!/usr/bin/env bash
# Builds the reference libconfig parser used by the differential tests.
# Requires: g++ and libconfig++-dev (same library version logid links to).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$here/build"
g++ -std=c++17 -O2 -Wall -Wextra -Werror "$here/main.cpp" \
  $(pkg-config --cflags --libs libconfig++) -o "$here/build/libconfig_check"
echo "built $here/build/libconfig_check ($(pkg-config --modversion libconfig++))"
