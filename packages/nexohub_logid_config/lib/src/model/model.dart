// Typed model of a logid 0.3.5 configuration (src/logid/config/schema.h).
//
// Values are exactly what logid decodes: e.g. `cid` is already truncated to
// 16 bits and SmartShift `threshold` is an unsigned 32-bit number, because
// that is what logid stores. Optional fields are `null` when absent.
// Collections keyed in logid (devices, profiles, buttons, gestures, ignore)
// keep file order but forbid duplicate keys, so encoding is unambiguous.
// Unknown keys are preserved in `extra` and may not reuse a known name.
import 'dart:convert';

import '../libconfig/ast.dart';

abstract base class _Value {
  const _Value();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      _deepEquals((other as _Value)._props, _props);

  @override
  int get hashCode => _deepHash(_props);
}

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? o) =>
    o is List ? Object.hashAll(o.map(_deepHash)) : o.hashCode;

void _checkExtra(List<LcSetting> extra, Set<String> reserved, String where) {
  for (final s in extra) {
    if (reserved.contains(s.name)) {
      throw ArgumentError.value(
        s.name,
        'extra',
        'is a known key of $where and cannot be an extra setting',
      );
    }
  }
  final names = <String>{};
  for (final s in extra) {
    if (!names.add(s.name)) {
      throw ArgumentError.value(s.name, 'extra', 'duplicate setting');
    }
  }
}

void _checkUnique<T, K>(Iterable<T> items, K Function(T) key, String what) {
  final seen = <K>{};
  for (final item in items) {
    if (!seen.add(key(item))) {
      throw ArgumentError.value(key(item), what, 'duplicate');
    }
  }
}

void _checkUnsigned(int value, int bits, String name) =>
    RangeError.checkValueInInterval(value, 0, (1 << bits) - 1, name);

void _checkSigned32(int value, String name) =>
    RangeError.checkValueInInterval(value, -0x80000000, 0x7fffffff, name);

