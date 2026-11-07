import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../../channels/domain/entities/telegram_channel.dart';
import '../../domain/entities/post.dart';

final class TelegramRssParser {
  List<Post> parse(
    String source, {
    required TelegramChannel channel,
    required Uri feedUri,
  }) {
    final document = XmlDocument.parse(source);
    final elements = document.descendants.whereType<XmlElement>().toList();

    final rssItems = elements
        .where((element) => element.name.local == 'item')
        .toList(growable: false);
    final atomEntries = elements
        .where((element) => element.name.local == 'entry')
        .toList(growable: false);

    final entries = rssItems.isNotEmpty ? rssItems : atomEntries;

    return entries
        .map(
          (entry) => _parseEntry(
            entry,
            channel: channel,
            feedUri: feedUri,
          ),
        )
        .where(
          (post) =>
              post.title.isNotEmpty ||
              post.content.isNotEmpty ||
              post.attachments.isNotEmpty,
        )
        .toList(growable: false);
  }

  Post _parseEntry(
    XmlElement entry, {
    required TelegramChannel channel,
    required Uri feedUri,
  }) {
    final title = _firstText(entry, const ['title']) ?? '';
    final rawContent = _firstText(
          entry,
          const ['encoded', 'description', 'summary', 'content'],
        ) ??
        '';
    final content = _htmlToText(rawContent);
    final publishedAt = _parseDate(
      _firstText(entry, const ['pubDate', 'published', 'updated', 'date']),
    );
    final permalink = _firstLink(entry, feedUri);
    final guid = _firstText(entry, const ['guid', 'id']);

    final attachments = _parseAttachments(
      entry,
      rawContent: rawContent,
      feedUri: feedUri,
    );

    final fallbackId = [
      channel.username,
      publishedAt?.millisecondsSinceEpoch.toString() ?? 'undated',
      title,
      permalink ?? '',
    ].join('|');

    return Post(
      id: guid?.isNotEmpty == true
          ? guid!
          : (permalink?.isNotEmpty == true ? permalink! : fallbackId),
      channelUsername: channel.username,
      channelTitle: channel.title,
      title: _htmlToText(title),
      content: content,
      sourceUrl: feedUri.toString(),
      publishedAt: publishedAt,
      permalink: permalink,
      attachments: attachments,
    );
  }

  String? _firstText(XmlElement parent, List<String> preferredNames) {
    final descendants = parent.descendants.whereType<XmlElement>().toList();

    for (final preferredName in preferredNames) {
      for (final element in descendants) {
        if (element.name.local != preferredName) continue;

        final value = element.innerText.trim();
        if (value.isNotEmpty) return value;
      }
    }

    return null;
  }

  String? _firstLink(XmlElement parent, Uri feedUri) {
    final links = parent.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'link');

    for (final link in links) {
      final relation = link.getAttribute('rel')?.toLowerCase();
      if (relation == 'self' || relation == 'enclosure') continue;

      final value = link.getAttribute('href')?.trim();
      final textValue = link.innerText.trim();
      final candidate = value?.isNotEmpty == true ? value : textValue;

      final resolved = _resolveUrl(candidate, feedUri);
      if (resolved != null) return resolved.toString();
    }

    return null;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = value.trim();
    final isoDate = DateTime.tryParse(normalized);
    if (isoDate != null) return isoDate.toUtc();

