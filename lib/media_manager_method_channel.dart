import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_manager_platform_interface.dart';

/// Default [MediaManagerPlatform] implementation via [MethodChannel].
class MethodChannelMediaManager extends MediaManagerPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('media_manager');

  // ─── Platform ────────────────────────────────────────────────────────────

  @override
  Future<String?> getPlatformVersion() =>
      methodChannel.invokeMethod<String>('getPlatformVersion');

  // ─── Permissions ─────────────────────────────────────────────────────────

  @override
  Future<bool> hasStoragePermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasStoragePermission',
    );
    return result ?? false;
  }

  @override
  Future<bool> requestStoragePermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'requestStoragePermission',
    );
    return result ?? false;
  }

  @override
  Future<void> openAllFilesAccessSettings() =>
      methodChannel.invokeMethod<void>('openAllFilesAccessSettings');

  // ─── Paginated media query ───────────────────────────────────────────────

  @override
  Future<List<MediaItem>> getMediaPage({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
    int page = 0,
    int pageSize = 100,
  }) async {
    final raw = await methodChannel.invokeMethod<List<dynamic>>(
      'getMediaPage',
      {
        'type': type.name,
        'extensions': extensions,
        'page': page,
        'pageSize': pageSize,
      },
    );
    if (raw == null) return const [];
    return raw
        .map((e) => MediaItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  @override
  Future<int> getMediaCount({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
  }) async {
    final result = await methodChannel.invokeMethod<int>('getMediaCount', {
      'type': type.name,
      'extensions': extensions,
    });
    return result ?? 0;
  }

  // ─── Thumbnails ───────────────────────────────────────────────────────────

  @override
  Future<String?> getThumbnail({
    required String uriOrPath,
    int width = 256,
    int? height,
    int dateModified = 0,
    String kind = 'image',
  }) async {
    final result = await methodChannel.invokeMethod<String>('getThumbnail', {
      'uri': uriOrPath,
      'width': width,
      'height': height ?? width,
      'dateModified': dateModified,
      'kind': kind,
    });
    return result;
  }

  @override
  Future<void> clearThumbnailCache() =>
      methodChannel.invokeMethod<void>('clearThumbnailCache');

  // ─── Directory helpers ───────────────────────────────────────────────────

  @override
  Future<List<Map<String, String>>> getDirectories() async {
    final raw = await methodChannel.invokeMethod<List<dynamic>>(
      'getDirectories',
    );
    if (raw == null) return const [];
    return raw
        .map((e) => Map<String, String>.from(e as Map))
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> getDirectoryContents({
    required String path,
    int page = 0,
    int pageSize = 200,
  }) async {
    final raw = await methodChannel.invokeMethod<List<dynamic>>(
      'getDirectoryContents',
      {'path': path, 'page': page, 'pageSize': pageSize},
    );
    if (raw == null) return const [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }
}
