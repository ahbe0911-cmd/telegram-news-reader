import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../media/presentation/pages/image_viewer_page.dart';
import '../../../media/presentation/pages/video_player_page.dart';
import '../../domain/entities/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.isBookmarked,
    this.onBookmark,
    this.onDownload,
    this.downloadProgress,
    this.localMediaPaths = const {},
    super.key,
  });

  final Post post;
  final bool isBookmarked;
  final VoidCallback? onBookmark;
  final VoidCallback? onDownload;
  final double? downloadProgress;
  final Map<String, String> localMediaPaths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: colors.secondaryContainer,
                  child: Icon(
                    Icons.campaign_rounded,
                    color: colors.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@\${post.channelUsername}',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.publishedAt != null)
                  Text(
                    _relativeDate(post.publishedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (post.title.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.6,
                ),
              ),
            ],
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                post.content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.85),
              ),
            ],
            if (post.attachments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: post.attachments.map((attachment) {
                  return _AttachmentPreview(
                    attachment: attachment,
                    localPath: localMediaPaths[attachment.url],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                IconButton(
                  tooltip: isBookmarked ? 'حذف از ذخیره‌شده‌ها' : 'ذخیره پست',
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isBookmarked ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                if (onDownload != null)
                  TextButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('دانلود رسانه‌ها'),
                  ),
                const Spacer(),
                if (post.permalink != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(post.permalink!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('مشاهده در تلگرام'),
                  ),
              ],
            ),
            if (downloadProgress != null) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(value: downloadProgress),
              const SizedBox(height: 4),
              Text(
                'در حال دانلود \${(downloadProgress! * 100).round()}٪',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.inMinutes < 1) return 'همین حالا';
    if (difference.inHours < 1) return '\${difference.inMinutes} دقیقه پیش';
    if (difference.inDays < 1) return '\${difference.inHours} ساعت پیش';
    if (difference.inDays < 7) return '\${difference.inDays} روز پیش';

    final local = date.toLocal();
    return '\${local.year}/\${local.month.toString().padLeft(2, '0')}/\${local.day.toString().padLeft(2, '0')}';
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    this.localPath,
  });

  final PostAttachment attachment;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (attachment.type == PostAttachmentType.image) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImageViewerPage(
              url: attachment.url,
              localPath: localPath,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 142,
            height: 118,
            child: localPath != null
                ? Image.file(File(localPath!), fit: BoxFit.cover)
                : CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colors.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
      );
    }

    if (attachment.type == PostAttachmentType.video) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VideoPlayerPage(
              url: attachment.url,
              localPath: localPath,
            ),
          ),
        ),
        child: Container(
          width: 142,
          height: 118,
          decoration: BoxDecoration(
            color: colors.inverseSurface,
            borderRadius: BorderRadius.circular(14),
            image: attachment.thumbnailUrl == null
                ? null
                : DecorationImage(
                    image: CachedNetworkImageProvider(attachment.thumbnailUrl!),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
          ),
          child: Center(
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              child: Icon(
                localPath == null
                    ? Icons.play_arrow_rounded
                    : Icons.play_circle_fill_rounded,
                size: 30,
              ),
            ),
          ),
        ),
      );
    }

    final icon = switch (attachment.type) {
      PostAttachmentType.audio => Icons.audiotrack_rounded,
      PostAttachmentType.document => Icons.description_outlined,
      _ => Icons.attach_file_rounded,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await launchUrl(
          Uri.parse(attachment.url),
          mode: LaunchMode.externalApplication,
        );
      },
      child: Container(
        width: 142,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachment.fileName ?? 'فایل پیوست',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
