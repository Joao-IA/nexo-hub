// Syntax tree of a libconfig document.
//
// Mirrors the value model of libconfig 1.7.3 (the library logid links to):
// groups, lists, arrays and five scalar types. Constructors enforce the same
// invariants libconfig enforces while parsing (unique names inside a group,
// homogeneous arrays, 32-bit `int`), so a tree that can be built can always
// be written back as text that libconfig accepts.
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// A 1-based line/column position in the source text (columns count bytes).
final class SourcePosition {
  /// Creates a position.
  const SourcePosition(this.line, this.column);

  /// Line number, starting at 1.
  final int line;

  /// Column number in bytes, starting at 1.
  final int column;

  @override
  String toString() => '$line:$column';
}

/// The libconfig type of a value. Arrays may only hold one scalar kind.
enum LcKind {
  /// 32-bit signed integer (`TypeInt`).
  integer,

  /// 64-bit signed integer (`TypeInt64`, written with an `L` suffix).
  integer64,

  /// Double-precision float (`TypeFloat`).
  float,

  /// Boolean (`TypeBoolean`).
  boolean,

  /// Byte string (`TypeString`).
  string,

  /// Named settings (`TypeGroup`).
  group,

  /// Homogeneous scalar sequence (`TypeArray`).
  array,

  /// Heterogeneous sequence (`TypeList`).
  list;

  /// Whether values of this kind may appear inside an array.
  bool get isScalar => index <= LcKind.string.index;
}

/// Integer literal style, preserved so `cid: 0xc3` stays hexadecimal.
enum LcIntFormat {
  /// Base 10.
  decimal,

  /// Base 16 (`0x…`).
  hex,
}

/// A libconfig value. Equality is structural and ignores [position] and
/// integer [LcIntFormat]; floats compare by their exact bit pattern.
sealed class LcValue {
  const LcValue({this.position});

  /// Where the value started in the parsed text, when it came from a parser.
  final SourcePosition? position;

  /// The libconfig type of this value.
  LcKind get kind;
}

/// A 32-bit signed integer.
final class LcInt extends LcValue {
  /// Creates an integer; throws [RangeError] outside the 32-bit range.
  LcInt(this.value, {this.format = LcIntFormat.decimal, super.position}) {
    RangeError.checkValueInInterval(value, _int32Min, _int32Max, 'value');
  }

  static const _int32Min = -0x80000000;
  static const _int32Max = 0x7fffffff;

  /// The integer value.
  final int value;

  /// How the value was (or should be) written.
  final LcIntFormat format;

  @override
  LcKind get kind => LcKind.integer;

  @override
  bool operator ==(Object other) => other is LcInt && other.value == value;

  @override
  int get hashCode => Object.hash(LcKind.integer, value);

  @override
  String toString() => 'LcInt($value)';
}

/// A 64-bit signed integer.
final class LcInt64 extends LcValue {
  /// Creates a 64-bit integer.
  const LcInt64(
    this.value, {
    this.format = LcIntFormat.decimal,
    super.position,
  });

  /// The integer value.
  final int value;

  /// How the value was (or should be) written.
  final LcIntFormat format;

  @override
  LcKind get kind => LcKind.integer64;

  @override
  bool operator ==(Object other) => other is LcInt64 && other.value == value;

  @override
  int get hashCode => Object.hash(LcKind.integer64, value);

  @override
  String toString() => 'LcInt64($value)';
}

/// A double-precision float.
final class LcFloat extends LcValue {
  /// Creates a float. NaN cannot be written by libconfig and is rejected.
  LcFloat(this.value, {super.position}) {
    if (value.isNaN) throw ArgumentError.value(value, 'value', 'NaN');
  }

  /// The float value.
  final double value;

  /// The IEEE-754 bit pattern, used for exact comparison.
  int get bits => (ByteData(8)..setFloat64(0, value)).getUint64(0);

  @override
  LcKind get kind => LcKind.float;

  @override
  bool operator ==(Object other) => other is LcFloat && other.bits == bits;

  @override
  int get hashCode => Object.hash(LcKind.float, bits);

  @override
  String toString() => 'LcFloat($value)';
}

/// A boolean.
final class LcBool extends LcValue {
  /// Creates a boolean.
  const LcBool(this.value, {super.position});

  /// The boolean value.
  final bool value;

  @override
  LcKind get kind => LcKind.boolean;

  @override
  bool operator ==(Object other) => other is LcBool && other.value == value;

  @override
  int get hashCode => Object.hash(LcKind.boolean, value);

  @override
  String toString() => 'LcBool($value)';
}

