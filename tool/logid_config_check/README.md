# logid_config_check

Reference decoder used by the differential tests of `packages/nexohub_logid_config`.
It decodes `logid.cfg` files with **logid 0.3.5's own configuration code** and prints, as one JSON
line per file, exactly what logid understands — including the warnings it would log.

```bash
tool/logid_config_check/build.sh                       # needs g++ (C++20) and libconfig++-dev
tool/logid_config_check/build/logid_config_check a.cfg b.cfg
```

## Third-party code

`upstream/` contains **unmodified** files from [logiops](https://github.com/PixlOne/logiops)
v0.3.5 (commit `628ab937a25724c1f21e7edf25c8e5aaff82c691`), licensed under the GNU GPL v3
(`upstream/LICENSE`):

| File | Upstream path |
|---|---|
| `upstream/config/schema.h` | `src/logid/config/schema.h` |
| `upstream/config/types.h` | `src/logid/config/types.h` |
| `upstream/config/group.h` | `src/logid/config/group.h` |
| `upstream/config/map.h` | `src/logid/config/map.h` |
| `upstream/config/config.cpp` | `src/logid/config/config.cpp` |

`build.sh` verifies them against `upstream/SHA256SUMS` before compiling. `stubs/` replaces the two
daemon-only dependencies (`ipcgull/property.h`, `util/log.h`) with minimal stand-ins that do not
affect decoding.

When logiops is updated, replace the files from the new tag, regenerate `SHA256SUMS`
(`sha256sum config/* LICENSE > SHA256SUMS` inside `upstream/`) and adapt `main.cpp` to schema changes.
