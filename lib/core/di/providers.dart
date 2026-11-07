import 'dart:async';

import 'package:dio/dio.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/bookmarks/data/models/bookmark_record.dart';
import '../../features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import '../../features/bookmarks/domain/repositories/bookmark_repository.dart';
import '../../features/channels/data/models/telegram_channel_record.dart';
import '../../features/channels/data/repositories/channel_repository_impl.dart';
import '../../features/channels/domain/entities/telegram_channel.dart';
import '../../features/channels/domain/repositories/channel_repository.dart';
import '../../features/feed/data/datasources/telegram_rss_remote_data_source.dart';
import '../../features/feed/data/parsers/telegram_rss_parser.dart';
import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/domain/entities/feed_page.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../config/app_config.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  final client = Dio(
    BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      followRedirects: true,
      maxRedirects: 5,
      headers: const {
        'Accept': 'application/rss+xml, application/xml, text/xml;q=0.9, */*;q=0.8',
      },
    ),
  );

  ref.onDispose(() => client.close(force: true));
  return client;
}

@Riverpod(keepAlive: true)
TelegramRssParser telegramRssParser(Ref ref) {
  return TelegramRssParser();
}

@Riverpod(keepAlive: true)
TelegramRssRemoteDataSource telegramRssRemoteDataSource(Ref ref) {
  return TelegramRssRemoteDataSource(
    dio: ref.watch(dioClientProvider),
    parser: ref.watch(telegramRssParserProvider),
    baseUrl: AppConfig.rssHubBaseUrl,
  );
}

@Riverpod(keepAlive: true)
FeedRepository feedRepository(Ref ref) {
  return FeedRepositoryImpl(
    remoteDataSource: ref.watch(telegramRssRemoteDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
Future<Isar> isarDatabase(Ref ref) async {
  final directory = await getApplicationDocumentsDirectory();
  final database = await Isar.open(
    [
      BookmarkRecordSchema,
      TelegramChannelRecordSchema,
    ],
    directory: directory.path,
    name: AppConfig.databaseName,
  );

  ref.onDispose(() => unawaited(database.close()));
  return database;
}

@Riverpod(keepAlive: true)
Future<BookmarkRepository> bookmarkRepository(Ref ref) async {
  final database = await ref.watch(isarDatabaseProvider.future);
  return BookmarkRepositoryImpl(database);
}

@Riverpod(keepAlive: true)
Future<ChannelRepository> channelRepository(Ref ref) async {
  final database = await ref.watch(isarDatabaseProvider.future);
  return ChannelRepositoryImpl(database);
}

@Riverpod(keepAlive: true)
Stream<List<BookmarkRecord>> savedBookmarks(Ref ref) async* {
  final repository = await ref.watch(bookmarkRepositoryProvider.future);
  yield* repository.watchAll();
}

@Riverpod(keepAlive: true)
Stream<List<TelegramChannel>> telegramChannels(Ref ref) async* {
  final repository = await ref.watch(channelRepositoryProvider.future);
  yield* repository.watchAll();
}

@Riverpod(keepAlive: true)
Future<FeedPage> feedPage(
  Ref ref, {
  int offset = 0,
  bool forceRefresh = false,
}) async {
  final channelRepository = await ref.watch(channelRepositoryProvider.future);
  final channels = await channelRepository.getEnabled();
  final repository = ref.watch(feedRepositoryProvider);

  return repository.getPage(
    channels: channels,
    offset: offset,
    pageSize: AppConfig.feedPageSize,
    forceRefresh: forceRefresh,
  );
}
