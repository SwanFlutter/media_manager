import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_manager_method_channel.dart';
import 'src/models/media_item.dart';
import 'src/tools/media_type.dart';

export 'src/models/media_item.dart';
export 'src/tools/media_type.dart';

/// Abstract base class for all platform implementations.
///
/// All method channels, mock implementations and future FFI
/// implementations must extend this class.
abstract class MediaManagerPlatform extends PlatformInterface {
  MediaManagerPlatform() : super(token: _token);

  static final Object _token = Object();
  static MediaManagerPlatform _instance = MethodChannelMediaManager();

  static MediaManagerPlatform get instance => _instance;

  static set instance(MediaManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ─── Platform ────────────────────────────────────────────────────────────

  /// Returns a human-readable platform version string, e.g. "Android 14".
  Future<String?> getPlatformVersion() =>
      throw UnimplementedError('getPlatformVersion() not implemented.');

  // ─── Permissions ─────────────────────────────────────────────────────────

  /// Returns `true` if the app already has storage / media-read permission.
  Future<bool> hasStoragePermission() =>
      throw UnimplementedError('hasStoragePermission() not implemented.');

  /// Asks the user for storage / media-read permission.
  /// Returns `true` when at least one permission was granted.
  Future<bool> requestStoragePermission() =>
      throw UnimplementedError('requestStoragePermission() not implemented.');

  /// Opens the system "All Files Access" settings page (Android 11+).
  /// No-op on iOS / macOS.
  Future<void> openAllFilesAccessSettings() =>
      throw UnimplementedError('openAllFilesAccessSettings() not implemented.');

  // ─── Paginated media query ───────────────────────────────────────────────

  /// Returns a single page of [MediaItem]s sorted by date-modified descending.
  ///
  /// [type]       – filter by media category (image / video / audio / document / any).
  /// [extensions] – optional additional extension filter (e.g. `['pdf', 'docx']`).
  /// [page]       – zero-based page index.
  /// [pageSize]   – number of items per page (1–500, default 100).
  Future<List<MediaItem>> getMediaPage({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
    int page = 0,
    int pageSize = 100,
  }) => throw UnimplementedError('getMediaPage() not implemented.');

  /// Returns the total count of media items matching the given filter.
  Future<int> getMediaCount({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
  }) => throw UnimplementedError('getMediaCount() not implemented.');

  // ─── Thumbnails ───────────────────────────────────────────────────────────

  /// Generates (or returns a cached) thumbnail for any media file.
  ///
  /// Returns the **absolute path** to the cached JPEG on disk, or `null`
  /// on failure.  Callers should use `Image.file(File(path))` to display it.
  ///
  /// [uriOrPath]    – `content://` URI (Android) or absolute file path.
  /// [width]        – thumbnail width in logical pixels (default 256).
  /// [height]       – thumbnail height in logical pixels (default = width).
  /// [dateModified] – epoch-ms stamp used for cache invalidation.
  /// [kind]         – `"image"` | `"video"` | `"audio"`.
  Future<String?> getThumbnail({
    required String uriOrPath,
    int width = 256,
    int? height,
    int dateModified = 0,
    String kind = 'image',
  }) => throw UnimplementedError('getThumbnail() not implemented.');

  /// Clears the on-disk thumbnail cache.
  Future<void> clearThumbnailCache() =>
      throw UnimplementedError('clearThumbnailCache() not implemented.');

  // ─── Directory helpers ───────────────────────────────────────────────────

  /// Returns the list of well-known public directories
  /// (DCIM, Pictures, Movies, Music, Downloads, Documents, …).
  Future<List<Map<String, String>>> getDirectories() =>
      throw UnimplementedError('getDirectories() not implemented.');

  /// Returns a single page of directory entries under [path].
  ///
  /// Each entry map contains:
  /// `name`, `path`, `isDirectory`, `size`, `dateModified`, `extension`.
  Future<List<Map<String, dynamic>>> getDirectoryContents({
    required String path,
    int page = 0,
    int pageSize = 200,
  }) => throw UnimplementedError('getDirectoryContents() not implemented.');
}
