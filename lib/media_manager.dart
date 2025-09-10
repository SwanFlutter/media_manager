library;

import 'dart:typed_data';

import 'media_manager_platform_interface.dart';
import 'src/isolate_worker.dart';

export 'src/isolate_worker.dart' show IsolateManager;

/// A class that provides media management functionality across platforms.
/// This acts as a bridge between platform-specific implementations and the Dart code.
/// Uses isolates for heavy operations to prevent UI freezing.
class MediaManager {
  static bool _useIsolates = true;

  /// Enable or disable isolate usage for heavy operations
  static void setIsolateUsage(bool enabled) {
    _useIsolates = enabled;
  }

  /// Dispose isolates when no longer needed
  static void disposeIsolates() {
    IsolateManager.dispose();
  }

  /// Gets the platform version information.
  ///
  /// Example:
  /// ```dart
  /// void checkPlatformVersion() async {
  ///   String? version = await MediaManager().getPlatformVersion();
  ///   print('Platform version: $version');
  /// }
  /// ```
  Future<String?> getPlatformVersion() {
    return MediaManagerPlatform.instance.getPlatformVersion();
  }

  /// Retrieves a list of available directories in the device storage.
  /// Returns a List of Maps containing directory information (name, path, etc.).
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void listDirectories() async {
  ///   List<Map<String, dynamic>> dirs = await MediaManager().getDirectories();
  ///   for (var dir in dirs) {
  ///     print('Directory: ${dir['name']}');
  ///     print('Path: ${dir['path']}');
  ///   }
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getDirectories() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeDirectoryScanOperation<List<Map<String, dynamic>>>(
    //     'getDirectories',
    //   );
    // }
    return MediaManagerPlatform.instance.getDirectories();
  }

  /// Gets contents of a specific directory by its path.
  /// [path] - The absolute path of the directory to scan.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void showDirectoryContents() async {
  ///   String path = '/storage/emulated/0/Downloads';
  ///   var contents = await MediaManager().getDirectoryContents(path);
  ///   for (var item in contents) {
  ///     print('Name: ${item['name']}');
  ///     print('Type: ${item['type']}');
  ///     print('Size: ${item['size']}');
  ///   }
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getDirectoryContents(String path) {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeDirectoryScanOperation<List<Map<String, dynamic>>>(
    //     'getDirectoryContents',
    //     path: path,
    //   );
    // }
    return MediaManagerPlatform.instance.getDirectoryContents(path);
  }

  /// Gets a thumbnail/preview of an image file as a byte array.
  /// [path] - The path of the image file.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// Widget buildImagePreview(String imagePath) {
  ///   return FutureBuilder<Uint8List?>(
  ///     future: MediaManager().getImagePreview(imagePath),
  ///     builder: (context, snapshot) {
  ///       if (snapshot.connectionState == ConnectionState.done &&
  ///           snapshot.data != null) {
  ///         return Image.memory(
  ///           snapshot.data!,
  ///           fit: BoxFit.cover,
  ///         );
  ///       } else {
  ///         return CircularProgressIndicator();
  ///       }
  ///     },
  ///   );
  /// }
  /// ```
  Future<Uint8List?> getImagePreview(String path) {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeImageProcessingOperation<Uint8List?>(
    //     'getImagePreview',
    //     path: path,
    //   );
    // }
    return MediaManagerPlatform.instance.getImagePreview(path);
  }

  /// Clears cached image thumbnails/previews.
  /// Returns true if operation was successful.
  ///
  /// Example:
  /// ```dart
  /// void clearCache() async {
  ///   await MediaManager().clearImageCache();
  ///   print('Image cache cleared');
  /// }
  /// ```
  Future<void> clearImageCache() {
    if (_useIsolates) {
      return IsolateManager.executeImageProcessingOperation('clearImageCache');
    }
    return MediaManagerPlatform.instance.clearImageCache();
  }

  /// Requests storage permission from the user.
  /// Returns true if permission was granted.
  ///
  /// Example:
  /// ```dart
  /// void checkAndRequestPermission() async {
  ///   bool hasPermission = await MediaManager().requestStoragePermission();
  ///   if (hasPermission) {
  ///     print('Permission granted, proceeding with operations');
  ///     // Continue with media operations
  ///   } else {
  ///     print('Permission denied, showing error message');
  ///     // Show error or request again
  ///   }
  /// }
  /// ```
  Future<bool> requestStoragePermission() {
    return MediaManagerPlatform.instance.requestStoragePermission();
  }

  /// Retrieves all image files from device storage.
  /// Returns a list of absolute file paths.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void displayAllImages() async {
  ///   List<String> images = await MediaManager().getAllImages();
  ///   print('Found ${images.length} images');
  ///   for (String path in images) {
  ///     print('Image path: $path');
  ///     // Use paths to display images in your UI
  ///   }
  /// }
  /// ```
  Future<List<String>> getAllImages() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeFilesScanOperation(
    //     'getAllImages',
    //     [],
    //   );
    // }
    return MediaManagerPlatform.instance.getAllImages();
  }

  /// Retrieves all video files from device storage.
  /// Returns a list of absolute file paths.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void listAllVideos() async {
  ///   List<String> videos = await MediaManager().getAllVideos();
  ///   print('Found ${videos.length} videos');
  ///   for (String videoPath in videos.take(5)) {
  ///     print('Video: $videoPath');
  ///     // Process video files
  ///   }
  /// }
  /// ```
  Future<List<String>> getAllVideos() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeFilesScanOperation(
    //     'getAllVideos',
    //     [],
    //   );
    // }
    return MediaManagerPlatform.instance.getAllVideos();
  }

  /// Retrieves all audio files from device storage.
  /// Returns a list of absolute file paths.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void scanAudioLibrary() async {
  ///   List<String> audioFiles = await MediaManager().getAllAudio();
  ///   print('Your audio library contains ${audioFiles.length} files');
  ///
  ///   // Create audio player for the first file if available
  ///   if (audioFiles.isNotEmpty) {
  ///     String firstAudioPath = audioFiles.first;
  ///     print('First audio file: $firstAudioPath');
  ///     // Initialize audio player with this path
  ///   }
  /// }
  /// ```
  Future<List<String>> getAllAudio() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeFilesScanOperation(
    //     'getAllAudio',
    //     [],
    //   );
    // }
    return MediaManagerPlatform.instance.getAllAudio();
  }

  /// Retrieves all document files from device storage.
  /// Returns a list of absolute file paths.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void organizeDocuments() async {
  ///   List<String> docs = await MediaManager().getAllDocuments();
  ///
  ///   // Group documents by extension
  ///   Map<String, List<String>> docsByType = {};
  ///
  ///   for (String path in docs) {
  ///     String ext = path.split('.').last.toLowerCase();
  ///     if (!docsByType.containsKey(ext)) {
  ///       docsByType[ext] = [];
  ///     }
  ///     docsByType[ext]!.add(path);
  ///   }
  ///
  ///   // Print document statistics
  ///   docsByType.forEach((ext, files) {
  ///     print('Found ${files.length} .$ext files');
  ///   });
  /// }
  /// ```
  Future<List<String>> getAllDocuments() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeFilesScanOperation(
    //     'getAllDocuments',
    //     [],
    //   );
    // }
    return MediaManagerPlatform.instance.getAllDocuments();
  }

  /// Retrieves all zip archive files from device storage.
  /// Returns a list of absolute file paths.
  /// Uses isolates for better performance when enabled.
  ///
  /// Example:
  /// ```dart
  /// void findArchives() async {
  ///   List<String> archives = await MediaManager().getAllZipFiles();
  ///   print('Found ${archives.length} archive files');
  ///
  ///   // Calculate total size of all archives
  ///   for (String archivePath in archives) {
  ///     print('Archive: $archivePath');
  ///     // You could get file size here and sum them
  ///   }
  ///
  ///   // Show dialog to user if many large archives are found
  ///   if (archives.length > 10) {
  ///     print('Consider cleaning up your archive files to save space');
  ///   }
  /// }
  /// ```
  Future<List<String>> getAllZipFiles() {
    // Temporarily disable isolates for debugging
    // if (_useIsolates) {
    //   return IsolateManager.executeFilesScanOperation(
    //     'getAllZipFiles',
    //     [],
    //   );
    // }
    return MediaManagerPlatform.instance.getAllZipFiles();
  }

  /// Generates a thumbnail for a video file.
  /// Returns thumbnail data as Uint8List or null if generation fails.
  ///
  /// Example:
  /// ```dart
  /// void showVideoThumbnail(String videoPath) async {
  ///   Uint8List? thumbnail = await MediaManager().getVideoThumbnail(videoPath);
  ///   if (thumbnail != null) {
  ///     // Display thumbnail using Image.memory(thumbnail)
  ///   }
  /// }
  /// ```
  Future<Uint8List?> getVideoThumbnail(String videoPath) {
    // Note: Video thumbnail generation is typically CPU intensive
    // Consider adding isolate support in future versions
    return MediaManagerPlatform.instance.getVideoThumbnail(videoPath);
  }

  /// Extracts album art from an audio file.
  /// Returns album art data as Uint8List or null if not available.
  ///
  /// Example:
  /// ```dart
  /// void showAlbumArt(String audioPath) async {
  ///   Uint8List? albumArt = await MediaManager().getAudioThumbnail(audioPath);
  ///   if (albumArt != null) {
  ///     // Display album art using Image.memory(albumArt)
  ///   }
  /// }
  /// ```
  Future<Uint8List?> getAudioThumbnail(String audioPath) {
    return MediaManagerPlatform.instance.getAudioThumbnail(audioPath);
  }

  /// Retrieves files by specific formats/extensions.
  /// [formats] - List of file extensions to search for (e.g., ['apk', 'dart', 'exe', 'deb'])
  /// Returns a list of absolute file paths.
  ///
  /// Example:
  /// ```dart
  /// // Get APK and executable files
  /// final appFiles = await MediaManager().getAllFilesByFormat(['apk', 'exe', 'msi']);
  ///
  /// // Get source code files
  /// final codeFiles = await MediaManager().getAllFilesByFormat(['dart', 'java', 'kt', 'swift']);
  ///
  /// // Get archive files
  /// final archives = await MediaManager().getAllFilesByFormat(['zip', 'rar', '7z', 'tar']);
  /// ```
  Future<List<String>> getAllFilesByFormat(List<String> formats) {
    if (_useIsolates) {
      return IsolateManager.executeFilesScanOperation(
        'getAllFilesByFormat',
        formats,
      );
    }
    return MediaManagerPlatform.instance.getAllFilesByFormat(formats);
  }

  /// Disposes isolate resources when the app is closing.
  /// Call this in your app's dispose method to clean up isolates.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   MediaManager().dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    IsolateManager.dispose();
  }
}
