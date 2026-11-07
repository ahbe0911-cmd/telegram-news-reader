import '../../../channels/domain/entities/telegram_channel.dart';
import '../entities/feed_page.dart';

abstract interface class FeedRepository {
  Future<FeedPage> getPage({
    required List<TelegramChannel> channels,
    required int offset,
    required int pageSize,
    bool forceRefresh = false,
  });
}
