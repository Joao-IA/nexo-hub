// Recursive-descent parser faithful to libconfig 1.7.3 `lib/grammar.y`:
// https://github.com/hyperrealm/libconfig/blob/v1.7.3/lib/grammar.y
import 'dart:convert';
import 'dart:typed_data';

import 'ast.dart';
import 'errors.dart';
import 'lexer.dart';

/// Parses libconfig [text] into its root group.
///
/// Throws [LibconfigSyntaxError] for anything libconfig 1.7.3 would reject,
/// plus `@include` (deliberately unsupported) and nesting deeper than
/// [maxLibconfigDepth].
LcGroup parseLibconfig(String text) => parseLibconfigBytes(utf8.encode(text));

/// Parses libconfig text given as raw bytes (how libconfig itself reads it).
LcGroup parseLibconfigBytes(List<int> bytes) {
  final source = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  return _Parser(Lexer(source)).parseDocument();
}

final class _Parser {
  _Parser(this._lexer) : _token = _lexer.next();

  final Lexer _lexer;
  Token _token;
  int _depth = 0;

  void _advance() => _token = _lexer.next();

  Never _unexpected() {
    if (_token.type == TokenType.eof) {
      throw _token.endsInUnterminatedString
          ? LibconfigSyntaxError(
              LibconfigErrorCode.unterminatedString,
              'string is not terminated',
              _token.position,
            )
          : LibconfigSyntaxError(
              LibconfigErrorCode.unexpectedEndOfInput,
              'unexpected end of input',
              _token.position,
            );
    }
    throw LibconfigSyntaxError(
      LibconfigErrorCode.unexpectedToken,
      'unexpected ${_token.type.name}',
      _token.position,
    );
  }

  void _expect(TokenType type) {
    if (_token.type != type) _unexpected();
    _advance();
  }

  // configuration: /* empty */ | setting_list
  LcGroup parseDocument() {
    final settings = _settingList();
    if (_token.type != TokenType.eof) _unexpected();
    return LcGroup(settings, position: const SourcePosition(1, 1));
  }

  // setting_list_optional: settings until something that is not a name.
  List<LcSetting> _settingList() {
    final settings = <LcSetting>[];
    final names = <String>{};
    while (_token.type == TokenType.name) {
      final nameToken = _token;
      if (!names.add(nameToken.text)) {
        throw LibconfigSyntaxError(
          LibconfigErrorCode.duplicateSetting,
          'duplicate setting name "${nameToken.text}"',
          nameToken.position,
        );
      }
      _advance();
      _expect(TokenType.equals);
      final value = _value();
      // setting_terminator: /* empty */ | ';' | ','
      if (_token.type == TokenType.semicolon ||
          _token.type == TokenType.comma) {
        _advance();
      }
      settings.add(
        LcSetting(nameToken.text, value, position: nameToken.position),
      );
    }
    return settings;
  }

  // value: simple_value | array | list | group
  LcValue _value() {
    switch (_token.type) {
      case TokenType.arrayStart:
        return _nested(_array);
      case TokenType.listStart:
        return _nested(_list);
      case TokenType.groupStart:
        return _nested(_group);
      default:
        if (_token.isScalarStart) return _scalar();
        _unexpected();
    }
  }

  T _nested<T>(T Function() parse) {
    if (++_depth > maxLibconfigDepth) {
      throw LibconfigSyntaxError(
        LibconfigErrorCode.nestingTooDeep,
        'nesting deeper than $maxLibconfigDepth levels',
        _token.position,
      );
    }
    try {
      return parse();
    } finally {
      _depth--;
    }
  }

  LcValue _scalar() {
    final t = _token;
    switch (t.type) {
      case TokenType.boolean:
        _advance();
        return LcBool(t.intValue == 1, position: t.position);
      case TokenType.integer:
        _advance();
        return LcInt(t.intValue, position: t.position);
      case TokenType.hex:
        _advance();
        return LcInt(t.intValue, format: LcIntFormat.hex, position: t.position);
      case TokenType.integer64:
        _advance();
        return LcInt64(t.intValue, position: t.position);
      case TokenType.hex64:
        _advance();
        return LcInt64(
          t.intValue,
          format: LcIntFormat.hex,
          position: t.position,
        );
      case TokenType.float:
        _advance();
        return LcFloat(t.doubleValue, position: t.position);
      case TokenType.string:
        // string: TOK_STRING | string TOK_STRING  (adjacent strings join).
        // Each piece is taken as a C string, so an embedded NUL (from
        // "\x00") ends that piece only: "a\x00b" "c" reads as "ac".
        final bytes = BytesBuilder(copy: false);
        while (_token.type == TokenType.string) {
          final piece = _token.bytes!;
          final nul = piece.indexOf(0);
          bytes.add(nul < 0 ? piece : piece.sublist(0, nul));
          _advance();
        }
        return LcString(bytes.takeBytes(), position: t.position);
      default:
        _unexpected();
    }
  }

  // array: '[' simple_value_list_optional ']'
  LcArray _array() {
    final position = _token.position;
    _advance();
    final elements = <LcValue>[];
    _sequence(
      isElementStart: () => _token.isScalarStart,
      parseElement: () {
        final elementPosition = _token.position;
        final element = _scalar();
        if (elements.isNotEmpty && element.kind != elements.first.kind) {
          throw LibconfigSyntaxError(
            LibconfigErrorCode.mismatchedArrayElementType,
            'mismatched element type in array',
            elementPosition,
          );
        }
        elements.add(element);
      },
    );
    _expect(TokenType.arrayEnd);
    return LcArray(elements, position: position);
  }

  // list: '(' value_list_optional ')'
  LcList _list() {
    final position = _token.position;
    _advance();
    final elements = <LcValue>[];
    _sequence(
      isElementStart: () =>
          _token.isScalarStart ||
          _token.type == TokenType.arrayStart ||
          _token.type == TokenType.listStart ||
          _token.type == TokenType.groupStart,
      parseElement: () => elements.add(_value()),
    );
    _expect(TokenType.listEnd);
    return LcList(elements, position: position);
  }

  // value_list: value | value_list ',' value | value_list ','
  // i.e. a first element, then any mix of commas where an element may only
  // appear right after a comma ("1,,2" and "1,2," are valid; "1 2" is not).
  void _sequence({
    required bool Function() isElementStart,
    required void Function() parseElement,
  }) {
    if (!isElementStart()) return; // empty: value_list_optional
    parseElement();
    while (_token.type == TokenType.comma) {
      _advance();
      if (isElementStart()) parseElement();
    }
  }

  // group: '{' setting_list_optional '}'
  LcGroup _group() {
    final position = _token.position;
    _advance();
    final settings = _settingList();
    _expect(TokenType.groupEnd);
    return LcGroup(settings, position: position);
  }
}
