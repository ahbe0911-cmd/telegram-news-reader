import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests media-library read access only when a user explicitly chooses
/// to browse existing media. Downloads written to the app's private directory
/// do not require READ_MEDIA permissions on Android 10+.
final class AndroidMediaPermissionService {
  const AndroidMediaPermissionService();

  Future<bool> requestReadAccess({
    bool images = true,
    bool videos = true,
  }) async {
    if (!Platform.isAndroid) return true;

    final requestedPermissions = <Permission>[
      if (images) Permission.photos,
      if (videos) Permission.videos,
    ];

    if (requestedPermissions.isEmpty) return true;

    final statuses = await requestedPermissions.request();
    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  Future<bool> requestLegacyStorageWriteAccess() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
