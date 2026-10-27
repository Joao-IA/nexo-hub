/// Reads, models, validates and writes logid (logiops) configuration files.
///
/// The `libconfig` layer reproduces the libconfig 1.7.3 grammar used by
/// logid byte for byte; it is checked against the real library by the
/// differential tests in `test/`.
library;

// The validator takes an EvdevCatalog; re-exported for convenience.
export 'package:nexohub_input_keys/nexohub_input_keys.dart'
    show EvdevCatalog, LibevdevCatalog, TableEvdevCatalog;

export 'src/libconfig/ast.dart';
export 'src/libconfig/errors.dart';
export 'src/libconfig/parser.dart' show parseLibconfig, parseLibconfigBytes;
export 'src/libconfig/writer.dart' show writeLibconfig;
export 'src/model/decode.dart';
export 'src/model/encode.dart';
export 'src/model/model.dart';
export 'src/validation/capabilities.dart';
export 'src/validation/validate.dart';
