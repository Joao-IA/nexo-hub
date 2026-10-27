// Seeded generators for the model tests.
import 'dart:math';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';

LcGroup _group(Random r, Iterable<LcSetting> settings) {
  final unique = <String, LcSetting>{};
  for (final s in settings) {
    unique.putIfAbsent(s.name, () => s);
  }
  final list = unique.values.toList();
  if (r.nextInt(4) == 0) list.shuffle(r);
  return LcGroup(list);
}

/// logid-shaped libconfig trees with plausible mistakes, to compare this
/// package's decoder with logid's own.
final class LogidTreeGenerator {
  /// Creates a generator with a fixed [seed].
  LogidTreeGenerator(int seed) : _r = Random(seed);

  final Random _r;

  bool _p(int percent) => _r.nextInt(100) < percent;
  T _pick<T>(List<T> items) => items[_r.nextInt(items.length)];

  /// A random root group.
  LcGroup document() => _group(_r, [
    if (_p(90)) LcSetting('devices', _sequenceOf(_device, max: 3)),
    if (_p(25))
      LcSetting(
        'ignore',
        _p(80)
            ? LcArray([
                for (var i = 0; i < _r.nextInt(3); i++) _int(hexy: true),
              ])
            : _junk(),
      ),
    if (_p(25))
      LcSetting(
        'io_timeout',
        _p(60) ? LcFloat(_pick([500.0, 1e3, 0.5])) : _junk(),
      ),
    if (_p(25))
      LcSetting('workers', _p(60) ? LcInt(_pick([1, 4, 8])) : _junk()),
    if (_p(15)) LcSetting(_pick(['foo', 'x-note']), _junk()),
  ]);

  LcValue _sequenceOf(LcValue Function() element, {int max = 4}) {
    final items = [for (var i = 0; i < _r.nextInt(max + 1); i++) element()];
    if (_p(85)) return LcList(items);
    if (_p(50)) return _junk();
    return _group(_r, [
      for (var i = 0; i < items.length; i++) LcSetting('e$i', items[i]),
    ]);
  }

  LcValue _junk() => _pick<LcValue Function()>([
    () => LcInt(_r.nextInt(2000) - 1000),
    () => const LcInt64(1600),
    () => LcFloat(1.5),
    () => const LcBool(true),
    () => LcString.fromText('x'),
    () => LcArray([LcInt(1), LcInt(2)]),
    () => LcList([LcString.fromText('a'), LcInt(3)]),
    () => LcGroup(const []),
  ])();

  LcInt _int({bool hexy = false}) => LcInt(
    _pick([0, 1, 20, 50, 1600, -1, 0xc3, 0xc4, 0x100c3, 65535, 0x7fffffff]),
    format: hexy && _p(50) ? LcIntFormat.hex : LcIntFormat.decimal,
  );

  LcValue _maybe(LcValue Function() good, {int goodPercent = 80}) =>
      _p(goodPercent) ? good() : _junk();

  LcValue _device() {
    if (_p(5)) return _junk();
    final name = _p(92)
        ? LcString.fromText(
            _pick(['MX Master 3S', 'MX Master 3S', 'M720', 'mx master 3s']),
          )
        : _junk();
    final profileForm = _p(40);
    return _group(_r, [
      if (_p(95)) LcSetting('name', name),
      if (profileForm) ...[
        if (_p(80))
          LcSetting(
            'default_profile',
            _maybe(
              () =>
                  LcString.fromText(_pick(['default', 'work', 'game', 'nope'])),
            ),
          ),
        if (_p(90)) LcSetting('profiles', _sequenceOf(_namedProfile, max: 3)),
        if (_p(20)) ..._profileFields(),
      ] else
        ..._profileFields(),
      if (_p(10)) LcSetting('note', _junk()),
    ]);
  }

  LcValue _namedProfile() => _p(5)
      ? _junk()
      : _group(_r, [
          if (_p(92))
            LcSetting(
              'name',
              _maybe(
                () => LcString.fromText(
                  _pick(['default', 'work', 'game', 'Work']),
                ),
              ),
            ),
          ..._profileFields(),
          if (_p(8)) LcSetting(_pick(['profiles', 'default_profile']), _junk()),
        ]);

