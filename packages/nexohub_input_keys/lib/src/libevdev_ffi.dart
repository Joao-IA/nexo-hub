// Thin dart:ffi binding to the system libevdev name functions. Kept free of
// generated tables so tool/generate.dart can use it to build them.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// `EV_KEY` from linux/input-event-codes.h.
const evKey = 0x01;

/// `EV_REL` from linux/input-event-codes.h.
const evRel = 0x02;

/// `KEY_MAX` from linux/input-event-codes.h.
const keyMax = 0x2ff;

/// `REL_MAX` from linux/input-event-codes.h.
const relMax = 0x0f;

typedef _FromNameC = Int32 Function(Uint32 type, Pointer<Utf8> name);
typedef _FromName = int Function(int type, Pointer<Utf8> name);
typedef _GetNameC = Pointer<Utf8> Function(Uint32 type, Uint32 code);
typedef _GetName = Pointer<Utf8> Function(int type, int code);

/// Low-level libevdev name functions.
final class Libevdev {
  Libevdev._(this._fromName, this._getName);

  /// Loads [library] (default `libevdev.so.2`), or returns null when it is
  /// not installed (non-Linux, minimal containers).
  static Libevdev? open({String library = 'libevdev.so.2'}) {
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(library);
    } on ArgumentError {
      return null;
    }
    return Libevdev._(
      lib.lookupFunction<_FromNameC, _FromName>(
        'libevdev_event_code_from_name',
      ),
      lib.lookupFunction<_GetNameC, _GetName>('libevdev_event_code_get_name'),
    );
  }

  final _FromName _fromName;
  final _GetName _getName;

  /// `libevdev_event_code_from_name(type, name)`, or null when unknown.
  int? codeFromName(int type, String name) => using((arena) {
    final code = _fromName(type, name.toNativeUtf8(allocator: arena));
    return code < 0 ? null : code;
  });

  /// `libevdev_event_code_get_name(type, code)`, or null when unnamed.
  String? nameOfCode(int type, int code) {
    final name = _getName(type, code);
    return name == nullptr ? null : name.toDartString();
  }
}
