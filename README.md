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
Provides paginated queries, on-disk thumbnail caching, directory browsing, archive discovery (zip / rar / 7z / apk …) and storage permission handling — all with zero large byte-array transfers over the method channel.

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

## Features

- **Paginated media queries** — images, videos, audio, documents, archives, or any custom extension. Pagination runs at the SQLite / PHFetchOptions level so only the requested page is loaded into memory.
- **Archive discovery** — zip, rar, 7z, tar, gz, apk, epub and 20+ more. Merges a file-system scan with the MediaStore result so files in `Download/` that were never indexed still appear.
- **On-disk thumbnail cache** — thumbnails are saved as JPEG files; only the path crosses the method channel. Cache key is `md5(uri + width + height + dateModified)`, so stale thumbnails are automatically regenerated.
- **Directory browser** — well-known public folders and paginated directory listing.
- **Permission helpers** — runtime storage permission + "All files access" (MANAGE_EXTERNAL_STORAGE) detection for Android 11+.

---

## Installation

```yaml
dependencies:
  media_manager: ^1.0.3
```

```bash
flutter pub get
```

### Android setup

Add `android:requestLegacyExternalStorage="true"` to `<application>` in your `AndroidManifest.xml` (required for Android 9 and below):

```xml
<application
    android:label="my_app"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:requestLegacyExternalStorage="true">
```

To show archives / documents from folders like `Download/` on **Android 11+**, you also need to declare `MANAGE_EXTERNAL_STORAGE` in your app manifest and guide the user to grant it:

```xml
<uses-permission
    android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

All media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_MEDIA_VISUAL_USER_SELECTED`, `READ_EXTERNAL_STORAGE`) are declared by the plugin automatically.

### iOS / macOS setup

No additional setup required.

---

## Quick start

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

final mm = MediaManager();

Future<void> quickStart() async {
  // 1. Request permission
  final granted = await mm.requestStoragePermission();
  if (!granted) return;

  // 2. Count total images
  final total = await mm.getMediaCount(type: MediaType.image);

  // 3. Load first page (60 items)
  final items = await mm.getMediaPage(
    type: MediaType.image,
    page: 0,
    pageSize: 60,
  );

  // 4. Generate a thumbnail (returns absolute path to a cached JPEG)
  if (items.isNotEmpty) {
    final thumbPath = await mm.getThumbnail(
      uriOrPath: items.first.uri,
      width: 200,
      dateModified: items.first.dateModified,
      kind: items.first.kind, // "image" | "video" | "audio"
    );
    // Display: Image.file(File(thumbPath!))
  }
}
```

---

## Complete API Reference

### 1. `getPlatformVersion()`

Returns a human-readable string identifying the OS and version.

```dart
final String? version = await mm.getPlatformVersion();
// "Android 14"  |  "iOS 17.4"  |  "macOS 14.5"
print('Running on: $version');
```

---

### 2. `hasStoragePermission()`

Checks whether the required media-read permission is already granted, **without** showing a dialog.

```dart
final bool already = await mm.hasStoragePermission();
if (already) {
  // safe to query media
} else {
  // call requestStoragePermission() first
}
```

---

### 3. `requestStoragePermission()`

Shows the system permission dialog. Returns `true` when at least one media permission was granted.

```dart
final bool granted = await mm.requestStoragePermission();
if (!granted) {
  // user denied — show rationale or disable media features
  return;
}
// proceed with media queries
```

---

### 4. `hasAllFilesAccess()`

Reports whether the "All files access" special setting (MANAGE_EXTERNAL_STORAGE) is active.  
Required on **Android 11+** to scan `Download/`, `Documents/` and other folders for archives and custom file types.  
Always returns `true` on Android ≤10, iOS and macOS.

```dart
final bool fullAccess = await mm.hasAllFilesAccess();
if (!fullAccess) {
  // Optionally prompt the user before opening settings
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enable All Files Access'),
      content: const Text(
        'To show ZIP, RAR, APK and documents from Downloads, '
        'the app needs "All files access".',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await mm.openAllFilesAccessSettings();
  }
}
```

---

### 5. `openAllFilesAccessSettings()`

Navigates to the system "All files access" page for the app (Android 11+ only). No-op on other platforms.

```dart
// Call after hasAllFilesAccess() returns false
await mm.openAllFilesAccessSettings();
// The user grants the setting in System settings, then returns to the app
```

---

### 6. `getMediaCount()`

Returns the total number of items matching the filter. Use it to compute page count before loading.

```dart
// Count all images
final int imageCount = await mm.getMediaCount(type: MediaType.image);

// Count videos
final int videoCount = await mm.getMediaCount(type: MediaType.video);

// Count PDF files only
final int pdfCount = await mm.getMediaCount(
  type: MediaType.document,
  extensions: ['pdf'],
);

