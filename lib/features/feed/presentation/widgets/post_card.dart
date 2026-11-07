import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../telegram/telegram_providers.dart';
import '../../../media/presentation/pages/image_viewer_page.dart';
import '../../../media/presentation/pages/pdf_viewer_page.dart';
import '../../../media/presentation/pages/video_player_page.dart';
import '../../../media/presentation/widgets/inline_video_player.dart';
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
    final nonVideoAttachments = post.attachments
        .where((attachment) => attachment.type != PostAttachmentType.video ||
            attachment.telegramFileId != null)
        .toList(growable: false);
    final videoAttachments = post.attachments
        .where((attachment) => attachment.type == PostAttachmentType.video &&
            attachment.telegramFileId == null)
        .toList(growable: false);

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
                        post.channelUsername.startsWith('chat_')
                            ? 'کانال خصوصی'
                            : '@${post.channelUsername}',
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
            if (nonVideoAttachments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: nonVideoAttachments.map((attachment) {
                  return _AttachmentPreview(
                    attachment: attachment,
                    localPath: localMediaPaths[attachment.url],
                  );
                }).toList(growable: false),
              ),
            ],
            for (final attachment in videoAttachments) ...[
              const SizedBox(height: 14),
              InlineVideoPlayer(
                url: attachment.url,
                localPath: localMediaPaths[attachment.url],
                thumbnailUrl: attachment.thumbnailUrl,
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
                    color: isBookmarked
                        ? colors.primary
                        : colors.onSurfaceVariant,
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
                'در حال دانلود ${(downloadProgress! * 100).round()}٪',
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
    if (difference.inHours < 1) return '${difference.inMinutes} دقیقه پیش';
    if (difference.inDays < 1) return '${difference.inHours} ساعت پیش';
    if (difference.inDays < 7) return '${difference.inDays} روز پیش';

    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }
}

class _AttachmentPreview extends ConsumerStatefulWidget {
  const _AttachmentPreview({
    required this.attachment,
    this.localPath,
  });

  final PostAttachment attachment;
  final String? localPath;

  @override
  ConsumerState<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends ConsumerState<_AttachmentPreview> {
  bool _downloading = false;
  String? _downloadError;

  bool get _isPdf =>
      widget.attachment.mimeType?.toLowerCase().contains('pdf') == true ||
      widget.attachment.fileName?.toLowerCase().endsWith('.pdf') == true ||
      Uri.tryParse(widget.attachment.url)?.path.toLowerCase().endsWith('.pdf') == true;

  Future<void> _open() async {
    if (widget.localPath != null) {
      await _openLocal(widget.localPath!);
      return;
    }

    final fileId = widget.attachment.telegramFileId;
    if (fileId == null) {
      await _openRemote();
      return;
    }

    setState(() {
      _downloading = true;
      _downloadError = null;
    });

    try {
      final file = await ref.read(telegramTdlibServiceProvider).downloadFile(fileId);
      final local = file['local'] is Map
          ? Map<String, dynamic>.from(file['local'] as Map)
          : const <String, dynamic>{};
      final path = local['path']?.toString();
      if (path == null || path.isEmpty || !await File(path).exists()) {
        throw StateError('فایل از تلگرام دریافت نشد یا مسیر محلی آن خالی است.');
      }
      if (!mounted) return;
      await _openLocal(path);
    } catch (error) {
      if (mounted) setState(() => _downloadError = error.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openLocal(String path) async {
    final attachment = widget.attachment;
    if (attachment.type == PostAttachmentType.image) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerPage(url: '', localPath: path),
        ),
      );
      return;
    }
    if (attachment.type == PostAttachmentType.video) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerPage(url: '', localPath: path),
        ),
      );
      return;
    }
    if (attachment.type == PostAttachmentType.document && _isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerPage(
            url: '',
            localPath: path,
            fileName: attachment.fileName,
          ),
        ),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فایل ذخیره شد: ${attachment.fileName ?? path}')),
      );
    }
  }

  Future<void> _openRemote() async {
    final attachment = widget.attachment;
    if (attachment.type == PostAttachmentType.image) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerPage(url: attachment.url),
        ),
      );
      return;
    }
    if (_isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerPage(
            url: attachment.url,
            fileName: attachment.fileName,
          ),
        ),
      );
      return;
    }
    await launchUrl(
      Uri.parse(attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final attachment = widget.attachment;

    if (attachment.type == PostAttachmentType.image &&
        attachment.telegramFileId == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 142,
            height: 118,
            child: widget.localPath != null
                ? Image.file(
                    File(widget.localPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  )
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

    final icon = switch (attachment.type) {
      PostAttachmentType.image => Icons.image_outlined,
      PostAttachmentType.video => Icons.play_circle_outline_rounded,
      PostAttachmentType.audio => Icons.audiotrack_rounded,
      PostAttachmentType.document => Icons.description_outlined,
      PostAttachmentType.unknown => Icons.attach_file_rounded,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _downloading ? null : _open,
      child: Container(
        width: 142,
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_downloading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: colors.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              _downloading
                  ? 'دریافت از تلگرام…'
                  : attachment.fileName ?? 'باز کردن پیوست',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (_downloadError != null)
              Text(
                'خطا؛ دوباره لمس کن',
                maxLines: 1,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
