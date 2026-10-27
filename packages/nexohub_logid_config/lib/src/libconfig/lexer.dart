// Tokenizer faithful to libconfig 1.7.3 `lib/scanner.l`:
// https://github.com/hyperrealm/libconfig/blob/v1.7.3/lib/scanner.l
//
// flex semantics are reproduced exactly: at each position the longest match
// wins and ties go to the rule listed first. Works on UTF-8 bytes, like flex.
import 'dart:typed_data';

import 'ast.dart';
import 'errors.dart';

/// Token kinds (libconfig `TOK_*`).
enum TokenType {
  /// A setting name.
  name,

  /// `=` or `:`.
  equals,

  /// `,`.
  comma,

  /// `;`.
  semicolon,

  /// `{`.
  groupStart,

  /// `}`.
  groupEnd,

  /// `[`.
  arrayStart,

  /// `]`.
  arrayEnd,

  /// `(`.
  listStart,

  /// `)`.
  listEnd,

  /// `true` / `false`, any letter case.
  boolean,

  /// Decimal/octal integer that fits in 32 bits.
  integer,

  /// Integer with `L` suffix, or decimal/octal too large for 32 bits.
  integer64,

  /// Hexadecimal integer (`0x…`), truncated to 32 bits.
  hex,

  /// Hexadecimal integer with `L` suffix.
  hex64,

  /// Floating-point number.
  float,

  /// One quoted string (adjacent strings are joined by the parser).
  string,

  /// End of input.
  eof,
}

/// A token with its decoded payload.
final class Token {
  /// Creates a token.
  const Token(
    this.type,
    this.position, {
    this.text = '',
    this.intValue = 0,
    this.doubleValue = 0,
    this.bytes,
    this.endsInUnterminatedString = false,
  });

  /// The token kind.
  final TokenType type;

  /// For [TokenType.eof]: the input ended inside a string literal.
  final bool endsInUnterminatedString;

  /// Where the token starts.
  final SourcePosition position;

  /// Source text of names and numbers.
  final String text;

  /// Value of integer and boolean (1/0) tokens.
  final int intValue;

  /// Value of float tokens.
  final double doubleValue;

  /// Bytes of string tokens.
  final Uint8List? bytes;

  /// Whether this token starts a scalar value (`simple_value`).
  bool get isScalarStart => switch (type) {
    TokenType.boolean ||
    TokenType.integer ||
    TokenType.integer64 ||
    TokenType.hex ||
    TokenType.hex64 ||
    TokenType.float ||
    TokenType.string => true,
    _ => false,
  };

  @override
  String toString() => '$type@$position';
}

/// Splits libconfig text into tokens, skipping whitespace and comments.
final class Lexer {
  /// Creates a lexer over UTF-8 [source] bytes.
  Lexer(this._src) : _lineStarts = _computeLineStarts(_src);

  final Uint8List _src;
  final List<int> _lineStarts;
  int _pos = 0;

  static final _int64Min = BigInt.from(-0x8000000000000000);
  static final _int64Max = BigInt.from(0x7fffffffffffffff);
  static final _uint64Max = (BigInt.one << 64) - BigInt.one;
  static const _int32Min = -0x80000000;
  static const _int32Max = 0x7fffffff;

  static List<int> _computeLineStarts(Uint8List src) {
    final starts = <int>[0];
    for (var i = 0; i < src.length; i++) {
      if (src[i] == _nl) starts.add(i + 1);
    }
    return starts;
  }

  /// Converts a byte offset into a 1-based line/column.
  SourcePosition positionOf(int offset) {
    var lo = 0, hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return SourcePosition(lo + 1, offset - _lineStarts[lo] + 1);
  }

  Never _fail(LibconfigErrorCode code, String message, int offset) =>
      throw LibconfigSyntaxError(code, message, positionOf(offset));

  int _at(int i) => i < _src.length ? _src[i] : -1;

