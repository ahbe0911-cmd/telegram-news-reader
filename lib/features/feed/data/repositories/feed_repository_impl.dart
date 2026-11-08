import '../../../../core/errors/app_exception.dart';
import '../../../channels/domain/entities/telegram_channel.dart';
import '../../domain/entities/feed_page.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../domain/utils/post_ordering.dart';
import '../datasources/telegram_tdlib_remote_data_source.dart';

final class FeedRepositoryImpl implements FeedRepository {
  /// Bounded parallel I/O; TDLib itself continues to use its one receive loop.
  FeedRepositoryImpl({
    TelegramTdlibRemoteDataSource? remoteDataSource,
    Future<List<Post>> Function(TelegramChannel)? fetchChannel,
    int maxConcurrentChannels = 3,
  })  : assert(remoteDataSource != null || fetchChannel != null),
        assert(maxConcurrentChannels > 0),
        _fetchChannel = fetchChannel ?? remoteDataSource!.fetchChannel,
        _maxConcurrentChannels = maxConcurrentChannels;

  final Future<List<Post>> Function(TelegramChannel) _fetchChannel;
  final int _maxConcurrentChannels;

  List<Post> _cachedPosts = const [];
  List<FeedSourceFailure> _lastFailures = const [];
  String? _cachedChannelKey;
  DateTime? _fetchedAt;
  bool _hasStaleData = false;
  Future<void> _refreshQueue = Future<void>.value();

  @override
  Future<FeedPage> getPage({
    required List<TelegramChannel> channels,
    required int offset,
    required int pageSize,
    bool forceRefresh = false,
  }) async {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Offset cannot be negative.');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Page size must be greater than zero.',
      );
    }

    final enabledChannels =
        channels.where((channel) => channel.enabled).toList();
    final channelKey = _createChannelKey(enabledChannels);

    if (forceRefresh || offset == 0 || channelKey != _cachedChannelKey) {
      await _refresh(enabledChannels, channelKey);
    }

    return _buildPage(offset: offset, pageSize: pageSize);
  }

  Future<void> _refresh(
    List<TelegramChannel> channels,
    String channelKey,
  ) {
    final next = _refreshQueue
        .catchError((Object _) {})
        .then((_) => _refreshInternal(channels, channelKey));
    _refreshQueue = next;
    return next;
  }

  Future<void> _refreshInternal(
    List<TelegramChannel> channels,
    String channelKey,
  ) async {
    if (channels.isEmpty) {
      _cachedPosts = const [];
      _lastFailures = const [];
      _cachedChannelKey = channelKey;
      _fetchedAt = DateTime.now();
      _hasStaleData = false;
      return;
    }

    // At most three channel pipelines overlap. Each TDLib request carries
    // its own @extra ID, so responses are correlated without blocking the
    // receive loop. A small fixed pool avoids request floods on weak phones.
    final results = List<_ChannelFetchResult?>.filled(channels.length, null);
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < channels.length) {
        final index = cursor++;
        results[index] = await _fetchOne(channels[index]);
      }
    }

    final workerCount = channels.length < _maxConcurrentChannels
        ? channels.length
        : _maxConcurrentChannels;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    final completedResults = results.whereType<_ChannelFetchResult>().toList();
    final successfulResults =
        completedResults.where((result) => result.failure == null).toList();
    final failures = completedResults
        .where((result) => result.failure != null)
        .map(
          (result) => FeedSourceFailure(
            channelUsername: result.channelUsername,
            message: result.failure!,
          ),
        )
        .toList(growable: false);

    final failedUsernames = failures
        .map((failure) => failure.channelUsername)
        .toSet();

    final canReuseOldCache = _cachedChannelKey == channelKey;
    final preservedPosts = canReuseOldCache
        ? _cachedPosts
            .where((post) => failedUsernames.contains(post.channelUsername))
            .toList()
        : <Post>[];

    if (successfulResults.isEmpty && failures.isNotEmpty) {
      if (!canReuseOldCache) {
        _cachedPosts = const [];
        _fetchedAt = DateTime.now();
      }
      _lastFailures = failures;
      _cachedChannelKey = channelKey;
      _fetchedAt ??= DateTime.now();
      _hasStaleData = _cachedPosts.isNotEmpty;
      return;
    }

    final mergedById = <String, Post>{};

    for (final result in successfulResults) {
      for (final post in result.posts) {
        mergedById[post.id] = post;
      }
    }

    for (final post in preservedPosts) {
      mergedById.putIfAbsent(post.id, () => post);
    }

    final mergedPosts = mergedById.values.toList()
      ..sort(comparePostsNewestFirst);

    _cachedPosts = List.unmodifiable(mergedPosts);
    _lastFailures = failures;
    _cachedChannelKey = channelKey;
    _fetchedAt = DateTime.now();
    _hasStaleData = preservedPosts.isNotEmpty;
  }

  Future<_ChannelFetchResult> _fetchOne(TelegramChannel channel) async {
    try {
      final posts = await _fetchChannel(channel);
      return _ChannelFetchResult(
        channelUsername: channel.username,
        posts: posts,
      );
    } on AppException catch (error) {
      return _ChannelFetchResult(
        channelUsername: channel.username,
        posts: const [],
        failure: error.message,
      );
    } catch (error) {
      return _ChannelFetchResult(
        channelUsername: channel.username,
        posts: const [],
        failure: 'خطای پیش‌بینی‌نشده: $error',
      );
    }
  }

  FeedPage _buildPage({
    required int offset,
    required int pageSize,
  }) {
    final start = offset.clamp(0, _cachedPosts.length).toInt();
    final end = (start + pageSize).clamp(0, _cachedPosts.length).toInt();
    final pagePosts = _cachedPosts.sublist(start, end);

    return FeedPage(
      posts: pagePosts,
      offset: start,
      nextOffset: end,
      hasMore: end < _cachedPosts.length,
      fetchedAt: _fetchedAt,
      failures: _lastFailures,
      isStale: _hasStaleData,
    );
  }

  String _createChannelKey(List<TelegramChannel> channels) {
    final usernames = channels.map((channel) => channel.username).toList()
      ..sort();
    return usernames.join(',');
  }


}

final class _ChannelFetchResult {
  const _ChannelFetchResult({
    required this.channelUsername,
    required this.posts,
    this.failure,
  });

  final String channelUsername;
  final List<Post> posts;
  final String? failure;
}
