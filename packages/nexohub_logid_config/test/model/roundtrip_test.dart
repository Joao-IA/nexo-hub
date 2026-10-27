import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

import '../support/model_generators.dart';

void main() {
  test('3000 random models survive write → parse → decode unchanged', () {
    final gen = ModelGenerator(2026);
    for (var i = 0; i < 3000; i++) {
      final model = gen.config();
      final text = writeLogidConfig(model);
      final result = parseLogidConfig(text);
      expect(result.config, model, reason: 'model #$i:\n$text');
      expect(
        result.issues.where((x) => x.code != DecodeIssueCode.unknownKey),
        isEmpty,
        reason: 'model #$i:\n$text',
      );
    }
  });

  test('decoding is idempotent on generated mistaken configs', () {
    final gen = LogidTreeGenerator(7);
    for (var i = 0; i < 2000; i++) {
      final first = decodeLogidConfig(gen.document()).config;
      final second = parseLogidConfig(writeLogidConfig(first));
      expect(second.config, first, reason: 'config #$i');
    }
  });

  group('invalid models cannot be built', () {
    test('duplicate keys', () {
      expect(
        () => Profile(
          name: 'p',
          buttons: [ButtonConfig(cid: 1), ButtonConfig(cid: 1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => GesturesAction(
          gestures: [
            DirectionalGesture('Up', NoPressGesture()),
            DirectionalGesture('UP', NoPressGesture()),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => DeviceConfig(
          name: 'M',
          defaultProfile: 'a',
          profiles: [
            Profile(name: 'a'),
            Profile(name: 'a'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a device needs at least one profile', () {
      expect(
        () => DeviceConfig(
          name: 'M',
          defaultProfile: 'default',
          profiles: const [],
        ),
        throwsArgumentError,
      );
    });

    test('extras cannot shadow known keys', () {
      expect(
        () => Profile(name: 'p', extra: [LcSetting('dpi', LcInt(1))]),
        throwsArgumentError,
      );
      expect(
        () => Profile(name: 'p', extra: [LcSetting('profiles', LcInt(1))]),
        throwsArgumentError,
      );
      expect(
        () => KeypressAction(extra: [LcSetting('type', LcInt(1))]),
        throwsArgumentError,
      );
      expect(
        () => ReleaseGesture(extra: [LcSetting('direction', LcInt(1))]),
        throwsArgumentError,
      );
    });

    test('values out of range', () {
      expect(() => ButtonConfig(cid: 0x10000), throwsRangeError);
      expect(() => KeyCode(-1), throwsRangeError);
      expect(() => SmartShiftConfig(threshold: 1 << 32), throwsRangeError);
      expect(() => FixedDpi(1 << 31), throwsRangeError);
    });
  });
}
