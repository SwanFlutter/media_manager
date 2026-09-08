## 1.0.1

### Bug Fixes
* **Android** — Fixed `java.io.SyncFailedException: sync failed` that prevented every thumbnail from being saved to disk. `FileDescriptor.sync()` throws on `cacheDir` (tmpfs/virtual FS) on many Android 10+ devices; replaced with `BufferedOutputStream.flush()` which is sufficient for thumbnail cache correctness.
* **Android** — Fixed blank image/video grid: `MediaStoreScanner` now builds typed URIs (`Images.Media`, `Video.Media`, `Audio.Media`) instead of the generic `Files` URI so `ContentResolver.loadThumbnail` (API 29+) and the legacy `Images.Thumbnails` API work correctly.
* **Android** — Replaced unused `glide` dependency with `androidx.exifinterface:exifinterface:1.3.7` and added `androidx.annotation:annotation:1.9.1` which are actually used by `ThumbnailEngine`.
* **Android** — `decodeSampled()` stream `open()` now wrapped in try/catch so a `SecurityException` on a single file doesn't abort the whole batch.
* **Android** — `imageBitmap()` fallback chain: `loadThumbnail` (API 29+) → legacy `Images.Thumbnails` (API < 29) → `BitmapFactory` two-pass decode. Previously `loadThumbnail` failure was silently swallowed without falling back.
* **Dart** — `ThumbnailQueue` duplicate-request handling rewritten from a busy-wait `Future.delayed(30 ms)` loop to a `Completer`-based waiter list — eliminates CPU waste and resolves duplicate channel calls for the same key.
* **Dart** — `_ThumbnailTileState`: thumbnail fetch now deferred to `addPostFrameCallback` so the grid renders its first frame before any platform calls are made (reduces `Skipped N frames` jank).
* **Dart** — When thumbnail path is `null`, widget correctly transitions to error state instead of staying stuck on a blank placeholder forever.
* **Example** — Removed unsupported `example/windows/` directory.

---

## 1.0.0

**BREAKING CHANGE — API redesign to match the new Android engine**

### Dart (lib)
* `MediaManager` facade fully rewritten — all old `getAllImages/Videos/Audio/Documents/ZipFiles` methods removed
* New paginated API: `getMediaPage(type, extensions, page, pageSize)` — pagination at SQLite/PHFetchOptions level, never loads the full library
* New `getMediaCount(type, extensions)` for computing total pages before the first query
* New `getThumbnail(uriOrPath, width, height, dateModified, kind)` — returns an **on-disk JPEG path** instead of raw bytes; eliminates large byte-array transfers over the method channel
* New `clearThumbnailCache()` replaces `clearImageCache()`
* New `hasStoragePermission()` — check without prompting
* New `openAllFilesAccessSettings()` — direct link to Android MANAGE_ALL_FILES page
* `getDirectories()` return type changed to `List<Map<String, String>>`
* `getDirectoryContents()` now accepts named parameters `path`, `page`, `pageSize`
* `MediaItem` model updated: added `mediaType` (int), `const` constructor, full `fromMap` with null-safe coercions
* `MediaType` enum doc-commented
* `isolate_worker.dart` replaced with a lightweight `parseMediaItems()` helper using `Isolate.run` — platform calls from secondary isolates removed (was broken by design)

### Android
* `ThumbnailEngine`: disk-backed JPEG cache (`mm_thumbs/`), MD5 cache key, `Semaphore(4)`, LRU trim at 96 MB, `Bitmap.recycle()` after write, returns absolute path
* `MediaStoreScanner`: real SQL `LIMIT/OFFSET` pagination via `Bundle` on API 30+ and legacy sort string on older
* `MediaManagerPlugin`: `SafeResult` wrapper prevents "Reply already submitted" crashes; `SupervisorJob` + `Dispatchers.IO` coroutine scope; `hasStoragePermission`, `openAllFilesAccessSettings` added; all old `getAllX` method-channel calls removed

### iOS
* `ThumbnailUtil.swift` removed — replaced by `ThumbnailEngine.swift`
* `ThumbnailEngine`: same disk-cache design as Android (`mm_thumbs/`, MD5, semaphore, LRU trim), uses `UIGraphicsImageRenderer` for scale-down decode, `ph://` PHAsset URI resolution, album-art via `AVAsset.commonMetadata`
* `MediaManagerPlugin`: `SafeResult` added; `getMediaPage`/`getMediaCount` use `PHFetchOptions` with sort + index-range enumeration; `hasStoragePermission` uses `PHAuthorizationStatus`; `getDirectoryContents` paginated; Kingfisher dependency **removed**

### macOS
* `ThumbnailUtil.swift` removed — replaced by `ThumbnailEngine.swift`
* `ThumbnailEngine`: same disk-cache design; uses `NSImage` + `NSBitmapImageRep` for JPEG output; `AVAssetImageGenerator` for video frames; no Kingfisher
* `MediaManagerPlugin`: `SafeResult` added; `getMediaPage`/`getMediaCount` use recursive file-system walk (max depth 8) with extension filtering; `getDirectories` returns well-known home subdirectories; `requestStoragePermission` uses `NSOpenPanel`; Kingfisher dependency **removed**

* Fix bug kotlin (AGP)

---

## 0.1.2

* Fix bug gradle.
* Remove debug logging from MediaManagerPlugin

---

## 0.1.1

* Fix README for use Performance Management & Isolate Usage

---

## 0.1.0

* **MAJOR PERFORMANCE IMPROVEMENTS**: Complete optimization overhaul based on photo_manager techniques
* Android: Integrate Glide library for superior image loading, caching, and processing
* Android: Replace simple ExecutorService with optimized ThreadPoolExecutor (3-5 threads with 60s keep-alive)
* Android: Implement advanced caching system with 1/8 memory allocation (similar to photo_manager)
* Android: Add dedicated ThumbnailUtil class for better code organization and maintainability
* Android: Optimize image preview generation with Glide's centerCrop and disk caching
* Android: Enhance video thumbnail extraction using Glide's frame extraction capabilities
* Android: Improve permission handling with proper RequestPermissionsResultListener implementation
* Android: Better resource management and cleanup in plugin lifecycle
* Performance: Significant speed improvements for image and video loading operations
* Code Quality: Refactor thumbnail generation logic into separate utility class following Single Responsibility Principle

---

## 0.0.9

* Fix: Optimize JVM memory allocation to resolve Kotlin daemon startup issues
* Android: Keep default heap size at 2G for optimal performance
* Android: Lower MetaspaceSize and ReservedCodeCacheSize for improved performance on low-memory systems
* Build: Add gradle.properties to main plugin directory for consistent JVM settings

---

## 0.0.8

* Android: Replace deprecated video thumbnail API with modern createVideoThumbnail(File, Size) on API 29+ and fallback for older versions
* Lower default Gradle JVM memory for better compatibility
* Docs: Update README usage version, minor cleanup

---

## 0.0.7

* Fix bug gradle.

---

## 0.0.6

* Edit pub point.
* Edit readme.

---

## 0.0.5

* Enhanced OS compatibility - Support for Android 16 (API 36), iOS 18, and macOS 15 (Sequoia)
* Improved memory management and battery optimization for Android
* Enhanced permissions handling for latest Android versions
* Added comprehensive documentation with platform-specific setup guides
* Fixed compilation errors and memory leaks
* Added feature parity across all platforms
* Improved error handling and logging

---

## 0.0.4

* Add New Feature thumbnail/preview.

---

## 0.0.3

* Fix bug iOS && MacOS.

---

## 0.0.2

* Fix pub point.

---

## 0.0.1

* Initial release.