    try {
      return HttpDate.parse(normalized).toUtc();
    } on FormatException {
      return null;
    }
  }

  List<PostAttachment> _parseAttachments(
    XmlElement entry, {
    required String rawContent,
    required Uri feedUri,
  }) {
    final byUrl = <String, PostAttachment>{};
    final xmlElements = entry.descendants.whereType<XmlElement>().toList();

    String? thumbnailUrl;
    for (final element in xmlElements) {
      if (element.name.local != 'thumbnail') continue;

      final thumbnail = _resolveUrl(
        element.getAttribute('url') ?? element.getAttribute('href'),
        feedUri,
      );
      thumbnailUrl ??= thumbnail?.toString();
    }

    for (final element in xmlElements) {
      final localName = element.name.local;
      if (localName != 'enclosure' && localName != 'content') continue;

      final rawUrl = element.getAttribute('url') ??
          element.getAttribute('src') ??
          element.getAttribute('href');
      final resolved = _resolveUrl(rawUrl, feedUri);
      if (resolved == null) continue;

      final attachment = _attachment(
        resolved,
        mimeType: element.getAttribute('type'),
        medium: element.getAttribute('medium'),
        thumbnailUrl: thumbnailUrl,
      );
      byUrl[attachment.url] = attachment;
    }

    final fragment = html_parser.parseFragment(rawContent);

    for (final image in fragment.querySelectorAll('img[src]')) {
      final resolved = _resolveUrl(image.attributes['src'], feedUri);
      if (resolved == null) continue;

      final attachment = _attachment(
        resolved,
        mimeType: 'image/*',
        medium: 'image',
      );
      byUrl.putIfAbsent(attachment.url, () => attachment);
    }

    for (final video in fragment.querySelectorAll(
      'video[src], video source[src]',
    )) {
      final resolved = _resolveUrl(video.attributes['src'], feedUri);
      if (resolved == null) continue;

      final attachment = _attachment(
        resolved,
        mimeType: video.attributes['type'],
        medium: 'video',
      );
      byUrl.putIfAbsent(attachment.url, () => attachment);
    }

    for (final anchor in fragment.querySelectorAll('a[href]')) {
      final resolved = _resolveUrl(anchor.attributes['href'], feedUri);
      if (resolved == null) continue;

      final attachment = _attachment(resolved);
      if (attachment.type == PostAttachmentType.unknown) continue;
      byUrl.putIfAbsent(attachment.url, () => attachment);
    }

    return byUrl.values.toList(growable: false);
  }

  PostAttachment _attachment(
    Uri uri, {
    String? mimeType,
    String? medium,
    String? thumbnailUrl,
  }) {
    final type = _inferType(
      uri: uri,
      mimeType: mimeType,
      medium: medium,
    );

    return PostAttachment(
      url: uri.toString(),
      type: type,
      mimeType: mimeType,
      fileName: uri.pathSegments.isEmpty ? null : uri.pathSegments.last,
      thumbnailUrl: thumbnailUrl,
    );
  }

  PostAttachmentType _inferType({
    required Uri uri,
    String? mimeType,
    String? medium,
  }) {
    final mime = (mimeType ?? '').toLowerCase();
    final media = (medium ?? '').toLowerCase();
    final path = uri.path.toLowerCase();

    if (mime.startsWith('image/') ||
        media == 'image' ||
        RegExp(r'\.(png|jpe?g|gif|webp|bmp|avif)$').hasMatch(path)) {
      return PostAttachmentType.image;
    }

    if (mime.startsWith('video/') ||
        media == 'video' ||
        RegExp(r'\.(mp4|m4v|mov|webm|m3u8)$').hasMatch(path)) {
      return PostAttachmentType.video;
    }

    if (mime.startsWith('audio/') ||
        RegExp(r'\.(mp3|m4a|aac|ogg|wav|flac)$').hasMatch(path)) {
      return PostAttachmentType.audio;
    }

    if (mime == 'application/pdf' ||
        RegExp(r'\.(pdf|doc|docx|ppt|pptx|xls|xlsx|zip|epub)$')
            .hasMatch(path)) {
      return PostAttachmentType.document;
    }

    return PostAttachmentType.unknown;
  }

  Uri? _resolveUrl(String? value, Uri baseUri) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final uri = baseUri.resolve(value.trim());
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;
      return uri;
    } on FormatException {
      return null;
    }
  }

  String _htmlToText(String value) {
    final normalizedHtml = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(p|div|li|blockquote|h[1-6])\s*>', caseSensitive: false),
          '\n',
        );

    final text = html_parser.parseFragment(normalizedHtml).text ?? '';
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
