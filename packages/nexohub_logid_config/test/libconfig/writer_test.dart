import 'dart:io';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

import '../support/generators.dart';

void main() {
  test('canonical layout', () {
    final root = LcGroup([
      LcSetting('a', LcInt(1)),
      LcSetting('cid', LcInt(0xc3, format: LcIntFormat.hex)),
      LcSetting('big', const LcInt64(-5)),
      LcSetting('f', LcFloat(100)),
      LcSetting('s', LcString.fromText('Padrão "x"\n')),
      LcSetting('arr', LcArray([LcInt(1), LcInt(2)])),
      LcSetting('empty', LcGroup(const [])),
      LcSetting(
        'l',
        LcList([
          const LcBool(true),
          LcGroup([LcSetting('b', LcInt(2))]),
        ]),
      ),
    ]);
    expect(writeLibconfig(root, header: 'Managed by Nexo'), '''
# Managed by Nexo

a: 1;
cid: 0xc3;
big: -5L;
f: 100.0;
s: "Padrão \\"x\\"\\n";
arr: [1, 2];
empty: {};
l: (
    true,
    {
        b: 2;
    }
);
''');
  });

  test('values that need care are written so they read back exactly', () {
    final root = LcGroup([
      LcSetting('neghex', LcInt(-1, format: LcIntFormat.hex)),
      LcSetting('neghex64', const LcInt64(-1, format: LcIntFormat.hex)),
      LcSetting('negzero', LcFloat(-0.0)),
      LcSetting('inf', LcFloat(double.infinity)),
      LcSetting('tiny', LcFloat(5e-324)),
      LcSetting('bytes', LcString(const [0x01, 0xFF, 0x7F, 0xC3, 0xA7])),
    ]);
    final text = writeLibconfig(root);
    expect(text, contains('neghex: 0xffffffff;'));
    expect(text, contains('neghex64: 0xffffffffffffffffL;'));
    expect(text, contains(r'bytes: "\x01\xff\x7fç";'));
    expect(parseLibconfig(text), root);
  });

  test('integer format survives a round trip', () {
    final text = writeLibconfig(parseLibconfig('a = 0xc3; b = 195;'));
    final g = parseLibconfig(text);
    expect((g['a']! as LcInt).format, LcIntFormat.hex);
    expect((g['b']! as LcInt).format, LcIntFormat.decimal);
  });

  test("the user's original config round-trips", () {
    final original = parseLibconfig(
      File('../../fixtures/logid/user-original-2026-10-27.cfg')
          .readAsStringSync(),
    );
    expect(parseLibconfig(writeLibconfig(original)), original);
  });

  test('2000 random trees round-trip through text', () {
    final gen = TreeGenerator(20261027);
    for (var i = 0; i < 2000; i++) {
      final tree = gen.document();
      final text = writeLibconfig(tree);
      expect(parseLibconfig(text), tree, reason: 'tree #$i:\n$text');
    }
  });

  test('invalid trees cannot be built', () {
    expect(() => LcInt(0x80000000), throwsRangeError);
    expect(() => LcFloat(double.nan), throwsArgumentError);
    expect(() => LcString(const [0x61, 0x00]), throwsArgumentError);
    expect(() => LcSetting('true', LcInt(1)), throwsArgumentError);
    expect(() => LcSetting('1a', LcInt(1)), throwsArgumentError);
    expect(
      () => LcGroup([LcSetting('a', LcInt(1)), LcSetting('a', LcInt(2))]),
      throwsArgumentError,
    );
    expect(() => LcArray([LcInt(1), const LcInt64(1)]), throwsArgumentError);
    expect(() => LcArray([LcList(const [])]), throwsArgumentError);
  });
}
