enum PostAttachmentType {
  image,
  video,
  audio,
  document,
  unknown,
}

final class PostAttachment {
  const PostAttachment({
    required this.url,
    required this.type,
    this.mimeType,
    this.fileName,
    this.thumbnailUrl,
  });

  final String url;
  final PostAttachmentType type;
  final String? mimeType;
  final String? fileName;
  final String? thumbnailUrl;
}

final class Post {
  Post({
    required this.id,
    required this.channelUsername,
    required this.channelTitle,
    required this.title,
    required this.content,
    required this.sourceUrl,
    this.publishedAt,
    this.permalink,
    List<PostAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments);

  final String id;
  final String channelUsername;
  final String channelTitle;
  final String title;
  final String content;
  final String sourceUrl;
  final DateTime? publishedAt;
  final String? permalink;
  final List<PostAttachment> attachments;

  bool get hasMedia => attachments.isNotEmpty;
}
