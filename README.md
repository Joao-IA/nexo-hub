# Nexo

> 🇧🇷 [Leia em português](README.pt-BR.md)

**Nexo** is an open-source peripheral hub for Linux (Windows/macOS planned). Its first module is a
complete graphical interface for [logiops](https://github.com/PixlOne/logiops) (`logid`), so Logitech
mice such as the **MX Master 3S** can be configured without ever editing `/etc/logid.cfg` by hand.

> **Status:** early development — Phase 0 (foundation). Nothing is usable yet.

## Goals (v1.0 — Logitech module)

- Interactive device illustration: click a button, pick an action.
- Buttons, gestures, scroll wheel, SmartShift, thumb wheel, DPI and Easy-Switch actions.
- Multiple profiles, switchable by a mouse button or **automatically per focused application**.
- Generated configuration is **always valid**: typed model, strict validator, differential tests
  against the real `libconfig` parser used by `logid`.
- Safe apply: backup → atomic write → restart `logid` → health check → **automatic rollback**.
- Asks for your password **once per login session**; switching profiles never asks.
- Tray icon with battery level and low-battery notifications.
- Portuguese (Brazil) and English.

## Architecture at a glance

| Component     | Technology            | Runs as             | Role                                           |
|---------------|-----------------------|---------------------|------------------------------------------------|
| `nexo`        | Flutter               | user, on demand     | The UI                                         |
| `nexo-agent`  | Dart (AOT)            | user, at login      | Tray, notifications, per-app profile engine    |
| `nexo-helper` | Dart (AOT)            | root, D-Bus service | Privileged operations, guarded by polkit       |
| `nexo-focus`  | GNOME Shell extension | inside the Shell    | Reports the focused app (Wayland requirement)  |

Detailed design documentation (architecture, decision records, runbooks) is kept privately by the
maintainer and is not part of this repository.

## Findings in logiops 0.3.5

Building Nexo meant testing logid's configuration handling exhaustively: logid's own config-decoding
code runs in a differential test harness against Nexo's parser, and every risky behaviour was then
reproduced on real hardware (MX Master 3S over Bluetooth). The critical findings:

| Configuration | What really happens |
|---|---|
| `interval: 0` in an `OnInterval` gesture | **logid crashes** (SIGFPE) on the first movement |
| `dpi: []`, more DPI values than sensors, or the typo `dpi: 1600L;` | **logid gives up on the device** — no setting is applied, only `Device timed out` in the log |
| Any `CycleDPI` action | **Never changes the DPI** (known upstream bug, fix still unmerged) |
| Unknown `axis` name in an `Axis` gesture | Undefined behaviour in logid's warning (random memory printed) |

Nexo's validator blocks all of these. Full write-up, with reproduction steps, root causes and
ready-to-paste upstream reports: [`reports/logiops-0.3.5-findings.md`](reports/logiops-0.3.5-findings.md).

## Roadmap

1. **v1.0** — Logitech module on Linux (logiops).
2. **v1.1** — Generic Bluetooth/audio layer on Linux (BlueZ, UPower, PipeWire).
3. **v2** — Samsung Galaxy Buds adapter.
4. **v3** — Windows port.
5. **v4+** — Community adapters (HeadsetControl, OpenRGB…).

## License

[GPL-3.0](LICENSE). Nexo is an independent project and is not affiliated with or endorsed by
Logitech, Samsung or any other manufacturer. All trademarks belong to their respective owners.
