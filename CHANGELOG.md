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
