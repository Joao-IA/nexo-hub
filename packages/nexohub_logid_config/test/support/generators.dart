// Seeded random inputs for property and differential tests.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';

/// Random valid trees (to test writer → parser round trips).
final class TreeGenerator {
  /// Creates a generator with a fixed [seed] for reproducible failures.
  TreeGenerator(int seed) : _r = Random(seed);

  final Random _r;

  static const _names = [
    'a', 'b', 'name', 'cid', 'x-1', '*', '*a', 'A_b', 'True1', 'devices', //
  ];

  /// A random root group.
  LcGroup document() => _group(0);

  LcGroup _group(int depth) {
    final names = (List.of(_names)..shuffle(_r)).take(_r.nextInt(5));
    return LcGroup([for (final n in names) LcSetting(n, _value(depth + 1))]);
  }

  LcValue _value(int depth) {
    final pick = _r.nextInt(depth > 4 ? 5 : 8);
    return switch (pick) {
      5 => _group(depth),
      6 => LcList([for (var i = 0; i < _r.nextInt(4); i++) _value(depth + 1)]),
      7 => _array(),
      _ => _scalar(LcKind.values[pick]),
    };
  }

  LcArray _array() {
    final kind = LcKind.values[_r.nextInt(5)];
    return LcArray([for (var i = 0; i < _r.nextInt(4); i++) _scalar(kind)]);
  }

  LcValue _scalar(LcKind kind) {
    final format = _r.nextBool() ? LcIntFormat.hex : LcIntFormat.decimal;
    return switch (kind) {
      LcKind.integer => LcInt(_int32(), format: format),
      LcKind.integer64 => LcInt64(_int64(), format: format),
      LcKind.float => LcFloat(_double()),
      LcKind.boolean => LcBool(_r.nextBool()),
      LcKind.string => LcString(_bytes()),
      _ => throw StateError('not a scalar: $kind'),
    };
  }

  int _int32() => switch (_r.nextInt(4)) {
    0 => const [0, -1, 1, -0x80000000, 0x7fffffff, 0xc3][_r.nextInt(6)],
    _ => _r.nextInt(1 << 32) - 0x80000000,
  };

  int _int64() => switch (_r.nextInt(3)) {
    0 => const [0, -1, -0x8000000000000000, 0x7fffffffffffffff][_r.nextInt(4)],
    _ => (_r.nextInt(1 << 32) << 32) | _r.nextInt(1 << 32),
  };

  double _double() {
    switch (_r.nextInt(3)) {
      case 0:
        const specials = [
          0.0, -0.0, 1.5, -2.25, 1e300, 5e-324, 1e21, 0.1, //
          double.infinity, double.negativeInfinity,
        ];
        return specials[_r.nextInt(specials.length)];
      case 1:
        return (_r.nextDouble() - 0.5) * pow(10, _r.nextInt(40) - 20);
      default:
        while (true) {
          final bits = ByteData(8)
            ..setUint32(0, _r.nextInt(1 << 32))
            ..setUint32(4, _r.nextInt(1 << 32));
          final d = bits.getFloat64(0);
          if (!d.isNaN) return d;
        }
    }
  }

  List<int> _bytes() => switch (_r.nextInt(3)) {
    0 => utf8.encode(
      const [
        '',
        'MX Master 3S',
        'Padrão',
        'KEY_LEFTCTRL',
        'a"b\\c',
        'tab\tnl\n',
        '😀',
      ][_r.nextInt(7)],
    ),
    _ => [for (var i = 0; i < _r.nextInt(12); i++) 1 + _r.nextInt(255)],
  };
}

/// Random libconfig-ish text: mostly well-formed with varied syntax, plus
/// byte-level mutations, to compare acceptance and results with libconfig.
final class TextGenerator {
  /// Creates a generator with a fixed [seed].
  TextGenerator(int seed) : _r = Random(seed);

  final Random _r;
  final _out = BytesBuilder();