  /// Returns the next token, or throws [LibconfigSyntaxError] for input the
  /// scanner rejects (`TOK_GARBAGE`, `TOK_ERROR`, unterminated string).
  Token next() {
    while (true) {
      if (_pos >= _src.length) return Token(TokenType.eof, positionOf(_pos));
      final start = _pos;
      final c = _src[start];

      // include_open  ^[ \t]*@include[ \t]+\"  — longer than the blank rule.
      if ((start == 0 || _src[start - 1] == _nl) && _matchIncludeOpen(start)) {
        _fail(
          LibconfigErrorCode.includeNotSupported,
          '@include directives are not supported',
          start,
        );
      }
      // (#|\/\/) single-line comment, up to (not including) the newline.
      if (c == _hash || (c == _slash && _at(start + 1) == _slash)) {
        while (_pos < _src.length && _src[_pos] != _nl) {
          _pos++;
        }
        continue;
      }
      // \/\* multi-line comment. An unterminated one silently ends the input.
      if (c == _slash && _at(start + 1) == _star) {
        _pos += 2;
        while (_pos < _src.length &&
            !(_src[_pos] == _star && _at(_pos + 1) == _slash)) {
          _pos++;
        }
        _pos = _pos < _src.length ? _pos + 2 : _src.length;
        continue;
      }
      if (c == _quote) return _lexString();
      // \n|\r|\f and [ \t]+ are ignored.
      if (c == _nl || c == _cr || c == _ff || c == _space || c == _tab) {
        _pos++;
        continue;
      }
      final punct = switch (c) {
        _equal || _colon => TokenType.equals,
        _comma => TokenType.comma,
        _lbrace => TokenType.groupStart,
        _rbrace => TokenType.groupEnd,
        _lbracket => TokenType.arrayStart,
        _rbracket => TokenType.arrayEnd,
        _lparen => TokenType.listStart,
        _rparen => TokenType.listEnd,
        _semicolon => TokenType.semicolon,
        _ => null,
      };
      if (punct != null) {
        _pos++;
        return Token(punct, positionOf(start));
      }
      final word = _lexWord(start);
      if (word != null) return word;
      _fail(
        LibconfigErrorCode.unexpectedCharacter,
        'unexpected character 0x${c.toRadixString(16).padLeft(2, '0')}',
        start,
      );
    }
  }

  bool _matchIncludeOpen(int i) {
    while (_at(i) == _space || _at(i) == _tab) {
      i++;
    }
    const word = '@include';
    for (var k = 0; k < word.length; k++) {
      if (_at(i + k) != word.codeUnitAt(k)) return false;
    }
    i += word.length;
    if (_at(i) != _space && _at(i) != _tab) return false;
    while (_at(i) == _space || _at(i) == _tab) {
      i++;
    }
    return _at(i) == _quote;
  }

  // <STRING> rules: escapes \n \r \t \f \\ \" and \xHH; any other backslash
  // is kept literally; raw newlines are allowed inside strings.
  Token _lexString() {
    final start = _pos;
    final out = BytesBuilder(copy: false);
    _pos++; // opening quote
    while (true) {
      if (_pos >= _src.length) {
        // No <<EOF>> rule for the STRING state: flex ends the input and the
        // unfinished string is dropped. The file is still valid when the
        // grammar is complete at that point ("a = 1; \"x" reads as a = 1).
        return Token(
          TokenType.eof,
          positionOf(start),
          endsInUnterminatedString: true,
        );
      }
      final c = _src[_pos];
      if (c == _quote) {
        _pos++;
        return Token(
          TokenType.string,
          positionOf(start),
          bytes: out.takeBytes(),
        );
      }
      if (c != _backslash) {
        // <STRING>[^\"\\]+ is appended with strlen(): a raw NUL byte drops
        // the rest of this run (up to the next quote or backslash) only.
        var end = _pos;
        while (end < _src.length &&
            _src[end] != _quote &&
            _src[end] != _backslash) {
          end++;
        }
        var stop = _pos;
        while (stop < end && _src[stop] != 0) {
          stop++;
        }
        out.add(Uint8List.sublistView(_src, _pos, stop));
        _pos = end;
        continue;
      }
      final e = _at(_pos + 1);
      final simple = switch (e) {
        0x6E => _nl, // n
        0x72 => _cr, // r
        0x74 => _tab, // t
        0x66 => _ff, // f
        _backslash => _backslash,
        _quote => _quote,
        _ => null,
      };
      if (simple != null) {
        out.addByte(simple);
        _pos += 2;
      } else if ((e == 0x78 || e == 0x58) &&
          _isHexDigit(_at(_pos + 2)) &&
          _isHexDigit(_at(_pos + 3))) {
        out.addByte(_hexValue(_at(_pos + 2)) << 4 | _hexValue(_at(_pos + 3)));
        _pos += 4;
      } else {
        out.addByte(_backslash);
        _pos++;
      }
    }
  }

