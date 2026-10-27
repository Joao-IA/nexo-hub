# Findings in logiops 0.3.5 (`logid`)

While building Nexo we tested logid's configuration handling far more systematically than a GUI
usually needs: logid's own config-decoding code is compiled into a test harness and compared, input by
input, against Nexo's parser (hundreds of thousands of generated configs), and every risky behaviour
found by reading the code was then **reproduced on real hardware** (Logitech MX Master 3S over
Bluetooth).

This page lists what we found and contains **ready-to-paste texts** for the upstream project
([PixlOne/logiops](https://github.com/PixlOne/logiops)). Nexo's validator already blocks every one of
these configurations, so Nexo users are protected regardless of upstream fixes.

| # | Finding | Impact | Upstream status (checked 2026-10-27) | Suggested action |
|---|---|---|---|---|
| 1 | `interval: 0` in an `OnInterval` gesture crashes logid (SIGFPE) | **Daemon crash** | Not reported | [New issue](#1-crash-sigfpe-when-a-gesture-has-interval-0) |
| 2 | A `dpi` list that is empty or longer than the sensor count makes logid give up on the device — this includes the typo `dpi: 1600L;` | **All settings silently lost** | Not reported (related: #547, #382) | [New issue](#2-device-is-never-configured-when-dpi-is-an-empty-or-too-long-list) |
| 3 | `CycleDPI` never changes the DPI | Feature broken | Reported: #394, #423; fix in PR #381 (open since 2023) | [Comment](#3-cycledpi-confirmation-comment-for-394--423--pr-381) |
| 4 | Invalid `axis` name: `logPrintf` called without its argument (undefined behaviour) | Garbage in logs, possible crash | Fixed in PR #413 (open since 2023) | [Comment on PR #413](#4-axis-warning-without-argument-comment-for-pr-413) |
| 5 | `ChangeHost` `"prev"` does nothing on the first channel; `host: 0` does nothing | Minor | Not reported | [New issue (optional)](#5-changehost-prev-does-nothing-on-the-first-channel) |
| 6 | For fixed DPI lists, an inexact `dpi` selects the **largest** value, not the closest | Minor (code review) | Not reported | [New issue (optional)](#6-getclosestdpi-picks-the-largest-value-for-fixed-dpi-lists) |

**Environment used for every hardware reproduction:** Ubuntu 26.04 LTS, kernel 7.0, logiops
`0.3.5-1build2` (Ubuntu package, built with GCC), libconfig 1.7.3, Logitech MX Master 3S
(PID `0xb034`) over Bluetooth. Each config was run with `sudo systemctl stop logid` followed by
`sudo logid -v -c repro.cfg`. All code references point to tag `v0.3.5`
(`628ab937`); the same code is unchanged on `main` at `e157995` (2025-12-29).

---

## 1. Crash (SIGFPE) when a gesture has `interval: 0`

**Title:** `logid crashes with SIGFPE when an OnInterval/OnFewPixels gesture has interval: 0`

**Body:**

### Summary
A gesture with `mode: "OnInterval"` (or `"OnFewPixels"`) and `interval: 0` kills logid with a
floating-point exception (integer division by zero) as soon as the gesture moves past its threshold.
The D-Bus setter already rejects 0, but the value read from the configuration file is never checked.

### Steps to reproduce
1. `repro.cfg`:
   ```
   devices: ({ name: "MX Master 3S"; dpi: 1000;
     buttons: ({ cid: 0xc3; action: { type: "Gestures"; gestures: (
       { direction: "Up"; mode: "OnInterval"; interval: 0;
         action: { type: "Keypress"; keys: ["KEY_VOLUMEUP"]; }; }
     ); }; });
   });
   ```
2. `sudo systemctl stop logid && sudo logid -v -c repro.cfg`
3. Hold the gesture button and move the mouse up.

### Expected
The gesture is rejected with a warning (or treated as disabled); logid keeps running.

### Actual
```
Floating point exception (core dumped)
```
(exit status 136) on the first movement.

### Cause
[`IntervalGesture::move`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/gesture/IntervalGesture.cpp#L73)
divides by `_config.interval.value()` without checking it; only the D-Bus path
[`setInterval`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/gesture/IntervalGesture.cpp#L99)
guards against 0. A negative interval does not crash but the gesture never fires.

### Suggested fix
```cpp
void IntervalGesture::move(int16_t axis) {
    std::shared_lock lock(_config_mutex);
    if (!_config.interval.has_value() || _config.interval.value() <= 0)
        return;
    ...
```
plus a warning in the constructor when `interval <= 0`, so the user learns why the gesture is inert.

Found while building [Nexo](https://github.com/Joao-IA/nexo-hub), a GUI for logiops; reproduced on an
MX Master 3S (Bluetooth), logiops 0.3.5 (Ubuntu 26.04). Also present on `main` (`e157995`).

---

## 2. Device is never configured when `dpi` is an empty or too long list

**Title:** `Device is never configured ("Device timed out") when dpi is an empty list or has more values than sensors — e.g. dpi: 1600L`

**Body:**

### Summary
If `dpi` is a list that is **empty** or has **more entries than the device has sensors**, logid fails to
add the device: `Error adding device /dev/hidrawN: Device timed out`. No setting at all is applied
(buttons, SmartShift, …), and the cause is not obvious from the log.

An empty list is easy to produce by accident: `dpi: 1600L;` (a 64-bit integer) is not an `int`, so the
`variant<int, list<int>>` falls back to `list<int>`, and reading a list from a scalar yields an empty
list instead of an error.

### Steps to reproduce
Single-sensor mouse (MX Master 3S). Any of:
```
devices: ({ name: "MX Master 3S"; dpi: [];            smartshift: { on: false; }; });
devices: ({ name: "MX Master 3S"; dpi: [800, 1600];   smartshift: { on: false; }; });
devices: ({ name: "MX Master 3S"; dpi: 1600L;         smartshift: { on: false; }; });
```
`sudo logid -v -c repro.cfg`

### Expected
The invalid `dpi` is reported and ignored; the rest of the configuration is applied.

### Actual
```
[INFO] Device found: MX Master 3S on /dev/hidraw2:255
[WARN] Error adding device /dev/hidraw2: Device timed out
```
The device never appears on D-Bus (`busctl tree pizza.pixl.LogiOps` lists no device) and nothing is
configured.

### Cause
[`DPI::configure`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/features/DPI.cpp#L84)
calls `_fillDPILists(dpis.size() - 1)`. For an empty list `size() - 1` underflows and becomes sensor
255 after the conversion to `uint8_t`; for a too long list it asks for sensors that do not exist. The
resulting HID++ errors abort the whole device initialization.

Two related details in the same loop:
- [`++i`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/features/DPI.cpp#L89)
  only runs when `dpi != 0`, so `dpi: [0, 1600]` sets **sensor 0** to 1600 instead of leaving sensor 0
  unchanged and setting sensor 1.
- [`config_io<std::list<T>>`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/config/types.h#L252-L262)
  returns an empty list for scalar settings (`getLength()` is 0) instead of throwing, which is how
  `dpi: 1600L` turns into an empty list silently (see also #382).

### Suggested fix
```cpp
} else {
    const auto& dpis = std::get<std::list<int>>(config);
    const auto sensors = _adjustable_dpi->getSensorCount();
    if (dpis.empty() || dpis.size() > sensors) {
        logPrintf(WARN, "%s: dpi has %zu value(s) but the device has %u sensor(s); ignored",
                  _device->name().c_str(), dpis.size(), sensors);
        return;
    }
    _fillDPILists(dpis.size() - 1);
    std::shared_lock dpi_lock(_dpi_list_mutex);
    int i = 0;
    for (const auto& dpi : dpis) {
        if (dpi != 0)
            _adjustable_dpi->setSensorDPI(i, getClosestDPI(_dpi_lists.at(i), dpi));
        ++i;
    }
}
```
and make `config_io<std::list<T>>::get` throw `SettingTypeException` when the setting is not an
aggregate, so type mistakes are logged instead of silently becoming empty lists.

Related but different: #547 (out-of-bounds read in `getSensorDPIList`).

Found while building [Nexo](https://github.com/Joao-IA/nexo-hub), a GUI for logiops; reproduced on an
MX Master 3S (Bluetooth), logiops 0.3.5 (Ubuntu 26.04). Also present on `main` (`e157995`).

---

## 3. `CycleDPI`: confirmation comment for #394 / #423 / PR #381

**Comment:**

Confirming on logiops 0.3.5 (Ubuntu 26.04 package) with an MX Master 3S over Bluetooth:

```
devices: ({ name: "MX Master 3S"; dpi: 1000;
  buttons: ({ cid: 0xc4; action: { type: "CycleDPI"; dpis: [400, 3000]; }; });
});
```

`GetDPI` over D-Bus returns `1000` before and after pressing the button several times — the DPI never
changes. The cause is the inverted condition in
[`CycleDPI::press`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/CycleDPI.cpp#L68):
it only acts when the list is **empty**, and in that case it increments and dereferences `end()` of an
empty list (undefined behaviour). PR #381 fixes it; the line is still unchanged on `main` (`e157995`).
It would be great to get #381 merged.

---

## 4. Axis warning without argument: comment for PR #413

**Comment:**

Confirming the `logPrintf` issue fixed by this PR on logiops 0.3.5: with
`{ direction: "Up"; mode: "Axis"; axis: "REL_FOO"; }` on an MX Master 3S, logid printed

```
[WARN] Invalid axis p.<garbage bytes>
```

i.e. `"Invalid axis %s."` at
[`AxisGesture.cpp#L48`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/gesture/AxisGesture.cpp#L48)
reads a random pointer because the argument is missing (undefined behaviour; it did not crash in our
run but may). The one-line fix in this PR (`axis.c_str()`) solves it and the line is still unchanged on
`main` (`e157995`).

---

## 5. `ChangeHost` `"prev"` does nothing on the first channel

**Title:** `ChangeHost: "prev" does nothing on the first channel; host: 0 does nothing`

**Body:**

In [`ChangeHostAction::release`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/actions/ChangeHostAction.cpp#L96-L104),
`"prev"` computes `currentHost - 1` and then `next_host %= hostCount`. On the first channel this is
`-1 % 3 == -1` (C++ keeps the sign of the dividend); converted to `uint8_t` it becomes 255 and
[`ChangeHost::setHost`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/backend/hidpp20/features/ChangeHost.cpp#L50)
throws `InvalidArgument`, so nothing happens instead of wrapping to the last channel. The same applies
to `host: 0` (and to negative numbers whose remainder is negative).

Suggested fix:
```cpp
next_host = ((next_host % host_info.hostCount) + host_info.hostCount) % host_info.hostCount;
```

Found by code review while building [Nexo](https://github.com/Joao-IA/nexo-hub); present on `main`
(`e157995`).

---

## 6. `getClosestDPI` picks the largest value for fixed DPI lists

**Title:** `getClosestDPI returns the largest DPI instead of the closest for devices with a fixed DPI list`

**Body:**

For devices that report a fixed list of DPIs (not a range), an inexact `dpi` is resolved with
[`std::min_element(..., [dpi](uint16_t a, uint16_t b) { return (dpi - a) < (dpi - b); })`](https://github.com/PixlOne/logiops/blob/628ab937a25724c1f21e7edf25c8e5aaff82c691/src/logid/features/DPI.cpp#L46-L48).
The operands are promoted to `int`, so the comparison selects the element with the smallest signed
difference — always the **largest** value — instead of the closest one. Example: list
`[400, 800, 1600]`, `dpi: 1000` → 1600 (expected 800).

Suggested fix: compare `std::abs(dpi - a) < std::abs(dpi - b)`.

Found by code review while building [Nexo](https://github.com/Joao-IA/nexo-hub) (not reproduced: our
test device reports a DPI range); present on `main` (`e157995`).