  List<LcSetting> _profileFields() => [
    if (_p(50))
      LcSetting(
        'dpi',
        _pick<LcValue Function()>([
          () => LcInt(_pick([400, 1000, 1600, 8000])),
          () => LcArray([LcInt(800), LcInt(1600)]),
          () => LcList([LcInt(800), LcString.fromText('x'), LcInt(400)]),
          _junk,
        ])(),
      ),
    if (_p(40))
      LcSetting(
        'smartshift',
        _maybe(
          () => _group(_r, [
            if (_p(70)) LcSetting('on', _maybe(() => LcBool(_p(50)))),
            if (_p(60)) LcSetting('threshold', _maybe(_int)),
            if (_p(30)) LcSetting('torque', _maybe(_int)),
            if (_p(10)) LcSetting('extra', _junk()),
          ]),
        ),
      ),
    if (_p(40))
      LcSetting(
        'hiresscroll',
        _pick<LcValue Function()>([
          () => LcBool(_p(50)),
          () => _group(_r, [
            if (_p(60)) LcSetting('hires', _maybe(() => LcBool(_p(50)))),
            if (_p(40)) LcSetting('invert', _maybe(() => LcBool(_p(50)))),
            if (_p(40)) LcSetting('target', _maybe(() => LcBool(_p(50)))),
            if (_p(25)) LcSetting('up', _gesture()),
            if (_p(25)) LcSetting('down', _gesture()),
          ]),
          _junk,
        ])(),
      ),
    if (_p(35))
      LcSetting(
        'thumbwheel',
        _maybe(
          () => _group(_r, [
            if (_p(70)) LcSetting('divert', _maybe(() => LcBool(_p(50)))),
            if (_p(40)) LcSetting('invert', _maybe(() => LcBool(_p(50)))),
            if (_p(50)) LcSetting('left', _gesture()),
            if (_p(50)) LcSetting('right', _gesture()),
            if (_p(20)) LcSetting('tap', _action(allowGestures: _p(20))),
            if (_p(15)) LcSetting('touch', _action()),
            if (_p(15)) LcSetting('proxy', _action()),
            if (_p(10)) LcSetting('direction', LcString.fromText('Up')),
          ]),
        ),
      ),
    if (_p(60)) LcSetting('buttons', _sequenceOf(_button, max: 4)),
  ];

  LcValue _button() => _p(5)
      ? _junk()
      : _group(_r, [
          if (_p(93))
            LcSetting(
              'cid',
              _pick<LcValue Function()>([
                () => LcInt(
                  _pick([0x52, 0x53, 0x56, 0xc3, 0xc4]),
                  format: LcIntFormat.hex,
                ),
                () => LcInt(_pick([0xc3, 0x100c3, -61])),
                () => const LcInt64(0xc3),
                () => LcString.fromText('0xc3'),
              ])(),
            ),
          if (_p(85)) LcSetting('action', _action(allowGestures: true)),
          if (_p(8)) LcSetting('note', _junk()),
        ]);

  static const _types = [
    'None', 'Keypress', 'keypress', 'KEYPRESS', 'ToggleSmartShift', //
    'ToggleSmartshift', 'ToggleHiresScroll', 'CycleDPI', 'ChangeDPI',
    'ChangeHost', 'ChangeProfile', 'Gestures', 'Bogus',
  ];

  LcValue _action({bool allowGestures = false}) {
    if (_p(5)) return _junk();
    // Buttons get Gestures often: it is the most used (and richest) action.
    final type = allowGestures && _p(35) ? 'Gestures' : _pick(_types);
    final t = type == 'Gestures' && !allowGestures && _p(70)
        ? 'Keypress'
        : type;
    return _group(_r, [
      if (_p(95)) LcSetting('type', _p(95) ? LcString.fromText(t) : _junk()),
      ...switch (t.toLowerCase()) {
        'keypress' => [
          if (_p(90))
            LcSetting(
              'keys',
              _pick<LcValue Function()>([
                () => LcString.fromText('KEY_A'),
                () => LcInt(30),
                () => LcArray([
                  LcString.fromText('KEY_LEFTCTRL'),
                  LcString.fromText('KEY_C'),
                ]),
                () =>
                    LcList([LcString.fromText('KEY_A'), LcInt(30), LcFloat(1)]),
                _junk,
              ])(),
            ),
        ],
        'cycledpi' => [
          if (_p(80))
            LcSetting('dpis', _maybe(() => LcArray([LcInt(400), LcInt(800)]))),
          if (_p(30)) LcSetting('sensor', _maybe(() => LcInt(0))),
        ],
        'changedpi' => [
          if (_p(80)) LcSetting('inc', _maybe(() => LcInt(_pick([-100, 100])))),
          if (_p(30)) LcSetting('sensor', _maybe(() => LcInt(0))),
        ],
        'changehost' => [
          if (_p(85))
            LcSetting(
              'host',
              _pick<LcValue Function()>([
                () => LcInt(_pick([1, 2, 3])),
                () => LcString.fromText(_pick(['next', 'prev', 'Previous'])),
                _junk,
              ])(),
            ),
        ],
        'changeprofile' => [
          if (_p(85))
            LcSetting(
              'profile',
              _maybe(() => LcString.fromText(_pick(['work', 'default']))),
            ),
        ],
        'gestures' => [
          if (_p(90)) LcSetting('gestures', _sequenceOf(_directional, max: 5)),
        ],
        _ => [if (_p(20)) LcSetting('keys', _junk())],
      },
      if (_p(8)) LcSetting('note', _junk()),
    ]);
  }

