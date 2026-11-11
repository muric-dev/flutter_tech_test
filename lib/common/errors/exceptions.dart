/// Domain exception hierarchy. Services translate low-level failures
/// (sockets, status codes, parse errors) into these so the presentation layer
/// can react without depending on `http`/`xml` internals.
sealed class CabinaException implements Exception {
  const CabinaException(this.message, {this.cause});

  final String message;
  final Object? cause;

  static const fallbackMessage = 'Something went wrong';

  /// The user-facing message for any [error].
  static String messageOf(Object error) =>
      error is CabinaException ? error.message : fallbackMessage;

  @override
  String toString() => message;
}

class NetworkException extends CabinaException {
  const NetworkException(super.message, {super.cause});
}

class ApiException extends CabinaException {
  const ApiException(super.message, {this.statusCode, super.cause});

  final int? statusCode;

  bool get isRateLimited => statusCode == 429;
}

class FeedParseException extends CabinaException {
  const FeedParseException(super.message, {super.cause});
}

class CabinaPlayerException extends CabinaException {
  const CabinaPlayerException(super.message, {super.cause});
}

/// Local storage failed to read or write. `LocalStorage` throws it whatever
/// the backend.
class StorageException extends CabinaException {
  const StorageException(super.message, {super.cause});
}

/// AI Companion could not prepare an episode. [message] is safe to show:
/// it never names the provider, the key or a limit.
class AICompanionException extends CabinaException {
  const AICompanionException(
    super.message, {
    this.canRetry = false,
    super.cause,
  });

  /// Whether trying again can succeed, so the sheet offers "Retry".
  final bool canRetry;
}
