abstract final class AppConfig {
  static const String rssHubBaseUrl = String.fromEnvironment(
    'RSSHUB_BASE_URL',
    defaultValue: 'https://rsshub.app',
  );

  static const int feedPageSize = 20;
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);
  static const String databaseName = 'telegram_news_reader';
}