  LcValue _directional() => _p(5)
      ? _junk()
      : _group(_r, [
          if (_p(93))
            LcSetting(
              'direction',
              _p(92)
                  ? LcString.fromText(
                      _pick([
                        'Up',
                        'up',
                        'Down',
                        'Left',
                        'Right',
                        'None',
                        'NONE',
                        'Diagonal',
                      ]),
                    )
                  : _junk(),
            ),
          ..._gestureFields(),
        ]);

  LcValue _gesture() => _p(5) ? _junk() : _group(_r, _gestureFields());

  static const _modes = [
    'NoPress', 'Axis', 'OnInterval', 'oninterval', 'OnFewPixels', //
    'OnRelease', 'OnThreshold', 'Bogus',
  ];

  List<LcSetting> _gestureFields() {
    final mode = _pick(_modes);
    return [
      if (_p(95)) LcSetting('mode', _p(95) ? LcString.fromText(mode) : _junk()),
      if (_p(30))
        LcSetting('threshold', _maybe(() => LcInt(_pick([10, 50, 100])))),
      if (_p(60)) LcSetting('interval', _maybe(() => LcInt(_pick([1, 3, 10])))),
      if (_p(70)) LcSetting('action', _action(allowGestures: _p(10))),
      if (_p(25))
        LcSetting('axis', _maybe(() => LcString.fromText('REL_WHEEL'))),
      if (_p(20))
        LcSetting('axis_multiplier', _maybe(() => LcFloat(_pick([0.5, 2.0])))),
      if (_p(8)) LcSetting('note', _junk()),
    ];
  }
}

/// Random valid models (for encode → decode round trips).
final class ModelGenerator {
  /// Creates a generator with a fixed [seed].
  ModelGenerator(int seed) : _r = Random(seed);

  final Random _r;

  bool _p(int percent) => _r.nextInt(100) < percent;
  T _pick<T>(List<T> items) => items[_r.nextInt(items.length)];
  int? _opt(List<int> values) => _p(60) ? _pick(values) : null;
  bool? _optBool() => _p(60) ? _p(50) : null;

  List<LcSetting> _extras() => [
    if (_p(10)) LcSetting('note', LcString.fromText('kept')),
    if (_p(5)) LcSetting('x-custom', LcArray([LcInt(1), LcInt(2)])),
  ];

  /// A random valid configuration.
  LogidConfig config() {
    final names = ([
      'MX Master 3S',
      'M720',
      'MX Anywhere 3',
      'Ergo',
    ]..shuffle(_r)).take(_r.nextInt(3));
    return LogidConfig(
      devices: _p(90) ? [for (final n in names) _device(n)] : null,
      ignore: _p(20)
          ? ({for (var i = 0; i < 3; i++) _r.nextInt(0x10000)}.toList())
          : null,
      ioTimeout: _p(20) ? _pick([500.0, 250.5, 1e3]) : null,
      workers: _opt([1, 4, 8]),
      extra: _extras(),
    );
  }

  DeviceConfig _device(String name) {
    final flat = _p(50);
    final profileNames = flat
        ? ['default']
        : ([
            'default',
            'work',
            'game',
            'Padrão',
          ]..shuffle(_r)).take(1 + _r.nextInt(3)).toList();
    return DeviceConfig(
      name: name,
      defaultProfile: flat ? 'default' : _pick([...profileNames, 'missing']),
      profiles: [for (final n in profileNames) _profile(n)],
      extra: flat ? const [] : _extras(),
    );
  }

