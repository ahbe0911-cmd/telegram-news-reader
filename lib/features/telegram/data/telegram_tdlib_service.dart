import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path_provider/path_provider.dart';

enum TelegramAuthStage {
  checking,
  needsApiCredentials,
  initializing,
  waitingForPhone,
  waitingForCode,
  waitingForPassword,
  waitingForEmailAddress,
  waitingForEmailCode,
  waitingForOtherDeviceConfirmation,
  ready,
  closed,
  error,
}

class TelegramAuthStatus {
  const TelegramAuthStatus(this.stage, {this.message});

  final TelegramAuthStage stage;
  final String? message;
}

class TelegramTdlibException implements Exception {
  const TelegramTdlibException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'Telegram error $code: $message';
}

/// Owns the TDLib worker, login flow and authenticated Telegram requests.
///
/// API credentials, the TDLib database key and the local authorization
/// database never leave this device.
class TelegramTdlibService {
  TelegramTdlibService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _apiIdKey = 'telegram_api_id';
  static const _apiHashKey = 'telegram_api_hash';
  static const _databaseKey = 'telegram_tdlib_database_key';

  final FlutterSecureStorage _storage;
  final StreamController<TelegramAuthStatus> _statusController =
      StreamController<TelegramAuthStatus>.broadcast();

  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  TelegramAuthStatus _status =
      const TelegramAuthStatus(TelegramAuthStage.checking);

  StreamSubscription<dynamic>? _workerSubscription;
  ReceivePort? _workerReceivePort;
  Isolate? _worker;
  SendPort? _workerCommandPort;
  Completer<void>? _workerReady;
  int _nextRequestId = 0;
  int? _apiId;
  String? _apiHash;
  String? _databaseEncryptionKey;
  bool _restoreStarted = false;
  bool _tdlibParametersSent = false;
  bool _databaseKeySent = false;
  bool _sendingParameters = false;
  bool _workerStopping = false;
  bool _disposed = false;
  Completer<void>? _workerStopped;
  Timer? _authorizationProbeTimer;
  String? _lastAuthorizationState;
  Future<void>? _startingWorker;

  TelegramAuthStatus get status => _status;
  Stream<TelegramAuthStatus> get statusStream => _statusController.stream;
  bool get isAuthorized => _status.stage == TelegramAuthStage.ready;

  Future<void> restore() async {
    if (_restoreStarted || _disposed) return;
    _restoreStarted = true;
    _emit(const TelegramAuthStatus(
      TelegramAuthStage.checking,
      message: 'در حال بررسی اطلاعات ورود ذخیره‌شده…',
    ));

    try {
      final id = await _storage
          .read(key: _apiIdKey)
          .timeout(const Duration(seconds: 15));
      final hash = await _storage
          .read(key: _apiHashKey)
          .timeout(const Duration(seconds: 15));
      if (id == null || hash == null || id.isEmpty || hash.isEmpty) {
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.needsApiCredentials,
        ));
        return;
      }

