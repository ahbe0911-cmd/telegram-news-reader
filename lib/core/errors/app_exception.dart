abstract class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class FeedSourceException extends AppException {
  const FeedSourceException({
    required this.channelUsername,
    required super.message,
    super.cause,
    this.sourceUrl,
  });

  final String channelUsername;
  final String? sourceUrl;
}

final class FeedParseException extends AppException {
  const FeedParseException({
    required super.message,
    super.cause,
    this.sourceUrl,
  });

  final String? sourceUrl;
}

final class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.cause,
  });
}
