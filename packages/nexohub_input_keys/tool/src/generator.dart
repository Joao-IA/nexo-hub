// Builds the generated tables of nexohub_input_keys. Used by
// tool/generate.dart (writes the files) and by test/generation_test.dart
// (checks the committed files are up to date).
import 'dart:convert';
import 'dart:io';

import 'package:nexohub_input_keys/src/libevdev_ffi.dart';

/// Default location of the kernel event-code header.
const headerPath = '/usr/include/linux/input-event-codes.h';

/// Evdev name tables, filtered by the system libevdev.
final class EvdevTables {
  EvdevTables._(
    this.keyCodes,
    this.keyCanonical,
    this.relCodes,
    this.relCanonical,
    this.rejected,
  );

  /// EV_KEY name → code.
  final Map<String, int> keyCodes;

  /// EV_KEY code → canonical name.
  final Map<int, String> keyCanonical;

  /// EV_REL name → code.
  final Map<String, int> relCodes;

  /// EV_REL code → canonical name.
  final Map<int, String> relCanonical;

  /// Header names libevdev does not accept (e.g. aliases), for the report.
  final List<String> rejected;
}

/// Parses `#define NAME VALUE` lines, resolving aliases (`#define A B`).
Map<String, int> parseDefines(String header) {
  final raw = <String, String>{};
  final define = RegExp(r'^#define\s+([A-Z][A-Z0-9_]*)\s+([^\s/]+)');
  for (final line in const LineSplitter().convert(header)) {
    final m = define.firstMatch(line);
    if (m != null) raw[m.group(1)!] = m.group(2)!;
  }
  int? resolve(String name, [int depth = 0]) {
    final value = raw[name];
    if (value == null || depth > 8) return null;
    if (value.startsWith('0x')) {
      return int.tryParse(value.substring(2), radix: 16);
    }
    return int.tryParse(value) ?? resolve(value, depth + 1);
  }

  return {for (final name in raw.keys) name: ?resolve(name)};
}

/// Builds the tables: header names accepted by [lib] plus every canonical
/// name [lib] reports. Throws if libevdev and the header disagree on a code.
EvdevTables buildEvdevTables(String header, Libevdev lib) {
  final defines = parseDefines(header);
  final rejected = <String>[];

  (Map<String, int>, Map<int, String>) table(
    int type,
    int max,
    bool Function(String) isCandidate,
  ) {
    final codes = <String, int>{};
    for (final MapEntry(key: name, value: value) in defines.entries) {
      if (!isCandidate(name)) continue;
      final code = lib.codeFromName(type, name);
      if (code == null) {
        rejected.add(name);
      } else if (code != value) {
        throw StateError('$name is $value in the header but $code in libevdev');
      } else {
        codes[name] = code;
      }
    }
    final canonical = <int, String>{};
    for (var code = 0; code <= max; code++) {
      final name = lib.nameOfCode(type, code);
      if (name == null) continue;
      canonical[code] = name;
      if (lib.codeFromName(type, name) != code) {
        throw StateError(
          'libevdev names $code "$name" but does not resolve it back',
        );
      }
      codes[name] = code;
    }
    return (codes, canonical);
  }

  final (keyCodes, keyCanonical) = table(
    evKey,
    keyMax,
    (n) => n.startsWith('KEY_') || n.startsWith('BTN_'),
  );
  final (relCodes, relCanonical) = table(
    evRel,
    relMax,
    (n) => n.startsWith('REL_'),
  );
  return EvdevTables._(
    keyCodes,
    keyCanonical,
    relCodes,
    relCanonical,
    rejected..sort(),
  );
}

/// Flutter physical key (USB HID usage) → evdev code, from the Flutter SDK's
/// Linux table (`kLinuxToPhysicalKey`: XKB keycode → key; evdev = XKB − 8).
/// Keys whose evdev code libevdev does not name are skipped.
({Map<int, int> table, List<String> skipped}) buildUsbHidTable({
  required String keyboardKeySource,
  required String keyboardMapsSource,
  required Map<int, String> keyCanonical,
}) {
  final usageOf = <String, int>{
    for (final m in RegExp(
      r'static const PhysicalKeyboardKey (\w+) = PhysicalKeyboardKey\((0x[0-9a-fA-F]+)\);',
    ).allMatches(keyboardKeySource))
      m.group(1)!: int.parse(m.group(2)!.substring(2), radix: 16),
  };
  final start = keyboardMapsSource.indexOf('kLinuxToPhysicalKey = ');
  final end = keyboardMapsSource.indexOf('};', start);
  if (start < 0 || end < 0) throw StateError('kLinuxToPhysicalKey not found');
  final table = <int, int>{};
  final skipped = <String>[];
  for (final m in RegExp(
    r'(0x[0-9a-fA-F]+): PhysicalKeyboardKey\.(\w+),',
  ).allMatches(keyboardMapsSource.substring(start, end))) {
    final evdev = int.parse(m.group(1)!.substring(2), radix: 16) - 8;
    final usage =
        usageOf[m.group(2)!] ??
        (throw StateError('unknown PhysicalKeyboardKey.${m.group(2)}'));
    if (!keyCanonical.containsKey(evdev)) {
      skipped.add('${m.group(2)} (evdev $evdev)');
    } else if (table.containsKey(usage)) {
      skipped.add('${m.group(2)} (duplicate usage)');
    } else {
      table[usage] = evdev;
    }
  }
  return (table: table, skipped: skipped);
}

