import 'package:nexohub_input_keys/nexohub_input_keys.dart';
import 'package:nexohub_input_keys/src/generated/evdev_tables.g.dart';
import 'package:test/test.dart';

import '../tool/src/generator.dart';

final libevdev = LibevdevCatalog.open();

/// Strict comparison only on the system the tables were generated on.
final bool sameSystemAsGeneration =
    dpkgVersion('libevdev2') == generatedForLibevdev &&
    dpkgVersion('linux-libc-dev') == generatedForKernelHeaders;

void main() {
  const table = TableEvdevCatalog.instance;

  group('generated tables', () {
    test('well-known names', () {
      expect(table.keyCode('KEY_A'), 30);
      expect(table.keyCode('KEY_LEFTMETA'), 125);
      expect(table.keyCode('KEY_VOLUMEUP'), 115);
      expect(table.keyCode('BTN_LEFT'), 0x110);
      expect(table.relativeAxisCode('REL_WHEEL'), 8);
      expect(table.relativeAxisCode('REL_WHEEL_HI_RES'), 11);
      expect(table.keyName(0x110), 'BTN_LEFT');
      expect(table.relativeAxisName(6), 'REL_HWHEEL');
    });

    test('kernel-header aliases libevdev rejects are not accepted', () {
      // logid would log "Invalid keycode … skipping" for these.
      for (final alias in [
        'KEY_HANGUEL',
        'KEY_SCREENLOCK',
        'KEY_ZOOM',
        'BTN_MISC',
      ]) {
        expect(table.keyCode(alias), isNull, reason: alias);
      }
      expect(table.keyCode('KEY_COFFEE'), isNotNull); // the canonical name
    });

    test('names are exact (case-sensitive), like libevdev', () {
      expect(table.keyCode('key_a'), isNull);
      expect(table.keyCode('KEY_FOO'), isNull);
    });

    test('every canonical name resolves back to its code', () {
      for (final MapEntry(key: code, value: name)
          in evdevKeyCanonicalNames.entries) {
        expect(table.keyCode(name), code, reason: name);
      }
      expect(table.keyNames.length, greaterThan(600));
    });
  });

  group('versus the system libevdev (what logid uses)', () {
    final skip = libevdev == null ? 'libevdev.so.2 not installed' : null;

    test('every table name resolves to the same code', () {
      final unknown = <String>[];
      for (final name in table.keyNames) {
        final code = libevdev!.keyCode(name);
        if (code == null) {
          unknown.add(name);
        } else {
          expect(code, table.keyCode(name), reason: name);
        }
      }
      for (final name in table.relativeAxisNames) {
        expect(
          libevdev!.relativeAxisCode(name),
          anyOf(isNull, table.relativeAxisCode(name)),
          reason: name,
        );
      }
      if (sameSystemAsGeneration) expect(unknown, isEmpty);
    }, skip: skip);

    test('every name libevdev reports is in the table', () {
      for (var code = 0; code <= keyMax; code++) {
        final name = libevdev!.keyName(code);
        if (name == null) continue;
        expect(
          table.keyCode(name),
          code,
          reason: '$name — regenerate with tool/generate.dart',
        );
        if (sameSystemAsGeneration) expect(table.keyName(code), name);
      }
      for (var code = 0; code <= relMax; code++) {
        final name = libevdev!.relativeAxisName(code);
        if (name != null) {
          expect(table.relativeAxisCode(name), code, reason: name);
        }
      }
    }, skip: skip);

    test('EvdevCatalog.system() uses libevdev when present', () {
      expect(EvdevCatalog.system(), isA<LibevdevCatalog>());
      expect(EvdevCatalog.system().keyCode('KEY_LEFTCTRL'), 29);
      expect(libevdev!.keyNames, containsAll(['KEY_A', 'BTN_LEFT', 'KEY_MAX']));
    }, skip: skip);
  });
}
