import '../../../feed/domain/entities/post.dart';
import '../../data/models/bookmark_record.dart';

abstract interface class BookmarkRepository {
  Future<List<BookmarkRecord>> getAll();

  Stream<List<BookmarkRecord>> watchAll();

  Future<bool> contains(String postId);

  Future<void> save(Post post);

  Future<void> remove(String postId);
}
