import 'package:isar_community/isar.dart';

import '../../../feed/domain/entities/post.dart';

part 'bookmark_record.g.dart';

@embedded
class BookmarkMediaRecord {
  String url = '';
  String type = PostAttachmentType.unknown.name;
  String? mimeType;
  String? fileName;
  String? thumbnailUrl;

  // Populated by the media/offline layer when the asset is downloaded.
  String? localPath;

  static BookmarkMediaRecord fromAttachment(PostAttachment attachment) {
    return BookmarkMediaRecord()
      ..url = attachment.url
      ..type = attachment.type.name
      ..mimeType = attachment.mimeType
      ..fileName = attachment.fileName
      ..thumbnailUrl = attachment.thumbnailUrl;
  }

  PostAttachment toAttachment() {
    return PostAttachment(
      url: url,
      type: _typeFromName(type),
      mimeType: mimeType,
      fileName: fileName,
      thumbnailUrl: thumbnailUrl,
    );
  }

  static PostAttachmentType _typeFromName(String value) {
    for (final type in PostAttachmentType.values) {
      if (type.name == value) return type;
    }
    return PostAttachmentType.unknown;
  }
}

@collection
class BookmarkRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String postId;

  late String channelUsername;
  late String channelTitle;
  late String title;
  late String content;
  late String sourceUrl;

  String? permalink;
  DateTime? publishedAt;
  DateTime savedAt = DateTime.now();

  List<BookmarkMediaRecord> attachments = [];

  static BookmarkRecord fromPost(
    Post post, {
    DateTime? savedAt,
  }) {
    return BookmarkRecord()
      ..postId = post.id
      ..channelUsername = post.channelUsername
      ..channelTitle = post.channelTitle
      ..title = post.title
      ..content = post.content
      ..sourceUrl = post.sourceUrl
      ..permalink = post.permalink
      ..publishedAt = post.publishedAt
      ..savedAt = savedAt ?? DateTime.now()
      ..attachments = post.attachments
          .map(BookmarkMediaRecord.fromAttachment)
          .toList();
  }

  Post toPost() {
    return Post(
      id: postId,
      channelUsername: channelUsername,
      channelTitle: channelTitle,
      title: title,
      content: content,
      sourceUrl: sourceUrl,
      permalink: permalink,
      publishedAt: publishedAt,
      attachments: attachments.map((media) => media.toAttachment()).toList(),
    );
  }
}
