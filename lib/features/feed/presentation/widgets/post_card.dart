import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
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
    final copy = _editorialCopy(post);
    final images = post.attachments
        .where((a) => a.type == PostAttachmentType.image).toList(growable: false);
    final hero = images.isNotEmpty ? images.first : null;
    final otherMedia = post.attachments.where((a) =>
        a != hero &&
        (a.type != PostAttachmentType.video || a.telegramFileId != null)
    ).toList(growable: false);
    final streamingVideos = post.attachments.where((a) =>
        a.type == PostAttachmentType.video && a.telegramFileId == null
    ).toList(growable: false);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.primary, AppPalette.violet],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        post.channelUsername.startsWith('chat_')
                            ? 'کانال خصوصی' : '@' + post.channelUsername,
                        textDirection: post.channelUsername.startsWith('chat_')
                            ? TextDirection.rtl : TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary,
                      ),
                    ],
                  ),
                ),
                if (post.publishedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _relativeDate(post.publishedAt!),
                      style: AppTypography.secondary.copyWith(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          if (copy.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(copy.title, style: AppTypography.newsHeadline),
            ),
          if (hero != null)
            _AttachmentPreview(
              key: ValueKey(hero.url),
              attachment: hero,
              localPath: localMediaPaths[hero.url],
              hero: true,
            ),
          if (copy.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 8),
              child: SelectableText(
                copy.body,
                textAlign: TextAlign.start,
                style: AppTypography.newsBody,
              ),
            ),
          if (otherMedia.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final a in otherMedia)
                    SizedBox(
                      width: 148,
                      child: _AttachmentPreview(
                        key: ValueKey(a.url),
                        attachment: a,
                        localPath: localMediaPaths[a.url],
                      ),
                    ),
                ],
              ),
            ),
          for (final a in streamingVideos)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: InlineVideoPlayer(
                url: a.url,
                localPath: localMediaPaths[a.url],
                thumbnailUrl: a.thumbnailUrl,
              ),
            ),
          const SizedBox(height: 13),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: isBookmarked ? 'حذف از ذخیره‌شده‌ها' : 'ذخیره پست',
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isBookmarked ? AppPalette.coral : AppPalette.muted,
                  ),
                ),
                if (onDownload != null)
                  Flexible(
                    child: TextButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('دانلود رسانه‌ها', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                const Spacer(),
                if (post.permalink != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(post.permalink!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('تلگرام'),
                  ),
              ],
            ),
          ),
          if (downloadProgress != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: LinearProgressIndicator(value: downloadProgress),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text(
                'در حال دانلود ' + (downloadProgress! * 100).round().toString() + '٪',
                style: AppTypography.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String title, String body}) _editorialCopy(Post post) {
    if (post.title.trim().isNotEmpty) {
      return (title: post.title.trim(), body: post.content);
    }
    final content = post.content.trim();
    if (content.isEmpty) return (title: '', body: '');
    int stop = content.indexOf(RegExp(r'[.!؟\n]'));
    if (stop > 26 && stop < 140) {
      stop += 1;
    } else if (content.length > 105) {
      stop = content.lastIndexOf(' ', 105);
      if (stop < 45) stop = 105;
    } else {
      stop = content.length;
    }
    return (
      title: content.substring(0, stop).trim(),
      body: content.substring(stop).trim(),
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
    this.hero = false,
  });

  final PostAttachment attachment;
  final String? localPath;
  final bool hero;

  @override
  ConsumerState<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends ConsumerState<_AttachmentPreview> {
  bool _downloading = false;
  String? _downloadError;
  String? _resolvedPath;
  bool _previewLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.type == PostAttachmentType.image &&
        widget.attachment.telegramFileId != null &&
        widget.localPath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTelegramPreview();
      });
    }
  }

  Future<void> _loadTelegramPreview() async {
    final id = widget.attachment.telegramFileId;
    if (id == null || _previewLoading || _resolvedPath != null) return;
    setState(() => _previewLoading = true);
    try {
      final file = await ref.read(telegramTdlibServiceProvider).downloadFile(id);
      final local = file['local'] is Map
          ? Map<String, dynamic>.from(file['local'] as Map)
          : const <String, dynamic>{};
      final path = local['path']?.toString();
      if (path != null && path.isNotEmpty && await File(path).exists() && mounted) {
        setState(() => _resolvedPath = path);
      }
    } catch (_) {
      // The interactive attachment remains available for manual retry.
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  bool get _isPdf =>
      widget.attachment.mimeType?.toLowerCase().contains('pdf') == true ||
      widget.attachment.fileName?.toLowerCase().endsWith('.pdf') == true ||
      Uri.tryParse(widget.attachment.url)?.path.toLowerCase().endsWith('.pdf') == true;

  Future<void> _open() async {
    final availablePath = widget.localPath ?? _resolvedPath;
    if (availablePath != null) {
      await _openLocal(availablePath);
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

    if (attachment.type == PostAttachmentType.image) {
      final path = widget.localPath ?? _resolvedPath;
      return InkWell(
        onTap: _downloading ? null : _open,
        child: AspectRatio(
          aspectRatio: widget.hero ? 16 / 9 : 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null)
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => const _ImagePlaceholder(),
                )
              else if (attachment.telegramFileId != null)
                const _ImagePlaceholder()
              else
                CachedNetworkImage(
                  imageUrl: attachment.url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const _ImagePlaceholder(),
                  errorWidget: (context, url, error) => const _ImagePlaceholder(),
                ),
              if (path == null && attachment.telegramFileId != null)
                Center(
                  child: _previewLoading || _downloading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)
                      : const Icon(Icons.image_search_rounded, color: Colors.white, size: 36),
                ),
              PositionedDirectional(
                bottom: 12,
                end: 12,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 17),
                ),
              ),
            ],
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


class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFB7C5F5),
      highlightColor: const Color(0xFFEDEBFF),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFA5B8F5),
              Color(0xFFCCB8EF),
              Color(0xFFFFD0C4),
            ],
          ),
        ),
        child: Center(
          child: Icon(Icons.auto_awesome_rounded, size: 38, color: Colors.white),
        ),
      ),
    );
  }
}
