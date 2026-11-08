import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/features/channels/domain/entities/telegram_channel.dart';
import 'package:telegram_news_reader/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:telegram_news_reader/features/feed/domain/entities/post.dart';
import 'package:telegram_news_reader/features/feed/domain/utils/post_ordering.dart';

void main() {
  Post createPost(String id, DateTime timestamp, {DateTime? edited}) => Post(
        id: id,
        channelUsername: 'channel_$id',
        channelTitle: 'اخبار $id',
        title: 'تیتر $id',
        content: 'متن خبر',
        sourceUrl: 'tdlib://chat/$id',
        publishedAt: timestamp,
        updatedAt: edited,
      );

  test('global ordering puts edited posts first and undated posts last', () {
    final oldest = createPost('older', DateTime.utc(2026, 11, 6));
    final newer = createPost('newer', DateTime.utc(2026, 11, 8));
    final edited = createPost(
      'edited',
      DateTime.utc(2026, 11, 5),
      edited: DateTime.utc(2026, 11, 9),
    );
    final undated = Post(
      id: 'undated',
      channelUsername: 'undated',
      channelTitle: 'بدون تاریخ',
      title: '',
      content: 'خبر بدون تاریخ',
      sourceUrl: '',
    );

    final posts = [undated, oldest, newer, edited]
      ..sort(comparePostsNewestFirst);

    expect(posts.map((p) => p.id).toList(),
        ['edited', 'newer', 'older', 'undated']);
  });

  test('different channels fetch concurrently with safe limit and sort', () async {
    final channels = List.generate(
      6,
      (index) => TelegramChannel(
        username: 'channel_$index',
        chatId: -1000000000 - index,
      ),
    );
    var active = 0;
    var peak = 0;
    final repository = FeedRepositoryImpl(
      maxConcurrentChannels: 3,
      fetchChannel: (channel) async {
        active++;
        if (active > peak) peak = active;
        // Synchronize overlapping work without native Telegram dependencies.
        await Future<void>.delayed(const Duration(milliseconds: 18));
        active--;
        final index = int.parse(channel.username.split('_').last);
        return [
          createPost(
            'post-$index',
            DateTime.utc(2026, 11, 8, index),
          ),
        ];
      },
    );

    final first = await repository.getPage(
      channels: channels,
      offset: 0,
      pageSize: 3,
    );
    final second = await repository.getPage(
      channels: channels,
      offset: first.nextOffset,
      pageSize: 3,
    );

    expect(peak, greaterThan(1));
    expect(peak, lessThanOrEqualTo(3));
    expect(active, 0);
    expect(first.posts.map((p) => p.id), ['post-5', 'post-4', 'post-3']);
    expect(second.posts.map((p) => p.id), ['post-2', 'post-1', 'post-0']);
    expect(second.hasMore, isFalse);
  });

  test('failure in one channel does not hide healthy channel headlines', () async {
    final channels = [
      TelegramChannel(username: 'channel_success'),
      TelegramChannel(username: 'channel_failure'),
    ];
    final repository = FeedRepositoryImpl(
      fetchChannel: (channel) async {
        if (channel.username == 'channel_failure') {
          throw StateError('temporary source error');
        }
        return [createPost('healthy', DateTime.utc(2026, 11, 8))];
      },
    );

    final page = await repository.getPage(
      channels: channels,
      offset: 0,
      pageSize: 20,
    );

    expect(page.posts.single.id, 'healthy');
    expect(page.failures.single.channelUsername, 'channel_failure');
  });
}
