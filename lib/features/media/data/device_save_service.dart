import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Saves to Gallery for pictures/videos and to public Downloads for documents.
/// On Android 10+, MediaStore writes require no storage permission.
/// Android 9 and below request WRITE_EXTERNAL_STORAGE only if needed.
abstract final class DeviceSaveService {
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'};
  static const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm', '3gp'};

  static Future<String> save({
    String? localPath,
    String? url,
    String? fileName,
    String? mimeType,
  }) async {
    if ((localPath == null || localPath.isEmpty) &&
        (url == null || url.isEmpty)) {
      throw ArgumentError('No media source was provided.');
    }

    final fromUrl = Uri.tryParse(url ?? '');
    if (localPath == null &&
        (fromUrl == null ||
            (fromUrl.scheme != 'https' && fromUrl.scheme != 'http'))) {
      throw ArgumentError('Unsupported media URL.');
    }

    final guessName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : (fromUrl?.pathSegments.isNotEmpty == true
            ? fromUrl!.pathSegments.last
            : (localPath?.split(Platform.pathSeparator).last ?? 'download'));
    var safeName = guessName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      safeName = 'download';
    }
    final extension = safeName.contains('.')
        ? safeName.split('.').last.toLowerCase()
        : _extensionFromMime(mimeType);
    final rootName = safeName.contains('.')
        ? safeName.substring(0, safeName.lastIndexOf('.'))
        : safeName;
    final isMedia = _imageExtensions.contains(extension) ||
        _videoExtensions.contains(extension);
    final targetMime = mimeType?.isNotEmpty == true
        ? mimeType!
        : _mimeForExtension(extension);

    String path;
    String? temporaryPath;
    if (localPath != null && localPath.isNotEmpty) {
      path = localPath;
      if (!await File(path).exists()) {
        throw const FileSystemException('Source file is missing.');
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/save_${DateTime.now().microsecondsSinceEpoch}.$extension',
      ).create(recursive: true);
      temporaryPath = file.path;
      path = file.path;
      try {
        await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 2),
        )).download(url!, path, deleteOnError: true);
      } catch (_) {
        await file.delete().catchError((Object _) => file);
        rethrow;
      }
    }

    try {
      Future<String?> action() => isMedia
          ? FileSaver.instance.saveToGallery(
              name: rootName,
              filePath: path,
              fileExtension: extension,
              mimeType: MimeType.custom,
              customMimeType: targetMime,
              album: 'TelePulse',
            )
          : FileSaver.instance.saveToDownloads(
              name: rootName,
              filePath: path,
              fileExtension: extension,
              mimeType: MimeType.custom,
              customMimeType: targetMime,
              subfolder: 'TelePulse',
            );

      String? result;
      try {
        result = await action();
      } on PlatformException catch (error) {
        if (!Platform.isAndroid ||
            !error.code.toLowerCase().contains('permission')) {
          rethrow;
        }
        // Android 9 and earlier only. Modern Android uses scoped storage.
        final permission = await Permission.storage.request();
        if (!permission.isGranted) {
          throw StateError('Storage permission was denied.');
        }
        result = await action();
      }
      return result ?? (isMedia ? 'Gallery' : 'Downloads/TelePulse');
    } finally {
      if (temporaryPath != null) {
        final file = File(temporaryPath);
        if (await file.exists()) await file.delete();
      }
    }
  }

  static String _extensionFromMime(String? type) {
    final value = type?.toLowerCase() ?? '';
    if (value.contains('image/jpeg')) return 'jpg';
    if (value.contains('image/png')) return 'png';
    if (value.contains('video/mp4')) return 'mp4';
    if (value.contains('pdf')) return 'pdf';
    if (value.contains('wordprocessingml')) return 'docx';
    if (value.contains('spreadsheetml')) return 'xlsx';
    return 'bin';
  }

  static String _mimeForExtension(String ext) => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'mp4' || 'm4v' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    '3gp' => 'video/3gpp',
    'pdf' => 'application/pdf',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt' => 'text/plain',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    _ => 'application/octet-stream',
  };
}
