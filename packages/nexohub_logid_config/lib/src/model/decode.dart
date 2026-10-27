// Decodes a libconfig tree into the typed model, reproducing logid 0.3.5's
// config_io rules (src/logid/config/types.h, group.h) — and therefore what
// the daemon really applies. Checked against logid's own code by
// test/model/differential_test.dart (tool/logid_config_check).
//
// Rules mirrored here:
// * Scalars are strictly typed (libconfig auto-convert is off): `dpi: 1600L`
//   is not an int, `io_timeout: 500` is not a float.
// * optional<T> fields: absent → null; undecodable → logid logs
//   "Error at line N" and ignores the field ([DecodeIssueCode.fieldIgnored]).
// * list/set/map elements that fail are dropped silently; for maps the
//   first key wins. GCC evaluates the value before the key, so a dropped
//   element still logs its own field errors.
// * "Lists" accept list, array or group children; a scalar is an empty list.
// * Groups decoded from a non-group value have every field absent.
// * variant<…> alternatives are tried in declaration order.
import '../libconfig/ast.dart';
import '../libconfig/parser.dart';
import 'model.dart';

/// Why part of a configuration was changed or dropped while decoding.
enum DecodeIssueCode {
  /// An optional field logid cannot decode: logid logs a warning and
  /// ignores it. Nexo drops it.
  fieldIgnored,

  /// A list/map element logid drops silently (wrong type, missing key, …).
  elementIgnored,

  /// An element whose key already exists; logid keeps the first one.
  duplicateIgnored,

  /// A value logid reinterprets: 16/32-bit truncation, non-list read as an
  /// empty list, non-group read as an empty group, profile normalization.
  valueReinterpreted,

  /// `profiles` without a valid string `default_profile`: logid falls back
  /// to the flat form and ignores every profile.
  profilesIgnored,

  /// A key logid knows elsewhere but ignores at this place. Dropped.
  keyIgnored,

  /// A key logid 0.3.5 does not know at all. Preserved as-is.
  unknownKey,
}

/// One finding of the decoder.
final class DecodeIssue {
  /// Creates an issue.
  const DecodeIssue(this.code, this.path, this.position, this.message);

  /// Machine-readable reason (the UI translates it).
  final DecodeIssueCode code;

  /// Where in the configuration, e.g. `devices["MX Master 3S"].dpi`.
  final String path;

  /// Source position of the offending setting or value, when known.
  final SourcePosition? position;

  /// English description, for logs.
  final String message;

  /// Whether logid itself prints a warning for this (the rest is silent).
  bool get loggedByLogid => code == DecodeIssueCode.fieldIgnored;

  /// Whether saving the decoded model changes the file content here
  /// (everything except preserved unknown keys).
  bool get changesOnSave => code != DecodeIssueCode.unknownKey;

  @override
  String toString() => '${code.name} at $path ($position): $message';
}

/// A decoded configuration plus everything the decoder had to change.
final class DecodeResult {
  /// Creates a result.
  const DecodeResult(this.config, this.issues);

  /// What logid applies.
  final LogidConfig config;

  /// Findings, in document order.
  final List<DecodeIssue> issues;
}

/// Decodes a parsed `logid.cfg`.
DecodeResult decodeLogidConfig(LcGroup root) {
  final decoder = _Decoder();
  final config = decoder.config(root);
  return DecodeResult(config, List.unmodifiable(decoder.issues));
}

/// Parses and decodes `logid.cfg` text. Throws `LibconfigSyntaxError` when
/// the text is not valid libconfig (logid would refuse to start).
DecodeResult parseLogidConfig(String text) =>
    decodeLogidConfig(parseLibconfig(text));

/// Thrown where logid's decoder throws a libconfig SettingException.
final class _Fail implements Exception {
  const _Fail(this.reason);
  final String reason;
}

final class _Decoder {
  final issues = <DecodeIssue>[];

  void _issue(
    DecodeIssueCode code,
    String path,
    SourcePosition? position,
    String message,
  ) => issues.add(DecodeIssue(code, path, position, message));

  // ---- primitives (strict, like libconfig Setting conversions) -------------

  static String _typeOf(LcValue v) => v.kind.name;

  int _int(LcValue v) => v is LcInt
      ? v.value
      : throw _Fail('expected an int, found ${_typeOf(v)}');

  int _uint32(LcValue v, String path) => _int(v).toUnsigned(32);

  bool _bool(LcValue v) => v is LcBool
      ? v.value
      : throw _Fail('expected a boolean, found ${_typeOf(v)}');

  double _double(LcValue v) => v is LcFloat
      ? v.value
      : throw _Fail('expected a float, found ${_typeOf(v)}');