      final parsedId = int.tryParse(id);
      if (parsedId == null || parsedId <= 0) {
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.needsApiCredentials,
          message: 'API ID ذخیره‌شده معتبر نیست. دوباره آن را وارد کن.',
        ));
        return;
      }

      _apiId = parsedId;
      _apiHash = hash;
      await _ensureDatabaseKey().timeout(const Duration(seconds: 15));
      await _startWorker();
    } catch (error) {
      // Allow the Retry button to re-read secure storage after an early failure.
      _restoreStarted = false;
      if (_status.stage != TelegramAuthStage.error) {
        _emit(TelegramAuthStatus(
          TelegramAuthStage.error,
          message: error is TimeoutException
              ? 'مهلت بازیابی اطلاعات ورود تمام شد. دوباره تلاش کن.'
              : 'بازیابی تنظیمات اتصال تلگرام ناموفق بود: $error',
        ));
      }
    }
  }

  Future<void> saveApiCredentials({
    required int apiId,
    required String apiHash,
  }) async {
    if (apiId <= 0) {
      throw ArgumentError('API ID باید یک عدد مثبت باشد.');
    }
    final normalizedHash = apiHash.trim();
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(normalizedHash)) {
      throw ArgumentError('API Hash باید یک کد ۳۲ کاراکتری معتبر باشد.');
    }

    await _storage
        .write(key: _apiIdKey, value: apiId.toString())
        .timeout(const Duration(seconds: 15));
    await _storage
        .write(key: _apiHashKey, value: normalizedHash)
        .timeout(const Duration(seconds: 15));
    _apiId = apiId;
    _apiHash = normalizedHash;
    _restoreStarted = true;
    await _ensureDatabaseKey().timeout(const Duration(seconds: 15));
    await _stopWorker();
    await _startWorker();
  }

  Future<void> submitPhoneNumber(String phoneNumber) async {
    final phone = phoneNumber.trim().replaceAll(' ', '');
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone)) {
      throw ArgumentError('شماره را با کد کشور وارد کن؛ مانند +989121234567');
    }
    await _request('setAuthenticationPhoneNumber', {
      'phone_number': phone,
    });
  }

  Future<void> submitCode(String code) async {
    final normalized = code.trim().replaceAll(' ', '');
    if (normalized.isEmpty) {
      throw ArgumentError('کد دریافتی را وارد کن.');
    }
    await _request('checkAuthenticationCode', {'code': normalized});
  }

  Future<void> submitPassword(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('رمز دومرحله‌ای را وارد کن.');
    }
    await _request('checkAuthenticationPassword', {
      'password': password,
    });
  }

  Future<void> submitEmailAddress(String email) async {
    if (!email.contains('@') || !email.contains('.')) {
      throw ArgumentError('نشانی ایمیل معتبر وارد کن.');
    }
    await _request('setAuthenticationEmailAddress', {
      'email_address': email.trim(),
    });
  }

  Future<void> submitEmailCode(String code) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('کد ایمیل را وارد کن.');
    }
    await _request('checkAuthenticationEmailCode', {
      'code': {'@type': 'emailAddressAuthenticationCode', 'code': code.trim()},
    });
  }

  Future<Map<String, dynamic>> resolvePublicChannel(String username) async {
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(normalized)) {
      throw ArgumentError('نام کاربری عمومی کانال معتبر نیست.');
    }

    final chat = await _request('searchPublicChat', {'username': normalized});
    _validateChannelChat(chat);
    return chat;
  }

  /// Accepts a public @username, t.me link, or a numeric chat ID already
  /// known to this Telegram account (for example a private channel ID).
  Future<Map<String, dynamic>> resolveChannel(String input) async {
    var normalized = input.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('آیدی یا لینک کانال را وارد کن.');
    }

    final linkCandidate = normalized.startsWith('t.me/')
        ? 'https://$normalized'
        : normalized;
    final uri = Uri.tryParse(linkCandidate);
    if (uri != null &&
        (uri.host.toLowerCase() == 't.me' ||
            uri.host.toLowerCase() == 'www.t.me')) {
      final segments =
          uri.pathSegments.where((part) => part.isNotEmpty).toList();
      if (segments.isEmpty) {
        throw ArgumentError('لینک کانال معتبر نیست.');
      }
      normalized = segments.first == 's' && segments.length > 1
          ? segments[1]
          : segments.first;
    }

    final numericChatId = int.tryParse(normalized);
    if (numericChatId != null) {
      if (numericChatId == 0) {
        throw ArgumentError('شناسه عددی کانال معتبر نیست.');
      }
      final chat = await getChat(numericChatId);
      _validateChannelChat(chat);
      return chat;
    }

    return resolvePublicChannel(normalized);
  }

  void _validateChannelChat(Map<String, dynamic> chat) {
    final type = chat['type'];
    if (type is! Map ||
        type['@type'] != 'chatTypeSupergroup' ||
        type['is_channel'] != true) {
      throw StateError('این شناسه متعلق به یک کانال تلگرام نیست.');
    }
  }

  Future<Map<String, dynamic>> getChatHistory({
    required int chatId,
    int limit = 50,
    int fromMessageId = 0,
  }) {
    return _request('getChatHistory', {
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'offset': 0,
      'limit': limit.clamp(1, 100),
      'only_local': false,
    }, timeout: const Duration(seconds: 90));
  }

  Future<Map<String, dynamic>> getChats({
    int limit = 100,
    bool archived = false,
  }) {
    return _request('getChats', {
      'chat_list': {
        '@type': archived ? 'chatListArchive' : 'chatListMain',
      },
      'limit': limit.clamp(1, 200),
    });
  }

  Future<Map<String, dynamic>> getChat(int chatId) {
    return _request('getChat', {'chat_id': chatId});
  }

  Future<Map<String, dynamic>> downloadFile(int fileId) {
    return _request(
      'downloadFile',
      {
        'file_id': fileId,
        'priority': 16,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      },
      timeout: const Duration(minutes: 5),
    );
  }

  Future<void> logout() async {
    await _request('logOut', const {});
  }

  Future<void> retry() async {
    if (_apiId == null || _apiHash == null) {
      _restoreStarted = false;
      await restore();
      return;
    }
    await _stopWorker();
    await _startWorker();
  }

  Future<void> clearApiCredentials() async {
    await _stopWorker();
    final supportDirectory = await getApplicationSupportDirectory();
    for (final directoryName in const [
      'telegram_database',
      'telegram_files',
    ]) {
      final directory = Directory('${supportDirectory.path}/$directoryName');
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    await _storage.delete(key: _apiIdKey);
    await _storage.delete(key: _apiHashKey);
    await _storage.delete(key: _databaseKey);
    _apiId = null;
    _apiHash = null;
    _databaseEncryptionKey = null;
    _restoreStarted = false;
    _emit(const TelegramAuthStatus(
      TelegramAuthStage.needsApiCredentials,
    ));
  }

  Future<void> _ensureDatabaseKey() async {
    var key = await _storage.read(key: _databaseKey);
    if (key == null || key.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = base64Encode(bytes);
      await _storage.write(key: _databaseKey, value: key);
    }
    _databaseEncryptionKey = key;
  }

  Future<void> _startWorker() {
    final activeStart = _startingWorker;
    if (activeStart != null) return activeStart;

    final start = _startWorkerInternal();
    _startingWorker = start;
    return start.whenComplete(() {
      if (identical(_startingWorker, start)) {
        _startingWorker = null;
      }
    });
  }

  Future<void> _startWorkerInternal() async {
    final apiId = _apiId;
    final apiHash = _apiHash;
    final databaseKey = _databaseEncryptionKey;
    if (apiId == null || apiHash == null || databaseKey == null) {
      _emit(const TelegramAuthStatus(
        TelegramAuthStage.needsApiCredentials,
      ));
      return;
    }

    _authorizationProbeTimer?.cancel();
    _tdlibParametersSent = false;
    _databaseKeySent = false;
    _sendingParameters = false;
    _lastAuthorizationState = null;

    _emit(const TelegramAuthStatus(
      TelegramAuthStage.initializing,
      message: 'در حال آماده‌سازی موتور تلگرام…',
    ));

    try {
      final supportDirectory = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 15));
      final databaseDirectory =
          Directory('${supportDirectory.path}/telegram_database');
      final filesDirectory =
          Directory('${supportDirectory.path}/telegram_files');
      await databaseDirectory.create(recursive: true);
      await filesDirectory.create(recursive: true);

      _workerReady = Completer<void>();
      _workerStopped = Completer<void>();
      _workerReceivePort = ReceivePort();
      _workerSubscription = _workerReceivePort!.listen(_handleWorkerMessage);

      _worker = await Isolate.spawn<Map<String, dynamic>>(
        _tdlibWorkerMain,
        {
          'mainPort': _workerReceivePort!.sendPort,
          'apiId': apiId,
          'apiHash': apiHash,
          'databaseKey': databaseKey,
          'databaseDirectory': databaseDirectory.path,
          'filesDirectory': filesDirectory.path,
        },
        onError: _workerReceivePort!.sendPort,
        onExit: _workerReceivePort!.sendPort,
        debugName: 'Telegram TDLib worker',
      ).timeout(const Duration(seconds: 15));

      await _workerReady!.future.timeout(const Duration(seconds: 30));

      _emit(const TelegramAuthStatus(
        TelegramAuthStage.initializing,
        message: 'موتور تلگرام آماده شد؛ در حال بررسی وضعیت نشست…',
      ));

      // TDLib starts with authorizationStateWaitTdlibParameters. This query
      // is a fallback in case the first update arrived before the UI listener.
      final authorization = await _request(
        'getAuthorizationState',
        const {},
        timeout: const Duration(seconds: 20),
      );
      final stateName = authorization['@type']?.toString();
      if (stateName == null || !stateName.startsWith('authorizationState')) {
        throw StateError(
          'پاسخ وضعیت ورود از تلگرام معتبر نبود: ${authorization['@type']}',
        );
      }
      _handleAuthorizationState(stateName);
    } on TimeoutException catch (error) {
      await _stopWorker();
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: 'تلگرام در زمان مجاز پاسخ نداد. آخرین مرحله اتصال کامل نشد: $error',
      ));
      rethrow;
    } catch (error) {
      await _stopWorker();
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: 'راه‌اندازی موتور تلگرام ناموفق بود: $error',
      ));
      rethrow;
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (message == null) {
      if (_workerStopping) {
        if (!(_workerStopped?.isCompleted ?? true)) {
          _workerStopped!.complete();
        }
        return;
      }
      if (!_disposed &&
          _worker != null &&
          _status.stage != TelegramAuthStage.error &&
          _status.stage != TelegramAuthStage.closed) {
        _reportWorkerFailure(
          'پردازش پس‌زمینه تلگرام بدون درخواست توقف بسته شد.',
        );
      }
      return;
    }

    if (message is List && message.isNotEmpty) {
      _reportWorkerFailure('خطای پردازش موتور تلگرام: ${message.first}');
      return;
    }
    if (message is! Map) return;
    final data = Map<String, dynamic>.from(message);

    if (data['kind'] == 'ready') {
      _workerCommandPort = data['commandPort'] as SendPort?;
      if (!(_workerReady?.isCompleted ?? true)) _workerReady!.complete();
      return;
    }
    if (data['kind'] == 'stopped') {
      if (!(_workerStopped?.isCompleted ?? true)) {
        _workerStopped!.complete();
      }
      return;
    }
    if (data['kind'] == 'workerError') {
      _reportWorkerFailure(
        data['message']?.toString() ?? 'خطای ناشناخته TDLib',
      );
      return;
    }

    final extra = data['@extra'];
    if (extra != null) {
      final requestId = int.tryParse(extra.toString());
      final completer = requestId == null ? null : _pending.remove(requestId);
      if (completer != null && !completer.isCompleted) {
        if (data['@type'] == 'error') {
          completer.completeError(TelegramTdlibException(
            (data['code'] as num?)?.toInt() ?? 0,
            data['message']?.toString() ?? 'Telegram request failed',
          ));
        } else {
          completer.complete(data);
        }
      }
      return;
    }

    if (data['@type'] == 'updateAuthorizationState') {
      final authState = data['authorization_state'];
      final stateName = authState is Map
          ? authState['@type']?.toString() ?? ''
          : '';
      _handleAuthorizationState(stateName);
    }
  }

  void _reportWorkerFailure(String message) {
    final error = StateError(message);
    if (!(_workerReady?.isCompleted ?? true)) {
      _workerReady!.completeError(error);
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();

    if (!_disposed && _status.stage != TelegramAuthStage.error) {
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: message,
      ));
    }
  }

  void _handleAuthorizationState(String stateName) {
    _lastAuthorizationState = stateName;
    _authorizationProbeTimer?.cancel();
    _authorizationProbeTimer = null;

    switch (stateName) {
      case 'authorizationStateWaitTdlibParameters':
        if (!_tdlibParametersSent && !_sendingParameters) {
          _tdlibParametersSent = true;
          _emit(const TelegramAuthStatus(
            TelegramAuthStage.initializing,
            message: 'در حال ارسال تنظیمات امن به تلگرام…',
          ));
          unawaited(_sendTdlibParameters());
        }
        break;
      case 'authorizationStateWaitEncryptionKey':
        if (!_databaseKeySent) {
          _databaseKeySent = true;
          _emit(const TelegramAuthStatus(
            TelegramAuthStage.initializing,
            message: 'در حال بازکردن پایگاه داده رمزگذاری‌شده…',
          ));
          unawaited(_checkDatabaseEncryptionKey());
        }
        break;
      case 'authorizationStateWaitPhoneNumber':
        _emit(const TelegramAuthStatus(TelegramAuthStage.waitingForPhone));
        break;
      case 'authorizationStateWaitCode':
        _emit(const TelegramAuthStatus(TelegramAuthStage.waitingForCode));
        break;
      case 'authorizationStateWaitPassword':
        _emit(const TelegramAuthStatus(TelegramAuthStage.waitingForPassword));
        break;
      case 'authorizationStateWaitEmailAddress':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.waitingForEmailAddress,
        ));
        break;
      case 'authorizationStateWaitEmailCode':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.waitingForEmailCode,
        ));
        break;
      case 'authorizationStateWaitOtherDeviceConfirmation':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.waitingForOtherDeviceConfirmation,
          message: 'ورود باید از دستگاه دیگری تأیید شود.',
        ));
        break;
      case 'authorizationStateReady':
        _emit(const TelegramAuthStatus(TelegramAuthStage.ready));
        break;
      case 'authorizationStateLoggingOut':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.initializing,
          message: 'در حال خروج از حساب تلگرام…',
        ));
        break;
      case 'authorizationStateClosing':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.initializing,
          message: 'در حال بستن نشست تلگرام…',
        ));
        break;
      case 'authorizationStateClosed':
        _emit(const TelegramAuthStatus(TelegramAuthStage.closed));
        break;
      case 'authorizationStateWaitRegistration':
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.error,
          message: 'این حساب نیاز به ثبت‌نام جدید دارد که هنوز در برنامه پشتیبانی نمی‌شود.',
        ));
        break;
      default:
        _emit(TelegramAuthStatus(
          TelegramAuthStage.initializing,
          message: 'وضعیت اتصال تلگرام: ${stateName.isEmpty ? 'نامشخص' : stateName}',
        ));
    }
  }

  Future<void> _checkDatabaseEncryptionKey() async {
    try {
      await _request('checkDatabaseEncryptionKey', {
        'encryption_key': _databaseEncryptionKey ?? '',
      }, timeout: const Duration(seconds: 30));
      _scheduleAuthorizationProbe(
        expectedState: 'authorizationStateWaitEncryptionKey',
        failureMessage: 'کلید پایگاه داده پذیرفته شد، اما وضعیت نشست تلگرام تغییر نکرد.',
      );
    } catch (error) {
      _databaseKeySent = false;
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: 'بازکردن پایگاه داده تلگرام ناموفق بود: $error',
      ));
    }
  }

  void _scheduleAuthorizationProbe({
    required String expectedState,
    required String failureMessage,
  }) {
    _authorizationProbeTimer?.cancel();
    _authorizationProbeTimer = Timer(const Duration(seconds: 8), () {
      unawaited(_probeAuthorizationState(
        expectedState: expectedState,
        failureMessage: failureMessage,
      ));
    });
  }

  Future<void> _probeAuthorizationState({
    required String expectedState,
    required String failureMessage,
  }) async {
    if (_disposed || _status.stage != TelegramAuthStage.initializing) return;

    try {
      final authorization = await _request(
        'getAuthorizationState',
        const {},
        timeout: const Duration(seconds: 15),
      );
      final stateName = authorization['@type']?.toString();
      if (stateName == null || !stateName.startsWith('authorizationState')) {
        throw StateError('پاسخ وضعیت نشست معتبر نیست.');
      }

      if (stateName == expectedState) {
        _emit(TelegramAuthStatus(
          TelegramAuthStage.error,
          message: '$failureMessage برای جلوگیری از توقف بی‌پایان، اتصال متوقف شد. می‌توانی دوباره تلاش کنی.',
        ));
        return;
      }

      _handleAuthorizationState(stateName);
    } catch (error) {
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: '$failureMessage پاسخ نهایی تلگرام دریافت نشد: $error',
      ));
    }
  }

  Future<void> _sendTdlibParameters() async {
    if (_sendingParameters) return;
    _sendingParameters = true;

    try {
      final supportDirectory = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 15));
      await _request('setTdlibParameters', {
        'use_test_dc': false,
        'database_directory': '${supportDirectory.path}/telegram_database',
        'files_directory': '${supportDirectory.path}/telegram_files',
        'database_encryption_key': _databaseEncryptionKey,
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': false,
        'api_id': _apiId,
        'api_hash': _apiHash,
        'system_language_code': 'fa',
        'device_model': 'Android',
        'system_version': '',
        'application_version': '1.2.0',
        'enable_storage_optimizer': true,
        'ignore_file_names': false,
      }, timeout: const Duration(seconds: 30));

      if (_lastAuthorizationState ==
          'authorizationStateWaitTdlibParameters') {
        _emit(const TelegramAuthStatus(
          TelegramAuthStage.initializing,
          message: 'تنظیمات پذیرفته شد؛ در حال بازیابی نشست ذخیره‌شده…',
        ));
        _scheduleAuthorizationProbe(
          expectedState: 'authorizationStateWaitTdlibParameters',
          failureMessage: 'تلگرام تنظیمات را پذیرفت، اما وضعیت ورود از مرحله راه‌اندازی عبور نکرد.',
        );
      }
    } catch (error) {
      _tdlibParametersSent = false;
      _emit(TelegramAuthStatus(
        TelegramAuthStage.error,
        message: 'ارسال تنظیمات اولیه به تلگرام ناموفق بود: $error',
      ));
    } finally {
      _sendingParameters = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String type,
    Map<String, dynamic> parameters, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (_disposed) {
      throw StateError('سرویس تلگرام بسته شده است.');
    }
    final commandPort = _workerCommandPort;
    if (commandPort == null) {
      throw StateError('اتصال تلگرام هنوز آماده نیست.');
    }

    final requestId = ++_nextRequestId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestId] = completer;

    try {
      commandPort.send({
        '@type': type,
        ...parameters,
        '@extra': requestId,
      });
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(requestId);
      throw TimeoutException('پاسخ تلگرام برای درخواست $type دریافت نشد.');
    } catch (_) {
      _pending.remove(requestId);
      rethrow;
    }
  }

  void _emit(TelegramAuthStatus value) {
    if (_disposed) return;
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  Future<void> _stopWorker() async {
    _authorizationProbeTimer?.cancel();
    _authorizationProbeTimer = null;

    final worker = _worker;
    final commandPort = _workerCommandPort;

    if (worker != null) {
      if (commandPort != null) {
        _workerStopping = true;
        _workerStopped ??= Completer<void>();
        try {
          commandPort.send({'__stop': true});
          await _workerStopped!.future.timeout(const Duration(seconds: 6));
        } on TimeoutException {
          worker.kill(priority: Isolate.immediate);
        } catch (_) {
          worker.kill(priority: Isolate.immediate);
        }
      } else {
        worker.kill(priority: Isolate.immediate);
      }
    }

    _workerCommandPort = null;
    await _workerSubscription?.cancel();
    _workerSubscription = null;
    _workerReceivePort?.close();
    _workerReceivePort = null;
    _worker = null;
    _workerReady = null;
    _workerStopped = null;
    _workerStopping = false;

    final closedError = StateError('اتصال تلگرام بسته شد.');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(closedError);
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopWorker();
    await _statusController.close();
  }
}

