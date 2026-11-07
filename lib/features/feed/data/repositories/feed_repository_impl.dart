import '../../../../core/errors/app_exception.dart';
import '../../../channels/domain/entities/telegram_channel.dart';
import '../../domain/entities/feed_page.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../datasources/telegram_tdlib_remote_data_source.dart';

final class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({required this._remoteDataSource});

  final TelegramTdlibRemoteDataSource _remoteDataSource;

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

    // TDLib uses one ordered receive loop. Fetch channels sequentially so
    // a refresh never floods the single native client with concurrent history
    // requests, especially immediately after a channel has been added.
    final results = <_ChannelFetchResult>[];
    for (final channel in channels) {
      results.add(await _fetchOne(channel));
    }
    final successfulResults =
        results.where((result) => result.failure == null).toList();
    final failures = results
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
      ..sort(_compareNewestFirst);

    _cachedPosts = List.unmodifiable(mergedPosts);
    _lastFailures = failures;
    _cachedChannelKey = channelKey;
    _fetchedAt = DateTime.now();
    _hasStaleData = preservedPosts.isNotEmpty;
  }

  Future<_ChannelFetchResult> _fetchOne(TelegramChannel channel) async {
    try {
      final posts = await _remoteDataSource.fetchChannel(channel);
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

  int _compareNewestFirst(Post first, Post second) {
    final firstDate = first.publishedAt;
    final secondDate = second.publishedAt;

    if (firstDate == null && secondDate == null) {
      return first.id.compareTo(second.id);
    }
    if (firstDate == null) return 1;
    if (secondDate == null) return -1;

    final dateComparison = secondDate.compareTo(firstDate);
    return dateComparison != 0
        ? dateComparison
        : first.id.compareTo(second.id);
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
