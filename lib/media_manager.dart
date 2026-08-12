/// media_manager — public API
///
/// Import this file to get everything you need:
/// ```dart
/// import 'package:media_manager/media_manager.dart';
/// ```
library;

import 'media_manager_platform_interface.dart';

export 'media_manager_platform_interface.dart' show MediaManagerPlatform;
export 'src/models/media_item.dart';
export 'src/tools/media_type.dart';

/// Top-level entry point for all media-manager operations.
///
/// All methods delegate directly to [MediaManagerPlatform.instance] so the
/// plugin works correctly on every platform without additional configuration.
class MediaManager {
  const MediaManager();

  // ─── Platform ─────────────────────────────────────────────────────────────

  /// Returns a human-readable platform version string.
  ///
  /// Example result: `"Android 14"`, `"iOS 17.4"`, `"macOS 14.5"`.
  Future<String?> getPlatformVersion() =>
      MediaManagerPlatform.instance.getPlatformVersion();

  // ─── Permissions ──────────────────────────────────────────────────────────

  /// Returns `true` when the app already holds the required storage /
  /// media-read permission — no dialog is shown.
  Future<bool> hasStoragePermission() =>
      MediaManagerPlatform.instance.hasStoragePermission();

  /// Prompts the user for storage / media-read permission.
  ///
  /// Returns `true` when at least one relevant permission was granted.
  /// On iOS the Photos library authorisation dialog is shown; on macOS a
  /// sandbox-compatible open-panel is presented instead.
  Future<bool> requestStoragePermission() =>
      MediaManagerPlatform.instance.requestStoragePermission();

  /// Opens the system "Manage All Files" settings page (Android 11+).
  ///
  /// Required when [hasStoragePermission] returns `false` on Android 11+
  /// and the app needs access to non-media files.  No-op on iOS / macOS.
  Future<void> openAllFilesAccessSettings() =>
      MediaManagerPlatform.instance.openAllFilesAccessSettings();

  // ─── Paginated media query ─────────────────────────────────────────────────

  /// Returns one page of [MediaItem]s sorted newest-first.
  ///
  /// Pagination is done at the database level (SQLite LIMIT/OFFSET on Android,
  /// PHFetchOptions on iOS) so only the requested rows are loaded into memory.
  ///
  /// ```dart
  /// // First page of images
  /// final items = await MediaManager().getMediaPage(
  ///   type: MediaType.image,
  ///   page: 0,
  ///   pageSize: 80,
  /// );
  ///
  /// // Custom extension filter (document type)
  /// final pdfs = await MediaManager().getMediaPage(
  ///   type: MediaType.document,
  ///   extensions: ['pdf'],
  ///   page: 0,
  /// );
  /// ```
  Future<List<MediaItem>> getMediaPage({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
    int page = 0,
    int pageSize = 100,
  }) => MediaManagerPlatform.instance.getMediaPage(
    type: type,
    extensions: extensions,
    page: page,
    pageSize: pageSize,
  );

  /// Returns the total number of media items matching the filter.
  ///
  /// Useful for computing the number of pages before the first query:
  /// ```dart
  /// final total  = await MediaManager().getMediaCount(type: MediaType.image);
  /// final pages  = (total / pageSize).ceil();
  /// ```
  Future<int> getMediaCount({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
  }) => MediaManagerPlatform.instance.getMediaCount(
    type: type,
    extensions: extensions,
  );

  // ─── Thumbnails ────────────────────────────────────────────────────────────

  /// Generates (or returns a cached) thumbnail for a media file.
  ///
  /// Returns the **absolute path** to the on-disk JPEG so callers can use
  /// `Image.file(File(path!))` — no large byte arrays cross the channel.
  ///
  /// The cache is keyed by `(uriOrPath, width, height, dateModified)` so
  /// thumbnails are automatically re-generated when the source file changes.
  ///
  /// ```dart
  /// final path = await MediaManager().getThumbnail(
  ///   uriOrPath: item.uri,
  ///   width: 200,
  ///   dateModified: item.dateModified,
  ///   kind: item.kind,          // "image" | "video" | "audio"
  /// );
  /// if (path != null) {
  ///   return Image.file(File(path), fit: BoxFit.cover);
  /// }
  /// ```
  Future<String?> getThumbnail({
    required String uriOrPath,
    int width = 256,
    int? height,
    int dateModified = 0,
    String kind = 'image',
  }) => MediaManagerPlatform.instance.getThumbnail(
    uriOrPath: uriOrPath,
    width: width,
    height: height,
    dateModified: dateModified,
    kind: kind,
  );

  /// Deletes all cached thumbnail files from disk.
  ///
  /// Call this when the user explicitly requests a cache clear or when
  /// free-space is low.
  Future<void> clearThumbnailCache() =>
      MediaManagerPlatform.instance.clearThumbnailCache();

  // ─── Directory helpers ─────────────────────────────────────────────────────

  /// Returns well-known public directories on the device.
  ///
  /// Each entry is a `Map<String, String>` with keys `"name"` and `"path"`.
  /// Android returns DCIM, Pictures, Movies, Music, Downloads, Documents and
  /// Internal Storage root.  iOS/macOS return the app sandbox directories.
  ///
  /// ```dart
  /// final dirs = await MediaManager().getDirectories();
  /// for (final d in dirs) {
  ///   print('${d['name']}: ${d['path']}');
  /// }
  /// ```
  Future<List<Map<String, String>>> getDirectories() =>
      MediaManagerPlatform.instance.getDirectories();

  /// Returns a single page of entries inside [path].
  ///
  /// Entries are sorted: directories first (alphabetical), then files
  /// (alphabetical).  Each map contains:
  /// - `name`         – file / folder name
  /// - `path`         – absolute path
  /// - `isDirectory`  – bool
  /// - `size`         – bytes (0 for directories)
  /// - `dateModified` – epoch ms
  /// - `extension`    – lowercase extension, empty for directories
  ///
  /// ```dart
  /// final entries = await MediaManager().getDirectoryContents(
  ///   path: '/storage/emulated/0/DCIM',
  ///   page: 0,
  ///   pageSize: 200,
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> getDirectoryContents({
    required String path,
    int page = 0,
    int pageSize = 200,
  }) => MediaManagerPlatform.instance.getDirectoryContents(
    path: path,
    page: page,
    pageSize: pageSize,
  );
}
