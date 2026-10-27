#!/usr/bin/env bash
# Builds the reference logid config decoder used by the differential tests.
# Compiles logid 0.3.5's own config code (upstream/, verified by SHA256SUMS)
# with small stubs for its daemon-only dependencies (stubs/).
# Requires: g++ (C++20) and libconfig++-dev.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(cd "$here/upstream" && sha256sum --quiet -c SHA256SUMS)
mkdir -p "$here/build"
g++ -std=c++20 -O1 -w \
  -I"$here/upstream" -I"$here/stubs" \
  "$here/main.cpp" "$here/upstream/config/config.cpp" \
  $(pkg-config --cflags --libs libconfig++) -o "$here/build/logid_config_check"
echo "built $here/build/logid_config_check (logid 0.3.5 config code, libconfig $(pkg-config --modversion libconfig++))"
