// Canonical libconfig writer.
//
// Emits a conservative subset of the libconfig syntax that reads back, with
// both this package's parser and libconfig 1.7.3, as exactly the same tree.
// Comments from the original text are not preserved.
import 'ast.dart';

/// Writes [root] as libconfig text.
///
/// Each line of [header] becomes a `#` comment at the top of the file.
/// Throws [ArgumentError] for values libconfig cannot express (NaN).
String writeLibconfig(LcGroup root, {String? header}) {
  final out = StringBuffer();
  if (header != null) {
    for (final line in header.split('\n')) {
      out.writeln(line.isEmpty ? '#' : '# $line');
    }
    out.writeln();
  }
  _writeSettings(out, root.settings, 0);
  return out.toString();
}

const _indentUnit = '    ';

void _writeSettings(StringBuffer out, List<LcSetting> settings, int depth) {
  final indent = _indentUnit * depth;
  for (final s in settings) {
    out
      ..write(indent)
      ..write(s.name)
      ..write(': ');
    _writeValue(out, s.value, depth);
    out.writeln(';');
  }
}

void _writeValue(StringBuffer out, LcValue value, int depth) {
  switch (value) {
    case LcGroup(:final settings):
      if (settings.isEmpty) {
        out.write('{}');
        return;
      }
      out.writeln('{');
      _writeSettings(out, settings, depth + 1);
      out.write('${_indentUnit * depth}}');
    case LcList(:final elements):
      if (elements.isEmpty) {
        out.write('()');
        return;
      }
      out.writeln('(');
      final inner = _indentUnit * (depth + 1);
      for (var i = 0; i < elements.length; i++) {
        out.write(inner);
        _writeValue(out, elements[i], depth + 1);
        out.writeln(i == elements.length - 1 ? '' : ',');
      }
      out.write('${_indentUnit * depth})');
    case LcArray(:final elements):
      out.write('[');
      for (var i = 0; i < elements.length; i++) {
        if (i > 0) out.write(', ');
        _writeValue(out, elements[i], depth);
      }
      out.write(']');
    case LcInt(:final value, :final format):
      out.write(
        format == LcIntFormat.hex
            // Read back by strtoul + cast to int: 0xffffffff → -1.
            ? '0x${value.toUnsigned(32).toRadixString(16)}'
            // Never a leading zero: that would be read as octal.
            : '$value',
      );
    case LcInt64(:final value, :final format):
      out.write(
        format == LcIntFormat.hex
            ? '0x${BigInt.from(value).toUnsigned(64).toRadixString(16)}L'
            : '${value}L',
      );
    case LcFloat(:final value):
      out.write(_formatFloat(value));
    case LcBool(:final value):
      out.write(value ? 'true' : 'false');
    case LcString(:final bytes):
      out.write(_quote(bytes));
  }
}

/// Shortest text that libconfig reads back as the same double and as a
/// float (it must contain `.` or an exponent).
String _formatFloat(double value) {
  if (value.isNaN) throw ArgumentError.value(value, 'value', 'NaN');
  // atof("1e999") overflows to infinity, which round-trips exactly.
  if (value.isInfinite) return value > 0 ? '1e999' : '-1e999';
  // Dart's shortest round-trip form always has a "." or an exponent
  // ("100.0", "1e+21", "-0.0", "5e-324").
  return value.toString();
}

/// Quotes [bytes] so the libconfig scanner reproduces them exactly: valid
/// UTF-8 is kept readable, everything else is escaped.
String _quote(List<int> bytes) {
  final out = StringBuffer('"');
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      switch (b) {
        case 0x22:
          out.write(r'\"');
        case 0x5C:
          out.write(r'\\');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        case 0x0C:
          out.write(r'\f');
        default:
          if (b < 0x20 || b == 0x7F) {
            out.write(_hexEscape(b));
          } else {
            out.writeCharCode(b);
          }
      }
      i++;
      continue;
    }
    final length = _utf8SequenceLength(bytes, i);
    if (length == 0) {
      out.write(_hexEscape(b));
      i++;
    } else {
      out.writeCharCode(_decodeUtf8(bytes, i, length));
      i += length;
    }
  }
  out.write('"');
  return out.toString();
}

String _hexEscape(int b) => '\\x${b.toRadixString(16).padLeft(2, '0')}';

/// Length of the well-formed UTF-8 sequence starting at [i] (2–4), or 0.
/// Rejects overlong forms, surrogates and code points above U+10FFFF.
int _utf8SequenceLength(List<int> bytes, int i) {
  final b = bytes[i];
  int length, min;
  if (b >= 0xC2 && b <= 0xDF) {
    length = 2;
    min = 0x80;
  } else if (b >= 0xE0 && b <= 0xEF) {
    length = 3;
    min = 0x800;
  } else if (b >= 0xF0 && b <= 0xF4) {
    length = 4;
    min = 0x10000;
  } else {
    return 0;
  }
  if (i + length > bytes.length) return 0;
  for (var k = 1; k < length; k++) {
    if (bytes[i + k] & 0xC0 != 0x80) return 0;
  }
  final cp = _decodeUtf8(bytes, i, length);
  if (cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) return 0;
  return length;
}

int _decodeUtf8(List<int> bytes, int i, int length) {
  var cp = bytes[i] & (0xFF >> (length + 1));
  for (var k = 1; k < length; k++) {
    cp = (cp << 6) | (bytes[i + k] & 0x3F);
  }
  return cp;
}
