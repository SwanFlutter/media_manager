/// A single media file returned by [MediaManagerPlatform.getMediaPage].
class MediaItem {
  const MediaItem({
    required this.id,
    required this.uri,
    required this.name,
    required this.size,
    required this.dateModified,
    required this.mediaType,
    this.mimeType,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  /// MediaStore row ID (Android) or iCloud asset ID (iOS).
  final int id;

  /// `content://` URI on Android; absolute file path on iOS/macOS.
  final String uri;

  /// Display name (file name including extension).
  final String name;

  /// File size in bytes.
  final int size;

  /// Last-modified timestamp in **milliseconds** since epoch.
  final int dateModified;

  /// Raw platform media-type constant
  /// (MediaStore.Files.FileColumns.MEDIA_TYPE on Android).
  final int mediaType;

  /// MIME type string, e.g. `"image/jpeg"`. May be null.
  final String? mimeType;

  /// Image / video width in pixels (0 if unavailable).
  final int width;

  /// Image / video height in pixels (0 if unavailable).
  final int height;

  /// Audio / video duration in **milliseconds** (0 if unavailable).
  final int duration;

  // ─── Factory ────────────────────────────────────────────────────────────

  factory MediaItem.fromMap(Map<String, dynamic> m) => MediaItem(
    id: (m['id'] as num).toInt(),
    uri: m['uri'] as String,
    name: (m['name'] as String?) ?? '',
    size: (m['size'] as num?)?.toInt() ?? 0,
    dateModified: (m['dateModified'] as num?)?.toInt() ?? 0,
    mediaType: (m['mediaType'] as num?)?.toInt() ?? 0,
    mimeType: m['mimeType'] as String?,
    width: (m['width'] as num?)?.toInt() ?? 0,
    height: (m['height'] as num?)?.toInt() ?? 0,
    duration: (m['duration'] as num?)?.toInt() ?? 0,
  );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Convenience kind derived from [mimeType].
  /// Returns `"video"`, `"audio"`, or `"image"` (fallback).
  String get kind {
    final m = mimeType ?? '';
    if (m.startsWith('video')) return 'video';
    if (m.startsWith('audio')) return 'audio';
    return 'image';
  }

  @override
  String toString() => 'MediaItem(id: $id, name: $name, size: $size)';
}