// Count archive files
final int archiveCount = await mm.getArchiveCount();

// Compute page count for a paginated list
const pageSize = 60;
final int pages = (imageCount / pageSize).ceil();
print('$imageCount images across $pages pages');
```

---

### 7. `getMediaPage()`

Returns one page of `MediaItem` objects sorted newest-first. Pagination is done at the database/filesystem level.

```dart
// Images — page 0
final List<MediaItem> images = await mm.getMediaPage(
  type: MediaType.image,
  page: 0,
  pageSize: 60,
);

// Videos — page 1
final List<MediaItem> videos = await mm.getMediaPage(
  type: MediaType.video,
  page: 1,
  pageSize: 30,
);

// Audio files
final List<MediaItem> audio = await mm.getMediaPage(
  type: MediaType.audio,
  page: 0,
  pageSize: 50,
);

// Documents — PDF only
final List<MediaItem> pdfs = await mm.getMediaPage(
  type: MediaType.document,
  extensions: ['pdf'],
  page: 0,
  pageSize: 40,
);

// All document types (PDF, Word, Excel, TXT, …)
final List<MediaItem> docs = await mm.getMediaPage(
  type: MediaType.document,
  page: 0,
  pageSize: 50,
);

// Use the items
for (final item in images) {
  print('${item.name}  ${item.size} bytes  ${item.mimeType}');
  print('  uri: ${item.uri}');
  print('  ${item.width}x${item.height}  modified: ${item.dateModified}');
}
```

**`MediaItem` fields**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `int` | MediaStore row ID (Android) or asset ID (iOS) |
| `uri` | `String` | `content://` URI (Android) or absolute path (iOS/macOS) |
| `name` | `String` | Display name including extension |
| `size` | `int` | File size in bytes |
| `dateModified` | `int` | Last-modified timestamp in **ms** since epoch |
| `mediaType` | `int` | Raw platform media-type constant |
| `mimeType` | `String?` | MIME type, e.g. `"image/jpeg"` |
| `width` | `int` | Image/video width in px (0 if unavailable) |
| `height` | `int` | Image/video height in px (0 if unavailable) |
| `duration` | `int` | Audio/video duration in **ms** (0 if unavailable) |
| `path` | `String?` | Absolute file-system path when available |
| `kind` | `String` | Derived: `"image"` \| `"video"` \| `"audio"` |

---

### 8. `getArchiveFiles()`

Convenience method for `MediaType.archive`. Merges a MediaStore query with a file-system walk so that zip/rar files sitting in `Download/` that were never indexed by the media scanner are still returned.

```dart
// All archive types (zip, rar, 7z, tar, gz, apk, epub, …)
final List<MediaItem> archives = await mm.getArchiveFiles(
  page: 0,
  pageSize: 50,
);

// ZIP files only
final List<MediaItem> zips = await mm.getArchiveFiles(
  extensions: ['zip'],
  page: 0,
  pageSize: 50,
);

// APK files
final List<MediaItem> apks = await mm.getArchiveFiles(
  extensions: ['apk'],
  page: 0,
);

for (final a in archives) {
  final ext = a.name.split('.').last.toUpperCase();
  print('[$ext] ${a.name}  ${(a.size / 1024).toStringAsFixed(1)} KB');
}
```

---

### 9. `getArchiveCount()`

Total number of archive files on the device.

```dart
final int total = await mm.getArchiveCount();
print('Found $total archive files');

// Count only ZIP files
final int zipCount = await mm.getArchiveCount(extensions: ['zip']);
```

---

### 10. `getThumbnail()`

Generates (or returns a cached) thumbnail for any media file. Returns the **absolute path** to a JPEG on disk — no byte arrays cross the channel.

```dart
// Image thumbnail
final String? imgPath = await mm.getThumbnail(
  uriOrPath: item.uri,
  width: 200,           // optional, default 256
  height: 200,          // optional, defaults to width
  dateModified: item.dateModified,
  kind: 'image',
);

// Video frame thumbnail
final String? vidPath = await mm.getThumbnail(
  uriOrPath: videoItem.uri,
  width: 320,
  dateModified: videoItem.dateModified,
  kind: 'video',
);

// Audio album-art thumbnail
final String? artPath = await mm.getThumbnail(
  uriOrPath: audioItem.uri,
  width: 128,
  dateModified: audioItem.dateModified,
  kind: 'audio',
);

// Display any of the above
if (imgPath != null) {
  Image.file(
    File(imgPath),
    fit: BoxFit.cover,
    cacheWidth: 200, // reduces Flutter decode cost
  );
}
```

---

### 11. `clearThumbnailCache()`

Deletes every cached thumbnail JPEG from disk. Call when the user requests a cache clear or when free space is low.

```dart
await mm.clearThumbnailCache();
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Thumbnail cache cleared')),
);
```

---

