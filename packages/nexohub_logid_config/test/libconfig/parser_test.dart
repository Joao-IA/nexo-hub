import 'dart:convert';
import 'dart:io';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

LcValue? valueOf(String text, [String name = 'a']) =>
    parseLibconfig(text)[name];

Matcher throwsCode(LibconfigErrorCode code) =>
    throwsA(isA<LibconfigSyntaxError>().having((e) => e.code, 'code', code));

void main() {
  group('structure', () {
    test('empty and comment-only documents are empty groups', () {
      expect(parseLibconfig('').settings, isEmpty);
      expect(parseLibconfig('# x\n// y\n/* z */').settings, isEmpty);
    });

    test('= and : are equivalent; terminators are optional', () {
      final g = parseLibconfig('a = 1; b : 2, c = 3 d = 4');
      expect(g.settings.map((s) => s.name), ['a', 'b', 'c', 'd']);
    });

    test('groups, lists and arrays nest', () {
      final g = parseLibconfig(
        'a = { b = ( 1, "x", [1, 2], { c = true; } ); };',
      );
      final list = (g['a']! as LcGroup)['b']! as LcList;
      expect(list.elements.map((e) => e.kind), [
        LcKind.integer,
        LcKind.string,
        LcKind.array,
        LcKind.group,
      ]);
    });

    test('extra commas inside lists and arrays are accepted', () {
      expect((valueOf('a = [1, 2,,];')! as LcArray).elements, hasLength(2));
      expect((valueOf('a = (1,, 2,);')! as LcList).elements, hasLength(2));
    });

    test('a leading comma or missing comma is rejected', () {
      expect(
        () => parseLibconfig('a = [,1];'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
      expect(
        () => parseLibconfig('a = [1 2];'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
    });

    test('duplicate names are rejected, case-sensitively', () {
      expect(
        () => parseLibconfig('a = 1; a = 2;'),
        throwsCode(LibconfigErrorCode.duplicateSetting),
      );
      expect(parseLibconfig('a = 1; A = 2;').settings, hasLength(2));
    });

    test('arrays must be homogeneous (int and int64 are different)', () {
      expect(
        () => parseLibconfig('a = [1, 2L];'),
        throwsCode(LibconfigErrorCode.mismatchedArrayElementType),
      );
      expect(
        () => parseLibconfig('a = [1, 2.0];'),
        throwsCode(LibconfigErrorCode.mismatchedArrayElementType),
      );
      expect(
        (valueOf('a = [1, 0x2];')! as LcArray).elementKind,
        LcKind.integer,
      );
    });

    test('arrays only hold scalars', () {
      expect(
        () => parseLibconfig('a = [ {} ];'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
    });

    test('true/false cannot be setting names', () {
      expect(
        () => parseLibconfig('true = 1;'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
      expect(valueOf('True1 = 1;', 'True1'), LcInt(1));
    });

    test('incomplete input reports end of input', () {
      expect(
        () => parseLibconfig('a = '),
        throwsCode(LibconfigErrorCode.unexpectedEndOfInput),
      );
      expect(
        () => parseLibconfig('a = { b = 1;'),
        throwsCode(LibconfigErrorCode.unexpectedEndOfInput),
      );
    });

    test('nesting is limited', () {
      final deep =
          'a = ${'(' * (maxLibconfigDepth + 1)}${')' * (maxLibconfigDepth + 1)};';
      expect(
        () => parseLibconfig(deep),
        throwsCode(LibconfigErrorCode.nestingTooDeep),
      );
    });

    test('positions are 1-based line and byte column', () {
      final g = parseLibconfig('\n  b = 1;');
      expect(g.settings.single.position.toString(), '2:3');
      expect(
        () => parseLibconfig('a = 1;\nb = @;'),
        throwsA(
          isA<LibconfigSyntaxError>().having(
            (e) => '${e.position}',
            'position',
            '2:5',
          ),
        ),
      );
    });
  });

  group('integers', () {
    test('decimal, sign and 32/64-bit promotion', () {
      expect(valueOf('a = -2147483648;'), LcInt(-2147483648));
      expect(valueOf('a = 2147483648;'), const LcInt64(2147483648));
      expect(valueOf('a = +7;'), LcInt(7));
    });

    test('a leading zero means octal; 8 and 9 make it invalid', () {
      expect(valueOf('a = 010;'), LcInt(8));
      expect(valueOf('a = -010;'), LcInt(-8));
      expect(valueOf('a = 00;'), LcInt(0));
      expect(
        () => parseLibconfig('a = 08;'),
        throwsCode(LibconfigErrorCode.invalidInteger),
      );
    });

    test('decimal literals beyond 64 bits are invalid', () {
      expect(
        () => parseLibconfig('a = 9223372036854775808;'),
        throwsCode(LibconfigErrorCode.invalidInteger),
      );
    });

    test('L suffix is base 10 (no octal) and saturates', () {
      expect(valueOf('a = 007L;'), const LcInt64(7));
      expect(valueOf('a = 5LL;'), const LcInt64(5));
      expect(
        valueOf('a = 99999999999999999999L;'),
        const LcInt64(0x7fffffffffffffff),
      );
    });

    test('hex is truncated to 32 bits; hex64 to 64 bits', () {
      final cid = valueOf('a = 0xc3;')! as LcInt;
      expect((cid.value, cid.format), (0xc3, LcIntFormat.hex));
      expect(valueOf('a = 0xffffffff;'), LcInt(-1));
      expect(valueOf('a = 0x100000001;'), LcInt(1));
      expect(valueOf('a = 0x1FFFFFFFFFFFFFFFF;'), LcInt(-1)); // saturates first
      expect(valueOf('a = 0xFFFFFFFFFFFFFFFFL;'), const LcInt64(-1));
    });

    test('a lowercase l suffix is not part of the number', () {
      expect(
        () => parseLibconfig('a = 10l;'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
    });
  });

  group('floats', () {
    test('all literal forms', () {
      expect(valueOf('a = 1.5;'), LcFloat(1.5));
      expect(valueOf('a = .5;'), LcFloat(0.5));
      expect(valueOf('a = 5.;'), LcFloat(5));
      expect(valueOf('a = 1e3;'), LcFloat(1000));
      expect(valueOf('a = 1.e3;'), LcFloat(1000));
      expect(valueOf('a = -0.0;'), LcFloat(-0.0));
      expect(valueOf('a = 08.5;'), LcFloat(8.5)); // floats are always base 10
      expect(valueOf('a = 1e999;'), LcFloat(double.infinity));
    });

    test('a mantissa without digits converts to +0.0', () {
      expect(valueOf('a = .;'), LcFloat(0));
      expect(valueOf('a = -.;'), LcFloat(0));
      expect(valueOf('a = +.e5;'), LcFloat(0));
    });

    test('an incomplete exponent is not part of the number', () {
      expect(
        () => parseLibconfig('a = 1e;'),
        throwsCode(LibconfigErrorCode.unexpectedToken),
      );
    });
  });

  group('strings', () {
    test('escapes', () {
      expect(
        (valueOf(r'a = "\n\r\t\f\\\"";')! as LcString).text,
        '\n\r\t\f\\"',
      );
      expect((valueOf(r'a = "\x41\X42";')! as LcString).text, 'AB');
    });

    test('unknown escapes and short \\x keep the backslash', () {
      expect((valueOf(r'a = "\q";')! as LcString).text, r'\q');
      expect((valueOf(r'a = "\x4g";')! as LcString).text, r'\x4g');
    });

    test('adjacent strings are joined; NUL ends each piece', () {
      expect((valueOf('a = "ab" "cd";')! as LcString).text, 'abcd');
      expect((valueOf(r'a = "a\x00b" "c";')! as LcString).text, 'ac');
    });

    test('a raw NUL byte drops only the rest of its literal run', () {
      // Found by the differential fuzz: "\<NUL>x41\x4g" reads as \\x4g.
      final bytes = [
        ...'a = "'.codeUnits, 0x5C, 0x00, ...r'x41\x4g";'.codeUnits, //
      ];
      expect((parseLibconfigBytes(bytes)['a']! as LcString).text, r'\\x4g');
    });

    test('raw newlines and UTF-8 are kept', () {
      expect((valueOf('a = "x\ny ç";')! as LcString).text, 'x\ny ç');
    });

    test('a dangling string at the end of a complete file is dropped', () {
      // Found by the differential test: libconfig accepts this as a = 3.
      expect(parseLibconfig('a : 3"000;').settings.single.value, LcInt(3));
    });

    test('unterminated strings are rejected where a value is needed', () {
      expect(
        () => parseLibconfig('a = "abc'),
        throwsCode(LibconfigErrorCode.unterminatedString),
      );
    });
  });

  group('booleans, comments and other tokens', () {
    test('booleans are case-insensitive', () {
      expect(valueOf('a = TRUE;'), const LcBool(true));
      expect(valueOf('a = fAlSe;'), const LcBool(false));
    });

    test('an unterminated block comment ends the input', () {
      expect(parseLibconfig('a = 1; /* never closed').settings, hasLength(1));
    });

    test('@include is refused', () {
      expect(
        () => parseLibconfig('@include "x.cfg"\n'),
        throwsCode(LibconfigErrorCode.includeNotSupported),
      );
      expect(
        () => parseLibconfig('a = 1; @include "x.cfg"'),
        throwsCode(LibconfigErrorCode.unexpectedCharacter),
      );
    });

    test('stray characters are rejected', () {
      expect(
        () => parseLibconfig('a = 1 ?'),
        throwsCode(LibconfigErrorCode.unexpectedCharacter),
      );
      expect(
        () => parseLibconfigBytes([0x61, 0x3D, 0x31, 0x3B, 0xFF]),
        throwsCode(LibconfigErrorCode.unexpectedCharacter),
      );
    });
  });

  group('real configurations', () {
    test("user's original logid.cfg", () {
      final text = File('../../fixtures/logid/user-original-2026-10-27.cfg')
          .readAsStringSync();
      final device =
          ((parseLibconfig(text)['devices']! as LcList).elements.single)
              as LcGroup;
      expect((device['name']! as LcString).text, 'MX Master 3S');
      expect(device['dpi'], LcInt(1600));
      final buttons = (device['buttons']! as LcList).elements.cast<LcGroup>();
      expect(
        buttons.map((b) => (b['cid']! as LcInt).format),
        everyElement(LcIntFormat.hex),
      );
      expect(buttons.map((b) => (b['cid']! as LcInt).value), [0xc3, 0xc4]);
      final gestures =
          ((buttons.first['action']! as LcGroup)['gestures']! as LcList)
              .elements;
      expect(gestures, hasLength(5));
    });

    test("logiops' example file is all comments", () {
      final text = File('../../fixtures/logid/logid.example.cfg')
          .readAsStringSync();
      expect(parseLibconfig(text).settings, isEmpty);
    });

    test('the example becomes a valid config when uncommented', () {
      final text = File('../../fixtures/logid/logid.example.cfg')
          .readAsLinesSync()
          .map((l) => l.replaceFirst(RegExp(r'^# ?'), ''))
          .join('\n');
      final device =
          ((parseLibconfig(text)['devices']! as LcList).elements.single)
              as LcGroup;
      expect(device['dpi'], LcInt(1000));
      expect(
        utf8.decode((device['name']! as LcString).bytes),
        'Wireless Mouse MX Master',
      );
    });
  });
}
