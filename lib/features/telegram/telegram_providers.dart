import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'data/telegram_tdlib_service.dart';

final telegramSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final telegramTdlibServiceProvider = Provider<TelegramTdlibService>((ref) {
  final service = TelegramTdlibService(
    storage: ref.watch(telegramSecureStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
