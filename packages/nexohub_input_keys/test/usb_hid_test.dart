import 'package:nexohub_input_keys/nexohub_input_keys.dart';
import 'package:test/test.dart';

/// (Flutter usbHidUsage, expected evdev name) — first block observed key by
/// key on the maintainer's ABNT2 keyboard in Nexo spike S3 (2026-10-27).
const observedInSpikeS3 = [
  (0x00070004, 'KEY_A'),
  (0x0007001d, 'KEY_Z'),
  (0x0007001e, 'KEY_1'),
  (0x00070027, 'KEY_0'),
  (0x000700e3, 'KEY_LEFTMETA'), // Super
  (0x00070033, 'KEY_SEMICOLON'), // ABNT2 "Ç"
  (0x0007002f, 'KEY_LEFTBRACE'), // ABNT2 "´" (dead key)
  (0x000700e5, 'KEY_RIGHTSHIFT'),
  (0x000700e0, 'KEY_LEFTCTRL'),
  (0x000700e2, 'KEY_LEFTALT'),
  (0x000700e6, 'KEY_RIGHTALT'), // AltGr
  (0x000700e1, 'KEY_LEFTSHIFT'),
  (0x0007003a, 'KEY_F1'),
  (0x0007003e, 'KEY_F5'),
  (0x00070045, 'KEY_F12'),
  (0x0007004a, 'KEY_HOME'),
  (0x0007004d, 'KEY_END'),
  (0x0007004b, 'KEY_PAGEUP'),
  (0x0007004e, 'KEY_PAGEDOWN'),
];

/// Keys not pressed during S3 (standard Linux HID ↔ evdev mapping).
const notObservedInSpikeS3 = [
  (0x00070029, 'KEY_ESC'),
  (0x0007002b, 'KEY_TAB'),
  (0x000700e4, 'KEY_RIGHTCTRL'),
  (0x0007004f, 'KEY_RIGHT'),
  (0x00070050, 'KEY_LEFT'),
  (0x00070051, 'KEY_DOWN'),
  (0x00070052, 'KEY_UP'),
  (0x00070034, 'KEY_APOSTROPHE'), // ABNT2 "~"
  (0x00070087, 'KEY_RO'), // ABNT2 "/" next to right Shift
  (0x00070064, 'KEY_102ND'), // ABNT2 "\" next to left Shift
  (0x00070046, 'KEY_SYSRQ'), // Print Screen
];

void main() {
  const table = TableEvdevCatalog.instance;

  for (final (label, cases) in [
    ('observed in spike S3', observedInSpikeS3),
    ('standard keys not observed in S3', notObservedInSpikeS3),
  ]) {
    test('physical key → evdev: $label', () {
      for (final (usage, name) in cases) {
        final code = evdevCodeForUsbHidUsage(usage);
        expect(
          code,
          table.keyCode(name),
          reason: '0x${usage.toRadixString(16)} → $name',
        );
        expect(usbHidUsageForEvdevCode(code!), usage);
      }
    });
  }

  test('every mapped evdev code has a libevdev name', () {
    for (final code in evdevCodesWithPhysicalKey) {
      expect(table.keyName(code), isNotNull, reason: '$code');
    }
    expect(evdevCodesWithPhysicalKey.length, greaterThan(200));
  });

  test('mouse buttons have no keyboard position', () {
    expect(usbHidUsageForEvdevCode(table.keyCode('BTN_LEFT')!), isNull);
    expect(evdevCodeForUsbHidUsage(0x7fffffff), isNull);
  });

  test('media keys (captured by GNOME, chosen from the list in the UI)', () {
    final volumeUp = table.keyCode('KEY_VOLUMEUP')!;
    expect(
      evdevCodeForUsbHidUsage(usbHidUsageForEvdevCode(volumeUp)!),
      volumeUp,
    );
  });
}
