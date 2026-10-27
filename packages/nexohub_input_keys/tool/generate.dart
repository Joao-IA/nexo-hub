// Regenerates lib/src/generated/*.g.dart.
//
//   cd packages/nexohub_input_keys && dart run tool/generate.dart
//
// Needs: /usr/include/linux/input-event-codes.h (linux-libc-dev),
// libevdev.so.2 (libevdev2) and the Flutter SDK pinned in .fvmrc.
// Run it on the target system (Ubuntu) after updating any of them.
import 'dart:io';

import 'package:nexohub_input_keys/src/libevdev_ffi.dart';

import 'src/generator.dart';

void main() {
  final lib = Libevdev.open() ?? (throw StateError('libevdev.so.2 not found'));
  final libevdevVersion = dpkgVersion('libevdev2') ?? 'unknown';
  final headersVersion = dpkgVersion('linux-libc-dev') ?? 'unknown';
  final evdev = buildEvdevTables(File(headerPath).readAsStringSync(), lib);
  File('lib/src/generated/evdev_tables.g.dart').writeAsStringSync(
    renderEvdevTables(
      evdev,
      libevdev: libevdevVersion,
      headers: headersVersion,
    ),
  );

  final root = findFlutterRoot() ?? (throw StateError('Flutter SDK not found'));
  final sources = flutterKeySources(root);
  final usb = buildUsbHidTable(
    keyboardKeySource: sources.keyboardKey,
    keyboardMapsSource: sources.keyboardMaps,
    keyCanonical: evdev.keyCanonical,
  );
  File('lib/src/generated/usb_hid_tables.g.dart').writeAsStringSync(
    renderUsbHidTable(usb.table, flutter: flutterVersion(root)),
  );

  stdout
    ..writeln(
      'libevdev2 $libevdevVersion, linux-libc-dev $headersVersion, Flutter ${flutterVersion(root)}',
    )
    ..writeln(
      'EV_KEY: ${evdev.keyCodes.length} names, ${evdev.keyCanonical.length} codes',
    )
    ..writeln(
      'EV_REL: ${evdev.relCodes.length} names, ${evdev.relCanonical.length} codes',
    )
    ..writeln(
      'header names rejected by libevdev (${evdev.rejected.length}): ${evdev.rejected.join(', ')}',
    )
    ..writeln(
      'USB HID → evdev: ${usb.table.length} keys; skipped: ${usb.skipped.join(', ')}',
    );
}
