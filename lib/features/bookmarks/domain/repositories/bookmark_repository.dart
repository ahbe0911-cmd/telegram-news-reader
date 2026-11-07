import '../../../feed/domain/entities/post.dart';
import '../entities/bookmark.dart';

abstract interface class BookmarkRepository {
  Future<List<Bookmark>> getAll();

  Stream<List<Bookmark>> watchAll();

  Future<bool> contains(String postId);

  Future<void> save(Post post);

  Future<void> updateAttachmentLocalPath({
    required String postId,
    required String attachmentUrl,
    required String? localPath,
  });

  Future<void> remove(String postId);
}
