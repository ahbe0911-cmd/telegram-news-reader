import 'package:isar_community/isar.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../feed/domain/entities/post.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../models/bookmark_record.dart';

final class BookmarkRepositoryImpl implements BookmarkRepository {
  const BookmarkRepositoryImpl(this._isar);

  final Isar _isar;

  @override
  Future<List<BookmarkRecord>> getAll() async {
    try {
      final records = await _isar.bookmarkRecords.where().findAll();
      return _sort(records);
    } catch (error) {
      throw DatabaseException(
        message: 'دریافت نشانک‌ها از حافظه محلی ناموفق بود.',
        cause: error,
      );
    }
  }

  @override
  Stream<List<BookmarkRecord>> watchAll() {
    return _isar.bookmarkRecords
        .where()
        .watch(fireImmediately: true)
        .map(_sort);
  }

  @override
  Future<bool> contains(String postId) async {
    try {
      final record = await _isar.bookmarkRecords
          .filter()
          .postIdEqualTo(postId)
          .findFirst();
      return record != null;
    } catch (error) {
      throw DatabaseException(
        message: 'بررسی وضعیت نشانک ناموفق بود.',
        cause: error,
      );
    }
  }

  @override
  Future<void> save(Post post) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.bookmarkRecords
            .filter()
            .postIdEqualTo(post.id)
            .findFirst();

        final record = BookmarkRecord.fromPost(
          post,
          savedAt: existing?.savedAt,
        );

        if (existing != null) {
          record.id = existing.id;
        }

        await _isar.bookmarkRecords.put(record);
      });
    } catch (error) {
      throw DatabaseException(
        message: 'ذخیره پست در نشانک‌ها انجام نشد.',
        cause: error,
      );
    }
  }

  @override
  Future<void> remove(String postId) async {
    try {
      await _isar.writeTxn(() async {
        final record = await _isar.bookmarkRecords
            .filter()
            .postIdEqualTo(postId)
            .findFirst();

        if (record != null) {
          await _isar.bookmarkRecords.delete(record.id);
        }
      });
    } catch (error) {
      throw DatabaseException(
        message: 'حذف پست از نشانک‌ها انجام نشد.',
        cause: error,
      );
    }
  }

  List<BookmarkRecord> _sort(List<BookmarkRecord> records) {
    final sorted = List<BookmarkRecord>.of(records);
    sorted.sort((first, second) => second.savedAt.compareTo(first.savedAt));
    return sorted;
  }
}
