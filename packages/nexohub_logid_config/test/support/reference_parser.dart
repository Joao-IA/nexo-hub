// Runs the real libconfig (tool/libconfig_check) so tests can compare this
// package's parser and writer against the library logid uses.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';

/// Path of the reference binary built by `tool/libconfig_check/build.sh`.
final referenceBinary = File(
  '${Directory.current.path}/../../tool/libconfig_check/build/libconfig_check',
);

/// When set (CI does), a missing reference binary fails instead of skipping.
final bool referenceRequired =
    Platform.environment['NEXO_REQUIRE_LIBCONFIG_CHECK'] == '1';

/// Skip reason for differential tests, or null when they can run.
String? get referenceSkipReason {
  if (referenceBinary.existsSync() || referenceRequired) return null;
  return 'reference parser not built: run tool/libconfig_check/build.sh';
}

/// Outcome of parsing one input with the real libconfig.
final class ReferenceResult {
  ReferenceResult._(this.tree, this.errorLine, this.errorText);

  /// The tree in the shared JSON encoding, when parsing succeeded.
  final Object? tree;

  /// libconfig's error line, when parsing failed.
  final int? errorLine;

  /// libconfig's error text, when parsing failed.
  final String? errorText;

  /// Whether libconfig accepted the input.
  bool get ok => errorText == null;
}

/// Parses every input with the real libconfig, in batches.
Future<List<ReferenceResult>> referenceParse(List<List<int>> inputs) async {
  if (!referenceBinary.existsSync()) {
    throw StateError('missing ${referenceBinary.path}');
  }
  final dir = await Directory.systemTemp.createTemp('nexo_lc_diff_');
  try {
    final paths = <String>[];
    for (var i = 0; i < inputs.length; i++) {
      final file = File('${dir.path}/$i.cfg');
      await file.writeAsBytes(inputs[i]);
      paths.add(file.path);
    }
    final results = <ReferenceResult>[];
    const batch = 400;
    for (var start = 0; start < paths.length; start += batch) {
      final chunk = paths.sublist(
        start,
        start + batch > paths.length ? paths.length : start + batch,
      );
      final run = await Process.run(
        referenceBinary.path,
        chunk,
        stdoutEncoding: utf8,
      );
      if (run.exitCode != 0) {
        throw StateError('libconfig_check failed: ${run.stderr}');
      }
      for (final line in const LineSplitter().convert(run.stdout as String)) {
        final json = jsonDecode(line) as Map<String, Object?>;
        final error = json['error'] as Map<String, Object?>?;
        results.add(
          ReferenceResult._(
            json['ok'],
            error?['line'] as int?,
            error?['text'] as String?,
          ),
        );
      }
    }
    if (results.length != inputs.length) {
      throw StateError(
        'expected ${inputs.length} results, got ${results.length}',
      );
    }
    return results;
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Encodes a tree exactly like `libconfig_check` does, for comparison.
Object toReferenceJson(LcValue value) => switch (value) {
  LcGroup(:final settings) => {
    'group': [
      for (final s in settings) [s.name, toReferenceJson(s.value)],
    ],
  },
  LcList(:final elements) => {
    'list': [for (final e in elements) toReferenceJson(e)],
  },
  LcArray(:final elements) => {
    'array': [for (final e in elements) toReferenceJson(e)],
  },
  LcInt(:final value) => {'int': value},
  LcInt64(:final value) => {'int64': '$value'},
  LcFloat(:final bits) => {
    'float': BigInt.from(bits)
        .toUnsigned(64)
        .toRadixString(16)
        .padLeft(16, '0'),
  },
  LcBool(:final value) => {'bool': value},
  LcString(:final bytes) => {'string': _hex(bytes)},
};

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