  String _string(LcValue v) => v is LcString
      ? v.text
      : throw _Fail('expected a string, found ${_typeOf(v)}');

  /// `optional<T>`: absent → null; failure → logged by logid, field ignored.
  T? _optional<T>(
    LcGroup? group,
    String key,
    String path,
    T Function(LcValue value, String path) decode,
  ) {
    if (group == null) return null;
    for (final s in group.settings) {
      if (s.name != key) continue;
      final fieldPath = '$path.$key';
      try {
        return decode(s.value, fieldPath);
      } on _Fail catch (f) {
        _issue(
          DecodeIssueCode.fieldIgnored,
          fieldPath,
          s.position,
          '${f.reason}; logid logs a warning and ignores it',
        );
        return null;
      }
    }
    return null;
  }

  /// Children of a list-like value (list, array, or group settings).
  List<LcValue> _elements(LcValue v, String path) => switch (v) {
    LcList(:final elements) || LcArray(:final elements) => elements,
    LcGroup(:final settings) => [for (final s in settings) s.value],
    _ => () {
      _issue(
        DecodeIssueCode.valueReinterpreted,
        path,
        v.position,
        '${_typeOf(v)} where a list is expected; logid reads an empty list',
      );
      return const <LcValue>[];
    }(),
  };

  /// The group a struct is decoded from; a non-group has no fields.
  LcGroup? _asGroup(LcValue v, String path) {
    if (v is LcGroup) return v;
    _issue(
      DecodeIssueCode.valueReinterpreted,
      path,
      v.position,
      '${_typeOf(v)} where a group is expected; logid reads it as empty',
    );
    return null;
  }

  /// Splits unknown settings into preserved extras / dropped keys.
  List<LcSetting> _extras(
    LcGroup? group,
    String path,
    Set<String> known, {
    Set<String> ignored = const {},
  }) {
    final extra = <LcSetting>[];
    for (final s in group?.settings ?? const <LcSetting>[]) {
      if (known.contains(s.name)) continue;
      if (ignored.contains(s.name)) {
        _issue(
          DecodeIssueCode.keyIgnored,
          '$path.${s.name}',
          s.position,
          'logid ignores "${s.name}" here',
        );
      } else {
        _issue(
          DecodeIssueCode.unknownKey,
          '$path.${s.name}',
          s.position,
          'unknown to logid 0.3.5; kept as-is',
        );
        extra.add(s);
      }
    }
    return extra;
  }