### 12. `getDirectories()`

Returns well-known public folders as a `List<Map<String, String>>` with keys `"name"` and `"path"`.

```dart
final List<Map<String, String>> dirs = await mm.getDirectories();

// Android returns: Internal Storage, DCIM, Pictures, Movies, Music,
//                  Downloads, Documents
// iOS/macOS return app sandbox directories

for (final d in dirs) {
  print('📁 ${d['name']}: ${d['path']}');
}

// Navigate into a folder
final dcim = dirs.firstWhere((d) => d['name'] == 'DCIM');
final contents = await mm.getDirectoryContents(path: dcim['path']!);
```

---

### 13. `getDirectoryContents()`

Returns a paginated listing of one directory. Sorted: folders first (alphabetical), then files (alphabetical).

```dart
// List the Downloads folder, page 0
final List<Map<String, dynamic>> entries = await mm.getDirectoryContents(
  path: '/storage/emulated/0/Download',
  page: 0,
  pageSize: 200,
);

for (final e in entries) {
  final bool isDir = e['isDirectory'] as bool;
  final String name = e['name'] as String;
  final int size = e['size'] as int;
  final String ext = e['extension'] as String;

  if (isDir) {
    print('📁 $name/');
  } else {
    final kb = (size / 1024).toStringAsFixed(1);
    print('📄 $name  [$ext]  $kb KB');
  }
}

// Load the next page
final page2 = await mm.getDirectoryContents(
  path: '/storage/emulated/0/Download',
  page: 1,
  pageSize: 200,
);
```

**Entry map keys**

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | File or folder name |
| `path` | `String` | Absolute path |
| `isDirectory` | `bool` | `true` for directories |
| `size` | `int` | Bytes (0 for directories) |
| `dateModified` | `int` | Epoch ms |
| `extension` | `String` | Lowercase extension, empty for directories |

---

## `MediaType` values

| Value | Covers |
|-------|--------|
| `MediaType.image` | jpg, jpeg, png, gif, bmp, webp, heic, heif, tiff … |
| `MediaType.video` | mp4, mov, mkv, avi, webm, 3gp, m4v … |
| `MediaType.audio` | mp3, m4a, flac, ogg, wav, aac, opus … |
| `MediaType.document` | pdf, doc/x, xls/x, ppt/x, txt, csv, html, epub, zip, apk … |
| `MediaType.archive` | zip, rar, 7z, tar, gz, tgz, bz2, xz, lzma, zst, apk, aab, deb, rpm, jar, cbz, epub … |
| `MediaType.any` | All files — combine with `extensions` for custom types |

---

## Custom extension search

Use `MediaType.any` with an `extensions` list to find any file type that MediaStore knows about, plus a file-system scan for formats it may have missed.

```dart
// Source code files
final List<MediaItem> code = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['dart', 'kt', 'swift', 'py', 'js', 'ts'],
  page: 0,
);

// Database files
final List<MediaItem> dbs = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['db', 'sqlite', 'sqlite3'],
  page: 0,
);

// Configuration files
final List<MediaItem> configs = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['json', 'yaml', 'yml', 'toml', 'ini', 'cfg'],
  page: 0,
);

// APK installer files
final List<MediaItem> apks = await mm.getMediaPage(
  type: MediaType.any,
  extensions: ['apk'],
  page: 0,
);
```

---

## Infinite-scroll list example

A complete paginated list that auto-loads the next page when the user scrolls near the bottom.

```dart
class MediaListPage extends StatefulWidget {
  const MediaListPage({super.key});
  @override
  State<MediaListPage> createState() => _MediaListPageState();
}

class _MediaListPageState extends State<MediaListPage> {
  static const _pageSize = 60;
  final _mm = MediaManager();
  final _items = <MediaItem>[];
  final _scroll = ScrollController();
  int _page = 0;
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading || _items.length >= _total && _total > 0) return;
    setState(() => _loading = true);
    try {
      if (_total == 0) {
        _total = await _mm.getMediaCount(type: MediaType.image);
      }
      final page = await _mm.getMediaPage(
        type: MediaType.image,
        page: _page++,
        pageSize: _pageSize,
      );
      setState(() => _items.addAll(page));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Images ($_total)')),
      body: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return _ThumbnailTile(item: _items[i], mm: _mm);
        },
      ),
    );
  }
}
```

---

## Thumbnail widget example

```dart
class _ThumbnailTile extends StatefulWidget {
  final MediaItem item;
  final MediaManager mm;
  const _ThumbnailTile({required this.item, required this.mm});
  @override
  State<_ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<_ThumbnailTile> {
  String? _path;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final p = await widget.mm.getThumbnail(
        uriOrPath: widget.item.uri,
        width: 200,
        dateModified: widget.item.dateModified,
        kind: widget.item.kind,
      );
      if (mounted) setState(() => _path = p);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(_path!),
          fit: BoxFit.cover,
          cacheWidth: 200,
          errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image),
        ),
      );
    }
    return _placeholder(_error ? Icons.broken_image : Icons.image);
  }

  Widget _placeholder(IconData icon) => Container(
    color: Colors.grey[200],
    child: Icon(icon, color: Colors.grey[400]),
  );
}
```

