import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../feed/domain/entities/post.dart';

final class MediaDownloadService {
  const MediaDownloadService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<String> downloadAttachment(
    PostAttachment attachment, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final mediaDirectory = Directory('\${appDirectory.path}/offline_media');
    await mediaDirectory.create(recursive: true);

    final fileName = _safeFileName(attachment);
    final target = File(
      '\${mediaDirectory.path}/\${_stableHash(attachment.url)}_\$fileName',
    );

    if (await target.exists() && await target.length() > 0) {
      return target.path;
    }

    await _dio.download(
      attachment.url,
      target.path,
      onReceiveProgress: onReceiveProgress,
      deleteOnError: true,
    );

    if (!await target.exists() || await target.length() == 0) {
      throw const FileSystemException('فایل دانلودشده معتبر نیست.');
    }

    return target.path;
  }

  String _safeFileName(PostAttachment attachment) {
    final original = attachment.fileName?.trim();
    final candidate = original == null || original.isEmpty
        ? 'media'
        : Uri.decodeComponent(original);

    final safe = candidate.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'media' : safe;
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