  /// `map<K, V>`: value decoded first (GCC order), then key; first key wins.
  List<T> _map<K, T>({
    required LcValue value,
    required String path,
    required String keyName,
    required K Function(LcValue key) decodeKey,
    required T Function(LcGroup element, String elementPath) decodeValue,
    required Object Function(K key) identity,
    required String Function(K key) label,
  }) {
    final result = <T>[];
    final seen = <Object>{};
    final elements = _elements(value, path);
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      final elementPath = '$path[$i]';
      if (e is! LcGroup) {
        _issue(
          DecodeIssueCode.elementIgnored,
          elementPath,
          e.position,
          '${_typeOf(e)} is not a group with "$keyName"; logid drops it',
        );
        continue;
      }
      final keySetting = e.settings.where((s) => s.name == keyName).firstOrNull;
      T? decoded;
      String? valueError;
      try {
        decoded = decodeValue(e, elementPath);
      } on _Fail catch (f) {
        valueError = f.reason;
      }
      K key;
      try {
        if (keySetting == null) throw _Fail('missing "$keyName"');
        key = decodeKey(keySetting.value);
      } on _Fail catch (f) {
        _issue(
          DecodeIssueCode.elementIgnored,
          elementPath,
          e.position,
          '${f.reason}; logid drops this element',
        );
        continue;
      }
      if (valueError != null) {
        _issue(
          DecodeIssueCode.elementIgnored,
          '$path[${label(key)}]',
          e.position,
          '$valueError; logid drops this element',
        );
        continue;
      }
      if (!seen.add(identity(key))) {
        _issue(
          DecodeIssueCode.duplicateIgnored,
          '$path[${label(key)}]',
          e.position,
          'duplicate ${label(key)}; logid keeps the first one',
        );
        continue;
      }
      result.add(decoded as T);
    }
    return result;
  }

  // ---- top level ----------------------------------------------------------

  LogidConfig config(LcGroup root) {
    const path = r'$';
    final devices = _optional(
      root,
      'devices',
      path,
      (v, p) => _map<String, DeviceConfig>(
        value: v,
        path: p,
        keyName: 'name',
        decodeKey: _string,
        decodeValue: _device,
        identity: (k) => k,
        label: (k) => '"$k"',
      ),
    );
    final ignore = _optional(root, 'ignore', path, (v, p) {
      final pids = <int>[];
      final elements = _elements(v, p);
      for (var i = 0; i < elements.length; i++) {
        final e = elements[i];
        if (e is! LcInt) {
          _issue(
            DecodeIssueCode.elementIgnored,
            '$p[$i]',
            e.position,
            '${_typeOf(e)} is not an int; logid drops it',
          );
          continue;
        }
        final pid = _uint16(e, '$p[$i]');
        if (pids.contains(pid)) {
          _issue(
            DecodeIssueCode.duplicateIgnored,
            '$p[$i]',
            e.position,
            'duplicate product ID',
          );
        } else {
          pids.add(pid);
        }
      }
      return pids;
    });
    return LogidConfig(
      devices: devices,
      ignore: ignore,
      ioTimeout: _optional(root, 'io_timeout', path, (v, _) => _double(v)),
      workers: _optional(root, 'workers', path, (v, _) => _int(v)),
      extra: _extras(root, path, LogidConfig.knownKeys),
    );
  }

  /// Text of a key that is validated separately (non-strings → '').
  static String _textOrEmpty(LcValue? v) => v is LcString ? v.text : '';

  int _uint16(LcInt v, String path) {
    final truncated = v.value & 0xFFFF;
    if (truncated != v.value) {
      _issue(
        DecodeIssueCode.valueReinterpreted,
        path,
        v.position,
        '${v.value} does not fit 16 bits; logid uses $truncated',
      );
    }
    return truncated;
  }

  // ---- devices --------------------------------------------------------------

  /// `variant<Device, Profile>` + `Device::_getConfig` normalization.
  DeviceConfig _device(LcGroup g, String path) {
    final name = _textOrEmpty(g['name']);
    final defaultProfile = g['default_profile'];
    final profilesValue = g['profiles'];
    // Device alternative: `default_profile` (string) then `profiles` must
    // both be readable; otherwise logid falls back to the flat Profile form.
    if (defaultProfile is LcString && profilesValue != null) {
      final profiles = _map<String, Profile>(
        value: profilesValue,
        path: '$path.profiles',
        keyName: 'name',
        decodeKey: _string,
        decodeValue: (e, p) => _profile(e, p, _textOrEmpty(e['name'])),
        identity: (k) => k,
        label: (k) => '"$k"',
      );
      final extra = _extras(g, path, const {
        'name',
        'default_profile',
        'profiles',
      }, ignored: Profile.fieldKeys);
      if (profiles.isEmpty) {
        _issue(
          DecodeIssueCode.valueReinterpreted,
          '$path.profiles',
          profilesValue.position,
          'no valid profile; logid uses an empty profile "default"',
        );
        return DeviceConfig(
          name: name,
          defaultProfile: 'default',
          profiles: [Profile(name: 'default')],
          extra: extra,
        );
      }
      return DeviceConfig(
        name: name,
        defaultProfile: defaultProfile.text,
        profiles: profiles,
        extra: extra,
      );
    }
    if (profilesValue != null || defaultProfile != null) {
      _issue(
        DecodeIssueCode.profilesIgnored,
        path,
        g.position,
        profilesValue == null
            ? '"default_profile" without "profiles"; logid ignores it'
            : '"profiles" needs a string "default_profile"; logid ignores '
                  'every profile and uses the settings outside them',
      );
    }
    return DeviceConfig(
      name: name,
      defaultProfile: 'default',
      profiles: [_profile(g, path, 'default')],
    );
  }

  Profile _profile(LcGroup g, String path, String name) {
    return Profile(
      name: name,
      dpi: _optional(g, 'dpi', path, _dpi),
      smartShift: _optional(g, 'smartshift', path, _smartShift),
      hiresScroll: _optional(g, 'hiresscroll', path, _hiresScroll),
      thumbWheel: _optional(g, 'thumbwheel', path, _thumbWheel),
      buttons: _optional(
        g,
        'buttons',
        path,
        (v, p) => _map<int, ButtonConfig>(
          value: v,
          path: p,
          keyName: 'cid',
          decodeKey: (k) => k is LcInt
              ? _uint16(k, '$p.cid')
              : throw _Fail('"cid" must be an int, found ${_typeOf(k)}'),
          decodeValue: _button,
          identity: (k) => k,
          label: (k) => '0x${k.toRadixString(16)}',
        ),
      ),
      extra: _extras(
        g,
        path,
        {'name', ...Profile.fieldKeys},
        ignored: const {'profiles', 'default_profile'},
      ),
    );
  }

  // ---- features ---------------------------------------------------------------

  /// `variant<int, list<int>>`.
  DpiSetting _dpi(LcValue v, String path) {
    if (v is LcInt) return FixedDpi(v.value);
    return PerSensorDpi(_intList(v, path));
  }

  List<int> _intList(LcValue v, String path) {
    final values = <int>[];
    final elements = _elements(v, path);
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (e is LcInt) {
        values.add(e.value);
      } else {
        _issue(
          DecodeIssueCode.elementIgnored,
          '$path[$i]',
          e.position,
          '${_typeOf(e)} is not an int; logid drops it',
        );
      }
    }
    return values;
  }

  SmartShiftConfig _smartShift(LcValue v, String path) {
    final g = _asGroup(v, path);
    return SmartShiftConfig(
      on: _optional(g, 'on', path, (v, _) => _bool(v)),
      threshold: _optional(g, 'threshold', path, _uint32),
      torque: _optional(g, 'torque', path, _uint32),
      extra: _extras(g, path, SmartShiftConfig.knownKeys),
    );
  }

  /// `variant<bool, HiresScroll>`.
  HiresScrollConfig _hiresScroll(LcValue v, String path) {
    if (v is LcBool) return HiresScrollConfig(hires: v.value);
    final g = _asGroup(v, path);
    return HiresScrollConfig(
      hires: _optional(g, 'hires', path, (v, _) => _bool(v)),
      invert: _optional(g, 'invert', path, (v, _) => _bool(v)),
      target: _optional(g, 'target', path, (v, _) => _bool(v)),
      up: _optional(g, 'up', path, _gesture),
      down: _optional(g, 'down', path, _gesture),
      extra: _extras(g, path, HiresScrollConfig.knownKeys),
    );
  }

  ThumbWheelConfig _thumbWheel(LcValue v, String path) {
    final g = _asGroup(v, path);
    return ThumbWheelConfig(
      divert: _optional(g, 'divert', path, (v, _) => _bool(v)),
      invert: _optional(g, 'invert', path, (v, _) => _bool(v)),
      left: _optional(g, 'left', path, _gesture),
      right: _optional(g, 'right', path, _gesture),
      proxy: _optional(g, 'proxy', path, _basicAction),
      touch: _optional(g, 'touch', path, _basicAction),
      tap: _optional(g, 'tap', path, _basicAction),
      extra: _extras(g, path, ThumbWheelConfig.knownKeys),
    );
  }

  ButtonConfig _button(LcGroup g, String path) {
    final cid = g['cid'];
    return ButtonConfig(
      cid: cid is LcInt ? cid.value & 0xFFFF : 0,
      action: _optional(g, 'action', path, _action),
      extra: _extras(g, path, ButtonConfig.knownKeys),
    );
  }

  // ---- actions ----------------------------------------------------------------

  static const _basicTypes = {
    'none', 'keypress', 'togglesmartshift', 'togglehiresscroll', //
    'cycledpi', 'changedpi', 'changehost', 'changeprofile',
  };

  /// signed_group lookup of `type`/`mode`, ASCII case-insensitive.
  String _signature(LcValue v, String field, Set<String> allowed) {
    if (v is! LcGroup) {
      throw _Fail('${_typeOf(v)} is not a group with "$field"');
    }
    final sign = v[field];
    if (sign == null) throw _Fail('missing "$field"');
    if (sign is! LcString) throw _Fail('"$field" must be a string');
    final normalized = asciiLowerCase(sign.text);
    if (!allowed.contains(normalized)) {
      throw _Fail('unknown $field "${sign.text}"');
    }
    return normalized;
  }

  LogidAction _action(LcValue v, String path) {
    final type = _signature(v, 'type', {..._basicTypes, 'gestures'});
    final g = v as LcGroup;
    if (type != 'gestures') return _basicOf(type, g, path);
    return GesturesAction(
      gestures: _optional(
        g,
        'gestures',
        path,
        (v, p) => _map<String, DirectionalGesture>(
          value: v,
          path: p,
          keyName: 'direction',
          decodeKey: _string,
          decodeValue: (e, ep) => DirectionalGesture(
            _textOrEmpty(e['direction']),
            _gesture(e, ep, inGestureList: true),
          ),
          identity: asciiLowerCase,
          label: (k) => '"$k"',
        ),
      ),
      extra: _extras(g, path, const {'type', 'gestures'}),
    );
  }

  BasicAction _basicAction(LcValue v, String path) {
    final type = _signature(v, 'type', _basicTypes);
    return _basicOf(type, v as LcGroup, path);
  }

  BasicAction _basicOf(String type, LcGroup g, String path) {
    switch (type) {
      case 'none':
        return NoneAction(extra: _extras(g, path, const {'type'}));
      case 'keypress':
        return KeypressAction(
          keys: _optional(g, 'keys', path, _keys),
          extra: _extras(g, path, const {'type', 'keys'}),
        );
      case 'togglesmartshift':
        return ToggleSmartShiftAction(extra: _extras(g, path, const {'type'}));
      case 'togglehiresscroll':
        return ToggleHiresScrollAction(extra: _extras(g, path, const {'type'}));
      case 'cycledpi':
        return CycleDpiAction(
          dpis: _optional(g, 'dpis', path, _intList),
          sensor: _optional(g, 'sensor', path, (v, _) => _int(v)),
          extra: _extras(g, path, const {'type', 'dpis', 'sensor'}),
        );
      case 'changedpi':
        return ChangeDpiAction(
          inc: _optional(g, 'inc', path, (v, _) => _int(v)),
          sensor: _optional(g, 'sensor', path, (v, _) => _int(v)),
          extra: _extras(g, path, const {'type', 'inc', 'sensor'}),
        );
      case 'changehost':
        return ChangeHostAction(
          host: _optional(
            g,
            'host',
            path,
            (v, _) => switch (v) {
              LcInt(:final value) => HostNumber(value),
              LcString(:final text) => HostKeyword(text),
              _ => throw const _Fail('"host" must be an int or a string'),
            },
          ),
          extra: _extras(g, path, const {'type', 'host'}),
        );
      default: // changeprofile
        return ChangeProfileAction(
          profile: _optional(g, 'profile', path, (v, _) => _string(v)),
          extra: _extras(g, path, const {'type', 'profile'}),
        );
    }
  }

  /// `variant<string, uint, list<variant<uint, string>>>`.
  List<KeyRef> _keys(LcValue v, String path) {
    if (v is LcString) return [KeyName(v.text)];
    if (v is LcInt) return [KeyCode(v.value.toUnsigned(32))];
    final keys = <KeyRef>[];
    final elements = _elements(v, path);
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      switch (e) {
        case LcInt(:final value):
          keys.add(KeyCode(value.toUnsigned(32)));
        case LcString(:final text):
          keys.add(KeyName(text));
        default:
          _issue(
            DecodeIssueCode.elementIgnored,
            '$path[$i]',
            e.position,
            '${_typeOf(e)} is not a key name or code; logid drops it',
          );
      }
    }
    return keys;
  }

  // ---- gestures ------------------------------------------------------------

  static const _modes = {
    'nopress',
    'axis',
    'oninterval',
    'onfewpixels',
    'onrelease',
    'onthreshold', //
  };

  Gesture _gesture(LcValue v, String path, {bool inGestureList = false}) {
    final mode = _signature(v, 'mode', _modes);
    final g = v as LcGroup;
    final threshold = _optional(g, 'threshold', path, (v, _) => _int(v));
    final known = {'mode', 'threshold', if (inGestureList) 'direction'};
    List<LcSetting> extra(Set<String> fields) => _extras(g, path, {
      ...known,
      ...fields,
    }, ignored: inGestureList ? const {} : const {'direction'});
    switch (mode) {
      case 'nopress':
        return NoPressGesture(threshold: threshold, extra: extra(const {}));
      case 'axis':
        return AxisGesture(
          threshold: threshold,
          axis: _optional(
            g,
            'axis',
            path,
            (v, _) => switch (v) {
              LcString(:final text) => AxisName(text),
              LcInt(:final value) => AxisCode(value.toUnsigned(32)),
              _ => throw const _Fail('"axis" must be a string or an int'),
            },
          ),
          axisMultiplier: _optional(
            g,
            'axis_multiplier',
            path,
            (v, _) => _double(v),
          ),
          extra: extra(const {'axis', 'axis_multiplier'}),
        );
      case 'oninterval' || 'onfewpixels':
        return IntervalGesture(
          threshold: threshold,
          action: _optional(g, 'action', path, _basicAction),
          interval: _optional(g, 'interval', path, (v, _) => _int(v)),
          fewPixels: mode == 'onfewpixels',
          extra: extra(const {'action', 'interval'}),
        );
      case 'onrelease':
        return ReleaseGesture(
          threshold: threshold,
          action: _optional(g, 'action', path, _basicAction),
          extra: extra(const {'action'}),
        );
      default: // onthreshold
        return ThresholdGesture(
          threshold: threshold,
          action: _optional(g, 'action', path, _basicAction),
          extra: extra(const {'action'}),
        );
    }
  }
}
