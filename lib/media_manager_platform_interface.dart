import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'media_manager_method_channel.dart';

/// The abstract base class for platform-specific implementations of media manager functionality.
///
/// This class extends [PlatformInterface] to ensure a single platform instance exists
/// and to prevent implementation collisions. All platform implementations must extend
/// this class rather than implementing the interface directly.
abstract class MediaManagerPlatform extends PlatformInterface {
  /// Constructs a MediaManagerPlatform.
  MediaManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaManagerPlatform _instance = MethodChannelMediaManager();

  /// The default singleton instance of [MediaManagerPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediaManager] if no other implementation is set.
  ///
  /// To provide a custom implementation:
  /// ```dart
  /// MediaManagerPlatform.instance = MyCustomMediaManager();
  /// ```
  static MediaManagerPlatform get instance => _instance;

  /// Sets the platform instance to a specific implementation.
  ///
  /// Platform implementations should call this when they register themselves,
  /// providing their own platform-specific class that extends [MediaManagerPlatform].
  ///
  /// Throws an assertion error if the instance doesn't extend MediaManagerPlatform
  /// or if the platform interface token doesn't match.
  static set instance(MediaManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Retrieves the platform's version string.
  ///
  /// Returns a String containing platform version information or null if unavailable.
  ///
  /// Example:
  /// ```dart
  /// final version = await MediaManagerPlatform.instance.getPlatformVersion();
  /// ```
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Gets a list of available storage directories on the device.
  ///
  /// Returns a List of Maps where each Map contains directory metadata
  /// (typically including 'name', 'path', and other platform-specific fields).
  ///
  /// Example:
  /// ```dart
  /// final directories = await MediaManagerPlatform.instance.getDirectories();
  /// ```
  Future<List<Map<String, dynamic>>> getDirectories() {
    throw UnimplementedError('getDirectories() has not been implemented.');
  }

  /// Retrieves contents of a specific directory.
  ///
  /// [path] - The absolute path of the directory to scan
  /// Returns a List of Maps with item metadata (name, path, type, size, etc.)
  ///
  /// Example:
  /// ```dart
  /// final contents = await MediaManagerPlatform.instance.getDirectoryContents('/storage/DCIM');
  /// ```
  Future<List<Map<String, dynamic>>> getDirectoryContents(String path) {
    throw UnimplementedError(
      'getDirectoryContents() has not been implemented.',
    );
  }

  /// Generates a thumbnail/preview for an image file.
  ///
  /// [path] - The absolute path to the image file
  /// Returns a [Uint8List] containing the thumbnail bytes or null if generation fails
  ///
  /// Example:
  /// ```dart
  /// final preview = await MediaManagerPlatform.instance.getImagePreview('/path/to/image.jpg');
  /// ```
  Future<Uint8List?> getImagePreview(String path) {
    throw UnimplementedError('getImagePreview() has not been implemented.');
  }

  /// Clears any cached image thumbnails/previews.
  ///
  /// Returns true if the cache was successfully cleared
  ///
  /// Example:
  /// ```dart
  /// final success = await MediaManagerPlatform.instance.clearImageCache();
  /// ```
  Future<bool> clearImageCache() {
    throw UnimplementedError('clearImageCache() has not been implemented.');
  }

  /// Requests storage access permission from the user.
  ///
  /// Returns true if permission was granted, false if denied
  ///
  /// Example:
  /// ```dart
  /// final hasPermission = await MediaManagerPlatform.instance.requestStoragePermission();
  /// ```
  Future<bool> requestStoragePermission() {
    throw UnimplementedError(
      'requestStoragePermission() has not been implemented.',
    );
  }

  /// Retrieves paths of all image files on the device.
  ///
  /// Returns a List of absolute file paths to image files
  ///
  /// Example:
  /// ```dart
  /// final images = await MediaManagerPlatform.instance.getAllImages();
  /// ```
  Future<List<String>> getAllImages() {
    throw UnimplementedError('getAllImages() has not been implemented.');
  }

  /// Retrieves paths of all video files on the device.
  ///
  /// Returns a List of absolute file paths to video files
  ///
  /// Example:
  /// ```dart
  /// final videos = await MediaManagerPlatform.instance.getAllVideos();
  /// ```
  Future<List<String>> getAllVideos() {
    throw UnimplementedError('getAllVideos() has not been implemented.');
  }

  /// Retrieves paths of all audio files on the device.
  ///
  /// Returns a List of absolute file paths to audio files
  ///
  /// Example:
  /// ```dart
  /// final audioFiles = await MediaManagerPlatform.instance.getAllAudio();
  /// ```
  Future<List<String>> getAllAudio() {
    throw UnimplementedError('getAllAudio() has not been implemented.');
  }

  /// Retrieves paths of all document files on the device.
  ///
  /// Returns a List of absolute file paths to document files
  ///
  /// Example:
  /// ```dart
  /// final documents = await MediaManagerPlatform.instance.getAllDocuments();
  /// ```
  Future<List<String>> getAllDocuments() {
    throw UnimplementedError('getAllDocuments() has not been implemented.');
  }

  /// Retrieves paths of all zip archive files on the device.
  ///
  /// Returns a List of absolute file paths to zip files
  ///
  /// Example:
  /// ```dart
  /// final zipFiles = await MediaManagerPlatform.instance.getAllZipFiles();
  /// ```
  Future<List<String>> getAllZipFiles() {
    throw UnimplementedError('getAllZipFiles() has not been implemented.');
  }

  /// Generates a thumbnail for a video file.
  ///
  /// Returns thumbnail data as Uint8List or null if generation fails
  ///
  /// Example:
  /// ```dart
  /// final thumbnail = await MediaManagerPlatform.instance.getVideoThumbnail('/path/to/video.mp4');
  /// ```
  Future<Uint8List?> getVideoThumbnail(String videoPath) {
    throw UnimplementedError('getVideoThumbnail() has not been implemented.');
  }

  /// Extracts album art from an audio file.
  ///
  /// Returns album art data as Uint8List or null if not available
  ///
  /// Example:
  /// ```dart
  /// final albumArt = await MediaManagerPlatform.instance.getAudioThumbnail('/path/to/audio.mp3');
  /// ```
  Future<Uint8List?> getAudioThumbnail(String audioPath) {
    throw UnimplementedError('getAudioThumbnail() has not been implemented.');
  }

  /// Retrieves files by specific formats/extensions.
  /// [formats] - List of file extensions to search for (e.g., ['apk', 'dart', 'exe'])
  /// Returns a list of absolute file paths.
  Future<List<String>> getAllFilesByFormat(List<String> formats) {
    throw UnimplementedError('getAllFilesByFormat() has not been implemented.');
  }
}
