# media_manager

[![pub package](https://img.shields.io/pub/v/media_manager.svg)](https://pub.dev/packages/media_manager)
[![Pub Points](https://img.shields.io/pub/points/media_manager)](https://pub.dev/packages/media_manager/score)
[![Popularity](https://img.shields.io/pub/popularity/media_manager)](https://pub.dev/packages/media_manager/score)
[![Pub Likes](https://img.shields.io/pub/likes/media_manager)](https://pub.dev/packages/media_manager/score)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-blue.svg)](https://github.com/SwanFlutter/media_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.3%2B-02569B.svg?logo=flutter)](https://flutter.dev)
[![GitHub issues](https://img.shields.io/github/issues/SwanFlutter/media_manager)](https://github.com/SwanFlutter/media_manager/issues)
[![GitHub forks](https://img.shields.io/github/forks/SwanFlutter/media_manager)](https://github.com/SwanFlutter/media_manager/network/members)

A Flutter plugin for browsing media files on Android, iOS, and macOS.  
Provides paginated queries, on-disk thumbnail caching, directory browsing, and storage permission handling — all with zero large byte-array transfers over the method channel.

<img width="386" height="869" alt="media_manager screenshot" src="https://github.com/user-attachments/assets/bdec60df-446c-4b70-9b2b-66047fcd92bf" />

---

## Platform Support

| Platform | Min Version | Status |
|----------|-------------|--------|
| **Android** | API 24 (7.0) | ✅ Fully supported |
| **iOS** | 13.0 | ✅ Fully supported |
| **macOS** | 10.11 (El Capitan) | ✅ Fully supported |
| **Windows / Linux / Web** | — | ❌ Not supported |

---

## Installation

```yaml
dependencies:
  media_manager: ^1.0.1
```

```bash
flutter pub get
```

### Android — one-time setup

Add `android:requestLegacyExternalStorage="true"` to `<application>` in your `AndroidManifest.xml` to ensure access on Android 9 and below:

```xml
<application
    android:label="my_app"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:requestLegacyExternalStorage="true">
```

All required permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`) are declared by the plugin — no manual additions needed.

### iOS / macOS setup

No additional setup required. The plugin handles `NSPhotoLibraryUsageDescription` and sandbox entitlements internally.

---

## Quick start

```dart
import 'package:media_manager/media_manager.dart';

final mm = MediaManager();

// 1. Request permission
final granted = await mm.requestStoragePermission();

// 2. Count items
final total = await mm.getMediaCount(type: MediaType.image);

// 3. Load first page
final items = await mm.getMediaPage(
  type: MediaType.image,
  page: 0,
  pageSize: 60,
);

// 4. Generate thumbnail (returns an absolute path to a cached JPEG)
final thumbPath = await mm.getThumbnail(
  uriOrPath: items.first.uri,
  width: 200,
  dateModified: items.first.dateModified,
  kind: items.first.kind, // "image" | "video" | "audio"
);

// 5. Display
if (thumbPath != null) {
  Image.file(File(thumbPath), fit: BoxFit.cover);
}
```

---

## API Reference

### Permissions

| Method | Returns | Description |
|--------|---------|-------------|
| `hasStoragePermission()` | `Future<bool>` | Check without showing a dialog |
| `requestStoragePermission()` | `Future<bool>` | Show system permission dialog |
| `openAllFilesAccessSettings()` | `Future<void>` | Open MANAGE_ALL_FILES page (Android 11+, no-op elsewhere) |

### Paginated media queries

```dart
// Total count — use before first query to compute page count
final total = await mm.getMediaCount(
  type: MediaType.image,   // image | video | audio | document | any
  extensions: [],          // optional extension filter, e.g. ['pdf', 'docx']
);
final pageCount = (total / pageSize).ceil();

// One page of MediaItem objects, sorted newest-first
final page = await mm.getMediaPage(
  type: MediaType.video,
  page: 2,
  pageSize: 60,
);
```

`MediaItem` fields: `id`, `uri`, `name`, `size`, `dateModified`, `mediaType`, `mimeType`, `width`, `height`, `duration`, `kind`.

### Thumbnails

```dart
// Returns absolute path to a cached JPEG on disk, or null on failure.
// Cache key = md5(uri + width + height + dateModified) — auto-invalidates on file change.
final path = await mm.getThumbnail(
  uriOrPath: item.uri,
  width: 256,           // default 256
  height: 256,          // defaults to width
  dateModified: item.dateModified,
  kind: item.kind,      // "image" | "video" | "audio"
);

// Clear all cached JPEG files from disk
await mm.clearThumbnailCache();
```

### Directory helpers

```dart
// Well-known public directories (DCIM, Pictures, Movies, Music, Downloads…)
final dirs = await mm.getDirectories();
// returns List<Map<String, String>> with keys "name" and "path"

// Paginated directory listing — dirs first (alpha), then files (alpha)
final entries = await mm.getDirectoryContents(
  path: '/storage/emulated/0/DCIM',
  page: 0,
  pageSize: 200,
);
// Each entry: name, path, isDirectory, size (bytes), dateModified (ms), extension
```

### Platform info

```dart
final version = await mm.getPlatformVersion();
// e.g. "Android 14", "iOS 17.4", "macOS 14.5"
```

---

## MediaType values

| Value | Matches |
|-------|---------|
| `MediaType.image` | jpg, jpeg, png, gif, bmp, webp, heic, heif, tiff … |
| `MediaType.video` | mp4, mov, mkv, avi, webm, 3gp … |
| `MediaType.audio` | mp3, m4a, flac, ogg, wav, aac … |
| `MediaType.document` | pdf, doc/x, xls/x, ppt/x, txt, csv, html, zip, rar … |
| `MediaType.any` | All files (use with `extensions` for custom types) |

---

## Custom extension search

```dart
// Find Dart / Kotlin / Swift source files
final code = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['dart', 'kt', 'swift', 'py', 'js'],
  page: 0,
);

// Find database files
final dbs = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['db', 'sqlite', 'sqlite3'],
  page: 0,
);
```

---

## Thumbnail widget example

```dart
class ThumbnailTile extends StatefulWidget {
  final MediaItem item;
  final MediaManager mm;
  const ThumbnailTile({super.key, required this.item, required this.mm});

  @override
  State<ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<ThumbnailTile> {
  String? _path;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = await widget.mm.getThumbnail(
      uriOrPath: widget.item.uri,
      width: 200,
      dateModified: widget.item.dateModified,
      kind: widget.item.kind,
    );
    if (mounted && p != null) setState(() => _path = p);
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(File(_path!), fit: BoxFit.cover),
      );
    }
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
```

---

## Error codes

| Code | Thrown by | Meaning |
|------|-----------|---------|
| `QUERY_ERROR` | `getMediaPage`, `getMediaCount` | MediaStore / filesystem query failed |
| `FILE_ACCESS_ERROR` | `getDirectoryContents` | Cannot read directory |
| `INVALID_ARGUMENT` | `getThumbnail` | `uri`/`path` argument missing |
| `NO_ACTIVITY` | `requestStoragePermission` | Android activity not attached |

---

## Contributors

<p align="left">
  <a href="https://github.com/SwanFlutter">
    <img src="https://contrib.rocks/image?repo=SwanFlutter/SwanFlutter" alt="SwanFlutter" style="vertical-align:middle;" />
    <span style="vertical-align:middle"> SwanFlutter</span>
  </a>
</p>

<a href="https://github.com/rezash76">
  <img src="https://avatars.githubusercontent.com/u/38264846?s=64&v=4" alt="rezash76" height="32" width="32" style="border-radius:50%;vertical-align:middle;" />
  <strong style="vertical-align:middle"> rezash76</strong> — رضا شریفی
</a>

---

## License

MIT — see the [LICENSE](LICENSE) file for details.
