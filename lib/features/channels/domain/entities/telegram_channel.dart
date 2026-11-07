final class TelegramChannel {
  factory TelegramChannel({
    required String username,
    String? title,
    int? chatId,
    bool enabled = true,
    DateTime? createdAt,
  }) {
    final normalizedUsername = _normalizeUsername(username, chatId);
    final normalizedTitle = title?.trim();

    return TelegramChannel._(
      username: normalizedUsername,
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? normalizedUsername
          : normalizedTitle,
      chatId: chatId,
      enabled: enabled,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  const TelegramChannel._({
    required this.username,
    required this.title,
    required this.chatId,
    required this.enabled,
    required this.createdAt,
  });

  /// A public Telegram username or a stable local key for a private chat.
  final String username;
  final String title;
  final int? chatId;
  final bool enabled;
  final DateTime createdAt;

  bool get isPrivateChat => username.startsWith('chat_');

  TelegramChannel copyWith({
    String? title,
    int? chatId,
    bool? enabled,
  }) {
    return TelegramChannel._(
      username: username,
      title: title ?? this.title,
      chatId: chatId ?? this.chatId,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  static String _normalizeUsername(String value, int? chatId) {
    final username = value.trim().replaceFirst(RegExp(r'^@'), '');

    if (RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(username)) {
      return username;
    }

    if (chatId != null && chatId != 0) {
      return 'chat_${chatId.abs()}';
    }

    throw ArgumentError.value(
      value,
      'username',
      'A Telegram username must contain 5–32 letters, digits, or underscores.',
    );
  }
}
