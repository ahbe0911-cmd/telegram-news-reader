import '../../../../core/errors/app_exception.dart';
import '../../../channels/domain/entities/telegram_channel.dart';
import '../../../telegram/data/telegram_tdlib_service.dart';
import '../../domain/entities/post.dart';

final class TelegramTdlibRemoteDataSource {
  const TelegramTdlibRemoteDataSource({required this.telegram});

  final TelegramTdlibService telegram;

  Future<List<Post>> fetchChannel(TelegramChannel channel) async {
    try {
      final chat = channel.chatId == null
          ? await telegram.resolvePublicChannel(channel.username)
          : await telegram.getChat(channel.chatId!);

      final chatId = (chat['id'] as num?)?.toInt();
      if (chatId == null) {
        throw const FormatException('Telegram did not return a chat ID.');
      }

      final title = chat['title']?.toString().trim();
      final username = _extractUsername(chat) ?? channel.username;
      final history = await telegram.getChatHistory(
        chatId: chatId,
        limit: 100,
      );
      final rawMessages = history['messages'];
      if (rawMessages is! List) return const [];

      return rawMessages
          .whereType<Map>()
          .map((message) => _parseMessage(
                Map<String, dynamic>.from(message),
                chatId: chatId,
                channelUsername: username,
                channelTitle: title?.isNotEmpty == true ? title! : channel.title,
              ))
          .where((post) => post.content.isNotEmpty || post.attachments.isNotEmpty)
          .toList(growable: false);
    } on TelegramTdlibException {
      rethrow;
    } catch (error) {
      throw FeedSourceException(
        channelUsername: channel.username,
        sourceUrl: 'tdlib://chat/${channel.chatId ?? channel.username}',
        message: 'دریافت پست‌های کانال از تلگرام ناموفق بود: $error',
        cause: error,
      );
    }
  }

  Post _parseMessage(
    Map<String, dynamic> message, {
    required int chatId,
    required String channelUsername,
    required String channelTitle,
  }) {
    final messageId = (message['id'] as num?)?.toInt() ?? 0;
    final dateSeconds = (message['date'] as num?)?.toInt();
    final date = dateSeconds == null || dateSeconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            dateSeconds * 1000,
            isUtc: true,
          );
    final content = _asMap(message['content']);
    final contentType = content['@type']?.toString() ?? '';
    final attachments = <PostAttachment>[];
    var text = '';

    switch (contentType) {
      case 'messageText':
        text = _formattedText(content['text']);
        break;
      case 'messagePhoto':
        text = _formattedText(content['caption']);
        final photo = _asMap(content['photo']);
        final sizes = photo['sizes'];
        if (sizes is List && sizes.isNotEmpty) {
          final largest = _asMap(sizes.last);
          final file = _asMap(largest['photo']);
          _addFileAttachment(
            attachments,
            file,
            type: PostAttachmentType.image,
            fileName: 'telegram-photo-$messageId.jpg',
            mimeType: 'image/jpeg',
          );
        }
        break;
      case 'messageVideo':
        final video = _asMap(content['video']);
        text = _formattedText(content['caption']);
        _addFileAttachment(
          attachments,
          _asMap(video['video']),
          type: PostAttachmentType.video,
          fileName: video['file_name']?.toString() ?? 'telegram-video.mp4',
          mimeType: video['mime_type']?.toString() ?? 'video/mp4',
        );
        break;
      case 'messageAnimation':
        final animation = _asMap(content['animation']);
        text = _formattedText(content['caption']);
        _addFileAttachment(
          attachments,
          _asMap(animation['animation']),
          type: PostAttachmentType.video,
          fileName: animation['file_name']?.toString() ?? 'telegram-animation.mp4',
          mimeType: animation['mime_type']?.toString() ?? 'video/mp4',
        );
        break;
      case 'messageDocument':
        final document = _asMap(content['document']);
        text = _formattedText(content['caption']);
        _addFileAttachment(
          attachments,
          _asMap(document['document']),
          type: PostAttachmentType.document,
          fileName: document['file_name']?.toString() ?? 'telegram-document',
          mimeType: document['mime_type']?.toString(),
        );
        break;
      case 'messageAudio':
        final audio = _asMap(content['audio']);
        text = _formattedText(content['caption']);
        _addFileAttachment(
          attachments,
          _asMap(audio['audio']),
          type: PostAttachmentType.audio,
          fileName: audio['file_name']?.toString() ?? 'telegram-audio',
          mimeType: audio['mime_type']?.toString(),
        );
        break;
      case 'messageVoiceNote':
        final voice = _asMap(content['voice_note']);
        _addFileAttachment(
          attachments,
          _asMap(voice['voice']),
          type: PostAttachmentType.audio,
          fileName: 'telegram-voice.ogg',
          mimeType: 'audio/ogg',
        );
        break;
      default:
        text = _formattedText(content['caption']);
    }

    final permalink = _messagePermalink(
      chatId: chatId,
      username: channelUsername,
      messageId: messageId,
    );

    return Post(
      id: '$chatId:$messageId',
      channelUsername: channelUsername,
      channelTitle: channelTitle,
      title: '',
      content: text,
      sourceUrl: 'tdlib://chat/$chatId',
      publishedAt: date,
      permalink: permalink,
      attachments: attachments,
    );
  }

  void _addFileAttachment(
    List<PostAttachment> attachments,
    Map<String, dynamic> file, {
    required PostAttachmentType type,
    required String fileName,
    String? mimeType,
  }) {
    final fileId = (file['id'] as num?)?.toInt();
    if (fileId == null || fileId <= 0) return;

    attachments.add(PostAttachment(
      url: 'tdlib://file/$fileId',
      type: type,
      fileName: fileName,
      mimeType: mimeType,
      telegramFileId: fileId,
    ));
  }

  String _formattedText(dynamic value) {
    final formatted = _asMap(value);
    return formatted['text']?.toString().trim() ?? '';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String? _extractUsername(Map<String, dynamic> chat) {
    final direct = chat['username']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final usernames = _asMap(chat['usernames']);
    final active = usernames['active_usernames'];
    if (active is List && active.isNotEmpty) {
      final value = active.first.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _messagePermalink({
    required int chatId,
    required String username,
    required int messageId,
  }) {
    if (messageId <= 0) return null;
    if (!username.startsWith('chat_')) {
      return 'https://t.me/$username/$messageId';
    }

    final rawId = chatId.toString();
    if (rawId.startsWith('-100') && rawId.length > 4) {
      return 'https://t.me/c/${rawId.substring(4)}/$messageId';
    }
    return null;
  }
}
