// Direct access to the system libevdev (the library logid links to), so name
// resolution is identical to logid's by construction.
import 'catalog.dart';
import 'generated/evdev_tables.g.dart';
import 'libevdev_ffi.dart';

/// [EvdevCatalog] that asks the system libevdev directly.
final class LibevdevCatalog implements EvdevCatalog {
  LibevdevCatalog._(this._lib);

  /// Opens the system libevdev, or returns null when unavailable.
  static LibevdevCatalog? open({String library = 'libevdev.so.2'}) {
    final lib = Libevdev.open(library: library);
    return lib == null ? null : LibevdevCatalog._(lib);
  }

  final Libevdev _lib;

  @override
  int? keyCode(String name) => _lib.codeFromName(evKey, name);

  @override
  int? relativeAxisCode(String name) => _lib.codeFromName(evRel, name);

  @override
  String? keyName(int code) =>
      code < 0 || code > keyMax ? null : _lib.nameOfCode(evKey, code);

  @override
  String? relativeAxisName(int code) =>
      code < 0 || code > relMax ? null : _lib.nameOfCode(evRel, code);

  @override
  Iterable<String> get keyNames => _names(evKey, keyMax, evdevKeyCodes.keys);

  @override
  Iterable<String> get relativeAxisNames =>
      _names(evRel, relMax, evdevRelativeAxisCodes.keys);

  /// Canonical names of every code plus the known aliases this libevdev
  /// accepts (libevdev has no API to list aliases).
  Iterable<String> _names(int type, int max, Iterable<String> aliases) => {
    for (var code = 0; code <= max; code++) ?_lib.nameOfCode(type, code),
    for (final alias in aliases)
      if (_lib.codeFromName(type, alias) != null) alias,
  };
}
