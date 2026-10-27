// The committed tables must equal what tool/generate.dart produces now.
import 'dart:io';

import 'package:nexohub_input_keys/nexohub_input_keys.dart';
import 'package:nexohub_input_keys/src/generated/evdev_tables.g.dart'
    show evdevKeyCanonicalNames;
import 'package:nexohub_input_keys/src/libevdev_ffi.dart';
import 'package:test/test.dart';

import '../tool/src/generator.dart';

void main() {
  final flutterRoot = findFlutterRoot();

  test('USB HID table matches the Flutter SDK pinned in .fvmrc', () {
    final version = flutterVersion(flutterRoot!);
    expect(
      version,
      generatedForFlutter,
      reason: 'Flutter changed: run `dart run tool/generate.dart` and commit',
    );
    final sources = flutterKeySources(flutterRoot);
    // Filter by the committed evdev names (not this system's libevdev), so the
    // check is deterministic on any machine, CI included.
    final usb = buildUsbHidTable(
      keyboardKeySource: sources.keyboardKey,
      keyboardMapsSource: sources.keyboardMaps,
      keyCanonical: evdevKeyCanonicalNames,
    );
    expect(
      renderUsbHidTable(usb.table, flutter: version),
      File('lib/src/generated/usb_hid_tables.g.dart').readAsStringSync(),
    );
  }, skip: flutterRoot == null ? 'Flutter SDK not found' : null);

  test('evdev tables match this system (libevdev + kernel headers)', () {
    final lib = Libevdev.open()!;
    final tables = buildEvdevTables(File(headerPath).readAsStringSync(), lib);
    expect(
      renderEvdevTables(
        tables,
        libevdev: generatedForLibevdev,
        headers: generatedForKernelHeaders,
      ),
      File('lib/src/generated/evdev_tables.g.dart').readAsStringSync(),
      reason: 'run `dart run tool/generate.dart` and commit',
    );
  }, skip: _evdevSkipReason());
}

String? _evdevSkipReason() {
  if (Libevdev.open() == null) return 'libevdev.so.2 not installed';
  final libevdev = dpkgVersion('libevdev2');
  final headers = dpkgVersion('linux-libc-dev');
  if (libevdev != generatedForLibevdev ||
      headers != generatedForKernelHeaders) {
    return 'tables were generated with libevdev2 $generatedForLibevdev and '
        'linux-libc-dev $generatedForKernelHeaders (this system: $libevdev, $headers)';
  }
  return null;
}
