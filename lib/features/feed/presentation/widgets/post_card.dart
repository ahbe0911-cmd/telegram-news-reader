import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/formatters/persian_news_date.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/channel_accent.dart';
import '../../../media/data/media_download_service.dart';
import '../../../media/presentation/pages/audio_preview_page.dart';
import '../../../media/presentation/pages/image_viewer_page.dart';
import '../../../media/presentation/pages/local_document_preview_page.dart';
import '../../../media/presentation/pages/pdf_viewer_page.dart';
import '../../../media/presentation/pages/video_player_page.dart';
import '../../../telegram/telegram_providers.dart';
import '../../../web/presentation/pages/in_app_browser_page.dart';
import '../../domain/entities/post.dart';
import 'news_link_text.dart';

class PostCard extends StatefulWidget {
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
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final settings = AppSettings.instance;
    final post = widget.post;
    final title = post.title.trim().isNotEmpty ? post.title.trim() : _firstLine(post.content);
    final body = post.title.trim().isNotEmpty
        ? post.content.trim()
        : post.content.trim().substring(title.length).trim();
    final images = post.attachments.where((a) => a.type == PostAttachmentType.image).toList();
    final hero = images.isNotEmpty && settings.showImages ? images.first : null;
    final remaining = post.attachments.where((a) => a != hero).toList();
    final p = settings.compactCards ? 12.0 : 17.0;
    final accent = ChannelAccent.forSource(post.channelUsername);

    return Card(
      elevation: settings.compactCards ? 2 : 3,
      shadowColor: accent.withValues(alpha: 0.16),
      color: ChannelAccent.tint(post.channelUsername),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: accent.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 3, child: ColoredBox(color: accent)),
            Padding(
              padding: EdgeInsets.fromLTRB(p, p, p, 8),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.channelTitle, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: accent)),
                    Text(post.channelUsername.startsWith('chat_')
                        ? 'کانال خصوصی' : '@${post.channelUsername}',
                      textDirection: post.channelUsername.startsWith('chat_')
                        ? TextDirection.rtl : TextDirection.ltr,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTypography.secondary.copyWith(fontSize: 12)),
                  ])),
                if (post.sortTimestamp != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        PersianNewsDate.relative(post.sortTimestamp!),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.secondary.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        PersianNewsDate.exact(post.sortTimestamp!),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.secondary.copyWith(
                          fontFamily: AppTypography.nazanin,
                          fontSize: 13,
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
              ]),
            ),
            if (title.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(p, 0, p, hero == null && body.isEmpty ? 4 : 7),
                child: NewsLinkText(
                  text: title,
                  style: AppTypography.newsHeadline.copyWith(
                    fontFamily: AppTypography.titr,
                    fontSize: 19 * settings.newsTextScale,
                    fontWeight: FontWeight.w700,
                    height: 1.42),
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                ),
              ),
            if (hero != null)
              _MediaTile(
                key: ValueKey(hero.url),
                attachment: hero,
                hero: true,
                localPath: widget.localMediaPaths[hero.url],
              ),
            if (body.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(p, 7, p, 7),
                child: NewsLinkText(
                  text: body,
                  style: AppTypography.newsBody.copyWith(
                    fontSize: 17 * settings.newsTextScale,
                    height: 1.45),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                ),
              ),
            if (remaining.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(p, 4, p, 5),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final attachment in remaining)
                    _MediaTile(
                      key: ValueKey(attachment.url),
                      attachment: attachment,
                      localPath: widget.localMediaPaths[attachment.url],
                    ),
                ]),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(p - 4, 0, p - 4, 4),
              child: Row(children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.isBookmarked ? 'حذف نشانک' : 'ذخیره خبر',
                  onPressed: widget.onBookmark,
                  icon: Icon(widget.isBookmarked
                    ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 22,
                    color: widget.isBookmarked ? AppPalette.coral : AppPalette.muted),
                ),
                if (widget.onDownload != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'دانلود همه رسانه‌ها',
                    onPressed: widget.onDownload,
                    icon: const Icon(Icons.download_rounded, color: AppPalette.primary),
                  ),
                if (post.permalink != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'نمایش منبع در برنامه',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InAppBrowserPage(initialUrl: post.permalink!))),
                    icon: const Icon(Icons.link_rounded, size: 21),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: Icon(_expanded
                    ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20),
                  label: Text(_expanded ? 'بستن' : 'ادامه خبر'),
                ),
              ]),
            ),
            if (widget.downloadProgress != null)
              Padding(
                padding: EdgeInsets.fromLTRB(p, 0, p, 7),
                child: LinearProgressIndicator(value: widget.downloadProgress),
              ),
          ],
        ),
      ),
    );
  }

  String _firstLine(String full) {
    final value = full.trim();
    // TDLib posts have no separate headline. Prefer a complete first
    // sentence/line rather than truncating the headline at 85 characters.
    final boundary = value.indexOf(RegExp(r'[؟.!\n]'));
    if (boundary >= 18 && boundary < 190) {
      return value.substring(0, boundary + 1).trim();
    }
    if (value.length <= 170) return value;
    final stop = value.lastIndexOf(' ', 170);
    return value.substring(0, stop >= 50 ? stop : 170).trim();
  }


}

