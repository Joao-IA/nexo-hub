// Differential tests: this package's decoder/encoder versus logid 0.3.5's
// own config code (tool/logid_config_check). For each input both must
// produce the same decoded configuration and the same logged warnings.
import 'dart:convert';
import 'dart:io';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

import '../support/logid_reference.dart';
import '../support/model_generators.dart';

final fuzzIterations =
    int.tryParse(Platform.environment['NEXO_FUZZ_ITERATIONS'] ?? '') ?? 5000;
final fuzzSeed =
    int.tryParse(Platform.environment['NEXO_FUZZ_SEED'] ?? '') ?? 1600;

/// Hand-written cases around logid's decoding rules.
const corpus = <String>[
  'devices: ({ name: "M"; dpi: 1600L; });',
  'devices: ({ name: "M"; dpi: 1.5; });',
  'devices: ({ name: "M"; dpi: (800, "x", 400); });',
  'devices: ({ name: "M"; smartshift: { on: true; threshold: 20.0; }; });',
  'devices: ({ name: "M"; smartshift: 5; });',
  'devices: ({ name: "M"; smartshift: { threshold: -1; torque: 150; }; });',
  'io_timeout = 500;',
  'io_timeout = 500.0; workers = 2; ignore = [0xc52b, 0xc52b, 70000];',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3; action = {type: "None";};}, {cid: 0xc3; action = {type: "Bogus";};}); });',
  'devices: ({ name: "M";\n buttons: (\n {cid: "x";\n action = {type: "Bogus";};});\n});',
  'devices: ({ name: "M"; buttons: ({cid: 0x100c4; action = {type: "keypress"; keys: "KEY_A";};}); });',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3L;}); });',
  'devices: ({ name: "M"; profiles: ({name: "p"; dpi: 800;}); dpi: 400; });',
  'devices: ({ name: "M"; default_profile: "p"; profiles: ({name: "p"; dpi: 800;}); dpi: 400; });',
  'devices: ({ name: "M"; default_profile: "p"; profiles: (); });',
  'devices: ({ name: "M"; default_profile: 3; profiles: ({name: "p";}); });',
  'devices: ({ name: "M"; default_profile: "x"; profiles: ({name: "a";}, {name: "a"; dpi: 1;}, {dpi: 2;}); });',
  'devices: ({ name: "M"; }, { name: "M"; dpi: 1; }, { dpi: 2; }, 5);',
  'devices: ({ name: "M"; hiresscroll: true; });',
  'devices: ({ name: "M"; hiresscroll: { hires: true; up: { mode: "OnInterval"; interval: 1; action = { type: "Keypress"; keys: ["KEY_VOLUMEUP"]; }; }; }; });',
  'devices: ({ name: "M"; hiresscroll: 3; });',
  'devices: ({ name: "M"; thumbwheel: { divert: true; tap: { type: "Gestures"; }; left: { mode: "Bogus"; }; }; });',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3; action = {type: "Gestures"; gestures: ({direction: "Up"; mode: "OnRelease";}, {direction: "up"; mode: "NoPress";}, {direction: "Diagonal"; mode: "onrelease";}, {mode: "OnRelease";}, {direction: "Left"; mode: "Bogus";});};}); });',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3; action = {type: "Keypress"; keys: ("KEY_A", 30, 1.5);};}, {cid: 0xc4; action = {type: "Keypress"; keys: 2.5;};}, {cid: 0x53; action = {type: "Keypress"; keys: { a = "KEY_B"; };};}); });',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3; action = {type: "ChangeHost"; host: 1.5;};}, {cid: 0xc4; action = {type: "ChangeHost"; host: "Next";};}); });',
  'devices: ({ name: "M"; buttons: ({cid: 0xc3; action = {type: "\\xe2\\x84\\xaaeypress"; keys: "KEY_A";};}); });',
  'devices: ({ name: "M"; thumbwheel: { left: { mode: "Axis"; axis: "REL_HWHEEL"; axis_multiplier: 2; }; right: { mode: "Axis"; axis: 6; axis_multiplier: 0.5; }; }; });',
  'devices: 5; ignore: "x"; workers: 1.0;',
  'devices: { a: { name: "M"; dpi: 800; }; };',
  'unknown_top = 1; devices: ({ name: "M"; foo: 1; smartshift: { bar: 2; }; });',
];

void main() {
  final skip = logidSkipReason;

  Future<void> compare(List<List<int>> inputs, String label) async {
    final reference = await logidDecode(inputs);
    for (var i = 0; i < inputs.length; i++) {
      final text = utf8.decode(inputs[i], allowMalformed: true);
      final where = '$label #$i, input:\n$text\n---';
      final ref = reference[i];
      if (ref.parseError != null) {
        expect(
          () => parseLibconfigBytes(inputs[i]),
          throwsA(isA<LibconfigSyntaxError>()),
          reason: 'libconfig rejects it. $where',
        );
        continue;
      }
      final ours = decodeLogidConfig(parseLibconfigBytes(inputs[i]));
      expect(
        jsonEncode(toLogidJson(ours.config)),
        jsonEncode(ref.decoded),
        reason: 'logid decodes it differently. $where',
      );
      expect(
        loggedLinesOf(ours),
        [...ref.loggedLines]..sort(),
        reason: 'different logged warnings. issues: ${ours.issues}\n$where',
      );
    }
  }

  test('hand-written corpus', () async {
    await compare([for (final c in corpus) bytesOf(c)], 'corpus');
  }, skip: skip);

  test('fixtures', () async {
    final example = File('../../fixtures/logid/logid.example.cfg')
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'^# ?'), ''))
        .join('\n');
    await compare([
      File('../../fixtures/logid/user-original-2026-10-27.cfg')
          .readAsBytesSync(),
      bytesOf(example),
    ], 'fixture');
  }, skip: skip);

  test(
    '$fuzzIterations generated logid configs with mistakes, seed $fuzzSeed',
    () async {
      final gen = LogidTreeGenerator(fuzzSeed);
      for (var done = 0; done < fuzzIterations; done += 2000) {
        final n = fuzzIterations - done < 2000 ? fuzzIterations - done : 2000;
        await compare([
          for (var i = 0; i < n; i++) bytesOf(writeLibconfig(gen.document())),
        ], 'generated');
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'encoded models are decoded by logid as the same model, silently',
    () async {
      final gen = ModelGenerator(42);
      final models = [for (var i = 0; i < 2000; i++) gen.config()];
      final texts = [for (final m in models) bytesOf(writeLogidConfig(m))];
      final reference = await logidDecode(texts);
      for (var i = 0; i < models.length; i++) {
        final where = 'model #$i:\n${utf8.decode(texts[i])}';
        expect(reference[i].parseError, isNull, reason: where);
        expect(reference[i].loggedLines, isEmpty, reason: where);
        expect(
          jsonEncode(reference[i].decoded),
          jsonEncode(toLogidJson(models[i])),
          reason: where,
        );
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
