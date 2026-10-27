// Spike S3 — does Flutter key capture on Linux/Wayland yield the right evdev
// code? Throwaway code: see docs/spikes.md.
//
// Mapping under test: Flutter's own XKB → physical-key table
// (kLinuxToPhysicalKey, the same data the GTK embedder uses), inverted, with
// evdev = XKB - 8. Key names come from the kernel header the logid build
// uses (libevdev names == input-event-codes.h names).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const KeySpikeApp());

/// usbHidUsage → evdev code, built by inverting Flutter's Linux XKB table.
final Map<int, int> _usbToEvdev = {
  for (final e in kLinuxToPhysicalKey.entries) e.value.usbHidUsage: e.key - 8,
};

/// evdev code → first KEY_/BTN_ name found in the kernel header.
final Map<int, String> _evdevNames = _loadEvdevNames();

Map<int, String> _loadEvdevNames() {
  final names = <int, String>{};
  final define = RegExp(r'^#define\s+((?:KEY|BTN)_\w+)\s+(0x[0-9a-fA-F]+|\d+)');
  for (final line in File(
    '/usr/include/linux/input-event-codes.h',
  ).readAsLinesSync()) {
    final m = define.firstMatch(line);
    if (m == null) continue;
    final code = int.parse(m.group(2)!);
    names.putIfAbsent(code, () => m.group(1)!);
  }
  return names;
}

class KeySpikeApp extends StatelessWidget {
  const KeySpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nexo S3 — key capture',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    home: const KeySpikePage(),
  );
}

class KeySpikePage extends StatefulWidget {
  const KeySpikePage({super.key});

  @override
  State<KeySpikePage> createState() => _KeySpikePageState();
}

class _KeySpikePageState extends State<KeySpikePage> {
  final _focus = FocusNode();
  final _rows = <String>[];

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final usb = event.physicalKey.usbHidUsage;
    final evdev = _usbToEvdev[usb];
    final name = evdev == null ? '?' : (_evdevNames[evdev] ?? '?');
    final row =
        'physical=${event.physicalKey.debugName} '
        'usb=0x${usb.toRadixString(16)} '
        'evdev=${evdev ?? '-'} name=$name '
        'label="${event.logicalKey.keyLabel}" char="${event.character ?? ''}"';
    // Machine-readable line for the spike log.
    stdout.writeln('S3KEY $row');
    setState(() {
      _rows.insert(0, row);
      if (_rows.length > 40) _rows.removeLast();
    });
    return KeyEventResult.handled; // keep Tab/arrows from moving focus
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nexo S3 — pressione as teclas')),
    body: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mapa USB→evdev: ${_usbToEvdev.length} teclas · '
            'nomes evdev: ${_evdevNames.length}',
          ),
          const Divider(),
          for (final r in _rows)
            Text(r, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    ),
  );
}