  // Word-like rules, in scanner.l order (the order breaks length ties):
  // true, false, name, float, integer, integer64, hex, hex64.
  Token? _lexWord(int start) {
    final lengths = [
      _matchKeyword(start, 'true'),
      _matchKeyword(start, 'false'),
      _matchName(start),
      _matchFloat(start),
      _matchInteger(start),
      _matchInteger64(start),
      _matchHex(start),
      _matchHex64(start),
    ];
    var rule = -1, best = 0;
    for (var r = 0; r < lengths.length; r++) {
      if (lengths[r] > best) {
        best = lengths[r];
        rule = r;
      }
    }
    if (rule < 0) return null;
    _pos = start + best;
    final text = String.fromCharCodes(_src, start, start + best);
    final position = positionOf(start);
    switch (rule) {
      case 0 || 1:
        return Token(
          TokenType.boolean,
          position,
          text: text,
          intValue: rule == 0 ? 1 : 0,
        );
      case 2:
        return Token(TokenType.name, position, text: text);
      case 3:
        return Token(
          TokenType.float,
          position,
          text: text,
          doubleValue: _atof(text),
        );
      case 4:
        // strtoll(s, &end, 0): base 8 when there is a leading 0; any digit
        // left unconsumed or an out-of-range value is a TOK_ERROR.
        final value = _strtollBase0(text);
        if (value == null) {
          _fail(
            LibconfigErrorCode.invalidInteger,
            'invalid integer "$text"',
            start,
          );
        }
        final v = value.toInt();
        final fits32 = v >= _int32Min && v <= _int32Max;
        return Token(
          fits32 ? TokenType.integer : TokenType.integer64,
          position,
          text: text,
          intValue: v,
        );
      case 5:
        // atoll(): base 10 (leading zeros are NOT octal here), saturating.
        final digits = text.replaceAll('L', '');
        return Token(
          TokenType.integer64,
          position,
          text: text,
          intValue: _clamp(BigInt.parse(digits), _int64Min, _int64Max).toInt(),
        );
      case 6:
        // strtoul(…, 16) saturates at 2^64-1, then is cast to a 32-bit int.
        final value = _clamp(_parseHex(text), BigInt.zero, _uint64Max);
        return Token(
          TokenType.hex,
          position,
          text: text,
          intValue: value.toSigned(32).toInt(),
        );
      default:
        // strtoull(…, 16) saturates, then is stored in a long long.
        final value = _clamp(_parseHex(text), BigInt.zero, _uint64Max);
        return Token(
          TokenType.hex64,
          position,
          text: text,
          intValue: value.toSigned(64).toInt(),
        );
    }
  }

  int _matchKeyword(int i, String word) {
    for (var k = 0; k < word.length; k++) {
      final c = _at(i + k);
      if (c < 0 || (c | 0x20) != word.codeUnitAt(k)) return 0;
    }
    return word.length;
  }

  // name  [A-Za-z\*][-A-Za-z0-9_\*]*
  int _matchName(int i) {
    final c = _at(i);
    if (!_isAlpha(c) && c != _star) return 0;
    var j = i + 1;
    while (true) {
      final d = _at(j);
      if (_isAlpha(d) ||
          _isDigit(d) ||
          d == _minus ||
          d == _underscore ||
          d == _star) {
        j++;
      } else {
        break;
      }
    }
    return j - i;
  }

  int _skipSign(int i) => (_at(i) == _minus || _at(i) == _plus) ? i + 1 : i;

  int _skipDigits(int i) {
    while (_isDigit(_at(i))) {
      i++;
    }
    return i;
  }

  // [eE][-+]?[0-9]+  → end offset, or -1 when absent/incomplete.
  int _exponentEnd(int i) {
    if (_at(i) != 0x65 && _at(i) != 0x45) return -1;
    final digitsStart = _skipSign(i + 1);
    final end = _skipDigits(digitsStart);
    return end > digitsStart ? end : -1;
  }

