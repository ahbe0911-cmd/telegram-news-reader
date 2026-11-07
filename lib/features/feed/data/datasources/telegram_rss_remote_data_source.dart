import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../channels/domain/entities/telegram_channel.dart';
import '../../domain/entities/post.dart';
import '../parsers/telegram_rss_parser.dart';

final class TelegramRssRemoteDataSource {
  TelegramRssRemoteDataSource({
    required this._dio,
    required this._parser,
    required this._baseUrl,
  });

  final Dio _dio;
  final TelegramRssParser _parser;
  final String _baseUrl;

  Future<List<Post>> fetchChannel(TelegramChannel channel) async {
    late final Uri feedUri;

    try {
      feedUri = _buildFeedUri(channel);

      final response = await _dio.get<String>(
        feedUri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Accept': 'application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8',
            'User-Agent': 'TelegramNewsReader/1.0',
          },
        ),
      );

      final body = response.data;
      if (body == null || body.trim().isEmpty) return const [];

      return _parser.parse(
        body,
        channel: channel,
        feedUri: feedUri,
      );
    } on DioException catch (error) {
      throw FeedSourceException(
        channelUsername: channel.username,
        sourceUrl: error.requestOptions.uri.toString(),
        message: _dioMessage(error),
        cause: error,
      );
    } on XmlException catch (error) {
      throw FeedParseException(
        sourceUrl: feedUri.toString(),
        message: 'ساختار RSS کانال قابل پردازش نیست.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw FeedParseException(
        message: 'نشانی یا محتوای RSS معتبر نیست.',
        cause: error,
      );
    }
  }

  Uri _buildFeedUri(TelegramChannel channel) {
    final base = Uri.parse(_baseUrl.trim());
    if (base.scheme != 'https' && base.scheme != 'http') {
      throw const FormatException('RSSHub base URL must use HTTP or HTTPS.');
    }

    final normalizedPath = base.path.endsWith('/')
        ? base.path
        : '\${base.path}/';

    final root = base.replace(
      path: normalizedPath,
      query: null,
      fragment: null,
    );

    return root.resolve(
      'telegram/channel/\${Uri.encodeComponent(channel.username)}',
    );
  }

  String _dioMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'مهلت اتصال به RSSHub به پایان رسید.';
      case DioExceptionType.sendTimeout:
        return 'ارسال درخواست به RSSHub بیش از حد طول کشید.';
      case DioExceptionType.receiveTimeout:
        return 'RSSHub در زمان تعیین‌شده پاسخ نداد.';
      case DioExceptionType.transformTimeout:
        return 'پردازش پاسخ RSSHub بیش از حد طول کشید.';
      case DioExceptionType.badResponse:
        return 'RSSHub پاسخ نامعتبر داد (HTTP \${error.response?.statusCode ?? 'نامشخص'}).';
      case DioExceptionType.cancel:
        return 'درخواست دریافت خبر لغو شد.';
      case DioExceptionType.connectionError:
        return 'اتصال به RSSHub برقرار نشد. اینترنت یا نشانی سرور را بررسی کنید.';
      case DioExceptionType.badCertificate:
        return 'گواهی امنیتی سرور RSSHub معتبر نیست.';
      case DioExceptionType.unknown:
        return 'خطای ناشناخته هنگام دریافت خبر از RSSHub.';
    }
  }
}
