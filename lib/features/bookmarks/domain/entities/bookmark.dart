import '../../../feed/domain/entities/post.dart';

final class Bookmark {
  Bookmark({
    required this.post,
    required this.savedAt,
    Map<String, String> localMediaPaths = const {},
  }) : localMediaPaths = Map.unmodifiable(localMediaPaths);

  final Post post;
  final DateTime savedAt;

  /// Maps each remote attachment URL to its private app-storage file path.
  final Map<String, String> localMediaPaths;

  bool get hasAllMediaOffline =>
      post.attachments.every((attachment) => localMediaPaths.containsKey(attachment.url));

  bool get isFullyAvailableOffline => !post.hasMedia || hasAllMediaOffline;

  String? localPathFor(PostAttachment attachment) =>
      localMediaPaths[attachment.url];
}