@pragma('vm:entry-point')
Future<void> _tdlibWorkerMain(Map<String, dynamic> bootstrap) async {
  final mainPort = bootstrap['mainPort'] as SendPort;
  ReceivePort? commandPort;
  var stopRequested = false;

  try {
    await TdPlugin.initialize();
    final clientId = TdPlugin.instance.tdCreateClientId();
    commandPort = ReceivePort();

    commandPort.listen((dynamic message) {
      if (message is! Map) return;
      final command = Map<String, dynamic>.from(message);

      if (command['__stop'] == true) {
        if (stopRequested) return;
        stopRequested = true;
        try {
          TdPlugin.instance.tdSend(
            clientId,
            jsonEncode({'@type': 'close'}),
          );
        } catch (error) {
          mainPort.send({
            'kind': 'workerError',
            'message': 'ارسال فرمان بستن TDLib ناموفق بود: $error',
          });
        }
        return;
      }

      try {
        TdPlugin.instance.tdSend(clientId, jsonEncode(command));
      } catch (error) {
        mainPort.send({
          'kind': 'workerError',
          'message': 'ارسال درخواست به TDLib ناموفق بود: $error',
        });
      }
    });

    mainPort.send({
      'kind': 'ready',
      'commandPort': commandPort.sendPort,
    });

    // Use one receive loop for this TDLib client. tdReceive is blocking for
    // at most one second, so command-port events are still serviced regularly.
    while (true) {
      final raw = TdPlugin.instance.tdReceive(1);
      if (raw == null || raw.isEmpty) continue;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;

      mainPort.send(decoded);

      final authorization = decoded['authorization_state'];
      final isClosed = decoded['@type'] == 'updateAuthorizationState' &&
          authorization is Map &&
          authorization['@type'] == 'authorizationStateClosed';
      if (stopRequested && isClosed) break;
    }

    commandPort.close();
    mainPort.send({'kind': 'stopped'});
  } catch (error, stackTrace) {
    mainPort.send({
      'kind': 'workerError',
      'message': '$error\n$stackTrace',
    });
  } finally {
    commandPort?.close();
  }
}