  // float  ([-+]?([0-9]*)?\.[0-9]*([eE][-+]?[0-9]+)?)
  //      | ([-+]?([0-9]+)(\.[0-9]*)?[eE][-+]?[0-9]+)
  int _matchFloat(int i) {
    final afterSign = _skipSign(i);
    final intEnd = _skipDigits(afterSign);
    var best = 0;
    if (_at(intEnd) == _dot) {
      final fracEnd = _skipDigits(intEnd + 1);
      final expEnd = _exponentEnd(fracEnd);
      best = (expEnd > 0 ? expEnd : fracEnd) - i;
    }
    if (intEnd > afterSign) {
      var j = intEnd;
      if (_at(j) == _dot) j = _skipDigits(j + 1);
      var expEnd = _exponentEnd(j);
      if (expEnd < 0 && j != intEnd) expEnd = _exponentEnd(intEnd);
      if (expEnd > 0 && expEnd - i > best) best = expEnd - i;
    }
    return best;
  }

  // integer  [-+]?[0-9]+
  int _matchInteger(int i) {
    final digitsStart = _skipSign(i);
    final end = _skipDigits(digitsStart);
    return end > digitsStart ? end - i : 0;
  }

  // integer64  [-+]?[0-9]+L(L)?
  int _matchInteger64(int i) {
    final n = _matchInteger(i);
    if (n == 0 || _at(i + n) != _upperL) return 0;
    return _at(i + n + 1) == _upperL ? n + 2 : n + 1;
  }

  // hex  0[Xx][0-9A-Fa-f]+
  int _matchHex(int i) {
    if (_at(i) != _zero || (_at(i + 1) != 0x78 && _at(i + 1) != 0x58)) {
      return 0;
    }
    var j = i + 2;
    while (_isHexDigit(_at(j))) {
      j++;
    }
    return j > i + 2 ? j - i : 0;
  }

  // hex64  0[Xx][0-9A-Fa-f]+L(L)?
  int _matchHex64(int i) {
    final n = _matchHex(i);
    if (n == 0 || _at(i + n) != _upperL) return 0;
    return _at(i + n + 1) == _upperL ? n + 2 : n + 1;
  }

  static BigInt? _strtollBase0(String text) {
    var digits = text;
    var negative = false;
    if (digits.startsWith('+') || digits.startsWith('-')) {
      negative = digits.startsWith('-');
      digits = digits.substring(1);
    }
    BigInt value;
    if (digits.length > 1 && digits.startsWith('0')) {
      if (digits.contains(RegExp('[89]'))) return null;
      value = BigInt.parse(digits, radix: 8);
    } else {
      value = BigInt.parse(digits);
    }
    if (negative) value = -value;
    if (value < _int64Min || value > _int64Max) return null;
    return value;
  }

  static BigInt _parseHex(String text) =>
      BigInt.parse(text.substring(2).replaceAll('L', ''), radix: 16);

  static BigInt _clamp(BigInt v, BigInt min, BigInt max) =>
      v < min ? min : (v > max ? max : v);

  // atof() in the C locale. When the mantissa has no digit at all (".",
  // "-.", "+.e5") strtod performs no conversion and returns +0.0.
  static double _atof(String text) {
    final m = RegExp(r'^([-+]?)(\d*)(?:\.(\d*))?(?:[eE]([-+]?\d+))?$')
        .firstMatch(text)!;
    final intDigits = m.group(2)!;
    final fracDigits = m.group(3) ?? '';
    if (intDigits.isEmpty && fracDigits.isEmpty) return 0.0;
    final mantissa =
        '${m.group(1)}${intDigits.isEmpty ? '0' : intDigits}'
        '.${fracDigits.isEmpty ? '0' : fracDigits}';
    final exponent = m.group(4);
    return double.parse(exponent == null ? mantissa : '${mantissa}e$exponent');
  }

  static bool _isAlpha(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isHexDigit(int c) =>
      _isDigit(c) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66);
  static int _hexValue(int c) =>
      _isDigit(c) ? c - 0x30 : (c | 0x20) - 0x61 + 10;

  static const _nl = 0x0A,
      _cr = 0x0D,
      _ff = 0x0C,
      _tab = 0x09,
      _space = 0x20,
      _quote = 0x22,
      _hash = 0x23,
      _lparen = 0x28,
      _rparen = 0x29,
      _star = 0x2A,
      _plus = 0x2B,
      _comma = 0x2C,
      _minus = 0x2D,
      _dot = 0x2E,
      _slash = 0x2F,
      _zero = 0x30,
      _colon = 0x3A,
      _semicolon = 0x3B,
      _equal = 0x3D,
      _upperL = 0x4C,
      _lbracket = 0x5B,
      _backslash = 0x5C,
      _rbracket = 0x5D,
      _underscore = 0x5F,
      _lbrace = 0x7B,
      _rbrace = 0x7D;
}