  static const _names = ['a', 'b', 'x-1', '*', 'cid', 'A_b', 'True1', 'e5'];
  static const _blanks = [
    ' ', '', '\n', '\t', '  ', '\r\n', '\f', ' # c\n', ' // c\n', '/* c */', //
  ];
  static const _ints = [
    '0', '1', '-1', '+7', '00', '010', '0777', '08', '-010', '0x1f', '0X1F', //
    '0xffffffff', '0x100000001', '3000000000', '-2147483648', '2147483647',
    '2147483648', '9223372036854775807', '9223372036854775808',
    '-9223372036854775809', '5L', '5LL', '007L', '-3L', '0x1fL', '0x1FLL',
    '0xFFFFFFFFFFFFFFFFL', '0x1FFFFFFFFFFFFFFFFL', '99999999999999999999L',
  ];
  static const _floats = [
    '1.0', '.5', '5.', '-.5', '.', '-.', '+.e5', '1e5', '1E-5', '1.5e+300', //
    '1e999', '-0.0', '1.e3', '0.1', '1e', '1.5e', '-1.5E-10', '00.5', '08.5',
  ];
  static const _strings = [
    '""', '"a"', r'"\n\t\r\f"', r'"\x41\x4g"', r'"\q"', '"ç"', r'"a\"b"', //
    r'"\\"', r'"a\x00b"', '"multi\nline"', r'"\X7e"', '"unterminated',
  ];

  /// A new random input.
  Uint8List next() {
    _out.clear();
    _settings(0);
    final bytes = _out.toBytes();
    return _r.nextInt(10) < 3 ? _mutate(bytes) : bytes;
  }

  void _s(String text) => _out.add(utf8.encode(text));

  void _blank() => _s(_blanks[_r.nextInt(_blanks.length)]);

  void _settings(int depth) {
    for (var i = 0; i < _r.nextInt(4); i++) {
      _blank();
      _s(_names[_r.nextInt(_names.length)]);
      _blank();
      _s(_r.nextBool() ? '=' : ':');
      _blank();
      _value(depth + 1);
      _s(const [';', ',', '', ';'][_r.nextInt(4)]);
      _blank();
    }
  }

  void _value(int depth) {
    switch (_r.nextInt(depth > 3 ? 4 : 7)) {
      case 4:
        _s('{');
        _settings(depth);
        _s('}');
      case 5:
        _sequence('(', ')', () => _value(depth + 1));
      case 6:
        final kind = _r.nextInt(4);
        // Usually homogeneous; sometimes mixed to hit type errors.
        _sequence(
          '[',
          ']',
          () => _scalar(_r.nextInt(8) == 0 ? _r.nextInt(4) : kind),
        );
      default:
        _scalar(_r.nextInt(4));
    }
  }

  void _sequence(String open, String close, void Function() element) {
    _s(open);
    final n = _r.nextInt(4);
    for (var i = 0; i < n; i++) {
      _blank();
      element();
      _blank();
      if (i < n - 1 || _r.nextInt(4) == 0) _s(_r.nextInt(6) == 0 ? ',,' : ',');
    }
    _s(close);
  }

  void _scalar(int kind) {
    switch (kind) {
      case 0:
        _s(_ints[_r.nextInt(_ints.length)]);
      case 1:
        _s(_floats[_r.nextInt(_floats.length)]);
      case 2:
        _s(const ['true', 'FALSE', 'True', 'false'][_r.nextInt(4)]);
      default:
        _s(_strings[_r.nextInt(_strings.length)]);
        if (_r.nextInt(4) == 0) {
          _blank();
          _s(_strings[_r.nextInt(_strings.length - 1)]);
        }
        if (_r.nextInt(10) == 0) _out.add(const [0x22, 0xff, 0xc3, 0x22]);
    }
  }

  static const _noise = [
    0x7B, 0x7D, 0x5B, 0x5D, 0x28, 0x29, 0x3B, 0x2C, 0x3D, 0x3A, 0x22, 0x5C, //
    0x2E, 0x2D, 0x40, 0x23, 0x2F, 0x2A, 0x4C, 0x78, 0x30, 0x0A, 0x00, 0xFF,
  ];

  Uint8List _mutate(Uint8List input) {
    final bytes = List.of(input);
    for (var k = 0; k < 1 + _r.nextInt(3); k++) {
      final at = bytes.isEmpty ? 0 : _r.nextInt(bytes.length + 1);
      switch (_r.nextInt(3)) {
        case 0 when bytes.isNotEmpty && at < bytes.length:
          bytes.removeAt(at);
        case 1:
          bytes.insert(at, _noise[_r.nextInt(_noise.length)]);
        default:
          if (at < bytes.length) bytes[at] = _noise[_r.nextInt(_noise.length)];
      }
    }
    return Uint8List.fromList(bytes);
  }
}