/// ASCII-only lower case, like C `tolower` in the "C" locale used by logid.
String asciiLowerCase(String s) => String.fromCharCodes(
  s.codeUnits.map((c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c),
);

// ---------------------------------------------------------------------------
// Top level
// ---------------------------------------------------------------------------

/// The whole `logid.cfg` (`struct Config`).
final class LogidConfig extends _Value {
  /// Creates a configuration. Device names must be unique.
  LogidConfig({
    List<DeviceConfig>? devices,
    List<int>? ignore,
    this.ioTimeout,
    this.workers,
    List<LcSetting> extra = const [],
  }) : devices = devices == null ? null : List.unmodifiable(devices),
       ignore = ignore == null ? null : List.unmodifiable(ignore),
       extra = List.unmodifiable(extra) {
    if (this.devices != null) {
      _checkUnique(this.devices!, (d) => d.name, 'devices');
    }
    if (this.ignore != null) {
      _checkUnique(this.ignore!, (p) => p, 'ignore');
      for (final pid in this.ignore!) {
        _checkUnsigned(pid, 16, 'ignore');
      }
    }
    if (workers != null) _checkSigned32(workers!, 'workers');
    _checkExtra(this.extra, knownKeys, 'the configuration');
  }

  /// Keys logid reads at the top level.
  static const knownKeys = {'devices', 'ignore', 'io_timeout', 'workers'};

  /// Configured devices, in file order (`devices`). Null when absent.
  final List<DeviceConfig>? devices;

  /// Product IDs logid must not manage (`ignore`), 16-bit, in file order.
  final List<int>? ignore;

  /// HID++ I/O timeout in milliseconds (`io_timeout`, must be a float).
  final double? ioTimeout;

  /// Worker thread count (`workers`).
  final int? workers;

  /// Unknown top-level settings, preserved verbatim.
  final List<LcSetting> extra;

  /// The device named exactly [name], or null.
  DeviceConfig? device(String name) {
    for (final d in devices ?? const <DeviceConfig>[]) {
      if (d.name == name) return d;
    }
    return null;
  }

  @override
  List<Object?> get _props => [devices, ignore, ioTimeout, workers, extra];
}

/// One device, normalized the way logid does when it connects
/// (`Device::_getConfig`): the flat form is profile `default`.
final class DeviceConfig extends _Value {
  /// Creates a device. [profiles] must be non-empty with unique names.
  DeviceConfig({
    required this.name,
    required this.defaultProfile,
    required List<Profile> profiles,
    List<LcSetting> extra = const [],
  }) : profiles = List.unmodifiable(profiles),
       extra = List.unmodifiable(extra) {
    if (this.profiles.isEmpty) {
      throw ArgumentError.value(profiles, 'profiles', 'must not be empty');
    }
    _checkUnique(this.profiles, (p) => p.name, 'profiles');
    _checkExtra(this.extra, reservedKeys, 'a device');
  }

  /// Keys with meaning at device level, in either form.
  static const reservedKeys = {
    'name', 'default_profile', 'profiles', ...Profile.fieldKeys, //
  };

  /// The device name as reported by HID++ (e.g. `MX Master 3S`).
  final String name;

  /// Profile activated when the device connects (`default_profile`).
  final String defaultProfile;

  /// Profiles in file order; the flat form is one profile named `default`.
  final List<Profile> profiles;

  /// Unknown device-level settings (profile form only), preserved.
  final List<LcSetting> extra;

  /// Whether this device can be written in the flat form (one profile
  /// `default`, active by default, no device-level extras).
  bool get isFlat =>
      profiles.length == 1 &&
      profiles.single.name == 'default' &&
      defaultProfile == 'default' &&
      extra.isEmpty;

  /// The profile named exactly [name], or null.
  Profile? profile(String name) {
    for (final p in profiles) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  List<Object?> get _props => [name, defaultProfile, profiles, extra];
}

/// A profile (`struct Profile`).
final class Profile extends _Value {
  /// Creates a profile. Button CIDs must be unique.
  Profile({
    required this.name,
    this.dpi,
    this.smartShift,
    this.hiresScroll,
    this.thumbWheel,
    List<ButtonConfig>? buttons,
    List<LcSetting> extra = const [],
  }) : buttons = buttons == null ? null : List.unmodifiable(buttons),
       extra = List.unmodifiable(extra) {
    if (this.buttons != null) {
      _checkUnique(this.buttons!, (b) => b.cid, 'buttons');
    }
    _checkExtra(this.extra, DeviceConfig.reservedKeys, 'a profile');
  }

  /// Keys logid reads in a profile.
  static const fieldKeys = {
    'dpi', 'smartshift', 'hiresscroll', 'thumbwheel', 'buttons', //
  };

  /// Profile name (the `name` key; implicit `default` in the flat form).
  final String name;

  /// Pointer speed (`dpi`).
  final DpiSetting? dpi;

  /// Wheel ratchet behaviour (`smartshift`).
  final SmartShiftConfig? smartShift;

  /// Main wheel (`hiresscroll`).
  final HiresScrollConfig? hiresScroll;

  /// Thumb wheel (`thumbwheel`).
  final ThumbWheelConfig? thumbWheel;

  /// Remapped buttons (`buttons`), in file order.
  final List<ButtonConfig>? buttons;

  /// Unknown profile settings, preserved.
  final List<LcSetting> extra;

  /// The button with [cid], or null.
  ButtonConfig? button(int cid) {
    for (final b in buttons ?? const <ButtonConfig>[]) {
      if (b.cid == cid) return b;
    }
    return null;
  }

  @override
  List<Object?> get _props => [
    name, dpi, smartShift, hiresScroll, thumbWheel, buttons, extra, //
  ];
}

// ---------------------------------------------------------------------------
// Profile features
// ---------------------------------------------------------------------------

/// `dpi`: a single value or one value per sensor.
sealed class DpiSetting extends _Value {
  const DpiSetting();
}

/// `dpi: 1600;`
final class FixedDpi extends DpiSetting {
  /// Creates a fixed DPI.
  FixedDpi(this.value) {
    _checkSigned32(value, 'value');
  }

  /// DPI of sensor 0.
  final int value;

  @override
  List<Object?> get _props => [value];
}

/// `dpi: [800, 1600];` — one entry per sensor (may be empty: no effect).
final class PerSensorDpi extends DpiSetting {
  /// Creates per-sensor DPIs.
  PerSensorDpi(List<int> values) : values = List.unmodifiable(values) {
    for (final v in this.values) {
      _checkSigned32(v, 'values');
    }
  }

  /// DPI per sensor index.
  final List<int> values;

  @override
  List<Object?> get _props => [values];
}

/// `smartshift` (`struct SmartShift`).
final class SmartShiftConfig extends _Value {
  /// Creates a SmartShift configuration.
  SmartShiftConfig({
    this.on,
    this.threshold,
    this.torque,
    List<LcSetting> extra = const [],
  }) : extra = List.unmodifiable(extra) {
    if (threshold != null) _checkUnsigned(threshold!, 32, 'threshold');
    if (torque != null) _checkUnsigned(torque!, 32, 'torque');
    _checkExtra(this.extra, knownKeys, 'smartshift');
  }

  /// Keys logid reads.
  static const knownKeys = {'on', 'threshold', 'torque'};

  /// SmartShift enabled (`on`).
  final bool? on;

  /// Auto-disengage threshold (`threshold`, unsigned 32-bit as decoded).
  final int? threshold;

  /// Ratchet force in percent (`torque`, unsigned 32-bit as decoded).
  final int? torque;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;

  @override
  List<Object?> get _props => [on, threshold, torque, extra];
}

/// `hiresscroll` (`struct HiresScroll`). The boolean form
/// `hiresscroll: true;` decodes as `HiresScrollConfig(hires: true)`.
final class HiresScrollConfig extends _Value {
  /// Creates a main-wheel configuration.
  HiresScrollConfig({
    this.hires,
    this.invert,
    this.target,
    this.up,
    this.down,
    List<LcSetting> extra = const [],
  }) : extra = List.unmodifiable(extra) {
    _checkExtra(this.extra, knownKeys, 'hiresscroll');
  }

  /// Keys logid reads.
  static const knownKeys = {'hires', 'invert', 'target', 'up', 'down'};

  /// High-resolution scrolling (`hires`).
  final bool? hires;

  /// Inverted direction (`invert`).
  final bool? invert;

  /// Divert wheel events to logid (`target`); required for [up]/[down].
  final bool? target;

  /// Gesture for scrolling up (`up`).
  final Gesture? up;

  /// Gesture for scrolling down (`down`).
  final Gesture? down;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;

  @override
  List<Object?> get _props => [hires, invert, target, up, down, extra];
}

/// `thumbwheel` (`struct ThumbWheel`).
final class ThumbWheelConfig extends _Value {
  /// Creates a thumb-wheel configuration.
  ThumbWheelConfig({
    this.divert,
    this.invert,
    this.left,
    this.right,
    this.proxy,
    this.touch,
    this.tap,
    List<LcSetting> extra = const [],
  }) : extra = List.unmodifiable(extra) {
    _checkExtra(this.extra, knownKeys, 'thumbwheel');
  }

  /// Keys logid reads.
  static const knownKeys = {
    'divert', 'invert', 'left', 'right', 'proxy', 'touch', 'tap', //
  };

  /// Divert thumb-wheel events to logid (`divert`).
  final bool? divert;

  /// Inverted direction (`invert`).
  final bool? invert;

  /// Gesture when rotating left (`left`).
  final Gesture? left;

  /// Gesture when rotating right (`right`).
  final Gesture? right;

  /// Action on finger proximity (`proxy`).
  final BasicAction? proxy;

  /// Action on touch (`touch`).
  final BasicAction? touch;

  /// Action on tap (`tap`).
  final BasicAction? tap;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;

  @override
  List<Object?> get _props => [
    divert, invert, left, right, proxy, touch, tap, extra, //
  ];
}

/// One entry of `buttons` (`struct Button`, keyed by `cid`).
final class ButtonConfig extends _Value {
  /// Creates a button mapping. [cid] is 16-bit unsigned.
  ButtonConfig({
    required this.cid,
    this.action,
    List<LcSetting> extra = const [],
  }) : extra = List.unmodifiable(extra) {
    _checkUnsigned(cid, 16, 'cid');
    _checkExtra(this.extra, knownKeys, 'a button');
  }

  /// Keys logid reads.
  static const knownKeys = {'cid', 'action'};

  /// HID++ control ID (e.g. `0xc3`).
  final int cid;

  /// What the button does (`action`); null leaves it unmapped.
  final LogidAction? action;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;

  @override
  List<Object?> get _props => [cid, action, extra];
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// Any action (`config::Action`). Only buttons accept [GesturesAction].
sealed class LogidAction extends _Value {
  LogidAction(List<LcSetting> extra) : extra = List.unmodifiable(extra) {
    _checkExtra(this.extra, {'type', ...fieldKeys}, 'a $typeName action');
  }

  /// The canonical `type` string written by Nexo (e.g. `Keypress`).
  String get typeName;

  /// Field keys of this action type (besides `type`).
  Set<String> get fieldKeys;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;
}

/// Actions allowed everywhere (`config::BasicAction`).
sealed class BasicAction extends LogidAction {
  BasicAction(super.extra);
}

/// `type: "None"`.
final class NoneAction extends BasicAction {
  /// Creates the action.
  NoneAction({List<LcSetting> extra = const []}) : super(extra);

  @override
  String get typeName => 'None';

  @override
  Set<String> get fieldKeys => const {};

  @override
  List<Object?> get _props => [extra];
}

/// `type: "Keypress"` — presses [keys] in order, releases on button up.
final class KeypressAction extends BasicAction {
  /// Creates the action.
  KeypressAction({List<KeyRef>? keys, List<LcSetting> extra = const []})
    : keys = keys == null ? null : List.unmodifiable(keys),
      super(extra);

  /// The keys; a single key in the file decodes as a one-element list.
  final List<KeyRef>? keys;

  @override
  String get typeName => 'Keypress';

  @override
  Set<String> get fieldKeys => const {'keys'};

  @override
  List<Object?> get _props => [keys, extra];
}

/// `type: "ToggleSmartShift"`.
final class ToggleSmartShiftAction extends BasicAction {
  /// Creates the action.
  ToggleSmartShiftAction({List<LcSetting> extra = const []}) : super(extra);

  @override
  String get typeName => 'ToggleSmartShift';

  @override
  Set<String> get fieldKeys => const {};

  @override
  List<Object?> get _props => [extra];
}

/// `type: "ToggleHiresScroll"`.
final class ToggleHiresScrollAction extends BasicAction {
  /// Creates the action.
  ToggleHiresScrollAction({List<LcSetting> extra = const []}) : super(extra);

  @override
  String get typeName => 'ToggleHiresScroll';

  @override
  Set<String> get fieldKeys => const {};

  @override
  List<Object?> get _props => [extra];
}

/// `type: "CycleDPI"` — steps through [dpis].
final class CycleDpiAction extends BasicAction {
  /// Creates the action.
  CycleDpiAction({
    List<int>? dpis,
    this.sensor,
    List<LcSetting> extra = const [],
  }) : dpis = dpis == null ? null : List.unmodifiable(dpis),
       super(extra) {
    for (final d in this.dpis ?? const <int>[]) {
      _checkSigned32(d, 'dpis');
    }
    if (sensor != null) _checkSigned32(sensor!, 'sensor');
  }

  /// DPI values to cycle through.
  final List<int>? dpis;

  /// Sensor index.
  final int? sensor;

  @override
  String get typeName => 'CycleDPI';

  @override
  Set<String> get fieldKeys => const {'dpis', 'sensor'};

  @override
  List<Object?> get _props => [dpis, sensor, extra];
}

/// `type: "ChangeDPI"` — adds [inc] to the current DPI.
final class ChangeDpiAction extends BasicAction {
  /// Creates the action.
  ChangeDpiAction({this.inc, this.sensor, List<LcSetting> extra = const []})
    : super(extra) {
    if (inc != null) _checkSigned32(inc!, 'inc');
    if (sensor != null) _checkSigned32(sensor!, 'sensor');
  }

  /// DPI increment (may be negative).
  final int? inc;

  /// Sensor index.
  final int? sensor;

  @override
  String get typeName => 'ChangeDPI';

  @override
  Set<String> get fieldKeys => const {'inc', 'sensor'};

  @override
  List<Object?> get _props => [inc, sensor, extra];
}

/// `type: "ChangeHost"` — Easy-Switch.
final class ChangeHostAction extends BasicAction {
  /// Creates the action.
  ChangeHostAction({this.host, List<LcSetting> extra = const []})
    : super(extra);

  /// Target channel.
  final HostTarget? host;

  @override
  String get typeName => 'ChangeHost';

  @override
  Set<String> get fieldKeys => const {'host'};

  @override
  List<Object?> get _props => [host, extra];
}

/// `type: "ChangeProfile"`.
final class ChangeProfileAction extends BasicAction {
  /// Creates the action.
  ChangeProfileAction({this.profile, List<LcSetting> extra = const []})
    : super(extra);

  /// Profile to activate.
  final String? profile;

  @override
  String get typeName => 'ChangeProfile';

  @override
  Set<String> get fieldKeys => const {'profile'};

  @override
  List<Object?> get _props => [profile, extra];
}

/// `type: "Gestures"` — only valid as a button action.
final class GesturesAction extends LogidAction {
  /// Creates the action. Directions are unique ignoring ASCII case.
  GesturesAction({
    List<DirectionalGesture>? gestures,
    List<LcSetting> extra = const [],
  }) : gestures = gestures == null ? null : List.unmodifiable(gestures),
       super(extra) {
    if (this.gestures != null) {
      _checkUnique(
        this.gestures!,
        (g) => asciiLowerCase(g.direction),
        'gestures',
      );
    }
  }

  /// Gestures by direction, in file order.
  final List<DirectionalGesture>? gestures;

  /// The gesture for [direction] (ASCII case-insensitive), or null.
  DirectionalGesture? gesture(String direction) {
    final key = asciiLowerCase(direction);
    for (final g in gestures ?? const <DirectionalGesture>[]) {
      if (asciiLowerCase(g.direction) == key) return g;
    }
    return null;
  }

  @override
  String get typeName => 'Gestures';

  @override
  Set<String> get fieldKeys => const {'gestures'};

  @override
  List<Object?> get _props => [gestures, extra];
}

/// A key in a Keypress action: a libevdev name or a numeric code.
sealed class KeyRef extends _Value {
  const KeyRef();
}

/// `"KEY_LEFTCTRL"`.
final class KeyName extends KeyRef {
  /// Creates a key by name.
  const KeyName(this.name);

  /// libevdev key name.
  final String name;

  @override
  List<Object?> get _props => [name];
}

/// A numeric key code (unsigned 32-bit, as logid decodes it).
final class KeyCode extends KeyRef {
  /// Creates a key by code.
  KeyCode(this.code) {
    _checkUnsigned(code, 32, 'code');
  }

  /// evdev key code.
  final int code;

  @override
  List<Object?> get _props => [code];
}

/// ChangeHost target: a 1-based channel or a keyword.
sealed class HostTarget extends _Value {
  const HostTarget();
}

/// `host: 2;`
final class HostNumber extends HostTarget {
  /// Creates a 1-based channel target.
  HostNumber(this.number) {
    _checkSigned32(number, 'number');
  }

  /// 1-based channel.
  final int number;

  @override
  List<Object?> get _props => [number];
}

/// `host: "next";` (logid understands `next`, `prev`, `previous`).
final class HostKeyword extends HostTarget {
  /// Creates a keyword target.
  const HostKeyword(this.keyword);

  /// The keyword as written.
  final String keyword;

  @override
  List<Object?> get _props => [keyword];
}

// ---------------------------------------------------------------------------
// Gestures
// ---------------------------------------------------------------------------

/// A gesture of a Gestures action, keyed by [direction].
final class DirectionalGesture extends _Value {
  /// Creates a directional gesture.
  const DirectionalGesture(this.direction, this.gesture);

  /// `Up`, `Down`, `Left`, `Right` or `None` (case-insensitive), as written.
  final String direction;

  /// What happens in that direction.
  final Gesture gesture;

  @override
  List<Object?> get _props => [direction, gesture];
}

/// A gesture (`config::Gesture`, selected by `mode`).
sealed class Gesture extends _Value {
  Gesture(this.threshold, List<LcSetting> extra)
    : extra = List.unmodifiable(extra) {
    if (threshold != null) _checkSigned32(threshold!, 'threshold');
    _checkExtra(this.extra, {
      'mode',
      'direction',
      'threshold',
      ...fieldKeys,
    }, 'a $modeName gesture');
  }

  /// The canonical `mode` string written by Nexo (e.g. `OnRelease`).
  String get modeName;

  /// Field keys of this mode (besides `mode` and `threshold`).
  Set<String> get fieldKeys;

  /// Movement needed before the gesture counts (`threshold`, default 50).
  final int? threshold;

  /// Unknown keys, preserved.
  final List<LcSetting> extra;
}

/// `mode: "NoPress"`.
final class NoPressGesture extends Gesture {
  /// Creates the gesture.
  NoPressGesture({int? threshold, List<LcSetting> extra = const []})
    : super(threshold, extra);

  @override
  String get modeName => 'NoPress';

  @override
  Set<String> get fieldKeys => const {};

  @override
  List<Object?> get _props => [threshold, extra];
}

/// `mode: "Axis"` — movement becomes an input axis (e.g. `REL_WHEEL`).
final class AxisGesture extends Gesture {
  /// Creates the gesture.
  AxisGesture({
    int? threshold,
    this.axis,
    this.axisMultiplier,
    List<LcSetting> extra = const [],
  }) : super(threshold, extra);

  /// The axis.
  final AxisRef? axis;

  /// Scale factor (`axis_multiplier`).
  final double? axisMultiplier;

  @override
  String get modeName => 'Axis';

  @override
  Set<String> get fieldKeys => const {'axis', 'axis_multiplier'};

  @override
  List<Object?> get _props => [threshold, axis, axisMultiplier, extra];
}

/// `mode: "OnInterval"` (or the equivalent `"OnFewPixels"`).
final class IntervalGesture extends Gesture {
  /// Creates the gesture.
  IntervalGesture({
    int? threshold,
    this.action,
    this.interval,
    this.fewPixels = false,
    List<LcSetting> extra = const [],
  }) : super(threshold, extra) {
    if (interval != null) _checkSigned32(interval!, 'interval');
  }

  /// Action fired every [interval] units.
  final BasicAction? action;

  /// Movement per repetition; without it the gesture never fires.
  final int? interval;

  /// Written as `OnFewPixels` instead of `OnInterval` (same behaviour).
  final bool fewPixels;

  @override
  String get modeName => fewPixels ? 'OnFewPixels' : 'OnInterval';

  @override
  Set<String> get fieldKeys => const {'action', 'interval'};

  @override
  List<Object?> get _props => [threshold, action, interval, fewPixels, extra];
}

/// `mode: "OnRelease"` — fires when the button is released.
final class ReleaseGesture extends Gesture {
  /// Creates the gesture.
  ReleaseGesture({
    int? threshold,
    this.action,
    List<LcSetting> extra = const [],
  }) : super(threshold, extra);

  /// Action fired.
  final BasicAction? action;

  @override
  String get modeName => 'OnRelease';

  @override
  Set<String> get fieldKeys => const {'action'};

  @override
  List<Object?> get _props => [threshold, action, extra];
}

/// `mode: "OnThreshold"` — fires as soon as the threshold is crossed.
final class ThresholdGesture extends Gesture {
  /// Creates the gesture.
  ThresholdGesture({
    int? threshold,
    this.action,
    List<LcSetting> extra = const [],
  }) : super(threshold, extra);

  /// Action fired.
  final BasicAction? action;

  @override
  String get modeName => 'OnThreshold';

  @override
  Set<String> get fieldKeys => const {'action'};

  @override
  List<Object?> get _props => [threshold, action, extra];
}

/// An Axis gesture target: a name (`REL_WHEEL`) or a numeric code.
sealed class AxisRef extends _Value {
  const AxisRef();
}

/// `axis: "REL_WHEEL";`
final class AxisName extends AxisRef {
  /// Creates an axis by name.
  const AxisName(this.name);

  /// libevdev axis name.
  final String name;

  @override
  List<Object?> get _props => [name];
}

/// `axis: 8;` (unsigned 32-bit, as logid decodes it).
final class AxisCode extends AxisRef {
  /// Creates an axis by code.
  AxisCode(this.code) {
    _checkUnsigned(code, 32, 'code');
  }

  /// evdev axis code.
  final int code;

  @override
  List<Object?> get _props => [code];
}

/// Debug representation used in test failure messages.
String describeModel(Object? o) =>
    const JsonEncoder.withIndent('  ')
        .convert(o is _Value ? o._props.map(_toJsonish).toList() : '$o');

Object? _toJsonish(Object? o) => switch (o) {
  final _Value v => {
    v.runtimeType.toString(): v._props.map(_toJsonish).toList(),
  },
  final List<Object?> l => l.map(_toJsonish).toList(),
  final LcSetting s => '${s.name}: ${s.value}',
  _ => o,
};