class _MediaTile extends ConsumerStatefulWidget {
  const _MediaTile({
    required this.attachment, this.localPath, this.hero = false, super.key,
  });
  final PostAttachment attachment;
  final String? localPath;
  final bool hero;
  @override
  ConsumerState<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends ConsumerState<_MediaTile> {
  String? _cachedPath;
  bool _busy = false;
  bool _openWhenReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.hero && widget.attachment.telegramFileId != null &&
        widget.localPath == null && !AppSettings.instance.dataSaver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch(openAfter: false);
      });
    }
  }

  Future<void> _fetch({required bool openAfter}) async {
    if (_busy) {
      if (openAfter) _openWhenReady = true;
      return;
    }
    final existing = widget.localPath ?? _cachedPath;
    if (existing != null && await File(existing).exists()) {
      if (openAfter && mounted) await _preview(existing);
      return;
    }
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      late final String path;
      final telegramId = widget.attachment.telegramFileId;
      if (telegramId != null) {
        final downloaded = await ref.read(telegramTdlibServiceProvider)
            .downloadFile(telegramId);
        final local = downloaded['local'] is Map
          ? Map<String, dynamic>.from(downloaded['local'] as Map)
          : const <String, dynamic>{};
        path = local['path']?.toString() ?? '';
        if (path.isEmpty || !await File(path).exists()) {
          throw const FileSystemException('دانلود از تلگرام کامل نشد.');
        }
      } else {
        path = await MediaDownloadService(dio: Dio())
            .downloadAttachment(widget.attachment);
      }
      if (!mounted) return;
      setState(() => _cachedPath = path);
      if (openAfter || _openWhenReady) {
        _openWhenReady = false;
        await _preview(path);
      }
    } catch (error) {
      _openWhenReady = false;
      if (mounted) {
        setState(() => _error = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('دانلود انجام نشد: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment() async {
    final attachment = widget.attachment;
    final existing = widget.localPath ?? _cachedPath;
    if (existing != null && await File(existing).exists()) {
      if (mounted) await _preview(existing);
      return;
    }
    if (!mounted) return;

    if (attachment.telegramFileId == null) {
      final url = Uri.tryParse(attachment.url);
      if (url != null && (url.scheme == 'http' || url.scheme == 'https')) {
        late final Widget destination;
        if (attachment.type == PostAttachmentType.image) {
          destination = ImageViewerPage(url: attachment.url);
        } else if (attachment.type == PostAttachmentType.video) {
          destination = VideoPlayerPage(url: attachment.url);
        } else if (attachment.type == PostAttachmentType.audio) {
          destination = AudioPreviewPage(url: attachment.url);
        } else if (_isPdf) {
          destination = PdfViewerPage(url: attachment.url, fileName: attachment.fileName);
        } else {
          await _fetch(openAfter: true);
          return;
        }
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => destination),
          );
        }
        return;
      }
    }
    await _fetch(openAfter: true);
  }

  bool get _isPdf =>
      widget.attachment.mimeType?.toLowerCase().contains('pdf') == true ||
      widget.attachment.fileName?.toLowerCase().endsWith('.pdf') == true;

  Future<void> _preview(String path) async {
    final attachment = widget.attachment;
    final isPdf = _isPdf;
    late final Widget destination;
    if (attachment.type == PostAttachmentType.image) {
      destination = ImageViewerPage(url: '', localPath: path);
    } else if (attachment.type == PostAttachmentType.video) {
      destination = VideoPlayerPage(url: '', localPath: path);
    } else if (attachment.type == PostAttachmentType.audio) {
      destination = AudioPreviewPage(localPath: path);
    } else if (isPdf) {
      destination = PdfViewerPage(
          url: '', localPath: path, fileName: attachment.fileName);
    } else {
      destination = LocalDocumentPreviewPage(
          path: path, fileName: attachment.fileName);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final icon = switch (attachment.type) {
      PostAttachmentType.image => Icons.image_rounded,
      PostAttachmentType.video => Icons.play_circle_rounded,
      PostAttachmentType.audio => Icons.headphones_rounded,
      PostAttachmentType.document => Icons.description_rounded,
      PostAttachmentType.unknown => Icons.attach_file_rounded,
    };
    if (widget.hero) {
      return LayoutBuilder(builder: (context, constraints) {
        // Strict 16:9 frame, capped at 180 logical pixels to avoid tall cards.
        final width = constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth;
        return Center(child: SizedBox(
          width: width, height: width * 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(fit: StackFit.expand, children: [
              if ((_cachedPath ?? widget.localPath) != null)
                Image.file(File((_cachedPath ?? widget.localPath)!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const _MediaPlaceholder())
              else if (attachment.telegramFileId != null)
                const _MediaPlaceholder()
              else
                CachedNetworkImage(
                  imageUrl: attachment.url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const _MediaPlaceholder(),
                  errorWidget: (context, url, error) => const _MediaPlaceholder(),
                ),
              if (attachment.telegramFileId != null &&
                  (_cachedPath ?? widget.localPath) == null)
                Center(child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.image_outlined, color: Colors.white, size: 30)),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openAttachment,
                    splashColor: Colors.white24,
                    highlightColor: Colors.white10,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 6, end: 8,
                child: IconButton.filledTonal(
                  tooltip: 'دانلود یا نمایش تصویر',
                  onPressed: _openAttachment,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.90),
                    foregroundColor: AppPalette.primary,
                  ),
                  icon: Icon((_cachedPath ?? widget.localPath) == null
                    ? Icons.download_rounded : Icons.open_in_full_rounded, size: 21),
                ),
              ),
              if (_error != null)
                PositionedDirectional(
                  bottom: 10, start: 8,
                  child: Icon(Icons.error_outline_rounded, color: Colors.white)),
            ]),
          ),
        ));
      });
    }
    if (attachment.type == PostAttachmentType.video) {
      return SizedBox(
        width: 290,
        child: Material(
          color: AppPalette.ink,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openAttachment,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (attachment.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: attachment.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppPalette.ink, AppPalette.primary],
                        ),
                      ),
                    ),
                  Center(
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 55,
                            color: Colors.white,
                          ),
                  ),
                  PositionedDirectional(
                    start: 12,
                    bottom: 10,
                    child: Text(
                      'پخش ویدئو',
                      style: AppTypography.ui.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 6,
                    bottom: 3,
                    child: IconButton(
                      tooltip: 'دانلود ویدئو',
                      onPressed: _busy ? null : () => _fetch(openAfter: false),
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (attachment.type == PostAttachmentType.audio) {
      return SizedBox(
        width: 290,
        child: Material(
          color: const Color(0xFFEAEFFF),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _openAttachment,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Row(
                children: [
                  _busy
                      ? const SizedBox(
                          width: 37,
                          height: 37,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppPalette.primary,
                          size: 37,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName ?? 'پیام صوتی',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            for (final size in <double>[8, 14, 11, 20, 13, 17, 9, 14])
                              Container(
                                width: 3,
                                height: size,
                                margin: const EdgeInsets.only(left: 3),
                                decoration: BoxDecoration(
                                  color: AppPalette.primary.withValues(alpha: 0.52),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            const SizedBox(width: 7),
                            Text(
                              'پخش',
                              style: AppTypography.secondary.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'دانلود فایل صوتی',
                    onPressed: _busy ? null : () => _fetch(openAfter: false),
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: const Color(0xFFF0F3FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAttachment,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppPalette.primary, size: 19),
              const SizedBox(width: 7),
              Flexible(child: Text(
                attachment.fileName ?? 'فایل رسانه',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.ui.copyWith(fontSize: 12),
              )),
              const SizedBox(width: 5),
              _busy
                ? const SizedBox(width: 19, height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    tooltip: 'دانلود و نمایش',
                    onPressed: _busy ? null : () => _fetch(openAfter: false),
                    icon: Icon((_cachedPath ?? widget.localPath) == null
                      ? Icons.download_rounded : Icons.visibility_rounded,
                      color: AppPalette.primary, size: 20),
                  ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFA5B6E7),
    highlightColor: const Color(0xFFE7E8FB),
    child: const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB6C6FA), Color(0xFFCCB8EF), Color(0xFFFFD5C5)])),
      child: Center(child: Icon(Icons.newspaper_rounded,
        color: Colors.white, size: 34)),
    ),
  );
}
