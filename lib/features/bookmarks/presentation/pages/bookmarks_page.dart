import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../media/data/media_download_service.dart';
import '../../domain/entities/bookmark.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(savedBookmarksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ذخیره‌شده‌ها')),
      body: bookmarks.when(
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyBookmarks();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _BookmarkCard(
              bookmark: items[index],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('دریافت ذخیره‌شده‌ها ناموفق بود: $error'),
          ),
        ),
      ),
    );
  }
}

class _BookmarkCard extends ConsumerStatefulWidget {
  const _BookmarkCard({required this.bookmark});

  final Bookmark bookmark;

  @override
  ConsumerState<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends ConsumerState<_BookmarkCard> {
  bool _downloading = false;
  double _progress = 0;

  Future<void> _downloadMedia() async {
    final attachments = widget.bookmark.post.attachments;
    if (attachments.isEmpty || _downloading) return;

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      final repository = await ref.read(bookmarkRepositoryProvider.future);
      final service = MediaDownloadService(
        dio: ref.read(dioClientProvider),
      );

      var completed = 0;
      for (final attachment in attachments) {
        final existingPath = widget.bookmark.localPathFor(attachment);
        if (existingPath != null && await File(existingPath).exists()) {
          completed++;
          continue;
        }

        final path = await service.downloadAttachment(
          attachment,
          onReceiveProgress: (received, total) {
            if (!mounted) return;
            final current = total > 0 ? received / total : 0.0;
            setState(() {
              _progress = ((completed + current) / attachments.length)
                  .clamp(0.0, 1.0);
            });
          },
        );

        await repository.updateAttachmentLocalPath(
          postId: widget.bookmark.post.id,
          attachmentUrl: attachment.url,
          localPath: path,
        );
        completed++;
        if (mounted) {
          setState(() {
            _progress = completed / attachments.length;
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رسانه‌های این پست برای مطالعه آفلاین ذخیره شدند.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('دانلود کامل نشد: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _removeBookmark() async {
    try {
      final repository = await ref.read(bookmarkRepositoryProvider.future);
      await repository.remove(widget.bookmark.post.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حذف نشانک انجام نشد: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    final hasMedia = bookmark.post.attachments.isNotEmpty;

    return PostCard(
      post: bookmark.post,
      isBookmarked: true,
      localMediaPaths: bookmark.localMediaPaths,
      onBookmark: _removeBookmark,
      onDownload: hasMedia && !bookmark.isFullyAvailableOffline
          ? _downloadMedia
          : null,
      downloadProgress: _downloading ? _progress : null,
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 32,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز پستی ذخیره نکرده‌ای',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'با زدن نشانک زیر هر خبر، آن را برای بعد نگه دار.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
