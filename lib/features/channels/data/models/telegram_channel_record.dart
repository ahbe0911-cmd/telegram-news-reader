import 'package:isar_community/isar.dart';

import '../../domain/entities/telegram_channel.dart';

part 'telegram_channel_record.g.dart';

@collection
class TelegramChannelRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String username;

  late String title;

  int? chatId;

  bool enabled = true;

  late DateTime createdAt;

  static TelegramChannelRecord fromEntity(TelegramChannel channel) {
    return TelegramChannelRecord()
      ..username = channel.username
      ..title = channel.title
      ..chatId = channel.chatId
      ..enabled = channel.enabled
      ..createdAt = channel.createdAt;
  }

  TelegramChannel toEntity() {
    return TelegramChannel(
      username: username,
      title: title,
      chatId: chatId,
      enabled: enabled,
      createdAt: createdAt,
    );
  }
}
