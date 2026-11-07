final class TelegramChannel {
  factory TelegramChannel({
    required String username,
    String? title,
    bool enabled = true,
    DateTime? createdAt,
  }) {
    final normalizedUsername = _normalizeUsername(username);
    final normalizedTitle = title?.trim();

    return TelegramChannel._(
      username: normalizedUsername,
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? normalizedUsername
          : normalizedTitle,
      enabled: enabled,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  const TelegramChannel._({
    required this.username,
    required this.title,
    required this.enabled,
    required this.createdAt,
  });

  final String username;
  final String title;
  final bool enabled;
  final DateTime createdAt;

  TelegramChannel copyWith({
    String? title,
    bool? enabled,
  }) {
    return TelegramChannel._(
      username: username,
      title: title ?? this.title,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  static String _normalizeUsername(String value) {
    final username = value.trim().replaceFirst(RegExp(r'^@'), '');

    if (!RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(username)) {
      throw ArgumentError.value(
        value,
        'username',
        'A public Telegram username must contain 5–32 letters, digits, or underscores.',
      );
    }

    return username;
  }
}
