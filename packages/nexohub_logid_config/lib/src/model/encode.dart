// Encodes the typed model as a libconfig tree that logid decodes back to the
// same model (round trip checked against logid's own code by the tests).
//
// Canonical layout:
// * A device with a single profile `default` (and no device-level extras) is
//   written in the flat form, like hand-written configs; otherwise in the
//   `default_profile` + `profiles` form. logid treats both identically.
// * Field order: dpi, smartshift, hiresscroll, thumbwheel, buttons; actions
//   start with `type`, gestures with `direction`/`mode`.
// * `cid` and `ignore` product IDs are hexadecimal; unsigned 32-bit values
//   are written as the signed int that logid casts back to the same value.
// * Preserved unknown keys come last in their group.
import '../libconfig/ast.dart';
import '../libconfig/writer.dart';
import 'model.dart';

/// Encodes [config] as a libconfig tree.
LcGroup encodeLogidConfig(LogidConfig config) => LcGroup([
  if (config.devices != null)
    LcSetting('devices', LcList([for (final d in config.devices!) _device(d)])),
  if (config.ignore != null)
    LcSetting(
      'ignore',
      LcArray([
        for (final p in config.ignore!) LcInt(p, format: LcIntFormat.hex),
      ]),
    ),
  if (config.ioTimeout != null)
    LcSetting('io_timeout', LcFloat(config.ioTimeout!)),
  if (config.workers != null) LcSetting('workers', LcInt(config.workers!)),
  ...config.extra,
]);

/// Encodes and writes [config] as `logid.cfg` text.
String writeLogidConfig(LogidConfig config, {String? header}) =>
    writeLibconfig(encodeLogidConfig(config), header: header);

LcValue _device(DeviceConfig d) {
  final name = LcSetting('name', LcString.fromText(d.name));
  if (d.isFlat) {
    return LcGroup([name, ..._profileFields(d.profiles.single)]);
  }
  return LcGroup([
    name,
    LcSetting('default_profile', LcString.fromText(d.defaultProfile)),
    LcSetting(
      'profiles',
      LcList([
        for (final p in d.profiles)
          LcGroup([
            LcSetting('name', LcString.fromText(p.name)),
            ..._profileFields(p),
          ]),
      ]),
    ),
    ...d.extra,
  ]);
}

List<LcSetting> _profileFields(Profile p) => [
  if (p.dpi != null) LcSetting('dpi', _dpi(p.dpi!)),
  if (p.smartShift != null) LcSetting('smartshift', _smartShift(p.smartShift!)),
  if (p.hiresScroll != null)
    LcSetting('hiresscroll', _hiresScroll(p.hiresScroll!)),
  if (p.thumbWheel != null) LcSetting('thumbwheel', _thumbWheel(p.thumbWheel!)),
  if (p.buttons != null)
    LcSetting('buttons', LcList([for (final b in p.buttons!) _button(b)])),
  ...p.extra,
];

LcValue _dpi(DpiSetting dpi) => switch (dpi) {
  FixedDpi(:final value) => LcInt(value),
  PerSensorDpi(:final values) => LcArray([for (final v in values) LcInt(v)]),
};

/// An unsigned 32-bit value as the int logid's `static_cast<unsigned>` restores.
LcInt _uint32(int value) => LcInt(value.toSigned(32));

LcValue _smartShift(SmartShiftConfig s) => LcGroup([
  if (s.on != null) LcSetting('on', LcBool(s.on!)),
  if (s.threshold != null) LcSetting('threshold', _uint32(s.threshold!)),
  if (s.torque != null) LcSetting('torque', _uint32(s.torque!)),
  ...s.extra,
]);

LcValue _hiresScroll(HiresScrollConfig h) => LcGroup([
  if (h.hires != null) LcSetting('hires', LcBool(h.hires!)),
  if (h.invert != null) LcSetting('invert', LcBool(h.invert!)),
  if (h.target != null) LcSetting('target', LcBool(h.target!)),
  if (h.up != null) LcSetting('up', _gesture(h.up!)),
  if (h.down != null) LcSetting('down', _gesture(h.down!)),
  ...h.extra,
]);