---

## Permission setup example

Full permission flow including "All files access" for archives on Android 11+.

```dart
class _MyAppState extends State<MyApp> {
  final _mm = MediaManager();

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    // Step 1 — basic media permission
    final granted = await _mm.requestStoragePermission();
    if (!granted) return;

    // Step 2 — all-files access for archives / documents on Android 11+
    final fullAccess = await _mm.hasAllFilesAccess();
    if (!fullAccess && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('All Files Access'),
          content: const Text(
            'Grant "All files access" to browse ZIP, RAR and APK files '
            'from your Downloads folder.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (go == true) await _mm.openAllFilesAccessSettings();
    }
  }
}
```

---

## Archive browser example

```dart
class ArchiveBrowserPage extends StatefulWidget {
  const ArchiveBrowserPage({super.key});
  @override
  State<ArchiveBrowserPage> createState() => _ArchiveBrowserPageState();
}

class _ArchiveBrowserPageState extends State<ArchiveBrowserPage> {
  final _mm = MediaManager();
  List<MediaItem> _archives = [];
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _total = await _mm.getArchiveCount();
    _archives = await _mm.getArchiveFiles(page: 0, pageSize: 100);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Archives ($_total)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _archives.length,
              itemBuilder: (ctx, i) {
                final item = _archives[i];
                final ext = item.name.split('.').last.toUpperCase();
                final kb = (item.size / 1024).toStringAsFixed(1);
                return ListTile(
                  leading: CircleAvatar(child: Text(ext, style: const TextStyle(fontSize: 9))),
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$kb KB'),
                );
              },
            ),
    );
  }
}
```

---

## Directory browser example

```dart
class DirectoryBrowserPage extends StatefulWidget {
  final String? initialPath;
  const DirectoryBrowserPage({super.key, this.initialPath});
  @override
  State<DirectoryBrowserPage> createState() => _DirectoryBrowserPageState();
}

class _DirectoryBrowserPageState extends State<DirectoryBrowserPage> {
  final _mm = MediaManager();
  List<Map<String, dynamic>> _entries = [];
  String _currentPath = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      _browse(widget.initialPath!);
    } else {
      _loadRoots();
    }
  }

  Future<void> _loadRoots() async {
    setState(() => _loading = true);
    final dirs = await _mm.getDirectories();
    // Convert to a list of directory entries for display
    setState(() {
      _entries = dirs.map((d) => {
        'name': d['name'],
        'path': d['path'],
        'isDirectory': true,
        'size': 0,
        'extension': '',
      }).toList();
      _loading = false;
    });
  }

  Future<void> _browse(String path) async {
    setState(() { _loading = true; _currentPath = path; });
    final contents = await _mm.getDirectoryContents(
      path: path,
      page: 0,
      pageSize: 300,
    );
    if (mounted) setState(() { _entries = contents; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.isEmpty
            ? 'Storage'
            : _currentPath.split('/').last),
        leading: _currentPath.isNotEmpty
            ? BackButton(onPressed: () => setState(() {
                _currentPath = _currentPath.substring(
                    0, _currentPath.lastIndexOf('/'));
                if (_currentPath.isEmpty) _loadRoots();
                else _browse(_currentPath);
              }))
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                final isDir = e['isDirectory'] as bool;
                final name = e['name'] as String;
                final size = e['size'] as int;
                final ext = (e['extension'] as String).toUpperCase();
                return ListTile(
                  leading: Icon(
                    isDir ? Icons.folder : Icons.insert_drive_file,
                    color: isDir ? Colors.amber : Colors.blue,
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: isDir
                      ? null
                      : Text('$ext  ${(size / 1024).toStringAsFixed(1)} KB'),
                  onTap: isDir
                      ? () => _browse(e['path'] as String)
                      : null,
                );
              },
            ),
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
| `INVALID_ARGUMENT` | `getThumbnail` | `uri` / `path` argument missing |
| `NO_ACTIVITY` | `requestStoragePermission` | Android activity not attached |

```dart
try {
  final items = await mm.getMediaPage(type: MediaType.archive);
} on PlatformException catch (e) {
  switch (e.code) {
    case 'QUERY_ERROR':
      print('Query failed: ${e.message}');
    case 'FILE_ACCESS_ERROR':
      print('Cannot read directory: ${e.message}');
    default:
      print('Error ${e.code}: ${e.message}');
  }
}
```

---


## License

MIT — see the [LICENSE](LICENSE) file for details.
