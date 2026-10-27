// Mapping between Flutter physical keys and evdev key codes.
//
// Flutter reports `KeyEvent.physicalKey.usbHidUsage` (position on the
// keyboard, independent of the layout). logid emits evdev codes, which are
// also positions. Storing the evdev code and showing the layout's label is
// what makes shortcuts work on any layout (e.g. the ABNT2 `Ç` key is
// KEY_SEMICOLON). Verified key by key in Nexo spike S3.
import 'generated/usb_hid_tables.g.dart';

final Map<int, int> _evdevToUsb = {
  for (final e in usbHidUsageToEvdev.entries) e.value: e.key,
};

/// The evdev key code for a Flutter `PhysicalKeyboardKey.usbHidUsage`, or
/// null when Linux has no evdev code for it.
int? evdevCodeForUsbHidUsage(int usbHidUsage) =>
    usbHidUsageToEvdev[usbHidUsage];

/// The Flutter `PhysicalKeyboardKey.usbHidUsage` for an evdev key code, or
/// null when Flutter has no physical key for it (e.g. mouse buttons).
int? usbHidUsageForEvdevCode(int evdevCode) => _evdevToUsb[evdevCode];

/// Every evdev code that has a Flutter physical key.
Iterable<int> get evdevCodesWithPhysicalKey => usbHidUsageToEvdev.values;