LcValue _thumbWheel(ThumbWheelConfig t) => LcGroup([
  if (t.divert != null) LcSetting('divert', LcBool(t.divert!)),
  if (t.invert != null) LcSetting('invert', LcBool(t.invert!)),
  if (t.left != null) LcSetting('left', _gesture(t.left!)),
  if (t.right != null) LcSetting('right', _gesture(t.right!)),
  if (t.proxy != null) LcSetting('proxy', _action(t.proxy!)),
  if (t.touch != null) LcSetting('touch', _action(t.touch!)),
  if (t.tap != null) LcSetting('tap', _action(t.tap!)),
  ...t.extra,
]);

LcValue _button(ButtonConfig b) => LcGroup([
  LcSetting('cid', LcInt(b.cid, format: LcIntFormat.hex)),
  if (b.action != null) LcSetting('action', _action(b.action!)),
  ...b.extra,
]);

LcGroup _action(LogidAction a) => LcGroup([
  LcSetting('type', LcString.fromText(a.typeName)),
  ...switch (a) {
    NoneAction() || ToggleSmartShiftAction() || ToggleHiresScrollAction() => [],
    KeypressAction(:final keys) => [
      if (keys != null) LcSetting('keys', _keys(keys)),
    ],
    CycleDpiAction(:final dpis, :final sensor) => [
      if (dpis != null)
        LcSetting('dpis', LcArray([for (final d in dpis) LcInt(d)])),
      if (sensor != null) LcSetting('sensor', LcInt(sensor)),
    ],
    ChangeDpiAction(:final inc, :final sensor) => [
      if (inc != null) LcSetting('inc', LcInt(inc)),
      if (sensor != null) LcSetting('sensor', LcInt(sensor)),
    ],
    ChangeHostAction(:final host) => [
      if (host != null)
        LcSetting('host', switch (host) {
          HostNumber(:final number) => LcInt(number),
          HostKeyword(:final keyword) => LcString.fromText(keyword),
        }),
    ],
    ChangeProfileAction(:final profile) => [
      if (profile != null) LcSetting('profile', LcString.fromText(profile)),
    ],
    GesturesAction(:final gestures) => [
      if (gestures != null)
        LcSetting(
          'gestures',
          LcList([
            for (final g in gestures)
              _gesture(g.gesture, direction: g.direction),
          ]),
        ),
    ],
  },
  ...a.extra,
]);

/// Keys as an array when they are all names (or all codes), else a list.
LcValue _keys(List<KeyRef> keys) {
  final values = [
    for (final k in keys)
      switch (k) {
        KeyName(:final name) => LcString.fromText(name),
        KeyCode(:final code) => _uint32(code),
      },
  ];
  final homogeneous = values.every((v) => v.kind == values.firstOrNull?.kind);
  return homogeneous ? LcArray(values) : LcList(values);
}

LcGroup _gesture(Gesture g, {String? direction}) => LcGroup([
  if (direction != null) LcSetting('direction', LcString.fromText(direction)),
  LcSetting('mode', LcString.fromText(g.modeName)),
  if (g.threshold != null) LcSetting('threshold', LcInt(g.threshold!)),
  ...switch (g) {
    NoPressGesture() => [],
    AxisGesture(:final axis, :final axisMultiplier) => [
      if (axis != null)
        LcSetting('axis', switch (axis) {
          AxisName(:final name) => LcString.fromText(name),
          AxisCode(:final code) => _uint32(code),
        }),
      if (axisMultiplier != null)
        LcSetting('axis_multiplier', LcFloat(axisMultiplier)),
    ],
    IntervalGesture(:final interval, :final action) => [
      if (interval != null) LcSetting('interval', LcInt(interval)),
      if (action != null) LcSetting('action', _action(action)),
    ],
    ReleaseGesture(:final action) || ThresholdGesture(:final action) => [
      if (action != null) LcSetting('action', _action(action)),
    ],
  },
  ...g.extra,
]);
