// Differential tests: this package versus the real libconfig 1.7.3
// (tool/libconfig_check). For every input both must agree on acceptance and,
// when accepted, on the exact tree.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

import '../support/generators.dart';
import '../support/reference_parser.dart';

/// Hand-written edge cases (valid and invalid).
const corpus = <String>[
  '', '# only a comment', 'a = 1;', 'a : 1, b = 2 c = 3', //
  'a = 010;', 'a = 08;', 'a = 00;', 'a = -010;', 'a = 0x1F;', 'a = 0X1f;',
  'a = 0xffffffff;', 'a = 0x100000001;', 'a = 3000000000;', 'a = 2147483647;',
  'a = 2147483648;', 'a = -2147483649;', 'a = 9223372036854775807;',
  'a = 9223372036854775808;', 'a = 5L;', 'a = 5LL;', 'a = 007L;', 'a = 10l;',
  'a = 0x1fL;', 'a = 0xFFFFFFFFFFFFFFFFL;', 'a = 0x1FFFFFFFFFFFFFFFFL;',
  'a = 99999999999999999999L;', 'a = -99999999999999999999L;',
  'a = 1.5;',
  'a = .5;',
  'a = 5.;',
  'a = .;',
  'a = -.;',
  'a = +.e5;',
  'a = 1e5;',
  'a = 1E-5;', 'a = 1.e3;', 'a = 1e;', 'a = 1e999;', 'a = -0.0;', 'a = 08.5;',
  'a = 1e-999;', 'a = 0.1;', 'a = 123456789012345678901234567890.0;',
  r'a = "\n\r\t\f\\\"";', r'a = "\x41\X42\x4g";', r'a = "\q";', 'a = "x" "y";',
  r'a = "a\x00b" "c";', 'a = "multi\nline";', 'a = "unterminated',
  'a = true; b = FALSE; c = True;', 'true = 1;', 'True1 = 1;', 'TRUEx = 1;',
  'a = [1, 2,,];', 'a = [,1];', 'a = [1 2];', 'a = (1,, 2,);', 'a = ();',
  'a = [];', 'a = {};', 'a = [1, 2L];', 'a = [1, 0x2];', 'a = [1.0, 2];',
  'a = [ {} ];',
  'a = ( [1], {b = 2;}, ("x") );',
  'a = 1; a = 2;',
  'a = 1; A = 2;',
  'a = { b = 1; b = 2; };', 'a = 1; /* never closed', 'a = 1 // trailing',
  'a = 1 ?', 'a = 1; @include "missing.cfg"', '@include "missing.cfg"\n',
  '*a = 1; x-1 = 2; A_b = 3;', '_a = 1;', '1a = 1;', 'a = -;', 'a = +;',
  'a = { b = ( { c = [1,2,3]; } ); };', 'a =', 'a = {', 'a = 1;;', ';',
  'a = 1\r\nb = 2\r\n', 'a\f=\f1;', 'a = "ç😀";', 'devices: ({ name: "MX"; });',
];

/// Scale and seed of the generated-text test. CI uses the defaults; run
/// `NEXO_FUZZ_ITERATIONS=100000 NEXO_FUZZ_SEED=7 dart test` for deeper runs.
final fuzzIterations =
    int.tryParse(Platform.environment['NEXO_FUZZ_ITERATIONS'] ?? '') ?? 5000;
final fuzzSeed =
    int.tryParse(Platform.environment['NEXO_FUZZ_SEED'] ?? '') ?? 271026;

void main() {
  final skip = referenceSkipReason;

  Future<void> compare(List<List<int>> inputs, String label) async {
    final reference = await referenceParse(inputs);
    for (var i = 0; i < inputs.length; i++) {
      Object? ours;
      String? ourError;
      try {
        ours = toReferenceJson(parseLibconfigBytes(inputs[i]));
      } on LibconfigSyntaxError catch (e) {
        ourError = '$e';
      }
      final ref = reference[i];
      final input = utf8.decode(inputs[i], allowMalformed: true);
      final where = '$label #$i, input:\n$input\n---';
      if (ref.ok) {
        expect(
          ourError,
          isNull,
          reason: 'libconfig accepts but we reject. $where',
        );
        expect(
          jsonEncode(ours),
          jsonEncode(ref.tree),
          reason: 'different tree. $where',
        );
      } else {
        expect(
          ourError,
          isNotNull,
          reason:
              'libconfig rejects (${ref.errorText}, line ${ref.errorLine}) '
              'but we accept. $where',
        );
      }
    }
  }

  test('hand-written corpus', () async {
    await compare([for (final c in corpus) utf8.encode(c)], 'corpus');
  }, skip: skip);

  test('fixtures', () async {
    await compare([
      File('../../fixtures/logid/user-original-2026-10-27.cfg')
          .readAsBytesSync(),
      File('../../fixtures/logid/logid.example.cfg').readAsBytesSync(),
    ], 'fixture');
  }, skip: skip);

  test(
    '$fuzzIterations generated texts (valid and mutated), seed $fuzzSeed',
    () async {
      final gen = TextGenerator(fuzzSeed);
      for (var done = 0; done < fuzzIterations; done += 5000) {
        final n = fuzzIterations - done < 5000 ? fuzzIterations - done : 5000;
        await compare([for (var i = 0; i < n; i++) gen.next()], 'generated');
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'writer output is read by libconfig as the same tree',
    () async {
      final gen = TreeGenerator(1600);
      final trees = [for (var i = 0; i < 2000; i++) gen.document()];
      final texts = [
        for (final t in trees)
          Uint8List.fromList(utf8.encode(writeLibconfig(t))),
      ];
      final reference = await referenceParse(texts);
      for (var i = 0; i < trees.length; i++) {
        expect(
          reference[i].ok,
          isTrue,
          reason:
              'rejected: ${reference[i].errorText}\n${utf8.decode(texts[i])}',
        );
        expect(
          jsonEncode(reference[i].tree),
          jsonEncode(toReferenceJson(trees[i])),
          reason: 'tree #$i:\n${utf8.decode(texts[i])}',
        );
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
