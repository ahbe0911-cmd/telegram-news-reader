import 'post.dart';

final class FeedSourceFailure {
  const FeedSourceFailure({
    required this.channelUsername,
    required this.message,
  });

  final String channelUsername;
  final String message;
}

final class FeedPage {
  FeedPage({
    required List<Post> posts,
    required this.offset,
    required this.nextOffset,
    required this.hasMore,
    required this.fetchedAt,
    List<FeedSourceFailure> failures = const [],
    this.isStale = false,
  })  : posts = List.unmodifiable(posts),
        failures = List.unmodifiable(failures);

  final List<Post> posts;
  final int offset;
  final int nextOffset;
  final bool hasMore;
  final DateTime? fetchedAt;
  final List<FeedSourceFailure> failures;
  final bool isStale;

  bool get hasSourceFailures => failures.isNotEmpty;
}
