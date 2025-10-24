## 0.0.1

*  initial release.

## 0.0.2

*  Fix pob point.

## 0.0.3

*  Fix bug Ios && MacOs.

## 0.0.4

* Add New Feature thumbnail/preview .


## 0.0.5

* Enhanced OS compatibility - Support for Android 16 (API 36), iOS 18, and macOS 15 (Sequoia)
* Improved memory management and battery optimization for Android
* Enhanced permissions handling for latest Android versions
* Added comprehensive documentation with platform-specific setup guides
* Fixed compilation errors and memory leaks
* Added feature parity across all platforms
* Improved error handling and logging 

## 0.0.6
*  Edit pub point.
*  Edit readme.

## 0.0.7
*  Fix bug gradle.

## 0.0.8
*  Android: Replace deprecated video thumbnail API with modern createVideoThumbnail(File, Size) on API 29+ and fallback for older versions
*  Lower default Gradle JVM memory for better compatibility
*  Docs: Update README usage version, minor cleanup

## 0.0.9
*  Fix: Optimize JVM memory allocation to resolve Kotlin daemon startup issues
*  Android: Keep default heap size at 2G for optimal performance
*  Android: Lower MetaspaceSize and ReservedCodeCacheSize for improved performance on low-memory systems
*  Build: Add gradle.properties to main plugin directory for consistent JVM settings

## 0.1.0
*  **MAJOR PERFORMANCE IMPROVEMENTS**: Complete optimization overhaul based on photo_manager techniques
*  Android: Integrate Glide library for superior image loading, caching, and processing
*  Android: Replace simple ExecutorService with optimized ThreadPoolExecutor (3-5 threads with 60s keep-alive)
*  Android: Implement advanced caching system with 1/8 memory allocation (similar to photo_manager)
*  Android: Add dedicated ThumbnailUtil class for better code organization and maintainability
*  Android: Optimize image preview generation with Glide's centerCrop and disk caching
*  Android: Enhance video thumbnail extraction using Glide's frame extraction capabilities
*  Android: Improve permission handling with proper RequestPermissionsResultListener implementation
*  Android: Better resource management and cleanup in plugin lifecycle
*  Performance: Significant speed improvements for image and video loading operations
*  Code Quality: Refactor thumbnail generation logic into separate utility class following Single Responsibility Principle
