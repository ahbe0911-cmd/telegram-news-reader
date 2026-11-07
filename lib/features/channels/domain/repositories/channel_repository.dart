import '../entities/telegram_channel.dart';

abstract interface class ChannelRepository {
  Future<List<TelegramChannel>> getAll();

  Future<List<TelegramChannel>> getEnabled();

  Stream<List<TelegramChannel>> watchAll();

  Future<void> upsert(TelegramChannel channel);

  Future<void> setEnabled({
    required String username,
    required bool enabled,
  });

  Future<void> remove(String username);
}
