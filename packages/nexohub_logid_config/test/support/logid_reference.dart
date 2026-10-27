// Runs logid 0.3.5's own config decoder (tool/logid_config_check) and encodes
// this package's model in the same JSON shape, so both can be compared.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';

/// Path of the binary built by `tool/logid_config_check/build.sh`.
final logidBinary = File(
  '${Directory.current.path}/../../tool/logid_config_check/build/logid_config_check',
);

/// Skip reason for logid differential tests, or null when they can run.
String? get logidSkipReason {
  final required = Platform.environment['NEXO_REQUIRE_LIBCONFIG_CHECK'] == '1';
  if (logidBinary.existsSync() || required) return null;
  return 'logid decoder not built: run tool/logid_config_check/build.sh';
}

/// What logid understood from one input.
final class LogidResult {
  LogidResult._(this.decoded, this.loggedLines, this.parseError);

  /// The decoded config (without the log), or null on a parse error.
  final Map<String, Object?>? decoded;

  /// Line numbers of "Error at line N" warnings, in order.
  final List<int> loggedLines;

  /// libconfig parse error text, when the file is not valid libconfig.
  final String? parseError;
}

/// Decodes every input with logid's code, in batches.
Future<List<LogidResult>> logidDecode(List<List<int>> inputs) async {
  final dir = await Directory.systemTemp.createTemp('nexo_logid_diff_');
  try {
    final paths = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      final f = File('${dir.path}/$i.cfg');
      await f.writeAsBytes(inputs[i]);
      paths.add(f.path);
    }
    final results = <LogidResult>[];
    for (var start = 0; start < paths.length; start += 400) {
      final end = start + 400 > paths.length ? paths.length : start + 400;
      final run = await Process.run(
        logidBinary.path,
        paths.sublist(start, end),
        stdoutEncoding: utf8,
      );
      if (run.exitCode != 0) throw StateError('harness failed: ${run.stderr}');
      for (final line in const LineSplitter().convert(run.stdout as String)) {
        final json = jsonDecode(line) as Map<String, Object?>;
        final ok = json['ok'] as Map<String, Object?>?;
        if (ok == null) {
          final error = json['error'] as Map<String, Object?>;
          results.add(LogidResult._(null, const [], error['text'] as String));
          continue;
        }
        final log = (ok.remove('log')! as List).cast<String>();
        results.add(
          LogidResult._(ok, [
            for (final l in log)
              int.parse(RegExp(r'line (\d+)').firstMatch(l)!.group(1)!),
          ], null),
        );
      }
    }
    return results;
  } finally {
    await dir.delete(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// Model → harness JSON (same keys, same order, std::map ordering)
// ---------------------------------------------------------------------------

/// Encodes [c] exactly like logid_config_check prints a decoded config.
Map<String, Object?> toLogidJson(LogidConfig c) => {
  'devices': c.devices == null
      ? null
      : [
          for (final d in _sorted(
            c.devices!,
            (d) => _bytes(d.name),
            _compareBytes,
          ))
            {
              'name': _hex(d.name),
              'default_profile': _hex(d.defaultProfile),
              'profiles': [
                for (final p in _sorted(
                  d.profiles,
                  (p) => _bytes(p.name),
                  _compareBytes,
                ))
                  [_hex(p.name), _profile(p)],
              ],
            },
        ],
  'ignore': c.ignore == null ? null : ([...c.ignore!]..sort()),
  'io_timeout': c.ioTimeout == null ? null : _bits(c.ioTimeout!),
  'workers': c.workers,
};

Map<String, Object?> _profile(Profile p) => {
  'dpi': switch (p.dpi) {
    null => null,
    FixedDpi(:final value) => {'int': value},
    PerSensorDpi(:final values) => {'list': values},
  },
  'smartshift': p.smartShift == null
      ? null
      : {
          'on': p.smartShift!.on,
          'threshold': p.smartShift!.threshold,
          'torque': p.smartShift!.torque,
        },
  'hiresscroll': p.hiresScroll == null
      ? null
      : {
          'hires': p.hiresScroll!.hires,
          'invert': p.hiresScroll!.invert,
          'target': p.hiresScroll!.target,
          'up': _gesture(p.hiresScroll!.up),
          'down': _gesture(p.hiresScroll!.down),
        },
  'thumbwheel': p.thumbWheel == null
      ? null
      : {
          'divert': p.thumbWheel!.divert,
          'invert': p.thumbWheel!.invert,
          'left': _gesture(p.thumbWheel!.left),
          'right': _gesture(p.thumbWheel!.right),
          'proxy': _action(p.thumbWheel!.proxy),
          'touch': _action(p.thumbWheel!.touch),
          'tap': _action(p.thumbWheel!.tap),
        },
  'buttons': p.buttons == null
      ? null
      : [
          for (final b in _sorted(p.buttons!, (b) => b.cid, (a, b) => a - b))
            [b.cid, _action(b.action)],
        ],
};

Object? _action(LogidAction? a) => switch (a) {
  null => null,
  NoneAction() => {'type': 'none'},
  KeypressAction(:final keys) => {
    'type': 'keypress',
    'keys': keys == null
        ? null
        : [
            for (final k in keys)
              switch (k) {
                KeyCode(:final code) => {'code': code},
                KeyName(:final name) => {'name': _hex(name)},
              },
          ],
  },
  ToggleSmartShiftAction() => {'type': 'togglesmartshift'},
  ToggleHiresScrollAction() => {'type': 'togglehiresscroll'},
  CycleDpiAction(:final dpis, :final sensor) => {
    'type': 'cycledpi',
    'dpis': dpis,
    'sensor': sensor,
  },
  ChangeDpiAction(:final inc, :final sensor) => {
    'type': 'changedpi',
    'inc': inc,
    'sensor': sensor,
  },
  ChangeHostAction(:final host) => {
    'type': 'changehost',
    'host': switch (host) {
      null => null,
      HostNumber(:final number) => {'int': number},
      HostKeyword(:final keyword) => {'string': _hex(keyword)},
    },
  },
  ChangeProfileAction(:final profile) => {
    'type': 'changeprofile',
    'profile': profile == null ? null : _hex(profile),
  },
  GesturesAction(:final gestures) => {
    'type': 'gestures',
    'gestures': gestures == null
        ? null
        : [
            for (final g in _sorted(
              gestures,
              (g) => _bytes(g.direction),
              _compareCaseless,
            ))
              [_hex(g.direction), _gesture(g.gesture)],
          ],
  },
};

Object? _gesture(Gesture? g) => switch (g) {
  null => null,
  NoPressGesture(:final threshold) => {
    'mode': 'nopress',
    'threshold': threshold,
  },
  AxisGesture(:final threshold, :final axis, :final axisMultiplier) => {
    'mode': 'axis',
    'threshold': threshold,
    'axis': switch (axis) {
      null => null,
      AxisName(:final name) => {'name': _hex(name)},
      AxisCode(:final code) => {'code': code},
    },
    'axis_multiplier': axisMultiplier == null ? null : _bits(axisMultiplier),
  },
  IntervalGesture(
    :final threshold,
    :final action,
    :final interval,
    :final fewPixels,
  ) =>
    {
      'mode': fewPixels ? 'onfewpixels' : 'oninterval',
      'threshold': threshold,
      'action': _action(action),
      'interval': interval,
    },
  ReleaseGesture(:final threshold, :final action) => {
    'mode': 'onrelease',
    'threshold': threshold,
    'action': _action(action),
  },
  ThresholdGesture(:final threshold, :final action) => {
    'mode': 'onthreshold',
    'threshold': threshold,
    'action': _action(action),
  },
};

List<T> _sorted<T, K>(
  List<T> items,
  K Function(T) key,
  int Function(K, K) compare,
) => [...items]..sort((a, b) => compare(key(a), key(b)));

List<int> _bytes(String s) => utf8.encode(s);

String _hex(String s) =>
    _bytes(s).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _bits(double d) =>
    BigInt.from((ByteData(8)..setFloat64(0, d)).getUint64(0))
        .toUnsigned(64)
        .toRadixString(16)
        .padLeft(16, '0');

/// std::less<std::string>: unsigned byte comparison.
int _compareBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

/// logid's less_caseless on `char` (signed on x86): bytes ≥ 0x80 sort first.
int _compareCaseless(List<int> a, List<int> b) {
  int lower(int byte) {
    final c = byte >= 0x80 ? byte - 256 : byte;
    return c >= 0x41 && c <= 0x5A ? c + 0x20 : c;
  }

  for (var i = 0; i < a.length && i < b.length; i++) {
    final x = lower(a[i]), y = lower(b[i]);
    if (x != y) return x - y;
  }
  return a.length - b.length;
}

/// Lines our decoder says logid logs, sorted (logid's order may differ).
List<int> loggedLinesOf(DecodeResult r) => [
  for (final i in r.issues)
    if (i.loggedByLogid) i.position!.line,
]..sort();

/// Bytes of [text] (helper for building inputs).
Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));
