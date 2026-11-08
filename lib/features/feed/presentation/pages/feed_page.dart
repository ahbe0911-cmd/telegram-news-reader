import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../telegram/telegram_providers.dart';
import '../../domain/utils/post_ordering.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/feed_page.dart' as feed_models;
import '../widgets/feed_loading_skeleton.dart';
import '../widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({
    required this.onOpenChannels,
    this.isActive = true,
    super.key,
  });

  final VoidCallback onOpenChannels;
  final bool isActive;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final List<Post> _additionalPosts = [];
  String _query = '';
  bool _loadingMore = false;
  bool _endReached = false;
  String? _loadMoreError;
  int _pageGeneration = 0;
  bool _refreshInFlight = false;
  bool _foreground = true;
  Set<int> _enabledChatIds = {};
  StreamSubscription<int>? _chatChanges;
  Timer? _periodicRefresh;
  Timer? _updateDebounce;
  DateTime? _lastAutomaticRefresh;

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_handleSettingsChange);
    WidgetsBinding.instance.addObserver(this);
    _chatChanges = ref.read(telegramTdlibServiceProvider)
        .changedChatIds.listen(_onTelegramChatChanged);
    _configurePolling();
  }

  void _handleSettingsChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _configurePolling();
      if (widget.isActive) {
        _lastAutomaticRefresh = null;
        unawaited(_autoRefresh());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _configurePolling();
    if (_foreground && widget.isActive) {
      _lastAutomaticRefresh = null;
      unawaited(_autoRefresh());
    }
  }

  void _configurePolling() {
    _periodicRefresh?.cancel();
    _periodicRefresh = null;
    if (widget.isActive && _foreground) {
      // Fallback for channels whose messages do not produce push updates
      // (e.g., public channels the account has not joined).
      _periodicRefresh = Timer.periodic(
        const Duration(seconds: 35),
        (_) => unawaited(_autoRefresh()),
      );
    } else {
      _updateDebounce?.cancel();
      _updateDebounce = null;
    }
  }

  void _onTelegramChatChanged(int chatId) {
    if (!mounted || !_foreground || !widget.isActive ||
        !_enabledChatIds.contains(chatId)) return;
    _updateDebounce?.cancel();
    _updateDebounce = Timer(
      const Duration(milliseconds: 1200),
      () => unawaited(_autoRefresh()),
    );
  }

  Future<void> _autoRefresh() async {
    if (!mounted || !_foreground || !widget.isActive || _refreshInFlight) return;
    final now = DateTime.now();
    if (_lastAutomaticRefresh != null &&
        now.difference(_lastAutomaticRefresh!) < const Duration(seconds: 7)) {
      return;
    }
    _lastAutomaticRefresh = now;
    await _refreshFeed();
  }

  @override
  void dispose() {
    _periodicRefresh?.cancel();
    _updateDebounce?.cancel();
    unawaited(_chatChanges?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    AppSettings.instance.removeListener(_handleSettingsChange);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    if (_refreshInFlight || !mounted) return;
    _refreshInFlight = true;
    setState(() {
      _pageGeneration++;
      _additionalPosts.clear();
      _loadingMore = false;
      _endReached = false;
      _loadMoreError = null;
    });
    try {
      await ref.refresh(feedPageProvider().future);
    } catch (_) {
      // The provider exposes the source errors to the feed/error UI.
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _loadMore(int offset) async {
    if (_loadingMore || _endReached || _refreshInFlight) return;
    final generation = _pageGeneration;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await ref.read(
        feedPageProvider(offset: offset).future,
      );

      if (!mounted || generation != _pageGeneration) return;

      final knownIds = _additionalPosts.map((post) => post.id).toSet();
      setState(() {
        _additionalPosts.addAll(
          page.posts.where((post) => !knownIds.contains(post.id)),
        );
        _endReached = !page.hasMore;
      });
    } catch (error) {
      if (mounted && generation == _pageGeneration) {
        setState(() => _loadMoreError = error.toString());
      }
    } finally {
      if (mounted && generation == _pageGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedPageProvider());
    _enabledChatIds = ref.watch(telegramChannelsProvider).when(
      data: (items) => items
          .where((channel) => channel.enabled && channel.chatId != null)
          .map((channel) => channel.chatId!)
          .toSet(),
      loading: () => _enabledChatIds,
      error: (error, stack) => _enabledChatIds,
    );
    final saved = ref.watch(savedBookmarksProvider);
    final savedIds = saved.when(
      data: (items) => items.map((item) => item.post.id).toSet(),
      error: (_, _) => <String>{},
      loading: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppPalette.primary, AppPalette.violet],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            const Text('نبض خبرها'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'به‌روزرسانی خبرها',
            onPressed: _refreshFeed,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: 'جست‌وجوی خبرها…',
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFeed,
              child: feed.when(
                data: (page) {
                  // Additional pages and newly refreshed headlines share
                  // the same global newest-first ordering and unique IDs.
                  final uniquePosts = <String, Post>{
                    for (final post in [...page.posts, ..._additionalPosts])
                      post.id: post,
                  };
                  final posts = uniquePosts.values.toList()
                    ..sort(comparePostsNewestFirst);

                  if (posts.isEmpty && page.hasSourceFailures) {
                    return _FeedSourceErrors(
                      failures: page.failures,
                      onRetry: _refreshFeed,
                    );
                  }

                  if (posts.isEmpty) {
                    return _EmptyFeed(onOpenChannels: widget.onOpenChannels);
                  }

                  final filtered = _filterPosts(posts, _query);
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(28),
                      children: const [
                        _EmptyMessage(
                          icon: Icons.search_off_rounded,
                          title: 'نتیجه‌ای پیدا نشد',
                          subtitle: 'عبارت دیگری را جست‌وجو کن.',
                        ),
                      ],
                    );
                  }

                  final canLoadMore = page.hasMore && !_endReached;
                  final showFooter =
                      canLoadMore || _loadingMore || _loadMoreError != null;

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                    itemCount: filtered.length + (showFooter ? 1 : 0),
                    separatorBuilder: (_, _) => SizedBox(
                      height: AppSettings.instance.compactCards ? 9 : 16),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (_loadMoreError != null) {
                          return OutlinedButton.icon(
                            onPressed: () => _loadMore(
                              page.nextOffset + _additionalPosts.length,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text(
                              'بارگذاری بیشتر ناموفق بود؛ تلاش دوباره',
                            ),
                          );
                        }

                        return const SizedBox(height: 12);
                      }

                      if (index >= filtered.length - 3 &&
                          canLoadMore &&
                          !_loadingMore &&
                          _loadMoreError == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_loadingMore && !_endReached) {
                            _loadMore(
                              page.nextOffset + _additionalPosts.length,
                            );
                          }
                        });
                      }

                      final post = filtered[index];
                      return PostCard(
                        post: post,
                        isBookmarked: savedIds.contains(post.id),
                        onBookmark: () => _toggleBookmark(
                          context,
                          post,
                          savedIds.contains(post.id),
                        ),
                      );
                    },
                  );
                },
                loading: () => const FeedLoadingSkeleton(),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    _EmptyMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'دریافت خبرها ناموفق بود',
                      subtitle: error.toString(),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => ref.invalidate(feedPageProvider()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تلاش دوباره'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Post> _filterPosts(List<Post> posts, String query) {
    if (query.isEmpty) return posts;
    final normalized = query.toLowerCase();

    return posts.where((post) {
      return post.title.toLowerCase().contains(normalized) ||
          post.content.toLowerCase().contains(normalized) ||
          post.channelTitle.toLowerCase().contains(normalized) ||
          post.channelUsername.toLowerCase().contains(normalized);
    }).toList(growable: false);
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    Post post,
    bool isSaved,
  ) async {
    try {
      final repository = await ref.read(bookmarkRepositoryProvider.future);
      if (isSaved) {
        await repository.remove(post.id);
      } else {
        await repository.save(post);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved
                ? 'پست از ذخیره‌شده‌ها حذف شد.'
                : 'پست ذخیره شد.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عملیات ذخیره انجام نشد: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _FeedSourceErrors extends StatelessWidget {
  const _FeedSourceErrors({
    required this.failures,
    required this.onRetry,
  });

  final List<feed_models.FeedSourceFailure> failures;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.cloud_off_rounded,
          size: 48,
          color: colors.error,
        ),
        const SizedBox(height: 16),
        Text(
          'دریافت پست‌ها از تلگرام ناموفق بود',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        for (final failure in failures)
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline_rounded),
              title: Text('@${failure.channelUsername}'),
              subtitle: Text(failure.message),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تلاش دوباره'),
        ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onOpenChannels});

  final VoidCallback onOpenChannels;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 70),
        const _EmptyMessage(
          icon: Icons.rss_feed_rounded,
          title: 'هنوز خبری اینجا نیست',
          subtitle: 'برای شروع، یک کانال عمومی تلگرام به فهرستت اضافه کن.',
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onOpenChannels,
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن کانال'),
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: colors.secondaryContainer,
          child: Icon(icon, size: 32, color: colors.onSecondaryContainer),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}