  Profile _profile(String name) => Profile(
    name: name,
    dpi: switch (_r.nextInt(4)) {
      0 => FixedDpi(_pick([400, 1600, 8000])),
      1 => PerSensorDpi([for (var i = 0; i < _r.nextInt(3); i++) 800]),
      _ => null,
    },
    smartShift: _p(50)
        ? SmartShiftConfig(
            on: _optBool(),
            threshold: _opt([1, 20, 255, 0xFFFFFFFF]),
            torque: _opt([1, 50, 100]),
            extra: _extras(),
          )
        : null,
    hiresScroll: _p(40)
        ? HiresScrollConfig(
            hires: _optBool(),
            invert: _optBool(),
            target: _optBool(),
            up: _p(30) ? _gesture() : null,
            down: _p(30) ? _gesture() : null,
            extra: _extras(),
          )
        : null,
    thumbWheel: _p(40)
        ? ThumbWheelConfig(
            divert: _optBool(),
            invert: _optBool(),
            left: _p(50) ? _gesture() : null,
            right: _p(50) ? _gesture() : null,
            proxy: _p(20) ? _basic() : null,
            touch: _p(20) ? _basic() : null,
            tap: _p(30) ? _basic() : null,
            extra: _extras(),
          )
        : null,
    buttons: _p(70)
        ? [
            for (final cid in ([
              0x52,
              0x53,
              0x56,
              0xc3,
              0xc4,
              0xd7,
            ]..shuffle(_r)).take(_r.nextInt(4)))
              ButtonConfig(
                cid: cid,
                action: _p(85) ? (_p(30) ? _gestures() : _basic()) : null,
                extra: _extras(),
              ),
          ]
        : null,
    extra: _extras(),
  );

  BasicAction _basic() => switch (_r.nextInt(8)) {
    0 => NoneAction(extra: _extras()),
    1 => KeypressAction(
      keys: _p(90)
          ? [
              for (var i = 0; i < _r.nextInt(4); i++)
                _p(80)
                    ? KeyName(_pick(['KEY_A', 'KEY_LEFTCTRL', 'KEY_TAB']))
                    : KeyCode(_pick([30, 0xFFFFFFFF])),
            ]
          : null,
      extra: _extras(),
    ),
    2 => ToggleSmartShiftAction(),
    3 => ToggleHiresScrollAction(),
    4 => CycleDpiAction(
      dpis: _p(80) ? [400, 800, 1600] : null,
      sensor: _opt([0, 1]),
    ),
    5 => ChangeDpiAction(inc: _opt([-200, 200]), sensor: _opt([0])),
    6 => ChangeHostAction(
      host: _p(80)
          ? (_p(50)
                ? HostNumber(_pick([1, 2, 3]))
                : HostKeyword(_pick(['next', 'prev'])))
          : null,
    ),
    _ => ChangeProfileAction(
      profile: _p(80) ? _pick(['work', 'default']) : null,
    ),
  };

  GesturesAction _gestures() => GesturesAction(
    gestures: _p(90)
        ? [
            for (final d in ([
              'Up',
              'Down',
              'Left',
              'Right',
              'None',
            ]..shuffle(_r)).take(_r.nextInt(6)))
              DirectionalGesture(_p(80) ? d : d.toLowerCase(), _gesture()),
          ]
        : null,
    extra: _extras(),
  );

  Gesture _gesture() => switch (_r.nextInt(5)) {
    0 => NoPressGesture(threshold: _opt([10, 50])),
    1 => AxisGesture(
      threshold: _opt([50]),
      axis: _p(70)
          ? (_p(70) ? const AxisName('REL_WHEEL') : AxisCode(8))
          : null,
      axisMultiplier: _p(50) ? _pick([0.5, 2.0, -1.0]) : null,
    ),
    2 => IntervalGesture(
      threshold: _opt([0, 50]),
      action: _p(80) ? _basic() : null,
      interval: _opt([1, 3, 10]),
      fewPixels: _p(30),
      extra: _extras(),
    ),
    3 => ReleaseGesture(
      threshold: _opt([50]),
      action: _p(80) ? _basic() : null,
    ),
    _ => ThresholdGesture(
      threshold: _opt([50]),
      action: _p(80) ? _basic() : null,
    ),
  };
}