/// Installed version of a Debian package, or null.
String? dpkgVersion(String package) {
  try {
    final r = Process.runSync('dpkg-query', ['-W', r'-f=${Version}', package]);
    return r.exitCode == 0 ? (r.stdout as String).trim() : null;
  } on ProcessException {
    return null;
  }
}

/// The Flutter SDK root: `$FLUTTER_ROOT`, else derived from `flutter` in PATH.
Directory? findFlutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return Directory(env);
  for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
    final exe = File('$dir/flutter');
    if (exe.existsSync()) {
      return Directory(exe.resolveSymbolicLinksSync()).parent.parent;
    }
  }
  return null;
}

/// Framework version of the Flutter SDK at [root].
String flutterVersion(Directory root) {
  final file = File('${root.path}/bin/cache/flutter.version.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return json['frameworkVersion']! as String;
}

/// Flutter source files with the key tables.
({String keyboardKey, String keyboardMaps}) flutterKeySources(Directory root) {
  final dir = '${root.path}/packages/flutter/lib/src/services';
  return (
    keyboardKey: File('$dir/keyboard_key.g.dart').readAsStringSync(),
    keyboardMaps: File('$dir/keyboard_maps.g.dart').readAsStringSync(),
  );
}

String _hex(int v, int width) => '0x${v.toRadixString(16).padLeft(width, '0')}';

/// Dart source of `lib/src/generated/evdev_tables.g.dart`.
String renderEvdevTables(
  EvdevTables t, {
  required String libevdev,
  required String headers,
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/generate.dart — do not edit by hand.')
    ..writeln('// Source: linux/input-event-codes.h (linux-libc-dev $headers),')
    ..writeln('// filtered by the system libevdev (libevdev2 $libevdev).')
    ..writeln()
    ..writeln(
      '/// libevdev2 package version the tables were generated against.',
    )
    ..writeln("const generatedForLibevdev = '$libevdev';")
    ..writeln()
    ..writeln('/// linux-libc-dev package version of input-event-codes.h.')
    ..writeln("const generatedForKernelHeaders = '$headers';")
    ..writeln();
  void map(String doc, String name, Map<String, int> codes) {
    final sorted = codes.entries.toList()
      ..sort(
        (a, b) =>
            a.value != b.value ? a.value - b.value : a.key.compareTo(b.key),
      );
    out
      ..writeln('/// $doc')
      ..writeln('const $name = <String, int>{');
    for (final e in sorted) {
      out.writeln("  '${e.key}': ${_hex(e.value, 3)},");
    }
    out
      ..writeln('};')
      ..writeln();
  }

  void canonical(String doc, String name, Map<int, String> names) {
    out
      ..writeln('/// $doc')
      ..writeln('const $name = <int, String>{');
    for (final code in names.keys.toList()..sort()) {
      out.writeln("  ${_hex(code, 3)}: '${names[code]}',");
    }
    out
      ..writeln('};')
      ..writeln();
  }

  map('EV_KEY names accepted by libevdev → code.', 'evdevKeyCodes', t.keyCodes);
  canonical(
    'EV_KEY code → canonical name (`libevdev_event_code_get_name`).',
    'evdevKeyCanonicalNames',
    t.keyCanonical,
  );
  map(
    'EV_REL names accepted by libevdev → code.',
    'evdevRelativeAxisCodes',
    t.relCodes,
  );
  canonical(
    'EV_REL code → canonical name.',
    'evdevRelativeAxisCanonicalNames',
    t.relCanonical,
  );
  return '${out.toString().trimRight()}\n';
}

/// Dart source of `lib/src/generated/usb_hid_tables.g.dart`.
String renderUsbHidTable(Map<int, int> table, {required String flutter}) {
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/generate.dart — do not edit by hand.')
    ..writeln('// Source: kLinuxToPhysicalKey of the Flutter SDK $flutter')
    ..writeln('// (XKB keycode → physical key; evdev code = XKB keycode − 8).')
    ..writeln()
    ..writeln('/// Flutter SDK version the table was generated from.')
    ..writeln("const generatedForFlutter = '$flutter';")
    ..writeln()
    ..writeln('/// Flutter `PhysicalKeyboardKey.usbHidUsage` → evdev key code.')
    ..writeln('const usbHidUsageToEvdev = <int, int>{');
  for (final usage in table.keys.toList()..sort()) {
    out.writeln('  ${_hex(usage, 8)}: ${_hex(table[usage]!, 3)},');
  }
  out.writeln('};');
  return out.toString();
}
