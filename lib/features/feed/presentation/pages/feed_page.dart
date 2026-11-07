import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/post.dart';
import '../widgets/feed_loading_skeleton.dart';
import '../widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({
    required this.onOpenChannels,
    super.key,
  });

  final VoidCallback onOpenChannels;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Post> _additionalPosts = [];
  String _query = '';
  bool _loadingMore = false;
  bool _endReached = false;
  String? _loadMoreError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _additionalPosts.clear();
      _loadingMore = false;
      _endReached = false;
      _loadMoreError = null;
    });
    await ref.refresh(feedPageProvider().future).then((_) {});
  }

  Future<void> _loadMore(int offset) async {
    if (_loadingMore || _endReached) return;

    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final page = await ref.read(
        feedPageProvider(offset: offset).future,
      );

      if (!mounted) return;

      final knownIds = _additionalPosts.map((post) => post.id).toSet();
      setState(() {
        _additionalPosts.addAll(
          page.posts.where((post) => !knownIds.contains(post.id)),
        );
        _endReached = !page.hasMore;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loadMoreError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedPageProvider());
    final saved = ref.watch(savedBookmarksProvider);
    final savedIds = saved.when(
      data: (items) => items.map((item) => item.post.id).toSet(),
      error: (_, _) => <String>{},
      loading: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('خبرخوان تلگرام'),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: 'جست‌وجو در عنوان و متن خبرها',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFeed,
              child: feed.when(
                data: (page) {
                  final posts = [
                    ...page.posts,
                    ..._additionalPosts,
                  ];

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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length + (showFooter ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
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

  final List<FeedSourceFailure> failures;
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
