import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/post.dart';
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
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedPostsProvider);
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
            onPressed: () => ref.invalidate(feedPostsProvider),
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
              onRefresh: () => ref.refresh(feedPostsProvider.future).then((_) {}),
              child: feed.when(
                data: (posts) {
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

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
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
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                    SizedBox(height: 16),
                    Center(child: Text('در حال دریافت خبرها...')),
                  ],
                ),
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
                        onPressed: () => ref.invalidate(feedPostsProvider),
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
