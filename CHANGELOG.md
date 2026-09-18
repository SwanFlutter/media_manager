## 1.0.3

- Added executables, installers and disk images (.exe, .msi, .msix, .appx, .iso, .img, .dmg, ...)
  plus expanded office/text/database formats to the document type on Android, iOS and macOS.

## 1.0.2

### New Features

* **Archive category** — new `MediaType.archive` (Android `Type.ARCHIVE`, iOS / macOS sandbox scan) with a dedicated method to list zip / rar / 7z / tar / gz / bz2 / xz / lzma / zst / apk / aab / deb / rpm / jar / war / cbz / cbr / epub and more. The Documents tab and the example app now have a separate **Archives** tab.
* **Android — file-system fallback scan** — `MediaStore` does **not** index archives or many custom formats (this is especially true on Android 13+ and on most OEM ROMs), so `DOCUMENT`, `ARCHIVE` and custom-extension `ANY` queries now merge a bounded, depth-limited walk of every accessible external-storage volume into the MediaStore result. Files sitting in `Download/` that never made it into the media database are now visible.
* **Android — custom extensions match by name too** — `buildExtensionFilter()` now always adds a `DISPLAY_NAME LIKE '%.ext'` term alongside the `mime_type IN (…)` term, so files with a missing or vendor-specific MIME (common for `zip`, `rar`, `7z`) are no longer silently dropped.
* **Dart** — `MediaItem.path` field: the real file-system path when the platform can provide one (MediaStore `DATA` on Android, absolute path on iOS / macOS), `null` otherwise.
* **Android / Dart** — new `MediaManager.hasAllFilesAccess()` — reports whether the "All files access" (MANAGE_EXTERNAL_STORAGE) special setting is granted, which is required for the archive / custom-extension file scan on Android 11+. The example now prompts the user to enable it on first launch.
* **Android** — the MediaStore half of a merged Documents / Archives query is wrapped in `runCatching`, so a ROM that rejects the selection string still returns the file-system scan instead of throwing.
* **iOS / macOS** — `getMediaPage` / `getMediaCount` with `document`, `archive` or a non-empty `extensions` filter resolve from the app sandbox (iOS: `Documents`, `Downloads`, `Caches`, `tmp`; macOS: the chosen root directory) instead of returning Photos-library assets, which never contain zips, PDFs or code files. macOS gains a full archive extension list.

### Bug Fixes — Android

* **Documents tab showed images/screenshots** — `buildSelection()` for `Type.DOCUMENT` was falling into the same `1=1` branch as `Type.ANY` when no extensions were supplied. Fixed by introducing a 35-entry MIME whitelist plus an explicit `media_type NOT IN (image, video, audio)` guard.
* **Many items showed a blank name** — `DISPLAY_NAME` can be `NULL` in MediaStore. The query now falls back to the last path segment of the content URI (URL-decoded).
* **Duplicate rows when merging MediaStore + file-system scan** — de-duplicated on both the real path (`DATA`) and `name|size`.
* **Comment syntax error broke the build** — KDoc `image/*, video/*` accidentally opened nested Kotlin block comments. Rewritten.
* **Example — removed debug `print` loop** from `_loadNext()`.

### Bug Fixes — iOS

* **`assetToMap` name never empty** — `filename` KVC key on `PHAsset` returns `nil` on some iOS versions. Name now falls back in order: `filename` KVC → `PHAssetResource.originalFilename` → first component of `localIdentifier`. A blank display name is no longer possible.
* **Expanded `archiveExts`** — aligned with Android and macOS. Added `aab`, `deb`, `rpm`, `jar`, `war`, `tbz2`, `txz`, `lz`, `lzma`, `tzst`, `whl`, `egg` (25 extensions total, up from 15).
* **Expanded `docExts`** — added `dot`, `dotx`, `docm`, `xlsm`, `xlsb`, `pptm`, `ppsx`, `odt`, `ods`, `odp`, `htm`, `markdown`, `azw3`, `fb2`, `mdb`.
* **`scanSandbox` improvements** — budget raised from 20 000 to 50 000 visited entries; added `.skipsPackageDescendants`.
* **Podspec metadata** — updated `version`, `summary`, `description`, `homepage`, `author` (were placeholder values).

### Bug Fixes — macOS

* **`hasAllFilesAccess` not handled** — `switch` fell through to `default`, causing `MissingPluginException` on Dart side. Added explicit handler that returns `true` (macOS has no `MANAGE_EXTERNAL_STORAGE` concept).
* **`mimeType(for:)` replaced static 30-entry map with `UTType` API** — macOS 11+ uses `UTType(filenameExtension:)?.preferredMIMEType` for full OS-backed coverage; older systems fall back to a 55-entry table.
* **Added `UniformTypeIdentifiers` import** — required for the `UTType` API path.
* **Podspec metadata** — updated `version`, `summary`, `description`, `homepage`, `author`.

---

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
