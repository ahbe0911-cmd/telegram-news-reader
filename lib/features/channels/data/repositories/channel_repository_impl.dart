import 'package:isar_community/isar.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/telegram_channel.dart';
import '../../domain/repositories/channel_repository.dart';
import '../models/telegram_channel_record.dart';

final class ChannelRepositoryImpl implements ChannelRepository {
  const ChannelRepositoryImpl(this._isar);

  final Isar _isar;

  @override
  Future<List<TelegramChannel>> getAll() async {
    try {
      final records = await _isar.telegramChannelRecords.where().findAll();
      return _sort(records.map((record) => record.toEntity()).toList());
    } catch (error) {
      throw DatabaseException(
        message: 'دریافت فهرست کانال‌ها از حافظه محلی ناموفق بود.',
        cause: error,
      );
    }
  }

  @override
  Future<List<TelegramChannel>> getEnabled() async {
    final channels = await getAll();
    return channels.where((channel) => channel.enabled).toList();
  }

  @override
  Stream<List<TelegramChannel>> watchAll() {
    return _isar.telegramChannelRecords
        .where()
        .watch(fireImmediately: true)
        .map(
          (records) => _sort(
            records.map((record) => record.toEntity()).toList(),
          ),
        );
  }

  @override
  Future<void> upsert(TelegramChannel channel) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.telegramChannelRecords
            .filter()
            .usernameEqualTo(channel.username)
            .findFirst();

        final record = TelegramChannelRecord.fromEntity(channel);
        if (existing != null) {
          record.id = existing.id;
          record.createdAt = existing.createdAt;
        }

        await _isar.telegramChannelRecords.put(record);
      });
    } catch (error) {
      throw DatabaseException(
        message: 'ذخیره کانال انجام نشد. نام کاربری کانال را بررسی کنید.',
        cause: error,
      );
    }
  }

  @override
  Future<void> setEnabled({
    required String username,
    required bool enabled,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final record = await _isar.telegramChannelRecords
            .filter()
            .usernameEqualTo(_normalize(username))
            .findFirst();

        if (record == null) return;

        record.enabled = enabled;
        await _isar.telegramChannelRecords.put(record);
      });
    } catch (error) {
      throw DatabaseException(
        message: 'تغییر وضعیت کانال ذخیره نشد.',
        cause: error,
      );
    }
  }

  @override
  Future<void> remove(String username) async {
    try {
      await _isar.writeTxn(() async {
        final record = await _isar.telegramChannelRecords
            .filter()
            .usernameEqualTo(_normalize(username))
            .findFirst();

        if (record != null) {
          await _isar.telegramChannelRecords.delete(record.id);
        }
      });
    } catch (error) {
      throw DatabaseException(
        message: 'حذف کانال از فهرست انجام نشد.',
        cause: error,
      );
    }
  }

  List<TelegramChannel> _sort(List<TelegramChannel> channels) {
    channels.sort(
      (first, second) =>
          first.title.toLowerCase().compareTo(second.title.toLowerCase()),
    );
    return channels;
  }

  String _normalize(String username) {
    return username.trim().replaceFirst(RegExp(r'^@'), '');
  }
}
