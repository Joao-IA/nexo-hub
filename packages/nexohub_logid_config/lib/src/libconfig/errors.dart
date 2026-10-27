import 'ast.dart';

/// Why a libconfig text was rejected. Stable codes so the UI can show
/// translated messages.
enum LibconfigErrorCode {
  /// A byte that starts no token (libconfig: `TOK_GARBAGE`).
  unexpectedCharacter,

  /// An integer literal libconfig cannot convert, e.g. `08` (octal) or a
  /// value outside 64 bits (libconfig: `TOK_ERROR`).
  invalidInteger,

  /// A string without its closing quote where a value was required.
  /// (libconfig silently drops a dangling string at the very end of an
  /// otherwise complete file, and so does this parser.)
  unterminatedString,

  /// `@include` directives. libconfig would read another file; Nexo
  /// deliberately refuses them.
  includeNotSupported,

  /// A token that the grammar does not allow at this point.
  unexpectedToken,

  /// The text ended in the middle of a construct.
  unexpectedEndOfInput,

  /// Two settings with the same name in one group.
  duplicateSetting,

  /// Array elements of different types (e.g. `[1, 2L]`).
  mismatchedArrayElementType,

  /// Nesting deeper than [maxLibconfigDepth].
  nestingTooDeep,
}

/// Maximum nesting of groups/lists/arrays accepted by the parser. libconfig's
/// own limit is far higher; real logid configs stay below 15.
const maxLibconfigDepth = 256;

/// A libconfig text could not be parsed.
final class LibconfigSyntaxError implements Exception {
  /// Creates an error.
  const LibconfigSyntaxError(this.code, this.message, this.position);

  /// Machine-readable reason.
  final LibconfigErrorCode code;

  /// English description (for logs; the UI translates [code]).
  final String message;

  /// Where the problem was detected.
  final SourcePosition position;

  @override
  String toString() =>
      'LibconfigSyntaxError($position, ${code.name}): $message';
}