/// A string. libconfig strings are byte strings (`\xHH` escapes can produce
/// any byte), so the raw [bytes] are the source of truth.
final class LcString extends LcValue {
  /// Creates a string from raw bytes. NUL bytes are rejected because
  /// libconfig stores strings as C strings.
  LcString(List<int> bytes, {super.position})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (this.bytes.contains(0)) {
      throw ArgumentError.value(bytes, 'bytes', 'contains a NUL byte');
    }
  }

  /// Creates a string from text, encoded as UTF-8.
  LcString.fromText(String text, {SourcePosition? position})
    : this(utf8.encode(text), position: position);

  /// The raw bytes.
  final Uint8List bytes;

  /// The bytes decoded as UTF-8 (invalid sequences become U+FFFD).
  String get text => utf8.decode(bytes, allowMalformed: true);

  @override
  LcKind get kind => LcKind.string;

  @override
  bool operator ==(Object other) =>
      other is LcString && _bytesEqual(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(LcKind.string, Object.hashAll(bytes));

  @override
  String toString() => 'LcString(${jsonEncode(text)})';
}

/// One `name = value` entry of a group.
final class LcSetting {
  /// Creates a setting; throws [ArgumentError] if [name] is not a valid
  /// libconfig name.
  LcSetting(this.name, this.value, {this.position}) {
    if (!isValidName(name)) {
      throw ArgumentError.value(name, 'name', 'not a valid libconfig name');
    }
  }

  /// The setting name.
  final String name;

  /// The setting value.
  final LcValue value;

  /// Where the name started in the parsed text.
  final SourcePosition? position;

  static final _namePattern = RegExp(r'^[A-Za-z*][-A-Za-z0-9_*]*$');

  /// Whether [name] can be written and read back as a setting name.
  ///
  /// Follows the scanner rule `[A-Za-z\*][-A-Za-z0-9_\*]*`. `true` and `false`
  /// (any case) are excluded: the scanner reads them as booleans.
  static bool isValidName(String name) {
    final lower = name.toLowerCase();
    return _namePattern.hasMatch(name) && lower != 'true' && lower != 'false';
  }

  @override
  bool operator ==(Object other) =>
      other is LcSetting && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => 'LcSetting($name: $value)';
}

/// A group of uniquely named settings, in source order.
final class LcGroup extends LcValue {
  /// Creates a group; throws [ArgumentError] on duplicate names
  /// (libconfig: "duplicate setting name"; names are case-sensitive).
  LcGroup(Iterable<LcSetting> settings, {super.position})
    : settings = List.unmodifiable(settings) {
    final seen = HashSet<String>();
    for (final s in this.settings) {
      if (!seen.add(s.name)) {
        throw ArgumentError.value(s.name, 'settings', 'duplicate setting');
      }
    }
  }

  /// The settings, in order.
  final List<LcSetting> settings;

  /// The value of the setting named [name], or null.
  LcValue? operator [](String name) {
    for (final s in settings) {
      if (s.name == name) return s.value;
    }
    return null;
  }

  @override
  LcKind get kind => LcKind.group;

  @override
  bool operator ==(Object other) =>
      other is LcGroup && _listsEqual(other.settings, settings);

  @override
  int get hashCode => Object.hash(LcKind.group, Object.hashAll(settings));

  @override
  String toString() => 'LcGroup($settings)';
}

/// An array: scalars of one single [LcKind].
final class LcArray extends LcValue {
  /// Creates an array; throws [ArgumentError] when an element is not a
  /// scalar or kinds are mixed (libconfig: "mismatched element type").
  LcArray(Iterable<LcValue> elements, {super.position})
    : elements = List.unmodifiable(elements) {
    for (final e in this.elements) {
      if (!e.kind.isScalar) {
        throw ArgumentError.value(e, 'elements', 'arrays only hold scalars');
      }
      if (e.kind != this.elements.first.kind) {
        throw ArgumentError.value(e, 'elements', 'mismatched element type');
      }
    }
  }

  /// The elements, in order.
  final List<LcValue> elements;

  /// The kind of every element, or null when empty.
  LcKind? get elementKind => elements.isEmpty ? null : elements.first.kind;

  @override
  LcKind get kind => LcKind.array;

  @override
  bool operator ==(Object other) =>
      other is LcArray && _listsEqual(other.elements, elements);

  @override
  int get hashCode => Object.hash(LcKind.array, Object.hashAll(elements));

  @override
  String toString() => 'LcArray($elements)';
}

/// A list: values of any kind, including groups and other lists.
final class LcList extends LcValue {
  /// Creates a list.
  LcList(Iterable<LcValue> elements, {super.position})
    : elements = List.unmodifiable(elements);

  /// The elements, in order.
  final List<LcValue> elements;

  @override
  LcKind get kind => LcKind.list;

  @override
  bool operator ==(Object other) =>
      other is LcList && _listsEqual(other.elements, elements);

  @override
  int get hashCode => Object.hash(LcKind.list, Object.hashAll(elements));

  @override
  String toString() => 'LcList($elements)';
}

bool _listsEqual<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
