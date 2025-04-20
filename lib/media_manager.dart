import 'dart:io';
import 'dart:typed_data';

import 'media_manager_platform_interface.dart';

/// A class that provides media management functionality across platforms.
/// This acts as a bridge between platform-specific implementations and the Dart code.
class MediaManager {
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
    return MediaManagerPlatform.instance.getDirectories();
  }

  /// Gets contents of a specific directory by its path.
  /// [path] - The absolute path of the directory to scan.
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
    return MediaManagerPlatform.instance.getDirectoryContents(path);
  }

  /// Gets a thumbnail/preview of an image file as a byte array.
  /// [path] - The path of the image file.
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
    return MediaManagerPlatform.instance.getImagePreview(path);
  }

  /// Clears cached image thumbnails/previews.
  /// Returns true if operation was successful.
  ///
  /// Example:
  /// ```dart
  /// void clearCache() async {
  ///   bool success = await MediaManager().clearImageCache();
  ///   if (success) {
  ///     print('Cache cleared successfully');
  ///   } else {
  ///     print('Failed to clear cache');
  ///   }
  /// }
  /// ```
  Future<bool> clearImageCache() {
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
    if (Platform.isAndroid) {
      return MediaManagerPlatform.instance.requestStoragePermission();
    } else if (Platform.isIOS) {
      return MediaManagerPlatform.instance.requestStoragePermission();
    } else if (Platform.isMacOS) {
      return MediaManagerPlatform.instance.requestMacStoragePermission();
    } else {
      return Future.value(false); // Default return value if no condition is met
    }
  }

  /// Requests Mac storage permission from the user.
  /// Returns true if permission was granted.
  ///
  /// Example:
  /// ```dart
  /// void checkAndRequestMacPermission() async {
  ///   bool hasPermission = await MediaManager().requestMacStoragePermission();
  ///   if (hasPermission) {
  ///     print('Permission granted, proceeding with operations');
  ///     // Continue with media operations
  ///   } else {
  ///     print('Permission denied, showing error message');
  ///     // Show error or request again
  ///   }
  /// }
  /// ```

  Future<bool> requestMacStoragePermission() {
    return MediaManagerPlatform.instance.requestMacStoragePermission();
  }

  /// Retrieves all image files from device storage.
  /// Returns a list of absolute file paths.
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
    return MediaManagerPlatform.instance.getAllImages();
  }

  /// Retrieves all video files from device storage.
  /// Returns a list of absolute file paths.
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
    return MediaManagerPlatform.instance.getAllVideos();
  }

  /// Retrieves all audio files from device storage.
  /// Returns a list of absolute file paths.
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
    return MediaManagerPlatform.instance.getAllAudio();
  }

  /// Retrieves all document files from device storage.
  /// Returns a list of absolute file paths.
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
    return MediaManagerPlatform.instance.getAllDocuments();
  }

  /// Retrieves all zip archive files from device storage.
  /// Returns a list of absolute file paths.
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
    return MediaManagerPlatform.instance.getAllZipFiles();
  }
}
